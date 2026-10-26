local Aetherist = {}
Aetherist.Version = "1.0.0"
Aetherist.Build = "AOFL"

local Services = {}
Services.Players = game:GetService("Players")
Services.RunService = game:GetService("RunService")
Services.ReplicatedStorage = game:GetService("ReplicatedStorage")
Services.Workspace = game:GetService("Workspace")
Services.Lighting = game:GetService("Lighting")
Services.UserInputService = game:GetService("UserInputService")
Services.ProximityPromptService = game:GetService("ProximityPromptService")
Services.TweenService = game:GetService("TweenService")
Services.TextChatService = game:GetService("TextChatService")

local LocalPlayer = Services.Players.LocalPlayer
local Camera = Services.Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local AOFL = {}
AOFL.State = {}
AOFL.Cache = {}
AOFL.Hooks = {}
AOFL.ESPObjects = {}
AOFL.Threads = {}
AOFL.Performance = {
    RenderTime = 0,
    MemoryUsage = 0,
    ActiveHooks = 0,
    ESPCount = 0
}

function AOFL.SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        return nil, result
    end
    return result
end

function AOFL.GetAttributeSafe(instance, name, default)
    if not instance or not instance.GetAttribute then
        return default
    end
    local val = instance:GetAttribute(name)
    return val ~= nil and val or default
end

function AOFL.SetAttributeSafe(instance, name, value)
    if not instance or not instance.SetAttribute then
        return false
    end
    local success = pcall(instance.SetAttribute, instance, name, value)
    return success
end

function AOFL.FindChildSafe(instance, name, recursive)
    if not instance then return nil end
    if recursive then
        return instance:FindFirstChild(name, true)
    end
    return instance:FindFirstChild(name)
end

function AOFL.WaitForChildSafe(instance, name, timeout)
    if not instance then return nil end
    return AOFL.SafeCall(instance.WaitForChild, instance, name, timeout or 5)
end

function AOFL.RegisterHook(name, callback)
    if AOFL.Hooks[name] then
        return false
    end
    AOFL.Hooks[name] = callback
    AOFL.Performance.ActiveHooks = AOFL.Performance.ActiveHooks + 1
    return true
end

function AOFL.UnregisterHook(name)
    if AOFL.Hooks[name] then
        AOFL.Hooks[name] = nil
        AOFL.Performance.ActiveHooks = AOFL.Performance.ActiveHooks - 1
        return true
    end
    return false
end

function AOFL.ExecuteHooks(...)
    for name, callback in pairs(AOFL.Hooks) do
        AOFL.SafeCall(callback, ...)
    end
end

function AOFL.CacheInstance(key, instance)
    AOFL.Cache[key] = instance
end

function AOFL.GetCached(key)
    local instance = AOFL.Cache[key]
    if instance and instance.Parent then
        return instance
    end
    AOFL.Cache[key] = nil
    return nil
end

function AOFL.ClearCache()
    for key in pairs(AOFL.Cache) do
        AOFL.Cache[key] = nil
    end
end

function AOFL.GarbageCollect()
    local count = 0
    for key, instance in pairs(AOFL.Cache) do
        if not instance or not instance.Parent then
            AOFL.Cache[key] = nil
            count = count + 1
        end
    end
    for target, data in pairs(AOFL.ESPObjects) do
        if not target or not target.Parent then
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            AOFL.ESPObjects[target] = nil
            count = count + 1
        end
    end
    AOFL.Performance.ESPCount = 0
    for _ in pairs(AOFL.ESPObjects) do
        AOFL.Performance.ESPCount = AOFL.Performance.ESPCount + 1
    end
    return count
end

local ESP = {}
ESP.Enabled = false
ESP.Config = {
    Monsters = true,
    Players = false,
    Items = true,
    Extraction = true,
    MaxDistance = 1500,
    ShowNames = true,
    ShowDistance = true,
    ShowHealth = false,
    BoxColor = Color3.fromRGB(255, 50, 50),
    NameColor = Color3.fromRGB(255, 255, 255),
    ItemColor = Color3.fromRGB(255, 215, 0)
}

function ESP.CreateHighlight(target, color, depthMode)
    if not target or not target.Parent then return nil end
    local highlight = Instance.new("Highlight")
    highlight.Name = "AOFL_ESP_HL"
    highlight.DepthMode = depthMode or Enum.HighlightDepthMode.AlwaysOnTop
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
    billboard.ResetOnSpawn = false
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

function ESP.UpdateBillboard(data, target, localPos)
    if not data.Billboard or not target or not target.Parent then return end
    
    local targetPos = nil
    if target:IsA("Model") and target.PrimaryPart then
        targetPos = target.PrimaryPart.Position
    elseif target:IsA("BasePart") then
        targetPos = target.Position
    end

    if not targetPos then return end

    local distance = (targetPos - localPos).Magnitude
    local nameText = ESP.Config.ShowNames and target.Name or ""
    local distText = ESP.Config.ShowDistance and string.format("[%d studs]", math.floor(distance)) or ""

    data.Billboard.Name.Text = nameText
    data.Billboard.Distance.Text = distText
    data.Billboard.Enabled = distance <= ESP.Config.MaxDistance
end

function ESP.ProcessTarget(target, category, color)
    if not target or not target.Parent then return end
    if AOFL.ESPObjects[target] then return end

    local data = {
        Category = category,
        Highlight = nil,
        Billboard = nil
    }

    if category == "Monster" or category == "Player" then
        data.Highlight = ESP.CreateHighlight(target, color, Enum.HighlightDepthMode.AlwaysOnTop)
    elseif category == "Item" then
        data.Highlight = ESP.CreateHighlight(target, color, Enum.HighlightDepthMode.Occluded)
    end

    if ESP.Config.ShowNames or ESP.Config.ShowDistance then
        local adornee = target
        if target:IsA("Model") and target.PrimaryPart then
            adornee = target.PrimaryPart
        elseif target:IsA("BasePart") then
            adornee = target
        else
            adornee = nil
        end
        
        if adornee then
            data.Billboard = ESP.CreateBillboard(adornee, target.Name, ESP.Config.NameColor)
        end
    end

    AOFL.ESPObjects[target] = data
    AOFL.Performance.ESPCount = AOFL.Performance.ESPCount + 1
end

function ESP.ClearCategory(category)
    for target, data in pairs(AOFL.ESPObjects) do
        if data.Category == category then
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
            AOFL.ESPObjects[target] = nil
        end
    end
end

function ESP.ClearAll()
    for target, data in pairs(AOFL.ESPObjects) do
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
    end
    table.clear(AOFL.ESPObjects)
    AOFL.Performance.ESPCount = 0
end

local Entities = {}
Entities.LocustSpoof = false
Entities.AngelSpoof = false
Entities.DeadlightsSpoof = false
Entities.ShadowDispel = false
Entities.FreezeMonsters = false

function Entities.SpoofLocust()
    local session = AOFL.GetCached("ShoppingSession")
    if not session then return end
    AOFL.SetAttributeSafe(session, "IsHiding", true)
    AOFL.SetAttributeSafe(session, "LocustSightRange", 0)
    AOFL.SetAttributeSafe(session, "MovementNoise", 0)
end

function Entities.SpoofAngel()
    local session = AOFL.GetCached("ShoppingSession")
    if not session then return end
    AOFL.SetAttributeSafe(session, "InSafeLight", true)
    AOFL.SetAttributeSafe(session, "AngelGazeActive", false)
    
    if LocalPlayer.Character then
        AOFL.SetAttributeSafe(LocalPlayer, "EncounterState", "Alive")
        AOFL.SetAttributeSafe(LocalPlayer, "AngelCaptivated", false)
    end
end

function Entities.SpoofDeadlights()
    if not LocalPlayer.Character then return end
    AOFL.SetAttributeSafe(LocalPlayer, "GlareLevel", 0)
    AOFL.SetAttributeSafe(LocalPlayer, "DeadlightsCaptivated", false)
    AOFL.SetAttributeSafe(LocalPlayer, "StruggleProgress", 0)
end

function Entities.DispelShadowCrowd()
    local shadowFolder = Services.Workspace:FindFirstChild("ShadowCrowdVisuals")
    if shadowFolder then
        for _, child in ipairs(shadowFolder:GetChildren()) do
            if child:IsA("BasePart") or child:IsA("Model") then
                child.Transparency = 1
                child.CanCollide = false
                child.CanTouch = false
                child.CanQuery = false
            end
        end
    end
end

function Entities.FreezeAllMonsters()
    local monsters = Services.Workspace:FindFirstChild("Monsters")
    if not monsters then return end
    
    for _, monster in ipairs(monsters:GetChildren()) do
        if monster:IsA("Model") then
            local humanoid = monster:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.WalkSpeed = 0
                humanoid.JumpPower = 0
            end
            for _, part in ipairs(monster:GetDescendants()) do
                if part:IsA("BasePart") and not part.Anchored then
                    part.Anchored = true
                end
            end
        end
    end
end

local Session = {}
Session.ForceLights = false
Session.ForceDay = false
Session.MaxQuota = false
Session.SkipPhase = false
Session.InfiniteTime = false

function Session.OverrideLighting()
    if not Session.ForceLights then return end
    
    local session = AOFL.GetCached("ShoppingSession")
    if session then
        AOFL.SetAttributeSafe(session, "LightsOn", true)
        AOFL.SetAttributeSafe(session, "RedAlertActive", false)
        AOFL.SetAttributeSafe(session, "LightsBurnedOut", false)
        AOFL.SetAttributeSafe(session, "BlackoutActive", false)
    end

    local lighting = Services.Lighting
    lighting.Brightness = 2
    lighting.ClockTime = 14
    lighting.FogEnd = 100000
    lighting.GlobalShadows = true
    lighting.Ambient = Color3.fromRGB(150, 150, 150)
    lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
end

function Session.OverrideQuota()
    if not Session.MaxQuota then return end
    local session = AOFL.GetCached("ShoppingSession")
    if session then
        AOFL.SetAttributeSafe(session, "QuotaProgress", 9999)
        AOFL.SetAttributeSafe(session, "QuotaTarget", 1)
    end
end

function Session.OverridePhase()
    if not Session.SkipPhase then return end
    local session = AOFL.GetCached("ShoppingSession")
    if session then
        AOFL.SetAttributeSafe(session, "Phase", "ListComplete")
        AOFL.SetAttributeSafe(session, "DaySecondsRemaining", 9999)
    end
end

local PlayerCtrl = {}
PlayerCtrl.InfiniteStamina = false
PlayerCtrl.Noclip = false
PlayerCtrl.Fly = false
PlayerCtrl.InstantPrompt = false
PlayerCtrl.WalkSpeed = 16
PlayerCtrl.JumpPower = 50
PlayerCtrl.GodMode = false

function PlayerCtrl.ApplyStamina()
    if not PlayerCtrl.InfiniteStamina then return end
    if not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        AOFL.SetAttributeSafe(humanoid, "Stamina", 9999)
        AOFL.SetAttributeSafe(humanoid, "CartStamina", 9999)
        AOFL.SetAttributeSafe(humanoid, "CartExhausted", false)
        AOFL.SetAttributeSafe(humanoid, "SprintStamina", 9999)
    end
    
    AOFL.SetAttributeSafe(LocalPlayer, "Stamina", 9999)
    AOFL.SetAttributeSafe(LocalPlayer, "MovementNoise", 0)
end

function PlayerCtrl.ApplyNoclip()
    if not PlayerCtrl.Noclip then return end
    if not LocalPlayer.Character then return end
    
    for _, descendant in ipairs(LocalPlayer.Character:GetDescendants()) do
        if descendant:IsA("BasePart") then
            descendant.CanCollide = false
        end
    end
end

function PlayerCtrl.ApplyGodMode()
    if not PlayerCtrl.GodMode then return end
    if not LocalPlayer.Character then return end
    
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.Health = humanoid.MaxHealth
    end
end

function PlayerCtrl.ApplyInstantPrompts()
    if not PlayerCtrl.InstantPrompt then return end
    
    for _, descendant in ipairs(Services.Workspace:GetDescendants()) do
        if descendant:IsA("ProximityPrompt") then
            descendant.HoldDuration = 0
            descendant.RequiresLineOfSight = false
        end
    end
end

function PlayerCtrl.HookProximityPrompts()
    Services.ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
        if PlayerCtrl.InstantPrompt then
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end
    end)
    
    Services.Workspace.DescendantAdded:Connect(function(descendant)
        if descendant:IsA("ProximityPrompt") and PlayerCtrl.InstantPrompt then
            task.defer(function()
                descendant.HoldDuration = 0
                descendant.RequiresLineOfSight = false
            end)
        end
    end)
end

local Autofarm = {}
Autofarm.AutoCollect = false
Autofarm.AutoExtract = false
Autofarm.AutoSell = false
Autofarm.AutoBuy = false

function Autofarm.CollectItems()
    if not Autofarm.AutoCollect then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPart = LocalPlayer.Character.HumanoidRootPart
    local closestItem = nil
    local closestDist = math.huge
    
    for _, descendant in ipairs(Services.Workspace:GetDescendants()) do
        if descendant:IsA("Tool") or descendant.Name:match("Grocery") or descendant.Name:match("Medkit") or descendant.Name:match("Noisemaker") then
            if descendant:IsA("BasePart") then
                local dist = (descendant.Position - rootPart.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestItem = descendant
                end
            elseif descendant.Parent and descendant.Parent:IsA("Model") then
                local primary = descendant.Parent.PrimaryPart
                if primary then
                    local dist = (primary.Position - rootPart.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closestItem = primary
                    end
                end
            end
        end
    end
    
    if closestItem and closestDist < 500 then
        rootPart.CFrame = closestItem.CFrame
    end
end

function Autofarm.Extract()
    if not Autofarm.AutoExtract then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local extractionZone = Services.Workspace:FindFirstChild("GroceryExtraction", true)
    if extractionZone then
        local zonePart = extractionZone:FindFirstChildOfClass("BasePart")
        if zonePart then
            LocalPlayer.Character.HumanoidRootPart.CFrame = zonePart.CFrame
        end
    end
end

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Aetherist / AOFL",
    Subtitle = "Absolute Override Force Layer",
    Icon = "shield",
    Badge = {Text = "v1.0", Icon = "sparkles"},
    LoadingTitle = "Aetherist",
    LoadingSubtitle = "Initializing AOFL Engine",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Aetherist_AOFL",
        FileName = "Config",
    },
})

local TabESP = Window:CreateTab("ESP", "eye")
local TabEntities = Window:CreateTab("Entities", "ghost")
local TabSession = Window:CreateTab("Session", "globe")
local TabPlayer = Window:CreateTab("Player", "user")
local TabAutofarm = Window:CreateTab("Autofarm", "zap")
local TabEngine = Window:CreateTab("Engine", "cpu")

TabESP:CreateSection("Targets")
local ESPRow1 = TabESP:CreateRow()
ESPRow1:CreateToggle({
    Name = "Monster ESP",
    Icon = "skull",
    CurrentValue = true,
    Flag = "AOFL_ESP_Monsters",
    Callback = function(value)
        ESP.Config.Monsters = value
        if not value then ESP.ClearCategory("Monster") end
    end,
})
ESPRow1:CreateToggle({
    Name = "Player ESP",
    Icon = "users",
    CurrentValue = false,
    Flag = "AOFL_ESP_Players",
    Callback = function(value)
        ESP.Config.Players = value
        if not value then ESP.ClearCategory("Player") end
    end,
})
ESPRow1:CreateToggle({
    Name = "Item ESP",
    Icon = "package",
    CurrentValue = true,
    Flag = "AOFL_ESP_Items",
    Callback = function(value)
        ESP.Config.Items = value
        if not value then ESP.ClearCategory("Item") end
    end,
})

TabESP:CreateSection("Visuals")
local ESPRow2 = TabESP:CreateRow()
ESPRow2:CreateToggle({
    Name = "Show Names",
    Icon = "type",
    CurrentValue = true,
    Flag = "AOFL_ESP_Names",
    Callback = function(value) ESP.Config.ShowNames = value end,
})
ESPRow2:CreateToggle({
    Name = "Show Distance",
    Icon = "ruler",
    CurrentValue = true,
    Flag = "AOFL_ESP_Dist",
    Callback = function(value) ESP.Config.ShowDistance = value end,
})
ESPRow2:CreateSlider({
    Name = "Max Render Distance",
    Range = {100, 2000},
    Increment = 50,
    Suffix = " studs",
    CurrentValue = 1500,
    Flag = "AOFL_ESP_MaxDist",
    Callback = function(value) ESP.Config.MaxDistance = value end,
})

TabEntities:CreateSection("Monster Manipulation")
local EntRow1 = TabEntities:CreateRow()
EntRow1:CreateToggle({
    Name = "Spoof Locust (Invisible)",
    Icon = "bug",
    CurrentValue = false,
    Flag = "AOFL_Ent_Locust",
    Description = "Spoofs hiding state and noise to 0.",
    Callback = function(value) Entities.LocustSpoof = value end,
})
EntRow1:CreateToggle({
    Name = "Spoof Angel (Safe Light)",
    Icon = "eye-off",
    CurrentValue = false,
    Flag = "AOFL_Ent_Angel",
    Description = "Forces safe light state and breaks gaze.",
    Callback = function(value) Entities.AngelSpoof = value end,
})

local EntRow2 = TabEntities:CreateRow()
EntRow2:CreateToggle({
    Name = "Spoof Deadlights",
    Icon = "sun",
    CurrentValue = false,
    Flag = "AOFL_Ent_Deadlights",
    Description = "Nullifies glare and captivation.",
    Callback = function(value) Entities.DeadlightsSpoof = value end,
})
EntRow2:CreateToggle({
    Name = "Dispel Shadow Crowd",
    Icon = "users",
    CurrentValue = false,
    Flag = "AOFL_Ent_Shadow",
    Description = "Makes shadow visuals transparent and non-collidable.",
    Callback = function(value) Entities.ShadowDispel = value end,
})

TabEntities:CreateSection("Global Entity Controls")
TabEntities:CreateToggle({
    Name = "Freeze All Monsters",
    Icon = "snowflake",
    CurrentValue = false,
    Flag = "AOFL_Ent_Freeze",
    Description = "Anchors all monster parts and sets speed to 0.",
    Callback = function(value) Entities.FreezeMonsters = value end,
})
TabEntities:CreateButton({
    Name = "Destroy Local Monster Models",
    Icon = "trash-2",
    Callback = function()
        local monsters = Services.Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, child in ipairs(monsters:GetChildren()) do
                child:Destroy()
            end
        end
        local angels = Services.Workspace:FindFirstChild("Angels")
        if angels then
            for _, child in ipairs(angels:GetChildren()) do
                child:Destroy()
            end
        end
    end,
})

TabSession:CreateSection("Environment Control")
local SessRow1 = TabSession:CreateRow()
SessRow1:CreateToggle({
    Name = "Force Lights On",
    Icon = "lightbulb",
    CurrentValue = false,
    Flag = "AOFL_Sess_Lights",
    Description = "Prevents blackouts and burnouts.",
    Callback = function(value) Session.ForceLights = value end,
})
SessRow1:CreateToggle({
    Name = "Force Day Phase",
    Icon = "sun",
    CurrentValue = false,
    Flag = "AOFL_Sess_Day",
    Description = "Locks lighting to daytime.",
    Callback = function(value) Session.ForceDay = value end,
})

local SessRow2 = TabSession:CreateRow()
SessRow2:CreateToggle({
    Name = "Max Quota Progress",
    Icon = "check-circle",
    CurrentValue = false,
    Flag = "AOFL_Sess_Quota",
    Callback = function(value) Session.MaxQuota = value end,
})
SessRow2:CreateToggle({
    Name = "Skip Phase / Infinite Time",
    Icon = "fast-forward",
    CurrentValue = false,
    Flag = "AOFL_Sess_Phase",
    Callback = function(value) Session.SkipPhase = value end,
})

TabPlayer:CreateSection("Survival & Movement")
local PlayRow1 = TabPlayer:CreateRow()
PlayRow1:CreateToggle({
    Name = "Infinite Stamina",
    Icon = "battery-charging",
    CurrentValue = true,
    Flag = "AOFL_Play_Stamina",
    Callback = function(value) PlayerCtrl.InfiniteStamina = value end,
})
PlayRow1:CreateToggle({
    Name = "God Mode",
    Icon = "shield",
    CurrentValue = false,
    Flag = "AOFL_Play_God",
    Callback = function(value) PlayerCtrl.GodMode = value end,
})
PlayRow1:CreateToggle({
    Name = "Noclip",
    Icon = "ghost",
    CurrentValue = false,
    Flag = "AOFL_Play_Noclip",
    Callback = function(value) PlayerCtrl.Noclip = value end,
})

local PlayRow2 = TabPlayer:CreateRow()
PlayRow2:CreateToggle({
    Name = "Instant Proximity Prompts",
    Icon = "hand",
    CurrentValue = true,
    Flag = "AOFL_Play_Prompt",
    Callback = function(value) PlayerCtrl.InstantPrompt = value end,
})
PlayRow2:CreateSlider({
    Name = "Walk Speed",
    Range = {16, 250},
    Increment = 1,
    Suffix = " Speed",
    CurrentValue = 16,
    Flag = "AOFL_Play_Speed",
    Callback = function(value)
        PlayerCtrl.WalkSpeed = value
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    end,
})
PlayRow2:CreateSlider({
    Name = "Jump Power",
    Range = {50, 300},
    Increment = 1,
    Suffix = " Power",
    CurrentValue = 50,
    Flag = "AOFL_Play_Jump",
    Callback = function(value)
        PlayerCtrl.JumpPower = value
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            LocalPlayer.Character.Humanoid.JumpPower = value
        end
    end,
})

TabAutofarm:CreateSection("Collection & Economy")
local FarmRow1 = TabAutofarm:CreateRow()
FarmRow1:CreateToggle({
    Name = "Auto Collect Items",
    Icon = "magnet",
    CurrentValue = false,
    Flag = "AOFL_Farm_Collect",
    Description = "Teleports to nearest grocery/item.",
    Callback = function(value) Autofarm.AutoCollect = value end,
})
FarmRow1:CreateToggle({
    Name = "Auto Extract",
    Icon = "door-open",
    CurrentValue = false,
    Flag = "AOFL_Farm_Extract",
    Description = "Teleports to extraction zone.",
    Callback = function(value) Autofarm.AutoExtract = value end,
})

TabEngine:CreateSection("AOFL Performance & Memory")
local EngineStat1 = TabEngine:CreateStat({
    Name = "Render Time",
    Icon = "clock",
    Value = "0.00 ms",
    Delta = "0%",
})
local EngineStat2 = TabEngine:CreateStat({
    Name = "Active ESP Objects",
    Icon = "eye",
    Value = "0",
    Delta = "0",
})
local EngineStat3 = TabEngine:CreateStat({
    Name = "Active Hooks",
    Icon = "link",
    Value = "0",
    Delta = "0",
})

TabEngine:CreateButton({
    Name = "Force Garbage Collection",
    Icon = "trash",
    Callback = function()
        local cleared = AOFL.GarbageCollect()
        Rayfield:Notify({
            Title = "AOFL Engine",
            Content = string.format("Cleared %d invalid references.", cleared),
            Duration = 4,
            Image = "trash",
        })
    end,
})

TabEngine:CreateButton({
    Name = "Clear All ESP",
    Icon = "eye-off",
    Callback = function()
        ESP.ClearAll()
        Rayfield:Notify({
            Title = "AOFL Engine",
            Content = "All ESP objects destroyed.",
            Duration = 3,
            Image = "eye-off",
        })
    end,
})

local function UpdateESP()
    if not ESP.Config.Monsters and not ESP.Config.Players and not ESP.Config.Items then
        return
    end

    local localPos = Vector3.new(0, 0, 0)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        localPos = LocalPlayer.Character.HumanoidRootPart.Position
    end

    if ESP.Config.Monsters then
        local monsters = Services.Workspace:FindFirstChild("Monsters")
        if monsters then
            for _, monster in ipairs(monsters:GetChildren()) do
                if monster:IsA("Model") then
                    ESP.ProcessTarget(monster, "Monster", ESP.Config.BoxColor)
                end
            end
        end
        local angels = Services.Workspace:FindFirstChild("Angels")
        if angels then
            for _, angel in ipairs(angels:GetChildren()) do
                if angel:IsA("Model") then
                    ESP.ProcessTarget(angel, "Monster", Color3.fromRGB(255, 255, 255))
                end
            end
        end
    end

    if ESP.Config.Players then
        for _, player in ipairs(Services.Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                ESP.ProcessTarget(player.Character, "Player", Color3.fromRGB(50, 150, 255))
            end
        end
    end

    if ESP.Config.Items then
        for _, descendant in ipairs(Services.Workspace:GetDescendants()) do
            if descendant:IsA("Tool") or descendant.Name:match("Grocery") or descendant.Name:match("Medkit") then
                local target = descendant
                if descendant.Parent and descendant.Parent:IsA("Model") then
                    target = descendant.Parent
                end
                ESP.ProcessTarget(target, "Item", ESP.Config.ItemColor)
            end
        end
    end

    for target, data in pairs(AOFL.ESPObjects) do
        ESP.UpdateBillboard(data, target, localPos)
    end
end

local function RunEntityHooks()
    if Entities.LocustSpoof then Entities.SpoofLocust() end
    if Entities.AngelSpoof then Entities.SpoofAngel() end
    if Entities.DeadlightsSpoof then Entities.SpoofDeadlights() end
    if Entities.ShadowDispel then Entities.DispelShadowCrowd() end
    if Entities.FreezeMonsters then Entities.FreezeAllMonsters() end
end

local function RunSessionHooks()
    Session.OverrideLighting()
    Session.OverrideQuota()
    Session.OverridePhase()
end

local function RunPlayerHooks()
    PlayerCtrl.ApplyStamina()
    PlayerCtrl.ApplyNoclip()
    PlayerCtrl.ApplyGodMode()
end

local function RunAutofarmHooks()
    Autofarm.CollectItems()
    Autofarm.Extract()
end

local function UpdateEngineStats()
    local mem = collectgarbage("count")
    AOFL.Performance.MemoryUsage = mem
    AOFL.Performance.ESPCount = 0
    for _ in pairs(AOFL.ESPObjects) do
        AOFL.Performance.ESPCount = AOFL.Performance.ESPCount + 1
    end
    
    EngineStat1:Set({Value = string.format("%.2f ms", AOFL.Performance.RenderTime * 1000)})
    EngineStat2:Set({Value = tostring(AOFL.Performance.ESPCount)})
    EngineStat3:Set({Value = tostring(AOFL.Performance.ActiveHooks)})
end

local function CacheCoreInstances()
    local session = Services.ReplicatedStorage:FindFirstChild("ShoppingSession")
    if session then
        AOFL.CacheInstance("ShoppingSession", session)
    end
    
    local remotes = Services.ReplicatedStorage:FindFirstChild("LocustRemotes")
    if remotes then
        AOFL.CacheInstance("LocustRemotes", remotes)
    end
    
    local deadlightsRemotes = Services.ReplicatedStorage:FindFirstChild("DeadlightsRemotes")
    if deadlightsRemotes then
        AOFL.CacheInstance("DeadlightsRemotes", deadlightsRemotes)
    end
end

local function InitCharacterHooks()
    local function onCharacterAdded(character)
        task.wait(0.5)
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = LocalPlayer.Character.Humanoid
            humanoid.WalkSpeed = PlayerCtrl.WalkSpeed
            humanoid.JumpPower = PlayerCtrl.JumpPower
        end
    end

    if LocalPlayer.Character then
        onCharacterAdded(LocalPlayer.Character)
    end

    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
end

local function MainLoop()
    local lastGC = tick()
    
    Services.RunService.Heartbeat:Connect(function(dt)
        local startTime = os.clock()
        
        CacheCoreInstances()
        RunEntityHooks()
        RunSessionHooks()
        RunPlayerHooks()
        RunAutofarmHooks()
        
        if tick() - lastGC > 30 then
            AOFL.GarbageCollect()
            lastGC = tick()
        end
        
        AOFL.Performance.RenderTime = os.clock() - startTime
    end)

    Services.RunService.RenderStepped:Connect(function(dt)
        UpdateESP()
        UpdateEngineStats()
    end)
end

local function Init()
    CacheCoreInstances()
    PlayerCtrl.HookProximityPrompts()
    InitCharacterHooks()
    MainLoop()
    
    Rayfield:Notify({
        Title = "Aetherist / AOFL",
        Content = "Absolute Override Force Layer initialized. Engine is stable.",
        Duration = 6,
        Image = "shield",
    })
end

Init()
Rayfield:LoadConfiguration()
