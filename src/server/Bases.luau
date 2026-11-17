--[[
	Bases: the six slots of a player's plot, the money they pay, and the padlock.

	Putting a carried brainrot down is the moment it starts earning: the slot prompt only exists for the
	plot's owner while their hands are full. The income tick runs once a second for everyone, and the
	padlock (L) makes the base unstealable for a while, which is the only defence in the game.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)
local CastModels = require(script.Parent.CastModels)
local Stealing = require(script.Parent.Stealing)

local Bases = {}

local function notify(player: Player, text: string, color: Color3?)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text, color or Color3.fromRGB(236, 240, 250))
	end
end

--[[ Put the brainrot a player carries into a slot of their own base. ]]
function Bases.place(record, slot: number): boolean
	local carried = record.carried
	if carried == nil then
		return false
	end
	if State.placedIn(record, slot) then
		notify(record.player, "That slot already holds a brainrot.", Color3.fromRGB(255, 196, 96))
		return false
	end
	local entry = Config.castById(carried.id)
	if entry == nil then
		return false
	end
	local mutation = Config.Mutations[1]
	for _, candidate in Config.Mutations do
		if candidate.id == carried.mutation then
			mutation = candidate
			break
		end
	end

	local model = carried.model
	if model == nil then
		model = CastModels.build(entry, mutation, true)
		model.Parent = workspace
	end
	CastModels.detachFrom(model)
	local position = State.slotPosition(record.plot, slot)
	CastModels.placeOn(model, position)
	CastModels.label(model, entry, mutation, Config.incomeOf(entry, mutation, record.rebirths))

	table.insert(record.placed, { slot = slot, id = entry.id, mutation = mutation.id, model = model })
	record.carried = nil
	CastModels.burst(position, Config.rarityOf(entry).color)
	notify(record.player, string.format("%s is on slot %d, paying %s.", Config.displayName(entry, mutation), slot, Format.rate(Config.incomeOf(entry, mutation, record.rebirths))), Config.rarityOf(entry).color)
	Stealing.arm(record, record.placed[#record.placed])
	State.publish(record)
	return true
end

--[[ Buy the padlock: a while in which nobody can lift a brainrot off this base. ]]
function Bases.buyLock(record): boolean
	local now = os.clock()
	if record.lockUntil > now then
		notify(record.player, string.format("Your padlock already holds for %s.", Format.seconds(record.lockUntil - now)), Color3.fromRGB(255, 196, 96))
		return false
	end
	if not State.spend(record, Config.Lock.cost) then
		notify(record.player, string.format("A padlock costs %s.", Format.cash(Config.Lock.cost)), Color3.fromRGB(255, 120, 120))
		return false
	end
	record.lockUntil = now + Config.Lock.duration
	notify(record.player, string.format("Padlock on for %d seconds.", Config.Lock.duration), Color3.fromRGB(120, 226, 255))
	State.publish(record)
	return true
end

--[[ A player's hands empty when they die: the carried brainrot is lost with them. ]]
function Bases.watchCharacter(record)
	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid == nil or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.Died:Connect(function()
			if record.carried and record.carried.model then
				record.carried.model:Destroy()
			end
			record.carried = nil
			State.publish(record)
		end)
	end
	if record.player.Character then
		task.spawn(watch, record.player.Character)
	end
	record.player.CharacterAdded:Connect(watch)
end

--[[ The once-a-second money tick: every base pays, and every HUD refreshes. ]]
function Bases.tick()
	while true do
		task.wait(1)
		State.each(function(record)
			local income = State.income(record)
			if income > 0 then
				State.addCash(record, income)
			end
			State.publish(record)
		end)
	end
end

--[[ Wire the slot prompts of every plot, and the character watch of every player. ]]
function Bases.start()
	for plot = 1, Config.PlotCount do
		for slot = 1, Config.SlotsPerBase do
			local marker = workspace:FindFirstChild(string.format("Plot%dSlot%d", plot, slot))
			if marker == nil or not marker:IsA("BasePart") then
				continue
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "Place"
			prompt.ActionText = "Place brainrot"
			prompt.ObjectText = "Your base"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = marker
			prompt.Triggered:Connect(function(player)
				local record = State.get(player)
				if record.plot ~= plot then
					notify(player, "That is not your base. Yours is plot " .. tostring(record.plot) .. ".", Color3.fromRGB(255, 196, 96))
					return
				end
				Bases.place(record, slot)
			end)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		Bases.watchCharacter(State.get(player))
	end)
	for _, player in Players:GetPlayers() do
		Bases.watchCharacter(State.get(player))
	end
	task.spawn(Bases.tick)
end

return Bases
