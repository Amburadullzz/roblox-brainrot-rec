--[[
	Rebirth: the altar on the bazaar's south edge.

	Give the whole base back — every brainrot on it and every dollar in the wallet — and come back with a
	permanent +25% on everything the next base earns. The price climbs by Config.Rebirth.growth each time,
	so a rebirth is a decision about whether the ladder is worth climbing again from the bottom.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local CastModels = require(script.Parent.CastModels)

local Rebirth = {}

local function notify(player: Player, text: string, color: Color3?)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text, color or Color3.fromRGB(236, 240, 250))
	end
end

--[[ Give a base back: brainrots gone, wallet back to the starting cash, one more rebirth on the count. ]]
function Rebirth.perform(record): boolean
	if record.rebirths >= Config.Rebirth.max then
		notify(record.player, "That is every rebirth there is. The island bows to you.", Color3.fromRGB(64, 246, 224))
		return false
	end
	local cost = Config.rebirthCost(record.rebirths)
	if record.earned < cost then
		notify(record.player, string.format("A rebirth costs %s earned. You are at %s.", Format.cash(cost), Format.cash(record.earned)), Color3.fromRGB(255, 196, 96))
		return false
	end
	local lost = #record.placed
	State.clearBase(record)
	record.cash = Config.StartCash
	record.earned = 0
	record.rebirths += 1
	local multiplier = 1 + Config.Rebirth.bonus * record.rebirths
	CastModels.burst(State.plotCenter(record.plot) + Vector3.new(0, 6, 0), Color3.fromRGB(255, 206, 64))
	notify(record.player, string.format("REBIRTH %d: %d brainrots given back, everything now pays %s.", record.rebirths, lost, Format.multiplier(multiplier)), Color3.fromRGB(255, 206, 64))
	State.publish(record)
	return true
end

function Rebirth.start()
	local altar = workspace:FindFirstChild("RebirthAltar")
	if altar == nil or not altar:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Rebirth"
	prompt.ActionText = "Rebirth"
	prompt.ObjectText = "Give the base back for +25% income"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = altar
	prompt.Triggered:Connect(function(player)
		Rebirth.perform(State.get(player))
	end)
end

return Rebirth
