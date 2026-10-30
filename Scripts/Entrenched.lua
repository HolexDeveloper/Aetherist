--[[
    Entrenched | Combat Suite v1.3
    --------------------------------------------------------------
      * SILENT AIM (real): Crosshair hook decides the aim point before
        Shoot builds its raycasts, remote rewrite forces the damage
        payload. hookmetamethod with a verified fallback.
      * Exploits: Rapid Fire, Instant Reload, No Recoil, No Spread,
        Instant Revive, driven off the captured weapon state
      * Enemy-only ESP, team read live
      * Ban status parsed correctly -> "Banned" / "Safe"
      * Overlays hide instantly when their toggle goes off
      * Chunked frustum + distance culling, budgeted
      * Perf: highlight cap, drawing reuse, ring buffer, hooks only
        installed while silent aim is on
    --------------------------------------------------------------
]]

-- ============================================================
-- Services
-- ============================================================
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local Lighting            = game:GetService("Lighting")
local Stats               = game:GetService("Stats")
local SoundService        = game:GetService("SoundService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local workspace           = workspace
local math                = math
local table               = table
local task                = task
local os                  = os
local select              = select
local typeof              = typeof

local LocalPlayer          = Players.LocalPlayer
local Camera               = workspace.CurrentCamera
local GetMouseLocation     = UserInputService.GetMouseLocation
local WorldToViewportPoint = Camera.WorldToViewportPoint
local Raycast              = workspace.Raycast

local math_sqrt  = math.sqrt
local math_floor = math.floor
local math_clamp = math.clamp
local math_abs   = math.abs
local math_max   = math.max
local math_min   = math.min
local math_rad   = math.rad
local math_tan   = math.tan

local function RefreshCamera()
    local cam = workspace.CurrentCamera
    if cam and cam ~= Camera then
        Camera = cam
        WorldToViewportPoint = Camera.WorldToViewportPoint
    end
end

-- ============================================================
-- Settings
-- ============================================================
local Settings = {
    ESP = {
        Enabled = true,
        Color = "Red",
        FillTransparency = 0.5,
        MaxDistance = 600,
        Box = true,
        Name = true,
        Distance = true,
        Health = true,
        Skeleton = false,
        Tracer = false,
        ClassTag = true,
    },
    Silent = {
        Enabled = false,
        Key = "LMB",
        Mode = "Hold",
        FOV = 120,
        WallCheck = true,
        Part = "Head",
        Prediction = 0,
    },
    Misc = {
        Hitmarker = true,
        RapidFire = false,
        InstantReload = false,
        NoRecoil = false,
        NoSpread = false,
        InstantRevive = false,
        WalkSpeedEnabled = false,
        WalkSpeed = 16,
        JumpPower = 50,
        FOVLock = false,
        FOVValue = 70,
        Fullbright = false,
        NoFog = false,
        PostFX = false,
    },
    Render = { Culling = true, Distance = 700, Lite = false },
    Perf = { Ping = 0, FPS = 0, Targets = 0, Hits = 0, Shots = 0, Culled = 0 },
    History = { Distance = {0,0,0,0,0,0,0,0,0,0}, Index = 1, Last = 0 },
}

local colorMap = {
    Red = Color3.fromRGB(255, 0, 0), Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 150, 255), White = Color3.fromRGB(255, 255, 255),
    Yellow = Color3.fromRGB(255, 220, 60), Cyan = Color3.fromRGB(0, 255, 240),
}

local KEY_MAP = {
    RMB = Enum.UserInputType.MouseButton2, LMB = Enum.UserInputType.MouseButton1,
    LeftShift = Enum.KeyCode.LeftShift, LeftAlt = Enum.KeyCode.LeftAlt,
    E = Enum.KeyCode.E, Q = Enum.KeyCode.Q,
}

local MAX_HIGHLIGHTS = 12
local NO_RECOIL = { { 1, 0, 0, 0.77, 0 } }

-- ============================================================
-- Strip registries
-- ============================================================
local SHADOW_PARTS = {
    Part = true, MeshPart = true, UnionOperation = true, WedgePart = true,
    SpawnLocation = true, TrussPart = true, CornerWedgePart = true,
}
local PARTICLE_FX = {
    ParticleEmitter = true, Trail = true, Beam = true, Fire = true,
    Sparkles = true, Smoke = true,
}
local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }
local DECAL_LIKE = { Decal = true, Texture = true }

-- ============================================================
-- Culling store
-- ============================================================
local CULL_CHUNK  = 128
local CULL_BUDGET = 6
local Chunks, Registered = {}, {}
local CullQueue, CullHead = {}, 1

local function IsCharacterPart(p)
    local parent = p.Parent
    if not parent then return true end
    if parent:FindFirstChildOfClass("Humanoid") then return true end
    if parent:IsA("Accessory") or parent:IsA("Tool") then
        local gp = parent.Parent
        if gp and gp:FindFirstChildOfClass("Humanoid") then return true end
    end
    return false
end

local function RegisterPart(p)
    if Registered[p] then return end
    Registered[p] = true
    if p.Transparency >= 1 then return end
    local s = p.Size
    if math_max(s.X, s.Y, s.Z) > 300 then return end
    if IsCharacterPart(p) then return end

    local pos = p.Position
    local key = math_floor(pos.X / CULL_CHUNK) .. "|"
        .. math_floor(pos.Y / CULL_CHUNK) .. "|"
        .. math_floor(pos.Z / CULL_CHUNK)

    local chunk = Chunks[key]
    if not chunk then
        chunk = { Center = pos, Parts = {}, Visible = true }
        Chunks[key] = chunk
    end
    local parts = chunk.Parts
    parts[#parts + 1] = p
    parts[#parts + 1] = p.Transparency
end

local function StripInstance(v)
    local cn = v.ClassName
    if SHADOW_PARTS[cn] then
        v.CastShadow = false
        if v:IsA("MeshPart") then
            pcall(function() v.RenderFidelity = Enum.RenderFidelity.Performance end)
        end
        RegisterPart(v)
    elseif PARTICLE_FX[cn] then
        v.Enabled = false
    elseif DECAL_LIKE[cn] then
        v.Transparency = 1
    elseif LIGHTS[cn] then
        v.Enabled = false
    elseif cn == "Humanoid" then
        v.HealthDisplayDistance = 0
        v.NameDisplayDistance = 0
    end
end

task.spawn(function()
    Lighting.GlobalShadows  = false
    Lighting.Technology     = Enum.Technology.Voxel
    Lighting.FogEnd         = 100000
    Lighting.FogStart       = 100000
    Lighting.Brightness     = 1
    Lighting.ClockTime      = 14
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient        = Color3.fromRGB(128, 128, 128)

    for _, v in ipairs(Lighting:GetChildren()) do
        if v.ClassName == "Sky" then
            v:Destroy()
        elseif v:IsA("PostEffect") then
            v.Enabled = false
        end
    end

    local Terrain = workspace:FindFirstChild("Terrain")
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
    end

    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityScale = 1
        workspace.StreamingTargetRadius = 512
    end)

    local d = workspace:GetDescendants()
    for i = 1, #d do
        StripInstance(d[i])
        if i % 400 == 0 then task.wait() end
    end
    workspace.DescendantAdded:Connect(StripInstance)
end)

-- ============================================================
-- Culling engine
-- ============================================================
local function ApplyChunk(chunk)
    local parts, vis = chunk.Parts, chunk.Visible
    for i = 1, #parts, 2 do
        local part = parts[i]
        if part.Parent then
            part.Transparency = vis and parts[i + 1] or 1
        end
    end
end

local function CullStep()
    if not Settings.Render.Culling or not Camera then return end
    local camCF = Camera.CFrame
    local camPos = camCF.Position
    local vp = Camera.ViewportSize
    local tanV = math_tan(math_rad(Camera.FieldOfView * 0.5))
    local tanH = tanV * (vp.X / math_max(1, vp.Y))
    local maxD = Settings.Render.Distance
    local radius = CULL_CHUNK * 0.9
    local culled = 0

    for _, chunk in pairs(Chunks) do
        local c = chunk.Center
        local dx, dy, dz = c.X - camPos.X, c.Y - camPos.Y, c.Z - camPos.Z
        local dist = math_sqrt(dx*dx + dy*dy + dz*dz)
        local want = true

        if dist - radius > maxD then
            want = false
        else
            local rel = camCF:PointToObjectSpace(c)
            local depth = -rel.Z
            if depth < -radius then
                want = false
            elseif math_abs(rel.X) > depth * tanH + radius then
                want = false
            elseif math_abs(rel.Y) > depth * tanV + radius then
                want = false
            end
        end

        if want ~= chunk.Visible then
            chunk.Visible = want
            CullQueue[#CullQueue + 1] = chunk
        end
        if not want then culled = culled + 1 end
    end

    Settings.Perf.Culled = culled

    local budget = CULL_BUDGET
    while CullHead <= #CullQueue and budget > 0 do
        local chunk = CullQueue[CullHead]
        CullQueue[CullHead] = nil
        CullHead = CullHead + 1
        budget = budget - 1
        ApplyChunk(chunk)
    end
    if CullHead > #CullQueue then CullQueue, CullHead = {}, 1 end
end

local function ResetCulling()
    for _, chunk in pairs(Chunks) do
        if not chunk.Visible then
            chunk.Visible = true
            ApplyChunk(chunk)
        end
    end
    CullQueue, CullHead = {}, 1
end

-- ============================================================
-- Drawing + UI
-- ============================================================
local DrawingEnabled = pcall(function()
    local t = Drawing.new("Line"); t:Remove()
end)

local Rayfield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"
))()

local Window = Rayfield:CreateWindow({
    Name = "Entrenched | Combat Suite",
    Subtitle = "v1.3",
    Icon = "crosshair",
    Badge = { Text = "v1.3", Icon = "shield" },
    LoadingTitle = "Entrenched",
    LoadingSubtitle = "Combat Suite v1.3",
    ToggleUIKeybind = "RightControl",
    ConfigurationSaving = {
        Enabled = true, FolderName = "Entrenched_Suite", FileName = "Config_v1_3",
    },
})

-- ============================================================
-- Cache
-- ============================================================
local ESP_Objects, ESP_Array, PlayerCache = {}, {}, {}
local CACHE_INTERVAL = 45
local PART_NAMES = {
    "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local function IsEnemy(player)
    local lt = LocalPlayer.Team
    if not lt then return true end
    local t = player.Team
    return t == nil or t ~= lt
end

local function CachePlayer(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then PlayerCache[player] = nil return end

    local parts = {}
    for i = 1, #PART_NAMES do
        parts[PART_NAMES[i]] = char:FindFirstChild(PART_NAMES[i])
    end

    PlayerCache[player] = {
        Character  = char,
        Humanoid   = char:FindFirstChildOfClass("Humanoid"),
        RootPart   = parts.HumanoidRootPart,
        Head       = parts.Head,
        UpperTorso = parts.UpperTorso,
        Parts      = parts,
    }
end

local function RebuildCache()
    table.clear(PlayerCache)
    local list = Players:GetPlayers()
    for i = 1, #list do CachePlayer(list[i]) end
end

-- ============================================================
-- Raycast
-- ============================================================
local RParams = RaycastParams.new()
RParams.FilterType = Enum.RaycastFilterType.Exclude
RParams.IgnoreWater = true
local IgnoreList = {}

local function CheckVisibility(origin, targetPos, targetChar)
    local dir = targetPos - origin
    table.clear(IgnoreList)
    IgnoreList[1] = LocalPlayer.Character
    RParams.FilterDescendantsInstances = IgnoreList

    for _ = 1, 16 do
        local result = Raycast(workspace, origin, dir, RParams)
        if not result then return true end
        if result.Instance:IsDescendantOf(targetChar) then return true end
        local inst = result.Instance
        local tr = inst.Transparency
        if tr >= 0.9 or (tr >= 0.5 and inst.Material == Enum.Material.Glass) or not inst.CanCollide then
            IgnoreList[#IgnoreList + 1] = inst
            RParams.FilterDescendantsInstances = IgnoreList
        else
            return false
        end
    end
    return false
end

-- ============================================================
-- Hitmarker
-- ============================================================
local hitSound
task.spawn(function()
    local s = ReplicatedStorage:FindFirstChild("Sounds")
    local src = s and (s:FindFirstChild("Insert") or s:FindFirstChild("Melee"))
    if not src then return end
    hitSound = src:Clone()
    hitSound.Volume = 0.6
    hitSound.PlaybackSpeed = 1.4
    hitSound.Parent = SoundService
end)

local function PlayHitmarker()
    if not Settings.Misc.Hitmarker or not hitSound then return end
    Settings.Perf.Hits = Settings.Perf.Hits + 1
    hitSound.TimePosition = 0
    hitSound:Play()
end

-- ============================================================
-- ESP objects
-- ============================================================
local function CreateHighlight(char)
    local hl = Instance.new("Highlight")
    hl.Name = "Suite_HL"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillTransparency = Settings.ESP.FillTransparency
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = char
    return hl
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    local char = player.Character or player.CharacterAdded:Wait()
    if not char then return end

    local data = {
        Player = player,
        Highlight = CreateHighlight(char),
        Draw = { List = {} },
        Connections = {},
        _enabled = false,
        _fill = nil,
        _outline = nil,
        _fillT = nil,
        _rank = nil,
    }
    ESP_Objects[player] = data
    ESP_Array[#ESP_Array + 1] = data

    local function HookHealth()
        if data.HealthConn then data.HealthConn:Disconnect() end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local last = hum.Health
        data.HealthConn = hum.HealthChanged:Connect(function(h)
            if h < last then PlayHitmarker() end
            last = h
        end)
    end
    HookHealth()

    data.Connections.CharAdded = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        local d = ESP_Objects[player]
        if not d or not newChar or not newChar.Parent then return end
        if d.Highlight then d.Highlight:Destroy() end
        d.Highlight = CreateHighlight(newChar)
        d._enabled = false
        char = newChar
        CachePlayer(player)
        HookHealth()
    end)
end

local function DestroyESP(player)
    local data = ESP_Objects[player]
    if not data then return end
    if data.Highlight then data.Highlight:Destroy() end
    if data.HealthConn then data.HealthConn:Disconnect() end
    for _, c in pairs(data.Connections) do c:Disconnect() end
    for i = 1, #data.Draw.List do pcall(function() data.Draw.List[i]:Remove() end) end

    local len = #ESP_Array
    for i = 1, len do
        if ESP_Array[i] == data then
            ESP_Array[i] = ESP_Array[len]
            ESP_Array[len] = nil
            break
        end
    end
    ESP_Objects[player] = nil
end

local function mk(data, class, props)
    local ok, d = pcall(Drawing.new, class)
    if not ok or not d then return nil end
    for k, v in pairs(props) do d[k] = v end
    data.Draw.List[#data.Draw.List + 1] = d
    return d
end

local function hideDraws(data)
    local list = data.Draw.List
    for i = 1, #list do
        if list[i].Visible then list[i].Visible = false end
    end
end

local SKELETON = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

-- ============================================================
-- Chams (8 Hz, capped)
-- ============================================================
local lastESP = 0
local candObj, candDist = {}, {}

local function UpdateESP()
    local col = colorMap[Settings.ESP.Color] or colorMap.Red
    local fillT = Settings.ESP.FillTransparency
    local camPos = Camera.CFrame.Position
    local maxSq = Settings.ESP.MaxDistance ^ 2
    local on = Settings.ESP.Enabled
    local n = 0

    for i = 1, #ESP_Array do
        local obj = ESP_Array[i]
        local cache = PlayerCache[obj.Player]
        obj._rank = nil
        if on and cache and cache.Character then
            local hum = cache.Humanoid
            local root = cache.RootPart
            if root and hum and hum.Health > 0 and IsEnemy(obj.Player) then
                local p = root.Position
                local dx, dy, dz = p.X - camPos.X, p.Y - camPos.Y, p.Z - camPos.Z
                local dSq = dx*dx + dy*dy + dz*dz
                if dSq <= maxSq then
                    n = n + 1
                    candObj[n] = obj
                    candDist[n] = dSq
                end
            end
        end
    end

    for i = 2, n do
        local d, o = candDist[i], candObj[i]
        local j = i - 1
        while j > 0 and candDist[j] > d do
            candDist[j + 1] = candDist[j]
            candObj[j + 1] = candObj[j]
            j = j - 1
        end
        candDist[j + 1] = d
        candObj[j + 1] = o
    end

    local limit = math_min(n, MAX_HIGHLIGHTS)
    for i = 1, limit do
        candObj[i]._rank = i
        candObj[i] = nil
    end
    for i = limit + 1, n do
        candObj[i] = nil
    end

    local active = 0
    for i = 1, #ESP_Array do
        local obj = ESP_Array[i]
        local show = obj._rank ~= nil
        local hl = obj.Highlight
        if hl then
            if show ~= obj._enabled then
                hl.Enabled = show
                obj._enabled = show
            end
            if show then
                if obj._fill ~= col then hl.FillColor = col; obj._fill = col end
                if obj._outline ~= col then hl.OutlineColor = col; obj._outline = col end
                if obj._fillT ~= fillT then hl.FillTransparency = fillT; obj._fillT = fillT end
                active = active + 1
            end
        end
    end

    Settings.Perf.Targets = active

    if limit > 0 then
        local hist = Settings.History.Distance
        local idx = Settings.History.Index
        local d = math_floor(math_sqrt(candDist[1]))
        hist[idx] = d
        Settings.History.Index = (idx % 10) + 1
        Settings.History.Last = d
    end
end

-- ============================================================
-- Overlay ESP (25 Hz, highlighted targets only)
-- ============================================================
local lastDraw = 0
local TEXT = 14

local function UpdateDrawings()
    local esp = Settings.ESP
    local on = esp.Enabled and not Settings.Render.Lite
    local col = colorMap[esp.Color] or colorMap.Red
    local camPos = Camera.CFrame.Position
    local mouse = GetMouseLocation(UserInputService)
    local origin = Vector2.new(mouse.X, mouse.Y)

    for i = 1, #ESP_Array do
        local data = ESP_Array[i]
        local draw = data.Draw
        local cache = PlayerCache[data.Player]
        local shown = false

        if on and data._enabled and cache and cache.Character then
            local hum = cache.Humanoid
            local head, root = cache.Head, cache.RootPart
            if hum and hum.Health > 0 and head and root then
                local hp = head.Position
                local hs, headOn = WorldToViewportPoint(Camera, hp)
                local rs, rootOn = WorldToViewportPoint(Camera, root.Position)
                if headOn and rootOn and hs.Z > 0 then
                    shown = true
                    local topY = hs.Y - 8
                    local botY = rs.Y + 6
                    local h = math_abs(botY - topY)
                    local w = h * 0.42
                    local left = (hs.X + rs.X) * 0.5 - w * 0.5
                    local right = left + w
                    local mid = (left + right) * 0.5

                    if esp.Box then
                        if not draw.Box then
                            draw.Box = {}
                            for k = 1, 4 do draw.Box[k] = mk(data, "Line", { Thickness = 1 }) end
                        end
                        local b = draw.Box
                        if b[1] then
                            b[1].From = Vector2.new(left, topY);  b[1].To = Vector2.new(right, topY)
                            b[2].From = Vector2.new(left, botY);  b[2].To = Vector2.new(right, botY)
                            b[3].From = Vector2.new(left, topY);  b[3].To = Vector2.new(left, botY)
                            b[4].From = Vector2.new(right, topY); b[4].To = Vector2.new(right, botY)
                            for k = 1, 4 do b[k].Color = col; b[k].Visible = true end
                        end
                    elseif draw.Box and draw.Box[1] then
                        for k = 1, 4 do draw.Box[k].Visible = false end
                    end

                    if esp.Name then
                        if not draw.Name then
                            draw.Name = mk(data, "Text", { Center = true, Outline = true, Font = 2 })
                        end
                        if draw.Name then
                            draw.Name.Color = col
                            draw.Name.Size = TEXT
                            draw.Name.Position = Vector2.new(mid, topY - TEXT - 4)
                            draw.Name.Text = data.Player.DisplayName
                            draw.Name.Visible = true
                        end
                    elseif draw.Name then
                        draw.Name.Visible = false
                    end

                    if esp.Distance then
                        if not draw.Dist then
                            draw.Dist = mk(data, "Text", { Center = true, Outline = true, Font = 2 })
                        end
                        if draw.Dist then
                            draw.Dist.Color = col
                            draw.Dist.Size = TEXT - 2
                            draw.Dist.Position = Vector2.new(mid, botY + 2)
                            draw.Dist.Text = ("%d m"):format((hp - camPos).Magnitude)
                            draw.Dist.Visible = true
                        end
                    elseif draw.Dist then
                        draw.Dist.Visible = false
                    end

                    if esp.Health and hum.MaxHealth > 0 then
                        if not draw.HPBack then
                            draw.HPBack = mk(data, "Square", { Filled = true })
                            draw.HPFill = mk(data, "Square", { Filled = true })
                        end
                        if draw.HPBack and draw.HPFill then
                            local frac = math_clamp(hum.Health / hum.MaxHealth, 0, 1)
                            draw.HPBack.Color = Color3.new(0, 0, 0)
                            draw.HPBack.Size = Vector2.new(3, h)
                            draw.HPBack.Position = Vector2.new(left - 6, topY)
                            draw.HPBack.Visible = true
                            draw.HPFill.Color = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(60, 255, 60), frac)
                            draw.HPFill.Size = Vector2.new(3, h * frac)
                            draw.HPFill.Position = Vector2.new(left - 6, botY - h * frac)
                            draw.HPFill.Visible = true
                        end
                    elseif draw.HPBack then
                        draw.HPBack.Visible = false
                        if draw.HPFill then draw.HPFill.Visible = false end
                    end

                    if esp.ClassTag then
                        if not draw.Class then
                            draw.Class = mk(data, "Text", { Center = true, Outline = true, Font = 2 })
                        end
                        if draw.Class then
                            local c = data.Player:GetAttribute("Class")
                            local sub = data.Player:GetAttribute("SubClass")
                            local label = c and (sub and (c .. "/" .. sub) or c) or ""
                            draw.Class.Text = label
                            draw.Class.Color = Color3.fromRGB(255, 220, 110)
                            draw.Class.Size = TEXT - 3
                            draw.Class.Position = Vector2.new(mid, botY + TEXT)
                            draw.Class.Visible = label ~= ""
                        end
                    elseif draw.Class then
                        draw.Class.Visible = false
                    end

                    if esp.Tracer then
                        if not draw.Tracer then draw.Tracer = mk(data, "Line", { Thickness = 1 }) end
                        if draw.Tracer then
                            draw.Tracer.Color = col
                            draw.Tracer.From = origin
                            draw.Tracer.To = Vector2.new(hs.X, hs.Y)
                            draw.Tracer.Visible = true
                        end
                    elseif draw.Tracer then
                        draw.Tracer.Visible = false
                    end

                    if esp.Skeleton then
                        if not draw.Skel then
                            draw.Skel = {}
                            for k = 1, #SKELETON do draw.Skel[k] = mk(data, "Line", { Thickness = 1 }) end
                        end
                        local parts = cache.Parts
                        for k = 1, #SKELETON do
                            local line = draw.Skel[k]
                            if line then
                                local a = parts[SKELETON[k][1]]
                                local b = parts[SKELETON[k][2]]
                                if a and b then
                                    local sa, oka = WorldToViewportPoint(Camera, a.Position)
                                    local sb, okb = WorldToViewportPoint(Camera, b.Position)
                                    if oka and okb then
                                        line.From = Vector2.new(sa.X, sa.Y)
                                        line.To = Vector2.new(sb.X, sb.Y)
                                        line.Color = col
                                        line.Visible = true
                                    else
                                        line.Visible = false
                                    end
                                else
                                    line.Visible = false
                                end
                            end
                        end
                    elseif draw.Skel then
                        for k = 1, #draw.Skel do
                            if draw.Skel[k].Visible then draw.Skel[k].Visible = false end
                        end
                    end
                end
            end
        end

        if not shown then hideDraws(data) end
    end
end

-- ============================================================
-- Key state
-- ============================================================
local pressed, silentToggled = {}, false

UserInputService.InputBegan:Connect(function(input)
    local k = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
    pressed[k] = true
    if k == KEY_MAP[Settings.Silent.Key] and Settings.Silent.Mode == "Toggle" then
        silentToggled = not silentToggled
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local k = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
    pressed[k] = false
end)

local function SilentActive()
    if not Settings.Silent.Enabled then return false end
    if Settings.Silent.Key == "Always" then return true end
    if Settings.Silent.Mode == "Toggle" then return silentToggled end
    return pressed[KEY_MAP[Settings.Silent.Key]] == true
end

-- ============================================================
-- Target search
-- ============================================================
local function GetTarget(fov, partName, wallCheck, prediction)
    local shortest = fov * fov
    local best, bestPart = nil, nil
    local mouse = GetMouseLocation(UserInputService)
    local camPos = Camera.CFrame.Position
    local localTeam = LocalPlayer.Team
    local pred = prediction / 100

    for i = 1, #ESP_Array do
        local player = ESP_Array[i].Player
        local cache = PlayerCache[player]
        if cache and cache.Character and cache.Humanoid and cache.Humanoid.Health > 0 then
            local t = player.Team
            if not localTeam or t == nil or t ~= localTeam then
                local part
                if partName == "Head" then part = cache.Head
                elseif partName == "UpperTorso" then part = cache.UpperTorso
                else part = cache.RootPart end
                if part then
                    local pos = part.Position
                    if pred > 0 then pos = pos + part.AssemblyLinearVelocity * pred end
                    local rx, ry, rz = pos.X - camPos.X, pos.Y - camPos.Y, pos.Z - camPos.Z
                    if rx*rx + ry*ry + rz*rz <= 810000 then
                        local sp, onScreen = WorldToViewportPoint(Camera, pos)
                        if onScreen then
                            local dx, dy = sp.X - mouse.X, sp.Y - mouse.Y
                            local dSq = dx*dx + dy*dy
                            if dSq < shortest then
                                if not wallCheck or CheckVisibility(camPos, pos, cache.Character) then
                                    shortest = dSq
                                    best, bestPart = player, part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return best, bestPart
end

-- ============================================================
-- Weapon state capture + hooks
-- ============================================================
local ShootRemote, ReloadRemote, EquipRemote
local weaponState = nil
local mt, oldNamecall = nil, nil
local crosshairHooked, namecallHooked = false, false
local silentPos, silentStamp, silentPart = nil, 0, nil

task.spawn(function()
    local se = ReplicatedStorage:WaitForChild("ServerEvents", 30)
    if not se then return end
    ShootRemote = se:WaitForChild("Shoot", 30)
    ReloadRemote = se:WaitForChild("Reload", 30)
    EquipRemote = se:WaitForChild("Equip", 30)
end)

local function CaptureState(st)
    if typeof(st) ~= "table" then return end
    weaponState = st
    if Settings.Misc.NoRecoil then
        st.RecoilPattern = NO_RECOIL
        local tool = st.Tool
        if tool and tool:GetAttribute("Recoil") ~= 0 then
            tool:SetAttribute("Recoil", 0)
        end
    end
end

-- ---- primary hook: Crosshair decides the aim point before Shoot
-- ---- builds its spread raycasts, so the hit table fills naturally
local CrosshairOrig = nil

local function InstallCrosshairHook()
    if crosshairHooked then return true end
    local ok = pcall(function()
        local module = ReplicatedStorage:WaitForChild("WeaponModule")
        require(module)
        local env = getsenv(module)
        local orig = env and env.Crosshair
        assert(typeof(orig) == "function", "no Crosshair")
        CrosshairOrig = orig
        hookfunction(orig, newcclosure(function(...)
            if silentPos and SilentActive() then
                return silentPos
            end
            return CrosshairOrig(...)
        end))
    end)
    crosshairHooked = ok
    return ok
end

-- ---- secondary hook: rewrite the remote args outright
local function BuildHit(part)
    return {{
        Instance = part,
        Position = part.Position,
        Normal = (Camera.CFrame.Position - part.Position).Unit,
        Material = part.Material,
    }}
end

local function onNamecall(self, ...)
    if checkcaller() then return oldNamecall(self, ...) end

    if self == ShootRemote or self == ReloadRemote or self == EquipRemote then
        local first = select(1, ...)
        if typeof(first) == "table" then CaptureState(first) end

        if self == ShootRemote and silentPos and silentPart and SilentActive() then
            local n = select("#", ...)
            local args = { ... }
            if typeof(args[2]) == "Vector3" then
                local camPos = Camera.CFrame.Position
                args[2] = silentPos
                if n >= 5 then
                    args[4] = 1
                    args[5] = BuildHit(silentPart)
                end
                if n >= 6 then args[6] = camPos end
                Settings.Perf.Shots = Settings.Perf.Shots + 1
                return oldNamecall(self, table.unpack(args, 1, n))
            end
        end
    end
    return oldNamecall(self, ...)
end

local function InstallNamecallHook()
    if namecallHooked then return true end
    local got = pcall(function()
        mt = getrawmetatable(game)
        oldNamecall = mt.__namecall
        return typeof(oldNamecall) == "function"
    end)
    if not got then return false end

    local wrapper = newcclosure(onNamecall)

    local ok = pcall(function()
        hookmetamethod(game, "__namecall", wrapper)
    end)
    if not ok then
        ok = pcall(function()
            setreadonly(mt, false)
            mt.__namecall = wrapper
            setreadonly(mt, true)
            return rawget(mt, "__namecall") == wrapper
        end)
    end
    namecallHooked = ok
    return ok
end

local function InstallHooks()
    local cross = InstallCrosshairHook()
    local nc = InstallNamecallHook()
    return cross or nc, cross, nc
end

local function UninstallHooks()
    if crosshairHooked and CrosshairOrig then
        pcall(function()
            local env = getsenv(ReplicatedStorage:WaitForChild("WeaponModule"))
            if env and env.Crosshair ~= CrosshairOrig then
                hookfunction(env.Crosshair, CrosshairOrig)
            end
        end)
        crosshairHooked = false
    end
    if namecallHooked and mt and oldNamecall then
        pcall(function()
            setreadonly(mt, false)
            mt.__namecall = oldNamecall
            setreadonly(mt, true)
        end)
        namecallHooked = false
    end
end

-- silent aim FOV circle
local SilentCircle
if DrawingEnabled then
    SilentCircle = Drawing.new("Circle")
    SilentCircle.Thickness = 1
    SilentCircle.NumSides = 72
    SilentCircle.Filled = false
    SilentCircle.Color = Color3.fromRGB(0, 255, 240)
    SilentCircle.Transparency = 0.7
    SilentCircle.Visible = false
end

local function UpdateSilent()
    if not Settings.Silent.Enabled then
        silentPos, silentPart = nil, nil
        if SilentCircle and SilentCircle.Visible then SilentCircle.Visible = false end
        return
    end

    local m = GetMouseLocation(UserInputService)
    if SilentCircle then
        SilentCircle.Position = Vector2.new(m.X, m.Y)
        SilentCircle.Radius = Settings.Silent.FOV
        SilentCircle.Visible = true
    end

    local _, part = GetTarget(Settings.Silent.FOV, Settings.Silent.Part,
        Settings.Silent.WallCheck, Settings.Silent.Prediction)

    if part then
        local pos = part.Position
        if Settings.Silent.Prediction > 0 then
            pos = pos + part.AssemblyLinearVelocity * (Settings.Silent.Prediction / 100)
        end
        silentPos, silentPart = pos, part
        silentStamp = os.clock()
    elseif os.clock() - silentStamp > 0.5 then
        silentPos, silentPart = nil, nil
    end
end

-- ============================================================
-- Exploits
-- ============================================================
local function LocalTool()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Tool")
end

task.spawn(function()
    while true do
        task.wait(0.2)
        local tool = LocalTool()

        if Settings.Misc.RapidFire and weaponState then
            weaponState.clientCanFire = true
        end

        if tool then
            if Settings.Misc.NoSpread then
                local bloom = tool:FindFirstChild("Bloom")
                if bloom and bloom:IsA("ValueBase") and bloom.Value ~= 0 then bloom.Value = 0 end
            end
            if Settings.Misc.NoRecoil and tool:GetAttribute("Recoil") ~= 0 then
                tool:SetAttribute("Recoil", 0)
            end
            if Settings.Misc.InstantReload then
                local ammo = tool:FindFirstChild("AmmoLoaded")
                local cap = tool:GetAttribute("AmmoCapacity")
                if ammo and cap and ammo:IsA("ValueBase") and ammo.Value < cap then
                    ammo.Value = cap
                end
                if weaponState and ReloadRemote and weaponState.Tool == tool then
                    task.spawn(function()
                        pcall(function() ReloadRemote:InvokeServer(weaponState) end)
                    end)
                end
            end
        end

        if Settings.Misc.InstantRevive then
            local me = LocalPlayer.Character
            local myRoot = me and me:FindFirstChild("HumanoidRootPart")
            if myRoot then
                local myPos = myRoot.Position
                local list = Players:GetPlayers()
                for i = 1, #list do
                    local p = list[i]
                    if p ~= LocalPlayer and p.Character and p.Team == LocalPlayer.Team then
                        local root = p.Character:FindFirstChild("HumanoidRootPart")
                        if root and (root.Position - myPos).Magnitude < 14 then
                            local d = p.Character:GetDescendants()
                            for j = 1, #d do
                                if d[j]:IsA("ProximityPrompt") then
                                    pcall(fireproximityprompt, d[j])
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- Movement
-- ============================================================
local function ApplyWalkSpeed(hum)
    if not Settings.Misc.WalkSpeedEnabled or not hum then return end
    if hum:GetAttribute("DefaultWalkSpeed") ~= nil then
        hum:SetAttribute("DefaultWalkSpeed", math_clamp(Settings.Misc.WalkSpeed, 1, 30))
    end
end

local function ApplyJump(hum)
    if not hum then return end
    hum.UseJumpPower = true
    hum.JumpPower = math_clamp(Settings.Misc.JumpPower, 1, 50)
end

local function HookCharacter(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    if Settings.Misc.WalkSpeedEnabled then
        task.wait(0.6)
        ApplyWalkSpeed(hum)
    end
    if Settings.Misc.JumpPower < 50 then ApplyJump(hum) end
end

LocalPlayer.CharacterAdded:Connect(HookCharacter)
if LocalPlayer.Character then task.spawn(HookCharacter, LocalPlayer.Character) end

local function SetPostFX(v)
    for _, e in ipairs(Lighting:GetChildren()) do
        if e:IsA("PostEffect") then e.Enabled = v end
    end
end

-- ============================================================
-- Loops
-- ============================================================
local fps, lastFps = 0, os.clock()

RunService.RenderStepped:Connect(function()
    RefreshCamera()
    fps = fps + 1
    local now = os.clock()
    if now - lastFps >= 1 then
        Settings.Perf.FPS = fps
        fps, lastFps = 0, now
    end

    if Settings.Misc.FOVLock and Camera then
        Camera.FieldOfView = Settings.Misc.FOVValue
    end

    UpdateSilent()
end)

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastESP >= 0.125 then
        UpdateESP()
        lastESP = now
    end
    if now - lastDraw >= 0.04 then
        if not Settings.Render.Lite then UpdateDrawings() end
        lastDraw = now
    end
    if now - (Settings.Perf._cull or 0) >= 0.12 then
        CullStep()
        Settings.Perf._cull = now
    end
end)

task.spawn(function()
    while true do
        pcall(function()
            Settings.Perf.Ping = math_floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        task.wait(1)
    end
end)

-- ============================================================
-- Player lifecycle
-- ============================================================
local function Track(p)
    CachePlayer(p)
    if p ~= LocalPlayer then task.spawn(CreateESP, p) end
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        CachePlayer(p)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do Track(p) end
Players.PlayerAdded:Connect(Track)
Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil
    DestroyESP(p)
end)

task.spawn(function()
    while true do
        task.wait(CACHE_INTERVAL)
        RebuildCache()
    end
end)

-- ============================================================
-- Stats
-- ============================================================
local ClientEvents
task.spawn(function()
    ClientEvents = ReplicatedStorage:WaitForChild("ClientEvents", 30)
end)

local function BanLabel(b)
    if b == nil or b == false then return "Safe" end
    if type(b) == "table" then
        local inner = b.Banned or b.IsBanned or b.Active
        local reason = b.Reason or b.reason or b.Message or b.message
        if reason and reason ~= "" then return "Banned (" .. tostring(reason) .. ")" end
        if inner ~= nil then return inner and "Banned" or "Safe" end
        if next(b) == nil then return "Safe" end
        return "Banned"
    end
    if type(b) == "string" then
        if b == "" or b == "false" or b == "0" then return "Safe" end
        return "Banned (" .. b .. ")"
    end
    if type(b) == "number" then return b ~= 0 and "Banned" or "Safe" end
    return "Banned"
end

local function ShowSelfStats()
    if not ClientEvents then
        Rayfield:Notify({ Title = "Not ready", Content = "ClientEvents missing.", Duration = 3 })
        return
    end
    task.spawn(function()
        local remote = ClientEvents:FindFirstChild("GetPlayerStats")
        if not remote then return end
        local ok, st = pcall(function() return remote:InvokeServer(LocalPlayer.UserId) end)
        if not ok or not st then
            Rayfield:Notify({ Title = "Failed", Content = "Could not load stats.", Duration = 3 })
            return
        end
        local g = st.General or {}
        Rayfield:Notify({
            Title = LocalPlayer.DisplayName,
            Content = table.concat({
                "Status: " .. BanLabel(st.Banned),
                "Rank: " .. tostring(g.Rank or "?"),
                "Class: " .. tostring(g.MainClass or "?"),
                "K/D: " .. string.format("%.2f", (g.Kills or 0) / math_max(1, g.Deaths or 0)),
                "Wins: " .. tostring(g.WinRate or 0) .. "%",
                "Playtime: " .. tostring(g.PlaytimeDisplay or "?"),
            }, "\n"),
            Duration = 12,
        })
    end)
end

-- ============================================================
-- UI
-- ============================================================
local CombatTab = Window:CreateTab("Combat", "crosshair")
local VisualTab = Window:CreateTab("Visuals", "eye")
local MiscTab   = Window:CreateTab("Misc", "zap")
local PerfTab   = Window:CreateTab("Perf", "activity")

CombatTab:CreateSection("Silent Aim")
CombatTab:CreateToggle({ Name = "Enable", CurrentValue = false, Flag = "SilentOn",
    Callback = function(v)
        if v then
            local any, cross, nc = InstallHooks()
            if not any then
                Rayfield:Notify({ Title = "Unsupported",
                    Content = "No hook API on this executor.", Duration = 5 })
                return
            end
            Rayfield:Notify({ Title = "Silent aim on",
                Content = ("Crosshair: %s   Remote: %s"):format(tostring(cross), tostring(nc)),
                Duration = 4 })
        end
        Settings.Silent.Enabled = v
        if not v then UninstallHooks() end
    end })
CombatTab:CreateDropdown({ Name = "Key", Options = {"LMB","RMB","LeftShift","LeftAlt","Always"},
    CurrentOption = {"LMB"}, Flag = "SilentKey",
    Callback = function(s) Settings.Silent.Key = s[1] or "LMB"; silentToggled = false end })
CombatTab:CreateDropdown({ Name = "Mode", Options = {"Hold","Toggle"}, CurrentOption = {"Hold"}, Flag = "SilentMode",
    Callback = function(s) Settings.Silent.Mode = s[1] or "Hold"; silentToggled = false end })
CombatTab:CreateSlider({ Name = "FOV", Range = {10, 400}, Increment = 10, Suffix = "px",
    CurrentValue = 120, Flag = "SilentFOV", Callback = function(v) Settings.Silent.FOV = v end })
CombatTab:CreateDropdown({ Name = "Part", Options = {"Head","UpperTorso","HumanoidRootPart"},
    CurrentOption = {"Head"}, Flag = "SilentPart",
    Callback = function(s) Settings.Silent.Part = s[1] or "Head" end })
CombatTab:CreateSlider({ Name = "Predict", Range = {0, 60}, Increment = 1, Suffix = "%",
    CurrentValue = 0, Flag = "SilentPred", Callback = function(v) Settings.Silent.Prediction = v end })
CombatTab:CreateToggle({ Name = "Wall Check", CurrentValue = true, Flag = "SilentWall",
    Callback = function(v) Settings.Silent.WallCheck = v end })
CombatTab:CreateToggle({ Name = "Show Circle", CurrentValue = true, Flag = "SilentCircle",
    Callback = function(v) if SilentCircle then SilentCircle.Visible = v end end })

CombatTab:CreateSection("Exploits")
local function exploitToggle(name, flag, key)
    CombatTab:CreateToggle({ Name = name, CurrentValue = Settings.Misc[key], Flag = flag,
        Callback = function(v) Settings.Misc[key] = v end })
end
exploitToggle("Rapid Fire", "X_Rapid", "RapidFire")
exploitToggle("Instant Reload", "X_Reload", "InstantReload")
exploitToggle("No Recoil", "X_Recoil", "NoRecoil")
exploitToggle("No Spread", "X_Spread", "NoSpread")
exploitToggle("Instant Revive", "X_Revive", "InstantRevive")

VisualTab:CreateSection("Chams (enemies only)")
VisualTab:CreateToggle({ Name = "Enable", CurrentValue = true, Flag = "ChamsOn",
    Callback = function(v) Settings.ESP.Enabled = v end })
VisualTab:CreateDropdown({ Name = "Color", Options = {"Red","Green","Blue","White","Yellow","Cyan"},
    CurrentOption = {"Red"}, Flag = "ChamsColor",
    Callback = function(s) Settings.ESP.Color = s[1] or "Red" end })
VisualTab:CreateSlider({ Name = "Fill", Range = {0, 100}, Increment = 5, Suffix = "%",
    CurrentValue = 50, Flag = "ChamsFill",
    Callback = function(v) Settings.ESP.FillTransparency = v / 100 end })

VisualTab:CreateSection("Overlay")
local overlays = {
    {"Box","Boxes"},{"Name","Names"},{"Distance","Distance"},
    {"Health","Health"},{"Skeleton","Skeleton"},{"Tracer","Tracers"},{"ClassTag","Class"},
}
for _, e in ipairs(overlays) do
    VisualTab:CreateToggle({ Name = e[2], CurrentValue = Settings.ESP[e[1]], Flag = "ESP_" .. e[1],
        Callback = function(v) Settings.ESP[e[1]] = v end })
end
VisualTab:CreateSlider({ Name = "Range", Range = {100, 2000}, Increment = 50, Suffix = "m",
    CurrentValue = 600, Flag = "ESPDist", Callback = function(v) Settings.ESP.MaxDistance = v end })

MiscTab:CreateSection("Movement")
MiscTab:CreateToggle({ Name = "Walk Speed", CurrentValue = false, Flag = "WSOn",
    Callback = function(v)
        Settings.Misc.WalkSpeedEnabled = v
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if v then ApplyWalkSpeed(hum)
        elseif hum then hum:SetAttribute("DefaultWalkSpeed", 16) end
    end })
MiscTab:CreateSlider({ Name = "Speed (max 30)", Range = {16, 30}, Increment = 1,
    CurrentValue = 16, Flag = "WSSpeed",
    Callback = function(v)
        Settings.Misc.WalkSpeed = v
        if Settings.Misc.WalkSpeedEnabled then
            ApplyWalkSpeed(LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
        end
    end })
MiscTab:CreateSlider({ Name = "Jump (max 50)", Range = {20, 50}, Increment = 1,
    CurrentValue = 50, Flag = "JumpPower",
    Callback = function(v)
        Settings.Misc.JumpPower = v
        ApplyJump(LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid"))
    end })

MiscTab:CreateSection("Camera")
MiscTab:CreateToggle({ Name = "Lock FOV", CurrentValue = false, Flag = "FOVLock",
    Callback = function(v) Settings.Misc.FOVLock = v end })
MiscTab:CreateSlider({ Name = "FOV Value", Range = {40, 120}, Increment = 5,
    CurrentValue = 70, Flag = "FOVValue", Callback = function(v) Settings.Misc.FOVValue = v end })

MiscTab:CreateSection("Render")
MiscTab:CreateToggle({ Name = "Chunk Culling", CurrentValue = true, Flag = "Culling",
    Callback = function(v)
        Settings.Render.Culling = v
        if not v then ResetCulling() end
    end })
MiscTab:CreateSlider({ Name = "Render Distance", Range = {200, 2000}, Increment = 50, Suffix = "m",
    CurrentValue = 700, Flag = "RenderDist", Callback = function(v) Settings.Render.Distance = v end })
MiscTab:CreateToggle({ Name = "Lite Mode (chams only)", CurrentValue = false, Flag = "Lite",
    Callback = function(v)
        Settings.Render.Lite = v
        if v then
            for i = 1, #ESP_Array do hideDraws(ESP_Array[i]) end
        end
    end })
MiscTab:CreateToggle({ Name = "Fullbright", CurrentValue = false, Flag = "Fullbright",
    Callback = function(v)
        Settings.Misc.Fullbright = v
        Lighting.Brightness = v and 2 or 1
        Lighting.Ambient = v and Color3.fromRGB(200,200,200) or Color3.fromRGB(128,128,128)
        Lighting.OutdoorAmbient = Lighting.Ambient
        Lighting.GlobalShadows = not v
    end })
MiscTab:CreateToggle({ Name = "No Fog", CurrentValue = false, Flag = "NoFog",
    Callback = function(v)
        Settings.Misc.NoFog = v
        Lighting.FogEnd = v and 1000000 or 100000
        Lighting.FogStart = Lighting.FogEnd
    end })
MiscTab:CreateToggle({ Name = "Post FX", CurrentValue = false, Flag = "PostFX",
    Callback = function(v) Settings.Misc.PostFX = v; SetPostFX(v) end })
MiscTab:CreateToggle({ Name = "Hitmarker", CurrentValue = true, Flag = "Hitmarker",
    Callback = function(v) Settings.Misc.Hitmarker = v end })

MiscTab:CreateSection("System")
MiscTab:CreateButton({ Name = "Uncap FPS (240)", Icon = "gauge",
    Callback = function()
        local ok = pcall(function() setfpscap(240) end)
        if not ok then
            ok = pcall(function() RunService:SetFpsCap(240) end)
        end
        if not ok then
            ok = pcall(function() game:GetService("RunService"):SetFpsCap(240) end)
        end
        Rayfield:Notify({
            Title = ok and "FPS cap set" or "Unsupported",
            Content = ok and "Target cap: 240." or "Executor has no fps cap API.",
            Duration = 3,
        })
    end })
MiscTab:CreateButton({ Name = "My Stats", Icon = "user", Callback = ShowSelfStats })

PerfTab:CreateSection("Live")
local Row = PerfTab:CreateRow()
local PingStat = Row:CreateStat({ Name = "Ping", Icon = "wifi", Value = "0ms", Delta = "" })
local FPSStat  = Row:CreateStat({ Name = "FPS", Icon = "zap", Value = "0", Delta = "" })
local TargStat = Row:CreateStat({ Name = "Targets", Icon = "users", Value = "0", Delta = "" })
local HitStat  = Row:CreateStat({ Name = "Hits", Icon = "target", Value = "0", Delta = "" })
local ShotStat = Row:CreateStat({ Name = "Aim", Icon = "crosshair", Value = "0", Delta = "" })

PerfTab:CreateSection("Closest Distance")
local Chart = PerfTab:CreateChart({ Name = "Distance", Icon = "ruler", Suffix = "m",
    Points = Settings.History.Distance })

task.spawn(function()
    while true do
        task.wait(1)
        PingStat:Set({ Value = Settings.Perf.Ping .. "ms" })
        FPSStat:Set({ Value = tostring(Settings.Perf.FPS) })
        TargStat:Set({ Value = tostring(Settings.Perf.Targets) })
        HitStat:Set({ Value = tostring(Settings.Perf.Hits) })
        ShotStat:Set({ Value = tostring(Settings.Perf.Shots) })
        Chart:Push(Settings.History.Last)
    end
end)

Rayfield:Notify({
    Title = "Entrenched v1.3",
    Content = "Silent aim + exploits ready. Chams is enemy-only.",
    Duration = 5,
    Image = "crosshair",
})

Rayfield:LoadConfiguration()
