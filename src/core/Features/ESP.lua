--[[
    Lua Test
    ESP.lua
    Version 3.1.0

    Advanced player visual overlay.

    Existing features:
        - Player name
        - Username
        - Team
        - Distance
        - Health
        - Max health
        - Health bar
        - Full box
        - Corner box
        - 2D screen-space box
        - Box fill
        - Tracer
        - Highlight / Chams
        - Skeleton
        - R6/R15 skeleton support
        - Head marker
        - Root marker
        - Off-screen indicator
        - Equipped tool
        - Character state
        - Alive filtering
        - Team filtering
        - Enemy filtering
        - Friend filtering
        - Whitelist
        - Blacklist
        - Name ignore list
        - Distance filtering
        - Distance fading
        - Visibility checking
        - Respawn rebinding
        - Automatic cleanup
        - Runtime configuration
        - FeatureManager interface

    New v3 features:
        - True 2D screen-space boxes
        - Dynamic box sizing
        - Corner box rendering
        - Box fill
        - Health bar side selection
        - Health color interpolation
        - Distance-based text hiding
        - Text outline control
        - Configurable text ordering
        - Configurable text offset
        - Chams depth mode
        - Separate visible/occluded behavior
        - Team/enemy/custom color modes
        - Friend detection
        - Name-based ignore list
        - Better off-screen indicators
        - Off-screen distance support
        - R6 skeleton fallback
        - Visibility state tracking
        - Target statistics
        - Character state tracking
        - Tool tracking
        - Automatic visual rebuilding
        - Safer runtime updates
        - Improved cleanup
        - Update throttling
]]

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local ESP = {
    Name = "ESP",
    Version = "3.0.0",

    Description = "Advanced player visual overlay",
    Category = "Visuals",

    Dependencies = {},

    Enabled = false,
    Initialized = false,
    Running = false,

    Visuals = nil,
    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    -- WorldESP is intentionally nested here.
    -- Keep world-object overlays inside ESP.lua instead of a duplicate module.
    WorldESP = nil,

    Connections = {},
    Entries = {},

    Settings = {
        Enabled = true,

        -- =================================================
        -- Filtering
        -- =================================================

        TeamCheck = false,
        EnemiesOnly = false,
        AliveOnly = true,

        IgnoreFriends = false,

        IgnoreNamesEnabled = false,
        IgnoreNames = {},

        MaxDistance = 2000,
        MinDistance = 0,

        -- =================================================
        -- Lists
        -- =================================================

        WhitelistEnabled = false,
        BlacklistEnabled = false,

        Whitelist = {},
        Blacklist = {},

        -- =================================================
        -- Color
        -- =================================================

        UseTeamColor = true,
        UseEnemyColor = false,

        EnemyColor = Color3.fromRGB(
            255,
            80,
            80
        ),

        FriendColor = Color3.fromRGB(
            80,
            170,
            255
        ),

        CustomColor = Color3.fromRGB(
            255,
            255,
            255
        ),

        -- =================================================
        -- Box
        -- =================================================

        Box = true,

        BoxStyle = "2D",
        -- Full / Corner / 2D

        BoxThickness = 1.5,

        BoxFill = false,
        BoxFillTransparency = 0.85,

        BoxPadding = 4,

        CornerLength = 0.25,

        -- =================================================
        -- Name
        -- =================================================

        Name = true,

        NameMode = "DisplayName",
        -- DisplayName / Username / Both

        NameSize = 13,

        ShowUsername = false,

        TextOutline = true,
        TextOutlineTransparency = 0,

        TextOffset = 4,

        -- =================================================
        -- Distance
        -- =================================================

        Distance = true,

        MaxTextDistance = 2000,

        -- =================================================
        -- Team
        -- =================================================

        ShowTeam = false,

        -- =================================================
        -- Health
        -- =================================================

        Health = true,
        HealthBar = true,

        ShowMaxHealth = false,

        HealthBarSide = "Left",
        -- Left / Right

        HealthBarWidth = 4,

        HealthBarGap = 5,

        -- =================================================
        -- Status
        -- =================================================

        ShowStatus = false,
        ShowTool = false,

        -- =================================================
        -- Tracer
        -- =================================================

        Tracer = false,

        TracerOrigin = "Bottom",
        -- Bottom / Center / Top

        TracerThickness = 1.5,

        TracerIgnoreOffscreen = true,

        -- =================================================
        -- Highlight / Chams
        -- =================================================

        Highlight = false,

        HighlightDepthMode = "AlwaysOnTop",
        -- AlwaysOnTop / Occluded

        HighlightFillTransparency = 0.55,

        HighlightOutlineTransparency = 0,

        -- =================================================
        -- Skeleton
        -- =================================================

        Skeleton = false,

        SkeletonThickness = 1.5,

        SkeletonIgnoreOffscreen = true,

        -- =================================================
        -- Markers
        -- =================================================

        HeadMarker = false,
        RootMarker = false,

        HeadMarkerSize = 5,
        RootMarkerSize = 5,

        -- =================================================
        -- Offscreen
        -- =================================================

        OffscreenIndicator = false,

        OffscreenSize = 12,

        OffscreenDistance = 80,

        -- =================================================
        -- Visual behavior
        -- =================================================

        FadeDistance = false,

        FadeStart = 500,
        FadeEnd = 2000,

        VisibilityCheck = true,

        HideOccluded = false,

        -- =================================================
        -- World ESP (object/world overlay)
        -- =================================================

        WorldESP = false,
        WorldHighlight = false,
        WorldBillboard = true,
        WorldName = true,
        WorldDistance = true,
        WorldBox2D = false,
        WorldTracer = false,
        WorldMaxDistance = 2000,
        WorldMinDistance = 0,
        WorldFadeDistance = false,
        WorldFadeStart = 500,
        WorldFadeEnd = 2000,
        WorldUpdateRate = 30,
        WorldAutoScan = false,
        WorldTags = {},
        WorldFolders = {},
        WorldDefaultColor = Color3.fromRGB(255, 255, 255),
        WorldHighlightFillTransparency = 0.55,
        WorldHighlightOutlineTransparency = 0,
        WorldDisplayOrder = 6,

        -- =================================================
        -- Performance
        -- =================================================

        UpdateRate = 60,

        -- =================================================
        -- UI
        -- =================================================

        DisplayOrder = 5,
    },

    _accumulator = 0,
}



-- Helpers


local function Disconnect(connection)
    if not connection then
        return
    end

    pcall(function()
        connection:Disconnect()
    end)
end


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
            "[Lua Test] ESP error:",
            result
        )

        return false, result
    end

    return true, result
end


local function New(className)
    local success, instance = pcall(
        Instance.new,
        className
    )

    if not success then
        warn(
            "[Lua Test] ESP failed to create:",
            className
        )

        return nil
    end

    return instance
end


local function ClampNumber(
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


local function IsColor3(value)
    return typeof(value) == "Color3"
end


local function LerpColor(a, b, alpha)
    return a:Lerp(
        b,
        math.clamp(alpha, 0, 1)
    )
end


local function GetHealthColor(percent)
    percent = math.clamp(
        percent,
        0,
        1
    )

    local red =
        Color3.fromRGB(
            255,
            70,
            70
        )

    local yellow =
        Color3.fromRGB(
            255,
            220,
            70
        )

    local green =
        Color3.fromRGB(
            70,
            255,
            100
        )

    if percent < 0.5 then
        return LerpColor(
            red,
            yellow,
            percent / 0.5
        )
    end

    return LerpColor(
        yellow,
        green,
        (percent - 0.5) / 0.5
    )
end



-- =============================================================
-- Integrated WorldESP subsystem
-- =============================================================
-- WorldESP intentionally lives inside ESP.lua. It shares the same
-- lifecycle, configuration, rendering and cleanup system.

local WorldESP = {
    Name = "WorldESP",
    Parent = "ESP",
    Version = "3.1.0",
    Enabled = false,
    Running = false,
    Entries = {},
    Connections = {},
    _accumulator = 0,
    _scanAccumulator = 0,
}

ESP.WorldESP = WorldESP

WorldESP.Settings = {
    Enabled = false,
    Highlight = false,
    Billboard = true,
    Name = true,
    Distance = true,
    Box2D = false,
    Tracer = false,
    MaxDistance = 2000,
    MinDistance = 0,
    FadeDistance = false,
    FadeStart = 500,
    FadeEnd = 2000,
    DefaultColor = Color3.fromRGB(255, 255, 255),
    HighlightFillTransparency = 0.55,
    HighlightOutlineTransparency = 0,
    UpdateRate = 30,
    AutoScan = false,
    Tags = {},
    Folders = {},
    DisplayOrder = 6,
}

function WorldESP:GetSetting(name, default)
    local parentNames = {
        Enabled = "WorldESP",
        Highlight = "WorldHighlight",
        Billboard = "WorldBillboard",
        Name = "WorldName",
        Distance = "WorldDistance",
        Box2D = "WorldBox2D",
        Tracer = "WorldTracer",
        MaxDistance = "WorldMaxDistance",
        MinDistance = "WorldMinDistance",
        FadeDistance = "WorldFadeDistance",
        FadeStart = "WorldFadeStart",
        FadeEnd = "WorldFadeEnd",
        UpdateRate = "WorldUpdateRate",
        AutoScan = "WorldAutoScan",
        Tags = "WorldTags",
        Folders = "WorldFolders",
        DefaultColor = "WorldDefaultColor",
        HighlightFillTransparency = "WorldHighlightFillTransparency",
        HighlightOutlineTransparency = "WorldHighlightOutlineTransparency",
        DisplayOrder = "WorldDisplayOrder",
    }

    local parentName = parentNames[name]

    if parentName and ESP.Settings[parentName] ~= nil then
        return ESP.Settings[parentName]
    end

    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    return default
end

function WorldESP:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    local parentNames = {
        Enabled = "WorldESP",
        Highlight = "WorldHighlight",
        Billboard = "WorldBillboard",
        Name = "WorldName",
        Distance = "WorldDistance",
        Box2D = "WorldBox2D",
        Tracer = "WorldTracer",
        MaxDistance = "WorldMaxDistance",
        MinDistance = "WorldMinDistance",
        FadeDistance = "WorldFadeDistance",
        FadeStart = "WorldFadeStart",
        FadeEnd = "WorldFadeEnd",
        UpdateRate = "WorldUpdateRate",
        AutoScan = "WorldAutoScan",
        Tags = "WorldTags",
        Folders = "WorldFolders",
        DefaultColor = "WorldDefaultColor",
        HighlightFillTransparency = "WorldHighlightFillTransparency",
        HighlightOutlineTransparency = "WorldHighlightOutlineTransparency",
        DisplayOrder = "WorldDisplayOrder",
    }

    self.Settings[name] = value

    local parentName = parentNames[name]
    if parentName and ESP.Settings[parentName] ~= nil then
        ESP.Settings[parentName] = value
    end

    self:Refresh()
    return true
end

function WorldESP:GetSettings()
    return self.Settings
end

function WorldESP:SetSettings(settings)
    if type(settings) ~= "table" then
        return false
    end
    for name, value in pairs(settings) do
        if self.Settings[name] ~= nil then
            self.Settings[name] = value
        end
    end
    self:Refresh()
    return true
end

function WorldESP:GetRoot(instance)
    if not instance or not instance.Parent then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance
    end
    if instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart", true)
            or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

function WorldESP:GetPosition(instance)
    if not instance or not instance.Parent then
        return nil
    end
    if instance:IsA("BasePart") then
        return instance.Position
    end
    if instance:IsA("Model") then
        local success, cf = pcall(function()
            return instance:GetBoundingBox()
        end)
        if success and cf then
            return cf.Position
        end
    end
    local root = self:GetRoot(instance)
    return root and root.Position or nil
end

function WorldESP:GetColor(entry)
    if entry.Color and IsColor3(entry.Color) then
        return entry.Color
    end
    local color = self:GetSetting("DefaultColor", Color3.new(1, 1, 1))
    return IsColor3(color) and color or Color3.new(1, 1, 1)
end

function WorldESP:GetDistance(position)
    local player = PlayersService.LocalPlayer
    local character = player and player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root or not position then
        return math.huge
    end
    return (position - root.Position).Magnitude
end

function WorldESP:GetAlpha(distance)
    if not self:GetSetting("FadeDistance", false) then
        return 1
    end
    local startDistance = tonumber(self:GetSetting("FadeStart", 500)) or 500
    local endDistance = tonumber(self:GetSetting("FadeEnd", 2000)) or 2000
    if endDistance <= startDistance then
        return 1
    end
    return math.clamp(1 - ((distance - startDistance) / (endDistance - startDistance)), 0, 1)
end

function WorldESP:CreateEntry(instance, name, color)
    if not instance or not instance.Parent then
        return nil
    end
    local existing = self.Entries[instance]
    if existing then
        if name then existing.Name = tostring(name) end
        if IsColor3(color) then existing.Color = color end
        return existing
    end

    local entry = {
        Instance = instance,
        Name = name or instance.Name,
        Color = IsColor3(color) and color or nil,
        Root = nil,
        Highlight = nil,
        Billboard = nil,
        NameLabel = nil,
        DistanceLabel = nil,
        ScreenGui = nil,
        Box = nil,
        BoxStroke = nil,
        TracerGui = nil,
        Tracer = nil,
        Visible = false,
        OnScreen = false,
        Distance = math.huge,
        Alpha = 1,
    }

    self.Entries[instance] = entry
    self:BuildVisuals(entry)
    return entry
end

function WorldESP:Register(instance, name, color)
    return self:CreateEntry(instance, name, color)
end

function WorldESP:RegisterMany(instances, color)
    if type(instances) ~= "table" then
        return 0
    end
    local count = 0
    for _, instance in ipairs(instances) do
        if self:Register(instance, nil, color) then
            count += 1
        end
    end
    return count
end

function WorldESP:DestroyVisuals(entry)
    if not entry then return end
    pcall(function() if entry.Highlight then entry.Highlight:Destroy() end end)
    pcall(function() if entry.Billboard then entry.Billboard:Destroy() end end)
    pcall(function() if entry.ScreenGui then entry.ScreenGui:Destroy() end end)
    pcall(function() if entry.TracerGui then entry.TracerGui:Destroy() end end)
    entry.Highlight = nil
    entry.Billboard = nil
    entry.NameLabel = nil
    entry.DistanceLabel = nil
    entry.ScreenGui = nil
    entry.Box = nil
    entry.BoxStroke = nil
    entry.TracerGui = nil
    entry.Tracer = nil
end

function WorldESP:BuildVisuals(entry)
    self:DestroyVisuals(entry)
    entry.Root = self:GetRoot(entry.Instance)
    if not entry.Root then return end

    if self:GetSetting("Highlight", false) then
        local highlight = New("Highlight")
        if highlight then
            highlight.Name = "LuaTestESPWorldHighlight"
            highlight.Adornee = entry.Instance
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Parent = entry.Instance
            entry.Highlight = highlight
        end
    end

    if self:GetSetting("Billboard", true) then
        local gui = New("BillboardGui")
        if gui then
            gui.Name = "LuaTestESPWorldInfo"
            gui.Adornee = entry.Root
            gui.Size = UDim2.fromOffset(240, 44)
            gui.StudsOffset = Vector3.new(0, 2.5, 0)
            gui.AlwaysOnTop = true
            gui.ResetOnSpawn = false
            gui.Parent = entry.Root

            local nameLabel = New("TextLabel")
            local distanceLabel = New("TextLabel")
            if nameLabel and distanceLabel then
                for _, data in ipairs({
                    {nameLabel, UDim2.fromOffset(0, 0), 22, 13},
                    {distanceLabel, UDim2.fromOffset(0, 21), 18, 11},
                }) do
                    local label, position, height, size = data[1], data[2], data[3], data[4]
                    label.BackgroundTransparency = 1
                    label.Position = position
                    label.Size = UDim2.new(1, 0, 0, height)
                    label.Font = Enum.Font.GothamBold
                    label.TextSize = size
                    label.TextStrokeTransparency = 0
                    label.TextXAlignment = Enum.TextXAlignment.Center
                    label.Parent = gui
                end
                entry.Billboard = gui
                entry.NameLabel = nameLabel
                entry.DistanceLabel = distanceLabel
            else
                gui:Destroy()
            end
        end
    end

    if self:GetSetting("Box2D", false) then
        local player = PlayersService.LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            local gui = New("ScreenGui")
            if gui then
                gui.Name = "LuaTestESPWorldBox"
                gui.IgnoreGuiInset = true
                gui.ResetOnSpawn = false
                gui.DisplayOrder = self:GetSetting("DisplayOrder", 6)
                gui.Parent = playerGui
                local box = New("Frame")
                if box then
                    box.BackgroundTransparency = 1
                    box.BorderSizePixel = 0
                    box.Visible = false
                    box.Parent = gui
                    local stroke = New("UIStroke")
                    if stroke then
                        stroke.Thickness = 1.5
                        stroke.Parent = box
                    end
                    entry.ScreenGui = gui
                    entry.Box = box
                    entry.BoxStroke = stroke
                else
                    gui:Destroy()
                end
            end
        end
    end

    if self:GetSetting("Tracer", false) then
        local player = PlayersService.LocalPlayer
        local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
        if playerGui then
            local gui = New("ScreenGui")
            if gui then
                gui.Name = "LuaTestESPWorldTracer"
                gui.IgnoreGuiInset = true
                gui.ResetOnSpawn = false
                gui.DisplayOrder = self:GetSetting("DisplayOrder", 6)
                gui.Parent = playerGui
                local line = New("Frame")
                if line then
                    line.AnchorPoint = Vector2.new(0.5, 0.5)
                    line.BorderSizePixel = 0
                    line.Visible = false
                    line.Parent = gui
                    entry.TracerGui = gui
                    entry.Tracer = line
                else
                    gui:Destroy()
                end
            end
        end
    end
end

function WorldESP:Remove(instance)
    local entry = self.Entries[instance]
    if not entry then return false end
    self:DestroyVisuals(entry)
    self.Entries[instance] = nil
    return true
end

WorldESP.Unregister = WorldESP.Remove

function WorldESP:Clear()
    local list = {}
    for instance in pairs(self.Entries) do
        list[#list + 1] = instance
    end
    for _, instance in ipairs(list) do
        self:Remove(instance)
    end
end

function WorldESP:GetScreenBounds(entry)
    local camera = workspace.CurrentCamera
    local instance = entry and entry.Instance
    if not camera or not instance or not instance.Parent then return nil end

    local cf, size
    if instance:IsA("Model") then
        local success, resultCF, resultSize = pcall(function()
            local c, s = instance:GetBoundingBox()
            return c, s
        end)
        if not success then return nil end
        cf, size = resultCF, resultSize
    elseif instance:IsA("BasePart") then
        cf, size = instance.CFrame, instance.Size
    else
        return nil
    end

    local half = size / 2
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local front = false

    for _, offset in ipairs({
        Vector3.new(-half.X, -half.Y, -half.Z),
        Vector3.new(-half.X, -half.Y, half.Z),
        Vector3.new(-half.X, half.Y, -half.Z),
        Vector3.new(-half.X, half.Y, half.Z),
        Vector3.new(half.X, -half.Y, -half.Z),
        Vector3.new(half.X, -half.Y, half.Z),
        Vector3.new(half.X, half.Y, -half.Z),
        Vector3.new(half.X, half.Y, half.Z),
    }) do
        local point = camera:WorldToViewportPoint(cf:PointToWorldSpace(offset))
        if point.Z > 0 then front = true end
        minX = math.min(minX, point.X)
        minY = math.min(minY, point.Y)
        maxX = math.max(maxX, point.X)
        maxY = math.max(maxY, point.Y)
    end

    if not front then return nil end

    local viewport = camera.ViewportSize
    local x1 = math.clamp(minX, 0, viewport.X)
    local y1 = math.clamp(minY, 0, viewport.Y)
    local x2 = math.clamp(maxX, 0, viewport.X)
    local y2 = math.clamp(maxY, 0, viewport.Y)

    if x2 <= x1 or y2 <= y1 then return nil end

    return {
        X = x1,
        Y = y1,
        Width = x2 - x1,
        Height = y2 - y1,
        Center = Vector2.new((x1 + x2) / 2, (y1 + y2) / 2),
    }
end

function WorldESP:UpdateEntry(entry)
    if not entry or not entry.Instance or not entry.Instance.Parent then
        if entry and entry.Instance then self:Remove(entry.Instance) end
        return
    end

    entry.Root = self:GetRoot(entry.Instance)
    local position = self:GetPosition(entry.Instance)
    if not entry.Root or not position then
        self:HideEntry(entry)
        return
    end

    local distance = self:GetDistance(position)
    entry.Distance = distance

    local maxDistance = tonumber(self:GetSetting("MaxDistance", 2000)) or 2000
    local minDistance = tonumber(self:GetSetting("MinDistance", 0)) or 0
    if distance > maxDistance or distance < minDistance then
        self:HideEntry(entry)
        return
    end

    local alpha = self:GetAlpha(distance)
    entry.Alpha = alpha
    if alpha <= 0 then
        self:HideEntry(entry)
        return
    end

    local color = self:GetColor(entry)
    local bounds = self:GetScreenBounds(entry)
    entry.OnScreen = bounds ~= nil
    entry.Visible = true

    if entry.Highlight then
        entry.Highlight.FillColor = color
        entry.Highlight.OutlineColor = color
        entry.Highlight.FillTransparency = math.clamp(self:GetSetting("HighlightFillTransparency", 0.55) + (1 - alpha) * 0.4, 0, 1)
        entry.Highlight.OutlineTransparency = math.clamp(self:GetSetting("HighlightOutlineTransparency", 0) + (1 - alpha) * 0.5, 0, 1)
        entry.Highlight.Enabled = true
    end

    if entry.Billboard then
        entry.Billboard.Enabled = self:GetSetting("Name", true) or self:GetSetting("Distance", true)
        if entry.NameLabel then
            entry.NameLabel.Visible = self:GetSetting("Name", true)
            entry.NameLabel.Text = entry.Name
            entry.NameLabel.TextColor3 = color
            entry.NameLabel.TextTransparency = 1 - alpha
        end
        if entry.DistanceLabel then
            entry.DistanceLabel.Visible = self:GetSetting("Distance", true)
            entry.DistanceLabel.Text = string.format("%d studs", math.floor(distance + 0.5))
            entry.DistanceLabel.TextColor3 = Color3.new(1, 1, 1)
            entry.DistanceLabel.TextTransparency = 1 - alpha
        end
    end

    if entry.Box then
        if bounds then
            entry.Box.Position = UDim2.fromOffset(bounds.X, bounds.Y)
            entry.Box.Size = UDim2.fromOffset(bounds.Width, bounds.Height)
            entry.Box.Visible = alpha > 0
            if entry.BoxStroke then
                entry.BoxStroke.Color = color
                entry.BoxStroke.Transparency = 1 - alpha
            end
        else
            entry.Box.Visible = false
        end
    end

    if entry.Tracer then
        if bounds then
            local camera = workspace.CurrentCamera
            if camera then
                local viewport = camera.ViewportSize
                local origin = Vector2.new(viewport.X / 2, viewport.Y)
                local target = bounds.Center
                local delta = target - origin
                local length = delta.Magnitude
                if length > 1 then
                    entry.Tracer.Position = UDim2.fromOffset((origin.X + target.X) / 2, (origin.Y + target.Y) / 2)
                    entry.Tracer.Size = UDim2.fromOffset(length, 1.5)
                    entry.Tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                    entry.Tracer.BackgroundColor3 = color
                    entry.Tracer.BackgroundTransparency = 1 - alpha
                    entry.Tracer.Visible = true
                else
                    entry.Tracer.Visible = false
                end
            end
        else
            entry.Tracer.Visible = false
        end
    end
end

function WorldESP:HideEntry(entry)
    if not entry then return end
    entry.Visible = false
    if entry.Billboard then entry.Billboard.Enabled = false end
    if entry.Highlight then entry.Highlight.Enabled = false end
    if entry.Box then entry.Box.Visible = false end
    if entry.Tracer then entry.Tracer.Visible = false end
end

function WorldESP:ScanTag(tag, name, color)
    if type(tag) ~= "string" or tag == "" then return 0 end
    local count = 0
    for _, instance in ipairs(CollectionService:GetTagged(tag)) do
        if instance and instance.Parent then
            self:Register(instance, name, color)
            count += 1
        end
    end
    return count
end

function WorldESP:ScanFolder(folder, name, color)
    if typeof(folder) ~= "Instance" or not folder.Parent then return 0 end
    local count = 0
    for _, instance in ipairs(folder:GetDescendants()) do
        if instance:IsA("Model") or instance:IsA("BasePart") then
            self:Register(instance, name, color)
            count += 1
        end
    end
    return count
end

function WorldESP:RefreshSources()
    local tags = self:GetSetting("Tags", {})
    local folders = self:GetSetting("Folders", {})
    if type(tags) == "table" then
        for _, tag in ipairs(tags) do self:ScanTag(tag) end
    end
    if type(folders) == "table" then
        for _, folder in ipairs(folders) do
            if typeof(folder) == "Instance" then self:ScanFolder(folder) end
        end
    end
end

function WorldESP:Update(deltaTime)
    if not self.Enabled then return end
    self._accumulator += deltaTime or 0
    local rate = math.clamp(tonumber(self:GetSetting("UpdateRate", 30)) or 30, 1, 240)
    local interval = 1 / rate
    if self._accumulator < interval then return end
    self._accumulator -= interval

    if self:GetSetting("AutoScan", false) then
        self._scanAccumulator += interval
        if self._scanAccumulator >= 1 then
            self._scanAccumulator = 0
            self:RefreshSources()
        end
    end

    for instance, entry in pairs(self.Entries) do
        if instance and instance.Parent then
            SafeCall(function() self:UpdateEntry(entry) end)
        else
            self:Remove(instance)
        end
    end
end

function WorldESP:Start()
    if self.Running then return true end
    self.Enabled = true
    self.Running = true
    self._accumulator = 0
    self._scanAccumulator = 0
    if self:GetSetting("AutoScan", false) then self:RefreshSources() end
    return true
end

function WorldESP:Stop()
    self.Enabled = false
    self.Running = false
    self._accumulator = 0
    self._scanAccumulator = 0
    self:Clear()
    return true
end

function WorldESP:Enable()
    self.Settings.Enabled = true
    return self:Start()
end

function WorldESP:Disable()
    self.Settings.Enabled = false
    return self:Stop()
end

function WorldESP:SetEnabled(enabled)
    enabled = enabled == true
    self.Settings.Enabled = enabled
    if enabled then self:Start() else self:Stop() end
    return self.Enabled
end

function WorldESP:Toggle()
    return self:SetEnabled(not self.Enabled)
end

function WorldESP:Refresh()
    if not self.Running then return end
    self:RefreshSources()
    for _, entry in pairs(self.Entries) do
        SafeCall(function() self:UpdateEntry(entry) end)
    end
end

function WorldESP:GetStatistics()
    local total, visible, onScreen = 0, 0, 0
    for _, entry in pairs(self.Entries) do
        total += 1
        if entry.Visible then visible += 1 end
        if entry.OnScreen then onScreen += 1 end
    end
    return {
        Total = total,
        Visible = visible,
        OnScreen = onScreen,
        Running = self.Running,
        Enabled = self.Enabled,
    }
end


-- Configuration


function ESP:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(
            function()
                return self.Config:Get(
                    "ESP." .. name,
                    default
                )
            end
        )

        if success and value ~= nil then
            return value
        end
    end

    return default
end


function ESP:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    if self.WorldESP then
        local worldMap = {
            WorldESP = "Enabled",
            WorldHighlight = "Highlight",
            WorldBillboard = "Billboard",
            WorldName = "Name",
            WorldDistance = "Distance",
            WorldBox2D = "Box2D",
            WorldTracer = "Tracer",
            WorldMaxDistance = "MaxDistance",
            WorldMinDistance = "MinDistance",
            WorldFadeDistance = "FadeDistance",
            WorldFadeStart = "FadeStart",
            WorldFadeEnd = "FadeEnd",
            WorldUpdateRate = "UpdateRate",
            WorldAutoScan = "AutoScan",
            WorldTags = "Tags",
            WorldFolders = "Folders",
            WorldDefaultColor = "DefaultColor",
            WorldHighlightFillTransparency = "HighlightFillTransparency",
            WorldHighlightOutlineTransparency = "HighlightOutlineTransparency",
            WorldDisplayOrder = "DisplayOrder",
        }

        local worldName = worldMap[name]
        if worldName then
            self.WorldESP.Settings[worldName] = value
        end
    end

    self:Refresh()

    return true
end


function ESP:GetSettings()
    return self.Settings
end


function ESP:SetSettings(settings)
    if type(settings) ~= "table" then
        return false
    end

    for name, value in pairs(settings) do
        if self.Settings[name] ~= nil then
            self.Settings[name] = value
        end
    end

    self:Refresh()

    return true
end


function ESP:ResetSettings()
    self.Settings = {
        Enabled = true,

        TeamCheck = false,
        EnemiesOnly = false,
        AliveOnly = true,
        IgnoreFriends = false,

        IgnoreNamesEnabled = false,
        IgnoreNames = {},

        MaxDistance = 2000,
        MinDistance = 0,

        WhitelistEnabled = false,
        BlacklistEnabled = false,

        Whitelist = {},
        Blacklist = {},

        UseTeamColor = true,
        UseEnemyColor = false,

        EnemyColor = Color3.fromRGB(
            255,
            80,
            80
        ),

        FriendColor = Color3.fromRGB(
            80,
            170,
            255
        ),

        CustomColor = Color3.fromRGB(
            255,
            255,
            255
        ),

        Box = true,
        BoxStyle = "2D",
        BoxThickness = 1.5,
        BoxFill = false,
        BoxFillTransparency = 0.85,
        BoxPadding = 4,
        CornerLength = 0.25,

        Name = true,
        NameMode = "DisplayName",
        NameSize = 13,
        ShowUsername = false,

        TextOutline = true,
        TextOutlineTransparency = 0,

        TextOffset = 4,

        Distance = true,
        MaxTextDistance = 2000,

        ShowTeam = false,

        Health = true,
        HealthBar = true,
        ShowMaxHealth = false,

        HealthBarSide = "Left",
        HealthBarWidth = 4,
        HealthBarGap = 5,

        ShowStatus = false,
        ShowTool = false,

        Tracer = false,
        TracerOrigin = "Bottom",
        TracerThickness = 1.5,
        TracerIgnoreOffscreen = true,

        Highlight = false,
        HighlightDepthMode = "AlwaysOnTop",
        HighlightFillTransparency = 0.55,
        HighlightOutlineTransparency = 0,

        Skeleton = false,
        SkeletonThickness = 1.5,
        SkeletonIgnoreOffscreen = true,

        HeadMarker = false,
        RootMarker = false,

        HeadMarkerSize = 5,
        RootMarkerSize = 5,

        OffscreenIndicator = false,
        OffscreenSize = 12,
        OffscreenDistance = 80,

        FadeDistance = false,
        FadeStart = 500,
        FadeEnd = 2000,

        VisibilityCheck = true,
        HideOccluded = false,

        WorldESP = false,
        WorldHighlight = false,
        WorldBillboard = true,
        WorldName = true,
        WorldDistance = true,
        WorldBox2D = false,
        WorldTracer = false,
        WorldMaxDistance = 2000,
        WorldMinDistance = 0,
        WorldFadeDistance = false,
        WorldFadeStart = 500,
        WorldFadeEnd = 2000,
        WorldUpdateRate = 30,
        WorldAutoScan = false,
        WorldTags = {},
        WorldFolders = {},
        WorldDefaultColor = Color3.fromRGB(255, 255, 255),
        WorldHighlightFillTransparency = 0.55,
        WorldHighlightOutlineTransparency = 0,
        WorldDisplayOrder = 6,

        UpdateRate = 60,

        DisplayOrder = 5,
    }

    self:Refresh()

    return true
end



-- Lists


function ESP:IsInList(list, player)
    if type(list) ~= "table"
        or not player then

        return false
    end

    for _, value in ipairs(list) do
        if value == player
            or value == player.Name
            or value == player.UserId
            or value == tostring(player.UserId) then

            return true
        end
    end

    return false
end


function ESP:IsNameIgnored(player)
    if not self:GetSetting(
        "IgnoreNamesEnabled",
        false
    ) then
        return false
    end

    local list =
        self:GetSetting(
            "IgnoreNames",
            {}
        )

    if self:IsInList(
        list,
        player
    ) then
        return true
    end

    for _, value in ipairs(list) do
        if type(value) == "string" then

            local lower =
                string.lower(value)

            if lower ==
                string.lower(
                    player.DisplayName
                ) then

                return true
            end
        end
    end

    return false
end


function ESP:IsWhitelisted(player)
    if not self:GetSetting(
        "WhitelistEnabled",
        false
    ) then
        return false
    end

    return self:IsInList(
        self:GetSetting(
            "Whitelist",
            {}
        ),
        player
    )
end


function ESP:IsBlacklisted(player)
    if not self:GetSetting(
        "BlacklistEnabled",
        false
    ) then
        return false
    end

    return self:IsInList(
        self:GetSetting(
            "Blacklist",
            {}
        ),
        player
    )
end



-- Player filtering


function ESP:IsValidPlayer(player)
    if not player then
        return false
    end

    if player == PlayersService.LocalPlayer then
        return false
    end

    if not player.Parent then
        return false
    end

    if self:IsBlacklisted(player) then
        return false
    end

    if self:IsNameIgnored(player) then
        return false
    end

    if self:GetSetting(
        "WhitelistEnabled",
        false
    ) then

        if not self:IsWhitelisted(player) then
            return false
        end
    end

    local localPlayer =
        PlayersService.LocalPlayer

    if not localPlayer then
        return false
    end

    if self:GetSetting(
        "IgnoreFriends",
        false
    ) then

        local success, isFriend =
            pcall(
                function()
                    return localPlayer:IsFriendsWith(
                        player.UserId
                    )
                end
            )

        if success and isFriend then
            return false
        end
    end

    if self:GetSetting(
        "TeamCheck",
        false
    ) then

        if localPlayer.Team
            and player.Team
            and localPlayer.Team == player.Team then

            return false
        end
    end

    if self:GetSetting(
        "EnemiesOnly",
        false
    ) then

        if not localPlayer.Team
            or not player.Team
            or localPlayer.Team == player.Team then

            return false
        end
    end

    return true
end



-- Character helpers


function ESP:GetCharacter(player)
    if self.Players
        and type(self.Players.GetCharacter)
            == "function" then

        local success, character =
            pcall(
                function()
                    return self.Players:GetCharacter(
                        player
                    )
                end
            )

        if success and character then
            return character
        end
    end

    return player
        and player.Character
end


function ESP:GetRoot(player)
    if self.Players
        and type(self.Players.GetRoot)
            == "function" then

        local success, root =
            pcall(
                function()
                    return self.Players:GetRoot(
                        player
                    )
                end
            )

        if success and root then
            return root
        end
    end

    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end


function ESP:GetHumanoid(player)
    if self.Players
        and type(self.Players.GetHumanoid)
            == "function" then

        local success, humanoid =
            pcall(
                function()
                    return self.Players:GetHumanoid(
                        player
                    )
                end
            )

        if success and humanoid then
            return humanoid
        end
    end

    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end


function ESP:GetHead(player)
    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "Head"
    )
end



-- Entry management


function ESP:GetEntry(player)
    return self.Entries[player]
end


function ESP:CreateEntry(player)
    if not player then
        return nil
    end

    local existing =
        self:GetEntry(player)

    if existing then
        return existing
    end

    local entry = {
        Player = player,

        Character = nil,
        Humanoid = nil,
        RootPart = nil,
        Head = nil,

        Highlight = nil,

        Billboard = nil,

        NameLabel = nil,
        UsernameLabel = nil,
        DistanceLabel = nil,
        TeamLabel = nil,
        StatusLabel = nil,
        HealthTextLabel = nil,
        ToolLabel = nil,

        BoxGui = nil,

        BoxFrame = nil,
        BoxStroke = nil,
        BoxFill = nil,

        CornerParts = {},

        ScreenBoxGui = nil,
        ScreenBoxParts = {},

        HealthBackground = nil,
        HealthFill = nil,

        TracerGui = nil,
        Tracer = nil,

        SkeletonGui = nil,
        SkeletonParts = {},

        HeadMarkerGui = nil,
        HeadMarker = nil,

        RootMarkerGui = nil,
        RootMarker = nil,

        OffscreenGui = nil,
        Offscreen = nil,

        Connections = {},

        Visible = false,
        OnScreen = false,
        Occluded = false,

        LastDistance = 0,
        LastAlpha = 1,
        LastScreenPosition = nil,

        LastBox = nil,

        State = "Unknown",
        Tool = nil,
    }

    self.Entries[player] = entry

    return entry
end


function ESP:RemoveEntry(player)
    local entry =
        self.Entries[player]

    if not entry then
        return
    end

    for _, connection in ipairs(
        entry.Connections
    ) do
        Disconnect(connection)
    end

    entry.Connections = {}

    self:DestroyEntryVisuals(entry)

    self.Entries[player] = nil
end


function ESP:ClearEntries()
    local players = {}

    for player in pairs(
        self.Entries
    ) do
        table.insert(
            players,
            player
        )
    end

    for _, player in ipairs(players) do
        self:RemoveEntry(player)
    end
end



-- Destruction


function ESP:DestroyInstance(instance)
    if not instance then
        return
    end

    pcall(function()
        instance:Destroy()
    end)
end


function ESP:DestroyEntryVisuals(entry)
    if not entry then
        return
    end

    self:DestroyInstance(
        entry.Highlight
    )

    self:DestroyInstance(
        entry.Billboard
    )

    self:DestroyInstance(
        entry.BoxGui
    )

    self:DestroyInstance(
        entry.ScreenBoxGui
    )

    self:DestroyInstance(
        entry.TracerGui
    )

    self:DestroyInstance(
        entry.SkeletonGui
    )

    self:DestroyInstance(
        entry.HeadMarkerGui
    )

    self:DestroyInstance(
        entry.RootMarkerGui
    )

    self:DestroyInstance(
        entry.OffscreenGui
    )

    entry.Highlight = nil

    entry.Billboard = nil

    entry.NameLabel = nil
    entry.UsernameLabel = nil
    entry.DistanceLabel = nil
    entry.TeamLabel = nil
    entry.StatusLabel = nil
    entry.HealthTextLabel = nil
    entry.ToolLabel = nil

    entry.BoxGui = nil
    entry.BoxFrame = nil
    entry.BoxStroke = nil
    entry.BoxFill = nil

    entry.CornerParts = {}

    entry.ScreenBoxGui = nil
    entry.ScreenBoxParts = {}

    entry.HealthBackground = nil
    entry.HealthFill = nil

    entry.TracerGui = nil
    entry.Tracer = nil

    entry.SkeletonGui = nil
    entry.SkeletonParts = {}

    entry.HeadMarkerGui = nil
    entry.HeadMarker = nil

    entry.RootMarkerGui = nil
    entry.RootMarker = nil

    entry.OffscreenGui = nil
    entry.Offscreen = nil
end



-- Character binding


function ESP:BindCharacter(
    entry,
    character
)
    if not entry then
        return
    end

    if entry.Character == character
        and character ~= nil then

        return
    end

    entry.Character = character

    entry.Humanoid = nil
    entry.RootPart = nil
    entry.Head = nil

    for _, connection in ipairs(
        entry.Connections
    ) do
        Disconnect(connection)
    end

    entry.Connections = {}

    self:DestroyEntryVisuals(entry)

    if not character then
        return
    end

    entry.Humanoid =
        character:FindFirstChildOfClass(
            "Humanoid"
        )

    entry.RootPart =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    entry.Head =
        character:FindFirstChild(
            "Head"
        )

    table.insert(
        entry.Connections,

        character.ChildAdded:Connect(
            function(child)

                if child:IsA("Humanoid") then
                    entry.Humanoid = child

                elseif child.Name ==
                    "HumanoidRootPart" then

                    entry.RootPart = child

                elseif child.Name == "Head" then
                    entry.Head = child
                end
            end
        )
    )
end



-- Highlight / Chams


function ESP:CreateHighlight(entry)
    if not entry
        or not entry.Character then

        return nil
    end

    if entry.Highlight then
        return entry.Highlight
    end

    local highlight =
        New("Highlight")

    if not highlight then
        return nil
    end

    highlight.Name =
        "LuaTestESPHighlight"

    highlight.Adornee =
        entry.Character

    local depthMode =
        self:GetSetting(
            "HighlightDepthMode",
            "AlwaysOnTop"
        )

    if depthMode == "Occluded" then
        highlight.DepthMode =
            Enum.HighlightDepthMode.Occluded
    else
        highlight.DepthMode =
            Enum.HighlightDepthMode.AlwaysOnTop
    end

    highlight.FillTransparency =
        ClampNumber(
            self:GetSetting(
                "HighlightFillTransparency",
                0.55
            ),
            0,
            1,
            0.55
        )

    highlight.OutlineTransparency =
        ClampNumber(
            self:GetSetting(
                "HighlightOutlineTransparency",
                0
            ),
            0,
            1,
            0
        )

    highlight.Parent =
        entry.Character

    entry.Highlight = highlight

    return highlight
end


function ESP:UpdateHighlight(
    entry,
    color,
    alpha
)
    if not self:GetSetting(
        "Highlight",
        false
    ) then

        if entry.Highlight then
            self:DestroyInstance(
                entry.Highlight
            )

            entry.Highlight = nil
        end

        return
    end

    if not entry.Character then
        return
    end

    local highlight =
        entry.Highlight

    if not highlight then
        highlight =
            self:CreateHighlight(entry)
    end

    if not highlight then
        return
    end

    highlight.FillColor = color
    highlight.OutlineColor = color

    highlight.Enabled =
        alpha > 0

    local fill =
        ClampNumber(
            self:GetSetting(
                "HighlightFillTransparency",
                0.55
            ),
            0,
            1,
            0.55
        )

    local outline =
        ClampNumber(
            self:GetSetting(
                "HighlightOutlineTransparency",
                0
            ),
            0,
            1,
            0
        )

    highlight.FillTransparency =
        math.clamp(
            fill + (1 - alpha) * 0.4,
            0,
            1
        )

    highlight.OutlineTransparency =
        math.clamp(
            outline + (1 - alpha) * 0.5,
            0,
            1
        )
end



-- Billboard


function ESP:CreateBillboard(entry)
    if not entry
        or not entry.Character then

        return nil
    end

    if entry.Billboard then
        return entry.Billboard
    end

    local adornee =
        entry.Head
        or entry.RootPart

    if not adornee then
        return nil
    end

    local billboard =
        New("BillboardGui")

    if not billboard then
        return nil
    end

    billboard.Name =
        "LuaTestESPInfo"

    billboard.Adornee =
        adornee

    billboard.Size =
        UDim2.fromOffset(
            300,
            180
        )

    billboard.StudsOffset =
        Vector3.new(
            0,
            3.5,
            0
        )

    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false

    billboard.Parent = adornee

    entry.Billboard = billboard

    local function CreateLabel(
        name,
        position,
        height,
        textSize
    )
        local label =
            New("TextLabel")

        if not label then
            return nil
        end

        label.Name = name

        label.Position =
            position

        label.Size =
            UDim2.new(
                1,
                0,
                0,
                height
            )

        label.BackgroundTransparency = 1

        label.TextSize = textSize

        label.Font =
            Enum.Font.GothamBold

        label.TextStrokeTransparency =
            self:GetSetting(
                "TextOutlineTransparency",
                0
            )

        label.TextXAlignment =
            Enum.TextXAlignment.Center

        label.Parent =
            billboard

        return label
    end

    entry.NameLabel =
        CreateLabel(
            "Name",
            UDim2.fromOffset(0, 0),
            20,
            13
        )

    entry.UsernameLabel =
        CreateLabel(
            "Username",
            UDim2.fromOffset(0, 18),
            17,
            11
        )

    entry.DistanceLabel =
        CreateLabel(
            "Distance",
            UDim2.fromOffset(0, 35),
            17,
            11
        )

    entry.TeamLabel =
        CreateLabel(
            "Team",
            UDim2.fromOffset(0, 52),
            17,
            11
        )

    entry.StatusLabel =
        CreateLabel(
            "Status",
            UDim2.fromOffset(0, 69),
            17,
            11
        )

    entry.HealthTextLabel =
        CreateLabel(
            "Health",
            UDim2.fromOffset(0, 86),
            17,
            11
        )

    entry.ToolLabel =
        CreateLabel(
            "Tool",
            UDim2.fromOffset(0, 103),
            17,
            11
        )

    return billboard
end


function ESP:UpdateBillboard(
    entry,
    color,
    distance,
    alpha
)
    if not entry then
        return
    end

    if not entry.Billboard then
        self:CreateBillboard(entry)
    end

    local billboard =
        entry.Billboard

    if not billboard then
        return
    end

    local maxTextDistance =
        tonumber(
            self:GetSetting(
                "MaxTextDistance",
                2000
            )
        ) or 2000

    local textAllowed =
        distance <= maxTextDistance

    local showName =
        self:GetSetting(
            "Name",
            true
        )

    local showUsername =
        self:GetSetting(
            "ShowUsername",
            false
        )

    local showDistance =
        self:GetSetting(
            "Distance",
            true
        )

    local showTeam =
        self:GetSetting(
            "ShowTeam",
            false
        )

    local showStatus =
        self:GetSetting(
            "ShowStatus",
            false
        )

    local showHealth =
        self:GetSetting(
            "Health",
            true
        )

    local showTool =
        self:GetSetting(
            "ShowTool",
            false
        )

    billboard.Enabled =
        textAllowed
        and (
            showName
            or showUsername
            or showDistance
            or showTeam
            or showStatus
            or showHealth
            or showTool
        )

    local outline =
        self:GetSetting(
            "TextOutline",
            true
        )

    local outlineTransparency =
        self:GetSetting(
            "TextOutlineTransparency",
            0
        )

    local function ApplyText(label)
        if not label then
            return
        end

        label.TextStrokeTransparency =
            outline
            and outlineTransparency
            or 1

        label.TextTransparency =
            1 - alpha
    end

    if entry.NameLabel then
        entry.NameLabel.Visible =
            showName
            and textAllowed

        entry.NameLabel.TextSize =
            ClampNumber(
                self:GetSetting(
                    "NameSize",
                    13
                ),
                8,
                32,
                13
            )

        local mode =
            self:GetSetting(
                "NameMode",
                "DisplayName"
            )

        if mode == "Username" then
            entry.NameLabel.Text =
                entry.Player.Name

        elseif mode == "Both" then
            entry.NameLabel.Text =
                entry.Player.DisplayName
                .. " ["
                .. entry.Player.Name
                .. "]"

        else
            entry.NameLabel.Text =
                entry.Player.DisplayName
        end

        entry.NameLabel.TextColor3 =
            color

        ApplyText(entry.NameLabel)
    end

    if entry.UsernameLabel then
        entry.UsernameLabel.Visible =
            showUsername
            and textAllowed

        entry.UsernameLabel.Text =
            "@"
            .. entry.Player.Name

        entry.UsernameLabel.TextColor3 =
            Color3.new(1, 1, 1)

        ApplyText(entry.UsernameLabel)
    end

    if entry.DistanceLabel then
        entry.DistanceLabel.Visible =
            showDistance
            and textAllowed

        entry.DistanceLabel.Text =
            string.format(
                "%d studs",
                math.floor(
                    distance + 0.5
                )
            )

        entry.DistanceLabel.TextColor3 =
            Color3.new(1, 1, 1)

        ApplyText(entry.DistanceLabel)
    end

    if entry.TeamLabel then
        entry.TeamLabel.Visible =
            showTeam
            and textAllowed

        entry.TeamLabel.Text =
            entry.Player.Team
            and entry.Player.Team.Name
            or "No Team"

        entry.TeamLabel.TextColor3 =
            color

        ApplyText(entry.TeamLabel)
    end

    if entry.StatusLabel then
        entry.StatusLabel.Visible =
            showStatus
            and textAllowed

        entry.StatusLabel.Text =
            entry.State

        entry.StatusLabel.TextColor3 =
            color

        ApplyText(entry.StatusLabel)
    end

    if entry.HealthTextLabel then
        entry.HealthTextLabel.Visible =
            showHealth
            and textAllowed

        if entry.Humanoid then
            local maxHealth =
                math.max(
                    entry.Humanoid.MaxHealth,
                    0.001
                )

            local health =
                math.clamp(
                    entry.Humanoid.Health
                    / maxHealth,
                    0,
                    1
                )

            if self:GetSetting(
                "ShowMaxHealth",
                false
            ) then

                entry.HealthTextLabel.Text =
                    string.format(
                        "HP: %d / %d",
                        math.floor(
                            entry.Humanoid.Health
                            + 0.5
                        ),
                        math.floor(
                            entry.Humanoid.MaxHealth
                            + 0.5
                        )
                    )
            else
                entry.HealthTextLabel.Text =
                    string.format(
                        "HP: %d%%",
                        math.floor(
                            health * 100
                            + 0.5
                        )
                    )
            end
        else
            entry.HealthTextLabel.Text =
                "HP: --"
        end

        entry.HealthTextLabel.TextColor3 =
            GetHealthColor(
                entry.Humanoid
                and (
                    entry.Humanoid.Health
                    / math.max(
                        entry.Humanoid.MaxHealth,
                        0.001
                    )
                )
                or 0
            )

        ApplyText(entry.HealthTextLabel)
    end

    if entry.ToolLabel then
        entry.ToolLabel.Visible =
            showTool
            and textAllowed

        local tool =
            entry.Character
            and entry.Character:FindFirstChildOfClass(
                "Tool"
            )

        entry.Tool =
            tool

        entry.ToolLabel.Text =
            tool
            and (
                "Tool: "
                .. tool.Name
            )
            or "Tool: None"

        entry.ToolLabel.TextColor3 =
            Color3.new(1, 1, 1)

        ApplyText(entry.ToolLabel)
    end
end



-- Billboard Box


function ESP:CreateBillboardBox(entry)
    if not entry
        or not entry.RootPart then

        return nil
    end

    if entry.BoxGui then
        return entry.BoxGui
    end

    local gui =
        New("BillboardGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESPBox"

    gui.Adornee =
        entry.RootPart

    gui.Size =
        UDim2.fromOffset(
            70,
            110
        )

    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false

    gui.Parent =
        entry.RootPart

    local frame =
        New("Frame")

    if not frame then
        gui:Destroy()
        return nil
    end

    frame.Name = "Box"

    frame.Size =
        UDim2.fromScale(
            1,
            1
        )

    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0

    frame.Parent = gui

    local stroke =
        New("UIStroke")

    if stroke then
        stroke.Thickness =
            ClampNumber(
                self:GetSetting(
                    "BoxThickness",
                    1.5
                ),
                0.5,
                10,
                1.5
            )

        stroke.Parent = frame
    end

    local fill =
        New("Frame")

    if fill then
        fill.Name = "Fill"

        fill.Size =
            UDim2.fromScale(
                1,
                1
            )

        fill.BorderSizePixel = 0

        fill.BackgroundTransparency =
            ClampNumber(
                self:GetSetting(
                    "BoxFillTransparency",
                    0.85
                ),
                0,
                1,
                0.85
            )

        fill.ZIndex = 0

        fill.Parent = frame
    end

    entry.BoxGui = gui
    entry.BoxFrame = frame
    entry.BoxStroke = stroke
    entry.BoxFill = fill

    return gui
end


function ESP:CreateCornerParts(parent)
    local parts = {}

    for index = 1, 8 do
        local part =
            New("Frame")

        if part then
            part.Name =
                "Corner_" .. index

            part.BorderSizePixel = 0

            part.Parent =
                parent

            parts[index] =
                part
        end
    end

    return parts
end


function ESP:UpdateCornerParts(
    entry,
    color,
    alpha
)
    local frame =
        entry.BoxFrame

    if not frame then
        return
    end

    local length =
        math.clamp(
            self:GetSetting(
                "CornerLength",
                0.25
            ),
            0.05,
            0.5
        )

    local thickness =
        ClampNumber(
            self:GetSetting(
                "BoxThickness",
                1.5
            ),
            0.5,
            10,
            1.5
        )

    if #entry.CornerParts == 0 then
        entry.CornerParts =
            self:CreateCornerParts(
                frame
            )
    end

    local parts =
        entry.CornerParts

    local width = 1
    local height = 1

    local positions = {
        {
            UDim2.fromScale(0, 0),
            UDim2.new(length, 0, 0, thickness)
        },

        {
            UDim2.fromScale(0, 0),
            UDim2.new(0, thickness, length, 0)
        },

        {
            UDim2.new(1 - length, 0, 0, 0),
            UDim2.new(length, 0, 0, thickness)
        },

        {
            UDim2.new(1, -thickness, 0, 0),
            UDim2.new(0, thickness, length, 0)
        },

        {
            UDim2.new(0, 0, 1, -thickness),
            UDim2.new(length, 0, 0, thickness)
        },

        {
            UDim2.new(0, 0, 1 - length, 0),
            UDim2.new(0, thickness, length, 0)
        },

        {
            UDim2.new(1 - length, 0, 1, -thickness),
            UDim2.new(length, 0, 0, thickness)
        },

        {
            UDim2.new(1, -thickness, 1 - length, 0),
            UDim2.new(0, thickness, length, 0)
        },
    }

    for index, part in ipairs(parts) do
        local data =
            positions[index]

        if data then
            part.Position = data[1]
            part.Size = data[2]

            part.BackgroundColor3 =
                color

            part.BackgroundTransparency =
                1 - alpha

            part.Visible =
                alpha > 0
        end
    end
end


function ESP:UpdateBox(
    entry,
    color,
    alpha
)
    if not self:GetSetting(
        "Box",
        true
    ) then

        if entry.BoxGui then
            self:DestroyInstance(
                entry.BoxGui
            )

            entry.BoxGui = nil
            entry.BoxFrame = nil
            entry.BoxStroke = nil
            entry.BoxFill = nil
            entry.CornerParts = {}
        end

        return
    end

    if not entry.BoxGui then
        self:CreateBillboardBox(entry)
    end

    if not entry.BoxFrame then
        return
    end

    local style =
        self:GetSetting(
            "BoxStyle",
            "2D"
        )

    local stroke =
        entry.BoxStroke

    if stroke then
        stroke.Color =
            color

        stroke.Thickness =
            ClampNumber(
                self:GetSetting(
                    "BoxThickness",
                    1.5
                ),
                0.5,
                10,
                1.5
            )

        stroke.Transparency =
            1 - alpha

        stroke.Enabled =
            style == "Full"
    end

    if entry.BoxFill then
        entry.BoxFill.BackgroundColor3 =
            color

        entry.BoxFill.BackgroundTransparency =
            math.clamp(
                self:GetSetting(
                    "BoxFillTransparency",
                    0.85
                ) + (1 - alpha) * 0.15,
                0,
                1
            )

        entry.BoxFill.Visible =
            self:GetSetting(
                "BoxFill",
                false
            )
            and style ~= "Corner"
            and alpha > 0
    end

    entry.BoxFrame.Visible =
        style ~= "2D"
        and alpha > 0

    if style == "Corner" then
        self:UpdateCornerParts(
            entry,
            color,
            alpha
        )
    else
        for _, part in ipairs(
            entry.CornerParts
        ) do
            part.Visible = false
        end
    end
end



-- 2D Screen Box


function ESP:CreateScreenBox(entry)
    if entry.ScreenBoxGui then
        return entry.ScreenBoxGui
    end

    local localPlayer =
        PlayersService.LocalPlayer

    local playerGui =
        localPlayer
        and localPlayer:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return nil
    end

    local gui =
        New("ScreenGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESP2DBox"

    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false

    gui.DisplayOrder =
        self:GetSetting(
            "DisplayOrder",
            5
        )

    gui.Parent =
        playerGui

    entry.ScreenBoxGui = gui

    for index = 1, 8 do
        local part =
            New("Frame")

        if part then
            part.Name =
                "Part_" .. index

            part.BorderSizePixel = 0

            part.Visible = false

            part.Parent = gui

            entry.ScreenBoxParts[index] =
                part
        end
    end

    return gui
end


function ESP:GetBoundingBox()
    local character = self.Character

    if not character then
        return nil
    end

    local success, cf, size =
        pcall(
            function()
                return character:GetBoundingBox()
            end
        )

    if not success
        or not cf
        or not size then

        return nil
    end

    return cf, size
end


function ESP:GetScreenBox(entry)
    local character =
        entry.Character

    local camera =
        workspace.CurrentCamera

    if not character
        or not camera then

        return nil
    end

    local success, cf, size =
        pcall(
            function()
                return character:GetBoundingBox()
            end
        )

    if not success
        or not cf
        or not size then

        return nil
    end

    local half =
        size / 2

    local corners = {
        cf * Vector3.new(-half.X, -half.Y, -half.Z),
        cf * Vector3.new(-half.X, -half.Y, half.Z),
        cf * Vector3.new(-half.X, half.Y, -half.Z),
        cf * Vector3.new(-half.X, half.Y, half.Z),
        cf * Vector3.new(half.X, -half.Y, -half.Z),
        cf * Vector3.new(half.X, -half.Y, half.Z),
        cf * Vector3.new(half.X, half.Y, -half.Z),
        cf * Vector3.new(half.X, half.Y, half.Z),
    }

    local minX = math.huge
    local minY = math.huge
    local maxX = -math.huge
    local maxY = -math.huge

    local front = false

    for _, worldPoint in ipairs(corners) do
        local screen =
            camera:WorldToViewportPoint(
                worldPoint
            )

        if screen.Z > 0 then
            front = true
        end

        minX =
            math.min(
                minX,
                screen.X
            )

        minY =
            math.min(
                minY,
                screen.Y
            )

        maxX =
            math.max(
                maxX,
                screen.X
            )

        maxY =
            math.max(
                maxY,
                screen.Y
            )
    end

    if not front then
        return nil
    end

    local viewport =
        camera.ViewportSize

    local padding =
        ClampNumber(
            self:GetSetting(
                "BoxPadding",
                4
            ),
            0,
            30,
            4
        )

    minX =
        math.clamp(
            minX - padding,
            0,
            viewport.X
        )

    minY =
        math.clamp(
            minY - padding,
            0,
            viewport.Y
        )

    maxX =
        math.clamp(
            maxX + padding,
            0,
            viewport.X
        )

    maxY =
        math.clamp(
            maxY + padding,
            0,
            viewport.Y
        )

    return {
        X = minX,
        Y = minY,
        Width = math.max(
            maxX - minX,
            2
        ),
        Height = math.max(
            maxY - minY,
            2
        ),
    }
end


function ESP:UpdateScreenBox(
    entry,
    color,
    alpha
)
    local enabled =
        self:GetSetting(
            "Box",
            true
        )

    local style =
        self:GetSetting(
            "BoxStyle",
            "2D"
        )

    if not enabled
        or style ~= "2D" then

        if entry.ScreenBoxGui then
            for _, part in ipairs(
                entry.ScreenBoxParts
            ) do
                part.Visible = false
            end
        end

        return
    end

    if not entry.ScreenBoxGui then
        self:CreateScreenBox(entry)
    end

    if not entry.ScreenBoxGui then
        return
    end

    local box =
        self:GetScreenBox(entry)

    entry.LastBox = box

    if not box then
        for _, part in ipairs(
            entry.ScreenBoxParts
        ) do
            part.Visible = false
        end

        return
    end

    local thickness =
        ClampNumber(
            self:GetSetting(
                "BoxThickness",
                1.5
            ),
            0.5,
            10,
            1.5
        )

    local x = box.X
    local y = box.Y
    local width = box.Width
    local height = box.Height

    local cornerLength =
        math.clamp(
            width
            * self:GetSetting(
                "CornerLength",
                0.25
            ),
            5,
            width / 2
        )

    local verticalLength =
        math.clamp(
            height
            * self:GetSetting(
                "CornerLength",
                0.25
            ),
            5,
            height / 2
        )

    local parts =
        entry.ScreenBoxParts

    local styleParts = {
        {
            UDim2.fromOffset(x, y),
            UDim2.fromOffset(
                width,
                thickness
            )
        },

        {
            UDim2.fromOffset(
                x,
                y + height - thickness
            ),
            UDim2.fromOffset(
                width,
                thickness
            )
        },

        {
            UDim2.fromOffset(x, y),
            UDim2.fromOffset(
                thickness,
                height
            )
        },

        {
            UDim2.fromOffset(
                x + width - thickness,
                y
            ),
            UDim2.fromOffset(
                thickness,
                height
            ),
        },
    }

    if self:GetSetting(
        "BoxFill",
        false
    ) then

        local fill =
            parts[5]

        if fill then
            fill.Position =
                UDim2.fromOffset(
                    x,
                    y
                )

            fill.Size =
                UDim2.fromOffset(
                    width,
                    height
                )

            fill.BackgroundColor3 =
                color

            fill.BackgroundTransparency =
                math.clamp(
                    self:GetSetting(
                        "BoxFillTransparency",
                        0.85
                    ) + (1 - alpha) * 0.15,
                    0,
                    1
                )

            fill.Visible =
                alpha > 0
        end
    elseif parts[5] then
        parts[5].Visible = false
    end

    for index = 1, 4 do
        local part =
            parts[index]

        local data =
            styleParts[index]

        if part and data then
            part.Position = data[1]
            part.Size = data[2]

            part.BackgroundColor3 =
                color

            part.BackgroundTransparency =
                1 - alpha

            part.Visible =
                alpha > 0
        end
    end

    if parts[6]
        and parts[7]
        and parts[8] then

        parts[6].Position =
            UDim2.fromOffset(
                x,
                y
            )

        parts[6].Size =
            UDim2.fromOffset(
                cornerLength,
                thickness
            )

        parts[7].Position =
            UDim2.fromOffset(
                x,
                y
            )

        parts[7].Size =
            UDim2.fromOffset(
                thickness,
                verticalLength
            )

        parts[8].Position =
            UDim2.fromOffset(
                x + width - cornerLength,
                y
            )

        parts[8].Size =
            UDim2.fromOffset(
                cornerLength,
                thickness
            )

        for _, index in ipairs({
            6,
            7,
            8
        }) do
            parts[index].BackgroundColor3 =
                color

            parts[index].BackgroundTransparency =
                1 - alpha
        end
    end
end



-- Health Bar


function ESP:CreateHealthBar(entry)
    if not entry
        or not entry.ScreenBoxGui then

        return nil
    end

    if entry.HealthBackground then
        return entry.HealthBackground
    end

    local background =
        New("Frame")

    if not background then
        return nil
    end

    background.Name =
        "HealthBackground"

    background.BorderSizePixel = 0

    background.BackgroundColor3 =
        Color3.fromRGB(
            25,
            25,
            25
        )

    background.BackgroundTransparency =
        0.25

    background.Parent =
        entry.ScreenBoxGui

    local fill =
        New("Frame")

    if not fill then
        background:Destroy()
        return nil
    end

    fill.Name =
        "HealthFill"

    fill.BorderSizePixel = 0

    fill.AnchorPoint =
        Vector2.new(
            0,
            1
        )

    fill.Position =
        UDim2.fromScale(
            0,
            1
        )

    fill.Size =
        UDim2.fromScale(
            1,
            1
        )

    fill.Parent =
        background

    entry.HealthBackground =
        background

    entry.HealthFill =
        fill

    return background
end


function ESP:UpdateHealthBar(
    entry,
    alpha
)
    if not self:GetSetting(
        "HealthBar",
        true
    ) then

        if entry.HealthBackground then
            self:DestroyInstance(
                entry.HealthBackground
            )

            entry.HealthBackground = nil
            entry.HealthFill = nil
        end

        return
    end

    if not entry.ScreenBoxGui then
        self:CreateScreenBox(entry)
    end

    if not entry.HealthBackground then
        self:CreateHealthBar(entry)
    end

    if not entry.HealthBackground
        or not entry.HealthFill
        or not entry.Humanoid then

        return
    end

    local box =
        entry.LastBox
        or self:GetScreenBox(entry)

    if not box then
        entry.HealthBackground.Visible =
            false

        return
    end

    local maxHealth =
        math.max(
            entry.Humanoid.MaxHealth,
            0.001
        )

    local health =
        math.clamp(
            entry.Humanoid.Health
            / maxHealth,
            0,
            1
        )

    local width =
        ClampNumber(
            self:GetSetting(
                "HealthBarWidth",
                4
            ),
            1,
            15,
            4
        )

    local gap =
        ClampNumber(
            self:GetSetting(
                "HealthBarGap",
                5
            ),
            1,
            30,
            5
        )

    local side =
        self:GetSetting(
            "HealthBarSide",
            "Left"
        )

    local x

    if side == "Right" then
        x =
            box.X
            + box.Width
            + gap
    else
        x =
            box.X
            - gap
            - width
    end

    entry.HealthBackground.Position =
        UDim2.fromOffset(
            x,
            box.Y
        )

    entry.HealthBackground.Size =
        UDim2.fromOffset(
            width,
            box.Height
        )

    entry.HealthFill.Size =
        UDim2.new(
            1,
            0,
            health,
            0
        )

    entry.HealthFill.BackgroundColor3 =
        GetHealthColor(
            health
        )

    entry.HealthBackground.BackgroundTransparency =
        math.clamp(
            0.25 + (1 - alpha),
            0,
            1
        )

    entry.HealthFill.BackgroundTransparency =
        1 - alpha

    entry.HealthBackground.Visible =
        alpha > 0
end



-- Tracer


function ESP:CreateTracer(entry)
    if entry.TracerGui then
        return entry.TracerGui
    end

    local player =
        PlayersService.LocalPlayer

    local playerGui =
        player
        and player:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return nil
    end

    local gui =
        New("ScreenGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESPTracer"

    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false

    gui.DisplayOrder =
        self:GetSetting(
            "DisplayOrder",
            5
        )

    gui.Parent =
        playerGui

    local line =
        New("Frame")

    if not line then
        gui:Destroy()
        return nil
    end

    line.Name =
        "Tracer"

    line.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    line.BorderSizePixel = 0

    line.Size =
        UDim2.fromOffset(
            0,
            1
        )

    line.Visible = false

    line.Parent = gui

    entry.TracerGui = gui
    entry.Tracer = line

    return gui
end


function ESP:UpdateTracer(
    entry,
    color,
    alpha,
    screenPosition
)
    if not self:GetSetting(
        "Tracer",
        false
    ) then

        if entry.TracerGui then
            self:DestroyInstance(
                entry.TracerGui
            )

            entry.TracerGui = nil
            entry.Tracer = nil
        end

        return
    end

    if not entry.TracerGui then
        self:CreateTracer(entry)
    end

    if not entry.Tracer then
        return
    end

    if not screenPosition
        or not screenPosition.Visible then

        entry.Tracer.Visible = false
        return
    end

    local camera =
        workspace.CurrentCamera

    if not camera then
        entry.Tracer.Visible = false
        return
    end

    local viewport =
        camera.ViewportSize

    local originType =
        self:GetSetting(
            "TracerOrigin",
            "Bottom"
        )

    local origin

    if originType == "Center" then
        origin =
            Vector2.new(
                viewport.X / 2,
                viewport.Y / 2
            )

    elseif originType == "Top" then
        origin =
            Vector2.new(
                viewport.X / 2,
                0
            )

    else
        origin =
            Vector2.new(
                viewport.X / 2,
                viewport.Y
            )
    end

    local target =
        Vector2.new(
            screenPosition.X,
            screenPosition.Y
        )

    local difference =
        target - origin

    local length =
        difference.Magnitude

    if length <= 1 then
        entry.Tracer.Visible = false
        return
    end

    local midpoint =
        (origin + target) / 2

    entry.Tracer.Position =
        UDim2.fromOffset(
            midpoint.X,
            midpoint.Y
        )

    entry.Tracer.Size =
        UDim2.fromOffset(
            length,
            ClampNumber(
                self:GetSetting(
                    "TracerThickness",
                    1.5
                ),
                0.5,
                10,
                1.5
            )
        )

    entry.Tracer.Rotation =
        math.deg(
            math.atan2(
                difference.Y,
                difference.X
            )
        )

    entry.Tracer.BackgroundColor3 =
        color

    entry.Tracer.BackgroundTransparency =
        1 - alpha

    entry.Tracer.Visible =
        true
end



-- Skeleton


function ESP:GetSkeletonPairs(character)
    if not character then
        return {}
    end

    local upperTorso =
        character:FindFirstChild(
            "UpperTorso"
        )

    local lowerTorso =
        character:FindFirstChild(
            "LowerTorso"
        )

    if upperTorso and lowerTorso then
        return {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},

            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},

            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},

            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},

            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
        }
    end

    return {
        {"Head", "Torso"},

        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},

        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    }
end


function ESP:CreateSkeleton(entry)
    if not entry
        or not entry.Character then

        return nil
    end

    if entry.SkeletonGui then
        return entry.SkeletonGui
    end

    local player =
        PlayersService.LocalPlayer

    local playerGui =
        player
        and player:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return nil
    end

    local gui =
        New("ScreenGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESPSkeleton"

    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false

    gui.DisplayOrder =
        self:GetSetting(
            "DisplayOrder",
            5
        )

    gui.Parent =
        playerGui

    entry.SkeletonGui =
        gui

    for index, pair in ipairs(
        self:GetSkeletonPairs(
            entry.Character
        )
    ) do

        local line =
            New("Frame")

        if line then
            line.Name =
                "Bone_" .. index

            line.AnchorPoint =
                Vector2.new(
                    0.5,
                    0.5
                )

            line.BorderSizePixel = 0

            line.Visible = false

            line.Parent = gui

            entry.SkeletonParts[index] =
                {
                    From = pair[1],
                    To = pair[2],
                    Line = line,
                }
        end
    end

    return gui
end


function ESP:UpdateSkeleton(
    entry,
    color,
    alpha
)
    if not self:GetSetting(
        "Skeleton",
        false
    ) then

        if entry.SkeletonGui then
            self:DestroyInstance(
                entry.SkeletonGui
            )

            entry.SkeletonGui = nil
            entry.SkeletonParts = {}
        end

        return
    end

    if not entry.SkeletonGui then
        self:CreateSkeleton(entry)
    end

    if not entry.SkeletonGui then
        return
    end

    local camera =
        workspace.CurrentCamera

    if not camera then
        return
    end

    local character =
        entry.Character

    if not character then
        return
    end

    for _, bone in ipairs(
        entry.SkeletonParts
    ) do

        local fromPart =
            character:FindFirstChild(
                bone.From
            )

        local toPart =
            character:FindFirstChild(
                bone.To
            )

        local line =
            bone.Line

        if fromPart
            and toPart
            and line then

            local fromPosition,
                fromVisible =
                camera:WorldToViewportPoint(
                    fromPart.Position
                )

            local toPosition,
                toVisible =
                camera:WorldToViewportPoint(
                    toPart.Position
                )

            if fromVisible
                and toVisible
                and fromPosition.Z > 0
                and toPosition.Z > 0 then

                local from =
                    Vector2.new(
                        fromPosition.X,
                        fromPosition.Y
                    )

                local to =
                    Vector2.new(
                        toPosition.X,
                        toPosition.Y
                    )

                local difference =
                    to - from

                local length =
                    difference.Magnitude

                local midpoint =
                    (from + to) / 2

                line.Position =
                    UDim2.fromOffset(
                        midpoint.X,
                        midpoint.Y
                    )

                line.Size =
                    UDim2.fromOffset(
                        length,
                        ClampNumber(
                            self:GetSetting(
                                "SkeletonThickness",
                                1.5
                            ),
                            0.5,
                            8,
                            1.5
                        )
                    )

                line.Rotation =
                    math.deg(
                        math.atan2(
                            difference.Y,
                            difference.X
                        )
                    )

                line.BackgroundColor3 =
                    color

                line.BackgroundTransparency =
                    1 - alpha

                line.Visible =
                    alpha > 0
            else
                line.Visible = false
            end
        elseif line then
            line.Visible = false
        end
    end
end



-- Markers


function ESP:CreateMarker(
    entry,
    part,
    name,
    size
)
    if not entry
        or not part then

        return nil
    end

    local gui =
        New("BillboardGui")

    if not gui then
        return nil
    end

    gui.Name = name

    gui.Adornee = part

    gui.Size =
        UDim2.fromOffset(
            size,
            size
        )

    gui.AlwaysOnTop = true
    gui.ResetOnSpawn = false

    gui.Parent = part

    local frame =
        New("Frame")

    if not frame then
        gui:Destroy()
        return nil
    end

    frame.Size =
        UDim2.fromScale(
            1,
            1
        )

    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0

    frame.Parent = gui

    local stroke =
        New("UIStroke")

    if stroke then
        stroke.Thickness = 1.5
        stroke.Parent = frame
    end

    return gui, frame
end


function ESP:CreateHeadMarker(entry)
    if entry.HeadMarkerGui then
        return entry.HeadMarkerGui
    end

    local head =
        entry.Head
        or self:GetHead(
            entry.Player
        )

    if not head then
        return nil
    end

    local gui, frame =
        self:CreateMarker(
            entry,
            head,
            "LuaTestESPHeadMarker",
            self:GetSetting(
                "HeadMarkerSize",
                5
            )
        )

    if not gui then
        return nil
    end

    entry.HeadMarkerGui = gui
    entry.HeadMarker = frame

    return gui
end


function ESP:CreateRootMarker(entry)
    if entry.RootMarkerGui then
        return entry.RootMarkerGui
    end

    local root =
        entry.RootPart

    if not root then
        return nil
    end

    local gui, frame =
        self:CreateMarker(
            entry,
            root,
            "LuaTestESPRootMarker",
            self:GetSetting(
                "RootMarkerSize",
                5
            )
        )

    if not gui then
        return nil
    end

    entry.RootMarkerGui = gui
    entry.RootMarker = frame

    return gui
end


function ESP:UpdateMarkers(
    entry,
    color,
    alpha
)
    local headEnabled =
        self:GetSetting(
            "HeadMarker",
            false
        )

    local rootEnabled =
        self:GetSetting(
            "RootMarker",
            false
        )

    if headEnabled then
        if not entry.HeadMarkerGui then
            self:CreateHeadMarker(entry)
        end

        if entry.HeadMarker then
            entry.HeadMarker.Visible =
                alpha > 0

            local stroke =
                entry.HeadMarker:FindFirstChildOfClass(
                    "UIStroke"
                )

            if stroke then
                stroke.Color =
                    color

                stroke.Transparency =
                    1 - alpha
            end
        end
    elseif entry.HeadMarkerGui then
        self:DestroyInstance(
            entry.HeadMarkerGui
        )

        entry.HeadMarkerGui = nil
        entry.HeadMarker = nil
    end

    if rootEnabled then
        if not entry.RootMarkerGui then
            self:CreateRootMarker(entry)
        end

        if entry.RootMarker then
            entry.RootMarker.Visible =
                alpha > 0

            local stroke =
                entry.RootMarker:FindFirstChildOfClass(
                    "UIStroke"
                )

            if stroke then
                stroke.Color =
                    color

                stroke.Transparency =
                    1 - alpha
            end
        end
    elseif entry.RootMarkerGui then
        self:DestroyInstance(
            entry.RootMarkerGui
        )

        entry.RootMarkerGui = nil
        entry.RootMarker = nil
    end
end



-- Offscreen indicator


function ESP:CreateOffscreen(entry)
    if entry.OffscreenGui then
        return entry.OffscreenGui
    end

    local player =
        PlayersService.LocalPlayer

    local playerGui =
        player
        and player:FindFirstChildOfClass(
            "PlayerGui"
        )

    if not playerGui then
        return nil
    end

    local gui =
        New("ScreenGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESPOffscreen"

    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false

    gui.DisplayOrder =
        self:GetSetting(
            "DisplayOrder",
            5
        )

    gui.Parent = playerGui

    local arrow =
        New("TextLabel")

    if not arrow then
        gui:Destroy()
        return nil
    end

    arrow.Size =
        UDim2.fromOffset(
            30,
            30
        )

    arrow.AnchorPoint =
        Vector2.new(
            0.5,
            0.5
        )

    arrow.BackgroundTransparency = 1

    arrow.Text =
        "▲"

    arrow.Font =
        Enum.Font.GothamBold

    arrow.TextSize =
        self:GetSetting(
            "OffscreenSize",
            12
        )

    arrow.Visible = false

    arrow.Parent = gui

    entry.OffscreenGui = gui
    entry.Offscreen = arrow

    return gui
end


function ESP:UpdateOffscreen(
    entry,
    color,
    alpha,
    screenPosition
)
    if not self:GetSetting(
        "OffscreenIndicator",
        false
    ) then

        if entry.OffscreenGui then
            self:DestroyInstance(
                entry.OffscreenGui
            )

            entry.OffscreenGui = nil
            entry.Offscreen = nil
        end

        return
    end

    if not entry.OffscreenGui then
        self:CreateOffscreen(entry)
    end

    local arrow =
        entry.Offscreen

    if not arrow then
        return
    end

    local camera =
        workspace.CurrentCamera

    if not camera
        or not entry.RootPart then

        arrow.Visible = false
        return
    end

    if screenPosition
        and screenPosition.Visible then

        arrow.Visible = false
        return
    end

    local viewport =
        camera.ViewportSize

    local center =
        Vector2.new(
            viewport.X / 2,
            viewport.Y / 2
        )

    local projected =
        camera:WorldToViewportPoint(
            entry.RootPart.Position
        )

    local target =
        Vector2.new(
            projected.X,
            projected.Y
        )

    if projected.Z < 0 then
        target =
            center
            - (target - center)
    end

    local direction =
        target - center

    if direction.Magnitude <= 0 then
        arrow.Visible = false
        return
    end

    direction =
        direction.Unit

    local radius =
        math.max(
            30,
            math.min(
                viewport.X,
                viewport.Y
            ) / 2
            - self:GetSetting(
                "OffscreenDistance",
                80
            )
        )

    local position =
        center
        + direction * radius

    arrow.Position =
        UDim2.fromOffset(
            position.X,
            position.Y
        )

    arrow.Rotation =
        math.deg(
            math.atan2(
                direction.Y,
                direction.X
            )
        ) + 90

    arrow.TextColor3 =
        color

    arrow.TextTransparency =
        1 - alpha

    arrow.TextSize =
        ClampNumber(
            self:GetSetting(
                "OffscreenSize",
                12
            ),
            8,
            40,
            12
        )

    arrow.Visible =
        alpha > 0
end



-- Color


function ESP:IsFriend(player)
    local localPlayer =
        PlayersService.LocalPlayer

    if not localPlayer
        or not player then

        return false
    end

    local success, result =
        pcall(
            function()
                return localPlayer:IsFriendsWith(
                    player.UserId
                )
            end
        )

    return success
        and result == true
end


function ESP:GetColor(player)
    if self:IsFriend(player) then
        local friendColor =
            self:GetSetting(
                "FriendColor",
                Color3.fromRGB(
                    80,
                    170,
                    255
                )
            )

        if IsColor3(friendColor) then
            return friendColor
        end
    end

    if self:GetSetting(
        "UseEnemyColor",
        false
    ) then

        local localPlayer =
            PlayersService.LocalPlayer

        if localPlayer
            and localPlayer.Team
            and player.Team
            and localPlayer.Team ~= player.Team then

            local enemyColor =
                self:GetSetting(
                    "EnemyColor",
                    Color3.fromRGB(
                        255,
                        80,
                        80
                    )
                )

            if IsColor3(enemyColor) then
                return enemyColor
            end
        end
    end

    if self.Visuals
        and type(self.Visuals.GetColor)
            == "function" then

        local success, color =
            pcall(
                function()
                    return self.Visuals:GetColor(
                        player
                    )
                end
            )

        if success
            and IsColor3(color) then

            return color
        end
    end

    if self:GetSetting(
        "UseTeamColor",
        true
    ) then

        if player.Team then
            return player.Team.TeamColor.Color
        end
    end

    local customColor =
        self:GetSetting(
            "CustomColor",
            Color3.new(
                1,
                1,
                1
            )
        )

    if IsColor3(customColor) then
        return customColor
    end

    return Color3.new(
        1,
        1,
        1
    )
end



-- Distance


function ESP:GetDistance(player)
    if self.Players
        and type(self.Players.GetDistanceFromLocal)
            == "function" then

        local success, distance =
            pcall(
                function()
                    return self.Players:GetDistanceFromLocal(
                        player
                    )
                end
            )

        if success
            and type(distance) == "number" then

            return distance
        end
    end

    local root =
        self:GetRoot(player)

    local localPlayer =
        PlayersService.LocalPlayer

    local localRoot =
        localPlayer
        and self:GetRoot(
            localPlayer
        )

    if not root
        or not localRoot then

        return math.huge
    end

    return (
        root.Position
        - localRoot.Position
    ).Magnitude
end


function ESP:GetAlpha(distance)
    if not self:GetSetting(
        "FadeDistance",
        false
    ) then
        return 1
    end

    local startDistance =
        tonumber(
            self:GetSetting(
                "FadeStart",
                500
            )
        ) or 500

    local endDistance =
        tonumber(
            self:GetSetting(
                "FadeEnd",
                2000
            )
        ) or 2000

    if endDistance <= startDistance then
        return 1
    end

    return math.clamp(
        1 - (
            (distance - startDistance)
            / (
                endDistance
                - startDistance
            )
        ),
        0,
        1
    )
end



-- Screen position


function ESP:GetScreenPosition(player)
    local root =
        self:GetRoot(player)

    local camera =
        workspace.CurrentCamera

    if not root
        or not camera then

        return nil
    end

    local position, visible =
        camera:WorldToViewportPoint(
            root.Position
        )

    return {
        X = position.X,
        Y = position.Y,
        Z = position.Z,

        Visible =
            visible
            and position.Z > 0,
    }
end



-- Visibility


function ESP:IsVisible(entry)
    if not self:GetSetting(
        "VisibilityCheck",
        true
    ) then
        return true
    end

    local camera =
        workspace.CurrentCamera

    if not camera
        or not entry.RootPart then

        return true
    end

    local localPlayer =
        PlayersService.LocalPlayer

    local origin =
        camera.CFrame.Position

    local direction =
        entry.RootPart.Position
        - origin

    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    params.FilterDescendantsInstances = {
        localPlayer
        and localPlayer.Character,

        entry.Character,
    }

    local result =
        workspace:Raycast(
            origin,
            direction,
            params
        )

    return result == nil
end



-- State


function ESP:UpdateState(entry)
    if not entry.Humanoid then
        entry.State = "Unknown"
        return
    end

    if entry.Humanoid.Health <= 0 then
        entry.State = "Dead"
        return
    end

    local success, state =
        pcall(
            function()
                return entry.Humanoid:GetState()
            end
        )

    if success and state then
        entry.State =
            state.Name
    else
        entry.State =
            "Unknown"
    end
end



-- Hide / Show


function ESP:HideEntry(entry)
    if not entry then
        return
    end

    entry.Visible = false
    entry.OnScreen = false

    if entry.Billboard then
        entry.Billboard.Enabled = false
    end

    if entry.Tracer then
        entry.Tracer.Visible = false
    end

    if entry.Highlight then
        entry.Highlight.Enabled = false
    end

    if entry.BoxFrame then
        entry.BoxFrame.Visible = false
    end

    if entry.BoxFill then
        entry.BoxFill.Visible = false
    end

    if entry.HealthBackground then
        entry.HealthBackground.Visible = false
    end

    if entry.Offscreen then
        entry.Offscreen.Visible = false
    end

    for _, part in ipairs(
        entry.ScreenBoxParts
    ) do
        part.Visible = false
    end

    for _, bone in ipairs(
        entry.SkeletonParts
    ) do
        if bone.Line then
            bone.Line.Visible = false
        end
    end

    if entry.HeadMarker then
        entry.HeadMarker.Visible = false
    end

    if entry.RootMarker then
        entry.RootMarker.Visible = false
    end
end


function ESP:ShowEntry(entry)
    if not entry then
        return
    end

    if entry.Highlight then
        entry.Highlight.Enabled =
            self:GetSetting(
                "Highlight",
                false
            )
    end
end



-- Entry update


function ESP:UpdateEntry(entry)
    if not entry then
        return
    end

    local player =
        entry.Player

    if not self:IsValidPlayer(player) then
        self:HideEntry(entry)
        return
    end

    local character =
        self:GetCharacter(player)

    if not character then
        self:HideEntry(entry)

        if entry.Character then
            self:BindCharacter(
                entry,
                nil
            )
        end

        return
    end

    if entry.Character ~= character then
        self:BindCharacter(
            entry,
            character
        )
    end

    local humanoid =
        entry.Humanoid
        or self:GetHumanoid(player)

    local root =
        entry.RootPart
        or self:GetRoot(player)

    local head =
        entry.Head
        or self:GetHead(player)

    entry.Humanoid = humanoid
    entry.RootPart = root
    entry.Head = head

    if not humanoid
        or not root then

        self:HideEntry(entry)
        return
    end

    if self:GetSetting(
        "AliveOnly",
        true
    ) and humanoid.Health <= 0 then

        self:HideEntry(entry)
        return
    end

    self:UpdateState(entry)

    local distance =
        self:GetDistance(player)

    entry.LastDistance =
        distance

    local maxDistance =
        tonumber(
            self:GetSetting(
                "MaxDistance",
                2000
            )
        ) or 2000

    local minDistance =
        tonumber(
            self:GetSetting(
                "MinDistance",
                0
            )
        ) or 0

    if distance > maxDistance
        or distance < minDistance then

        self:HideEntry(entry)
        return
    end

    local alpha =
        self:GetAlpha(
            distance
        )

    entry.LastAlpha =
        alpha

    if alpha <= 0 then
        self:HideEntry(entry)
        return
    end

    local color =
        self:GetColor(player)

    local screenPosition =
        self:GetScreenPosition(
            player
        )

    entry.LastScreenPosition =
        screenPosition

    entry.OnScreen =
        screenPosition
        and screenPosition.Visible
        or false

    entry.Occluded =
        not self:IsVisible(entry)

    if self:GetSetting(
        "HideOccluded",
        false
    ) and entry.Occluded then

        self:HideEntry(entry)
        return
    end

    self:ShowEntry(entry)

    self:UpdateHighlight(
        entry,
        color,
        alpha
    )

    self:UpdateBillboard(
        entry,
        color,
        distance,
        alpha
    )

    self:UpdateBox(
        entry,
        color,
        alpha
    )

    self:UpdateScreenBox(
        entry,
        color,
        alpha
    )

    self:UpdateHealthBar(
        entry,
        alpha
    )

    self:UpdateTracer(
        entry,
        color,
        alpha,
        screenPosition
    )

    self:UpdateSkeleton(
        entry,
        color,
        alpha
    )

    self:UpdateMarkers(
        entry,
        color,
        alpha
    )

    self:UpdateOffscreen(
        entry,
        color,
        alpha,
        screenPosition
    )

    entry.Visible = true
end



-- Update


function ESP:Update(deltaTime)
    if not self.Enabled then
        return
    end

    if self:GetSetting(
        "Enabled",
        true
    ) ~= true then
        return
    end

    self._accumulator +=
        deltaTime or 0

    local updateRate =
        ClampNumber(
            self:GetSetting(
                "UpdateRate",
                60
            ),
            1,
            240,
            60
        )

    local interval =
        1 / updateRate

    if self._accumulator < interval then
        return
    end

    self._accumulator =
        self._accumulator - interval

    for player, entry in pairs(
        self.Entries
    ) do

        if player
            and player.Parent then

            SafeCall(
                function()
                    self:UpdateEntry(
                        entry
                    )
                end
            )
        else
            self:RemoveEntry(
                player
            )
        end
    end
end



-- Player events


function ESP:PlayerAdded(player)
    if player ==
        PlayersService.LocalPlayer then

        return
    end

    if self.Entries[player] then
        return
    end

    local entry =
        self:CreateEntry(
            player
        )

    if not entry then
        return
    end

    if player.Character then
        self:BindCharacter(
            entry,
            player.Character
        )
    end

    table.insert(
        entry.Connections,

        player.CharacterAdded:Connect(
            function(character)
                if not self.Enabled then
                    return
                end

                self:BindCharacter(
                    entry,
                    character
                )
            end
        )
    )

    table.insert(
        entry.Connections,

        player.CharacterRemoving:Connect(
            function(character)

                if entry.Character ==
                    character then

                    entry.Character = nil
                    entry.Humanoid = nil
                    entry.RootPart = nil
                    entry.Head = nil

                    self:DestroyEntryVisuals(
                        entry
                    )
                end
            end
        )
    )
end


function ESP:PlayerRemoving(player)
    self:RemoveEntry(
        player
    )
end



-- Start


function ESP:Start()
    if self.Running then
        return true
    end

    if not self.Initialized then
        warn(
            "[Lua Test] ESP must be initialized before starting"
        )

        return false
    end

    if self:GetSetting(
        "Enabled",
        true
    ) ~= true then

        return false
    end

    self.Running = true
    self.Enabled = true

    self._accumulator = 0

    self:ClearEntries()

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do

        if player ~=
            PlayersService.LocalPlayer then

            self:PlayerAdded(
                player
            )
        end
    end

    table.insert(
        self.Connections,

        PlayersService.PlayerAdded:Connect(
            function(player)
                self:PlayerAdded(
                    player
                )
            end
        )
    )

    table.insert(
        self.Connections,

        PlayersService.PlayerRemoving:Connect(
            function(player)
                self:PlayerRemoving(
                    player
                )
            end
        )
    )

    table.insert(
        self.Connections,

        RunService.RenderStepped:Connect(
            function(deltaTime)
                self:Update(
                    deltaTime
                )

                if self.WorldESP then
                    self.WorldESP:Update(deltaTime)
                end
            end
        )
    )

    if self.WorldESP
        and self:GetSetting("WorldESP", false) then
        self.WorldESP:Start()
    end

    return true
end



-- Stop


function ESP:Stop()
    self.Enabled = false
    self.Running = false

    self._accumulator = 0

    for _, connection in ipairs(
        self.Connections
    ) do
        Disconnect(connection)
    end

    self.Connections = {}

    if self.WorldESP then
        self.WorldESP:Stop()
    end

    self:ClearEntries()

    return true
end



-- FeatureManager interface


function ESP:Enable()
    self.Settings.Enabled = true

    return self:Start()
end


function ESP:Disable()
    self.Settings.Enabled = false

    return self:Stop()
end


function ESP:SetEnabled(enabled)
    enabled =
        enabled == true

    self.Settings.Enabled =
        enabled

    if enabled then
        self:Start()
    else
        self:Stop()
    end

    return self.Enabled
end


function ESP:Toggle()
    return self:SetEnabled(
        not self.Enabled
    )
end



-- Refresh


function ESP:Refresh()
    if not self.Initialized then
        return
    end

    for _, entry in pairs(
        self.Entries
    ) do

        if entry.Character then
            SafeCall(
                function()
                    self:UpdateEntry(
                        entry
                    )
                end
            )
        end
    end

    if self.WorldESP then
        self.WorldESP:Refresh()
    end
end



-- Statistics


function ESP:GetStatistics()
    local total = 0
    local visible = 0
    local initialized = 0
    local onScreen = 0
    local occluded = 0
    local alive = 0

    for _, entry in pairs(
        self.Entries
    ) do

        total += 1

        if entry.Visible then
            visible += 1
        end

        if entry.Character then
            initialized += 1
        end

        if entry.OnScreen then
            onScreen += 1
        end

        if entry.Occluded then
            occluded += 1
        end

        if entry.Humanoid
            and entry.Humanoid.Health > 0 then

            alive += 1
        end
    end

    return {
        Total = total,

        Visible = visible,

        Initialized = initialized,

        OnScreen = onScreen,

        Occluded = occluded,

        Alive = alive,

        Running = self.Running,

        Enabled = self.Enabled,

        WorldESP = self.WorldESP
            and self.WorldESP:GetStatistics()
            or nil,
    }
end


function ESP:GetPlayerInfo(player)
    local entry =
        self:GetEntry(
            player
        )

    if not entry then
        return nil
    end

    return {
        Player = player,

        Character = entry.Character,

        Distance =
            entry.LastDistance,

        Alpha =
            entry.LastAlpha,

        Visible =
            entry.Visible,

        OnScreen =
            entry.OnScreen,

        Occluded =
            entry.Occluded,

        State =
            entry.State,

        Tool =
            entry.Tool,

        Health =
            entry.Humanoid
            and entry.Humanoid.Health
            or 0,

        MaxHealth =
            entry.Humanoid
            and entry.Humanoid.MaxHealth
            or 0,

        Team =
            player.Team,

        Box =
            entry.LastBox,
    }
end


-- WorldESP convenience API

function ESP:RegisterWorld(instance, name, color)
    if not self.WorldESP then
        return nil
    end
    return self.WorldESP:Register(instance, name, color)
end

function ESP:UnregisterWorld(instance)
    if not self.WorldESP then
        return false
    end
    return self.WorldESP:Unregister(instance)
end

function ESP:ClearWorld()
    if not self.WorldESP then
        return false
    end
    self.WorldESP:Clear()
    return true
end

function ESP:ScanWorldTag(tag, name, color)
    if not self.WorldESP then
        return 0
    end
    return self.WorldESP:ScanTag(tag, name, color)
end

function ESP:ScanWorldFolder(folder, name, color)
    if not self.WorldESP then
        return 0
    end
    return self.WorldESP:ScanFolder(folder, name, color)
end

function ESP:GetWorldStatistics()
    if not self.WorldESP then
        return {
            Total = 0,
            Visible = 0,
            OnScreen = 0,
            Running = false,
            Enabled = false,
        }
    end
    return self.WorldESP:GetStatistics()
end



-- Initialize


function ESP:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Visuals =
        modules.Visuals

    self.Players =
        modules.Players

    self.Character =
        modules.Character

    self.Math =
        modules.Math

    self.Cleanup =
        modules.Cleanup

    self.Config =
        modules.Config

    if self.WorldESP then
        self.WorldESP.Settings.Enabled = self:GetSetting("WorldESP", false)
        self.WorldESP.Settings.Highlight = self:GetSetting("WorldHighlight", false)
        self.WorldESP.Settings.Billboard = self:GetSetting("WorldBillboard", true)
        self.WorldESP.Settings.Name = self:GetSetting("WorldName", true)
        self.WorldESP.Settings.Distance = self:GetSetting("WorldDistance", true)
        self.WorldESP.Settings.Box2D = self:GetSetting("WorldBox2D", false)
        self.WorldESP.Settings.Tracer = self:GetSetting("WorldTracer", false)
        self.WorldESP.Settings.MaxDistance = self:GetSetting("WorldMaxDistance", 2000)
        self.WorldESP.Settings.MinDistance = self:GetSetting("WorldMinDistance", 0)
        self.WorldESP.Settings.FadeDistance = self:GetSetting("WorldFadeDistance", false)
        self.WorldESP.Settings.FadeStart = self:GetSetting("WorldFadeStart", 500)
        self.WorldESP.Settings.FadeEnd = self:GetSetting("WorldFadeEnd", 2000)
        self.WorldESP.Settings.UpdateRate = self:GetSetting("WorldUpdateRate", 30)
        self.WorldESP.Settings.AutoScan = self:GetSetting("WorldAutoScan", false)
        self.WorldESP.Settings.Tags = self:GetSetting("WorldTags", {})
        self.WorldESP.Settings.Folders = self:GetSetting("WorldFolders", {})
        self.WorldESP.Settings.DefaultColor = self:GetSetting("WorldDefaultColor", Color3.new(1, 1, 1))
        self.WorldESP.Settings.HighlightFillTransparency = self:GetSetting("WorldHighlightFillTransparency", 0.55)
        self.WorldESP.Settings.HighlightOutlineTransparency = self:GetSetting("WorldHighlightOutlineTransparency", 0)
        self.WorldESP.Settings.DisplayOrder = self:GetSetting("WorldDisplayOrder", 6)
    end

    self.Initialized = true

    return self
end



-- Destroy


function ESP:Destroy()
    self:Stop()

    if self.WorldESP then
        self.WorldESP:Clear()
        self.WorldESP = nil
    end

    self.Visuals = nil
    self.Players = nil
    self.Character = nil
    self.Math = nil
    self.Cleanup = nil
    self.Config = nil

    self.Initialized = false

    return true
end


return ESP