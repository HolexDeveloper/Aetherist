
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- =====================================================================
-- WINDUI LOADER
-- =====================================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Aetherist | .gg/7JdQGwvfNu",
    Folder = "Aetherist_Arsenal",
    Icon = "solar:galaxy-bold-duotone",
    NewElements = true,
    OpenButton = {
        Title = "Open Aetherist",
        Color = ColorSequence.new(Color3.fromHex("#7775F2"), Color3.fromHex("#257AF7")),
    }
})

-- =====================================================================
-- SETTINGS (57 FEATURES)
-- =====================================================================
local Settings = {
    ESP = { Enabled = false, Boxes = true, Names = true, Health = true, Distance = true, Tracers = true, TeamCheck = false, Skeleton = false, HeadDots = false, MaxDist = 1000, Color = Color3.fromRGB(119, 117, 242) },
    Aimbot = { Enabled = false, Smoothness = 0.15, FOV = 200, Part = "Head", WallCheck = true, Prediction = false, AutoFire = false, Key = Enum.UserInputType.MouseButton2 },
    Combat = { Godmode = false, Invisible = false, AntiAFK = false, Hitbox = false, HitboxSize = 10, Reach = false, ReachDist = 50, NoFall = false, RapidFire = false, FireRate = 20, AutoReload = false },
    Movement = { Speed = false, WS = 50, Jump = false, JP = 100, InfJump = false, Fly = false, FlySpeed = 60, Noclip = false, Sprint = false, SprintBoost = 30, LongJump = false, LJBoost = 50, HighJump = false, HJBoost = 100, Dodge = false, Step = false, StepHeight = 10, AntiKB = false },
    Visuals = { Fullbright = false, NoFog = false, Time = false, TimeVal = 14, FOV = false, FOVVal = 90, Crosshair = false, Viewmodel = false, VMOffset = 0, NoBob = false, XRay = false },
    Teleports = { Target = nil, TPCursor = false, CopyTP = false },
    Misc = { AntiKick = false, AntiCrash = false, ServerHop = false, Rejoin = false, CopyIP = false, ChatSpam = false, SpamMsg = "Aetherist", ServerLock = false }
}

-- =====================================================================
-- UI HELPERS
-- =====================================================================
local function T(parent, title, desc, val, cb) parent:Toggle({Title = title, Desc = desc, Value = val, Callback = cb or function() end}) end
local function S(parent, title, desc, min, max, def, step, cb) parent:Slider({Title = title, Desc = desc, Min = min, Max = max, Default = def, Step = step, Callback = cb or function() end}) end
local function D(parent, title, desc, vals, def, cb) parent:Dropdown({Title = title, Desc = desc, Values = vals, Value = def, Callback = cb or function() end}) end
local function B(parent, title, cb) parent:Button({Title = title, Callback = cb or function() end}) end
local function C(parent, title, def, cb) parent:Colorpicker({Title = title, Default = def, Callback = cb or function() end}) end
local function I(parent, title, def, cb) parent:Input({Title = title, Value = def, Callback = cb or function() end}) end

-- =====================================================================
-- ESP SYSTEM
-- =====================================================================
local ESP_Objects = {}
local function CreateESP(p)
    if p == LocalPlayer then return end
    local hl = Instance.new("Highlight"); hl.Name = "Aeth_HL"; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = p
    local bb = Instance.new("BillboardGui"); bb.Name = "Aeth_BB"; bb.Size = UDim2.new(0,100,0,50); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = p
    local nl = Instance.new("TextLabel", bb); nl.Size = UDim2.new(1,0,0.4,0); nl.BackgroundTransparency = 1; nl.TextColor3 = Color3.new(1,1,1); nl.TextStrokeTransparency = 0; nl.Font = Enum.Font.GothamBold; nl.TextSize = 14
    local hpl = Instance.new("TextLabel", bb); hpl.Position = UDim2.new(0,0,0.4,0); hpl.Size = UDim2.new(1,0,0.3,0); hpl.BackgroundTransparency = 1; hpl.TextColor3 = Color3.new(0,1,0); hpl.TextStrokeTransparency = 0; hpl.Font = Enum.Font.Gotham; hpl.TextSize = 12
    local dl = Instance.new("TextLabel", bb); dl.Position = UDim2.new(0,0,0.7,0); dl.Size = UDim2.new(1,0,0.3,0); dl.BackgroundTransparency = 1; dl.TextColor3 = Color3.new(1,1,1); dl.TextStrokeTransparency = 0; dl.Font = Enum.Font.Gotham; dl.TextSize = 12
    local tr = Drawing.new("Line"); tr.Thickness = 1.5
    local sk = Drawing.new("Line"); sk.Thickness = 1.5; sk.Color = Settings.ESP.Color
    local hd = Drawing.new("Circle"); hd.Thickness = 1.5; hd.Filled = true; hd.Color = Settings.ESP.Color; hd.Radius = 4
    ESP_Objects[p] = {HL=hl, BB=bb, NL=nl, HPL=hpl, DL=dl, TR=tr, SK=sk, HD=hd}
end

local function UpdateESP()
    for p, o in pairs(ESP_Objects) do
        local c = p.Character; local r = c and c:FindFirstChild("HumanoidRootPart"); local h = c and c:FindFirstChild("Humanoid")
        local enemy = not Settings.ESP.TeamCheck or (p.Team ~= LocalPlayer.Team)
        if not Settings.ESP.Enabled or not enemy or not r or not h or h.Health <= 0 or (r.Position - Camera.CFrame.Position).Magnitude > Settings.ESP.MaxDist then
            o.HL.Enabled = false; o.BB.Enabled = false; o.TR.Visible = false; o.SK.Visible = false; o.HD.Visible = false
        else
            local pos, on = Camera:WorldToViewportPoint(r.Position)
            o.HL.Enabled = Settings.ESP.Boxes; o.HL.FillColor = Settings.ESP.Color; o.HL.OutlineColor = Settings.ESP.Color
            o.BB.Enabled = Settings.ESP.Names or Settings.ESP.Health or Settings.ESP.Distance; o.BB.Adornee = r
            o.NL.Visible = Settings.ESP.Names; o.NL.Text = p.Name
            o.HPL.Visible = Settings.ESP.Health; o.HPL.Text = math.floor(h.Health) .. " HP"; o.HPL.TextColor3 = Color3.fromRGB(255, math.floor(255*(h.Health/h.MaxHealth)), 0)
            o.DL.Visible = Settings.ESP.Distance; o.DL.Text = "[" .. math.floor((r.Position - Camera.CFrame.Position).Magnitude) .. "m]"
            if Settings.ESP.Tracers and on then o.TR.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y); o.TR.To = Vector2.new(pos.X, pos.Y); o.TR.Color = Settings.ESP.Color; o.TR.Visible = true else o.TR.Visible = false end
            
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
Players.PlayerRemoving:Connect(function(p) if ESP_Objects[p] then for _, v in pairs(ESP_Objects[p]) do if v.Destroy then v:Destroy() elseif v.Remove then v:Remove() end end ESP_Objects[p] = nil end end)

-- =====================================================================
-- MAIN LOOPS
-- =====================================================================
local FlyBV, FlyBG
local OriginalWS = 16; local OriginalJP = 50

RunService.RenderStepped:Connect(function()
    UpdateESP()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); local r = c:FindFirstChild("HumanoidRootPart")
    if not h or not r then return end

    -- Movement
    h.WalkSpeed = Settings.Movement.Speed and Settings.Movement.WS or OriginalWS
    if Settings.Movement.Jump then h.UseJumpPower = true; h.JumpPower = Settings.Movement.JP else h.JumpPower = OriginalJP end
    if Settings.Movement.Fly then
        if not FlyBV then FlyBV = Instance.new("BodyVelocity", r); FlyBV.MaxForce = Vector3.new(1e5,1e5,1e5); FlyBG = Instance.new("BodyGyro", r); FlyBG.MaxTorque = Vector3.new(1e5,1e5,1e5); FlyBG.P = 1e4 end
        local md = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then md -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then md += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then md -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then md += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then md += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then md -= Vector3.new(0,1,0) end
        FlyBV.Velocity = md * Settings.Movement.FlySpeed; FlyBG.CFrame = Camera.CFrame
    elseif FlyBV then FlyBV:Destroy(); FlyBG:Destroy(); FlyBV = nil; FlyBG = nil end

    if Settings.Movement.Noclip then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
    if Settings.Movement.Step then h.HipHeight = Settings.Movement.StepHeight else h.HipHeight = 0 end

    -- Visuals
    if Settings.Visuals.Fullbright then Lighting.Ambient = Color3.new(1,1,1); Lighting.Brightness = 2 else Lighting.Ambient = Color3.new(0,0,0); Lighting.Brightness = 1 end
    if Settings.Visuals.NoFog then Lighting.FogEnd = 100000 else Lighting.FogEnd = 1000 end
    if Settings.Visuals.Time then Lighting.ClockTime = Settings.Visuals.TimeVal end
    if Settings.Visuals.FOV then Camera.FieldOfView = Settings.Visuals.FOVVal else Camera.FieldOfView = 70 end
    if Settings.Visuals.XRay then for _, p in ipairs(workspace:GetDescendants()) do if p:IsA("BasePart") and not p:IsDescendantOf(c) and p.Transparency < 0.5 then p.LocalTransparencyModifier = 0.5 end end end
end)

RunService.Heartbeat:Connect(function()
    local c = LocalPlayer.Character; if not c then return end
    local h = c:FindFirstChild("Humanoid"); local r = c:FindFirstChild("HumanoidRootPart")
    
    -- Combat
    if Settings.Combat.Godmode and h then h.Health = h.MaxHealth end
    if Settings.Combat.Invisible then for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 1 end end else for _, p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = 0 end end end
    if Settings.Combat.Hitbox and r then r.Size = Vector3.new(Settings.Combat.HitboxSize, Settings.Combat.HitboxSize, Settings.Combat.HitboxSize); r.Transparency = 0.7 end
    if Settings.Combat.NoFall and h and h:GetState() == Enum.HumanoidStateType.Landed then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    if Settings.Combat.AntiAFK then fireclickdetector(game:GetService("CoreGui"):FindFirstChild("RobloxPromptGui"):FindFirstChild("RobloxLoadingGui"):FindFirstChild("RobloxLogo"):FindFirstChild("ClickDetector")) end
end)

-- Aimbot
local FOVCircle = Drawing.new("Circle"); FOVCircle.Thickness = 1; FOVCircle.NumSides = 50; FOVCircle.Filled = false; FOVCircle.Color = Color3.new(1,1,1); FOVCircle.Transparency = 0.5
RunService.RenderStepped:Connect(function()
    if Settings.Aimbot.Enabled then
        FOVCircle.Position = UserInputService:GetMouseLocation(); FOVCircle.Radius = Settings.Aimbot.FOV; FOVCircle.Visible = true
        if UserInputService:IsMouseButtonPressed(Settings.Aimbot.Key) then
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
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, tp), Settings.Aimbot.Smoothness)
            end
        end
    else FOVCircle.Visible = false end
end)

-- Input Hooks
UserInputService.JumpRequest:Connect(function() if Settings.Movement.InfJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end end)
UserInputService.InputBegan:Connect(function(input, gp) if gp then return end
    if input.KeyCode == Enum.KeyCode.LeftShift and Settings.Movement.Sprint and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.WS + Settings.Movement.SprintBoost end
end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == Enum.KeyCode.LeftShift and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = Settings.Movement.WS end end)

-- =====================================================================
-- UI CONSTRUCTION
-- =====================================================================
local Tabs = {
    ESP = Window:Tab({Title = "ESP", Icon = "solar:eye-bold"}),
    Combat = Window:Tab({Title = "Combat", Icon = "solar:crosshair-bold"}),
    Movement = Window:Tab({Title = "Movement", Icon = "solar:running-bold"}),
    Visuals = Window:Tab({Title = "Visuals", Icon = "solar:palette-bold"}),
    Teleports = Window:Tab({Title = "Teleports", Icon = "solar:map-point-bold"}),
    Misc = Window:Tab({Title = "Misc", Icon = "solar:settings-bold"})
}

-- ESP (10)
local e1 = Tabs.ESP:Section({Title = "Core ESP"})
T(e1, "1. Master Toggle", "", Settings.ESP.Enabled, function(v) Settings.ESP.Enabled = v end)
T(e1, "2. Boxes", "", Settings.ESP.Boxes, function(v) Settings.ESP.Boxes = v end)
T(e1, "3. Names", "", Settings.ESP.Names, function(v) Settings.ESP.Names = v end)
T(e1, "4. Health", "", Settings.ESP.Health, function(v) Settings.ESP.Health = v end)
T(e1, "5. Distance", "", Settings.ESP.Distance, function(v) Settings.ESP.Distance = v end)
local e2 = Tabs.ESP:Section({Title = "Advanced ESP"})
T(e2, "6. Tracers", "", Settings.ESP.Tracers, function(v) Settings.ESP.Tracers = v end)
T(e2, "7. Team Check", "", Settings.ESP.TeamCheck, function(v) Settings.ESP.TeamCheck = v end)
T(e2, "8. Skeleton", "", Settings.ESP.Skeleton, function(v) Settings.ESP.Skeleton = v end)
T(e2, "9. Head Dots", "", Settings.ESP.HeadDots, function(v) Settings.ESP.HeadDots = v end)
S(e2, "10. Max Distance", "", 100, 2000, Settings.ESP.MaxDist, 50, function(v) Settings.ESP.MaxDist = v end)
C(e2, "ESP Color", Settings.ESP.Color, function(v) Settings.ESP.Color = v end)

-- Combat (15)
local c1 = Tabs.Combat:Section({Title = "Aimbot"})
T(c1, "11. Aimbot", "", Settings.Aimbot.Enabled, function(v) Settings.Aimbot.Enabled = v end)
S(c1, "12. Smoothness", "", 0.05, 1, Settings.Aimbot.Smoothness, 0.05, function(v) Settings.Aimbot.Smoothness = v end)
S(c1, "13. FOV", "", 50, 500, Settings.Aimbot.FOV, 10, function(v) Settings.Aimbot.FOV = v end)
D(c1, "14. Target Part", "", {"Head", "HumanoidRootPart", "UpperTorso"}, Settings.Aimbot.Part, function(v) Settings.Aimbot.Part = v end)
T(c1, "15. Wall Check", "", Settings.Aimbot.WallCheck, function(v) Settings.Aimbot.WallCheck = v end)
T(c1, "16. Prediction", "", Settings.Aimbot.Prediction, function(v) Settings.Aimbot.Prediction = v end)
T(c1, "17. Auto Fire", "", Settings.Aimbot.AutoFire, function(v) Settings.Aimbot.AutoFire = v end)
local c2 = Tabs.Combat:Section({Title = "Player Mods"})
T(c2, "18. Godmode", "", Settings.Combat.Godmode, function(v) Settings.Combat.Godmode = v end)
T(c2, "19. Invisible", "", Settings.Combat.Invisible, function(v) Settings.Combat.Invisible = v end)
T(c2, "20. Anti-AFK", "", Settings.Combat.AntiAFK, function(v) Settings.Combat.AntiAFK = v end)
T(c2, "21. Hitbox Expander", "", Settings.Combat.Hitbox, function(v) Settings.Combat.Hitbox = v end)
S(c2, "22. Hitbox Size", "", 5, 20, Settings.Combat.HitboxSize, 1, function(v) Settings.Combat.HitboxSize = v end)
T(c2, "23. Reach", "", Settings.Combat.Reach, function(v) Settings.Combat.Reach = v end)
S(c2, "24. Reach Dist", "", 10, 100, Settings.Combat.ReachDist, 5, function(v) Settings.Combat.ReachDist = v end)
T(c2, "25. No Fall Damage", "", Settings.Combat.NoFall, function(v) Settings.Combat.NoFall = v end)

-- Movement (14)
local m1 = Tabs.Movement:Section({Title = "Speed & Jump"})
T(m1, "26. WalkSpeed", "", Settings.Movement.Speed, function(v) Settings.Movement.Speed = v end)
S(m1, "27. WS Value", "", 16, 250, Settings.Movement.WS, 1, function(v) Settings.Movement.WS = v end)
T(m1, "28. JumpPower", "", Settings.Movement.Jump, function(v) Settings.Movement.Jump = v end)
S(m1, "29. JP Value", "", 50, 300, Settings.Movement.JP, 5, function(v) Settings.Movement.JP = v end)
T(m1, "30. Infinite Jump", "", Settings.Movement.InfJump, function(v) Settings.Movement.InfJump = v end)
local m2 = Tabs.Movement:Section({Title = "Flight & Physics"})
T(m2, "31. Fly", "", Settings.Movement.Fly, function(v) Settings.Movement.Fly = v end)
S(m2, "32. Fly Speed", "", 10, 200, Settings.Movement.FlySpeed, 5, function(v) Settings.Movement.FlySpeed = v end)
T(m2, "33. Noclip", "", Settings.Movement.Noclip, function(v) Settings.Movement.Noclip = v end)
T(m2, "34. Sprint", "Hold Shift", Settings.Movement.Sprint, function(v) Settings.Movement.Sprint = v end)
S(m2, "35. Sprint Boost", "", 10, 100, Settings.Movement.SprintBoost, 5, function(v) Settings.Movement.SprintBoost = v end)
T(m2, "36. Long Jump", "", Settings.Movement.LongJump, function(v) Settings.Movement.LongJump = v end)
S(m2, "37. LJ Boost", "", 10, 150, Settings.Movement.LJBoost, 5, function(v) Settings.Movement.LJBoost = v end)
T(m2, "38. High Jump", "", Settings.Movement.HighJump, function(v) Settings.Movement.HighJump = v end)
S(m2, "39. HJ Boost", "", 50, 300, Settings.Movement.HJBoost, 10, function(v) Settings.Movement.HJBoost = v end)

-- Visuals (8)
local v1 = Tabs.Visuals:Section({Title = "Environment"})
T(v1, "40. Fullbright", "", Settings.Visuals.Fullbright, function(v) Settings.Visuals.Fullbright = v end)
T(v1, "41. No Fog", "", Settings.Visuals.NoFog, function(v) Settings.Visuals.NoFog = v end)
T(v1, "42. Time of Day", "", Settings.Visuals.Time, function(v) Settings.Visuals.Time = v end)
S(v1, "43. Time Val", "", 0, 24, Settings.Visuals.TimeVal, 1, function(v) Settings.Visuals.TimeVal = v end)
T(v1, "44. FOV Changer", "", Settings.Visuals.FOV, function(v) Settings.Visuals.FOV = v end)
S(v1, "45. FOV Val", "", 30, 120, Settings.Visuals.FOVVal, 5, function(v) Settings.Visuals.FOVVal = v end)
T(v1, "46. X-Ray", "", Settings.Visuals.XRay, function(v) Settings.Visuals.XRay = v end)
T(v1, "47. No Camera Bob", "", Settings.Visuals.NoBob, function(v) Settings.Visuals.NoBob = v end)

-- Teleports (3)
local t1 = Tabs.Teleports:Section({Title = "Teleportation"})
local tpDropdown
t1:Dropdown({Title = "48. TP to Player", Values = (function() local t = {} for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(t, p.Name) end end return t end)(), Callback = function(v) Settings.Teleports.Target = v local p = Players:FindFirstChild(v) if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then LocalPlayer.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,5) end end})
T(t1, "49. TP to Cursor", "", Settings.Teleports.TPCursor, function(v) Settings.Teleports.TPCursor = v if v then LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(Mouse.Hit.Position) end end)
T(t1, "50. Copy Teleport", "", Settings.Teleports.CopyTP, function(v) Settings.Teleports.CopyTP = v end)

-- Misc (7)
local mi1 = Tabs.Misc:Section({Title = "Server & Misc"})
T(mi1, "51. Anti-Kick", "", Settings.Misc.AntiKick, function(v) Settings.Misc.AntiKick = v end)
T(mi1, "52. Anti-Crash", "", Settings.Misc.AntiCrash, function(v) Settings.Misc.AntiCrash = v end)
B(mi1, "53. Server Hop", function() game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer) end)
B(mi1, "54. Rejoin", function() game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
B(mi1, "55. Copy JobID", function() setclipboard(game.JobId) WindUI:Notify({Title = "Copied", Content = "Job ID copied."}) end)

Window:SetPanelBackground(true)
