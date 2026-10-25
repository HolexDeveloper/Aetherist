-- ============================================
-- AETHERIST / DEMON ARENA - VIM EDITION
-- VirtualInputManager for Clicks, Equip, Anti-AFK
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Singleton Management
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_VIM_V1"

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
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
    end)
end

local function performEquip()
    pcall(function()
        -- Simulate pressing '1' to equip the first tool
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
    end)
end

local function performAntiAfk()
    pcall(function()
        -- Simulate a harmless key press to reset AFK timer
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.RightShift, false, game)
        task.wait(0.05)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.RightShift, false, game)
    end)
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

-- Equip Verification Loop (Every 3 seconds)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local char = getCharacter()
                local hasToolEquipped = false
                
                if char then
                    local tool = char:FindFirstChildWhichIsA("Tool")
                    if tool then
                        hasToolEquipped = true
                    end
                end
                
                if not hasToolEquipped then
                    performEquip()
                end
            end)
        end
        task.wait(3)
    end
end))

-- Spam Click Loop (0.30s delay)
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local char = getCharacter()
                local tool = char and char:FindFirstChildWhichIsA("Tool")
                
                if tool and tool.Parent == char then
                    performClick()
                end
            end)
        end
        task.wait(0.30)
    end
end))

-- Silent Anti-AFK Loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.SilentAntiAFK then
            pcall(function()
                performAntiAfk()
            end)
        end
        task.wait(120)
    end
end))

-- UI Generation (Rayfield Gen 2)
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    name = "Aetherist / Demon Arena",
    subtitle = "VIM Edition",
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
    description = "Caution: You must equip the tool you want to farm with first.",
    callback = function(value)
        State.AutoFarmActive = value
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
    content = "VIM wired. UI stripped. Extras tab ready.",
    duration = 4,
    icon = "bot",
})

print("[Aetherist] VIM Edition loaded. All inputs routed through VirtualInputManager.")
