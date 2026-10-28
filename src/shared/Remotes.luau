-- All the messages between server and players. The server creates them;
-- players wait for them to appear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"DataUpdate", -- server -> player: the player's full save data
	"Notify", -- server -> player: a toast message
	"OpenPanel", -- server -> player: open a menu (e.g. the shop)
	"Bonk", -- player -> server: swing the hammer
	"Dash", -- player -> server: I just dashed (for quests, the guide and effects)
	"Launch", -- server -> player: you got bonked, fly with this velocity
	"Effect", -- server -> everyone: show a hit, knockout or power-up effect
	"Announce", -- server -> player: big text in the middle of the screen
	"Matches", -- server -> everyone: the state of every match
}

local FUNCTIONS = {
	"Action", -- player -> server: buy or equip a cosmetic, pick an arena...
}

local Remotes = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

for _, name in ipairs(EVENTS) do
	Remotes[name] = folder:WaitForChild(name)
end
for _, name in ipairs(FUNCTIONS) do
	Remotes[name] = folder:WaitForChild(name)
end

return Remotes
