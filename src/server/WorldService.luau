-- The lobby: practice dummies, the global leaderboards, and catching players
-- who fall off the lobby island.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Quests = require(Shared.Quests)
local Format = require(Shared.Format)

local CombatService = require(script.Parent.CombatService)
local CosmeticService = require(script.Parent.CosmeticService)
local TutorialService = require(script.Parent.TutorialService)
local MatchService = require(script.Parent.MatchService)

local WorldService = {}

local LEADERBOARD_REFRESH = 120
local DUMMY_RESET = 6 -- seconds without a hit before a dummy's damage goes back to 0

------------------------------------------------------------------ Practice dummies
local function makeDummy(spot)
	local description = Instance.new("HumanoidDescription")
	local wood = Color3.fromRGB(205, 170, 120)
	description.HeadColor = wood
	description.LeftArmColor = wood
	description.RightArmColor = wood
	description.TorsoColor = Color3.fromRGB(180, 60, 60)
	description.LeftLegColor = wood
	description.RightLegColor = wood
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		return nil
	end
	model.Name = "PracticeDummy"
	local home = CFrame.lookAt(spot.Position, Vector3.new(spot.Position.X - 10, spot.Position.Y, spot.Position.Z))
	model:PivotTo(home)
	model.Parent = Workspace
	pcall(function()
		model.HumanoidRootPart:SetNetworkOwner(nil)
	end)
	local entity = CombatService.Register(model, { kind = "dummy", name = "Practice Dummy", key = "d" .. model:GetDebugId(), walkSpeed = 8 })
	entity.home = home
	model:SetAttribute("ShowDamage", true)
	CosmeticService.Tag(model, { name = "Practice Dummy", nameColor = Color3.fromRGB(255, 220, 160), subtitle = "Bonk me!" })
	return entity
end

local function runDummy(spot)
	while true do
		local entity = makeDummy(spot)
		if not entity then
			return
		end
		while entity.model.Parent and entity.humanoid.Health > 0 do
			task.wait(0.5)
			local root = entity.root
			if root.Position.Y < entity.home.Position.Y - 20 then
				break
			end
			local idle = not entity.lastHit or os.clock() - entity.lastHit.time > DUMMY_RESET
			if idle and entity.damage > 0 then
				CombatService.SetDamage(entity, 0)
			end
			if os.clock() > entity.stunUntil and (root.Position - entity.home.Position).Magnitude > 3 then
				entity.humanoid:MoveTo(entity.home.Position)
			end
		end
		entity.model:Destroy()
		task.wait(1)
	end
end

------------------------------------------------------------------ Leaderboards
local function makeBoardFace(boardPart, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = gui
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Parent = gui
	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Position = UDim2.new(0, 0, 0.18, 0)
	body.Size = UDim2.new(1, 0, 0.8, 0)
	body.BackgroundTransparency = 1
	body.Text = "Loading..."
	body.TextScaled = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Font = Enum.Font.GothamMedium
	body.TextColor3 = Color3.new(1, 1, 1)
	body.Parent = gui
	gui.Parent = boardPart
	return title, body
end

-- Boards show the same text on both sides. Returns a function(title, text).
local function makeBoardGui(boardPart)
	local frontTitle, frontBody = makeBoardFace(boardPart, Enum.NormalId.Front)
	local backTitle, backBody = makeBoardFace(boardPart, Enum.NormalId.Back)
	return function(title, text)
		frontTitle.Text = title
		backTitle.Text = title
		frontBody.Text = text
		backBody.Text = text
	end
end

local function findStation(name)
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("Station") == name then
			return item
		end
	end
	return nil
end

local nameCache = {}
local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("Player " .. userId)
	return nameCache[userId]
end

local function topTen(storeName, emptyText)
	local ok, pages = pcall(function()
		return DataStoreService:GetOrderedDataStore(storeName):GetSortedAsync(false, 10)
	end)
	if not ok then
		return "Leaderboard unavailable right now."
	end
	local lines = {}
	for rank, entry in ipairs(pages:GetCurrentPage()) do
		table.insert(lines, string.format("%d. %s  -  %s", rank, nameFor(tonumber(entry.key)), Format.Number(entry.value)))
	end
	return #lines > 0 and table.concat(lines, "\n") or emptyText
end

-- The wins board takes turns showing all-time wins and this week's wins
local function runWinsBoard(boardPart)
	local setText = makeBoardGui(boardPart)
	local allTime, weekly, weekLeft = "Loading...", "Loading...", 0
	task.spawn(function()
		while true do
			local week, left = Quests.Week(os.time())
			allTime = topTen(Config.WinsStoreName, "No wins yet. Be the first!")
			weekly = topTen(Config.WeeklyWinsStorePrefix .. week, "No wins this week yet!")
			weekLeft = os.time() + left
			task.wait(LEADERBOARD_REFRESH)
		end
	end)
	while true do
		setText("Most Wins", allTime)
		task.wait(12)
		setText("This Week's Wins", weekly .. "\n\nNew week in " .. Format.Duration(weekLeft - os.time()))
		task.wait(12)
	end
end

local function runKosBoard(boardPart)
	local setText = makeBoardGui(boardPart)
	while true do
		setText("Most Knockouts", topTen(Config.KosStoreName, "No knockouts yet. Go bonk someone!"))
		task.wait(LEADERBOARD_REFRESH)
	end
end

function WorldService.Start()
	for _, item in ipairs(Workspace:GetDescendants()) do
		if item:IsA("BasePart") and item:GetAttribute("Dummy") then
			task.spawn(runDummy, item)
		end
	end

	CombatService.OnHit(function(attacker, target)
		if target.kind == "dummy" and attacker.player then
			TutorialService.Event(attacker.player, "BonkDummy")
		end
	end)

	local winsBoard = findStation("WinsBoard")
	if winsBoard then
		task.spawn(runWinsBoard, winsBoard)
	end
	local kosBoard = findStation("KosBoard")
	if kosBoard then
		task.spawn(runKosBoard, kosBoard)
	end

	-- Anyone who falls off the lobby comes back to the spawn
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < -40 and not MatchService.ParticipantOfPlayer(player) then
					character:PivotTo(MatchService.LobbySpawn())
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)
end

return WorldService
