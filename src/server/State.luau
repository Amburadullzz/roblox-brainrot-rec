--[[
	State: the one place a player's game lives. Cash, what they have earned in total, their rebirth
	count, the six slots of their base, the brainrot they are carrying and their padlock are all here,
	and every other server module reads and writes them through this file. Nothing else keeps a copy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local State = {}

export type Placed = {
	slot: number,
	id: string,
	mutation: string,
	model: Model?,
}

export type Carried = {
	id: string,
	mutation: string,
	model: Model?,
}

export type Record = {
	player: Player,
	cash: number,
	earned: number,
	rebirths: number,
	plot: number,
	placed: { Placed },
	carried: Carried?,
	lockUntil: number,
	lastSteal: number,
	joinedAt: number,
}

local records: { [Player]: Record } = {}
local plotOwner: { [number]: Player } = {}

local function leaderstatsOf(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats") :: Folder?
	if folder then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = folder
	local income = Instance.new("IntValue")
	income.Name = "PerSecond"
	income.Parent = folder
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	return folder
end

--[[ The first plot nobody holds, so two players never share a base. ]]
local function takePlot(): number
	for index = 1, Config.PlotCount do
		if plotOwner[index] == nil then
			return index
		end
	end
	return 1
end

--[[ The record of a player, made on first use. ]]
function State.get(player: Player): Record
	local existing = records[player]
	if existing then
		return existing
	end
	local plot = takePlot()
	plotOwner[plot] = player
	local record: Record = {
		player = player,
		cash = Config.StartCash,
		earned = 0,
		rebirths = 0,
		plot = plot,
		placed = {},
		carried = nil,
		lockUntil = 0,
		lastSteal = 0,
		joinedAt = os.clock(),
	}
	records[player] = record
	leaderstatsOf(player)
	State.publish(record)
	return record
end

function State.plotOf(record: Record): number
	return record.plot
end

--[[ A plot's world centre, read from the deck the place ships with. ]]
function State.plotCenter(plot: number): Vector3
	local deck = workspace:FindFirstChild(string.format("Plot%dDeck", plot))
	if deck and deck:IsA("BasePart") then
		return deck.Position
	end
	return Vector3.zero
end

--[[ Where slot `slot` of a plot stands: the marker parts the place ships with, two rows of three. ]]
function State.slotPosition(plot: number, slot: number): Vector3
	local marker = workspace:FindFirstChild(string.format("Plot%dSlot%d", plot, slot))
	if marker and marker:IsA("BasePart") then
		return marker.Position + Vector3.new(0, 3.2, 0)
	end
	return State.plotCenter(plot)
end

function State.addCash(record: Record, amount: number)
	if amount <= 0 then
		return
	end
	record.cash += amount
	record.earned += amount
end

function State.spend(record: Record, amount: number): boolean
	if record.cash < amount then
		return false
	end
	record.cash -= amount
	return true
end

--[[ What the base pays a second: every placed brainrot's rate, mutation and rebirth bonus. ]]
function State.income(record: Record): number
	local total = 0
	for _, placed in record.placed do
		local entry = Config.castById(placed.id)
		if entry then
			local mutation = Config.Mutations[1]
			for _, candidate in Config.Mutations do
				if candidate.id == placed.mutation then
					mutation = candidate
					break
				end
			end
			total += Config.incomeOf(entry, mutation, record.rebirths)
		end
	end
	return total
end

--[[ The first free slot of a base, or nil when all six are full. ]]
function State.freeSlot(record: Record): number?
	for slot = 1, Config.SlotsPerBase do
		local taken = false
		for _, placed in record.placed do
			if placed.slot == slot then
				taken = true
				break
			end
		end
		if not taken then
			return slot
		end
	end
	return nil
end

--[[ The placed entry in a slot, if any. ]]
function State.placedIn(record: Record, slot: number): Placed?
	for _, placed in record.placed do
		if placed.slot == slot then
			return placed
		end
	end
	return nil
end

function State.removePlaced(record: Record, slot: number): Placed?
	for index, placed in record.placed do
		if placed.slot == slot then
			table.remove(record.placed, index)
			if placed.model then
				placed.model:Destroy()
			end
			return placed
		end
	end
	return nil
end

--[[ Empty a base of its brainrots, models and all; the rebirth altar and a reset both use it. ]]
function State.clearBase(record: Record)
	for _, placed in record.placed do
		if placed.model then
			placed.model:Destroy()
		end
	end
	table.clear(record.placed)
end

--[[ What the client is told: the numbers the HUD draws, never the models. ]]
function State.snapshot(record: Record)
	local placed = {}
	for _, entry in record.placed do
		local cast = Config.castById(entry.id)
		if cast then
			local mutation = Config.Mutations[1]
			for _, candidate in Config.Mutations do
				if candidate.id == entry.mutation then
					mutation = candidate
					break
				end
			end
			table.insert(placed, {
				slot = entry.slot,
				id = entry.id,
				name = Config.displayName(cast, mutation),
				rarity = cast.rarity,
				income = Config.incomeOf(cast, mutation, record.rebirths),
				model = entry.model,
			})
		end
	end
	local carried = nil
	if record.carried then
		local cast = Config.castById(record.carried.id)
		if cast then
			carried = { id = cast.id, name = cast.name, rarity = cast.rarity }
		end
	end
	return {
		cash = record.cash,
		earned = record.earned,
		income = State.income(record),
		rebirths = record.rebirths,
		plot = record.plot,
		placed = placed,
		carried = carried,
		lockUntil = record.lockUntil,
		nextRebirth = Config.rebirthCost(record.rebirths),
		slots = Config.SlotsPerBase,
	}
end

--[[ Push a record's numbers to its player, and its leaderstats. Called after every change worth showing. ]]
function State.publish(record: Record)
	local folder = leaderstatsOf(record.player)
	local cash = folder:FindFirstChild("Cash")
	local income = folder:FindFirstChild("PerSecond")
	local rebirths = folder:FindFirstChild("Rebirths")
	if cash and cash:IsA("IntValue") then
		cash.Value = math.floor(record.cash)
	end
	if income and income:IsA("IntValue") then
		income.Value = math.floor(State.income(record))
	end
	if rebirths and rebirths:IsA("IntValue") then
		rebirths.Value = record.rebirths
	end
	local remote = ReplicatedStorage:FindFirstChild("StateSync")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(record.player, State.snapshot(record))
	end
end

function State.forget(player: Player)
	local record = records[player]
	if record == nil then
		return
	end
	State.clearBase(record)
	if record.carried and record.carried.model then
		record.carried.model:Destroy()
	end
	if plotOwner[record.plot] == player then
		plotOwner[record.plot] = nil
	end
	records[player] = nil
end

function State.each(fn: (Record) -> ())
	for _, record in records do
		fn(record)
	end
end

Players.PlayerRemoving:Connect(State.forget)

return State
