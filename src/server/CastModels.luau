--[[
	CastModels: builds the 3D body of a brainrot out of blocky parts, and moves that body between the
	three places it lives: standing in a pod, riding on a player's head, and sitting on a base slot.

	A brainrot's look comes from Config: two colours, one of five body plans, one silly accessory. The
	name and the money a second float above it on a BillboardGui, coloured by rarity, so a base reads at a
	glance from across the island.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local CastModels = {}

local BODY_PLANS = {
	blob = { torso = Vector3.new(3.6, 3.6, 3.6), head = Vector3.new(2.4, 2.4, 2.4), headY = 1.2, shape = Enum.PartType.Ball },
	tall = { torso = Vector3.new(2.8, 4.0, 2.4), head = Vector3.new(2.6, 2.6, 2.6), headY = 3.0, shape = Enum.PartType.Block },
	wide = { torso = Vector3.new(4.8, 2.6, 3.0), head = Vector3.new(2.2, 2.2, 2.2), headY = 1.9, shape = Enum.PartType.Block },
	orb = { torso = Vector3.new(4.2, 4.2, 4.2), head = Vector3.new(2.0, 2.0, 2.0), headY = 0.4, shape = Enum.PartType.Ball },
	bird = { torso = Vector3.new(2.4, 2.6, 4.4), head = Vector3.new(2.0, 2.0, 2.0), headY = 1.9, shape = Enum.PartType.Block },
}

local function makePart(model: Model, name: string, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = CFrame.new(offset)
	part.Color = color
	part.Shape = shape or Enum.PartType.Block
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

--[[ The accessory a brainrot wears, built around the head at `headY`. ]]
local function addAccessory(model: Model, kind: string, entry, headY: number)
	local shell = entry.body[1]
	local accent = entry.body[2]
	if kind == "hat" then
		makePart(model, "Hat", Vector3.new(3.0, 0.5, 3.0), Vector3.new(0, headY + 1.5, 0), accent)
		makePart(model, "HatTop", Vector3.new(1.8, 1.4, 1.8), Vector3.new(0, headY + 2.4, 0), shell)
	elseif kind == "spoon" then
		makePart(model, "SpoonHandle", Vector3.new(0.3, 3.2, 0.3), Vector3.new(1.9, headY + 0.4, 0), Color3.fromRGB(206, 210, 220), Enum.PartType.Cylinder)
		makePart(model, "SpoonBowl", Vector3.new(1.1, 0.5, 1.1), Vector3.new(1.9, headY + 2.1, 0), Color3.fromRGB(226, 230, 238), Enum.PartType.Ball)
	elseif kind == "wig" then
		makePart(model, "Wig", Vector3.new(3.4, 1.4, 3.4), Vector3.new(0, headY + 1.1, 0.2), shell)
		makePart(model, "WigCurl", Vector3.new(1.2, 1.2, 1.2), Vector3.new(-1.5, headY + 0.6, 1.2), accent, Enum.PartType.Ball)
	elseif kind == "horn" then
		makePart(model, "HornL", Vector3.new(0.5, 1.8, 0.5), Vector3.new(-0.8, headY + 1.5, 0), accent, Enum.PartType.Cylinder)
		makePart(model, "HornR", Vector3.new(0.5, 1.8, 0.5), Vector3.new(0.8, headY + 1.5, 0), accent, Enum.PartType.Cylinder)
	elseif kind == "crown" then
		makePart(model, "Crown", Vector3.new(2.8, 0.7, 2.8), Vector3.new(0, headY + 1.4, 0), Color3.fromRGB(255, 206, 64), Enum.PartType.Block, Enum.Material.Neon)
	elseif kind == "antenna" then
		makePart(model, "Antenna", Vector3.new(0.25, 1.8, 0.25), Vector3.new(0, headY + 1.6, 0), Color3.fromRGB(90, 96, 110), Enum.PartType.Cylinder)
		makePart(model, "AntennaTip", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, headY + 2.5, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
	elseif kind == "teeth" then
		makePart(model, "TeethTop", Vector3.new(2.0, 0.5, 0.4), Vector3.new(0, headY - 0.2, 1.1), Color3.fromRGB(252, 252, 248))
		makePart(model, "TeethBottom", Vector3.new(2.0, 0.5, 0.4), Vector3.new(0, headY - 0.9, 1.1), Color3.fromRGB(252, 252, 248))
	elseif kind == "wing" then
		makePart(model, "WingL", Vector3.new(2.6, 0.3, 1.6), Vector3.new(-2.0, 0.6, 0), accent)
		makePart(model, "WingR", Vector3.new(2.6, 0.3, 1.6), Vector3.new(2.0, 0.6, 0), accent)
	end
end

--[[
	A brainrot's model, built at the origin: `entry` a Config.Cast row, `mutation` a Config.Mutations row
	or nil. `label` false leaves the billboard off (a pod shows its own sign instead).
]]
function CastModels.build(entry, mutation, label: boolean?): Model
	local model = Instance.new("Model")
	model.Name = entry.id

	local plan = BODY_PLANS[entry.build] or BODY_PLANS.blob
	local shell = entry.body[1]
	local accent = entry.body[2]
	if mutation and mutation.color then
		shell = shell:Lerp(mutation.color, 0.55)
		accent = accent:Lerp(mutation.color, 0.35)
	end

	local torso = makePart(model, "Torso", plan.torso, Vector3.new(0, plan.torso.Y / 2, 0), shell, plan.shape)
	makePart(model, "Head", plan.head, Vector3.new(0, plan.headY + plan.head.Y / 2 + plan.torso.Y / 2, 0), accent, Enum.PartType.Block)
	local headY = plan.headY + plan.head.Y / 2 + plan.torso.Y / 2
	makePart(model, "EyeL", Vector3.new(0.45, 0.55, 0.2), Vector3.new(-0.55, headY + 0.2, plan.head.Z / 2 + 0.05), Color3.fromRGB(24, 24, 30))
	makePart(model, "EyeR", Vector3.new(0.45, 0.55, 0.2), Vector3.new(0.55, headY + 0.2, plan.head.Z / 2 + 0.05), Color3.fromRGB(24, 24, 30))
	makePart(model, "FootL", Vector3.new(0.9, 0.6, 1.2), Vector3.new(-0.9, 0.3, 0), accent)
	makePart(model, "FootR", Vector3.new(0.9, 0.6, 1.2), Vector3.new(0.9, 0.3, 0), accent)
	addAccessory(model, entry.extra, entry, headY)

	model.PrimaryPart = torso

	-- The parts hold together with welds, so the whole body moves when the primary part does.
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part ~= torso then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = torso
			weld.Part1 = part
			weld.Parent = part
		end
	end

	if label ~= false then
		CastModels.label(model, entry, mutation, Config.incomeOf(entry, mutation, 0))
	end
	return model
end

--[[ The floating name plate: the brainrot's name in its rarity's colour, and what it pays. ]]
function CastModels.label(model: Model, entry, mutation, income: number)
	local existing = model:FindFirstChild("NamePlate")
	if existing then
		existing:Destroy()
	end
	local torso = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if torso == nil then
		return
	end
	local rarity = Config.rarityOf(entry)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NamePlate"
	billboard.Size = UDim2.fromOffset(220, 64)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 140
	billboard.Adornee = torso
	billboard.Parent = torso

	local name = Instance.new("TextLabel")
	name.Name = "Title"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.62)
	name.Font = Enum.Font.FredokaOne
	name.Text = Config.displayName(entry, mutation)
	name.TextColor3 = rarity.color
	name.TextStrokeTransparency = 0.35
	name.TextStrokeColor3 = Color3.fromRGB(10, 10, 14)
	name.TextScaled = true
	name.Parent = billboard

	local rate = Instance.new("TextLabel")
	rate.Name = "Rate"
	rate.BackgroundTransparency = 1
	rate.Position = UDim2.fromScale(0, 0.6)
	rate.Size = UDim2.fromScale(1, 0.38)
	rate.Font = Enum.Font.GothamBold
	rate.Text = string.format("%s · %s", entry.rarity, Format.rate(income))
	rate.TextColor3 = Color3.fromRGB(236, 240, 250)
	rate.TextStrokeTransparency = 0.4
	rate.TextStrokeColor3 = Color3.fromRGB(10, 10, 14)
	rate.TextScaled = true
	rate.Parent = billboard
end

--[[ Set a model down in the world, standing on `position`. ]]
function CastModels.placeOn(model: Model, position: Vector3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	model:PivotTo(CFrame.new(position))
end

--[[ Ride on a character's head: every part unanchored, welded to the humanoid's head. ]]
function CastModels.attachTo(model: Model, character: Model): boolean
	local head = character:FindFirstChild("Head")
	local primary = model.PrimaryPart
	if head == nil or not head:IsA("BasePart") or primary == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local anchor = if root and root:IsA("BasePart") then root else head
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
		end
	end
	model:PivotTo(anchor.CFrame * CFrame.new(0, 2.6, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = anchor
	weld.Part1 = primary
	weld.Parent = primary
	return true
end

--[[ Take a carried brainrot off a character, and hand the model back. ]]
function CastModels.detachFrom(model: Model)
	local primary = model.PrimaryPart
	if primary then
		local weld = primary:FindFirstChild("CarryWeld")
		if weld then
			weld:Destroy()
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
end

--[[ A short burst of parts where a brainrot lands, so a purchase and a steal read as an event. ]]
function CastModels.burst(position: Vector3, color: Color3)
	local folder = Instance.new("Folder")
	folder.Name = "Burst"
	folder.Parent = workspace
	for index = 1, 10 do
		local spark = Instance.new("Part")
		spark.Size = Vector3.new(0.5, 0.5, 0.5)
		spark.Color = color
		spark.Material = Enum.Material.Neon
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.CFrame = CFrame.new(position + Vector3.new(
			math.random(-30, 30) / 10,
			math.random(0, 20) / 10,
			math.random(-30, 30) / 10
		))
		spark.Parent = folder
		task.delay(0.5, function()
			spark:Destroy()
		end)
	end
	task.delay(0.6, function()
		folder:Destroy()
	end)
end

return CastModels
