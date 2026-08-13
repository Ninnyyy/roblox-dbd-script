local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local ESP = {
    Name = "ESP",

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

    Connections = {},
    Entries = {},

    Settings = {
        Enabled = true,

        -- =================================================
        -- General
        -- =================================================

        TeamCheck = false,
        EnemiesOnly = false,
        MaxDistance = 2000,

        -- =================================================
        -- Box
        -- =================================================

        Box = true,
        BoxStyle = "Full",
        BoxThickness = 1.5,

        -- =================================================
        -- Name
        -- =================================================

        Name = true,
        NameSize = 13,

        -- =================================================
        -- Distance
        -- =================================================

        Distance = true,

        -- =================================================
        -- Health
        -- =================================================

        Health = true,
        HealthBar = true,

        -- =================================================
        -- Tracer
        -- =================================================

        Tracer = false,
        TracerOrigin = "Bottom",

        -- =================================================
        -- Highlight
        -- =================================================

        Highlight = false,

        HighlightFillTransparency = 0.55,
        HighlightOutlineTransparency = 0,

        -- =================================================
        -- Status
        -- =================================================

        ShowStatus = false,

        -- =================================================
        -- Visual behavior
        -- =================================================

        UseTeamColor = true,

        FadeDistance = false,

        FadeStart = 500,
        FadeEnd = 2000,

        -- =================================================
        -- Update
        -- =================================================

        UpdateRate = 60,
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

        if success
            and value ~= nil then

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
        MaxDistance = 2000,

        Box = true,
        BoxStyle = "Full",
        BoxThickness = 1.5,

        Name = true,
        NameSize = 13,

        Distance = true,

        Health = true,
        HealthBar = true,

        Tracer = false,
        TracerOrigin = "Bottom",

        Highlight = false,
        HighlightFillTransparency = 0.55,
        HighlightOutlineTransparency = 0,

        ShowStatus = false,

        UseTeamColor = true,

        FadeDistance = false,
        FadeStart = 500,
        FadeEnd = 2000,

        UpdateRate = 60,
    }

    self:Refresh()

    return true
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

    local localPlayer =
        PlayersService.LocalPlayer

    if not localPlayer then
        return false
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

        if success
            and character then

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

        if success
            and root then

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

        if success
            and humanoid then

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

        Highlight = nil,

        Billboard = nil,
        NameLabel = nil,
        DistanceLabel = nil,
        StatusLabel = nil,
        HealthTextLabel = nil,

        BoxGui = nil,
        BoxFrame = nil,
        BoxStroke = nil,

        HealthBackground = nil,
        HealthFill = nil,

        TracerGui = nil,
        Tracer = nil,

        Connections = {},

        Visible = false,
        LastDistance = 0,
        LastAlpha = 1,
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


-- Visual destruction


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
        entry.TracerGui
    )

    entry.Highlight = nil

    entry.Billboard = nil
    entry.NameLabel = nil
    entry.DistanceLabel = nil
    entry.StatusLabel = nil
    entry.HealthTextLabel = nil

    entry.BoxGui = nil
    entry.BoxFrame = nil
    entry.BoxStroke = nil

    entry.HealthBackground = nil
    entry.HealthFill = nil

    entry.TracerGui = nil
    entry.Tracer = nil
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

    table.insert(
        entry.Connections,

        character.ChildAdded:Connect(
            function(child)
                if child:IsA("Humanoid") then
                    entry.Humanoid = child

                elseif child.Name
                    == "HumanoidRootPart" then

                    entry.RootPart = child

                elseif child.Name == "Head" then
                    if self:GetSetting(
                        "Name",
                        true
                    )
                        or self:GetSetting(
                            "Distance",
                            true
                        )
                        or self:GetSetting(
                            "ShowStatus",
                            false
                        ) then

                        self:CreateBillboard(
                            entry
                        )
                    end
                end
            end
        )
    )

    if self:GetSetting(
        "Highlight",
        false
    ) then
        self:CreateHighlight(entry)
    end

    self:CreateBillboard(entry)

    self:CreateBox(entry)
end


-- Highlight


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

    highlight.DepthMode =
        Enum.HighlightDepthMode.AlwaysOnTop

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
    if not entry then
        return
    end

    local enabled =
        self:GetSetting(
            "Highlight",
            false
        )

    if not enabled then
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

    local fillTransparency =
        ClampNumber(
            self:GetSetting(
                "HighlightFillTransparency",
                0.55
            ),
            0,
            1,
            0.55
        )

    local outlineTransparency =
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
            fillTransparency
                + (1 - alpha) * 0.4,
            0,
            1
        )

    highlight.OutlineTransparency =
        math.clamp(
            outlineTransparency
                + (1 - alpha) * 0.5,
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

    local head =
        entry.Character:FindFirstChild(
            "Head"
        )

    local root =
        entry.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    local adornee =
        head or root

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
            240,
            110
        )

    billboard.StudsOffset =
        Vector3.new(
            0,
            3.2,
            0
        )

    billboard.AlwaysOnTop = true

    billboard.ResetOnSpawn = false

    billboard.Parent = adornee

    entry.Billboard = billboard

    -- =====================================================
    -- Name
    -- =====================================================

    local nameLabel =
        New("TextLabel")

    if nameLabel then
        nameLabel.Name = "Name"

        nameLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                20
            )

        nameLabel.BackgroundTransparency = 1

        nameLabel.Text =
            entry.Player.DisplayName

        nameLabel.TextSize =
            ClampNumber(
                self:GetSetting(
                    "NameSize",
                    13
                ),
                8,
                32,
                13
            )

        nameLabel.Font =
            Enum.Font.GothamBold

        nameLabel.TextStrokeTransparency = 0

        nameLabel.Parent =
            billboard

        entry.NameLabel =
            nameLabel
    end

    -- =====================================================
    -- Distance
    -- =====================================================

    local distanceLabel =
        New("TextLabel")

    if distanceLabel then
        distanceLabel.Name =
            "Distance"

        distanceLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                20
            )

        distanceLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                18
            )

        distanceLabel.BackgroundTransparency = 1

        distanceLabel.TextSize = 12

        distanceLabel.Font =
            Enum.Font.Gotham

        distanceLabel.TextStrokeTransparency = 0

        distanceLabel.Parent =
            billboard

        entry.DistanceLabel =
            distanceLabel
    end

    -- =====================================================
    -- Status
    -- =====================================================

    local statusLabel =
        New("TextLabel")

    if statusLabel then
        statusLabel.Name =
            "Status"

        statusLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                38
            )

        statusLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                18
            )

        statusLabel.BackgroundTransparency = 1

        statusLabel.TextSize = 11

        statusLabel.Font =
            Enum.Font.Gotham

        statusLabel.TextStrokeTransparency = 0

        statusLabel.Visible =
            self:GetSetting(
                "ShowStatus",
                false
            )

        statusLabel.Parent =
            billboard

        entry.StatusLabel =
            statusLabel
    end

    -- =====================================================
    -- Health text
    -- =====================================================

    local healthLabel =
        New("TextLabel")

    if healthLabel then
        healthLabel.Name =
            "Health"

        healthLabel.Position =
            UDim2.new(
                0,
                0,
                0,
                56
            )

        healthLabel.Size =
            UDim2.new(
                1,
                0,
                0,
                18
            )

        healthLabel.BackgroundTransparency = 1

        healthLabel.TextSize = 11

        healthLabel.Font =
            Enum.Font.Gotham

        healthLabel.TextStrokeTransparency = 0

        healthLabel.Parent =
            billboard

        entry.HealthTextLabel =
            healthLabel
    end

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

    if not entry.Billboard
        and entry.Character then

        self:CreateBillboard(entry)
    end

    local billboard =
        entry.Billboard

    if not billboard then
        return
    end

    local showName =
        self:GetSetting(
            "Name",
            true
        )

    local showDistance =
        self:GetSetting(
            "Distance",
            true
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

    billboard.Enabled =
        showName
        or showDistance
        or showStatus
        or showHealth

    -- =====================================================
    -- Name
    -- =====================================================

    if entry.NameLabel then
        entry.NameLabel.Visible =
            showName

        entry.NameLabel.TextColor3 =
            color

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

        entry.NameLabel.TextTransparency =
            1 - alpha

        entry.NameLabel.Text =
            entry.Player.DisplayName
    end

    -- =====================================================
    -- Distance
    -- =====================================================

    if entry.DistanceLabel then
        entry.DistanceLabel.Visible =
            showDistance

        entry.DistanceLabel.Text =
            string.format(
                "%d studs",
                math.floor(
                    distance + 0.5
                )
            )

        entry.DistanceLabel.TextColor3 =
            Color3.new(
                1,
                1,
                1
            )

        entry.DistanceLabel.TextTransparency =
            1 - alpha
    end

    -- =====================================================
    -- Status
    -- =====================================================

    if entry.StatusLabel then
        entry.StatusLabel.Visible =
            showStatus

        if entry.Humanoid then
            if entry.Humanoid.Health <= 0 then
                entry.StatusLabel.Text =
                    "DEAD"
            else
                entry.StatusLabel.Text =
                    "ALIVE"
            end
        else
            entry.StatusLabel.Text =
                "UNKNOWN"
        end

        entry.StatusLabel.TextColor3 =
            color

        entry.StatusLabel.TextTransparency =
            1 - alpha
    end

    -- =====================================================
    -- Health
    -- =====================================================

    if entry.HealthTextLabel then
        entry.HealthTextLabel.Visible =
            showHealth

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

            entry.HealthTextLabel.Text =
                string.format(
                    "HP: %d%%",
                    math.floor(
                        health * 100 + 0.5
                    )
                )
        else
            entry.HealthTextLabel.Text =
                "HP: --"
        end

        entry.HealthTextLabel.TextColor3 =
            Color3.new(
                1,
                1,
                1
            )

        entry.HealthTextLabel.TextTransparency =
            1 - alpha
    end
end


-- Box


function ESP:CreateBox(entry)
    if not entry
        or not entry.Character then

        return nil
    end

    if entry.BoxGui then
        return entry.BoxGui
    end

    local root =
        entry.RootPart
        or entry.Character:FindFirstChild(
            "HumanoidRootPart"
        )

    if not root then
        return nil
    end

    local gui =
        New("BillboardGui")

    if not gui then
        return nil
    end

    gui.Name =
        "LuaTestESPBox"

    gui.Adornee =
        root

    gui.Size =
        UDim2.fromOffset(
            70,
            110
        )

    gui.AlwaysOnTop = true

    gui.ResetOnSpawn = false

    gui.Parent = root

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
        stroke.Name =
            "BoxStroke"

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

        stroke.Transparency = 0

        stroke.Parent = frame
    end

    entry.BoxGui = gui
    entry.BoxFrame = frame
    entry.BoxStroke = stroke

    return gui
end

function ESP:UpdateBox(
    entry,
    color,
    alpha
)
    local enabled =
        self:GetSetting(
            "Box",
            true
        )

    if not enabled then
        if entry.BoxGui then
            self:DestroyInstance(
                entry.BoxGui
            )

            entry.BoxGui = nil
            entry.BoxFrame = nil
            entry.BoxStroke = nil
        end

        return
    end

    if not entry.BoxGui then
        self:CreateBox(entry)
    end

    if not entry.BoxGui
        or not entry.BoxFrame then

        return
    end

    local style =
        self:GetSetting(
            "BoxStyle",
            "Full"
        )

    -- Current supported style.
    -- Additional styles can be added
    -- without changing the update system.
    if style == "Full" then
        entry.BoxFrame.Visible =
            alpha > 0
    else
        entry.BoxFrame.Visible =
            alpha > 0
    end

    local stroke =
        entry.BoxStroke

    if not stroke then
        stroke =
            entry.BoxFrame:FindFirstChild(
                "BoxStroke"
            )
    end

    if stroke then
        stroke.Color = color

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
    end
end


-- Health bar


function ESP:CreateHealthBar(entry)
    if not entry
        or not entry.BoxGui then

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

    background.AnchorPoint =
        Vector2.new(
            1,
            0
        )

    background.Position =
        UDim2.new(
            0,
            -5,
            0,
            0
        )

    background.Size =
        UDim2.new(
            0,
            4,
            1,
            0
        )

    background.BackgroundColor3 =
        Color3.fromRGB(
            30,
            30,
            30
        )

    background.BackgroundTransparency =
        0.25

    background.BorderSizePixel = 0

    background.Parent =
        entry.BoxGui

    local fill =
        New("Frame")

    if not fill then
        background:Destroy()
        return nil
    end

    fill.Name =
        "HealthFill"

    fill.AnchorPoint =
        Vector2.new(
            0,
            1
        )

    fill.Position =
        UDim2.new(
            0,
            0,
            1,
            0
        )

    fill.Size =
        UDim2.new(
            1,
            0,
            1,
            0
        )

    fill.BackgroundColor3 =
        Color3.fromRGB(
            80,
            255,
            100
        )

    fill.BorderSizePixel = 0

    fill.Parent =
        background

    entry.HealthBackground =
        background

    entry.HealthFill =
        fill

    return background
end

function ESP:UpdateHealthBar(entry)
    local enabled =
        self:GetSetting(
            "HealthBar",
            true
        )

    if not enabled then
        if entry.HealthBackground then
            self:DestroyInstance(
                entry.HealthBackground
            )

            entry.HealthBackground = nil
            entry.HealthFill = nil
        end

        return
    end

    if not entry.BoxGui then
        return
    end

    if not entry.HealthBackground then
        self:CreateHealthBar(entry)
    end

    if not entry.HealthFill
        or not entry.Humanoid then

        return
    end

    local humanoid =
        entry.Humanoid

    local maxHealth =
        math.max(
            humanoid.MaxHealth,
            0.001
        )

    local health =
        math.clamp(
            humanoid.Health
                / maxHealth,
            0,
            1
        )

    entry.HealthFill.Size =
        UDim2.new(
            1,
            0,
            health,
            0
        )

    if health > 0.5 then
        entry.HealthFill.BackgroundColor3 =
            Color3.fromRGB(
                80,
                255,
                100
            )

    elseif health > 0.25 then
        entry.HealthFill.BackgroundColor3 =
            Color3.fromRGB(
                255,
                220,
                80
            )

    else
        entry.HealthFill.BackgroundColor3 =
            Color3.fromRGB(
                255,
                80,
                80
            )
    end
end


-- Tracer


function ESP:CreateTracer(entry)
    if entry.TracerGui then
        return entry.TracerGui
    end

    local player =
        PlayersService.LocalPlayer

    if not player then
        return nil
    end

    local playerGui =
        player:FindFirstChildOfClass(
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

    gui.DisplayOrder = 5

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
    local enabled =
        self:GetSetting(
            "Tracer",
            false
        )

    if not enabled then
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

    local origin

    local originType =
        self:GetSetting(
            "TracerOrigin",
            "Bottom"
        )

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
            1
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

    entry.Tracer.Visible = true
end


-- Color


function ESP:GetColor(player)
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
            and typeof(color) == "Color3" then

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
        and self:GetRoot(localPlayer)

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
            / (endDistance - startDistance)
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


-- Entry update


function ESP:HideEntry(entry)
    if not entry then
        return
    end

    entry.Visible = false

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

    if entry.HealthBackground then
        entry.HealthBackground.Visible = false
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

    if entry.HealthBackground then
        entry.HealthBackground.Visible =
            self:GetSetting(
                "HealthBar",
                true
            )
    end
end

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

        self:BindCharacter(
            entry,
            nil
        )

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

    entry.Humanoid = humanoid
    entry.RootPart = root

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

    local distance =
        self:GetDistance(player)

    entry.LastDistance = distance

    local maxDistance =
        tonumber(
            self:GetSetting(
                "MaxDistance",
                2000
            )
        ) or 2000

    if distance > maxDistance then
        self:HideEntry(entry)
        return
    end

    local alpha =
        self:GetAlpha(distance)

    entry.LastAlpha = alpha

    if alpha <= 0 then
        self:HideEntry(entry)
        return
    end

    local color =
        self:GetColor(player)

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

    self:UpdateHealthBar(entry)

    local screenPosition =
        self:GetScreenPosition(player)

    self:UpdateTracer(
        entry,
        color,
        alpha,
        screenPosition
    )

    entry.Visible = true
end


-- Update all


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
            self:RemoveEntry(player)
        end
    end
end


-- Player events


function ESP:PlayerAdded(player)
    if player == PlayersService.LocalPlayer then
        return
    end

    if self.Entries[player] then
        return
    end

    local entry =
        self:CreateEntry(player)

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
                if entry.Character == character then
                    entry.Character = nil
                    entry.Humanoid = nil
                    entry.RootPart = nil

                    self:DestroyEntryVisuals(
                        entry
                    )
                end
            end
        )
    )
end

function ESP:PlayerRemoving(player)
    self:RemoveEntry(player)
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

        if player ~= PlayersService.LocalPlayer then
            self:PlayerAdded(player)
        end
    end

    table.insert(
        self.Connections,

        PlayersService.PlayerAdded:Connect(
            function(player)
                self:PlayerAdded(player)
            end
        )
    )

    table.insert(
        self.Connections,

        PlayersService.PlayerRemoving:Connect(
            function(player)
                self:PlayerRemoving(player)
            end
        )
    )

    table.insert(
        self.Connections,

        RunService.RenderStepped:Connect(
            function(deltaTime)
                self:Update(deltaTime)
            end
        )
    )

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

    self:ClearEntries()

    return true
end


-- FeatureManager interface


function ESP:Enable()
    return self:Start()
end

function ESP:Disable()
    return self:Stop()
end

function ESP:SetEnabled(enabled)
    enabled = enabled == true

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
            self:UpdateEntry(
                entry
            )
        end
    end
end


-- Initialize


function ESP:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules = modules or {}

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

    self.Initialized = true

    return self
end


-- Destroy


function ESP:Destroy()
    self:Stop()

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