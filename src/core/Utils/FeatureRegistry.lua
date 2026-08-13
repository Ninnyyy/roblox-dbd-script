--[[
    Lua Test Script
    FeatureRegistry.lua

    Central feature registry.

    Responsibilities:
        - Register features
        - Store feature metadata
        - Track feature order
        - Track categories
        - Track dependencies
        - Track priority
        - Track enabled state
        - Track initialization state
        - Track runtime status
        - Track errors
        - Provide feature queries
        - Provide category queries
        - Provide UI metadata
        - Provide search
        - Provide status snapshots
        - Support manager synchronization
        - Support UI synchronization

    UI CATEGORIES:

        Player
        Killer
        Visuals
        Movement
        Misc

    Existing APIs are preserved.
]]

local FeatureRegistry = {
    Name = "FeatureRegistry",

    Items = {},
    Order = {},

    Initialized = false,

    Settings = {
        AllowDuplicate = false,
        SortByPriority = true,
        DefaultCategory = "Misc",
    },
}




-- HELPERS


local function NormalizeName(name)

    if type(name) ~= "string" then
        return nil
    end

    name = name:gsub("^%s+", "")
    name = name:gsub("%s+$", "")

    if name == "" then
        return nil
    end

    return name
end


local function NormalizeCategory(category)

    if type(category) ~= "string" then
        return FeatureRegistry.Settings.DefaultCategory
    end

    category = category:gsub("^%s+", "")
    category = category:gsub("%s+$", "")

    if category == "" then
        return FeatureRegistry.Settings.DefaultCategory
    end

    local lower =
        string.lower(category)

    local aliases = {
        player = "Player",
        players = "Player",

        killer = "Killer",
        killers = "Killer",

        visual = "Visuals",
        visuals = "Visuals",

        movement = "Movement",
        move = "Movement",

        misc = "Misc",
        miscellaneous = "Misc",
        general = "Misc",
    }

    return aliases[lower]
        or category
end


local function NormalizeDependencies(
    dependencies
)

    if type(dependencies) ~= "table" then
        return {}
    end

    local result = {}
    local seen = {}

    for _, dependency in ipairs(
        dependencies
    ) do

        dependency =
            NormalizeName(dependency)

        if dependency
            and not seen[dependency] then

            seen[dependency] = true

            table.insert(
                result,
                dependency
            )
        end
    end

    return result
end


local function CopyTable(source)

    if type(source) ~= "table" then
        return source
    end

    local result = {}

    for key, value in pairs(source) do

        if type(value) == "table" then
            result[key] =
                CopyTable(value)
        else
            result[key] = value
        end
    end

    return result
end


local function GetFunction(
    module,
    names
)

    if type(module) ~= "table" then
        return nil
    end

    for _, name in ipairs(names) do

        if type(module[name]) == "function" then
            return module[name]
        end

    end

    return nil
end




-- INITIALIZE


function FeatureRegistry:Initialize()

    if self.Initialized then
        return self
    end

    self.Items =
        self.Items
        or {}

    self.Order =
        self.Order
        or {}

    self.Initialized = true

    return self
end




-- REGISTRATION


function FeatureRegistry:Register(
    name,
    feature,
    options
)

    name =
        NormalizeName(name)

    if not name then

        return false,
            "Feature name must be a string"
    end

    if type(feature) ~= "table" then

        return false,
            "Feature must be a table"
    end

    options =
        options
        or {}

    if self.Items[name]
        and not self.Settings.AllowDuplicate then

        return false,
            "Feature already registered"
    end

    if self.Items[name] then
        self:Remove(name)
    end


    local category =
        NormalizeCategory(
            options.Category
            or feature.Category
        )


    local metadata =
        CopyTable(
            options.Metadata
            or feature.Metadata
            or {}
        )


    -- UI metadata

    local displayName =
        options.DisplayName
        or feature.DisplayName
        or name

    local description =
        options.Description
        or feature.Description
        or metadata.Description
        or ""

    local icon =
        options.Icon
        or feature.Icon
        or metadata.Icon
        or ""


    local record = {

        Name = name,

        DisplayName =
            tostring(
                displayName
            ),

        Description =
            tostring(
                description
            ),

        Icon =
            tostring(
                icon
            ),

        Module =
            feature,

        Enabled = false,

        Initialized = false,

        Status = "Registered",

        Error = nil,

        Category =
            category,

        Priority =
            tonumber(
                options.Priority
                or feature.Priority
            )
            or 0,

        AutoStart =
            options.AutoStart == true,

        Dependencies =
            NormalizeDependencies(
                options.Dependencies
                or feature.Dependencies
            ),

        Metadata =
            metadata,
    }


    self.Items[name] =
        record

    table.insert(
        self.Order,
        name
    )


    if self.Settings.SortByPriority then
        self:SortOrder()
    end


    return true
end




-- REMOVE


function FeatureRegistry:Remove(name)

    name =
        NormalizeName(name)

    if not name then
        return false
    end

    if not self.Items[name] then
        return false
    end

    self.Items[name] = nil

    for index =
        #self.Order,
        1,
        -1 do

        if self.Order[index] == name then

            table.remove(
                self.Order,
                index
            )

        end
    end

    return true
end


function FeatureRegistry:Unregister(name)

    return self:Remove(name)
end




-- ORDERING


function FeatureRegistry:SortOrder()

    table.sort(
        self.Order,
        function(a, b)

            local featureA =
                self.Items[a]

            local featureB =
                self.Items[b]

            if not featureA
                or not featureB then

                return a < b
            end

            if featureA.Priority ==
                featureB.Priority then

                return a < b
            end

            return featureA.Priority <
                featureB.Priority

        end
    )

    return true
end




-- BASIC QUERIES


function FeatureRegistry:Get(name)

    name =
        NormalizeName(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return record.Module
end


function FeatureRegistry:GetRecord(name)

    name =
        NormalizeName(name)

    return self.Items[name]
end


function FeatureRegistry:Exists(name)

    name =
        NormalizeName(name)

    return self.Items[name] ~= nil
end


function FeatureRegistry:Has(name)

    return self:Exists(name)
end


function FeatureRegistry:GetAll()

    return self.Items
end


function FeatureRegistry:GetOrder()

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        table.insert(
            result,
            name
        )

    end

    return result
end


function FeatureRegistry:GetNames()

    local names = {}

    for _, name in ipairs(
        self.Order
    ) do

        table.insert(
            names,
            name
        )

    end

    return names
end


function FeatureRegistry:Count()

    local count = 0

    for _ in pairs(
        self.Items
    ) do

        count += 1

    end

    return count
end




-- DISPLAY INFORMATION


function FeatureRegistry:GetDisplayName(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return record.DisplayName
end


function FeatureRegistry:GetDescription(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return record.Description
end


function FeatureRegistry:GetIcon(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return record.Icon
end


function FeatureRegistry:SetDisplayInfo(
    name,
    displayName,
    description,
    icon
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    if displayName ~= nil then
        record.DisplayName =
            tostring(displayName)
    end

    if description ~= nil then
        record.Description =
            tostring(description)
    end

    if icon ~= nil then
        record.Icon =
            tostring(icon)
    end

    return true
end




-- ENABLED STATE


function FeatureRegistry:SetEnabled(
    name,
    enabled
)

    local record =
        self.Items[name]

    if not record then

        return false,
            "Feature not found"
    end

    record.Enabled =
        enabled == true

    if record.Enabled then

        if record.Initialized then
            record.Status =
                "Initialized"
        else
            record.Status =
                "Registered"
        end

    else

        record.Status =
            "Disabled"

    end

    return true
end


function FeatureRegistry:IsEnabled(name)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    return record.Enabled == true
end


function FeatureRegistry:GetEnabled()

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and record.Enabled then

            result[name] =
                record.Module

        end
    end

    return result
end


function FeatureRegistry:GetEnabledNames()

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and record.Enabled then

            table.insert(
                result,
                name
            )

        end
    end

    return result
end




-- INITIALIZATION STATE


function FeatureRegistry:SetInitialized(
    name,
    initialized
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    record.Initialized =
        initialized == true

    if record.Initialized then

        record.Status =
            "Initialized"

    elseif record.Enabled then

        record.Status =
            "Registered"

    else

        record.Status =
            "Disabled"

    end

    return true
end


function FeatureRegistry:IsInitialized(name)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    return record.Initialized == true
end




-- RUNTIME STATUS


function FeatureRegistry:SetStatus(
    name,
    status,
    errorMessage
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    record.Status =
        status
        or "Unknown"

    record.Error =
        errorMessage

    return true
end


function FeatureRegistry:SetError(
    name,
    errorMessage
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    record.Status =
        "Error"

    record.Error =
        errorMessage

    return true
end


function FeatureRegistry:ClearError(name)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    record.Error = nil

    if record.Initialized then
        record.Status =
            "Initialized"

    elseif record.Enabled then
        record.Status =
            "Registered"

    else
        record.Status =
            "Disabled"
    end

    return true
end




-- DEPENDENCIES


function FeatureRegistry:GetDependencies(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return CopyTable(
        record.Dependencies
    )
end


function FeatureRegistry:HasDependency(
    name,
    dependency
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    dependency =
        NormalizeName(dependency)

    for _, value in ipairs(
        record.Dependencies
    ) do

        if value == dependency then
            return true
        end

    end

    return false
end


function FeatureRegistry:GetDependents(name)

    local result = {}

    for _, featureName in ipairs(
        self.Order
    ) do

        local record =
            self.Items[featureName]

        if record then

            for _, dependency in ipairs(
                record.Dependencies
            ) do

                if dependency == name then

                    table.insert(
                        result,
                        featureName
                    )

                    break
                end

            end
        end
    end

    return result
end




-- CATEGORIES


function FeatureRegistry:GetCategory(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return record.Category
end


function FeatureRegistry:SetCategory(
    name,
    category
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    record.Category =
        NormalizeCategory(category)

    return true
end


function FeatureRegistry:GetByCategory(
    category
)

    category =
        NormalizeCategory(category)

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and record.Category ==
                category then

            result[name] =
                record.Module

        end
    end

    return result
end


function FeatureRegistry:GetNamesByCategory(
    category
)

    category =
        NormalizeCategory(category)

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and record.Category ==
                category then

            table.insert(
                result,
                name
            )

        end
    end

    return result
end


function FeatureRegistry:GetRecordsByCategory(
    category
)

    category =
        NormalizeCategory(category)

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and record.Category ==
                category then

            table.insert(
                result,
                record
            )

        end
    end

    return result
end


function FeatureRegistry:GetCategories()

    local categories = {}
    local seen = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record
            and not seen[record.Category] then

            seen[record.Category] = true

            table.insert(
                categories,
                record.Category
            )

        end
    end


    table.sort(
        categories,
        function(a, b)

            local preferred = {
                Player = 1,
                Killer = 2,
                Visuals = 3,
                Movement = 4,
                Misc = 5,
            }

            local pa =
                preferred[a]
                or 100

            local pb =
                preferred[b]
                or 100

            if pa == pb then
                return a < b
            end

            return pa < pb

        end
    )

    return categories
end


function FeatureRegistry:GetCategoryCounts()

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record then

            local category =
                record.Category

            result[category] =
                (result[category] or 0) + 1

        end
    end

    return result
end




-- SEARCH


function FeatureRegistry:Search(
    query,
    category
)

    query =
        tostring(
            query
            or ""
        )

    query =
        string.lower(query)

    if category then
        category =
            NormalizeCategory(category)
    end

    local result = {}

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record then

            local categoryMatch =
                not category
                or record.Category ==
                    category

            if categoryMatch then

                local searchable =
                    string.lower(
                        table.concat(
                            {
                                record.Name,
                                record.DisplayName,
                                record.Description,
                                record.Category,
                            },
                            " "
                        )
                    )

                if query == ""
                    or string.find(
                        searchable,
                        query,
                        1,
                        true
                    ) then

                    table.insert(
                        result,
                        record
                    )

                end
            end
        end
    end

    return result
end




-- METADATA


function FeatureRegistry:GetMetadata(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return CopyTable(
        record.Metadata
    )
end


function FeatureRegistry:SetMetadata(
    name,
    metadata
)

    local record =
        self.Items[name]

    if not record
        or type(metadata) ~= "table" then

        return false
    end

    record.Metadata =
        CopyTable(metadata)

    return true
end


function FeatureRegistry:SetMetadataValue(
    name,
    key,
    value
)

    local record =
        self.Items[name]

    if not record then
        return false
    end

    if type(key) ~= "string"
        or key == "" then

        return false
    end

    record.Metadata[key] =
        value

    return true
end


function FeatureRegistry:GetMetadataValue(
    name,
    key,
    fallback
)

    local record =
        self.Items[name]

    if not record then
        return fallback
    end

    local value =
        record.Metadata[key]

    if value == nil then
        return fallback
    end

    return value
end




-- STATUS


function FeatureRegistry:GetStatus(name)

    local record =
        self.Items[name]

    if not record then
        return nil
    end

    return {
        Name =
            record.Name,

        DisplayName =
            record.DisplayName,

        Description =
            record.Description,

        Icon =
            record.Icon,

        Enabled =
            record.Enabled,

        Initialized =
            record.Initialized,

        Status =
            record.Status,

        Error =
            record.Error,

        Category =
            record.Category,

        Priority =
            record.Priority,

        AutoStart =
            record.AutoStart,

        Dependencies =
            CopyTable(
                record.Dependencies
            ),
    }
end


function FeatureRegistry:GetStatuses()

    local statuses = {}

    for _, name in ipairs(
        self.Order
    ) do

        statuses[name] =
            self:GetStatus(name)

    end

    return statuses
end


function FeatureRegistry:GetSnapshot()

    return {
        Initialized =
            self.Initialized,

        Count =
            self:Count(),

        Names =
            self:GetNames(),

        Enabled =
            self:GetEnabledNames(),

        Categories =
            self:GetCategories(),

        CategoryCounts =
            self:GetCategoryCounts(),

        Statuses =
            self:GetStatuses(),
    }
end




-- UI DATA


function FeatureRegistry:GetUIData(
    category
)

    local result = {}

    local categories

    if category then
        categories = {
            NormalizeCategory(category)
        }
    else
        categories =
            self:GetCategories()
    end


    for _, categoryName in ipairs(
        categories
    ) do

        local features = {}

        for _, name in ipairs(
            self.Order
        ) do

            local record =
                self.Items[name]

            if record
                and record.Category ==
                    categoryName then

                table.insert(
                    features,
                    {
                        Name =
                            record.Name,

                        DisplayName =
                            record.DisplayName,

                        Description =
                            record.Description,

                        Icon =
                            record.Icon,

                        Category =
                            record.Category,

                        Enabled =
                            record.Enabled,

                        Initialized =
                            record.Initialized,

                        Status =
                            record.Status,

                        Error =
                            record.Error,

                        Priority =
                            record.Priority,

                        Module =
                            record.Module,
                    }
                )

            end
        end

        result[categoryName] =
            features
    end

    return result
end




-- MANAGER SYNCHRONIZATION


function FeatureRegistry:Sync(
    name,
    data
)

    local record =
        self.Items[name]

    if not record
        or type(data) ~= "table" then

        return false
    end


    if data.Enabled ~= nil then

        record.Enabled =
            data.Enabled == true

    end


    if data.Initialized ~= nil then

        record.Initialized =
            data.Initialized == true

    end


    if data.Status ~= nil then

        record.Status =
            data.Status

    end


    if data.Error ~= nil then

        record.Error =
            data.Error

    end


    return true
end


function FeatureRegistry:SyncFromManager(
    manager
)

    if not manager
        or type(manager.GetRecord) ~=
            "function" then

        return false
    end


    for _, name in ipairs(
        self.Order
    ) do

        local managerRecord =
            manager:GetRecord(name)

        if managerRecord then

            self:Sync(
                name,
                {
                    Enabled =
                        managerRecord.Enabled,

                    Initialized =
                        managerRecord.Initialized,

                    Status =
                        managerRecord.Status,

                    Error =
                        managerRecord.Error,
                }
            )

        end
    end

    return true
end




-- FEATURE INITIALIZATION


function FeatureRegistry:InitializeFeature(
    name
)

    local record =
        self.Items[name]

    if not record then

        return false,
            "Feature not found"
    end


    if not record.Enabled then

        record.Status =
            "Disabled"

        return false,
            "Feature disabled"
    end


    if record.Initialized then
        return true
    end


    local module =
        record.Module

    local initialize =
        GetFunction(
            module,
            {
                "Initialize",
                "Init",
            }
        )


    if initialize then

        local success, result =
            pcall(function()

                return initialize(
                    module
                )

            end)


        if not success then

            record.Status =
                "Error"

            record.Error =
                result

            record.Initialized =
                false

            return false,
                result
        end


        if result == false then

            record.Status =
                "Error"

            record.Error =
                "Feature rejected initialization"

            record.Initialized =
                false

            return false,
                record.Error
        end
    end


    record.Initialized =
        true

    record.Status =
        "Initialized"

    record.Error =
        nil

    return true
end


function FeatureRegistry:Initialize(
    name
)

    if name then

        return self:InitializeFeature(
            name
        )

    end

    self.Initialized = true

    return self
end


function FeatureRegistry:InitializeAll()

    local results = {}

    self.Initialized = true


    if self.Settings.SortByPriority then
        self:SortOrder()
    end


    for _, name in ipairs(
        self.Order
    ) do

        local success, errorMessage =
            self:InitializeFeature(
                name
            )

        results[name] = {
            Success =
                success,

            Error =
                errorMessage,
        }

    end


    return results
end




-- SHUTDOWN


function FeatureRegistry:Shutdown(name)

    local record =
        self.Items[name]

    if not record then

        return false,
            "Feature not found"
    end


    if not record.Initialized then
        return true
    end


    local module =
        record.Module

    local shutdown =
        GetFunction(
            module,
            {
                "Shutdown",
                "Destroy",
            }
        )


    if shutdown then

        local success, result =
            pcall(function()

                return shutdown(
                    module
                )

            end)


        if not success then

            record.Status =
                "Error"

            record.Error =
                result

            return false,
                result
        end
    end


    record.Initialized =
        false


    if record.Enabled then

        record.Status =
            "Registered"

    else

        record.Status =
            "Disabled"

    end


    record.Error =
        nil


    return true
end


function FeatureRegistry:ShutdownAll()

    local results = {}


    for index =
        #self.Order,
        1,
        -1 do

        local name =
            self.Order[index]

        local success, errorMessage =
            self:Shutdown(name)

        results[name] = {
            Success =
                success,

            Error =
                errorMessage,
        }

    end


    self.Initialized =
        false


    return results
end




-- CLEAR


function FeatureRegistry:Clear()

    self:ShutdownAll()

    table.clear(
        self.Items
    )

    table.clear(
        self.Order
    )

    self.Initialized =
        false

    return true
end




-- DEBUG


function FeatureRegistry:PrintSummary()

    print(
        "[Lua Test] ==============================="
    )

    print(
        "[Lua Test] Feature Registry"
    )

    print(
        "[Lua Test] Count:",
        self:Count()
    )

    print(
        "[Lua Test] Categories:"
    )


    local counts =
        self:GetCategoryCounts()

    for _, category in ipairs(
        self:GetCategories()
    ) do

        print(
            "[Lua Test]  -",
            category,
            counts[category] or 0
        )

    end


    print(
        "[Lua Test] Features:"
    )


    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Items[name]

        if record then

            print(
                "[Lua Test]  -",
                record.DisplayName,
                "|",
                record.Category,
                "|",
                record.Status
            )

        end
    end


    print(
        "[Lua Test] ==============================="
    )

    return true
end



return FeatureRegistry