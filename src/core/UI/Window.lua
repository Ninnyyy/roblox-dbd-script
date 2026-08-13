--[[
    Lua Test
    Window.lua

    Complete UI Window System

    Version:
        4.0.0

    Responsibilities:
        - Main window creation
        - Centered window positioning
        - Square / rectangular UI design
        - Tab navigation
        - Feature organization
        - Search
        - Sections
        - Toggles
        - Buttons
        - Sliders
        - Dropdowns
        - Status labels
        - Feature callbacks
        - Window dragging
        - Window minimizing
        - Window closing
        - Keyboard toggle
        - Theme integration
        - Components.lua integration
        - Runtime UI refresh
        - Cleanup

    Tabs:
        - Player
        - Killer
        - Visuals
        - Movement
        - Misc

    IMPORTANT:

        Window.lua owns the UI.

        Feature modules own feature behavior.

        This module does NOT directly implement gameplay behavior.

        Feature callbacks can be connected to:
            FeatureManager
            FeatureRegistry
            individual feature modules

        Existing Components.lua APIs are preserved.
]]




-- SERVICES


local Players =
    game:GetService("Players")

local UserInputService =
    game:GetService("UserInputService")

local TweenService =
    game:GetService("TweenService")




-- PLAYER


local LocalPlayer =
    Players.LocalPlayer




-- MODULE


local Window = {}

Window.__index = Window




-- DEFAULTS


local DEFAULTS = {

    Name = "LuaTest",

    Title = "Lua Test",

    Subtitle = "Feature Control",

    Width = 860,

    Height = 560,

    MinWidth = 680,

    MinHeight = 440,

    TabWidth = 150,

    HeaderHeight = 58,

    FooterHeight = 28,

    SearchHeight = 36,

    SectionSpacing = 10,

    FeatureHeight = 46,

    SliderHeight = 54,

    DropdownHeight = 46,

    AnimationTime = 0.16,

    ToggleKey = Enum.KeyCode.RightShift,

    StartOpen = true,

    CenterOnOpen = true,

    Draggable = true,

    ShowSearch = true,

    ShowFooter = true,

    EnableAnimations = true,

    SquareCorners = true,

    CornerRadius = 0,

    BorderThickness = 1,

    BackgroundTransparency = 0,

    Parent = nil,

    TitleText = "Singularity-Ninny.top",

    SubtitleText = "FEATURE CONTROL",

}




-- UTILITIES


local function copyTable(source)

    local result = {}

    for key, value in pairs(source or {}) do

        if type(value) == "table" then
            result[key] = copyTable(value)
        else
            result[key] = value
        end

    end

    return result
end


local function mergeTables(target, source)

    if type(source) ~= "table" then
        return target
    end

    for key, value in pairs(source) do

        if type(value) == "table"
            and type(target[key]) == "table" then

            mergeTables(
                target[key],
                value
            )

        else

            target[key] = value

        end

    end

    return target
end


local function safeCall(callback, ...)

    if type(callback) ~= "function" then
        return
    end

    local arguments = table.pack(...)

    task.spawn(function()

        pcall(function()

            callback(
                table.unpack(
                    arguments,
                    1,
                    arguments.n
                )
            )

        end)

    end)

end


local function isGuiObject(object)

    return object
        and object:IsA("GuiObject")
end




-- CONSTRUCTOR


function Window.new(options)

    options =
        options
        or {}

    local self =
        setmetatable(
            {},
            Window
        )

    self.Options =
        copyTable(DEFAULTS)

    mergeTables(
        self.Options,
        options
    )

    self.Components =
        options.Components

    self.Themes =
        options.Themes
        or options.ThemeManager
        or options.ThemeProvider

    self.FeatureManager =
        options.FeatureManager

    self.FeatureRegistry =
        options.FeatureRegistry

    self.Parent =
        options.Parent

    self.Destroyed = false

    self.Opened =
        self.Options.StartOpen ~= false

    self.Minimized = false

    self.ActiveTab = nil

    self.Tabs = {}

    self.TabOrder = {}

    self.Sections = {}

    self.Controls = {}

    self.Connections = {}

    self.Objects = {}

    self.FeatureRecords = {}

    self.SearchQuery = ""

    self.ConfigState = {}
    self.ConfigKey = options.ConfigKey or "LuaTestConfig"
    self.Profiles = options.Profiles
    self.Debug = options.Debug
    self.Commands = options.Commands

    self._dragging = false

    self._dragStart = nil

    self._windowStart = nil

    self:_build()

    self:_bindInput()

    self:_center()

    if self.Opened then
        self:Open(false)
    else
        self:Close(false)
    end

    return self
end




-- COMPONENT HELPERS


function Window:_component()

    return self.Components
end


function Window:_track(connection)

    if connection then

        table.insert(
            self.Connections,
            connection
        )

    end

    return connection
end


function Window:_trackObject(object)

    if object then

        table.insert(
            self.Objects,
            object
        )

    end

    return object
end


function Window:_create(className, properties)

    local Components =
        self:_component()

    if Components
        and Components.Create then

        return self:_trackObject(
            Components:Create(
                className,
                properties
            )
        )

    end

    local success, object =
        pcall(
            Instance.new,
            className
        )

    if not success then
        return nil
    end

    for property, value in pairs(
        properties or {}
    ) do

        pcall(function()

            object[property] =
                value

        end)

    end

    return self:_trackObject(object)
end


function Window:_frame(parent, properties)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    local Components =
        self:_component()

    if Components
        and Components.Frame then

        return Components:Frame(
            parent,
            properties
        )

    end

    return self:_create(
        "Frame",
        properties
    )
end


function Window:_label(parent, properties)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    local Components =
        self:_component()

    if Components
        and Components.TextLabel then

        return Components:TextLabel(
            parent,
            properties
        )

    end

    return self:_create(
        "TextLabel",
        properties
    )
end


function Window:_button(parent, properties)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    local Components =
        self:_component()

    if Components
        and Components.TextButton then

        return Components:TextButton(
            parent,
            properties
        )

    end

    return self:_create(
        "TextButton",
        properties
    )
end


function Window:_scroll(parent, properties)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    local Components =
        self:_component()

    if Components
        and Components.ScrollingFrame then

        return Components:ScrollingFrame(
            parent,
            properties
        )

    end

    return self:_create(
        "ScrollingFrame",
        properties
    )
end




-- THEME HELPERS


function Window:_color(name, fallback)

    local Components =
        self:_component()

    if Components
        and Components.GetColor then

        local value =
            Components:GetColor(
                name,
                fallback
            )

        if value ~= nil then
            return value
        end

    end

    return fallback
end


function Window:_font(name, fallback)

    local Components =
        self:_component()

    if Components
        and Components.GetFont then

        return Components:GetFont(
            name,
            fallback
        )

    end

    return fallback
end


function Window:_tween(
    object,
    properties,
    duration
)

    if not object then
        return
    end

    local Components =
        self:_component()

    if Components
        and Components.Tween then

        return Components:Tween(
            object,
            properties,
            duration
        )

    end

    local success, tween =
        pcall(function()

            return TweenService:Create(
                object,
                TweenInfo.new(
                    duration
                        or self.Options.AnimationTime,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),
                properties
            )

        end)

    if success and tween then

        tween:Play()

        return tween

    end

end




-- COLORS


function Window:_background()

    return self:_color(
        "Background",
        Color3.fromRGB(
            15,
            15,
            18
        )
    )

end


function Window:_secondary()

    return self:_color(
        "Secondary",
        Color3.fromRGB(
            20,
            20,
            24
        )
    )

end


function Window:_surface()

    return self:_color(
        "Card",
        Color3.fromRGB(
            25,
            25,
            30
        )
    )

end


function Window:_hover()

    return self:_color(
        "Hover",
        Color3.fromRGB(
            34,
            34,
            40
        )
    )

end


function Window:_accent()

    return self:_color(
        "Accent",
        Color3.fromRGB(
            90,
            120,
            255
        )
    )

end


function Window:_text()

    return self:_color(
        "Text",
        Color3.fromRGB(
            240,
            240,
            245
        )
    )

end


function Window:_muted()

    return self:_color(
        "MutedText",
        Color3.fromRGB(
            145,
            145,
            155
        )
    )

end


function Window:_border()

    return self:_color(
        "Border",
        Color3.fromRGB(
            48,
            48,
            56
        )
    )

end


function Window:_danger()

    return self:_color(
        "Danger",
        Color3.fromRGB(
            220,
            75,
            75
        )
    )

end




-- CORNER


function Window:_square(object, radius)

    if not object then
        return
    end

    local Components =
        self:_component()

    if Components
        and Components.Corner then

        return Components:Corner(
            object,
            radius
            or self.Options.CornerRadius
        )

    end

    local corner =
        self:_create(
            "UICorner",
            {
                Parent = object,

                CornerRadius =
                    UDim.new(
                        0,
                        radius
                        or self.Options.CornerRadius
                    )
            }
        )

    return corner
end




-- STROKE


function Window:_stroke(
    object,
    color,
    thickness,
    transparency
)

    if not object then
        return
    end

    local Components =
        self:_component()

    if Components
        and Components.Stroke then

        return Components:Stroke(
            object,
            color
                or self:_border(),
            thickness
                or self.Options.BorderThickness,
            transparency
                or 0
        )

    end

    return self:_create(
        "UIStroke",
        {
            Parent = object,

            Color =
                color
                or self:_border(),

            Thickness =
                thickness
                or self.Options.BorderThickness,

            Transparency =
                transparency
                or 0
        }
    )
end




-- MAIN BUILD


function Window:_build()

    local parent =
        self.Parent

    if not parent then

        parent =
            LocalPlayer:WaitForChild(
                "PlayerGui"
            )

    end

    self.Parent =
        parent

    self.ScreenGui =
        self:_create(
            "ScreenGui",
            {
                Name =
                    self.Options.Name,

                ResetOnSpawn =
                    false,

                IgnoreGuiInset =
                    true,

                ZIndexBehavior =
                    Enum.ZIndexBehavior.Sibling,

                DisplayOrder =
                    100
            }
        )

    if not self.ScreenGui then
        return
    end

    self.Main =
        self:_frame(
            self.ScreenGui,
            {
                Name =
                    "Window",

                AnchorPoint =
                    Vector2.new(
                        0.5,
                        0.5
                    ),

                Position =
                    UDim2.fromScale(
                        0.5,
                        0.5
                    ),

                Size =
                    UDim2.fromOffset(
                        self.Options.Width,
                        self.Options.Height
                    ),

                BackgroundColor3 =
                    self:_background(),

                BackgroundTransparency =
                    self.Options.BackgroundTransparency,

                BorderSizePixel =
                    0,

                ClipsDescendants =
                    true,

                Active =
                    true,

                Selectable =
                    true
            }
        )

    if not self.Main then
        return
    end

    -- Intentionally square.

    if self.Options.SquareCorners then

        self:_square(
            self.Main,
            self.Options.CornerRadius
        )

    end

    self:_stroke(
        self.Main,
        self:_border(),
        self.Options.BorderThickness,
        0
    )

    self:_buildHeader()

    self:_buildNavigation()

    self:_buildContent()

    self:_buildFooter()

end




-- HEADER


function Window:_buildHeader()

    self.Header =
        self:_frame(
            self.Main,
            {
                Name =
                    "Header",

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.HeaderHeight
                    ),

                Position =
                    UDim2.fromOffset(
                        0,
                        0
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0,

                ZIndex =
                    10
            }
        )

    self:_stroke(
        self.Header,
        self:_border(),
        1,
        0
    )

    self.Title =
        self:_label(
            self.Header,
            {
                Name =
                    "Title",

                Position =
                    UDim2.fromOffset(
                        18,
                        8
                    ),

                Size =
                    UDim2.new(
                        1,
                        -130,
                        0,
                        23
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    self.Options.TitleText,

                TextColor3 =
                    self:_text(),

                TextSize =
                    16,

                Font =
                    self:_font(
                        "Title",
                        Enum.Font.GothamBold
                    ),

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                TextYAlignment =
                    Enum.TextYAlignment.Center,

                ZIndex =
                    11
            }
        )

    self.Subtitle =
        self:_label(
            self.Header,
            {
                Name =
                    "Subtitle",

                Position =
                    UDim2.fromOffset(
                        18,
                        30
                    ),

                Size =
                    UDim2.new(
                        1,
                        -130,
                        0,
                        16
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    self.Options.SubtitleText,

                TextColor3 =
                    self:_muted(),

                TextSize =
                    9,

                Font =
                    self:_font(
                        "Small",
                        Enum.Font.Gotham
                    ),

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                ZIndex =
                    11
            }
        )


    -- MINIMIZE

    self.MinimizeButton =
        self:_button(
            self.Header,
            {
                Name =
                    "Minimize",

                AnchorPoint =
                    Vector2.new(
                        1,
                        0
                    ),

                Position =
                    UDim2.new(
                        1,
                        -48,
                        0,
                        12
                    ),

                Size =
                    UDim2.fromOffset(
                        30,
                        30
                    ),

                BackgroundColor3 =
                    self:_surface(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    "—",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    15,

                Font =
                    Enum.Font.GothamBold,

                ZIndex =
                    12
            }
        )

    self:_square(
        self.MinimizeButton,
        0
    )

    self:_track(
        self.MinimizeButton.MouseButton1Click:Connect(
            function()

                self:ToggleMinimize()

            end
        )
    )


    -- CLOSE

    self.CloseButton =
        self:_button(
            self.Header,
            {
                Name =
                    "Close",

                AnchorPoint =
                    Vector2.new(
                        1,
                        0
                    ),

                Position =
                    UDim2.new(
                        1,
                        -10,
                        0,
                        12
                    ),

                Size =
                    UDim2.fromOffset(
                        30,
                        30
                    ),

                BackgroundColor3 =
                    self:_surface(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    "×",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    18,

                Font =
                    Enum.Font.GothamBold,

                ZIndex =
                    12
            }
        )

    self:_square(
        self.CloseButton,
        0
    )

    self:_track(
        self.CloseButton.MouseButton1Click:Connect(
            function()

                self:Close()

            end
        )
    )


    -- HOVER

    self:_buttonHover(
        self.MinimizeButton
    )

    self:_buttonHover(
        self.CloseButton,
        self:_danger()
    )

end




-- NAVIGATION


function Window:_buildNavigation()

    local navigationTop =
        self.Options.HeaderHeight

    self.Navigation =
        self:_frame(
            self.Main,
            {
                Name =
                    "Navigation",

                Position =
                    UDim2.fromOffset(
                        0,
                        navigationTop
                    ),

                Size =
                    UDim2.new(
                        0,
                        self.Options.TabWidth,
                        1,
                        -navigationTop
                        - self.Options.FooterHeight
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0
            }
        )

    self:_stroke(
        self.Navigation,
        self:_border(),
        1,
        0
    )


    self.TabList =
        self:_scroll(
            self.Navigation,
            {
                Name =
                    "TabList",

                Position =
                    UDim2.fromOffset(
                        8,
                        8
                    ),

                Size =
                    UDim2.new(
                        1,
                        -16,
                        1,
                        -16
                    ),

                BackgroundTransparency =
                    1,

                BorderSizePixel =
                    0,

                ScrollBarThickness =
                    2,

                ScrollBarImageColor3 =
                    self:_border(),

                CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        0
                    )
            }
        )

    self.TabLayout =
        self:_create(
            "UIListLayout",
            {
                Parent =
                    self.TabList,

                FillDirection =
                    Enum.FillDirection.Vertical,

                Padding =
                    UDim.new(
                        0,
                        5
                    ),

                SortOrder =
                    Enum.SortOrder.LayoutOrder
            }
        )

    self:_create(
        "UIPadding",
        {
            Parent =
                self.TabList,

            PaddingTop =
                UDim.new(
                    0,
                    4
                )
        }
    )


    self:_createDefaultTabs()

end




-- DEFAULT TABS


function Window:_createDefaultTabs()

    self:AddTab(
        "Visuals",
        {
            Icon = "V",
            Order = 1
        }
    )

    self:AddTab(
        "Survivor",
        {
            Icon = "S",
            Order = 2
        }
    )

    self:AddTab(
        "Killer",
        {
            Icon = "K",
            Order = 3
        }
    )

    self:AddTab(
        "Movement",
        {
            Icon = "M",
            Order = 4
        }
    )

    self:AddTab(
        "Camera",
        {
            Icon = "C",
            Order = 5
        }
    )

    self:AddTab(
        "Environment",
        {
            Icon = "E",
            Order = 6
        }
    )

    self:AddTab(
        "Developer",
        {
            Icon = "D",
            Order = 7
        }
    )

    self:AddTab(
        "Misc",
        {
            Icon = "X",
            Order = 8
        }
    )

end




-- CONTENT


function Window:_buildContent()

    local contentX =
        self.Options.TabWidth

    local contentY =
        self.Options.HeaderHeight

    local contentWidth =
        -self.Options.TabWidth

    local contentHeight =
        -self.Options.HeaderHeight
        - self.Options.FooterHeight

    self.Content =
        self:_frame(
            self.Main,
            {
                Name =
                    "Content",

                Position =
                    UDim2.fromOffset(
                        contentX,
                        contentY
                    ),

                Size =
                    UDim2.new(
                        1,
                        contentWidth,
                        1,
                        contentHeight
                    ),

                BackgroundColor3 =
                    self:_background(),

                BorderSizePixel =
                    0
            }
        )


    -- SEARCH

    if self.Options.ShowSearch then

        self:_buildSearch()

    end


    self.PageContainer =
        self:_frame(
            self.Content,
            {
                Name =
                    "PageContainer",

                Position =
                    UDim2.fromOffset(
                        0,
                        self.Options.ShowSearch
                            and self.Options.SearchHeight
                            or 0
                    ),

                Size =
                    UDim2.new(
                        1,
                        0,
                        1,
                        self.Options.ShowSearch
                            and -self.Options.SearchHeight
                            or 0
                    ),

                BackgroundTransparency =
                    1,

                BorderSizePixel =
                    0,

                ClipsDescendants =
                    true
            }
        )

end




-- SEARCH


function Window:_buildSearch()

    self.Search =
        self:_button(
            self.Content,
            {
                Name =
                    "Search",

                Position =
                    UDim2.fromOffset(
                        10,
                        8
                    ),

                Size =
                    UDim2.new(
                        1,
                        -20,
                        0,
                        self.Options.SearchHeight
                        - 12
                    ),

                BackgroundColor3 =
                    self:_surface(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    "Search features...",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    11,

                Font =
                    Enum.Font.Gotham,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )

    self:_square(
        self.Search,
        0
    )

    self:_stroke(
        self.Search,
        self:_border(),
        1,
        0
    )

    self:_create(
        "UIPadding",
        {
            Parent =
                self.Search,

            PaddingLeft =
                UDim.new(
                    0,
                    12
                )
        }
    )


    self:_track(
        self.Search.MouseButton1Click:Connect(
            function()

                self:_beginSearch()

            end
        )
    )

end




-- SEARCH BOX


function Window:_beginSearch()

    if self.SearchBox then
        return
    end

    local old =
        self.Search

    if old then
        old.Visible = false
    end

    self.SearchBox =
        self:_create(
            "TextBox",
            {
                Parent =
                    self.Content,

                Name =
                    "SearchBox",

                Position =
                    UDim2.fromOffset(
                        10,
                        8
                    ),

                Size =
                    UDim2.new(
                        1,
                        -20,
                        0,
                        self.Options.SearchHeight
                        - 12
                    ),

                BackgroundColor3 =
                    self:_surface(),

                BorderSizePixel =
                    0,

                ClearTextOnFocus =
                    false,

                PlaceholderText =
                    "Search features...",

                PlaceholderColor3 =
                    self:_muted(),

                Text =
                    self.SearchQuery,

                TextColor3 =
                    self:_text(),

                TextSize =
                    11,

                Font =
                    Enum.Font.Gotham,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )

    self:_square(
        self.SearchBox,
        0
    )

    self:_stroke(
        self.SearchBox,
        self:_border(),
        1,
        0
    )

    self:_create(
        "UIPadding",
        {
            Parent =
                self.SearchBox,

            PaddingLeft =
                UDim.new(
                    0,
                    12
                ),

            PaddingRight =
                UDim.new(
                    0,
                    12
                )
        }
    )


    self:_track(
        self.SearchBox:GetPropertyChangedSignal(
            "Text"
        ):Connect(
            function()

                self.SearchQuery =
                    self.SearchBox.Text

                self:_refreshSearch()

            end
        )
    )


    self:_track(
        self.SearchBox.FocusLost:Connect(
            function()

                if self.SearchQuery == "" then

                    self.SearchBox:Destroy()

                    self.SearchBox =
                        nil

                    if self.Search then
                        self.Search.Visible =
                            true
                    end

                end

            end
        )
    )

    self.SearchBox:CaptureFocus()

end




-- SEARCH FILTER


function Window:_refreshSearch()

    local query =
        string.lower(
            self.SearchQuery
                or ""
        )

    for _, record in ipairs(
        self.Controls
    ) do

        if record
            and record.Object
            and record.Name then

            local matches =
                query == ""

            if not matches then

                matches =
                    string.find(
                        string.lower(
                            record.Name
                        ),
                        query,
                        1,
                        true
                    )
                    ~= nil

            end

            if record.Description
                and not matches then

                matches =
                    string.find(
                        string.lower(
                            record.Description
                        ),
                        query,
                        1,
                        true
                    )
                    ~= nil

            end

            record.Object.Visible =
                matches

        end

    end

end




-- FOOTER


function Window:_buildFooter()

    self.Footer =
        self:_frame(
            self.Main,
            {
                Name =
                    "Footer",

                AnchorPoint =
                    Vector2.new(
                        0,
                        1
                    ),

                Position =
                    UDim2.new(
                        0,
                        0,
                        1,
                        0
                    ),

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.FooterHeight
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0
            }
        )

    self.Status =
        self:_label(
            self.Footer,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        0
                    ),

                Size =
                    UDim2.new(
                        0.5,
                        -10,
                        1,
                        0
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    "READY",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    8,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                TextYAlignment =
                    Enum.TextYAlignment.Center
            }
        )


    self.HotkeyLabel =
        self:_label(
            self.Footer,
            {
                AnchorPoint =
                    Vector2.new(
                        1,
                        0
                    ),

                Position =
                    UDim2.new(
                        1,
                        -10,
                        0,
                        0
                    ),

                Size =
                    UDim2.new(
                        0.5,
                        -10,
                        1,
                        0
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    "RIGHT SHIFT  •  TOGGLE",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    8,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Right,

                TextYAlignment =
                    Enum.TextYAlignment.Center
            }
        )

end




-- BUTTON HOVER


function Window:_buttonHover(
    button,
    hoverColor
)

    if not button then
        return
    end

    local normal =
        button.BackgroundColor3

    hoverColor =
        hoverColor
        or self:_hover()

    self:_track(
        button.MouseEnter:Connect(
            function()

                self:_tween(
                    button,
                    {
                        BackgroundColor3 =
                            hoverColor
                    },
                    0.10
                )

            end
        )
    )

    self:_track(
        button.MouseLeave:Connect(
            function()

                self:_tween(
                    button,
                    {
                        BackgroundColor3 =
                            normal
                    },
                    0.10
                )

            end
        )
    )

end




-- TAB RESET


function Window:ClearTabs()
    self.Tabs = {}
    self.TabOrder = {}
    self.Sections = {}
    self.Controls = {}
    self.FeatureRecords = {}

    if self.TabList then
        for _, child in ipairs(self.TabList:GetChildren()) do
            if child ~= self.TabLayout then
                pcall(function()
                    child:Destroy()
                end)
            end
        end
    end

    if self.PageContainer then
        for _, child in ipairs(self.PageContainer:GetChildren()) do
            pcall(function()
                child:Destroy()
            end)
        end
    end
end


-- TAB CREATION


function Window:AddTab(
    name,
    options
)

    options =
        options
        or {}

    if self.Tabs[name] then
        return self.Tabs[name]
    end

    local tab =
        {}

    tab.Name =
        name

    tab.Icon =
        options.Icon
        or string.sub(
            name,
            1,
            1
        )

    tab.Order =
        options.Order
        or (#self.TabOrder + 1)

    tab.Sections = {}

    tab.Controls = {}

    tab.Button =
        self:_button(
            self.TabList,
            {
                Name =
                    name .. "Tab",

                Size =
                    UDim2.new(
                        1,
                        -4,
                        0,
                        42
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    "",

                LayoutOrder =
                    tab.Order
            }
        )

    self:_square(
        tab.Button,
        0
    )


    tab.IconLabel =
        self:_label(
            tab.Button,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        0
                    ),

                Size =
                    UDim2.fromOffset(
                        24,
                        42
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    tab.Icon,

                TextColor3 =
                    self:_muted(),

                TextSize =
                    11,

                Font =
                    Enum.Font.GothamBold,

                TextXAlignment =
                    Enum.TextXAlignment.Center,

                TextYAlignment =
                    Enum.TextYAlignment.Center
            }
        )


    tab.TextLabel =
        self:_label(
            tab.Button,
            {
                Position =
                    UDim2.fromOffset(
                        42,
                        0
                    ),

                Size =
                    UDim2.new(
                        1,
                        -50,
                        1,
                        0
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    name,

                TextColor3 =
                    self:_muted(),

                TextSize =
                    11,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                TextYAlignment =
                    Enum.TextYAlignment.Center
            }
        )


    tab.Page =
        self:_scroll(
            self.PageContainer,
            {
                Name =
                    name .. "Page",

                Size =
                    UDim2.fromScale(
                        1,
                        1
                    ),

                BackgroundTransparency =
                    1,

                BorderSizePixel =
                    0,

                Visible =
                    false,

                ScrollBarThickness =
                    3,

                ScrollBarImageColor3 =
                    self:_border(),

                CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        0
                    )
            }
        )


    tab.Padding =
        self:_create(
            "UIPadding",
            {
                Parent =
                    tab.Page,

                PaddingTop =
                    UDim.new(
                        0,
                        12
                    ),

                PaddingBottom =
                    UDim.new(
                        0,
                        12
                    ),

                PaddingLeft =
                    UDim.new(
                        0,
                        12
                    ),

                PaddingRight =
                    UDim.new(
                        0,
                        12
                    )
            }
        )


    tab.Layout =
        self:_create(
            "UIListLayout",
            {
                Parent =
                    tab.Page,

                FillDirection =
                    Enum.FillDirection.Vertical,

                Padding =
                    UDim.new(
                        0,
                        self.Options.SectionSpacing
                    ),

                SortOrder =
                    Enum.SortOrder.LayoutOrder
            }
        )


    self:_track(
        tab.Layout:GetPropertyChangedSignal(
            "AbsoluteContentSize"
        ):Connect(
            function()

                tab.Page.CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        tab.Layout
                            .AbsoluteContentSize
                            .Y
                            + 30
                    )

            end
        )
    )


    self:_track(
        tab.Button.MouseButton1Click:Connect(
            function()

                self:SelectTab(
                    name
                )

            end
        )
    )


    self:_buttonHover(
        tab.Button
    )


    self.Tabs[name] =
        tab

    table.insert(
        self.TabOrder,
        name
    )


    if not self.ActiveTab then

        self:SelectTab(
            name,
            false
        )

    end

    return tab
end




-- SELECT TAB


function Window:SelectTab(
    name,
    animate
)

    local tab =
        self.Tabs[name]

    if not tab then
        return false
    end

    self.ActiveTab =
        name

    for tabName, other in pairs(
        self.Tabs
    ) do

        local selected =
            tabName == name

        other.Page.Visible =
            selected

        if selected then

            other.Button.BackgroundColor3 =
                self:_surface()

            other.IconLabel.TextColor3 =
                self:_accent()

            other.TextLabel.TextColor3 =
                self:_text()

        else

            other.Button.BackgroundColor3 =
                self:_secondary()

            other.IconLabel.TextColor3 =
                self:_muted()

            other.TextLabel.TextColor3 =
                self:_muted()

        end

    end

    return true
end




-- SECTION


function Window:AddSection(
    tabName,
    name,
    options
)

    options =
        options
        or {}

    local tab =
        self.Tabs[tabName]

    if not tab then

        tab =
            self:AddTab(
                tabName
            )

    end


    local section =
        self:_frame(
            tab.Page,
            {
                Name =
                    name .. "Section",

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        options.Height
                        or 50
                    ),

                BackgroundColor3 =
                    options.Background
                    or self:_surface(),

                BorderSizePixel =
                    0,

                LayoutOrder =
                    options.Order
                    or #tab.Sections + 1
            }
        )

    self:_square(
        section,
        0
    )

    self:_stroke(
        section,
        options.Border
        or self:_border(),
        1,
        0
    )


    local title =
        self:_label(
            section,
            {
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
                        18
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    string.upper(
                        name
                    ),

                TextColor3 =
                    options.TextColor
                    or self:_muted(),

                TextSize =
                    9,

                Font =
                    Enum.Font.GothamBold,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )


    local container =
        self:_frame(
            section,
            {
                Name =
                    "Controls",

                Position =
                    UDim2.fromOffset(
                        10,
                        32
                    ),

                Size =
                    UDim2.new(
                        1,
                        -20,
                        1,
                        -38
                    ),

                BackgroundTransparency =
                    1,

                BorderSizePixel =
                    0
            }
        )


    local layout =
        self:_create(
            "UIListLayout",
            {
                Parent =
                    container,

                Padding =
                    UDim.new(
                        0,
                        5
                    ),

                FillDirection =
                    Enum.FillDirection.Vertical,

                SortOrder =
                    Enum.SortOrder.LayoutOrder
            }
        )


    section.Title =
        title

    section.Container =
        container

    section.Layout =
        layout

    section.Tab =
        tab

    table.insert(
        tab.Sections,
        section
    )

    table.insert(
        self.Sections,
        section
    )

    return section
end




-- FEATURE RECORD


function Window:_registerControl(
    tabName,
    controlName,
    object,
    options
)

    options =
        options
        or {}

    local record =
        {
            Name =
                controlName,

            Description =
                options.Description
                or "",

            Object =
                object,

            Tab =
                tabName,

            Enabled =
                options.Default
                or false
        }

    table.insert(
        self.Controls,
        record
    )

    table.insert(
        self.FeatureRecords,
        record
    )

    return record
end




-- TOGGLE


function Window:AddToggle(
    tabName,
    section,
    name,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    local row =
        self:_frame(
            parent,
            {
                Name =
                    name,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.FeatureHeight
                    ),

                BackgroundColor3 =
                    options.Background
                    or self:_secondary(),

                BorderSizePixel =
                    0,

                LayoutOrder =
                    options.Order
                    or 0
            }
        )

    self:_square(
        row,
        0
    )


    local title =
        self:_label(
            row,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        5
                    ),

                Size =
                    UDim2.new(
                        1,
                        -72,
                        0,
                        18
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    name,

                TextColor3 =
                    self:_text(),

                TextSize =
                    11,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )


    local description =
        self:_label(
            row,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        24
                    ),

                Size =
                    UDim2.new(
                        1,
                        -72,
                        0,
                        14
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    options.Description
                    or "",

                TextColor3 =
                    self:_muted(),

                TextSize =
                    8,

                Font =
                    Enum.Font.Gotham,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )


    local toggle =
        self:_button(
            row,
            {
                Name =
                    "Toggle",

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
                        42,
                        22
                    ),

                BackgroundColor3 =
                    self:_border(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    ""
            }
        )

    self:_square(
        toggle,
        0
    )


    local indicator =
        self:_frame(
            toggle,
            {
                Name =
                    "Indicator",

                Position =
                    UDim2.fromOffset(
                        3,
                        3
                    ),

                Size =
                    UDim2.fromOffset(
                        16,
                        16
                    ),

                BackgroundColor3 =
                    self:_muted(),

                BorderSizePixel =
                    0
            }
        )

    self:_square(
        indicator,
        0
    )


    local enabled =
        options.Default
        == true


    local function update(value)

        enabled =
            value == true

        self:_tween(
            toggle,
            {
                BackgroundColor3 =
                    enabled
                    and self:_accent()
                    or self:_border()
            },
            0.12
        )

        self:_tween(
            indicator,
            {
                Position =
                    enabled
                    and UDim2.new(
                        1,
                        -19,
                        0,
                        3
                    )
                    or UDim2.fromOffset(
                        3,
                        3
                    ),

                BackgroundColor3 =
                    enabled
                    and Color3.new(
                        1,
                        1,
                        1
                    )
                    or self:_muted()
            },
            0.12
        )

        record.Enabled =
            enabled

        record.Value =
            enabled

        self.ConfigState[name] =
            enabled

        safeCall(
            options.Callback,
            enabled
        )

        safeCall(
            options.OnChanged,
            enabled
        )

    end


    local record =
        self:_registerControl(
            tabName,
            name,
            row,
            {
                Description =
                    options.Description,

                Default =
                    enabled
            }
        )

    record.Value = enabled
    self.ConfigState[name] = enabled

    self:_track(
        toggle.MouseButton1Click:Connect(
            function()

                update(
                    not enabled
                )

            end
        )
    )


    update(
        enabled
    )


    return {
        Object = row,

        Toggle = toggle,

        Indicator = indicator,

        Get = function()

            return enabled

        end,

        Set = function(
            value
        )

            update(
                value
            )

        end,

        Toggle = function()

            update(
                not enabled
            )

        end,

        Record = record
    }
end




-- BUTTON


function Window:AddButton(
    tabName,
    section,
    name,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    local button =
        self:_button(
            parent,
            {
                Name =
                    name,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.FeatureHeight
                    ),

                BackgroundColor3 =
                    options.Background
                    or self:_secondary(),

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    name,

                TextColor3 =
                    options.TextColor
                    or self:_text(),

                TextSize =
                    11,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left,

                LayoutOrder =
                    options.Order
                    or 0
            }
        )

    self:_square(
        button,
        0
    )


    self:_create(
        "UIPadding",
        {
            Parent =
                button,

            PaddingLeft =
                UDim.new(
                    0,
                    12
                )
        }
    )


    self:_buttonHover(
        button
    )


    local record =
        self:_registerControl(
            tabName,
            name,
            button,
            {
                Description =
                    options.Description
            }
        )


    self:_track(
        button.MouseButton1Click:Connect(
            function()

                safeCall(
                    options.Callback
                )

                safeCall(
                    options.OnClick
                )

            end
        )
    )


    return {
        Object = button,

        Button = button,

        Record = record
    }
end




-- LABEL


function Window:AddLabel(
    tabName,
    section,
    text,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    local label =
        self:_label(
            parent,
            {
                Name =
                    options.Name
                    or "Label",

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        options.Height
                        or 28
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    text,

                TextColor3 =
                    options.TextColor
                    or self:_muted(),

                TextSize =
                    options.TextSize
                    or 9,

                Font =
                    options.Font
                    or Enum.Font.Gotham,

                TextXAlignment =
                    options.TextXAlignment
                    or Enum.TextXAlignment.Left,

                TextYAlignment =
                    Enum.TextYAlignment.Center,

                LayoutOrder =
                    options.Order
                    or 0
            }
        )

    return label
end




-- DIVIDER


function Window:AddDivider(
    tabName,
    section,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    return self:_frame(
        parent,
        {
            Name =
                "Divider",

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    1
                ),

            BackgroundColor3 =
                options.Color
                or self:_border(),

            BackgroundTransparency =
                options.Transparency
                or 0,

            BorderSizePixel =
                0,

            LayoutOrder =
                options.Order
                or 0
        }
    )
end




-- SLIDER


function Window:AddSlider(
    tabName,
    section,
    name,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    local minimum =
        tonumber(options.Min)
        or 0

    local maximum =
        tonumber(options.Max)
        or 100

    local value =
        tonumber(options.Default)
        or minimum

    value =
        math.clamp(
            value,
            minimum,
            maximum
        )


    local row =
        self:_frame(
            parent,
            {
                Name =
                    name,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.SliderHeight
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0,

                LayoutOrder =
                    options.Order
                    or 0
            }
        )

    self:_square(
        row,
        0
    )


    local title =
        self:_label(
            row,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        5
                    ),

                Size =
                    UDim2.new(
                        0.7,
                        0,
                        0,
                        18
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    name,

                TextColor3 =
                    self:_text(),

                TextSize =
                    10,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )


    local valueLabel =
        self:_label(
            row,
            {
                AnchorPoint =
                    Vector2.new(
                        1,
                        0
                    ),

                Position =
                    UDim2.new(
                        1,
                        -10,
                        0,
                        5
                    ),

                Size =
                    UDim2.fromOffset(
                        80,
                        18
                    ),

                BackgroundTransparency =
                    1,

                Text =
                    tostring(value),

                TextColor3 =
                    self:_accent(),

                TextSize =
                    10,

                Font =
                    Enum.Font.GothamBold,

                TextXAlignment =
                    Enum.TextXAlignment.Right
            }
        )


    local bar =
        self:_frame(
            row,
            {
                Position =
                    UDim2.fromOffset(
                        10,
                        32
                    ),

                Size =
                    UDim2.new(
                        1,
                        -20,
                        0,
                        6
                    ),

                BackgroundColor3 =
                    self:_border(),

                BorderSizePixel =
                    0,

                Active =
                    true
            }
        )

    self:_square(
        bar,
        0
    )


    local fill =
        self:_frame(
            bar,
            {
                Size =
                    UDim2.new(
                        (
                            value - minimum
                        )
                        / math.max(
                            maximum - minimum,
                            1
                        ),
                        0,
                        1,
                        0
                    ),

                BackgroundColor3 =
                    self:_accent(),

                BorderSizePixel =
                    0
            }
        )

    self:_square(
        fill,
        0
    )


    local function setValue(
        newValue
    )

        newValue =
            tonumber(newValue)
            or minimum

        newValue =
            math.clamp(
                newValue,
                minimum,
                maximum
            )

        if options.Step then

            local step =
                tonumber(
                    options.Step
                )
                or 1

            newValue =
                math.floor(
                    (
                        newValue
                        - minimum
                    )
                    / step
                    + 0.5
                )
                * step
                + minimum

            newValue =
                math.clamp(
                    newValue,
                    minimum,
                    maximum
                )

        end

        value =
            newValue

        local percentage =
            (
                value
                - minimum
            )
            / math.max(
                maximum - minimum,
                1
            )

        fill.Size =
            UDim2.new(
                percentage,
                0,
                1,
                0
            )

        valueLabel.Text =
            tostring(value)

        self.ConfigState[name] =
            value

        if record then
            record.Value = value
        end

        safeCall(
            options.Callback,
            value
        )

        safeCall(
            options.OnChanged,
            value
        )

    end


    self:_track(
        bar.InputBegan:Connect(
            function(input)

                if input.UserInputType
                    ~= Enum.UserInputType.MouseButton1 then

                    return

                end

                local connection

                connection =
                    UserInputService.InputChanged:Connect(
                        function(changed)

                            if changed.UserInputType
                                ~= Enum.UserInputType.MouseMovement then

                                return

                            end

                            local x =
                                changed.Position.X
                                - bar.AbsolutePosition.X

                            local percentage =
                                x
                                / math.max(
                                    bar.AbsoluteSize.X,
                                    1
                                )

                            percentage =
                                math.clamp(
                                    percentage,
                                    0,
                                    1
                                )

                            setValue(
                                minimum
                                + (
                                    maximum
                                    - minimum
                                )
                                * percentage
                            )

                        end
                    )

                local ended

                ended =
                    UserInputService.InputEnded:Connect(
                        function(endedInput)

                            if endedInput.UserInputType
                                == Enum.UserInputType.MouseButton1 then

                                if connection then
                                    connection:Disconnect()
                                end

                                if ended then
                                    ended:Disconnect()
                                end

                            end

                        end
                    )

                self:_track(
                    connection
                )

                self:_track(
                    ended
                )

            end
        )
    )


    local record =
        self:_registerControl(
            tabName,
            name,
            row,
            {
                Description =
                    options.Description
            }
        )


    return {
        Object = row,

        Slider = bar,

        Get = function()

            return value

        end,

        Set = function(
            newValue
        )

            setValue(
                newValue
            )

        end,

        Record = record
    }

end




-- DROPDOWN


function Window:AddDropdown(
    tabName,
    section,
    name,
    options
)

    options =
        options
        or {}

    local parent =
        section.Container
        or section

    local values =
        options.Values
        or options.Options
        or {}

    local selected =
        options.Default
        or values[1]

    local expanded =
        false


    local row =
        self:_frame(
            parent,
            {
                Name =
                    name,

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.DropdownHeight
                    ),

                BackgroundColor3 =
                    self:_secondary(),

                BorderSizePixel =
                    0,

                ClipsDescendants =
                    true,

                LayoutOrder =
                    options.Order
                    or 0
            }
        )

    self:_square(
        row,
        0
    )


    local button =
        self:_button(
            row,
            {
                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        self.Options.DropdownHeight
                    ),

                BackgroundTransparency =
                    1,

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    name
                    .. ": "
                    .. tostring(
                        selected
                        or "None"
                    ),

                TextColor3 =
                    self:_text(),

                TextSize =
                    10,

                Font =
                    Enum.Font.GothamMedium,

                TextXAlignment =
                    Enum.TextXAlignment.Left
            }
        )

    self:_create(
        "UIPadding",
        {
            Parent =
                button,

            PaddingLeft =
                UDim.new(
                    0,
                    10
                ),

            PaddingRight =
                UDim.new(
                    0,
                    10
                )
        }
    )


    local optionContainer =
        self:_frame(
            row,
            {
                Position =
                    UDim2.fromOffset(
                        0,
                        self.Options.DropdownHeight
                    ),

                Size =
                    UDim2.new(
                        1,
                        0,
                        0,
                        #values * 30
                    ),

                BackgroundColor3 =
                    self:_surface(),

                BorderSizePixel =
                    0
            }
        )


    local layout =
        self:_create(
            "UIListLayout",
            {
                Parent =
                    optionContainer,

                FillDirection =
                    Enum.FillDirection.Vertical,

                SortOrder =
                    Enum.SortOrder.LayoutOrder
            }
        )


    for index, item in ipairs(values) do

        local optionButton =
            self:_button(
                optionContainer,
                {
                    Size =
                        UDim2.new(
                            1,
                            0,
                            0,
                            30
                        ),

                    BackgroundColor3 =
                        self:_surface(),

                    BorderSizePixel =
                        0,

                    AutoButtonColor =
                        false,

                    Text =
                        tostring(item),

                    TextColor3 =
                        self:_muted(),

                    TextSize =
                        9,

                    Font =
                        Enum.Font.Gotham,

                    TextXAlignment =
                        Enum.TextXAlignment.Left,

                    LayoutOrder =
                        index
                }
            )

        self:_create(
            "UIPadding",
            {
                Parent =
                    optionButton,

                PaddingLeft =
                    UDim.new(
                        0,
                        10
                    )
            }
        )


        self:_track(
            optionButton.MouseButton1Click:Connect(
                function()

                    selected =
                        item

                    button.Text =
                        name
                        .. ": "
                        .. tostring(
                            selected
                        )

self.ConfigState[name] =
                selected

            if record then
                record.Value = selected
            end

            safeCall(
                        options.Callback,
                        selected
                    )

                    safeCall(
                        options.OnChanged,
                        selected
                    )

                    expanded =
                        false

                    self:_setDropdownExpanded(
                        row,
                        optionContainer,
                        expanded,
                        #values
                    )

                end
            )
        )

    end


    self:_track(
        button.MouseButton1Click:Connect(
            function()

                expanded =
                    not expanded

                self:_setDropdownExpanded(
                    row,
                    optionContainer,
                    expanded,
                    #values
                )

            end
        )
    )


    local record =
        self:_registerControl(
            tabName,
            name,
            row,
            {
                Description =
                    options.Description
            }
        )


    return {
        Object = row,

        Get = function()

            return selected

        end,

        Set = function(
            newValue
        )

            selected =
                newValue

            button.Text =
                name
                .. ": "
                .. tostring(
                    selected
                )

            self.ConfigState[name] =
                selected

            if record then
                record.Value = selected
            end

            safeCall(
                options.Callback,
                selected
            )

        end,

        Record = record
    }

end




-- DROPDOWN EXPANSION


function Window:_setDropdownExpanded(
    row,
    container,
    expanded,
    count
)

    local baseHeight =
        self.Options.DropdownHeight

    local expandedHeight =
        baseHeight
        + (
            expanded
            and count * 30
            or 0
        )

    self:_tween(
        row,
        {
            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    expandedHeight
                )
        },
        0.12
    )

end




-- FEATURE HELPERS


function Window:_resolveFeatureKey(featureName)
    local name = tostring(featureName or "")
    local normalized = string.lower(name)

    local aliases = {
        ["player esp"] = "ESP",
        ["world objects"] = "ESP",
        ["health bars"] = "ESP",
        ["distance labels"] = "ESP",
        ["name labels"] = "ESP",
        ["player esp"] = "ESP",
        ["targeting"] = "Targeting",
        ["combat"] = "Combat",
        ["auto attack"] = "Combat",
        ["aimbot"] = "Combat",
        ["auto heal"] = "GameFeatures",
        ["speed"] = "GameFeatures",
        ["jump"] = "GameFeatures",
        ["gravity"] = "GameFeatures",
        ["no clip"] = "GameFeatures",
        ["flight"] = "GameFeatures",
        ["fullbright"] = "Visuals",
        ["fog"] = "Visuals",
        ["shadows"] = "Visuals",
        ["ambient"] = "Visuals",
        ["field of view"] = "Camera",
        ["free cam"] = "Camera",
        ["spectate"] = "Camera",
        ["third person"] = "Camera",
        ["fov"] = "Camera",
        ["fov controls"] = "Camera",
        ["camera distance"] = "Camera",
        ["camera angle"] = "Camera",
        ["camera smoothness"] = "Camera",
        ["generator assistance"] = "GameFeatures",
        ["healing assistance"] = "GameFeatures",
        ["objective automation"] = "GameFeatures",
        ["exit assistance"] = "GameFeatures",
        ["teleportation"] = "GameFeatures",
        ["skill-check assist"] = "GameFeatures",
        ["perfect skill-chance"] = "GameFeatures",
        ["anti-fail"] = "GameFeatures",
        ["combat assistance"] = "Combat",
        ["target detection"] = "Targeting",
        ["auto carry"] = "Combat",
        ["auto hook"] = "Combat",
        ["hitbox testing"] = "Targeting",
        ["lunge controls"] = "Combat",
        ["pallet destruction"] = "GameFeatures",
        ["survivor teleportation"] = "GameFeatures",
        ["teleport"] = "GameFeatures",
        ["free camera"] = "Camera",
        ["launch / physics"] = "Movement",
        ["custom coordinates"] = "Movement",
        ["position reset"] = "Movement",
        ["fog controls"] = "Visuals",
        ["shadow controls"] = "Visuals",
        ["lighting"] = "Visuals",
        ["visibility testing"] = "Visuals",
        ["debug modes"] = "GameFeatures",
        ["physics testing"] = "GameFeatures",
        ["map exploration"] = "GameFeatures",
        ["objective testing"] = "GameFeatures",
        ["endgame testing"] = "GameFeatures",
        ["diagnostics"] = "GameFeatures",
        ["utility"] = "GameFeatures",
        ["settings"] = "Config",
        ["notifications"] = "Notifications",
        ["keybinds"] = "Keybinds",
        ["status"] = "Config",
    }

    if aliases[normalized] then
        return aliases[normalized]
    end

    if name ~= "" then
        return name
    end

    return nil
end


function Window:_applyFeatureToggle(featureName, enabled)
    local mappedFeature = self:_resolveFeatureKey(featureName)
    if not mappedFeature then
        return
    end

    local key = string.lower(tostring(featureName or ""))

    if self.FeatureManager and type(self.FeatureManager.Get) == "function" then
        local module = self.FeatureManager:Get(mappedFeature)

        if module then
            if key == "free cam" and type(module.SetFreeCam) == "function" then
                module:SetFreeCam(enabled)
                return
            end

            if key == "spectate" and type(module.SetSpectate) == "function" then
                module:SetSpectate(enabled)
                return
            end

            if key == "no clip" and type(module.SetNoClip) == "function" then
                module:SetNoClip(enabled)
                return
            end

            if key == "flight" and type(module.SetFlight) == "function" then
                module:SetFlight(enabled)
                return
            end

            if key == "fullbright" and type(module.SetEnabled) == "function" then
                module:SetEnabled(enabled)
                return
            end

            if key == "speed" and type(module.SetSpeedEnabled) == "function" then
                module:SetSpeedEnabled(enabled)
                return
            end

            if key == "jump" and type(module.SetJumpEnabled) == "function" then
                module:SetJumpEnabled(enabled)
                return
            end

            if key == "gravity" and type(module.SetGravityEnabled) == "function" then
                module:SetGravityEnabled(enabled)
                return
            end

            if type(module.SetEnabled) == "function" then
                module:SetEnabled(enabled)
                return
            end
        end
    end

    if self.FeatureManager and type(self.FeatureManager.SetEnabled) == "function" then
        pcall(function()
            self.FeatureManager:SetEnabled(mappedFeature, enabled)
        end)
    end
end


function Window:_applyFeatureSlider(featureName, settingName, value)
    local mappedFeature = self:_resolveFeatureKey(featureName)
    if not mappedFeature then
        return
    end

    local key = string.lower(tostring(featureName or ""))

    if self.FeatureManager and type(self.FeatureManager.Get) == "function" then
        local module = self.FeatureManager:Get(mappedFeature)

        if module then
            if key == "speed" and type(module.SetWalkSpeed) == "function" then
                module:SetWalkSpeed(value)
                return
            end

            if key == "jump" and type(module.SetJumpPower) == "function" then
                module:SetJumpPower(value)
                return
            end

            if key == "gravity" and type(module.SetGravity) == "function" then
                module:SetGravity(value)
                return
            end

            if key == "field of view" and type(module.SetSetting) == "function" then
                module:SetSetting("FOV", value)
                return
            end

            if key == "camera distance" and type(module.SetSetting) == "function" then
                module:SetSetting("Distance", value)
                return
            end

            if key == "camera smoothness" and type(module.SetSetting) == "function" then
                module:SetSetting("Smoothness", value)
                return
            end

            if type(module.SetSetting) == "function" then
                module:SetSetting(settingName or "Strength", value)
                return
            end
        end
    end

    if self.FeatureManager and type(self.FeatureManager.UpdateFeatureSetting) == "function" then
        pcall(function()
            self.FeatureManager:UpdateFeatureSetting(mappedFeature, settingName or "Strength", value)
        end)
    end
end


function Window:AddFeatureToggle(
    tabName,
    section,
    featureName,
    options
)

    options =
        options
        or {}

    return self:AddToggle(
        tabName,
        section,
        featureName,
        {
            Description =
                options.Description,

            Default =
                options.Default,

            Callback =
                function(enabled)

                    self:_featureChanged(
                        featureName,
                        enabled,
                        options
                    )

                end
        }
    )

end


function Window:AddFeatureButton(
    tabName,
    section,
    featureName,
    options
)

    options =
        options
        or {}

    return self:AddButton(
        tabName,
        section,
        featureName,
        {
            Description =
                options.Description,

            Callback =
                function()

                    self:_featureTriggered(
                        featureName,
                        options
                    )

                end
        }
    )

end




-- FEATURE CALLBACKS


function Window:_featureChanged(
    featureName,
    enabled,
    options
)

    safeCall(
        options.Callback,
        enabled
    )

    local manager =
        self.FeatureManager

    if manager then

        if type(manager.SetEnabled)
            == "function" then

            pcall(function()

                manager:SetEnabled(
                    featureName,
                    enabled
                )

            end)

        end

    end

end


function Window:_featureTriggered(
    featureName,
    options
)

    safeCall(
        options.Callback
    )

    local manager =
        self.FeatureManager

    if manager then

        if type(manager.Trigger)
            == "function" then

            pcall(function()

                manager:Trigger(
                    featureName
                )

            end)

        end

    end

end




-- WINDOW POSITION


function Window:_center()

    if not self.Main then
        return
    end

    self.Main.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    self.Main.Position =
        UDim2.fromScale(
            0.5,
            0.5
        )

end


function Window:Center()

    self:_center()

    return true
end




-- DRAGGING


function Window:_beginDrag(input)

    if not self.Options.Draggable then
        return
    end

    self._dragging =
        true

    self._dragStart =
        input.Position

    self._windowStart =
        self.Main.Position

end


function Window:_updateDrag(input)

    if not self._dragging then
        return
    end

    if not self._dragStart
        or not self._windowStart then

        return
    end

    local delta =
        input.Position
        - self._dragStart

    self.Main.Position =
        UDim2.new(
            self._windowStart.X.Scale,
            self._windowStart.X.Offset
                + delta.X,

            self._windowStart.Y.Scale,
            self._windowStart.Y.Offset
                + delta.Y
        )

end


function Window:_endDrag()

    self._dragging =
        false

    self._dragStart =
        nil

    self._windowStart =
        nil

end




-- INPUT


function Window:_bindInput()

    if not self.Main then
        return
    end


    -- WINDOW DRAG

    if self.Options.Draggable then

        self:_track(
            self.Header.InputBegan:Connect(
                function(input)

                    if input.UserInputType
                        == Enum.UserInputType.MouseButton1 then

                        self:_beginDrag(
                            input
                        )

                    end

                end
            )
        )


        self:_track(
            UserInputService.InputChanged:Connect(
                function(input)

                    if input.UserInputType
                        == Enum.UserInputType.MouseMovement then

                        self:_updateDrag(
                            input
                        )

                    end

                end
            )
        )


        self:_track(
            UserInputService.InputEnded:Connect(
                function(input)

                    if input.UserInputType
                        == Enum.UserInputType.MouseButton1 then

                        self:_endDrag()

                    end

                end
            )
        )

    end


    -- TOGGLE KEY

    self:_track(
        UserInputService.InputBegan:Connect(
            function(input, processed)

                if processed then
                    return
                end

                if input.KeyCode
                    == self.Options.ToggleKey then

                    self:Toggle()

                end

            end
        )
    )

end




-- OPEN


function Window:Open(
    animate
)

    if self.Destroyed
        or not self.Main then

        return false
    end

    self.Opened =
        true

    self.Main.Visible =
        true

    if self.Options.CenterOnOpen then

        self:_center()

    end

    if animate == false
        or self.Options.EnableAnimations == false then

        self.Main.BackgroundTransparency =
            self.Options.BackgroundTransparency

        return true

    end

    return true
end




-- CLOSE


function Window:Close(
    animate
)

    if self.Destroyed
        or not self.Main then

        return false
    end

    self.Opened =
        false

    self.Main.Visible =
        false

    return true
end




-- TOGGLE


function Window:Toggle()

    if self.Opened then

        return self:Close()

    end

    return self:Open()

end




-- MINIMIZE


function Window:Minimize()

    if self.Minimized then
        return
    end

    self.Minimized =
        true

    if self.PageContainer then
        self.PageContainer.Visible =
            false
    end

    if self.Navigation then
        self.Navigation.Visible =
            false
    end

    if self.Footer then
        self.Footer.Visible =
            false
    end

    self.Main.Size =
        UDim2.fromOffset(
            self.Options.Width,
            self.Options.HeaderHeight
        )

end


function Window:Restore()

    if not self.Minimized then
        return
    end

    self.Minimized =
        false

    if self.PageContainer then
        self.PageContainer.Visible =
            true
    end

    if self.Navigation then
        self.Navigation.Visible =
            true
    end

    if self.Footer then
        self.Footer.Visible =
            true
    end

    self.Main.Size =
        UDim2.fromOffset(
            self.Options.Width,
            self.Options.Height
        )

end


function Window:ToggleMinimize()

    if self.Minimized then

        self:Restore()

    else

        self:Minimize()

    end

end




-- STATUS


function Window:SetStatus(
    text
)

    if not self.Status then
        return false
    end

    self.Status.Text =
        tostring(
            text
            or ""
        )

    return true
end




-- TITLE


function Window:SetTitle(
    title,
    subtitle
)

    if self.Title then

        self.Title.Text =
            tostring(
                title
                or ""
            )

    end

    if subtitle ~= nil
        and self.Subtitle then

        self.Subtitle.Text =
            tostring(
                subtitle
            )

    end

end


function Window:ApplyPremiumStyle()
    if self.Header then
        self.Header.BackgroundColor3 = self:_accent()
        self.Header.BorderSizePixel = 0
    end

    if self.Main then
        self.Main.BackgroundColor3 = self:_background()
    end

    if self.Navigation then
        self.Navigation.BackgroundColor3 = self:_secondary()
    end

    if self.Content then
        self.Content.BackgroundColor3 = self:_background()
    end

    if self.Footer then
        self.Footer.BackgroundColor3 = self:_secondary()
    end

    if self.Title then
        self.Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        self.Title.Font = Enum.Font.GothamBold
    end

    if self.Subtitle then
        self.Subtitle.TextColor3 = self:_muted()
        self.Subtitle.Font = Enum.Font.GothamSemibold
    end

    if self.Status then
        self.Status.TextColor3 = Color3.fromRGB(214, 245, 255)
        self.Status.Font = Enum.Font.GothamBold
    end

    return true
end




-- TAB ACCESS


function Window:GetTab(
    name
)

    return self.Tabs[name]
end


function Window:GetActiveTab()

    return self.ActiveTab
end




-- CONTROL ACCESS


function Window:GetControl(
    name
)

    for _, record in ipairs(
        self.Controls
    ) do

        if record.Name == name then

            return record

        end

    end

    return nil
end




-- REFRESH THEME


function Window:RefreshTheme()

    if self.Destroyed then
        return false
    end

    local Components =
        self:_component()

    if Components
        and Components.RefreshTheme then

        pcall(function()

            Components:RefreshTheme()

        end)

    end

    if self.Main then

        self.Main.BackgroundColor3 =
            self:_background()

    end

    if self.Header then

        self.Header.BackgroundColor3 =
            self:_secondary()

    end

    if self.Navigation then

        self.Navigation.BackgroundColor3 =
            self:_secondary()

    end

    if self.Content then

        self.Content.BackgroundColor3 =
            self:_background()

    end

    if self.Footer then

        self.Footer.BackgroundColor3 =
            self:_secondary()

    end

    return true
end




-- SET SIZE


function Window:SetSize(
    width,
    height
)

    width =
        tonumber(width)
        or self.Options.Width

    height =
        tonumber(height)
        or self.Options.Height

    width =
        math.max(
            width,
            self.Options.MinWidth
        )

    height =
        math.max(
            height,
            self.Options.MinHeight
        )

    self.Options.Width =
        width

    self.Options.Height =
        height

    if self.Main
        and not self.Minimized then

        self.Main.Size =
            UDim2.fromOffset(
                width,
                height
            )

    end

end




-- SET TAB VISIBILITY


function Window:SetTabVisible(
    name,
    visible
)

    local tab =
        self.Tabs[name]

    if not tab then
        return false
    end

    tab.Button.Visible =
        visible == true

    return true
end




-- SHOW / HIDE


function Window:SetVisible(
    visible
)

    if visible then

        return self:Open()

    end

    return self:Close()

end




-- DESTROY


function Window:Destroy()

    if self.Destroyed then
        return
    end

    self.Destroyed =
        true

    self._dragging =
        false

    for _, connection in ipairs(
        self.Connections
    ) do

        if connection
            and connection.Disconnect then

            pcall(function()

                connection:Disconnect()

            end)

        end

    end


    for _, object in ipairs(
        self.Objects
    ) do

        if object
            and object.Destroy then

            pcall(function()

                object:Destroy()

            end)

        end

    end


    self.Connections = {}

    self.Objects = {}

    self.Tabs = {}

    self.TabOrder = {}

    self.Sections = {}

    self.Controls = {}

    self.FeatureRecords = {}

    self.Main = nil

    self.ScreenGui = nil

end




-- GETTERS


function Window:IsOpen()

    return self.Opened
        == true

end


function Window:IsMinimized()

    return self.Minimized
        == true

end


function Window:IsDestroyed()

    return self.Destroyed
        == true

end


function Window:GetMain()

    return self.Main

end


function Window:GetScreenGui()

    return self.ScreenGui

end




-- DEFAULT FEATURE ORGANIZATION


function Window:BuildDefaultFeatureLayout(
    features
)

    features =
        features
        or {}

    return self:BuildAdvancedFeatureLayout(features)
end


function Window:ApplyTheme(themeName)
    if self.Themes and type(self.Themes.SetTheme) == "function" then
        local success = pcall(function()
            self.Themes:SetTheme(themeName)
        end)

        if success then
            self:RefreshTheme()
            return true
        end
    end

    return false
end


function Window:SaveConfig()
    local payload = {
        Theme = self.Themes and self.Themes:GetCurrentTheme() or "Midnight",
        CenterOnOpen = self.Options.CenterOnOpen == true,
        ToggleKey = tostring(self.Options.ToggleKey or "RightShift"),
        Settings = self.ConfigState,
    }

    local serialized = tostring(payload)

    if game:GetService and game:GetService("HttpService") then
        local HttpService = game:GetService("HttpService")
        if HttpService.JSONEncode then
            serialized = HttpService:JSONEncode(payload)
        end
    end

    self.LastSavedConfig = serialized

    if self.Profiles and type(self.Profiles.Save) == "function" then
        pcall(function()
            self.Profiles:Save(self.ConfigKey, payload)
        end)
    end

    if self.ScreenGui then
        local value = self.ScreenGui:FindFirstChild(self.ConfigKey)
        if not value then
            value = Instance.new("StringValue")
            value.Name = self.ConfigKey
            value.Parent = self.ScreenGui
        end

        value.Value = serialized
    end

    if self.Debug and type(self.Debug.Info) == "function" then
        pcall(function()
            self.Debug:Info("Saved UI config")
        end)
    end

    if self.Status then
        self.Status.Text = "CONFIG SAVED"
    end

    return true
end


function Window:LoadConfig()
    local data = self.LastSavedConfig

    if self.Profiles and type(self.Profiles.Load) == "function" then
        local success, profileData = pcall(function()
            return self.Profiles:Load(self.ConfigKey, nil)
        end)

        if success and type(profileData) == "table" then
            data = profileData
        end
    end

    if self.ScreenGui then
        local value = self.ScreenGui:FindFirstChild(self.ConfigKey)
        if value and value.Value ~= nil then
            local raw = value.Value
            if type(raw) == "string" then
                if game:GetService and game:GetService("HttpService") then
                    local HttpService = game:GetService("HttpService")
                    if HttpService.JSONDecode then
                        local ok, decoded = pcall(function()
                            return HttpService:JSONDecode(raw)
                        end)
                        if ok and type(decoded) == "table" then
                            data = decoded
                        end
                    end
                end
            end
        end
    end

    if type(data) == "string" then
        local ok, decoded = pcall(function()
            if game:GetService and game:GetService("HttpService") then
                local HttpService = game:GetService("HttpService")
                if HttpService.JSONDecode then
                    return HttpService:JSONDecode(data)
                end
            end

            return nil
        end)

        if ok and type(decoded) == "table" then
            data = decoded
        end
    end

    if type(data) == "table" then
        if data.Theme and self.Themes and type(self.Themes.SetTheme) == "function" then
            pcall(function()
                self.Themes:SetTheme(data.Theme)
            end)
        end

        if type(data.Settings) == "table" then
            self.ConfigState = data.Settings
        end
    end

    if self.Debug and type(self.Debug.Info) == "function" then
        pcall(function()
            self.Debug:Info("Loaded UI config")
        end)
    end

    if self.Status then
        self.Status.Text = "CONFIG LOADED"
    end

    return true
end


function Window:BuildAdvancedFeatureLayout(
    features
)

    features =
        features
        or {}

    self:ClearTabs()

    self.Options.CenterOnOpen = true
    self.Options.StartOpen = true
    self.Options.ToggleKey = Enum.KeyCode.RightShift

    if self.Themes and type(self.Themes.SetTheme) == "function" then
        pcall(function()
            self.Themes:SetTheme("Purple")
        end)
    end

    self:SetTitle(
        "Singularity-Ninny.top",
        "FEATURE CONTROL"
    )

    self:ApplyPremiumStyle()
    self:SetStatus("PREMIUM MODE • ACTIVE")

    if self.HotkeyLabel then
        self.HotkeyLabel.Text = "RIGHT SHIFT  •  TOGGLE"
    end

    if self.Commands and type(self.Commands.Register) == "function" then
        pcall(function()
            self.Commands:Register("togglemenu", function()
                self:Toggle()
            end, "Toggle the premium menu")

            self.Commands:Register("saveconfig", function()
                self:SaveConfig()
            end, "Save current UI config")

            self.Commands:Register("loadconfig", function()
                self:LoadConfig()
            end, "Load saved UI config")

            self.Commands:Register("theme", function(themeName)
                if themeName and themeName ~= "" then
                    self:ApplyTheme(themeName)
                end
            end, "Change the active UI theme")
        end)
    end

    local tabs = {
        "Player",
        "Movement",
        "Visuals",
        "Misc",
    }

    local registry = {
        Player = {
            { Name = "Player ESP", Key = "Player ESP", Type = "Toggle" },
            { Name = "Targeting", Key = "Targeting", Type = "Toggle" },
            { Name = "Auto Attack", Key = "Combat", Type = "Toggle" },
            { Name = "Aimbot", Key = "Combat", Type = "Toggle" },
            { Name = "Auto Heal", Key = "Auto Heal", Type = "Toggle" },
            { Name = "Spectate", Key = "Spectate", Type = "Toggle" },
            { Name = "Sensitivity", Key = "Sensitivity", Type = "Slider", Min = 0, Max = 100, Default = 55 },
        },

        Movement = {
            { Name = "Speed", Key = "Speed", Type = "Slider", Min = 0, Max = 200, Default = 90 },
            { Name = "Jump", Key = "Jump", Type = "Slider", Min = 0, Max = 200, Default = 80 },
            { Name = "No Clip", Key = "No Clip", Type = "Toggle" },
            { Name = "Flight", Key = "Flight", Type = "Toggle" },
            { Name = "Gravity", Key = "Gravity", Type = "Slider", Min = 0, Max = 200, Default = 100 },
            { Name = "Teleport", Key = "Teleport", Type = "Toggle" },
        },

        Visuals = {
            { Name = "Fullbright", Key = "Fullbright", Type = "Toggle" },
            { Name = "Fog Control", Key = "Fog", Type = "Toggle" },
            { Name = "Shadow Control", Key = "Shadows", Type = "Toggle" },
            { Name = "Ambient", Key = "Ambient", Type = "Toggle" },
            { Name = "Field of View", Key = "Field of View", Type = "Slider", Min = 0, Max = 120, Default = 70 },
            { Name = "Theme", Key = "Theme", Type = "Dropdown", Options = { "Midnight", "Dark", "Purple", "Blue", "Red", "Green", "Cyan", "Orange" } },
        },

        Misc = {
            { Name = "Center Window", Key = "CenterWindow", Type = "Toggle" },
            { Name = "Free Cam", Key = "Free Cam", Type = "Toggle" },
            { Name = "Save Config", Key = "SaveConfig", Type = "Button" },
            { Name = "Load Config", Key = "LoadConfig", Type = "Button" },
            { Name = "Reset Theme", Key = "ResetTheme", Type = "Button" },
            { Name = "Status", Key = "Status", Type = "Label" },
        },
    }

    for _, tabName in ipairs(tabs) do
        self:AddTab(
            tabName,
            {
                Icon = string.sub(tabName, 1, 1),
                Order = self.TabOrder and (#self.TabOrder + 1) or 1,
            }
        )
    end

    local sections = {}

    for _, tabName in ipairs(tabs) do
        local panel = registry[tabName] or {}
        local container = {}

        for index, item in ipairs(panel) do
            local section = self:AddSection(
                tabName,
                item.Name,
                {
                    Height = 82,
                    Order = index,
                    Background = Color3.fromRGB(20, 22, 28),
                    Border = Color3.fromRGB(45, 48, 56),
                }
            )

            container[item.Name] = section

            if item.Type == "Toggle" then
                self:AddToggle(
                    tabName,
                    section,
                    item.Name,
                    {
                        Description = "Feature toggle",
                        Default = false,
                        Callback = function(enabled)
                            self:_applyFeatureToggle(item.Key, enabled)
                        end,
                    }
                )
            elseif item.Type == "Slider" then
                self:AddSlider(
                    tabName,
                    section,
                    item.Name,
                    {
                        Min = item.Min or 0,
                        Max = item.Max or 100,
                        Default = item.Default or 50,
                        Description = "Value control",
                        Callback = function(value)
                            self:_applyFeatureSlider(item.Key, item.Name, value)
                        end,
                    }
                )
            elseif item.Type == "Dropdown" then
                self:AddDropdown(
                    tabName,
                    section,
                    item.Name,
                    {
                        Values = item.Options or { "Midnight" },
                        Default = item.Options and item.Options[1] or "Midnight",
                        Description = "Theme selector",
                        Callback = function(value)
                            if item.Key == "Theme" then
                                self:ApplyTheme(value)
                            end
                        end,
                    }
                )
            elseif item.Type == "Button" then
                self:AddButton(
                    tabName,
                    section,
                    item.Name,
                    {
                        Description = "Quick action",
                        Background = Color3.fromRGB(36, 40, 48),
                        Callback = function()
                            if item.Name == "Save Config" then
                                self:SaveConfig()
                            elseif item.Name == "Load Config" then
                                self:LoadConfig()
                            elseif item.Name == "Reset Theme" then
                                if self.Themes and type(self.Themes.SetTheme) == "function" then
                                    pcall(function()
                                        self.Themes:SetTheme("Midnight")
                                    end)
                                    self:RefreshTheme()
                                end
                            end
                        end,
                    }
                )
            elseif item.Type == "Label" then
                self:AddLabel(
                    tabName,
                    section,
                    "Framework status: online",
                    {
                        Height = 18,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }
                )
                self:AddLabel(
                    tabName,
                    section,
                    "UI: premium build active",
                    {
                        Height = 18,
                        TextSize = 10,
                        TextXAlignment = Enum.TextXAlignment.Left,
                    }
                )
            end
        end

        sections[tabName] = container
    end

    return sections
end


function Window:BuildFeaturePanel(tabName, sectionName, items)
    items = items or {}

    local section = self:AddSection(
        tabName,
        sectionName,
        {
            Height = 52 + (math.max(#items, 1) * 36),
            Order = 1,
        }
    )

    for index, item in ipairs(items) do
        if type(item) == "table" then
            local name = item.Name or item.Label or "Setting"
            local defaultValue = item.Default ~= nil and item.Default or false

            if item.Type == "slider" then
                self:AddSlider(
                    tabName,
                    section,
                    name,
                    {
                        Min = item.Min or 0,
                        Max = item.Max or 100,
                        Default = item.Default or 0,
                        Description = item.Description or "",
                        Callback = item.Callback,
                    }
                )
            else
                self:AddToggle(
                    tabName,
                    section,
                    name,
                    {
                        Description = item.Description or "",
                        Default = defaultValue,
                        Callback = item.Callback,
                    }
                )
            end
        end
    end

    return section
end


function Window:AddStatusCard(tabName, title, value, color)
    local section = self:AddSection(
        tabName,
        title,
        {
            Height = 60,
            Order = 1,
        }
    )

    self:AddLabel(
        tabName,
        section,
        tostring(value or "0"),
        {
            Height = 24,
            TextSize = 12,
            TextColor = color or self:_accent(),
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        }
    )

    return section
end




-- MODULE RETURN


return Window