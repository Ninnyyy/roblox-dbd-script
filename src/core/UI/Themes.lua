--[[
    Lua Test
    Themes.lua

  Responsibilities:
        - Theme presets
        - Active theme management
        - Runtime theme switching
        - Custom themes
        - Color management
        - Typography
        - Component dimensions
        - Transparency
        - Animation settings
        - UI scaling
        - Visual effects
        - Theme change signals
        - Theme validation
        - Theme cloning
        - Theme reset
        - Safe fallback values

]]

local Themes = {
    Name = "Themes",

    Description = "Central UI theme and styling engine",

    Category = "UI",

    Dependencies = {},

    Initialized = false,

    CurrentTheme = "Midnight",

    Themes = {},

    CustomThemes = {},

    Connections = {},

    _initialized = false,
}




-- Helpers


local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result = pcall(
        callback,
        ...
    )

    if not success then
        warn(
            "[Lua Test] Themes error:",
            result
        )

        return false, result
    end

    return true, result
end


local function IsColor3(value)
    return typeof(value) == "Color3"
end


local function IsNumber(value)
    return type(value) == "number"
        and value == value
end


local function Clamp(value, minimum, maximum, fallback)
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


local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] then
        return seen[value]
    end

    local copy = {}

    seen[value] = copy

    for key, child in pairs(value) do
        copy[
            DeepCopy(key, seen)
        ] = DeepCopy(child, seen)
    end

    return copy
end


local function DeepMerge(base, override)
    local result = DeepCopy(base)

    if type(override) ~= "table" then
        return result
    end

    for key, value in pairs(override) do
        if type(value) == "table"
            and type(result[key]) == "table" then

            result[key] =
                DeepMerge(
                    result[key],
                    value
                )
        else
            result[key] = value
        end
    end

    return result
end


local function SplitPath(path)
    local parts = {}

    for part in string.gmatch(
        tostring(path),
        "[^%.]+"
    ) do
        table.insert(
            parts,
            part
        )
    end

    return parts
end


local function GetPath(root, path)
    if path == nil
        or path == "" then

        return root
    end

    local current = root

    for _, part in ipairs(
        SplitPath(path)
    ) do

        if type(current) ~= "table" then
            return nil
        end

        current =
            current[part]

        if current == nil then
            return nil
        end
    end

    return current
end


local function SetPath(root, path, value)
    local parts =
        SplitPath(path)

    if #parts == 0 then
        return false
    end

    local current = root

    for index = 1, #parts - 1 do
        local part = parts[index]

        if type(current[part]) ~= "table" then
            current[part] = {}
        end

        current =
            current[part]
    end

    current[
        parts[#parts]
    ] = value

    return true
end




-- Signals


function Themes:CreateSignal()
    local signal = {
        Connections = {},
    }

    function signal:Connect(callback)
        if type(callback) ~= "function" then
            return {
                Disconnect = function()
                end,
            }
        end

        local connection = {
            Connected = true,
        }

        function connection:Disconnect()
            if not self.Connected then
                return
            end

            self.Connected = false

            for index, callbackData in ipairs(
                signal.Connections
            ) do
                if callbackData == callback then
                    table.remove(
                        signal.Connections,
                        index
                    )

                    break
                end
            end
        end

        table.insert(
            signal.Connections,
            callback
        )

        return connection
    end

    function signal:Fire(...)
        for _, callback in ipairs(
            signal.Connections
        ) do
            SafeCall(
                callback,
                ...
            )
        end
    end

    function signal:Destroy()
        table.clear(
            signal.Connections
        )
    end

    return signal
end


Themes.Changed = nil




-- Base Theme


Themes.BaseTheme = {
    -- =====================================================
    -- Core colors
    -- =====================================================

    Accent = Color3.fromRGB(
        139,
        92,
        246
    ),

    AccentHover = Color3.fromRGB(
        155,
        110,
        255
    ),

    AccentPressed = Color3.fromRGB(
        118,
        75,
        215
    ),

    AccentMuted = Color3.fromRGB(
        90,
        65,
        145
    ),

    Background = Color3.fromRGB(
        13,
        14,
        18
    ),

    BackgroundSecondary = Color3.fromRGB(
        17,
        18,
        23
    ),

    Surface = Color3.fromRGB(
        22,
        23,
        29
    ),

    SurfaceHover = Color3.fromRGB(
        28,
        29,
        36
    ),

    SurfacePressed = Color3.fromRGB(
        34,
        35,
        43
    ),

    SurfaceSelected = Color3.fromRGB(
        39,
        35,
        52
    ),

    -- =====================================================
    -- Text
    -- =====================================================

    Text = Color3.fromRGB(
        245,
        245,
        248
    ),

    TextSecondary = Color3.fromRGB(
        170,
        171,
        180
    ),

    TextTertiary = Color3.fromRGB(
        125,
        127,
        138
    ),

    TextDisabled = Color3.fromRGB(
        82,
        84,
        94
    ),

    TextOnAccent = Color3.fromRGB(
        255,
        255,
        255
    ),

    -- =====================================================
    -- Lines
    -- =====================================================

    Border = Color3.fromRGB(
        48,
        49,
        59
    ),

    BorderHover = Color3.fromRGB(
        70,
        71,
        83
    ),

    BorderActive = Color3.fromRGB(
        139,
        92,
        246
    ),

    Divider = Color3.fromRGB(
        38,
        39,
        47
    ),

    -- =====================================================
    -- State colors
    -- =====================================================

    Success = Color3.fromRGB(
        74,
        222,
        128
    ),

    Warning = Color3.fromRGB(
        250,
        204,
        21
    ),

    Error = Color3.fromRGB(
        248,
        113,
        113
    ),

    Info = Color3.fromRGB(
        96,
        165,
        250
    ),

    -- =====================================================
    -- Shape
    -- =====================================================

    CornerRadius = 6,

    BorderThickness = 1,

    -- =====================================================
    -- Transparency
    -- =====================================================

    Transparency = {
        Window = 0,

        Background = 0,

        Surface = 0,

        Control = 0,

        Hover = 0,

        Disabled = 0.35,

        Overlay = 0.25,

        Shadow = 0.45,
    },

    -- =====================================================
    -- Animation
    -- =====================================================

    Animation = {
        Enabled = true,

        Speed = 0.15,

        Window = {
            Open = 0.20,
            Close = 0.15,
        },

        Hover = {
            Speed = 0.10,
        },

        Press = {
            Speed = 0.08,
        },

        Tab = {
            Speed = 0.15,
        },

        Dropdown = {
            Speed = 0.12,
        },

        Notification = {
            Enter = 0.20,
            Exit = 0.15,
        },

        Toggle = {
            Speed = 0.12,
        },

        Slider = {
            Speed = 0.08,
        },
    },

    -- =====================================================
    -- UI scaling
    -- =====================================================

    Scale = {
        Enabled = true,

        Value = 1,

        Minimum = 0.75,

        Maximum = 1.50,
    },

    -- =====================================================
    -- Typography
    -- =====================================================

    Fonts = {
        Default = Enum.Font.Gotham,

        Medium = Enum.Font.GothamMedium,

        Bold = Enum.Font.GothamBold,

        Title = Enum.Font.GothamBold,

        Section = Enum.Font.GothamBold,

        Small = Enum.Font.Gotham,

        Mono = Enum.Font.Code,

        TitleSize = 18,

        SectionSize = 14,

        NormalSize = 13,

        SmallSize = 11,

        TinySize = 10,
    },

    -- =====================================================
    -- Window
    -- =====================================================

    Window = {
        Width = 850,

        Height = 600,

        MinimumWidth = 650,

        MinimumHeight = 450,

        MaximumWidth = 1400,

        MaximumHeight = 1000,

        CornerRadius = 8,

        BorderThickness = 1,

        TitleHeight = 46,

        Padding = 12,

        SidebarWidth = 180,

        ResizeHandleSize = 12,
    },

    -- =====================================================
    -- Sidebar
    -- =====================================================

    Sidebar = {
        Width = 180,

        Padding = 8,

        ItemHeight = 36,

        ItemSpacing = 4,

        CornerRadius = 6,

        IconSize = 18,

        TextSize = 12,
    },

    -- =====================================================
    -- Tabs
    -- =====================================================

    Tab = {
        Height = 36,

        Padding = 10,

        CornerRadius = 6,

        Spacing = 4,

        TextSize = 12,
    },

    -- =====================================================
    -- Buttons
    -- =====================================================

    Button = {
        Height = 32,

        MinimumWidth = 70,

        Padding = 10,

        CornerRadius = 6,

        BorderThickness = 1,

        TextSize = 12,

        PressScale = 0.97,
    },

    -- =====================================================
    -- Toggles
    -- =====================================================

    Toggle = {
        Width = 38,

        Height = 20,

        KnobSize = 16,

        Padding = 2,

        CornerRadius = 10,

        BorderThickness = 1,
    },

    -- =====================================================
    -- Sliders
    -- =====================================================

    Slider = {
        Height = 6,

        ThumbSize = 14,

        CornerRadius = 3,

        BorderThickness = 1,

        TextSize = 12,
    },

    -- =====================================================
    -- Dropdown
    -- =====================================================

    Dropdown = {
        Height = 32,

        ItemHeight = 30,

        MaxVisibleItems = 7,

        CornerRadius = 6,

        BorderThickness = 1,

        Padding = 8,

        TextSize = 12,
    },

    -- =====================================================
    -- Input
    -- =====================================================

    Input = {
        Height = 32,

        CornerRadius = 6,

        BorderThickness = 1,

        Padding = 8,

        TextSize = 12,

        PlaceholderTransparency = 0.45,
    },

    -- =====================================================
    -- Sections
    -- =====================================================

    Section = {
        Padding = 10,

        Spacing = 8,

        CornerRadius = 6,

        BorderThickness = 1,

        HeaderHeight = 28,

        TextSize = 13,
    },

    -- =====================================================
    -- Notifications
    -- =====================================================

    Notification = {
        Width = 320,

        MinimumHeight = 60,

        Padding = 12,

        Spacing = 8,

        CornerRadius = 7,

        BorderThickness = 1,

        Duration = 4,

        TitleSize = 13,

        TextSize = 11,

        IconSize = 18,
    },

    -- =====================================================
    -- Color picker
    -- =====================================================

    ColorPicker = {
        Width = 260,

        Height = 300,

        CornerRadius = 7,

        BorderThickness = 1,

        Padding = 10,

        PreviewSize = 30,
    },

    -- =====================================================
    -- Keybind
    -- =====================================================

    Keybind = {
        Height = 28,

        MinimumWidth = 70,

        Padding = 8,

        CornerRadius = 5,

        BorderThickness = 1,

        TextSize = 11,
    },

    -- =====================================================
    -- Effects
    -- =====================================================

    Effects = {
        Shadows = true,

        Blur = false,

        Glow = false,

        HoverHighlight = true,

        PressAnimation = true,

        WindowTransparency = false,

        SmoothScrolling = true,

        SmoothDragging = true,

        AntiAliasing = true,
    },

    -- =====================================================
    -- Icons
    -- =====================================================

    Icons = {
        Home = "⌂",

        Combat = "⚔",

        Visuals = "◉",

        Movement = "↔",

        Targeting = "◎",

        Teleports = "◆",

        Settings = "⚙",

        Search = "⌕",

        Close = "×",

        Minimize = "−",

        Chevron = "›",

        Check = "✓",

        Plus = "+",

        Warning = "!",

        Error = "×",

        Info = "i",
    },

    -- =====================================================
    -- Scrollbars
    -- =====================================================

    Scrollbar = {
        Thickness = 4,

        CornerRadius = 2,

        Transparency = 0.35,

        HoverTransparency = 0.10,
    },

    -- =====================================================
    -- Cursor / interaction
    -- =====================================================

    Interaction = {
        HoverEnabled = true,

        ClickFeedback = true,

        KeyboardFeedback = true,

        FocusOutline = true,

        DisabledOpacity = 0.45,
    },

    -- =====================================================
    -- Layout
    -- =====================================================

    Layout = {
        Spacing = 8,

        SmallSpacing = 4,

        LargeSpacing = 12,

        Padding = 10,

        ContentPadding = 12,
    },
}




-- Theme Presets


Themes.Presets = {}




-- Midnight


Themes.Presets.Midnight =
    DeepCopy(
        Themes.BaseTheme
    )




-- Dark


Themes.Presets.Dark =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                99,
                102,
                241
            ),

            AccentHover = Color3.fromRGB(
                118,
                121,
                255
            ),

            AccentPressed = Color3.fromRGB(
                79,
                82,
                210
            ),

            Background = Color3.fromRGB(
                15,
                15,
                15
            ),

            BackgroundSecondary = Color3.fromRGB(
                19,
                19,
                19
            ),

            Surface = Color3.fromRGB(
                25,
                25,
                25
            ),

            SurfaceHover = Color3.fromRGB(
                32,
                32,
                32
            ),

            SurfacePressed = Color3.fromRGB(
                39,
                39,
                39
            ),

            SurfaceSelected = Color3.fromRGB(
                35,
                35,
                48
            ),

            Border = Color3.fromRGB(
                48,
                48,
                48
            ),

            Divider = Color3.fromRGB(
                38,
                38,
                38
            ),
        }
    )




-- Light


Themes.Presets.Light =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                99,
                102,
                241
            ),

            AccentHover = Color3.fromRGB(
                79,
                82,
                220
            ),

            AccentPressed = Color3.fromRGB(
                67,
                70,
                190
            ),

            Background = Color3.fromRGB(
                242,
                243,
                247
            ),

            BackgroundSecondary = Color3.fromRGB(
                234,
                235,
                240
            ),

            Surface = Color3.fromRGB(
                255,
                255,
                255
            ),

            SurfaceHover = Color3.fromRGB(
                247,
                247,
                250
            ),

            SurfacePressed = Color3.fromRGB(
                238,
                239,
                244
            ),

            SurfaceSelected = Color3.fromRGB(
                235,
                233,
                249
            ),

            Text = Color3.fromRGB(
                25,
                26,
                32
            ),

            TextSecondary = Color3.fromRGB(
                91,
                93,
                104
            ),

            TextTertiary = Color3.fromRGB(
                125,
                127,
                138
            ),

            TextDisabled = Color3.fromRGB(
                170,
                171,
                180
            ),

            Border = Color3.fromRGB(
                215,
                216,
                223
            ),

            BorderHover = Color3.fromRGB(
                190,
                191,
                200
            ),

            Divider = Color3.fromRGB(
                225,
                226,
                232
            ),

            Transparency = {
                Window = 0,

                Background = 0,

                Surface = 0,

                Control = 0,

                Hover = 0,

                Disabled = 0.35,

                Overlay = 0.20,

                Shadow = 0.70,
            },
        }
    )




-- Purple


Themes.Presets.Purple =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                168,
                85,
                247
            ),

            AccentHover = Color3.fromRGB(
                192,
                112,
                255
            ),

            AccentPressed = Color3.fromRGB(
                139,
                64,
                210
            ),

            AccentMuted = Color3.fromRGB(
                103,
                65,
                145
            ),

            SurfaceSelected = Color3.fromRGB(
                45,
                32,
                59
            ),

            BorderActive = Color3.fromRGB(
                168,
                85,
                247
            ),
        }
    )




-- Red


Themes.Presets.Red =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                239,
                68,
                68
            ),

            AccentHover = Color3.fromRGB(
                248,
                92,
                92
            ),

            AccentPressed = Color3.fromRGB(
                200,
                50,
                50
            ),

            AccentMuted = Color3.fromRGB(
                145,
                55,
                55
            ),

            SurfaceSelected = Color3.fromRGB(
                55,
                31,
                34
            ),

            BorderActive = Color3.fromRGB(
                239,
                68,
                68
            ),
        }
    )




-- Green


Themes.Presets.Green =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                34,
                197,
                94
            ),

            AccentHover = Color3.fromRGB(
                55,
                220,
                112
            ),

            AccentPressed = Color3.fromRGB(
                25,
                165,
                75
            ),

            AccentMuted = Color3.fromRGB(
                45,
                125,
                70
            ),

            SurfaceSelected = Color3.fromRGB(
                28,
                50,
                37
            ),

            BorderActive = Color3.fromRGB(
                34,
                197,
                94
            ),
        }
    )




-- Blue


Themes.Presets.Blue =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                59,
                130,
                246
            ),

            AccentHover = Color3.fromRGB(
                83,
                151,
                255
            ),

            AccentPressed = Color3.fromRGB(
                42,
                102,
                205
            ),

            AccentMuted = Color3.fromRGB(
                55,
                95,
                150
            ),

            SurfaceSelected = Color3.fromRGB(
                29,
                40,
                58
            ),

            BorderActive = Color3.fromRGB(
                59,
                130,
                246
            ),
        }
    )




-- Orange


Themes.Presets.Orange =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                249,
                115,
                22
            ),

            AccentHover = Color3.fromRGB(
                255,
                140,
                55
            ),

            AccentPressed = Color3.fromRGB(
                210,
                85,
                15
            ),

            AccentMuted = Color3.fromRGB(
                155,
                82,
                40
            ),

            SurfaceSelected = Color3.fromRGB(
                53,
                38,
                28
            ),

            BorderActive = Color3.fromRGB(
                249,
                115,
                22
            ),
        }
    )




-- Cyan


Themes.Presets.Cyan =
    DeepMerge(
        Themes.BaseTheme,
        {
            Accent = Color3.fromRGB(
                6,
                182,
                212
            ),

            AccentHover = Color3.fromRGB(
                30,
                205,
                235
            ),

            AccentPressed = Color3.fromRGB(
                5,
                145,
                170
            ),

            AccentMuted = Color3.fromRGB(
                40,
                120,
                140
            ),

            SurfaceSelected = Color3.fromRGB(
                25,
                48,
                53
            ),

            BorderActive = Color3.fromRGB(
                6,
                182,
                212
            ),
        }
    )




-- Preset Management


function Themes:RegisterTheme(name, theme)
    if type(name) ~= "string"
        or name == "" then

        return false
    end

    if type(theme) ~= "table" then
        return false
    end

    local merged =
        DeepMerge(
            self.BaseTheme,
            theme
        )

    self.CustomThemes[name] = merged

    return true
end


function Themes:RemoveTheme(name)
    if not self.CustomThemes[name] then
        return false
    end

    if name == self.CurrentTheme then
        return false
    end

    self.CustomThemes[name] = nil

    return true
end


function Themes:HasTheme(name)
    if self.Presets[name] then
        return true
    end

    if self.CustomThemes[name] then
        return true
    end

    return false
end


function Themes:GetTheme(name)
    name = name or self.CurrentTheme

    if self.CustomThemes[name] then
        return self.CustomThemes[name]
    end

    if self.Presets[name] then
        return self.Presets[name]
    end

    return nil
end


function Themes:GetThemeNames()
    local names = {}

    for name in pairs(
        self.Presets
    ) do
        table.insert(
            names,
            name
        )
    end

    for name in pairs(
        self.CustomThemes
    ) do
        if not self.Presets[name] then
            table.insert(
                names,
                name
            )
        end
    end

    table.sort(names)

    return names
end




-- Current Theme


function Themes:SetTheme(name, silent)
    if not self:HasTheme(name) then
        warn(
            "[Lua Test] Themes:",
            "Unknown theme:",
            name
        )

        return false
    end

    local previous =
        self.CurrentTheme

    self.CurrentTheme = name

    if not silent
        and self.Changed then

        self.Changed:Fire(
            name,
            previous,
            self:GetTheme(name)
        )
    end

    return true
end


function Themes:Set(name)
    return self:SetTheme(
        name
    )
end


function Themes:GetCurrentTheme()
    return self.CurrentTheme
end


function Themes:GetCurrent()
    return self:GetTheme(
        self.CurrentTheme
    )
end




-- Value Access


function Themes:Get(path, default)
    local theme =
        self:GetCurrent()

    if not theme then
        return default
    end

    local value =
        GetPath(
            theme,
            path
        )

    if value == nil then
        return default
    end

    return value
end


function Themes:GetColor(path, default)
    local value =
        self:Get(
            path,
            default
        )

    if IsColor3(value) then
        return value
    end

    return default
end


function Themes:GetNumber(path, default)
    local value =
        self:Get(
            path,
            default
        )

    if IsNumber(value) then
        return value
    end

    return default
end


function Themes:GetBoolean(path, default)
    local value =
        self:Get(
            path,
            default
        )

    if type(value) == "boolean" then
        return value
    end

    return default
end


function Themes:GetFont(path, default)
    local value =
        self:Get(
            path,
            default
        )

    if typeof(value) == "EnumItem"
        and value.EnumType == Enum.Font then

        return value
    end

    return default
end




-- Common Shortcuts


function Themes:GetAccent()
    return self:GetColor(
        "Accent",
        Color3.new(
            1,
            1,
            1
        )
    )
end


function Themes:GetBackground()
    return self:GetColor(
        "Background",
        Color3.new(
            0,
            0,
            0
        )
    )
end


function Themes:GetSurface()
    return self:GetColor(
        "Surface",
        self:GetBackground()
    )
end


function Themes:GetText()
    return self:GetColor(
        "Text",
        Color3.new(
            1,
            1,
            1
        )
    )
end


function Themes:GetSecondaryText()
    return self:GetColor(
        "TextSecondary",
        self:GetText()
    )
end


function Themes:GetBorder()
    return self:GetColor(
        "Border",
        Color3.new(
            0.2,
            0.2,
            0.2
        )
    )
end




-- Runtime Customization


function Themes:SetValue(path, value)
    local theme =
        self:GetCurrent()

    if not theme then
        return false
    end

    if not SetPath(
        theme,
        path,
        value
    ) then
        return false
    end

    if self.Changed then
        self.Changed:Fire(
            self.CurrentTheme,
            self.CurrentTheme,
            theme
        )
    end

    return true
end


function Themes:SetColor(path, color)
    if not IsColor3(color) then
        return false
    end

    return self:SetValue(
        path,
        color
    )
end


function Themes:SetNumber(path, value)
    if not IsNumber(value) then
        return false
    end

    return self:SetValue(
        path,
        value
    )
end


function Themes:SetBoolean(path, value)
    if type(value) ~= "boolean" then
        return false
    end

    return self:SetValue(
        path,
        value
    )
end




-- Theme Cloning


function Themes:CloneTheme(
    sourceName,
    destinationName
)
    if type(destinationName) ~= "string"
        or destinationName == "" then

        return false
    end

    local source =
        self:GetTheme(
            sourceName
        )

    if not source then
        return false
    end

    self.CustomThemes[destinationName] =
        DeepCopy(source)

    return true
end




-- Theme Export


function Themes:Export(name)
    local theme =
        self:GetTheme(name)

    if not theme then
        return nil
    end

    return DeepCopy(theme)
end


function Themes:Import(
    name,
    theme,
    activate
)
    if type(name) ~= "string"
        or name == "" then

        return false
    end

    if type(theme) ~= "table" then
        return false
    end

    self:RegisterTheme(
        name,
        theme
    )

    if activate then
        self:SetTheme(name)
    end

    return true
end




-- Reset


function Themes:ResetTheme(name)
    name = name or self.CurrentTheme

    if self.Presets[name] then
        self.CustomThemes[name] = nil

        if self.CurrentTheme == name
            and self.Changed then

            self.Changed:Fire(
                name,
                name,
                self.Presets[name]
            )
        end

        return true
    end

    return false
end


function Themes:ResetCurrent()
    return self:ResetTheme(
        self.CurrentTheme
    )
end




-- Validation


function Themes:Validate(theme)
    if type(theme) ~= "table" then
        return false, {
            "Theme is not a table",
        }
    end

    local errors = {}

    local requiredColors = {
        "Accent",
        "Background",
        "BackgroundSecondary",
        "Surface",
        "SurfaceHover",
        "Text",
        "TextSecondary",
        "TextDisabled",
        "Border",
        "Divider",
        "Success",
        "Warning",
        "Error",
    }

    for _, path in ipairs(
        requiredColors
    ) do

        local value =
            GetPath(
                theme,
                path
            )

        if not IsColor3(value) then
            table.insert(
                errors,
                path
                .. " must be Color3"
            )
        end
    end

    local cornerRadius =
        GetPath(
            theme,
            "CornerRadius"
        )

    if not IsNumber(cornerRadius) then
        table.insert(
            errors,
            "CornerRadius must be number"
        )
    end

    local borderThickness =
        GetPath(
            theme,
            "BorderThickness"
        )

    if not IsNumber(borderThickness) then
        table.insert(
            errors,
            "BorderThickness must be number"
        )
    end

    local animation =
        GetPath(
            theme,
            "Animation"
        )

    if type(animation) ~= "table" then
        table.insert(
            errors,
            "Animation must be table"
        )
    end

    local transparency =
        GetPath(
            theme,
            "Transparency"
        )

    if type(transparency) ~= "table" then
        table.insert(
            errors,
            "Transparency must be table"
        )
    end

    return #errors == 0, errors
end




-- Scaling


function Themes:GetScale()
    local enabled =
        self:GetBoolean(
            "Scale.Enabled",
            true
        )

    if not enabled then
        return 1
    end

    local value =
        self:GetNumber(
            "Scale.Value",
            1
        )

    local minimum =
        self:GetNumber(
            "Scale.Minimum",
            0.75
        )

    local maximum =
        self:GetNumber(
            "Scale.Maximum",
            1.50
        )

    return math.clamp(
        value,
        minimum,
        maximum
    )
end


function Themes:SetScale(value)
    local minimum =
        self:GetNumber(
            "Scale.Minimum",
            0.75
        )

    local maximum =
        self:GetNumber(
            "Scale.Maximum",
            1.50
        )

    value =
        Clamp(
            value,
            minimum,
            maximum,
            1
        )

    return self:SetNumber(
        "Scale.Value",
        value
    )
end


function Themes:Scale(value)
    return value
        * self:GetScale()
end




-- Animation


function Themes:IsAnimationEnabled()
    return self:GetBoolean(
        "Animation.Enabled",
        true
    )
end


function Themes:GetAnimationSpeed(
    path,
    default
)
    if not self:IsAnimationEnabled() then
        return 0
    end

    return self:GetNumber(
        path,
        default
            or self:GetNumber(
                "Animation.Speed",
                0.15
            )
    )
end




-- Effects


function Themes:IsEffectEnabled(
    effect
)
    return self:GetBoolean(
        "Effects." .. effect,
        false
    )
end




-- Transparency


function Themes:GetTransparency(
    name,
    default
)
    local value =
        self:GetNumber(
            "Transparency." .. name,
            default or 0
        )

    return math.clamp(
        value,
        0,
        1
    )
end




-- Component Style


function Themes:GetComponent(
    component
)
    local value =
        self:Get(
            component,
            nil
        )

    if type(value) ~= "table" then
        return nil
    end

    return value
end


function Themes:GetComponentValue(
    component,
    property,
    default
)
    return self:Get(
        component
        .. "."
        .. property,
        default
    )
end




-- Theme Change Helpers


function Themes:OnChanged(callback)
    if not self.Changed then
        self.Changed =
            self:CreateSignal()
    end

    return self.Changed:Connect(
        callback
    )
end


function Themes:Apply(callback)
    if type(callback) ~= "function" then
        return false
    end

    local success =
        SafeCall(
            callback,
            self:GetCurrent()
        )

    return success
end




-- Debug


function Themes:GetStatistics()
    local presetCount = 0
    local customCount = 0

    for _ in pairs(
        self.Presets
    ) do
        presetCount += 1
    end

    for _ in pairs(
        self.CustomThemes
    ) do
        customCount += 1
    end

    return {
        CurrentTheme = self.CurrentTheme,

        Presets = presetCount,

        CustomThemes = customCount,

        Scale = self:GetScale(),

        AnimationEnabled =
            self:IsAnimationEnabled(),

        Initialized =
            self.Initialized,
    }
end




-- Initialize


function Themes:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules = modules or {}

    self.Config =
        modules.Config

    self.Debug =
        modules.Debug

    self.Signal =
        modules.Signal

    if not self.Changed then
        self.Changed =
            self:CreateSignal()
    end

    self.Initialized = true
    self._initialized = true

    return self
end




-- Destroy


function Themes:Destroy()
    if self.Changed then
        self.Changed:Destroy()
    end

    self.Changed = nil

    table.clear(
        self.Connections
    )

    self.Initialized = false
    self._initialized = false

    return true
end




-- Return


return Themes