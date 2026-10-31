-- Bonk Your Friends Off! server. Starts every service in order.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local MapBuilder = require(script.MapBuilder)
local DataService = require(script.DataService)
local ShopService = require(script.ShopService)
local CosmeticService = require(script.CosmeticService)
local CombatService = require(script.CombatService)
local BotService = require(script.BotService)
local TutorialService = require(script.TutorialService)
local ProgressService = require(script.ProgressService)
local MatchService = require(script.MatchService)
local WorldService = require(script.WorldService)
local CommunityService = require(script.CommunityService)

-- Players' screens can't check who owns a private server, so share it
if game.PrivateServerId ~= "" then
	game:GetService("ReplicatedStorage"):SetAttribute("PrivateServerOwnerId", game.PrivateServerOwnerId)
end

-- Phones play sideways only (the player script sets this too)
game:GetService("StarterGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

MapBuilder.Build()

-- Services that react to players loading must start before DataService
ShopService.Start()
CosmeticService.Start()
CombatService.Start()
BotService.Start()
TutorialService.Start()
ProgressService.Start()
MatchService.Start()
WorldService.Start()
CommunityService.Start({
	gameId = "bonk",
	rewards = { "community_hammer", "community_title" },
	equip = { hammer = "community_hammer", title = "community_title" },
	rewardText = "Crew Hammer and Pandot Crew title",
})
DataService.Start()

-- Test helpers for Roblox Studio only (never in the live game). In the command
-- bar, with the Server view selected:
--   game.ServerStorage.BonkArenaTest:Invoke("coins", 5000)
--   game.ServerStorage.BonkArenaTest:Invoke("xp", 10000)
--   game.ServerStorage.BonkArenaTest:Invoke("match", 2) -- start a match on pad 2 now (you + bots)
--   game.ServerStorage.BonkArenaTest:Invoke("arena", "lava") -- every round on that arena ("random" to undo)
--   game.ServerStorage.BonkArenaTest:Invoke("damage", 120) -- set your damage %
if RunService:IsStudio() then
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local test = Instance.new("BindableFunction")
	test.Name = "BonkArenaTest"
	test.OnInvoke = function(command, amount)
		local player = Players:GetPlayers()[1]
		if command == "match" then
			MatchService.TestStart(amount or 2, player)
			return "ok"
		elseif command == "arena" then
			ReplicatedStorage:SetAttribute("ArenaPick", amount ~= "random" and amount or nil)
			return "ok"
		elseif command == "damage" then
			local entity = player and CombatService.GetByPlayer(player)
			if entity then
				CombatService.SetDamage(entity, amount)
			end
			return "ok"
		end
		for _, each in ipairs(Players:GetPlayers()) do
			DataService.Update(each, function(data)
				if command == "coins" then
					data.coins += amount
				elseif command == "xp" then
					data.xp += amount
				end
			end)
		end
		return "ok"
	end
	test.Parent = game:GetService("ServerStorage")
end

print("[Bonk Your Friends Off!] Server ready")
