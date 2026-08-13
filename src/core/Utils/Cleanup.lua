--[[
    Lua Test Script
    Cleanup.lua

    Centralized resource lifecycle manager.

    Responsibilities:
        - Track cleanup resources
        - Cleanup Instances
        - Cleanup connections
        - Cleanup functions
        - Cleanup tables/objects
        - Group resources
        - Owner resources
        - Scoped cleanup
        - Bulk cleanup
        - Reverse-order cleanup
        - Safe error handling
        - Resource statistics
        - Feature lifecycle cleanup
]]

local Cleanup = {
    Name = "Cleanup",

    Initialized = false,

    Items = {},
    Groups = {},
    Owners = {},

    Records = {},
    NextId = 0,

    Settings = {
        SafeMode = true,
        WarnOnFailure = true,
    },
}



-- Helpers


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


local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return false, nil
    end

    local success, result =
        pcall(
            callback,
            ...
        )

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

    --====================================================--
    -- Roblox connection
    --====================================================--

    if itemType ==
        "RBXScriptConnection" then

        return SafeCall(function()
            item:Disconnect()
        end)
    end


    --====================================================--
    -- Roblox Instance
    --====================================================--

    if itemType ==
        "Instance" then

        return SafeCall(function()
            if item.Parent ~= nil then
                item:Destroy()
            end
        end)
    end


    --====================================================--
    -- Function
    --====================================================--

    if type(item) ==
        "function" then

        return SafeCall(item)
    end


    --====================================================--
    -- Table/object
    --====================================================--

    if type(item) ==
        "table" then

        if type(item.Destroy) ==
            "function" then

            return SafeCall(
                item.Destroy,
                item
            )
        end

        if type(item.Cleanup) ==
            "function" then

            return SafeCall(
                item.Cleanup,
                item
            )
        end

        if type(item.Disconnect) ==
            "function" then

            return SafeCall(
                item.Disconnect,
                item
            )
        end

        if type(item.Dispose) ==
            "function" then

            return SafeCall(
                item.Dispose,
                item
            )
        end

        if type(item.Close) ==
            "function" then

            return SafeCall(
                item.Close,
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
    self.Owners = {}

    self.Records = {}
    self.NextId = 0

    self.Initialized = true

    return self
end



-- IDs


function Cleanup:CreateId()
    self.NextId += 1

    return self.NextId
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



-- Owners


function Cleanup:CreateOwner(owner)
    owner =
        NormalizeOwner(owner)

    if not self.Owners[owner] then
        self.Owners[owner] = {}
    end

    return self.Owners[owner]
end


function Cleanup:HasOwner(owner)
    owner =
        NormalizeOwner(owner)

    return self.Owners[owner] ~= nil
end


function Cleanup:GetOwner(owner)
    owner =
        NormalizeOwner(owner)

    return self.Owners[owner]
end


function Cleanup:GetOwners()
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



-- Add


function Cleanup:Add(
    item,
    group,
    owner
)
    if not item then
        return nil
    end

    group =
        NormalizeGroup(group)

    owner =
        NormalizeOwner(owner)

    local groupItems =
        self:CreateGroup(group)

    local ownerItems =
        self:CreateOwner(owner)

    local id =
        self:CreateId()

    local record = {
        Id = id,

        Item = item,

        Group = group,
        Owner = owner,

        Active = true,
    }

    self.Records[item] =
        record

    table.insert(
        groupItems,
        item
    )

    table.insert(
        ownerItems,
        item
    )

    table.insert(
        self.Items,
        item
    )

    return item
end



-- Specialized Add Methods


function Cleanup:AddFunction(
    callback,
    group,
    owner
)
    if type(callback) ~= "function" then
        return nil
    end

    return self:Add(
        callback,
        group,
        owner
    )
end


function Cleanup:AddConnection(
    connection,
    group,
    owner
)
    if not connection then
        return nil
    end

    return self:Add(
        connection,
        group,
        owner
    )
end


function Cleanup:AddInstance(
    instance,
    group,
    owner
)
    if not instance then
        return nil
    end

    return self:Add(
        instance,
        group,
        owner
    )
end


function Cleanup:AddMany(
    items,
    group,
    owner
)
    if type(items) ~= "table" then
        return false
    end

    for _, item in ipairs(items) do

        self:Add(
            item,
            group,
            owner
        )
    end

    return true
end



-- Remove


function Cleanup:Remove(item)
    if not item then
        return false
    end

    local record =
        self.Records[item]

    local removed = false

    -- Remove from main list.
    for index =
        #self.Items,
        1,
        -1 do

        if self.Items[index] ==
            item then

            table.remove(
                self.Items,
                index
            )

            removed = true
        end
    end

    -- Remove from group.
    if record then

        local groupItems =
            self.Groups[record.Group]

        if groupItems then

            for index =
                #groupItems,
                1,
                -1 do

                if groupItems[index] ==
                    item then

                    table.remove(
                        groupItems,
                        index
                    )
                end
            end
        end

        -- Remove from owner.
        local ownerItems =
            self.Owners[record.Owner]

        if ownerItems then

            for index =
                #ownerItems,
                1,
                -1 do

                if ownerItems[index] ==
                    item then

                    table.remove(
                        ownerItems,
                        index
                    )
                end
            end
        end
    end

    self.Records[item] =
        nil

    return removed
end



-- Destroy One


function Cleanup:DestroyItem(item)
    if not item then
        return false
    end

    local success =
        CleanupItem(item)

    self:Remove(item)

    return success
end



-- Clean Group


function Cleanup:CleanGroup(group)
    group =
        NormalizeGroup(group)

    local groupItems =
        self.Groups[group]

    if not groupItems then
        return false
    end

    local items = {}

    for _, item in ipairs(
        groupItems
    ) do

        table.insert(
            items,
            item
        )
    end

    -- Reverse order.
    for index =
        #items,
        1,
        -1 do

        self:DestroyItem(
            items[index]
        )
    end

    self.Groups[group] = {}

    return true
end



-- Clean Owner


function Cleanup:CleanOwner(owner)
    owner =
        NormalizeOwner(owner)

    local ownerItems =
        self.Owners[owner]

    if not ownerItems then
        return false
    end

    local items = {}

    for _, item in ipairs(
        ownerItems
    ) do

        table.insert(
            items,
            item
        )
    end

    for index =
        #items,
        1,
        -1 do

        self:DestroyItem(
            items[index]
        )
    end

    self.Owners[owner] = {}

    return true
end



-- Clean All


function Cleanup:CleanAll()
    local items = {}

    for _, item in ipairs(
        self.Items
    ) do

        table.insert(
            items,
            item
        )
    end

    -- Reverse registration order.
    for index =
        #items,
        1,
        -1 do

        self:DestroyItem(
            items[index]
        )
    end

    self.Items = {}

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



-- Aliases


function Cleanup:Clear(group)
    if group then
        return self:CleanGroup(group)
    end

    return self:CleanAll()
end


function Cleanup:DestroyGroup(group)
    return self:CleanGroup(group)
end


function Cleanup:ClearOwner(owner)
    return self:CleanOwner(owner)
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


function Cleanup:CountOwner(owner)
    owner =
        NormalizeOwner(owner)

    local ownerItems =
        self.Owners[owner]

    if not ownerItems then
        return 0
    end

    return #ownerItems
end


function Cleanup:Contains(item)
    if not item then
        return false
    end

    return self.Records[item] ~= nil
end


function Cleanup:GetRecord(item)
    return self.Records[item]
end


function Cleanup:GetStats()
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


function Cleanup:GetGroupStats()
    local stats = {}

    for group, items in pairs(
        self.Groups
    ) do

        stats[group] = #items
    end

    return stats
end


function Cleanup:GetOwnerStats()
    local stats = {}

    for owner, items in pairs(
        self.Owners
    ) do

        stats[owner] = #items
    end

    return stats
end



-- Scoped Cleanup


function Cleanup:CreateScope(
    group,
    owner
)
    group =
        NormalizeGroup(group)

    owner =
        NormalizeOwner(
            owner or group
        )

    self:CreateGroup(group)
    self:CreateOwner(owner)

    local scope = {
        Group = group,
        Owner = owner,

        Manager = self,

        Closed = false,
    }


    function scope:Add(item)
        if self.Closed then
            return nil
        end

        return self.Manager:Add(
            item,
            self.Group,
            self.Owner
        )
    end


    function scope:AddFunction(callback)
        if self.Closed then
            return nil
        end

        return self.Manager:AddFunction(
            callback,
            self.Group,
            self.Owner
        )
    end


    function scope:AddConnection(connection)
        if self.Closed then
            return nil
        end

        return self.Manager:AddConnection(
            connection,
            self.Group,
            self.Owner
        )
    end


    function scope:AddInstance(instance)
        if self.Closed then
            return nil
        end

        return self.Manager:AddInstance(
            instance,
            self.Group,
            self.Owner
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


    function scope:CleanOwner()
        if self.Closed then
            return
        end

        self.Manager:CleanOwner(
            self.Owner
        )

        self.Closed = true
    end


    function scope:IsClosed()
        return self.Closed
    end


    return scope
end



-- Settings


function Cleanup:GetSetting(
    name,
    default
)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    return default
end


function Cleanup:SetSetting(
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


function Cleanup:Destroy()
    self:CleanAll()

    self.Items = {}
    self.Groups = {}
    self.Owners = {}

    self.Records = {}

    self.NextId = 0

    self.Initialized = false
end


return Cleanup