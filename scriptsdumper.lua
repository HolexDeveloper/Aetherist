local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

-- ==========================================
-- 1. CREATE PROGRESS UI
-- ==========================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DecompilerUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = CoreGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 130)
mainFrame.Position = UDim2.new(0.5, -160, 0.5, -65)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", mainFrame).Color = Color3.fromRGB(50, 50, 60)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 35)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🔓 Script Dumper"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 0, 40)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Initializing..."
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, -20, 0, 8)
progressBg.Position = UDim2.new(0, 10, 0, 70)
progressBg.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
progressBg.BorderSizePixel = 0
progressBg.Parent = mainFrame
Instance.new("UICorner", progressBg).CornerRadius = UDim.new(1, 0)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(85, 255, 127) -- Nice bright green
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg
Instance.new("UICorner", progressFill).CornerRadius = UDim.new(1, 0)

local countLabel = Instance.new("TextLabel")
countLabel.Size = UDim2.new(1, -20, 0, 20)
countLabel.Position = UDim2.new(0, 10, 0, 90)
countLabel.BackgroundTransparency = 1
countLabel.Text = "0 / 0"
countLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
countLabel.Font = Enum.Font.Gotham
countLabel.TextSize = 12
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.Parent = mainFrame

-- ==========================================
-- 2. DECOMPILER LOGIC (OPTIMIZED)
-- ==========================================
local scripts = getscripts()
local totalScripts = #scripts
local codeParts = {} -- Using a table is MUCH faster and prevents memory crashes

for i, v in ipairs(scripts) do
	-- Update UI
	local progress = i / totalScripts
	progressFill.Size = UDim2.new(progress, 0, 1, 0)
	statusLabel.Text = "Decompiling: " .. v.Name
	countLabel.Text = i .. " / " .. totalScripts .. " (Remaining: " .. (totalScripts - i) .. ")"

	-- Safely attempt to decompile
	pcall(function()
		local success, decompiledCode = pcall(function()
			return decompile(v)
		end)

		if success and decompiledCode then
			table.insert(codeParts, "SCRIPTNAME: " .. v.Name)
			table.insert(codeParts, "SCRIPT PATH: " .. v:GetFullName())
			table.insert(codeParts, "SCRIPT CODE:\n" .. tostring(decompiledCode))
			table.insert(codeParts, "====================================================================")
		else
			table.insert(codeParts, "SCRIPTNAME: " .. v.Name .. " [FAILED TO DECOMPILE]")
			table.insert(codeParts, "SCRIPT PATH: " .. v:GetFullName())
			table.insert(codeParts, "====================================================================")
		end
	end)

	-- Safety delay to prevent executor/game freezing
	task.wait(0.05)
end

-- ==========================================
-- 3. COMPLETION & CLIPBOARD
-- ==========================================
statusLabel.Text = "Finished Dumping!"
statusLabel.TextColor3 = Color3.fromRGB(85, 255, 127) -- Green text
countLabel.Text = "Copying to clipboard..."

-- Concatenate all parts at once (highly optimized)
local finalCode = table.concat(codeParts, "\n\n")
setclipboard(finalCode)

countLabel.Text = "✅ Copied to clipboard successfully!"

-- Auto-destroy UI after 3 seconds
task.delay(3, function()
	TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, -160, 0.5, -45) -- Slide down slightly
	}):Play()
	
	task.wait(0.3)
	screenGui:Destroy()
end)