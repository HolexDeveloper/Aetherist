local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- =====================================================================
-- WINDUI LOADER
-- =====================================================================
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

-- =====================================================================
-- SETTINGS
-- =====================================================================
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
        Smoothness = 0.2,
        TargetPart = "Head",
        WallCheck = true,
        Keybind = Enum.UserInputType.MouseButton2
    }
}

-- =====================================================================
-- ESP SYSTEM
-- =====================================================================
local ESP_Objects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    
    -- Highlight (Boxes/Chams)
    local highlight = Instance.new("Highlight")
    highlight.Name = "Suite_HL"
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = player
    
    -- Billboard (Names/Health/Distance)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Suite_BB"
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = player
    
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

    -- Tracer (Drawing API)
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Color = Settings.ESP.Color

    ESP_Objects[player] = {
        Highlight = highlight,
        Billboard = billboard,
        NameLabel = nameLabel,
        HealthLabel = healthLabel,
        DistLabel = distLabel,
        Tracer = tracer
    }
end

local function UpdateESP()
    for player, obj in pairs(ESP_Objects) do
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        -- Team Check Logic
        local isEnemy = true
        if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then
            isEnemy = false
        end

        if not Settings.ESP.Enabled or not isEnemy or not root or not hum or hum.Health <= 0 then
            obj.Highlight.Enabled = false
            obj.Billboard.Enabled = false
            obj.Tracer.Visible = false
            continue
        end

        local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
        local dist = (root.Position - Camera.CFrame.Position).Magnitude

        -- Highlight
        obj.Highlight.Enabled = Settings.ESP.Boxes
        obj.Highlight.FillColor = Settings.ESP.Color
        obj.Highlight.OutlineColor = Settings.ESP.Color

        -- Billboard
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

        -- Tracer
        if Settings.ESP.Tracers and onScreen then
            obj.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            obj.Tracer.To = Vector2.new(pos.X, pos.Y)
            obj.Tracer.Color = Settings.ESP.Color
            obj.Tracer.Visible = true
        else
            obj.Tracer.Visible = false
        end
    end
end

-- =====================================================================
-- AIMBOT SYSTEM
-- =====================================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 50
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Filled = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Transparency = 0.5
FOVCircle.Visible = false

local function GetClosestTarget()
    local closest, shortest = nil, Settings.Aimbot.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for player, _ in pairs(ESP_Objects) do
        if player.Team == LocalPlayer.Team and Settings.ESP.TeamCheck then continue end
        
        local char = player.Character
        local part = char and char:FindFirstChild(Settings.Aimbot.TargetPart)
        local hum = char and char:FindFirstChild("Humanoid")

        if part and hum and hum.Health > 0 then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if dist < shortest then
                    -- Wall Check
                    if Settings.Aimbot.WallCheck then
                        local ray = Ray.new(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000)
                        local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character)
                        if hit and hit:IsDescendantOf(char) then
                            shortest = dist
                            closest = player
                        end
                    else
                        shortest = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    UpdateESP()

    -- FOV Circle
    if Settings.Aimbot.ShowFOV and Settings.Aimbot.Enabled then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Settings.Aimbot.FOV
        FOVCircle.Visible = true
    else
        FOVCircle.Visible = false
    end

    -- Aimlock Logic
    if Settings.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Settings.Aimbot.Keybind) then
        local target = GetClosestTarget()
        if target and target.Character and target.Character:FindFirstChild(Settings.Aimbot.TargetPart) then
            local targetPos = target.Character[Settings.Aimbot.TargetPart].Position
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(currentCF.Position, targetPos)
            Camera.CFrame = currentCF:Lerp(targetCF, Settings.Aimbot.Smoothness)
        end
    end
end)

-- =====================================================================
-- INIT & CLEANUP
-- =====================================================================
local function InitPlayer(player)
    if player == LocalPlayer then return end
    CreateESP(player)
    
    player.CharacterAdded:Connect(function()
        task.wait(0.5) -- Wait for character load
        if ESP_Objects[player] then
            ESP_Objects[player].Highlight.Adornee = player.Character
            ESP_Objects[player].Billboard.Adornee = player.Character:FindFirstChild("HumanoidRootPart")
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do InitPlayer(p) end
Players.PlayerAdded:Connect(InitPlayer)

Players.PlayerRemoving:Connect(function(player)
    if ESP_Objects[player] then
        ESP_Objects[player].Highlight:Destroy()
        ESP_Objects[player].Billboard:Destroy()
        ESP_Objects[player].Tracer:Remove()
        ESP_Objects[player] = nil
    end
end)

-- =====================================================================
-- UI CONSTRUCTION
-- =====================================================================
local VisualsTab = Window:Tab({ Title = "Visuals", Icon = "solar:eye-bold" })
local CombatTab = Window:Tab({ Title = "Combat", Icon = "solar:crosshair-bold" })

-- Visuals Tab
local espSec = VisualsTab:Section({ Title = "ESP Settings" })
espSec:Toggle({ Title = "Master Toggle", Value = Settings.ESP.Enabled, Callback = function(v) Settings.ESP.Enabled = v end })
espSec:Toggle({ Title = "Team Check (Enemy Only)", Value = Settings.ESP.TeamCheck, Callback = function(v) Settings.ESP.TeamCheck = v end })
espSec:Toggle({ Title = "Boxes (Highlight)", Value = Settings.ESP.Boxes, Callback = function(v) Settings.ESP.Boxes = v end })
espSec:Toggle({ Title = "Names", Value = Settings.ESP.Names, Callback = function(v) Settings.ESP.Names = v end })
espSec:Toggle({ Title = "Health", Value = Settings.ESP.Health, Callback = function(v) Settings.ESP.Health = v end })
espSec:Toggle({ Title = "Distance", Value = Settings.ESP.Distance, Callback = function(v) Settings.ESP.Distance = v end })
espSec:Toggle({ Title = "Tracers", Value = Settings.ESP.Tracers, Callback = function(v) Settings.ESP.Tracers = v end })
espSec:Colorpicker({ Title = "ESP Color", Default = Settings.ESP.Color, Callback = function(v) Settings.ESP.Color = v end })

-- Combat Tab
local aimSec = CombatTab:Section({ Title = "Aimlock" })
aimSec:Toggle({ Title = "Enable Aimlock", Value = Settings.Aimbot.Enabled, Callback = function(v) Settings.Aimbot.Enabled = v end })
aimSec:Toggle({ Title = "Show FOV Circle", Value = Settings.Aimbot.ShowFOV, Callback = function(v) Settings.Aimbot.ShowFOV = v end })
aimSec:Slider({ Title = "FOV Radius", Step = 10, Value = { Min = 50, Max = 500, Default = Settings.Aimbot.FOV }, Callback = function(v) Settings.Aimbot.FOV = v end })
aimSec:Slider({ Title = "Smoothness", Step = 0.05, Value = { Min = 0.05, Max = 1, Default = Settings.Aimbot.Smoothness }, Callback = function(v) Settings.Aimbot.Smoothness = v end })
aimSec:Dropdown({ Title = "Target Part", Values = { "Head", "HumanoidRootPart", "UpperTorso" }, Value = Settings.Aimbot.TargetPart, Callback = function(v) Settings.Aimbot.TargetPart = v end })
aimSec:Toggle({ Title = "Wall Check (Raycast)", Value = Settings.Aimbot.WallCheck, Callback = function(v) Settings.Aimbot.WallCheck = v end })
aimSec:Keybind({ Title = "Activation Key", Value = "MouseButton2", Callback = function(v) 
    -- Map string back to Enum if needed, or handle directly
    if v == "MouseButton2" then Settings.Aimbot.Keybind = Enum.UserInputType.MouseButton2 
    else Settings.Aimbot.Keybind = Enum.KeyCode[v] end
end })

Window:SetPanelBackground(true)
