local PlayersService = game:GetService("Players")

local Players = {
    Name = "Players",

    LocalPlayer = nil,

    Initialized = false,
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


-- Initialize


function Players:Initialize()
    if self.Initialized then
        return self
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    self.Initialized = true

    return self
end


-- Basic player access


function Players:GetLocal()
    return self.LocalPlayer
        or PlayersService.LocalPlayer
end

function Players:GetAll()
    return PlayersService:GetPlayers()
end

function Players:GetCount()
    return #PlayersService:GetPlayers()
end

function Players:IsLocalPlayer(player)
    return player == self:GetLocal()
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
        PlayersService:GetPlayers()

    -- Exact username first.
    for _, player in ipairs(players) do
        if string.lower(
            player.Name
        ) == query then
            return player
        end
    end

    -- Exact display name second.
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

function Players:FindByUserId(
    userId
)
    userId =
        tonumber(userId)

    if not userId then
        return nil
    end

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do
        if player.UserId == userId then
            return player
        end
    end

    return nil
end


-- Character helpers


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


-- Character state


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

function Players:GetHealthPercent(
    player
)
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


-- Position / distance


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


-- Team helpers


function Players:GetTeam(player)
    if not IsPlayer(player) then
        return nil
    end

    return player.Team
end

function Players:GetTeamColor(
    player
)
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
        or not player then
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

    if not IsPlayer(player) then
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

    return true
end

function Players:GetTargets(
    options
)
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
            ) < self:GetDistance(
                reference,
                b
            )
        end
    )

    return result
end


-- Nearest player


function Players:GetNearest(
    options
)
    options =
        options or {}

    local targets =
        self:GetTargets(
            options
        )

    if #targets == 0 then
        return nil
    end

    local sorted =
        self:SortByDistance(
            targets
        )

    return sorted[1]
end


-- Player information


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

        Health = self:GetHealth(player),
        MaxHealth = self:GetMaxHealth(player),

        Position = self:GetPosition(player),

        Distance =
            self:GetDistanceFromLocal(
                player
            ),
    }
end


-- Character parts commonly used by visuals


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


-- Initialization compatibility


function Players:Refresh()
    self.LocalPlayer =
        PlayersService.LocalPlayer

    return self.LocalPlayer
end


-- Destroy


function Players:Destroy()
    self.LocalPlayer = nil
    self.Initialized = false
end

return Players