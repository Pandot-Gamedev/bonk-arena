-- Coins, XP, levels, daily quests and the daily login reward, plus the menu
-- buttons players press (all go through the "Action" remote): buying cosmetics
-- with coins, equipping them, and picking the arena in a private server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Cosmetics = require(Shared.Cosmetics)
local Arenas = require(Shared.Arenas)
local Quests = require(Shared.Quests)
local Level = require(Shared.Level)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local ProgressService = {}

local function notify(player, text, kind)
	Remotes.Notify:FireClient(player, text, kind)
end

local function refreshQuests(player, data)
	local today = Quests.Today(os.time())
	if data.quests.day ~= today then
		data.quests.day = today
		data.quests.list = Quests.Generate(player.UserId, today)
	end
end

-- Adds XP and pays the coin reward for every level reached. Call inside DataService.Update.
local function addXp(player, data, amount)
	data.xp += amount
	local level = Level.FromXp(data.xp)
	local reached = {}
	while data.levelRewards < level do
		data.levelRewards += 1
		local reward = data.levelRewards * Level.CoinsPerLevel
		data.coins += reward
		data.totalEarned += reward
		table.insert(reached, { level = data.levelRewards, coins = reward })
	end
	for _, entry in ipairs(reached) do
		task.defer(notify, player, string.format("Level %d! +%s coins", entry.level, Format.Number(entry.coins)), "rare")
	end
end

-- Adds to the daily quests. Call inside DataService.Update.
local function addQuestProgress(player, data, stats)
	refreshQuests(player, data)
	for _, entry in ipairs(data.quests.list) do
		local quest = Quests.ById[entry.id]
		if quest and not entry.done then
			entry.progress = math.min(entry.goal, entry.progress + (stats[quest.stat] or 0))
			if entry.progress >= entry.goal then
				entry.done = true
				data.coins += quest.coins
				data.totalEarned += quest.coins
				addXp(player, data, math.floor(quest.coins * Quests.XpShare))
				task.defer(notify, player, string.format("Quest done: %s! +%d coins", Quests.Text(entry), quest.coins), "success")
			end
		end
	end
end

-- After a match: result = { coins, xp, stats = { matches, wins, rounds, kos, bonks, powerups, round_<arena> }, won }
function ProgressService.AddMatchResult(player, result)
	if not DataService.IsLoaded(player) then
		return
	end
	local coins = result.coins
	if ShopService.HasPass(player, "VIP") then
		coins = math.floor(coins * (1 + Config.VipCoinBonus))
	end
	DataService.Update(player, function(data)
		data.coins += coins
		data.totalEarned += coins
		for key, value in pairs(result.stats) do
			if data.stats[key] ~= nil then
				data.stats[key] += value
			end
		end
		local week = Quests.Week(os.time())
		if data.weekly.week ~= week then
			data.weekly.week = week
			data.weekly.wins = 0
		end
		data.weekly.wins += result.stats.wins or 0
		addXp(player, data, result.xp)
		addQuestProgress(player, data, result.stats)
	end)
	notify(player, string.format("%s +%s coins, +%d XP", result.won and "You won!" or "Good match!", Format.Number(coins), result.xp), "coins")
end

------------------------------------------------------------------ Actions
local function buyCosmetic(player, itemId)
	local item = Cosmetics.ById[itemId or ""]
	local data = DataService.Get(player)
	if not item or not data then
		return false, "Unknown item"
	end
	if item.source ~= "coins" then
		return false, "That one can't be bought with coins"
	end
	if data.cosmetics.owned[item.id] then
		return false, "You already have it"
	end
	if data.coins < item.price then
		return false, string.format("You need %s more coins", Format.Number(item.price - data.coins))
	end
	DataService.Update(player, function(saved)
		saved.coins -= item.price
		saved.cosmetics.owned[item.id] = true
		saved.cosmetics.equipped[item.kind] = item.id
	end)
	notify(player, "You got " .. item.name .. "! It's equipped.", "success")
	return true
end

local function equipCosmetic(player, itemId)
	local item = Cosmetics.ById[itemId or ""]
	local data = DataService.Get(player)
	if not item or not data then
		return false, "Unknown item"
	end
	if not Cosmetics.Owns(data, item, ShopService.HasPass(player, "VIP")) then
		return false, "You don't own that yet"
	end
	DataService.Update(player, function(saved)
		if saved.cosmetics.equipped[item.kind] == item.id and not Cosmetics.Defaults[item.kind] then
			saved.cosmetics.equipped[item.kind] = nil -- pressing again takes a title or trail off
		else
			saved.cosmetics.equipped[item.kind] = item.id
		end
	end)
	return true
end

-- In a private server, its owner picks which arena every round uses
local function pickArena(player, arenaId)
	local isOwner = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == player.UserId
	if not isOwner and not RunService:IsStudio() then
		return false, "Only the owner of a private server can pick the arena"
	end
	if arenaId == "random" then
		ReplicatedStorage:SetAttribute("ArenaPick", nil)
		notify(player, "Arenas are random again.", "info")
		return true
	end
	local arena = Arenas.ById[arenaId or ""]
	if not arena then
		return false, "Unknown arena"
	end
	ReplicatedStorage:SetAttribute("ArenaPick", arena.id)
	for _, other in ipairs(Players:GetPlayers()) do
		notify(other, "Every round is now on " .. arena.name .. ".", "info")
	end
	return true
end

local function giveDailyReward(player, data)
	local today = math.floor(os.time() / 86400)
	if data.lastDailyDay == today then
		return
	end
	if data.lastDailyDay == today - 1 then
		data.dailyStreak += 1
	else
		data.dailyStreak = 1
	end
	data.lastDailyDay = today
	local day = math.min(data.dailyStreak, Config.DailyStreakCap)
	local reward = Config.DailyRewardBase * day
	data.coins += reward
	data.totalEarned += reward
	task.spawn(function()
		if DataService.WaitFor(player) then
			notify(player, string.format("Daily reward (day %d streak): +%s coins! Come back tomorrow for more.", data.dailyStreak, Format.Number(reward)), "coins")
		end
	end)
end

local actions = {
	BuyCosmetic = buyCosmetic,
	EquipCosmetic = equipCosmetic,
	PickArena = pickArena,
}

-- Lets other services add actions (the guide's reset, for example)
function ProgressService.AddAction(name, handler)
	actions[name] = handler
end

function ProgressService.Start()
	DataService.OnLoaded(function(player, data)
		giveDailyReward(player, data)
		refreshQuests(player, data)
	end)

	-- New quests at midnight UTC for players who are online
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data and data.quests.day ~= Quests.Today(os.time()) then
					DataService.Update(player, function(saved)
						refreshQuests(player, saved)
					end)
				end
			end
		end
	end)

	Remotes.Action.OnServerInvoke = function(player, actionName, argument)
		local action = actions[actionName]
		if type(actionName) ~= "string" or not action then
			return false, "Unknown action"
		end
		if argument ~= nil and type(argument) ~= "string" then
			return false, "Bad request"
		end
		local ok, success, message = pcall(action, player, argument)
		if not ok then
			warn("[ProgressService] " .. actionName .. " failed: " .. tostring(success))
			return false, "Something went wrong"
		end
		return success, message
	end
end

return ProgressService
