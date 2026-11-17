--[[
	Config: every number and every character of BRAINROT BAZAAR in one table.

	The game is a brainrot collector in the genre Steal a Brainrot began: you buy an absurd little
	creature at the bazaar, carry it on your head to your own plot, and it pays you every second until
	the next tier is affordable. A tsunami sweeps the island on a timer and washes away whatever you are
	carrying, and anyone standing on your base can walk off with a brainrot unless your padlock is up.

	Server and client both read this module, so a price, a rate or a rarity colour is never written twice.
]]

local Config = {}

Config.GameName = "BRAINROT BAZAAR"
Config.Tagline = "Catch a brainrot. Carry it home. Cash it before the tide."

-- Economy ------------------------------------------------------------------

Config.StartCash = 60
Config.SlotsPerBase = 6
Config.PlotCount = 6
Config.PlotRadius = 26 -- how far from a plot's centre the owner still counts as home

-- The seven rungs of the ladder, weakest first.
Config.Rarities = {
	Common = { color = Color3.fromRGB(168, 172, 180), order = 1 },
	Uncommon = { color = Color3.fromRGB(96, 214, 108), order = 2 },
	Rare = { color = Color3.fromRGB(86, 152, 255), order = 3 },
	Epic = { color = Color3.fromRGB(186, 108, 255), order = 4 },
	Legendary = { color = Color3.fromRGB(255, 196, 64), order = 5 },
	Mythic = { color = Color3.fromRGB(255, 92, 92), order = 6 },
	Secret = { color = Color3.fromRGB(64, 246, 224), order = 7 },
}

--[[
	The cast. Each entry is one purchasable brainrot:
	  id       the entry's key in a saved base and in the shop's pod table
	  name     what the HUD and the model's billboard say
	  rarity   a key of Config.Rarities
	  income   money a second while it sits on a base
	  cost     what the pod charges for it
	  quirk    the line the shop shows when you walk up
	  body     the model's two colours: { shell, face }
	  build    how the model is put together: "blob", "tall", "wide", "orb" or "bird"
	  extra    the silly thing it wears: "hat", "spoon", "wig", "horn", "crown", "antenna", "teeth", "wing" or "none"
]]
Config.Cast = {
	{
		id = "puddle_goblin",
		name = "Puddle Goblin",
		rarity = "Common",
		income = 1,
		cost = 25,
		quirk = "It is 90% puddle. The other 10% is opinions.",
		body = { Color3.fromRGB(96, 158, 92), Color3.fromRGB(176, 214, 120) },
		build = "blob",
		extra = "none",
	},
	{
		id = "squishy_nork",
		name = "Squishy Nork",
		rarity = "Common",
		income = 2,
		cost = 45,
		quirk = "Squish it and it says a word that is not a word.",
		body = { Color3.fromRGB(232, 132, 168), Color3.fromRGB(255, 208, 224) },
		build = "blob",
		extra = "antenna",
	},
	{
		id = "toddler_spoon",
		name = "Toddler With A Spoon",
		rarity = "Uncommon",
		income = 5,
		cost = 110,
		quirk = "The spoon is not for eating. It is for leverage.",
		body = { Color3.fromRGB(255, 206, 122), Color3.fromRGB(74, 132, 210) },
		build = "tall",
		extra = "spoon",
	},
	{
		id = "waffle_frog",
		name = "Chonky Waffle Frog",
		rarity = "Uncommon",
		income = 9,
		cost = 220,
		quirk = "Ribs of syrup. Knees of butter. All frog.",
		body = { Color3.fromRGB(214, 160, 74), Color3.fromRGB(126, 200, 96) },
		build = "wide",
		extra = "none",
	},
	{
		id = "auntie_wig",
		name = "Auntie Bimbly's Wig",
		rarity = "Rare",
		income = 18,
		cost = 480,
		quirk = "Auntie Bimbly is not in it. She left in 1998.",
		body = { Color3.fromRGB(198, 112, 206), Color3.fromRGB(255, 236, 176) },
		build = "tall",
		extra = "wig",
	},
	{
		id = "sir_loin",
		name = "Sir Loin Of Beef",
		rarity = "Rare",
		income = 32,
		cost = 900,
		quirk = "Knighted for services to the grill. Still raw in the middle.",
		body = { Color3.fromRGB(186, 62, 66), Color3.fromRGB(248, 200, 168) },
		build = "wide",
		extra = "crown",
	},
	{
		id = "gronk",
		name = "Gronk The Unemployed",
		rarity = "Epic",
		income = 60,
		cost = 1800,
		quirk = "Has a CV. The CV says GRONK in 96 point font.",
		body = { Color3.fromRGB(122, 156, 232), Color3.fromRGB(52, 66, 112) },
		build = "tall",
		extra = "hat",
	},
	{
		id = "microwave_baby",
		name = "Microwave Baby",
		rarity = "Epic",
		income = 110,
		cost = 3600,
		quirk = "Beeps when it is done. It is never done.",
		body = { Color3.fromRGB(226, 228, 232), Color3.fromRGB(120, 124, 132) },
		build = "wide",
		extra = "antenna",
	},
	{
		id = "grandma_dentures",
		name = "Grandma Gex's Dentures",
		rarity = "Legendary",
		income = 220,
		cost = 7500,
		quirk = "They bite on their own schedule. The schedule is now.",
		body = { Color3.fromRGB(250, 244, 220), Color3.fromRGB(232, 96, 140) },
		build = "orb",
		extra = "teeth",
	},
	{
		id = "the_orb",
		name = "The Orb That Knows",
		rarity = "Legendary",
		income = 400,
		cost = 14000,
		quirk = "It knows what you did. It is not going to bring it up.",
		body = { Color3.fromRGB(96, 246, 240), Color3.fromRGB(28, 60, 96) },
		build = "orb",
		extra = "none",
	},
	{
		id = "pigeon_prophet",
		name = "Biblically Accurate Pigeon",
		rarity = "Mythic",
		income = 800,
		cost = 26000,
		quirk = "It has seen the bread at the end of the universe.",
		body = { Color3.fromRGB(184, 190, 204), Color3.fromRGB(255, 226, 128) },
		build = "bird",
		extra = "wing",
	},
	{
		id = "mosquito_god",
		name = "God Of Getting Bit By A Mosquito",
		rarity = "Secret",
		income = 1600,
		cost = 55000,
		quirk = "One bite. One itch. One eternity of it.",
		body = { Color3.fromRGB(255, 78, 138), Color3.fromRGB(38, 24, 44) },
		build = "orb",
		extra = "horn",
	},
}

-- Mutations: rolled when a brainrot leaves a pod, multiplying what it earns for good.
Config.Mutations = {
	{ id = "normal", name = "", multiplier = 1.0, chance = 55, color = nil },
	{ id = "shiny", name = "Shiny", multiplier = 1.75, chance = 22, color = Color3.fromRGB(130, 226, 255) },
	{ id = "golden", name = "Golden", multiplier = 2.5, chance = 13, color = Color3.fromRGB(255, 202, 64) },
	{ id = "radioactive", name = "Radioactive", multiplier = 3.2, chance = 7, color = Color3.fromRGB(126, 255, 96) },
	{ id = "cursed", name = "Cursed", multiplier = 4.5, chance = 3, color = Color3.fromRGB(162, 62, 220) },
}

-- The tsunami: it sweeps from the north shore to the south, and anything carried gets soaked.
Config.Wave = {
	interval = 105, -- seconds between one wave's end and the next one's warning
	warnTime = 14, -- the countdown before the wall starts moving
	travelTime = 16, -- seconds the wall takes to cross the island
	startZ = -205,
	endZ = 205,
	wetSpeed = 10, -- walk speed while soaked
	wetTime = 4,
}

-- A padlock blocks every steal from your base while it lasts.
Config.Lock = { cost = 320, duration = 45 }

-- Stealing: hold the prompt on someone else's brainrot, then carry it home.
Config.Steal = { holdTime = 1.6, cooldown = 18, reach = 14 }

-- Rebirth: give the whole base back for a permanent income multiplier.
Config.Rebirth = { baseCost = 9000, growth = 3.2, bonus = 0.25, max = 12 }

-- Shop ---------------------------------------------------------------------

--[[ The six pods around the vault. Pod n sells Config.Cast[2n-1] and Config.Cast[2n], so the ladder
	climbs the way the pods ring the bazaar. ]]
function Config.podFor(index: number)
	local first = (index - 1) * 2 + 1
	return Config.Cast[first], Config.Cast[first + 1]
end

function Config.castById(id: string)
	for _, entry in Config.Cast do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Config.rarityOf(entry)
	return Config.Rarities[entry.rarity] or Config.Rarities.Common
end

--[[ A mutation rolled by weight, `random` a Random object (the server's) or nil for math.random. ]]
function Config.rollMutation(random)
	local roll = if random then random:NextNumber() * 100 else math.random() * 100
	local seen = 0
	for _, mutation in Config.Mutations do
		seen += mutation.chance
		if roll <= seen then
			return mutation
		end
	end
	return Config.Mutations[1]
end

--[[ What one placed brainrot pays a second: its rate, its mutation, and the owner's rebirths. ]]
function Config.incomeOf(entry, mutation, rebirths: number)
	local base = entry.income * (mutation and mutation.multiplier or 1)
	return base * (1 + Config.Rebirth.bonus * (rebirths or 0))
end

function Config.rebirthCost(rebirths: number)
	return math.floor(Config.Rebirth.baseCost * Config.Rebirth.growth ^ (rebirths or 0))
end

function Config.displayName(entry, mutation)
	if mutation and mutation.name ~= "" then
		return mutation.name .. " " .. entry.name
	end
	return entry.name
end

return Config
