local PlayersService = game:GetService("Players")

local Players = {
    Name = "Players",
    Version = "2.2.0",

    LocalPlayer = nil,

    Initialized = false,

    Connections = {},

    Cache = {
        Players = {},
        LastRefresh = 0,
    },

    Events = {
        PlayerAdded = {},
        PlayerRemoving = {},
    },
}



-- Helpers



local function NormalizeQuery(query)
    if query == nil then
        return nil
    end

    query = tostring(query)

    if query == "" then
        return nil
    end

    return string.lower(query)
end


local function IsPlayer(value)
    return typeof(value) == "Instance"
        and value:IsA("Player")
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
            "[Lua Test] Players:",
            result
        )

        return false, result
    end

    return true, result
end



-- Initialization



function Players:Initialize()
    if self.Initialized then
        return self
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    self:Refresh()

    self:_BindEvents()

    self.Initialized = true

    return self
end


function Players:_BindEvents()
    self:_DisconnectEvents()

    local addedConnection =
        PlayersService.PlayerAdded:Connect(
            function(player)
                self:_AddToCache(player)
                self:_FireEvent(
                    "PlayerAdded",
                    player
                )
            end
        )

    local removingConnection =
        PlayersService.PlayerRemoving:Connect(
            function(player)
                self:_RemoveFromCache(player)
                self:_FireEvent(
                    "PlayerRemoving",
                    player
                )
            end
        )

    table.insert(
        self.Connections,
        addedConnection
    )

    table.insert(
        self.Connections,
        removingConnection
    )
end


function Players:_DisconnectEvents()
    for index = #self.Connections, 1, -1 do
        local connection =
            self.Connections[index]

        if connection then
            pcall(function()
                connection:Disconnect()
            end)
        end

        table.remove(
            self.Connections,
            index
        )
    end
end



-- Internal Cache



function Players:_AddToCache(player)
    if not IsPlayer(player) then
        return
    end

    self.Cache.Players[player] = true
end


function Players:_RemoveFromCache(player)
    self.Cache.Players[player] = nil
end


function Players:_RebuildCache()
    table.clear(
        self.Cache.Players
    )

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do
        self.Cache.Players[player] = true
    end

    self.Cache.LastRefresh =
        os.clock()
end



-- Events



function Players:_FireEvent(
    eventName,
    ...
)
    local listeners =
        self.Events[eventName]

    if not listeners then
        return
    end

    for _, callback in ipairs(
        listeners
    ) do
        if type(callback) == "function" then
            task.spawn(
                function()
                    SafeCall(
                        callback,
                        ...
                    )
                end
            )
        end
    end
end


function Players:OnPlayerAdded(callback)
    if type(callback) ~= "function" then
        return function() end
    end

    table.insert(
        self.Events.PlayerAdded,
        callback
    )

    local removed = false

    return function()
        if removed then
            return
        end

        removed = true

        local listeners =
            self.Events.PlayerAdded

        for index = #listeners, 1, -1 do
            if listeners[index] == callback then
                table.remove(
                    listeners,
                    index
                )
                break
            end
        end
    end
end


function Players:OnPlayerRemoving(callback)
    if type(callback) ~= "function" then
        return function() end
    end

    table.insert(
        self.Events.PlayerRemoving,
        callback
    )

    local removed = false

    return function()
        if removed then
            return
        end

        removed = true

        local listeners =
            self.Events.PlayerRemoving

        for index = #listeners, 1, -1 do
            if listeners[index] == callback then
                table.remove(
                    listeners,
                    index
                )
                break
            end
        end
    end
end



-- Basic Player Access



function Players:GetLocal()
    return self.LocalPlayer
        or PlayersService.LocalPlayer
end


function Players:GetAll()
    return PlayersService:GetPlayers()
end


function Players:GetCached()
    local result = {}

    for player in pairs(
        self.Cache.Players
    ) do
        if IsPlayer(player)
            and player.Parent then

            table.insert(
                result,
                player
            )
        end
    end

    return result
end


function Players:GetCount()
    return #PlayersService:GetPlayers()
end


function Players:IsLocalPlayer(player)
    return IsPlayer(player)
        and player == self:GetLocal()
end


function Players:IsValid(player)
    return IsPlayer(player)
        and player.Parent ~= nil
end



-- Lookup



function Players:Find(query)
    if IsPlayer(query) then
        return query
    end

    query =
        NormalizeQuery(query)

    if not query then
        return nil
    end

    local players =
        self:GetAll()

    -- Exact username.
    for _, player in ipairs(players) do
        if string.lower(
            player.Name
        ) == query then
            return player
        end
    end

    -- Exact display name.
    for _, player in ipairs(players) do
        if string.lower(
            player.DisplayName
        ) == query then
            return player
        end
    end

    -- Partial username/display name.
    for _, player in ipairs(players) do
        if string.find(
            string.lower(player.Name),
            query,
            1,
            true
        ) then
            return player
        end

        if string.find(
            string.lower(player.DisplayName),
            query,
            1,
            true
        ) then
            return player
        end
    end

    return nil
end


function Players:FindAll(query)
    query =
        NormalizeQuery(query)

    if not query then
        return {}
    end

    local result = {}

    for _, player in ipairs(
        self:GetAll()
    ) do
        local name =
            string.lower(
                player.Name
            )

        local displayName =
            string.lower(
                player.DisplayName
            )

        if string.find(
            name,
            query,
            1,
            true
        )
        or string.find(
            displayName,
            query,
            1,
            true
        ) then

            table.insert(
                result,
                player
            )
        end
    end

    return result
end


function Players:FindByUserId(userId)
    userId =
        tonumber(userId)

    if not userId then
        return nil
    end

    for _, player in ipairs(
        self:GetAll()
    ) do
        if player.UserId == userId then
            return player
        end
    end

    return nil
end



-- Character Helpers



function Players:GetCharacter(player)
    if not IsPlayer(player) then
        return nil
    end

    return player.Character
end


function Players:GetHumanoid(player)
    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChildOfClass(
        "Humanoid"
    )
end


function Players:GetRoot(player)
    local character =
        self:GetCharacter(player)

    if not character then
        return nil
    end

    return character:FindFirstChild(
        "HumanoidRootPart"
    )
end


function Players:GetPart(
    player,
    partName
)
    if not IsPlayer(player) then
        return nil
    end

    if type(partName) ~= "string"
        or partName == "" then
        return nil
    end

    local character =
        player.Character

    if not character then
        return nil
    end

    return character:FindFirstChild(
        partName
    )
end


function Players:GetBodyPart(
    player,
    preferredNames
)
    if not IsPlayer(player) then
        return nil
    end

    local character =
        player.Character

    if not character then
        return nil
    end

    if type(preferredNames) == "string" then
        preferredNames = {
            preferredNames,
        }
    end

    if type(preferredNames) ~= "table" then
        preferredNames = {
            "HumanoidRootPart",
            "UpperTorso",
            "Torso",
        }
    end

    for _, name in ipairs(
        preferredNames
    ) do
        local part =
            character:FindFirstChild(
                name
            )

        if part
            and part:IsA("BasePart") then
            return part
        end
    end

    return nil
end


function Players:GetHead(player)
    return self:GetPart(
        player,
        "Head"
    )
end



-- Character State



function Players:IsAlive(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return false
    end

    return humanoid.Health > 0
end


function Players:GetHealth(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return 0
    end

    return humanoid.Health
end


function Players:GetMaxHealth(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return 0
    end

    return humanoid.MaxHealth
end


function Players:GetHealthPercent(player)
    local health =
        self:GetHealth(player)

    local maxHealth =
        self:GetMaxHealth(player)

    if maxHealth <= 0 then
        return 0
    end

    return math.clamp(
        health / maxHealth,
        0,
        1
    )
end


function Players:GetHumanoidState(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return nil
    end

    return humanoid:GetState()
end


function Players:IsMoving(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return false
    end

    return humanoid.MoveDirection.Magnitude > 0
end


function Players:GetMoveDirection(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return Vector3.zero
    end

    return humanoid.MoveDirection
end


function Players:IsGrounded(player)
    local humanoid =
        self:GetHumanoid(player)

    if not humanoid then
        return false
    end

    return humanoid.FloorMaterial
        ~= Enum.Material.Air
end



-- Position / Distance



function Players:GetPosition(player)
    local root =
        self:GetRoot(player)

    if not root then
        return nil
    end

    return root.Position
end


function Players:GetCFrame(player)
    local root =
        self:GetRoot(player)

    if not root then
        return nil
    end

    return root.CFrame
end


function Players:GetVelocity(player)
    local root =
        self:GetRoot(player)

    if not root then
        return Vector3.zero
    end

    return root.AssemblyLinearVelocity
end


function Players:GetDistance(
    playerA,
    playerB
)
    local positionA =
        self:GetPosition(playerA)

    local positionB =
        self:GetPosition(playerB)

    if not positionA
        or not positionB then
        return math.huge
    end

    return (
        positionA
        - positionB
    ).Magnitude
end


function Players:GetDistanceFromLocal(
    player
)
    return self:GetDistance(
        self:GetLocal(),
        player
    )
end



-- Team Helpers



function Players:GetTeam(player)
    if not IsPlayer(player) then
        return nil
    end

    return player.Team
end


function Players:GetTeamColor(player)
    if not IsPlayer(player) then
        return nil
    end

    return player.TeamColor
end


function Players:SameTeam(
    playerA,
    playerB
)
    if not IsPlayer(playerA)
        or not IsPlayer(playerB) then
        return false
    end

    if playerA.Team == nil
        or playerB.Team == nil then
        return false
    end

    return playerA.Team ==
        playerB.Team
end


function Players:IsEnemy(player)
    local localPlayer =
        self:GetLocal()

    if not localPlayer
        or not IsPlayer(player) then
        return false
    end

    return not self:SameTeam(
        localPlayer,
        player
    )
end



-- Filtering



function Players:IsValidTarget(
    player,
    options
)
    options =
        options or {}

    if not self:IsValid(player) then
        return false
    end

    if options.ExcludeLocal ~= false
        and self:IsLocalPlayer(player) then
        return false
    end

    if options.AliveOnly
        and not self:IsAlive(player) then
        return false
    end

    if options.TeamCheck
        and self:SameTeam(
            self:GetLocal(),
            player
        ) then
        return false
    end

    if options.EnemiesOnly
        and not self:IsEnemy(player) then
        return false
    end

    local maxDistance =
        tonumber(
            options.MaxDistance
        )

    if maxDistance then
        local distance =
            self:GetDistanceFromLocal(
                player
            )

        if distance > maxDistance then
            return false
        end
    end

    local minDistance =
        tonumber(
            options.MinDistance
        )

    if minDistance then
        local distance =
            self:GetDistanceFromLocal(
                player
            )

        if distance < minDistance then
            return false
        end
    end

    return true
end


function Players:GetTargets(options)
    options =
        options or {}

    local targets = {}

    for _, player in ipairs(
        self:GetAll()
    ) do
        if self:IsValidTarget(
            player,
            options
        ) then

            table.insert(
                targets,
                player
            )
        end
    end

    return targets
end



-- Sorting



function Players:SortByDistance(
    players,
    reference
)
    if type(players) ~= "table" then
        return {}
    end

    reference =
        reference
        or self:GetLocal()

    local result = {}

    for _, player in ipairs(
        players
    ) do
        table.insert(
            result,
            player
        )
    end

    table.sort(
        result,
        function(a, b)
            return self:GetDistance(
                reference,
                a
            ) <
            self:GetDistance(
                reference,
                b
            )
        end
    )

    return result
end



-- Nearest / Farthest



function Players:GetNearest(options)
    options =
        options or {}

    local reference =
        options.Reference
        or self:GetLocal()

    local nearest = nil
    local nearestDistance =
        math.huge

    for _, player in ipairs(
        self:GetAll()
    ) do

        if self:IsValidTarget(
            player,
            options
        ) then

            local distance =
                self:GetDistance(
                    reference,
                    player
                )

            if distance < nearestDistance then
                nearestDistance =
                    distance

                nearest =
                    player
            end
        end
    end

    return nearest
end


function Players:GetFarthest(options)
    options =
        options or {}

    local reference =
        options.Reference
        or self:GetLocal()

    local farthest = nil
    local farthestDistance =
        -math.huge

    for _, player in ipairs(
        self:GetAll()
    ) do

        if self:IsValidTarget(
            player,
            options
        ) then

            local distance =
                self:GetDistance(
                    reference,
                    player
                )

            if distance > farthestDistance then
                farthestDistance =
                    distance

                farthest =
                    player
            end
        end
    end

    return farthest
end



-- Player Information



function Players:GetInfo(player)
    if not IsPlayer(player) then
        return nil
    end

    return {
        Player = player,

        Name = player.Name,
        DisplayName = player.DisplayName,

        UserId = player.UserId,

        Team = player.Team,
        TeamColor = player.TeamColor,

        Alive = self:IsAlive(player),

        Health =
            self:GetHealth(player),

        MaxHealth =
            self:GetMaxHealth(player),

        HealthPercent =
            self:GetHealthPercent(player),

        Position =
            self:GetPosition(player),

        CFrame =
            self:GetCFrame(player),

        Velocity =
            self:GetVelocity(player),

        Moving =
            self:IsMoving(player),

        Grounded =
            self:IsGrounded(player),

        State =
            self:GetHumanoidState(player),

        Distance =
            self:GetDistanceFromLocal(
                player
            ),
    }
end



-- Refresh



function Players:Refresh()
    self.LocalPlayer =
        PlayersService.LocalPlayer

    self:_RebuildCache()

    return self.LocalPlayer
end



-- Destroy



function Players:Destroy()
    self:_DisconnectEvents()

    table.clear(
        self.Cache.Players
    )

    table.clear(
        self.Events.PlayerAdded
    )

    table.clear(
        self.Events.PlayerRemoving
    )

    self.LocalPlayer = nil
    self.Initialized = false
end


return Players