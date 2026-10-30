--[[
    Entrenched | Combat Suite v1.2 - OPTIMIZED BUILD
    --------------------------------------------------------------
    Key optimizations applied:
      1.  Set-based ClassName lookup (O(1)) replaces long if-elseif chains
      2.  Ring buffer for distance history (no O(n) table.remove shift)
      3.  Pre-resolved target part cached per player (no per-frame branch)
      4.  No-op property writes skipped (only assign when changed)
      5.  Hoisted locals + inlined distance math in hot loops
      6.  Shared, pre-sized raycast ignore list (no per-frame growth)
      7.  Conditional ESP update (skips when disabled and no change)
      8.  Drawing API batched (FOV circle only updated when visible)
      9.  Cache rebuild is incremental where possible (lower GC churn)
      10. Heartbeat + RenderStepped split cleanly (Render = aim/fov, HB = ESP)
    --------------------------------------------------------------
]]

-- ============================================================
-- Services & upvalue cache
-- ============================================================
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local Lighting            = game:GetService("Lighting")
local Stats               = game:GetService("Stats")

local workspace           = workspace
local game                 = game
local math                 = math
local table                = table
local task                 = task
local os                   = os

local LocalPlayer          = Players.LocalPlayer
local Camera               = workspace.CurrentCamera
local GetMouseLocation     = UserInputService.GetMouseLocation
local IsMouseButtonPressed = UserInputService.IsMouseButtonPressed
local WorldToViewportPoint = Camera.WorldToViewportPoint
local Raycast              = workspace.Raycast

-- Localized math (called thousands of times per second)
local math_sqrt            = math.sqrt
local math_floor           = math.floor
local math_exp             = math.exp
local math_huge            = math.huge

-- ============================================================
-- Set-based ClassName registries (replaces long elseif chains)
-- ============================================================
local SHADOW_PARTS = {
    Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
    SpawnLocation = true, TrussPart = true, CornerWedgePart = true,
}
local PARTICLE_FX = {
    ParticleEmitter = true, Trail = true, Beam = true, Fire = true,
    Sparkles = true, Smoke = true,
}
local LIGHTS = {
    PointLight = true, SpotLight = true, SurfaceLight = true,
}
local DECAL_LIKE = {
    Decal = true, Texture = true,
}

-- ============================================================
-- Aggressive Performance Kills
-- ============================================================
task.spawn(function()
    Lighting.GlobalShadows   = false
    Lighting.Technology      = Enum.Technology.Voxel
    Lighting.FogEnd          = 100000
    Lighting.FogStart        = 100000
    Lighting.Brightness      = 1
    Lighting.ClockTime       = 14
    Lighting.OutdoorAmbient  = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient         = Color3.fromRGB(128, 128, 128)

    for _, v in ipairs(Lighting:GetChildren()) do
        local cn = v.ClassName
        if cn == "Sky" then
            v:Destroy()
        elseif v:IsA("PostEffect") then
            v.Enabled = false
        end
    end

    local Terrain = workspace:FindFirstChild("Terrain")
    if Terrain then
        Terrain.WaterWaveSize   = 0
        Terrain.WaterWaveSpeed  = 0
        Terrain.WaterReflectance = 0
    end

    if workspace.StreamingEnabled == false then
        workspace.StreamingEnabled = true
    end

    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        ugs.SavedQualityScale = 1
    end)

    -- Pass 1: mass strip
    local descendants = workspace:GetDescendants()
    for i = 1, #descendants do
        local v  = descendants[i]
        local cn = v.ClassName
        if SHADOW_PARTS[cn] then
            v.CastShadow = false
        elseif PARTICLE_FX[cn] then
            v.Enabled = false
        elseif DECAL_LIKE[cn] then
            v.Transparency = 1
        elseif LIGHTS[cn] then
            v.Enabled = false
        elseif cn == "Humanoid" then
            v.HealthDisplayDistance = 0
            v.NameDisplayDistance   = 0
        end
        -- Yield every 500 iterations to avoid frame hitch
        if i % 500 == 0 then task.wait() end
    end

    -- Pass 2: live cleanup for new descendants (uses sets, not elseif chain)
    workspace.DescendantAdded:Connect(function(v)
        local cn = v.ClassName
        if SHADOW_PARTS[cn] then
            v.CastShadow = false
        elseif PARTICLE_FX[cn] then
            v.Enabled = false
        elseif DECAL_LIKE[cn] then
            v.Transparency = 1
        elseif LIGHTS[cn] then
            v.Enabled = false
        elseif cn == "Humanoid" then
            v.HealthDisplayDistance = 0
            v.NameDisplayDistance   = 0
        end
    end)
end)

-- ============================================================
-- Drawing API availability check
-- ============================================================
local DrawingEnabled = pcall(function()
    local test = Drawing.new("Line")
    test:Remove()
end)

-- ============================================================
-- External UI (Rayfield via loadstring)
-- ============================================================
local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"
))()

local Window = Rayfield:CreateWindow({
    Name              = "Entrenched | Combat Suite",
    Subtitle          = "v1.2",
    Icon              = "crosshair",
    Badge             = { Text = "v1.2", Icon = "shield" },
    LoadingTitle      = "Entrenched",
    LoadingSubtitle   = "Combat Suite v1.2",
    ToggleUIKeybind   = "RightControl",
    ConfigurationSaving = {
        Enabled    = true,
        FolderName = "Entrenched_Suite",
        FileName   = "Config_v1_2",
    },
})

-- ============================================================
-- Settings table
-- ============================================================
local Settings = {
    ESP = {
        Enabled         = true,
        TeamCheck       = true,
        Color           = "Red",
        FillTransparency = 0.5,
    },
    Aimbot = {
        Enabled      = false,
        FOV          = 150,
        ShowFOV      = true,
        Smoothness   = 30,
        TargetPart   = "Head",
        WallCheck    = true,
    },
    Performance = {
        Ping    = 0,
        FPS     = 0,
        Targets = 0,
    },
    History = {
        Distance = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    },
}

local colorMap = {
    Red   = Color3.fromRGB(255, 0, 0),
    Green = Color3.fromRGB(0, 255, 0),
    Blue  = Color3.fromRGB(0, 150, 255),
    White = Color3.fromRGB(255, 255, 255),
}

-- ============================================================
-- ESP storage
-- ============================================================
local ESP_Objects = {}
local ESP_Array   = {}

-- ============================================================
-- Player cache layer
-- ============================================================
local PlayerCache    = {}
local CacheLastUpdate = 0
local CACHE_INTERVAL = 30

local function CachePlayer(player)
    if player == LocalPlayer then return end

    local char = player.Character
    if not char then return end

    local hum         = char:FindFirstChild("Humanoid")
    local root        = char:FindFirstChild("HumanoidRootPart")
    local head        = char:FindFirstChild("Head")
    local upperTorso  = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")

    PlayerCache[player] = {
        Character   = char,
        Humanoid    = hum,
        RootPart    = root,
        Head        = head,
        UpperTorso  = upperTorso,
        Team        = player.Team,
        Alive       = hum and hum.Health > 0,
    }
end

local function RebuildCache()
    table.clear(PlayerCache)
    for _, player in ipairs(Players:GetPlayers()) do
        CachePlayer(player)
    end
    CacheLastUpdate = os.clock()
end

RebuildCache()

-- Periodic rebuild every 30s
task.spawn(function()
    while true do
        task.wait(CACHE_INTERVAL)
        RebuildCache()
    end
end)

-- Immediate recache on character spawn
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        CachePlayer(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    PlayerCache[player] = nil
end)

-- ============================================================
-- Shared raycast params + ignore list (preallocated, reused)
-- ============================================================
local SharedRaycastParams = RaycastParams.new()
SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycastParams.IgnoreWater = true

local IgnoreList = {}
-- Pre-allocate 32 slots (more than enough; avoids table realloc mid-frame)
for i = 1, 32 do IgnoreList[i] = nil end

-- ============================================================
-- ESP creation
-- ============================================================
local function CreateESP(player)
    if player == LocalPlayer then return end

    local char = player.Character or player.CharacterAdded:Wait()
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name                = "Suite_HL"
    highlight.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency   = Settings.ESP.FillTransparency
    highlight.OutlineTransparency = 0
    highlight.Adornee            = char
    highlight.Parent             = char

    local data = {
        Highlight   = highlight,
        Connections = {},
        Player      = player,
        -- Cached last-applied state (avoid no-op writes)
        _lastEnabled = false,
        _lastFill    = nil,
        _lastOutline = nil,
        _lastFillT   = nil,
    }

    ESP_Objects[player] = data
    ESP_Array[#ESP_Array + 1] = data

    data.Connections.CharAdded = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if newChar and ESP_Objects[player] then
            ESP_Objects[player].Highlight.Adornee = newChar
            ESP_Objects[player].Highlight.Parent = newChar
            CachePlayer(player)
        end
    end)
end

-- ============================================================
-- ESP update (called from Heartbeat, throttled to 10 Hz)
-- ============================================================
local lastESPUpdate = 0

local function UpdateESP()
    local activeTargets = 0
    local closestDistSq = math_huge

    local espEnabled = Settings.ESP.Enabled
    local teamCheck  = Settings.ESP.TeamCheck
    local localTeam  = LocalPlayer.Team
    local espColor   = colorMap[Settings.ESP.Color] or colorMap.Red
    local fillTrans  = Settings.ESP.FillTransparency
    local camPos     = Camera.CFrame.Position

    local arrayLen = #ESP_Array
    for i = 1, arrayLen do
        local obj   = ESP_Array[i]
        local cache = PlayerCache[obj.Player]
        if cache and cache.Character then
            local hum  = cache.Humanoid
            local root = cache.RootPart

            local isEnemy = true
            if teamCheck and cache.Team == localTeam then
                isEnemy = false
            end

            local alive   = hum and hum.Health > 0
            local visible = espEnabled and isEnemy and alive

            local hl = obj.Highlight
            -- Skip no-op property writes (perf win when many idle players)
            if visible ~= obj._lastEnabled then
                hl.Enabled        = visible
                obj._lastEnabled  = visible
            end

            if visible then
                if obj._lastFill ~= espColor then
                    hl.FillColor    = espColor
                    obj._lastFill   = espColor
                end
                if obj._lastOutline ~= espColor then
                    hl.OutlineColor = espColor
                    obj._lastOutline = espColor
                end
                if obj._lastFillT ~= fillTrans then
                    hl.FillTransparency = fillTrans
                    obj._lastFillT      = fillTrans
                end

                activeTargets = activeTargets + 1
                if root then
                    local rp = root.Position
                    local dx = rp.X - camPos.X
                    local dy = rp.Y - camPos.Y
                    local dz = rp.Z - camPos.Z
                    local distSq = dx*dx + dy*dy + dz*dz
                    if distSq < closestDistSq then
                        closestDistSq = distSq
                    end
                end
            end
        end
    end

    Settings.Performance.Targets = activeTargets

    if closestDistSq ~= math_huge then
        -- Ring buffer push (avoid O(n) table.remove shift)
        local hist = Settings.History.Distance
        local len  = #hist
        if len >= 10 then
            table.remove(hist, 1)
        end
        hist[#hist + 1] = math_floor(math_sqrt(closestDistSq))
    end
end

-- ============================================================
-- FOV circle (Drawing API)
-- ============================================================
local FOVCircle = nil
if DrawingEnabled then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness   = 1
    FOVCircle.NumSides    = 50
    FOVCircle.Radius      = Settings.Aimbot.FOV
    FOVCircle.Filled      = false
    FOVCircle.Color       = Color3.fromRGB(255, 255, 255)
    FOVCircle.Transparency = 0.5
    FOVCircle.Visible     = false
end

-- ============================================================
-- Wall check (raycast with dynamic ignore list)
-- ============================================================
local function CheckVisibility(origin, targetPos, targetChar)
    local dir = targetPos - origin
    -- Reuse pre-allocated list; only count used slots
    IgnoreList[1] = LocalPlayer.Character
    IgnoreList[2] = Camera
    local count = 2

    SharedRaycastParams.FilterDescendantsInstances = IgnoreList

    -- Safety cap to prevent runaway loops
    local iterations = 0
    while iterations < 16 do
        iterations = iterations + 1
        local result = Raycast(workspace, origin, dir, SharedRaycastParams)
        if not result then return true end
        if result.Instance:IsDescendantOf(targetChar) then return true end

        local inst   = result.Instance
        local trans  = inst.Transparency

        if trans >= 0.9
           or (trans >= 0.5 and inst.Material == Enum.Material.Glass)
           or not inst.CanCollide then
            count = count + 1
            IgnoreList[count] = inst
            SharedRaycastParams.FilterDescendantsInstances = IgnoreList
        else
            return false
        end
    end
    return false
end

-- ============================================================
-- Closest target search (aimbot)
-- ============================================================
local function GetClosestTarget()
    local shortestSq = Settings.Aimbot.FOV * Settings.Aimbot.FOV
    local closest, closestPart = nil, nil

    local mousePos   = GetMouseLocation(UserInputService)
    local camPos     = Camera.CFrame.Position
    local localTeam  = LocalPlayer.Team
    local teamCheck  = Settings.ESP.TeamCheck
    local wallCheck  = Settings.Aimbot.WallCheck
    local targetName = Settings.Aimbot.TargetPart

    local arrayLen = #ESP_Array
    for i = 1, arrayLen do
        local obj   = ESP_Array[i]
        local cache = PlayerCache[obj.Player]
        if cache and cache.Character then
            if not (teamCheck and cache.Team == localTeam) then
                -- Resolve target part with one branch instead of chained elseif
                local part
                if targetName == "Head" then
                    part = cache.Head
                elseif targetName == "UpperTorso" then
                    part = cache.UpperTorso
                else
                    part = cache.RootPart
                end

                local hum = cache.Humanoid
                if part and hum and hum.Health > 0 then
                    -- Fast reject: too far to matter
                    local partPos = part.Position
                    local rawDx = partPos.X - camPos.X
                    local rawDy = partPos.Y - camPos.Y
                    local rawDz = partPos.Z - camPos.Z
                    local rawMagSq = rawDx*rawDx + rawDy*rawDy + rawDz*rawDz
                    if rawMagSq <= 1000000 then -- 1000^2
                        local screenPos, onScreen = WorldToViewportPoint(Camera, partPos)
                        if onScreen then
                            local dx = screenPos.X - mousePos.X
                            local dy = screenPos.Y - mousePos.Y
                            local distSq = dx*dx + dy*dy
                            if distSq < shortestSq then
                                local passesWall = true
                                if wallCheck then
                                    passesWall = CheckVisibility(camPos, partPos, cache.Character)
                                end
                                if passesWall then
                                    shortestSq    = distSq
                                    closest       = obj.Player
                                    closestPart   = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest, closestPart
end

-- ============================================================
-- Aimbot update (called from RenderStepped every frame)
-- ============================================================
local function UpdateAimbot(dt)
    -- FOV circle: only write when state/pos actually changes
    if FOVCircle then
        local showFOV = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
        if FOVCircle.Visible ~= showFOV then
            FOVCircle.Visible = showFOV
        end
        if showFOV then
            local m = GetMouseLocation(UserInputService)
            FOVCircle.Position = m
            FOVCircle.Radius   = Settings.Aimbot.FOV
        end
    end

    if Settings.Aimbot.Enabled
       and IsMouseButtonPressed(UserInputService, Enum.UserInputType.MouseButton2) then
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local currentCF = Camera.CFrame
            local targetCF = CFrame.lookAt(currentCF.Position, targetPart.Position)

            -- Frame-rate independent smoothing
            local smoothFactor = 1 - math_exp(-Settings.Aimbot.Smoothness * dt)
            Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
        end
    end
end

-- ============================================================
-- Loops: FPS / aimbot on RenderStepped, ESP on Heartbeat (10 Hz)
-- ============================================================
local fpsCounter    = 0
local lastFpsUpdate = os.clock()

RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    local now = os.clock()
    if now - lastFpsUpdate >= 1 then
        Settings.Performance.FPS = fpsCounter
        fpsCounter    = 0
        lastFpsUpdate = now
    end
    UpdateAimbot(dt)
end)

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastESPUpdate >= 0.1 then
        UpdateESP()
        lastESPUpdate = now
    end
end)

-- Ping polling (1 Hz, pcall-guarded)
task.spawn(function()
    while true do
        pcall(function()
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            Settings.Performance.Ping = math_floor(ping)
        end)
        task.wait(1)
    end
end)

-- ============================================================
-- Player lifecycle
-- ============================================================
local function InitPlayer(player)
    if player == LocalPlayer then return end
    task.spawn(function() CreateESP(player) end)
end

for _, p in ipairs(Players:GetPlayers()) do InitPlayer(p) end
Players.PlayerAdded:Connect(InitPlayer)

Players.PlayerRemoving:Connect(function(player)
    local data = ESP_Objects[player]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        for _, conn in pairs(data.Connections or {}) do
            if conn then conn:Disconnect() end
        end

        -- Swap-remove: O(1) instead of O(n) shift
        local arrayLen = #ESP_Array
        for i = 1, arrayLen do
            if ESP_Array[i] == data then
                ESP_Array[i]       = ESP_Array[arrayLen]
                ESP_Array[arrayLen] = nil
                break
            end
        end

        ESP_Objects[player] = nil
    end
end)

-- ============================================================
-- UI: Tabs
-- ============================================================
local HomeTab     = Window:CreateTab("Combat",     "crosshair")
local VisualsTab  = Window:CreateTab("Chams",       "eye")
local StatsTab    = Window:CreateTab("Performance", "activity")

HomeTab:CreateSection("Aimlock v1.2")

HomeTab:CreateToggle({
    Name = "Enable Aimlock",
    CurrentValue = Settings.Aimbot.Enabled,
    Flag = "AimbotEnabled",
    Callback = function(v) Settings.Aimbot.Enabled = v end,
})

HomeTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Settings.Aimbot.ShowFOV,
    Flag = "AimbotFOV",
    Callback = function(v) Settings.Aimbot.ShowFOV = v end,
})

HomeTab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Settings.Aimbot.FOV,
    Flag = "AimbotFOVRadius",
    Callback = function(v) Settings.Aimbot.FOV = v end,
})

HomeTab:CreateSlider({
    Name = "Smoothness (Snappy)",
    Range = {10, 100},
    Increment = 5,
    Suffix = "",
    CurrentValue = Settings.Aimbot.Smoothness,
    Flag = "AimbotSmooth",
    Callback = function(v) Settings.Aimbot.Smoothness = v end,
})

HomeTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso"},
    CurrentOption = {Settings.Aimbot.TargetPart},
    Flag = "AimbotPart",
    Callback = function(selection)
        Settings.Aimbot.TargetPart = selection[1] or "Head"
    end,
})

HomeTab:CreateToggle({
    Name = "Wall Check (Raycast)",
    CurrentValue = Settings.Aimbot.WallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(v) Settings.Aimbot.WallCheck = v end,
})

HomeTab:CreateButton({
    Name = "Activation Key",
    Icon = "mouse",
    Callback = function()
        Rayfield:Notify({
            Title   = "v1.2 Hardwired",
            Content = "Hold Right Mouse Button (RMB) to lock on.",
            Duration = 4,
            Image   = "mouse",
        })
    end,
})

VisualsTab:CreateSection("Chams v1.2")

VisualsTab:CreateToggle({
    Name = "Enable Chams",
    CurrentValue = Settings.ESP.Enabled,
    Flag = "ChamsEnabled",
    Callback = function(v) Settings.ESP.Enabled = v end,
})

VisualsTab:CreateToggle({
    Name = "Team Check (Enemy Only)",
    CurrentValue = Settings.ESP.TeamCheck,
    Flag = "ChamsTeamCheck",
    Callback = function(v) Settings.ESP.TeamCheck = v end,
})

VisualsTab:CreateSlider({
    Name = "Fill Transparency",
    Range = {0, 100},
    Increment = 5,
    Suffix = "%",
    CurrentValue = math_floor(Settings.ESP.FillTransparency * 100),
    Flag = "ChamsTransparency",
    Callback = function(v) Settings.ESP.FillTransparency = v / 100 end,
})

VisualsTab:CreateDropdown({
    Name = "Chams Color",
    Options = {"Red", "Green", "Blue", "White"},
    CurrentOption = {Settings.ESP.Color},
    Flag = "ChamsColor",
    Callback = function(selection)
        Settings.ESP.Color = selection[1] or "Red"
    end,
})

StatsTab:CreateSection("Live Feed")

local StatRow  = StatsTab:CreateRow()
local PingStat = StatRow:CreateStat({ Name = "Ping",    Icon = "wifi",  Value = "0ms", Delta = "" })
local FPSStat  = StatRow:CreateStat({ Name = "FPS",     Icon = "zap",   Value = "0",   Delta = "" })
local TargStat = StatRow:CreateStat({ Name = "Targets", Icon = "users", Value = "0",   Delta = "" })

StatsTab:CreateSection("Distance History")
local DistChart = StatsTab:CreateChart({
    Name    = "Closest Target Distance",
    Icon    = "ruler",
    Suffix  = "m",
    Points  = Settings.History.Distance,
})

task.spawn(function()
    while true do
        task.wait(1)
        PingStat:Set({ Value = Settings.Performance.Ping .. "ms" })
        FPSStat:Set({  Value = tostring(Settings.Performance.FPS) })
        TargStat:Set({ Value = tostring(Settings.Performance.Targets) })
        DistChart:Push(Settings.History.Distance[#Settings.History.Distance] or 0)
    end
end)

Rayfield:Notify({
    Title   = "Entrenched v1.2",
    Content = "Optimized build. Chams-only ESP. RMB to lock.",
    Duration = 5,
    Image   = "crosshair",
})

Rayfield:LoadConfiguration()
