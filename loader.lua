--[[
    Aetherist Loader (multigame + subplace support + loading screen)
    GitHub: https://github.com/HolexDeveloper

    Simple Roblox script loader with a local game library (GAMES/CONFIG).
    - Waits for the game to load and detects the LocalPlayer.
    - If game.PlaceId matches ANY id listed in a game entry, that game's script runs.
    - Optional: if an entry has "gameId" (universe id), EVERY subplace of that
      game matches automatically — no need to list each subplace id.
    - If nothing matches, the loader runs the local Universal_Script fallback.
    - Shows a full-screen loading screen with steps:
        1) "Fetching gameID..."     -> fetches the universe ID via Roblox API
        2) "Fetching script..."     -> resolves which script to run
        3) "Loading Script for %s"  -> fetches the game name via Roblox API
                                       and uses it in the final status text.

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

-- Aisles-Of-The-Locust script: runs only inside the game with PlaceId 10766578375
local Aisles_Of_The_Locust_Script = [[
loadstring(game:HttpGet("https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/AOFL.lua", true))()
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
    {
        title  = "Aisles-Of-The-Locust",
        ids    = { 10766578375 }, -- Aisles-Of-The-Locust is ONLY executable on this PlaceId
        script = Aisles_Of_The_Locust_Script,
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
-- SERVICES
-- =====================================================================
local Players            = game:GetService("Players")
local CoreGui            = game:GetService("CoreGui")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService        = game:GetService("HttpService")

-- =====================================================================
-- WAIT FOR GAME TO LOAD / DETECT LOCAL PLAYER & PLACE ID
-- =====================================================================
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    print("[Aetherist] Waiting for LocalPlayer...")
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

repeat
    task.wait(0.1)
until game:IsLoaded() and game.PlaceId ~= 0

local currentPlaceId = tonumber(game.PlaceId)
local currentGameId  = tonumber(game.GameId)

print(("[Aetherist] Environment Ready. PlaceId: %d | GameId: %d | Player: %s")
    :format(currentPlaceId, currentGameId, LocalPlayer.Name))

-- =====================================================================
-- LOADING SCREEN (full-screen UI, tween-animated)
-- =====================================================================
local DISCORD_LINK = "https://discord.gg/q3Jm9gNpGe"

-- Try to copy text to the clipboard; fall back to printing it.
local function copyOrPrint(text)
    local copied = false
    pcall(function()
        if type(setclipboard) == "function" then
            setclipboard(text)
            copied = true
        elseif type(set_clipboard) == "function" then
            set_clipboard(text)
            copied = true
        elseif type(writeclipboard) == "function" then
            writeclipboard(text)
            copied = true
        end
    end)
    if copied then
        print("[Aetherist] Discord link copied to clipboard: " .. text)
    else
        print("[Aetherist] Clipboard not supported. Discord link: " .. text)
    end
end

local function buildLoadingScreen()
    -- Pick a parent that can hold a ScreenGui. Prefer CoreGui; fall back to PlayerGui.
    local parent
    local okCore = pcall(function()
        _ = CoreGui.Name
        parent = CoreGui
    end)
    if not okCore or not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Remove any previous loader UI
    pcall(function()
        local old = parent:FindFirstChild("AetheristLoader")
        if old then old:Destroy() end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AetheristLoader"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 999999
    screenGui.Parent = parent

    -- =================================================================
    -- Fullscreen animated background
    -- =================================================================
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.fromScale(1, 1)
    bg.Position = UDim2.fromScale(0, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    bg.BorderSizePixel = 0
    bg.ZIndex = 1
    bg.Parent = screenGui

    -- Animated radial-ish gradient on the background
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Name = "BgGradient"
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0.00, Color3.fromRGB(28, 32, 48)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(14, 14, 22)),
        ColorSequenceKeypoint.new(1.00, Color3.fromRGB(6, 6, 10)),
    })
    bgGradient.Rotation = 35
    bgGradient.Parent = bg

    -- Slowly rotate the gradient for a subtle live effect
    task.spawn(function()
        local rot = 35
        while bg and bg.Parent do
            rot = rot + 0.15
            if rot >= 360 then rot = rot - 360 end
            pcall(function() bgGradient.Rotation = rot end)
            task.wait(0.05)
        end
    end)

    -- Top accent line (slides in from the left)
    local accent = Instance.new("Frame")
    accent.Name = "Accent"
    accent.Size = UDim2.fromScale(0, 0.006)
    accent.Position = UDim2.fromScale(0, 0)
    accent.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    accent.BorderSizePixel = 0
    accent.ZIndex = 2
    accent.Parent = bg

    local accentGlow = Instance.new("UIStroke")
    accentGlow.Color = Color3.fromRGB(120, 180, 255)
    accentGlow.Thickness = 1.5
    accentGlow.Transparency = 0.4
    accentGlow.Parent = accent

    -- =================================================================
    -- Center container (everything visible slides / scales in together)
    -- =================================================================
    local center = Instance.new("Frame")
    center.Name = "Center"
    center.AnchorPoint = Vector2.new(0.5, 0.5)
    center.Position = UDim2.fromScale(0.5, 0.5)
    center.Size = UDim2.fromScale(0, 0) -- start collapsed; tweened open
    center.BackgroundTransparency = 1
    center.ZIndex = 3
    center.Parent = bg

    -- BIG title: Aetherist
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.AnchorPoint = Vector2.new(0.5, 1)
    title.Position = UDim2.fromScale(0.5, 0.45)
    title.Size = UDim2.fromScale(2.2, 0.18)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.TextScaled = true
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Aetherist"
    title.ZIndex = 4
    title.Parent = center

    -- Title glow / outline
    local titleStroke = Instance.new("UIStroke")
    titleStroke.Color = Color3.fromRGB(120, 180, 255)
    titleStroke.Thickness = 1.2
    titleStroke.Transparency = 0.25
    titleStroke.Parent = title

    -- Subtitle: clickable Discord link
    local subtitle = Instance.new("TextButton")
    subtitle.Name = "Subtitle"
    subtitle.AnchorPoint = Vector2.new(0.5, 0)
    subtitle.Position = UDim2.fromScale(0.5, 0.48)
    subtitle.Size = UDim2.fromScale(2.0, 0.06)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextScaled = true
    subtitle.TextColor3 = Color3.fromRGB(150, 180, 255)
    subtitle.Text = DISCORD_LINK
    subtitle.AutoButtonColor = false
    subtitle.ZIndex = 4
    subtitle.Parent = center

    -- Subtitle underline (animates width on hover / click)
    local underline = Instance.new("Frame")
    underline.Name = "Underline"
    underline.AnchorPoint = Vector2.new(0.5, 0)
    underline.Position = UDim2.fromScale(0.5, 1)
    underline.Size = UDim2.fromScale(0, 0.08)
    underline.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    underline.BorderSizePixel = 0
    underline.ZIndex = 5
    underline.Parent = subtitle

    local underlineCorner = Instance.new("UICorner")
    underlineCorner.CornerRadius = UDim.new(1, 0)
    underlineCorner.Parent = underline

    -- Hover effects for subtitle (color + underline grow)
    subtitle.MouseEnter:Connect(function()
        TweenService:Create(subtitle, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        TweenService:Create(underline, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(1, 0.08) }):Play()
    end)
    subtitle.MouseLeave:Connect(function()
        TweenService:Create(subtitle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextColor3 = Color3.fromRGB(150, 180, 255) }):Play()
        TweenService:Create(underline, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(0, 0.08) }):Play()
    end)
    subtitle.MouseButton1Click:Connect(function()
        -- Click "pulse" animation then copy / print
        TweenService:Create(subtitle, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
        local pulse = Instance.new("Frame")
        pulse.AnchorPoint = Vector2.new(0.5, 0.5)
        pulse.Position = UDim2.fromScale(0.5, 0.5)
        pulse.Size = UDim2.fromScale(0, 0)
        pulse.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
        pulse.BackgroundTransparency = 0.5
        pulse.BorderSizePixel = 0
        pulse.ZIndex = 3
        pulse.Parent = subtitle
        local pulseCorner = Instance.new("UICorner")
        pulseCorner.CornerRadius = UDim.new(1, 0)
        pulseCorner.Parent = pulse
        TweenService:Create(pulse, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Size = UDim2.fromScale(2.5, 3.5), BackgroundTransparency = 1 }):Play()
        task.delay(0.55, function() pcall(function() pulse:Destroy() end) end)
        copyOrPrint(DISCORD_LINK)
    end)

    -- Status text (the changing step text)
    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.AnchorPoint = Vector2.new(0.5, 0)
    status.Position = UDim2.fromScale(0.5, 0.62)
    status.Size = UDim2.fromScale(2.0, 0.05)
    status.BackgroundTransparency = 1
    status.Font = Enum.Font.GothamMedium
    status.TextScaled = true
    status.TextColor3 = Color3.fromRGB(220, 220, 230)
    status.Text = "Initializing..."
    status.ZIndex = 4
    status.Parent = center

    -- Progress bar background
    local barBg = Instance.new("Frame")
    barBg.Name = "BarBackground"
    barBg.AnchorPoint = Vector2.new(0.5, 0)
    barBg.Position = UDim2.fromScale(0.5, 0.72)
    barBg.Size = UDim2.fromScale(1.6, 0.012)
    barBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    barBg.BorderSizePixel = 0
    barBg.ZIndex = 4
    barBg.Parent = center

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = barBg

    local barFill = Instance.new("Frame")
    barFill.Name = "BarFill"
    barFill.Size = UDim2.fromScale(0, 1)
    barFill.Position = UDim2.fromScale(0, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
    barFill.BorderSizePixel = 0
    barFill.ZIndex = 5
    barFill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = barFill

    -- Glow at the leading edge of the bar fill (right edge as the bar grows)
    local barGlow = Instance.new("ImageLabel")
    barGlow.Name = "BarGlow"
    barGlow.AnchorPoint = Vector2.new(0.5, 0.5)
    barGlow.Position = UDim2.fromScale(1, 0.5)
    barGlow.Size = UDim2.fromOffset(80, 80)
    barGlow.BackgroundTransparency = 1
    barGlow.Image = "rbxassetid://5028857084" -- soft radial glow
    barGlow.ImageColor3 = Color3.fromRGB(150, 200, 255)
    barGlow.ImageTransparency = 0.15
    barGlow.ZIndex = 6
    barGlow.Parent = barFill

    -- Percentage label
    local percent = Instance.new("TextLabel")
    percent.Name = "Percent"
    percent.AnchorPoint = Vector2.new(0.5, 0)
    percent.Position = UDim2.fromScale(0.5, 0.76)
    percent.Size = UDim2.fromScale(1.4, 0.04)
    percent.BackgroundTransparency = 1
    percent.Font = Enum.Font.Gotham
    percent.TextScaled = true
    percent.TextColor3 = Color3.fromRGB(140, 160, 200)
    percent.Text = "0%"
    percent.ZIndex = 4
    percent.Parent = center

    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Name = "Footer"
    footer.AnchorPoint = Vector2.new(0.5, 1)
    footer.Position = UDim2.fromScale(0.5, 0.98)
    footer.Size = UDim2.fromScale(2.0, 0.035)
    footer.BackgroundTransparency = 1
    footer.Font = Enum.Font.Gotham
    footer.TextScaled = true
    footer.TextColor3 = Color3.fromRGB(110, 110, 130)
    footer.Text = "github.com/HolexDeveloper/Aetherist  |  click the discord link to copy"
    footer.ZIndex = 4
    footer.Parent = center

    -- =================================================================
    -- Entrance animation: open the center container + slide the accent
    -- =================================================================
    TweenService:Create(accent, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(1, 0.006) }):Play()

    TweenService:Create(center, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(0.5, 0.7) }):Play()

    -- Title shimmer: pulse the stroke transparency for a glowy effect
    task.spawn(function()
        local forward = true
        while title and title.Parent do
            TweenService:Create(titleStroke,
                TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                { Transparency = forward and 0.05 or 0.45 }):Play()
            forward = not forward
            task.wait(1.4)
        end
    end)

    return screenGui, status, barFill, percent, barGlow, center
end

local screenGui, statusLabel, barFill, percentLabel, barGlow, centerContainer = buildLoadingScreen()

local function setStatus(text, progress)
    if statusLabel then
        statusLabel.Text = text
        print("[Aetherist] " .. text)
    end
    if barFill and progress then
        pcall(function()
            TweenService:Create(
                barFill,
                TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { Size = UDim2.fromScale(progress, 1) }
            ):Play()
        end)
    end
    if percentLabel and progress then
        pcall(function()
            TweenService:Create(
                percentLabel,
                TweenInfo.new(0.2),
                { TextColor3 = Color3.fromRGB(255, 255, 255) }
            ):Play()
            percentLabel.Text = string.format("%d%%", math.floor(progress * 100 + 0.5))
            task.delay(0.25, function()
                pcall(function()
                    TweenService:Create(percentLabel, TweenInfo.new(0.4),
                        { TextColor3 = Color3.fromRGB(140, 160, 200) }):Play()
                end)
            end)
        end)
    end
    task.wait(0.4)
end

-- =====================================================================
-- HELPER: fetch universe/gameId from a PlaceId via Roblox API
-- =====================================================================
-- Returns the universeId (number) for a given placeId, or nil on failure.
local function fetchUniverseId(placeId)
    local universeId
    pcall(function()
        local body = game:HttpGet(
            "https://apis.roblox.com/universes/v1/places/" .. tostring(placeId) .. "/universe",
            true
        )
        if body and body ~= "" then
            local decoded = HttpService:JSONDecode(body)
            if decoded and decoded.universeId then
                universeId = tonumber(decoded.universeId)
            end
        end
    end)
    return universeId
end

-- =====================================================================
-- HELPER: fetch game name from a universeId via Roblox API
-- =====================================================================
-- Returns the game name (string) for a given universeId, or nil on failure.
local function fetchGameName(universeId)
    local name
    pcall(function()
        local body = game:HttpGet(
            "https://games.roblox.com/v1/games?universeIds=" .. tostring(universeId),
            true
        )
        if body and body ~= "" then
            local decoded = HttpService:JSONDecode(body)
            if decoded and decoded.data and decoded.data[1] and decoded.data[1].name then
                name = decoded.data[1].name
            end
        end
    end)
    return name
end

-- =====================================================================
-- LOADING STEPS
-- =====================================================================

-- STEP 1: Fetching gameID
setStatus("Fetching gameID...", 0.15)
local fetchedUniverseId = fetchUniverseId(currentPlaceId)
if not fetchedUniverseId then
    -- Fall back to the in-game game.GameId value if the API fails
    fetchedUniverseId = currentGameId
    print("[Aetherist] API fetch for universeId failed, falling back to game.GameId: " .. tostring(fetchedUniverseId))
else
    print(("[Aetherist] Fetched universeId via API: %d"):format(fetchedUniverseId))
end

-- STEP 2: Fetching script (resolve which script to run)
setStatus("Fetching script...", 0.45)
local data = CONFIG[currentPlaceId] or BY_GAME_ID[fetchedUniverseId] or BY_GAME_ID[currentGameId]
local scriptSource

if data then
    print(("[Aetherist] Supported game detected: %s (PlaceId: %d)"):format(data.title, currentPlaceId))
    scriptSource = data.script
else
    print(("[Aetherist] Unsupported game (PlaceId: %d). Running local Universal_Script fallback..."):format(currentPlaceId))
    scriptSource = Universal_Script
end

-- STEP 3: Fetch game name via Roblox API using the fetched universeId
setStatus("Fetching game name...", 0.65)
local gameName
if fetchedUniverseId then
    gameName = fetchGameName(fetchedUniverseId)
end

-- Fall back to MarketplaceService, then to local library title, then to a placeholder
if not gameName then
    pcall(function()
        local info = MarketplaceService:GetProductInfo(currentPlaceId)
        if info and info.Name then
            gameName = info.Name
        end
    end)
end
if not gameName then
    gameName = (data and data.title) or "Unknown Game"
end

print("[Aetherist] Resolved game name: " .. tostring(gameName))

-- STEP 4: Loading Script for {GameName}
setStatus(("Loading Script for %s..."):format(gameName), 0.85)

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
    warn("[Aetherist] Failed to run script: " .. tostring(err))
end

-- =====================================================================
-- FINALIZE -> mark done + tween out the loading screen
-- =====================================================================
setStatus("Done!", 1.0)
task.wait(0.7)

if screenGui then
    -- 1) Collapse the center container back to 0 with a Quint ease
    if centerContainer then
        pcall(function()
            TweenService:Create(centerContainer,
                TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
                { Size = UDim2.fromScale(0, 0) }):Play()
        end)
    end

    -- 2) Fade out the background frame + every text/image descendant
    local function fadeOut(obj)
        if obj:IsA("GuiObject") then
            pcall(function()
                TweenService:Create(obj, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    { BackgroundTransparency = 1 }):Play()
            end)
        end
        for _, child in ipairs(obj:GetDescendants()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") then
                pcall(function()
                    TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { TextTransparency = 1 }):Play()
                end)
            elseif child:IsA("Frame") then
                pcall(function()
                    TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { BackgroundTransparency = 1 }):Play()
                end)
            elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
                pcall(function()
                    TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        { ImageTransparency = 1 }):Play()
                end)
            end
            pcall(function()
                if child:IsA("GuiObject") and child:FindFirstChildWhichIsA("UIStroke") then
                    local stroke = child:FindFirstChildWhichIsA("UIStroke")
                    TweenService:Create(stroke, TweenInfo.new(0.5),
                        { Transparency = 1 }):Play()
                end
            end)
        end
    end
    fadeOut(screenGui)
    task.wait(0.6)
    pcall(function() screenGui:Destroy() end)
end
