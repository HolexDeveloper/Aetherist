-- ============================================
-- AETHERIST / DEMON ARENA - INPUT PATCH
-- Fixed LMB Spam, Fixed Auto-Equip, Smooth Tween
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Singleton Management
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_InputPatch_V1"

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
    SelectedStat = "Attack",
    ClickDelay = 0.30,
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

-- Fixed Auto-Equip Logic
local function equipStatTool()
    local char = getCharacter()
    local hum = getHumanoid()
    if not char or not hum then return end

    local targetName = State.SelectedStat
    
    -- 1. Check Backpack for the specific stat tool
    local tool = LocalPlayer.Backpack:FindFirstChild(targetName)
    
    -- 2. Check Character if not in backpack
    if not tool then
        tool = char:FindFirstChild(targetName)
    end
    
    -- 3. Fallback to first available tool in backpack
    if not tool then
        tool = LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
    end

    if tool and tool:IsA("Tool") then
        -- Only equip if it's not already in the character
        if tool.Parent ~= char then
            hum:EquipTool(tool)
        end
    end
end

-- Fixed LMB Spam Click (Direct VIM Methods)
local function performClick()
    pcall(function()
        VirtualInputManager:MouseButton1Down(0, 0, game)
        task.wait(0.05)
        VirtualInputManager:MouseButton1Up(0, 0, game)
    end)
end

-- Silent Anti-AFK
local antiAfkThread = nil
local function toggleSilentAntiAFK(state)
    if state then
        antiAfkThread = Script:TrackThread(task.spawn(function()
            while State.SilentAntiAFK and Script.Active do
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new(0, 0))
                end)
                task.wait(120)
            end
        end))
    else
        if antiAfkThread then
            pcall(task.cancel, antiAfkThread)
            antiAfkThread = nil
        end
    end
end

-- Main Loop: Positioning & Maintenance
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local hrp = getHRP()
                if not hrp then return end
                
                local target = BoostSpots["150% Boost Area"]
                local dist = (hrp.Position - target).Magnitude
                
                if dist > 15 then
                    tweenToTarget(target)
                end
                
                equipStatTool()
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
                local targetName = State.SelectedStat
                local hasToolEquipped = false
                
                if char then
                    local tool = char:FindFirstChild(targetName) or char:FindFirstChildWhichIsA("Tool")
                    if tool and tool:IsA("Tool") then
                        hasToolEquipped = true
                    end
                end
                
                if not hasToolEquipped then
                    equipStatTool()
                end
            end)
        end
        task.wait(3)
    end
end))

-- Spam Click Loop
Script:TrackThread(task.spawn(function()
    while Script.Active do
        if State.AutoFarmActive then
            pcall(function()
                local char = getCharacter()
                local targetName = State.SelectedStat
                
                -- Verify tool is actually equipped before clicking
                local tool = char and char:FindFirstChild(targetName) or char and char:FindFirstChildWhichIsA("Tool")
                
                if tool and tool:IsA("Tool") and tool.Parent == char then
                    performClick()
                end
            end)
        end
        task.wait(State.ClickDelay)
    end
end))

-- UI Generation (Rayfield Gen 2)
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncUnofficial/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    name = "Aetherist / Demon Arena",
    subtitle = "Input Patch",
    icon = "dumbbell",
    theme = "default",
    configuration = {
        autoSave = false,
        autoLoad = false,
    },
})

local AutofarmTab = Window:CreateTab({ name = "Autofarm", icon = "bot" })

AutofarmTab:CreateSection({ name = "Training Configuration" })

AutofarmTab:CreateDropdown({
    name = "Stat to Train",
    options = {"Attack", "Health", "Defense", "Pierce"},
    value = "Attack",
    flag = "SelectedStat",
    callback = function(choice)
        State.SelectedStat = choice
        equipStatTool() 
    end,
})

AutofarmTab:CreateToggle({
    name = "Activate Stat Autofarm",
    value = false,
    flag = "AutoFarmActive",
    description = "Tweens to area, equips tool, spam clicks LMB.",
    callback = function(value)
        State.AutoFarmActive = value
        if value then
            equipStatTool()
        end
    end,
})

AutofarmTab:CreateSection({ name = "Click Settings" })

AutofarmTab:CreateSlider({
    name = "Spam Click Delay",
    range = {0.05, 0.50},
    increment = 0.01,
    suffix = "s",
    value = 0.30,
    flag = "ClickDelay",
    description = "Lower = faster clicks. 0.30s is standard safe speed.",
    callback = function(value)
        State.ClickDelay = value
    end,
})

AutofarmTab:CreateSection({ name = "AFK Utilities" })

AutofarmTab:CreateToggle({
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
    content = "Input layer patched. LMB and Equip locked in.",
    duration = 4,
    icon = "dumbbell",
})

print("[Aetherist] Input Patch loaded. LMB and Equip fixed.")
