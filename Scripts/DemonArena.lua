-- ============================================
-- AETHERIST / DEMON ARENA - PATHFIND EDITION
-- Stripped UI, 30 WalkSpeed, SoundService Muted, Noclip OFF
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local SoundService = game:GetService("SoundService")

local LocalPlayer = Players.LocalPlayer

-- Singleton Management
local genv = getgenv and getgenv() or _G
local SCRIPT_KEY = "Aetherist_Pathfind_V1"

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
end

-- State
local State = {
    AutoFarmActive = false,
    SelectedTarget = "Nearest Honor Ball",
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

-- Mute SoundService Aggressively
local function muteAllSounds()
    for _, sound in pairs(SoundService:GetDescendants()) do
        if sound:IsA("Sound") then
            sound.Volume = 0
            sound.Playing = false
        end
    end
    Script:TrackConnection(SoundService.DescendantAdded:Connect(function(desc)
        if desc:IsA("Sound") then
            desc.Volume = 0
            desc.Playing = false
        end
    end))
end
muteAllSounds()

-- Pathfinding Logic (30 WalkSpeed, Noclip OFF)
local function pathfindTo(targetPos)
    local hrp = getHRP()
    local hum = getHumanoid()
    if not hrp or not hum then return false end
    
    -- Force walkspeed, ensure noclip is OFF (CanCollide remains true)
    hum.WalkSpeed = 30
    
    local char = getCharacter()
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true -- Explicitly disable noclip
            end
        end
    end
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true
    })
    
    local success = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        for _, waypoint in pairs(path:GetWaypoints()) do
            if not State.AutoFarmActive then return false end
            hum:MoveTo(waypoint.Position)
            
            -- Prevent hanging on obstacles
            local reached = hum.MoveToFinished:Wait(2)
            if not reached then
                hum.Jump = true
                task.wait(0.5)
            end
        end
        return true
    else
        -- Fallback direct move if pathfinding fails
        hum:MoveTo(targetPos)
        return true
    end
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
                        targetPos = ball.Position + Vector3.new(0, 3, 0)
                    end
                end
                
                if targetPos then
                    local success = pathfindTo(targetPos)
                    if success and State.SelectedTarget == "Nearest Honor Ball" then
                        task.wait(0.2)
                        -- Simple interaction trigger upon arrival
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
    subtitle = "Pathfind Edition",
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
    name = "Activate Autofarm (WalkSpeed 30)",
    value = false,
    flag = "AutoFarmActive",
    description = "Uses PathfindingService. Noclip is OFF. SoundService is muted.",
    callback = function(value)
        State.AutoFarmActive = value
        if not value then
            local hum = getHumanoid()
            if hum then hum.WalkSpeed = 16 end -- Reset on disable
        end
    end,
})

Window:Notify({
    title = "4080 Initialized",
    content = "Stripped UI. Pathfinding active. Sound muted.",
    duration = 4,
    icon = "bot",
})

print("[Aetherist] Pathfind Edition loaded. Noclip OFF. SoundService muted.")
