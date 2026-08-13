-- Potassium Diagnostic Script
local function Log(msg)
    print(msg)
    warn(msg)
end

Log("\n")
Log("=":rep(50))
Log("[POTASSIUM DIAGNOSTIC] Testing HttpGet")
Log("=":rep(50))

local url = "https://raw.githubusercontent.com/Ninnyyy/roblox-dbd-script/main/main.lua"

Log("[DIAGNOSTIC] Repository: https://github.com/Ninnyyy/roblox-dbd-script")
Log("[DIAGNOSTIC] Testing URL: " .. url)
Log("[DIAGNOSTIC] Executor: Potassium")
Log("=":rep(50))

if not game.HttpGet then
    Log("[DIAGNOSTIC] ✗ FATAL: game:HttpGet is not available")
    Log("[DIAGNOSTIC] Your Potassium version may not support HTTP requests")
    Log("=":rep(50))
    return
end

Log("[DIAGNOSTIC] ✓ HttpGet is available")
Log("[DIAGNOSTIC] Attempting download...")

local success, result = pcall(function()
    return game:HttpGet(url, true)
end)

Log("[DIAGNOSTIC] Execution success: " .. tostring(success))
Log("[DIAGNOSTIC] Result type: " .. type(result))

if success and result and #result > 0 then
    Log("[DIAGNOSTIC] ✓ Download successful!")
    Log("[DIAGNOSTIC] File size: " .. tostring(#result) .. " bytes")
    Log("[DIAGNOSTIC] First 100 characters:")
    Log(string.sub(tostring(result), 1, 100))
    Log("=":rep(50))
    Log("[DIAGNOSTIC] ✓ VERDICT: Repository is accessible")
    Log("[DIAGNOSTIC] ✓ HttpGet works fine")
    Log("[DIAGNOSTIC] ✓ You should be able to run the main script")
else
    Log("[DIAGNOSTIC] ✗ Download failed!")
    Log("[DIAGNOSTIC] Error: " .. tostring(result))
    Log("=":rep(50))
    Log("[DIAGNOSTIC] ✗ VERDICT: Repository is NOT accessible")
    Log("[DIAGNOSTIC] Possible causes:")
    Log("[DIAGNOSTIC]   1. Repository doesn't exist (check GitHub)")
    Log("[DIAGNOSTIC]   2. Repository is PRIVATE (must be PUBLIC)")
    Log("[DIAGNOSTIC]   3. GitHub is down")
    Log("[DIAGNOSTIC]   4. Wrong username in URL")
    Log("[DIAGNOSTIC]   5. Files not uploaded to GitHub yet")
end

Log("=":rep(50))
Log("")
