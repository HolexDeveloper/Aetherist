-- ============================================
-- AETHERIST / DEMON ARENA - EQUIP LOCK & VIM CLICK
-- Direct Equip Forcing, VIM Left Click Spam
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Singleton Management
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_EquipLock_V1"

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
    
    pcall(function() RunService:Set3dRenderingEnabled(true) end)
end

-- State
local State = {
    AutoFarmActive = false,
    SelectedSpot = "150% Boost Area",
    Disable3DRendering = false,
    SilentAntiAFK = false,
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

-- VIM Actions
local function performClick()
    pcall(function()
        local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        VirtualInputManager:MouseButton1Down(center.X, center.Y, game)
        task.wait(0.02)
        VirtualInputManager:MouseButton1Up(center.X, center.Y, game)
    end)
end

local function performAntiAfk()
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
    end)
end

-- Direct Equip Forcing (Bypasses hotkey toggle unequip)
local function forceEquipTool()
    local char = getCharacter()
    local hum = getHumanoid()
    if not char or not hum then return end
    
    -- Find the tool in backpack or character
    local tool = LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    if not tool then
        tool = char:FindFirstChildWhichIsA("Tool")
    end
    
    if tool and tool:IsA("Tool") then
        -- If it's in the backpack, equip it directly via Humanoid
        if tool.Parent == LocalPlayer.Backpack then
            pcall(function() hum:EquipTool(tool) end)
        end
    end
end

-- Smooth Tween (Under 40 Walkspeed equivalent)
local function tweenToTarget(targetPos)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end
    
    local char = getCharacter()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true -- Noclip OFF
            end
        end
    end
    
    hum.WalkSpeed = 16 
    
    local safePos = Vector3.new(targetPos.X, targetPos.Y + 3, targetPos.Z)
    local tweenInfo = TweenInfo.new(2.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(safePos)})
    
    tween:Play()
    tween.Completed:Wait()
    return true
end

-- Main Loop: Positioning
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local hrp = getHRP()
                if not hrp then return end
                
                local target = BoostSpots[State.SelectedSpot]
                if not target then return end
                
                local dist = (hrp.Position - target).Magnitude
                if dist > 15 then
                    tweenToTarget(target)
                end
            end)
        end
        task.wait(1)
    end
end))

-- Rapid Equip Verification Loop (Every 0.2s to outpace game unequip scripts)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(forceEquipTool)
        end
        task.wait(0.2)
    end
end))

-- Spam Click Loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(performClick)
        end
        task.wait(0.05) -- Fast spam for training speedup
    end
end))

-- Silent Anti-AFK Loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.SilentAntiAFK then
            pcall(performAntiAfk)
        end
        task.wait(120)
    end
end))

-- UI Generation (Rayfield Gen 2)
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    name = "Aetherist / Demon Arena",
    subtitle = "Equip Lock Edition",
    icon = "bot",
    theme = "default",
    configuration = {
        autoSave = false,
        autoLoad = false,
    },
})

-- AUTOFARM TAB (Stripped)
local AutofarmTab = Window:CreateTab({ name = "Autofarm", icon = "bot" })

AutofarmTab:CreateSection({ name = "Configuration" })

AutofarmTab:CreateDropdown({
    name = "Select Spot",
    options = {"150% Boost Area", "300% Boost Area"},
    value = "150% Boost Area",
    flag = "SelectedSpot",
    callback = function(choice)
        State.SelectedSpot = choice
    end,
})

AutofarmTab:CreateToggle({
    name = "Activate Autofarm",
    value = false,
    flag = "AutoFarmActive",
    description = "Caution: You must equip the tool you want to farm with first. Script will lock it in hand and spam LMB.",
    callback = function(value)
        State.AutoFarmActive = value
        if value then
            forceEquipTool()
        end
    end,
})

-- EXTRAS TAB
local ExtrasTab = Window:CreateTab({ name = "Extras", icon = "settings" })

ExtrasTab:CreateSection({ name = "Utilities" })

ExtrasTab:CreateToggle({
    name = "Disable 3D Rendering",
    value = false,
    flag = "Disable3DRendering",
    description = "Drops FPS to near zero for ultimate AFK performance.",
    callback = function(value)
        State.Disable3DRendering = value
        pcall(function()
            RunService:Set3dRenderingEnabled(not value)
        end)
    end,
})

ExtrasTab:CreateToggle({
    name = "Silent Anti-AFK",
    value = false,
    flag = "SilentAntiAFK",
    description = "Uses VirtualInputManager to silently prevent idle disconnects.",
    callback = function(value)
        State.SilentAntiAFK = value
    end,
})

Window:Notify({
    title = "4080 Initialized",
    content = "Equip locked. LMB spam active. UI stripped.",
    duration = 4,
    icon = "bot",
})

print("[Aetherist] Equip Lock Edition loaded. Tool forced in hand.")
