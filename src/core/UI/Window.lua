local Window = {}
Window.__index = Window

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local DEFAULTS = {
    Size = UDim2.fromOffset(720, 520),
    Position = UDim2.fromScale(0.5, 0.5),

    Background = Color3.fromRGB(18, 18, 22),
    Secondary = Color3.fromRGB(24, 24, 29),
    Accent = Color3.fromRGB(120, 90, 255),
    Text = Color3.fromRGB(235, 235, 240),
    MutedText = Color3.fromRGB(145, 145, 155),
    Border = Color3.fromRGB(45, 45, 52),

    CornerRadius = 8,

    AnimationTime = 0.15
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
        object[property] = value
    end

    return object
end

function Window.new(components, config, connections, notifications, options)
    assert(components, "Window requires Components")
    assert(config, "Window requires Config")

    local self = setmetatable({}, Window)

    self.Components = components
    self.Config = config
    self.Connections = connections
    self.Notifications = notifications

    self.Options = merge(DEFAULTS, options)

    self.Gui = nil
    self.Main = nil
    self.Content = nil

    self.Tabs = {}
    self.Pages = {}

    self.CurrentTab = nil
    self.Destroyed = false

    self.Theme = {
        Background = self.Options.Background,
        Secondary = self.Options.Secondary,
        Accent = self.Options.Accent,
        Text = self.Options.Text,
        MutedText = self.Options.MutedText,
        Border = self.Options.Border
    }

    return self
end

function Window:_tween(object, properties)
    return TweenService:Create(
        object,
        TweenInfo.new(
            self.Options.AnimationTime,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        properties
    )
end

function Window:_register(name, connection)
    if self.Connections and self.Connections.Add then
        return self.Connections:Add(name, connection)
    end

    return connection
end

function Window:Create()
    local player = Players.LocalPlayer

    if not player then
        error("LocalPlayer unavailable")
    end

    local playerGui = player:WaitForChild("PlayerGui")

    local oldGui = playerGui:FindFirstChild("LuaTestUI")

    if oldGui then
        oldGui:Destroy()
    end

    local gui = create("ScreenGui", {
        Name = "LuaTestUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = playerGui
    })

    self.Gui = gui

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = self.Options.Position,
        Size = self.Options.Size,
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        Parent = gui
    })

    self.Main = main

    self.Components:Corner(main, self.Options.CornerRadius)

    self:_createHeader()
    self:_createBody()

    self:_register(
        "WindowInput",
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed then
                return
            end

            if input.KeyCode == self.Config.UI.ToggleKey then
                self:SetVisible(not self.Gui.Enabled)
            end
        end)
    )

    self:SetVisible(true, false)

    return self
end

function Window:_createHeader()
    local header = create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 48),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = self.Main
    })

    self.Components:Corner(header, self.Options.CornerRadius)

    local title = create("TextLabel", {
        Name = "Title",
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -120, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "Lua Test",
        TextColor3 = self.Theme.Text,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = header
    })

    self.Title = title

    local minimize = create("TextButton", {
        Name = "Minimize",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = "—",
        TextColor3 = self.Theme.MutedText,
        TextSize = 18,
        AutoButtonColor = false,
        Parent = header
    })

    minimize.MouseButton1Click:Connect(function()
        self:SetVisible(false)
    end)

    self:_makeDraggable(header)
end

function Window:_createBody()
    local body = create("Frame", {
        Name = "Body",
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 1, -48),
        BackgroundTransparency = 1,
        Parent = self.Main
    })

    local tabBar = create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(0, 140, 1, 0),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = body
    })

    local pages = create("Frame", {
        Name = "Pages",
        Position = UDim2.fromOffset(140, 0),
        Size = UDim2.new(1, -140, 1, 0),
        BackgroundTransparency = 1,
        Parent = body
    })

    self.TabBar = tabBar
    self.PagesContainer = pages
end

function Window:AddTab(name)
    assert(type(name) == "string", "Tab name must be a string")

    if self.Tabs[name] then
        return self.Tabs[name]
    end

    local button = create("TextButton", {
        Name = name .. "Button",
        Size = UDim2.new(1, -16, 0, 38),
        Position = UDim2.fromOffset(8, 8 + (#self.Tabs * 42)),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = self.Theme.MutedText,
        TextSize = 13,
        AutoButtonColor = false,
        Parent = self.TabBar
    })

    self.Components:Corner(button, 6)

    local page = create("ScrollingFrame", {
        Name = name .. "Page",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = self.Theme.Accent,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Parent = self.PagesContainer
    })

    create("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = page
    })

    local tab = {
        Name = name,
        Button = button,
        Page = page,
        Sections = {}
    }

    self.Tabs[name] = tab
    self.Pages[name] = page

    button.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    if not self.CurrentTab then
        self:SelectTab(name)
    end

    return tab
end

function Window:SelectTab(name)
    local selected = self.Tabs[name]

    if not selected then
        return false
    end

    self.CurrentTab = name

    for tabName, tab in pairs(self.Tabs) do
        local active = tabName == name

        tab.Page.Visible = active

        self:_tween(tab.Button, {
            BackgroundColor3 = active
                and self.Theme.Accent
                or self.Theme.Secondary,

            TextColor3 = active
                and Color3.new(1, 1, 1)
                or self.Theme.MutedText
        }):Play()
    end

    return true
end

function Window:AddSection(tabName, title)
    local tab = self.Tabs[tabName]

    assert(tab, "Tab does not exist: " .. tabName)

    local section = create("Frame", {
        Name = title .. "Section",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
        Parent = tab.Page
    })

    self.Components:Corner(section, 7)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 0, 36),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = self.Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = section
    })

    local layout = create("UIListLayout", {
        Padding = UDim.new(0, 6),
        Parent = section
    })

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        section.Size = UDim2.new(
            1,
            0,
            0,
            layout.AbsoluteContentSize.Y + 14
        )
    end)

    local sectionData = {
        Frame = section,
        Label = label,
        Layout = layout
    }

    table.insert(tab.Sections, sectionData)

    return sectionData
end

function Window:AddToggle(section, name, default, callback)
    local value = default == true

    local button = create("TextButton", {
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = "",
        AutoButtonColor = false,
        Parent = section.Frame
    })

    self.Components:Corner(button, 6)

    local label = create("TextLabel", {
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -60, 1, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = name,
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = button
    })

    local indicator = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(28, 16),
        BackgroundColor3 = value
            and self.Theme.Accent
            or self.Theme.Border,
        BorderSizePixel = 0,
        Parent = button
    })

    self.Components:Corner(indicator, 8)

    local function update(newValue)
        value = newValue == true

        self:_tween(indicator, {
            BackgroundColor3 = value
                and self.Theme.Accent
                or self.Theme.Border
        }):Play()

        if callback then
            callback(value)
        end
    end

    button.MouseButton1Click:Connect(function()
        update(not value)
    end)

    return {
        Get = function()
            return value
        end,

        Set = update,

        Button = button
    }
end

function Window:SetVisible(visible, animate)
    if not self.Gui then
        return
    end

    animate = animate ~= false

    self.Gui.Enabled = true

    if not animate then
        self.Main.Visible = visible
        return
    end

    if visible then
        self.Main.Visible = true
        self.Main.Size = UDim2.fromOffset(
            self.Options.Size.X.Offset * 0.95,
            self.Options.Size.Y.Offset * 0.95
        )

        self:_tween(self.Main, {
            Size = self.Options.Size
        }):Play()
    else
        self:_tween(self.Main, {
            Size = UDim2.fromOffset(
                self.Options.Size.X.Offset * 0.95,
                self.Options.Size.Y.Offset * 0.95
            )
        }):Play()

        task.delay(self.Options.AnimationTime, function()
            if self.Gui and not self.Destroyed then
                self.Main.Visible = false
            end
        end)
    end
end

function Window:_makeDraggable(handle)
    local dragging = false
    local dragStart
    local startPosition

    self:_register(
        "WindowDragStart",
        handle.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end

            dragging = true
            dragStart = input.Position
            startPosition = self.Main.Position
        end)
    )

    self:_register(
        "WindowDragChanged",
        UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end

            if input.UserInputType ~= Enum.UserInputType.MouseMovement then
                return
            end

            local delta = input.Position - dragStart

            self.Main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end)
    )

    self:_register(
        "WindowDragEnd",
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    )
end

function Window:Destroy()
    self.Destroyed = true

    if self.Gui then
        self.Gui:Destroy()
    end

    self.Gui = nil
    self.Main = nil
    self.Tabs = {}
    self.Pages = {}
    self.CurrentTab = nil
end


function Window:AddButton(section, name, callback)
    local button = create("TextButton", {
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        Text = name,
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = section.Frame
    })

    self.Components:Corner(button, 6)

    button.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
    end)

    return button
end

function Window:AddSlider(section, name, minimum, maximum, default, callback)
    local value = math.clamp(default or minimum, minimum, maximum)

    local container = create("Frame", {
        Size = UDim2.new(1, -20, 0, 52),
        BackgroundTransparency = 1,
        Parent = section.Frame
    })

    local label = create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Text = name .. ": " .. tostring(value),
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    local bar = create("Frame", {
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 0, 6),
        BackgroundColor3 = self.Theme.Border,
        BorderSizePixel = 0,
        Parent = container
    })

    self.Components:Corner(bar, 3)

    local fill = create("Frame", {
        Size = UDim2.new(
            (value - minimum) / (maximum - minimum),
            0,
            1,
            0
        ),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Parent = bar
    })

    self.Components:Corner(fill, 3)

    local dragging = false

    local function updateFromInput(input)
        local relative = math.clamp(
            (input.Position.X - bar.AbsolutePosition.X)
                / bar.AbsoluteSize.X,
            0,
            1
        )

        value = minimum + ((maximum - minimum) * relative)

        label.Text = name .. ": " .. string.format("%.2f", value)

        fill.Size = UDim2.new(relative, 0, 1, 0)

        if callback then
            callback(value)
        end
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return {
        Get = function()
            return value
        end,

        Set = function(newValue)
            value = math.clamp(newValue, minimum, maximum)

            local alpha = (value - minimum) / (maximum - minimum)

            fill.Size = UDim2.new(alpha, 0, 1, 0)
            label.Text = name .. ": " .. string.format("%.2f", value)

            if callback then
                callback(value)
            end
        end
    }
end

function Window:AddColorPicker(section, name, default, callback)
    local value = default or Color3.new(1, 1, 1)

    local button = create("TextButton", {
        Size = UDim2.new(1, -20, 0, 34),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        Font = Enum.Font.Gotham,
        Text = name,
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        AutoButtonColor = false,
        Parent = section.Frame
    })

    self.Components:Corner(button, 6)

    local preview = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(24, 18),
        BackgroundColor3 = value,
        BorderSizePixel = 0,
        Parent = button
    })

    self.Components:Corner(preview, 5)

    return {
        Get = function()
            return value
        end,

        Set = function(newValue)
            if typeof(newValue) ~= "Color3" then
                return
            end

            value = newValue
            preview.BackgroundColor3 = value

            if callback then
                callback(value)
            end
        end,

        Button = button
    }
end

local colorsSection = window:AddSection("VISUAL", "ESP Colors")

window:AddColorPicker(
    colorsSection,
    "Killer Color",
    Config.ESP.Colors.Killer,
    function(color)
        Config.ESP.Colors.Killer = color
    end
)

window:AddColorPicker(
    colorsSection,
    "Survivor Color",
    Config.ESP.Colors.Survivor,
    function(color)
        Config.ESP.Colors.Survivor = color
    end
)

window:AddColorPicker(
    colorsSection,
    "Generator Color",
    Config.ESP.Colors.Generator,
    function(color)
        Config.ESP.Colors.Generator = color
    end
)

window:AddColorPicker(
    colorsSection,
    "Pallet Color",
    Config.ESP.Colors.Pallet,
    function(color)
        Config.ESP.Colors.Pallet = color
    end
)

return Window