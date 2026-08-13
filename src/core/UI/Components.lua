local Components = {}
Components.__index = Components

local TweenService = game:GetService("TweenService")

local DEFAULTS = {
    CornerRadius = 7,
    CardHeight = 42,
    Padding = 10,

    AnimationTime = 0.14,
    EnableAnimations = true,
    EnableHover = true,

    Background = Color3.fromRGB(16, 16, 20),
    Secondary = Color3.fromRGB(22, 22, 28),
    Card = Color3.fromRGB(26, 26, 33),

    Accent = Color3.fromRGB(120, 90, 255),
    AccentDark = Color3.fromRGB(91, 65, 210),

    Text = Color3.fromRGB(235, 235, 240),
    MutedText = Color3.fromRGB(145, 145, 155),

    Border = Color3.fromRGB(45, 45, 54),

    Hover = Color3.fromRGB(31, 31, 39),
    Pressed = Color3.fromRGB(36, 36, 46),

    Success = Color3.fromRGB(80, 210, 130),
    Warning = Color3.fromRGB(240, 185, 80),
    Danger = Color3.fromRGB(235, 85, 95),
}

local function create(className, properties)
    local object = Instance.new(className)

    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end

    return object
end

local function copyTable(source)
    local result = {}

    for key, value in pairs(source or {}) do
        result[key] = value
    end

    return result
end

local function safeSet(object, property, value)
    if not object then
        return false
    end

    local success = pcall(function()
        object[property] = value
    end)

    return success
end

function Components.new(options)
    local self = setmetatable({}, Components)

    self.Options = copyTable(DEFAULTS)

    for key, value in pairs(options or {}) do
        self.Options[key] = value
    end

    self.Connections = {}
    self.Objects = {}

    self.Destroyed = false

    return self
end

function Components:_track(connection)
    if connection then
        table.insert(self.Connections, connection)
    end

    return connection
end

function Components:_trackObject(object)
    if object then
        table.insert(self.Objects, object)
    end

    return object
end

function Components:_tween(object, properties, duration)
    if not object or self.Destroyed then
        return nil
    end

    if not self.Options.EnableAnimations then
        for property, value in pairs(properties or {}) do
            safeSet(object, property, value)
        end

        return nil
    end

    local success, tween = pcall(function()
        return TweenService:Create(
            object,
            TweenInfo.new(
                duration or self.Options.AnimationTime,
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            ),
            properties
        )
    end)

    if not success or not tween then
        return nil
    end

    tween:Play()

    return tween
end

function Components:Create(className, properties)
    if self.Destroyed then
        return nil
    end

    return self:_trackObject(
        create(className, properties)
    )
end

function Components:Frame(parent, properties)
    properties = copyTable(properties)
    properties.Parent = parent

    return self:Create("Frame", properties)
end

function Components:TextLabel(parent, properties)
    properties = copyTable(properties)
    properties.Parent = parent

    return self:Create("TextLabel", properties)
end

function Components:TextButton(parent, properties)
    properties = copyTable(properties)
    properties.Parent = parent

    return self:Create("TextButton", properties)
end

function Components:TextBox(parent, properties)
    properties = copyTable(properties)
    properties.Parent = parent

    return self:Create("TextBox", properties)
end

function Components:ScrollingFrame(parent, properties)
    properties = copyTable(properties)
    properties.Parent = parent

    return self:Create("ScrollingFrame", properties)
end

function Components:Corner(parent, radius)
    if not parent then
        return nil
    end

    return self:Create("UICorner", {
        Parent = parent,

        CornerRadius = UDim.new(
            0,
            radius or self.Options.CornerRadius
        )
    })
end

function Components:Stroke(
    parent,
    color,
    thickness,
    transparency
)
    if not parent then
        return nil
    end

    return self:Create("UIStroke", {
        Parent = parent,

        Color =
            color
            or self.Options.Border,

        Thickness =
            thickness
            or 1,

        Transparency =
            transparency
            or 0,

        ApplyStrokeMode =
            Enum.ApplyStrokeMode.Border
    })
end

function Components:Padding(parent, amount)
    if not parent then
        return nil
    end

    amount =
        amount
        or self.Options.Padding

    return self:Create("UIPadding", {
        Parent = parent,

        PaddingTop = UDim.new(0, amount),
        PaddingBottom = UDim.new(0, amount),
        PaddingLeft = UDim.new(0, amount),
        PaddingRight = UDim.new(0, amount)
    })
end

function Components:PaddingXY(
    parent,
    horizontal,
    vertical
)
    if not parent then
        return nil
    end

    horizontal = horizontal or 0
    vertical = vertical or 0

    return self:Create("UIPadding", {
        Parent = parent,

        PaddingTop =
            UDim.new(0, vertical),

        PaddingBottom =
            UDim.new(0, vertical),

        PaddingLeft =
            UDim.new(0, horizontal),

        PaddingRight =
            UDim.new(0, horizontal)
    })
end

function Components:List(
    parent,
    padding,
    horizontalAlignment,
    verticalAlignment
)
    if not parent then
        return nil
    end

    local layout = self:Create(
        "UIListLayout",
        {
            Parent = parent,

            Padding = UDim.new(
                0,
                padding or 6
            ),

            FillDirection =
                Enum.FillDirection.Vertical,

            HorizontalAlignment =
                horizontalAlignment
                or Enum.HorizontalAlignment.Left,

            VerticalAlignment =
                verticalAlignment
                or Enum.VerticalAlignment.Top,

            SortOrder =
                Enum.SortOrder.LayoutOrder
        }
    )

    self:_track(
        layout:GetPropertyChangedSignal(
            "AbsoluteContentSize"
        ):Connect(function()
            if self.Destroyed then
                return
            end

            if not parent
                or not parent.Parent then
                return
            end

            if parent:IsA("ScrollingFrame") then
                parent.CanvasSize =
                    UDim2.new(
                        0,
                        0,
                        0,
                        layout.AbsoluteContentSize.Y + 6
                    )
            end
        end)
    )

    return layout
end

function Components:Grid(
    parent,
    cellSize,
    padding
)
    return self:Create(
        "UIGridLayout",
        {
            Parent = parent,

            CellSize =
                cellSize
                or UDim2.fromOffset(
                    100,
                    40
                ),

            CellPadding =
                padding
                or UDim2.fromOffset(
                    6,
                    6
                ),

            SortOrder =
                Enum.SortOrder.LayoutOrder
        }
    )
end

function Components:CreateCard(
    parent,
    height,
    options
)
    options = options or {}

    local card = self:Frame(
        parent,
        {
            Name =
                options.Name
                or "Card",

            Size =
                options.Size
                or UDim2.new(
                    1,
                    0,
                    0,
                    height
                    or self.Options.CardHeight
                ),

            BackgroundColor3 =
                options.Background
                or self.Options.Card,

            BackgroundTransparency =
                options.Transparency
                or 0,

            BorderSizePixel = 0,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )

    self:Corner(
        card,
        options.CornerRadius
        or self.Options.CornerRadius
    )

    if options.Stroke ~= false then
        self:Stroke(
            card,
            options.Border
            or self.Options.Border,

            options.StrokeThickness
            or 1,

            options.StrokeTransparency
            or 0.75
        )
    end

    return card
end

function Components:AddHover(
    object,
    normalColor,
    hoverColor,
    pressedColor
)
    if not object
        or not object:IsA("GuiButton")
        or not self.Options.EnableHover then

        return object
    end

    normalColor =
        normalColor
        or object.BackgroundColor3

    hoverColor =
        hoverColor
        or self.Options.Hover

    pressedColor =
        pressedColor
        or self.Options.Pressed

    self:_track(
        object.MouseEnter:Connect(function()
            self:_tween(
                object,
                {
                    BackgroundColor3 =
                        hoverColor
                },
                0.1
            )
        end)
    )

    self:_track(
        object.MouseLeave:Connect(function()
            self:_tween(
                object,
                {
                    BackgroundColor3 =
                        normalColor
                },
                0.1
            )
        end)
    )

    self:_track(
        object.MouseButton1Down:Connect(function()
            self:_tween(
                object,
                {
                    BackgroundColor3 =
                        pressedColor
                },
                0.07
            )
        end)
    )

    self:_track(
        object.MouseButton1Up:Connect(function()
            if object:IsMouseOver() then
                self:_tween(
                    object,
                    {
                        BackgroundColor3 =
                            hoverColor
                    },
                    0.07
                )
            else
                self:_tween(
                    object,
                    {
                        BackgroundColor3 =
                            normalColor
                    },
                    0.07
                )
            end
        end)
    )

    return object
end

function Components:CreateButton(
    parent,
    text,
    options
)
    options = options or {}

    local normalColor =
        options.Background
        or self.Options.Card

    local hoverColor =
        options.Hover
        or self.Options.Hover

    local pressedColor =
        options.Pressed
        or self.Options.Pressed

    local button = self:TextButton(
        parent,
        {
            Name =
                options.Name
                or "Button",

            Size =
                options.Size
                or UDim2.new(
                    1,
                    0,
                    0,
                    38
                ),

            BackgroundColor3 =
                normalColor,

            BorderSizePixel = 0,

            AutoButtonColor = false,

            Text =
                tostring(
                    text
                    or options.Text
                    or "Button"
                ),

            TextColor3 =
                options.TextColor
                or self.Options.Text,

            TextSize =
                options.TextSize
                or 12,

            Font =
                options.Font
                or Enum.Font.GothamMedium,

            TextXAlignment =
                options.TextXAlignment
                or Enum.TextXAlignment.Left,

            TextYAlignment =
                options.TextYAlignment
                or Enum.TextYAlignment.Center,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )

    self:Corner(
        button,
        options.CornerRadius
        or self.Options.CornerRadius
    )

    if options.Stroke ~= false then
        self:Stroke(
            button,
            options.Border
            or self.Options.Border,
            options.StrokeThickness
            or 1,
            options.StrokeTransparency
            or 0.8
        )
    end

    self:Padding(
        button,
        options.Padding
        or 10
    )

    self:AddHover(
        button,
        normalColor,
        hoverColor,
        pressedColor
    )

    return button
end

function Components:CreateIconButton(
    parent,
    icon,
    options
)
    options = options or {}

    local normalColor =
        options.Background
        or self.Options.Card

    local hoverColor =
        options.Hover
        or self.Options.Hover

    local button = self:TextButton(
        parent,
        {
            Name =
                options.Name
                or "IconButton",

            Size =
                options.Size
                or UDim2.fromOffset(
                    30,
                    30
                ),

            BackgroundColor3 =
                normalColor,

            BorderSizePixel = 0,

            AutoButtonColor = false,

            Text =
                tostring(icon or ""),

            TextColor3 =
                options.TextColor
                or self.Options.MutedText,

            TextSize =
                options.TextSize
                or 15,

            Font =
                options.Font
                or Enum.Font.GothamBold,

            TextXAlignment =
                Enum.TextXAlignment.Center,

            TextYAlignment =
                Enum.TextYAlignment.Center
        }
    )

    self:Corner(
        button,
        options.CornerRadius
        or 6
    )

    self:_track(
        button.MouseEnter:Connect(function()
            if not self.Options.EnableHover then
                return
            end

            self:_tween(
                button,
                {
                    BackgroundColor3 =
                        hoverColor,

                    TextColor3 =
                        options.HoverTextColor
                        or self.Options.Text
                },
                0.1
            )
        end)
    )

    self:_track(
        button.MouseLeave:Connect(function()
            if not self.Options.EnableHover then
                return
            end

            self:_tween(
                button,
                {
                    BackgroundColor3 =
                        normalColor,

                    TextColor3 =
                        options.TextColor
                        or self.Options.MutedText
                },
                0.1
            )
        end)
    )

    return button
end

function Components:CreateDivider(
    parent,
    options
)
    options = options or {}

    return self:Frame(
        parent,
        {
            Name =
                options.Name
                or "Divider",

            Size =
                UDim2.new(
                    1,
                    0,
                    0,
                    options.Height
                    or 1
                ),

            BackgroundColor3 =
                options.Color
                or self.Options.Border,

            BackgroundTransparency =
                options.Transparency
                or 0,

            BorderSizePixel = 0,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )
end

function Components:CreateText(
    parent,
    text,
    options
)
    options = options or {}

    return self:TextLabel(
        parent,
        {
            Name =
                options.Name
                or "Text",

            Size =
                options.Size
                or UDim2.new(
                    1,
                    0,
                    0,
                    options.Height
                    or 20
                ),

            BackgroundTransparency = 1,

            Text =
                tostring(text or ""),

            TextColor3 =
                options.TextColor
                or self.Options.Text,

            TextSize =
                options.TextSize
                or 12,

            Font =
                options.Font
                or Enum.Font.Gotham,

            TextXAlignment =
                options.TextXAlignment
                or Enum.TextXAlignment.Left,

            TextYAlignment =
                options.TextYAlignment
                or Enum.TextYAlignment.Center,

            TextWrapped =
                options.TextWrapped
                or false,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )
end

function Components:CreateBadge(
    parent,
    text,
    options
)
    options = options or {}

    local badge = self:TextLabel(
        parent,
        {
            Name =
                options.Name
                or "Badge",

            Size =
                options.Size
                or UDim2.fromOffset(
                    options.Width or 58,
                    options.Height or 22
                ),

            BackgroundColor3 =
                options.Background
                or self.Options.Accent,

            BorderSizePixel = 0,

            Text =
                tostring(text or ""),

            TextColor3 =
                options.TextColor
                or Color3.new(1, 1, 1),

            TextSize =
                options.TextSize
                or 9,

            Font =
                options.Font
                or Enum.Font.GothamBold,

            TextXAlignment =
                Enum.TextXAlignment.Center,

            TextYAlignment =
                Enum.TextYAlignment.Center,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )

    self:Corner(
        badge,
        options.CornerRadius or 6
    )

    return badge
end

function Components:CreateToggleVisual(
    parent,
    enabled,
    options
)
    options = options or {}

    local switch = self:Frame(
        parent,
        {
            Name =
                options.Name
                or "Toggle",

            Size =
                options.Size
                or UDim2.fromOffset(
                    38,
                    21
                ),

            BackgroundColor3 =
                enabled
                and (
                    options.EnabledColor
                    or self.Options.Accent
                )
                or (
                    options.DisabledColor
                    or self.Options.Border
                ),

            BorderSizePixel = 0
        }
    )

    self:Corner(switch, 11)

    local knob = self:Frame(
        switch,
        {
            Name = "Knob",

            AnchorPoint =
                Vector2.new(
                    0,
                    0.5
                ),

            Position =
                enabled
                and UDim2.new(
                    1,
                    -19,
                    0.5,
                    0
                )
                or UDim2.new(
                    0,
                    2,
                    0.5,
                    0
                ),

            Size =
                UDim2.fromOffset(
                    17,
                    17
                ),

            BackgroundColor3 =
                options.KnobColor
                or Color3.new(1, 1, 1),

            BorderSizePixel = 0
        }
    )

    self:Corner(knob, 9)

    return switch, knob
end

function Components:SetToggleVisual(
    switch,
    knob,
    enabled,
    options
)
    options = options or {}

    if not switch or not knob then
        return
    end

    local enabledColor =
        options.EnabledColor
        or self.Options.Accent

    local disabledColor =
        options.DisabledColor
        or self.Options.Border

    self:_tween(
        switch,
        {
            BackgroundColor3 =
                enabled
                and enabledColor
                or disabledColor
        }
    )

    self:_tween(
        knob,
        {
            Position =
                enabled
                and UDim2.new(
                    1,
                    -19,
                    0.5,
                    0
                )
                or UDim2.new(
                    0,
                    2,
                    0.5,
                    0
                )
        }
    )
end

function Components:SetTheme(theme)
    if type(theme) ~= "table" then
        return
    end

    for key, value in pairs(theme) do
        self.Options[key] = value
    end
end

function Components:GetTheme()
    return copyTable(self.Options)
end

function Components:GetOption(name)
    return self.Options[name]
end

function Components:SetOption(name, value)
    if name == nil then
        return false
    end

    self.Options[name] = value

    return true
end

function Components:TrackConnection(connection)
    return self:_track(connection)
end

function Components:TrackObject(object)
    return self:_trackObject(object)
end

function Components:Destroy()
    if self.Destroyed then
        return
    end

    self.Destroyed = true

    for _, connection in ipairs(self.Connections) do
        if connection
            and connection.Disconnect then

            pcall(function()
                connection:Disconnect()
            end)
        end
    end

    for _, object in ipairs(self.Objects) do
        if object
            and object.Destroy then

            pcall(function()
                object:Destroy()
            end)
        end
    end

    self.Connections = {}
    self.Objects = {}
end

return Components