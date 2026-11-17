--[[
	Shop: the twelve pods around the vault, one brainrot each, and the sale itself.

	A pod shows its brainrot turning on the pad and the price above it. Walking up and pressing E buys
	it: the cash leaves the wallet, a mutation is rolled, and the brainrot is welded over the buyer's
	head, where it earns nothing until it is put down on a base slot (Bases.luau does that half).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local CastModels = require(script.Parent.CastModels)

local Shop = {}

local random = Random.new()
local podModels: { [number]: Model } = {}
local spinning = false

local function notify(player: Player, text: string, color: Color3?)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text, color or Color3.fromRGB(236, 240, 250))
	end
end

--[[ The sign above a pod: the brainrot's name in its rarity's colour, and what it costs. ]]
local function signFor(pad: BasePart, entry, index: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PodSign"
	billboard.Size = UDim2.fromOffset(230, 74)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Adornee = pad
	billboard.Parent = pad

	local rarity = Config.rarityOf(entry)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.55)
	title.Font = Enum.Font.FredokaOne
	title.Text = entry.name
	title.TextColor3 = rarity.color
	title.TextStrokeTransparency = 0.35
	title.TextStrokeColor3 = Color3.fromRGB(8, 8, 12)
	title.TextScaled = true
	title.Parent = billboard

	local price = Instance.new("TextLabel")
	price.BackgroundTransparency = 1
	price.Position = UDim2.fromScale(0, 0.55)
	price.Size = UDim2.fromScale(1, 0.4)
	price.Font = Enum.Font.GothamBold
	price.Text = string.format("%s  ·  %s  ·  %s", entry.rarity, Format.cash(entry.cost), Format.rate(entry.income))
	price.TextColor3 = Color3.fromRGB(240, 244, 252)
	price.TextStrokeTransparency = 0.4
	price.TextStrokeColor3 = Color3.fromRGB(8, 8, 12)
	price.TextScaled = true
	price.Parent = billboard
end

--[[ Buy `entry` for `record`: the wallet check, the mutation roll, and the ride on the buyer's head. ]]
function Shop.purchase(record, entry): boolean
	local player = record.player
	if record.carried then
		notify(player, "Hands full: put the one you are carrying on your base first.", Color3.fromRGB(255, 196, 96))
		return false
	end
	if not State.spend(record, entry.cost) then
		notify(player, string.format("You need %s for the %s.", Format.cash(entry.cost), entry.name), Color3.fromRGB(255, 120, 120))
		return false
	end

	local mutation = Config.rollMutation(random)
	local model = CastModels.build(entry, mutation, true)
	model.Parent = workspace
	local character = player.Character
	if character == nil or not CastModels.attachTo(model, character) then
		model:Destroy()
		record.cash += entry.cost
		notify(player, "You need to be alive and standing to carry that.", Color3.fromRGB(255, 120, 120))
		return false
	end
	record.carried = { id = entry.id, mutation = mutation.id, model = model }

	local rarity = Config.rarityOf(entry)
	CastModels.burst(State.slotPosition(record.plot, 1), rarity.color)
	local rolled = if mutation.name ~= "" then string.format(" It rolled %s (x%s).", mutation.name, tostring(mutation.multiplier)) else ""
	notify(player, string.format("Caught a %s for %s.%s Carry it to your base.", entry.name, Format.cash(entry.cost), rolled), rarity.color)
	State.publish(record)
	return true
end

--[[ Wire every pod: its model, its sign, its prompt. ]]
function Shop.start()
	for index, entry in Config.Cast do
		local pad = workspace:FindFirstChild(string.format("PodPad%d", index))
		if pad == nil or not pad:IsA("BasePart") then
			continue
		end
		local model = CastModels.build(entry, nil, false)
		model.Parent = workspace
		CastModels.placeOn(model, pad.Position + Vector3.new(0, 1.4, 0))
		podModels[index] = model
		signFor(pad, entry, index)

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Buy"
		prompt.ActionText = "Buy " .. Format.cash(entry.cost)
		prompt.ObjectText = string.format("%s (%s)", entry.name, entry.rarity)
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			local record = State.get(player)
			Shop.purchase(record, entry)
		end)
	end
end

--[[ Turn the pods' brainrots so the bazaar looks alive from the spawn gate. ]]
function Shop.animate()
	if spinning then
		return
	end
	spinning = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		for index, model in podModels do
			local pad = workspace:FindFirstChild(string.format("PodPad%d", index))
			if pad and pad:IsA("BasePart") and model.Parent then
				local angle = elapsed * 0.8 + index
				model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 1.4 + math.sin(elapsed * 2 + index) * 0.25, 0))
					* CFrame.Angles(0, angle, 0))
			end
		end
	end)
end

return Shop
