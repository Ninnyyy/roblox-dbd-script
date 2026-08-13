--[[
    Lua Test Script
    Targeting.lua

    Shared targeting / selection module.

    Features:
        - Player validation
        - Character validation
        - Alive / dead checks
        - Team filtering
        - Friendly-fire filtering
        - Distance filtering
        - Field-of-view filtering
        - Line-of-sight checks
        - Nearest target selection
        - Screen-center target selection
        - Config integration
        - Target caching
        - Target state tracking
        - Character respawn handling
        - Target change callbacks
        - Safe lifecycle management
        - Cleanup support

    Designed to work with:
        Players.lua
        Character.lua
        Math.lua
        Cleanup.lua
        Config.lua
        Combat.lua
        ESP.lua
        GameFeatures.lua
]]

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Targeting = {
    Name = "Targeting",

    Enabled = false,
    Running = false,
    Initialized = false,

    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    LocalPlayer = nil,

    Connections = {},
    PlayerConnections = {},
    Cache = {},
    Targets = {},

    CurrentTarget = nil,
    PreviousTarget = nil,

    Settings = {
        Enabled = true,

        -- General
        TeamCheck = true,
        FriendlyFire = false,
        RequireAlive = true,

        -- Distance
        MaxDistance = 2000,
        MinDistance = 0,

        -- Visibility
        RequireLineOfSight = false,

        -- Selection
        SelectionMode = "Nearest",
        FieldOfView = 180,
        UseScreenCenter = true,

        -- Target point
        TargetPart = "HumanoidRootPart",

        -- Screen behavior
        RequireScreenVisible = false,

        -- Update
        UpdateRate = 30,

        -- Cache
        CacheEnabled = true,
        CacheLifetime = 1,

        -- State
        ClearOnDeath = true,
        ClearOnCharacterRemoving = true,
    },

    State = {
        LastUpdate = 0,
        TargetChanged = false,
        TargetAcquired = false,
        TargetLost = false,
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


local function DisconnectList(list)
    if type(list) ~= "table" then
        return
    end

    for _, connection in ipairs(list) do
        Disconnect(connection)
    end

    table.clear(list)
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
            "[Lua Test] Targeting error:",
            result
        )

        return false, result
    end

    return true, result
end


local function IsFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end


local function GetNumber(value, fallback)
    value = tonumber(value)

    if not IsFiniteNumber(value) then
        return fallback
    end

    return value
end




-- Configuration


function Targeting:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(function()
            return self.Config:Get(
                "Targeting." .. name,
                default
            )
        end)

        if success and value ~= nil then
            return value
        end
    end

    return default
end


function Targeting:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


function Targeting:GetSettings()
    return self.Settings
end




-- Local player


function Targeting:GetLocalPlayer()
    if self.LocalPlayer
        and self.LocalPlayer.Parent then

        return self.LocalPlayer
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    return self.LocalPlayer
end




-- Character helpers


function Targeting:GetCharacter(player)
    player = player or self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetCharacter) == "function" then

        local success, character = pcall(function()
            return self.Players:GetCharacter(player)
        end)

        if success and character then
            return character
        end
    end

    return player.Character
end


function Targeting:GetHumanoid(player)
    player = player or self:GetLocalPlayer()

    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    if self.Players
        and type(self.Players.GetHumanoid) == "function" then

        local success, humanoid = pcall(function()
            return self.Players:GetHumanoid(player)
        end)

        if success and humanoid then
            return humanoid
        end
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end


function Targeting:GetRoot(player)
    player = player or self:GetLocalPlayer()

    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    if self.Players
        and type(self.Players.GetRoot) == "function" then

        local success, root = pcall(function()
            return self.Players:GetRoot(player)
        end)

        if success and root then
            return root
        end
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end


function Targeting:GetHead(player)
    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild("Head")
end


function Targeting:GetTargetPart(player)
    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    local requested =
        tostring(
            self:GetSetting(
                "TargetPart",
                "HumanoidRootPart"
            )
        )

    local part =
        character:FindFirstChild(requested)

    if part
        and part:IsA("BasePart") then

        return part
    end

    local root =
        character:FindFirstChild(
            "HumanoidRootPart"
        )

    if root then
        return root
    end

    local head =
        character:FindFirstChild("Head")

    if head then
        return head
    end

    return nil
end




-- Team / friendship


function Targeting:IsSameTeam(playerA, playerB)
    if not playerA or not playerB then
        return false
    end

    if playerA.Team
        and playerB.Team then

        return playerA.Team ==
            playerB.Team
    end

    if playerA.TeamColor
        and playerB.TeamColor then

        return playerA.TeamColor ==
            playerB.TeamColor
    end

    return false
end


function Targeting:IsFriendly(player)
    local localPlayer =
        self:GetLocalPlayer()

    if not localPlayer
        or not player then

        return false
    end

    return self:IsSameTeam(
        localPlayer,
        player
    )
end




-- Character state


function Targeting:IsAlive(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end


function Targeting:GetHealth(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return 0
    end

    return math.max(
        humanoid.Health,
        0
    )
end


function Targeting:GetMaxHealth(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return 0
    end

    return math.max(
        humanoid.MaxHealth,
        0
    )
end


function Targeting:GetHealthPercent(player)
    local maxHealth =
        self:GetMaxHealth(player)

    if maxHealth <= 0 then
        return 0
    end

    return math.clamp(
        self:GetHealth(player)
            / maxHealth,
        0,
        1
    )
end




-- Distance


function Targeting:GetDistance(player)
    local localRoot =
        self:GetRoot()

    local targetRoot =
        self:GetRoot(player)

    if not localRoot
        or not targetRoot then

        return math.huge
    end

    return (
        localRoot.Position
        - targetRoot.Position
    ).Magnitude
end


function Targeting:IsInDistanceRange(player)
    local distance =
        self:GetDistance(player)

    if not IsFiniteNumber(distance) then
        return false
    end

    local minimum =
        math.max(
            0,
            GetNumber(
                self:GetSetting(
                    "MinDistance",
                    0
                ),
                0
            )
        )

    local maximum =
        GetNumber(
            self:GetSetting(
                "MaxDistance",
                2000
            ),
            2000
        )

    if maximum < minimum then
        maximum = minimum
    end

    return distance >= minimum
        and distance <= maximum
end




-- Screen position


function Targeting:GetScreenPosition(
    player,
    part
)
    local camera =
        workspace.CurrentCamera

    if not camera then
        return nil
    end

    part =
        part
        or self:GetTargetPart(player)

    if not part then
        return nil
    end

    local position, visible =
        camera:WorldToViewportPoint(
            part.Position
        )

    return {
        X = position.X,
        Y = position.Y,
        Z = position.Z,

        Visible =
            visible
            and position.Z > 0,

        OnScreen =
            position.X >= 0
            and position.X <= camera.ViewportSize.X
            and position.Y >= 0
            and position.Y <= camera.ViewportSize.Y,
    }
end


function Targeting:GetScreenDistance(player)
    local screen =
        self:GetScreenPosition(player)

    if not screen
        or not screen.Visible then

        return math.huge
    end

    local camera =
        workspace.CurrentCamera

    if not camera then
        return math.huge
    end

    local center =
        Vector2.new(
            camera.ViewportSize.X / 2,
            camera.ViewportSize.Y / 2
        )

    local point =
        Vector2.new(
            screen.X,
            screen.Y
        )

    return (
        point - center
    ).Magnitude
end


function Targeting:IsWithinFOV(player)
    local fov =
        GetNumber(
            self:GetSetting(
                "FieldOfView",
                180
            ),
            180
        )

    if fov <= 0 then
        return false
    end

    return self:GetScreenDistance(player)
        <= fov
end




-- Line of sight


function Targeting:HasLineOfSight(
    player,
    originPart,
    targetPart
)
    if not self:GetSetting(
        "RequireLineOfSight",
        false
    ) then
        return true
    end

    local localCharacter =
        self:GetCharacter()

    local targetCharacter =
        self:GetCharacter(player)

    if not targetCharacter then
        return false
    end

    originPart =
        originPart
        or self:GetRoot()

    targetPart =
        targetPart
        or self:GetTargetPart(player)

    if not originPart
        or not targetPart then

        return false
    end

    local origin =
        originPart.Position

    local target =
        targetPart.Position

    local direction =
        target - origin

    if direction.Magnitude <= 0 then
        return true
    end

    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    local ignored = {}

    if localCharacter then
        table.insert(
            ignored,
            localCharacter
        )
    end

    params.FilterDescendantsInstances =
        ignored

    local result =
        workspace:Raycast(
            origin,
            direction,
            params
        )

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(
        targetCharacter
    )
end




-- Player validation


function Targeting:IsValidPlayer(player)
    if not player then
        return false
    end

    local localPlayer =
        self:GetLocalPlayer()

    if not localPlayer then
        return false
    end

    if player == localPlayer then
        return false
    end

    if not player.Parent then
        return false
    end

    local character =
        self:GetCharacter(player)

    if not character
        or not character.Parent then

        return false
    end

    local root =
        self:GetRoot(player)

    if not root
        or not root.Parent then

        return false
    end

    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return false
    end

    if self:GetSetting(
        "RequireAlive",
        true
    ) then

        if humanoid.Health <= 0 then
            return false
        end
    end

    if self:GetSetting(
        "TeamCheck",
        true
    ) and not self:GetSetting(
        "FriendlyFire",
        false
    ) then

        if self:IsFriendly(player) then
            return false
        end
    end

    if not self:IsInDistanceRange(
        player
    ) then

        return false
    end

    if self:GetSetting(
        "RequireScreenVisible",
        false
    ) then

        local screen =
            self:GetScreenPosition(player)

        if not screen
            or not screen.Visible then

            return false
        end
    end

    if not self:HasLineOfSight(
        player
    ) then

        return false
    end

    return true
end




-- Target data


function Targeting:BuildTargetData(player)
    if not player then
        return nil
    end

    local character =
        self:GetCharacter(player)

    local humanoid =
        self:GetHumanoid(player)

    local root =
        self:GetRoot(player)

    local targetPart =
        self:GetTargetPart(player)

    if not character
        or not humanoid
        or not root then

        return nil
    end

    local distance =
        self:GetDistance(player)

    local screen =
        self:GetScreenPosition(
            player,
            targetPart
        )

    local screenDistance =
        self:GetScreenDistance(
            player
        )

    return {
        Player = player,

        Character = character,
        Humanoid = humanoid,

        RootPart = root,
        Head = self:GetHead(player),
        TargetPart = targetPart,

        Distance = distance,

        Health = math.max(
            humanoid.Health,
            0
        ),

        MaxHealth = math.max(
            humanoid.MaxHealth,
            0
        ),

        HealthPercent =
            self:GetHealthPercent(
                player
            ),

        Screen = screen,

        ScreenDistance =
            screenDistance,

        WithinFOV =
            self:IsWithinFOV(player),

        SameTeam =
            self:IsFriendly(player),

        Alive =
            humanoid.Health > 0,

        LineOfSight =
            self:HasLineOfSight(
                player
            ),

        Timestamp = os.clock(),
    }
end




-- Cache


function Targeting:GetCachedTargetData(player)
    if not self:GetSetting(
        "CacheEnabled",
        true
    ) then
        return nil
    end

    local cached =
        self.Cache[player]

    if not cached then
        return nil
    end

    local lifetime =
        math.max(
            0,
            GetNumber(
                self:GetSetting(
                    "CacheLifetime",
                    1
                ),
                1
            )
        )

    if os.clock() - cached.Timestamp
        > lifetime then

        return nil
    end

    return cached.Data
end


function Targeting:SetCachedTargetData(
    player,
    data
)
    if not player then
        return
    end

    self.Cache[player] = {
        Player = player,
        Data = data,
        Timestamp = os.clock(),
    }
end


function Targeting:ClearCache()
    table.clear(self.Cache)
end




-- Target collection


function Targeting:GetAllTargets()
    local targets = {}

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do

        if self:IsValidPlayer(player) then
            local data =
                self:GetCachedTargetData(
                    player
                )

            if not data then
                data =
                    self:BuildTargetData(
                        player
                    )

                if data then
                    self:SetCachedTargetData(
                        player,
                        data
                    )
                end
            end

            if data then
                table.insert(
                    targets,
                    data
                )
            end
        else
            self.Cache[player] = nil
        end
    end

    self.Targets = targets

    return targets
end




-- Sorting


function Targeting:SortByDistance(
    targets
)
    table.sort(
        targets,
        function(a, b)
            if a.Distance == b.Distance then
                return a.Player.UserId
                    < b.Player.UserId
            end

            return a.Distance < b.Distance
        end
    )

    return targets
end


function Targeting:SortByScreenDistance(
    targets
)
    table.sort(
        targets,
        function(a, b)
            if a.ScreenDistance
                == b.ScreenDistance then

                return a.Player.UserId
                    < b.Player.UserId
            end

            return a.ScreenDistance
                < b.ScreenDistance
        end
    )

    return targets
end




-- Selection


function Targeting:GetNearestTarget()
    local targets =
        self:GetAllTargets()

    if #targets == 0 then
        return nil
    end

    self:SortByDistance(
        targets
    )

    return targets[1]
end


function Targeting:GetClosestToCenter()
    local targets =
        self:GetAllTargets()

    if #targets == 0 then
        return nil
    end

    local filtered = {}

    for _, target in ipairs(
        targets
    ) do

        if target.Screen
            and target.Screen.Visible
            and target.WithinFOV then

            table.insert(
                filtered,
                target
            )
        end
    end

    if #filtered == 0 then
        return nil
    end

    self:SortByScreenDistance(
        filtered
    )

    return filtered[1]
end


function Targeting:GetBestTarget()
    local mode =
        tostring(
            self:GetSetting(
                "SelectionMode",
                "Nearest"
            )
        )

    if mode == "Screen"
        or mode == "FOV"
        or mode == "Center" then

        return self:GetClosestToCenter()
    end

    if mode == "Distance"
        or mode == "Nearest" then

        if self:GetSetting(
            "UseScreenCenter",
            true
        ) then

            local screenTarget =
                self:GetClosestToCenter()

            if screenTarget then
                return screenTarget
            end
        end

        return self:GetNearestTarget()
    end

    return self:GetNearestTarget()
end




-- Target state


function Targeting:SetTarget(target)
    local player = target

    if type(target) == "table" then
        player = target.Player
    end

    if player
        and not self:IsValidPlayer(player) then

        player = nil
    end

    if self.CurrentTarget == player then
        self.State.TargetChanged = false
        self.State.TargetAcquired = false
        self.State.TargetLost = false

        return false
    end

    local previous =
        self.CurrentTarget

    self.PreviousTarget =
        previous

    self.CurrentTarget =
        player

    self.State.TargetChanged =
        true

    self.State.TargetAcquired =
        player ~= nil
        and previous == nil

    self.State.TargetLost =
        player == nil
        and previous ~= nil

    return true
end


function Targeting:ClearTarget()
    if not self.CurrentTarget then
        self.State.TargetChanged = false
        self.State.TargetAcquired = false
        self.State.TargetLost = false

        return false
    end

    self.PreviousTarget =
        self.CurrentTarget

    self.CurrentTarget =
        nil

    self.State.TargetChanged = true
    self.State.TargetAcquired = false
    self.State.TargetLost = true

    return true
end


function Targeting:GetTarget()
    local target =
        self.CurrentTarget

    if not target then
        return nil
    end

    if not self:IsValidPlayer(target) then
        self:ClearTarget()
        return nil
    end

    return target
end


function Targeting:GetTargetData()
    local target =
        self:GetTarget()

    if not target then
        return nil
    end

    local cached =
        self:GetCachedTargetData(
            target
        )

    if cached then
        return cached
    end

    local data =
        self:BuildTargetData(
            target
        )

    if data then
        self:SetCachedTargetData(
            target,
            data
        )
    end

    return data
end


function Targeting:HasTarget()
    return self:GetTarget() ~= nil
end


function Targeting:WasTargetChanged()
    return self.State.TargetChanged
end




-- Refresh


function Targeting:Refresh()
    if not self.Enabled then
        return nil
    end

    self:ClearCache()

    local target =
        self:GetBestTarget()

    self:SetTarget(
        target
            and target.Player
            or nil
    )

    self.State.LastUpdate =
        os.clock()

    return target
end




-- Update


function Targeting:Update(deltaTime)
    if not self.Enabled then
        return
    end

    self._accumulator +=
        deltaTime

    local updateRate =
        math.max(
            1,
            GetNumber(
                self:GetSetting(
                    "UpdateRate",
                    30
                ),
                30
            )
        )

    local interval =
        1 / updateRate

    if self._accumulator < interval then
        return
    end

    self._accumulator = 0

    SafeCall(function()
        self:Refresh()
    end)
end




-- Player lifecycle


function Targeting:RemovePlayerConnections(
    player
)
    local connections =
        self.PlayerConnections[player]

    if connections then
        DisconnectList(connections)
        self.PlayerConnections[player] = nil
    end
end


function Targeting:PlayerRemoving(player)
    if self.CurrentTarget == player then
        self:ClearTarget()
    end

    self.Cache[player] = nil
    self:RemovePlayerConnections(player)
end


function Targeting:PlayerAdded(player)
    if not player
        or player == self:GetLocalPlayer() then

        return
    end

    self:RemovePlayerConnections(player)

    self.Cache[player] = {
        Player = player,
        Timestamp = os.clock(),
    }

    local connections = {}

    connections.CharacterRemoving =
        player.CharacterRemoving:Connect(
            function(character)

                self.Cache[player] = nil

                if self.CurrentTarget == player
                    and self:GetSetting(
                        "ClearOnCharacterRemoving",
                        true
                    ) then

                    self:ClearTarget()
                end
            end
        )

    connections.CharacterAdded =
        player.CharacterAdded:Connect(
            function()

                self.Cache[player] = nil
            end
        )

    self.PlayerConnections[player] =
        connections
end




-- Start


function Targeting:Start()
    if self.Running then
        return
    end

    self.Running = true
    self.Enabled = true

    self.LocalPlayer =
        PlayersService.LocalPlayer

    self._accumulator = 0

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do

        if player ~= self.LocalPlayer then
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

        RunService.Heartbeat:Connect(
            function(deltaTime)

                SafeCall(
                    function()
                        self:Update(
                            deltaTime
                        )
                    end
                )
            end
        )
    )

    self:Refresh()
end




-- Stop


function Targeting:Stop()
    self.Enabled = false
    self.Running = false

    DisconnectList(
        self.Connections
    )

    for player, connections in pairs(
        self.PlayerConnections
    ) do

        DisconnectList(
            connections
        )

        self.PlayerConnections[player] =
            nil
    end

    self:ClearTarget()

    self.Targets = {}

    self:ClearCache()

    self._accumulator = 0
end




-- Toggle


function Targeting:SetEnabled(enabled)
    enabled = enabled == true

    if enabled then
        self:Start()
    else
        self:Stop()
    end

    return self.Enabled
end


function Targeting:Toggle()
    return self:SetEnabled(
        not self.Enabled
    )
end




-- Initialize


function Targeting:Initialize(modules)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

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

    self.LocalPlayer =
        PlayersService.LocalPlayer

    self.Initialized = true

    return self
end




-- Cleanup


function Targeting:Destroy()
    self:Stop()

    self.Players = nil
    self.Character = nil
    self.Math = nil
    self.Cleanup = nil
    self.Config = nil

    self.LocalPlayer = nil

    self.CurrentTarget = nil
    self.PreviousTarget = nil

    self.Targets = {}
    self.Cache = {}

    self.State.LastUpdate = 0
    self.State.TargetChanged = false
    self.State.TargetAcquired = false
    self.State.TargetLost = false

    self.Initialized = false
end


return Targeting