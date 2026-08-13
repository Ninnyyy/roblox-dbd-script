--[[
    Lua Test Script
    FeatureManager.lua

    Central feature lifecycle manager.

    Responsibilities:
        - Register features
        - Initialize features
        - Start / stop features
        - Enable / disable individual features
        - Toggle individual features
        - Query feature state
        - Bulk enable / disable
        - Safe error handling
        - Cleanup
        - Feature dependency support
]]

local FeatureManager = {
    Name = "FeatureManager",

    Initialized = false,
    Running = false,

    Config = nil,
    Connections = nil,
    Cleanup = nil,

    Features = {},
    Order = {},

    Settings = {
        AutoStart = false,
        SafeMode = true,
    },
}


--========================================================--
-- Helpers
--========================================================--

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
            "[Lua Test] FeatureManager error:",
            result
        )

        return false, result
    end

    return true, result
end


local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    return name
end


--========================================================--
-- Registration
--========================================================--

function FeatureManager:Register(
    name,
    feature,
    options
)
    name = NormalizeName(name)

    if not name then
        return false
    end

    if type(feature) ~= "table" then
        return false
    end

    options = options or {}

    if self.Features[name] then
        self:Unregister(name)
    end

    self.Features[name] = {
        Name = name,
        Module = feature,

        Enabled = false,
        Initialized = false,

        Dependencies =
            options.Dependencies or {},

        AutoStart =
            options.AutoStart == true,

        Priority =
            tonumber(
                options.Priority
            ) or 0,
    }

    table.insert(
        self.Order,
        name
    )

    self:SortOrder()

    return true
end


function FeatureManager:Unregister(name)
    name = NormalizeName(name)

    if not name then
        return false
    end

    local record =
        self.Features[name]

    if not record then
        return false
    end

    self:Disable(name)

    SafeCall(function()
        if type(record.Module.Destroy) ==
            "function" then

            record.Module:Destroy()
        end
    end)

    self.Features[name] = nil

    for index, value in ipairs(
        self.Order
    ) do
        if value == name then
            table.remove(
                self.Order,
                index
            )

            break
        end
    end

    return true
end


function FeatureManager:SortOrder()
    table.sort(
        self.Order,
        function(a, b)
            local featureA =
                self.Features[a]

            local featureB =
                self.Features[b]

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
end


--========================================================--
-- Queries
--========================================================--

function FeatureManager:Get(name)
    local record =
        self.Features[name]

    if not record then
        return nil
    end

    return record.Module
end


function FeatureManager:GetRecord(name)
    return self.Features[name]
end


function FeatureManager:Has(name)
    return self.Features[name] ~= nil
end


function FeatureManager:IsEnabled(name)
    local record =
        self.Features[name]

    if not record then
        return false
    end

    return record.Enabled == true
end


function FeatureManager:IsInitialized(name)
    local record =
        self.Features[name]

    if not record then
        return false
    end

    return record.Initialized == true
end


function FeatureManager:GetNames()
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


function FeatureManager:GetEnabled()
    local enabled = {}

    for _, name in ipairs(
        self.Order
    ) do
        local record =
            self.Features[name]

        if record
            and record.Enabled then

            table.insert(
                enabled,
                name
            )
        end
    end

    return enabled
end


--========================================================--
-- Dependencies
--========================================================--

function FeatureManager:DependenciesReady(
    record
)
    if not record then
        return false
    end

    for _, dependency in ipairs(
        record.Dependencies
    ) do
        local dependencyRecord =
            self.Features[dependency]

        if not dependencyRecord then
            warn(
                "[Lua Test] Missing feature dependency:",
                record.Name,
                dependency
            )

            return false
        end

        if not dependencyRecord.Initialized then
            local success =
                self:Initialize(
                    dependency
                )

            if not success then
                return false
            end
        end
    end

    return true
end


--========================================================--
-- Initialization
--========================================================--

function FeatureManager:Initialize(
    name
)
    local record =
        self.Features[name]

    if not record then
        return false
    end

    if record.Initialized then
        return true
    end

    if not self:DependenciesReady(
        record
    ) then
        return false
    end

    local module =
        record.Module

    if type(module.Initialize) ==
        "function" then

        local success =
            SafeCall(
                function()
                    return module:Initialize({
                        Config =
                            self.Config,

                        Connections =
                            self.Connections,

                        Cleanup =
                            self.Cleanup,

                        FeatureManager =
                            self,
                    })
                end
            )

        if not success then
            return false
        end
    end

    record.Initialized = true

    return true
end


function FeatureManager:InitializeAll()
    local success = true

    for _, name in ipairs(
        self.Order
    ) do
        if not self:Initialize(name) then
            success = false

            if self.Settings.SafeMode then
                warn(
                    "[Lua Test] Failed to initialize:",
                    name
                )
            end
        end
    end

    return success
end


--========================================================--
-- Enable / Disable
--========================================================--

function FeatureManager:Enable(name)
    local record =
        self.Features[name]

    if not record then
        return false
    end

    if record.Enabled then
        return true
    end

    if not record.Initialized then
        if not self:Initialize(name) then
            return false
        end
    end

    local module =
        record.Module

    if type(module.SetEnabled) ==
        "function" then

        local success, result =
            SafeCall(
                function()
                    return module:SetEnabled(
                        true
                    )
                end
            )

        if not success then
            return false
        end

        record.Enabled =
            result ~= false

        return record.Enabled
    end

    if type(module.Start) ==
        "function" then

        local success =
            SafeCall(function()
                module:Start()
            end)

        if not success then
            return false
        end

        record.Enabled = true

        return true
    end

    record.Enabled = true

    return true
end


function FeatureManager:Disable(name)
    local record =
        self.Features[name]

    if not record then
        return false
    end

    if not record.Enabled then
        return true
    end

    local module =
        record.Module

    if type(module.SetEnabled) ==
        "function" then

        local success =
            SafeCall(function()
                module:SetEnabled(
                    false
                )
            end)

        if not success then
            return false
        end

        record.Enabled = false

        return true
    end

    if type(module.Stop) ==
        "function" then

        local success =
            SafeCall(function()
                module:Stop()
            end)

        if not success then
            return false
        end
    end

    record.Enabled = false

    return true
end


function FeatureManager:Toggle(name)
    if self:IsEnabled(name) then
        return self:Disable(name)
    end

    return self:Enable(name)
end


--========================================================--
-- Bulk controls
--========================================================--

function FeatureManager:EnableAll()
    local success = true

    for _, name in ipairs(
        self.Order
    ) do
        local record =
            self.Features[name]

        if record then
            if not self:Enable(name) then
                success = false

                if self.Settings.SafeMode then
                    warn(
                        "[Lua Test] Failed to enable:",
                        name
                    )
                end
            end
        end
    end

    return success
end


function FeatureManager:DisableAll()
    local success = true

    for index =
        #self.Order,
        1,
        -1 do

        local name =
            self.Order[index]

        if not self:Disable(name) then
            success = false
        end
    end

    return success
end


--========================================================--
-- Runtime
--========================================================--

function FeatureManager:Start()
    if self.Running then
        return true
    end

    self.Running = true

    if not self:InitializeAll() then
        if self.Settings.SafeMode then
            warn(
                "[Lua Test] Some features failed initialization."
            )
        end
    end

    for _, name in ipairs(
        self.Order
    ) do
        local record =
            self.Features[name]

        if record
            and record.AutoStart then

            self:Enable(name)
        end
    end

    return true
end


function FeatureManager:Stop()
    if not self.Running then
        return true
    end

    self:DisableAll()

    self.Running = false

    return true
end


--========================================================--
-- Settings
--========================================================--

function FeatureManager:GetSetting(
    name,
    default
)
    if self.Settings[name] ~= nil then
        return self.Settings[name]
    end

    if self.Config
        and type(self.Config.Get) ==
            "function" then

        local success, value =
            pcall(function()
                return self.Config:Get(
                    "FeatureManager."
                        .. name,
                    default
                )
            end)

        if success then
            return value
        end
    end

    return default
end


function FeatureManager:SetSetting(
    name,
    value
)
    if self.Settings[name] == nil then
        return false
    end

    self.Settings[name] = value

    return true
end


--========================================================--
-- Initialize manager
--========================================================--

function FeatureManager:Setup(
    modules
)
    if self.Initialized then
        return self
    end

    modules =
        modules or {}

    self.Config =
        modules.Config

    self.Connections =
        modules.Connections

    self.Cleanup =
        modules.Cleanup

    self.Initialized = true

    return self
end


--========================================================--
-- Cleanup
--========================================================--

function FeatureManager:Destroy()
    self:Stop()

    for index =
        #self.Order,
        1,
        -1 do

        local name =
            self.Order[index]

        local record =
            self.Features[name]

        if record then
            SafeCall(function()
                if type(
                    record.Module.Destroy
                ) == "function" then

                    record.Module:Destroy()
                end
            end)
        end
    end

    self.Features = {}
    self.Order = {}

    self.Config = nil
    self.Connections = nil
    self.Cleanup = nil

    self.Running = false
    self.Initialized = false
end


return FeatureManager