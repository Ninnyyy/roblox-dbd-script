--[[
    Lua Test Script
    main.lua
    Optimized for Potassium Executor
]]

local function Log(msg)
    print(msg)
    if game:FindFirstChildOfClass("UserInputService") then
        warn(msg)
    end
end

Log("\n")
Log("=":rep(50))
Log("[POTASSIUM] Roblox DBD Script Bootstrap")
Log("=":rep(50))
Log("[POTASSIUM] Executor: Potassium")
Log("[POTASSIUM] Time: " .. tostring(os.date("%H:%M:%S")))

local BASE_URL = "https://raw.githubusercontent.com/Ninnyyy/roblox-dbd-script/main/"
local INIT_PATH = "src/core/Init.lua"
local INIT_URL = BASE_URL .. INIT_PATH

Log("[POTASSIUM] Repository: https://github.com/Ninnyyy/roblox-dbd-script")
Log("[POTASSIUM] Loading: " .. INIT_PATH)
Log("=":rep(50))

-- Test HttpGet availability
if not game.HttpGet then
    Log("[POTASSIUM] ✗ ERROR: game:HttpGet is not available")
    Log("[POTASSIUM] ✗ Your executor may not support HTTP requests")
    Log("=":rep(50))
    error("HttpGet not available in this executor")
end

Log("[POTASSIUM] ✓ HttpGet is available")

-- Attempt HTTP download
local httpSuccess, source
local attempts = 0
local maxAttempts = 3

while attempts < maxAttempts do
    attempts = attempts + 1
    Log("[POTASSIUM] Attempt " .. attempts .. " to download Init.lua...")
    
    httpSuccess, source = pcall(function()
        return game:HttpGet(INIT_URL, true)
    end)
    
    if httpSuccess and source and #source > 0 then
        Log("[POTASSIUM] ✓ Download successful (" .. tostring(#source) .. " bytes)")
        break
    else
        Log("[POTASSIUM] ✗ Download failed (attempt " .. attempts .. "/" .. maxAttempts .. ")")
        if source then
            Log("[POTASSIUM] Error: " .. tostring(source))
        end
        if attempts < maxAttempts then
            task.wait(1)
        end
    end
end

if not httpSuccess then
    Log("[POTASSIUM] ✗ ERROR: Failed to download Init.lua after " .. maxAttempts .. " attempts")
    Log("[POTASSIUM] ✗ Possible causes:")
    Log("[POTASSIUM]   - Repository does not exist: https://github.com/Ninnyyy/roblox-dbd-script")
    Log("[POTASSIUM]   - Repository is private (must be PUBLIC)")
    Log("[POTASSIUM]   - GitHub is temporarily unavailable")
    Log("[POTASSIUM]   - Incorrect username in URL")
    Log("=":rep(50))
    error("HttpGet failed: " .. tostring(source))
end

if type(source) ~= "string" or #source == 0 then
    Log("[POTASSIUM] ✗ ERROR: GitHub returned empty file")
    Log("[POTASSIUM] ✗ Check that main.lua exists at: " .. INIT_URL)
    Log("=":rep(50))
    error("Empty response from GitHub")
end

-- Verify source is valid Lua
if not source:match("local") and not source:match("function") and not source:match("return") then
    Log("[POTASSIUM] ⚠ WARNING: Downloaded file doesn't look like Lua code")
    Log("[POTASSIUM] First 100 chars: " .. string.sub(source, 1, 100))
end

Log("[POTASSIUM] ✓ Compiling Init.lua...")

-- Compile
local loader, compileError = loadstring(source)

if not loader then
    Log("[POTASSIUM] ✗ ERROR: Failed to compile Init.lua")
    Log("[POTASSIUM] Compile error: " .. tostring(compileError))
    Log("=":rep(50))
    error("Compilation failed: " .. tostring(compileError))
end

Log("[POTASSIUM] ✓ Compilation successful")
Log("[POTASSIUM] ✓ Executing Init.lua...")

-- Execute
local executeSuccess, Core = pcall(loader)

if not executeSuccess then
    Log("[POTASSIUM] ✗ ERROR: Execution failed")
    Log("[POTASSIUM] Runtime error: " .. tostring(Core))
    Log("=":rep(50))
    error("Execution failed: " .. tostring(Core))
end

if type(Core) ~= "table" then
    Log("[POTASSIUM] ✗ ERROR: Init.lua did not return a table")
    Log("[POTASSIUM] Returned type: " .. type(Core))
    Log("=":rep(50))
    error("Invalid return type: " .. type(Core))
end

Log("[POTASSIUM] ✓ Core module loaded successfully")
Log("=":rep(50))
Log("[POTASSIUM] ✓ BOOTSTRAP COMPLETE")

if Core.Init then
    Log("[POTASSIUM] Version: " .. tostring(Core.Init.Version or "unknown"))
    Log("[POTASSIUM] Initialized: " .. tostring(Core.Init.Initialized))
    Log("[POTASSIUM] Running: " .. tostring(Core.Init.Running))
end

if Core.Init and Core.Init.Errors and #Core.Init.Errors > 0 then
    Log("[POTASSIUM] ⚠ Module load errors detected:")
    for i, err in ipairs(Core.Init.Errors) do
        Log("[POTASSIUM] [" .. i .. "] " .. tostring(err.Path) .. ": " .. tostring(err.Error))
    end
end

Log("=":rep(50))
Log("[POTASSIUM] ✓ Script loaded and ready")
Log("[POTASSIUM] → Press RIGHT SHIFT to toggle the menu")
Log("[POTASSIUM] → Check console for any errors above")
Log("=":rep(50))
Log("")

return Core