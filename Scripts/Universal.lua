local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- =====================================================================
-- RAYFIELD GEN2 LOADER
-- =====================================================================
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Aetherist",
    Subtitle = ".gg/7JdQGwvfNu",
    Icon = "galaxy",
    LoadingTitle = "Aetherist",
    LoadingSubtitle = "by @thedude_whotalks3",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Aetherist_Arsenal",
        FileName = "Config",
    },
})

-- =====================================================================
-- SETTINGS (STRIPPED TO GUI FEATURES ONLY)
-- =====================================================================
local Settings = {
    ESP = {
        Enabled = false,
        Chams = false,
        Tracers = false,
        Names = false,
        Distance = false,
        DisplayName = false,
        MaxDist = 1000,
        Color = Color3.fromRGB(119, 117, 242),
        TracerThickness = 1.5,
        NameSize = 14
    },
    Aimbot = {
        Enabled = false,
        Smoothness = 0.15,
        FOV = 200,
        Part = "Head",
        WallCheck = true,
        Prediction = false,
        Key = Enum.UserInputType.MouseButton2,
        Triggerbot = false,
        HitChance = 100,
        FOVVisible = true,
        FOVColor = Color3.fromRGB(255, 255, 255)
    },
    Movement = {
        Speed = false,
        WS = 50,
        Jump = false,
        JP = 100,
        Fly = false,
        FlySpeed = 60,
        Noclip = false
    },
    Teleports = {
        FTP = false
    },
    Misc = {
        AntiKick = false
    }
}

-- =====================================================================
-- CACHED REFERENCES
-- =====================================================================
local CachedPlayers = {}
local CachedCharacters = {}
local CachedHumanoids = {}
local CachedRootParts = {}
local CachedHeads = {}

local function CachePlayer(p)
    if p == LocalPlayer then return end
    CachedPlayers[p] = true
    local function onChar(char)
        CachedCharacters[p] = char
        CachedHumanoids[p] = char:WaitForChild("Humanoid", 5)
        CachedRootParts[p] = char:WaitForChild("HumanoidRootPart", 5)
        CachedHeads[p] = char:WaitForChild("Head", 5)
    end
    if p.Character then onChar(p.Character) end
    p.CharacterAdded:Connect(onChar)
end

local function UncachePlayer(p)
    CachedPlayers[p] = nil
    CachedCharacters[p] = nil
    CachedHumanoids[p] = nil
    CachedRootParts[p] = nil
    CachedHeads[p] = nil
end

for _, p in ipairs(Players:GetPlayers()) do CachePlayer(p) end
Players.PlayerAdded:Connect(CachePlayer)
Players.PlayerRemoving:Connect(UncachePlayer)

-- =====================================================================
-- ESP SYSTEM (CHAMS, TRACERS, NAMES, DISTANCE, DISPLAYNAME)
-- =====================================================================
local ESP_Objects = {}

local function CreateESP(p)
    if p == LocalPlayer then return end
    
    local hl = Instance.new("Highlight")
    hl.Name = "Aeth_HL"
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = p.Character
    hl.Parent = game:GetService("CoreGui")
    
    local bb = Instance.new("BillboardGui")
    bb.Name = "Aeth_BB"
    bb.Size = UDim2.new(0, 150, 0, 60)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = game:GetService("CoreGui")
    
    local nl = Instance.new("TextLabel", bb)
    nl.Size = UDim2.new(1, 0, 0.5, 0)
    nl.BackgroundTransparency = 1
    nl.TextColor3 = Color3.new(1, 1, 1)
    nl.TextStrokeTransparency = 0
    nl.Font = Enum.Font.GothamBold
    nl.TextSize = Settings.ESP.NameSize
    
    local dl = Instance.new("TextLabel", bb)
    dl.Position = UDim2.new(0, 0, 0.5, 0)
    dl.Size = UDim2.new(1, 0, 0.5, 0)
    dl.BackgroundTransparency = 1
    dl.TextColor3 = Color3.new(1, 1, 1)
    dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.Gotham
    dl.TextSize = 12
    
    local tr = Drawing.new("Line")
    tr.Thickness = Settings.ESP.TracerThickness
    
    ESP_Objects[p] = {
        HL = hl,
        BB = bb,
        NL = nl,
        DL = dl,
        TR = tr
    }
end

local function UpdateESP()
    local camPos = Camera.CFrame.Position
    local viewportSize = Camera.ViewportSize
    
    for p, o in pairs(ESP_Objects) do
        local root = CachedRootParts[p]
        local hum = CachedHumanoids[p]
        
        if not Settings.ESP.Enabled or not root or not hum or hum.Health <= 0 or (root.Position - camPos).Magnitude > Settings.ESP.MaxDist then
            o.HL.Enabled = false
            o.BB.Enabled = false
            o.TR.Visible = false
        else
            local pos, on = Camera:WorldToViewportPoint(root.Position)
            local dist = (root.Position - camPos).Magnitude
            
            -- Chams
            o.HL.Enabled = Settings.ESP.Chams
            o.HL.FillColor = Settings.ESP.Color
            o.HL.OutlineColor = Settings.ESP.Color
            o.HL.FillTransparency = 0.7
            
            -- Billboard (Names + Distance + DisplayName)
            o.BB.Enabled = Settings.ESP.Names or Settings.ESP.Distance or Settings.ESP.DisplayName
            o.BB.Adornee = root
            
            -- Names / DisplayName
            o.NL.Visible = Settings.ESP.Names or Settings.ESP.DisplayName
            if Settings.ESP.DisplayName then
                o.NL.Text = p.DisplayName
            else
                o.NL.Text = p.Name
            end
            o.NL.TextSize = Settings.ESP.NameSize
            
            -- Distance
            o.DL.Visible = Settings.ESP.Distance
            o.DL.Text = "[" .. math.floor(dist) .. " studs]"
            
            -- Tracers
            if Settings.ESP.Tracers and on then
                o.TR.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                o.TR.To = Vector2.new(pos.X, pos.Y)
                o.TR.Color = Settings.ESP.Color
                o.TR.Visible = true
            else
                o.TR.Visible = false
            end
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(function(p)
    CachePlayer(p)
    CreateESP(p)
end)
Players.PlayerRemoving:Connect(function(p)
    if ESP_Objects[p] then
        for _, v in pairs(ESP_Objects[p]) do
            if v.Destroy then
                v:Destroy()
            elseif v.Remove then
                v:Remove()
            end
        end
        ESP_Objects[p] = nil
    end
    UncachePlayer(p)
end)

-- =====================================================================
-- MAIN RENDER LOOP (FIXED FLY + NOCLIP + WALKSPEED + JUMPPOWER)
-- =====================================================================
local FlyBV, FlyBG
local OriginalWS = 16
local OriginalJP = 50

RunService.RenderStepped:Connect(function()
    UpdateESP()
    
    local char = LocalPlayer.Character
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    -- WalkSpeed (FIXED)
    if Settings.Movement.Speed then
        hum.WalkSpeed = Settings.Movement.WS
    else
        hum.WalkSpeed = OriginalWS
    end
    
    -- JumpPower (FIXED)
    if Settings.Movement.Jump then
        hum.UseJumpPower = true
        hum.JumpPower = Settings.Movement.JP
    else
        hum.UseJumpPower = false
        hum.JumpPower = OriginalJP
    end
    
    -- Fly (FIXED: W=forward, S=backward, A=left, D=right)
    if Settings.Movement.Fly then
        if not FlyBV then
            FlyBV = Instance.new("BodyVelocity")
            FlyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            FlyBV.Velocity = Vector3.new(0, 0, 0)
            FlyBV.Parent = root
            
            FlyBG = Instance.new("BodyGyro")
            FlyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            FlyBG.P = 1e4
            FlyBG.CFrame = root.CFrame
            FlyBG.Parent = root
        end
        
        local moveDir = Vector3.new()
        
        -- W = Forward (camera look vector)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + Camera.CFrame.LookVector
        end
        
        -- S = Backward (opposite of camera look vector)
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - Camera.CFrame.LookVector
        end
        
        -- A = Left (opposite of camera right vector)
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - Camera.CFrame.RightVector
        end
        
        -- D = Right (camera right vector)
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + Camera.CFrame.RightVector
        end
        
        -- Space = Up
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        
        -- LeftControl = Down
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        
        -- Normalize and apply speed
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end
        
        FlyBV.Velocity = moveDir * Settings.Movement.FlySpeed
        FlyBG.CFrame = Camera.CFrame
    else
        if FlyBV then
            FlyBV:Destroy()
            FlyBV = nil
        end
        if FlyBG then
            FlyBG:Destroy()
            FlyBG = nil
        end
    end

    -- Noclip (FIXED: only runs when enabled, more efficient)
    if Settings.Movement.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
end)

-- =====================================================================
-- AIMBOT & TRIGGERBOT
-- =====================================================================
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.NumSides = 50
FOVCircle.Filled = false
FOVCircle.Color = Settings.Aimbot.FOVColor
FOVCircle.Transparency = 0.5

RunService.RenderStepped:Connect(function()
    if Settings.Aimbot.Enabled or Settings.Aimbot.Triggerbot then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Settings.Aimbot.FOV
        FOVCircle.Visible = Settings.Aimbot.FOVVisible and Settings.Aimbot.Enabled
        
        local closest, shortest = nil, Settings.Aimbot.FOV
        local camPos = Camera.CFrame.Position
        
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local char = CachedCharacters[p]
                local part = char and char:FindFirstChild(Settings.Aimbot.Part)
                local hum = CachedHumanoids[p]
                
                if part and hum and hum.Health > 0 then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local dist = (Vector2.new(sp.X, sp.Y) - mousePos).Magnitude
                        if dist < shortest then
                            if Settings.Aimbot.WallCheck then
                                local ray = Ray.new(camPos, (part.Position - camPos).Unit * 1000)
                                local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character)
                                if hit and hit:IsDescendantOf(char) then
                                    shortest = dist
                                    closest = p
                                end
                            else
                                shortest = dist
                                closest = p
                            end
                        end
                    end
                end
            end
        end
        
        if closest and CachedCharacters[closest] and CachedCharacters[closest]:FindFirstChild(Settings.Aimbot.Part) then
            local targetPart = CachedCharacters[closest][Settings.Aimbot.Part]
            local tp = targetPart.Position
            
            if Settings.Aimbot.Prediction then
                local targetRoot = CachedRootParts[closest]
                if targetRoot then
                    tp = tp + (targetRoot.Velocity * 0.1)
                end
            end
            
            if math.random(1, 100) <= Settings.Aimbot.HitChance then
                if Settings.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Settings.Aimbot.Key) then
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(camPos, tp), Settings.Aimbot.Smoothness)
                end
                
                if Settings.Aimbot.Triggerbot and Mouse.Target and Mouse.Target:IsDescendantOf(CachedCharacters[closest]) then
                    if fireclickdetector then
                        fireclickdetector(Mouse.Target)
                    end
                end
            end
        end
    else
        FOVCircle.Visible = false
    end
end)

-- =====================================================================
-- INPUT HOOKS (FTP ON F KEY)
-- =====================================================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    -- FTP (Press F)
    if input.KeyCode == Enum.KeyCode.F and Settings.Teleports.FTP then
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position)
            Rayfield:Notify({
                Title = "FTP Executed",
                Content = "Teleported to cursor.",
                Duration = 2
            })
        end
    end
end)

-- =====================================================================
-- LOCAL SCRIPT ANTI-KICK
-- =====================================================================
if Settings.Misc.AntiKick then
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" then
            return
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
end

-- =====================================================================
-- UI CONSTRUCTION (ONLY GUI FEATURES)
-- =====================================================================
local Tabs = {
    ESP = Window:CreateTab("ESP", "eye"),
    Combat = Window:CreateTab("Combat", "crosshair"),
    Movement = Window:CreateTab("Movement", "activity"),
    Teleports = Window:CreateTab("Teleports", "map-pin"),
    Misc = Window:CreateTab("Misc", "settings")
}

-- =====================================================================
-- ESP TAB (CHAMS, TRACERS, NAMES, DISTANCE, DISPLAYNAME)
-- =====================================================================
Tabs.ESP:CreateSection("ESP Settings")
Tabs.ESP:CreateToggle({
    Name = "Master Toggle",
    CurrentValue = Settings.ESP.Enabled,
    Flag = "ESP_Master",
    Callback = function(v)
        Settings.ESP.Enabled = v
    end
})

Tabs.ESP:CreateToggle({
    Name = "Chams",
    CurrentValue = Settings.ESP.Chams,
    Flag = "ESP_Chams",
    Callback = function(v)
        Settings.ESP.Chams = v
    end
})

Tabs.ESP:CreateToggle({
    Name = "Tracers",
    CurrentValue = Settings.ESP.Tracers,
    Flag = "ESP_Tracers",
    Callback = function(v)
        Settings.ESP.Tracers = v
    end
})

Tabs.ESP:CreateToggle({
    Name = "Names",
    CurrentValue = Settings.ESP.Names,
    Flag = "ESP_Names",
    Callback = function(v)
        Settings.ESP.Names = v
    end
})

Tabs.ESP:CreateToggle({
    Name = "Display Name",
    CurrentValue = Settings.ESP.DisplayName,
    Flag = "ESP_DisplayName",
    Callback = function(v)
        Settings.ESP.DisplayName = v
    end
})

Tabs.ESP:CreateToggle({
    Name = "Distance",
    CurrentValue = Settings.ESP.Distance,
    Flag = "ESP_Distance",
    Callback = function(v)
        Settings.ESP.Distance = v
    end
})

Tabs.ESP:CreateSlider({
    Name = "Max Distance",
    Range = {100, 5000},
    Increment = 50,
    CurrentValue = Settings.ESP.MaxDist,
    Flag = "ESP_MaxDist",
    Callback = function(v)
        Settings.ESP.MaxDist = v
    end
})

Tabs.ESP:CreateSlider({
    Name = "Tracer Thickness",
    Range = {1, 5},
    Increment = 0.5,
    CurrentValue = Settings.ESP.TracerThickness,
    Flag = "ESP_TracerThick",
    Callback = function(v)
        Settings.ESP.TracerThickness = v
    end
})

Tabs.ESP:CreateSlider({
    Name = "Name Size",
    Range = {10, 24},
    Increment = 1,
    CurrentValue = Settings.ESP.NameSize,
    Flag = "ESP_NameSize",
    Callback = function(v)
        Settings.ESP.NameSize = v
    end
})

Tabs.ESP:CreateColorPicker({
    Name = "ESP Color",
    Color = Settings.ESP.Color,
    Flag = "ESP_Color",
    Callback = function(v)
        Settings.ESP.Color = v
    end
})

-- =====================================================================
-- COMBAT TAB (AIMBOT + TRIGGERBOT)
-- =====================================================================
Tabs.Combat:CreateSection("Aimbot")
Tabs.Combat:CreateToggle({
    Name = "Aimbot",
    CurrentValue = Settings.Aimbot.Enabled,
    Flag = "Aimbot_Enable",
    Callback = function(v)
        Settings.Aimbot.Enabled = v
    end
})

Tabs.Combat:CreateToggle({
    Name = "Triggerbot",
    CurrentValue = Settings.Aimbot.Triggerbot,
    Flag = "Aimbot_Trigger",
    Callback = function(v)
        Settings.Aimbot.Triggerbot = v
    end
})

Tabs.Combat:CreateSlider({
    Name = "Smoothness",
    Range = {0.05, 1},
    Increment = 0.05,
    CurrentValue = Settings.Aimbot.Smoothness,
    Flag = "Aimbot_Smooth",
    Callback = function(v)
        Settings.Aimbot.Smoothness = v
    end
})

Tabs.Combat:CreateSlider({
    Name = "FOV",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = Settings.Aimbot.FOV,
    Flag = "Aimbot_FOV",
    Callback = function(v)
        Settings.Aimbot.FOV = v
    end
})

Tabs.Combat:CreateSlider({
    Name = "Hit Chance",
    Range = {0, 100},
    Increment = 1,
    CurrentValue = Settings.Aimbot.HitChance,
    Flag = "Aimbot_Chance",
    Callback = function(v)
        Settings.Aimbot.HitChance = v
    end
})

Tabs.Combat:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"},
    CurrentOption = {"Head"},
    Flag = "Aimbot_Part",
    Callback = function(v)
        Settings.Aimbot.Part = v[1]
    end
})

Tabs.Combat:CreateToggle({
    Name = "Wall Check",
    CurrentValue = Settings.Aimbot.WallCheck,
    Flag = "Aimbot_Wall",
    Callback = function(v)
        Settings.Aimbot.WallCheck = v
    end
})

Tabs.Combat:CreateToggle({
    Name = "Prediction",
    CurrentValue = Settings.Aimbot.Prediction,
    Flag = "Aimbot_Pred",
    Callback = function(v)
        Settings.Aimbot.Prediction = v
    end
})

Tabs.Combat:CreateToggle({
    Name = "FOV Visible",
    CurrentValue = Settings.Aimbot.FOVVisible,
    Flag = "Aimbot_FOVVis",
    Callback = function(v)
        Settings.Aimbot.FOVVisible = v
    end
})

Tabs.Combat:CreateColorPicker({
    Name = "FOV Color",
    Color = Settings.Aimbot.FOVColor,
    Flag = "Aimbot_FOVColor",
    Callback = function(v)
        Settings.Aimbot.FOVColor = v
    end
})

-- =====================================================================
-- MOVEMENT TAB (WALKSPEED, JUMPPOWER, FLY, NOCLIP)
-- =====================================================================
Tabs.Movement:CreateSection("Movement Settings")
Tabs.Movement:CreateToggle({
    Name = "WalkSpeed",
    CurrentValue = Settings.Movement.Speed,
    Flag = "Move_Speed",
    Callback = function(v)
        Settings.Movement.Speed = v
    end
})

Tabs.Movement:CreateSlider({
    Name = "WS Value",
    Range = {16, 500},
    Increment = 1,
    CurrentValue = Settings.Movement.WS,
    Flag = "Move_WS",
    Callback = function(v)
        Settings.Movement.WS = v
    end
})

Tabs.Movement:CreateToggle({
    Name = "JumpPower",
    CurrentValue = Settings.Movement.Jump,
    Flag = "Move_Jump",
    Callback = function(v)
        Settings.Movement.Jump = v
    end
})

Tabs.Movement:CreateSlider({
    Name = "JP Value",
    Range = {50, 500},
    Increment = 5,
    CurrentValue = Settings.Movement.JP,
    Flag = "Move_JP",
    Callback = function(v)
        Settings.Movement.JP = v
    end
})

Tabs.Movement:CreateToggle({
    Name = "Fly",
    CurrentValue = Settings.Movement.Fly,
    Flag = "Move_Fly",
    Callback = function(v)
        Settings.Movement.Fly = v
    end
})

Tabs.Movement:CreateSlider({
    Name = "Fly Speed",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = Settings.Movement.FlySpeed,
    Flag = "Move_FlySpeed",
    Callback = function(v)
        Settings.Movement.FlySpeed = v
    end
})

Tabs.Movement:CreateToggle({
    Name = "Noclip",
    CurrentValue = Settings.Movement.Noclip,
    Flag = "Move_Noclip",
    Callback = function(v)
        Settings.Movement.Noclip = v
    end
})

-- =====================================================================
-- TELEPORTS TAB (TP TO PLAYERS + FTP)
-- =====================================================================
Tabs.Teleports:CreateSection("Teleportation")
local playerList = {}
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(playerList, p.Name)
    end
end

Tabs.Teleports:CreateDropdown({
    Name = "TP to Player",
    Options = playerList,
    CurrentOption = {},
    Flag = "TP_Player",
    Callback = function(v)
        if v[1] then
            local target = Players:FindFirstChild(v[1])
            if target and CachedRootParts[target] then
                local myChar = LocalPlayer.Character
                if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                    myChar.HumanoidRootPart.CFrame = CachedRootParts[target].CFrame * CFrame.new(0, 0, 5)
                end
            end
        end
    end
})

Tabs.Teleports:CreateToggle({
    Name = "FTP (Press F)",
    Description = "Teleport to cursor on F press",
    CurrentValue = Settings.Teleports.FTP,
    Flag = "TP_FTP",
    Callback = function(v)
        Settings.Teleports.FTP = v
    end
})

-- =====================================================================
-- MISC TAB (LOCAL SCRIPT ANTI-KICK)
-- =====================================================================
Tabs.Misc:CreateSection("Protection")
Tabs.Misc:CreateToggle({
    Name = "Local Script Anti-Kick",
    CurrentValue = Settings.Misc.AntiKick,
    Flag = "Misc_AntiKick",
    Callback = function(v)
        Settings.Misc.AntiKick = v
        if v then
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" then
                    return
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
            Rayfield:Notify({
                Title = "Anti-Kick",
                Content = "Local script anti-kick enabled.",
                Duration = 3
            })
        end
    end
})

-- =====================================================================
-- FINALIZE
-- =====================================================================
Rayfield:LoadConfiguration()

Rayfield:Notify({
    Title = "Aetherist Loaded",
    Content = "Stripped build. Only the essentials. Press K to toggle UI.",
    Duration = 5,
    Image = "galaxy"
})
