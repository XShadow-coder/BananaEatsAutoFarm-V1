local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local RUNNER_TEAM = "Runners"
local BANANA_TEAM = "Banana"
local MONEY_NAME = "Token"

-- === VARIABLES ===
local isScriptActive = false
local currentMode = "None"
local hasEscaped = false
local myPlatform = nil

local holdBodyPos = nil
local holdGyro = nil
local bonusConnection = nil

local gameClock = nil
local exitsFolder = nil

-- === GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BananaFixedFinal"
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.ResetOnSpawn = false

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

-- === ANTI AFK ===
player.Idled:Connect(function()
	if isScriptActive then
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end)

-- ==========================================
-- SAFE TELEPORT
-- ==========================================
local function SpamTeleport(targetCFrame, duration)
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local startTime = tick()
	local wasAnchored = root.Anchored
	root.Anchored = true

	while tick() - startTime < duration do
		if not player.Character then break end
		local newRoot = player.Character:FindFirstChild("HumanoidRootPart")
		if not newRoot then break end

		newRoot.CFrame = targetCFrame
		newRoot.AssemblyLinearVelocity = Vector3.zero
		RunService.Heartbeat:Wait()
	end

	if root then
		root.Anchored = wasAnchored
	end
end

-- ==========================================
-- MAP SEARCH
-- ==========================================
local function UpdateMapReferences()
	if not gameClock then
		local gp = Workspace:FindFirstChild("GameProperties")
		if gp then
			gameClock = gp:FindFirstChild("GameClock")
		end
	end

	if not exitsFolder then
		local gk = Workspace:FindFirstChild("GameKeeper")
		if gk then
			exitsFolder = gk:FindFirstChild("Exits")
		end
	end
end

-- ==========================================
-- CLEANUP
-- ==========================================
local function CleanUpPhysics()
	if holdBodyPos then holdBodyPos:Destroy() holdBodyPos = nil end
	if holdGyro then holdGyro:Destroy() holdGyro = nil end
	if myPlatform then myPlatform:Destroy() myPlatform = nil end
	if bonusConnection then bonusConnection:Disconnect() bonusConnection = nil end

	if player.Character then
		local hum = player.Character:FindFirstChild("Humanoid")
		if hum then
			hum.PlatformStand = false
		end
	end
end

-- ==========================================
-- PLATFORM
-- ==========================================
local function ActivatePlatform(root)
	CleanUpPhysics()

	local targetPos = root.Position + Vector3.new(0, 60, 0)

	myPlatform = Instance.new("Part")
	myPlatform.Size = Vector3.new(50, 1, 50)
	myPlatform.Anchored = true
	myPlatform.CanCollide = true
	myPlatform.Transparency = 0.6
	myPlatform.Color = Color3.fromRGB(255, 255, 0)
	myPlatform.Material = Enum.Material.Neon
	myPlatform.CFrame = CFrame.new(targetPos)
	myPlatform.Parent = Workspace

	local hum = player.Character and player.Character:FindFirstChild("Humanoid")
	if hum then hum.PlatformStand = true end

	holdGyro = Instance.new("BodyGyro")
	holdGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	holdGyro.CFrame = CFrame.new()
	holdGyro.Parent = root

	holdBodyPos = Instance.new("BodyPosition")
	holdBodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	holdBodyPos.Position = targetPos + Vector3.new(0, 3, 0)
	holdBodyPos.Parent = root
end

-- ==========================================
-- BANANA LOOP (SAFE)
-- ==========================================
local function BananaLoop()
	task.wait(20)

	if not isScriptActive or currentMode ~= "Banana" then return end

	task.spawn(function()
		while isScriptActive and currentMode == "Banana" do

			local targets = {}

			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= player and p.Team and p.Team.Name == RUNNER_TEAM then
					if p.Character then
						local root = p.Character:FindFirstChild("HumanoidRootPart")
						local hum = p.Character:FindFirstChild("Humanoid")
						if root and hum and hum.Health > 0 then
							table.insert(targets, p)
						end
					end
				end
			end

			for _, target in ipairs(targets) do
				if not isScriptActive or currentMode ~= "Banana" then break end
				if not target.Team or target.Team.Name ~= RUNNER_TEAM then continue end

				local startTime = tick()
				while tick() - startTime < 2 do
					if not target.Team or target.Team.Name ~= RUNNER_TEAM then break end
					if not player.Character then break end

					local myRoot = player.Character:FindFirstChild("HumanoidRootPart")
					local tRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

					if myRoot and tRoot then
						myRoot.CFrame = tRoot.CFrame
						myRoot.AssemblyLinearVelocity = Vector3.zero
					else
						break
					end

					RunService.Heartbeat:Wait()
				end
			end

			task.wait(0.2)
		end
	end)
end

-- ==========================================
-- TEAM CONTROLLER
-- ==========================================
local function OnTeamChanged()
	if not isScriptActive then return end

	local team = player.Team
	local teamName = team and team.Name or "None"

	if teamName == "Lobby" or teamName == "Spectators" or teamName == "None" then
		currentMode = "Lobby"
		CleanUpPhysics()

	elseif teamName == RUNNER_TEAM then
		currentMode = "Runner"
		hasEscaped = false
		CleanUpPhysics()

		task.delay(8, function()
			if currentMode == "Runner" and isScriptActive then
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					ActivatePlatform(root)
				end
			end
		end)

	elseif teamName == BANANA_TEAM then
		currentMode = "Banana"
		CleanUpPhysics()
		BananaLoop()
	end
end

player:GetPropertyChangedSignal("Team"):Connect(OnTeamChanged)

-- ==========================================
-- MAIN LOOP
-- ==========================================
RunService.Stepped:Connect(function()
	if not isScriptActive then return end
	UpdateMapReferences()
end)

-- Toggle
toggleBtn.MouseButton1Click:Connect(function()
	isScriptActive = not isScriptActive

	if isScriptActive then
		toggleBtn.Text = "Stop"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
		OnTeamChanged()
	else
		toggleBtn.Text = "Start"
		toggleBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
		currentMode = "None"
		CleanUpPhysics()
	end
end)

player.CharacterAdded:Connect(function()
	if isScriptActive then
		CleanUpPhysics()
		task.delay(1, OnTeamChanged)
	end
end)
