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
    Subtitle = "v1.1 Rayfield Gen2",
    Icon = "crosshair",
    Badge = {Text = "v1.1", Icon = "shield"},
    LoadingTitle = "Entrenched",
    LoadingSubtitle = "Combat Suite v1.1",
    ToggleUIKeybind = "RightControl",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Entrenched_Suite",
        FileName = "Config_v1_1",
    },
})

local Settings = {
    ESP = {
        Enabled = true,
        TeamCheck = true,
        Color = "Red",
        FillTransparency = 0.5,
    },
    Aimbot = {
        Enabled = false,
        FOV = 150,
        ShowFOV = true,
        Smoothness = 30,
        TargetPart = "Head",
        WallCheck = true,
        Prediction = 0.165,
    },
    Performance = {
        Ping = 0,
        FPS = 0,
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
    if not char then return end

    local highlight = Instance.new("Highlight")
    highlight.Name = "Suite_HL"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = Settings.ESP.FillTransparency
    highlight.OutlineTransparency = 0
    highlight.Adornee = char
    highlight.Parent = char

    ESP_Objects[player] = {
        Highlight = highlight,
        Connections = {}
    }

    ESP_Objects[player].Connections.CharAdded = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if newChar and ESP_Objects[player] then
            ESP_Objects[player].Highlight.Adornee = newChar
            ESP_Objects[player].Highlight.Parent = newChar
        end
    end)
end

local function UpdateESP()
    local activeTargets = 0
    local closestDist = 9999

    for player, obj in pairs(ESP_Objects) do
        pcall(function()
            local char = player.Character
            local hum = char and char:FindFirstChild("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")

            local isEnemy = true
            if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then
                isEnemy = false
            end

            local alive = char and hum and hum.Health > 0
            local visible = Settings.ESP.Enabled and isEnemy and alive

            obj.Highlight.Enabled = visible
            if visible then
                local c = colorMap[Settings.ESP.Color] or Color3.fromRGB(255, 0, 0)
                obj.Highlight.FillColor = c
                obj.Highlight.OutlineColor = c
                obj.Highlight.FillTransparency = Settings.ESP.FillTransparency
                activeTargets = activeTargets + 1

                if root then
                    local dist = (root.Position - Camera.CFrame.Position).Magnitude
                    if dist < closestDist then closestDist = dist end
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
            targetPos = targetPos + vel * Settings.Aimbot.Prediction

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
        UpdateESP()
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
        for _, conn in pairs(data.Connections or {}) do
            if conn then conn:Disconnect() end
        end
        ESP_Objects[player] = nil
    end
end)

local HomeTab = Window:CreateTab("Combat", "crosshair")
local VisualsTab = Window:CreateTab("Chams", "eye")
local StatsTab = Window:CreateTab("Performance", "activity")

HomeTab:CreateSection("Aimlock v1.1")

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

HomeTab:CreateSlider({
    Name = "Prediction Factor",
    Range = {0, 500},
    Increment = 5,
    Suffix = "ms",
    CurrentValue = math.floor(Settings.Aimbot.Prediction * 1000),
    Flag = "AimbotPrediction",
    Callback = function(v) Settings.Aimbot.Prediction = v / 1000 end,
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
            Title = "v1.1 Hardwired",
            Content = "Hold Right Mouse Button (RMB) to lock on.",
            Duration = 4,
            Image = "mouse",
        })
    end,
})

VisualsTab:CreateSection("Chams v1.1")

VisualsTab:CreateToggle({
    Name = "Enable Chams",
    CurrentValue = Settings.ESP.Enabled,
    Flag = "ChamsEnabled",
    Callback = function(v) Settings.ESP.Enabled = v end,
})

VisualsTab:CreateToggle({
    Name = "Team Check (Enemy Only)",
    CurrentValue = Settings.ESP.TeamCheck,
    Flag = "ChamsTeamCheck",
    Callback = function(v) Settings.ESP.TeamCheck = v end,
})

VisualsTab:CreateSlider({
    Name = "Fill Transparency",
    Range = {0, 100},
    Increment = 5,
    Suffix = "%",
    CurrentValue = math.floor(Settings.ESP.FillTransparency * 100),
    Flag = "ChamsTransparency",
    Callback = function(v) Settings.ESP.FillTransparency = v / 100 end,
})

VisualsTab:CreateDropdown({
    Name = "Chams Color",
    Options = {"Red", "Green", "Blue", "White"},
    CurrentOption = {Settings.ESP.Color},
    Flag = "ChamsColor",
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
    Title = "Entrenched v1.1",
    Content = "Chams-only ESP loaded. RMB to lock.",
    Duration = 5,
    Image = "crosshair",
})

Rayfield:LoadConfiguration()
