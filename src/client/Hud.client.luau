--[[
	Hud: everything the player reads, drawn over the 3D world in one ScreenGui.

	Top middle is the wallet and what the base pays a second; top right is the rebirth count and its
	multiplier; the left column is the base's six slots, each row a brainrot's name in its rarity's colour
	and what it pays. The bottom bar names the keys. The wave banner sits under the wallet, so the one
	warning that matters is where the player is already looking, and the top-left corner is left empty
	because Roblox's own menu buttons live there.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TEXT = Color3.fromRGB(238, 242, 252)
local DIM = Color3.fromRGB(160, 172, 194)
local PANEL = Color3.fromRGB(16, 18, 28)
local ACCENT = Color3.fromRGB(64, 246, 224)

local function stroke(target: TextLabel, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(6, 8, 14)
	s.Thickness = thickness or 2
	s.Transparency = 0.25
	s.Parent = target
	return s
end

local function corner(frame: GuiObject, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = frame
	return c
end

local function label(parent: GuiObject, name: string, text: string, size: UDim2, position: UDim2, textSize: number, font: Enum.Font, color: Color3)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.Font = font
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	stroke(l)
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 5
gui.Parent = playerGui

-- Wallet, top middle.
local wallet = Instance.new("Frame")
wallet.Name = "Wallet"
wallet.AnchorPoint = Vector2.new(0.5, 0)
wallet.Position = UDim2.new(0.5, 0, 0, 12)
wallet.Size = UDim2.fromOffset(340, 92)
wallet.BackgroundColor3 = PANEL
wallet.BackgroundTransparency = 0.15
wallet.BorderSizePixel = 0
wallet.Parent = gui
corner(wallet, 16)

local cashLabel = label(wallet, "Cash", "$0", UDim2.new(1, -24, 0, 52), UDim2.fromOffset(12, 6), 44, Enum.Font.FredokaOne, TEXT)
cashLabel.TextXAlignment = Enum.TextXAlignment.Center

local rateLabel = label(wallet, "Rate", "$0/s", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 58), 18, Enum.Font.GothamBold, ACCENT)
rateLabel.TextXAlignment = Enum.TextXAlignment.Center

-- Rebirths, top right.
local rebirthPanel = Instance.new("Frame")
rebirthPanel.Name = "Rebirths"
rebirthPanel.AnchorPoint = Vector2.new(1, 0)
rebirthPanel.Position = UDim2.new(1, -18, 0, 12)
rebirthPanel.Size = UDim2.fromOffset(190, 64)
rebirthPanel.BackgroundColor3 = PANEL
rebirthPanel.BackgroundTransparency = 0.15
rebirthPanel.BorderSizePixel = 0
rebirthPanel.Parent = gui
corner(rebirthPanel, 14)

local rebirthLabel = label(rebirthPanel, "Count", "REBIRTH 0", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(10, 6), 18, Enum.Font.FredokaOne, Color3.fromRGB(255, 206, 64))
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Center
local multLabel = label(rebirthPanel, "Multiplier", "x1.00 income", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 34), 15, Enum.Font.GothamBold, DIM)
multLabel.TextXAlignment = Enum.TextXAlignment.Center

-- The base's six slots, down the left side (clear of the menu corner).
local basePanel = Instance.new("Frame")
basePanel.Name = "Base"
basePanel.Position = UDim2.fromOffset(14, 150)
basePanel.Size = UDim2.fromOffset(292, 300)
basePanel.BackgroundColor3 = PANEL
basePanel.BackgroundTransparency = 0.25
basePanel.BorderSizePixel = 0
basePanel.Parent = gui
corner(basePanel, 14)

local baseTitle = label(basePanel, "Title", "YOUR BASE  0/6", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(12, 8), 16, Enum.Font.FredokaOne, ACCENT)

local rows = {}
for slot = 1, Config.SlotsPerBase do
	local row = Instance.new("Frame")
	row.Name = "Slot" .. slot
	row.Position = UDim2.fromOffset(8, 36 + (slot - 1) * 42)
	row.Size = UDim2.new(1, -16, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(28, 32, 46)
	row.BackgroundTransparency = 0.35
	row.BorderSizePixel = 0
	row.Parent = basePanel
	corner(row, 8)
	local nameLabel = label(row, "Name", "— empty —", UDim2.new(1, -90, 1, 0), UDim2.fromOffset(10, 0), 15, Enum.Font.GothamBold, DIM)
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	local rate = label(row, "Rate", "", UDim2.fromOffset(78, 38), UDim2.new(1, -84, 0, 0), 14, Enum.Font.GothamBold, ACCENT)
	rate.TextXAlignment = Enum.TextXAlignment.Right
	rate.TextYAlignment = Enum.TextYAlignment.Center
	rows[slot] = { frame = row, name = nameLabel, rate = rate }
end

-- What you are carrying: the one line that tells a player to run.
local carryLabel = Instance.new("TextLabel")
carryLabel.Name = "Carrying"
carryLabel.AnchorPoint = Vector2.new(0.5, 1)
carryLabel.Position = UDim2.new(0.5, 0, 1, -104)
carryLabel.Size = UDim2.fromOffset(560, 44)
carryLabel.BackgroundColor3 = Color3.fromRGB(26, 30, 44)
carryLabel.BackgroundTransparency = 0.1
carryLabel.BorderSizePixel = 0
carryLabel.Font = Enum.Font.FredokaOne
carryLabel.TextSize = 24
carryLabel.TextColor3 = Color3.fromRGB(255, 226, 128)
carryLabel.Text = ""
carryLabel.Visible = false
carryLabel.Parent = gui
corner(carryLabel, 12)
stroke(carryLabel)

-- The keys, bottom middle.
local hintBar = Instance.new("Frame")
hintBar.Name = "Keys"
hintBar.AnchorPoint = Vector2.new(0.5, 1)
hintBar.Position = UDim2.new(0.5, 0, 1, -14)
hintBar.Size = UDim2.fromOffset(660, 38)
hintBar.BackgroundColor3 = PANEL
hintBar.BackgroundTransparency = 0.2
hintBar.BorderSizePixel = 0
hintBar.Parent = gui
corner(hintBar, 10)

local hintLabel = label(hintBar, "Hint", "[E] buy · place   [L] padlock   [R] rebirth   [F] steal", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 16, Enum.Font.GothamBold, TEXT)
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.TextYAlignment = Enum.TextYAlignment.Center

-- The wave: countdown, then the tide itself.
local waveBanner = Instance.new("TextLabel")
waveBanner.Name = "Wave"
waveBanner.AnchorPoint = Vector2.new(0.5, 0)
waveBanner.Position = UDim2.new(0.5, 0, 0, 112)
waveBanner.Size = UDim2.fromOffset(560, 46)
waveBanner.BackgroundColor3 = Color3.fromRGB(120, 24, 30)
waveBanner.BackgroundTransparency = 0.1
waveBanner.BorderSizePixel = 0
waveBanner.Font = Enum.Font.FredokaOne
waveBanner.TextSize = 24
waveBanner.TextColor3 = Color3.fromRGB(255, 236, 236)
waveBanner.Text = ""
waveBanner.Visible = false
waveBanner.Parent = gui
corner(waveBanner, 12)
stroke(waveBanner)

-- Toasts: what the server just told you, newest at the bottom.
local toastArea = Instance.new("Frame")
toastArea.Name = "Toasts"
toastArea.AnchorPoint = Vector2.new(0, 1)
toastArea.Position = UDim2.new(0, 14, 1, -64)
toastArea.Size = UDim2.fromOffset(430, 240)
toastArea.BackgroundTransparency = 1
toastArea.Parent = gui

local toasts = {}

local function toast(text: string, color: Color3)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(430, 34)
	frame.BackgroundColor3 = Color3.fromRGB(22, 26, 38)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Parent = toastArea
	corner(frame, 8)

	local text_ = label(frame, "Text", text, UDim2.new(1, -16, 1, 0), UDim2.fromOffset(8, 0), 14, Enum.Font.GothamBold, color)
	text_.TextYAlignment = Enum.TextYAlignment.Center

	table.insert(toasts, text_)
	for index, existing in toasts do
		local parent = existing.Parent
		if parent then
			parent.Position = UDim2.fromOffset(0, (index - 1) * 40)
		end
	end
	if #toasts > 5 then
		local oldest = table.remove(toasts, 1)
		if oldest and oldest.Parent then
			oldest.Parent:Destroy()
		end
	end
	task.delay(5, function()
		TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(text_, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		frame:Destroy()
	end)
end

-- The title card: the game's name over its own island, until the player clicks in.
local titleScreen = Instance.new("Frame")
titleScreen.Name = "TitleScreen"
titleScreen.Size = UDim2.fromScale(1, 1)
titleScreen.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
titleScreen.BackgroundTransparency = 0.25
titleScreen.BorderSizePixel = 0
titleScreen.Parent = gui

local titleName = label(titleScreen, "Name", Config.GameName, UDim2.new(1, 0, 0, 96), UDim2.new(0, 0, 0.3, 0), 78, Enum.Font.FredokaOne, Color3.fromRGB(255, 226, 128))
titleName.TextXAlignment = Enum.TextXAlignment.Center
titleName.TextStrokeTransparency = 0
titleName.TextStrokeColor3 = Color3.fromRGB(20, 14, 6)

local titleTag = label(titleScreen, "Tagline", Config.Tagline, UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0.3, 104), 24, Enum.Font.GothamBold, TEXT)
titleTag.TextXAlignment = Enum.TextXAlignment.Center

local playButton = Instance.new("TextButton")
playButton.Name = "Play"
playButton.AnchorPoint = Vector2.new(0.5, 0)
playButton.Position = UDim2.new(0.5, 0, 0.3, 168)
playButton.Size = UDim2.fromOffset(300, 62)
playButton.BackgroundColor3 = ACCENT
playButton.BorderSizePixel = 0
playButton.Font = Enum.Font.FredokaOne
playButton.TextSize = 30
playButton.TextColor3 = Color3.fromRGB(8, 16, 20)
playButton.Text = "CLICK TO PLAY"
playButton.Parent = titleScreen
corner(playButton, 14)

local controls = label(titleScreen, "Controls", "E buy at a pod · E place on your base · L padlock · R rebirth · F steal a neighbour's brainrot", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.3, 246), 18, Enum.Font.Gotham, DIM)
controls.TextXAlignment = Enum.TextXAlignment.Center

local started = false

local function startGame()
	if started then
		return
	end
	started = true
	local info = TweenInfo.new(0.6)
	TweenService:Create(titleScreen, info, { BackgroundTransparency = 1 }):Play()
	for _, child in titleScreen:GetChildren() do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			TweenService:Create(child, info, { TextTransparency = 1 }):Play()
		end
	end
	task.wait(0.65)
	titleScreen.Visible = false
end

playButton.MouseButton1Click:Connect(startGame)

-- Live state -----------------------------------------------------------------

local function render(snapshot)
	cashLabel.Text = Format.cash(snapshot.cash)
	rateLabel.Text = Format.rate(snapshot.income) .. "  ·  plot " .. tostring(snapshot.plot)
	rebirthLabel.Text = "REBIRTH " .. tostring(snapshot.rebirths)
	multLabel.Text = Format.multiplier(1 + Config.Rebirth.bonus * snapshot.rebirths) .. " income  ·  next " .. Format.cash(snapshot.nextRebirth)

	local placedBySlot = {}
	for _, entry in snapshot.placed do
		placedBySlot[entry.slot] = entry
	end
	for slot = 1, Config.SlotsPerBase do
		local row = rows[slot]
		local entry = placedBySlot[slot]
		if entry then
			local rarity = Config.Rarities[entry.rarity] or Config.Rarities.Common
			row.name.Text = string.format("%d. %s", slot, entry.name)
			row.name.TextColor3 = rarity.color
			row.rate.Text = Format.rate(entry.income)
			row.rate.TextColor3 = ACCENT
			row.frame.BackgroundTransparency = 0.2
		else
			row.name.Text = string.format("%d. — empty —", slot)
			row.name.TextColor3 = DIM
			row.rate.Text = ""
			row.frame.BackgroundTransparency = 0.55
		end
	end
	baseTitle.Text = string.format("YOUR BASE  %d/%d", #snapshot.placed, snapshot.slots)

	if snapshot.carried then
		local rarity = Config.Rarities[snapshot.carried.rarity] or Config.Rarities.Common
		carryLabel.Text = string.format("CARRYING  %s  —  RUN IT HOME", snapshot.carried.name)
		carryLabel.TextColor3 = rarity.color
		carryLabel.Visible = true
	else
		carryLabel.Visible = false
	end

	if snapshot.lockUntil and snapshot.lockUntil > os.clock() then
		hintLabel.Text = string.format("[E] buy · place   [L] padlock (%ds)   [R] rebirth   [F] steal", math.floor(snapshot.lockUntil - os.clock()))
	else
		hintLabel.Text = "[E] buy · place   [L] padlock   [R] rebirth   [F] steal"
	end
end

local stateRemote = ReplicatedStorage:WaitForChild("StateSync")
stateRemote.OnClientEvent:Connect(render)

local notifyRemote = ReplicatedStorage:WaitForChild("Notify")
notifyRemote.OnClientEvent:Connect(function(text: string, color: Color3?)
	toast(text, color or TEXT)
end)

local waveRemote = ReplicatedStorage:WaitForChild("Wave")
waveRemote.OnClientEvent:Connect(function(info)
	if info.phase == "warning" then
		waveBanner.Visible = true
		waveBanner.BackgroundColor3 = Color3.fromRGB(120, 24, 30)
		waveBanner.Text = string.format("TSUNAMI IN %s — GET HOME", Format.seconds(info.seconds))
	elseif info.phase == "sweeping" then
		waveBanner.Visible = true
		waveBanner.BackgroundColor3 = Color3.fromRGB(24, 96, 150)
		waveBanner.Text = "THE TIDE IS HERE — HOLD ON TO NOTHING"
	else
		waveBanner.Visible = false
	end
end)

-- The title card goes away on the first input too, so nobody is stuck behind it.
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
		startGame()
	end
end)
