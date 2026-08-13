--[[
    Lua Test Script
    Connections.lua

    Centralized connection manager.

    Responsibilities:
        - Create connections
        - Group connections
        - Track connection ownership
        - Disconnect individual connections
        - Disconnect groups
        - Disconnect owners
        - Disconnect everything
        - One-shot connections
        - Connection statistics
        - Safe callback execution
        - Feature lifecycle cleanup
]]

local Connections = {
    Name = "Connections",

    Initialized = false,

    Groups = {},
    All = {},

    Records = {},
    Owners = {},

    NextId = 0,

    Settings = {
        SafeCallbacks = true,
        WarnOnInvalid = true,
    },
}



-- Helpers


local function IsConnection(value)
    return value ~= nil
        and type(value) == "userdata"
        and type(value.Disconnect) == "function"
end


local function DisconnectConnection(connection)
    if not connection then
        return false
    end

    local success =
        pcall(function()
            connection:Disconnect()
        end)

    return success
end


local function NormalizeGroup(group)
    if type(group) ~= "string"
        or group == "" then

        return "Default"
    end

    return group
end


local function NormalizeOwner(owner)
    if type(owner) ~= "string"
        or owner == "" then

        return "Unknown"
    end

    return owner
end



-- Initialize


function Connections:Initialize()
    if self.Initialized then
        return self
    end

    self.Groups = {}
    self.All = {}

    self.Records = {}
    self.Owners = {}

    self.NextId = 0

    self.Initialized = true

    return self
end



-- Internal IDs


function Connections:CreateId()
    self.NextId += 1

    return self.NextId
end



-- Groups


function Connections:CreateGroup(group)
    group =
        NormalizeGroup(group)

    if not self.Groups[group] then
        self.Groups[group] = {}
    end

    return self.Groups[group]
end


function Connections:HasGroup(group)
    group =
        NormalizeGroup(group)

    return self.Groups[group] ~= nil
end


function Connections:GetGroup(group)
    group =
        NormalizeGroup(group)

    return self.Groups[group]
end


function Connections:RemoveGroup(group)
    group =
        NormalizeGroup(group)

    if not self.Groups[group] then
        return false
    end

    self:DisconnectGroup(group)

    self.Groups[group] = nil

    return true
end


function Connections:GetGroups()
    local groups = {}

    for group in pairs(
        self.Groups
    ) do

        table.insert(
            groups,
            group
        )
    end

    table.sort(groups)

    return groups
end



-- Ownership


function Connections:CreateOwner(owner)
    owner =
        NormalizeOwner(owner)

    if not self.Owners[owner] then
        self.Owners[owner] = {}
    end

    return self.Owners[owner]
end


function Connections:HasOwner(owner)
    owner =
        NormalizeOwner(owner)

    return self.Owners[owner] ~= nil
end


function Connections:GetOwner(owner)
    owner =
        NormalizeOwner(owner)

    return self.Owners[owner]
end


function Connections:GetOwners()
    local owners = {}

    for owner in pairs(
        self.Owners
    ) do

        table.insert(
            owners,
            owner
        )
    end

    table.sort(owners)

    return owners
end



-- Add Connection


function Connections:Add(
    connection,
    group,
    owner
)
    if not connection then
        return nil
    end

    if not IsConnection(connection) then

        if self.Settings.WarnOnInvalid then
            warn(
                "[Lua Test] Connections:Add received invalid connection"
            )
        end

        return nil
    end

    group =
        NormalizeGroup(group)

    owner =
        NormalizeOwner(owner)

    local groupTable =
        self:CreateGroup(group)

    local ownerTable =
        self:CreateOwner(owner)

    -- Prevent duplicate tracking.
    if self:IsConnected(connection) then
        return connection
    end

    local id =
        self:CreateId()

    local record = {
        Id = id,

        Connection = connection,

        Group = group,
        Owner = owner,

        Connected = true,
    }

    self.Records[connection] =
        record

    table.insert(
        groupTable,
        connection
    )

    table.insert(
        ownerTable,
        connection
    )

    table.insert(
        self.All,
        connection
    )

    return connection
end



-- Connect


function Connections:Connect(
    signal,
    callback,
    group,
    owner
)
    if not signal then
        return nil,
            "Signal missing"
    end

    if type(callback) ~= "function" then
        return nil,
            "Callback must be a function"
    end

    local wrappedCallback =
        callback

    if self.Settings.SafeCallbacks then

        wrappedCallback =
            function(...)
                local success, result =
                    pcall(
                        callback,
                        ...
                    )

                if not success then
                    warn(
                        "[Lua Test] Connection callback error:",
                        result
                    )
                end

                return result
            end
    end

    local success, connection =
        pcall(function()
            return signal:Connect(
                wrappedCallback
            )
        end)

    if not success then
        warn(
            "[Lua Test] Failed to create connection:",
            connection
        )

        return nil,
            connection
    end

    self:Add(
        connection,
        group,
        owner
    )

    return connection
end



-- Once


function Connections:Once(
    signal,
    callback,
    group,
    owner
)
    if not signal then
        return nil,
            "Signal missing"
    end

    if type(callback) ~= "function" then
        return nil,
            "Callback must be a function"
    end

    local connection

    local function Handler(...)
        if connection then
            self:Disconnect(
                connection
            )
        end

        if self.Settings.SafeCallbacks then
            local success, result =
                pcall(
                    callback,
                    ...
                )

            if not success then
                warn(
                    "[Lua Test] One-shot callback error:",
                    result
                )
            end
        else
            callback(...)
        end
    end

    local success, result =
        pcall(function()
            return signal:Connect(
                Handler
            )
        end)

    if not success then
        return nil,
            result
    end

    connection = result

    self:Add(
        connection,
        group,
        owner
    )

    return connection
end



-- Disconnect One


function Connections:Disconnect(
    connection
)
    if not connection then
        return false
    end

    local record =
        self.Records[connection]

    local disconnected =
        DisconnectConnection(
            connection
        )

    if record then
        record.Connected = false

        local groupTable =
            self.Groups[record.Group]

        if groupTable then
            for index =
                #groupTable,
                1,
                -1 do

                if groupTable[index] ==
                    connection then

                    table.remove(
                        groupTable,
                        index
                    )
                end
            end
        end

        local ownerTable =
            self.Owners[record.Owner]

        if ownerTable then
            for index =
                #ownerTable,
                1,
                -1 do

                if ownerTable[index] ==
                    connection then

                    table.remove(
                        ownerTable,
                        index
                    )
                end
            end
        end
    end

    for index =
        #self.All,
        1,
        -1 do

        if self.All[index] ==
            connection then

            table.remove(
                self.All,
                index
            )
        end
    end

    self.Records[connection] =
        nil

    return disconnected
end



-- Disconnect Group


function Connections:DisconnectGroup(
    group
)
    group =
        NormalizeGroup(group)

    local groupTable =
        self.Groups[group]

    if not groupTable then
        return false
    end

    local connections = {}

    for _, connection in ipairs(
        groupTable
    ) do

        table.insert(
            connections,
            connection
        )
    end

    for _, connection in ipairs(
        connections
    ) do

        self:Disconnect(
            connection
        )
    end

    self.Groups[group] = {}

    return true
end



-- Disconnect Owner


function Connections:DisconnectOwner(
    owner
)
    owner =
        NormalizeOwner(owner)

    local ownerTable =
        self.Owners[owner]

    if not ownerTable then
        return false
    end

    local connections = {}

    for _, connection in ipairs(
        ownerTable
    ) do

        table.insert(
            connections,
            connection
        )
    end

    for _, connection in ipairs(
        connections
    ) do

        self:Disconnect(
            connection
        )
    end

    self.Owners[owner] = {}

    return true
end



-- Disconnect All


function Connections:DisconnectAll()
    local connections = {}

    for _, connection in ipairs(
        self.All
    ) do

        table.insert(
            connections,
            connection
        )
    end

    for _, connection in ipairs(
        connections
    ) do

        self:Disconnect(
            connection
        )
    end

    self.All = {}

    for group in pairs(
        self.Groups
    ) do

        self.Groups[group] = {}
    end

    for owner in pairs(
        self.Owners
    ) do

        self.Owners[owner] = {}
    end

    return true
end



-- Statistics


function Connections:CountGroup(
    group
)
    group =
        NormalizeGroup(group)

    local groupTable =
        self.Groups[group]

    if not groupTable then
        return 0
    end

    return #groupTable
end


function Connections:CountOwner(
    owner
)
    owner =
        NormalizeOwner(owner)

    local ownerTable =
        self.Owners[owner]

    if not ownerTable then
        return 0
    end

    return #ownerTable
end


function Connections:Count()
    return #self.All
end


function Connections:IsConnected(
    connection
)
    if not connection then
        return false
    end

    local record =
        self.Records[connection]

    if record then
        return record.Connected == true
    end

    for _, existing in ipairs(
        self.All
    ) do

        if existing == connection then
            return true
        end
    end

    return false
end


function Connections:GetRecord(
    connection
)
    return self.Records[connection]
end


function Connections:GetStats()
    local stats = {
        Total = self:Count(),
        Groups = 0,
        Owners = 0,
    }

    for _ in pairs(
        self.Groups
    ) do
        stats.Groups += 1
    end

    for _ in pairs(
        self.Owners
    ) do
        stats.Owners += 1
    end

    return stats
end


function Connections:GetGroupStats()
    local stats = {}

    for group, connections in pairs(
        self.Groups
    ) do

        stats[group] = #connections
    end

    return stats
end


function Connections:GetOwnerStats()
    local stats = {}

    for owner, connections in pairs(
        self.Owners
    ) do

        stats[owner] = #connections
    end

    return stats
end



-- Cleanup Aliases


function Connections:Clear(group)
    if group then
        return self:DisconnectGroup(
            group
        )
    end

    return self:DisconnectAll()
end


function Connections:DestroyGroup(
    group
)
    return self:RemoveGroup(
        group
    )
end


function Connections:ClearOwner(
    owner
)
    return self:DisconnectOwner(
        owner
    )
end



-- Settings


function Connections:GetSetting(
    name,
    default
)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    return default
end


function Connections:SetSetting(
    name,
    value
)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end



-- Destroy


function Connections:Destroy()
    self:DisconnectAll()

    self.Groups = {}
    self.All = {}

    self.Records = {}
    self.Owners = {}

    self.NextId = 0

    self.Initialized = false
end


return Connections