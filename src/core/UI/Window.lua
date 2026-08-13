local Window = {}
Window.__index = Window

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local DEFAULTS = {
    Size = UDim2.fromOffset(820, 570),
    Position = UDim2.fromScale(0.5, 0.5),

    Background = Color3.fromRGB(14, 14, 18),
    Secondary = Color3.fromRGB(20, 20, 26),
    Card = Color3.fromRGB(25, 25, 32),

    Accent = Color3.fromRGB(120, 90, 255),
    AccentDark = Color3.fromRGB(91, 65, 210),

    Text = Color3.fromRGB(238, 238, 244),
    MutedText = Color3.fromRGB(145, 145, 157),

    Border = Color3.fromRGB(43, 43, 53),

    Success = Color3.fromRGB(80, 210, 130),
    Warning = Color3.fromRGB(240, 185, 80),
    Danger = Color3.fromRGB(235, 85, 95),

    CornerRadius = 9,
    AnimationTime = 0.16,

    SidebarWidth = 158,
    HeaderHeight = 52,

    TabHeight = 37,
    TabSpacing = 6,

    EnableAnimations = true,
    EnableHover = true,
    ClampToScreen = true,

    SearchSections = true,
    SearchControls = true,

    ClosePopupsOnOutsideClick = true,
}

local function merge(defaults, overrides)
    local result = {}

    for key, value in pairs(defaults) do
        result[key] = value
    end

    for key, value in pairs(overrides or {}) do
        result[key] = value
    end

    return result
end

local function create(className, properties)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end

    return object
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end

    local args = table.pack(...)

    task.spawn(function()
        local success, err = pcall(function()
            callback(table.unpack(args, 1, args.n))
        end)

        if not success then
            warn("[Lua Test] UI callback error:", err)
        end
    end)
end

local function containsText(text, query)
    text = tostring(text or ""):lower()
    query = tostring(query or ""):lower()

    if query == "" then
        return true
    end

    return text:find(query, 1, true) ~= nil
end

function Window.new(
    components,
    config,
    connections,
    notifications,
    options
)
    assert(components, "Window requires Components")
    assert(config, "Window requires Config")

    local self = setmetatable({}, Window)

    self.Components = components
    self.Config = config
    self.ConnectionManager = connections
    self.Notifications = notifications

    self.Options = merge(DEFAULTS, options)

    self.Theme = {
        Background = self.Options.Background,
        Secondary = self.Options.Secondary,
        Card = self.Options.Card,

        Accent = self.Options.Accent,
        AccentDark = self.Options.AccentDark,

        Text = self.Options.Text,
        MutedText = self.Options.MutedText,

        Border = self.Options.Border,

        Success = self.Options.Success,
        Warning = self.Options.Warning,
        Danger = self.Options.Danger,
    }

    self.Gui = nil
    self.Main = nil
    self.Header = nil
    self.Body = nil
    self.Sidebar = nil
    self.PagesContainer = nil
    self.SearchBox = nil

    self.Title = nil
    self.Subtitle = nil
    self.Footer = nil

    self.Tabs = {}
    self.Controls = {}

    self.CurrentTab = nil

    self.Visible = false
    self.Minimized = false
    self.Destroyed = false

    self._tabOrder = {}
    self._connections = {}
    self._popups = {}
    self._dragging = false
    self._dragStart = nil
    self._startPosition = nil
    self._keybindListening = nil

    self._searchQuery = ""

    return self
end

function Window:_tween(object, properties, duration)
    if not object then
        return nil
    end

    if not self.Options.EnableAnimations then
        for property, value in pairs(properties) do
            pcall(function()
                object[property] = value
            end)
        end

        return nil
    end

    local tween = TweenService:Create(
        object,
        TweenInfo.new(
            duration or self.Options.AnimationTime,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        properties
    )

    return tween
end

function Window:_play(object, properties, duration)
    local tween = self:_tween(
        object,
        properties,
        duration
    )

    if tween then
        tween:Play()
    end

    return tween
end

function Window:_register(name, connection)
    if not connection then
        return nil
    end

    if self.ConnectionManager
        and self.ConnectionManager.Add then

        local success, result = pcall(function()
            return self.ConnectionManager:Add(
                name,
                connection
            )
        end)

        if success then
            return result or connection
        end
    end

    table.insert(
        self._connections,
        connection
    )

    return connection
end

function Window:_disconnectAll()
    for _, connection in ipairs(self._connections) do
        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end
    end

    table.clear(self._connections)

    if self.ConnectionManager
        and self.ConnectionManager.Clear then

        pcall(function()
            self.ConnectionManager:Clear()
        end)
    elseif self.ConnectionManager
        and self.ConnectionManager.Destroy then

        pcall(function()
            self.ConnectionManager:Destroy()
        end)
    end
end

function Window:_corner(object, radius)
    if self.Components.Corner then
        return self.Components:Corner(
            object,
            radius or 6
        )
    end

    return create("UICorner", {
        CornerRadius = UDim.new(
            0,
            radius or 6
        ),
        Parent = object
    })
end

function Window:_stroke(
    object,
    color,
    thickness,
    transparency
)
    if self.Components.Stroke then
        return self.Components:Stroke(
            object,
            color,
            thickness or 1,
            transparency or 0
        )
    end

    return create("UIStroke", {
        Color = color or self.Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = object
    })
end

function Window:_padding(object, amount)
    if self.Components.Padding then
        return self.Components:Padding(
            object,
            amount
        )
    end

    return create("UIPadding", {
        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount),
        Parent = object
    })
end

function Window:_list(parent, padding)
    if self.Components.List then
        return self.Components:List(
            parent,
            padding or 6
        )
    end

    return create("UIListLayout", {
        Padding = UDim.new(
            0,
            padding or 6
        ),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = parent
    })
end

function Window:_card(parent, height)
    if self.Components.CreateCard then
        return self.Components:CreateCard(
            parent,
            height or 42
        )
    end

    local card = create("Frame", {
        Size = UDim2.new(
            1,
            0,
            0,
            height or 42
        ),
        BackgroundColor3 = self.Theme.Card,
        BorderSizePixel = 0,
        Parent = parent
    })

    self:_corner(card, 7)

    self:_stroke(
        card,
        self.Theme.Border,
        1,
        0.55
    )

    return card
end

function Window:_button(parent, text)
    if self.Components.CreateButton then
        return self.Components:CreateButton(
            parent,
            text
        )
    end

    local button = create("TextButton", {
        Size = UDim2.new(
            1,
            0,
            0,
            36
        ),
        BackgroundColor3 = self.Theme.Card,
        BorderSizePixel = 0,
        AutoButtonColor = false,

        Font = Enum.Font.GothamMedium,
        Text = text or "Button",
        TextColor3 = self.Theme.Text,
        TextSize = 12,

        Parent = parent
    })

    self:_corner(button, 7)

    return button
end

function Window:_addHover(
    object,
    normalColor,
    hoverColor
)
    if not object
        or not self.Options.EnableHover then
        return
    end

    self:_register(
        "HoverEnter_" .. tostring(object),
        object.MouseEnter:Connect(function()
            if self.Destroyed then
                return
            end

            self:_play(
                object,
                {
                    BackgroundColor3 = hoverColor
                },
                0.1
            )
        end)
    )

    self:_register(
        "HoverLeave_" .. tostring(object),
        object.MouseLeave:Connect(function()
            if self.Destroyed then
                return
            end

            self:_play(
                object,
                {
                    BackgroundColor3 = normalColor
                },
                0.1
            )
        end)
    )
end

function Window:_registerPopup(popup)
    if not popup then
        return
    end

    table.insert(
        self._popups,
        popup
    )
end

function Window:_closePopups(except)
    for _, popup in ipairs(self._popups) do
        if popup
            and popup ~= except
            and popup.Parent then

            popup.Visible = false
        end
    end
end

function Window:_setupPopupManager()
    if not self.Options.ClosePopupsOnOutsideClick then
        return
    end

    self:_register(
        "PopupManager",
        UserInputService.InputBegan:Connect(
            function(input, processed)
                if processed
                    or self.Destroyed then
                    return
                end

                if input.UserInputType
                    ~= Enum.UserInputType.MouseButton1 then
                    return
                end

                local mousePosition =
                    input.Position

                for _, popup in ipairs(self._popups) do
                    if popup
                        and popup.Visible then

                        local position =
                            popup.AbsolutePosition

                        local size =
                            popup.AbsoluteSize

                        local inside =
                            mousePosition.X >= position.X
                            and mousePosition.X <=
                                position.X + size.X
                            and mousePosition.Y >= position.Y
                            and mousePosition.Y <=
                                position.Y + size.Y

                        if not inside then
                            popup.Visible = false
                        end
                    end
                end
            end
        )
    )
end

function Window:Create()
    if self.Destroyed then
        error("Cannot create a destroyed Window")
    end

    local player = Players.LocalPlayer

    if not player then
        error("LocalPlayer unavailable")
    end

    local playerGui =
        player:WaitForChild("PlayerGui")

    local oldGui =
        playerGui:FindFirstChild("LuaTestUI")

    if oldGui then
        oldGui:Destroy()
    end

    local gui = create("ScreenGui", {
        Name = "LuaTestUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior =
            Enum.ZIndexBehavior.Sibling,
        Parent = playerGui
    })

    self.Gui = gui

    local main = create("Frame", {
        Name = "Main",

        AnchorPoint =
            Vector2.new(0.5, 0.5),

        Position =
            self.Options.Position,

        Size =
            self.Options.Size,

        BackgroundColor3 =
            self.Theme.Background,

        BorderSizePixel = 0,

        ClipsDescendants = true,

        Parent = gui
    })

    self.Main = main

    self:_corner(
        main,
        self.Options.CornerRadius
    )

    self:_stroke(
        main,
        self.Theme.Border,
        1,
        0.1
    )

    self:_createHeader()
    self:_createBody()
    self:_setupPopupManager()

    if self.Notifications
        and self.Notifications.Init then

        self.Notifications:Init(gui)
    end

    self:_register(
        "WindowToggle",
        UserInputService.InputBegan:Connect(
            function(input, processed)
                if processed
                    or self.Destroyed then
                    return
                end

                local ui = self.Config.UI

                local toggleKey =
                    ui and ui.ToggleKey

                if toggleKey
                    and input.KeyCode == toggleKey then

                    self:SetVisible(
                        not self.Visible
                    )
                end
            end
        )
    )

    self:SetVisible(
        true,
        false
    )

    return self
end

function Window:_createHeader()
    local header = create("Frame", {
        Name = "Header",

        Size = UDim2.new(
            1,
            0,
            0,
            self.Options.HeaderHeight
        ),

        BackgroundColor3 =
            self.Theme.Secondary,

        BorderSizePixel = 0,

        Parent = self.Main
    })

    self.Header = header

    local accent = create("Frame", {
        Name = "Accent",

        Size =
            UDim2.new(0, 3, 1, 0),

        BackgroundColor3 =
            self.Theme.Accent,

        BorderSizePixel = 0,

        Parent = header
    })

    self.HeaderAccent = accent

    self:_corner(
        accent,
        2
    )

    local title = create("TextLabel", {
        Position =
            UDim2.fromOffset(17, 7),

        Size =
            UDim2.new(0, 170, 0, 20),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamBold,

        Text = "Lua Test",

        TextColor3 =
            self.Theme.Text,

        TextSize = 15,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = header
    })

    self.Title = title

    local subtitle = create("TextLabel", {
        Position =
            UDim2.fromOffset(17, 27),

        Size =
            UDim2.new(0, 220, 0, 16),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.Gotham,

        Text =
            "Advanced Control Panel",

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 9,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = header
    })

    self.Subtitle = subtitle

    local minimize = create("TextButton", {
        AnchorPoint =
            Vector2.new(1, 0.5),

        Position =
            UDim2.new(
                1,
                -10,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(28, 28),

        BackgroundTransparency = 1,

        Text = "—",

        Font =
            Enum.Font.GothamBold,

        TextSize = 18,

        TextColor3 =
            self.Theme.MutedText,

        AutoButtonColor = false,

        Parent = header
    })

    self.MinimizeButton = minimize

    self:_register(
        "Minimize",
        minimize.MouseButton1Click:Connect(
            function()
                self:SetVisible(false)
            end
        )
    )

    local search = create("TextBox", {
        AnchorPoint =
            Vector2.new(1, 0.5),

        Position =
            UDim2.new(
                1,
                -48,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(210, 30),

        BackgroundColor3 =
            self.Theme.Background,

        BorderSizePixel = 0,

        PlaceholderText =
            "Search controls...",

        PlaceholderColor3 =
            self.Theme.MutedText,

        Text = "",

        TextColor3 =
            self.Theme.Text,

        TextSize = 11,

        Font =
            Enum.Font.Gotham,

        ClearTextOnFocus = false,

        Parent = header
    })

    self.SearchBox = search

    self:_corner(
        search,
        7
    )

    self:_stroke(
        search,
        self.Theme.Border,
        1,
        0.5
    )

    self:_padding(
        search,
        9
    )

    self:_register(
        "SearchChanged",
        search:GetPropertyChangedSignal(
            "Text"
        ):Connect(function()
            self:Search(
                search.Text
            )
        end)
    )

    local searchIcon = create("TextLabel", {
        AnchorPoint =
            Vector2.new(1, 0.5),

        Position =
            UDim2.new(
                1,
                -8,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(18, 18),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamBold,

        Text = "⌕",

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 15,

        Parent = search
    })

    self.SearchIcon = searchIcon

    self:_register(
        "HeaderDrag",
        header.InputBegan:Connect(
            function(input)
                if input.UserInputType
                    == Enum.UserInputType.MouseButton1 then

                    self:_beginDrag(input)
                end
            end
        )
    )

    self:_makeDraggable(header)
end

function Window:_createBody()
    local body = create("Frame", {
        Name = "Body",

        Position =
            UDim2.fromOffset(
                0,
                self.Options.HeaderHeight
            ),

        Size =
            UDim2.new(
                1,
                0,
                1,
                -self.Options.HeaderHeight
            ),

        BackgroundTransparency = 1,

        Parent = self.Main
    })

    self.Body = body

    local sidebar = create("Frame", {
        Name = "Sidebar",

        Size =
            UDim2.new(
                0,
                self.Options.SidebarWidth,
                1,
                0
            ),

        BackgroundColor3 =
            self.Theme.Secondary,

        BorderSizePixel = 0,

        Parent = body
    })

    self.Sidebar = sidebar

    self:_corner(
        sidebar,
        7
    )

    local sidebarLayout = create(
        "UIListLayout",
        {
            Padding =
                UDim.new(
                    0,
                    self.Options.TabSpacing
                ),

            SortOrder =
                Enum.SortOrder.LayoutOrder,

            Parent = sidebar
        }
    )

    self.SidebarLayout = sidebarLayout

    local sidebarPadding = create(
        "UIPadding",
        {
            PaddingTop =
                UDim.new(0, 10),

            PaddingBottom =
                UDim.new(0, 34),

            PaddingLeft =
                UDim.new(0, 8),

            PaddingRight =
                UDim.new(0, 8),

            Parent = sidebar
        }
    )

    self.SidebarPadding = sidebarPadding

    local sidebarLine = create("Frame", {
        AnchorPoint =
            Vector2.new(1, 0),

        Position =
            UDim2.new(1, 0, 0, 0),

        Size =
            UDim2.new(0, 1, 1, 0),

        BackgroundColor3 =
            self.Theme.Border,

        BorderSizePixel = 0,

        Parent = sidebar
    })

    self.SidebarLine = sidebarLine

    local pages = create("Frame", {
        Name = "Pages",

        Position =
            UDim2.fromOffset(
                self.Options.SidebarWidth,
                0
            ),

        Size =
            UDim2.new(
                1,
                -self.Options.SidebarWidth,
                1,
                0
            ),

        BackgroundTransparency = 1,

        Parent = body
    })

    self.PagesContainer = pages

    local footer = create("TextLabel", {
        AnchorPoint =
            Vector2.new(0, 1),

        Position =
            UDim2.new(
                0,
                10,
                1,
                -8
            ),

        Size =
            UDim2.new(
                1,
                -20,
                0,
                18
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.Gotham,

        Text =
            "Lua Test • Ready",

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 8,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = sidebar
    })

    self.Footer = footer
end

function Window:AddTab(name, icon)
    assert(
        type(name) == "string",
        "Tab name must be a string"
    )

    if self.Tabs[name] then
        return self.Tabs[name]
    end

    local order =
        #self._tabOrder + 1

    table.insert(
        self._tabOrder,
        name
    )

    local button = create("TextButton", {
        Name =
            name .. "Button",

        Size =
            UDim2.new(
                1,
                0,
                0,
                self.Options.TabHeight
            ),

        BackgroundColor3 =
            self.Theme.Secondary,

        BorderSizePixel = 0,

        AutoButtonColor = false,

        Text = "",

        LayoutOrder = order,

        Parent = self.Sidebar
    })

    self:_corner(
        button,
        7
    )

    local indicator = create("Frame", {
        AnchorPoint =
            Vector2.new(0, 0.5),

        Position =
            UDim2.new(
                0,
                0,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(3, 18),

        BackgroundColor3 =
            self.Theme.Accent,

        BorderSizePixel = 0,

        Visible = false,

        Parent = button
    })

    self:_corner(
        indicator,
        3
    )

    local iconLabel = create("TextLabel", {
        Position =
            UDim2.fromOffset(12, 0),

        Size =
            UDim2.fromOffset(22, self.Options.TabHeight),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamMedium,

        Text =
            icon or "•",

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 12,

        TextXAlignment =
            Enum.TextXAlignment.Center,

        Parent = button
    })

    local textLabel = create("TextLabel", {
        Position =
            UDim2.fromOffset(39, 0),

        Size =
            UDim2.new(
                1,
                -48,
                1,
                0
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamMedium,

        Text = name,

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 11,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = button
    })

    local page = create("ScrollingFrame", {
        Name =
            name .. "Page",

        Size =
            UDim2.fromScale(1, 1),

        BackgroundTransparency = 1,

        BorderSizePixel = 0,

        ScrollBarThickness = 3,

        ScrollBarImageColor3 =
            self.Theme.Accent,

        AutomaticCanvasSize =
            Enum.AutomaticSize.Y,

        CanvasSize =
            UDim2.new(),

        Visible = false,

        Parent =
            self.PagesContainer
    })

    self:_padding(
        page,
        14
    )

    local layout =
        self:_list(page, 10)

    local tab = {
        Name = name,

        Button = button,
        Page = page,

        Layout = layout,

        Indicator = indicator,

        Icon = iconLabel,
        Label = textLabel,

        Sections = {},

        Order = order
    }

    self.Tabs[name] = tab

    self:_register(
        "Tab_" .. name,
        button.MouseButton1Click:Connect(
            function()
                self:SelectTab(name)
            end
        )
    )

    self:_addHover(
        button,
        self.Theme.Secondary,
        self.Theme.Card
    )

    if not self.CurrentTab then
        self:SelectTab(name)
    end

    return tab
end

function Window:SelectTab(name)
    local selected =
        self.Tabs[name]

    if not selected then
        return false
    end

    self.CurrentTab = name

    for tabName, tab in pairs(self.Tabs) do
        local active =
            tabName == name

        tab.Page.Visible = active
        tab.Indicator.Visible = active

        self:_play(
            tab.Button,
            {
                BackgroundColor3 =
                    active
                    and self.Theme.Accent
                    or self.Theme.Secondary
            }
        )

        self:_play(
            tab.Label,
            {
                TextColor3 =
                    active
                    and Color3.new(1, 1, 1)
                    or self.Theme.MutedText
            }
        )

        self:_play(
            tab.Icon,
            {
                TextColor3 =
                    active
                    and Color3.new(1, 1, 1)
                    or self.Theme.MutedText
            }
        )
    end

    return true
end

function Window:AddSection(
    tabName,
    title,
    description
)
    local tab =
        self.Tabs[tabName]

    assert(
        tab,
        "Tab does not exist: "
            .. tostring(tabName)
    )

    local section = create("Frame", {
        Name =
            title .. "Section",

        Size =
            UDim2.new(
                1,
                0,
                0,
                60
            ),

        AutomaticSize =
            Enum.AutomaticSize.Y,

        BackgroundColor3 =
            self.Theme.Secondary,

        BorderSizePixel = 0,

        Parent =
            tab.Page
    })

    self:_corner(
        section,
        9
    )

    local stroke =
        self:_stroke(
            section,
            self.Theme.Border,
            1,
            0.45
        )

    self:_padding(
        section,
        11
    )

    local titleLabel = create("TextLabel", {
        Size =
            UDim2.new(
                1,
                0,
                0,
                20
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamBold,

        Text = title,

        TextColor3 =
            self.Theme.Text,

        TextSize = 13,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = section
    })

    local descriptionLabel

    if description then
        descriptionLabel =
            create("TextLabel", {
                Position =
                    UDim2.fromOffset(
                        0,
                        21
                    ),

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        18
                    ),

                BackgroundTransparency = 1,

                Font =
                    Enum.Font.Gotham,

                Text = description,

                TextColor3 =
                    self.Theme.MutedText,

                TextSize = 9,

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                Parent = section
            })
    end

    local content = create("Frame", {
        Position =
            UDim2.fromOffset(
                0,
                description
                and 44
                or 26
            ),

        Size =
            UDim2.new(
                1,
                0,
                0,
                0
            ),

        AutomaticSize =
            Enum.AutomaticSize.Y,

        BackgroundTransparency = 1,

        Parent = section
    })

    local layout =
        self:_list(
            content,
            6
        )

    local sectionData = {
        Frame = section,
        Content = content,

        Title = titleLabel,
        Description = descriptionLabel,

        Layout = layout,
        Stroke = stroke,

        Controls = {},

        Name = title,
        Tab = tabName
    }

    table.insert(
        tab.Sections,
        sectionData
    )

    return sectionData
end

function Window:_registerControl(
    control,
    section,
    name,
    description
)
    control.Name = name
    control.Description = description
    control.Section = section
    control.Visible = true

    table.insert(
        self.Controls,
        control
    )

    if section
        and section.Controls then

        table.insert(
            section.Controls,
            control
        )
    end

    return control
end

function Window:AddToggle(
    section,
    name,
    default,
    callback,
    description
)
    local value =
        default == true

    local height =
        description
        and 58
        or 44

    local card =
        self:_card(
            section.Content,
            height
        )

    local label = create("TextLabel", {
        Position =
            UDim2.fromOffset(
                12,
                6
            ),

        Size =
            UDim2.new(
                1,
                -72,
                0,
                20
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamMedium,

        Text = name,

        TextColor3 =
            self.Theme.Text,

        TextSize = 12,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = card
    })

    local descriptionLabel

    if description then
        descriptionLabel =
            create("TextLabel", {
                Position =
                    UDim2.fromOffset(
                        12,
                        27
                    ),

                Size =
                    UDim2.new(
                        1,
                        -72,
                        0,
                        18
                    ),

                BackgroundTransparency = 1,

                Font =
                    Enum.Font.Gotham,

                Text = description,

                TextColor3 =
                    self.Theme.MutedText,

                TextSize = 9,

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                Parent = card
            })
    end

    local switch = create("Frame", {
        AnchorPoint =
            Vector2.new(
                1,
                0.5
            ),

        Position =
            UDim2.new(
                1,
                -12,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(
                36,
                20
            ),

        BackgroundColor3 =
            value
            and self.Theme.Accent
            or self.Theme.Border,

        BorderSizePixel = 0,

        Parent = card
    })

    self:_corner(
        switch,
        10
    )

    local knob = create("Frame", {
        AnchorPoint =
            Vector2.new(
                0,
                0.5
            ),

        Position =
            UDim2.new(
                value and 1 or 0,
                value and -18 or 2,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(
                16,
                16
            ),

        BackgroundColor3 =
            Color3.new(
                1,
                1,
                1
            ),

        BorderSizePixel = 0,

        Parent = switch
    })

    self:_corner(
        knob,
        9
    )

    local button = create("TextButton", {
        Size =
            UDim2.fromScale(
                1,
                1
            ),

        BackgroundTransparency = 1,

        Text = "",

        Parent = card
    })

    local control

    local function update(
        newValue,
        fire
    )
        value =
            newValue == true

        self:_play(
            switch,
            {
                BackgroundColor3 =
                    value
                    and self.Theme.Accent
                    or self.Theme.Border
            }
        )

        self:_play(
            knob,
            {
                Position =
                    UDim2.new(
                        value and 1 or 0,
                        value and -18 or 2,
                        0.5,
                        0
                    )
            }
        )

        if fire ~= false then
            safeCallback(
                callback,
                value
            )
        end
    end

    self:_register(
        "Toggle_" .. name,
        button.MouseButton1Click:Connect(
            function()
                update(
                    not value
                )
            end
        )
    )

    control = {
        Type = "Toggle",

        Get = function()
            return value
        end,

        Set = function(newValue)
            update(newValue)
        end,

        Card = card,
        Button = button,
        Label = label,
        DescriptionLabel =
            descriptionLabel
    }

    return self:_registerControl(
        control,
        section,
        name,
        description
    )
end

function Window:AddButton(
    section,
    name,
    callback
)
    local button =
        self:_button(
            section.Content,
            name
        )

    self:_addHover(
        button,
        self.Theme.Card,
        self.Theme.Secondary
    )

    self:_register(
        "Button_" .. name,
        button.MouseButton1Click:Connect(
            function()
                safeCallback(callback)
            end
        )
    )

    local control = {
        Type = "Button",
        Button = button,
        Card = button
    }

    return self:_registerControl(
        control,
        section,
        name
    )
end

function Window:AddSlider(
    section,
    name,
    minimum,
    maximum,
    default,
    callback
)
    minimum =
        tonumber(minimum)
        or 0

    maximum =
        tonumber(maximum)
        or 100

    default =
        tonumber(default)
        or minimum

    if maximum <= minimum then
        maximum =
            minimum + 1
    end

    local value =
        math.clamp(
            default,
            minimum,
            maximum
        )

    local card =
        self:_card(
            section.Content,
            64
        )

    local label = create("TextLabel", {
        Position =
            UDim2.fromOffset(
                12,
                7
            ),

        Size =
            UDim2.new(
                1,
                -24,
                0,
                18
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamMedium,

        Text = name,

        TextColor3 =
            self.Theme.Text,

        TextSize = 12,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = card
    })

    local valueLabel =
        create("TextLabel", {
            AnchorPoint =
                Vector2.new(
                    1,
                    0
                ),

            Position =
                UDim2.new(
                    1,
                    -12,
                    0,
                    7
                ),

            Size =
                UDim2.fromOffset(
                    70,
                    18
                ),

            BackgroundTransparency = 1,

            Font =
                Enum.Font.GothamMedium,

            TextColor3 =
                self.Theme.Accent,

            TextSize = 11,

            TextXAlignment =
                Enum.TextXAlignment.Right,

            Parent = card
        })

    local bar = create("Frame", {
        Position =
            UDim2.new(
                0,
                12,
                0,
                39
            ),

        Size =
            UDim2.new(
                1,
                -24,
                0,
                6
            ),

        BackgroundColor3 =
            self.Theme.Border,

        BorderSizePixel = 0,

        Parent = card
    })

    self:_corner(
        bar,
        4
    )

    local fill = create("Frame", {
        Size =
            UDim2.new(
                0,
                0,
                1,
                0
            ),

        BackgroundColor3 =
            self.Theme.Accent,

        BorderSizePixel = 0,

        Parent = bar
    })

    self:_corner(
        fill,
        4
    )

    local knob = create("Frame", {
        AnchorPoint =
            Vector2.new(
                0.5,
                0.5
            ),

        Size =
            UDim2.fromOffset(
                12,
                12
            ),

        BackgroundColor3 =
            Color3.new(
                1,
                1,
                1
            ),

        BorderSizePixel = 0,

        Parent = bar
    })

    self:_corner(
        knob,
        7
    )

    local hitbox = create("TextButton", {
        Size =
            UDim2.new(
                1,
                0,
                1,
                20
            ),

        Position =
            UDim2.fromOffset(
                0,
                -10
            ),

        BackgroundTransparency = 1,

        Text = "",

        Parent = bar
    })

    local dragging = false

    local function setValue(
        newValue,
        fire
    )
        value =
            math.clamp(
                tonumber(newValue)
                    or minimum,
                minimum,
                maximum
            )

        local alpha =
            (
                value - minimum
            )
            /
            (
                maximum - minimum
            )

        fill.Size =
            UDim2.new(
                alpha,
                0,
                1,
                0
            )

        knob.Position =
            UDim2.new(
                alpha,
                0,
                0.5,
                0
            )

        valueLabel.Text =
            string.format(
                "%.2f",
                value
            )

        if fire ~= false then
            safeCallback(
                callback,
                value
            )
        end
    end

    local function updateFromInput(
        input
    )
        if bar.AbsoluteSize.X <= 0 then
            return
        end

        local alpha =
            math.clamp(
                (
                    input.Position.X
                    - bar.AbsolutePosition.X
                )
                /
                bar.AbsoluteSize.X,

                0,
                1
            )

        setValue(
            minimum
            +
            (
                maximum - minimum
            )
            * alpha
        )
    end

    setValue(
        value,
        false
    )

    self:_register(
        "SliderDown_" .. name,
        hitbox.MouseButton1Down:Connect(
            function()
                dragging = true
            end
        )
    )

    self:_register(
        "SliderChanged_" .. name,
        UserInputService.InputChanged:Connect(
            function(input)
                if not dragging then
                    return
                end

                if input.UserInputType
                    ==
                    Enum.UserInputType.MouseMovement then

                    updateFromInput(input)
                end
            end
        )
    )

    self:_register(
        "SliderEnd_" .. name,
        UserInputService.InputEnded:Connect(
            function(input)
                if input.UserInputType
                    ==
                    Enum.UserInputType.MouseButton1 then

                    dragging = false
                end
            end
        )
    )

    local control = {
        Type = "Slider",

        Get = function()
            return value
        end,

        Set = function(newValue)
            setValue(
                newValue
            )
        end,

        Card = card,
        Button = hitbox,
        Fill = fill,
        Knob = knob,
        ValueLabel = valueLabel
    }

    return self:_registerControl(
        control,
        section,
        name
    )
end

function Window:AddDropdown(
    section,
    name,
    values,
    default,
    callback
)
    values =
        values or {}

    local current =
        default

    if current == nil then
        current =
            values[1]
    end

    local card =
        self:_card(
            section.Content,
            42
        )

    card.ZIndex = 10

    local button = create("TextButton", {
        Size =
            UDim2.fromScale(
                1,
                1
            ),

        BackgroundTransparency = 1,

        Text = "",

        Parent = card
    })

    button.ZIndex = 11

    local label = create("TextLabel", {
        Position =
            UDim2.fromOffset(
                12,
                0
            ),

        Size =
            UDim2.new(
                1,
                -100,
                1,
                0
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamMedium,

        Text = name,

        TextColor3 =
            self.Theme.Text,

        TextSize = 12,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = button
    })

    local selected = create("TextLabel", {
        AnchorPoint =
            Vector2.new(
                1,
                0.5
            ),

        Position =
            UDim2.new(
                1,
                -30,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(
                110,
                20
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.Gotham,

        Text =
            tostring(
                current
                or "None"
            ),

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 10,

        TextXAlignment =
            Enum.TextXAlignment.Right,

        Parent = button
    })

    local arrow = create("TextLabel", {
        AnchorPoint =
            Vector2.new(
                1,
                0.5
            ),

        Position =
            UDim2.new(
                1,
                -10,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(
                14,
                18
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.GothamBold,

        Text = "›",

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 14,

        Parent = button
    })

    local popup = create("Frame", {
        Position =
            UDim2.new(
                0,
                0,
                1,
                5
            ),

        Size =
            UDim2.new(
                1,
                0,
                0,
                math.min(
                    #values * 32 + 8,
                    170
                )
            ),

        BackgroundColor3 =
            self.Theme.Background,

        BorderSizePixel = 0,

        Visible = false,

        ZIndex = 100,

        Parent = card
    })

    self:_corner(
        popup,
        7
    )

    self:_stroke(
        popup,
        self.Theme.Border,
        1,
        0.1
    )

    self:_padding(
        popup,
        4
    )

    create("UIListLayout", {
        Padding =
            UDim.new(
                0,
                2
            ),

        SortOrder =
            Enum.SortOrder.LayoutOrder,

        Parent = popup
    })

    self:_registerPopup(
        popup
    )

    local open = false

    local function close()
        open = false
        popup.Visible = false
        arrow.Text = "›"
    end

    local function setValue(
        newValue,
        fire
    )
        for _, option in ipairs(values) do
            if option == newValue then
                current = newValue

                selected.Text =
                    tostring(
                        newValue
                    )

                if fire ~= false then
                    safeCallback(
                        callback,
                        newValue
                    )
                end

                return true
            end
        end

        return false
    end

    for index, option in ipairs(values) do
        local optionButton =
            create(
                "TextButton",
                {
                    LayoutOrder =
                        index,

                    Size =
                        UDim2.new(
                            1,
                            0,
                            0,
                            28
                        ),

                    BackgroundColor3 =
                        self.Theme.Background,

                    BorderSizePixel = 0,

                    AutoButtonColor = false,

                    Text =
                        tostring(option),

                    TextColor3 =
                        self.Theme.Text,

                    TextSize = 10,

                    Font =
                        Enum.Font.Gotham,

                    ZIndex = 101,

                    Parent = popup
                }
            )

        self:_corner(
            optionButton,
            5
        )

        self:_register(
            "DropdownHover_" .. name .. index,
            optionButton.MouseEnter:Connect(
                function()
                    optionButton.BackgroundColor3 =
                        self.Theme.Card
                end
            )
        )

        self:_register(
            "DropdownLeave_" .. name .. index,
            optionButton.MouseLeave:Connect(
                function()
                    optionButton.BackgroundColor3 =
                        self.Theme.Background
                end
            )
        )

        self:_register(
            "DropdownOption_" .. name .. index,
            optionButton.MouseButton1Click:Connect(
                function()
                    setValue(
                        option
                    )

                    close()
                end
            )
        )
    end

    self:_register(
        "Dropdown_" .. name,
        button.MouseButton1Click:Connect(
            function()
                open =
                    not open

                if open then
                    self:_closePopups(
                        popup
                    )
                end

                popup.Visible =
                    open

                arrow.Text =
                    open
                    and "⌄"
                    or "›"
            end
        )
    )

    local control = {
        Type = "Dropdown",

        Get = function()
            return current
        end,

        Set = function(value)
            setValue(
                value
            )
        end,

        Card = card,
        Button = button,
        Popup = popup,
        Selected = selected
    }

    return self:_registerControl(
        control,
        section,
        name
    )
end

function Window:AddColorPicker(
    section,
    name,
    default,
    callback
)
    local value =
        typeof(default) == "Color3"
        and default
        or Color3.new(
            1,
            1,
            1
        )

    local card =
        self:_card(
            section.Content,
            42
        )

    local button = create("TextButton", {
        Size =
            UDim2.fromScale(
                1,
                1
            ),

        BackgroundTransparency = 1,

        Text = name,

        TextColor3 =
            self.Theme.Text,

        TextSize = 12,

        Font =
            Enum.Font.GothamMedium,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent = card
    })

    self:_padding(
        button,
        12
    )

    local preview = create("Frame", {
        AnchorPoint =
            Vector2.new(
                1,
                0.5
            ),

        Position =
            UDim2.new(
                1,
                -12,
                0.5,
                0
            ),

        Size =
            UDim2.fromOffset(
                30,
                19
            ),

        BackgroundColor3 =
            value,

        BorderSizePixel = 0,

        Parent = button
    })

    self:_corner(
        preview,
        5
    )

    self:_stroke(
        preview,
        Color3.new(
            1,
            1,
            1
        ),
        1,
        0.5
    )

    local popup = create("Frame", {
        AnchorPoint =
            Vector2.new(
                1,
                1
            ),

        Position =
            UDim2.new(
                1,
                0,
                0,
                -5
            ),

        Size =
            UDim2.fromOffset(
                230,
                170
            ),

        BackgroundColor3 =
            self.Theme.Background,

        BorderSizePixel = 0,

        Visible = false,

        ZIndex = 50,

        Parent = card
    })

    self:_corner(
        popup,
        8
    )

    self:_stroke(
        popup,
        self.Theme.Border,
        1,
        0.1
    )

    self:_registerPopup(
        popup
    )

    local popupTitle = create("TextLabel", {
        Position =
            UDim2.fromOffset(
                12,
                8
            ),

        Size =
            UDim2.new(
                1,
                -24,
                0,
                20
            ),

        BackgroundTransparency = 1,

        Text = name,

        TextColor3 =
            self.Theme.Text,

        TextSize = 11,

        Font =
            Enum.Font.GothamBold,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        ZIndex = 51,

        Parent = popup
    })

    local function colorBox(position, valueText)
        local box = create("TextBox", {
            Position = position,

            Size =
                UDim2.fromOffset(
                    62,
                    28
                ),

            BackgroundColor3 =
                self.Theme.Card,

            BorderSizePixel = 0,

            Text = valueText,

            TextColor3 =
                self.Theme.Text,

            TextSize = 10,

            Font =
                Enum.Font.Gotham,

            ClearTextOnFocus = false,

            ZIndex = 51,

            Parent = popup
        })

        self:_corner(
            box,
            5
        )

        self:_stroke(
            box,
            self.Theme.Border,
            1,
            0.5
        )

        return box
    end

    local red =
        colorBox(
            UDim2.fromOffset(
                12,
                38
            ),
            tostring(
                math.floor(
                    value.R * 255
                )
            )
        )

    local green =
        colorBox(
            UDim2.fromOffset(
                84,
                38
            ),
            tostring(
                math.floor(
                    value.G * 255
                )
            )
        )

    local blue =
        colorBox(
            UDim2.fromOffset(
                156,
                38
            ),
            tostring(
                math.floor(
                    value.B * 255
                )
            )
        )

    local previewLarge = create("Frame", {
        Position =
            UDim2.fromOffset(
                12,
                78
            ),

        Size =
            UDim2.new(
                1,
                -24,
                0,
                30
            ),

        BackgroundColor3 =
            value,

        BorderSizePixel = 0,

        ZIndex = 51,

        Parent = popup
    })

    self:_corner(
        previewLarge,
        6
    )

    local apply = create("TextButton", {
        Position =
            UDim2.fromOffset(
                12,
                118
            ),

        Size =
            UDim2.new(
                1,
                -24,
                0,
                34
            ),

        BackgroundColor3 =
            self.Theme.Accent,

        BorderSizePixel = 0,

        Text = "Apply",

        TextColor3 =
            Color3.new(
                1,
                1,
                1
            ),

        TextSize = 11,

        Font =
            Enum.Font.GothamMedium,

        AutoButtonColor = false,

        ZIndex = 51,

        Parent = popup
    })

    self:_corner(
        apply,
        6
    )

    local function readColor()
        local r =
            math.clamp(
                tonumber(red.Text)
                    or 255,
                0,
                255
            )

        local g =
            math.clamp(
                tonumber(green.Text)
                    or 255,
                0,
                255
            )

        local b =
            math.clamp(
                tonumber(blue.Text)
                    or 255,
                0,
                255
            )

        return Color3.fromRGB(
            r,
            g,
            b
        )
    end

    local function updatePreview()
        previewLarge.BackgroundColor3 =
            readColor()
    end

    self:_register(
        "ColorRed_" .. name,
        red.FocusLost:Connect(
            updatePreview
        )
    )

    self:_register(
        "ColorGreen_" .. name,
        green.FocusLost:Connect(
            updatePreview
        )
    )

    self:_register(
        "ColorBlue_" .. name,
        blue.FocusLost:Connect(
            updatePreview
        )
    )

    self:_register(
        "ColorApply_" .. name,
        apply.MouseButton1Click:Connect(
            function()
                value =
                    readColor()

                preview.BackgroundColor3 =
                    value

                previewLarge.BackgroundColor3 =
                    value

                popup.Visible =
                    false

                safeCallback(
                    callback,
                    value
                )
            end
        )
    )

    self:_register(
        "ColorOpen_" .. name,
        button.MouseButton1Click:Connect(
            function()
                if popup.Visible then
                    popup.Visible = false
                else
                    self:_closePopups(
                        popup
                    )

                    popup.Visible = true
                end
            end
        )
    )

    local control = {
        Type = "ColorPicker",

        Get = function()
            return value
        end,

        Set = function(newValue)
            if typeof(newValue)
                ~= "Color3" then
                return
            end

            value =
                newValue

            preview.BackgroundColor3 =
                value

            previewLarge.BackgroundColor3 =
                value

            red.Text =
                tostring(
                    math.floor(
                        value.R * 255
                    )
                )

            green.Text =
                tostring(
                    math.floor(
                        value.G * 255
                    )
                )

            blue.Text =
                tostring(
                    math.floor(
                        value.B * 255
                    )
                )

            safeCallback(
                callback,
                value
            )
        end,

        Card = card,
        Button = button,
        Popup = popup,
        Preview = preview
    }

    return self:_registerControl(
        control,
        section,
        name
    )
end

function Window:AddKeybind(
    section,
    name,
    default,
    keybinds,
    callback
)
    local current =
        default

    local button =
        self:_button(
            section.Content,
            ""
        )

    local listening =
        false

    local function refresh()
        button.Text =
            name
            .. ": "
            .. (
                current
                and current.Name
                or "None"
            )
    end

    local function stopListening()
        listening = false

        if self._keybindListening
            == name then

            self._keybindListening =
                nil
        end

        refresh()
    end

    refresh()

    self:_register(
        "KeybindButton_" .. name,
        button.MouseButton1Click:Connect(
            function()
                if listening then
                    stopListening()
                    return
                end

                if self._keybindListening then
                    return
                end

                listening = true
                self._keybindListening =
                    name

                button.Text =
                    name
                    .. ": Press key..."

                task.spawn(function()
                    while listening
                        and not self.Destroyed do

                        local input =
                            UserInputService.InputBegan:Wait()

                        if not listening
                            or self.Destroyed then
                            break
                        end

                        if input.UserInputType
                            ~= Enum.UserInputType.Keyboard then
                            continue
                        end

                        if input.KeyCode
                            == Enum.KeyCode.Unknown then
                            continue
                        end

                        current =
                            input.KeyCode

                        stopListening()

                        safeCallback(
                            callback,
                            current
                        )

                        break
                    end
                end)
            end
        )
    )

    local control = {
        Type = "Keybind",

        Get = function()
            return current
        end,

        Set = function(key)
            if key ~= nil
                and typeof(key)
                    ~= "EnumItem" then
                return
            end

            current =
                key

            refresh()

            safeCallback(
                callback,
                key
            )
        end,

        Button = button
    }

    return self:_registerControl(
        control,
        section,
        name
    )
end

function Window:AddLabel(
    section,
    text
)
    local label = create("TextLabel", {
        Size =
            UDim2.new(
                1,
                0,
                0,
                28
            ),

        BackgroundTransparency = 1,

        Font =
            Enum.Font.Gotham,

        Text = text,

        TextColor3 =
            self.Theme.MutedText,

        TextSize = 10,

        TextWrapped = true,

        TextXAlignment =
            Enum.TextXAlignment.Left,

        Parent =
            section.Content
    })

    return label
end

function Window:AddDivider(
    section
)
    local divider = create("Frame", {
        Size =
            UDim2.new(
                1,
                0,
                0,
                1
            ),

        BackgroundColor3 =
            self.Theme.Border,

        BorderSizePixel = 0,

        Parent =
            section.Content
    })

    return divider
end

function Window:Search(query)
    query =
        tostring(
            query or ""
        ):lower()

    self._searchQuery =
        query

    for _, tab in pairs(self.Tabs) do
        local tabMatch =
            query == ""
            or containsText(
                tab.Name,
                query
            )

        local anySectionMatch =
            false

        for _, section in ipairs(
            tab.Sections
        ) do
            local sectionMatch =
                query == ""
            or containsText(
                section.Title.Text,
                query
            )
            or (
                section.Description
                and containsText(
                    section.Description.Text,
                    query
                )
            )

            local anyControlMatch =
                false

            if self.Options.SearchControls
                and query ~= "" then

                for _, control in ipairs(
                    section.Controls
                ) do
                    local matches =
                        containsText(
                            control.Name,
                            query
                        )
                        or containsText(
                            control.Description,
                            query
                        )

                    control.Visible =
                        matches

                    if control.Card then
                        control.Card.Visible =
                            matches
                    elseif control.Button
                        and control.Type
                            ~= "Button" then

                        control.Button.Visible =
                            matches
                    end

                    if matches then
                        anyControlMatch =
                            true
                    end
                end
            else
                for _, control in ipairs(
                    section.Controls
                ) do
                    control.Visible = true

                    if control.Card then
                        control.Card.Visible =
                            true
                    end
                end
            end

            if query == "" then
                sectionMatch = true
            elseif self.Options.SearchControls
                and anyControlMatch then

                sectionMatch = true
            end

            section.Frame.Visible =
                sectionMatch

            if sectionMatch then
                anySectionMatch =
                    true
            end
        end

        if query == "" then
            tab.Button.Visible = true
        else
            tab.Button.Visible =
                tabMatch
                or anySectionMatch
        end
    end

    return true
end

function Window:SetTheme(theme)
    if type(theme) ~= "table" then
        return
    end

    for key, value in pairs(theme) do
        if self.Theme[key] ~= nil then
            self.Theme[key] = value
        end
    end

    if self.Main then
        self.Main.BackgroundColor3 =
            self.Theme.Background
    end

    if self.Header then
        self.Header.BackgroundColor3 =
            self.Theme.Secondary
    end

    if self.Sidebar then
        self.Sidebar.BackgroundColor3 =
            self.Theme.Secondary
    end

    if self.HeaderAccent then
        self.HeaderAccent.BackgroundColor3 =
            self.Theme.Accent
    end

    if self.Title then
        self.Title.TextColor3 =
            self.Theme.Text
    end

    if self.Subtitle then
        self.Subtitle.TextColor3 =
            self.Theme.MutedText
    end

    if self.Footer then
        self.Footer.TextColor3 =
            self.Theme.MutedText
    end

    if self.SearchBox then
        self.SearchBox.BackgroundColor3 =
            self.Theme.Background

        self.SearchBox.TextColor3 =
            self.Theme.Text

        self.SearchBox.PlaceholderColor3 =
            self.Theme.MutedText
    end

    for _, tab in pairs(self.Tabs) do
        tab.Indicator.BackgroundColor3 =
            self.Theme.Accent

        tab.Page.ScrollBarImageColor3 =
            self.Theme.Accent

        tab.Button.BackgroundColor3 =
            tab.Name == self.CurrentTab
            and self.Theme.Accent
            or self.Theme.Secondary

        tab.Label.TextColor3 =
            tab.Name == self.CurrentTab
            and Color3.new(1, 1, 1)
            or self.Theme.MutedText

        tab.Icon.TextColor3 =
            tab.Name == self.CurrentTab
            and Color3.new(1, 1, 1)
            or self.Theme.MutedText

        for _, section in ipairs(
            tab.Sections
        ) do
            section.Frame.BackgroundColor3 =
                self.Theme.Secondary

            if section.Title then
                section.Title.TextColor3 =
                    self.Theme.Text
            end

            if section.Description then
                section.Description.TextColor3 =
                    self.Theme.MutedText
            end

            for _, control in ipairs(
                section.Controls
            ) do
                if control.Label then
                    control.Label.TextColor3 =
                        self.Theme.Text
                end

                if control.ValueLabel then
                    control.ValueLabel.TextColor3 =
                        self.Theme.Accent
                end

                if control.Fill then
                    control.Fill.BackgroundColor3 =
                        self.Theme.Accent
                end
            end
        end
    end
end

function Window:SetAccent(color)
    if typeof(color)
        ~= "Color3" then
        return
    end

    self.Theme.Accent =
        color

    if self.HeaderAccent then
        self.HeaderAccent.BackgroundColor3 =
            color
    end

    for _, tab in pairs(
        self.Tabs
    ) do
        tab.Indicator.BackgroundColor3 =
            color

        tab.Page.ScrollBarImageColor3 =
            color

        if tab.Name ==
            self.CurrentTab then

            tab.Button.BackgroundColor3 =
                color
        end
    end

    for _, control in ipairs(
        self.Controls
    ) do
        if control.Type ==
            "Slider" then

            if control.Fill then
                control.Fill.BackgroundColor3 =
                    color
            end

            if control.ValueLabel then
                control.ValueLabel.TextColor3 =
                    color
            end
        end
    end
end

function Window:SetTitle(
    title,
    subtitle
)
    if self.Title then
        self.Title.Text =
            tostring(
                title
                or "Lua Test"
            )
    end

    if self.Subtitle then
        self.Subtitle.Text =
            tostring(
                subtitle
                or "Advanced Control Panel"
            )
    end
end

function Window:SetVisible(
    visible,
    animate
)
    if not self.Gui
        or not self.Main then
        return
    end

    animate =
        animate ~= false

    self.Visible =
        visible == true

    if self.Visible then
        self.Minimized = false

        self.Main.Visible = true

        if not animate
            or not self.Options.EnableAnimations then

            self.Main.Size =
                self.Options.Size

            return
        end

        local originalSize =
            self.Options.Size

        self.Main.Size =
            UDim2.fromOffset(
                originalSize.X.Offset * 0.96,
                originalSize.Y.Offset * 0.96
            )

        self:_play(
            self.Main,
            {
                Size =
                    originalSize
            }
        )
    else
        if not animate
            or not self.Options.EnableAnimations then

            self.Main.Visible =
                false

            return
        end

        self:_play(
            self.Main,
            {
                Size =
                    UDim2.fromOffset(
                        self.Options.Size.X.Offset
                            * 0.96,

                        self.Options.Size.Y.Offset
                            * 0.96
                    )
            }
        )

        task.delay(
            self.Options.AnimationTime,
            function()
                if self.Main
                    and not self.Destroyed
                    and not self.Visible then

                    self.Main.Visible =
                        false

                    self.Main.Size =
                        self.Options.Size
                end
            end
        )
    end
end

function Window:Toggle()
    self:SetVisible(
        not self.Visible
    )
end

function Window:IsVisible()
    return self.Visible
end

function Window:_beginDrag(input)
    self._dragging =
        true

    self._dragStart =
        input.Position

    self._startPosition =
        self.Main.Position
end

function Window:_makeDraggable(handle)
    self:_register(
        "DragChanged",
        UserInputService.InputChanged:Connect(
            function(input)
                if not self._dragging
                    or self.Destroyed then
                    return
                end

                if input.UserInputType
                    ~=
                    Enum.UserInputType.MouseMovement then
                    return
                end

                local delta =
                    input.Position
                    - self._dragStart

                local start =
                    self._startPosition

                local x =
                    start.X.Offset
                    + delta.X

                local y =
                    start.Y.Offset
                    + delta.Y

                if self.Options.ClampToScreen
                    and self.Gui then

                    local viewport =
                        self.Gui.AbsoluteSize

                    local size =
                        self.Main.AbsoluteSize

                    local halfX =
                        size.X / 2

                    local halfY =
                        size.Y / 2

                    x =
                        math.clamp(
                            x,
                            -viewport.X / 2
                                + halfX,
                            viewport.X / 2
                                - halfX
                        )

                    y =
                        math.clamp(
                            y,
                            -viewport.Y / 2
                                + halfY,
                            viewport.Y / 2
                                - halfY
                        )
                end

                self.Main.Position =
                    UDim2.new(
                        start.X.Scale,
                        x,
                        start.Y.Scale,
                        y
                    )
            end
        )
    )

    self:_register(
        "DragEnded",
        UserInputService.InputEnded:Connect(
            function(input)
                if input.UserInputType
                    ==
                    Enum.UserInputType.MouseButton1 then

                    self._dragging =
                        false
                end
            end
        )
    )
end

function Window:GetTab(name)
    return self.Tabs[name]
end

function Window:GetControl(index)
    return self.Controls[index]
end

function Window:GetControls()
    return self.Controls
end

function Window:Notify(
    title,
    message
)
    if not self.Notifications then
        return
    end

    if self.Notifications.Info
        and title then

        self.Notifications:Info(
            title,
            message
        )

        return
    end

    if self.Notifications.Show then
        self.Notifications:Show(
            tostring(
                message
                or title
            )
        )
    end
end

function Window:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed =
        true

    self.Visible =
        false

    self._dragging =
        false

    self._keybindListening =
        nil

    self:_closePopups()

    self:_disconnectAll()

    if self.Gui then
        self.Gui:Destroy()
    end

    self.Gui = nil
    self.Main = nil
    self.Header = nil
    self.Body = nil
    self.Sidebar = nil
    self.PagesContainer = nil
    self.SearchBox = nil

    self.Title = nil
    self.Subtitle = nil
    self.Footer = nil

    self.Tabs = {}
    self.Controls = {}

    self._tabOrder = {}
    self._popups = {}

    self.CurrentTab =
        nil
end

return Window