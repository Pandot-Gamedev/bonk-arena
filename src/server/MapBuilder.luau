-- Builds the sky lobby and the three arena spots when the place has no folder
-- called "Map" in Workspace, so the game is playable the moment you press Play.
-- The arenas themselves are built fresh for every round by ArenaService.
-- To use your own scenery later, the game only cares about parts with these attributes:
--   QueuePad = 1      a pad in the lobby that queues players for arena spot 1
--   PadSize  = 4      how many players a match on that pad has (2 or 4)
--   PadName  = "Brawl"
--   ArenaCenter = 1   the middle of arena spot 1's floor
--   Deck = 1          where knocked-out players of spot 1 watch the rest of the round
--   Podium = 1        where the winner of spot 1 dances
--   Station = "WinsBoard" / "KosBoard" / "HowTo"
--   GuideTarget = "Practice" / "Pads"   where the first-time guide points
--   Dummy = true      where a practice dummy stands
--   LobbyFloor = true the lobby (players who fall off it come back)

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local MapBuilder = {}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		if key ~= "Parent" then
			p[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function disc(folder, name, position, radius, thickness, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, radius * 2, radius * 2),
		CFrame = CFrame.new(position - Vector3.new(0, thickness / 2, 0)) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = folder,
	})
end

local function sign(parentPart, text, face, color, pixelsPerStud)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud or 40
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = parentPart
	return label
end

-- A floating island: a grassy top with rocky layers getting smaller underneath
local function floatingIsland(folder, name, top, radius, grass)
	disc(folder, name .. "Top", top, radius, 3, grass, Enum.Material.Grass)
	local rock = Color3.fromRGB(120, 105, 95)
	for index, shrink in ipairs({ 0.92, 0.75, 0.55, 0.32 }) do
		disc(folder, name .. "Rock" .. index, top - Vector3.new(0, 3 + (index - 1) * 6, 0), radius * shrink, 6, rock:Lerp(Color3.fromRGB(80, 70, 65), index / 4), Enum.Material.Rock)
	end
end

local function cloud(folder, position, size, random)
	for _ = 1, 4 do
		part({
			Name = "Cloud",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * random:NextNumber(0.6, 1),
			Position = position + Vector3.new(random:NextNumber(-size, size), random:NextNumber(-size / 4, size / 4), random:NextNumber(-size / 2, size / 2)),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		})
	end
end

local function tree(folder, position, random)
	local height = random:NextNumber(8, 13)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.6, 1.6), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * UPRIGHT, Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 80, 50), Parent = folder })
	part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * random:NextNumber(7, 10), Position = position + Vector3.new(0, height + 1.5, 0), Material = Enum.Material.Grass, Color = Color3.fromRGB(70, 180, 80), CanCollide = false, Parent = folder })
end

local function lamp(folder, position)
	part({ Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), Position = position + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal, Parent = folder })
	local bulb = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), Position = position + Vector3.new(0, 9.4, 0), Color = Color3.fromRGB(255, 230, 160), Material = Enum.Material.Neon, Parent = folder })
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 220, 150)
	light.Parent = bulb
end

local function board(folder, name, cframe, size, station)
	local p = part({ Name = name, Size = size, CFrame = cframe, Color = Color3.fromRGB(30, 40, 60), Material = Enum.Material.SmoothPlastic, Parent = folder })
	p:SetAttribute("Station", station)
	-- Two posts from the ground up to the board
	local postHeight = cframe.Position.Y - size.Y / 2 + 0.5
	for _, x in ipairs({ -size.X / 2 + 1, size.X / 2 - 1 }) do
		local at = (cframe * CFrame.new(x, 0, 0)).Position
		part({ Name = "BoardPost", Size = Vector3.new(0.8, postHeight, 0.8), Position = Vector3.new(at.X, postHeight / 2, at.Z), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = folder })
	end
	return p
end

-- A pad in the lobby that queues players for one arena spot
local function queuePad(folder, slot, position, size, name, color)
	local pad = disc(folder, "QueuePad" .. slot, position + Vector3.new(0, 0.4, 0), 7, 0.4, color, Enum.Material.Neon)
	pad.CanCollide = false
	pad:SetAttribute("QueuePad", slot)
	pad:SetAttribute("PadSize", size)
	pad:SetAttribute("PadName", name)
	disc(folder, "PadRim" .. slot, position + Vector3.new(0, 0.3, 0), 8, 0.3, Color3.fromRGB(40, 45, 60), Enum.Material.Metal)
	-- Glowing pillars of light at the edge
	for index = 0, 5 do
		local angle = index / 6 * math.pi * 2
		part({ Name = "PadLight", Size = Vector3.new(0.6, 6, 0.6), Position = position + Vector3.new(math.cos(angle) * 7.5, 3, math.sin(angle) * 7.5), Color = color, Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false, CanQuery = false, Parent = folder })
	end
	-- A sign above the pad. MatchService writes the status on it.
	local signPart = part({ Name = "PadSign" .. slot, Size = Vector3.new(14, 5, 0.6), Position = position + Vector3.new(0, 11, -9), Color = Color3.fromRGB(25, 30, 45), Parent = folder })
	signPart:SetAttribute("PadSign", slot)
	local label = sign(signPart, name, Enum.NormalId.Back, color, 30)
	label.Name = "Status"
	for _, x in ipairs({ -6.4, 6.4 }) do
		part({ Name = "SignPost", Size = Vector3.new(0.6, 9, 0.6), Position = position + Vector3.new(x, 4.5, -9), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = folder })
	end
	return pad
end

-- The permanent parts of an arena spot: a marker for the middle of the floor,
-- the watching deck with its podium, and some clouds underneath.
local function arenaSpot(folder, slot, center, random)
	local marker = part({ Name = "ArenaCenter" .. slot, Size = Vector3.new(1, 1, 1), Position = center, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder })
	marker:SetAttribute("ArenaCenter", slot)

	local deckCenter = center + Vector3.new(0, 16, 95)
	part({ Name = "Deck", Size = Vector3.new(36, 2, 20), Position = deckCenter - Vector3.new(0, 1, 0), Color = Color3.fromRGB(70, 80, 110), Material = Enum.Material.DiamondPlate, Parent = folder })
	local deckSpot = part({ Name = "DeckSpawn" .. slot, Size = Vector3.new(1, 1, 1), Position = deckCenter + Vector3.new(0, 3, 4), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = folder })
	deckSpot:SetAttribute("Deck", slot)
	-- Walls so nobody falls or jumps off the deck (the front one is glass)
	part({ Name = "DeckGlass", Size = Vector3.new(36, 10, 0.6), Position = deckCenter + Vector3.new(0, 5, -10), Color = Color3.fromRGB(180, 220, 255), Material = Enum.Material.Glass, Transparency = 0.75, Parent = folder })
	part({ Name = "DeckWall", Size = Vector3.new(36, 10, 0.6), Position = deckCenter + Vector3.new(0, 5, 10), Transparency = 1, Parent = folder })
	part({ Name = "DeckRail", Size = Vector3.new(36, 1, 0.6), Position = deckCenter + Vector3.new(0, 1, 10), Color = Color3.fromRGB(50, 55, 75), Material = Enum.Material.Metal, Parent = folder })
	for _, x in ipairs({ -18, 18 }) do
		part({ Name = "DeckWall", Size = Vector3.new(0.6, 10, 20), Position = deckCenter + Vector3.new(x, 5, 0), Transparency = 1, Parent = folder })
		part({ Name = "DeckRail", Size = Vector3.new(0.6, 1, 20), Position = deckCenter + Vector3.new(x, 1, 0), Color = Color3.fromRGB(50, 55, 75), Material = Enum.Material.Metal, Parent = folder })
	end
	part({ Name = "DeckRoof", Size = Vector3.new(36, 0.6, 20), Position = deckCenter + Vector3.new(0, 10.3, 0), Transparency = 1, Parent = folder })
	-- Podium: the winner dances on the top step
	part({ Name = "PodiumStep", Size = Vector3.new(6, 1, 5), Position = deckCenter + Vector3.new(-6, 0.5, -4), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.SmoothPlastic, Parent = folder })
	part({ Name = "PodiumStep", Size = Vector3.new(6, 1, 5), Position = deckCenter + Vector3.new(6, 0.5, -4), Color = Color3.fromRGB(205, 127, 50), Material = Enum.Material.SmoothPlastic, Parent = folder })
	local podium = part({ Name = "Podium" .. slot, Size = Vector3.new(6, 2.5, 5), Position = deckCenter + Vector3.new(0, 1.25, -4), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.SmoothPlastic, Parent = folder })
	podium:SetAttribute("Podium", slot)
	sign(podium, "1", Enum.NormalId.Back, Color3.fromRGB(120, 80, 0))

	for _ = 1, 5 do
		local angle = random:NextNumber(0, math.pi * 2)
		cloud(folder, center + Vector3.new(math.cos(angle) * random:NextNumber(20, 70), -random:NextNumber(30, 60), math.sin(angle) * random:NextNumber(20, 70)), random:NextNumber(12, 22), random)
	end
end

function MapBuilder.Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)
	Lighting.GlobalShadows = true

	if Workspace:FindFirstChild("Map") then
		return -- the creator made their own map
	end

	local map = Instance.new("Folder")
	map.Name = "Map"
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = map
	local random = Random.new(7)

	-- The lobby island
	floatingIsland(scenery, "Lobby", Vector3.new(0, 0, 0), 75, Color3.fromRGB(110, 195, 95))
	local floor = scenery:FindFirstChild("LobbyTop")
	floor:SetAttribute("LobbyFloor", true)
	-- Low invisible walls round the edge so nobody walks off by accident
	for index = 0, 23 do
		local angle = index / 24 * math.pi * 2
		local at = Vector3.new(math.cos(angle) * 74, 4, math.sin(angle) * 74)
		part({ Name = "EdgeWall", Size = Vector3.new(1, 8, 20), CFrame = CFrame.lookAt(at, Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.rad(90), 0), Transparency = 1, Parent = map })
		if index % 2 == 0 then
			part({ Name = "Fence", Size = Vector3.new(0.6, 2.5, 19.5), CFrame = CFrame.lookAt(Vector3.new(at.X, 1.25, at.Z), Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(240, 240, 230), Material = Enum.Material.WoodPlanks, Parent = scenery })
		end
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.CFrame = CFrame.lookAt(Vector3.new(0, 0.5, 45), Vector3.new(0, 0.5, 0))
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Color = Color3.fromRGB(255, 200, 60)
	spawnLocation.Duration = 0
	spawnLocation.Parent = map

	-- Paths
	part({ Name = "Path", Size = Vector3.new(8, 0.2, 70), Position = Vector3.new(0, 0.1, 10), Material = Enum.Material.Pebble, Color = Color3.fromRGB(215, 205, 175), CanCollide = false, Parent = scenery })
	part({ Name = "Path", Size = Vector3.new(90, 0.2, 8), Position = Vector3.new(0, 0.1, -22), Material = Enum.Material.Pebble, Color = Color3.fromRGB(215, 205, 175), CanCollide = false, Parent = scenery })

	-- The three queue pads, one per arena spot. Arena spots float out past the
	-- pads, so you can see them from the lobby.
	local spots = {
		{ name = "DUEL  1 v 1", size = 2, color = Color3.fromRGB(80, 170, 255), pad = Vector3.new(-32, 0, -32), arena = Vector3.new(-280, 90, -340) },
		{ name = "BRAWL  up to 4", size = 4, color = Color3.fromRGB(255, 150, 50), pad = Vector3.new(0, 0, -38), arena = Vector3.new(0, 90, -380) },
		{ name = "BRAWL  up to 4", size = 4, color = Color3.fromRGB(255, 90, 180), pad = Vector3.new(32, 0, -32), arena = Vector3.new(280, 90, -340) },
	}
	for slot, spot in ipairs(spots) do
		queuePad(map, slot, spot.pad, spot.size, spot.name, spot.color)
		arenaSpot(map, slot, spot.arena, random)
	end
	local padsTarget = part({ Name = "PadsTarget", Size = Vector3.new(2, 1, 2), Position = Vector3.new(0, 1, -30), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = map })
	padsTarget:SetAttribute("GuideTarget", "Pads")

	-- Practice ring with dummies to try bonking on
	local practiceCenter = Vector3.new(46, 0, 22)
	disc(scenery, "PracticeFloor", practiceCenter + Vector3.new(0, 0.2, 0), 15, 0.2, Color3.fromRGB(230, 200, 140), Enum.Material.Sand).CanCollide = false
	for index = 0, 15 do
		local angle = index / 16 * math.pi * 2
		local at = practiceCenter + Vector3.new(math.cos(angle) * 15, 2, math.sin(angle) * 15)
		local isGap = index == 8 -- the way in, facing the spawn side
		if not isGap then
			part({ Name = "PracticeRope", Size = Vector3.new(0.5, 4, 6.2), CFrame = CFrame.lookAt(at, practiceCenter + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(230, 70, 70), Material = Enum.Material.Fabric, Parent = map })
		end
	end
	local practiceSign = part({ Name = "PracticeSign", Size = Vector3.new(14, 3, 0.5), Position = practiceCenter + Vector3.new(0, 7, 15.5), Color = Color3.fromRGB(30, 40, 60), Parent = scenery })
	sign(practiceSign, "PRACTICE RING", Enum.NormalId.Front, Color3.fromRGB(255, 220, 120))
	sign(practiceSign, "PRACTICE RING", Enum.NormalId.Back, Color3.fromRGB(255, 220, 120))
	local practiceTarget = part({ Name = "PracticeTarget", Size = Vector3.new(2, 1, 2), Position = practiceCenter + Vector3.new(0, 1, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = map })
	practiceTarget:SetAttribute("GuideTarget", "Practice")
	for _, offset in ipairs({ Vector3.new(-6, 0, -4), Vector3.new(6, 0, -4), Vector3.new(0, 0, 6) }) do
		local spot = part({ Name = "DummySpot", Size = Vector3.new(1, 1, 1), Position = practiceCenter + offset + Vector3.new(0, 3, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = map })
		spot:SetAttribute("Dummy", true)
	end

	-- Leaderboards and the how-to-play board
	board(map, "WinsBoard", CFrame.new(-56, 11, 6) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(22, 16, 1), "WinsBoard")
	board(map, "KosBoard", CFrame.new(-50, 11, 34) * CFrame.Angles(0, math.rad(-120), 0), Vector3.new(22, 16, 1), "KosBoard")
	local howTo = board(map, "HowToBoard", CFrame.new(-22, 8, 52) * CFrame.Angles(0, math.rad(-160), 0), Vector3.new(18, 11, 1), "HowTo")
	local howToText = "HOW TO PLAY\n\nBonk: click / BONK button\nDash: Q / DASH button\n\nKnock rivals off the arena!\nThe higher their %, the farther they fly.\nWin 2 rounds to win the match."
	sign(howTo, howToText, Enum.NormalId.Front, Color3.fromRGB(255, 240, 200), 30)
	sign(howTo, howToText, Enum.NormalId.Back, Color3.fromRGB(255, 240, 200), 30)

	local title = part({ Name = "TitleSign", Size = Vector3.new(40, 9, 1), Position = Vector3.new(0, 26, -62), Color = Color3.fromRGB(255, 120, 60), Material = Enum.Material.SmoothPlastic, Parent = scenery })
	sign(title, "BONK ARENA", Enum.NormalId.Back, Color3.new(1, 1, 1))
	sign(title, "BONK ARENA", Enum.NormalId.Front, Color3.new(1, 1, 1))
	for _, x in ipairs({ -18, 18 }) do
		part({ Name = "TitlePost", Size = Vector3.new(1.2, 22, 1.2), Position = Vector3.new(x, 11, -62), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = scenery })
	end

	for _, at in ipairs({ Vector3.new(-12, 0, 30), Vector3.new(12, 0, 30), Vector3.new(-12, 0, -10), Vector3.new(12, 0, -10), Vector3.new(-48, 0, -10), Vector3.new(48, 0, -10) }) do
		lamp(scenery, at)
	end
	for _ = 1, 16 do
		local angle = random:NextNumber(0, math.pi * 2)
		local distance = random:NextNumber(55, 68)
		local at = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local nearPads = at.Z < -15 and math.abs(at.X) < 50
		local nearPractice = (at - practiceCenter).Magnitude < 22
		local nearBoards = at.X < -35 and at.Z > -5 and at.Z < 45
		if not nearPads and not nearPractice and not nearBoards then
			tree(scenery, at, random)
		end
	end
	for _ = 1, 10 do
		local angle = random:NextNumber(0, math.pi * 2)
		cloud(scenery, Vector3.new(math.cos(angle) * random:NextNumber(110, 220), random:NextNumber(-60, -20), math.sin(angle) * random:NextNumber(110, 220)), random:NextNumber(14, 26), random)
	end

	map.Parent = Workspace
end

return MapBuilder
