--[[
    Lua Test Script
    FeatureManager.lua

    Central feature lifecycle manager.

    Version:
        3.0.0

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
        - Dependency cycle protection
        - Priority ordering
        - Runtime status tracking
        - Registry compatibility
        - Feature restart support
        - Complete module context
        - Logger integration
        - Signal integration
        - Lifecycle events
        - Feature statistics
        - Dependency diagnostics
]]


local FeatureManager = {
    Name = "FeatureManager",
    Version = "3.0.0",

    Initialized = false,
    Running = false,

    Config = nil,
    Connections = nil,
    Cleanup = nil,
    Registry = nil,

    Logger = nil,
    SignalModule = nil,

    Modules = {},

    Features = {},
    Order = {},

    Signals = {},

    Runtime = {
        StartedAt = nil,
        StoppedAt = nil,

        StartCount = 0,
        StopCount = 0,

        InitializeCount = 0,
        EnableCount = 0,
        DisableCount = 0,
        RestartCount = 0,

        ErrorCount = 0,
        DependencyErrors = 0,
    },

    Settings = {
        AutoStart = false,
        SafeMode = true,
        StopDependents = true,

        LogLifecycle = true,
        EmitSignals = true,
    },
}




-- Helpers



local function SafeToString(value)
    if value == nil then
        return "nil"
    end

    local success, result =
        pcall(
            tostring,
            value
        )

    if success then
        return result
    end

    return "<unprintable>"
end


local function GetClock()
    local success, result =
        pcall(
            os.clock
        )

    if success then
        return result
    end

    return 0
end


local function NormalizeName(name)
    if type(name) ~= "string" then
        return nil
    end

    if name == "" then
        return nil
    end

    return name
end


local function SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return true, nil
    end

    local success, result =
        pcall(
            callback,
            ...
        )

    if not success then
        return false, result
    end

    return true, result
end




-- Logging



function FeatureManager:_Log(
    level,
    message,
    ...
)
    if not self.Settings.LogLifecycle then
        return
    end

    if not self.Logger then
        return
    end

    local loggerMethod =
        self.Logger[level]

    if type(loggerMethod) ~= "function" then
        return
    end

    pcall(function()
        loggerMethod(
            self.Logger,
            self.Name,
            message,
            ...
        )
    end)
end


function FeatureManager:_LogDebug(
    message,
    ...
)
    self:_Log(
        "Debug",
        message,
        ...
    )
end


function FeatureManager:_LogInfo(
    message,
    ...
)
    self:_Log(
        "Info",
        message,
        ...
    )
end


function FeatureManager:_LogSuccess(
    message,
    ...
)
    self:_Log(
        "Success",
        message,
        ...
    )
end


function FeatureManager:_LogWarn(
    message,
    ...
)
    self:_Log(
        "Warn",
        message,
        ...
    )
end


function FeatureManager:_LogError(
    message,
    ...
)
    self:_Log(
        "Error",
        message,
        ...
    )
end




-- Signals



local function CreateSignal(signalModule)
    if not signalModule then
        return nil
    end

    local constructors = {
        "new",
        "New",
        "Create",
        "create",
    }

    for _, constructorName in ipairs(
        constructors
    ) do
        local constructor =
            signalModule[constructorName]

        if type(constructor) == "function" then

            local success, signal =
                pcall(
                    constructor,
                    signalModule
                )

            if success
                and signal then

                return signal
            end

            success, signal =
                pcall(
                    constructor
                )

            if success
                and signal then

                return signal
            end
        end
    end

    return nil
end


function FeatureManager:_CreateSignals()
    self.Signals = {}

    if not self.Settings.EmitSignals then
        return
    end

    if not self.SignalModule then
        return
    end

    local names = {
        "Registered",
        "Unregistered",

        "Initializing",
        "Initialized",

        "Enabling",
        "Enabled",

        "Disabling",
        "Disabled",

        "Starting",
        "Started",

        "Stopping",
        "Stopped",

        "Restarting",
        "Restarted",

        "DependencyError",
        "Error",

        "Changed",
    }

    for _, name in ipairs(names) do
        local signal =
            CreateSignal(
                self.SignalModule
            )

        if signal then
            self.Signals[name] =
                signal
        end
    end
end


function FeatureManager:_FireSignal(
    name,
    ...
)
    if not self.Settings.EmitSignals then
        return false
    end

    local signal =
        self.Signals[name]

    if not signal then
        return false
    end

    local fireMethods = {
        "Fire",
        "fire",
        "Emit",
        "emit",
        "Dispatch",
        "dispatch",
    }

    for _, methodName in ipairs(
        fireMethods
    ) do

        local method =
            signal[methodName]

        if type(method) == "function" then

            local success =
                pcall(
                    method,
                    signal,
                    ...
                )

            if success then
                return true
            end

            success =
                pcall(
                    method,
                    ...
                )

            if success then
                return true
            end
        end
    end

    return false
end


function FeatureManager:_DestroySignals()
    for _, signal in pairs(
        self.Signals
    ) do

        if signal then

            local destroy =
                signal.Destroy
                or signal.destroy

            if type(destroy) == "function" then
                pcall(
                    destroy,
                    signal
                )
            end
        end
    end

    self.Signals = {}
end




-- Feature Statistics



local function CreateFeatureStats()
    return {
        RegisteredAt = GetClock(),

        InitializedAt = nil,
        EnabledAt = nil,
        DisabledAt = nil,
        DestroyedAt = nil,

        InitializeCount = 0,
        EnableCount = 0,
        DisableCount = 0,
        RestartCount = 0,

        ErrorCount = 0,
        DependencyErrorCount = 0,

        LastError = nil,
        LastAction = "Registered",
        LastActionAt = GetClock(),
    }
end


function FeatureManager:_Touch(
    record,
    action
)
    if not record
        or not record.Stats then

        return
    end

    record.Stats.LastAction =
        action

    record.Stats.LastActionAt =
        GetClock()
end


function FeatureManager:_RecordError(
    record,
    message,
    dependencyError
)
    self.Runtime.ErrorCount += 1

    if dependencyError then
        self.Runtime.DependencyErrors += 1
    end

    if record then
        record.Error = message

        if record.Stats then
            record.Stats.ErrorCount += 1
            record.Stats.LastError = message

            if dependencyError then
                record.Stats.DependencyErrorCount += 1
            end
        end
    end
end




-- Registration



function FeatureManager:Register(
    name,
    feature,
    options
)
    name =
        NormalizeName(name)

    if not name then
        return false,
            "Invalid feature name"
    end

    if type(feature) ~= "table" then
        return false,
            "Feature must be a table"
    end

    options =
        options or {}

    if type(options) ~= "table" then
        options = {}
    end

    if self.Features[name] then
        self:Unregister(name)
    end

    local dependencies =
        options.Dependencies
        or {}

    if type(dependencies) ~= "table" then
        dependencies = {}
    end

    self.Features[name] = {
        Name = name,
        Module = feature,

        Enabled = false,
        Initialized = false,

        Status = "Registered",
        Error = nil,

        Dependencies = dependencies,

        AutoStart =
            options.AutoStart == true,

        Priority =
            tonumber(
                options.Priority
            ) or 0,

        Stats =
            CreateFeatureStats(),
    }

    table.insert(
        self.Order,
        name
    )

    self:SortOrder()

    if self.Registry
        and type(
            self.Registry.Register
        ) == "function" then

        pcall(function()
            self.Registry:Register(
                name,
                feature
            )
        end)
    end

    self:_LogInfo(
        "Registered feature:",
        name
    )

    self:_FireSignal(
        "Registered",
        name,
        self.Features[name]
    )

    self:_FireSignal(
        "Changed",
        name,
        "Registered"
    )

    return true
end


function FeatureManager:Unregister(
    name
)
    name =
        NormalizeName(name)

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
        if type(
            record.Module.Destroy
        ) == "function" then

            record.Module:Destroy()
        end
    end)

    if record.Stats then
        record.Stats.DestroyedAt =
            GetClock()

        record.Stats.LastAction =
            "Unregistered"
    end

    self.Features[name] = nil

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

    if self.Registry
        and type(
            self.Registry.Remove
        ) == "function" then

        pcall(function()
            self.Registry:Remove(name)
        end)
    end

    self:_LogInfo(
        "Unregistered feature:",
        name
    )

    self:_FireSignal(
        "Unregistered",
        name,
        record
    )

    self:_FireSignal(
        "Changed",
        name,
        "Unregistered"
    )

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




-- Context



function FeatureManager:SetModules(
    modules
)
    if type(modules) ~= "table" then
        return false
    end

    self.Modules = modules

    return true
end


function FeatureManager:GetModules()
    return self.Modules
end


function FeatureManager:GetModule(name)
    if type(name) ~= "string" then
        return nil
    end

    return self.Modules[name]
end


function FeatureManager:GetContext()
    return {
        Config = self.Config,
        Connections = self.Connections,
        Cleanup = self.Cleanup,

        Logger = self.Logger,
        Signal = self.SignalModule,

        FeatureManager = self,

        Modules = self.Modules,
    }
end




-- Queries



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


function FeatureManager:GetStatus(name)
    local record =
        self.Features[name]

    if not record then
        return nil
    end

    return {
        Name =
            record.Name,

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

        AutoStart =
            record.AutoStart,

        Dependencies =
            record.Dependencies,

        Stats =
            record.Stats,
    }
end


function FeatureManager:GetStatuses()
    local statuses = {}

    for _, name in ipairs(
        self.Order
    ) do

        statuses[name] =
            self:GetStatus(name)
    end

    return statuses
end


function FeatureManager:GetFeatureStats(name)
    local record =
        self.Features[name]

    if not record then
        return nil
    end

    return record.Stats
end


function FeatureManager:Count()
    local count = 0

    for _ in pairs(
        self.Features
    ) do
        count += 1
    end

    return count
end




-- Dependency System



function FeatureManager:DependenciesReady(
    record,
    stack
)
    if not record then
        return false
    end

    stack =
        stack or {}

    if stack[record.Name] then

        local message =
            "Circular dependency detected"

        record.Status =
            "DependencyError"

        self:_RecordError(
            record,
            message,
            true
        )

        self:_LogError(
            "Circular feature dependency:",
            record.Name
        )

        self:_FireSignal(
            "DependencyError",
            record.Name,
            message
        )

        return false
    end

    stack[record.Name] = true

    for _, dependency in ipairs(
        record.Dependencies
    ) do

        local dependencyRecord =
            self.Features[dependency]

        if not dependencyRecord then

            local message =
                "Missing dependency: "
                .. SafeToString(
                    dependency
                )

            record.Status =
                "DependencyError"

            self:_RecordError(
                record,
                message,
                true
            )

            self:_LogError(
                "Missing feature dependency:",
                record.Name,
                dependency
            )

            self:_FireSignal(
                "DependencyError",
                record.Name,
                dependency,
                message
            )

            stack[record.Name] = nil

            return false
        end

        if not dependencyRecord.Initialized then

            local success =
                self:Initialize(
                    dependency,
                    stack
                )

            if not success then

                local message =
                    "Dependency failed: "
                    .. SafeToString(
                        dependency
                    )

                record.Status =
                    "DependencyError"

                self:_RecordError(
                    record,
                    message,
                    true
                )

                self:_FireSignal(
                    "DependencyError",
                    record.Name,
                    dependency,
                    message
                )

                stack[record.Name] = nil

                return false
            end
        end
    end

    stack[record.Name] = nil

    return true
end


function FeatureManager:GetDependents(
    name
)
    local dependents = {}

    for _, featureName in ipairs(
        self.Order
    ) do

        local record =
            self.Features[featureName]

        if record then

            for _, dependency in ipairs(
                record.Dependencies
            ) do

                if dependency == name then

                    table.insert(
                        dependents,
                        featureName
                    )

                    break
                end
            end
        end
    end

    return dependents
end


function FeatureManager:GetDependencyTree(
    name,
    visited
)
    local record =
        self.Features[name]

    if not record then
        return nil
    end

    visited =
        visited or {}

    if visited[name] then
        return {
            Name = name,
            Circular = true,
        }
    end

    visited[name] = true

    local result = {
        Name = name,

        Enabled =
            record.Enabled,

        Initialized =
            record.Initialized,

        Status =
            record.Status,

        Dependencies = {},
    }

    for _, dependency in ipairs(
        record.Dependencies
    ) do

        local child =
            self:GetDependencyTree(
                dependency,
                visited
            )

        if child then
            table.insert(
                result.Dependencies,
                child
            )
        else
            table.insert(
                result.Dependencies,
                {
                    Name = dependency,
                    Missing = true,
                }
            )
        end
    end

    visited[name] = nil

    return result
end




-- Initialization



function FeatureManager:Initialize(
    name,
    dependencyStack
)
    local record =
        self.Features[name]

    if not record then
        return false,
            "Feature not found"
    end

    if record.Initialized then
        return true
    end

    record.Status =
        "Initializing"

    record.Error = nil

    self:_Touch(
        record,
        "Initializing"
    )

    self:_FireSignal(
        "Initializing",
        name,
        record
    )

    if not self:DependenciesReady(
        record,
        dependencyStack
    ) then

        if record.Status ==
            "Initializing" then

            record.Status =
                "DependencyError"
        end

        return false,
            record.Error
    end

    local module =
        record.Module

    if type(module.Initialize) ==
        "function" then

        local context =
            self:GetContext()

        local success, result =
            SafeCall(
                function()
                    return module:Initialize(
                        context
                    )
                end
            )

        if not success then

            record.Status =
                "Error"

            record.Initialized =
                false

            self:_RecordError(
                record,
                result,
                false
            )

            self:_LogError(
                "Failed to initialize feature:",
                name,
                result
            )

            self:_FireSignal(
                "Error",
                name,
                "Initialize",
                result
            )

            return false,
                result
        end

        if result == false then

            local message =
                "Feature rejected initialization"

            record.Status =
                "Error"

            record.Initialized =
                false

            self:_RecordError(
                record,
                message,
                false
            )

            self:_LogError(
                "Feature rejected initialization:",
                name
            )

            self:_FireSignal(
                "Error",
                name,
                "Initialize",
                message
            )

            return false,
                message
        end
    end

    record.Initialized =
        true

    record.Status =
        "Initialized"

    record.Error =
        nil

    if record.Stats then
        record.Stats.InitializeCount += 1
        record.Stats.InitializedAt =
            GetClock()
    end

    self.Runtime.InitializeCount += 1

    self:_Touch(
        record,
        "Initialized"
    )

    self:_LogSuccess(
        "Initialized feature:",
        name
    )

    self:_FireSignal(
        "Initialized",
        name,
        record
    )

    self:_FireSignal(
        "Changed",
        name,
        "Initialized"
    )

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

                self:_LogWarn(
                    "Failed to initialize:",
                    name
                )
            end
        end
    end

    return success
end




-- Enable / Disable



function FeatureManager:Enable(name)
    local record =
        self.Features[name]

    if not record then
        return false,
            "Feature not found"
    end

    if record.Enabled then
        return true
    end

    if not record.Initialized then

        local initialized =
            self:Initialize(name)

        if not initialized then
            return false,
                record.Error
        end
    end

    local module =
        record.Module

    record.Status =
        "Enabling"

    record.Error =
        nil

    self:_Touch(
        record,
        "Enabling"
    )

    self:_FireSignal(
        "Enabling",
        name,
        record
    )

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

            record.Status =
                "Error"

            self:_RecordError(
                record,
                result,
                false
            )

            self:_LogError(
                "Failed to enable feature:",
                name,
                result
            )

            self:_FireSignal(
                "Error",
                name,
                "Enable",
                result
            )

            return false,
                result
        end

        if result == false then

            local message =
                "Feature rejected enable request"

            record.Status =
                "Disabled"

            self:_RecordError(
                record,
                message,
                false
            )

            self:_LogWarn(
                "Feature rejected enable request:",
                name
            )

            return false,
                message
        end

    elseif type(module.Start) ==
        "function" then

        local success, result =
            SafeCall(function()
                return module:Start()
            end)

        if not success then

            record.Status =
                "Error"

            self:_RecordError(
                record,
                result,
                false
            )

            self:_LogError(
                "Failed to start feature:",
                name,
                result
            )

            self:_FireSignal(
                "Error",
                name,
                "Start",
                result
            )

            return false,
                result
        end
    end

    record.Enabled =
        true

    record.Status =
        "Enabled"

    record.Error =
        nil

    if record.Stats then
        record.Stats.EnableCount += 1
        record.Stats.EnabledAt =
            GetClock()
    end

    self.Runtime.EnableCount += 1

    self:_Touch(
        record,
        "Enabled"
    )

    self:_LogSuccess(
        "Enabled feature:",
        name
    )

    self:_FireSignal(
        "Enabled",
        name,
        record
    )

    self:_FireSignal(
        "Changed",
        name,
        "Enabled"
    )

    return true
end


function FeatureManager:Disable(name)
    local record =
        self.Features[name]

    if not record then
        return false,
            "Feature not found"
    end

    if not record.Enabled then
        return true
    end

    if self.Settings.StopDependents then

        local dependents =
            self:GetDependents(name)

        for _, dependent in ipairs(
            dependents
        ) do

            if self:IsEnabled(
                dependent
            ) then

                self:Disable(
                    dependent
                )
            end
        end
    end

    local module =
        record.Module

    record.Status =
        "Disabling"

    self:_Touch(
        record,
        "Disabling"
    )

    self:_FireSignal(
        "Disabling",
        name,
        record
    )

    if type(module.SetEnabled) ==
        "function" then

        local success, result =
            SafeCall(function()
                return module:SetEnabled(
                    false
                )
            end)

        if not success then

            record.Status =
                "Error"

            self:_RecordError(
                record,
                result,
                false
            )

            self:_LogError(
                "Failed to disable feature:",
                name,
                result
            )

            self:_FireSignal(
                "Error",
                name,
                "Disable",
                result
            )

            return false,
                result
        end

        if result == false then

            local message =
                "Feature rejected disable request"

            record.Status =
                "Error"

            self:_RecordError(
                record,
                message,
                false
            )

            self:_LogError(
                "Feature rejected disable request:",
                name
            )

            return false,
                message
        end

    elseif type(module.Stop) ==
        "function" then

        local success, result =
            SafeCall(function()
                return module:Stop()
            end)

        if not success then

            record.Status =
                "Error"

            self:_RecordError(
                record,
                result,
                false
            )

            self:_LogError(
                "Failed to stop feature:",
                name,
                result
            )

            self:_FireSignal(
                "Error",
                name,
                "Stop",
                result
            )

            return false,
                result
        end
    end

    record.Enabled =
        false

    record.Status =
        "Initialized"

    record.Error =
        nil

    if record.Stats then
        record.Stats.DisableCount += 1
        record.Stats.DisabledAt =
            GetClock()
    end

    self.Runtime.DisableCount += 1

    self:_Touch(
        record,
        "Disabled"
    )

    self:_LogInfo(
        "Disabled feature:",
        name
    )

    self:_FireSignal(
        "Disabled",
        name,
        record
    )

    self:_FireSignal(
        "Changed",
        name,
        "Disabled"
    )

    return true
end


function FeatureManager:Toggle(name)
    if self:IsEnabled(name) then
        return self:Disable(name)
    end

    return self:Enable(name)
end




-- Restart



function FeatureManager:Restart(name)
    local record =
        self.Features[name]

    if not record then
        return false,
            "Feature not found"
    end

    local wasEnabled =
        record.Enabled

    self:_LogInfo(
        "Restarting feature:",
        name
    )

    self:_FireSignal(
        "Restarting",
        name,
        record
    )

    if record.Enabled then

        if not self:Disable(name) then
            return false
        end
    end

    local module =
        record.Module

    if record.Initialized then

        if type(module.Destroy) ==
            "function" then

            local success, result =
                SafeCall(function()
                    return module:Destroy()
                end)

            if not success then

                self:_RecordError(
                    record,
                    result,
                    false
                )

                self:_FireSignal(
                    "Error",
                    name,
                    "Destroy",
                    result
                )

                return false,
                    result
            end
        end

        record.Initialized =
            false

        record.Status =
            "Registered"

        record.Error =
            nil
    end

    if record.Stats then
        record.Stats.RestartCount += 1
    end

    self.Runtime.RestartCount += 1

    local initialized =
        self:Initialize(name)

    if not initialized then
        return false,
            record.Error
    end

    if wasEnabled then

        local enabled =
            self:Enable(name)

        if not enabled then
            return false,
                record.Error
        end
    end

    self:_LogSuccess(
        "Restarted feature:",
        name
    )

    self:_FireSignal(
        "Restarted",
        name,
        record
    )

    self:_FireSignal(
        "Changed",
        name,
        "Restarted"
    )

    return true
end




-- Bulk Controls



function FeatureManager:EnableAll()
    local success = true

    for _, name in ipairs(
        self.Order
    ) do

        if not self:Enable(name) then

            success = false

            if self.Settings.SafeMode then

                self:_LogWarn(
                    "Failed to enable:",
                    name
                )
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


function FeatureManager:RestartAll()
    local success = true

    for index =
        #self.Order,
        1,
        -1 do

        local name =
            self.Order[index]

        if not self:Restart(name) then

            success = false

            if self.Settings.SafeMode then

                self:_LogWarn(
                    "Failed to restart:",
                    name
                )
            end
        end
    end

    return success
end




-- Runtime



function FeatureManager:Start()
    if self.Running then
        return true
    end

    self.Running =
        true

    self.Runtime.StartedAt =
        GetClock()

    self.Runtime.StartCount += 1

    self:_LogInfo(
        "Starting FeatureManager"
    )

    self:_FireSignal(
        "Starting"
    )

    local initialized =
        self:InitializeAll()

    if not initialized
        and self.Settings.SafeMode then

        self:_LogWarn(
            "Some features failed initialization."
        )
    end

    for _, name in ipairs(
        self.Order
    ) do

        local record =
            self.Features[name]

        if record
            and (
                record.AutoStart
                or self:GetSetting(
                    "AutoStart",
                    false
                )
            ) then

            if not self:Enable(name) then

                if self.Settings.SafeMode then

                    self:_LogWarn(
                        "Failed to auto-start:",
                        name
                    )
                end
            end
        end
    end

    self:_LogSuccess(
        "FeatureManager started"
    )

    self:_FireSignal(
        "Started",
        initialized
    )

    self:_FireSignal(
        "Changed",
        nil,
        "Started"
    )

    return initialized
end


function FeatureManager:Stop()
    if not self.Running then
        return true
    end

    self:_LogInfo(
        "Stopping FeatureManager"
    )

    self:_FireSignal(
        "Stopping"
    )

    local success =
        self:DisableAll()

    self.Running =
        false

    self.Runtime.StoppedAt =
        GetClock()

    self.Runtime.StopCount += 1

    self:_LogSuccess(
        "FeatureManager stopped"
    )

    self:_FireSignal(
        "Stopped",
        success
    )

    self:_FireSignal(
        "Changed",
        nil,
        "Stopped"
    )

    return success
end




-- Settings



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

    self.Settings[name] =
        value

    return true
end




-- Logger / Signal Setup



function FeatureManager:SetLogger(
    logger
)
    self.Logger =
        logger

    return true
end


function FeatureManager:SetSignalModule(
    signalModule
)
    self:_DestroySignals()

    self.SignalModule =
        signalModule

    self:_CreateSignals()

    return true
end




-- Runtime Diagnostics



function FeatureManager:GetRuntimeStatus()
    return {
        Name =
            self.Name,

        Version =
            self.Version,

        Initialized =
            self.Initialized,

        Running =
            self.Running,

        FeatureCount =
            self:Count(),

        EnabledCount =
            #self:GetEnabled(),

        Runtime = {
            StartedAt =
                self.Runtime.StartedAt,

            StoppedAt =
                self.Runtime.StoppedAt,

            StartCount =
                self.Runtime.StartCount,

            StopCount =
                self.Runtime.StopCount,

            InitializeCount =
                self.Runtime.InitializeCount,

            EnableCount =
                self.Runtime.EnableCount,

            DisableCount =
                self.Runtime.DisableCount,

            RestartCount =
                self.Runtime.RestartCount,

            ErrorCount =
                self.Runtime.ErrorCount,

            DependencyErrors =
                self.Runtime.DependencyErrors,
        },

        Settings = {
            AutoStart =
                self.Settings.AutoStart,

            SafeMode =
                self.Settings.SafeMode,

            StopDependents =
                self.Settings.StopDependents,

            LogLifecycle =
                self.Settings.LogLifecycle,

            EmitSignals =
                self.Settings.EmitSignals,
        },
    }
end


function FeatureManager:GetFullStatus()
    return {
        Manager =
            self:GetRuntimeStatus(),

        Features =
            self:GetStatuses(),

        Enabled =
            self:GetEnabled(),

        Order =
            self:GetNames(),
    }
end




-- Setup



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

    self.Registry =
        modules.FeatureRegistry

    self.Logger =
        modules.Logger

    self.SignalModule =
        modules.Signal

    self.Modules =
        modules.Modules
        or modules

    self:_CreateSignals()

    self.Initialized =
        true

    self:_LogSuccess(
        "FeatureManager initialized",
        "Version:",
        self.Version
    )

    return self
end




-- Reset



function FeatureManager:ResetRuntime()
    self.Runtime = {
        StartedAt = nil,
        StoppedAt = nil,

        StartCount = 0,
        StopCount = 0,

        InitializeCount = 0,
        EnableCount = 0,
        DisableCount = 0,
        RestartCount = 0,

        ErrorCount = 0,
        DependencyErrors = 0,
    }

    return true
end




-- Cleanup



function FeatureManager:Destroy()
    self:_LogInfo(
        "Destroying FeatureManager"
    )

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

            if record.Stats then
                record.Stats.DestroyedAt =
                    GetClock()

                record.Stats.LastAction =
                    "Destroyed"
            end

            record.Initialized =
                false

            record.Enabled =
                false

            record.Status =
                "Destroyed"
        end
    end

    self:_FireSignal(
        "Changed",
        nil,
        "Destroyed"
    )

    self:_DestroySignals()

    self.Features = {}
    self.Order = {}

    self.Config =
        nil

    self.Connections =
        nil

    self.Cleanup =
        nil

    self.Registry =
        nil

    self.Logger =
        nil

    self.SignalModule =
        nil

    self.Modules =
        {}

    self.Running =
        false

    self.Initialized =
        false

    self:ResetRuntime()

    return true
end


return FeatureManager