--[[
	Effects: the client's feel — a camera that shakes while the tide is over the island, and a cold blue
	wash on the screen while the player is soaked.

	The default Roblox camera owns the camera every frame, so the shake is bound at Camera priority plus
	one: it reads the camera the default scripts just placed and nudges it, then lets go.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local shakeUntil = 0
local shakeAmount = 0.45

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotEffects"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

-- The soaked wash: a cold full-screen tint that only shows while the player is slowed by water.
local soaked = Instance.new("Frame")
soaked.Name = "Soaked"
soaked.Size = UDim2.fromScale(1, 1)
soaked.BackgroundColor3 = Color3.fromRGB(40, 120, 200)
soaked.BackgroundTransparency = 1
soaked.BorderSizePixel = 0
soaked.Parent = gui

local soakLabel = Instance.new("TextLabel")
soakLabel.Name = "SoakedLabel"
soakLabel.AnchorPoint = Vector2.new(0.5, 1)
soakLabel.Position = UDim2.new(0.5, 0, 0.78, 0)
soakLabel.Size = UDim2.fromOffset(420, 34)
soakLabel.BackgroundTransparency = 1
soakLabel.Font = Enum.Font.FredokaOne
soakLabel.TextSize = 26
soakLabel.TextColor3 = Color3.fromRGB(210, 240, 255)
soakLabel.TextStrokeTransparency = 0.3
soakLabel.Text = "SOAKED"
soakLabel.Visible = false
soakLabel.Parent = gui

local waveRemote = ReplicatedStorage:WaitForChild("Wave")
waveRemote.OnClientEvent:Connect(function(info)
	if info.phase == "sweeping" then
		shakeUntil = os.clock() + (info.seconds or 16)
	end
end)

-- Soaked is read from the humanoid: the server slows a wet player, so the client shows it.
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid == nil or not humanoid:IsA("Humanoid") then
		return
	end
	task.spawn(function()
		while humanoid.Parent do
			local wet = humanoid.WalkSpeed < 20
			soaked.BackgroundTransparency = if wet then 0.82 else 1
			soakLabel.Visible = wet
			task.wait(0.2)
		end
		soaked.BackgroundTransparency = 1
		soakLabel.Visible = false
	end)
end

if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

RunService:BindToRenderStep("BrainrotShake", Enum.RenderPriority.Camera.Value + 1, function()
	if os.clock() >= shakeUntil then
		return
	end
	local current = workspace.CurrentCamera
	if current == nil then
		return
	end
	local offset = Vector3.new(
		(math.random() - 0.5) * shakeAmount,
		(math.random() - 0.5) * shakeAmount,
		0
	)
	current.CFrame = current.CFrame * CFrame.new(offset)
end)
