--[[
    Lua Test Script
    src/core/Init.lua

    Core framework bootstrap.

    Responsibilities:
        - Load core modules by repository-relative path
        - Load utility subsystem via src/core/Utils/Init.lua
        - Load feature modules and UI modules
        - Initialize services in a safe order
        - Expose framework public API
        - Guard against duplicate remote loads
        - Track runtime status and module errors
]]

local Init = {
    Name = "Init",
    Version = "3.0.0",

    Initialized = false,
    Running = false,

    BaseURL =
        "https://raw.githubusercontent.com/Ninnyyy/roblox-dbd-script/main/",

    Modules = {},
    Core = {},
    Utils = {},
    Features = {},
    UI = {},
    API = {},

    Errors = {},

    StartedAt = nil,
    StoppedAt = nil,
}



-- STATE

local LoadedPaths = {}



-- HELPERS

local function SafeToString(value)
    if value == nil then
        return "nil"
    end

    local success, result =
        pcall(tostring, value)

    if success then
        return result
    end

    return "<unprintable>"
end


local function RecordError(path, message)
    table.insert(Init.Errors, {
        Path = path,
        Error = SafeToString(message),
    })
end


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


local function GetModuleNameFromPath(path)
    if type(path) ~= "string" then
        return nil
    end

    local name = path:match("([^/]+)%.lua$")
    if not name then
        return nil
    end

    return name
end


local function InvokeLifecycle(module, methodName, ...)
    if type(module) ~= "table" then
        return true
    end

    local method = module[methodName]
    if type(method) ~= "function" then
        return true
    end

    local success, result =
        pcall(function()
            return method(module, ...)
        end)

    if not success then
        return false, result
    end

    if result == false then
        return false, methodName .. " rejected"
    end

    return true, result
end


-- REMOTE LOADER

local function LoadRemote(path)
    if type(path) ~= "string" or path == "" then
        error("Invalid module path")
    end

    local normalized = NormalizeName(path)
    if not normalized then
        error("Invalid module path")
    end

    if LoadedPaths[normalized] ~= nil then
        return LoadedPaths[normalized]
    end

    local url = Init.BaseURL .. normalized

    local requestSuccess, source =
        pcall(function()
            return game:HttpGet(url, true)
        end)

    if not requestSuccess then
        local message =
            "Failed to download module:\n"
            .. normalized
            .. "\n"
            .. SafeToString(source)

        RecordError(normalized, message)
        error(message)
    end

    if type(source) ~= "string" or source == "" then
        local message =
            "Empty source returned for module: "
            .. normalized

        RecordError(normalized, message)
        error(message)
    end

    local loader, compileError =
        loadstring(source)

    if type(loader) ~= "function" then
        local message =
            "Failed to compile module: "
            .. normalized
            .. "\n"
            .. SafeToString(compileError)

        RecordError(normalized, message)
        error(message)
    end

    local executeSuccess, module =
        pcall(loader)

    if not executeSuccess then
        local message =
            "Module execution failed: "
            .. normalized
            .. "\n"
            .. SafeToString(module)

        RecordError(normalized, message)
        error(message)
    end

    if module == nil then
        local message =
            "Module returned nil: "
            .. normalized

        RecordError(normalized, message)
        error(message)
    end

    if type(module) ~= "table" then
        local message =
            "Module returned non-table value: "
            .. normalized
            .. " ("
            .. type(module)
            .. ")"

        RecordError(normalized, message)
        error(message)
    end

    LoadedPaths[normalized] = module
    return module
end


-- MODULE REGISTRATION

local function RegisterModule(name, module)
    if type(name) ~= "string" then
        return
    end

    if module == nil then
        return
    end

    Init.Modules[name] = module

    if type(module) == "table" then
        Init[name] = module
    end
end


local function LoadCoreModules()
    local paths = {
        "src/core/Config.lua",
        "src/core/Connections.lua",
        "src/core/Character.lua",
        "src/core/Cleanup.lua",
        "src/core/FeatureRegistry.lua",
        "src/core/FeatureManager.lua",
        "src/core/Logger.lua",
        "src/core/Signal.lua",
    }

    for _, path in ipairs(paths) do
        local module = LoadRemote(path)
        local moduleName = GetModuleNameFromPath(path)
        if moduleName then
            RegisterModule(moduleName, module)
            Init.Core[moduleName] = module
        end
    end
end


local function LoadUtilitySubsystem()
    local utilsModule =
        LoadRemote("src/core/Utils/Init.lua")

    if type(utilsModule) == "table" then
        Init.Utils = utilsModule
        Init.Modules.Utils = utilsModule
        Init.UtilsModule = utilsModule

        if type(utilsModule.Initialize) == "function" then
            local success, result = pcall(function()
                return utilsModule:Initialize()
            end)

            if not success then
                table.insert(Init.Errors, {
                    Path = "src/core/Utils/Init.lua",
                    Error = SafeToString(result),
                })
                warn("[Lua Test] Utils bootstrap failed:", result)
            end
        end
    end
end


local function LoadFeatureModules()
    local paths = {
        "src/core/Features/Visuals.lua",
        "src/core/Features/Targeting.lua",
        "src/core/Features/ESP.lua",
        "src/core/Features/Combat.lua",
        "src/core/Features/Camera.lua",
        "src/core/Features/GameFeatures.lua",
        "src/core/Features/Teleports.lua",
    }

    for _, path in ipairs(paths) do
        local success, module = pcall(LoadRemote, path)
        if success and module ~= nil then
            local moduleName = GetModuleNameFromPath(path)
            if moduleName then
                RegisterModule(moduleName, module)
                Init.Features[moduleName] = module
            end
        else
            RecordError(path, module)
        end
    end
end


local function LoadUIModules()
    local paths = {
        "src/core/UI/Components.lua",
        "src/core/UI/Notifications.lua",
        "src/core/UI/Themes.lua",
        "src/core/UI/Window.lua",
        "src/core/UI/Keybinds.lua",
    }

    for _, path in ipairs(paths) do
        local success, module = pcall(LoadRemote, path)
        if success and module ~= nil then
            local moduleName = GetModuleNameFromPath(path)
            if moduleName then
                RegisterModule(moduleName, module)
                Init.UI[moduleName] = module
            end
        else
            RecordError(path, module)
        end
    end
end


local function ApplyModuleContext(module, context)
    if type(module) ~= "table" then
        return true
    end

    if type(module.Initialize) == "function" then
        local success, result =
            pcall(function()
                return module:Initialize(context)
            end)

        if not success then
            RecordError(module.Name or "unknown", result)
            warn("[Lua Test] Module initialization failed:", module.Name or "unknown", result)
            return false
        end
    end

    return true
end


local function SyncFeaturesToManager()
    local manager = Init:GetFeatureManager()
    if not manager or type(manager.Register) ~= "function" then
        return
    end

    for featureName, feature in pairs(Init.Features) do
        if type(feature) == "table" and type(manager.GetRecord) == "function" then
            local existing = manager:GetRecord(featureName)
            if not existing then
                local category = "Misc"

                if type(feature.Category) == "string" and feature.Category ~= "" then
                    category = feature.Category
                end

                pcall(function()
                    manager:Register(featureName, feature, {
                        Category = category,
                        AutoStart = false,
                        Priority = tonumber(feature.Priority) or 0,
                    })
                end)
            end
        end
    end
end


-- PUBLIC API

function Init:GetModule(name)
    if type(name) ~= "string" then
        return nil
    end

    local key = NormalizeName(name)
    if not key then
        return nil
    end

    return self.Modules[key]
        or self.Core[key]
        or self.Utils[key]
        or self.Features[key]
        or self.UI[key]
end


function Init:GetFeature(name)
    if type(name) ~= "string" then
        return nil
    end

    return self.Features[NormalizeName(name)]
end


function Init:GetFeatureManager()
    return self:GetModule("FeatureManager")
end


function Init:GetRegistry()
    return self:GetModule("FeatureRegistry")
end


function Init:GetConfig()
    return self:GetModule("Config")
end


function Init:GetUI(name)
    if type(name) ~= "string" then
        return self.UI
    end

    return self.UI[NormalizeName(name)]
end


function Init:IsRunning()
    return self.Running == true
end


function Init:IsInitialized()
    return self.Initialized == true
end


function Init:GetLoadErrors()
    local result = {}
    for index, item in ipairs(self.Errors) do
        result[index] = {
            Path = item.Path,
            Error = item.Error,
        }
    end
    return result
end


function Init:GetStatus()
    return {
        Name = self.Name,
        Version = self.Version,
        Initialized = self.Initialized,
        Running = self.Running,
        Modules = self.Modules,
        Errors = self:GetLoadErrors(),
    }
end


function Init:Initialize()
    if self.Initialized then
        return true
    end

    local context = {
        Config = self:GetModule("Config"),
        Connections = self:GetModule("Connections"),
        Character = self:GetModule("Character"),
        Cleanup = self:GetModule("Cleanup"),
        Logger = self:GetModule("Logger"),
        Signal = self:GetModule("Signal"),
        FeatureRegistry = self:GetModule("FeatureRegistry"),
        FeatureManager = self:GetModule("FeatureManager"),
        Modules = self.Modules,
        Features = self.Features,
        UI = self.UI,
        Init = self,
    }

    local success, err = pcall(function()
        LoadCoreModules()
        LoadUtilitySubsystem()
        LoadFeatureModules()
        LoadUIModules()

        local config = self:GetModule("Config")
        if config and type(config.Initialize) == "function" then
            config:Initialize(context)
        end

        local logger = self:GetModule("Logger")
        if logger and type(logger.Initialize) == "function" then
            logger:Initialize(context)
        end

        local signal = self:GetModule("Signal")
        if signal and type(signal.Initialize) == "function" then
            signal:Initialize(context)
        end

        local connections = self:GetModule("Connections")
        if connections and type(connections.Initialize) == "function" then
            connections:Initialize(context)
        end

        local character = self:GetModule("Character")
        if character and type(character.Initialize) == "function" then
            character:Initialize(context)
        end

        local cleanup = self:GetModule("Cleanup")
        if cleanup and type(cleanup.Initialize) == "function" then
            cleanup:Initialize(context)
        end

        local registry = self:GetModule("FeatureRegistry")
        if registry and type(registry.Initialize) == "function" then
            registry:Initialize(context)
        end

        local manager = self:GetModule("FeatureManager")
        if manager and type(manager.Initialize) == "function" then
            manager:Initialize(context)
        end

        for _, feature in pairs(self.Features) do
            if type(feature) == "table" and type(feature.Initialize) == "function" then
                feature:Initialize(context)
            end
        end

        if manager and type(manager.Start) == "function" then
            manager:Start()
        end

        for _, component in pairs(self.UI) do
            if type(component) == "table" and type(component.Initialize) == "function" then
                component:Initialize(context)
            end
        end

        SyncFeaturesToManager()

        self.Initialized = true
        self.Running = true
        self.StartedAt = os.clock and os.clock() or 0
    end)

    if not success then
        self.Initialized = false
        self.Running = false
        RecordError("src/core/Init.lua", err)
        return false, err
    end

    return true
end


function Init:Start()
    if self.Running then
        return true
    end

    local success, err = self:Initialize()
    if not success then
        return false, err
    end

    local manager = self:GetFeatureManager()
    if manager and type(manager.Start) == "function" then
        local ok, result = pcall(function()
            return manager:Start()
        end)

        if not ok then
            return false, result
        end
    end

    self.Running = true
    return true
end


function Init:Stop()
    if not self.Running then
        return true
    end

    local manager = self:GetFeatureManager()
    if manager and type(manager.Stop) == "function" then
        pcall(function()
            manager:Stop()
        end)
    end

    self.Running = false
    self.StoppedAt = os.clock and os.clock() or 0
    return true
end


function Init:Destroy()
    self:Stop()

    local manager = self:GetFeatureManager()
    if manager and type(manager.Destroy) == "function" then
        pcall(function()
            manager:Destroy()
        end)
    end

    if self.Utils and type(self.Utils.Destroy) == "function" then
        pcall(function()
            self.Utils:Destroy()
        end)
    end

    self.Initialized = false
    self.Running = false
    self.Modules = {}
    self.Core = {}
    self.Utils = {}
    self.Features = {}
    self.UI = {}
    self.API = {}
    self.Errors = {}
    LoadedPaths = {}
    return true
end


-- BOOTSTRAP

local success, errorMessage =
    pcall(function()
        Init:Initialize()
    end)

if not success then
    print("[Lua Test] ⚠ Framework bootstrap failed:")
    print(errorMessage)
    table.insert(Init.Errors, {
        Path = "src/core/Init.lua",
        Error = "Bootstrap failed: " .. tostring(errorMessage),
    })
else
    print("[Lua Test] ✓ Framework initialized successfully")
end

return Init
