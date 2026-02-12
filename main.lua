-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

-- Player / Teams
local player = Players.LocalPlayer
local RUNNER_TEAM = "Runners"
local BANANA_TEAM = "Banana"
local MONEY_NAME = "Token"

-- Variables
local isScriptActive = false
local currentMode = "None"
local hasEscaped = false
local myPlatform = nil
local platformHeight = 60 -- sopra la mappa
local bonusConnection = nil

local gameClock = nil
local exitsFolder = nil

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BananaFixedFinal"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 220, 0, 130)
mainFrame.Position = UDim2.new(0.5, -110, 0.5, -65)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 35, 10) 
mainFrame.BorderSizePixel = 3
mainFrame.BorderColor3 = Color3.fromRGB(255, 230, 0) 
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🍌 BANANA EATS AUTO FARM 🍌"
titleLabel.TextColor3 = Color3.fromRGB(255, 230, 0)
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8, 0, 0, 40)
toggleBtn.Position = UDim2.new(0.1, 0, 0.35, 0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 0) 
toggleBtn.Text = "Start"
toggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0) 
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.TextSize = 20
toggleBtn.Parent = mainFrame
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0.8, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Waiting..."
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 200)
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.TextSize = 14
statusLabel.Parent = mainFrame

-- Hide / Show UI Button
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 100, 0, 28)
hideBtn.Position = UDim2.new(1, -110, 0, 15)
hideBtn.AnchorPoint = Vector2.new(0, 0)
hideBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
hideBtn.BorderSizePixel = 0
hideBtn.Text = "Hide UI"
hideBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 13
hideBtn.Parent = screenGui
hideBtn.AutoButtonColor = true
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 200, 0)
stroke.Thickness = 2
stroke.Parent = hideBtn

local uiVisible = true
hideBtn.MouseButton1Click:Connect(function()
	uiVisible = not uiVisible
	mainFrame.Visible = uiVisible
	hideBtn.Text = uiVisible and "Hide UI" or "Show UI"
end)

-- Anti-AFK
player.Idled:Connect(function()
	if isScriptActive then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

-- Utilities
local function CleanUpPhysics()
	if myPlatform then myPlatform:Destroy() myPlatform = nil end
	if bonusConnection then bonusConnection:Disconnect() bonusConnection = nil end
	if player.Character then
		local hum = player.Character:FindFirstChild("Humanoid")
		if hum then hum.PlatformStand = false end
	end
end

local function UpdateMapReferences()
	if not gameClock then
		local gp = Workspace:FindFirstChild("GameProperties")
		if gp then gameClock = gp:FindFirstChild("GameClock") end
	end
	if not exitsFolder then
		local gk = Workspace:FindFirstChild("GameKeeper")
		if gk then exitsFolder = gk:FindFirstChild("Exits") end
	end
end

local function SpamTeleport(targetCFrame, duration)
	local startTime = tick()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
		while tick() - startTime < duration do
			if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then break end
			root.CFrame = targetCFrame
			root.AssemblyLinearVelocity = Vector3.zero
			RunService.Heartbeat:Wait()
		end
		if root then root.Anchored = false end
	end
end

-- Bonus
local function CollectBonus()
	if currentMode ~= "Lobby" or not isScriptActive then return end
	local barrel = Workspace:FindFirstChild("BonusBarrel")
	if barrel and barrel:FindFirstChild("Root") then
		statusLabel.Text = "🎁 BONUS!"
		statusLabel.TextColor3 = Color3.fromRGB(255, 0, 255)
		SpamTeleport(barrel.Root.CFrame + Vector3.new(0, 2, 0), 3)
		statusLabel.Text = "Status: Lobby"
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function SetupBonusListener()
	local holder = player:WaitForChild("BonusBarrelHolder", 5)
	if holder then
		local timeVal = holder:WaitForChild("Time", 5)
		if timeVal then
			if timeVal.Value == 0 then CollectBonus() end
			if bonusConnection then bonusConnection:Disconnect() end
			bonusConnection = timeVal:GetPropertyChangedSignal("Value"):Connect(function()
				if timeVal.Value == 0 and currentMode == "Lobby" then CollectBonus() end
			end)
		end
	end
end

-- Team logic
local function OnTeamChanged()
	if not isScriptActive then return end
	local teamName = player.Team and player.Team.Name or "None"

	if teamName == "Lobby" or teamName == "Spectators" or teamName == "None" then
		currentMode = "Lobby"
		CleanUpPhysics()
		statusLabel.Text = "Status: Lobby"
		statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
		SetupBonusListener()

	elseif teamName == RUNNER_TEAM then
		currentMode = "Runner"
		CleanUpPhysics()
		hasEscaped = false
		statusLabel.Text = "Status: Runner (Starting...)"
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)

		task.spawn(function()
			local root
			repeat
				root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				task.wait(0.1)
			until root

			-- Create flying platform above the map
			local platformPos = root.Position + Vector3.new(0, platformHeight, 0)
			myPlatform = Instance.new("Part")
			myPlatform.Size = Vector3.new(50, 1, 50)
			myPlatform.Anchored = true
			myPlatform.CanCollide = true
			myPlatform.Transparency = 0.6
			myPlatform.Color = Color3.fromRGB(255, 255, 0)
			myPlatform.Material = Enum.Material.Neon
			myPlatform.CFrame = CFrame.new(platformPos)
			myPlatform.Parent = Workspace

			local hum = player.Character:FindFirstChild("Humanoid")
			if hum then hum.PlatformStand = true end

			-- Magnet loop with offset above platform
			RunService.Heartbeat:Connect(function()
				if not isScriptActive or currentMode ~= "Runner" then return end
				local charRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not charRoot then return end

				for _, obj in pairs(Workspace:GetDescendants()) do
					if obj.Name == MONEY_NAME then
						local targetPos = charRoot.Position + Vector3.new(0, 3, 5) -- leggermente davanti e sopra
						if obj:IsA("BasePart") then
							obj.CanCollide = false
							obj.CFrame = CFrame.new(targetPos)
							obj.AssemblyLinearVelocity = Vector3.zero
						elseif obj:IsA("Model") and obj.PrimaryPart then
							obj.PrimaryPart.CanCollide = false
							obj:PivotTo(CFrame.new(targetPos))
							obj.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
						elseif obj:IsA("Tool") and obj:FindFirstChild("Handle") then
							obj.Handle.CanCollide = false
							obj.Handle.CFrame = CFrame.new(targetPos)
						end
					end
				end
			end)

			statusLabel.Text = "Status: Farming"
			statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
		end)

	elseif teamName == BANANA_TEAM then
		currentMode = "Banana"
		CleanUpPhysics()
		statusLabel.Text = "Status: Banana (Resetting...)"
		statusLabel.TextColor3 = Color3.fromRGB(255,0,0)
		task.wait(0.5)
		player:LoadCharacter()
	end
end

player:GetPropertyChangedSignal("Team"):Connect(OnTeamChanged)

-- Main loop (Escape Runner)
RunService.Stepped:Connect(function()
	if not isScriptActive then return end
	UpdateMapReferences()

	-- Escape
	if currentMode == "Runner" and gameClock and gameClock.Value <= 60 and gameClock.Value > 50 and not hasEscaped then
		hasEscaped = true
		CleanUpPhysics() -- rimuove piattaforma

		if exitsFolder then
			local exits = exitsFolder:GetChildren()
			local primaryExit = exits[2]
			local targetPart = primaryExit and (primaryExit:FindFirstChild("Neon") or primaryExit.PrimaryPart)
			if targetPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				statusLabel.Text = "🏃 ESCAPE: EXIT 2"
				statusLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
				task.spawn(function()
					SpamTeleport(targetPart.CFrame + Vector3.new(0,3,0), 3)
				end)
			end

			task.delay(13, function()
				if isScriptActive and player.Team and player.Team.Name == RUNNER_TEAM then
					statusLabel.Text = "⚠ PLAN B: ESCAPE DOOR"
					statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
					local backupExit = exitsFolder:FindFirstChild("EscapeDoor")
					if backupExit then
						local backupPart = backupExit:FindFirstChild("Neon") or backupExit.PrimaryPart or backupExit:FindFirstChildWhichIsA("BasePart")
						if backupPart and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
							SpamTeleport(backupPart.CFrame + Vector3.new(0,3,0), 5)
						end
					end
				end
			end)
		end
	end
end)

-- Toggle button
toggleBtn.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive
	if isScriptActive then
		toggleBtn.Text = "Stop"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		statusLabel.Text = "Status: Active"
		OnTeamChanged()
	else
		toggleBtn.Text = "Start"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
		statusLabel.Text = "Status: Turned Off"
		currentMode = "None"
		CleanUpPhysics()
	end
end)

-- Character respawn
player.CharacterAdded:Connect(function()
	if isScriptActive then
		CleanUpPhysics()
		task.delay(0.5, OnTeamChanged)
	end
end)
