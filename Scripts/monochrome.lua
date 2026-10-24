-- [[ Aetherist / Monochrome ]]
-- Advanced Utility Suite built on Rayfield Gen 2
-- Loadstring: loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- ==============================================================================
-- MONOCHROME ESP SYSTEM
-- ==============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonochromeEspGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 100
screenGui.Parent = playerGui

-- Monochrome color palette (White, Light Gray, Dark Gray)
local targetDefs = {
    { name = "PlaceholderMonster", color = Color3.fromRGB(255, 255, 255), group = "monster" },
    { name = "HiddenKey1",         color = Color3.fromRGB(200, 200, 200), group = "items" },
    { name = "HiddenKey2",         color = Color3.fromRGB(200, 200, 200), group = "items" },
    { name = "HiddenKey3",         color = Color3.fromRGB(200, 200, 200), group = "items" },
    { name = "HiddenKey4",         color = Color3.fromRGB(200, 200, 200), group = "items" },
    { name = "CodeNote",           color = Color3.fromRGB(150, 150, 150), group = "items" },
}

local groupEnabled = {
    monster = false,
    items = false,
}

local trackers = {}
local corners = {
    Vector3.new(-0.5, -0.5, -0.5), Vector3.new(0.5, -0.5, -0.5),
    Vector3.new(0.5, -0.5, 0.5),   Vector3.new(-0.5, -0.5, 0.5),
    Vector3.new(-0.5, 0.5, -0.5),  Vector3.new(0.5, 0.5, -0.5),
    Vector3.new(0.5, 0.5, 0.5),    Vector3.new(-0.5, 0.5, 0.5),
}

for _, def in ipairs(targetDefs) do
    local boxFrame = Instance.new("Frame")
    boxFrame.Name = def.name .. "Box"
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.Parent = screenGui

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = def.color
    stroke.Parent = boxFrame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 16)
    label.Position = UDim2.new(0, 0, 0, -18)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = def.color
    label.Text = def.name
    label.Parent = boxFrame

    table.insert(trackers, {
        def = def,
        boxFrame = boxFrame,
        target = nil,
    })
end

local function findByName(name)
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == name and (obj:IsA("BasePart") or obj:IsA("Model")) then
            return obj
        end
    end
    return nil
end

local function getBoundsCFrameAndSize(target)
    if target:IsA("Model") then
        local cf, size = target:GetBoundingBox()
        return cf, size
    elseif target:IsA("BasePart") then
        return target.CFrame, target.Size
    end
    return nil, nil
end

RunService.RenderStepped:Connect(function()
    for _, t in ipairs(trackers) do
        if not groupEnabled[t.def.group] then
            t.boxFrame.Visible = false
        else
            if not t.target or not t.target.Parent then
                t.target = findByName(t.def.name)
            end

            if not t.target then
                t.boxFrame.Visible = false
            else
                local cf, size = getBoundsCFrameAndSize(t.target)
                if not cf then
                    t.boxFrame.Visible = false
                else
                    local minX, minY = math.huge, math.huge
                    local maxX, maxY = -math.huge, -math.huge
                    local anyBehindCamera = false

                    for _, offset in ipairs(corners) do
                        local worldPoint = cf:PointToWorldSpace(offset * size)
                        local screenPoint = camera:WorldToViewportPoint(worldPoint)

                        if screenPoint.Z <= 0 then
                            anyBehindCamera = true
                            break
                        end

                        minX = math.min(minX, screenPoint.X)
                        minY = math.min(minY, screenPoint.Y)
                        maxX = math.max(maxX, screenPoint.X)
                        maxY = math.max(maxY, screenPoint.Y)
                    end

                    if anyBehindCamera then
                        t.boxFrame.Visible = false
                    else
                        t.boxFrame.Visible = true
                        t.boxFrame.Position = UDim2.fromOffset(minX, minY)
                        t.boxFrame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- TELEPORT & MOVEMENT SYSTEMS
-- ==============================================================================
local SPAWN_POSITION = Vector3.new(254, 22, -314)

local function teleportToPosition(pos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos)
end

local function getPosition(target)
    if target:IsA("Model") then
        return target:GetBoundingBox().Position
    elseif target:IsA("BasePart") then
        return target.Position
    end
    return nil
end

local function teleportToTarget(target)
    local pos = getPosition(target)
    if not pos then return end
    teleportToPosition(pos + Vector3.new(0, 3, 0))
end

-- Speed Variables
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")

local minSpeed = 16
local maxSpeed = 90
local targetSpeed = 45
local speedEnabled = false
local speedConnection = nil
local attachment = nil
local linearVel = nil

local function setupVelocity()
    if attachment then attachment:Destroy() end
    if linearVel then linearVel:Destroy() end

    attachment = Instance.new("Attachment")
    attachment.Name = "SpeedAtt"
    attachment.Parent = root

    linearVel = Instance.new("LinearVelocity")
    linearVel.Name = "SpeedForce"
    linearVel.Attachment0 = attachment
    linearVel.MaxForce = 99999
    linearVel.VectorVelocity = Vector3.zero
    linearVel.RelativeTo = Enum.ActuatorRelativeTo.World
    linearVel.Parent = root
end

local function startSpeed()
    if speedConnection then speedConnection:Disconnect() end
    setupVelocity()

    speedConnection = RunService.Heartbeat:Connect(function()
        if not speedEnabled or not humanoid or not root or not linearVel then return end

        local moveDir = humanoid.MoveDirection
        if moveDir.Magnitude > 0.05 then
            local random = math.random(-2, 2)
            local finalSpeed = targetSpeed + random
            linearVel.VectorVelocity = Vector3.new(moveDir.X * finalSpeed, 0, moveDir.Z * finalSpeed)
            linearVel.MaxForce = 99999
        else
            linearVel.VectorVelocity = Vector3.zero
            linearVel.MaxForce = 0
        end
    end)
end

local function stopSpeed()
    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end
    if linearVel then
        linearVel.VectorVelocity = Vector3.zero
        linearVel.MaxForce = 0
    end
end

player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    root = char:WaitForChild("HumanoidRootPart")
    task.wait(0.8)
    if speedEnabled then
        startSpeed()
    end
end)

-- ==============================================================================
-- RAYFIELD GEN 2 UI SETUP
-- ==============================================================================
local Window = Rayfield:CreateWindow({
    Name = "Aetherist / Monochrome",
    Subtitle = "Advanced Utility Suite",
    Icon = "eye",
    Badge = {Text = "v1.0", Icon = "zap"},
    LoadingTitle = "Aetherist / Monochrome",
    LoadingSubtitle = "Initializing systems...",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AetheristMonochrome",
        FileName = "Config",
    },
})

local Visuals = Window:CreateTab("Visuals", "eye")
local Teleport = Window:CreateTab("Teleport", "map-pin")
local Movement = Window:CreateTab("Movement", "footprints")

-- VISUALS TAB
Visuals:CreateSection("ESP Settings")
Visuals:CreateToggle({
    Name = "Monster ESP",
    Icon = "ghost",
    CurrentValue = false,
    Flag = "MonsterESP",
    Description = "Highlights hostile entities in white.",
    Callback = function(value)
        groupEnabled.monster = value
    end,
})
Visuals:CreateToggle({
    Name = "Items ESP",
    Icon = "key",
    CurrentValue = false,
    Flag = "ItemsESP",
    Description = "Highlights keys and notes in gray.",
    Callback = function(value)
        groupEnabled.items = value
    end,
})

-- TELEPORT TAB
Teleport:CreateSection("Quick Teleports")
Teleport:CreateButton({
    Name = "Teleport to Spawn",
    Icon = "home",
    Description = "Returns you to the default spawn coordinates.",
    Callback = function()
        teleportToPosition(SPAWN_POSITION)
        Rayfield:Notify({
            Title = "Teleport",
            Content = "Teleported to Spawn",
            Duration = 3,
            Image = "home",
        })
    end,
})

Teleport:CreateSection("Target Teleports")
for _, def in ipairs(targetDefs) do
    Teleport:CreateButton({
        Name = "TP: " .. def.name,
        Icon = "map-pin",
        Description = "Teleports directly to " .. def.name,
        Callback = function()
            local target = findByName(def.name)
            if target then
                teleportToTarget(target)
                Rayfield:Notify({
                    Title = "Teleport",
                    Content = "Teleported to " .. def.name,
                    Duration = 3,
                    Image = "map-pin",
                })
            else
                Rayfield:Notify({
                    Title = "Error",
                    Content = def.name .. " not found in workspace.",
                    Duration = 3,
                    Image = "alert-circle",
                })
            end
        end,
    })
end

-- MOVEMENT TAB
Movement:CreateSection("Speed Modification")
Movement:CreateToggle({
    Name = "Enable Speed Hack",
    Icon = "zap",
    CurrentValue = false,
    Flag = "SpeedHack",
    Description = "Applies LinearVelocity-based movement speed.",
    Callback = function(value)
        speedEnabled = value
        if value then
            startSpeed()
            Rayfield:Notify({
                Title = "Movement",
                Content = "Speed hack enabled.",
                Duration = 3,
                Image = "zap",
            })
        else
            stopSpeed()
            Rayfield:Notify({
                Title = "Movement",
                Content = "Speed hack disabled.",
                Duration = 3,
                Image = "zap-off",
            })
        end
    end,
})
Movement:CreateSlider({
    Name = "Walk Speed",
    Icon = "gauge",
    Range = {minSpeed, maxSpeed},
    Increment = 1,
    Suffix = " Studs/s",
    CurrentValue = targetSpeed,
    Flag = "WalkSpeed",
    Description = "Adjusts the maximum velocity applied to your character.",
    Callback = function(value)
        targetSpeed = value
    end,
})

-- Initial Notification
Rayfield:Notify({
    Title = "Aetherist / Monochrome",
    Content = "System loaded successfully. Hover over elements for details.",
    Duration = 5,
    Image = "shield-check",
})

Rayfield:LoadConfiguration()
