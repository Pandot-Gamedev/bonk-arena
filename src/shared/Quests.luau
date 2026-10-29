-- Daily quests: three small goals per player per day. Finishing one pays coins
-- and XP right away.

local Quests = {}

-- stat: what counts toward the goal (MatchService adds these up after every match)
Quests.Pool = {
	{ id = "wins", stat = "wins", text = "Win %d matches", goal = { 1, 3 }, coins = 120 },
	{ id = "kos", stat = "kos", text = "Knock out %d rivals", goal = { 3, 8 }, coins = 100 },
	{ id = "rounds", stat = "rounds", text = "Win %d rounds", goal = { 2, 5 }, coins = 100 },
	{ id = "matches", stat = "matches", text = "Play %d matches", goal = { 2, 5 }, coins = 80 },
	{ id = "bonks", stat = "bonks", text = "Land %d bonks", goal = { 25, 60 }, coins = 80 },
	{ id = "powerups", stat = "powerups", text = "Grab %d power-ups", goal = { 3, 6 }, coins = 80 },
	{ id = "round_ice", stat = "round_ice", text = "Win %d round on Ice Floe", goal = { 1, 1 }, coins = 100 },
	{ id = "round_spin", stat = "round_spin", text = "Win %d round on Spin Cycle", goal = { 1, 1 }, coins = 100 },
	{ id = "round_lava", stat = "round_lava", text = "Win %d round on Lava Rise", goal = { 1, 1 }, coins = 100 },
	{ id = "round_bounce", stat = "round_bounce", text = "Win %d round on Bounce House", goal = { 1, 1 }, coins = 100 },
}

Quests.ById = {}
for _, quest in ipairs(Quests.Pool) do
	Quests.ById[quest.id] = quest
end

Quests.PerDay = 3
Quests.XpShare = 0.5 -- XP reward = coins * this

function Quests.Today(now)
	return math.floor(now / 86400)
end

-- Week number for the weekly leaderboard; weeks start Monday 00:00 UTC
-- (1 Jan 1970 was a Thursday). Also returns the seconds left in the week.
local WEEK = 7 * 86400
local MONDAY_OFFSET = 4 * 86400
function Quests.Week(now)
	return math.floor((now - MONDAY_OFFSET) / WEEK), WEEK - ((now - MONDAY_OFFSET) % WEEK)
end

-- The same three quests for a player all day, picked from the pool. Only one
-- "win a round on X" quest at a time.
function Quests.Generate(userId, day)
	local random = Random.new(userId % 1000003 * 977 + day)
	local pool = table.clone(Quests.Pool)
	local list = {}
	local arenaQuest = false
	while #list < Quests.PerDay and #pool > 0 do
		local quest = table.remove(pool, random:NextInteger(1, #pool))
		local isArena = string.sub(quest.id, 1, 6) == "round_"
		if not (isArena and arenaQuest) then
			arenaQuest = arenaQuest or isArena
			local goal = random:NextInteger(quest.goal[1], quest.goal[2])
			if goal >= 20 then
				goal = math.floor(goal / 5 + 0.5) * 5 -- 45 bonks, not 43
			end
			table.insert(list, {
				id = quest.id,
				goal = goal,
				progress = 0,
				done = false,
			})
		end
	end
	return list
end

function Quests.Text(entry)
	local quest = Quests.ById[entry.id]
	local text = string.format(quest.text, entry.goal)
	if entry.goal ~= 1 then
		return text
	end
	-- "Win 1 matches" -> "Win 1 match"
	return (text:gsub("matches", "match"):gsub("rivals", "rival"):gsub("rounds", "round"):gsub("bonks", "bonk"):gsub("power%-ups", "power-up"))
end

return Quests
