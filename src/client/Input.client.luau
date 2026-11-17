--[[
	Input: the three keys the HUD names, bound with ContextActionService.

	Roblox's default camera scripts take the arrow keys, so a UserInputService handler that skips
	gameProcessedEvent never sees them; ContextActionService binds above that and still lets the
	character walk with WASD. E is left to the ProximityPrompts on the pods, the base slots and the altar,
	which is what a player's hand already expects in this genre.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = ReplicatedStorage:WaitForChild("Action")

local function press(actionName: string)
	return function(_name: string, state: Enum.UserInputState)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		remote:FireServer(actionName)
		return Enum.ContextActionResult.Sink
	end
end

ContextActionService:BindAction("BrainrotPadlock", press("lock"), false, Enum.KeyCode.L)
ContextActionService:BindAction("BrainrotRebirth", press("rebirth"), false, Enum.KeyCode.R)
ContextActionService:BindAction("BrainrotSteal", press("stealNearest"), false, Enum.KeyCode.F)

-- Keep the actions alive through a respawn: a player who dies should not lose their keys.
local function rebind()
	ContextActionService:UnbindAction("BrainrotPadlock")
	ContextActionService:UnbindAction("BrainrotRebirth")
	ContextActionService:UnbindAction("BrainrotSteal")
	ContextActionService:BindAction("BrainrotPadlock", press("lock"), false, Enum.KeyCode.L)
	ContextActionService:BindAction("BrainrotRebirth", press("rebirth"), false, Enum.KeyCode.R)
	ContextActionService:BindAction("BrainrotSteal", press("stealNearest"), false, Enum.KeyCode.F)
end

local player = game:GetService("Players").LocalPlayer
player.CharacterAdded:Connect(function()
	task.wait(0.5)
	rebind()
end)
