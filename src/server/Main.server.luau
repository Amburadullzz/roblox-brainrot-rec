--[[
	Main: the server's bootstrap. It makes the remotes the client listens on, starts the five systems
	(shop, bases, waves, rebirth, and the pod animation), and answers the two actions the client can ask
	for by key: the padlock and the rebirth. Every system keeps its own file; this one only wires them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local Shop = require(script.Parent.Shop)
local Bases = require(script.Parent.Bases)
local Waves = require(script.Parent.Waves)
local Rebirth = require(script.Parent.Rebirth)
local Stealing = require(script.Parent.Stealing)

local function ensureRemote(name: string, className: string): Instance
	local existing = ReplicatedStorage:FindFirstChild(name)
	if existing then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = ReplicatedStorage
	return remote
end

ensureRemote("StateSync", "RemoteEvent")
ensureRemote("Notify", "RemoteEvent")
ensureRemote("Wave", "RemoteEvent")
local action = ensureRemote("Action", "RemoteEvent")

--[[ Put the owner's name on their plot's sign, so a raider knows whose fence to jump. ]]
local function namePlot(record)
	local sign = workspace:FindFirstChild(string.format("Plot%dSign", record.plot))
	if sign == nil or not sign:IsA("BasePart") then
		return
	end
	local old = sign:FindFirstChild("Owner")
	if old then
		old:Destroy()
	end
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Owner"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(300, 120)
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = record.player.DisplayName
	label.TextColor3 = Color3.fromRGB(64, 246, 224)
	label.TextScaled = true
	label.Parent = surface
end

local function welcome(player: Player)
	local record = State.get(player)
	namePlot(record)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, string.format(
			"Plot %d is yours. Buy at a pod, carry it home, put it down. The tide comes every %d seconds.",
			record.plot,
			Config.Wave.interval
		), Color3.fromRGB(64, 246, 224))
		remote:FireClient(player, string.format("Start cash: %s. Padlock: %s for %ds.", Format.cash(Config.StartCash), Format.cash(Config.Lock.cost), Config.Lock.duration), Color3.fromRGB(200, 208, 224))
	end
end

action.OnServerEvent:Connect(function(player: Player, name: string)
	local record = State.get(player)
	if name == "lock" then
		Bases.buyLock(record)
	elseif name == "rebirth" then
		Rebirth.perform(record)
	elseif name == "stealNearest" then
		Stealing.nearest(player)
	end
end)

Players.PlayerAdded:Connect(welcome)
for _, player in Players:GetPlayers() do
	welcome(player)
end

Shop.start()
Bases.start()
Rebirth.start()
Waves.start()
Shop.animate()

print(string.format("[%s] island up: %d pods, %d plots", Config.GameName, #Config.Cast, Config.PlotCount))
