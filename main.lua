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
local magnetConnection = nil
local platformLockConnection = nil
local bonusConnection = nil
local gameClock = nil
local exitsFolder = nil

----------------------------------------------------
-- GUI
----------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BananaStableFarm"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0,220,0,130)
mainFrame.Position = UDim2.new(0.5,-110,0.5,-65)
mainFrame.BackgroundColor3 = Color3.fromRGB(40,35,10)
mainFrame.BorderSizePixel = 3
mainFrame.BorderColor3 = Color3.fromRGB(255,230,0)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,0,0,30)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "🍌 BANANA AUTO FARM 🍌"
titleLabel.TextColor3 = Color3.fromRGB(255,230,0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.Parent = mainFrame

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.8,0,0,40)
toggleBtn.Position = UDim2.new(0.1,0,0.35,0)
toggleBtn.BackgroundColor3 = Color3.fromRGB(255,220,0)
toggleBtn.Text = "Start"
toggleBtn.TextColor3 = Color3.new(0,0,0)
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.TextSize = 20
toggleBtn.Parent = mainFrame
Instance.new("UICorner",toggleBtn).CornerRadius = UDim.new(0,8)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1,0,0,20)
statusLabel.Position = UDim2.new(0,0,0.8,0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Waiting..."
statusLabel.TextColor3 = Color3.fromRGB(255,255,200)
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.TextSize = 14
statusLabel.Parent = mainFrame

-- Hide UI Button
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0,100,0,28)
hideBtn.Position = UDim2.new(1,-110,0,15)
hideBtn.BackgroundColor3 = Color3.fromRGB(255,220,0)
hideBtn.Text = "Hide UI"
hideBtn.TextColor3 = Color3.new(0,0,0)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 13
hideBtn.Parent = screenGui
Instance.new("UICorner",hideBtn)

local uiVisible = true
hideBtn.MouseButton1Click:Connect(function()
	uiVisible = not uiVisible
	mainFrame.Visible = uiVisible
	hideBtn.Text = uiVisible and "Hide UI" or "Show UI"
end)

----------------------------------------------------
-- Anti AFK
----------------------------------------------------

player.Idled:Connect(function()
	if isScriptActive then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

----------------------------------------------------
-- Utility
----------------------------------------------------

local function CleanUp()
	if magnetConnection then magnetConnection:Disconnect() end
	if platformLockConnection then platformLockConnection:Disconnect() end
	if myPlatform then myPlatform:Destroy() end
	magnetConnection = nil
	platformLockConnection = nil
	myPlatform = nil
end

local function UpdateMapRefs()
	if not gameClock then
		local gp = Workspace:FindFirstChild("GameProperties")
		if gp then gameClock = gp:FindFirstChild("GameClock") end
	end
	if not exitsFolder then
		local gk = Workspace:FindFirstChild("GameKeeper")
		if gk then exitsFolder = gk:FindFirstChild("Exits") end
	end
end

local function ForceTeleport(root, cf, duration)
	local start = tick()
	while tick() - start < duration do
		root.CFrame = cf
		root.AssemblyLinearVelocity = Vector3.zero
		RunService.Heartbeat:Wait()
	end
end

----------------------------------------------------
-- Runner Setup
----------------------------------------------------

local function SetupRunner()
	CleanUp()
	hasEscaped = false
	statusLabel.Text = "Runner Mode"
	statusLabel.TextColor3 = Color3.fromRGB(0,255,0)

	local root
	repeat
		root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		task.wait()
	until root

	-- Create platform 60 studs above
	myPlatform = Instance.new("Part")
	myPlatform.Size = Vector3.new(50,1,50)
	myPlatform.Anchored = true
	myPlatform.CanCollide = true
	myPlatform.Material = Enum.Material.Neon
	myPlatform.Color = Color3.fromRGB(255,255,0)
	myPlatform.Transparency = 0.4
	myPlatform.CFrame = CFrame.new(root.Position + Vector3.new(0,60,0))
	myPlatform.Parent = Workspace

	-- Force teleport above platform (impossible to fail)
	local targetCF = myPlatform.CFrame + Vector3.new(0,3,0)
	ForceTeleport(root, targetCF, 1)

	-- Light position lock (no lag)
	platformLockConnection = RunService.Heartbeat:Connect(function()
		if not isScriptActive or currentMode ~= "Runner" then return end
		if root then
			root.CFrame = targetCF
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end)

	-- Magnet (distance limited → no lag)
	magnetConnection = RunService.Heartbeat:Connect(function()
		if not isScriptActive or currentMode ~= "Runner" then return end
		if not root then return end

		for _, obj in ipairs(Workspace:GetChildren()) do
			if obj.Name == MONEY_NAME and obj:IsA("BasePart") then
				if (obj.Position - root.Position).Magnitude < 200 then
					obj.CanCollide = false
					obj.CFrame = root.CFrame
				end
			end
		end
	end)
end

----------------------------------------------------
-- Escape
----------------------------------------------------

RunService.Stepped:Connect(function()
	if not isScriptActive then return end
	UpdateMapRefs()

	if currentMode == "Runner" and gameClock and gameClock.Value <= 60 and gameClock.Value > 50 and not hasEscaped then
		hasEscaped = true
		CleanUp()

		if exitsFolder then
			local exits = exitsFolder:GetChildren()
			local exit = exits[2]
			if exit then
				local part = exit:FindFirstChildWhichIsA("BasePart")
				if part then
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					if root then
						ForceTeleport(root, part.CFrame + Vector3.new(0,3,0), 2)
					end
				end
			end
		end
	end
end)

----------------------------------------------------
-- Team Handling
----------------------------------------------------

local function OnTeamChanged()
	if not isScriptActive then return end

	local teamName = player.Team and player.Team.Name or "None"

	if teamName == RUNNER_TEAM then
		currentMode = "Runner"
		SetupRunner()

	elseif teamName == BANANA_TEAM then
		currentMode = "Banana"
		CleanUp()
		player:LoadCharacter()

	else
		currentMode = "Lobby"
		CleanUp()
		statusLabel.Text = "Lobby Mode"
	end
end

player:GetPropertyChangedSignal("Team"):Connect(OnTeamChanged)

----------------------------------------------------
-- Toggle
----------------------------------------------------

toggleBtn.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive
	if isScriptActive then
		toggleBtn.Text = "Stop"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(200,0,0)
		OnTeamChanged()
	else
		toggleBtn.Text = "Start"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(255,220,0)
		currentMode = "None"
		CleanUp()
		statusLabel.Text = "Turned Off"
	end
end)

player.CharacterAdded:Connect(function()
	if isScriptActive then
		task.delay(0.5, OnTeamChanged)
	end
end)
