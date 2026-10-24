--[[
    Aetherist Loader
    GitHub: https://github.com/HolexDeveloper

    Simple Roblox script loader with a local game-ID library (CONFIG).
    - Waits for the game to load and detects the LocalPlayer.
    - If game.PlaceId matches an entry in CONFIG, that game's local script runs.
    - If the PlaceId does NOT match any supported game, the loader simply runs
      the local Universal_Script (no extra fetching needed).
]]

-- =====================================================================
-- LOCAL SCRIPTS (stored right here inside loader.lua)
-- =====================================================================

-- Universal script: runs for every game that is NOT in CONFIG below
local Universal_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Universal.lua", true))()
]]

-- Entrenched script: runs only when LocalPlayer is detected inside Entrenched WW1
local Entrenched_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Entrenched.lua", true))()
]]

-- FPV Drone Battlefield script: runs only inside FPV Drone Battlefield
local FPV_Drone_Battlefield_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/FPVdronebattlefield.txt", true))()
]]

-- House of the Locust script: runs only inside House of the Locust
local House_of_the_Locust_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Houseofthelocust.lua", true))()
]]

-- Monochrome script: runs only inside Monochrome
local Monochrome_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/monochrome.lua", true))()
]]

-- =====================================================================
-- LOCAL LIBRARY OF SUPPORTED GAMES
-- =====================================================================
local CONFIG = {
    [3678761576] = { -- Entrenched WW1
        title  = "Entrenched WW1",
        page   = "https://www.roblox.com/games/3678761576/ENTRENCHED",
        script = Entrenched_Script,
    },
    [100661692738190] = { -- FPV Drone Battlefield
        title  = "FPV Drone Battlefield",
        page   = "https://www.roblox.com/games/100661692738190/FPV-Drone-Battlefield",
        script = FPV_Drone_Battlefield_Script,
    },
    [86247128610772] = { -- House of the Locust
        title  = "House of the Locust",
        page   = "https://www.roblox.com/games/86247128610772/House-of-the-Locust",
        script = House_of_the_Locust_Script,
    },
    [134208374070897] = { -- Monochrome
        title  = "Monochrome",
        page   = "https://www.roblox.com/games/134208374070897/MONOCHROME",
        script = Monochrome_Script,
    },
}

-- =====================================================================
-- WAIT FOR GAME TO LOAD / DETECT LOCAL PLAYER
-- =====================================================================
repeat
    task.wait()
until game:IsLoaded()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

if not LocalPlayer then
    warn("[Aetherist] LocalPlayer not found, cannot continue.")
    return
end

-- Use game.PlaceId, NOT game.GameId (which often returns the Universe ID)
local currentPlaceId = game.PlaceId

print(("[Aetherist] Loaded. PlaceId: %d | Player: %s"):format(currentPlaceId, LocalPlayer.Name))

-- =====================================================================
-- RESOLVE SCRIPT (game-specific or local Universal fallback)
-- =====================================================================
local data = CONFIG[currentPlaceId]
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
