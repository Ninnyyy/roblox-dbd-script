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
            - Provide status snapshots
            - Support manager synchronization
    ]]

    local FeatureRegistry = {
        Name = "FeatureRegistry",

        Items = {},
        Order = {},

        Initialized = false,

        Settings = {
            AllowDuplicate = false,
            SortByPriority = true,
        },
    }



    -- Helpers


    local function NormalizeName(name)
        if type(name) ~= "string" then
            return nil
        end

        if name == "" then
            return nil
        end

        return name
    end


    local function NormalizeCategory(category)
        if type(category) ~= "string"
            or category == "" then

            return "General"
        end

        return category
    end


    local function NormalizeDependencies(
        dependencies
    )
        if type(dependencies) ~= "table" then
            return {}
        end

        local result = {}

        for _, dependency in ipairs(
            dependencies
        ) do

            if type(dependency) == "string"
                and dependency ~= "" then

                table.insert(
                    result,
                    dependency
                )
            end
        end

        return result
    end



    -- Initialize


    function FeatureRegistry:Initialize()
        if self.Initialized then
            return self
        end

        self.Items = self.Items or {}
        self.Order = self.Order or {}

        self.Initialized = true

        return self
    end



    -- Registration


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
            options or {}

        if self.Items[name]
            and not self.Settings.AllowDuplicate then

            return false,
                "Feature already registered"
        end

        -- If replacing an existing entry,
        -- remove it from ordering first.
        if self.Items[name] then
            self:Remove(name)
        end

        local record = {
            Name = name,

            Module = feature,

            Enabled = false,
            Initialized = false,

            Status = "Registered",
            Error = nil,

            Category =
                NormalizeCategory(
                    options.Category
                    or feature.Category
                ),

            Priority =
                tonumber(
                    options.Priority
                    or feature.Priority
                ) or 0,

            AutoStart =
                options.AutoStart == true,

            Dependencies =
                NormalizeDependencies(
                    options.Dependencies
                    or feature.Dependencies
                ),

            Metadata =
                options.Metadata
                or feature.Metadata
                or {},
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



    -- Unregister


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

            if self.Order[index] ==
                name then

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



    -- Ordering


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



    -- Queries


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
        return self.Order
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



    -- Enabled State


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



    -- Initialization State


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
            record.Status = "Initialized"
        elseif record.Enabled then
            record.Status = "Registered"
        else
            record.Status = "Disabled"
        end

        return true
    end


    function FeatureRegistry:IsInitialized(
        name
    )
        local record =
            self.Items[name]

        if not record then
            return false
        end

        return record.Initialized == true
    end



    -- Runtime Status


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
            status or "Unknown"

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

        record.Status = "Error"
        record.Error = errorMessage

        return true
    end


    function FeatureRegistry:ClearError(
        name
    )
        local record =
            self.Items[name]

        if not record then
            return false
        end

        record.Error = nil

        return true
    end



    -- Dependencies


    function FeatureRegistry:GetDependencies(
        name
    )
        local record =
            self.Items[name]

        if not record then
            return nil
        end

        return record.Dependencies
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

        for _, value in ipairs(
            record.Dependencies
        ) do

            if value == dependency then
                return true
            end
        end

        return false
    end


    function FeatureRegistry:GetDependents(
        name
    )
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



    -- Categories


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

        table.sort(categories)

        return categories
    end



    -- Metadata


    function FeatureRegistry:GetMetadata(
        name
    )
        local record =
            self.Items[name]

        if not record then
            return nil
        end

        return record.Metadata
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
            metadata

        return true
    end



    -- Status


    function FeatureRegistry:GetStatus(
        name
    )
        local record =
            self.Items[name]

        if not record then
            return nil
        end

        return {
            Name = record.Name,

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
                record.Dependencies,
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
        local snapshot = {
            Initialized =
                self.Initialized,

            Count =
                self:Count(),

            Names =
                self:GetNames(),

            Enabled =
                self:GetEnabledNames(),

            Statuses =
                self:GetStatuses(),
        }

        return snapshot
    end



    -- Manager Synchronization


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



    -- Legacy Initialization API


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
            record.Status = "Disabled"

            return false,
                "Feature disabled"
        end

        if record.Initialized then
            return true
        end

        local module =
            record.Module

        local initialize =
            module.Initialize
            or module.Init

        if type(initialize) ==
            "function" then

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
        return self:InitializeFeature(
            name
        )
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
                Success = success,
                Error = errorMessage,
            }
        end

        return results
    end



    -- Shutdown


    function FeatureRegistry:Shutdown(
        name
    )
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
            module.Shutdown
            or module.Destroy

        if type(shutdown) ==
            "function" then

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
                Success = success,
                Error = errorMessage,
            }
        end

        self.Initialized = false

        return results
    end



    -- Clear


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


    return FeatureRegistry