-- The match screen: round and timer at the top, a card for each player at the
-- bottom (name, damage %, rounds won), big announcements in the middle, and a
-- feed of knockouts. Also lets lobby players watch a match that's on.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Arenas = require(Shared.Arenas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local UI = require(script.Parent.UI)
local T = UI.Theme

local MatchHud = {}

local player = Players.LocalPlayer
local matches = {}
local watching = nil -- { slot = n, key = participant key }
local topBar, roundLine, timerLine, watchLine
local cardsRow
local bigLabel, countdownLabel
local feed
local bigToken = 0

local KINDS = {
	big = { color = Color3.fromRGB(255, 230, 90), size = 70 },
	round = { color = Color3.new(1, 1, 1), size = 56 },
	victory = { color = Color3.fromRGB(255, 200, 40), size = 76 },
}
local FEED_COLORS = {
	ko = Color3.fromRGB(255, 120, 90),
	info = Color3.fromRGB(180, 220, 255),
	power = Color3.fromRGB(200, 160, 255),
	small = Color3.new(1, 1, 1),
}

local function serverTime()
	return Workspace:GetServerTimeNow()
end

local function myMatch()
	for _, match in ipairs(matches) do
		for _, entry in ipairs(match.players) do
			if entry.userId == player.UserId and not entry.bot then
				return match
			end
		end
	end
	return nil
end

local function watchedMatch()
	if not watching then
		return nil
	end
	for _, match in ipairs(matches) do
		if match.slot == watching.slot then
			return match
		end
	end
	return nil
end

function MatchHud.AnyMatchOn()
	return #matches > 0
end

function MatchHud.IsWatching()
	return watching ~= nil
end

local function ownHumanoid()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function stopWatching()
	watching = nil
	local humanoid = ownHumanoid()
	if humanoid then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end

-- Points the camera at someone still fighting in the watched match
local function followSomeone(match, skipKey)
	for _, entry in ipairs(match.players) do
		if entry.alive and entry.model and entry.model.Parent and entry.key ~= skipKey then
			local humanoid = entry.model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				watching.key = entry.key
				Workspace.CurrentCamera.CameraSubject = humanoid
				return true
			end
		end
	end
	return false
end

function MatchHud.ToggleWatch()
	if watching then
		stopWatching()
		return
	end
	for _, match in ipairs(matches) do
		if match.state == "fight" or match.state == "countdown" then
			watching = { slot = match.slot }
			if followSomeone(match) then
				return
			end
		end
	end
	watching = nil
end

local function dots(parent, wins, needed)
	local row = UI.new("Frame", { Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, LayoutOrder = 3, Parent = parent }, {
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
	})
	for index = 1, needed do
		UI.new("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundColor3 = index <= wins and T.Gold or T.Card, Parent = row }, { UI.corner(6) })
	end
end

local function renderCards(match)
	UI.clear(cardsRow)
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = cardsRow })
	for _, entry in ipairs(match.players) do
		local isMe = entry.userId == player.UserId and not entry.bot
		local card = UI.new("Frame", {
			Size = UDim2.fromOffset(140, 84),
			BackgroundColor3 = isMe and Color3.fromRGB(40, 70, 110) or T.Background,
			BackgroundTransparency = entry.alive and 0.1 or 0.5,
			Parent = cardsRow,
		}, { UI.corner(10), UI.padding(6), UI.list(2), isMe and UI.stroke(T.Gold, 2) or nil })
		UI.label(entry.name, { Size = UDim2.new(1, 0, 0, 18), TextColor3 = entry.bot and T.Muted or T.Text, LayoutOrder = 1, Parent = card })
		local damage = entry.alive and (entry.damage .. "%") or "OUT"
		UI.label(damage, { Size = UDim2.new(1, 0, 0, 34), TextColor3 = entry.alive and Format.DamageColor(entry.damage) or T.Bad, TextStrokeTransparency = 0.4, LayoutOrder = 2, Parent = card })
		dots(card, entry.wins, match.roundsToWin)
	end
end

local function render()
	local match = myMatch() or watchedMatch()
	if watching and not watchedMatch() then
		stopWatching()
	end
	topBar.Visible = match ~= nil
	cardsRow.Visible = match ~= nil and match.state ~= "victory"
	if not match then
		countdownLabel.Visible = false
		return
	end
	local arena = Arenas.ById[match.arena or ""]
	roundLine.Text = string.format("%s  -  Round %d%s", match.pad, match.round, arena and ("  -  " .. arena.name) or "")
	roundLine.TextColor3 = arena and arena.color or T.Text
	renderCards(match)
	if watching then
		local subject = Workspace.CurrentCamera.CameraSubject
		local alive = false
		for _, entry in ipairs(match.players) do
			if entry.key == watching.key and entry.alive then
				alive = true
			end
		end
		if not alive or not subject or not subject.Parent then
			followSomeone(match, watching.key)
		end
		watchLine.Visible = true
		for _, entry in ipairs(match.players) do
			if entry.key == watching.key then
				watchLine.Text = "Watching " .. entry.name
			end
		end
	else
		watchLine.Visible = false
	end
end

-- The timer and the 3-2-1 countdown, every frame-ish
local function tick()
	local match = myMatch() or watchedMatch()
	if not match then
		countdownLabel.Visible = false
		return
	end
	local left = match.endsAt - serverTime()
	if match.state == "countdown" then
		countdownLabel.Visible = left > 0
		countdownLabel.Text = tostring(math.max(1, math.ceil(left)))
		timerLine.Text = "Get ready!"
		timerLine.TextColor3 = T.Text
	elseif match.state == "fight" then
		countdownLabel.Visible = false
		if match.suddenDeath then
			timerLine.Text = "SUDDEN DEATH  " .. Format.Clock(left)
			timerLine.TextColor3 = T.Bad
		else
			timerLine.Text = Format.Clock(left)
			timerLine.TextColor3 = left < 10 and T.Gold or T.Text
		end
	elseif match.state == "roundEnd" then
		countdownLabel.Visible = false
		timerLine.Text = "Next round coming up"
		timerLine.TextColor3 = T.Muted
	elseif match.state == "victory" then
		countdownLabel.Visible = false
		timerLine.Text = (match.winner or "Nobody") .. " wins!"
		timerLine.TextColor3 = T.Gold
	end
end

function MatchHud.ShowBig(text, kind, seconds)
	local style = KINDS[kind] or KINDS.big
	bigToken += 1
	local token = bigToken
	bigLabel.Text = text
	bigLabel.TextColor3 = style.color
	bigLabel.Size = UDim2.new(0.9, 0, 0, style.size)
	bigLabel.Visible = true
	task.delay(seconds or 1.6, function()
		if bigToken == token then
			bigLabel.Visible = false
		end
	end)
end

function MatchHud.AddFeed(text, kind)
	local line = UI.label(text, {
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = FEED_COLORS[kind] or T.Text,
		TextStrokeTransparency = 0.3,
		Parent = feed,
	})
	task.delay(3.5, function()
		line:Destroy()
	end)
	local lines = {}
	for _, child in ipairs(feed:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(lines, child)
		end
	end
	if #lines > 4 then
		lines[1]:Destroy()
	end
end

function MatchHud.Init(screenGui)
	topBar = UI.new("Frame", {
		Name = "MatchBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(480, 64),
		BackgroundColor3 = T.Background,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = screenGui,
	}, { UI.corner(12), UI.padding(6), UI.list(2) })
	roundLine = UI.label("", { Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = topBar })
	timerLine = UI.label("", { Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 2, Parent = topBar })
	watchLine = UI.label("", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.new(1, 0, 0, 20),
		Font = T.BodyFont,
		TextColor3 = Color3.fromRGB(200, 160, 255),
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = topBar,
	})

	feed = UI.new("Frame", {
		Name = "Feed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(520, 130),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, { UI.list(2) })

	cardsRow = UI.new("Frame", {
		Name = "Cards",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(600, 84),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screenGui,
	})

	bigLabel = UI.label("", {
		Name = "Big",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.new(0.9, 0, 0, 70),
		TextStrokeTransparency = 0,
		Visible = false,
		ZIndex = 5,
		Parent = screenGui,
	})
	countdownLabel = UI.label("", {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(200, 110),
		TextColor3 = T.Gold,
		TextStrokeTransparency = 0,
		Visible = false,
		ZIndex = 5,
		Parent = screenGui,
	})

	Remotes.Matches.OnClientEvent:Connect(function(list)
		matches = list or {}
		render()
	end)
	Remotes.Announce.OnClientEvent:Connect(function(text, kind, seconds)
		if KINDS[kind] then
			MatchHud.ShowBig(text, kind, seconds)
		else
			MatchHud.AddFeed(text, kind)
		end
	end)
	player.CharacterAdded:Connect(function()
		if watching then
			stopWatching()
		end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.1)
		end
	end)
end

return MatchHud
