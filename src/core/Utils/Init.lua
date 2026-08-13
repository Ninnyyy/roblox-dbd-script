--[[
    Lua Test Script
    Init.lua

    Main bootstrap / module loader.

    Version:
        3.0.0

    Responsibilities:
        - Load core modules
        - Load utilities
        - Load features
        - Load UI
        - Initialize Config
        - Initialize Connections
        - Initialize Character
        - Initialize Cleanup
        - Setup Logger
        - Setup Signal
        - Setup FeatureRegistry
        - Setup FeatureManager
        - Register features
        - Resolve feature dependencies
        - Start framework
        - Initialize UI
        - Expose public API
        - Safe module loading
        - Runtime diagnostics
        - Shutdown / cleanup
]]

local Init = {
    Name = "Init",
    Version = "3.0.0",

    Initialized = false,
    Running = false,

    BaseURL = nil,

    Modules = {},
    Core = {},
    Utils = {},
    Features = {},
    UI = {},

    API = {},
}


-- CONFIGURATION


local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/src/core/Init.lua"

Init.BaseURL = BASE_URL


-- INTERNAL STATE


local LoadErrors = {}
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


local function RecordLoadError(
    path,
    errorMessage
)
    table.insert(
        LoadErrors,
        {
            Path = path,
            Error = errorMessage,
        }
    )
end


local function LoadRemote(
    path
)
    if type(path) ~= "string"
        or path == "" then

        error("Invalid module path")
    end

    if LoadedPaths[path] then
        return LoadedPaths[path]
    end

    local url =
        BASE_URL .. path

    local success, source =
        pcall(function()
            return game:HttpGet(url)
        end)

    if not success then
        RecordLoadError(
            path,
            source
        )

        error(
            "Failed to download module '"
                .. path
                .. "': "
                .. SafeToString(source)
        )
    end

    if type(source) ~= "string"
        or source == "" then

        local message =
            "Empty source returned for module: "
                .. path

        RecordLoadError(
            path,
            message
        )

        error(message)
    end

    local loader =
        loadstring(source)

    if type(loader) ~= "function" then

        local message =
            "Failed to compile module: "
                .. path

        RecordLoadError(
            path,
            message
        )

        error(message)
    end

    local moduleSuccess, module =
        pcall(loader)

    if not moduleSuccess then

        RecordLoadError(
            path,
            module
        )

        error(
            "Module execution failed '"
                .. path
                .. "': "
                .. SafeToString(module)
        )
    end

    if module == nil then

        local message =
            "Module returned nil: "
                .. path

        RecordLoadError(
            path,
            message
        )

        error(message)
    end

    LoadedPaths[path] = module

    return module
end


local function SafeInitialize(
    module,
    ...
)
    if type(module) ~= "table" then
        return true
    end

    local initialize =
        module.Initialize

    if type(initialize) ~= "function" then
        return true
    end

    local success, result =
        pcall(
            function()
                return module:Initialize(...)
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Module rejected initialization"
    end

    return true, result
end


local function SafeSetup(
    module,
    ...
)
    if type(module) ~= "table" then
        return true
    end

    local setup =
        module.Setup

    if type(setup) ~= "function" then
        return true
    end

    local success, result =
        pcall(
            function()
                return module:Setup(...)
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Module rejected setup"
    end

    return true, result
end


local function SafeDestroy(
    module
)
    if type(module) ~= "table" then
        return true
    end

    local destroy =
        module.Destroy

    if type(destroy) ~= "function" then
        return true
    end

    local success, result =
        pcall(function()
            return module:Destroy()
        end)

    if not success then
        return false, result
    end

    return true
end


local function CallOptional(
    module,
    methodName,
    ...
)
    if type(module) ~= "table" then
        return true
    end

    local method =
        module[methodName]

    if type(method) ~= "function" then
        return true
    end

    local success, result =
        pcall(
            function()
                return method(
                    module,
                    ...
                )
            end
        )

    if not success then
        return false, result
    end

    if result == false then
        return false,
            "Module rejected " .. methodName
    end

    return true, result
end


-- LOAD CORE


local function LoadCore()
    Init.Core.Config =
        LoadRemote(
            "Config.lua"
        )

    Init.Core.Connections =
        LoadRemote(
            "Connections.lua"
        )

    Init.Core.Character =
        LoadRemote(
            "Character.lua"
        )

    Init.Core.Cleanup =
        LoadRemote(
            "Cleanup.lua"
        )

    Init.Core.FeatureRegistry =
        LoadRemote(
            "FeatureRegistry.lua"
        )

    Init.Core.FeatureManager =
        LoadRemote(
            "FeatureManager.lua"
        )

    -- Optional core modules.
    --
    -- These are loaded only when they exist in the
    -- current project architecture.

    local optionalCore = {
        "Logger.lua",
        "Signal.lua",
    }

    for _, fileName in ipairs(optionalCore) do

        local success, result =
            pcall(
                LoadRemote,
                fileName
            )

        if success then

            local moduleName =
                string.gsub(
                    fileName,
                    "%.lua$",
                    ""
                )

            Init.Core[moduleName] =
                result

        end
    end
end


-- LOAD UTILS


local function LoadUtils()
    Init.Utils.Helpers =
        LoadRemote(
            "Utils/Helpers.lua"
        )

    Init.Utils.Math =
        LoadRemote(
            "Utils/Math.lua"
        )

    Init.Utils.Players =
        LoadRemote(
            "Utils/Players.lua"
        )
end


-- LOAD FEATURES


local function LoadFeatures()
    Init.Features.Visuals =
        LoadRemote(
            "Features/Visuals.lua"
        )

    Init.Features.Targeting =
        LoadRemote(
            "Features/Targeting.lua"
        )

    Init.Features.ESP =
        LoadRemote(
            "Features/ESP.lua"
        )

    Init.Features.Combat =
        LoadRemote(
            "Features/Combat.lua"
        )

    Init.Features.GameFeatures =
        LoadRemote(
            "Features/GameFeatures.lua"
        )
end


-- LOAD UI


local function LoadUI()
    Init.UI.Components =
        LoadRemote(
            "UI/Components.lua"
        )

    Init.UI.Notifications =
        LoadRemote(
            "UI/Notifications.lua"
        )

    Init.UI.Window =
        LoadRemote(
            "UI/Window.lua"
        )

    Init.UI.Keybinds =
        LoadRemote(
            "UI/Keybinds.lua"
        )
end


-- COLLECT ALL MODULES


local function BuildModuleTable()

    Init.Modules = {
        Config =
            Init.Core.Config,

        Connections =
            Init.Core.Connections,

        Character =
            Init.Core.Character,

        Cleanup =
            Init.Core.Cleanup,

        FeatureRegistry =
            Init.Core.FeatureRegistry,

        FeatureManager =
            Init.Core.FeatureManager,

        Logger =
            Init.Core.Logger,

        Signal =
            Init.Core.Signal,

        Utils =
            Init.Utils,

        Features =
            Init.Features,

        UI =
            Init.UI,
    }

    -- Expose every individual utility/module too.

    for name, module in pairs(
        Init.Core
    ) do

        Init.Modules[name] =
            module
    end

    for name, module in pairs(
        Init.Utils
    ) do

        Init.Modules[name] =
            module
    end

    for name, module in pairs(
        Init.Features
    ) do

        Init.Modules[name] =
            module
    end

    for name, module in pairs(
        Init.UI
    ) do

        Init.Modules[name] =
            module
    end
end


-- CONFIGURATION INITIALIZATION


local function InitializeConfig()

    local Config =
        Init.Core.Config

    if not Config then
        error(
            "Config module failed to load"
        )
    end

    if type(Config.Initialize) ==
        "function" then

        local success, result =
            pcall(function()
                return Config:Initialize()
            end)

        if not success then
            error(
                "Config initialization failed: "
                    .. SafeToString(result)
            )
        end
    end
end


-- LOGGER


local function InitializeLogger()

    local Logger =
        Init.Core.Logger

    if not Logger then
        return
    end

    local success, errorMessage =
        SafeInitialize(
            Logger,
            Init.Modules
        )

    if not success then
        error(
            "Logger initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- SIGNAL


local function InitializeSignal()

    local Signal =
        Init.Core.Signal

    if not Signal then
        return
    end

    local success, errorMessage =
        SafeInitialize(
            Signal
        )

    if not success then
        error(
            "Signal initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- CONNECTIONS


local function InitializeConnections()

    local Connections =
        Init.Core.Connections

    if not Connections then
        return
    end

    local success, errorMessage =
        SafeInitialize(
            Connections,
            Init.Modules
        )

    if not success then
        error(
            "Connections initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- CHARACTER


local function InitializeCharacter()

    local Character =
        Init.Core.Character

    if not Character then
        return
    end

    local success, errorMessage =
        SafeInitialize(
            Character,
            Init.Modules
        )

    if not success then
        error(
            "Character initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- CLEANUP


local function InitializeCleanup()

    local Cleanup =
        Init.Core.Cleanup

    if not Cleanup then
        return
    end

    local success, errorMessage =
        SafeInitialize(
            Cleanup,
            Init.Modules
        )

    if not success then
        error(
            "Cleanup initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- FEATURE REGISTRY


local function InitializeRegistry()

    local Registry =
        Init.Core.FeatureRegistry

    if not Registry then
        error(
            "FeatureRegistry module failed to load"
        )
    end

    local success, errorMessage =
        SafeInitialize(
            Registry,
            Init.Modules
        )

    if not success then
        error(
            "FeatureRegistry initialization failed: "
                .. SafeToString(errorMessage)
        )
    end
end


-- FEATURE MANAGER


local function InitializeFeatureManager()

    local Manager =
        Init.Core.FeatureManager

    if not Manager then
        error(
            "FeatureManager module failed to load"
        )
    end

    -- The updated FeatureManager uses Setup()
    -- to receive the complete module context.

    local success, errorMessage =
        pcall(function()
            Manager:Setup(
                Init.Modules
            )
        end)

    if not success then
        error(
            "FeatureManager setup failed: "
                .. SafeToString(errorMessage)
        )
    end

    -- Explicitly configure logger.

    if Init.Core.Logger
        and type(
            Manager.SetLogger
        ) == "function" then

        Manager:SetLogger(
            Init.Core.Logger
        )
    end

    -- Explicitly configure Signal.

    if Init.Core.Signal
        and type(
            Manager.SetSignalModule
        ) == "function" then

        Manager:SetSignalModule(
            Init.Core.Signal
        )
    end

    -- Keep Config synchronized.

    Manager.Config =
        Init.Core.Config

    Manager.Connections =
        Init.Core.Connections

    Manager.Character =
        Init.Core.Character

    Manager.Cleanup =
        Init.Core.Cleanup

    Manager.Registry =
        Init.Core.FeatureRegistry

    Manager.Modules =
        Init.Modules
end


-- REGISTER FEATURES


local function RegisterFeatures()

    local Manager =
        Init.Core.FeatureManager

    if not Manager then
        error(
            "FeatureManager unavailable"
        )
    end

    
    -- VISUALS
    

    Manager:Register(
        "Visuals",
        Init.Features.Visuals,
        {
            Priority = 10,
            AutoStart = true,

            Dependencies = {},
        }
    )

    
    -- TARGETING
    

    Manager:Register(
        "Targeting",
        Init.Features.Targeting,
        {
            Priority = 20,
            AutoStart = false,

            Dependencies = {},
        }
    )

    
    -- ESP
    

    Manager:Register(
        "ESP",
        Init.Features.ESP,
        {
            Priority = 30,
            AutoStart = true,

            Dependencies = {
                "Visuals",
            },
        }
    )

    
    -- COMBAT
    

    Manager:Register(
        "Combat",
        Init.Features.Combat,
        {
            Priority = 40,
            AutoStart = false,

            Dependencies = {
                "Targeting",
            },
        }
    )

    
    -- GAME FEATURES
    

    Manager:Register(
        "GameFeatures",
        Init.Features.GameFeatures,
        {
            Priority = 50,
            AutoStart = true,

            Dependencies = {},
        }
    )

    Manager:SortOrder()
end


-- INITIALIZE FEATURE CONTEXT


local function PrepareFeatureContext()

    local Manager =
        Init.Core.FeatureManager

    if not Manager then
        return
    end

    -- The FeatureManager itself creates the context
    -- passed to every feature.
    --
    -- This additionally exposes the complete module
    -- table directly to feature modules that support
    -- SetModules().

    if type(
        Manager.SetModules
    ) == "function" then

        Manager:SetModules(
            Init.Modules
        )
    end

    -- Give each feature direct access to the complete
    -- module collection when supported.

    for _, feature in pairs(
        Init.Features
    ) do

        if type(feature) == "table"
            and type(
                feature.SetModules
            ) == "function" then

            pcall(function()
                feature:SetModules(
                    Init.Modules
                )
            end)
        end
    end
end


-- START FEATURE MANAGER


local function StartFeatureManager()

    local Manager =
        Init.Core.FeatureManager

    if not Manager then
        error(
            "FeatureManager unavailable"
        )
    end

    local success, result =
        pcall(function()
            return Manager:Start()
        end)

    if not success then
        error(
            "FeatureManager failed to start: "
                .. SafeToString(result)
        )
    end

    return result
end


-- UI CONTEXT


local function BuildUIContext()

    return {
        Config =
            Init.Core.Config,

        Connections =
            Init.Core.Connections,

        Character =
            Init.Core.Character,

        Cleanup =
            Init.Core.Cleanup,

        Logger =
            Init.Core.Logger,

        Signal =
            Init.Core.Signal,

        FeatureRegistry =
            Init.Core.FeatureRegistry,

        FeatureManager =
            Init.Core.FeatureManager,

        Modules =
            Init.Modules,

        Features =
            Init.Features,

        UI =
            Init.UI,

        Init =
            Init,
    }
end


-- INITIALIZE UI


local function InitializeUI()

    local context =
        BuildUIContext()

    
    -- COMPONENTS
    

    if Init.UI.Components then

        local success, errorMessage =
            SafeInitialize(
                Init.UI.Components,
                context
            )

        if not success then

            warn(
                "[Lua Test] Components initialization failed:",
                errorMessage
            )
        end
    end

    
    -- NOTIFICATIONS
    

    if Init.UI.Notifications then

        local success, errorMessage =
            SafeInitialize(
                Init.UI.Notifications,
                context
            )

        if not success then

            warn(
                "[Lua Test] Notifications initialization failed:",
                errorMessage
            )
        end
    end

    
    -- WINDOW
    

    if Init.UI.Window then

        local success, errorMessage =
            SafeInitialize(
                Init.UI.Window,
                context
            )

        if not success then

            warn(
                "[Lua Test] Window initialization failed:",
                errorMessage
            )
        end
    end

    
    -- KEYBINDS
    

    if Init.UI.Keybinds then

        local success, errorMessage =
            SafeInitialize(
                Init.UI.Keybinds,
                context
            )

        if not success then

            warn(
                "[Lua Test] Keybinds initialization failed:",
                errorMessage
            )
        end
    end

    
    -- SETUP UI MODULES
    

    local uiModules = {
        Init.UI.Components,
        Init.UI.Notifications,
        Init.UI.Window,
        Init.UI.Keybinds,
    }

    for _, module in ipairs(uiModules) do

        if type(module) == "table" then

            SafeSetup(
                module,
                context
            )
        end
    end
end


-- PUBLIC API


function Init:GetModule(name)

    if type(name) ~= "string" then
        return nil
    end

    return self.Modules[name]
end


function Init:GetFeature(name)

    if not self.Core.FeatureManager then
        return nil
    end

    return self.Core.FeatureManager:Get(
        name
    )
end


function Init:GetFeatureManager()

    return self.Core.FeatureManager
end


function Init:GetRegistry()

    return self.Core.FeatureRegistry
end


function Init:GetConfig()

    return self.Core.Config
end


function Init:GetUI(name)

    if not name then
        return self.UI
    end

    return self.UI[name]
end


function Init:IsRunning()

    return self.Running == true
end


function Init:IsInitialized()

    return self.Initialized == true
end


function Init:GetLoadErrors()

    local result = {}

    for index, item in ipairs(
        LoadErrors
    ) do

        result[index] = {
            Path = item.Path,
            Error = item.Error,
        }
    end

    return result
end


function Init:GetStatus()

    local managerStatus

    if self.Core.FeatureManager
        and type(
            self.Core.FeatureManager.GetRuntimeStatus
        ) == "function" then

        managerStatus =
            self.Core.FeatureManager:GetRuntimeStatus()
    end

    return {
        Name =
            self.Name,

        Version =
            self.Version,

        Initialized =
            self.Initialized,

        Running =
            self.Running,

        Manager =
            managerStatus,

        LoadErrors =
            self:GetLoadErrors(),
    }
end


-- START


function Init:Start()

    if self.Running then
        return true
    end

    if not self.Initialized then

        local success, errorMessage =
            self:Initialize()

        if not success then
            return false,
                errorMessage
        end
    end

    if self.Core.FeatureManager then

        local success, result =
            pcall(function()
                return self.Core.FeatureManager:Start()
            end)

        if not success then

            return false,
                result
        end
    end

    self.Running = true

    return true
end


-- INITIALIZE


function Init:Initialize()

    if self.Initialized then
        return true
    end

    
    -- LOAD
    

    local success, errorMessage =
        pcall(function()

            LoadCore()

            LoadUtils()

            LoadFeatures()

            LoadUI()

            BuildModuleTable()

        end)

    if not success then

        return false,
            errorMessage
    end

    
    -- INITIALIZE CORE
    

    success, errorMessage =
        pcall(function()

            InitializeConfig()

            InitializeLogger()

            InitializeSignal()

            InitializeConnections()

            InitializeCharacter()

            InitializeCleanup()

            InitializeRegistry()

            InitializeFeatureManager()

        end)

    if not success then

        return false,
            errorMessage
    end

    
    -- REGISTER FEATURES
    

    success, errorMessage =
        pcall(function()

            RegisterFeatures()

            PrepareFeatureContext()

        end)

    if not success then

        return false,
            errorMessage
    end

    
    -- START FEATURE MANAGER
    

    success, errorMessage =
        pcall(function()

            StartFeatureManager()

        end)

    if not success then

        return false,
            errorMessage
    end

    
    -- UI
    

    pcall(function()
        InitializeUI()
    end)

    
    -- BUILD PUBLIC API
    

    self.API = {

        Config =
            self.Core.Config,

        Connections =
            self.Core.Connections,

        Character =
            self.Core.Character,

        Cleanup =
            self.Core.Cleanup,

        FeatureRegistry =
            self.Core.FeatureRegistry,

        FeatureManager =
            self.Core.FeatureManager,

        Logger =
            self.Core.Logger,

        Signal =
            self.Core.Signal,

        Features =
            self.Features,

        UI =
            self.UI,

        Modules =
            self.Modules,

        GetFeature =
            function(name)
                return self:GetFeature(name)
            end,

        GetConfig =
            function()
                return self:GetConfig()
            end,

        GetStatus =
            function()
                return self:GetStatus()
            end,
    }

    self.Initialized = true
    self.Running = true

    return true
end


-- STOP


function Init:Stop()

    if not self.Running then
        return true
    end

    local success = true

    
    -- STOP FEATURE MANAGER
    

    if self.Core.FeatureManager then

        local result =
            pcall(function()
                self.Core.FeatureManager:Stop()
            end)

        if not result then
            success = false
        end
    end

    
    -- STOP UI
    

    local uiOrder = {
        "Keybinds",
        "Window",
        "Notifications",
        "Components",
    }

    for _, name in ipairs(uiOrder) do

        local module =
            self.UI[name]

        if module then

            local stopped =
                CallOptional(
                    module,
                    "Stop"
                )

            if not stopped then
                success = false
            end
        end
    end

    self.Running = false

    return success
end


-- DESTROY


function Init:Destroy()

    self:Stop()

    
    -- FEATURE MANAGER
    

    if self.Core.FeatureManager then

        pcall(function()
            self.Core.FeatureManager:Destroy()
        end)
    end

    
    -- UI
    

    local uiOrder = {
        "Keybinds",
        "Window",
        "Notifications",
        "Components",
    }

    for _, name in ipairs(uiOrder) do

        SafeDestroy(
            self.UI[name]
        )
    end

    
    -- CORE
    

    local coreOrder = {
        "Character",
        "Connections",
        "Cleanup",
        "FeatureRegistry",
        "Signal",
        "Logger",
        "Config",
    }

    for _, name in ipairs(coreOrder) do

        if name ~= "FeatureManager" then

            SafeDestroy(
                self.Core[name]
            )
        end
    end

    self.Modules = {}
    self.Core = {}
    self.Utils = {}
    self.Features = {}
    self.UI = {}
    self.API = {}

    self.Initialized = false
    self.Running = false

    return true
end


-- BOOTSTRAP


local success, errorMessage =
    pcall(function()
        Init:Initialize()
    end)

if not success then

    warn(
        "[Lua Test] Framework initialization failed:",
        errorMessage
    )

    return Init
end

return Init