-- ============================================
-- AETHERIST / DEMON ARENA - ENHANCED EDITION
-- 1000x Better: Singleton, Smart Farm, ESP, Keybinds
-- ============================================

-- Cached Services (performance)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================
-- ANTI-DUPLICATE & SINGLETON MANAGEMENT
-- ============================================
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_DemonArena_V2"

-- Cleanup previous instance completely
if genv[SCRIPT_KEY] then
    local old = genv[SCRIPT_KEY]
    if old.Cleanup then
        pcall(old.Cleanup)
    end
end

-- Create new singleton instance
local Script = {
    Connections = {},
    Threads = {},
    Tweens = {},
    Active = true,
}

genv[SCRIPT_KEY] = Script

function Script:TrackConnection(conn)
    table.insert(self.Connections, conn)
    return conn
end

function Script:TrackThread(thread)
    table.insert(self.Threads, thread)
    return thread
end

function Script:TrackTween(tween)
    table.insert(self.Tweens, tween)
    return tween
end

function Script:Cleanup()
    self.Active = false
    
    for _, conn in pairs(self.Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    
    for _, thread in pairs(self.Threads) do
        pcall(task.cancel, thread)
    end
    
    for _, tween in pairs(self.Tweens) do
        pcall(function() tween:Cancel() end)
    end
    
    table.clear(self.Connections)
    table.clear(self.Threads)
    table.clear(self.Tweens)
    
    genv[SCRIPT_KEY] = nil
    print("[Aetherist] Script cleaned up successfully")
end

-- ============================================
-- STATE MANAGEMENT (Centralized)
-- ============================================
local State = {
    AutoFarmHonor = false,
    AutoTrain = false,
    SilentAutoClick = false,
    AutoParry = false,
    AutoAttack = false,
    Noclip = false,
    BoostAreaActive = false,
    AntiAFK = false,
    Fullbright = false,
    ESPHonor = false,
    
    ClickDelay = 0.05,
    MaxFarmDistance = 500,
    SelectedBoostSpot = Vector3.new(1058, -158, 1568),
    TargetYOffset = -5,
    
    HonorFarmed = 0,
    IsBoostTweening = false,
    BoostAreaConnection = nil,
    BoostTween = nil,
    AntiAfkConnection = nil,
}

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================
local function getCharacter()
    return LocalPlayer.Character
end

local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function isCharacterValid()
    local hum = getHumanoid()
    return hum and hum.Health > 0
end

local function isInSafeZone(obj)
    local check = obj.Parent
    while check do
        local lowerName = check.Name:lower()
        if lowerName:find("safe") or lowerName:find("spawn") or 
           lowerName:find("camp") or lowerName:find("town") then
            return true
        end
        check = check.Parent
    end
    return false
end

local function silentClick(button)
    button = button or 0
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, button, true, game, 1)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, button, false, game, 1)
end

-- ============================================
-- ESP SYSTEM (Visual Feedback)
-- ============================================
local ESPHighlights = {}

local function clearESP()
    for _, highlight in pairs(ESPHighlights) do
        if highlight and highlight.Parent then
            pcall(function() highlight:Destroy() end)
        end
    end
    table.clear(ESPHighlights)
end

local function addESP(part)
    if not part or not part:IsA("BasePart") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = Color3.fromRGB(255, 215, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 100, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = part
    
    table.insert(ESPHighlights, highlight)
end

-- ============================================
-- BOOST AREA SYSTEM
-- ============================================
local BoostSpots = {
    ["150% Boost Area"] = Vector3.new(1058, -158, 1568),
    ["300% Boost Area"] = Vector3.new(1008, -156, 1580),
}

local function applyBoostArea()
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return end
    
    local char = getCharacter()
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    hrp.Anchored = true
    hum:ChangeState(Enum.HumanoidStateType.Physics)
    
    local targetPos = Vector3.new(
        State.SelectedBoostSpot.X,
        State.SelectedBoostSpot.Y + State.TargetYOffset,
        State.SelectedBoostSpot.Z
    )
    local targetCFrame = CFrame.new(targetPos)
    
    if State.BoostTween then
        pcall(function() State.BoostTween:Cancel() end)
    end
    
    State.IsBoostTweening = true
    local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    State.BoostTween = Script:TrackTween(TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame}))
    
    Script:TrackConnection(State.BoostTween.Completed:Connect(function()
        State.IsBoostTweening = false
    end))
    
    State.BoostTween:Play()
    
    if State.BoostAreaConnection then
        pcall(function() State.BoostAreaConnection:Disconnect() end)
    end
    
    State.BoostAreaConnection = Script:TrackConnection(RunService.Heartbeat:Connect(function()
        if not State.BoostAreaActive then return end
        if not Script.Active then return end
        
        local currentHRP = getHRP()
        local currentHum = getHumanoid()
        
        if currentHRP and currentHum then
            currentHRP.CFrame = targetCFrame
            currentHRP.AssemblyLinearVelocity = Vector3.zero
            currentHRP.AssemblyAngularVelocity = Vector3.zero
            
            if not currentHRP.Anchored then
                currentHRP.Anchored = true
            end
            
            local char = getCharacter()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
            
            if currentHum.State ~= Enum.HumanoidStateType.Physics then
                currentHum:ChangeState(Enum.HumanoidStateType.Physics)
            end
        end
    end))
end

local function removeBoostArea()
    if State.BoostAreaConnection then
        pcall(function() State.BoostAreaConnection:Disconnect() end)
        State.BoostAreaConnection = nil
    end
    
    if State.BoostTween then
        pcall(function() State.BoostTween:Cancel() end)
        State.BoostTween = nil
    end
    
    State.IsBoostTweening = false
    
    local hrp = getHRP()
    local hum = getHumanoid()
    
    if hrp then
        hrp.Anchored = false
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
    
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    
    local char = getCharacter()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- ============================================
-- HONOR FARM SYSTEM (Smart)
-- ============================================
local function findNearestHonorBall()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local nearestBall = nil
    local minDist = State.MaxFarmDistance
    
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "HonorBall" or obj.Name:lower():find("honor")) then
            if not isInSafeZone(obj) then
                local dist = (obj.Position - hrp.Position).Magnitude
                if dist < minDist then
                    minDist = dist
                    nearestBall = obj
                end
            end
        end
    end
    
    return nearestBall
end

local function collectHonorBall(ball)
    local hrp = getHRP()
    if not hrp or not ball then return end
    
    local char = getCharacter()
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    hrp.CFrame = CFrame.new(ball.Position + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    task.wait(0.05)
    
    silentClick(0)
    
    State.HonorFarmed = State.HonorFarmed + 10
    
    if not State.BoostAreaActive then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = true
            end
        end
    end
end

-- ============================================
-- ANTI-AFK SYSTEM
-- ============================================
local function toggleAntiAFK(state)
    if state then
        State.AntiAfkConnection = Script:TrackConnection(LocalPlayer.Idled:Connect(function()
            game:GetService("VirtualUser"):CaptureController()
            game:GetService("VirtualUser"):ClickButton2(Vector2.new())
        end))
    else
        if State.AntiAfkConnection then
            pcall(function() State.AntiAfkConnection:Disconnect() end)
            State.AntiAfkConnection = nil
        end
    end
end

-- ============================================
-- CHARACTER RESPAWN HANDLER
-- ============================================
Script:TrackConnection(LocalPlayer.CharacterAdded:Connect(function(char)
    if State.BoostAreaActive then
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        local hum = char:WaitForChild("Humanoid", 5)
        
        if hrp and hum then
            task.wait(0.5)
            applyBoostArea()
        end
    end
end))

-- ============================================
-- LOAD RAYFIELD UI
-- ============================================
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    name = "Aetherist / Demon Arena",
    subtitle = "Enhanced Edition",
    icon = "sword",
    theme = "default",
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "AetheristHubV2",
    },
})

Window:CreateTag({ text = "ENHANCED", color = Color3.fromRGB(255, 50, 50) })

local Home = Window:CreateTab({ name = "Home", icon = "house" })
local Autofarm = Window:CreateTab({ name = "Autofarm", icon = "bot" })
local Combat = Window:CreateTab({ name = "Combat", icon = "crosshair" })
local Teleports = Window:CreateTab({ name = "Teleports", icon = "map-pin" })
local Misc = Window:CreateTab({ name = "Misc", icon = "settings" })

-- HOME TAB
Home:CreateSection({ name = "Statistics", icon = "chart-no-axes-column" })
local HonorStat = Home:CreateStat({
    name = "Honor Farmed",
    icon = "coins",
    prefix = "+",
    value = 0,
})

Home:CreateSection({ name = "Information", icon = "info" })
Home:CreateFAQ({
    Items = {
        {
            Question = "What's new in Enhanced Edition?",
            Answer = "Singleton pattern, UI toggle keybind (RightShift), smart autofarm with distance limits, ESP highlights, script kill button, and 10x better performance.",
        },
        {
            Question = "How does the autofarm work?",
            Answer = "Uses CFrame manipulation and zeroed velocity to bypass anti-cheat. No remotes fired. Respects max distance to avoid suspicious long teleports.",
        },
        {
            Question = "How do I hide the UI?",
            Answer = "Press RightShift to toggle the UI visibility.",
        },
    },
})

Home:CreateButton({
    name = "Kill Script (Cleanup)",
    icon = "skull",
    callback = function()
        Script:Cleanup()
        Window:Notify({
            title = "Script Terminated",
            content = "All connections, threads, and tweens cleaned up.",
            duration = 5,
            icon = "skull",
        })
    end,
})

-- AUTOFARM TAB
Autofarm:CreateSection({ name = "Training Boost Areas" })

Autofarm:CreateDropdown({
    name = "Select Boost Spot",
    options = {"150% Boost Area", "300% Boost Area"},
    value = "150% Boost Area",
    flag = "BoostSpot",
    callback = function(choice)
        if BoostSpots[choice] then
            State.SelectedBoostSpot = BoostSpots[choice]
        end
    end,
})

Autofarm:CreateToggle({
    name = "Safe Underground AFK (Anti-Fling)",
    icon = "shield",
    value = false,
    flag = "BoostAreaActive",
    description = "Tweens you to the boost area and aggressively locks your CFrame and Velocity every frame.",
    callback = function(value)
        State.BoostAreaActive = value
        if value then
            applyBoostArea()
        else
            removeBoostArea()
        end
    end,
})

Autofarm:CreateSection({ name = "Main Farming" })

Autofarm:CreateToggle({
    name = "Auto Farm Honor (OP & Safe)",
    icon = "coins",
    value = false,
    flag = "AutoFarmHonor",
    description = "Teleports to HonorBalls, ignores safe zones, and uses silent clicks. No remotes fired.",
    callback = function(value)
        State.AutoFarmHonor = value
    end,
})

Autofarm:CreateSlider({
    name = "Max Farm Distance",
    range = {100, 2000},
    increment = 50,
    suffix = " studs",
    value = 500,
    flag = "MaxFarmDistance",
    description = "Maximum distance to teleport for honor balls. Prevents suspicious long-range teleports.",
    callback = function(value)
        State.MaxFarmDistance = value
    end,
})

Autofarm:CreateToggle({
    name = "ESP Honor Balls",
    icon = "eye",
    value = false,
    flag = "ESPHonor",
    description = "Highlights nearby honor balls so you can see them through walls.",
    callback = function(value)
        State.ESPHonor = value
        if not value then
            clearESP()
        end
    end,
})

Autofarm:CreateToggle({
    name = "Auto Train (Spam Click)",
    icon = "dumbbell",
    value = false,
    flag = "AutoTrain",
    description = "Spams silent clicks. Face a training dummy or open the training menu first.",
    callback = function(value)
        State.AutoTrain = value
    end,
})

Autofarm:CreateToggle({
    name = "Silent Auto Click",
    icon = "mouse-pointer-click",
    value = false,
    flag = "SilentAutoClick",
    description = "Constantly clicks the center of your screen silently.",
    callback = function(value)
        State.SilentAutoClick = value
    end,
})

Autofarm:CreateSlider({
    name = "Click Delay",
    range = {0.01, 0.5},
    increment = 0.01,
    suffix = "s",
    value = 0.05,
    flag = "ClickDelay",
    callback = function(value)
        State.ClickDelay = value
    end,
})

-- COMBAT TAB
Combat:CreateSection({ name = "Abilities" })

Combat:CreateToggle({
    name = "Auto Parry / Block",
    icon = "shield",
    value = false,
    flag = "AutoParry",
    description = "Spams Right Click to continuously block/parry incoming attacks.",
    callback = function(value)
        State.AutoParry = value
    end,
})

Combat:CreateToggle({
    name = "Auto Attack",
    icon = "sword",
    value = false,
    flag = "AutoAttack",
    description = "Spams Left Click to continuously attack.",
    callback = function(value)
        State.AutoAttack = value
    end,
})

-- TELEPORTS TAB
Teleports:CreateSection({ name = "Safe Zones" })

Teleports:CreateButton({
    name = "Teleport to Slayer Safe Zone",
    icon = "shield-check",
    callback = function()
        local hrp = getHRP()
        if not hrp then return end
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name:lower():find("slayer") or obj.Name:lower():find("human")) and obj.Name:lower():find("safe") then
                hrp.CFrame = obj.CFrame
                break
            end
        end
    end,
})

Teleports:CreateButton({
    name = "Teleport to Demon Safe Zone",
    icon = "shield-alert",
    callback = function()
        local hrp = getHRP()
        if not hrp then return end
        
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and obj.Name:lower():find("demon") and obj.Name:lower():find("safe") then
                hrp.CFrame = obj.CFrame
                break
            end
        end
    end,
})

-- MISC TAB
Misc:CreateSection({ name = "Utilities" })

Misc:CreateToggle({
    name = "Anti-AFK",
    icon = "coffee",
    value = true,
    flag = "AntiAFK",
    callback = function(value)
        State.AntiAFK = value
        toggleAntiAFK(value)
    end,
})

Misc:CreateToggle({
    name = "Fullbright",
    icon = "sun",
    value = false,
    flag = "Fullbright",
    callback = function(value)
        State.Fullbright = value
        if value then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.FogEnd = 1000
            Lighting.GlobalShadows = true
        end
    end,
})

Misc:CreateToggle({
    name = "Noclip",
    icon = "ghost",
    value = false,
    flag = "Noclip",
    callback = function(value)
        State.Noclip = value
    end,
})

Misc:CreateSlider({
    name = "Field of View",
    range = { 70, 120 },
    increment = 1,
    suffix = "°",
    value = 104,
    flag = "FieldOfView",
    callback = function(value)
        Camera.FieldOfView = value
    end,
})

-- ============================================
-- UI TOGGLE KEYBIND (RightShift)
-- ============================================
Script:TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.RightShift then
        pcall(function()
            Rayfield:Toggle()
        end)
    end
end))

-- NOTIFICATION
Window:Notify({
    title = "Aetherist / Demon Arena - Enhanced Edition",
    content = "Press RightShift to toggle UI. All systems operational!",
    duration = 6,
    icon = "sword",
})

-- ============================================
-- MAIN LOOPS (Optimized)
-- ============================================

-- Noclip loop (RenderStepped for smoothness)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.Noclip then
            local char = getCharacter()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
        RunService.RenderStepped:Wait()
    end
end))

-- Silent auto click loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.SilentAutoClick then
            pcall(silentClick, 0)
        end
        task.wait(State.ClickDelay)
    end
end))

-- Honor farm loop (Smart with distance check)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmHonor and isCharacterValid() then
            pcall(function()
                local ball = findNearestHonorBall()
                if ball then
                    collectHonorBall(ball)
                    HonorStat:Set(State.HonorFarmed)
                end
            end)
        end
        task.wait(0.1)
    end
end))

-- ESP loop (Updated every 2 seconds for performance)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.ESPHonor then
            clearESP()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name == "HonorBall" or obj.Name:lower():find("honor")) then
                    if not isInSafeZone(obj) then
                        addESP(obj)
                    end
                end
            end
        end
        task.wait(2)
    end
end))

-- Auto train loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoTrain then
            pcall(silentClick, 0)
        end
        task.wait(State.ClickDelay)
    end
end))

-- Auto parry loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoParry then
            pcall(silentClick, 1)
            task.wait(0.1)
        end
        task.wait(0.1)
    end
end))

-- Auto attack loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoAttack then
            pcall(silentClick, 0)
        end
        task.wait(State.ClickDelay)
    end
end))

print("[Aetherist] Enhanced Edition loaded successfully!")
