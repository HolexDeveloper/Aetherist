-- ============================================
-- AETHERIST / DEMON ARENA - TWEEN AFK EDITION
-- Tweening, 3D Render Toggle, Silent Anti-AFK
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

-- Singleton Management
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_TweenAFK_V1"

if genv[SCRIPT_KEY] then
    local old = genv[SCRIPT_KEY]
    if old.Cleanup then pcall(old.Cleanup) end
end

local Script = {
    Connections = {},
    Threads = {},
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
    table.clear(self.Connections)
    table.clear(self.Threads)
    genv[SCRIPT_KEY] = nil
    
    -- Restore 3D rendering on cleanup
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
end

-- State
local State = {
    AutoFarmActive = false,
    SelectedTarget = "Nearest Honor Ball",
    Disable3DRendering = false,
    SilentAntiAFK = false,
    HonorFarmed = 0,
}

local BoostSpots = {
    ["150% Boost Area"] = Vector3.new(1058, -158, 1568),
    ["300% Boost Area"] = Vector3.new(1008, -156, 1580),
}

-- Utilities
local function getCharacter() return LocalPlayer.Character end
local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
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

-- Tween Logic (Noclip OFF, prevents floor clipping with Y offset)
local function tweenTo(targetPos)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end
    
    -- Force walkspeed context, ensure Noclip is strictly OFF
    hum.WalkSpeed = 30
    local char = getCharacter()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true -- Noclip OFF
            end
        end
    end
    
    -- Add slight Y offset to prevent floor clipping during tween
    local safeTargetPos = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    local targetCFrame = CFrame.new(safeTargetPos)
    
    local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    tween:Play()
    tween.Completed:Wait()
    return true
end

local function findNearestHonorBall()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local nearestBall = nil
    local minDist = 500
    
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

-- Silent Anti-AFK Thread
local antiAfkThread = nil
local function toggleSilentAntiAFK(state)
    if state then
        antiAfkThread = Script:TrackThread(task.spawn(function()
            while State.SilentAntiAFK and Script.Active do
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
                task.wait(120) -- Trigger every 2 minutes
            end
        end))
    else
        if antiAfkThread then
            pcall(task.cancel, antiAfkThread)
            antiAfkThread = nil
        end
    end
end

-- Main Farm Loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local targetPos = nil
                
                if State.SelectedTarget == "150% Boost Area" then
                    targetPos = BoostSpots["150% Boost Area"]
                elseif State.SelectedTarget == "300% Boost Area" then
                    targetPos = BoostSpots["300% Boost Area"]
                else
                    local ball = findNearestHonorBall()
                    if ball then
                        targetPos = ball.Position
                    end
                end
                
                if targetPos then
                    local success = tweenTo(targetPos)
                    if success and State.SelectedTarget == "Nearest Honor Ball" then
                        task.wait(0.2)
                        local hrp = getHRP()
                        if hrp then
                            for _, v in pairs(workspace:GetDescendants()) do
                                if v:IsA("ClickDetector") and (v.Parent.Name == "HonorBall" or v.Parent.Name:lower():find("honor")) then
                                    if (v.Parent.Position - hrp.Position).Magnitude < 10 then
                                        fireclickdetector(v)
                                    end
                                end
                            end
                        end
                        State.HonorFarmed = State.HonorFarmed + 10
                    end
                end
            end)
        end
        task.wait(0.5)
    end
end))

-- UI Generation (Rayfield Gen 2 Fanmade)
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    name = "Aetherist / Demon Arena",
    subtitle = "Tween AFK Edition",
    icon = "bot",
    theme = "default",
    configuration = {
        autoSave = false,
        autoLoad = false,
    },
})

-- ONLY ONE TAB
local AutofarmTab = Window:CreateTab({ name = "Autofarm", icon = "bot" })

AutofarmTab:CreateSection({ name = "Configuration" })

AutofarmTab:CreateDropdown({
    name = "Select Target",
    options = {"Nearest Honor Ball", "150% Boost Area", "300% Boost Area"},
    value = "Nearest Honor Ball",
    flag = "TargetSpot",
    callback = function(choice)
        State.SelectedTarget = choice
    end,
})

AutofarmTab:CreateToggle({
    name = "Activate Autofarm (Tween)",
    value = false,
    flag = "AutoFarmActive",
    description = "Smooth tweens to target. Noclip is OFF. Sounds remain active.",
    callback = function(value)
        State.AutoFarmActive = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end
        end
    end,
})

AutofarmTab:CreateSection({ name = "AFK Utilities" })

AutofarmTab:CreateToggle({
    name = "Disable 3D Rendering",
    value = false,
    flag = "Disable3DRendering",
    description = "Drops FPS to near zero for ultimate AFK performance. Re-enables on disable.",
    callback = function(value)
        State.Disable3DRendering = value
        pcall(function()
            RunService:Set3dRenderingEnabled(not value)
        end)
    end,
})

AutofarmTab:CreateToggle({
    name = "Silent Anti-AFK",
    value = false,
    flag = "SilentAntiAFK",
    description = "Silently prevents Roblox idle disconnects in the background.",
    callback = function(value)
        State.SilentAntiAFK = value
        toggleSilentAntiAFK(value)
    end,
})

Window:Notify({
    title = "4080 Initialized",
    content = "Tweening active. 3D render toggle ready. Anti-AFK silent.",
    duration = 4,
    icon = "bot",
})

print("[Aetherist] Tween AFK Edition loaded. Noclip OFF. Sounds intact.")
