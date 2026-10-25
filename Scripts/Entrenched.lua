local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")

local workspace = workspace
local game = game
local math = math
local table = table
local task = task
local tick = tick
local os = os

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local GetMouseLocation = UserInputService.GetMouseLocation
local IsMouseButtonPressed = UserInputService.IsMouseButtonPressed
local WorldToViewportPoint = Camera.WorldToViewportPoint
local Raycast = workspace.Raycast

-- AGGRESSIVE PERFORMANCE KILLS (Deep Clean, No Shadows, Min Graphics)
task.spawn(function()
    Lighting.GlobalShadows = false
    Lighting.Technology = Enum.Technology.Voxel
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
    Lighting.Brightness = 1
    Lighting.ClockTime = 14
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    
    for _, v in ipairs(Lighting:GetChildren()) do
        if v.ClassName == "Sky" then 
            v:Destroy()
        elseif v:IsA("PostEffect") then 
            v.Enabled = false 
        end
    end

    local Terrain = workspace:FindFirstChild("Terrain")
    if Terrain then
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0
    end

    if workspace.StreamingEnabled == false then
        workspace.StreamingEnabled = true
    end

    pcall(function()
        local ugs = UserSettings():GetService("UserGameSettings")
        ugs.SavedQualityScale = 1
    end)

    local descendants = workspace:GetDescendants()
    for i = 1, #descendants do
        local v = descendants[i]
        local cn = v.ClassName
        if cn == "Part" or cn == "MeshPart" or cn == "UnionOperation" or cn == "WedgePart" or cn == "SpawnLocation" or cn == "TrussPart" or cn == "CornerWedgePart" then
            v.CastShadow = false
        elseif cn == "ParticleEmitter" or cn == "Trail" or cn == "Beam" or cn == "Fire" or cn == "Sparkles" or cn == "Smoke" then
            v.Enabled = false
        elseif cn == "Decal" or cn == "Texture" then
            v.Transparency = 1
        elseif cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight" then
            v.Enabled = false
        elseif cn == "Humanoid" then
            v.HealthDisplayDistance = 0
            v.NameDisplayDistance = 0
        end
        if i % 500 == 0 then task.wait() end
    end
    
    workspace.DescendantAdded:Connect(function(v)
        local cn = v.ClassName
        if cn == "Part" or cn == "MeshPart" or cn == "UnionOperation" or cn == "WedgePart" or cn == "SpawnLocation" or cn == "TrussPart" or cn == "CornerWedgePart" then
            v.CastShadow = false
        elseif cn == "ParticleEmitter" or cn == "Trail" or cn == "Beam" or cn == "Fire" or cn == "Sparkles" or cn == "Smoke" then
            v.Enabled = false
        elseif cn == "Decal" or cn == "Texture" then
            v.Transparency = 1
        elseif cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight" then
            v.Enabled = false
        elseif cn == "Humanoid" then
            v.HealthDisplayDistance = 0
            v.NameDisplayDistance = 0
        end
    end)
end)

local DrawingEnabled = pcall(function()
    local test = Drawing.new("Line")
    test:Remove()
end)

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Entrenched | Combat Suite",
    Subtitle = "v1.2 Rat-Optimized",
    Icon = "crosshair",
    Badge = {Text = "v1.2", Icon = "shield"},
    LoadingTitle = "Entrenched",
    LoadingSubtitle = "Combat Suite v1.2",
    ToggleUIKeybind = "RightControl",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Entrenched_Suite",
        FileName = "Config_v1_2",
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
local ESP_Array = {}

local SharedRaycastParams = RaycastParams.new()
SharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
SharedRaycastParams.IgnoreWater = true

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

    local data = {
        Highlight = highlight,
        Connections = {},
        Player = player
    }
    
    ESP_Objects[player] = data
    table.insert(ESP_Array, data)

    data.Connections.CharAdded = player.CharacterAdded:Connect(function(newChar)
        task.wait(0.5)
        if newChar and ESP_Objects[player] then
            ESP_Objects[player].Highlight.Adornee = newChar
            ESP_Objects[player].Highlight.Parent = newChar
        end
    end)
end

local lastESPUpdate = 0
local function UpdateESP()
    local activeTargets = 0
    local closestDistSq = 99990000
    local espEnabled = Settings.ESP.Enabled
    local teamCheck = Settings.ESP.TeamCheck
    local localTeam = LocalPlayer.Team
    local espColor = colorMap[Settings.ESP.Color] or colorMap.Red
    local fillTrans = Settings.ESP.FillTransparency
    local camPos = Camera.CFrame.Position

    for i = 1, #ESP_Array do
        local obj = ESP_Array[i]
        local player = obj.Player
        local char = player.Character
        
        if char then
            local hum = char:FindFirstChild("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")

            local isEnemy = true
            if teamCheck and player.Team == localTeam then
                isEnemy = false
            end

            local alive = hum and hum.Health > 0
            local visible = espEnabled and isEnemy and alive

            local hl = obj.Highlight
            if hl.Enabled ~= visible then hl.Enabled = visible end
            
            if visible then
                if hl.FillColor ~= espColor then hl.FillColor = espColor end
                if hl.OutlineColor ~= espColor then hl.OutlineColor = espColor end
                if hl.FillTransparency ~= fillTrans then hl.FillTransparency = fillTrans end
                
                activeTargets = activeTargets + 1
                if root then
                    local rp = root.Position
                    local dx = rp.X - camPos.X
                    local dy = rp.Y - camPos.Y
                    local dz = rp.Z - camPos.Z
                    local distSq = dx*dx + dy*dy + dz*dz
                    if distSq < closestDistSq then closestDistSq = distSq end
                end
            end
        end
    end

    Settings.Performance.Targets = activeTargets
    if closestDistSq ~= 99990000 then
        table.remove(Settings.History.Distance, 1)
        table.insert(Settings.History.Distance, math.floor(math.sqrt(closestDistSq)))
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

local IgnoreList = {}
local function CheckVisibility(origin, targetPos, targetChar)
    local dir = targetPos - origin
    table.clear(IgnoreList)
    IgnoreList[1] = LocalPlayer.Character
    IgnoreList[2] = Camera
    local count = 2

    SharedRaycastParams.FilterDescendantsInstances = IgnoreList

    while true do
        local result = Raycast(workspace, origin, dir, SharedRaycastParams)
        if not result then return true end
        if result.Instance:IsDescendantOf(targetChar) then return true end
        
        local inst = result.Instance
        local trans = inst.Transparency
        
        if trans >= 0.9 or (trans >= 0.5 and inst.Material == Enum.Material.Glass) or not inst.CanCollide then
            count = count + 1
            IgnoreList[count] = inst
            SharedRaycastParams.FilterDescendantsInstances = IgnoreList
        else
            return false
        end
    end
end

local function GetClosestTarget()
    local closest, shortestSq, closestPart = nil, Settings.Aimbot.FOV * Settings.Aimbot.FOV, nil
    local mousePos = GetMouseLocation(UserInputService)
    local camPos = Camera.CFrame.Position
    local localTeam = LocalPlayer.Team
    local teamCheck = Settings.ESP.TeamCheck
    local wallCheck = Settings.Aimbot.WallCheck
    local targetPartName = Settings.Aimbot.TargetPart

    for i = 1, #ESP_Array do
        local obj = ESP_Array[i]
        local player = obj.Player
        
        if not (teamCheck and player.Team == localTeam) then
            local char = player.Character
            if char then
                local part = char:FindFirstChild(targetPartName) or char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")

                if part and hum and hum.Health > 0 then
                    local rawDir = part.Position - camPos
                    if rawDir.Magnitude <= 1000 then 
                        local screenPos, onScreen = WorldToViewportPoint(Camera, part.Position)
                        if onScreen then
                            local dx = screenPos.X - mousePos.X
                            local dy = screenPos.Y - mousePos.Y
                            local distSq = dx*dx + dy*dy
                            if distSq < shortestSq then
                                if wallCheck then
                                    if CheckVisibility(camPos, part.Position, char) then
                                        shortestSq = distSq
                                        closest = player
                                        closestPart = part
                                    end
                                else
                                    shortestSq = distSq
                                    closest = player
                                    closestPart = part
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest, closestPart
end

local function UpdateAimbot(dt)
    if FOVCircle then
        local showFOV = Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled
        if FOVCircle.Visible ~= showFOV then FOVCircle.Visible = showFOV end
        if showFOV then
            FOVCircle.Position = GetMouseLocation(UserInputService)
            FOVCircle.Radius = Settings.Aimbot.FOV
        end
    end

    if Settings.Aimbot.Enabled and IsMouseButtonPressed(UserInputService, Enum.UserInputType.MouseButton2) then
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
local lastFpsUpdate = os.clock()

RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    local now = os.clock()
    if now - lastFpsUpdate >= 1 then
        Settings.Performance.FPS = fpsCounter
        fpsCounter = 0
        lastFpsUpdate = now
    end
    UpdateAimbot(dt)
end)

RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastESPUpdate >= 0.1 then
        UpdateESP()
        lastESPUpdate = now
    end
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
        
        for i = 1, #ESP_Array do
            if ESP_Array[i] == data then
                table.remove(ESP_Array, i)
                break
            end
        end
        
        ESP_Objects[player] = nil
    end
end)

local HomeTab = Window:CreateTab("Combat", "crosshair")
local VisualsTab = Window:CreateTab("Chams", "eye")
local StatsTab = Window:CreateTab("Performance", "activity")

HomeTab:CreateSection("Aimlock v1.2")

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
            Title = "v1.2 Hardwired",
            Content = "Hold Right Mouse Button (RMB) to lock on.",
            Duration = 4,
            Image = "mouse",
        })
    end,
})

VisualsTab:CreateSection("Chams v1.2")

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
        PingStat:Set({Value = Settings.Performance.Ping .. "ms"})
        FPSStat:Set({Value = tostring(Settings.Performance.FPS)})
        TargStat:Set({Value = tostring(Settings.Performance.Targets)})
        DistChart:Push(Settings.History.Distance[#Settings.History.Distance] or 0)
    end
end)

Rayfield:Notify({
    Title = "Entrenched v1.2",
    Content = "Bare Metal Optimization. Chams-only ESP. RMB to lock.",
    Duration = 5,
    Image = "crosshair",
})

Rayfield:LoadConfiguration()
