local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
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
    LoadingSubtitle = "by gucci4080",
    ToggleUIKeybind = "K",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Aetherist_Arsenal",
        FileName = "Config",
    },
})

-- =====================================================================
-- SETTINGS & STATE (EXPANDED)
-- =====================================================================
local Settings = {
    ESP = { 
        Enabled = false, Boxes = true, Names = true, Health = true, Distance = true, 
        Tracers = true, TeamCheck = false, Skeleton = false, HeadDots = false, 
        MaxDist = 1000, Color = Color3.fromRGB(119, 117, 242), Chams = false, 
        ItemESP = false, VehicleESP = false, TracerThickness = 1.5, NameSize = 14 
    },
    Aimbot = { 
        Enabled = false, Smoothness = 0.15, FOV = 200, Part = "Head", WallCheck = true, 
        Prediction = false, AutoFire = false, Key = Enum.UserInputType.MouseButton2,
        Triggerbot = false, SilentAim = false, HitChance = 100
    },
    Combat = { 
        Godmode = false, Invisible = false, AntiAFK = false, Hitbox = false, HitboxSize = 10, 
        Reach = false, ReachDist = 50, NoFall = false, RapidFire = false, FireRate = 20, 
        AutoReload = false, NoRecoil = false, InfiniteStamina = false, DamageMult = 1, KnockbackMult = 1
    },
    Movement = { 
        Speed = false, WS = 50, Jump = false, JP = 100, InfJump = false, Fly = false, 
        FlySpeed = 60, Noclip = false, Sprint = false, SprintBoost = 30, LongJump = false, 
        LJBoost = 50, HighJump = false, HJBoost = 100, Dodge = false, Step = false, 
        StepHeight = 10, AntiKB = false, SwimSpeed = false, SwimVal = 50, WallClimb = false, BunnyHop = false
    },
    Visuals = { 
        Fullbright = false, NoFog = false, Time = false, TimeVal = 14, FOV = false, 
        FOVVal = 90, Crosshair = false, CrosshairType = "Dot", Viewmodel = false, 
        VMOffset = 0, NoBob = false, XRay = false, ChromaESP = false, RemoveSky = false, RemoveWater = false
    },
    Teleports = { 
        Target = nil, FTP = false, CopyTP = false, SavedCoords = {}, AutoTP = false
    },
    Misc = { 
        AntiKick = false, AntiCrash = false, ServerHop = false, Rejoin = false, 
        CopyIP = false, ChatSpam = false, SpamMsg = "Aetherist", ServerLock = false, 
        FakeLag = false, LagMs = 500, AutoFarm = false, NameChanger = false, NewName = "gucci4080"
    }
}

-- =====================================================================
-- ESP SYSTEM (EXPANDED)
-- =====================================================================
local ESP_Objects = {}
local function CreateESP(p)
    if p == LocalPlayer then return end
    local hl = Instance.new("Highlight"); hl.Name = "Aeth_HL"; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = p
    local bb = Instance.new("BillboardGui"); bb.Name = "Aeth_BB"; bb.Size = UDim2.new(0,100,0,50); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = p
    local nl = Instance.new("TextLabel", bb); nl.Size = UDim2.new(1,0,0.4,0); nl.BackgroundTransparency = 1; nl.TextColor3 = Color3.new(1,1,1); nl.TextStrokeTransparency = 0; nl.Font = Enum.Font.GothamBold; nl.TextSize = Settings.ESP.NameSize
    local hpl = Instance.new("TextLabel", bb); hpl.Position = UDim2.new(0,0,0.4,0); hpl.Size = UDim2.new(1,0,0.3,0); hpl.BackgroundTransparency = 1; hpl.TextColor3 = Color3.new(0,1,0); hpl.TextStrokeTransparency = 0; hpl.Font = Enum.Font.Gotham; hpl.TextSize = 12
    local dl = Instance.new("TextLabel", bb); dl.Position = UDim2.new(0,0,0.7,0); dl.Size = UDim2.new(1,0,0.3,0); dl.BackgroundTransparency = 1; dl.TextColor3 = Color3.new(1,1,1); dl.TextStrokeTransparency = 0; dl.Font = Enum.Font.Gotham; dl.TextSize = 12
    local tr = Drawing.new("Line"); tr.Thickness = Settings.ESP.TracerThickness
    local sk = Drawing.new("Line"); sk.Thickness = 1.5; sk.Color = Settings.ESP.Color
    local hd = Drawing.new("Circle"); hd.Thickness = 1.5; hd.Filled = true; hd.Color = Settings.ESP.Color; hd.Radius = 4
    ESP_Objects[p] = {HL=hl, BB=bb, NL=nl, HPL=hpl, DL=dl, TR=tr, SK=sk, HD=hd}
end

local function UpdateESP()
    for p, o in pairs(ESP_Objects) do
        local c = p.Character; local r = c and c:FindFirstChild("HumanoidRootPart"); local h = c and c:FindFirstChild("Humanoid")
        local enemy = not Settings.ESP.TeamCheck or (p.Team ~= LocalPlayer.Team)
        local col = Settings.Visuals.ChromaESP and Color3.fromHSV(tick() % 5 / 5, 1, 1) or Settings.ESP.Color
        
        if not Settings.ESP.Enabled or not enemy or not r or not h or h.Health <= 0 or (r.Position - Camera.CFrame.Position).Magnitude > Settings.ESP.MaxDist then
            o.HL.Enabled = false; o.BB.Enabled = false; o.TR.Visible = false; o.SK.Visible = false; o.HD.Visible = false
        else
            local pos, on = Camera:WorldToViewportPoint(r.Position)
            o.HL.Enabled = Settings.ESP.Boxes or Settings.ESP.Chams; o.HL.FillColor = col; o.HL.OutlineColor = col
            o.BB.Enabled = Settings.ESP.Names or Settings.ESP.Health or Settings.ESP.Distance; o.BB.Adornee = r
            o.NL.Visible = Settings.ESP.Names; o.NL.Text = p.Name; o.NL.TextSize = Settings.ESP.NameSize
            o.HPL.Visible = Settings.ESP.Health; o.HPL.Text = math.floor(h.Health) .. " HP"; o.HPL.TextColor3 = Color3.fromRGB(255, math.floor(255*(h.Health/h.MaxHealth)), 0)
            o.DL.Visible = Settings.ESP.Distance; o.DL.Text = "[" .. math.floor((r.Position - Camera.CFrame.Position).Magnitude) .. "m]"
            
            if Settings.ESP.Tracers and on then 
                o.TR.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                o.TR.To = Vector2.new(pos.X, pos.Y)
                o.TR.Color = col; o.TR.Visible = true 
            else 
                o.TR.Visible = false 
            end
            
            if Settings.ESP.Skeleton and c then
                local head = c:FindFirstChild("Head"); local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
                if head and torso then
                    local p1, v1 = Camera:WorldToViewportPoint(head.Position); local p2, v2 = Camera:WorldToViewportPoint(torso.Position)
                    if v1 and v2 then o.SK.From = Vector2.new(p1.X, p1.Y); o.SK.To = Vector2.new(p2.X, p2.Y); o.SK.Visible = true else o.SK.Visible = false end
                else o.SK.Visible = false end
            else o.SK.Visible = false end

            if Settings.ESP.HeadDots and c:FindFirstChild("Head") then
                local hp, hv = Camera:WorldToViewportPoint(c.Head.Position)
                if hv then o.HD.Position = Vector2.new(hp.X, hp.Y); o.HD.Visible = true else o.HD.Visible = false end
            else o.HD.Visible = false end
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(function(p) 
    if ESP_Objects[p] then 
        for _, v in pairs(ESP_Objects[p]) do 
            if v.Destroy then v:Destroy() elseif v.Remove then v:Remove() end 
        end 
        ESP_Objects[p] = nil 
    end 
end)

-- =====================================================================
-- MAIN LOOPS
-- =====================================================================
local FlyBV, FlyBG
local OriginalWS = 16; local OriginalJP = 50
local OriginalSwim = 16

RunService.RenderStepped:Connect(function()
    UpdateESP()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); local r = c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end

    -- Movement
    h.WalkSpeed = Settings.Movement.Speed and Settings.Movement.WS or OriginalWS
    if Settings.Movement.Jump then h.UseJumpPower = true; h.JumpPower = Settings.Movement.JP else h.JumpPower = OriginalJP end
    
    if Settings.Movement.Fly then
        if not FlyBV then 
            FlyBV = Instance.new("BodyVelocity", r); FlyBV.MaxForce = Vector3.new(1e5,1e5,1e5)
            FlyBG = Instance.new("BodyGyro", r); FlyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); FlyBG.P = 1e4 
        end
        local md = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.new(0,1,0) end
        FlyBV.Velocity = md * Settings.Movement.FlySpeed; FlyBG.CFrame = Camera.CFrame
    elseif FlyBV then FlyBV:Destroy(); FlyBG:Destroy(); FlyBV = nil; FlyBG = nil end

    if Settings.Movement.Noclip then 
        for _, p in ipairs(c:GetDescendants()) do 
            if p:IsA("BasePart") then p.CanCollide = false end 
        end 
    end
    if Settings.Movement.Step then h.HipHeight = Settings.Movement.StepHeight else h.HipHeight = 0 end
    if Settings.Movement.SwimSpeed then h.WalkSpeed = Settings.Movement.SwimVal end

    -- Visuals
    if Settings.Visuals.Fullbright then Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2 else Lighting.Ambient = Color3.new(0,0,0); Lighting.Brightness = 1 end
    if Settings.Visuals.NoFog then Lighting.FogEnd = 100000 else Lighting.FogEnd = 1000 end
    if Settings.Visuals.Time then Lighting.ClockTime = Settings.Visuals.TimeVal end
    if Settings.Visuals.FOV then Camera.FieldOfView = Settings.Visuals.FOVVal else Camera.FieldOfView = 70 end
    if Settings.Visuals.RemoveSky then Lighting.Sky:Destroy() end
    if Settings.Visuals.XRay then 
        for _, p in ipairs(workspace:GetDescendants()) do 
            if p:IsA("BasePart") and not p:IsDescendantOf(c) and p.Transparency < 0.5 then 
                p.LocalTransparencyModifier = 0.5 
            end 
        end 
    end
end)

RunService.Heartbeat:Connect(function()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); local r = c:FindFirstChild("HumanoidRootPart")
    
    if Settings.Combat.Godmode and h then h.Health = h.MaxHealth end
    if Settings.Combat.Invisible then 
        for _, p in ipairs(c:GetDescendants()) do 
            if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 1 end 
        end 
    else 
        for _, p in ipairs(c:GetDescendants()) do 
            if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end 
        end 
    end
    if Settings.Combat.Hitbox and r then 
        r.Size = Vector3.new(Settings.Combat.HitboxSize, Settings.Combat.HitboxSize, Settings.Combat.HitboxSize)
        r.Transparency = 0.7 
    end
    if Settings.Combat.NoFall and h and h:GetState() == Enum.HumanoidStateType.Landed then 
        h:ChangeState(Enum.HumanoidStateType.Jumping) 
    end
    if Settings.Combat.AntiAFK then 
        fireclickdetector(game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui"):FindFirstChild("RobloxLoadingGui"):FindFirstChild("RobloxLogo"):FindFirstChild("ClickDetector")) 
    end
    if Settings.Combat.InfiniteStamina and h then h:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, true) end
end)

-- Aimbot & Triggerbot
local FOVCircle = Drawing.new("Circle"); FOVCircle.Thickness = 1; FOVCircle.NumSides = 50; FOVCircle.Filled = false; FOVCircle.Color = Color3.new(1,1,1); FOVCircle.Transparency = 0.5
RunService.RenderStepped:Connect(function()
    if Settings.Aimbot.Enabled or Settings.Aimbot.Triggerbot then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Settings.Aimbot.FOV
        FOVCircle.Visible = Settings.Aimbot.Enabled
        
        local closest, shortest = nil, Settings.Aimbot.FOV
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (not Settings.ESP.TeamCheck or p.Team ~= LocalPlayer.Team) then
                local c = p.Character; local part = c and c:FindFirstChild(Settings.Aimbot.Part); local hum = c and c:FindFirstChild("Humanoid")
                if part and hum and hum.Health > 0 then
                    local sp, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local dist = (Vector2.new(sp.X, sp.Y) - UserInputService:GetMouseLocation()).Magnitude
                        if dist < shortest then
                            if Settings.Aimbot.WallCheck then
                                local ray = Ray.new(Camera.CFrame.Position, (part.Position - Camera.CFrame.Position).Unit * 1000)
                                local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character)
                                if hit and hit:IsDescendantOf(c) then shortest = dist; closest = p end
                            else shortest = dist; closest = p end
                        end
                    end
                end
            end
        end
        
        if closest and closest.Character and closest.Character:FindFirstChild(Settings.Aimbot.Part) then
            local tp = closest.Character[Settings.Aimbot.Part].Position
            if Settings.Aimbot.Prediction then tp += closest.Character.HumanoidRootPart.Velocity * 0.1 end
            
            if Settings.Aimbot.Enabled and UserInputService:IsMouseButtonPressed(Settings.Aimbot.Key) then
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, tp), Settings.Aimbot.Smoothness)
            end
            
            if Settings.Aimbot.Triggerbot and Mouse.Target and Mouse.Target:IsDescendantOf(closest.Character) then
                -- Simulated click or game-specific trigger logic
                fireclickdetector(Mouse.Target)
            end
        end
    else 
        FOVCircle.Visible = false 
    end
end)

-- Input Hooks
UserInputService.JumpRequest:Connect(function() 
    if Settings.Movement.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) 
    end 
end)

UserInputService.InputBegan:Connect(function(input, gp) 
    if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftShift and Settings.Movement.Sprint and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
        LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.WS + Settings.Movement.SprintBoost 
    end
    if input.KeyCode == Enum.KeyCode.F and Settings.Teleports.FTP and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position)
        Rayfield:Notify({Title = "FTP Executed", Content = "Teleported to cursor.", Duration = 2})
    end
end)

UserInputService.InputEnded:Connect(function(input) 
    if input.KeyCode == Enum.KeyCode.LeftShift and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then 
        LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.WS 
    end 
end)

-- =====================================================================
-- UI CONSTRUCTION (RAYFIELD GEN2 EXPANDED)
-- =====================================================================
local Tabs = {
    ESP = Window:CreateTab("ESP", "eye"),
    Combat = Window:CreateTab("Combat", "crosshair"),
    Movement = Window:CreateTab("Movement", "running"),
    Visuals = Window:CreateTab("Visuals", "palette"),
    Teleports = Window:CreateTab("Teleports", "map-point"),
    Misc = Window:CreateTab("Misc", "settings")
}

-- ESP TAB
Tabs.ESP:CreateSection("Core ESP")
Tabs.ESP:CreateToggle({ Name = "Master Toggle", CurrentValue = Settings.ESP.Enabled, Flag = "ESP_Master", Callback = function(v) Settings.ESP.Enabled = v end })
Tabs.ESP:CreateToggle({ Name = "Boxes", CurrentValue = Settings.ESP.Boxes, Flag = "ESP_Boxes", Callback = function(v) Settings.ESP.Boxes = v end })
Tabs.ESP:CreateToggle({ Name = "Names", CurrentValue = Settings.ESP.Names, Flag = "ESP_Names", Callback = function(v) Settings.ESP.Names = v end })
Tabs.ESP:CreateToggle({ Name = "Health", CurrentValue = Settings.ESP.Health, Flag = "ESP_Health", Callback = function(v) Settings.ESP.Health = v end })
Tabs.ESP:CreateToggle({ Name = "Distance", CurrentValue = Settings.ESP.Distance, Flag = "ESP_Distance", Callback = function(v) Settings.ESP.Distance = v end })

Tabs.ESP:CreateSection("Advanced ESP")
Tabs.ESP:CreateToggle({ Name = "Tracers", CurrentValue = Settings.ESP.Tracers, Flag = "ESP_Tracers", Callback = function(v) Settings.ESP.Tracers = v end })
Tabs.ESP:CreateToggle({ Name = "Team Check", CurrentValue = Settings.ESP.TeamCheck, Flag = "ESP_TeamCheck", Callback = function(v) Settings.ESP.TeamCheck = v end })
Tabs.ESP:CreateToggle({ Name = "Skeleton", CurrentValue = Settings.ESP.Skeleton, Flag = "ESP_Skeleton", Callback = function(v) Settings.ESP.Skeleton = v end })
Tabs.ESP:CreateToggle({ Name = "Head Dots", CurrentValue = Settings.ESP.HeadDots, Flag = "ESP_HeadDots", Callback = function(v) Settings.ESP.HeadDots = v end })
Tabs.ESP:CreateToggle({ Name = "Chams", CurrentValue = Settings.ESP.Chams, Flag = "ESP_Chams", Callback = function(v) Settings.ESP.Chams = v end })
Tabs.ESP:CreateToggle({ Name = "Item ESP", CurrentValue = Settings.ESP.ItemESP, Flag = "ESP_Items", Callback = function(v) Settings.ESP.ItemESP = v end })
Tabs.ESP:CreateToggle({ Name = "Vehicle ESP", CurrentValue = Settings.ESP.VehicleESP, Flag = "ESP_Vehicles", Callback = function(v) Settings.ESP.VehicleESP = v end })
Tabs.ESP:CreateSlider({ Name = "Max Distance", Range = {100, 2000}, Increment = 50, CurrentValue = Settings.ESP.MaxDist, Flag = "ESP_MaxDist", Callback = function(v) Settings.ESP.MaxDist = v end })
Tabs.ESP:CreateSlider({ Name = "Tracer Thickness", Range = {1, 5}, Increment = 0.5, CurrentValue = Settings.ESP.TracerThickness, Flag = "ESP_TracerThick", Callback = function(v) Settings.ESP.TracerThickness = v end })
Tabs.ESP:CreateSlider({ Name = "Name Size", Range = {10, 24}, Increment = 1, CurrentValue = Settings.ESP.NameSize, Flag = "ESP_NameSize", Callback = function(v) Settings.ESP.NameSize = v end })
Tabs.ESP:CreateColorpicker({ Name = "ESP Color", CurrentValue = Settings.ESP.Color, Flag = "ESP_Color", Callback = function(v) Settings.ESP.Color = v end })
Tabs.ESP:CreateToggle({ Name = "Chroma ESP", CurrentValue = Settings.Visuals.ChromaESP, Flag = "ESP_Chroma", Callback = function(v) Settings.Visuals.ChromaESP = v end })

-- COMBAT TAB
Tabs.Combat:CreateSection("Aimbot & Trigger")
Tabs.Combat:CreateToggle({ Name = "Aimbot", CurrentValue = Settings.Aimbot.Enabled, Flag = "Aimbot_Enable", Callback = function(v) Settings.Aimbot.Enabled = v end })
Tabs.Combat:CreateToggle({ Name = "Triggerbot", CurrentValue = Settings.Aimbot.Triggerbot, Flag = "Aimbot_Trigger", Callback = function(v) Settings.Aimbot.Triggerbot = v end })
Tabs.Combat:CreateToggle({ Name = "Silent Aim", CurrentValue = Settings.Aimbot.SilentAim, Flag = "Aimbot_Silent", Callback = function(v) Settings.Aimbot.SilentAim = v end })
Tabs.Combat:CreateSlider({ Name = "Smoothness", Range = {0.05, 1}, Increment = 0.05, CurrentValue = Settings.Aimbot.Smoothness, Flag = "Aimbot_Smooth", Callback = function(v) Settings.Aimbot.Smoothness = v end })
Tabs.Combat:CreateSlider({ Name = "FOV", Range = {50, 500}, Increment = 10, CurrentValue = Settings.Aimbot.FOV, Flag = "Aimbot_FOV", Callback = function(v) Settings.Aimbot.FOV = v end })
Tabs.Combat:CreateSlider({ Name = "Hit Chance", Range = {0, 100}, Increment = 1, CurrentValue = Settings.Aimbot.HitChance, Flag = "Aimbot_Chance", Callback = function(v) Settings.Aimbot.HitChance = v end })
Tabs.Combat:CreateDropdown({ Name = "Target Part", Options = {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, CurrentOption = {"Head"}, Flag = "Aimbot_Part", Callback = function(v) Settings.Aimbot.Part = v[1] end })
Tabs.Combat:CreateToggle({ Name = "Wall Check", CurrentValue = Settings.Aimbot.WallCheck, Flag = "Aimbot_Wall", Callback = function(v) Settings.Aimbot.WallCheck = v end })
Tabs.Combat:CreateToggle({ Name = "Prediction", CurrentValue = Settings.Aimbot.Prediction, Flag = "Aimbot_Pred", Callback = function(v) Settings.Aimbot.Prediction = v end })
Tabs.Combat:CreateToggle({ Name = "Auto Fire", CurrentValue = Settings.Aimbot.AutoFire, Flag = "Aimbot_AutoFire", Callback = function(v) Settings.Aimbot.AutoFire = v end })

Tabs.Combat:CreateSection("Player Mods")
Tabs.Combat:CreateToggle({ Name = "Godmode", CurrentValue = Settings.Combat.Godmode, Flag = "Combat_God", Callback = function(v) Settings.Combat.Godmode = v end })
Tabs.Combat:CreateToggle({ Name = "Invisible", CurrentValue = Settings.Combat.Invisible, Flag = "Combat_Invis", Callback = function(v) Settings.Combat.Invisible = v end })
Tabs.Combat:CreateToggle({ Name = "Anti-AFK", CurrentValue = Settings.Combat.AntiAFK, Flag = "Combat_AFK", Callback = function(v) Settings.Combat.AntiAFK = v end })
Tabs.Combat:CreateToggle({ Name = "Hitbox Expander", CurrentValue = Settings.Combat.Hitbox, Flag = "Combat_Hitbox", Callback = function(v) Settings.Combat.Hitbox = v end })
Tabs.Combat:CreateSlider({ Name = "Hitbox Size", Range = {5, 20}, Increment = 1, CurrentValue = Settings.Combat.HitboxSize, Flag = "Combat_HitboxSize", Callback = function(v) Settings.Combat.HitboxSize = v end })
Tabs.Combat:CreateToggle({ Name = "Reach", CurrentValue = Settings.Combat.Reach, Flag = "Combat_Reach", Callback = function(v) Settings.Combat.Reach = v end })
Tabs.Combat:CreateSlider({ Name = "Reach Dist", Range = {10, 100}, Increment = 5, CurrentValue = Settings.Combat.ReachDist, Flag = "Combat_ReachDist", Callback = function(v) Settings.Combat.ReachDist = v end })
Tabs.Combat:CreateToggle({ Name = "No Fall Damage", CurrentValue = Settings.Combat.NoFall, Flag = "Combat_NoFall", Callback = function(v) Settings.Combat.NoFall = v end })
Tabs.Combat:CreateToggle({ Name = "Infinite Stamina", CurrentValue = Settings.Combat.InfiniteStamina, Flag = "Combat_Stamina", Callback = function(v) Settings.Combat.InfiniteStamina = v end })
Tabs.Combat:CreateSlider({ Name = "Damage Multiplier", Range = {1, 10}, Increment = 0.5, CurrentValue = Settings.Combat.DamageMult, Flag = "Combat_DmgMult", Callback = function(v) Settings.Combat.DamageMult = v end })
Tabs.Combat:CreateSlider({ Name = "Knockback Multiplier", Range = {1, 10}, Increment = 0.5, CurrentValue = Settings.Combat.KnockbackMult, Flag = "Combat_KBMult", Callback = function(v) Settings.Combat.KnockbackMult = v end })

-- MOVEMENT TAB
Tabs.Movement:CreateSection("Speed & Jump")
Tabs.Movement:CreateToggle({ Name = "WalkSpeed", CurrentValue = Settings.Movement.Speed, Flag = "Move_Speed", Callback = function(v) Settings.Movement.Speed = v end })
Tabs.Movement:CreateSlider({ Name = "WS Value", Range = {16, 250}, Increment = 1, CurrentValue = Settings.Movement.WS, Flag = "Move_WS", Callback = function(v) Settings.Movement.WS = v end })
Tabs.Movement:CreateToggle({ Name = "JumpPower", CurrentValue = Settings.Movement.Jump, Flag = "Move_Jump", Callback = function(v) Settings.Movement.Jump = v end })
Tabs.Movement:CreateSlider({ Name = "JP Value", Range = {50, 300}, Increment = 5, CurrentValue = Settings.Movement.JP, Flag = "Move_JP", Callback = function(v) Settings.Movement.JP = v end })
Tabs.Movement:CreateToggle({ Name = "Infinite Jump", CurrentValue = Settings.Movement.InfJump, Flag = "Move_InfJump", Callback = function(v) Settings.Movement.InfJump = v end })
Tabs.Movement:CreateToggle({ Name = "Bunny Hop", CurrentValue = Settings.Movement.BunnyHop, Flag = "Move_BHop", Callback = function(v) Settings.Movement.BunnyHop = v end })

Tabs.Movement:CreateSection("Flight & Physics")
Tabs.Movement:CreateToggle({ Name = "Fly", CurrentValue = Settings.Movement.Fly, Flag = "Move_Fly", Callback = function(v) Settings.Movement.Fly = v end })
Tabs.Movement:CreateSlider({ Name = "Fly Speed", Range = {10, 200}, Increment = 5, CurrentValue = Settings.Movement.FlySpeed, Flag = "Move_FlySpeed", Callback = function(v) Settings.Movement.FlySpeed = v end })
Tabs.Movement:CreateToggle({ Name = "Noclip", CurrentValue = Settings.Movement.Noclip, Flag = "Move_Noclip", Callback = function(v) Settings.Movement.Noclip = v end })
Tabs.Movement:CreateToggle({ Name = "Sprint", Description = "Hold Shift", CurrentValue = Settings.Movement.Sprint, Flag = "Move_Sprint", Callback = function(v) Settings.Movement.Sprint = v end })
Tabs.Movement:CreateSlider({ Name = "Sprint Boost", Range = {10, 100}, Increment = 5, CurrentValue = Settings.Movement.SprintBoost, Flag = "Move_SprintBoost", Callback = function(v) Settings.Movement.SprintBoost = v end })
Tabs.Movement:CreateToggle({ Name = "Long Jump", CurrentValue = Settings.Movement.LongJump, Flag = "Move_LongJump", Callback = function(v) Settings.Movement.LongJump = v end })
Tabs.Movement:CreateSlider({ Name = "LJ Boost", Range = {10, 150}, Increment = 5, CurrentValue = Settings.Movement.LJBoost, Flag = "Move_LJBoost", Callback = function(v) Settings.Movement.LJBoost = v end })
Tabs.Movement:CreateToggle({ Name = "High Jump", CurrentValue = Settings.Movement.HighJump, Flag = "Move_HighJump", Callback = function(v) Settings.Movement.HighJump = v end })
Tabs.Movement:CreateSlider({ Name = "HJ Boost", Range = {50, 300}, Increment = 10, CurrentValue = Settings.Movement.HJBoost, Flag = "Move_HJBoost", Callback = function(v) Settings.Movement.HJBoost = v end })
Tabs.Movement:CreateToggle({ Name = "Wall Climb", CurrentValue = Settings.Movement.WallClimb, Flag = "Move_WallClimb", Callback = function(v) Settings.Movement.WallClimb = v end })
Tabs.Movement:CreateToggle({ Name = "Swim Speed", CurrentValue = Settings.Movement.SwimSpeed, Flag = "Move_Swim", Callback = function(v) Settings.Movement.SwimSpeed = v end })
Tabs.Movement:CreateSlider({ Name = "Swim Value", Range = {16, 200}, Increment = 5, CurrentValue = Settings.Movement.SwimVal, Flag = "Move_SwimVal", Callback = function(v) Settings.Movement.SwimVal = v end })

-- VISUALS TAB
Tabs.Visuals:CreateSection("Environment")
Tabs.Visuals:CreateToggle({ Name = "Fullbright", CurrentValue = Settings.Visuals.Fullbright, Flag = "Vis_Fullbright", Callback = function(v) Settings.Visuals.Fullbright = v end })
Tabs.Visuals:CreateToggle({ Name = "No Fog", CurrentValue = Settings.Visuals.NoFog, Flag = "Vis_NoFog", Callback = function(v) Settings.Visuals.NoFog = v end })
Tabs.Visuals:CreateToggle({ Name = "Remove Sky", CurrentValue = Settings.Visuals.RemoveSky, Flag = "Vis_NoSky", Callback = function(v) Settings.Visuals.RemoveSky = v end })
Tabs.Visuals:CreateToggle({ Name = "Remove Water", CurrentValue = Settings.Visuals.RemoveWater, Flag = "Vis_NoWater", Callback = function(v) Settings.Visuals.RemoveWater = v end })
Tabs.Visuals:CreateToggle({ Name = "Time of Day", CurrentValue = Settings.Visuals.Time, Flag = "Vis_Time", Callback = function(v) Settings.Visuals.Time = v end })
Tabs.Visuals:CreateSlider({ Name = "Time Val", Range = {0, 24}, Increment = 1, CurrentValue = Settings.Visuals.TimeVal, Flag = "Vis_TimeVal", Callback = function(v) Settings.Visuals.TimeVal = v end })
Tabs.Visuals:CreateToggle({ Name = "FOV Changer", CurrentValue = Settings.Visuals.FOV, Flag = "Vis_FOV", Callback = function(v) Settings.Visuals.FOV = v end })
Tabs.Visuals:CreateSlider({ Name = "FOV Val", Range = {30, 120}, Increment = 5, CurrentValue = Settings.Visuals.FOVVal, Flag = "Vis_FOVVal", Callback = function(v) Settings.Visuals.FOVVal = v end })
Tabs.Visuals:CreateToggle({ Name = "X-Ray", CurrentValue = Settings.Visuals.XRay, Flag = "Vis_XRay", Callback = function(v) Settings.Visuals.XRay = v end })

Tabs.Visuals:CreateSection("HUD & Camera")
Tabs.Visuals:CreateToggle({ Name = "Custom Crosshair", CurrentValue = Settings.Visuals.Crosshair, Flag = "Vis_Crosshair", Callback = function(v) Settings.Visuals.Crosshair = v end })
Tabs.Visuals:CreateDropdown({ Name = "Crosshair Type", Options = {"Dot", "Circle", "Plus", "Cross"}, CurrentOption = {"Dot"}, Flag = "Vis_CrossType", Callback = function(v) Settings.Visuals.CrosshairType = v[1] end })
Tabs.Visuals:CreateToggle({ Name = "No Camera Bob", CurrentValue = Settings.Visuals.NoBob, Flag = "Vis_NoBob", Callback = function(v) Settings.Visuals.NoBob = v end })
Tabs.Visuals:CreateToggle({ Name = "Viewmodel Changer", CurrentValue = Settings.Visuals.Viewmodel, Flag = "Vis_VM", Callback = function(v) Settings.Visuals.Viewmodel = v end })
Tabs.Visuals:CreateSlider({ Name = "VM Offset", Range = {-5, 5}, Increment = 0.1, CurrentValue = Settings.Visuals.VMOffset, Flag = "Vis_VMOffset", Callback = function(v) Settings.Visuals.VMOffset = v end })

-- TELEPORTS TAB
Tabs.Teleports:CreateSection("Teleportation")
local playerList = {}
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(playerList, p.Name) end end
Tabs.Teleports:CreateDropdown({ Name = "TP to Player", Options = playerList, CurrentOption = {}, Flag = "TP_Player", Callback = function(v) 
    if v[1] then 
        local target = Players:FindFirstChild(v[1])
        if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then 
            LocalPlayer.Character.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,5) 
        end 
    end 
end})

Tabs.Teleports:CreateToggle({ Name = "FTP (Press F)", Description = "Teleport to cursor on F press", CurrentValue = Settings.Teleports.FTP, Flag = "TP_FTP", Callback = function(v) Settings.Teleports.FTP = v end })
Tabs.Teleports:CreateToggle({ Name = "Auto TP to Spawn", CurrentValue = Settings.Teleports.AutoTP, Flag = "TP_AutoSpawn", Callback = function(v) Settings.Teleports.AutoTP = v end })
Tabs.Teleports:CreateButton({ Name = "Save Current Coordinates", Callback = function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local pos = LocalPlayer.Character.HumanoidRootPart.Position
        Settings.Teleports.SavedCoords[#Settings.Teleports.SavedCoords + 1] = {X = pos.X, Y = pos.Y, Z = pos.Z}
        Rayfield:Notify({Title = "Coords Saved", Content = "Position saved to memory.", Duration = 3})
    end
end})
Tabs.Teleports:CreateButton({ Name = "Teleport to Last Saved", Callback = function()
    local coords = Settings.Teleports.SavedCoords[#Settings.Teleports.SavedCoords]
    if coords and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Vector3.new(coords.X, coords.Y, coords.Z))
        Rayfield:Notify({Title = "Teleported", Content = "Moved to saved coordinates.", Duration = 3})
    end
end})
Tabs.Teleports:CreateToggle({ Name = "Copy Teleport", CurrentValue = Settings.Teleports.CopyTP, Flag = "TP_Copy", Callback = function(v) Settings.Teleports.CopyTP = v end })

-- MISC TAB
Tabs.Misc:CreateSection("Server & Network")
Tabs.Misc:CreateToggle({ Name = "Anti-Kick", CurrentValue = Settings.Misc.AntiKick, Flag = "Misc_AntiKick", Callback = function(v) Settings.Misc.AntiKick = v end })
Tabs.Misc:CreateToggle({ Name = "Anti-Crash", CurrentValue = Settings.Misc.AntiCrash, Flag = "Misc_AntiCrash", Callback = function(v) Settings.Misc.AntiCrash = v end })
Tabs.Misc:CreateToggle({ Name = "Fake Lag", CurrentValue = Settings.Misc.FakeLag, Flag = "Misc_FakeLag", Callback = function(v) Settings.Misc.FakeLag = v end })
Tabs.Misc:CreateSlider({ Name = "Lag MS", Range = {100, 2000}, Increment = 50, CurrentValue = Settings.Misc.LagMs, Flag = "Misc_LagMs", Callback = function(v) Settings.Misc.LagMs = v end })
Tabs.Misc:CreateButton({ Name = "Server Hop", Callback = function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end })
Tabs.Misc:CreateButton({ Name = "Rejoin", Callback = function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end })
Tabs.Misc:CreateButton({ Name = "Copy JobID", Callback = function() setclipboard(game.JobId) Rayfield:Notify({Title = "Copied", Content = "Job ID copied.", Duration = 3}) end })
Tabs.Misc:CreateToggle({ Name = "Server Lock", CurrentValue = Settings.Misc.ServerLock, Flag = "Misc_ServerLock", Callback = function(v) Settings.Misc.ServerLock = v end })

Tabs.Misc:CreateSection("Automation & Fun")
Tabs.Misc:CreateToggle({ Name = "Auto Farm", CurrentValue = Settings.Misc.AutoFarm, Flag = "Misc_AutoFarm", Callback = function(v) Settings.Misc.AutoFarm = v end })
Tabs.Misc:CreateToggle({ Name = "Chat Spam", CurrentValue = Settings.Misc.ChatSpam, Flag = "Misc_ChatSpam", Callback = function(v) Settings.Misc.ChatSpam = v end })
Tabs.Misc:CreateInput({ Name = "Spam Message", CurrentValue = Settings.Misc.SpamMsg, Flag = "Misc_SpamMsg", Callback = function(v) Settings.Misc.SpamMsg = v end })
Tabs.Misc:CreateToggle({ Name = "Name Changer", CurrentValue = Settings.Misc.NameChanger, Flag = "Misc_NameChange", Callback = function(v) Settings.Misc.NameChanger = v end })
Tabs.Misc:CreateInput({ Name = "New Name", CurrentValue = Settings.Misc.NewName, Flag = "Misc_NewName", Callback = function(v) Settings.Misc.NewName = v end })

Rayfield:LoadConfiguration()
