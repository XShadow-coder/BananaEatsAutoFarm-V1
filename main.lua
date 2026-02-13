-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

-- Player and Teams
local player = Players.LocalPlayer
local RUNNER_TEAM = "Runners"
local BANANA_TEAM = "Banana"
local MONEY_NAME = "Token"

-- Variables
local isScriptActive = false
local currentMode = "None"
local hasEscaped = false
local roundStarted = false
local myPlatform = nil
local magnetConnection = nil
local gameClock = nil

-- GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BananaFarmFinal"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

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

-- Hide UI
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 100, 0, 28)
hideBtn.Position = UDim2.new(1, -110, 0, 15)
hideBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
hideBtn.Text = "Hide UI"
hideBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 13
hideBtn.Parent = screenGui
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 8)

local uiVisible = true
hideBtn.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    mainFrame.Visible = uiVisible
    hideBtn.Text = uiVisible and "Hide UI" or "Show UI"
end)

-- Anti AFK
player.Idled:Connect(function()
    if isScriptActive then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- Update status label
local function UpdateStatus()
    if not isScriptActive then
        statusLabel.Text = "Status: Off"
        statusLabel.TextColor3 = Color3.fromRGB(255,255,255)
        return
    end

    if currentMode == "Lobby" then
        statusLabel.Text = "Status: Lobby (Waiting…)"
        statusLabel.TextColor3 = Color3.fromRGB(200,200,200)
        return
    end

    if currentMode == "Banana" then
        statusLabel.Text = "Status: Banana (Resetting…)"
        statusLabel.TextColor3 = Color3.fromRGB(255,120,0)
        return
    end

    if currentMode == "Runner" then
        if hasEscaped then
            statusLabel.Text = "Status: Escaped"
            statusLabel.TextColor3 = Color3.fromRGB(0,255,255)
        elseif roundStarted and gameClock and gameClock.Value <= 60 then
            statusLabel.Text = "Status: Escaping…"
            statusLabel.TextColor3 = Color3.fromRGB(255,255,0)
        else
            statusLabel.Text = "Status: Runner (Farming)"
            statusLabel.TextColor3 = Color3.fromRGB(0,255,0)
        end
    end
end

-- Cleanup
local function CleanUp()
    if magnetConnection then
        magnetConnection:Disconnect()
        magnetConnection = nil
    end
    if myPlatform then
        myPlatform:Destroy()
        myPlatform = nil
    end
    hasEscaped = false
    roundStarted = false
    UpdateStatus()
end

-- Get closest exit
local function getClosestExit()
    local gk = Workspace:FindFirstChild("GameKeeper")
    if not gk then return nil end
    
    local exits = gk:FindFirstChild("Exits")
    if not exits then return nil end
    
    local char = player.Character
    if not char then return nil end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    local closest, dist = nil, math.huge
    
    for _, v in pairs(exits:GetChildren()) do
        if v.Name == "EscapeDoor" then
            local part = v:FindFirstChild("Root") or v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (root.Position - part.Position).Magnitude
                if d < dist then
                    dist = d
                    closest = part
                end
            end
        end
    end
    
    return closest
end

-- Setup runner
local function SetupRunner()
    CleanUp()
    hasEscaped = false

    task.wait(3)

    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Create platform above map
    myPlatform = Instance.new("Part")
    myPlatform.Size = Vector3.new(50,1,50)
    myPlatform.Anchored = true
    myPlatform.CanCollide = true
    myPlatform.Transparency = 0.6
    myPlatform.Material = Enum.Material.Neon
    myPlatform.Color = Color3.fromRGB(255,255,0)
    myPlatform.CFrame = CFrame.new(root.Position + Vector3.new(0,60,0))
    myPlatform.Parent = Workspace

    -- Move player above platform
    local start = tick()
    while tick() - start < 1 do
        root.CFrame = myPlatform.CFrame + Vector3.new(0,3,0)
        root.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end

    local hum = player.Character:FindFirstChild("Humanoid")
    if hum then hum.PlatformStand = true end

    -- Start 7s round delay
    task.delay(7, function()
        if currentMode == "Runner" and isScriptActive then
            roundStarted = true
            UpdateStatus()
        end
    end)

    -- Magnet loop (every 0.5s)
    magnetConnection = RunService.Heartbeat:Connect(function()
        if not isScriptActive or currentMode ~= "Runner" then return end
        if tick() % 0.5 > 0.03 then return end
        
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == MONEY_NAME then
                local targetPos = myPlatform.Position + Vector3.new(0,3,0)
                if obj:IsA("BasePart") then
                    obj.CanCollide = false
                    obj.CFrame = CFrame.new(targetPos)
                end
            end
        end
    end)

    UpdateStatus()
end

local retryingEscape = false -- variabile di lock

-- Escape loop
RunService.Heartbeat:Connect(function()
	if not isScriptActive then return end
	if currentMode ~= "Runner" then return end
	if not roundStarted then return end
	if hasEscaped then return end
	if retryingEscape then return end

	if not gameClock then
		local gp = Workspace:FindFirstChild("GameProperties")
		if gp then gameClock = gp:FindFirstChild("GameClock") end
	end

	if not gameClock then return end

	if gameClock.Value <= 60 then
		UpdateStatus()
		local char = player.Character
		if not char then return end

		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end

		local target = getClosestExit()
		if not target then return end

		for _, v in pairs(char:GetDescendants()) do
			if v:IsA("BasePart") then
				v.CanCollide = false
			end
		end

		-- try to escape
		local start = tick()
		while tick() - start < 4 do
			root.CFrame = target.CFrame * CFrame.new(0,5,0)
			root.AssemblyLinearVelocity = Vector3.zero
			RunService.Heartbeat:Wait()
		end

		-- Check if Escape failed
		if (root.Position - target.Position).Magnitude > 10 then
			if not retryingEscape then
				retryingEscape = true
				print("Escape failed, recreating platform and retrying in 10 seconds...")
				SetupRunner() -- start magnet and platform
				task.delay(10, function()
					hasEscaped = false -- reset escape to retry
					retryingEscape = false
				end)
			end
		else
			hasEscaped = true
			UpdateStatus()
		end
	end
end)
			end
    end
end)

-- Team change handler
local function OnTeamChanged()
    if not isScriptActive then return end
    
    local teamName = player.Team and player.Team.Name or "None"
    
    if teamName == RUNNER_TEAM then
        currentMode = "Runner"
        SetupRunner()
        
    elseif teamName == BANANA_TEAM then
        currentMode = "Banana"
        CleanUp()
        
        task.wait(0.5)
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
        
    else
        currentMode = "Lobby"
        CleanUp()
    end
    
    UpdateStatus()
end

player:GetPropertyChangedSignal("Team"):Connect(OnTeamChanged)

-- Toggle main farm
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
        UpdateStatus()
    end
end)

player.CharacterAdded:Connect(function()
    if isScriptActive then
        task.delay(0.5, OnTeamChanged)
    end
end)
