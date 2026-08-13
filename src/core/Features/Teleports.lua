--[[
    Lua Test Script
    Teleports.lua

    Teleport management module.

    Features:
        - Save current position
        - Load saved position
        - Named teleport locations
        - Delete teleport locations
        - Teleport to player
        - Teleport to spawn
        - Teleport to last position
        - Position history
        - Safe character/root handling
        - Respawn-aware operation
        - Config integration
        - Cleanup support
]]

local PlayersService = game:GetService("Players")

local Teleports = {
    Name = "Teleports",

    Enabled = true,
    Initialized = false,

    Players = nil,
    Character = nil,
    Math = nil,
    Cleanup = nil,
    Config = nil,

    LocalPlayer = nil,

    Settings = {
        Enabled = true,

        -- General
        PreserveVelocity = false,
        SafeTeleport = true,

        -- History
        HistoryEnabled = true,
        MaxHistory = 20,

        -- Saved locations
        MaxLocations = 100,

        -- Player teleport
        AllowPlayerTeleport = true,

        -- Spawn
        UseSpawnLocation = true,
    },

    Locations = {},
    History = {},

    LastPosition = nil,
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
            "[Lua Test] Teleports error:",
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


function Teleports:GetSetting(name, default)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) == "function" then

        local success, value = pcall(
            function()
                return self.Config:Get(
                    "Teleports." .. name,
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


function Teleports:SetSetting(name, value)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


function Teleports:GetSettings()
    return self.Settings
end



-- Character


function Teleports:GetLocalPlayer()
    if self.LocalPlayer then
        return self.LocalPlayer
    end

    self.LocalPlayer =
        PlayersService.LocalPlayer

    return self.LocalPlayer
end


function Teleports:GetCharacter(player)
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


function Teleports:GetRoot(player)
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


function Teleports:GetHumanoid(player)
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



-- Position helpers


function Teleports:IsValidCFrame(value)
    return typeof(value) == "CFrame"
end


function Teleports:IsValidVector3(value)
    return typeof(value) == "Vector3"
end


function Teleports:GetCurrentCFrame()
    local root =
        self:GetRoot()

    if not root then
        return nil
    end

    return root.CFrame
end


function Teleports:GetCurrentPosition()
    local root =
        self:GetRoot()

    if not root then
        return nil
    end

    return root.Position
end



-- History


function Teleports:AddHistory(cframe)
    if not self:GetSetting(
        "HistoryEnabled",
        true
    ) then
        return
    end

    if not self:IsValidCFrame(cframe) then
        return
    end

    table.insert(
        self.History,
        1,
        cframe
    )

    local maximum =
        math.max(
            1,
            tonumber(
                self:GetSetting(
                    "MaxHistory",
                    20
                )
            ) or 20
        )

    while #self.History > maximum do
        table.remove(
            self.History
        )
    end
end


function Teleports:GetHistory()
    return self.History
end


function Teleports:GetHistoryPosition(index)
    index =
        tonumber(index)

    if not index then
        return nil
    end

    return self.History[index]
end


function Teleports:ClearHistory()
    self.History = {}
end


function Teleports:UndoTeleport()
    if #self.History == 0 then
        return false
    end

    local previous =
        table.remove(
            self.History,
            1
        )

    if not previous then
        return false
    end

    return self:TeleportToCFrame(
        previous,
        false
    )
end



-- Save / restore current position


function Teleports:SaveCurrentPosition()
    local cframe =
        self:GetCurrentCFrame()

    if not cframe then
        return false
    end

    self.LastPosition =
        cframe

    return true
end


function Teleports:GetLastPosition()
    return self.LastPosition
end


function Teleports:ClearLastPosition()
    self.LastPosition = nil
end


function Teleports:TeleportToLastPosition()
    if not self.LastPosition then
        return false
    end

    return self:TeleportToCFrame(
        self.LastPosition
    )
end



-- Named locations


function Teleports:SaveLocation(name, cframe)
    if type(name) ~= "string" then
        return false
    end

    name =
        name:match("^%s*(.-)%s*$")

    if name == "" then
        return false
    end

    if cframe == nil then
        cframe =
            self:GetCurrentCFrame()
    end

    if not self:IsValidCFrame(cframe) then
        return false
    end

    local maximum =
        math.max(
            1,
            tonumber(
                self:GetSetting(
                    "MaxLocations",
                    100
                )
            ) or 100
        )

    if self.Locations[name] == nil then
        local count = 0

        for _ in pairs(self.Locations) do
            count += 1
        end

        if count >= maximum then
            return false
        end
    end

    self.Locations[name] = cframe

    return true
end


function Teleports:GetLocation(name)
    if type(name) ~= "string" then
        return nil
    end

    return self.Locations[name]
end


function Teleports:HasLocation(name)
    return self:GetLocation(name) ~= nil
end


function Teleports:DeleteLocation(name)
    if type(name) ~= "string" then
        return false
    end

    if self.Locations[name] == nil then
        return false
    end

    self.Locations[name] = nil

    return true
end


function Teleports:RenameLocation(oldName, newName)
    if type(oldName) ~= "string"
        or type(newName) ~= "string" then

        return false
    end

    if not self.Locations[oldName] then
        return false
    end

    if self.Locations[newName] then
        return false
    end

    self.Locations[newName] =
        self.Locations[oldName]

    self.Locations[oldName] =
        nil

    return true
end


function Teleports:GetLocations()
    return self.Locations
end


function Teleports:GetLocationNames()
    local names = {}

    for name in pairs(
        self.Locations
    ) do
        table.insert(
            names,
            name
        )
    end

    table.sort(names)

    return names
end


function Teleports:ClearLocations()
    self.Locations = {}
end



-- Safe position


function Teleports:FindSafePosition(cframe)
    if not self:GetSetting(
        "SafeTeleport",
        true
    ) then
        return cframe
    end

    if not self:IsValidCFrame(cframe) then
        return nil
    end

    local position =
        cframe.Position

    local rayOrigin =
        position + Vector3.new(
            0,
            100,
            0
        )

    local rayDirection =
        Vector3.new(
            0,
            -300,
            0
        )

    local params =
        RaycastParams.new()

    params.FilterType =
        Enum.RaycastFilterType.Exclude

    local character =
        self:GetCharacter()

    if character then
        params.FilterDescendantsInstances = {
            character
        }
    end

    local result =
        workspace:Raycast(
            rayOrigin,
            rayDirection,
            params
        )

    if result then
        local safePosition =
            result.Position
            + Vector3.new(
                0,
                4,
                0
            )

        local rotation =
            cframe - cframe.Position

        return CFrame.new(
            safePosition
        ) * rotation
    end

    return cframe
end



-- Teleport core


function Teleports:TeleportToCFrame(
    cframe,
    addHistory
)
    if not self:GetSetting(
        "Enabled",
        true
    ) then
        return false
    end

    if not self:IsValidCFrame(cframe) then
        return false
    end

    local root =
        self:GetRoot()

    if not root then
        return false
    end

    local humanoid =
        self:GetHumanoid()

    if humanoid
        and humanoid.Health <= 0 then

        return false
    end

    if addHistory ~= false then
        local current =
            root.CFrame

        self:AddHistory(
            current
        )
    end

    local target =
        self:FindSafePosition(
            cframe
        )

    if not target then
        return false
    end

    local preserveVelocity =
        self:GetSetting(
            "PreserveVelocity",
            false
        )

    local velocity

    if preserveVelocity then
        velocity =
            root.AssemblyLinearVelocity
    end

    local success =
        SafeCall(function()
            root.CFrame =
                target
        end)

    if not success then
        return false
    end

    if preserveVelocity
        and velocity then

        pcall(function()
            root.AssemblyLinearVelocity =
                velocity
        end)
    end

    return true
end


function Teleports:TeleportToPosition(
    position,
    addHistory
)
    if not self:IsValidVector3(
        position
    ) then
        return false
    end

    local current =
        self:GetCurrentCFrame()

    local rotation =
        CFrame.identity

    if current then
        rotation =
            current - current.Position
    end

    return self:TeleportToCFrame(
        CFrame.new(position)
            * rotation,
        addHistory
    )
end



-- Named teleport


function Teleports:TeleportToLocation(name)
    local cframe =
        self:GetLocation(name)

    if not cframe then
        return false
    end

    return self:TeleportToCFrame(
        cframe
    )
end



-- Player teleport


function Teleports:CanTeleportToPlayer()
    return self:GetSetting(
        "AllowPlayerTeleport",
        true
    ) == true
end


function Teleports:TeleportToPlayer(player)
    if not self:CanTeleportToPlayer() then
        return false
    end

    if not player then
        return false
    end

    if player == self:GetLocalPlayer() then
        return false
    end

    if not player.Parent then
        return false
    end

    local targetRoot =
        self:GetRoot(player)

    if not targetRoot then
        return false
    end

    local targetCFrame =
        targetRoot.CFrame

    return self:TeleportToCFrame(
        targetCFrame
            + targetCFrame.LookVector * -4
    )
end


function Teleports:TeleportToPlayerName(
    playerName
)
    if type(playerName) ~= "string" then
        return false
    end

    local lowered =
        playerName:lower()

    for _, player in ipairs(
        PlayersService:GetPlayers()
    ) do
        if player ~= self:GetLocalPlayer() then
            local username =
                player.Name:lower()

            local displayName =
                player.DisplayName:lower()

            if username == lowered
                or displayName == lowered then

                return self:TeleportToPlayer(
                    player
                )
            end
        end
    end

    return false
end



-- Spawn


function Teleports:GetSpawnLocation()
    local character =
        self:GetCharacter()

    local root =
        self:GetRoot()

    local spawn

    if workspace:FindFirstChildOfClass(
        "SpawnLocation"
    ) then
        spawn =
            workspace:FindFirstChildOfClass(
                "SpawnLocation"
            )
    end

    if not spawn
        and workspace:FindFirstChild(
            "SpawnLocation"
        ) then

        spawn =
            workspace.SpawnLocation
    end

    if spawn
        and spawn:IsA("BasePart") then

        return spawn.CFrame
            + Vector3.new(
                0,
                4,
                0
            )
    end

    if character
        and root then

        return root.CFrame
    end

    return nil
end


function Teleports:TeleportToSpawn()
    if not self:GetSetting(
        "UseSpawnLocation",
        true
    ) then
        return false
    end

    local spawn =
        self:GetSpawnLocation()

    if not spawn then
        return false
    end

    return self:TeleportToCFrame(
        spawn
    )
end



-- Relative teleport


function Teleports:TeleportOffset(
    offset
)
    if not self:IsValidVector3(
        offset
    ) then
        return false
    end

    local current =
        self:GetCurrentCFrame()

    if not current then
        return false
    end

    return self:TeleportToCFrame(
        current + offset
    )
end


function Teleports:TeleportForward(
    distance
)
    distance =
        tonumber(distance)

    if not distance then
        return false
    end

    local root =
        self:GetRoot()

    if not root then
        return false
    end

    return self:TeleportToCFrame(
        root.CFrame
            + root.CFrame.LookVector
                * distance
    )
end


function Teleports:TeleportUp(
    distance
)
    distance =
        tonumber(distance)

    if not distance then
        return false
    end

    return self:TeleportOffset(
        Vector3.new(
            0,
            distance,
            0
        )
    )
end


function Teleports:TeleportDown(
    distance
)
    distance =
        tonumber(distance)

    if not distance then
        return false
    end

    return self:TeleportOffset(
        Vector3.new(
            0,
            -distance,
            0
        )
    )
end



-- Utility


function Teleports:CopyLocation(name)
    local cframe =
        self:GetLocation(name)

    if not cframe then
        return nil
    end

    return {
        Position = cframe.Position,
        CFrame = cframe,
    }
end


function Teleports:GetLocationCount()
    local count = 0

    for _ in pairs(
        self.Locations
    ) do
        count += 1
    end

    return count
end


function Teleports:ExportLocations()
    local result = {}

    for name, cframe in pairs(
        self.Locations
    ) do
        result[name] = {
            X = cframe.Position.X,
            Y = cframe.Position.Y,
            Z = cframe.Position.Z,

            Components = {
                cframe:GetComponents()
            },
        }
    end

    return result
end


function Teleports:ImportLocations(data)
    if type(data) ~= "table" then
        return false
    end

    for name, dataEntry in pairs(data) do
        if type(name) == "string"
            and type(dataEntry) == "table" then

            if dataEntry.Components
                and #dataEntry.Components >= 12 then

                local success, cframe =
                    pcall(
                        CFrame.new,
                        table.unpack(
                            dataEntry.Components
                        )
                    )

                if success
                    and self:IsValidCFrame(
                        cframe
                    ) then

                    self.Locations[name] =
                        cframe
                end

            elseif dataEntry.X
                and dataEntry.Y
                and dataEntry.Z then

                self.Locations[name] =
                    CFrame.new(
                        dataEntry.X,
                        dataEntry.Y,
                        dataEntry.Z
                    )
            end
        end
    end

    return true
end



-- Initialize


function Teleports:Initialize(modules)
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


function Teleports:Destroy()
    self.Locations = {}
    self.History = {}

    self.LastPosition = nil

    self.Players = nil
    self.Character = nil
    self.Math = nil
    self.Cleanup = nil
    self.Config = nil

    self.LocalPlayer = nil

    self.Initialized = false
end


return Teleports