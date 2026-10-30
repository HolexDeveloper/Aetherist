--[[
    ====================================================================
     AETHERIST  -  AUTO LOADER  v2.0
     by HolexDeveloper  |  https://github.com/HolexDeveloper
    ====================================================================

    WHAT'S NEW IN v2.0
      - Cinematic custom intro: letter-by-letter "Aetherist" reveal,
        glow orb, rising particles, animated progress bar + blur.
      - AUTO-LOADER: reads game.PlaceId on startup. If it matches a
        PlaceIds entry below, that game's script is fetched and
        executed automatically -- zero clicks needed.
      - NO UI LIBRARY: Rayfield is gone. Everything (pill, picker
        menu, toasts) is hand-built and lightweight.
      - Manual picker menu (press K or click the pill) so any script
        can still be loaded from anywhere.
      - Double-injection guard, executor-safe clipboard, HttpGet
        fallbacks, clean unload.

    HOW THE AUTO-LOADER WORKS
      1. Script starts -> intro plays while the client finishes loading.
      2. game.PlaceId is compared against every PlaceIds table below.
      3. Match found -> that script runs automatically.
         No match  -> the picker menu opens so you can choose.

    HOW TO ADD A GAME
      Copy one block inside GAMES and fill in:
        Name     = anything you want shown in the menu
        PlaceIds = { id1, id2, ... }   -- every place that should trigger it
        URL      = the raw script link
]]

-- =====================================================================
--  CONFIG  --  tweak freely
-- =====================================================================
local CONFIG = {
    IntroEnabled     = true,             -- cinematic splash on startup
    IntroMinimumTime = 3.2,              -- minimum seconds the splash stays
    AutoLoad         = true,             -- auto-execute the matched game script
    FallbackUniversal= false,             -- auto-load Universal when nothing matches
    AutoClosePanel   = true,              -- close picker after a successful load
    OpenMenuIfIdle   = true,             -- open picker when nothing auto-loaded
    MenuKey          = Enum.KeyCode.K,   -- key that toggles the picker menu
    Discord          = "https://discord.gg/q3Jm9gNpGe",
}

-- =====================================================================
--  GAME DATABASE  --  PlaceId -> script
--  Each entry can hold multiple PlaceIds (main place + sub-places).
--  IDs below were verified against their roblox.com game pages.
-- =====================================================================
local GAMES = {
    {
        Name     = "Entrenched WW1",
        PlaceIds = { 3678761576 },  -- roblox.com/games/3678761576/ENTRENCHED
        URL      = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Entrenched.lua",
    },
    {
        Name     = "FPV Drone Battlefield",
        PlaceIds = { 100661692738190 },  -- roblox.com/games/100661692738190/FPV-Drone-Battlefield
        URL      = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/FPVdronebattlefield.txt",
    },
    {
        Name     = "House of the Locust",
        PlaceIds = { 86247128610772 },  -- roblox.com/games/86247128610772/House-of-The-Locust
        URL      = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Houseofthelocust.lua",
    },
    {
        Name     = "Monochrome",
        PlaceIds = { 134208374070897 },  -- roblox.com/games/134208374070897/MONOCHROME
        URL      = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/monochrome.lua",
    },
    {
        Name     = "Aisles Of The Locust",
        PlaceIds = { 134728380684025 },  -- roblox.com/games/134728380684025/Aisles-Of-The-Locust
        URL      = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/AOFL.lua",
    },
}

-- Never auto-detected; always available in the picker menu as a fallback.
local UNIVERSAL = {
    Name        = "Universal (any game)",
    PlaceIds    = {},
    URL         = "https://raw.githubusercontent.com/HolexDeveloper/Aetherist/refs/heads/main/Scripts/Universal.lua",
    IsUniversal = true,
}

-- =====================================================================
--  SERVICES / LOCALS
-- =====================================================================
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
end

-- =====================================================================
--  THEME
-- =====================================================================
local THEME = {
    BG        = Color3.fromRGB(10, 11, 16),
    BG2       = Color3.fromRGB(15, 17, 26),
    Card      = Color3.fromRGB(23, 26, 38),
    CardHover = Color3.fromRGB(32, 36, 52),
    Stroke    = Color3.fromRGB(64, 70, 100),
    Text      = Color3.fromRGB(235, 238, 255),
    SubText   = Color3.fromRGB(140, 148, 184),
    AccentA   = Color3.fromRGB(124, 92, 255),  -- violet
    AccentB   = Color3.fromRGB(0, 224, 255),   -- cyan
    Success   = Color3.fromRGB(90, 230, 165),
    Error     = Color3.fromRGB(255, 92, 110),
    Warning   = Color3.fromRGB(255, 190, 92),
}

local TOAST_COLORS = {
    info    = THEME.AccentB,
    success = THEME.Success,
    warn    = THEME.Warning,
    error   = THEME.Error,
}

-- =====================================================================
--  STATE
-- =====================================================================
local state = {
    loaded      = nil,   -- game definition currently running
    connections = {},    -- UserInputService connections (disconnected on unload)
    guis        = {},    -- every ScreenGui we own (destroyed on unload)
    builtUi     = false,
}

-- Forward declarations (reassigned once the persistent UI exists).
local updatePill = function() end
local setPanel   = function() end
local unloadAll  -- defined below, used by the picker menu

-- =====================================================================
--  HELPERS
-- =====================================================================
local function new(class, props, children)
    local inst = Instance.new(class)
    local parent = nil
    if props then
        for k, v in pairs(props) do
            if k == "Parent" then
                parent = v
            else
                inst[k] = v
            end
        end
    end
    if children then
        for _, c in ipairs(children) do
            c.Parent = inst
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function tween(inst, seconds, style, dir, goal)
    local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(inst, info, goal)
    t:Play()
    return t
end

local function isGroup(inst)
    return inst ~= nil and inst:IsA("CanvasGroup")
end

local function shortError(err)
    local s = tostring(err or "unknown error")
    if #s > 90 then
        s = string.sub(s, 1, 90) .. "..."
    end
    return s
end

-- Rough wrapped-line estimate so toasts get a fixed, deterministic height
-- (no AutomaticSize chain -> no layout edge cases in any executor).
local function estimateMessageHeight(text)
    local charsPerLine = 42
    local lines = 0
    for line in string.gmatch(tostring(text) .. "\n", "(.-)\n") do
        lines = lines + math.max(1, math.ceil(#line / charsPerLine))
    end
    lines = math.clamp(lines, 1, 4)
    return lines * 15
end

local function copyText(text)
    local candidates = { setclipboard, set_clipboard, writeclipboard, toclipboard }
    for _, f in ipairs(candidates) do
        if type(f) == "function" then
            local ok = pcall(f, text)
            if ok then
                return true
            end
        end
    end
    return false
end

local function fetchScript(url)
    local ok, result = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok and type(result) == "string" and #result > 0 then
        return true, result
    end
    local requesters = {}
    if type(http_request) == "function" then table.insert(requesters, http_request) end
    if type(request) == "function" then table.insert(requesters, request) end
    if syn and type(syn.request) == "function" then table.insert(requesters, syn.request) end
    for _, requester in ipairs(requesters) do
        local ok2, res2 = pcall(function()
            return requester({ Url = url, Method = "GET" })
        end)
        if ok2 and type(res2) == "string" and #res2 > 0 then
            return true, res2
        end
        if ok2 and type(res2) == "table" and type(res2.Body) == "string" and #res2.Body > 0 then
            return true, res2.Body
        end
    end
    return false, "no working HttpGet found on this executor"
end

-- =====================================================================
--  GUI PARENTING  (executor-safe) + cleanup of previous runs
-- =====================================================================
local function getGuiParent()
    if gethui then
        local ok, ui = pcall(gethui)
        if ok and ui then
            return ui
        end
    end
    local ok, core = pcall(function()
        return game:GetService("CoreGui")
    end)
    if ok and core then
        local ok2 = pcall(function()
            local probe = Instance.new("Folder")
            probe.Parent = core
            probe:Destroy()
        end)
        if ok2 then
            return core
        end
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

do
    local holders = {}
    if gethui then
        pcall(function() table.insert(holders, gethui()) end)
    end
    pcall(function() table.insert(holders, game:GetService("CoreGui")) end)
    pcall(function() table.insert(holders, LocalPlayer:FindFirstChild("PlayerGui")) end)
    table.insert(holders, guiParent)
    for _, h in ipairs(holders) do
        pcall(function()
            for _, child in ipairs(h:GetChildren()) do
                if string.sub(child.Name, 1, 9) == "Aetherist" then
                    child:Destroy()
                end
            end
        end)
    end
end

local function track(gui)
    table.insert(state.guis, gui)
    return gui
end

local function makeScreenGui(name, displayOrder)
    return track(new("ScreenGui", {
        Name           = name,
        ResetOnSpawn   = false,
        IgnoreGuiInset = true,
        DisplayOrder   = displayOrder,
        Parent         = guiParent,
    }))
end

-- =====================================================================
--  TOASTS  --  lightweight custom notifications (top right)
-- =====================================================================
local toastHolder = nil
local toastOrder  = 0
local activeToasts = {}

local function buildToastHolder()
    if toastHolder then
        return
    end
    local gui = makeScreenGui("Aetherist_Toasts", 100000)
    toastHolder = new("Frame", {
        Name                   = "Holder",
        AnchorPoint            = Vector2.new(1, 0),
        Position               = UDim2.new(1, -16, 0, 16),
        Size                   = UDim2.new(0, 320, 1, -32),
        BackgroundTransparency = 1,
        Parent                 = gui,
    }, {
        new("UIListLayout", {
            Padding            = UDim.new(0, 8),
            SortOrder          = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            VerticalAlignment  = Enum.VerticalAlignment.Top,
        }),
    })
end

local function closeToast(entry)
    if entry.closing then
        return
    end
    entry.closing = true
    local group = entry.group
    if isGroup(group) then
        tween(group, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { GroupTransparency = 1 })
    end
    local scale = group:FindFirstChildOfClass("UIScale")
    if scale then
        tween(scale, 0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { Scale = 0.94 })
    end
    task.delay(0.24, function()
        for i, e in ipairs(activeToasts) do
            if e == entry then
                table.remove(activeToasts, i)
                break
            end
        end
        pcall(function() group:Destroy() end)
    end)
end

local function notify(title, message, kind, duration)
    buildToastHolder()
    kind = TOAST_COLORS[kind] and kind or "info"
    local accent = TOAST_COLORS[kind]

    local group
    pcall(function()
        group = Instance.new("CanvasGroup")
    end)
    if not group then
        group = Instance.new("Frame")
    end
    local messageHeight = estimateMessageHeight(message)
    local totalHeight = 42 + messageHeight  -- 10 pad + 16 title + 4 gap + text + 12 pad

    group.Name                 = "Toast"
    group.BackgroundColor3     = THEME.Card
    group.BorderSizePixel      = 0
    group.Size                 = UDim2.new(1, 0, 0, totalHeight)
    group.LayoutOrder          = 0
    if isGroup(group) then
        group.GroupTransparency = 1
        group.BackgroundTransparency = 1
    else
        new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = group })
    end

    local card = new("Frame", {
        Name                   = "Card",
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundColor3       = THEME.Card,
        BackgroundTransparency = 0,
        BorderSizePixel        = 0,
        Parent                 = group,
    }, { corner(12) })

    new("UIStroke", { Color = THEME.Stroke, Transparency = 0.45, Parent = card })

    new("Frame", {
        Name                   = "Accent",
        Position               = UDim2.fromOffset(0, 10),
        Size                   = UDim2.new(0, 3, 1, -20),
        BackgroundColor3       = accent,
        BorderSizePixel        = 0,
        Parent                 = card,
    }, { corner(2) })

    new("TextLabel", {
        Name                   = "Title",
        Position               = UDim2.fromOffset(16, 10),
        Size                   = UDim2.new(1, -28, 0, 16),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        Text                   = tostring(title),
        TextSize               = 13,
        TextColor3             = THEME.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = card,
    })

    new("TextLabel", {
        Name                   = "Message",
        Position               = UDim2.fromOffset(16, 30),
        Size                   = UDim2.new(1, -28, 0, messageHeight),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = tostring(message),
        TextSize               = 12,
        TextColor3             = THEME.SubText,
        TextWrapped            = true,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = card,
    })

    toastOrder = toastOrder + 1
    group.LayoutOrder = toastOrder
    group.Parent = toastHolder

    local scale = new("UIScale", { Scale = 0.94, Parent = group })

    local entry = { group = group, closing = false }
    table.insert(activeToasts, entry)

    if isGroup(group) then
        tween(group, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { GroupTransparency = 0 })
    end
    tween(scale, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            closeToast(entry)
        end
    end)

    if #activeToasts > 5 then
        closeToast(activeToasts[1])
    end

    task.delay(duration or 5, function()
        closeToast(entry)
    end)
    return entry
end

-- =====================================================================
--  AUTO-LOADER CORE
-- =====================================================================
local function detectGame()
    local pid = game.PlaceId
    if not pid or pid == 0 then
        return nil
    end
    for _, def in ipairs(GAMES) do
        for _, id in ipairs(def.PlaceIds or {}) do
            if id == pid then
                return def
            end
        end
    end
    return nil
end

local function executeGame(def)
    if not def then
        return false
    end
    if state.loaded == def then
        notify("Already loaded", def.Name .. " is already running. Re-injecting can cause conflicts.", "warn", 5)
        return true
    end

    updatePill(def.Name .. " - loading", THEME.Warning)
    notify("Fetching script", "Downloading and executing " .. def.Name .. "...", "info", 3)

    local ok, err = pcall(function()
        local good, source = fetchScript(def.URL)
        if not good then
            error("download failed: " .. tostring(source))
        end
        local factory = loadstring(source)
        if not factory then
            error("loadstring returned nil (empty or blocked source)")
        end
        factory()
    end)

    if ok then
        if state.loaded and state.loaded._statusLabel then
            state.loaded._statusLabel.Text = ""
        end
        state.loaded = def
        if def._statusLabel then
            def._statusLabel.Text = "loaded"
        end
        updatePill(def.Name .. " - loaded", THEME.Success)
        notify("Loaded", def.Name .. " is now running. Press K for the menu.", "success", 5)
        print("[Aetherist] Loaded " .. def.Name)
    else
        updatePill(def.Name .. " - failed", THEME.Error)
        notify("Load failed", def.Name .. " -- " .. shortError(err), "error", 8)
        warn("[Aetherist] Failed to load " .. def.Name .. ": " .. tostring(err))
    end
    return ok
end

-- =====================================================================
--  INTRO  --  cinematic splash, fully hand-built
-- =====================================================================
local function createIntro()
    if not CONFIG.IntroEnabled then
        return {
            setStatus = function() end,
            progress  = function() end,
            finish    = function() end,
        }
    end

    local finished  = false
    local particlesAlive = true

    -- ScreenGui + (CanvasGroup) root ------------------------------------------------
    local splashGui = makeScreenGui("Aetherist_Splash", 99998)

    local root
    pcall(function()
        root = Instance.new("CanvasGroup")
        root.GroupTransparency = 1
    end)
    if not root then
        root = Instance.new("Frame")
        root.BackgroundTransparency = 1
    end
    root.Name                 = "Root"
    root.Size                 = UDim2.fromScale(1, 1)
    root.BackgroundColor3     = THEME.BG
    root.BorderSizePixel      = 0
    root.Parent               = splashGui

    local rootIsGroup = isGroup(root)

    -- background depth gradient -----------------------------------------------------
    new("Frame", {
        Name                   = "Depth",
        Size                   = UDim2.fromScale(1, 1),
        BackgroundColor3       = THEME.BG2,
        BackgroundTransparency = 0.35,
        BorderSizePixel        = 0,
        Parent                 = root,
    }, {
        new("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 24, 40)),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(1, 0.4),
            }),
        }),
    })

    -- ambient particles --------------------------------------------------------------
    local particleLayer = new("Frame", {
        Name                   = "Particles",
        Size                   = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent                 = root,
    })

    task.spawn(function()
        while particlesAlive and particleLayer.Parent do
            local size = math.random(3, 7)
            local x = math.random(-4, 104) / 100
            local drift = math.random(-10, 10) / 100
            local dur = math.random(60, 110) / 10
            local dot = new("Frame", {
                AnchorPoint            = Vector2.new(0.5, 0.5),
                Position               = UDim2.new(x, 0, 1.06, 0),
                Size                   = UDim2.fromOffset(size, size),
                BackgroundColor3       = (math.random() > 0.5) and THEME.AccentA or THEME.AccentB,
                BackgroundTransparency = 0.45,
                BorderSizePixel        = 0,
                Parent                 = particleLayer,
            }, { corner(math.floor(size / 2)) })
            tween(dot, dur, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, {
                Position               = UDim2.new(math.clamp(x + drift, 0, 1), 0, -0.1, 0),
                BackgroundTransparency = 1,
            })
            task.delay(dur, function()
                dot:Destroy()
            end)
            task.wait(math.random(12, 40) / 100)
        end
    end)

    -- glow orb behind the title ------------------------------------------------------
    local orb = new("Frame", {
        Name                   = "Orb",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, 0),
        Size                   = UDim2.fromOffset(250, 250),
        BackgroundColor3       = THEME.AccentA,
        BackgroundTransparency = 0.86,
        BorderSizePixel        = 0,
        Parent                 = particleLayer,
    }, {
        corner(125),
        new("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.AccentA),
                ColorSequenceKeypoint.new(1, THEME.AccentB),
            }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(1, 1),
            }),
        }),
    })

    local orbInfo = TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    TweenService:Create(orb, orbInfo, { Size = UDim2.fromOffset(300, 300) }):Play()

    -- diamond logo mark ---------------------------------------------------------------
    local diamond = new("Frame", {
        Name                   = "Mark",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, -66),
        Size                   = UDim2.fromOffset(20, 20),
        Rotation               = 45,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Parent                 = root,
    }, {
        corner(6),
        new("UIGradient", {
            Rotation = 45,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.AccentA),
                ColorSequenceKeypoint.new(1, THEME.AccentB),
            }),
        }),
    })

    -- "Aetherist" wordmark, one label per letter -------------------------------------
    local TITLE_TEXT = "Aetherist"
    local titleRow = new("Frame", {
        Name                   = "Title",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.415, 0),
        Size                   = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        AutomaticSize          = Enum.AutomaticSize.XY,
        Parent                 = root,
    }, {
        new("UIListLayout", {
            FillDirection       = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment   = Enum.VerticalAlignment.Center,
            SortOrder           = Enum.SortOrder.LayoutOrder,
            Padding             = UDim.new(0, 1),
        }),
    })

    for i = 1, #TITLE_TEXT do
        local ch = string.sub(TITLE_TEXT, i, i)
        local frac = (i - 1) / math.max(#TITLE_TEXT - 1, 1)
        local letter = new("TextLabel", {
            BackgroundTransparency = 1,
            Font                   = Enum.Font.GothamBlack,
            Text                   = ch,
            TextSize               = 62,
            TextColor3             = THEME.AccentA:Lerp(THEME.AccentB, frac),
            TextTransparency       = 1,
            AutomaticSize          = Enum.AutomaticSize.XY,
            LayoutOrder            = i,
            Parent                 = titleRow,
        })
        task.delay(0.45 + i * 0.06, function()
            if letter.Parent then
                tween(letter, 0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0 })
            end
        end)
    end
    tween(titleRow, 1.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
        Position = UDim2.new(0.5, 0, 0.40, 0),
    })

    -- underline accent bar -------------------------------------------------------------
    local underline = new("Frame", {
        Name                   = "Underline",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, 54),
        Size                   = UDim2.new(0, 0, 0, 3),
        BackgroundTransparency = 0.2,
        BorderSizePixel        = 0,
        Parent                 = root,
    }, {
        corner(2),
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.AccentA),
                ColorSequenceKeypoint.new(1, THEME.AccentB),
            }),
        }),
    })

    -- tagline ---------------------------------------------------------------------------
    local tagline = new("TextLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, 76),
        Size                   = UDim2.fromOffset(400, 16),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamMedium,
        Text                   = "BY HOLEXDEVELOPER  -  MULTIGAME AUTO LOADER",
        TextSize               = 12,
        TextColor3             = THEME.SubText,
        TextTransparency       = 1,
        Parent                 = root,
    })

    -- progress bar -----------------------------------------------------------------------
    local barBg = new("Frame", {
        Name                   = "BarBg",
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, 136),
        Size                   = UDim2.fromOffset(320, 5),
        BackgroundColor3       = THEME.Card,
        BackgroundTransparency = 1,
        BorderSizePixel        = 0,
        Parent                 = root,
    }, { corner(3) })

    local barFill = new("Frame", {
        Name                   = "Fill",
        Size                   = UDim2.new(0, 0, 1, 0),
        BackgroundColor3       = Color3.fromRGB(255, 255, 255),
        BorderSizePixel        = 0,
        Parent                 = barBg,
    }, {
        corner(3),
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, THEME.AccentA),
                ColorSequenceKeypoint.new(1, THEME.AccentB),
            }),
        }),
    })

    -- status line ------------------------------------------------------------------------
    local statusLabel = new("TextLabel", {
        AnchorPoint            = Vector2.new(0.5, 0.5),
        Position               = UDim2.new(0.5, 0, 0.40, 160),
        Size                   = UDim2.fromOffset(480, 16),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = "...",
        TextSize               = 12,
        TextColor3             = THEME.SubText,
        TextTransparency       = 1,
        Parent                 = root,
    })

    -- footer -------------------------------------------------------------------------------
    local footerLeft = new("TextLabel", {
        AnchorPoint            = Vector2.new(0, 1),
        Position               = UDim2.new(0, 16, 1, -14),
        Size                   = UDim2.fromOffset(300, 14),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamMedium,
        Text                   = "AETHERIST v2.0",
        TextSize               = 10,
        TextColor3             = THEME.SubText,
        TextTransparency       = 1,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = root,
    })

    local footerRight = new("TextLabel", {
        AnchorPoint            = Vector2.new(1, 1),
        Position               = UDim2.new(1, -16, 1, -14),
        Size                   = UDim2.fromOffset(300, 14),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamMedium,
        Text                   = "GITHUB.COM/HOLEXDEVELOPER",
        TextSize               = 10,
        TextColor3             = THEME.SubText,
        TextTransparency       = 1,
        TextXAlignment         = Enum.TextXAlignment.Right,
        Parent                 = root,
    })

    -- blur ------------------------------------------------------------------------------------
    local blur = Instance.new("BlurEffect")
    blur.Name  = "AetheristBlur"
    blur.Size  = 0
    blur.Parent = Lighting
    tween(blur, 0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = 18 })

    -- entrance choreography ---------------------------------------------------------------------
    if rootIsGroup then
        tween(root, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { GroupTransparency = 0 })
    else
        tween(root, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })
    end

    task.delay(0.35, function()
        tween(diamond, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { BackgroundTransparency = 0 })
    end)
    task.delay(0.8, function()
        tween(barBg, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundTransparency = 0.35 })
        tween(statusLabel, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { TextTransparency = 0.15 })
    end)
    task.delay(1.15, function()
        tween(tagline, 0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.2 })
    end)
    task.delay(1.3, function()
        tween(underline, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Size = UDim2.new(0, 150, 0, 3) })
    end)
    task.delay(1.45, function()
        tween(footerLeft, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.35 })
        tween(footerRight, 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.35 })
    end)

    -- public intro API ------------------------------------------------------------------------------
    return {
        setStatus = function(text, color)
            statusLabel.Text = tostring(text)
            statusLabel.TextColor3 = color or THEME.SubText
            statusLabel.TextTransparency = 0.45
            tween(statusLabel, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, { TextTransparency = 0.15 })
        end,
        progress = function(frac)
            frac = math.clamp(tonumber(frac) or 0, 0, 1)
            tween(barFill, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
                Size = UDim2.new(frac, 0, 1, 0),
            })
        end,
        finish = function()
            if finished then
                return
            end
            finished = true
            particlesAlive = false

            tween(blur, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { Size = 0 })
            task.delay(0.5, function()
                pcall(function() blur:Destroy() end)
            end)

            if rootIsGroup then
                tween(root, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { GroupTransparency = 1 })
            else
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        tween(d, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { TextTransparency = 1 })
                    elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
                        tween(d, 0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.In, {
                            BackgroundTransparency = math.clamp(d.BackgroundTransparency + 0.55, 0, 1),
                        })
                    end
                end
                tween(root, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { BackgroundTransparency = 1 })
            end
            task.delay(0.55, function()
                pcall(function() splashGui:Destroy() end)
            end)
        end,
    }
end

-- =====================================================================
--  PERSISTENT UI  --  status pill + picker menu (no library)
-- =====================================================================
local function makeDraggable(frame, clickCallback)
    local dragging = false
    local moved = 0
    local dragStart = nil
    local startPos = nil

    frame.Active = true
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = 0
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and moved < 6 and clickCallback then
                clickCallback()
            end
            dragging = false
        end
    end)
    table.insert(state.connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            moved = math.max(moved, math.abs(delta.X) + math.abs(delta.Y))
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))
end

local function buildPersistentUi()
    if state.builtUi then
        return
    end
    state.builtUi = true

    local gui = makeScreenGui("Aetherist_Main", 99000)

    ------------------------------------------------------------------
    -- status pill
    ------------------------------------------------------------------
    local pill = new("Frame", {
        Name                   = "Pill",
        AnchorPoint            = Vector2.new(0, 0.5),
        Position               = UDim2.new(0, 16, 0, 180),
        Size                   = UDim2.fromOffset(178, 40),
        BackgroundColor3       = THEME.Card,
        BorderSizePixel        = 0,
        Parent                 = gui,
    }, { corner(12) })

    new("UIStroke", { Color = THEME.Stroke, Transparency = 0.4, Parent = pill })
    local pillScale = new("UIScale", { Scale = 0.85, Parent = pill })

    local pillDot = new("Frame", {
        AnchorPoint            = Vector2.new(0, 0.5),
        Position               = UDim2.new(0, 14, 0.5, 0),
        Size                   = UDim2.fromOffset(8, 8),
        BackgroundColor3       = THEME.SubText,
        BorderSizePixel        = 0,
        Parent                 = pill,
    }, { corner(4) })

    new("TextLabel", {
        Position               = UDim2.fromOffset(30, 0),
        Size                   = UDim2.new(0, 76, 1, 0),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBold,
        Text                   = "Aetherist",
        TextSize               = 13,
        TextColor3             = THEME.Text,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = pill,
    })

    local pillStatus = new("TextLabel", {
        AnchorPoint            = Vector2.new(1, 0.5),
        Position               = UDim2.new(1, -10, 0.5, 0),
        Size                   = UDim2.fromOffset(64, 12),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = "idle",
        TextSize               = 10,
        TextColor3             = THEME.SubText,
        TextXAlignment         = Enum.TextXAlignment.Right,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Parent                 = pill,
    })

    pill.MouseEnter:Connect(function()
        tween(pill, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.CardHover })
    end)
    pill.MouseLeave:Connect(function()
        tween(pill, 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.Card })
    end)

    updatePill = function(text, color)
        pillStatus.Text = tostring(text or "")
        pillDot.BackgroundColor3 = color or THEME.SubText
    end

    ------------------------------------------------------------------
    -- picker menu
    ------------------------------------------------------------------
    local panel
    pcall(function()
        panel = Instance.new("CanvasGroup")
        panel.GroupTransparency = 1
    end)
    if not panel then
        panel = Instance.new("Frame")
        panel.BackgroundTransparency = 1
    end
    panel.Name                 = "Menu"
    panel.AnchorPoint          = Vector2.new(0.5, 0.5)
    panel.Position             = UDim2.fromScale(0.5, 0.5)
    panel.Size                 = UDim2.fromOffset(348, 512)
    panel.BackgroundColor3     = THEME.BG2
    panel.BorderSizePixel      = 0
    panel.Visible              = false
    panel.Parent               = gui

    new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = panel })
    new("UIStroke", { Color = THEME.Stroke, Transparency = 0.35, Parent = panel })
    local panelScale = new("UIScale", { Scale = 0.92, Parent = panel })
    local panelOpen = false

    -- header
    local headerTitle = new("TextLabel", {
        Position               = UDim2.fromOffset(18, 14),
        Size                   = UDim2.fromOffset(200, 24),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.GothamBlack,
        Text                   = "Aetherist",
        TextSize               = 19,
        TextColor3             = Color3.fromRGB(255, 255, 255),
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = panel,
    }, {
        new("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                ColorSequenceKeypoint.new(1, THEME.AccentB),
            }),
        }),
    })

    new("TextLabel", {
        Position               = UDim2.fromOffset(18, 38),
        Size                   = UDim2.fromOffset(240, 14),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = "Multigame auto-loader by HolexDeveloper",
        TextSize               = 11,
        TextColor3             = THEME.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = panel,
    })

    local currentLabel = new("TextLabel", {
        Position               = UDim2.fromOffset(18, 58),
        Size                   = UDim2.new(1, -36, 0, 14),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = "Detected: -  -  PlaceId " .. tostring(game.PlaceId),
        TextSize               = 11,
        TextColor3             = THEME.SubText,
        TextXAlignment         = Enum.TextXAlignment.Left,
        TextTruncate           = Enum.TextTruncate.AtEnd,
        Parent                 = panel,
    })

    local closeButton = new("TextButton", {
        AnchorPoint            = Vector2.new(1, 0),
        Position               = UDim2.new(1, -12, 0, 12),
        Size                   = UDim2.fromOffset(26, 26),
        BackgroundColor3       = THEME.Card,
        BorderSizePixel        = 0,
        Font                   = Enum.Font.GothamBold,
        Text                   = "X",
        TextSize               = 12,
        TextColor3             = THEME.SubText,
        AutoButtonColor        = false,
        Parent                 = panel,
    }, { corner(8) })
    closeButton.MouseButton1Click:Connect(function()
        setPanel(false)
    end)

    -- game buttons
    local function makeGameButton(def, y, dotColor)
        local btn = new("TextButton", {
            Position               = UDim2.fromOffset(14, y),
            Size                   = UDim2.new(1, -28, 0, 38),
            BackgroundColor3       = THEME.Card,
            BorderSizePixel        = 0,
            Text                   = "",
            AutoButtonColor        = false,
            Parent                 = panel,
        }, { corner(10) })
        new("UIStroke", { Color = THEME.Stroke, Transparency = 0.55, Parent = btn })
        new("Frame", {
            AnchorPoint            = Vector2.new(0, 0.5),
            Position               = UDim2.new(0, 14, 0.5, 0),
            Size                   = UDim2.fromOffset(8, 8),
            BackgroundColor3       = dotColor,
            BorderSizePixel        = 0,
            Parent                 = btn,
        }, { corner(4) })
        new("TextLabel", {
            Position               = UDim2.fromOffset(32, 0),
            Size                   = UDim2.new(1, -120, 1, 0),
            BackgroundTransparency = 1,
            Font                   = Enum.Font.GothamMedium,
            Text                   = def.Name,
            TextSize               = 13,
            TextColor3             = THEME.Text,
            TextXAlignment         = Enum.TextXAlignment.Left,
            TextTruncate           = Enum.TextTruncate.AtEnd,
            Parent                 = btn,
        })
        local statusTag = new("TextLabel", {
            AnchorPoint            = Vector2.new(1, 0.5),
            Position               = UDim2.new(1, -12, 0.5, 0),
            Size                   = UDim2.fromOffset(70, 14),
            BackgroundTransparency = 1,
            Font                   = Enum.Font.GothamBold,
            Text                   = "",
            TextSize               = 10,
            TextColor3             = THEME.Success,
            TextXAlignment         = Enum.TextXAlignment.Right,
            Parent                 = btn,
        })
        btn.MouseEnter:Connect(function()
            tween(btn, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.CardHover })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.Card })
        end)
        btn.Activated:Connect(function()
            local ok = executeGame(def)
            if ok and CONFIG.AutoClosePanel then
                setPanel(false)
            end
        end)
        def._statusLabel = statusTag
    end

    local uiList = {}
    for _, def in ipairs(GAMES) do
        table.insert(uiList, def)
    end
    table.insert(uiList, UNIVERSAL)

    for i, def in ipairs(uiList) do
        local frac = (i - 1) / math.max(#uiList - 1, 1)
        makeGameButton(def, 80 + (i - 1) * 44, THEME.AccentA:Lerp(THEME.AccentB, frac))
    end

    -- divider
    new("Frame", {
        Position               = UDim2.fromOffset(14, 350),
        Size                   = UDim2.new(1, -28, 0, 1),
        BackgroundColor3       = THEME.Stroke,
        BackgroundTransparency = 0.5,
        BorderSizePixel        = 0,
        Parent                 = panel,
    })

    -- utility buttons
    local function makeUtilButton(text, y, callback)
        local btn = new("TextButton", {
            Position               = UDim2.fromOffset(14, y),
            Size                   = UDim2.new(1, -28, 0, 34),
            BackgroundColor3       = THEME.Card,
            BorderSizePixel        = 0,
            Font                   = Enum.Font.GothamMedium,
            Text                   = text,
            TextSize               = 12,
            TextColor3             = THEME.Text,
            AutoButtonColor        = false,
            Parent                 = panel,
        }, { corner(10) })
        new("UIStroke", { Color = THEME.Stroke, Transparency = 0.6, Parent = btn })
        btn.MouseEnter:Connect(function()
            tween(btn, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.CardHover })
        end)
        btn.MouseLeave:Connect(function()
            tween(btn, 0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { BackgroundColor3 = THEME.Card })
        end)
        btn.Activated:Connect(function()
            callback()
        end)
        return btn
    end

    makeUtilButton("Copy Discord invite", 360, function()
        local copied = copyText(CONFIG.Discord)
        if copied then
            notify("Copied", "Discord invite copied to clipboard.", "success", 4)
        else
            notify("Clipboard unavailable", CONFIG.Discord, "warn", 7)
            print("[Aetherist] Discord: " .. CONFIG.Discord)
        end
    end)

    makeUtilButton("Re-run auto-detect", 400, function()
        local match = detectGame()
        if match then
            currentLabel.Text = "Detected: " .. match.Name .. "  -  PlaceId " .. tostring(game.PlaceId)
            executeGame(match)
        else
            notify("No match", "No script is mapped to PlaceId " .. tostring(game.PlaceId) .. ".", "warn", 6)
        end
    end)

    local unloadButton = makeUtilButton("Unload Aetherist UI", 440, function()
        unloadButton.TextColor3 = THEME.Error
        task.delay(0.05, function()
            unloadAll()
        end)
    end)
    unloadButton.TextColor3 = THEME.SubText

    -- footer
    new("TextLabel", {
        AnchorPoint            = Vector2.new(0.5, 1),
        Position               = UDim2.new(0.5, 0, 1, -10),
        Size                   = UDim2.new(1, -36, 0, 14),
        BackgroundTransparency = 1,
        Font                   = Enum.Font.Gotham,
        Text                   = "Press K to toggle  -  v2.0",
        TextSize               = 10,
        TextColor3             = THEME.SubText,
        TextTransparency       = 0.25,
        Parent                 = panel,
    })

    -- resolve the actual place name asynchronously
    task.spawn(function()
        local name = nil
        pcall(function()
            local info = MarketplaceService:GetProductInfo(game.PlaceId)
            if info and info.Name then
                name = info.Name
            end
        end)
        if name and currentLabel.Parent then
            currentLabel.Text = "Detected: " .. name .. "  -  PlaceId " .. tostring(game.PlaceId)
        end
    end)

    ------------------------------------------------------------------
    -- menu open/close + keybind
    ------------------------------------------------------------------
    setPanel = function(show)
        if show == panelOpen then
            return
        end
        panelOpen = show
        if show then
            panel.Visible = true
            if isGroup(panel) then
                panel.GroupTransparency = 1
                tween(panel, 0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { GroupTransparency = 0 })
            end
            panelScale.Scale = 0.92
            tween(panelScale, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
        else
            if isGroup(panel) then
                tween(panel, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { GroupTransparency = 1 })
            end
            tween(panelScale, 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { Scale = 0.92 })
            task.delay(0.22, function()
                if not panelOpen then
                    panel.Visible = false
                end
            end)
        end
    end

    makeDraggable(pill, function()
        setPanel(not panelOpen)
    end)

    table.insert(state.connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == CONFIG.MenuKey then
            setPanel(not panelOpen)
        end
    end))

    -- pill entrance
    task.delay(0.1, function()
        tween(pillScale, 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
    end)
end

-- =====================================================================
--  UNLOAD
-- =====================================================================
unloadAll = function()
    for _, conn in ipairs(state.connections) do
        pcall(function() conn:Disconnect() end)
    end
    state.connections = {}
    for _, gui in ipairs(state.guis) do
        pcall(function() gui:Destroy() end)
    end
    state.guis = {}
    state.builtUi = false
    toastHolder = nil
    activeToasts = {}
    pcall(function()
        local b = Lighting:FindFirstChild("AetheristBlur")
        if b then
            b:Destroy()
        end
    end)
    print("[Aetherist] UI unloaded. Already-loaded scripts keep running.")
end

-- =====================================================================
--  BOOT SEQUENCE
-- =====================================================================
local function boot()
    local startedAt = os.clock()
    local intro = createIntro()

    intro.setStatus("Waiting for Roblox to load...")
    if not game:IsLoaded() then
        local t0 = os.clock()
        while not game:IsLoaded() and os.clock() - t0 < 20 do
            task.wait(0.1)
        end
    end

    task.wait(0.3)
    intro.setStatus("Initializing environment...")
    intro.progress(0.18)
    task.wait(0.55)

    intro.setStatus("Detecting game via PlaceId...")
    intro.progress(0.40)
    local match = detectGame()
    task.wait(0.5)

    if match then
        intro.setStatus("Match found: " .. match.Name, THEME.AccentB)
        intro.progress(0.60)
        task.wait(0.8)
        intro.setStatus("Executing " .. match.Name .. " script...")
        intro.progress(0.85)
        executeGame(match)
        intro.progress(1)
        if state.loaded then
            intro.setStatus("Welcome to Aetherist", THEME.Success)
        else
            intro.setStatus("Execution failed -- check console (F9)", THEME.Error)
        end
    else
        intro.progress(1)
        if game.PlaceId == 0 then
            intro.setStatus("PlaceId unavailable (Studio?) - pick manually", THEME.Warning)
        else
            intro.setStatus("No script mapped for this game yet", THEME.Warning)
        end
        if CONFIG.FallbackUniversal then
            task.wait(0.6)
            intro.setStatus("Loading Universal fallback...", THEME.AccentB)
            executeGame(UNIVERSAL)
        end
    end

    local elapsed = os.clock() - startedAt
    if CONFIG.IntroEnabled and elapsed < CONFIG.IntroMinimumTime then
        task.wait(CONFIG.IntroMinimumTime - elapsed)
    end
    task.wait(state.loaded and 0.55 or 1.5)

    intro.finish()
    task.wait(0.15)
    buildPersistentUi()

    if state.loaded then
        notify("Aetherist ready", state.loaded.Name .. " is running. Press K for the menu.", "success", 6)
    elseif match then
        notify("Aetherist ready", match.Name .. " failed to load -- open the menu to retry.", "error", 6)
        if CONFIG.OpenMenuIfIdle then
            task.wait(0.4)
            setPanel(true)
        end
    else
        notify("Aetherist ready", "No auto-script for this game. Pick one in the menu.", "warn", 6)
        if CONFIG.OpenMenuIfIdle then
            task.wait(0.4)
            setPanel(true)
        end
    end
end

print("[Aetherist] v2.0 starting  -  PlaceId: " .. tostring(game.PlaceId) .. "  -  Menu key: K")
task.spawn(boot)
