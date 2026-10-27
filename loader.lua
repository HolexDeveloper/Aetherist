--[[
    Aetherist Loader (UI edition — Rayfield Gen 2)
    GitHub: https://github.com/HolexDeveloper

    - No auto-detection: a Rayfield window lists every game as a button.
    - Click a button to load that game's script, regardless of where you are.
    - AOFL / Aisles-Of-The-Locust is included as a normal button.
    - The Discord subtitle button and a Universal fallback are also included.
]]

-- =====================================================================
-- SERVICES / LOCALS
-- =====================================================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

repeat task.wait(0.1) until game:IsLoaded()

-- =====================================================================
-- SCRIPT SOURCES
-- =====================================================================
local SCRIPTS = {
    Universal                = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Universal.lua", true))()',
    Entrenched               = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Entrenched.lua", true))()',
    FPVDroneBattlefield      = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/FPVdronebattlefield.txt", true))()',
    HouseOfTheLocust         = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Houseofthelocust.lua", true))()',
    Monochrome               = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/monochrome.lua", true))()',
    AislesOfTheLocust        = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/AOFL.lua", true))()',
}

-- Buttons shown in the UI, in order: {display name, key into SCRIPTS, icon}
local GAME_LIST = {
    { "Entrenched WW1",        "Entrenched",         "swords"     },
    { "FPV Drone Battlefield", "FPVDroneBattlefield","plane"      },
    { "House of the Locust",   "HouseOfTheLocust",   "bug"        },
    { "Monochrome",            "Monochrome",         "contrast"   },
    { "Aisles Of The Locust",  "AislesOfTheLocust",  "store"      },
    { "Universal (any game)",  "Universal",          "globe"      },
}

local DISCORD_LINK = "https://discord.gg/q3Jm9gNpGe"

-- =====================================================================
-- LOAD RAYFIELD
-- =====================================================================
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Aetherist",
    Subtitle = "Multigame Loader",
    Icon = "zap",
    Badge = { Text = "us-en", Icon = "messages-square" },
    LoadingTitle = "Aetherist",
    LoadingSubtitle = "by HolexDeveloper",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AetheristLoader",
        FileName = "Aetherist",
    },
})

-- =====================================================================
-- GAME SELECT TAB
-- =====================================================================
local GamesTab = Window:CreateTab("Games", "gamepad-2")
GamesTab:CreateSection("Load a Script")

-- Track what's currently running so we can warn about double-loads
local currentlyLoaded = nil

local function runScript(displayName, key)
    local src = SCRIPTS[key]
    if not src then
        Rayfield:Notify({
            Title = "Error",
            Content = "No script source found for " .. displayName .. ".",
            Duration = 5,
            Image = "alert-triangle",
        })
        return
    end

    if currentlyLoaded == key then
        Rayfield:Notify({
            Title = "Already loaded",
            Content = displayName .. " is already running. Re-injecting can cause conflicts.",
            Duration = 5,
            Image = "info",
        })
        return
    end

    Rayfield:Notify({
        Title = "Loading...",
        Content = "Fetching and executing " .. displayName .. "...",
        Duration = 4,
        Image = "loader",
    })

    local ok, err = pcall(function()
        loadstring(src)()
    end)

    if ok then
        currentlyLoaded = key
        Rayfield:Notify({
            Title = "Loaded",
            Content = displayName .. " loaded successfully.",
            Duration = 5,
            Image = "check",
        })
        print(("[Aetherist] Loaded %s"):format(displayName))
    else
        Rayfield:Notify({
            Title = "Failed",
            Content = displayName .. " failed: " .. tostring(err),
            Duration = 7,
            Image = "alert-triangle",
        })
        warn("[Aetherist] Failed to load " .. displayName .. ": " .. tostring(err))
    end
end

for _, entry in ipairs(GAME_LIST) do
    local displayName, key, icon = entry[1], entry[2], entry[3]
    GamesTab:CreateButton({
        Name = "Load: " .. displayName,
        Icon = icon,
        Callback = function()
            runScript(displayName, key)
        end,
    })
end

-- =====================================================================
-- INFO TAB
-- =====================================================================
local InfoTab = Window:CreateTab("Info", "info")

InfoTab:CreateSection("Links")

InfoTab:CreateButton({
    Name = "Copy Discord Invite",
    Icon = "copy",
    Callback = function()
        local copied = false
        pcall(function()
            if type(setclipboard) == "function" then setclipboard(DISCORD_LINK) copied = true
            elseif type(set_clipboard) == "function" then set_clipboard(DISCORD_LINK) copied = true
            elseif type(writeclipboard) == "function" then writeclipboard(DISCORD_LINK) copied = true end
        end)
        Rayfield:Notify({
            Title = copied and "Copied!" or "Clipboard unsupported",
            Content = copied and DISCORD_LINK or ("Discord link: " .. DISCORD_LINK),
            Duration = 5,
            Image = "copy",
        })
        if not copied then print("[Aetherist] Discord: " .. DISCORD_LINK) end
    end,
})

InfoTab:CreateSection("Session")

InfoTab:CreateParagraph({
    Title = "Current Game",
    Content = ("PlaceId: %d\nGameId: %d\nPlayer: %s"):format(
        game.PlaceId, game.GameId, LocalPlayer.Name
    ),
})

-- =====================================================================
-- DONE
-- =====================================================================
Rayfield:Notify({
    Title = "Aetherist loaded",
    Content = "Pick a game from the Games tab to load its script. Press K to toggle the UI.",
    Duration = 7,
    Image = "zap",
})

Rayfield:LoadConfiguration()
