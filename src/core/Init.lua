--[[
    Lua Test Script
    Init.lua

    Main bootstrap / module loader.

    Responsibilities:
        - Load all modules
        - Validate module loading
        - Initialize FeatureManager
        - Register feature modules
        - Start the feature system
        - Return the complete module table
]]

local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/"

local Init = {
    Name = "LuaTest",
    Version = "2.0.0",

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

    local loader,
        compileError =
        loadstring(source)

    if not loader then
        error(
            "[Lua Test] Failed to compile "
                .. path
                .. ":\n"
                .. tostring(compileError)
        )
    end

    local moduleSuccess,
        result =
        pcall(loader)

    if not moduleSuccess then
        error(
            "[Lua Test] Failed to load "
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



-- Safe module import


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

    Init.Modules[name] =
        result

    return result
end



-- Core


local Config =
    ImportModule(
        "Config",
        "src/core/Config.lua"
    )

local Connections =
    ImportModule(
        "Connections",
        "src/core/Connections.lua"
    )

local Character =
    ImportModule(
        "Character",
        "src/core/Character.lua"
    )

local Cleanup =
    ImportModule(
        "Cleanup",
        "src/core/Cleanup.lua"
    )

local FeatureManager =
    ImportModule(
        "FeatureManager",
        "src/core/FeatureManager.lua"
    )



-- Utilities


local Helpers =
    ImportModule(
        "Helpers",
        "src/core/Utils/Helpers.lua"
    )

local Math =
    ImportModule(
        "Math",
        "src/core/Utils/Math.lua"
    )

local Players =
    ImportModule(
        "Players",
        "src/core/Utils/Players.lua"
    )



-- Features


local Visuals =
    ImportModule(
        "Visuals",
        "src/core/Features/Visuals.lua"
    )

local ESP =
    ImportModule(
        "ESP",
        "src/core/Features/ESP.lua"
    )

local Combat =
    ImportModule(
        "Combat",
        "src/core/Features/Combat.lua"
    )

local Targeting =
    ImportModule(
        "Targeting",
        "src/core/Features/Targeting.lua"
    )

local GameFeatures =
    ImportModule(
        "GameFeatures",
        "src/core/Features/GameFeatures.lua"
    )



-- UI


local Components =
    ImportModule(
        "Components",
        "src/core/UI/Components.lua"
    )

local Notifications =
    ImportModule(
        "Notifications",
        "src/core/UI/Notifications.lua"
    )

local Window =
    ImportModule(
        "Window",
        "src/core/UI/Window.lua"
    )

local Keybinds =
    ImportModule(
        "Keybinds",
        "src/core/UI/Keybinds.lua"
    )



-- Feature Manager Setup


if type(FeatureManager.Setup) ==
    "function" then

    FeatureManager:Setup({
        Config =
            Config,

        Connections =
            Connections,

        Cleanup =
            Cleanup,
    })
end



-- Feature Registration


local function RegisterFeature(
    name,
    module,
    options
)
    if type(
        FeatureManager.Register
    ) ~= "function" then

        return false
    end

    return FeatureManager:Register(
        name,
        module,
        options
    )
end


RegisterFeature(
    "Visuals",
    Visuals,
    {
        Priority = 10,
    }
)

RegisterFeature(
    "ESP",
    ESP,
    {
        Priority = 20,
    }
)

RegisterFeature(
    "Combat",
    Combat,
    {
        Priority = 30,
        Dependencies = {
            "Targeting",
        },
    }
)

RegisterFeature(
    "Targeting",
    Targeting,
    {
        Priority = 25,
    }
)

RegisterFeature(
    "GameFeatures",
    GameFeatures,
    {
        Priority = 40,
    }
)



-- Feature Manager Start


if type(FeatureManager.Start) ==
    "function" then

    local success, result =
        pcall(function()
            return FeatureManager:Start()
        end)

    if not success then
        error(
            "[Lua Test] FeatureManager failed to start:\n"
                .. tostring(result)
        )
    end
end



-- Status


Init.Initialized = true

print(
    "[Lua Test] Initialized successfully"
)

print(
    "[Lua Test] Version:",
    Init.Version
)

print(
    "[Lua Test] Modules loaded:",
    #(
        FeatureManager.GetNames
        and FeatureManager:GetNames()
        or {}
    )
)



-- Public API


return {
    -- Bootstrap
    Init = Init,

    -- Core
    Config = Config,
    Connections = Connections,
    Character = Character,
    Cleanup = Cleanup,
    FeatureManager = FeatureManager,

    -- Utilities
    Helpers = Helpers,
    Math = Math,
    Players = Players,

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