--[[
    Lua Test Script
    Init.lua

    Main bootstrap / module loader.

    Responsibilities:
        - Load core modules
        - Load utilities
        - Load features
        - Load UI
        - Setup Logger
        - Setup Signal
        - Setup FeatureRegistry
        - Setup FeatureManager
        - Register features
        - Start framework
        - Initialize UI
        - Expose public API
]]

local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/"

local Init = {
    Name = "LuaTest",
    Version = "2.3.0",

    Initialized = false,
    Modules = {},
}




-- Loader


local function Import(path)
    assert(
        type(path) == "string"
            and path ~= "",
        "[Lua Test] Invalid module path"
    )

    local url =
        BASE_URL .. path

    local success, source =
        pcall(function()
            return game:HttpGet(
                url,
                true
            )
        end)

    if not success then
        error(
            "[Lua Test] Failed to download "
                .. path
                .. ":\n"
                .. tostring(source)
        )
    end

    if type(source) ~= "string"
        or source == "" then

        error(
            "[Lua Test] Empty source returned for: "
                .. path
        )
    end

    local loader, compileError =
        loadstring(source)

    if not loader then
        error(
            "[Lua Test] Failed to compile "
                .. path
                .. ":\n"
                .. tostring(compileError)
        )
    end

    local moduleSuccess, result =
        pcall(loader)

    if not moduleSuccess then
        error(
            "[Lua Test] Failed to execute "
                .. path
                .. ":\n"
                .. tostring(result)
        )
    end

    if result == nil then
        error(
            "[Lua Test] Module returned nil: "
                .. path
        )
    end

    return result
end


local function ImportModule(
    name,
    path
)
    local success, result =
        pcall(function()
            return Import(path)
        end)

    if not success then
        error(
            "[Lua Test] Failed importing "
                .. name
                .. ":\n"
                .. tostring(result)
        )
    end

    Init.Modules[name] = result

    return result
end




-- Core


local Config = ImportModule(
    "Config",
    "src/core/Config.lua"
)

local Connections = ImportModule(
    "Connections",
    "src/core/Connections.lua"
)

local Character = ImportModule(
    "Character",
    "src/core/Character.lua"
)

local Cleanup = ImportModule(
    "Cleanup",
    "src/core/Cleanup.lua"
)

local Logger = ImportModule(
    "Logger",
    "src/core/Logger.lua"
)

local FeatureRegistry = ImportModule(
    "FeatureRegistry",
    "src/core/FeatureRegistry.lua"
)

local FeatureManager = ImportModule(
    "FeatureManager",
    "src/core/FeatureManager.lua"
)




-- Utilities


local Helpers = ImportModule(
    "Helpers",
    "src/core/Utils/Helpers.lua"
)

local Math = ImportModule(
    "Math",
    "src/core/Utils/Math.lua"
)

local Players = ImportModule(
    "Players",
    "src/core/Utils/Players.lua"
)

local Signal = ImportModule(
    "Signal",
    "src/core/Utils/Signal.lua"
)




-- Features


local Visuals = ImportModule(
    "Visuals",
    "src/core/Features/Visuals.lua"
)

local ESP = ImportModule(
    "ESP",
    "src/core/Features/ESP.lua"
)

local Combat = ImportModule(
    "Combat",
    "src/core/Features/Combat.lua"
)

local Targeting = ImportModule(
    "Targeting",
    "src/core/Features/Targeting.lua"
)

local GameFeatures = ImportModule(
    "GameFeatures",
    "src/core/Features/GameFeatures.lua"
)




-- UI


local Components = ImportModule(
    "Components",
    "src/core/UI/Components.lua"
)

local Notifications = ImportModule(
    "Notifications",
    "src/core/UI/Notifications.lua"
)

local Window = ImportModule(
    "Window",
    "src/core/UI/Window.lua"
)

local Keybinds = ImportModule(
    "Keybinds",
    "src/core/UI/Keybinds.lua"
)




-- Complete Module Context


local FeatureModules = {
    -- Core
    Config = Config,
    Connections = Connections,
    Character = Character,
    Cleanup = Cleanup,
    Logger = Logger,

    FeatureRegistry = FeatureRegistry,
    FeatureManager = FeatureManager,

    -- Utilities
    Helpers = Helpers,
    Math = Math,
    Players = Players,
    Signal = Signal,

    -- Features
    Visuals = Visuals,
    ESP = ESP,
    Combat = Combat,
    Targeting = Targeting,
    GameFeatures = GameFeatures,

    -- UI
    Components = Components,
    Notifications = Notifications,
    Window = Window,
    Keybinds = Keybinds,
}


for name, module in pairs(
    FeatureModules
) do
    Init.Modules[name] = module
end




-- Logger Setup


local loggerSetupSuccess, loggerSetupResult =
    pcall(function()
        if Logger
            and type(Logger.Initialize)
                == "function" then

            return Logger:Initialize({
                Config = Config,
                Connections = Connections,
            })
        end

        return true
    end)

if not loggerSetupSuccess then
    warn(
        "[Lua Test] Logger initialization failed:\n"
            .. tostring(loggerSetupResult)
    )
end


local Log =
    Logger
        and type(Logger.For) == "function"
        and Logger:For("Init")
        or nil


if Log then
    Log:Info(
        "Bootstrap modules loaded"
    )
end




-- Signal Setup


local signalSetupSuccess, signalSetupResult =
    pcall(function()
        if Signal
            and type(Signal.Initialize)
                == "function" then

            return Signal:Initialize()
        end

        return true
    end)

if not signalSetupSuccess then
    if Log then
        Log:Error(
            "Signal initialization failed:",
            signalSetupResult
        )
    else
        warn(
            "[Lua Test] Signal initialization failed:",
            signalSetupResult
        )
    end
end




-- Feature Manager Setup


local setupSuccess, setupResult =
    pcall(function()
        return FeatureManager:Setup({
            Config = Config,
            Connections = Connections,
            Cleanup = Cleanup,

            Logger = Logger,
            Signal = Signal,

            FeatureRegistry =
                FeatureRegistry,
        })
    end)

if not setupSuccess then
    if Log then
        Log:Error(
            "FeatureManager setup failed:",
            setupResult
        )
    end

    error(
        "[Lua Test] FeatureManager setup failed:\n"
            .. tostring(setupResult)
    )
end


if Log then
    Log:Success(
        "FeatureManager setup complete"
    )
end




-- Feature Registration


local function RegisterFeature(
    name,
    module,
    options
)
    local success, result =
        FeatureManager:Register(
            name,
            module,
            options
        )

    if not success then
        if Log then
            Log:Error(
                "Failed to register feature",
                name,
                result
            )
        end

        error(
            "[Lua Test] Failed to register feature "
                .. name
                .. ":\n"
                .. tostring(result)
        )
    end

    if Log then
        Log:Debug(
            "Registered feature",
            name
        )
    end

    return true
end


RegisterFeature(
    "Visuals",
    Visuals,
    {
        Priority = 10,
        AutoStart = true,
    }
)


RegisterFeature(
    "Targeting",
    Targeting,
    {
        Priority = 20,
        AutoStart = false,
    }
)


RegisterFeature(
    "ESP",
    ESP,
    {
        Priority = 30,

        Dependencies = {
            "Visuals",
        },

        AutoStart = true,
    }
)


RegisterFeature(
    "Combat",
    Combat,
    {
        Priority = 40,

        Dependencies = {
            "Targeting",
        },

        AutoStart = false,
    }
)


RegisterFeature(
    "GameFeatures",
    GameFeatures,
    {
        Priority = 50,
        AutoStart = true,
    }
)




-- Feature Startup


local startSuccess, startResult =
    pcall(function()
        return FeatureManager:Start()
    end)

if not startSuccess then
    if Log then
        Log:Error(
            "FeatureManager failed to start:",
            startResult
        )
    end

    error(
        "[Lua Test] FeatureManager failed to start:\n"
            .. tostring(startResult)
    )
end


if startResult == false then
    if Log then
        Log:Warn(
            "FeatureManager started with initialization errors"
        )
    else
        warn(
            "[Lua Test] FeatureManager started with initialization errors."
        )
    end
else
    if Log then
        Log:Success(
            "FeatureManager started"
        )
    end
end




-- UI Safe Initialization


local function SafeCall(
    name,
    callback
)
    if type(callback) ~= "function" then
        return false
    end

    local success, result =
        pcall(callback)

    if not success then
        if Log then
            Log:Error(
                name
                    .. " initialization failed:",
                result
            )
        else
            warn(
                "[Lua Test] "
                    .. name
                    .. " initialization failed:",
                result
            )
        end

        return false
    end

    if Log then
        Log:Debug(
            name
                .. " initialized"
        )
    end

    return true
end




-- Window


SafeCall(
    "Window",
    function()
        if Window
            and type(Window.Initialize)
                == "function" then

            Window:Initialize(
                FeatureModules
            )
        end
    end
)




-- Keybinds


SafeCall(
    "Keybinds",
    function()
        if Keybinds
            and type(Keybinds.Initialize)
                == "function" then

            Keybinds:Initialize(
                FeatureModules
            )
        end
    end
)




-- Notifications


SafeCall(
    "Notifications",
    function()
        if Notifications
            and type(Notifications.Info)
                == "function" then

            Notifications:Info(
                "Lua Test",
                "Framework initialized"
            )
        end
    end
)




-- Runtime Information


Init.Initialized = true


if Log then
    Log:Success(
        "Lua Test Script initialized",
        "Version:",
        Init.Version
    )
end


print(
    "[Lua Test] ======================================="
)

print(
    "[Lua Test] Lua Test Script initialized"
)

print(
    "[Lua Test] Version:",
    Init.Version
)

print(
    "[Lua Test] ======================================="
)


local featureNames =
    FeatureManager:GetNames()

local enabledFeatures =
    FeatureManager:GetEnabled()


print(
    "[Lua Test] Features:",
    table.concat(
        featureNames,
        ", "
    )
)


print(
    "[Lua Test] Enabled:",
    table.concat(
        enabledFeatures,
        ", "
    )
)


print(
    "[Lua Test] Feature Count:",
    FeatureManager:Count()
)


print(
    "[Lua Test] Initialization complete"
)




-- Public API


return {
    Init = Init,

    -- Core
    Config = Config,
    Connections = Connections,
    Character = Character,
    Cleanup = Cleanup,
    Logger = Logger,

    FeatureRegistry =
        FeatureRegistry,

    FeatureManager =
        FeatureManager,

    -- Utilities
    Helpers = Helpers,
    Math = Math,
    Players = Players,
    Signal = Signal,

    -- Features
    Visuals = Visuals,
    ESP = ESP,
    Combat = Combat,
    Targeting = Targeting,
    GameFeatures = GameFeatures,

    -- UI
    Components = Components,
    Notifications = Notifications,
    Window = Window,
    Keybinds = Keybinds,

    -- Loader
    Import = Import,
}