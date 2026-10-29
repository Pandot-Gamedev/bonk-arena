-- Queue pads, matches and rounds.
--
-- Stand on a pad in the lobby to queue for that pad's arena spot. The match
-- starts when the pad is full, or after Config.QueueSeconds with bots filling
-- the empty spots. A match is best of 3 rounds, each on a freshly built arena.
-- If someone steps on the pad while a match with bots is running, a bot steps
-- aside for them at the start of the next round.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Arenas = require(Shared.Arenas)
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local CombatService = require(script.Parent.CombatService)
local CosmeticService = require(script.Parent.CosmeticService)
local ArenaService = require(script.Parent.ArenaService)
local BotService = require(script.Parent.BotService)
local PowerUpService = require(script.Parent.PowerUpService)
local ProgressService = require(script.Parent.ProgressService)
local TutorialService = require(script.Parent.TutorialService)

local MatchService = {}

local slots = {} -- [slot number] = slot
local arenaFolder
local random = Random.new()
local dirty = true -- something changed that players' screens should show

local function now()
	return os.clock()
end

local function serverTime()
	return Workspace:GetServerTimeNow()
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

------------------------------------------------------------------ Finding things
local function findAttribute(name)
	local found = {}
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute(name) ~= nil then
			found[item:GetAttribute(name)] = item
		end
	end
	return found
end

local function lobbySpawn()
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = spawnLocation and spawnLocation.CFrame or CFrame.new(0, 3, 40)
	return base * CFrame.new(random:NextNumber(-4, 4), 3.5, random:NextNumber(-4, 4))
end
MatchService.LobbySpawn = lobbySpawn

------------------------------------------------------------------ Matches
local Match = {}
Match.__index = Match

-- The entity (combat body) of a participant right now
function Match:Entity(participant)
	if participant.player then
		local entity = CombatService.GetByPlayer(participant.player)
		if entity and entity == participant.entity then
			return entity
		end
		return nil
	end
	return participant.entity
end

-- Entities still in the round (what bonks and hazards can hit)
function Match:Targets()
	local list = {}
	if self.state ~= "fight" and self.state ~= "countdown" then
		return list
	end
	for _, participant in ipairs(self.participants) do
		if participant.alive then
			local entity = self:Entity(participant)
			if entity then
				table.insert(list, entity)
			end
		end
	end
	return list
end

function Match:Bots()
	local list = {}
	if self.state ~= "fight" then
		return list
	end
	for _, participant in ipairs(self.participants) do
		if participant.alive and participant.bot then
			table.insert(list, participant.entity)
		end
	end
	return list
end

function Match:PowerUpPositions()
	return PowerUpService.Positions(self)
end

function Match:ParticipantOf(entity)
	for _, participant in ipairs(self.participants) do
		if participant.entity == entity then
			return participant
		end
	end
	return nil
end

function Match:CountPowerUp(entity)
	local participant = self:ParticipantOf(entity)
	if participant then
		participant.powerups += 1
	end
end

function Match:RealPlayers()
	local list = {}
	for _, participant in ipairs(self.participants) do
		if participant.player and participant.player.Parent then
			table.insert(list, participant)
		end
	end
	return list
end

-- A message to everyone in this match (and those watching from its deck)
function Match:Announce(text, kind, seconds)
	for _, participant in ipairs(self:RealPlayers()) do
		Remotes.Announce:FireClient(participant.player, text, kind or "small", seconds)
	end
end

local function newParticipant(player, botEntity)
	return {
		key = player and ("p" .. player.UserId) or botEntity.key,
		player = player,
		bot = botEntity ~= nil,
		entity = botEntity,
		name = player and player.DisplayName or botEntity.name,
		wins = 0,
		alive = false,
		kos = 0,
		botKos = 0,
		bonks = 0,
		powerups = 0,
		roundWins = {}, -- [arenaId] = rounds won there
		lastSafe = nil,
		eliminatedAt = 0,
	}
end

local function participantOfPlayer(player)
	for _, slot in pairs(slots) do
		local match = slot.match
		if match then
			for _, participant in ipairs(match.participants) do
				if participant.player == player then
					return participant, match
				end
			end
		end
	end
	return nil
end
MatchService.ParticipantOfPlayer = participantOfPlayer

-- Puts an entity on its match's deck to watch
local function toDeck(match, entity)
	if not entity or not entity.root or not entity.root.Parent then
		return
	end
	entity.space = nil
	CombatService.Reset(entity) -- no giant hammer or shield on the deck
	entity.model:SetAttribute("ShowDamage", false)
	CombatService.Freeze(entity, false)
	local spot = match.slot.deck * CFrame.new(random:NextNumber(-12, 12), 0, random:NextNumber(-3, 4))
	if entity.player then
		entity.model:PivotTo(spot)
		entity.root.AssemblyLinearVelocity = Vector3.zero
	else
		BotService.Place(entity, spot)
	end
end

local function chooseArena(match)
	local pick = ReplicatedStorage:GetAttribute("ArenaPick")
	if pick and Arenas.ById[pick] then
		return pick
	end
	local choices = {}
	for _, arena in ipairs(Arenas.List) do
		if not match.usedArenas[arena.id] and arena.id ~= match.slot.lastArena then
			table.insert(choices, arena.id)
		end
	end
	if #choices == 0 then
		match.usedArenas = {}
		for _, arena in ipairs(Arenas.List) do
			if arena.id ~= match.slot.lastArena then
				table.insert(choices, arena.id)
			end
		end
	end
	local id = choices[random:NextInteger(1, #choices)]
	match.usedArenas[id] = true
	match.slot.lastArena = id
	return id
end

local function eliminate(match, participant, entity)
	if not participant.alive then
		return
	end
	participant.alive = false
	participant.eliminatedAt = now()
	dirty = true
	local position = participant.lastSafe or (entity and entity.root and entity.root.Position) or match.slot.center
	local knocker = nil
	if entity and entity.lastHit and now() - entity.lastHit.time <= Config.KoCreditSeconds and entity.lastHit.by ~= entity then
		knocker = match:ParticipantOf(entity.lastHit.by)
	end
	if knocker then
		if participant.bot then
			knocker.botKos += 1
		else
			knocker.kos += 1
		end
		local effect = "ko_poof"
		if knocker.player then
			local item = CosmeticService.Equipped(knocker.player, "ko")
			effect = item and item.id or effect
		end
		CombatService.Effect("ko", position, { effect = effect })
		match:Announce(string.format("%s knocked out %s!", knocker.name, participant.name), "ko")
	else
		CombatService.Effect("ko", position, { effect = "ko_poof" })
		match:Announce(participant.name .. " fell off!", "ko")
	end
	if entity then
		task.delay(0.3, toDeck, match, entity)
	end
end

local function placeForRound(match)
	local arena = match.arena
	local order = table.clone(match.participants)
	for index = #order, 2, -1 do
		local other = random:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end
	for index, participant in ipairs(order) do
		local entity
		if participant.player then
			entity = CombatService.GetByPlayer(participant.player)
			participant.entity = entity
		else
			entity = participant.entity
		end
		if entity and CombatService.IsAlive(entity) then
			local spawnCFrame = arena.spawns[((index - 1) % #arena.spawns) + 1]
			CombatService.Reset(entity)
			entity.space = match
			entity.model:SetAttribute("ShowDamage", true)
			if participant.player then
				entity.model:PivotTo(spawnCFrame)
				entity.root.AssemblyLinearVelocity = Vector3.zero
			else
				BotService.Place(entity, spawnCFrame)
			end
			CombatService.Freeze(entity, true)
			participant.alive = true
			participant.lastSafe = spawnCFrame.Position
		else
			participant.alive = false
		end
	end
end

-- Real players who stepped on the pad take over from bots between rounds
local function swapInJoiners(match)
	local slot = match.slot
	for player in pairs(slot.joining) do
		if player.Parent and DataService.IsLoaded(player) and not participantOfPlayer(player) then
			local botParticipant, botIndex = nil, nil
			for index, participant in ipairs(match.participants) do
				if participant.bot then
					botParticipant, botIndex = participant, index
					break
				end
			end
			if not botParticipant then
				break
			end
			local newcomer = newParticipant(player, nil)
			match.participants[botIndex] = newcomer
			match:Announce(string.format("%s made room for %s!", botParticipant.name, newcomer.name), "info")
			Remotes.Announce:FireClient(player, "You're in! You replace " .. botParticipant.name .. ".", "info")
			BotService.Remove(botParticipant.entity)
			player:SetAttribute("QueuePad", nil)
			player:SetAttribute("InMatch", slot.index)
			TutorialService.Event(player, "Queue")
		end
	end
	slot.joining = {}
end

local function giveRewards(match, winner)
	local opponentsAllBots = true
	for _, participant in ipairs(match.participants) do
		if participant ~= winner and not participant.bot then
			opponentsAllBots = false
		end
	end
	for _, participant in ipairs(match:RealPlayers()) do
		local won = participant == winner
		local coins = Config.CoinRewards.play
			+ participant.wins * Config.CoinRewards.roundWin
			+ participant.kos * Config.CoinRewards.ko
			+ math.floor(participant.botKos * Config.CoinRewards.ko * Config.BotKoShare)
		local xp = Config.XpRewards.play
			+ participant.wins * Config.XpRewards.roundWin
			+ participant.kos * Config.XpRewards.ko
			+ math.floor(participant.botKos * Config.XpRewards.ko * Config.BotKoShare)
		if won then
			local share = opponentsAllBots and Config.BotOnlyWinShare or 1
			coins += math.floor(Config.CoinRewards.matchWin * share)
			xp += math.floor(Config.XpRewards.matchWin * share)
		end
		local stats = {
			matches = 1,
			wins = won and 1 or 0,
			rounds = participant.wins,
			kos = participant.kos + participant.botKos,
			bonks = participant.bonks,
			powerups = participant.powerups,
		}
		for arenaId, count in pairs(participant.roundWins) do
			stats["round_" .. arenaId] = count
		end
		ProgressService.AddMatchResult(participant.player, { coins = coins, xp = xp, stats = stats, won = won })
		TutorialService.Event(participant.player, "Match")
	end
end

local function endMatch(match)
	local slot = match.slot
	match.state = "over"
	if match.arena then
		match.arena:Destroy()
		match.arena = nil
	end
	PowerUpService.EndRound(match)
	for _, participant in ipairs(match.participants) do
		if participant.bot then
			BotService.Remove(participant.entity)
		elseif participant.player and participant.player.Parent then
			local entity = CombatService.GetByPlayer(participant.player)
			if entity then
				entity.space = nil
				CombatService.Reset(entity)
				entity.model:SetAttribute("ShowDamage", false)
				if entity.root and entity.root.Anchored then
					entity.root.Anchored = false
				end
				entity.model:PivotTo(lobbySpawn())
				entity.root.AssemblyLinearVelocity = Vector3.zero
			end
			participant.player:SetAttribute("InMatch", nil)
		end
	end
	slot.match = nil
	slot.joining = {}
	dirty = true
end

local function runRound(match)
	local slot = match.slot
	match.round += 1
	local arenaId = chooseArena(match)
	if match.arena then
		match.arena:Destroy()
	end
	local arena = ArenaService.Build(arenaId, slot.center, arenaFolder)
	match.arena = arena
	match.arenaId = arenaId
	arena.say = function(text)
		match:Announce(text, "info")
	end
	arena.entities = function()
		return match:Targets()
	end

	match.state = "countdown"
	match.suddenDeath = false
	match.endsAt = serverTime() + Config.CountdownSeconds
	placeForRound(match)
	dirty = true
	match:Announce(string.format("Round %d: %s", match.round, Arenas.ById[arenaId].name), "round", Config.CountdownSeconds)
	task.wait(Config.CountdownSeconds)

	match.state = "fight"
	for _, entity in ipairs(match:Targets()) do
		CombatService.Freeze(entity, false)
	end
	match:Announce("BONK!", "big", 1)
	arena:Start()
	PowerUpService.StartRound(match)
	local fightStarted = now()
	match.endsAt = serverTime() + Config.RoundSeconds
	dirty = true

	local winner = nil
	local lastThink = 0
	while true do
		task.wait(0.1)
		if #match:RealPlayers() == 0 then
			return nil, true -- everyone left
		end
		-- Who is out?
		local aliveList = {}
		for _, participant in ipairs(match.participants) do
			if participant.alive then
				local entity = match:Entity(participant)
				local out = entity == nil or not CombatService.IsAlive(entity)
				if not out then
					local position = entity.root.Position
					local fromCenter = flat(position - slot.center).Magnitude
					out = position.Y < arena.floorY - Config.OutBelow or fromCenter > arena.radius + Config.OutBeyond or arena:IsOut(position)
					if not out and position.Y > arena.floorY - 2 and fromCenter < arena.radius then
						participant.lastSafe = position
					end
				end
				if out then
					eliminate(match, participant, entity)
				else
					table.insert(aliveList, participant)
				end
			end
		end
		if #aliveList <= 1 then
			winner = aliveList[1]
			break
		end
		if now() - lastThink >= 0.15 then
			lastThink = now()
			BotService.Think(match)
		end
		local elapsed = now() - fightStarted
		if not match.suddenDeath and elapsed >= Config.RoundSeconds then
			match.suddenDeath = true
			match.endsAt = serverTime() + Config.SuddenDeathSeconds
			for _, participant in ipairs(aliveList) do
				local entity = match:Entity(participant)
				if entity then
					CombatService.SetDamage(entity, math.max(entity.damage, Config.SuddenDeathDamage))
				end
			end
			arena:SuddenDeath()
			match:Announce("SUDDEN DEATH! Everyone is at " .. Config.SuddenDeathDamage .. "%", "big", 2)
			dirty = true
		elseif match.suddenDeath and elapsed >= Config.RoundSeconds + Config.SuddenDeathSeconds then
			-- Time's up: whoever has the least damage wins
			local best = math.huge
			for _, participant in ipairs(aliveList) do
				local entity = match:Entity(participant)
				local damage = entity and entity.damage or math.huge
				if damage < best then
					best = damage
					winner = participant
				end
			end
			break
		end
	end

	if not winner then
		-- Everyone went out at once: the last one to fall wins
		local latest = -1
		for _, participant in ipairs(match.participants) do
			if participant.eliminatedAt > latest then
				latest = participant.eliminatedAt
				winner = participant
			end
		end
	end
	match.state = "roundEnd"
	PowerUpService.EndRound(match)
	for _, participant in ipairs(match.participants) do
		local entity = match:Entity(participant)
		if entity and participant.alive then
			CombatService.Freeze(entity, true)
		end
	end
	if winner then
		winner.wins += 1
		winner.roundWins[arenaId] = (winner.roundWins[arenaId] or 0) + 1
		match:Announce(string.format("%s wins round %d!", winner.name, match.round), "big", Config.BetweenRoundsSeconds - 0.5)
	end
	dirty = true
	return winner, false
end

local function runVictory(match, winner)
	local slot = match.slot
	match.state = "victory"
	match.winner = winner
	match.endsAt = serverTime() + Config.VictorySeconds
	dirty = true
	if match.arena then
		match.arena:Destroy()
		match.arena = nil
	end
	for _, participant in ipairs(match.participants) do
		local entity = match:Entity(participant)
		if entity and participant ~= winner then
			toDeck(match, entity)
		end
	end
	local winnerEntity = winner and match:Entity(winner)
	if winnerEntity and winnerEntity.root and winnerEntity.root.Parent then
		winnerEntity.space = nil
		CombatService.Freeze(winnerEntity, false)
		winnerEntity.model:SetAttribute("ShowDamage", false)
		local stand = slot.podium * CFrame.new(0, 3, 0)
		winnerEntity.model:PivotTo(stand)
		local dance = Cosmetics.Defaults.dance
		if winner.player then
			local item = CosmeticService.Equipped(winner.player, "dance")
			dance = item and item.id or dance
		end
		CosmeticService.Dance(winnerEntity.model, dance, stand, Config.VictorySeconds - 1)
	end
	match:Announce(string.format("%s WINS THE MATCH!", winner and winner.name or "Nobody"), "victory", Config.VictorySeconds - 1)
	giveRewards(match, winner)
	task.wait(Config.VictorySeconds)
end

local function runMatch(match)
	while match.state ~= "over" do
		if match.round > 0 then
			swapInJoiners(match)
		end
		local winner, abandoned = runRound(match)
		if abandoned then
			break
		end
		if winner and winner.wins >= Config.RoundsToWin then
			runVictory(match, winner)
			break
		end
		task.wait(Config.BetweenRoundsSeconds)
	end
	endMatch(match)
end

local function startMatch(slot, players)
	local match = setmetatable({
		slot = slot,
		participants = {},
		round = 0,
		state = "starting",
		usedArenas = {},
		endsAt = 0,
	}, Match)
	for _, player in ipairs(players) do
		table.insert(match.participants, newParticipant(player, nil))
		player:SetAttribute("QueuePad", nil)
		player:SetAttribute("InMatch", slot.index)
		TutorialService.Event(player, "Queue")
	end
	local deck = slot.deck
	while #match.participants < slot.size do
		local bot = BotService.Create(deck * CFrame.new(random:NextNumber(-10, 10), 0, 0))
		if not bot then
			break
		end
		table.insert(match.participants, newParticipant(nil, bot))
	end
	slot.match = match
	slot.queue = {}
	slot.countdownEnds = nil
	dirty = true
	task.spawn(function()
		local ok, err = pcall(runMatch, match)
		if not ok then
			warn("[MatchService] Match error: " .. tostring(err))
			pcall(endMatch, match)
		end
	end)
	return match
end

------------------------------------------------------------------ Queue pads
local function onPad(slot, player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local pad = slot.pad
	local offset = root.Position - pad.Position
	return flat(offset).Magnitude <= 7.5 and offset.Y > -1 and offset.Y < 8
end

local function updatePads()
	local t = now()
	for _, slot in pairs(slots) do
		local standing = {}
		for _, player in ipairs(Players:GetPlayers()) do
			if DataService.IsLoaded(player) and not participantOfPlayer(player) and onPad(slot, player) then
				table.insert(standing, player)
			end
		end
		-- Keep the order people arrived in
		local stillThere = {}
		for _, player in ipairs(slot.queue) do
			if table.find(standing, player) then
				table.insert(stillThere, player)
			end
		end
		for _, player in ipairs(standing) do
			if not table.find(stillThere, player) then
				table.insert(stillThere, player)
				TutorialService.Event(player, "Queue")
			end
		end
		slot.queue = stillThere

		local status
		local match = slot.match
		if match then
			slot.joining = {}
			local bots = 0
			for _, participant in ipairs(match.participants) do
				if participant.bot then
					bots += 1
				end
			end
			for index, player in ipairs(slot.queue) do
				if index <= bots then
					slot.joining[player] = true
				end
			end
			if bots > 0 and #slot.queue > 0 then
				status = string.format("Match on: you'll take a bot's place next round")
			elseif bots > 0 then
				status = string.format("Round %d on: step here to replace a bot", math.max(1, match.round))
			else
				status = string.format("Round %d on: next match after this one", math.max(1, match.round))
			end
		else
			local queued = math.min(#slot.queue, slot.size)
			if queued == 0 then
				slot.countdownEnds = nil
				status = "Step here to play!"
			else
				if not slot.countdownEnds then
					slot.countdownEnds = t + Config.QueueSeconds
				end
				if queued >= slot.size then
					slot.countdownEnds = math.min(slot.countdownEnds, t + Config.QueueFullSeconds)
				end
				local left = math.max(0, math.ceil(slot.countdownEnds - t))
				status = string.format("%d/%d ready. Starting in %ds%s", queued, slot.size, left, queued < slot.size and " (bots fill in)" or "")
				if t >= slot.countdownEnds then
					local players = {}
					for index = 1, queued do
						table.insert(players, slot.queue[index])
					end
					startMatch(slot, players)
				end
			end
		end
		for _, player in ipairs(Players:GetPlayers()) do
			local queuedHere = table.find(slot.queue, player) ~= nil and not participantOfPlayer(player)
			if queuedHere then
				player:SetAttribute("QueuePad", slot.index)
			elseif player:GetAttribute("QueuePad") == slot.index then
				player:SetAttribute("QueuePad", nil)
			end
		end
		if slot.status ~= status then
			slot.status = status
			ReplicatedStorage:SetAttribute("PadStatus" .. slot.index, status)
			if slot.signLabel then
				slot.signLabel.Text = slot.name .. "\n" .. status
			end
		end
	end
end

------------------------------------------------------------------ What players see
local function summaries()
	local list = {}
	for _, slot in pairs(slots) do
		local match = slot.match
		if match and match.state ~= "starting" then
			local players = {}
			for _, participant in ipairs(match.participants) do
				local entity = match:Entity(participant) or participant.entity
				table.insert(players, {
					key = participant.key,
					name = participant.name,
					userId = participant.player and participant.player.UserId or 0,
					bot = participant.bot,
					alive = participant.alive,
					wins = participant.wins,
					damage = entity and math.floor(entity.damage) or 0,
					model = entity and entity.model or nil,
				})
			end
			table.insert(list, {
				slot = slot.index,
				pad = slot.name,
				arena = match.arenaId,
				round = match.round,
				state = match.state,
				endsAt = match.endsAt,
				suddenDeath = match.suddenDeath,
				winner = match.winner and match.winner.name or nil,
				roundsToWin = Config.RoundsToWin,
				players = players,
			})
		end
	end
	return list
end

-- Studio test helper: starts a match on a pad right away (the player plus bots)
function MatchService.TestStart(slotIndex, player)
	local slot = slots[slotIndex or 2]
	if slot and not slot.match and player then
		return startMatch(slot, { player })
	end
end

function MatchService.Start()
	arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arenas"
	arenaFolder.Parent = Workspace

	local pads = findAttribute("QueuePad")
	local centers = findAttribute("ArenaCenter")
	local decks = findAttribute("Deck")
	local podiums = findAttribute("Podium")
	local signs = findAttribute("PadSign")
	for index, pad in pairs(pads) do
		local center = centers[index]
		local deck = decks[index]
		if center and deck then
			local podium = podiums[index]
			local signPart = signs[index]
			local label = nil
			if signPart then
				local gui = signPart:FindFirstChildWhichIsA("SurfaceGui")
				label = gui and gui:FindFirstChild("Status")
			end
			slots[index] = {
				index = index,
				pad = pad,
				size = pad:GetAttribute("PadSize") or 4,
				name = pad:GetAttribute("PadName") or ("Arena " .. index),
				center = center.Position,
				deck = CFrame.lookAt(deck.Position, center.Position * Vector3.new(1, 0, 1) + Vector3.new(0, deck.Position.Y, 0)),
				podium = podium and CFrame.lookAt(podium.Position + Vector3.new(0, podium.Size.Y / 2, 0), deck.Position + Vector3.new(0, podium.Size.Y / 2, 30)) or deck.CFrame,
				signLabel = label,
				queue = {},
				joining = {},
				countdownEnds = nil,
				match = nil,
			}
		end
	end

	CombatService.OnHit(function(attacker)
		local space = attacker.space
		if space and space.ParticipantOf then
			local participant = space:ParticipantOf(attacker)
			if participant then
				participant.bonks += 1
			end
		end
	end)

	-- Players who reset or respawn during a match go to the deck to watch
	local function watch(player)
		player.CharacterAdded:Connect(function(character)
			local _, match = participantOfPlayer(player)
			if match and (match.state == "fight" or match.state == "countdown" or match.state == "roundEnd" or match.state == "victory") then
				task.wait(0.2)
				local entity = CombatService.Get(character)
				if entity then
					toDeck(match, entity)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local participant = participantOfPlayer(player)
		if participant then
			participant.alive = false
			dirty = true
		end
		for _, slot in pairs(slots) do
			slot.joining[player] = nil
			local index = table.find(slot.queue, player)
			if index then
				table.remove(slot.queue, index)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(updatePads)
			if not ok then
				warn("[MatchService] " .. tostring(err))
			end
		end
	end)

	-- Send everyone the state of every match: right away when something changes,
	-- and four times a second while a round is on (for the damage numbers)
	task.spawn(function()
		local lastSent = 0
		while true do
			task.wait(0.1)
			local anyFight = false
			for _, slot in pairs(slots) do
				if slot.match and slot.match.state == "fight" then
					anyFight = true
				end
			end
			if dirty or (anyFight and now() - lastSent >= 0.25) then
				dirty = false
				lastSent = now()
				Remotes.Matches:FireAllClients(summaries())
			end
		end
	end)
end

return MatchService
