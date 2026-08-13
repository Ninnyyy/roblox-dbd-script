```lua
--[[
    Lua Test
    Components.lua

    Central UI component system.

    Responsibilities:
        - UI object creation
        - Centralized Themes.lua integration
        - Nested theme support
        - Runtime theme refresh
        - Rounded corners
        - Borders / strokes
        - Padding
        - Lists / grids
        - Cards
        - Buttons
        - Icon buttons
        - Text
        - Badges
        - Toggles
        - Hover effects
        - Press effects
        - Tween animations
        - Transparency handling
        - UI scaling
        - Font management
        - Effect settings
        - Component tracking
        - Connection cleanup
        - Object cleanup

    IMPORTANT:

        Components.lua does NOT own the application's theme.

        Themes.lua is the source of truth.

        Components may receive a ThemeProvider through:
            Components.new({
                Themes = Themes
            })

        or:

            Components.new({
                Theme = Themes:GetActiveTheme()
            })

        Runtime theme changes can be pushed through:

            Components:SetTheme(theme)

        or:

            Components:RefreshTheme()

        Existing component APIs are preserved.
]]

local TweenService = game:GetService("TweenService")

local Components = {}
Components.__index = Components



-- COMPONENT DEFAULTS


-- These are NOT theme colors.
--
-- They are only compatibility/fallback values used when a theme
-- does not provide the requested setting.
--
-- Theme styling itself belongs to Themes.lua.

local COMPONENT_DEFAULTS = {

    Padding = 10,

    CardHeight = 42,

    ButtonHeight = 38,

    ToggleWidth = 38,

    ToggleHeight = 21,

    ToggleKnobSize = 17,

    IconButtonSize = 30,

    BadgeWidth = 58,

    BadgeHeight = 22,

    TextHeight = 20,

    ListPadding = 6,

    GridPadding = 6,

    AnimationTime = 0.15,

    EnableAnimations = true,

    EnableHover = true,

    CornerRadius = 6,

    BorderThickness = 1,

    WindowTransparency = 0,

    SurfaceTransparency = 0,

    ControlTransparency = 0,

    Scale = 1,
}



-- UTILITY


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


local function safeSet(object, property, value)

    if not object then
        return false
    end

    local success =
        pcall(function()
            object[property] = value
        end)

    return success
end


local function safeGet(object, property)

    if not object then
        return nil
    end

    local success, value =
        pcall(function()
            return object[property]
        end)

    if success then
        return value
    end

    return nil
end


local function clamp(
    value,
    minimum,
    maximum,
    fallback
)

    value = tonumber(value)

    if not value then
        value = fallback
    end

    return math.clamp(
        value,
        minimum,
        maximum
    )
end


local function create(className, properties)

    local success, object =
        pcall(
            Instance.new,
            className
        )

    if not success or not object then

        warn(
            "[Lua Test] Components failed to create:",
            className
        )

        return nil
    end

    for property, value in pairs(
        properties or {}
    ) do

        pcall(function()
            object[property] = value
        end)

    end

    return object
end


local function getPath(
    root,
    path,
    fallback
)

    if type(root) ~= "table"
        or type(path) ~= "string" then

        return fallback
    end

    local current = root

    for part in string.gmatch(
        path,
        "[^%.]+"
    ) do

        if type(current) ~= "table"
            or current[part] == nil then

            return fallback
        end

        current = current[part]
    end

    if current == nil then
        return fallback
    end

    return current
end


local function firstValue(
    root,
    paths,
    fallback
)

    for _, path in ipairs(paths or {}) do

        local value =
            getPath(
                root,
                path,
                nil
            )

        if value ~= nil then
            return value
        end
    end

    return fallback
end



-- CONSTRUCTOR


function Components.new(options)

    options = options or {}

    local self =
        setmetatable(
            {},
            Components
        )

    self.Options =
        copyTable(
            COMPONENT_DEFAULTS
        )

    self.Themes =
        options.Themes
        or options.ThemeManager
        or options.ThemeProvider

    self.Theme =
        {}

    self.Connections = {}

    self.Objects = {}

    self.Components = {}

    self.Destroyed = false

    self._ThemeConnection = nil

    -- Compatibility:
    --
    -- Existing code may still pass:
    --
    -- Theme = {...}
    --
    -- We support that without making it the permanent source
    -- of truth.

    if type(options.Theme) == "table" then

        self.Theme =
            copyTable(
                options.Theme
            )

    elseif self.Themes then

        self:_pullThemeFromProvider()

    end

    -- Component-specific overrides are still supported.

    for key, value in pairs(options) do

        if key ~= "Theme"
            and key ~= "Themes"
            and key ~= "ThemeManager"
            and key ~= "ThemeProvider" then

            self.Options[key] = value

        end
    end

    self:_syncThemeOptions()

    self:_connectThemeProvider()

    return self
end



-- THEME PROVIDER


function Components:_pullThemeFromProvider()

    local provider = self.Themes

    if not provider then
        return false
    end

    local theme

    -- GetActiveTheme()

    pcall(function()

        if type(provider.GetActiveTheme) == "function" then

            theme =
                provider:GetActiveTheme()

        end

    end)

    -- GetTheme()

    if type(theme) ~= "table" then

        pcall(function()

            if type(provider.GetTheme) == "function" then

                theme =
                    provider:GetTheme()

            end

        end)

    end

    -- ActiveTheme property

    if type(theme) ~= "table" then

        local success, value =
            pcall(function()
                return provider.ActiveTheme
            end)

        if success
            and type(value) == "table" then

            theme = value

        end

    end

    -- Theme property

    if type(theme) ~= "table" then

        local success, value =
            pcall(function()
                return provider.Theme
            end)

        if success
            and type(value) == "table" then

            theme = value

        end

    end

    if type(theme) ~= "table" then
        return false
    end

    self.Theme =
        copyTable(theme)

    return true
end


function Components:_connectThemeProvider()

    local provider = self.Themes

    if not provider then
        return
    end

    local signal

    -- ThemeChanged

    pcall(function()

        if provider.ThemeChanged then
            signal =
                provider.ThemeChanged
        end

    end)

    -- Changed

    if not signal then

        pcall(function()

            if provider.Changed then
                signal =
                    provider.Changed
            end

        end)

    end

    -- OnThemeChanged

    if not signal then

        pcall(function()

            if provider.OnThemeChanged then
                signal =
                    provider.OnThemeChanged
            end

        end)

    end

    if signal
        and signal.Connect then

        self._ThemeConnection =
            self:_track(
                signal:Connect(
                    function(theme)

                        if self.Destroyed then
                            return
                        end

                        if type(theme) == "table" then

                            self.Theme =
                                copyTable(theme)

                        else

                            self:_pullThemeFromProvider()

                        end

                        self:_syncThemeOptions()

                        self:RefreshTheme()

                    end
                )
            )

    end
end



-- THEME ACCESS


function Components:GetThemeValue(
    path,
    default
)

    if type(path) ~= "string" then
        return default
    end

    local value =
        getPath(
            self.Theme,
            path,
            nil
        )

    if value ~= nil then
        return value
    end

    return default
end


function Components:SetThemeValue(
    path,
    value
)

    if type(path) ~= "string"
        or path == "" then

        return false
    end

    local parts = {}

    for part in string.gmatch(
        path,
        "[^%.]+"
    ) do

        table.insert(
            parts,
            part
        )

    end

    if #parts == 0 then
        return false
    end

    local current =
        self.Theme

    for index = 1, #parts - 1 do

        local part =
            parts[index]

        if type(current[part])
            ~= "table" then

            current[part] = {}

        end

        current =
            current[part]

    end

    current[
        parts[#parts]
    ] = value

    self:_syncThemeOptions()

    self:RefreshTheme()

    return true
end


function Components:SetTheme(theme)

    if type(theme) ~= "table" then
        return false
    end

    self.Theme =
        copyTable(theme)

    self:_syncThemeOptions()

    self:RefreshTheme()

    return true
end


function Components:MergeTheme(theme)

    if type(theme) ~= "table" then
        return false
    end

    mergeTables(
        self.Theme,
        theme
    )

    self:_syncThemeOptions()

    self:RefreshTheme()

    return true
end


function Components:GetTheme()

    return copyTable(
        self.Theme
    )
end


function Components:RefreshTheme()

    if self.Destroyed then
        return false
    end

    self:_pullThemeFromProvider()

    self:_syncThemeOptions()

    for _, record in ipairs(
        self.Components
    ) do

        if record
            and record.Refresh then

            pcall(function()
                record:Refresh()
            end)

        end

    end

    return true
end



-- THEME SYNCHRONIZATION


function Components:_syncThemeOptions()

    local theme =
        self.Theme

    -- Colors

    self.Options.Accent =
        firstValue(
            theme,
            {
                "Accent",
                "Colors.Accent",
                "Color.Accent"
            },
            self.Options.Accent
        )

    self.Options.AccentDark =
        firstValue(
            theme,
            {
                "AccentDark",
                "Colors.AccentDark",
                "Color.AccentDark"
            },
            self.Options.Accent
        )

    self.Options.Background =
        firstValue(
            theme,
            {
                "Background",
                "Colors.Background",
                "Color.Background"
            },
            self.Options.Background
        )

    self.Options.Secondary =
        firstValue(
            theme,
            {
                "BackgroundSecondary",
                "Secondary",
                "Colors.BackgroundSecondary",
                "Color.BackgroundSecondary"
            },
            self.Options.Secondary
        )

    self.Options.Card =
        firstValue(
            theme,
            {
                "Surface",
                "Colors.Surface",
                "Color.Surface"
            },
            self.Options.Card
        )

    self.Options.Hover =
        firstValue(
            theme,
            {
                "SurfaceHover",
                "Hover",
                "Colors.SurfaceHover",
                "Color.SurfaceHover"
            },
            self.Options.Hover
        )

    self.Options.Text =
        firstValue(
            theme,
            {
                "Text",
                "Colors.Text",
                "Color.Text"
            },
            self.Options.Text
        )

    self.Options.MutedText =
        firstValue(
            theme,
            {
                "TextSecondary",
                "MutedText",
                "Colors.TextSecondary",
                "Color.TextSecondary"
            },
            self.Options.MutedText
        )

    self.Options.DisabledText =
        firstValue(
            theme,
            {
                "TextDisabled",
                "DisabledText",
                "Colors.TextDisabled",
                "Color.TextDisabled"
            },
            self.Options.DisabledText
        )

    self.Options.Border =
        firstValue(
            theme,
            {
                "Border",
                "Colors.Border",
                "Color.Border"
            },
            self.Options.Border
        )

    self.Options.Divider =
        firstValue(
            theme,
            {
                "Divider",
                "Colors.Divider",
                "Color.Divider"
            },
            self.Options.Divider
        )

    self.Options.Success =
        firstValue(
            theme,
            {
                "Success",
                "Colors.Success",
                "Color.Success"
            },
            self.Options.Success
        )

    self.Options.Warning =
        firstValue(
            theme,
            {
                "Warning",
                "Colors.Warning",
                "Color.Warning"
            },
            self.Options.Warning
        )

    self.Options.Danger =
        firstValue(
            theme,
            {
                "Error",
                "Danger",
                "Colors.Error",
                "Color.Error"
            },
            self.Options.Danger
        )


    --==========================================================
    -- COMPONENT DIMENSIONS
    --==========================================================

    self.Options.CornerRadius =
        tonumber(
            firstValue(
                theme,
                {
                    "Window.CornerRadius",
                    "CornerRadius",
                    "Dimensions.CornerRadius"
                },
                self.Options.CornerRadius
            )
        )
        or self.Options.CornerRadius

    self.Options.BorderThickness =
        tonumber(
            firstValue(
                theme,
                {
                    "BorderThickness",
                    "Border.Thickness",
                    "Dimensions.BorderThickness"
                },
                self.Options.BorderThickness
            )
        )
        or self.Options.BorderThickness


    -- Button.Height

    self.Options.ButtonHeight =
        tonumber(
            firstValue(
                theme,
                {
                    "Button.Height",
                    "Buttons.Height",
                    "Controls.Button.Height"
                },
                self.Options.ButtonHeight
            )
        )
        or self.Options.ButtonHeight


    -- Toggle.Width

    self.Options.ToggleWidth =
        tonumber(
            firstValue(
                theme,
                {
                    "Toggle.Width",
                    "Toggles.Width",
                    "Controls.Toggle.Width"
                },
                self.Options.ToggleWidth
            )
        )
        or self.Options.ToggleWidth


    -- Toggle.Height

    self.Options.ToggleHeight =
        tonumber(
            firstValue(
                theme,
                {
                    "Toggle.Height",
                    "Toggles.Height",
                    "Controls.Toggle.Height"
                },
                self.Options.ToggleHeight
            )
        )
        or self.Options.ToggleHeight


    -- Toggle knob

    self.Options.ToggleKnobSize =
        tonumber(
            firstValue(
                theme,
                {
                    "Toggle.KnobSize",
                    "Toggles.KnobSize"
                },
                self.Options.ToggleKnobSize
            )
        )
        or self.Options.ToggleKnobSize


    -- Card height

    self.Options.CardHeight =
        tonumber(
            firstValue(
                theme,
                {
                    "Card.Height",
                    "Cards.Height"
                },
                self.Options.CardHeight
            )
        )
        or self.Options.CardHeight


    -- Padding

    self.Options.Padding =
        tonumber(
            firstValue(
                theme,
                {
                    "Spacing.Padding",
                    "Padding"
                },
                self.Options.Padding
            )
        )
        or self.Options.Padding


    --==========================================================
    -- TRANSPARENCY
    --==========================================================

    self.Options.WindowTransparency =
        tonumber(
            firstValue(
                theme,
                {
                    "Transparency.Window",
                    "Window.Transparency"
                },
                self.Options.WindowTransparency
            )
        )
        or 0

    self.Options.SurfaceTransparency =
        tonumber(
            firstValue(
                theme,
                {
                    "Transparency.Surface",
                    "Surface.Transparency"
                },
                self.Options.SurfaceTransparency
            )
        )
        or 0

    self.Options.ControlTransparency =
        tonumber(
            firstValue(
                theme,
                {
                    "Transparency.Control",
                    "Control.Transparency"
                },
                self.Options.ControlTransparency
            )
        )
        or 0


    --==========================================================
    -- ANIMATION
    --==========================================================

    local animationEnabled =
        firstValue(
            theme,
            {
                "Animation.Enabled",
                "Animations.Enabled"
            },
            self.Options.EnableAnimations
        )

    self.Options.EnableAnimations =
        animationEnabled ~= false

    self.Options.AnimationSpeed =
        tonumber(
            firstValue(
                theme,
                {
                    "Animation.Speed",
                    "Animation.Duration",
                    "Animations.Speed"
                },
                self.Options.AnimationTime
            )
        )
        or self.Options.AnimationTime


    --==========================================================
    -- EFFECTS
    --==========================================================

    self.Options.HoverHighlight =
        firstValue(
            theme,
            {
                "Effects.HoverHighlight",
                "Effects.Hover",
                "HoverHighlight"
            },
            true
        )

    self.Options.PressAnimation =
        firstValue(
            theme,
            {
                "Effects.PressAnimation",
                "Effects.Press",
                "PressAnimation"
            },
            true
        )

    self.Options.Glow =
        firstValue(
            theme,
            {
                "Effects.Glow"
            },
            false
        )

    self.Options.Blur =
        firstValue(
            theme,
            {
                "Effects.Blur"
            },
            false
        )

    self.Options.SmoothScrolling =
        firstValue(
            theme,
            {
                "Effects.SmoothScrolling",
                "Effects.SmoothScroll"
            },
            true
        )

    self.Options.SmoothDragging =
        firstValue(
            theme,
            {
                "Effects.SmoothDragging",
                "Effects.SmoothDrag"
            },
            true
        )


    --==========================================================
    -- SCALE
    --==========================================================

    self.Options.Scale =
        tonumber(
            firstValue(
                theme,
                {
                    "Scale",
                    "UI.Scale",
                    "UIScale.Value",
                    "Window.Scale"
                },
                self.Options.Scale
            )
        )
        or self.Options.Scale

    self.Options.Scale =
        clamp(
            self.Options.Scale,
            0.5,
            2,
            1
        )


    --==========================================================
    -- FONTS
    --==========================================================

    self.Options.Fonts =
        firstValue(
            theme,
            {
                "Fonts",
                "Typography.Fonts"
            },
            self.Options.Fonts
        )

    return true
end



-- FONT RESOLUTION


function Components:GetFont(
    name,
    fallback
)

    local fonts =
        self.Options.Fonts

    if type(fonts) == "table" then

        local value =
            fonts[name]

        if value ~= nil then

            if typeof(value) == "EnumItem" then
                return value
            end

            if type(value) == "string" then

                local success, font =
                    pcall(function()

                        return Enum.Font[value]

                    end)

                if success and font then
                    return font
                end

            end
        end
    end

    if typeof(fallback) == "EnumItem" then
        return fallback
    end

    if type(fallback) == "string" then

        local success, font =
            pcall(function()

                return Enum.Font[fallback]

            end)

        if success and font then
            return font
        end
    end

    return Enum.Font.Gotham
end



-- SCALE


function Components:ScaleValue(value)

    value =
        tonumber(value)
        or 0

    return math.round(
        value * (
            tonumber(self.Options.Scale)
            or 1
        )
    )
end


function Components:ScaleUDim2(size)

    if typeof(size) ~= "UDim2" then
        return size
    end

    local scale =
        tonumber(
            self.Options.Scale
        )
        or 1

    return UDim2.new(
        size.X.Scale,
        math.round(
            size.X.Offset * scale
        ),
        size.Y.Scale,
        math.round(
            size.Y.Offset * scale
        )
    )
end


function Components:SetScale(scale)

    scale =
        clamp(
            scale,
            0.5,
            2,
            1
        )

    self.Options.Scale =
        scale

    self:RefreshTheme()

    return true
end


function Components:GetScale()

    return self.Options.Scale
end



-- TRACKING


function Components:_track(connection)

    if connection then

        table.insert(
            self.Connections,
            connection
        )

    end

    return connection
end


function Components:_trackObject(object)

    if object then

        table.insert(
            self.Objects,
            object
        )

    end

    return object
end


function Components:_trackComponent(record)

    if record then

        table.insert(
            self.Components,
            record
        )

    end

    return record
end


function Components:TrackConnection(connection)

    return self:_track(
        connection
    )
end


function Components:TrackObject(object)

    return self:_trackObject(
        object
    )
end



-- TWEEN


function Components:_tween(
    object,
    properties,
    duration
)

    if not object
        or self.Destroyed then

        return nil
    end

    if self.Options.EnableAnimations == false then

        for property, value in pairs(
            properties or {}
        ) do

            safeSet(
                object,
                property,
                value
            )

        end

        return nil
    end

    local time =
        tonumber(duration)
        or tonumber(
            self.Options.AnimationSpeed
        )
        or self.Options.AnimationTime

    time =
        math.max(
            time or 0.15,
            0
        )

    local success, tween =
        pcall(function()

            return TweenService:Create(

                object,

                TweenInfo.new(
                    time,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                ),

                properties
            )

        end)

    if not success
        or not tween then

        return nil
    end

    pcall(function()
        tween:Play()
    end)

    return tween
end


function Components:Tween(
    object,
    properties,
    duration
)

    return self:_tween(
        object,
        properties,
        duration
    )
end



-- BASIC OBJECTS


function Components:Create(
    className,
    properties
)

    if self.Destroyed then
        return nil
    end

    return self:_trackObject(
        create(
            className,
            properties
        )
    )
end


function Components:Frame(
    parent,
    properties
)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    return self:Create(
        "Frame",
        properties
    )
end


function Components:TextLabel(
    parent,
    properties
)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    return self:Create(
        "TextLabel",
        properties
    )
end


function Components:TextButton(
    parent,
    properties
)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    return self:Create(
        "TextButton",
        properties
    )
end


function Components:TextBox(
    parent,
    properties
)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    return self:Create(
        "TextBox",
        properties
    )
end


function Components:ScrollingFrame(
    parent,
    properties
)

    properties =
        copyTable(properties)

    properties.Parent =
        parent

    return self:Create(
        "ScrollingFrame",
        properties
    )
end



-- CORNER


function Components:Corner(
    parent,
    radius
)

    if not parent then
        return nil
    end

    radius =
        radius
        or self.Options.CornerRadius

    radius =
        clamp(
            radius,
            0,
            100,
            self.Options.CornerRadius
        )

    return self:Create(
        "UICorner",
        {
            Parent = parent,

            CornerRadius =
                UDim.new(
                    0,
                    self:ScaleValue(radius)
                )
        }
    )
end



-- STROKE


function Components:Stroke(
    parent,
    color,
    thickness,
    transparency
)

    if not parent then
        return nil
    end

    return self:Create(
        "UIStroke",
        {
            Parent = parent,

            Color =
                color
                or self.Options.Border,

            Thickness =
                thickness
                or self.Options.BorderThickness,

            Transparency =
                transparency
                or 0,

            ApplyStrokeMode =
                Enum.ApplyStrokeMode.Border
        }
    )
end



-- PADDING


function Components:Padding(
    parent,
    amount
)

    if not parent then
        return nil
    end

    amount =
        amount
        or self.Options.Padding

    amount =
        self:ScaleValue(amount)

    return self:Create(
        "UIPadding",
        {
            Parent = parent,

            PaddingTop =
                UDim.new(
                    0,
                    amount
                ),

            PaddingBottom =
                UDim.new(
                    0,
                    amount
                ),

            PaddingLeft =
                UDim.new(
                    0,
                    amount
                ),

            PaddingRight =
                UDim.new(
                    0,
                    amount
                )
        }
    )
end


function Components:PaddingXY(
    parent,
    horizontal,
    vertical
)

    if not parent then
        return nil
    end

    horizontal =
        self:ScaleValue(
            horizontal or 0
        )

    vertical =
        self:ScaleValue(
            vertical or 0
        )

    return self:Create(
        "UIPadding",
        {
            Parent = parent,

            PaddingTop =
                UDim.new(
                    0,
                    vertical
                ),

            PaddingBottom =
                UDim.new(
                    0,
                    vertical
                ),

            PaddingLeft =
                UDim.new(
                    0,
                    horizontal
                ),

            PaddingRight =
                UDim.new(
                    0,
                    horizontal
                )
        }
    )
end



-- LIST


function Components:List(
    parent,
    padding,
    horizontalAlignment,
    verticalAlignment
)

    if not parent then
        return nil
    end

    local layout =
        self:Create(
            "UIListLayout",
            {
                Parent = parent,

                Padding =
                    UDim.new(
                        0,
                        self:ScaleValue(
                            padding
                            or self.Options.ListPadding
                        )
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

    if layout then

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

                if parent:IsA(
                    "ScrollingFrame"
                ) then

                    parent.CanvasSize =
                        UDim2.new(
                            0,
                            0,
                            0,
                            layout
                                .AbsoluteContentSize
                                .Y
                                + self:ScaleValue(6)
                        )

                end

            end)
        )

    end

    return layout
end



-- GRID


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
                    self:ScaleValue(100),
                    self:ScaleValue(40)
                ),

            CellPadding =
                padding
                or UDim2.fromOffset(
                    self:ScaleValue(6),
                    self:ScaleValue(6)
                ),

            SortOrder =
                Enum.SortOrder.LayoutOrder
        }
    )
end



-- CARD


function Components:CreateCard(
    parent,
    height,
    options
)

    options =
        options
        or {}

    local card =
        self:Frame(
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
                        self:ScaleValue(
                            height
                            or self.Options.CardHeight
                        )
                    ),

                BackgroundColor3 =
                    options.Background
                    or self.Options.Card,

                BackgroundTransparency =
                    options.Transparency
                    ~= nil
                    and options.Transparency
                    or self.Options.SurfaceTransparency,

                BorderSizePixel =
                    0,

                LayoutOrder =
                    options.LayoutOrder
                    or 0
            }
        )

    if not card then
        return nil
    end

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
            or self.Options.BorderThickness,

            options.StrokeTransparency
            ~= nil
            and options.StrokeTransparency
            or 0.75
        )

    end

    return card
end



-- HOVER


function Components:AddHover(
    object,
    normalColor,
    hoverColor,
    pressedColor
)

    if not object
        or not object:IsA("GuiButton") then

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
        or self.Options.AccentDark


    self:_track(
        object.MouseEnter:Connect(
            function()

                if self.Options.EnableHover == false
                    or self.Options.HoverHighlight == false then

                    return
                end

                self:_tween(
                    object,
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
        object.MouseLeave:Connect(
            function()

                if self.Options.EnableHover == false then
                    return
                end

                self:_tween(
                    object,
                    {
                        BackgroundColor3 =
                            normalColor
                    },
                    0.10
                )

            end
        )
    )


    self:_track(
        object.MouseButton1Down:Connect(
            function()

                if self.Options.PressAnimation == false then
                    return
                end

                self:_tween(
                    object,
                    {
                        BackgroundColor3 =
                            pressedColor
                    },
                    0.07
                )

            end
        )
    )


    self:_track(
        object.MouseButton1Up:Connect(
            function()

                if self.Options.EnableHover == false then
                    return
                end

                local mouseOver =
                    false

                pcall(function()

                    mouseOver =
                        object:IsMouseOver()

                end)

                self:_tween(
                    object,
                    {
                        BackgroundColor3 =
                            mouseOver
                            and hoverColor
                            or normalColor
                    },
                    0.07
                )

            end
        )
    )

    return object
end



-- BUTTON


function Components:CreateButton(
    parent,
    text,
    options
)

    options =
        options
        or {}

    local normalColor =
        options.Background
        or self.Options.Card

    local hoverColor =
        options.Hover
        or self.Options.Hover

    local pressedColor =
        options.Pressed
        or self.Options.AccentDark

    local button =
        self:TextButton(
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
                        self:ScaleValue(
                            options.Height
                            or self.Options.ButtonHeight
                        )
                    ),

                BackgroundColor3 =
                    normalColor,

                BackgroundTransparency =
                    options.Transparency
                    ~= nil
                    and options.Transparency
                    or self.Options.ControlTransparency,

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

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
                    or self:GetFont(
                        "Button",
                        Enum.Font.GothamMedium
                    ),

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

    if not button then
        return nil
    end

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
            or self.Options.BorderThickness,

            options.StrokeTransparency
            ~= nil
            and options.StrokeTransparency
            or 0.8
        )

    end

    self:Padding(
        button,
        options.Padding
        or self.Options.Padding
    )

    self:AddHover(
        button,
        normalColor,
        hoverColor,
        pressedColor
    )

    return button
end



-- ICON BUTTON


function Components:CreateIconButton(
    parent,
    icon,
    options
)

    options =
        options
        or {}

    local normalColor =
        options.Background
        or self.Options.Card

    local hoverColor =
        options.Hover
        or self.Options.Hover

    local button =
        self:TextButton(
            parent,
            {
                Name =
                    options.Name
                    or "IconButton",

                Size =
                    options.Size
                    or UDim2.fromOffset(
                        self:ScaleValue(
                            options.Width
                            or self.Options.IconButtonSize
                        ),
                        self:ScaleValue(
                            options.Height
                            or self.Options.IconButtonSize
                        )
                    ),

                BackgroundColor3 =
                    normalColor,

                BackgroundTransparency =
                    options.Transparency
                    ~= nil
                    and options.Transparency
                    or self.Options.ControlTransparency,

                BorderSizePixel =
                    0,

                AutoButtonColor =
                    false,

                Text =
                    tostring(
                        icon
                        or ""
                    ),

                TextColor3 =
                    options.TextColor
                    or self.Options.MutedText,

                TextSize =
                    options.TextSize
                    or 15,

                Font =
                    options.Font
                    or self:GetFont(
                        "Icon",
                        Enum.Font.GothamBold
                    ),

                TextXAlignment =
                    Enum.TextXAlignment.Center,

                TextYAlignment =
                    Enum.TextYAlignment.Center
            }
        )

    if not button then
        return nil
    end

    self:Corner(
        button,
        options.CornerRadius
        or self.Options.CornerRadius
    )

    if options.Stroke then

        self:Stroke(
            button,

            options.Border
            or self.Options.Border,

            options.StrokeThickness
            or self.Options.BorderThickness,

            options.StrokeTransparency
            ~= nil
            and options.StrokeTransparency
            or 0.8
        )

    end

    self:_track(
        button.MouseEnter:Connect(
            function()

                if not self.Options.EnableHover
                    or not self.Options.HoverHighlight then

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
                    0.10
                )

            end
        )
    )

    self:_track(
        button.MouseLeave:Connect(
            function()

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
                    0.10
                )

            end
        )
    )

    return button
end



-- DIVIDER


function Components:CreateDivider(
    parent,
    options
)

    options =
        options
        or {}

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
                or self.Options.Divider,

            BackgroundTransparency =
                options.Transparency
                ~= nil
                and options.Transparency
                or 0,

            BorderSizePixel =
                0,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )
end



-- TEXT


function Components:CreateText(
    parent,
    text,
    options
)

    options =
        options
        or {}

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
                    self:ScaleValue(
                        options.Height
                        or self.Options.TextHeight
                    )
                ),

            BackgroundTransparency =
                1,

            Text =
                tostring(
                    text
                    or ""
                ),

            TextColor3 =
                options.TextColor
                or self.Options.Text,

            TextSize =
                options.TextSize
                or 12,

            Font =
                options.Font
                or self:GetFont(
                    "Text",
                    Enum.Font.Gotham
                ),

            TextXAlignment =
                options.TextXAlignment
                or Enum.TextXAlignment.Left,

            TextYAlignment =
                options.TextYAlignment
                or Enum.TextYAlignment.Center,

            TextWrapped =
                options.TextWrapped
                or false,

            TextTruncate =
                options.TextTruncate
                or Enum.TextTruncate.None,

            LayoutOrder =
                options.LayoutOrder
                or 0
        }
    )
end



-- BADGE


function Components:CreateBadge(
    parent,
    text,
    options
)

    options =
        options
        or {}

    local badge =
        self:TextLabel(
            parent,
            {
                Name =
                    options.Name
                    or "Badge",

                Size =
                    options.Size
                    or UDim2.fromOffset(
                        self:ScaleValue(
                            options.Width
                            or self.Options.BadgeWidth
                        ),

                        self:ScaleValue(
                            options.Height
                            or self.Options.BadgeHeight
                        )
                    ),

                BackgroundColor3 =
                    options.Background
                    or self.Options.Accent,

                BackgroundTransparency =
                    options.Transparency
                    ~= nil
                    and options.Transparency
                    or 0,

                BorderSizePixel =
                    0,

                Text =
                    tostring(
                        text
                        or ""
                    ),

                TextColor3 =
                    options.TextColor
                    or Color3.new(
                        1,
                        1,
                        1
                    ),

                TextSize =
                    options.TextSize
                    or 9,

                Font =
                    options.Font
                    or self:GetFont(
                        "Badge",
                        Enum.Font.GothamBold
                    ),

                TextXAlignment =
                    Enum.TextXAlignment.Center,

                TextYAlignment =
                    Enum.TextYAlignment.Center,

                LayoutOrder =
                    options.LayoutOrder
                    or 0
            }
        )

    if not badge then
        return nil
    end

    self:Corner(
        badge,
        options.CornerRadius
        or self.Options.CornerRadius
    )

    return badge
end



-- TOGGLE


function Components:CreateToggleVisual(
    parent,
    enabled,
    options
)

    options =
        options
        or {}

    local width =
        options.Width
        or self.Options.ToggleWidth

    local height =
        options.Height
        or self.Options.ToggleHeight

    local knobSize =
        options.KnobSize
        or self.Options.ToggleKnobSize

    local switch =
        self:Frame(
            parent,
            {
                Name =
                    options.Name
                    or "Toggle",

                Size =
                    options.Size
                    or UDim2.fromOffset(
                        self:ScaleValue(width),
                        self:ScaleValue(height)
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

                BackgroundTransparency =
                    options.Transparency
                    ~= nil
                    and options.Transparency
                    or self.Options.ControlTransparency,

                BorderSizePixel =
                    0
            }
        )

    if not switch then
        return nil, nil
    end

    self:Corner(
        switch,
        height / 2
    )

    local knob =
        self:Frame(
            switch,
            {
                Name =
                    "Knob",

                AnchorPoint =
                    Vector2.new(
                        0,
                        0.5
                    ),

                Position =
                    enabled
                    and UDim2.new(
                        1,
                        -self:ScaleValue(
                            knobSize + 2
                        ),
                        0.5,
                        0
                    )
                    or UDim2.new(
                        0,
                        self:ScaleValue(2),
                        0.5,
                        0
                    ),

                Size =
                    UDim2.fromOffset(
                        self:ScaleValue(knobSize),
                        self:ScaleValue(knobSize)
                    ),

                BackgroundColor3 =
                    options.KnobColor
                    or Color3.new(
                        1,
                        1,
                        1
                    ),

                BorderSizePixel =
                    0
            }
        )

    if knob then

        self:Corner(
            knob,
            knobSize / 2
        )

    end

    return switch, knob
end


function Components:SetToggleVisual(
    switch,
    knob,
    enabled,
    options
)

    options =
        options
        or {}

    if not switch
        or not knob then

        return
    end

    local width =
        options.Width
        or self.Options.ToggleWidth

    local knobSize =
        options.KnobSize
        or self.Options.ToggleKnobSize

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
                    -self:ScaleValue(
                        knobSize + 2
                    ),
                    0.5,
                    0
                )
                or UDim2.new(
                    0,
                    self:ScaleValue(2),
                    0.5,
                    0
                )
        }
    )
end



-- VISUAL HELPERS


function Components:SetVisible(
    object,
    visible
)

    if not object then
        return false
    end

    return safeSet(
        object,
        "Visible",
        visible == true
    )
end


function Components:SetEnabled(
    object,
    enabled
)

    if not object then
        return false
    end

    return safeSet(
        object,
        "Active",
        enabled == true
    )
end


function Components:SetTransparency(
    object,
    transparency
)

    if not object then
        return false
    end

    transparency =
        clamp(
            transparency,
            0,
            1,
            0
        )

    return safeSet(
        object,
        "BackgroundTransparency",
        transparency
    )
end


function Components:SetTextColor(
    object,
    color
)

    if not object then
        return false
    end

    return safeSet(
        object,
        "TextColor3",
        color
    )
end


function Components:SetBackground(
    object,
    color
)

    if not object then
        return false
    end

    return safeSet(
        object,
        "BackgroundColor3",
        color
    )
end


function Components:SetStroke(
    object,
    color,
    thickness,
    transparency
)

    if not object then
        return false
    end

    local stroke =
        object:FindFirstChildOfClass(
            "UIStroke"
        )

    if not stroke then

        stroke =
            self:Stroke(
                object,
                color,
                thickness,
                transparency
            )

    else

        safeSet(
            stroke,
            "Color",
            color
            or self.Options.Border
        )

        safeSet(
            stroke,
            "Thickness",
            thickness
            or self.Options.BorderThickness
        )

        safeSet(
            stroke,
            "Transparency",
            transparency
            ~= nil
            and transparency
            or 0
        )

    end

    return stroke ~= nil
end



-- THEME COLORS


function Components:GetColor(
    name,
    fallback
)

    local value =
        self.Options[name]

    if value ~= nil then
        return value
    end

    return fallback
end


function Components:GetAccent()

    return self.Options.Accent
end


function Components:GetBackground()

    return self.Options.Background
end


function Components:GetSurface()

    return self.Options.Card
end


function Components:GetText()

    return self.Options.Text
end


function Components:GetSecondaryText()

    return self.Options.MutedText
end


function Components:GetBorder()

    return self.Options.Border
end



-- RESET


function Components:ResetTheme()

    if self.Themes then

        pcall(function()

            if type(self.Themes.Reset) == "function" then

                self.Themes:Reset()

            end

        end)

        self:_pullThemeFromProvider()

    else

        self.Theme = {}

    end

    self:_syncThemeOptions()

    self:RefreshTheme()

    return true
end


function Components:ResetOptions()

    self.Options =
        copyTable(
            COMPONENT_DEFAULTS
        )

    self:_syncThemeOptions()

    self:RefreshTheme()

    return true
end



-- DESTROY


function Components:Destroy()

    if self.Destroyed then
        return
    end

    self.Destroyed = true

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

    self.Components = {}

    self.Themes = nil

    self.Theme = nil

end


return Components