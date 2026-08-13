--[[
    Lua Test Script
    Init.lua

    Main bootstrap / module loader.
]]

local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/"

local Init = {
    Name = "LuaTest",
    Version = "2.1.0",

    Initialized = false,
    Modules = {},
}


-- Loader


local function Import(path)
    assert(
        type(path) == "string" and path ~= "",
        "[Lua Test] Invalid module path"
    )

    local url = BASE_URL .. path

    local success, source = pcall(function()
        return game:HttpGet(url, true)
    end)

    if not success then
        error(
            "[Lua Test] Failed to download "
                .. path
                .. ":\n"
                .. tostring(source)
        )
    end

    if type(source) ~= "string" or source == "" then
        error(
            "[Lua Test] Empty source returned for: "
                .. path
        )
    end

    local loader, compileError = loadstring(source)

    if not loader then
        error(
            "[Lua Test] Failed to compile "
                .. path
                .. ":\n"
                .. tostring(compileError)
        )
    end

    local moduleSuccess, result = pcall(loader)

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

local function ImportModule(name, path)
    local success, result = pcall(function()
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


-- Feature Manager Setup


FeatureManager:Setup({
    Config = Config,
    Connections = Connections,
    Cleanup = Cleanup,
})


-- Register Features


FeatureManager:Register(
    "Visuals",
    Visuals,
    {
        Priority = 10,
        AutoStart = true,
    }
)

FeatureManager:Register(
    "Targeting",
    Targeting,
    {
        Priority = 20,
        AutoStart = false,
    }
)

FeatureManager:Register(
    "ESP",
    ESP,
    {
        Priority = 30,
        AutoStart = true,
    }
)

FeatureManager:Register(
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

FeatureManager:Register(
    "GameFeatures",
    GameFeatures,
    {
        Priority = 50,
        AutoStart = true,
    }
)


-- Initialize Features


local FeatureModules = {
    Config = Config,
    Connections = Connections,
    Cleanup = Cleanup,

    Helpers = Helpers,
    Math = Math,
    Players = Players,

    Character = Character,

    Visuals = Visuals,
    ESP = ESP,
    Combat = Combat,
    Targeting = Targeting,
    GameFeatures = GameFeatures,

    Components = Components,
    Notifications = Notifications,
    Window = Window,
    Keybinds = Keybinds,

    FeatureManager = FeatureManager,
}

-- Give every feature the complete module table.
-- This fixes ESP.Initialize() receiving only
-- Config/Connections/Cleanup.

local function InitializeFeature(name)
    local module = FeatureManager:Get(name)

    if not module then
        warn(
            "[Lua Test] Missing feature module:",
            name
        )

        return false
    end

    if type(module.Initialize) ~= "function" then
        return true
    end

    local success, result = pcall(function()
        return module:Initialize(FeatureModules)
    end)

    if not success then
        warn(
            "[Lua Test] Failed to initialize feature "
                .. name
                .. ":",
            result
        )

        return false
    end

    return result ~= false
end

-- Initialize in dependency/priority order.
for _, name in ipairs(FeatureManager:GetNames()) do
    InitializeFeature(name)
end


-- Start Feature Manager


local startSuccess, startResult = pcall(function()
    return FeatureManager:Start()
end)

if not startSuccess then
    error(
        "[Lua Test] FeatureManager failed to start:\n"
            .. tostring(startResult)
    )
end


-- UI


local function SafeCall(name, callback)
    if type(callback) ~= "function" then
        return false
    end

    local success, result = pcall(callback)

    if not success then
        warn(
            "[Lua Test] "
                .. name
                .. " initialization failed:",
            result
        )

        return false
    end

    return true
end

SafeCall("Window", function()
    if Window and type(Window.Initialize) == "function" then
        Window:Initialize(FeatureModules)
    end
end)

SafeCall("Keybinds", function()
    if Keybinds and type(Keybinds.Initialize) == "function" then
        Keybinds:Initialize(FeatureModules)
    end
end)

SafeCall("Notifications", function()
    if Notifications
        and type(Notifications.Info) == "function" then

        Notifications:Info(
            "Lua Test",
            "Framework initialized"
        )
    end
end)


-- Complete


Init.Initialized = true

print("[Lua Test] =======================================")
print("[Lua Test] Lua Test Script initialized")
print("[Lua Test] Version:", Init.Version)
print("[Lua Test] =======================================")

print(
    "[Lua Test] Features:",
    table.concat(
        FeatureManager:GetNames(),
        ", "
    )
)

print(
    "[Lua Test] Enabled:",
    table.concat(
        FeatureManager:GetEnabled(),
        ", "
    )
)

print("[Lua Test] Initialization complete")


-- Public API


return {
    Init = Init,

    Config = Config,
    Connections = Connections,
    Character = Character,
    Cleanup = Cleanup,
    FeatureManager = FeatureManager,

    Helpers = Helpers,
    Math = Math,
    Players = Players,

    Visuals = Visuals,
    ESP = ESP,
    Combat = Combat,
    Targeting = Targeting,
    GameFeatures = GameFeatures,

    Components = Components,
    Notifications = Notifications,
    Window = Window,
    Keybinds = Keybinds,

    Import = Import,
}