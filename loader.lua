--[[
    Aetherist Loader (multigame + subplace support)
    GitHub: https://github.com/HolexDeveloper

    Simple Roblox script loader with a local game library (GAMES/CONFIG).
    - Waits for the game to load and detects the LocalPlayer.
    - If game.PlaceId matches ANY id listed in a game entry, that game's script runs.
    - Optional: if an entry has "gameId" (universe id), EVERY subplace of that
      game matches automatically — no need to list each subplace id.
    - If nothing matches, the loader runs the local Universal_Script fallback.

    FIX NOTE:
    Lua does NOT allow multiple ids in one table key, e.g.
        [id1,id2,id3] = { ... }      -- syntax error -> whole file fails to load
    The library is now a GAMES list where each entry holds an "ids" array,
    and a reverse-lookup map (CONFIG) is built from it at runtime.
]]

-- =====================================================================
-- LOCAL SCRIPTS (stored right here inside loader.lua)
-- =====================================================================

-- Universal script: runs for every game that is NOT matched below
local Universal_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Universal.lua", true))()
]]

-- Entrenched script: runs only inside Entrenched WW1
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
-- LOCAL LIBRARY OF SUPPORTED GAMES  (MULTI-GAME / SUBPLACE SUPPORT)
-- =====================================================================
-- Each entry:
--   ids    = { mainGameId, subplaceId1, subplaceId2, ... }  (list every place)
--   gameId = OPTIONAL universe id -> auto-matches ALL subplaces of the game.
--            Get it once by executing:  print(game.GameId)  inside the game.
local GAMES = {
    {
        title  = "Entrenched WW1",
        ids    = { 3678761576 },
        script = Entrenched_Script,
    },
    {
        title  = "FPV Drone Battlefield",
        ids    = { 100661692738190 },
        script = FPV_Drone_Battlefield_Script,
    },
    {
        title  = "House of the Locust",
        ids    = {
            10530261598,        -- lobby / main game (as you provided)
            -- 86247128610772, -- NOTE: this is the id inside your game URL.
            --                 -- Uncomment it if it is a real place of this game.
            -- SUBPLACE_ID_2,  -- <- paste subplace 2 id here
            -- SUBPLACE_ID_3,  -- <- paste subplace 3 id here
        },
        -- gameId = 0000000000, -- optional: auto-match ALL subplaces
        script = House_of_the_Locust_Script,
    },
    {
        title  = "Monochrome",
        ids    = {
            134208374070897,    -- main game
            10624691669,        -- subplace 1
            -- SUBPLACE_ID_2,  -- <- paste subplace 2 id here (you mentioned 2 subplaces)
        },
        -- gameId = 0000000000, -- optional: auto-match ALL subplaces
        script = Monochrome_Script,
    },
}

-- =====================================================================
-- BUILD REVERSE LOOKUP MAPS (do not edit below this line to add games)
-- =====================================================================
-- CONFIG[placeId]     -> game entry   (exact PlaceId match)
-- BY_GAME_ID[gameId]  -> game entry   (universe-wide fallback match)
local CONFIG = {}
local BY_GAME_ID = {}

for _, entry in ipairs(GAMES) do
    for _, id in ipairs(entry.ids) do
        CONFIG[tonumber(id)] = entry
    end
    if entry.gameId then
        BY_GAME_ID[tonumber(entry.gameId)] = entry
    end
end

-- =====================================================================
-- WAIT FOR GAME TO LOAD / DETECT LOCAL PLAYER & PLACE ID
-- =====================================================================
local Players = game:GetService("Players")

-- 1. Robustly wait for LocalPlayer to exist
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    print("[Aetherist] Waiting for LocalPlayer...")
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

-- 2. Robustly wait for game to load AND PlaceId to be valid (not 0)
--    Some executors report PlaceId as 0 briefly before it updates to the real ID.
repeat
    task.wait(0.1)
until game:IsLoaded() and game.PlaceId ~= 0

-- 3. Ensure numbers to prevent any type mismatches in the lookup
local currentPlaceId = tonumber(game.PlaceId)
local currentGameId  = tonumber(game.GameId)

print(("[Aetherist] Environment Ready. PlaceId: %d | GameId: %d | Player: %s")
    :format(currentPlaceId, currentGameId, LocalPlayer.Name))

-- =====================================================================
-- RESOLVE SCRIPT (game-specific or local Universal fallback)
-- =====================================================================
-- 1) exact PlaceId match (main game or a listed subplace)
-- 2) universe GameId match (covers every subplace when gameId is set)
local data = CONFIG[currentPlaceId] or BY_GAME_ID[currentGameId]
local scriptSource

if data then
    print(("[Aetherist] ✅ Supported game detected: %s (PlaceId: %d)"):format(data.title, currentPlaceId))
    scriptSource = data.script
else
    print(("[Aetherist] ⚠️ Unsupported game (PlaceId: %d). Running local Universal_Script fallback..."):format(currentPlaceId))
    scriptSource = Universal_Script
end

-- =====================================================================
-- EXECUTE
-- =====================================================================
local ok, err = pcall(function()
    local chunk = loadstring(scriptSource)
    if type(chunk) ~= "function" then
        error("loadstring did not return a function. Chunk: " .. tostring(chunk))
    end
    chunk()
end)

if not ok then
    warn("[Aetherist] ❌ Failed to run script: " .. tostring(err))
end
