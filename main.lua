--[[
    Lua Test Script
    main.lua

    Single entry point.

    Responsibilities:
        - Download Init.lua
        - Compile it
        - Execute it safely
        - Validate the returned Core table
        - Report useful errors
]]

local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/"

local INIT_PATH = "src/core/Init.lua"
local INIT_URL = BASE_URL .. INIT_PATH

print("[Lua Test] ===============================")
print("[Lua Test] Starting bootstrap")
print("[Lua Test] URL:", INIT_URL)
print("[Lua Test] ===============================")



-- HTTP


local httpSuccess, source = pcall(function()
    return game:HttpGet(INIT_URL, true)
end)

if not httpSuccess then
    error(
        "[Lua Test] HTTP request failed:\n"
        .. tostring(source)
    )
end

if type(source) ~= "string" or source == "" then
    error(
        "[Lua Test] GitHub returned empty Init.lua"
    )
end

print(
    "[Lua Test] Downloaded Init.lua ("
    .. tostring(#source)
    .. " bytes)"
)



-- Compile


if type(loadstring) ~= "function" then
    error(
        "[Lua Test] loadstring is unavailable in this environment"
    )
end

local loader, compileError =
    loadstring(source)

if not loader then
    error(
        "[Lua Test] Init.lua compilation failed:\n"
        .. tostring(compileError)
    )
end

print("[Lua Test] Init.lua compiled successfully")



-- Execute


local executeSuccess, Core =
    pcall(loader)

if not executeSuccess then
    error(
        "[Lua Test] Init.lua execution failed:\n"
        .. tostring(Core)
    )
end

if type(Core) ~= "table" then
    error(
        "[Lua Test] Init.lua did not return a table"
    )
end



-- Validate


if not Core.Init then
    warn(
        "[Lua Test] Warning: Core.Init is missing"
    )
end

if not Core.FeatureManager then
    warn(
        "[Lua Test] Warning: FeatureManager is missing"
    )
end

if not Core.ESP then
    warn(
        "[Lua Test] Warning: ESP is missing"
    )
end

if not Core.Window then
    warn(
        "[Lua Test] Warning: Window is missing"
    )
end



-- Success


print("[Lua Test] ===============================")
print("[Lua Test] Bootstrap completed")
print("[Lua Test] Version:",
    Core.Init
        and Core.Init.Version
        or "unknown"
)
print("[Lua Test] Initialized:",
    Core.Init
        and tostring(Core.Init.Initialized)
        or "unknown"
)
print("[Lua Test] ===============================")


return Core