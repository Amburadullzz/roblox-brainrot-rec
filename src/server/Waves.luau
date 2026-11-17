--[[
	Waves: the cringe tsunami, the one thing on the island that cannot be bought off.

	Every Config.Wave.interval seconds the wall rises at the north shore, the island gets
	Config.Wave.warnTime of countdown, and then it sweeps south across the whole map in
	Config.Wave.travelTime. A player standing in it is soaked and slowed; a player still carrying a
	brainrot when it reaches them loses it. So the loop is buy, run, place, and never get caught holding.

	Waves.forceWave brings the next one on demand, which is how a reviewer (or TOUR.json) reaches the
	tsunami screenshot without waiting out the interval.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.State)

local Waves = {}

local wall: BasePart? = nil
local crest: BasePart? = nil
local phase = "idle"
local phaseEnds = 0
local forceRequest: string? = nil

local function notify(player: Player, text: string, color: Color3?)
	local remote = ReplicatedStorage:FindFirstChild("Notify")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireClient(player, text, color or Color3.fromRGB(236, 240, 250))
	end
end

local function broadcast()
	local remote = ReplicatedStorage:FindFirstChild("Wave")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireAllClients({
			phase = phase,
			seconds = math.max(0, phaseEnds - os.clock()),
			z = if wall then wall.Position.Z else Config.Wave.startZ,
		})
	end
end

local function setWallZ(z: number)
	if wall then
		wall.CFrame = CFrame.new(0, 14, z)
	end
	if crest then
		crest.CFrame = CFrame.new(0, 30, z)
	end
end

--[[ Soak one player: slower feet for a few seconds, and the brainrot in their hands is gone. ]]
local function soak(record)
	local character = record.player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local before = humanoid.WalkSpeed
			humanoid.WalkSpeed = Config.Wave.wetSpeed
			task.delay(Config.Wave.wetTime, function()
				if humanoid.Parent then
					humanoid.WalkSpeed = before
				end
			end)
		end
	end
	if record.carried then
		local cast = Config.castById(record.carried.id)
		local name = if cast then cast.name else "brainrot"
		if record.carried.model then
			record.carried.model:Destroy()
		end
		record.carried = nil
		notify(record.player, string.format("The tide took your %s. Get the next one home faster.", name), Color3.fromRGB(120, 200, 255))
		State.publish(record)
	end
end

--[[ Who the wall is over right now: everyone still carrying and not standing on their own plot. ]]
local function sweepCheck(z: number)
	for _, player in Players:GetPlayers() do
		local record = State.get(player)
		local character = player.Character
		if character == nil then
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root == nil or not root:IsA("BasePart") then
			continue
		end
		local near = math.abs(root.Position.Z - z) < 6
		if not near then
			continue
		end
		local home = State.plotCenter(record.plot)
		local carryingHome = record.carried ~= nil and (root.Position - home).Magnitude < Config.PlotRadius
		if carryingHome then
			-- Safe: the wave breaks on the plot's fence and the catch stays.
			continue
		end
		soak(record)
	end
end

--[[ The wall's run south, from the first frame it moves to the last. ]]
local function sweep()
	phase = "sweeping"
	local started = os.clock()
	phaseEnds = started + Config.Wave.travelTime
	broadcast()
	while true do
		local alpha = (os.clock() - started) / Config.Wave.travelTime
		if alpha >= 1 then
			break
		end
		local z = Config.Wave.startZ + (Config.Wave.endZ - Config.Wave.startZ) * alpha
		setWallZ(z)
		sweepCheck(z)
		task.wait(0.12)
	end
	setWallZ(Config.Wave.startZ)
	phase = "idle"
	phaseEnds = os.clock() + Config.Wave.interval
	broadcast()
end

--[[ Run one wave from its warning to the far shore. ]]
local function runWave(skipWarning: boolean?)
	if not skipWarning then
		phase = "warning"
		phaseEnds = os.clock() + Config.Wave.warnTime
		broadcast()
		while os.clock() < phaseEnds do
			task.wait(0.5)
			broadcast()
		end
	end
	sweep()
end

--[[
	Bring the next wave on now: "warn" for the countdown and then the wall, "sweep" for the wall alone.
	Ignored while a wave is already running.
]]
function Waves.forceWave(mode: string?)
	if phase ~= "idle" then
		return false
	end
	forceRequest = if mode == "sweep" then "sweep" else "warn"
	return true
end

--[[ Where the wall is now, for a HUD or a test that wants to know. ]]
function Waves.status()
	return { phase = phase, seconds = math.max(0, phaseEnds - os.clock()), z = if wall then wall.Position.Z else Config.Wave.startZ }
end

function Waves.start()
	wall = workspace:FindFirstChild("TsunamiWall") :: BasePart?
	crest = workspace:FindFirstChild("TsunamiCrest") :: BasePart?
	setWallZ(Config.Wave.startZ)

	task.spawn(function()
		task.wait(20)
		while true do
			local request = forceRequest
			forceRequest = nil
			runWave(request == "sweep")
			local deadline = os.clock() + Config.Wave.interval
			while os.clock() < deadline and forceRequest == nil do
				task.wait(0.5)
			end
		end
	end)

	-- A player who is about to be caught is told once, in the same breath as the banner.
	local remote = ReplicatedStorage:FindFirstChild("Wave")
	if remote and remote:IsA("RemoteEvent") then
		remote.OnServerEvent:Connect(function() end)
	end
	print(string.format("[wave] every %s, %s of warning, %s to cross", Format.seconds(Config.Wave.interval), Format.seconds(Config.Wave.warnTime), Format.seconds(Config.Wave.travelTime)))
end

return Waves
