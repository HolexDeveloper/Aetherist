local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Stats = game:GetService("Stats")

local DrawingEnabled = pcall(function()
    local test = Drawing.new("Line")
    test:Remove()
end)

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Entrenched | Combat Suite",
    Subtitle = "v3.0 Rayfield Gen2",
    Icon = "crosshair",
    Badge = {Text = "v3.0", Icon = "shield"},
    LoadingTitle = "Entrenched",
    LoadingSubtitle = "Combat Suite",
    ToggleUIKeybind = "RightControl",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Entrenched_Suite",
        FileName = "Config_v3",
    },
})

local Settings = {
    ESP = {
        Enabled = true,
        TeamCheck = true,
        Boxes = true,
        Names = true,
        Health = true,
        Distance = true,
        Tracers = true,
        Color = "Red",
    },
    Aimbot = {
        Enabled = false,
        FOV = 150,
        ShowFOV = true,
        Smoothness = 30,
        TargetPart = "Head",
        WallCheck = true,
    },
    Performance = {
        Ping = 0,
        FPS = 0,
        Kills = 0,
        Targets = 0,
    },
    History = {
        Distance = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    }
}

local colorMap = {
    Red = Color3.fromRGB(255, 0, 0),
    Green = Color3.fromRGB(0, 255, 0),
    Blue = Color3.fromRGB(0, 150, 255),
    White = Color3.fromRGB(255, 255, 255),
}

local ESP_Objects = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Suite_HL"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Suite_BB"
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = hrp
    billboard.Parent = hrp
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Parent = billboard
    
    local healthLabel = Instance.new("TextLabel")
    healthLabel.Name = "Health"
    healthLabel.Position = UDim2.new(0, 0, 0, 20)
    healthLabel.Size = UDim2.new(1, 0, 0, 15)
    healthLabel.BackgroundTransparency = 1
    healthLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    healthLabel.TextStrokeTransparency = 0
    healthLabel.Font = Enum.Font.Gotham
    healthLabel.TextSize = 12
    healthLabel.Parent = billboard

    local distLabel = Instance.new("TextLabel")
    distLabel.Name = "Dist"
    distLabel.Position = UDim2.new(0, 0, 0, 35)
    distLabel.Size = UDim2.new(1, 0, 0, 15)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.TextStrokeTransparency = 0
    distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12
    distLabel.Parent = billboard

    local tracer = nil
    if DrawingEnabled then
        tracer = Drawing.new("Line")
        tracer.Thickness = 1.5
        tracer.Color = colorMap[Settings.ESP.Color]
    end

    ESP_Objects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        HealthLabel = healthLabel,
        DistLabel = distLabel,
        Tracer = tracer,
        Connections = {}
    }
    
    ESP_Objects[player].Connections.CharAdded = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        local newHrp = newChar:WaitForChild("HumanoidRootPart", 5)
        if newHrp and ESP_Objects[player] then
            ESP_Objects[player].Highlight.Adornee = newChar
            ESP_Objects[player].Highlight.Parent = newChar
            ESP_Objects[player].Billboard.Adornee = newHrp
            ESP_Objects[player].Billboard.Parent = newHrp
        end
    end)
end

local function UpdateESP(dt)
    local activeTargets = 0
    local closestDist = 9999
    
    for player, obj in pairs(ESP_Objects) do
        pcall(function()
            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChild("Humanoid")
            
            local isEnemy = true
            if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then
                isEnemy = false
            end

            if not Settings.ESP.Enabled or not isEnemy or not root or not hum or hum.Health <= 0 then
                if obj.Highlight then obj.Highlight.Enabled = false end
                if obj.Billboard then obj.Billboard.Enabled = false end
                if obj.Tracer then obj.Tracer.Visible = false end
                return
            end
            
            activeTargets = activeTargets + 1
            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local dist = (root.Position - Camera.CFrame.Position).Magnitude
            if dist < closestDist then closestDist = dist end

            if obj.Highlight then
                obj.Highlight.Enabled = Settings.ESP.Boxes
                local c = colorMap[Settings.ESP.Color] or Color3.fromRGB(255,0,0)
                obj.Highlight.FillColor = c
                obj.Highlight.OutlineColor = c
            end
            
            if obj.Billboard then
                obj.Billboard.Enabled = Settings.ESP.Names or Settings.ESP.Health or Settings.ESP.Distance
                obj.Billboard.Adornee = root
                
                if Settings.ESP.Names then
                    obj.NameLabel.Text = player.Name
                    obj.NameLabel.Visible = true
                else
                    obj.NameLabel.Visible = false
                end

                if Settings.ESP.Health then
                    obj.HealthLabel.Text = math.floor(hum.Health) .. " HP"
                    obj.HealthLabel.TextColor3 = Color3.fromRGB(255, math.floor(255 * (hum.Health/hum.MaxHealth)), 0)
                    obj.HealthLabel.Visible = true
                else
                    obj.HealthLabel.Visible = false
                end

                if Settings.ESP.Distance then
                    obj.DistLabel.Text = "[" .. math.floor(dist) .. "m]"
                    obj.DistLabel.Visible = true
                else
                    obj.DistLabel.Visible = false
                end
            end

            if obj.Tracer then
                if Settings.ESP.Tracers and onScreen then
                    obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    obj.Tracer.To = Vector2.new(pos.X, pos.Y)
                    obj.Tracer.Color = colorMap[Settings.ESP.Color] or Color3.fromRGB(255,0,0)
                    obj.Tracer.Visible = true
                else
                    obj.Tracer.Visible = false
                end
            end
        end)
    end
    Settings.Performance.Targets = activeTargets
    if closestDist ~= 9999 then
        table.remove(Settings.History.Distance, 1)
        table.insert(Settings.History.Distance, math.floor(closestDist))
    end
end

local FOVCircle = nil
if DrawingEnabled then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 50
    FOVCircle.Radius = Settings.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Transparency = 0.5
    FOVCircle.Visible = false
end

local function GetClosestTarget()
    local closest, shortest, closestPart = nil, Settings.Aimbot.FOV, nil
    local mousePos = UserInputService:GetMouseLocation()

    for player, _ in pairs(ESP_Objects) do
        if player.Team == LocalPlayer.Team and Settings.ESP.TeamCheck then continue end
        
        local char = player.Character
        local part = char and (char:FindFirstChild(Settings.Aimbot.TargetPart) or char:FindFirstChild("HumanoidRootPart"))
        local hum = char and char:FindFirstChild("Humanoid")

        if part and hum and hum.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < shortest then
                    if Settings.Aimbot.WallCheck then
                        if LocalPlayer.Character then
                            raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
                        end
                        local result = workspace:Raycast(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000, raycastParams)
                        if result and result.Instance:IsDescendantOf(char) then
                            shortest = dist
                            closest = player
                            closestPart = part
                        end
                    else
                        shortest = dist
                        closest = player
                        closestPart = part
                    end
                end
            end
        end
    end
    return closest, closestPart
end

local function UpdateAimbot(dt)
    if FOVCircle then
        if Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled then
            FOVCircle.Position = UserInputService:GetMouseLocation()
            FOVCircle.Radius = Settings.Aimbot.FOV
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    end

    local isAiming = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)

    if Settings.Aimbot.Enabled and isAiming then
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local targetPos = targetPart.Position
            
            local vel = targetPart.AssemblyLinearVelocity or targetPart.Velocity
            targetPos = targetPos + vel * dt * 0.15
            
            local currentCF = Camera.CFrame
            local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
            
            local smoothFactor = 1 - math.exp(-Settings.Aimbot.Smoothness * dt)
            Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
        end
    end
end

local fpsCounter = 0
local lastFpsUpdate = tick()
RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    if tick() - lastFpsUpdate >= 1 then
        Settings.Performance.FPS = fpsCounter
        fpsCounter = 0
        lastFpsUpdate = tick()
    end
    
    pcall(function()
        UpdateESP(dt)
        UpdateAimbot(dt)
    end)
end)

task.spawn(function()
    while true do
        pcall(function()
            local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            Settings.Performance.Ping = math.floor(ping)
        end)
        task.wait(1)
    end
end)

local function InitPlayer(player)
    if player == LocalPlayer then return end
    task.spawn(function() CreateESP(player) end)
end

for _, p in ipairs(Players:GetPlayers()) do InitPlayer(p) end
Players.PlayerAdded:Connect(InitPlayer)

Players.PlayerRemoving:Connect(function(player)
    local data = ESP_Objects[player]
    if data then
        if data.Highlight then data.Highlight:Destroy() end
        if data.Billboard then data.Billboard:Destroy() end
        if data.Tracer and DrawingEnabled then data.Tracer:Remove() end
        for _, conn in pairs(data.Connections or {}) do
            if conn then conn:Disconnect() end
        end
        ESP_Objects[player] = nil
    end
end)

local HomeTab = Window:CreateTab("Combat", "crosshair")
local VisualsTab = Window:CreateTab("Visuals", "eye")
local StatsTab = Window:CreateTab("Performance", "activity")

HomeTab:CreateSection("Aimlock")

HomeTab:CreateToggle({
    Name = "Enable Aimlock",
    CurrentValue = Settings.Aimbot.Enabled,
    Flag = "AimbotEnabled",
    Callback = function(v) Settings.Aimbot.Enabled = v end,
})

HomeTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Settings.Aimbot.ShowFOV,
    Flag = "AimbotFOV",
    Callback = function(v) Settings.Aimbot.ShowFOV = v end,
})

HomeTab:CreateSlider({
    Name = "FOV Radius",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = Settings.Aimbot.FOV,
    Flag = "AimbotFOVRadius",
    Callback = function(v) Settings.Aimbot.FOV = v end,
})

HomeTab:CreateSlider({
    Name = "Smoothness (Snappy)",
    Range = {10, 100},
    Increment = 5,
    Suffix = "",
    CurrentValue = Settings.Aimbot.Smoothness,
    Flag = "AimbotSmooth",
    Callback = function(v) Settings.Aimbot.Smoothness = v end,
})

HomeTab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso"},
    CurrentOption = {Settings.Aimbot.TargetPart},
    Flag = "AimbotPart",
    Callback = function(selection) Settings.Aimbot.TargetPart = selection[1] or "Head" end,
})

HomeTab:CreateToggle({
    Name = "Wall Check (Raycast)",
    CurrentValue = Settings.Aimbot.WallCheck,
    Flag = "AimbotWallCheck",
    Callback = function(v) Settings.Aimbot.WallCheck = v end,
})

HomeTab:CreateButton({
    Name = "Activation Key",
    Icon = "mouse",
    Callback = function()
        Rayfield:Notify({
            Title = "Hardcoded",
            Content = "Hold Right Mouse Button (RMB) to lock on.",
            Duration = 4,
            Image = "mouse",
        })
    end,
})

VisualsTab:CreateSection("ESP Settings")

VisualsTab:CreateToggle({
    Name = "Master Toggle",
    CurrentValue = Settings.ESP.Enabled,
    Flag = "ESPEnabled",
    Callback = function(v) Settings.ESP.Enabled = v end,
})

VisualsTab:CreateToggle({
    Name = "Team Check (Enemy Only)",
    CurrentValue = Settings.ESP.TeamCheck,
    Flag = "ESPTeamCheck",
    Callback = function(v) Settings.ESP.TeamCheck = v end,
})

local ESPCols = VisualsTab:CreateColumns(2)
ESPCols:CreateToggle({ Name = "Boxes", CurrentValue = Settings.ESP.Boxes, Flag = "ESPBoxes", Callback = function(v) Settings.ESP.Boxes = v end })
ESPCols:CreateToggle({ Name = "Names", CurrentValue = Settings.ESP.Names, Flag = "ESPNames", Callback = function(v) Settings.ESP.Names = v end })
ESPCols:CreateToggle({ Name = "Health", CurrentValue = Settings.ESP.Health, Flag = "ESPHealth", Callback = function(v) Settings.ESP.Health = v end })
ESPCols:CreateToggle({ Name = "Distance", CurrentValue = Settings.ESP.Distance, Flag = "ESPDistance", Callback = function(v) Settings.ESP.Distance = v end })
VisualsTab:CreateToggle({
    Name = "Tracers",
    CurrentValue = Settings.ESP.Tracers,
    Flag = "ESPTracers",
    Callback = function(v) Settings.ESP.Tracers = v end,
})

VisualsTab:CreateDropdown({
    Name = "ESP Color",
    Options = {"Red", "Green", "Blue", "White"},
    CurrentOption = {Settings.ESP.Color},
    Flag = "ESPColor",
    Callback = function(selection) Settings.ESP.Color = selection[1] or "Red" end,
})

StatsTab:CreateSection("Live Feed")

local StatRow = StatsTab:CreateRow()
local PingStat = StatRow:CreateStat({ Name = "Ping", Icon = "wifi", Value = "0ms", Delta = "" })
local FPSStat = StatRow:CreateStat({ Name = "FPS", Icon = "zap", Value = "0", Delta = "" })
local TargStat = StatRow:CreateStat({ Name = "Targets", Icon = "users", Value = "0", Delta = "" })

StatsTab:CreateSection("Distance History")
local DistChart = StatsTab:CreateChart({
    Name = "Closest Target Distance",
    Icon = "ruler",
    Suffix = "m",
    Points = Settings.History.Distance,
})

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            PingStat:Set({Value = Settings.Performance.Ping .. "ms"})
            FPSStat:Set({Value = tostring(Settings.Performance.FPS)})
            TargStat:Set({Value = tostring(Settings.Performance.Targets)})
            DistChart:Push(Settings.History.Distance[#Settings.History.Distance] or 0)
        end)
    end
end)

Rayfield:Notify({
    Title = "Entrenched v3.0",
    Content = "Rayfield Gen2 loaded. Hold RMB to aimlock.",
    Duration = 5,
    Image = "crosshair",
})

Rayfield:LoadConfiguration()
