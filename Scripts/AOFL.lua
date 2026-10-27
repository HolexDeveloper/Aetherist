-- =====================================================================
-- Aetherist / AOFL
-- Hyper-Optimized & Perf-Integrated System
-- Made by @thedude_whotalks3
-- =====================================================================
--!nonstrict

local Services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    Workspace = game:GetService("Workspace"),
    Lighting = game:GetService("Lighting"),
    UserInputService = game:GetService("UserInputService"),
    ProximityPromptService = game:GetService("ProximityPromptService"),
}

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera

-- =====================================================================
-- AOFL STATE & CACHING
-- =====================================================================
local AOFL = {
    Cache = {
        Monsters = {},
        Players = {},
        Items = {}
    },
    ESPObjects = {},
    Performance = {
        ESPCount = 0,
        LastGC = tick()
    }
}

local Settings = {
    WalkSpeed = 16,
    JumpPower = 50,
    UseCFrameSpeed = false,
    FlySpeed = 60,
    FlyBoost = 150,
    IsFlying = false,
    Noclip = false,
    InfiniteStamina = false,
    GodMode = false,
    InstantPrompt = false,
    ESP = {
        Enabled = false,
        Monsters = true,
        Players = false,
        Items = true,
        MaxDist = 1500,
        ShowNames = true,
        ShowDistance = true,
        Color = Color3.fromRGB(255, 50, 50)
    }
}

-- =====================================================================
-- PERF OPTIMIZER CORE (Weak-Keyed Cache & Batch Queue)
-- =====================================================================
local Perf = {
    Enabled = false,
    Config = {
        NoFog = true, NoSky = true, NoShadows = true, DisablePostFx = true,
        DisableParticles = true, DisableTrailsBeams = true, DisableFireSmokeSparkles = true,
        NoCastShadow = true, CalmWater = true, NoGrass = true,
        RemoveDecals = false, ClearMeshTextures = false, FlatMaterials = false,
        ForceQuality = true, ShowStats = true, BatchSize = 300
    },
    Cache = {
        originals = setmetatable({}, { __mode = "k" }),
        processed = setmetatable({}, { __mode = "k" }),
        detached = {}
    },
    Stats = { touched = 0, effects = 0, shadows = 0 },
    Queue = { list = {}, head = 1, queued = setmetatable({}, { __mode = "k" }) }
}

local SettingsService = settings()
local RenderSettings, UserGameSettings
pcall(function() RenderSettings = SettingsService.Rendering end)
pcall(function() UserGameSettings = UserSettings():GetService("UserGameSettings") end)

function Perf.Save(instance, prop)
    local rec = Perf.Cache.originals[instance]
    if not rec then
        rec = {}
        Perf.Cache.originals[instance] = rec
    end
    if rec[prop] == nil then
        local ok, value = pcall(function() return instance[prop] end)
        if ok then rec[prop] = value end
    end
end

function Perf.GetOriginal(instance, prop)
    local rec = Perf.Cache.originals[instance]
    return rec and rec[prop] or nil
end

function Perf.MarkProcessed(instance)
    Perf.Cache.processed[instance] = true
end

function Perf.IsProcessed(instance)
    return Perf.Cache.processed[instance] == true
end

function Perf.Detach(instance)
    if instance.Parent then
        Perf.Save(instance, "Parent")
        instance.Parent = nil
    end
    table.insert(Perf.Cache.detached, instance)
end

function Perf.RevertInstance(instance)
    local rec = Perf.Cache.originals[instance]
    if rec then
        for prop, value in pairs(rec) do
            pcall(function() instance[prop] = value end)
        end
        Perf.Cache.originals[instance] = nil
    end
    Perf.Cache.processed[instance] = nil
end

function Perf.RevertAll()
    for instance in pairs(Perf.Cache.originals) do
        Perf.RevertInstance(instance)
    end
    for _, instance in ipairs(Perf.Cache.detached) do
        Perf.RevertInstance(instance)
    end
    Perf.Cache.detached = {}
end

function Perf.DisableEffect(inst)
    if inst.Enabled then
        Perf.Save(inst, "Enabled")
        inst.Enabled = false
        Perf.Stats.effects = Perf.Stats.effects + 1
    end
end

function Perf.HandleBasePart(part)
    if part:IsA("Terrain") then return end
    if Perf.Config.NoCastShadow and part.CastShadow then
        Perf.Save(part, "CastShadow")
        part.CastShadow = false
        Perf.Stats.shadows = Perf.Stats.shadows + 1
    end
    if Perf.Config.FlatMaterials then
        if part.Material ~= Enum.Material.Plastic then
            Perf.Save(part, "Material")
            part.Material = Enum.Material.Plastic
        end
        if part.Reflectance ~= 0 then
            Perf.Save(part, "Reflectance")
            part.Reflectance = 0
        end
    end
end

function Perf.HandleMeshPart(part)
    if Perf.Config.ClearMeshTextures and part.TextureID ~= "" then
        Perf.Save(part, "TextureID")
        part.TextureID = ""
    end
end

function Perf.HandleSpecialMesh(mesh)
    if Perf.Config.ClearMeshTextures and mesh.TextureId ~= "" then
        Perf.Save(mesh, "TextureId")
        mesh.TextureId = ""
    end
end

function Perf.HandleDecal(decal)
    if Perf.Config.RemoveDecals and decal.Transparency ~= 1 then
        Perf.Save(decal, "Transparency")
        decal.Transparency = 1
    end
end

function Perf.HandleTerrain(terrain)
    if Perf.Config.CalmWater then
        Perf.Save(terrain, "WaterWaveSize")
        Perf.Save(terrain, "WaterWaveSpeed")
        Perf.Save(terrain, "WaterReflectance")
        terrain.WaterWaveSize = 0
        terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0
    end
    if Perf.Config.NoGrass then
        Perf.Save(terrain, "Decoration")
        terrain.Decoration = false
    end
end

function Perf.HandleLighting(light)
    if Perf.Config.NoFog then
        Perf.Save(light, "FogStart")
        Perf.Save(light, "FogEnd")
        if light.FogStart ~= 100000 then light.FogStart = 100000 end
        if light.FogEnd ~= 100000 then light.FogEnd = 100000 end
    end
    if Perf.Config.NoShadows and light.GlobalShadows then
        Perf.Save(light, "GlobalShadows")
        light.GlobalShadows = false
    end
    if light.EnvironmentDiffuseScale ~= 0 then
        Perf.Save(light, "EnvironmentDiffuseScale")
        light.EnvironmentDiffuseScale = 0
    end
    if light.EnvironmentSpecularScale ~= 0 then
        Perf.Save(light, "EnvironmentSpecularScale")
        light.EnvironmentSpecularScale = 0
    end
    if Perf.Config.NoSky then
        for _, child in ipairs(light:GetChildren()) do
            if child:IsA("Sky") then Perf.Detach(child) end
        end
    end
end

local PerfHandlerRules = {
    { test = "BasePart", fn = Perf.HandleBasePart },
    { test = "MeshPart", fn = Perf.HandleMeshPart },
    { test = "SpecialMesh", fn = Perf.HandleSpecialMesh },
    { test = "Decal", fn = Perf.HandleDecal },
    { test = "Terrain", fn = Perf.HandleTerrain },
    { test = "Lighting", fn = Perf.HandleLighting },
    { test = "PostEffect", fn = Perf.DisableEffect },
    { test = "ParticleEmitter", fn = Perf.DisableEffect },
    { test = "Trail", fn = Perf.DisableEffect },
    { test = "Beam", fn = Perf.DisableEffect },
    { test = "Fire", fn = Perf.DisableEffect },
    { test = "Smoke", fn = Perf.DisableEffect },
    { test = "Sparkles", fn = Perf.DisableEffect },
}

local PerfHandlerCache = {}
local function GetPerfHandlers(instance)
    local className = instance.ClassName
    local list = PerfHandlerCache[className]
    if list == nil then
        list = {}
        for _, rule in ipairs(PerfHandlerRules) do
            local ok, matches = pcall(function() return instance:IsA(rule.test) end)
            if ok and matches then table.insert(list, rule.fn) end
        end
        PerfHandlerCache[className] = list
    end
    return list
end

local function ApplyPerfTo(instance)
    if Perf.IsProcessed(instance) then return end
    Perf.MarkProcessed(instance)
    local handlers = GetPerfHandlers(instance)
    for i = 1, #handlers do
        pcall(handlers[i], instance)
    end
    Perf.Stats.touched = Perf.Stats.touched + 1
end

local function EnqueuePerf(instance)
    if not Perf.Enabled then return end
    if Perf.Queue.queued[instance] or Perf.IsProcessed(instance) then return end
    Perf.Queue.queued[instance] = true
    Perf.Queue.list[#Perf.Queue.list + 1] = instance
end

local function FlushPerfQueue()
    if Perf.Queue.head > #Perf.Queue.list then return end
    local lastIndex = #Perf.Queue.list
    local target = Perf.Queue.head + Perf.Config.BatchSize - 1
    if target > lastIndex then target = lastIndex end
    for i = Perf.Queue.head, target do
        local inst = Perf.Queue.list[i]
        Perf.Queue.queued[inst] = nil
        if Perf.Enabled and inst.Parent ~= nil then
            ApplyPerfTo(inst)
        end
    end
    Perf.Queue.head = target + 1
    if Perf.Queue.head > lastIndex then
        Perf.Queue.list = {}
        Perf.Queue.head = 1
    end
end

local function ApplyPerfQuality()
    if not Perf.Config.ForceQuality then return end
    if RenderSettings then
        Perf.Save(RenderSettings, "QualityLevel")
        pcall(function() RenderSettings.QualityLevel = Enum.QualityLevel.Level01 end)
    end
    if UserGameSettings then
        Perf.Save(UserGameSettings, "SavedQualityLevel")
        pcall(function() UserGameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
    end
end

local function RestorePerfQuality()
    if not Perf.Config.ForceQuality then return end
    if RenderSettings then
        local orig = Perf.GetOriginal(RenderSettings, "QualityLevel")
        pcall(function() RenderSettings.QualityLevel = orig or Enum.QualityLevel.Automatic end)
    end
    if UserGameSettings then
        local orig = Perf.GetOriginal(UserGameSettings, "SavedQualityLevel")
        pcall(function() UserGameSettings.SavedQualityLevel = orig or Enum.SavedQualitySetting.Automatic end)
    end
end

-- =====================================================================
-- AOFL OPTIMIZED CACHING (Event-Driven)
-- =====================================================================
local function AddToCache(category, target)
    if not AOFL.Cache[category][target] then
        AOFL.Cache[category][target] = true
        if Settings.ESP.Enabled then ESP.ProcessTarget(target, category) end
    end
end

local function RemoveFromCache(category, target)
    if AOFL.Cache[category][target] then
        AOFL.Cache[category][target] = nil
        if AOFL.ESPObjects[target] then
            local data = AOFL.ESPObjects[target]
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            AOFL.ESPObjects[target] = nil
        end
    end
end

Services.Workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") then
        local parent = descendant.Parent
        if parent and (parent.Name == "Monsters" or parent.Name == "Angels") then
            AddToCache("Monsters", descendant)
        end
    elseif descendant:IsA("Tool") or descendant.Name:match("Grocery") or descendant.Name:match("Medkit") then
        local target = descendant.Parent:IsA("Model") and descendant.Parent or descendant
        AddToCache("Items", target)
    elseif descendant:IsA("ProximityPrompt") and Settings.InstantPrompt then
        descendant.HoldDuration = 0
        descendant.RequiresLineOfSight = false
    end
    EnqueuePerf(descendant)
end)

Services.Workspace.DescendantRemoving:Connect(function(descendant)
    if descendant:IsA("Model") then
        RemoveFromCache("Monsters", descendant)
    else
        local target = descendant.Parent:IsA("Model") and descendant.Parent or descendant
        RemoveFromCache("Items", target)
    end
end)

Services.Players.PlayerAdded:Connect(function(player)
    AddToCache("Players", player)
end)

Services.Players.PlayerRemoving:Connect(function(player)
    RemoveFromCache("Players", player)
end)

-- =====================================================================
-- ESP SYSTEM
-- =====================================================================
local ESP = {}
function ESP.CreateHighlight(target, color)
    if not target or not target.Parent then return nil end
    local highlight = Instance.new("Highlight")
    highlight.Name = "AOFL_ESP_HL"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = color
    highlight.FillTransparency = 0.75
    highlight.OutlineColor = color
    highlight.OutlineTransparency = 0
    highlight.Adornee = target
    highlight.Parent = target
    return highlight
end

function ESP.CreateBillboard(target, name, color)
    if not target or not target.Parent then return nil end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "AOFL_ESP_BB"
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = target
    billboard.Parent = target

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = color
    nameLabel.TextStrokeTransparency = 0.5
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 16
    nameLabel.Text = name
    nameLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Distance"
    distLabel.Size = UDim2.new(1, 0, 0.5, 0)
    distLabel.Position = UDim2.new(0, 0, 0.5, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 14
    distLabel.Text = ""
    distLabel.Parent = billboard

    return billboard
end

function ESP.ProcessTarget(target, category)
    if not target or not target.Parent then return end
    if AOFL.ESPObjects[target] then return end

    local data = { Category = category, Highlight = nil, Billboard = nil, LastDistText = "" }
    local color = category == "Monster" and Settings.ESP.Color or (category == "Player" and Color3.fromRGB(50, 150, 255) or Color3.fromRGB(255, 215, 0))
    
    data.Highlight = ESP.CreateHighlight(target, color)

    if Settings.ESP.ShowNames or Settings.ESP.ShowDistance then
        local adornee = target:IsA("Model") and target.PrimaryPart or (target:IsA("BasePart") and target)
        if adornee then
            data.Billboard = ESP.CreateBillboard(adornee, target.Name, Color3.fromRGB(255, 255, 255))
        end
    end
    AOFL.ESPObjects[target] = data
end

function ESP.Update()
    if not Settings.ESP.Enabled then return end
    local localPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position or Vector3.new(0, 0, 0)

    if Settings.ESP.Monsters then
        for target, _ in pairs(AOFL.Cache.Monsters) do
            if not AOFL.ESPObjects[target] then ESP.ProcessTarget(target, "Monster") end
        end
    end
    if Settings.ESP.Players then
        for player, _ in pairs(AOFL.Cache.Players) do
            if player ~= LocalPlayer and player.Character and not AOFL.ESPObjects[player.Character] then
                ESP.ProcessTarget(player.Character, "Player")
            end
        end
    end
    if Settings.ESP.Items then
        for target, _ in pairs(AOFL.Cache.Items) do
            if not AOFL.ESPObjects[target] then ESP.ProcessTarget(target, "Item") end
        end
    end

    for target, data in pairs(AOFL.ESPObjects) do
        if not target or not target.Parent then
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            AOFL.ESPObjects[target] = nil
            continue
        end

        local targetPos = target:IsA("Model") and target.PrimaryPart and target.PrimaryPart.Position or (target:IsA("BasePart") and target.Position)
        if not targetPos then continue end

        local distance = (targetPos - localPos).Magnitude
        if distance > Settings.ESP.MaxDist then
            if data.Billboard then data.Billboard.Enabled = false end
            continue
        end

        if data.Billboard then
            data.Billboard.Enabled = true
            local newDistText = Settings.ESP.ShowDistance and string.format("[%d studs]", math.floor(distance)) or ""
            if data.LastDistText ~= newDistText then
                data.Billboard.Name.Text = Settings.ESP.ShowNames and target.Name or ""
                data.Billboard.Distance.Text = newDistText
                data.LastDistText = newDistText
            end
        end
    end
end

-- =====================================================================
-- MOVEMENT & PHYSICS (CFrame Hardened & Event-Driven Noclip)
-- =====================================================================
local NoclipConnection = nil

local function ApplyNoclip(char)
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    if not NoclipConnection then
        NoclipConnection = char.DescendantAdded:Connect(function(part)
            if Settings.Noclip and part:IsA("BasePart") then part.CanCollide = false end
        end)
    end
end

local function RemoveNoclip(char)
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- =====================================================================
-- RAYFIELD GEN 2 LOADER
-- =====================================================================
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Aetherist / AOFL",
    Subtitle = "Hyper-Optimized & Perf-Integrated",
    Icon = "cpu",
    Badge = {Text = "v3.0", Icon = "zap"},
    LoadingTitle = "Aetherist",
    LoadingSubtitle = "Initializing CFrame & Perf Engine",
    ToggleUIKeybind = "K",
    ConfigurationSaving = { Enabled = true, FolderName = "Aetherist_AOFL", FileName = "Config" },
})

local TabMovement = Window:CreateTab("Movement", "activity")
local TabESP = Window:CreateTab("ESP", "eye")
local TabPerf = Window:CreateTab("Performance", "gauge")
local TabAdmin = Window:CreateTab("Admin", "crown")

-- Movement Tab
TabMovement:CreateSection("CFrame Movement")
TabMovement:CreateToggle({
    Name = "Enable CFrame Fly",
    Description = "W/A/S/D + Space/Ctrl. Hold Left Shift to boost.",
    CurrentValue = false,
    Flag = "Move_Fly",
    Callback = function(v) Settings.IsFlying = v end
})
TabMovement:CreateSlider({ Name = "Fly Speed", Range = {10, 200}, Increment = 5, CurrentValue = 60, Flag = "Move_FlySpeed", Callback = function(v) Settings.FlySpeed = v end })
TabMovement:CreateSlider({ Name = "Shift Boost Speed", Range = {100, 500}, Increment = 10, CurrentValue = 150, Flag = "Move_FlyBoost", Callback = function(v) Settings.FlyBoost = v end })

TabMovement:CreateSection("Humanoid / CFrame Fallback")
TabMovement:CreateToggle({ Name = "Custom WalkSpeed", CurrentValue = false, Flag = "Move_WalkSpeedToggle", Callback = function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v and Settings.WalkSpeed or 16 end
end })
TabMovement:CreateSlider({ Name = "WalkSpeed Value", Range = {16, 250}, Increment = 1, CurrentValue = 16, Flag = "Move_WalkSpeedVal", Callback = function(v) 
    Settings.WalkSpeed = v 
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and Rayfield.Flags.Move_WalkSpeedToggle then hum.WalkSpeed = v end
end })
TabMovement:CreateToggle({ Name = "Force CFrame Speed", Description = "Use pure CFrame translation if server blocks WalkSpeed changes.", CurrentValue = false, Flag = "Move_CFrameSpeed", Callback = function(v) Settings.UseCFrameSpeed = v end })

TabMovement:CreateToggle({ Name = "Custom JumpPower", CurrentValue = false, Flag = "Move_JumpPowerToggle", Callback = function(v)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.UseJumpPower = v; hum.JumpPower = v and Settings.JumpPower or 50 end
end })
TabMovement:CreateSlider({ Name = "JumpPower Value", Range = {50, 300}, Increment = 5, CurrentValue = 50, Flag = "Move_JumpPowerVal", Callback = function(v) 
    Settings.JumpPower = v 
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and Rayfield.Flags.Move_JumpPowerToggle then hum.JumpPower = v end
end })

TabMovement:CreateToggle({ Name = "Safe Noclip", Description = "Event-driven, zero per-frame performance cost.", CurrentValue = false, Flag = "Move_Noclip", Callback = function(v) 
    Settings.Noclip = v 
    if v then ApplyNoclip(LocalPlayer.Character) else RemoveNoclip(LocalPlayer.Character) end 
end })

-- ESP Tab
TabESP:CreateSection("Targets")
local ESPRow1 = TabESP:CreateRow()
ESPRow1:CreateToggle({ Name = "Monsters", CurrentValue = true, Flag = "ESP_Monsters", Callback = function(v) Settings.ESP.Monsters = v; Settings.ESP.Enabled = v or Settings.ESP.Players or Settings.ESP.Items end })
ESPRow1:CreateToggle({ Name = "Players", CurrentValue = false, Flag = "ESP_Players", Callback = function(v) Settings.ESP.Players = v; Settings.ESP.Enabled = v or Settings.ESP.Monsters or Settings.ESP.Items end })
ESPRow1:CreateToggle({ Name = "Items", CurrentValue = true, Flag = "ESP_Items", Callback = function(v) Settings.ESP.Items = v; Settings.ESP.Enabled = v or Settings.ESP.Monsters or Settings.ESP.Players end })

TabESP:CreateSection("Visuals")
local ESPRow2 = TabESP:CreateRow()
ESPRow2:CreateToggle({ Name = "Show Names", CurrentValue = true, Flag = "ESP_Names", Callback = function(v) Settings.ESP.ShowNames = v end })
ESPRow2:CreateToggle({ Name = "Show Distance", CurrentValue = true, Flag = "ESP_Dist", Callback = function(v) Settings.ESP.ShowDistance = v end })
ESPRow2:CreateSlider({ Name = "Max Distance", Range = {100, 3000}, Increment = 50, CurrentValue = 1500, Flag = "ESP_MaxDist", Callback = function(v) Settings.ESP.MaxDist = v end })

-- Performance Tab (PerfOptimizer Integration)
TabPerf:CreateSection("Core Passes (Safe)")
local PerfRow1 = TabPerf:CreateRow()
PerfRow1:CreateToggle({ Name = "No Fog", CurrentValue = true, Flag = "Perf_NoFog", Callback = function(v) Perf.Config.NoFog = v end })
PerfRow1:CreateToggle({ Name = "No Sky", CurrentValue = true, Flag = "Perf_NoSky", Callback = function(v) Perf.Config.NoSky = v end })
PerfRow1:CreateToggle({ Name = "No Shadows", CurrentValue = true, Flag = "Perf_NoShadows", Callback = function(v) Perf.Config.NoShadows = v end })
PerfRow1:CreateToggle({ Name = "Disable Post-FX", CurrentValue = true, Flag = "Perf_DisablePostFx", Callback = function(v) Perf.Config.DisablePostFx = v end })

local PerfRow2 = TabPerf:CreateRow()
PerfRow2:CreateToggle({ Name = "Disable Particles", CurrentValue = true, Flag = "Perf_DisableParticles", Callback = function(v) Perf.Config.DisableParticles = v end })
PerfRow2:CreateToggle({ Name = "Disable Trails/Beams", CurrentValue = true, Flag = "Perf_DisableTrailsBeams", Callback = function(v) Perf.Config.DisableTrailsBeams = v end })
PerfRow2:CreateToggle({ Name = "No Cast Shadow", CurrentValue = true, Flag = "Perf_NoCastShadow", Callback = function(v) Perf.Config.NoCastShadow = v end })
PerfRow2:CreateToggle({ Name = "Calm Water / No Grass", CurrentValue = true, Flag = "Perf_CalmWater", Callback = function(v) Perf.Config.CalmWater = v; Perf.Config.NoGrass = v end })

TabPerf:CreateSection("Aggressive Passes (Higher Gains)")
local PerfRow3 = TabPerf:CreateRow()
PerfRow3:CreateToggle({ Name = "Remove Decals", CurrentValue = false, Flag = "Perf_RemoveDecals", Callback = function(v) Perf.Config.RemoveDecals = v end })
PerfRow3:CreateToggle({ Name = "Clear Mesh Textures", CurrentValue = false, Flag = "Perf_ClearMeshTextures", Callback = function(v) Perf.Config.ClearMeshTextures = v end })
PerfRow3:CreateToggle({ Name = "Flat Materials", CurrentValue = false, Flag = "Perf_FlatMaterials", Callback = function(v) Perf.Config.FlatMaterials = v end })
PerfRow3:CreateToggle({ Name = "Force Lowest Quality", CurrentValue = true, Flag = "Perf_ForceQuality", Callback = function(v) Perf.Config.ForceQuality = v end })

TabPerf:CreateSection("System Controls")
TabPerf:CreateToggle({ 
    Name = "Enable Perf Optimizer", 
    Description = "Applies all selected optimizations with reversible weak-keyed caching.",
    CurrentValue = false, 
    Flag = "Perf_Enabled", 
    Callback = function(v) 
        Perf.Enabled = v 
        if v then 
            print("[PerfOptimizer] ON - re-scanning world...")
            ApplyPerfQuality()
            EnqueuePerf(Services.Workspace.Terrain)
            EnqueuePerf(Services.Lighting)
            for _, inst in ipairs(Services.Workspace:GetDescendants()) do EnqueuePerf(inst) end
            for _, inst in ipairs(Services.Lighting:GetDescendants()) do EnqueuePerf(inst) end
        else 
            print("[PerfOptimizer] OFF - everything restored to original values.")
            RestorePerfQuality()
            Perf.RevertAll()
        end 
    end 
})

TabPerf:CreateButton({ 
    Name = "Force Garbage Collection & Clear Cache", 
    Callback = function() 
        local cleared = 0
        for instance in pairs(Perf.Cache.originals) do
            if not instance or not instance.Parent then
                Perf.Cache.originals[instance] = nil
                cleared = cleared + 1
            end
        end
        Perf.Queue.list = {}
        Perf.Queue.head = 1
        Perf.Queue.queued = setmetatable({}, { __mode = "k" })
        Rayfield:Notify({ Title = "AOFL Engine", Content = string.format("Cleared %d invalid references.", cleared), Duration = 3, Image = "trash" })
    end 
})

-- Admin Tab (Brute Force)
TabAdmin:CreateSection("Admin Brute Force")
TabAdmin:CreateInput({ Name = "Command Name", PlaceholderText = "e.g., Kick, BanPlayer", CurrentValue = "Kick", Flag = "Admin_CmdName", Callback = function() end })
TabAdmin:CreateInput({ Name = "Arguments", PlaceholderText = "e.g., All, PlayerName", CurrentValue = "All", Flag = "Admin_CmdArgs", Callback = function() end })
TabAdmin:CreateButton({ 
    Name = "Execute Command", 
    Callback = function()
        local cmd = Rayfield.Flags.Admin_CmdName or "Kick"
        local args = Rayfield.Flags.Admin_CmdArgs or "All"
        if type(cmd) == "table" then cmd = cmd[1] or "Kick" end
        if type(args) == "table" then args = args[1] or "All" end
        
        if args:lower() == "all" and (cmd:lower() == "kick" or cmd:lower() == "banplayer") then
            local count = 0
            for _, p in ipairs(Services.Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local remote = Services.ReplicatedStorage:FindFirstChild("RemoteEvents") and Services.ReplicatedStorage.RemoteEvents:FindFirstChild("AdminCommands")
                    if remote then pcall(function() remote:FireServer(cmd, p.Name, "0s", "Brute Force") end) end
                    count = count + 1
                    task.wait(0.05)
                end
            end
            Rayfield:Notify({Title = "Brute Force Success", Content = "Executed '" .. cmd .. "' on " .. count .. " players.", Duration = 4, Image = "zap"})
        else
            local remote = Services.ReplicatedStorage:FindFirstChild("RemoteEvents") and Services.ReplicatedStorage.RemoteEvents:FindFirstChild("AdminCommands")
            if remote then 
                pcall(function() remote:FireServer(cmd, args) end)
                Rayfield:Notify({Title = "Command Sent", Content = "Fired: " .. cmd .. " " .. args, Duration = 3, Image = "terminal"})
            else
                Rayfield:Notify({Title = "Error", Content = "Admin remote not found!", Duration = 3, Image = "alert-circle"})
            end
        end
    end 
})

-- =====================================================================
-- MAIN LOOPS
-- =====================================================================
LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart")
    if Settings.Noclip then ApplyNoclip(char) end
end)

local lastAutofarm = 0
Services.RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if humanoid then
        if not Settings.UseCFrameSpeed and humanoid.WalkSpeed ~= Settings.WalkSpeed then
            humanoid.WalkSpeed = Settings.WalkSpeed
        end
        if humanoid.JumpPower ~= Settings.JumpPower then
            humanoid.UseJumpPower = true
            humanoid.JumpPower = Settings.JumpPower
        end
        if Settings.GodMode and humanoid.Health < humanoid.MaxHealth then
            humanoid.Health = humanoid.MaxHealth
        end
        if Settings.InfiniteStamina and humanoid:GetAttribute("Stamina") ~= 9999 then
            pcall(function() humanoid:SetAttribute("Stamina", 9999) end)
        end
    end

    local now = tick()
    if now - AOFL.Performance.LastGC > 30 then
        for target, data in pairs(AOFL.ESPObjects) do
            if not target or not target.Parent then
                if data.Highlight then data.Highlight:Destroy() end
                if data.Billboard then data.Billboard:Destroy() end
                AOFL.ESPObjects[target] = nil
            end
        end
        AOFL.Performance.LastGC = now
    end
    
    FlushPerfQueue()
end)

Services.RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    
    if root and humanoid then
        if Settings.IsFlying then
            local moveDir = Vector3.new(0, 0, 0)
            local cam = Camera
            
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir - cam.CFrame.LookVector end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir + cam.CFrame.LookVector end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cam.CFrame.RightVector end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cam.CFrame.RightVector end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
            
            local currentSpeed = Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and Settings.FlyBoost or Settings.FlySpeed
            if moveDir.Magnitude > 0 then
                root.CFrame = root.CFrame + moveDir.Unit * (currentSpeed / 60)
            end
        end

        if Settings.UseCFrameSpeed and humanoid.MoveDirection.Magnitude > 0 then
            local speed = Settings.WalkSpeed
            root.CFrame = root.CFrame + root.CFrame:vectorToWorldSpace(humanoid.MoveDirection) * (speed / 60)
        end
    end

    ESP.Update()
end)

-- =====================================================================
-- FINALIZE
-- =====================================================================
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "Aetherist / AOFL",
    Content = "CFrame Hardened. Perf-Optimizer Integrated. Zero Lag.",
    Duration = 5,
    Image = "cpu"
})
