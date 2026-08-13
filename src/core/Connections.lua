local Connections = {
    Name = "Connections",

    Initialized = false,

    Groups = {},
    All = {},
}


-- Helpers


local function IsConnection(value)
    return value ~= nil
        and type(value) == "userdata"
        and type(value.Disconnect) == "function"
end

local function Disconnect(connection)
    if not connection then
        return false
    end

    local success = pcall(function()
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


-- Initialize


function Connections:Initialize()
    if self.Initialized then
        return self
    end

    self.Groups = {}
    self.All = {}

    self.Initialized = true

    return self
end


-- Group management


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


-- Add connection


function Connections:Add(
    connection,
    group
)
    if not connection then
        return nil
    end

    if not IsConnection(connection) then
        warn(
            "[Lua Test] Connections:Add received invalid connection"
        )

        return nil
    end

    group =
        NormalizeGroup(group)

    local groupTable =
        self:CreateGroup(group)

    table.insert(
        groupTable,
        connection
    )

    table.insert(
        self.All,
        connection
    )

    return connection
end


-- Connect helper


function Connections:Connect(
    signal,
    callback,
    group
)
    if not signal then
        return nil,
            "Signal missing"
    end

    if type(callback) ~= "function" then
        return nil,
            "Callback must be a function"
    end

    local success, connection =
        pcall(function()
            return signal:Connect(
                callback
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
        group
    )

    return connection
end


-- One-shot connection


function Connections:Once(
    signal,
    callback,
    group
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

        callback(...)
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
        group
    )

    return connection
end


-- Disconnect one


function Connections:Disconnect(
    connection
)
    if not connection then
        return false
    end

    local disconnected =
        Disconnect(connection)

    -- Remove from groups.
    for _, groupTable in pairs(
        self.Groups
    ) do
        for index = #groupTable, 1, -1 do
            if groupTable[index] == connection then
                table.remove(
                    groupTable,
                    index
                )
            end
        end
    end

    -- Remove from global list.
    for index = #self.All, 1, -1 do
        if self.All[index] == connection then
            table.remove(
                self.All,
                index
            )
        end
    end

    return disconnected
end


-- Disconnect group


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

    for index = #groupTable, 1, -1 do
        local connection =
            groupTable[index]

        Disconnect(connection)

        groupTable[index] = nil

        for allIndex = #self.All, 1, -1 do
            if self.All[allIndex] == connection then
                table.remove(
                    self.All,
                    allIndex
                )

                break
            end
        end
    end

    return true
end


-- Disconnect everything


function Connections:DisconnectAll()
    for index = #self.All, 1, -1 do
        Disconnect(
            self.All[index]
        )

        self.All[index] = nil
    end

    for group in pairs(
        self.Groups
    ) do
        self.Groups[group] = {}
    end

    return true
end


-- Group statistics


function Connections:CountGroup(group)
    group =
        NormalizeGroup(group)

    local groupTable =
        self.Groups[group]

    if not groupTable then
        return 0
    end

    return #groupTable
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

    for _, existing in ipairs(
        self.All
    ) do
        if existing == connection then
            return true
        end
    end

    return false
end


-- Cleanup aliases


function Connections:Clear(group)
    if group then
        return self:DisconnectGroup(
            group
        )
    end

    return self:DisconnectAll()
end

function Connections:DestroyGroup(group)
    return self:RemoveGroup(
        group
    )
end


-- Destroy


function Connections:Destroy()
    self:DisconnectAll()

    self.Groups = {}
    self.All = {}

    self.Initialized = false
end

return Connections