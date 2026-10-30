--[[
    Aetherist / BE  -  V1.0.0
    Bug Evolution [spider]  |  under-map autofarm + telemetry

    Remotes
        ReplicatedStorage.Remotes.Attack:FireServer(instance)
        ReplicatedStorage.Remotes.PickTrait:FireServer(index)
        ReplicatedStorage.Remotes.RequestSpawn:FireServer("Respawn")

    Server behaviour measured on placeVersion 19
        hit range      = LocalPlayer:GetAttribute("Reach")  (scales with level)
        hit cooldown   = 1 / (AttackSpeed * AttackSpeedMult)  (~0.96s at 1.045)
        range check is 3D, so straight below a target is still in range
        orb pickup radius ~16 studs from the orb centre
        death wipes TotalXP and drops Level to 1  (Config.Death.RespawnKeepXP = 0)

    The character is held at target X/Z, Depth studs under the target's own Y,
    clamped by Reach - 1.0 and by VoidFloor. Nothing above the surface ever
    sees the body; the hits still validate because the vertical offset is
    inside Reach.
]]

local Rayfield
do
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()
    end)
    if not ok or not lib then
        warn("[Aetherist/BE] Rayfield failed to load")
        return
    end
    Rayfield = lib
end

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local REM = ReplicatedStorage:WaitForChild("Remotes")

-- ============================================================
-- CONFIG
-- ============================================================
local VERSION = "V1.0.0"

local CFG = {
    Enabled      = false,
    CollectOrbs  = true,
    Breakables   = true,
    Creatures    = false,
    Priority     = "Value / distance",
    Zone         = "All",
    Radius       = 900,
    OrbRadius    = 180,
    UnderMap     = true,
    Depth        = 9,
    VoidFloor    = -1.0,
    Jitter       = true,
    AutoRespawn  = true,
    AutoTrait    = true,
    LowHPGuard   = true,
    LowHPPercent = 22,
    RetreatOnLowHP = true,
    CacheTTL     = 0.6,
    AttackPad    = 0.05,
    StallTimeout = 9,
    CameraAbove  = true,
    CameraHeight = 55,
}

-- ============================================================
-- RELOAD SAFETY
-- ============================================================
local genv = getgenv()
genv.__aetheristBE = genv.__aetheristBE or { gen = 0 }
local STATE = genv.__aetheristBE
STATE.gen = (STATE.gen or 0) + 1
local MY_GEN = STATE.gen

if STATE.connections then
    for _, c in ipairs(STATE.connections) do pcall(function() c:Disconnect() end) end
end
if STATE.window then pcall(function() STATE.window:Destroy() end) end
STATE.connections = {}
local conns = STATE.connections

local function track(c)
    conns[#conns + 1] = c
    return c
end

local function alive()
    return STATE.gen == MY_GEN
end

-- ============================================================
-- CHARACTER
-- ============================================================
local function getChar()
    local char = LP.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return nil end
    if hum.Health <= 0 then return nil end
    return char, hum, hrp
end

local function partOf(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
end

local function reachNow()
    return LP:GetAttribute("Reach") or 6.8
end

local function damageNow()
    return LP:GetAttribute("Damage") or 10
end

local function biteInterval()
    local a = (LP:GetAttribute("AttackSpeed") or 1) * (LP:GetAttribute("AttackSpeedMult") or 1)
    local base = 1 / math.max(a, 0.05)
    if CFG.Jitter then base = base + math.random() * 0.05 end
    return math.max(0.30, base) + CFG.AttackPad
end

-- ============================================================
-- MOTION LOCK
-- ============================================================
local Lock = { active = false, pos = Vector3.zero, since = 0 }

local groundUnder -- defined below, forward declared for the camera lift

local function restoreCamera()
    local cam = Workspace.CurrentCamera
    if cam and cam.CameraType == Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Custom
    end
end

track(RunService.RenderStepped:Connect(function()
    if not Lock.active then return end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(Lock.pos)

    -- the body is buried, so lift the view above the terrain at that X/Z
    if CFG.CameraAbove and CFG.Enabled then
        local cam = Workspace.CurrentCamera
        if cam then
            local gy = groundUnder(Lock.pos.X, Lock.pos.Z, Lock.pos.Y + 400)
            local eyeY = gy and (gy + CFG.CameraHeight) or (Lock.pos.Y + CFG.CameraHeight)
            local focusY = gy or Lock.pos.Y
            local eye = Vector3.new(Lock.pos.X, eyeY, Lock.pos.Z + 14)
            cam.CameraType = Enum.CameraType.Scriptable
            cam.CFrame = CFrame.lookAt(eye, Vector3.new(Lock.pos.X, focusY, Lock.pos.Z))
        end
    end
end))

local function lockTo(pos)
    Lock.pos = pos
    Lock.since = os.clock()
    Lock.active = true
end

local function unlock()
    Lock.active = false
    if CFG.CameraAbove then restoreCamera() end
end

-- ============================================================
-- SAFE SPOT  (surface point used by panic + low HP retreat)
-- ============================================================
local SafeSpot = Vector3.new(0, 12, 0)

local function rememberSafeSpot()
    local _, _, hrp = getChar()
    if hrp then SafeSpot = hrp.Position end
end

local GroundCache = {}
local GROUND_CELL = 12

function groundUnder(x, z, fromY)
    local key = string.format("%d:%d", math.floor(x / GROUND_CELL), math.floor(z / GROUND_CELL))
    local cached = GroundCache[key]
    if cached and os.clock() - cached.t < 20 then
        return cached.y
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = LP.Character
    if char then params.FilterDescendantsInstances = { char } end
    local hit = Workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -1200, 0), params)
    local y = hit and hit.Position.Y or nil
    GroundCache[key] = { y = y, t = os.clock() }
    return y
end

-- ============================================================
-- CACHE
-- ============================================================
local Cache = {
    orbs = {},
    breakables = {},
    creatures = {},
    zones = {},
    zoneCount = {},
    orbCount = 0,
    breakableCount = 0,
    creatureCount = 0,
    totalXP = 0,
    totalCoins = 0,
    totalHP = 0,
    sweeps = 0,
    hits = 0,
    misses = 0,
    lastSweep = 0,
    lastSweepMs = 0,
    avgSweepMs = 0,
}

local function sweep()
    local t0 = os.clock()

    local orbFolder = Workspace:FindFirstChild("Orbs")
    local orbs = {}
    if orbFolder then
        for _, o in ipairs(orbFolder:GetChildren()) do
            if o:IsA("BasePart") then
                orbs[#orbs + 1] = { inst = o, pos = o.Position, xp = o:GetAttribute("XP") or 0 }
            end
        end
    end
    Cache.orbs = orbs
    Cache.orbCount = #orbs

    local breakables, zones, zoneCount = {}, {}, {}
    local totalXP, totalCoins, totalHP = 0, 0, 0

    for _, b in ipairs(CollectionService:GetTagged("Breakable")) do
        if b.Parent then
            local p = partOf(b)
            if p then
                local xp = b:GetAttribute("XP") or 0
                local coins = b:GetAttribute("Coins") or 0
                local hp = b:GetAttribute("HP") or 0
                local maxhp = b:GetAttribute("MaxHP") or hp
                local zone = b:GetAttribute("Zone") or "Unknown"
                local id = b:GetAttribute("BreakId") or b.Name

                breakables[#breakables + 1] = {
                    inst = b,
                    pos = p.Position,
                    hp = hp,
                    maxhp = maxhp,
                    xpleft = b:GetAttribute("XPLeft") or xp,
                    xp = xp,
                    coins = coins,
                    radius = b:GetAttribute("Radius") or 1,
                    zone = zone,
                    id = id,
                }
                zones[zone] = true
                zoneCount[zone] = (zoneCount[zone] or 0) + 1
                totalXP = totalXP + xp
                totalCoins = totalCoins + coins
                totalHP = totalHP + hp
            end
        end
    end

    Cache.breakables = breakables
    Cache.breakableCount = #breakables
    Cache.zones = zones
    Cache.zoneCount = zoneCount
    Cache.totalXP = totalXP
    Cache.totalCoins = totalCoins
    Cache.totalHP = totalHP

    local creatures = {}
    for _, c in ipairs(CollectionService:GetTagged("Creature")) do
        if c.Parent and not c:GetAttribute("Corpse") then
            local p = partOf(c)
            if p then
                creatures[#creatures + 1] = {
                    inst = c,
                    pos = p.Position,
                    hp = c:GetAttribute("HP") or 0,
                    xp = c:GetAttribute("XP") or 0,
                }
            end
        end
    end
    Cache.creatures = creatures
    Cache.creatureCount = #creatures

    Cache.sweeps = Cache.sweeps + 1
    Cache.lastSweep = os.clock()
    Cache.lastSweepMs = (os.clock() - t0) * 1000
    Cache.avgSweepMs = Cache.avgSweepMs == 0 and Cache.lastSweepMs
        or (Cache.avgSweepMs * 0.8 + Cache.lastSweepMs * 0.2)
end

local function cacheFresh()
    if os.clock() - Cache.lastSweep > CFG.CacheTTL then
        Cache.misses = Cache.misses + 1
        sweep()
    else
        Cache.hits = Cache.hits + 1
    end
end

-- ============================================================
-- TELEMETRY
-- ============================================================
local T = {
    startedAt = os.clock(),
    xp0 = LP:GetAttribute("TotalXP") or 0,
    coins0 = LP:GetAttribute("Coins") or 0,
    level0 = LP:GetAttribute("Level") or 1,
    orbs = 0,
    orbXP = 0,
    breaks = 0,
    kills = 0,
    attacks = 0,
    landed = 0,
    deaths = 0,
    respawns = 0,
    traits = 0,
    levelsGained = 0,
    lastLevel = LP:GetAttribute("Level") or 1,
    xpHist = {},
    coinHist = {},
    rateHist = {},
    rateXP = 0,
    rateCoins = 0,
    lastXP = 0,
    lastCoins = 0,
    lastSample = os.clock(),
    typeBreaks = {},
    zoneBreaks = {},
    log = {},
    logDirty = true,
}

local function xpNow() return LP:GetAttribute("TotalXP") or 0 end
local function coinNow() return LP:GetAttribute("Coins") or 0 end
local function levelNow() return LP:GetAttribute("Level") or 1 end
local function xpInLevel() return LP:GetAttribute("XP") or 0 end
local function xpNeed() return LP:GetAttribute("XPNeed") or 0 end

local function logEvent(fmt, ...)
    local line = string.format(fmt, ...)
    T.log[#T.log + 1] = string.format("[%s] %s", os.date("%H:%M:%S"), line)
    while #T.log > 40 do table.remove(T.log, 1) end
    T.logDirty = true
end

local function pushSample()
    local now = os.clock()
    local dt = now - T.lastSample
    if dt < 0.5 then return end
    T.lastSample = now

    local xp, coins = xpNow(), coinNow()
    T.rateXP = (xp - T.lastXP) / dt * 60
    T.rateCoins = (coins - T.lastCoins) / dt * 60
    T.lastXP, T.lastCoins = xp, coins

    local lvl = levelNow()
    if lvl > T.lastLevel then
        T.levelsGained = T.levelsGained + (lvl - T.lastLevel)
        logEvent("level up -> %d", lvl)
        T.lastLevel = lvl
    elseif lvl < T.lastLevel then
        T.deaths = T.deaths + 1
        logEvent("death, level reset to %d", lvl)
        T.lastLevel = lvl
    end

    T.xpHist[#T.xpHist + 1] = xp
    T.coinHist[#T.coinHist + 1] = coins
    T.rateHist[#T.rateHist + 1] = math.max(0, T.rateXP)
    while #T.xpHist > 120 do table.remove(T.xpHist, 1) end
    while #T.coinHist > 120 do table.remove(T.coinHist, 1) end
    while #T.rateHist > 120 do table.remove(T.rateHist, 1) end
end

-- ============================================================
-- TARGET SELECTION
-- ============================================================
local function zoneOK(entry)
    if CFG.Zone == "All" then return true end
    return entry.zone == CFG.Zone
end

local function score(entry, hrp)
    local d = (entry.pos - hrp.Position).Magnitude
    if d > CFG.Radius then return nil end

    if CFG.Priority == "Nearest" then
        return d
    elseif CFG.Priority == "Highest XP" then
        return -(entry.xpleft or entry.xp or 0) + d * 0.001
    elseif CFG.Priority == "Weakest" then
        return (entry.hp or 999) + d * 0.001
    elseif CFG.Priority == "Value / distance" then
        local value = (entry.xpleft or entry.xp or 1)
        return -(value / (1 + d / 40))
    end
    return d
end

local function pick(list, hrp)
    local best, bestScore
    for _, e in ipairs(list) do
        if e.inst.Parent and zoneOK(e) then
            local s = score(e, hrp)
            if s and (not bestScore or s < bestScore) then
                best, bestScore = e, s
            end
        end
    end
    return best
end

-- ============================================================
-- POSITIONING
-- ============================================================
local function anchorFor(pos)
    local reach = reachNow()
    if not CFG.UnderMap then
        return pos + Vector3.new(0, 2.2, 0) + Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.5
    end

    -- depth is measured from the target, never from the terrain: a fixed drop
    -- keeps every blink small and keeps the body out of the fall-damage range
    local maxDrop = math.max(1.0, reach - 1.0)
    local depth = math.min(CFG.Depth, maxDrop)
    local y = pos.Y - depth

    -- if that still sits above the terrain, push just under it
    local gy = groundUnder(pos.X, pos.Z, pos.Y + 300)
    if gy and y > gy - 1.5 then y = gy - 1.5 end

    if y < pos.Y - maxDrop then y = pos.Y - maxDrop end
    if y < CFG.VoidFloor then y = CFG.VoidFloor end

    return Vector3.new(pos.X, y, pos.Z)
end

local function retreat()
    unlock()
    local char, _, hrp = getChar()
    if not hrp then return end
    local y = groundUnder(hrp.Position.X, hrp.Position.Z, hrp.Position.Y + 60)
    local target = Vector3.new(hrp.Position.X, (y and y + 3) or SafeSpot.Y, hrp.Position.Z)
    hrp.CFrame = CFrame.new(target)
end

-- ============================================================
-- ACTIONS
-- ============================================================
local function collectOrb(hrp)
    cacheFresh()
    local best, bestD
    for _, o in ipairs(Cache.orbs) do
        if o.inst.Parent then
            local d = (o.pos - hrp.Position).Magnitude
            if d <= CFG.OrbRadius and (not bestD or o.xp > best.xp or (o.xp == best.xp and d < bestD)) then
                best, bestD = o, d
            end
        end
    end
    if not best then return false end

    local xp = best.xp
    lockTo(anchorFor(best.pos))

    local deadline = os.clock() + 0.55
    while os.clock() < deadline do
        task.wait(0.05)
        if not best.inst.Parent then
            T.orbs = T.orbs + 1
            T.orbXP = T.orbXP + xp
            return true
        end
    end
    return true
end

local function killTarget(entry, kind)
    local inst = entry.inst
    local part = partOf(inst)
    if not part then return false end

    lockTo(anchorFor(part.Position))
    task.wait(0.10)

    local deadline = os.clock() + 20
    local lastHP = inst:GetAttribute("HP") or entry.hp or 0
    local stalledAt = os.clock()
    local startHP = lastHP

    while alive() and os.clock() < deadline do
        if not inst.Parent then
            break
        end

        local hp = inst:GetAttribute("HP")
        if hp ~= nil and hp <= 0 then
            task.wait(0.10)
            break
        end

        if not CFG.Enabled then return false end

        local d = (part.Position - Lock.pos).Magnitude
        if d > reachNow() - 1.0 then
            lockTo(anchorFor(part.Position))
            task.wait(0.06)
        end

        REM.Attack:FireServer(inst)
        T.attacks = T.attacks + 1
        if hp ~= nil and hp < lastHP then
            T.landed = T.landed + 1
            stalledAt = os.clock()
        end
        lastHP = hp or lastHP

        if os.clock() - stalledAt > CFG.StallTimeout then
            logEvent("stall on %s, re-target", tostring(entry.id))
            return false
        end

        task.wait(biteInterval())
    end

    if kind == "breakable" then
        T.breaks = T.breaks + 1
        T.typeBreaks[entry.id] = (T.typeBreaks[entry.id] or 0) + 1
        T.zoneBreaks[entry.zone] = (T.zoneBreaks[entry.zone] or 0) + 1
    else
        T.kills = T.kills + 1
    end
    if startHP > 0 then
        local bites = math.max(1, math.ceil(startHP / math.max(damageNow(), 1)))
        logEvent("%s down (%d hp, ~%d bites)", tostring(entry.id), startHP, bites)
    end
    return true
end

-- ============================================================
-- SAFETY SYSTEMS
-- ============================================================
local lastTraitAt, lastRespawnAt, lastRetreatAt = 0, 0, 0

local function traitOpen()
    local pg = LP:FindFirstChild("PlayerGui")
    local t = pg and pg:FindFirstChild("Traits")
    return t ~= nil and t:IsA("ScreenGui") and t.Enabled
end

local function autoTrait()
    if not CFG.AutoTrait then return end
    if os.clock() - lastTraitAt < 1.6 then return end
    if not traitOpen() then return end
    lastTraitAt = os.clock()
    T.traits = T.traits + 1
    logEvent("trait card taken")
    pcall(function() REM.PickTrait:FireServer(1) end)
end

local function autoRespawn()
    if not CFG.AutoRespawn then return end
    if os.clock() - lastRespawnAt < 2.5 then return end
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 then return end
    lastRespawnAt = os.clock()
    T.respawns = T.respawns + 1
    logEvent("respawn request")
    pcall(function() REM.RequestSpawn:FireServer("Respawn") end)
end

local function healthPercent()
    local _, hum = getChar()
    if not hum then return 0 end
    return (hum.Health / math.max(hum.MaxHealth, 1)) * 100
end

local function lowHP()
    if not CFG.LowHPGuard then return false end
    local char, hum = getChar()
    if not char then return false end
    return (hum.Health / math.max(hum.MaxHealth, 1)) * 100 < CFG.LowHPPercent
end

-- ============================================================
-- FARM LOOP
-- ============================================================
local function farmTick()
    autoTrait()

    if not CFG.Enabled then
        unlock()
        task.wait(0.2)
        return
    end

    if lowHP() then
        unlock()
        if CFG.RetreatOnLowHP and os.clock() - lastRetreatAt > 4 then
            lastRetreatAt = os.clock()
            retreat()
            logEvent("low hp (%.0f%%), surfaced", healthPercent())
        end
        task.wait(0.35)
        return
    end

    local char, hum, hrp = getChar()
    if not char then
        unlock()
        autoRespawn()
        task.wait(0.4)
        return
    end

    local did = false

    if CFG.CollectOrbs and collectOrb(hrp) then did = true end

    if CFG.Breakables then
        cacheFresh()
        local e = pick(Cache.breakables, hrp)
        if e then
            killTarget(e, "breakable")
            did = true
        end
    end

    if CFG.Creatures then
        cacheFresh()
        local e = pick(Cache.creatures, hrp)
        if e then
            killTarget(e, "creature")
            did = true
        end
    end

    if not did then task.wait(0.2) else task.wait(0.05) end
end

local function farmLoop()
    while alive() do
        local ok, err = xpcall(farmTick, debug.traceback)
        if not ok then
            warn("[Aetherist/BE] farm: " .. tostring(err))
            task.wait(0.5)
        end
    end
end

-- ============================================================
-- UI
-- ============================================================
-- a previous load in the same session leaves its own ScreenGui behind when
-- getgenv is wiped (executor re-inject), so clear those before building.
do
    local function purge(parent, depth)
        if not parent or depth > 4 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child.Name == "RayfieldGen2" then
                pcall(function() child:Destroy() end)
            elseif child:IsA("ScreenGui") or child:IsA("Folder") then
                purge(child, depth + 1)
            end
        end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then pcall(purge, cg, 0) end
    pcall(purge, LP:FindFirstChild("PlayerGui"), 0)
end

local Window = Rayfield:CreateWindow({
    Name = "Aetherist / BE",
    Subtitle = "Bug Evolution  |  under-map autofarm",
    Icon = "bug",
    Badge = { Text = VERSION, Icon = "zap" },
    LoadingTitle = "Aetherist / BE",
    LoadingSubtitle = "warming the cache",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AetheristBE",
        FileName = "BugEvolution",
    },
})
STATE.window = Window

local FarmTab = Window:CreateTab("Farm", "bug")
local DataTab = Window:CreateTab("Data", "activity")
local SafeTab = Window:CreateTab("Safety", "shield")
local CfgTab  = Window:CreateTab("Config", "settings")

-- ============================================================
-- FARM TAB
-- ============================================================
FarmTab:CreateSection("Loop")

FarmTab:CreateToggle({
    Name = "Enable farm",
    Icon = "play",
    CurrentValue = false,
    Flag = "FarmEnabled",
    Description = "Master switch. Everything below only runs while this is on.",
    Callback = function(v)
        CFG.Enabled = v
        logEvent(v and "farm on" or "farm off")
    end,
})

FarmTab:CreateSection("Targets")

FarmTab:CreateToggle({
    Name = "Collect orbs",
    Icon = "sparkles",
    CurrentValue = true,
    Flag = "CollectOrbs",
    Callback = function(v) CFG.CollectOrbs = v end,
})

FarmTab:CreateToggle({
    Name = "Break breakables",
    Icon = "box",
    CurrentValue = true,
    Flag = "BreakBreakables",
    Callback = function(v) CFG.Breakables = v end,
})

FarmTab:CreateToggle({
    Name = "Hunt creatures",
    Icon = "crosshair",
    CurrentValue = false,
    Flag = "HuntCreatures",
    Description = "Corpses are skipped automatically.",
    Callback = function(v) CFG.Creatures = v end,
})

FarmTab:CreateDropdown({
    Name = "Priority",
    Icon = "list-ordered",
    Options = { "Value / distance", "Highest XP", "Nearest", "Weakest" },
    CurrentOption = { "Value / distance" },
    Flag = "Priority",
    Callback = function(sel)
        CFG.Priority = sel[1] or "Value / distance"
    end,
})

FarmTab:CreateDropdown({
    Name = "Zone filter",
    Icon = "map",
    Options = { "All" },
    CurrentOption = { "All" },
    Flag = "ZoneFilter",
    Callback = function(sel)
        CFG.Zone = sel[1] or "All"
    end,
})

FarmTab:CreateSlider({
    Name = "Target radius",
    Icon = "radar",
    Range = { 50, 1200 },
    Increment = 25,
    Suffix = " studs",
    CurrentValue = 900,
    Flag = "Radius",
    Callback = function(v) CFG.Radius = v end,
})

FarmTab:CreateSlider({
    Name = "Orb radius",
    Icon = "circle-dot",
    Range = { 10, 400 },
    Increment = 10,
    Suffix = " studs",
    CurrentValue = 180,
    Flag = "OrbRadius",
    Callback = function(v) CFG.OrbRadius = v end,
})

FarmTab:CreateSection("Cache")

FarmTab:CreateSlider({
    Name = "Cache TTL",
    Icon = "database",
    Range = { 0.2, 3 },
    Increment = 0.1,
    Suffix = " s",
    CurrentValue = 0.6,
    Flag = "CacheTTL",
    Callback = function(v) CFG.CacheTTL = v end,
})

FarmTab:CreateButton({
    Name = "Rebuild cache now",
    Icon = "refresh-cw",
    Callback = function()
        sweep()
        logEvent("cache rebuilt in %.1f ms", Cache.lastSweepMs)
        Rayfield:Notify({
            Title = "Cache rebuilt",
            Content = string.format("%d breakables  |  %d orbs  |  %d creatures  |  %.1f ms",
                Cache.breakableCount, Cache.orbCount, Cache.creatureCount, Cache.lastSweepMs),
            Duration = 4,
            Image = "database",
        })
    end,
})

FarmTab:CreateSection("Panic")

FarmTab:CreateButton({
    Name = "Stop and surface",
    Icon = "arrow-up-from-line",
    Callback = function()
        CFG.Enabled = false
        unlock()
        retreat()
        logEvent("panic: stopped and surfaced")
        Rayfield:Notify({
            Title = "Stopped",
            Content = "Farm off, character back on the surface.",
            Duration = 4,
            Image = "shield",
        })
    end,
})

-- ============================================================
-- DATA TAB
-- ============================================================
DataTab:CreateSection("Core")

local RowA = DataTab:CreateColumns(3)
local StatLevel = RowA:CreateStat({ Name = "Level", Icon = "trending-up", Value = "1", Delta = "+0" })
local StatXP    = RowA:CreateStat({ Name = "XP", Icon = "sparkles", Value = "0", Delta = "0/0" })
local StatCoins = RowA:CreateStat({ Name = "Coins", Icon = "coins", Value = "0", Delta = "+0" })

DataTab:CreateSection("Throughput")

local RowB = DataTab:CreateColumns(3)
local StatRateXP    = RowB:CreateStat({ Name = "XP / min", Icon = "gauge", Value = "0", Delta = "live" })
local StatRateCoins = RowB:CreateStat({ Name = "Coins / min", Icon = "wallet", Value = "0", Delta = "live" })
local StatETA       = RowB:CreateStat({ Name = "Next level", Icon = "hourglass", Value = "-", Delta = "no data" })

DataTab:CreateSection("Combat")

local RowC = DataTab:CreateColumns(3)
local StatReach  = RowC:CreateStat({ Name = "Reach", Icon = "move", Value = "0", Delta = "studs" })
local StatDamage = RowC:CreateStat({ Name = "Damage", Icon = "sword", Value = "0", Delta = "per bite" })
local StatDepth  = RowC:CreateStat({ Name = "Depth", Icon = "arrow-down", Value = "0", Delta = "under map" })

DataTab:CreateSection("Session")

local RowD = DataTab:CreateColumns(3)
local StatBreaks = RowD:CreateStat({ Name = "Broken", Icon = "box", Value = "0", Delta = "0 orbs" })
local StatKills  = RowD:CreateStat({ Name = "Creatures", Icon = "crosshair", Value = "0", Delta = "0 kills" })
local StatAcc    = RowD:CreateStat({ Name = "Hit rate", Icon = "target", Value = "0%", Delta = "0 bites" })

DataTab:CreateSection("Cache")

local RowE = DataTab:CreateColumns(3)
local StatCacheHit = RowE:CreateStat({ Name = "Cache hit", Icon = "database", Value = "0%", Delta = "0 sweeps" })
local StatSweepMs  = RowE:CreateStat({ Name = "Sweep", Icon = "timer", Value = "0", Delta = "ms avg" })
local StatWorld    = RowE:CreateStat({ Name = "World XP", Icon = "globe", Value = "0", Delta = "0 coins" })

DataTab:CreateSection("History")

local ChartXP = DataTab:CreateChart({
    Name = "Total XP",
    Icon = "sparkles",
    Filled = true,
    Points = { 0, 0 },
})

local ChartCoins = DataTab:CreateChart({
    Name = "Coins",
    Icon = "coins",
    Filled = false,
    Points = { 0, 0 },
})

local ChartRate = DataTab:CreateChart({
    Name = "XP per minute",
    Icon = "activity",
    Suffix = " xp",
    Smooth = true,
    Points = { 0, 0 },
})

DataTab:CreateSection("World composition")

local BarZones = DataTab:CreateBarChart({
    Name = "Breakables by zone",
    Icon = "map",
    Points = {
        { Label = "-", Value = 0 }, { Label = "-", Value = 0 }, { Label = "-", Value = 0 },
        { Label = "-", Value = 0 }, { Label = "-", Value = 0 }, { Label = "-", Value = 0 },
    },
})

DataTab:CreateSection("Live feed")

local Feed = DataTab:CreateLabel("waiting for events", "terminal")

DataTab:CreateButton({
    Name = "Replay charts",
    Icon = "play",
    Callback = function()
        pcall(function() ChartXP:Replay() end)
        pcall(function() ChartCoins:Replay() end)
        pcall(function() ChartRate:Replay() end)
    end,
})

DataTab:CreateButton({
    Name = "Reset session stats",
    Icon = "rotate-ccw",
    Callback = function()
        T.startedAt = os.clock()
        T.xp0, T.coins0, T.level0 = xpNow(), coinNow(), levelNow()
        T.orbs, T.orbXP, T.breaks, T.kills, T.attacks, T.landed = 0, 0, 0, 0, 0, 0
        T.deaths, T.respawns, T.traits, T.levelsGained = 0, 0, 0, 0
        T.xpHist, T.coinHist, T.rateHist = {}, {}, {}
        T.typeBreaks, T.zoneBreaks = {}, {}
        T.log = {}
        T.lastXP, T.lastCoins = xpNow(), coinNow()
        logEvent("session reset")
        Rayfield:Notify({ Title = "Session reset", Content = "Counters and charts cleared.", Duration = 3, Image = "rotate-ccw" })
    end,
})

-- ============================================================
-- SAFETY TAB
-- ============================================================
SafeTab:CreateSection("Position")

SafeTab:CreateToggle({
    Name = "Under-map lock",
    Icon = "eye-off",
    CurrentValue = true,
    Flag = "UnderMap",
    Description = "Holds the body below the target's own Y so the blinks never show above ground.",
    Callback = function(v)
        CFG.UnderMap = v
        if not v then unlock() end
    end,
})

SafeTab:CreateSlider({
    Name = "Depth",
    Icon = "arrow-down",
    Range = { 1, 14 },
    Increment = 1,
    Suffix = " studs",
    CurrentValue = 9,
    Flag = "Depth",
    Description = "Clamped to Reach - 1.0 so every bite still validates.",
    Callback = function(v) CFG.Depth = v end,
})

SafeTab:CreateSlider({
    Name = "Void floor",
    Icon = "shield-alert",
    Range = { -10, 10 },
    Increment = 0.5,
    Suffix = " Y",
    CurrentValue = -1,
    Flag = "VoidFloor",
    Description = "Hard floor. Death wipes TotalXP in this game, so the lock never goes below it.",
    Callback = function(v) CFG.VoidFloor = v end,
})

SafeTab:CreateSection("Camera")

SafeTab:CreateToggle({
    Name = "Lift the camera",
    Icon = "video",
    CurrentValue = true,
    Flag = "CameraAbove",
    Description = "The body is buried, so the view sits CameraHeight above the lock point instead of inside the terrain.",
    Callback = function(v)
        CFG.CameraAbove = v
        if not v then restoreCamera() end
    end,
})

SafeTab:CreateSlider({
    Name = "Camera height",
    Icon = "move-vertical",
    Range = { 20, 160 },
    Increment = 5,
    Suffix = " studs",
    CurrentValue = 55,
    Flag = "CameraHeight",
    Callback = function(v) CFG.CameraHeight = v end,
})

SafeTab:CreateSection("Behaviour")
SafeTab:CreateToggle({
    Name = "Delay jitter",
    Icon = "waves",
    CurrentValue = true,
    Flag = "Jitter",
    Callback = function(v) CFG.Jitter = v end,
})

SafeTab:CreateSlider({
    Name = "Stall timeout",
    Icon = "timer-off",
    Range = { 3, 20 },
    Increment = 1,
    Suffix = " s",
    CurrentValue = 9,
    Flag = "StallTimeout",
    Description = "Drops a target that has not lost HP for this long.",
    Callback = function(v) CFG.StallTimeout = v end,
})

SafeTab:CreateToggle({
    Name = "Low HP guard",
    Icon = "heart-pulse",
    CurrentValue = true,
    Flag = "LowHPGuard",
    Description = "Pauses the loop under the threshold instead of feeding a death.",
    Callback = function(v) CFG.LowHPGuard = v end,
})

SafeTab:CreateSlider({
    Name = "HP threshold",
    Icon = "heart",
    Range = { 5, 90 },
    Increment = 1,
    Suffix = "%",
    CurrentValue = 22,
    Flag = "LowHPPercent",
    Callback = function(v) CFG.LowHPPercent = v end,
})

SafeTab:CreateToggle({
    Name = "Surface when low",
    Icon = "arrow-up-from-line",
    CurrentValue = true,
    Flag = "RetreatOnLowHP",
    Description = "Under the threshold the lock releases and the body is put back on the surface until it heals.",
    Callback = function(v) CFG.RetreatOnLowHP = v end,
})

SafeTab:CreateToggle({
    Name = "Auto respawn",
    Icon = "rotate-cw",
    CurrentValue = true,
    Flag = "AutoRespawn",
    Callback = function(v) CFG.AutoRespawn = v end,
})

SafeTab:CreateToggle({
    Name = "Auto trait pick",
    Icon = "git-branch",
    CurrentValue = true,
    Flag = "AutoTrait",
    Description = "Takes the first card whenever the trait panel opens.",
    Callback = function(v) CFG.AutoTrait = v end,
})

SafeTab:CreateSection("Panic key")

SafeTab:CreateKeybind({
    Name = "Stop and surface",
    Icon = "shield",
    CurrentKeybind = "P",
    Flag = "PanicKey",
    Callback = function()
        CFG.Enabled = false
        unlock()
        retreat()
        logEvent("panic key: stopped and surfaced")
        Rayfield:Notify({
            Title = "Panic",
            Content = "Farm off, body surfaced.",
            Duration = 4,
            Image = "shield",
        })
    end,
})

-- ============================================================
-- CONFIG TAB
-- ============================================================
CfgTab:CreateSection("Session")

CfgTab:CreateButton({
    Name = "Save configuration",
    Icon = "save",
    Callback = function()
        pcall(function() Rayfield:SaveConfiguration() end)
        Rayfield:Notify({ Title = "Saved", Content = "AetheristBE/BugEvolution written.", Duration = 3, Image = "save" })
    end,
})

CfgTab:CreateButton({
    Name = "Load configuration",
    Icon = "folder-open",
    Callback = function()
        pcall(function() Rayfield:LoadConfiguration() end)
        Rayfield:Notify({ Title = "Loaded", Content = "Flags restored from disk.", Duration = 3, Image = "folder-open" })
    end,
})

CfgTab:CreateSection("Runtime")

CfgTab:CreateButton({
    Name = "Print diagnostic snapshot",
    Icon = "terminal",
    Callback = function()
        local lines = {
            string.format("%s  gen=%d  reach=%.2f  damage=%.1f  depth=%.1f  floor=%.1f",
                VERSION, MY_GEN, reachNow(), damageNow(), CFG.Depth, CFG.VoidFloor),
            string.format("cache=%d/%d/%d sweeps=%d avg=%.1fms hit=%.0f%%",
                Cache.breakableCount, Cache.orbCount, Cache.creatureCount, Cache.sweeps, Cache.avgSweepMs,
                (Cache.hits + Cache.misses) > 0 and (Cache.hits / (Cache.hits + Cache.misses) * 100) or 0),
            string.format("attacks=%d landed=%d breaks=%d orbs=%d kills=%d deaths=%d",
                T.attacks, T.landed, T.breaks, T.orbs, T.kills, T.deaths),
            string.format("xp=%d xp/min=%.0f coins=%d coins/min=%.0f",
                xpNow(), T.rateXP, coinNow(), T.rateCoins),
            string.format("level=%d xpInLevel=%d need=%d", levelNow(), xpInLevel(), xpNeed()),
        }
        print("[Aetherist/BE]\n" .. table.concat(lines, "\n"))
        logEvent("diagnostic printed")
    end,
})

CfgTab:CreateSection("About")

CfgTab:CreateFAQ({
    Items = {
        {
            Question = "Why is the character under the map?",
            Answer = "Hit validation is a 3D distance check against the Reach attribute, so a point straight below a target is still in range. Holding that point keeps the blink out of every sightline, and the orb pickup radius is wide enough to loot from the same depth.",
        },
        {
            Question = "Why does death matter so much?",
            Answer = "RespawnKeepXP is 0, so dying resets TotalXP and drops Level to 1. The void floor, the HP guard and the panic key all exist to keep that from happening.",
        },
        {
            Question = "Why is the bite interval not adjustable?",
            Answer = "The server enforces 1 / (AttackSpeed * AttackSpeedMult) between accepted bites. Anything faster is silently dropped, so the interval is derived from your live attributes instead of a guess.",
        },
        {
            Question = "What does Value / distance do?",
            Answer = "It scores each breakable by its remaining XP divided by distance, so a fat target across the map beats a cheap one next to you without ever walking into a corner where the only targets left are worth nothing.",
        },
    },
})

-- ============================================================
-- DATA REFRESH
-- ============================================================
local lastChartPush = 0
local lastBarBuild = 0

local function refreshUI()
    pushSample()

    local xp, coins, lvl = xpNow(), coinNow(), levelNow()
    local xpGain = xp - T.xp0
    local coinGain = coins - T.coins0
    local levelGain = lvl - T.level0

    pcall(function()
        StatLevel:Set({ Value = tostring(lvl), Delta = (levelGain >= 0 and "+" or "") .. tostring(levelGain) })
        StatXP:Set({ Value = tostring(xp), Delta = string.format("%d/%d", xpInLevel(), xpNeed()) })
        StatCoins:Set({ Value = tostring(coins), Delta = (coinGain >= 0 and "+" or "") .. tostring(coinGain) })
    end)

    pcall(function()
        StatRateXP:Set({ Value = string.format("%.0f", T.rateXP), Delta = "live" })
        StatRateCoins:Set({ Value = string.format("%.0f", T.rateCoins), Delta = "live" })

        local need = xpNeed() - xpInLevel()
        if T.rateXP > 1 and need > 0 then
            local minutes = need / T.rateXP
            StatETA:Set({
                Value = minutes < 1 and string.format("%.0fs", minutes * 60) or string.format("%.1fm", minutes),
                Delta = string.format("%d xp left", need),
            })
        else
            StatETA:Set({ Value = "-", Delta = "no data" })
        end
    end)

    pcall(function()
        StatReach:Set({ Value = string.format("%.1f", reachNow()), Delta = "studs" })
        StatDamage:Set({ Value = string.format("%.1f", damageNow()), Delta = "per bite" })
        StatDepth:Set({ Value = string.format("%.1f", math.min(CFG.Depth, math.max(1, reachNow() - 1.0))), Delta = "under map" })
    end)

    pcall(function()
        StatBreaks:Set({ Value = tostring(T.breaks), Delta = T.orbs .. " orbs" })
        StatKills:Set({ Value = tostring(T.kills), Delta = string.format("%d deaths", T.deaths) })
        local acc = T.attacks > 0 and (T.landed / T.attacks * 100) or 0
        StatAcc:Set({ Value = string.format("%.0f%%", acc), Delta = T.attacks .. " bites" })
    end)

    pcall(function()
        local total = Cache.hits + Cache.misses
        local hit = total > 0 and (Cache.hits / total * 100) or 0
        StatCacheHit:Set({ Value = string.format("%.0f%%", hit), Delta = Cache.sweeps .. " sweeps" })
        StatSweepMs:Set({ Value = string.format("%.1f", Cache.avgSweepMs), Delta = "ms avg" })
        StatWorld:Set({ Value = tostring(Cache.totalXP), Delta = Cache.totalCoins .. " coins" })
    end)

    if T.logDirty then
        T.logDirty = false
        local tail = {}
        local first = math.max(1, #T.log - 5)
        for i = first, #T.log do tail[#tail + 1] = T.log[i] end
        pcall(function() Feed:Set(#tail > 0 and table.concat(tail, "\n") or "waiting for events") end)
    end

    if os.clock() - lastChartPush > 5 then
        lastChartPush = os.clock()
        pcall(function() ChartXP:Push(xp) end)
        pcall(function() ChartCoins:Push(coins) end)
        pcall(function() ChartRate:Push(math.max(0, T.rateXP)) end)
    end

    if os.clock() - lastBarBuild > 15 then
        lastBarBuild = os.clock()
        local list = {}
        for zone, count in pairs(Cache.zoneCount) do list[#list + 1] = { Label = zone, Value = count } end
        table.sort(list, function(a, b) return a.Value > b.Value end)
        local points = {}
        for i = 1, 6 do
            points[i] = list[i] or { Label = "-", Value = 0 }
        end
        pcall(function() BarZones:Set({ Points = points }) end)
    end
end

-- ============================================================
-- BOOT
-- ============================================================
sweep()
rememberSafeSpot()
T.lastXP, T.lastCoins = xpNow(), coinNow()
T.lastLevel = levelNow()

STATE.cfg = CFG
STATE.T = T
STATE.Cache = Cache
STATE.Lock = Lock
STATE.unlock = unlock
STATE.retreat = retreat

logEvent("cache warmed: %d breakables, %d orbs", Cache.breakableCount, Cache.orbCount)

task.spawn(function()
    while alive() do
        local ok, err = xpcall(refreshUI, debug.traceback)
        if not ok then warn("[Aetherist/BE] ui: " .. tostring(err)) end
        task.wait(1)
    end
end)

task.spawn(farmLoop)

pcall(function() Rayfield:LoadConfiguration() end)

Rayfield:Notify({
    Title = "Aetherist / BE  " .. VERSION,
    Content = string.format("%d breakables, %d orbs cached. Reach %.2f, bite %.2fs.",
        Cache.breakableCount, Cache.orbCount, reachNow(), biteInterval()),
    Duration = 6,
    Image = "bug",
})
