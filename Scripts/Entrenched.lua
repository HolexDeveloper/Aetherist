local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local DrawingEnabled = pcall(function()
    local test = Drawing.new("Line")
    test:Remove()
end)

local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Entrenched | Combat Suite",
    Folder = "Entrenched_Suite",
    Icon = "solar:crosshair-bold-duotone",
    NewElements = true,
    OpenButton = {
        Title = "Open Suite",
        Color = ColorSequence.new(Color3.fromHex("#4a4a4a"), Color3.fromHex("#8b0000")),
    }
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
        Color = Color3.fromRGB(255, 0, 0)
    },
    Aimbot = {
        Enabled = false,
        FOV = 150,
        ShowFOV = true,
        Smoothness = 0.25,
        TargetPart = "Head",
        WallCheck = true,
        Keybind = Enum.UserInputType.MouseButton2
    }
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
        tracer.Color = Settings.ESP.Color
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
    for player, obj in pairs(ESP_Objects) do
        local success = pcall(function()
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

            local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
            local dist = (root.Position - Camera.CFrame.Position).Magnitude

            if obj.Highlight then
                obj.Highlight.Enabled = Settings.ESP.Boxes
                obj.Highlight.FillColor = Settings.ESP.Color
                obj.Highlight.OutlineColor = Settings.ESP.Color
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
                    obj.Tracer.Color = Settings.ESP.Color
                    obj.Tracer.Visible = true
                else
                    obj.Tracer.Visible = false
                end
            end
        end)
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

    local isAiming = false
    local kb = Settings.Aimbot.Keybind
    if typeof(kb) == "EnumItem" then
        if kb.EnumType == Enum.UserInputType then
            isAiming = UserInputService:IsMouseButtonPressed(kb)
        else
            isAiming = UserInputService:IsKeyDown(kb)
        end
    end

    if Settings.Aimbot.Enabled and isAiming then
        local target, targetPart = GetClosestTarget()
        if target and targetPart then
            local targetPos = targetPart.Position
            
            local vel = targetPart.AssemblyLinearVelocity or targetPart.Velocity
            targetPos = targetPos + vel * dt * 0.15
            
            local currentCF = Camera.CFrame
            local targetCF = CFrame.lookAt(currentCF.Position, targetPos)
            
            local smoothFactor = 1 - math.exp(-Settings.Aimbot.Smoothness * 30 * dt)
            Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
        end
    end
end

RunService.RenderStepped:Connect(function(dt)
    local success, err = pcall(function()
        UpdateESP(dt)
        UpdateAimbot(dt)
    end)
end)

local function InitPlayer(player)
    if player == LocalPlayer then return end
    task.spawn(function()
        CreateESP(player)
    end)
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

local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "solar:eye-bold" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "solar:crosshair-bold" })

local espSec = VisualsTab:Section({ Title = "ESP Settings" })
espSec:Toggle({ Title = "Master Toggle", Value = Settings.ESP.Enabled, Callback = function(v) Settings.ESP.Enabled = v end })
espSec:Toggle({ Title = "Team Check (Enemy Only)", Value = Settings.ESP.TeamCheck, Callback = function(v) Settings.ESP.TeamCheck = v end })
espSec:Toggle({ Title = "Boxes (Highlight)", Value = Settings.ESP.Boxes, Callback = function(v) Settings.ESP.Boxes = v end })
espSec:Toggle({ Title = "Names", Value = Settings.ESP.Names, Callback = function(v) Settings.ESP.Names = v end })
espSec:Toggle({ Title = "Health", Value = Settings.ESP.Health, Callback = function(v) Settings.ESP.Health = v end })
espSec:Toggle({ Title = "Distance", Value = Settings.ESP.Distance, Callback = function(v) Settings.ESP.Distance = v end })
espSec:Toggle({ Title = "Tracers", Value = Settings.ESP.Tracers, Callback = function(v) Settings.ESP.Tracers = v end })
espSec:Colorpicker({ Title = "ESP Color", Default = Settings.ESP.Color, Callback = function(v) Settings.ESP.Color = v end })

local aimSec = CombatTab:Section({ Title = "Aimlock" })
aimSec:Toggle({ Title = "Enable Aimlock", Value = Settings.Aimbot.Enabled, Callback = function(v) Settings.Aimbot.Enabled = v end })
aimSec:Toggle({ Title = "Show FOV Circle", Value = Settings.Aimbot.ShowFOV, Callback = function(v) Settings.Aimbot.ShowFOV = v end })
aimSec:Slider({ Title = "FOV Radius", Step = 10, Value = { Min = 50, Max = 500, Default = Settings.Aimbot.FOV }, Callback = function(v) Settings.Aimbot.FOV = v end })
aimSec:Slider({ Title = "Smoothness (Snappy)", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = Settings.Aimbot.Smoothness }, Callback = function(v) Settings.Aimbot.Smoothness = v end })
aimSec:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "UpperTorso" }, Value = Settings.Aimbot.TargetPart, Callback = function(v) Settings.Aimbot.TargetPart = v end })
aimSec:Toggle({ Title = "Wall Check (Raycast)", Value = Settings.Aimbot.WallCheck, Callback = function(v) Settings.Aimbot.WallCheck = v end })
aimSec:Keybind({ Title = "Activation Key", Default = Enum.UserInputType.MouseButton2, Callback = function(v) Settings.Aimbot.Keybind = v end })

Window:SetPanelBackground(true)
