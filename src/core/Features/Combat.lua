--[[
    Lua Test Script
    Combat.lua

    Modular combat system for a Roblox experience.

    Features:
        - Target validation
        - Team checking
        - Range checking
        - Cooldowns
        - Damage handling
        - Hit detection
        - Critical hits
        - Knockback
        - Friendly-fire protection
        - Character/respawn handling
        - Config integration
        - Cleanup support
]]

local PlayersService = game:GetService("Players")
local RunService = game:GetService("RunService")

local Combat = {
    Name = "Combat",

    Enabled = false,
    Running = false,
    Initialized = false,

    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    LocalPlayer = nil,
    CharacterModel = nil,
    Humanoid = nil,
    RootPart = nil,

    Connections = {},
    Cooldowns = {},

    Settings = {
        Enabled = true,

        -- Premium features
        AutoAttack = false,
        SmartAttack = false,
        TargetPriority = "Health",

        -- General
        TeamCheck = true,
        FriendlyFire = false,

        -- Range
        AttackRange = 12,

        -- Damage
        Damage = 25,
        CriticalEnabled = false,
        CriticalChance = 0.1,
        CriticalMultiplier = 2,

        -- Cooldown
        AttackCooldown = 0.5,

        -- Knockback
        KnockbackEnabled = false,
        KnockbackForce = 30,

        -- Targeting
        RequireAliveTarget = true,
        RequireLineOfSight = false,

        -- Update
        UpdateRate = 30,
    },

    State = {
        LastAttack = 0,
        CurrentTarget = nil,
    },

    _accumulator = 0,
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
            "[Lua Test] Combat error:",
            result
        )

        return false, result
    end

    return true, result
end


local function Disconnect(connection)
    if not connection then
        return
    end

    pcall(function()
        connection:Disconnect()
    end)
end



-- Configuration


function Combat:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(
            function()
                return self.Config:Get(
                    "Combat." .. name,
                    default
                )
            end
        )

        if success then
            return value
        end
    end

    return default
end


function Combat:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


function Combat:GetSettings()
    return self.Settings
end



-- Character


function Combat:GetLocalPlayer()
    if self.LocalPlayer then
        return self.LocalPlayer
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    return self.LocalPlayer
end


function Combat:GetCharacter(player)
    player =
        player
        or self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetCharacter) == "function" then

        local success, character =
            pcall(function()
                return self.Players:GetCharacter(
                    player
                )
            end)

        if success and character then
            return character
        end
    end

    return player.Character
end


function Combat:GetHumanoid(player)
    player =
        player
        or self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetHumanoid) == "function" then

        local success, humanoid =
            pcall(function()
                return self.Players:GetHumanoid(
                    player
                )
            end)

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


function Combat:GetRoot(player)
    player =
        player
        or self:GetLocalPlayer()

    if not player then
        return nil
    end

    if self.Players
        and type(self.Players.GetRoot) == "function" then

        local success, root =
            pcall(function()
                return self.Players:GetRoot(
                    player
                )
            end)

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


function Combat:RefreshCharacter()
    self.CharacterModel =
        self:GetCharacter()

    self.Humanoid =
        self:GetHumanoid()

    self.RootPart =
        self:GetRoot()

    return self.CharacterModel ~= nil
end



-- Teams


function Combat:IsSameTeam(playerA, playerB)
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


function Combat:IsFriendly(player)
    local localPlayer =
        self:GetLocalPlayer()

    if not localPlayer or not player then
        return false
    end

    return self:IsSameTeam(
        localPlayer,
        player
    )
end



-- Target validation


function Combat:IsValidTarget(player)
    if not player then
        return false
    end

    local localPlayer =
        self:GetLocalPlayer()

    if player == localPlayer then
        return false
    end

    if not player.Parent then
        return false
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

    local humanoid =
        self:GetHumanoid(player)

    local root =
        self:GetRoot(player)

    if not humanoid or not root then
        return false
    end

    if self:GetSetting(
        "RequireAliveTarget",
        true
    ) and humanoid.Health <= 0 then

        return false
    end

    return true
end



-- Distance


function Combat:GetDistance(player)
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


function Combat:IsInRange(player, range)
    range =
        tonumber(range)
        or self:GetSetting(
            "AttackRange",
            12
        )

    return self:GetDistance(
        player
    ) <= range
end



-- Line of sight


function Combat:HasLineOfSight(player)
    if not self:GetSetting(
        "RequireLineOfSight",
        false
    ) then
        return true
    end

    local localRoot =
        self:GetRoot()

    local targetRoot =
        self:GetRoot(player)

    if not localRoot
        or not targetRoot then

        return false
    end

    local origin =
        localRoot.Position

    local direction =
        targetRoot.Position
        - origin

    if direction.Magnitude <= 0 then
        return true
    end

    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    local localCharacter =
        self:GetCharacter()

    if localCharacter then
        params.FilterDescendantsInstances = {
            localCharacter
        }
    end

    local result =
        workspace:Raycast(
            origin,
            direction,
            params
        )

    if not result then
        return true
    end

    local targetCharacter =
        self:GetCharacter(player)

    if targetCharacter
        and result.Instance:IsDescendantOf(
            targetCharacter
        ) then

        return true
    end

    return false
end



-- Cooldowns


function Combat:IsOnCooldown(player)
    if not player then
        return false
    end

    local cooldown =
        tonumber(
            self:GetSetting(
                "AttackCooldown",
                0.5
            )
        ) or 0.5

    local lastAttack =
        self.Cooldowns[player]

    if not lastAttack then
        return false
    end

    return (
        os.clock() - lastAttack
    ) < cooldown
end


function Combat:SetCooldown(player)
    if not player then
        return
    end

    self.Cooldowns[player] =
        os.clock()
end


function Combat:ClearCooldown(player)
    if player then
        self.Cooldowns[player] = nil
    end
end


function Combat:ClearCooldowns()
    self.Cooldowns = {}
end



-- Damage


function Combat:CalculateDamage()
    local damage =
        tonumber(
            self:GetSetting(
                "Damage",
                25
            )
        ) or 25

    if damage <= 0 then
        return 0, false
    end

    local critical =
        self:GetSetting(
            "CriticalEnabled",
            false
        )

    if not critical then
        return damage, false
    end

    local chance =
        tonumber(
            self:GetSetting(
                "CriticalChance",
                0.1
            )
        ) or 0.1

    chance =
        math.clamp(
            chance,
            0,
            1
        )

    if math.random() <= chance then
        local multiplier =
            tonumber(
                self:GetSetting(
                    "CriticalMultiplier",
                    2
                )
            ) or 2

        return (
            damage * multiplier
        ), true
    end

    return damage, false
end


function Combat:ApplyDamage(
    targetPlayer,
    amount
)
    if not targetPlayer then
        return false
    end

    local humanoid =
        self:GetHumanoid(
            targetPlayer
        )

    if not humanoid then
        return false
    end

    if humanoid.Health <= 0 then
        return false
    end

    amount =
        tonumber(amount)

    if not amount
        or amount <= 0 then

        return false
    end

    -- Server-authoritative combat should
    -- normally perform damage here.
    --
    -- This module intentionally does not
    -- attempt to bypass server authority.

    local success =
        SafeCall(function()
            humanoid:TakeDamage(
                amount
            )
        end)

    return success
end



-- Knockback


function Combat:ApplyKnockback(player)
    if not self:GetSetting(
        "KnockbackEnabled",
        false
    ) then
        return false
    end

    local targetRoot =
        self:GetRoot(player)

    local localRoot =
        self:GetRoot()

    if not targetRoot
        or not localRoot then

        return false
    end

    local direction =
        targetRoot.Position
        - localRoot.Position

    if direction.Magnitude <= 0 then
        return false
    end

    direction =
        direction.Unit

    local force =
        tonumber(
            self:GetSetting(
                "KnockbackForce",
                30
            )
        ) or 30

    pcall(function()
        targetRoot.AssemblyLinearVelocity =
            direction * force
    end)

    return true
end



-- Attack


function Combat:CanAttack(player)
    if not self.Enabled then
        return false
    end

    if not self:IsValidTarget(player) then
        return false
    end

    if not self:IsInRange(player) then
        return false
    end

    if not self:HasLineOfSight(player) then
        return false
    end

    if self:IsOnCooldown(player) then
        return false
    end

    return true
end


function Combat:Attack(player)
    if not self:CanAttack(player) then
        return false
    end

    local damage, critical =
        self:CalculateDamage()

    if damage <= 0 then
        return false
    end

    local success =
        self:ApplyDamage(
            player,
            damage
        )

    if not success then
        return false
    end

    self:SetCooldown(player)

    self.State.LastAttack =
        os.clock()

    self.State.CurrentTarget =
        player

    self:ApplyKnockback(
        player
    )

    return true, {
        Damage = damage,
        Critical = critical,
        Target = player,
    }
end



-- Target search


function Combat:GetTargets()
    local targets = {}

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do
        if self:IsValidTarget(player)
            and self:IsInRange(player)
            and self:HasLineOfSight(player) then

            table.insert(
                targets,
                player
            )
        end
    end

    return targets
end


function Combat:GetNearestTarget()
    local nearest = nil
    local nearestDistance =
        math.huge

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do
        if self:IsValidTarget(player) then
            local distance =
                self:GetDistance(player)

            if distance <
                nearestDistance
                and self:IsInRange(player)
                and self:HasLineOfSight(player) then

                nearest =
                    player

                nearestDistance =
                    distance
            end
        end
    end

    return nearest, nearestDistance
end



-- Update


function Combat:AttackNearestValidTarget()
    local nearestPlayer, _ = self:GetNearestTarget()
    if not nearestPlayer then
        return false
    end

    return self:Attack(nearestPlayer)
end


function Combat:AttackBestPriorityTarget()
    local targets = self:GetTargets()
    if #targets == 0 then
        return false
    end

    local bestTarget = nil
    local bestValue = -math.huge

    for _, player in ipairs(targets) do
        local humanoid = self:GetHumanoid(player)
        if humanoid then
            local healthValue = math.max(0, humanoid.Health)
            local distance = self:GetDistance(player)
            local score = (1000 - distance) + healthValue
            if score > bestValue then
                bestValue = score
                bestTarget = player
            end
        end
    end

    if not bestTarget then
        return false
    end

    return self:Attack(bestTarget)
end


function Combat:Update(deltaTime)
    if not self.Enabled then
        return
    end

    self._accumulator +=
        deltaTime

    local updateRate =
        math.max(
            1,
            tonumber(
                self:GetSetting(
                    "UpdateRate",
                    30
                )
            ) or 30
        )

    local interval =
        1 / updateRate

    if self._accumulator < interval then
        return
    end

    self._accumulator = 0

    if not self.CharacterModel
        or not self.CharacterModel.Parent then

        self:RefreshCharacter()
    end

    if self.State.CurrentTarget then
        if not self:IsValidTarget(
            self.State.CurrentTarget
        ) then

            self.State.CurrentTarget =
                nil
        end
    end

    if self:GetSetting("AutoAttack", false) then
        if self:GetSetting("SmartAttack", false) then
            self:AttackBestPriorityTarget()
        else
            self:AttackNearestValidTarget()
        end
    end
end



-- Player events


function Combat:PlayerRemoving(player)
    self:ClearCooldown(
        player
    )

    if self.State.CurrentTarget ==
        player then

        self.State.CurrentTarget =
            nil
    end
end



-- Start


function Combat:Start()
    if self.Running then
        return
    end

    self.Running = true
    self.Enabled = true

    self:RefreshCharacter()

    local player =
        self:GetLocalPlayer()

    if player then
        table.insert(
            self.Connections,

            player.CharacterAdded:Connect(
                function()
                    task.defer(function()
                        self:RefreshCharacter()
                    end)
                end
            )
        )
    end

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
end



-- Stop


function Combat:Stop()
    self.Enabled = false
    self.Running = false

    for _, connection in ipairs(
        self.Connections
    ) do
        Disconnect(connection)
    end

    self.Connections = {}

    self:ClearCooldowns()

    self.State.CurrentTarget =
        nil
end



-- Toggle


function Combat:SetEnabled(enabled)
    enabled =
        enabled == true

    if enabled then
        self:Start()
    else
        self:Stop()
    end

    return self.Enabled
end


function Combat:Toggle()
    return self:SetEnabled(
        not self.Enabled
    )
end



-- Initialize


function Combat:Initialize(modules)
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


function Combat:Destroy()
    self:Stop()

    self.Players = nil
    self.Character = nil
    self.Math = nil
    self.Cleanup = nil
    self.Config = nil

    self.LocalPlayer = nil

    self.CharacterModel = nil
    self.Humanoid = nil
    self.RootPart = nil

    self.Initialized = false
end


return Combat