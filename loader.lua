--[[
    Aetherist Loader
    GitHub: https://github.com/HolexDeveloper

    Simple Roblox script loader with a local game-ID library (CONFIG).
    - Waits for the game to load and detects the LocalPlayer.
    - If game.GameId matches an entry in CONFIG, that game's local script runs.
    - If the GameId does NOT match any supported game, the loader simply runs
      the local Universal_Script (no extra fetching needed):
      loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Universal.lua", true))()
]]

-- =====================================================================
-- LOCAL SCRIPTS (stored right here inside loader.lua)
-- =====================================================================

-- Universal script: runs for every game that is NOT in CONFIG below
local Universal_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Universal.lua",true))()
]]

-- Entrenched script: runs only when LocalPlayer is detected inside Entrenched WW1
local Entrenched_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Entrenched.lua",true))()
]]

-- =====================================================================
-- LOCAL LIBRARY OF SUPPORTED GAMES
-- =====================================================================
local CONFIG = {
    [3678761576] = { -- Entrenched WW1 - https://www.roblox.com/games/3678761576/ENTRENCHED
        title  = "Entrenched WW1",
        page   = "https://www.roblox.com/games/3678761576/ENTRENCHED",
        script = Entrenched_Script,
    },
}

-- =====================================================================
-- WAIT FOR GAME TO LOAD / DETECT LOCAL PLAYER
-- =====================================================================
repeat
    task.wait()
until game:IsLoaded()

local LocalPlayer = game:GetService("Players").LocalPlayer
if not LocalPlayer then
    warn("[Aetherist] LocalPlayer not found, cannot continue.")
    return
end

print(("[Aetherist] Loaded. GameId: %d | Player: %s"):format(game.GameId, LocalPlayer.Name))

-- =====================================================================
-- RESOLVE SCRIPT (game-specific or local Universal fallback)
-- =====================================================================
local data = CONFIG[game.GameId]
local scriptSource

if data then
    print(("Aetherist | Supported game detected: %s"):format(tostring(data.title)))
    scriptSource = data.script
else
    print("Aetherist | Unsupported game, running local Universal_Script...")
    scriptSource = Universal_Script
end

-- =====================================================================
-- EXECUTE
-- =====================================================================
local ok, err = pcall(function()
    local chunk = loadstring(scriptSource)
    if type(chunk) ~= "function" then
        error("loadstring did not return a function")
    end
    chunk()
end)

if not ok then
    warn("[Aetherist] Failed to run script: " .. tostring(err))
end
