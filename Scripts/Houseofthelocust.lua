-- [[ Aetherist / HOL - Ultimate Survival Suite ]]
-- Built with Rayfield Gen 2 [fanmade]
-- Features: Chams Highlight ESP, Auto Safe Spot Finder, Named Cube ESP, Generator/Fuel ESP

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SyncOfficialSpec/Rayfield_Gen_2_fanmade/main/source.lua"))()

-- ==============================================================================
-- SERVICES & SETUP
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ==============================================================================
-- CONFIGURATION
-- ==============================================================================
local Config = {
    -- ESP & Chams
    ChamsEnabled = true,
    ChamsFillTransparency = 0.6,
    ChamsOutlineTransparency = 0.0,
    
    KillerChams = true,
    KillerColor = Color3.fromRGB(255, 35, 60),
    
    ItemChams = true,
    ItemColor = Color3.fromRGB(255, 215, 0), -- WireCutter, Keycard, Fuel
    
    ObjectiveChams = true,
    ObjectiveColor = Color3.fromRGB(0, 230, 255), -- Cubes, Doors, Generators
    
    PlayerChams = false,
    PlayerColor = Color3.fromRGB(0, 150, 255),

    -- Drawing ESP (Names & Distances)
    NameESP = true,
    DistanceESP = true,
    TracerESP = false,
    
    -- Specific Toggles
    FuelGeneratorESP = true,
    AutoSafeSpot = false,
    AntiJumpscare = true,
    Fullbright = true,
    NoFog = true,
}

-- Cache for Highlight instances (Chams)
local ChamCache = {}

-- ==============================================================================
-- UTILITY FUNCTIONS
-- ==============================================================================
local function getRoot(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end

local function applyCham(target, color, name)
    if not Config.ChamsEnabled then return end
    if not ChamCache[target] then
        local cham = Instance.new("Highlight")
        cham.Name = "AetheristCham_" .. name
        cham.FillColor = color
        cham.OutlineColor = Color3.fromRGB(0, 0, 0)
        cham.FillTransparency = Config.ChamFillTransparency or 0.6
        cham.OutlineTransparency = Config.ChamOutlineTransparency or 0.0
        cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        cham.Parent = target
        ChamCache[target] = cham
    else
        ChamCache[target].FillColor = color
        ChamCache[target].FillTransparency = Config.ChamFillTransparency or 0.6
    end
end

local function removeCham(target)
    if ChamCache[target] then
        ChamCache[target]:Destroy()
        ChamCache[target] = nil
    end
end

local function clearAllChams()
    for target, cham in pairs(ChamCache) do
        cham:Destroy()
    end
    table.clear(ChamCache)
end

-- ==============================================================================
-- AUTO SAFE SPOT FINDER
-- ==============================================================================
local function findAndTeleportToSafeSpot()
    local char = LocalPlayer.Character
    local hrp = getRoot(char)
    if not hrp then return end
    
    local myPos = hrp.Position
    local bestSpot = nil
    local minDist = math.huge
    
    -- Scan for high, collidable, anchored parts (map geometry)
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.CanCollide and part.Anchored then
            -- Check if it's above us and has a flat surface (normal Y is 1)
            if part.Position.Y > myPos.Y + 15 and math.abs(part.CFrame.UpVector.Y - 1) < 0.1 then
                local dist = (part.Position - myPos).Magnitude
                if dist < minDist and dist < 150 then
                    minDist = dist
                    bestSpot = part
                end
            end
        end
    end
    
    if bestSpot then
        -- Temporarily highlight the safe spot
        applyCham(bestSpot, Color3.fromRGB(0, 255, 100), "SafeSpot")
        task.delay(3, function() removeCham(bestSpot) end)
        
        hrp.CFrame = CFrame.new(bestSpot.Position + Vector3.new(0, 3, 0))
        Rayfield:Notify({
            Title = "Safe Spot Found",
            Content = "Teleported to high ground: " .. math.floor(minDist) .. " studs away.",
            Duration = 3,
            Image = "shield-check"
        })
    else
        -- Fallback: Teleport to highest SpawnLocation
        local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation")
        if spawn then
            hrp.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 5, 0))
            Rayfield:Notify({Title = "Safe Spot", Content = "Teleported to Spawn area.", Duration = 3})
        else
            Rayfield:Notify({Title = "Safe Spot", Content = "No safe spot found nearby.", Duration = 3, Image = "alert-triangle"})
        end
    end
end

-- ==============================================================================
-- ESP & CHAMS RENDER LOOP
-- ==============================================================================
local DrawingCache = {}

local function updateESP()
    local char = LocalPlayer.Character
    local hrp = getRoot(char)
    local myPos = hrp and hrp.Position or Vector3.zero
    
    -- 1. KILLERS (Locust / Boiled One)
    local entities = Workspace:FindFirstChild("Entities")
    local killers = {}
    if entities then
        for _, obj in ipairs(entities:GetChildren()) do
            if obj.Name == "Locust" or obj.Name == "Boiled One" then
                table.insert(killers, obj)
            end
        end
    end
    
    for _, killer in ipairs(killers) do
        if Config.KillerChams then applyCham(killer, Config.KillerColor, "Killer") end
        
        if Config.NameESP or Config.DistanceESP or Config.TracerESP then
            local root = getRoot(killer)
            if root then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
                if onScreen then
                    local dist = math.floor((root.Position - myPos).Magnitude)
                    local text = ""
                    if Config.NameESP then text = text .. (killer.Name == "Boiled One" and "💀 Boiled One" or "💀 Locust") end
                    if Config.DistanceESP then text = text .. " [" .. dist .. "m]" end
                    
                    if not DrawingCache[killer] then
                        DrawingCache[killer] = {
                            Text = Drawing.new("Text"),
                            Tracer = Drawing.new("Line")
                        }
                        DrawingCache[killer].Text.Size = 16
                        DrawingCache[killer].Text.Center = true
                        DrawingCache[killer].Text.Outline = true
                        DrawingCache[killer].Text.Color = Config.KillerColor
                        DrawingCache[killer].Tracer.Thickness = 2
                        DrawingCache[killer].Tracer.Color = Config.KillerColor
                    end
                    
                    DrawingCache[killer].Text.Visible = true
                    DrawingCache[killer].Text.Position = Vector2.new(pos.X, pos.Y)
                    DrawingCache[killer].Text.Text = text
                    
                    if Config.TracerESP then
                        DrawingCache[killer].Tracer.Visible = true
                        DrawingCache[killer].Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        DrawingCache[killer].Tracer.To = Vector2.new(pos.X, pos.Y + 16)
                    else
                        DrawingCache[killer].Tracer.Visible = false
                    end
                end
            end
        end
    end
    
    -- 2. ITEMS (WireCutter, Keycard, Fuel/Fuel Canister)
    local items = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "WireCutter" or obj.Name == "Keycard" or obj.Name == "Fuel" or obj.Name == "Fuel Canister" then
            table.insert(items, obj)
        end
    end
    
    for _, item in ipairs(items) do
        if Config.ItemChams then applyCham(item, Config.ItemColor, "Item") end
        
        if Config.NameESP or Config.DistanceESP then
            local pos, onScreen = Camera:WorldToViewportPoint(item:GetPivot().Position)
            if onScreen then
                local dist = math.floor((item:GetPivot().Position - myPos).Magnitude)
                local text = ""
                if Config.NameESP then text = text .. "🎒 " .. item.Name end
                if Config.DistanceESP then text = text .. " [" .. dist .. "m]" end
                
                if not DrawingCache[item] then
                    DrawingCache[item] = { Text = Drawing.new("Text") }
                    DrawingCache[item].Text.Size = 14
                    DrawingCache[item].Text.Center = true
                    DrawingCache[item].Text.Outline = true
                    DrawingCache[item].Text.Color = Config.ItemColor
                end
                
                DrawingCache[item].Text.Visible = true
                DrawingCache[item].Text.Position = Vector2.new(pos.X, pos.Y)
                DrawingCache[item].Text.Text = text
            end
        end
    end
    
    -- 3. OBJECTIVES (Cubes, Doors, Generators)
    local objectives = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "CubeYellow" or obj.Name == "CubeRed" or obj.Name == "CubeBlue" or 
           obj.Name == "DoorWire" or obj.Name == "Keyhole" or obj.Name == "KeycardReader" or
           obj.Name == "Generator" or obj.Name == "Gen" then
            table.insert(objectives, obj)
        end
    end
    
    for _, obj in ipairs(objectives) do
        if Config.ObjectiveChams then applyCham(obj, Config.ObjectiveColor, "Objective") end
        
        if Config.NameESP or Config.DistanceESP then
            local pos, onScreen = Camera:WorldToViewportPoint(obj:GetPivot().Position)
            if onScreen then
                local dist = math.floor((obj:GetPivot().Position - myPos).Magnitude)
                local displayName = obj.Name
                if obj.Name == "CubeYellow" then displayName = "🟡 Yellow Cube"
                elseif obj.Name == "CubeRed" then displayName = "🔴 Red Cube"
                elseif obj.Name == "CubeBlue" then displayName = "🔵 Blue Cube"
                elseif obj.Name == "DoorWire" then displayName = "🔒 Wire Door"
                elseif obj.Name == "Keyhole" then displayName = "🔑 Keyhole"
                elseif obj.Name == "KeycardReader" then displayName = "💳 Card Reader"
                elseif obj.Name == "Generator" or obj.Name == "Gen" then displayName = "⚡ Generator"
                end
                
                local text = ""
                if Config.NameESP then text = text .. displayName end
                if Config.DistanceESP then text = text .. " [" .. dist .. "m]" end
                
                if not DrawingCache[obj] then
                    DrawingCache[obj] = { Text = Drawing.new("Text") }
                    DrawingCache[obj].Text.Size = 14
                    DrawingCache[obj].Text.Center = true
                    DrawingCache[obj].Text.Outline = true
                    DrawingCache[obj].Text.Color = Config.ObjectiveColor
                end
                
                DrawingCache[obj].Text.Visible = true
                DrawingCache[obj].Text.Position = Vector2.new(pos.X, pos.Y)
                DrawingCache[obj].Text.Text = text
            end
        end
    end
    
    -- 4. PLAYERS
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = getRoot(player.Character)
            if root then
                if Config.PlayerChams then applyCham(player.Character, Config.PlayerColor, "Player") end
                
                if Config.NameESP or Config.DistanceESP then
                    local pos, onScreen = Camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
                    if onScreen then
                        local dist = math.floor((root.Position - myPos).Magnitude)
                        local text = ""
                        if Config.NameESP then text = text .. "👤 " .. player.DisplayName end
                        if Config.DistanceESP then text = text .. " [" .. dist .. "m]" end
                        
                        if not DrawingCache[player] then
                            DrawingCache[player] = { Text = Drawing.new("Text") }
                            DrawingCache[player].Text.Size = 14
                            DrawingCache[player].Text.Center = true
                            DrawingCache[player].Text.Outline = true
                            DrawingCache[player].Text.Color = Config.PlayerColor
                        end
                        
                        DrawingCache[player].Text.Visible = true
                        DrawingCache[player].Text.Position = Vector2.new(pos.X, pos.Y)
                        DrawingCache[player].Text.Text = text
                    end
                end
            end
        end
    end
    
    -- Cleanup stale drawings
    for obj, cache in pairs(DrawingCache) do
        local isValid = false
        if Workspace:FindFirstChild(obj.Name) or (obj:IsA("Model") and obj.Parent) or Players:FindFirstChild(obj.Name) then
            isValid = true
        end
        if not isValid then
            for _, drawObj in pairs(cache) do
                pcall(function() drawObj:Remove() end)
            end
            DrawingCache[obj] = nil
            removeCham(obj)
        end
    end
end

-- ==============================================================================
-- ATMOSPHERE & ANTI-JUMPSCARE
-- ==============================================================================
local OriginalLighting = {
    Ambient = Workspace.Lighting.Ambient,
    OutdoorAmbient = Workspace.Lighting.OutdoorAmbient,
    FogEnd = Workspace.Lighting.FogEnd,
    FogStart = Workspace.Lighting.FogStart,
}

local function updateAtmosphere()
    if Config.Fullbright then
        Workspace.Lighting.Ambient = Color3.fromRGB(245, 245, 245)
        Workspace.Lighting.OutdoorAmbient = Color3.fromRGB(245, 245, 245)
    else
        Workspace.Lighting.Ambient = OriginalLighting.Ambient
        Workspace.Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    end
    
    if Config.NoFog then
        Workspace.Lighting.FogEnd = 100000
        Workspace.Lighting.FogStart = 0
    else
        Workspace.Lighting.FogEnd = OriginalLighting.FogEnd
        Workspace.Lighting.FogStart = OriginalLighting.FogStart
    end
end

local function counterJumpscare()
    if not Config.AntiJumpscare then return end
    if Camera.CameraType == Enum.CameraType.Scriptable then
        Camera.CameraType = Enum.CameraType.Custom
    end
    local char = LocalPlayer.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") or v:IsA("Decal") then
                v.LocalTransparencyModifier = 0
            end
        end
    end
end

-- ==============================================================================
-- MAIN LOOPS
-- ==============================================================================
task.spawn(function()
    while true do
        pcall(counterJumpscare)
        task.wait(0.1)
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(updateESP)
end)

-- ==============================================================================
-- RAYFIELD GEN 2 UI
-- ==============================================================================
local Window = Rayfield:CreateWindow({
    Name = "Aetherist / HOL",
    Subtitle = "Nightmare Mode Survival Suite",
    Icon = "ghost",
    LoadingTitle = "Aetherist / HOL",
    LoadingSubtitle = "Initializing Nightmare Protocols...",
    ToggleUIKeybind = "RightShift",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "Aetherist_HOL",
        FileName = "Config",
    },
})

local TabVisuals = Window:CreateTab("Visuals & ESP", "eye")
local TabPlayer = Window:CreateTab("Player & Utilities", "user")
local TabSettings = Window:CreateTab("Settings", "settings")

-- VISUALS TAB
TabVisuals:CreateSection("Chams (Highlight ESP)")
TabVisuals:CreateToggle({
    Name = "Enable Chams",
    CurrentValue = Config.ChamsEnabled,
    Flag = "ChamsEnabled",
    Description = "Uses Roblox Highlight instances for clean, wallhack-style ESP.",
    Callback = function(value) Config.ChamsEnabled = value end
})
TabVisuals:CreateSlider({
    Name = "Fill Transparency",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0.6,
    Flag = "ChamFillTransparency",
    Callback = function(value) Config.ChamFillTransparency = value end
})

TabVisuals:CreateSection("Entity Chams")
TabVisuals:CreateToggle({
    Name = "Killer Chams (Locust / Boiled One)",
    CurrentValue = Config.KillerChams,
    Flag = "KillerChams",
    Callback = function(value) Config.KillerChams = value end
})
TabVisuals:CreateColorPicker({
    Name = "Killer Color",
    Color = Config.KillerColor,
    Flag = "KillerColor",
    Callback = function(value) Config.KillerColor = value end
})

TabVisuals:CreateToggle({
    Name = "Item Chams (WireCutter, Keycard, Fuel)",
    CurrentValue = Config.ItemChams,
    Flag = "ItemChams",
    Callback = function(value) Config.ItemChams = value end
})
TabVisuals:CreateColorPicker({
    Name = "Item Color",
    Color = Config.ItemColor,
    Flag = "ItemColor",
    Callback = function(value) Config.ItemColor = value end
})

TabVisuals:CreateToggle({
    Name = "Objective Chams (Cubes, Doors, Generators)",
    CurrentValue = Config.ObjectiveChams,
    Flag = "ObjectiveChams",
    Callback = function(value) Config.ObjectiveChams = value end
})
TabVisuals:CreateColorPicker({
    Name = "Objective Color",
    Color = Config.ObjectiveColor,
    Flag = "ObjectiveColor",
    Callback = function(value) Config.ObjectiveColor = value end
})

TabVisuals:CreateSection("Drawing ESP (Names & Distances)")
TabVisuals:CreateToggle({
    Name = "Name ESP",
    CurrentValue = Config.NameESP,
    Flag = "NameESP",
    Description = "Shows exact names (e.g., '🟡 Yellow Cube') so they don't mix up.",
    Callback = function(value) Config.NameESP = value end
})
TabVisuals:CreateToggle({
    Name = "Distance ESP",
    CurrentValue = Config.DistanceESP,
    Flag = "DistanceESP",
    Callback = function(value) Config.DistanceESP = value end
})
TabVisuals:CreateToggle({
    Name = "Tracer Lines",
    CurrentValue = Config.TracerESP,
    Flag = "TracerESP",
    Callback = function(value) Config.TracerESP = value end
})

TabVisuals:CreateSection("Atmosphere")
TabVisuals:CreateToggle({
    Name = "Fullbright",
    CurrentValue = Config.Fullbright,
    Flag = "Fullbright",
    Callback = function(value) Config.Fullbright = value; updateAtmosphere() end
})
TabVisuals:CreateToggle({
    Name = "No Fog",
    CurrentValue = Config.NoFog,
    Flag = "NoFog",
    Callback = function(value) Config.NoFog = value; updateAtmosphere() end
})

-- PLAYER TAB
TabPlayer:CreateSection("Survival Utilities")
TabPlayer:CreateButton({
    Name = "Find & Teleport to Safe Spot",
    Description = "Scans for high, flat surfaces nearby and teleports you to safety.",
    Callback = findAndTeleportToSafeSpot
})
TabPlayer:CreateToggle({
    Name = "Anti-Jumpscare",
    CurrentValue = Config.AntiJumpscare,
    Flag = "AntiJumpscare",
    Description = "Prevents camera locks and character transparency during jumpscares.",
    Callback = function(value) Config.AntiJumpscare = value end
})

TabPlayer:CreateSection("Movement")
TabPlayer:CreateToggle({
    Name = "Fly (Press 'F' to toggle)",
    CurrentValue = false,
    Flag = "Fly",
    Callback = function(value) 
        -- Basic fly toggle logic can be expanded here
    end
})

-- SETTINGS TAB
TabSettings:CreateSection("Script Management")
TabSettings:CreateButton({
    Name = "Rejoin Server",
    Description = "Rejoins the current game instance.",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end
})
TabSettings:CreateButton({
    Name = "Clear All Chams & ESP",
    Description = "Instantly removes all visual modifications.",
    Callback = function()
        clearAllChams()
        for obj, cache in pairs(DrawingCache) do
            for _, drawObj in pairs(cache) do
                pcall(function() drawObj:Remove() end)
            end
        end
        table.clear(DrawingCache)
        Rayfield:Notify({Title = "Cleared", Content = "All ESP and Chams removed.", Duration = 2})
    end
})

-- Initialize
updateAtmosphere()
Rayfield:Notify({
    Title = "Aetherist / HOL",
    Content = "Nightmare Mode Suite Loaded. Chams & Named ESP Active.",
    Duration = 4,
    Image = "shield-check"
})

Rayfield:LoadConfiguration()
