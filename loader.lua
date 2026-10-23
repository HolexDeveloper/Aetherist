--[[
    Aetherist Loader
    GitHub: https://github.com/HolexDeveloper

    Simple Roblox script loader with a local game-ID library (CONFIG).
    - If the current game's GameId matches an entry in CONFIG, that game's
      script is fetched and executed.
    - If the GameId does NOT match any supported game, the loader falls back to:
      loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Entrenched.lua", true))()
]]

-- =====================================================================
-- LOCAL LIBRARY OF SUPPORTED GAMES
-- =====================================================================
local CONFIG = {
    [3678761576] = {
        title = "Entrenched WW1",
        url = "https://www.roblox.com/games/3678761576/ENTRENCHED",
        script = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Entrenched.lua",
    },
}

-- Fallback script used when the GameId is not found in CONFIG
local FALLBACK_SCRIPT = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Entrenched.lua"

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

print(("[Aetherist] Loaded. GameId: %d | Place: %s"):format(game.GameId, LocalPlayer.Name))

-- =====================================================================
-- RESOLVE SCRIPT URL
-- =====================================================================
local data = CONFIG[game.GameId]
local scriptUrl

if data then
    print(("[Aetherist] Supported game detected: %s"):format(tostring(data.title)))
    scriptUrl = data.script
else
    print("[Aetherist] Unsupported game, running fallback script...")
    scriptUrl = FALLBACK_SCRIPT
end

-- =====================================================================
-- FETCH & EXECUTE
-- =====================================================================
local ok, err = pcall(function()
    local source = game:HttpGet(scriptUrl, true)
    local chunk = loadstring(source)
    if type(chunk) ~= "function" then
        error("loadstring did not return a function")
    end
    chunk()
end)

if not ok then
    warn("[Aetherist] Failed to load script: " .. tostring(err))
end
