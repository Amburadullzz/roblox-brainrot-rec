--[[
	Stealing: the threat that makes a base worth guarding.

	Every brainrot standing on a base carries a prompt that only other players can use: hold it for
	Config.Steal.holdTime and the brainrot lifts off the base and onto the thief's head, where it must be
	carried to the thief's own plot and put down before it earns anything. A padlock, a cooldown and the
	owner's own reach are the three things that stop it.

	F does the same thing without aiming: Stealing.nearest lifts the closest brainrot within reach, so a
	player being robbed can snatch something back on the run.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local CastModels = require(script.Parent.CastModels)

local Stealing = {}

local function notify(player: Player, text: string, color: Color3?)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text, color or Color3.fromRGB(236, 240, 250))
	end
end

--[[ Lift `placed` off `owner`'s base and onto `thiefPlayer`'s head, or say why not. ]]
function Stealing.attempt(thiefPlayer: Player, owner, placed): boolean
	if thiefPlayer == owner.player then
		notify(thiefPlayer, "That one is yours. Leave it alone.", Color3.fromRGB(255, 196, 96))
		return false
	end
	local now = os.clock()
	local thief = State.get(thiefPlayer)
	if thief.carried then
		notify(thiefPlayer, "Hands full: put the one you are carrying down first.", Color3.fromRGB(255, 196, 96))
		return false
	end
	if owner.lockUntil > now then
		notify(thiefPlayer, string.format("That base is padlocked for %s.", Format.seconds(owner.lockUntil - now)), Color3.fromRGB(255, 120, 120))
		return false
	end
	if now - thief.lastSteal < Config.Steal.cooldown then
		notify(thiefPlayer, string.format("Catch your breath: %s until you can steal again.", Format.seconds(Config.Steal.cooldown - (now - thief.lastSteal))), Color3.fromRGB(255, 196, 96))
		return false
	end

	local entry = Config.castById(placed.id)
	local taken = State.removePlaced(owner, placed.slot)
	if entry == nil or taken == nil or taken.model == nil then
		return false
	end
	local character = thiefPlayer.Character
	if character == nil or not CastModels.attachTo(taken.model, character) then
		-- Nowhere to carry it: it goes back on the base it came from.
		table.insert(owner.placed, taken)
		CastModels.placeOn(taken.model, State.slotPosition(owner.plot, taken.slot))
		notify(thiefPlayer, "You dropped it. It is back on their base.", Color3.fromRGB(255, 120, 120))
		return false
	end

	thief.carried = { id = taken.id, mutation = taken.mutation, model = taken.model }
	thief.lastSteal = now
	notify(thiefPlayer, string.format("You lifted a %s. Run it home to your base.", entry.name), Config.rarityOf(entry).color)
	notify(owner.player, string.format("%s just stole your %s. Steal one back or lock the base.", thiefPlayer.DisplayName, entry.name), Color3.fromRGB(255, 120, 120))
	State.publish(owner)
	State.publish(thief)
	return true
end

--[[ The closest brainrot on somebody else's base, within Config.Steal.reach of the thief. ]]
function Stealing.nearest(thiefPlayer: Player): boolean
	local character = thiefPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return false
	end
	local thief = State.get(thiefPlayer)
	local bestOwner = nil
	local bestPlaced = nil
	local bestDistance = Config.Steal.reach
	State.each(function(record)
		if record.player == thiefPlayer then
			return
		end
		for _, placed in record.placed do
			if placed.model == nil or placed.model.PrimaryPart == nil then
				continue
			end
			local distance = (placed.model.PrimaryPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestOwner = record
				bestPlaced = placed
			end
		end
	end)
	if bestOwner == nil or bestPlaced == nil then
		notify(thiefPlayer, "Nothing to steal within reach. Stand closer to a base.", Color3.fromRGB(255, 196, 96))
		return false
	end
	if thief.carried then
		notify(thiefPlayer, "Hands full: put the one you are carrying down first.", Color3.fromRGB(255, 196, 96))
		return false
	end
	return Stealing.attempt(thiefPlayer, bestOwner, bestPlaced)
end

--[[ The moment a brainrot lands on a base, its steal prompt goes on. ]]
function Stealing.arm(owner, placed)
	local model = placed.model
	if model == nil or model.PrimaryPart == nil then
		return
	end
	local entry = Config.castById(placed.id)
	if entry == nil then
		return
	end
	local old = model.PrimaryPart:FindFirstChild("Steal")
	if old then
		old:Destroy()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Steal"
	prompt.ActionText = "Steal"
	prompt.ObjectText = string.format("%s (%s)", entry.name, entry.rarity)
	prompt.HoldDuration = Config.Steal.holdTime
	prompt.MaxActivationDistance = Config.Steal.reach
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart

	prompt.Triggered:Connect(function(thiefPlayer)
		Stealing.attempt(thiefPlayer, owner, placed)
	end)
end

return Stealing
