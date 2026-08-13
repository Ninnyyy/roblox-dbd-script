local BASE_URL =
    "https://raw.githubusercontent.com/Ninnyyy/Lua-Test-Script/main/"

local InitURL = BASE_URL .. "src/core/Init.lua"

local success, source = pcall(function()
    return game:HttpGet(InitURL, true)
end)

if not success then
    error(
        "[Lua Test] Failed to download Init.lua:\n"
            .. tostring(source)
    )
end

local loader, compileError = loadstring(source)

if not loader then
    error(
        "[Lua Test] Failed to compile Init.lua:\n"
            .. tostring(compileError)
    )
end

local executed, Core = pcall(loader)

if not executed then
    error(
        "[Lua Test] Failed to initialize:\n"
            .. tostring(Core)
    )
end

if type(Core) ~= "table" then
    error("[Lua Test] Init.lua did not return a module table")
end

print("[Lua Test] =======================================")
print("[Lua Test] Lua Test Script started")
print("[Lua Test] =======================================")

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

-- Register the available features.
if Core.GameFeatures then
    Core.GameFeatures:Register("Visuals", {
        Enabled = true,

        Start = function()
            if Core.Visuals and Core.Visuals.Enable then
                Core.Visuals:Enable()
            end
        end,

        Stop = function()
            if Core.Visuals and Core.Visuals.Disable then
                Core.Visuals:Disable()
            end
        end,
    })

    Core.GameFeatures:Register("ESP", {
        Enabled = false,

        Start = function()
            if Core.ESP then
                Core.ESP:Enable()
            end
        end,

        Stop = function()
            if Core.ESP then
                Core.ESP:Disable()
            end
        end,
    })

    Core.GameFeatures:Register("Movement", {
        Enabled = true,

        Start = function()
            if Core.Movement then
                Core.Movement:SetEnabled(true)
            end
        end,

        Stop = function()
            if Core.Movement then
                Core.Movement:SetEnabled(false)
            end
        end,
    })
end

-- Initialize UI.
SafeCall("Window", function()
    if Core.Window and Core.Window.Initialize then
        Core.Window:Initialize(Core)
    end
end)

SafeCall("Keybinds", function()
    if Core.Keybinds and Core.Keybinds.Initialize then
        Core.Keybinds:Initialize(Core)
    end
end)

SafeCall("Notifications", function()
    if Core.Notifications
        and Core.Notifications.Info then

        Core.Notifications:Info(
            "Lua Test",
            "Framework initialized"
        )
    end
end)

print("[Lua Test] Initialization complete")

return Core