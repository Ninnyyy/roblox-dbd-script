local Cleanup = {
    Name = "Cleanup",

    Initialized = false,

    Items = {},
    Groups = {},
}


-- Helpers


local function NormalizeGroup(group)
    if type(group) ~= "string"
        or group == "" then
        return "Default"
    end

    return group
end

local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result =
        pcall(callback, ...)

    if not success then
        warn(
            "[Lua Test] Cleanup error:",
            result
        )

        return false, result
    end

    return true, result
end

local function CleanupItem(item)
    if not item then
        return false
    end

    local itemType =
        typeof(item)

    -- Roblox connections
    if itemType == "RBXScriptConnection" then
        return SafeCall(function()
            item:Disconnect()
        end)
    end

    -- Instances
    if itemType == "Instance" then
        return SafeCall(function()
            item:Destroy()
        end)
    end

    -- Functions
    if type(item) == "function" then
        return SafeCall(item)
    end

    -- Tables with cleanup methods
    if type(item) == "table" then
        if type(item.Destroy) == "function" then
            return SafeCall(
                item.Destroy,
                item
            )
        end

        if type(item.Cleanup) == "function" then
            return SafeCall(
                item.Cleanup,
                item
            )
        end

        if type(item.Disconnect) == "function" then
            return SafeCall(
                item.Disconnect,
                item
            )
        end
    end

    return false
end


-- Initialize


function Cleanup:Initialize()
    if self.Initialized then
        return self
    end

    self.Items = {}
    self.Groups = {}

    self.Initialized = true

    return self
end


-- Groups


function Cleanup:CreateGroup(group)
    group =
        NormalizeGroup(group)

    if not self.Groups[group] then
        self.Groups[group] = {}
    end

    return self.Groups[group]
end

function Cleanup:HasGroup(group)
    group =
        NormalizeGroup(group)

    return self.Groups[group] ~= nil
end

function Cleanup:GetGroup(group)
    group =
        NormalizeGroup(group)

    return self.Groups[group]
end

function Cleanup:GetGroups()
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


-- Add


function Cleanup:Add(
    item,
    group
)
    if not item then
        return nil
    end

    group =
        NormalizeGroup(group)

    local groupItems =
        self:CreateGroup(group)

    table.insert(
        groupItems,
        item
    )

    table.insert(
        self.Items,
        item
    )

    return item
end


-- Add cleanup callback


function Cleanup:AddFunction(
    callback,
    group
)
    if type(callback) ~= "function" then
        return nil
    end

    return self:Add(
        callback,
        group
    )
end


-- Add connection


function Cleanup:AddConnection(
    connection,
    group
)
    if not connection then
        return nil
    end

    return self:Add(
        connection,
        group
    )
end


-- Add instance


function Cleanup:AddInstance(
    instance,
    group
)
    if not instance then
        return nil
    end

    return self:Add(
        instance,
        group
    )
end


-- Remove item


function Cleanup:Remove(item)
    if not item then
        return false
    end

    local removed = false

    for index = #self.Items, 1, -1 do
        if self.Items[index] == item then
            table.remove(
                self.Items,
                index
            )

            removed = true
        end
    end

    for _, groupItems in pairs(
        self.Groups
    ) do
        for index = #groupItems, 1, -1 do
            if groupItems[index] == item then
                table.remove(
                    groupItems,
                    index
                )
            end
        end
    end

    return removed
end


-- Cleanup one item


function Cleanup:DestroyItem(item)
    if not item then
        return false
    end

    local success =
        CleanupItem(item)

    self:Remove(item)

    return success
end


-- Cleanup group


function Cleanup:CleanGroup(group)
    group =
        NormalizeGroup(group)

    local groupItems =
        self.Groups[group]

    if not groupItems then
        return false
    end

    for index = #groupItems, 1, -1 do
        local item =
            groupItems[index]

        CleanupItem(item)

        groupItems[index] = nil

        for itemIndex = #self.Items, 1, -1 do
            if self.Items[itemIndex] == item then
                table.remove(
                    self.Items,
                    itemIndex
                )

                break
            end
        end
    end

    return true
end


-- Cleanup everything


function Cleanup:CleanAll()
    -- Reverse order is intentional.
    for index = #self.Items, 1, -1 do
        CleanupItem(
            self.Items[index]
        )

        self.Items[index] = nil
    end

    for group in pairs(
        self.Groups
    ) do
        self.Groups[group] = {}
    end

    return true
end


-- Aliases


function Cleanup:Clear(group)
    if group then
        return self:CleanGroup(
            group
        )
    end

    return self:CleanAll()
end

function Cleanup:DestroyGroup(group)
    return self:CleanGroup(
        group
    )
end


-- Statistics


function Cleanup:Count()
    return #self.Items
end

function Cleanup:CountGroup(group)
    group =
        NormalizeGroup(group)

    local groupItems =
        self.Groups[group]

    if not groupItems then
        return 0
    end

    return #groupItems
end

function Cleanup:Contains(item)
    if not item then
        return false
    end

    for _, existing in ipairs(
        self.Items
    ) do
        if existing == item then
            return true
        end
    end

    return false
end


-- Batch registration


function Cleanup:AddMany(
    items,
    group
)
    if type(items) ~= "table" then
        return false
    end

    for _, item in ipairs(items) do
        self:Add(
            item,
            group
        )
    end

    return true
end


-- Scoped cleanup


function Cleanup:CreateScope(
    group
)
    group =
        NormalizeGroup(group)

    self:CreateGroup(group)

    local scope = {
        Group = group,
        Manager = self,
        Closed = false,
    }

    function scope:Add(item)
        if self.Closed then
            return nil
        end

        return self.Manager:Add(
            item,
            self.Group
        )
    end

    function scope:AddFunction(callback)
        if self.Closed then
            return nil
        end

        return self.Manager:AddFunction(
            callback,
            self.Group
        )
    end

    function scope:AddConnection(connection)
        if self.Closed then
            return nil
        end

        return self.Manager:AddConnection(
            connection,
            self.Group
        )
    end

    function scope:AddInstance(instance)
        if self.Closed then
            return nil
        end

        return self.Manager:AddInstance(
            instance,
            self.Group
        )
    end

    function scope:Clean()
        if self.Closed then
            return
        end

        self.Manager:CleanGroup(
            self.Group
        )

        self.Closed = true
    end

    return scope
end


-- Initialize


function Cleanup:Initialize()
    if self.Initialized then
        return self
    end

    self.Items = {}
    self.Groups = {}

    self.Initialized = true

    return self
end


-- Destroy


function Cleanup:Destroy()
    self:CleanAll()

    self.Items = {}
    self.Groups = {}

    self.Initialized = false
end

return Cleanup