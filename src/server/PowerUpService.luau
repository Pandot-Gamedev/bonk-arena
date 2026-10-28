-- Power-ups that drop onto the arena during a round. Anyone can grab one by
-- running into it. They are never sold.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local PowerUps = require(Shared.PowerUps)
local Remotes = require(Shared.Remotes)

local CombatService = require(script.Parent.CombatService)
local CosmeticService = require(script.Parent.CosmeticService)

local PowerUpService = {}

local rounds = {} -- [match] = { items = {}, bananas = {} }
local random = Random.new()

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function weldTo(root, p, offset)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = root.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = p
	weld.C0 = offset
	weld.Parent = p
end

local function tell(entity, text)
	if entity.player then
		Remotes.Announce:FireClient(entity.player, text, "power", 2.5)
	end
end

------------------------------------------------------------------ Effects of each power-up
local GIVE = {}

GIVE.giant = function(entity)
	entity.giantUntil = os.clock() + Config.PowerUpSeconds
	entity.model:SetAttribute("GiantHammer", true)
	if entity.player then
		CosmeticService.RefreshHammer(entity.player, 1.8)
	else
		CosmeticService.BuildHammer(entity.model, entity.hammerItem, 1.8)
	end
end

GIVE.shield = function(entity)
	entity.shield = PowerUps.ShieldHits
	local old = entity.model:FindFirstChild("BonkShield")
	if old then
		old:Destroy()
	end
	local bubble = Instance.new("Part")
	bubble.Name = "BonkShield"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.one * 7
	bubble.Material = Enum.Material.ForceField
	bubble.Color = Color3.fromRGB(90, 200, 255)
	weldTo(entity.root, bubble, CFrame.new())
	bubble.Parent = entity.model
end

GIVE.speed = function(entity)
	entity.speedUntil = os.clock() + Config.PowerUpSeconds
	entity.speedEnds = true
	CombatService.UpdateMovement(entity)
end

GIVE.iron = function(entity)
	entity.ironUntil = os.clock() + Config.PowerUpSeconds
	local old = entity.model:FindFirstChild("IronBoots")
	if old then
		old:Destroy()
	end
	local boots = Instance.new("Model")
	boots.Name = "IronBoots"
	for _, footName in ipairs({ "LeftFoot", "RightFoot", "Left Leg", "Right Leg" }) do
		local foot = entity.model:FindFirstChild(footName)
		if foot then
			local boot = Instance.new("Part")
			boot.Name = "Boot"
			boot.Size = Vector3.new(1.3, 0.8, 1.6)
			boot.Color = Color3.fromRGB(110, 110, 125)
			boot.Material = Enum.Material.DiamondPlate
			local offset = CFrame.new(0, -foot.Size.Y / 2 + 0.3, -0.1)
			boot.CFrame = foot.CFrame * offset
			boot.CanCollide = false
			boot.CanQuery = false
			boot.CanTouch = false
			boot.Massless = true
			local weld = Instance.new("Weld")
			weld.Part0 = foot
			weld.Part1 = boot
			weld.C0 = offset
			weld.Parent = boot
			boot.Parent = boots
		end
	end
	boots.Parent = entity.model
end

GIVE.magnet = function(entity, match)
	local origin = entity.root.Position
	for _, other in ipairs(match:Targets()) do
		if other ~= entity and other.root then
			local offset = flat(origin - other.root.Position)
			if offset.Magnitude < PowerUps.MagnetRange and offset.Magnitude > 3 then
				CombatService.Push(other, offset.Unit * math.min(50, offset.Magnitude * 2.2) + Vector3.yAxis * 18, 0.45, 0, entity)
			end
		end
	end
	entity.magnetUntil = os.clock() + PowerUps.MagnetBonkSeconds
	CombatService.Effect("shockwave", origin, { range = PowerUps.MagnetRange })
end

GIVE.banana = function(entity, match, state)
	local root = entity.root
	local look = flat(root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local spot = root.Position - look * 4
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { entity.model }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 2, 0), Vector3.new(0, -12, 0), params)
	local floorY = hit and hit.Position.Y or (root.Position.Y - 3)
	local banana = Instance.new("Part")
	banana.Name = "Banana"
	banana.Size = Vector3.new(1.8, 0.5, 0.7)
	banana.Color = Color3.fromRGB(255, 225, 60)
	banana.Material = Enum.Material.SmoothPlastic
	banana.Anchored = true
	banana.CanCollide = false
	banana.CanQuery = false
	banana.CFrame = CFrame.new(spot.X, floorY + 0.25, spot.Z) * CFrame.Angles(0, random:NextNumber(0, math.pi), math.rad(10))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = banana
	banana.Parent = match.arena and match.arena.folder or Workspace
	table.insert(state.bananas, { part = banana, owner = entity, placedAt = os.clock() })
end

------------------------------------------------------------------ Spawning and grabbing
local function spawnOne(match, state)
	local arena = match.arena
	if not arena then
		return
	end
	local powerUp = PowerUps.List[random:NextInteger(1, #PowerUps.List)]
	local position = arena:RandomFloorPoint()
	local orb = Instance.new("Part")
	orb.Name = "PowerUp"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * 2.6
	orb.Color = powerUp.color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.Position = position
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = powerUp.letter
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = powerUp.color:Lerp(Color3.new(0, 0, 0), 0.5)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = orb
	local light = Instance.new("PointLight")
	light.Color = powerUp.color
	light.Range = 12
	light.Parent = orb
	orb.Parent = arena.folder
	TweenService:Create(orb, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = position + Vector3.new(0, 1, 0) }):Play()
	table.insert(state.items, { id = powerUp.id, part = orb, position = position })
end

local function grab(match, state, item, entity)
	local powerUp = PowerUps.ById[item.id]
	item.part:Destroy()
	CombatService.Effect("powerup", entity.root.Position, { id = item.id })
	tell(entity, powerUp.name .. "! " .. powerUp.description)
	GIVE[item.id](entity, match, state)
	match:CountPowerUp(entity)
end

local function tick(match, state)
	local targets = match:Targets()
	for index = #state.items, 1, -1 do
		local item = state.items[index]
		if not item.part.Parent then
			table.remove(state.items, index)
		else
			-- Power-ups on floor that fell away (or into lava) go with it
			local arena = match.arena
			if arena and (arena:IsOut(item.position) or flat(item.position - arena.center).Magnitude > arena:SafeRadius() + 8) then
				item.part:Destroy()
				table.remove(state.items, index)
			else
				for _, entity in ipairs(targets) do
					if not entity.frozen and (entity.root.Position - item.part.Position).Magnitude < 4.2 then
						table.remove(state.items, index)
						grab(match, state, item, entity)
						break
					end
				end
			end
		end
	end
	local t = os.clock()
	for index = #state.bananas, 1, -1 do
		local banana = state.bananas[index]
		if not banana.part.Parent or t - banana.placedAt > PowerUps.BananaSeconds then
			banana.part:Destroy()
			table.remove(state.bananas, index)
		else
			for _, entity in ipairs(targets) do
				local ownGrace = entity == banana.owner and t - banana.placedAt < 3
				if not ownGrace and (flat(entity.root.Position - banana.part.Position)).Magnitude < 2.6 and math.abs(entity.root.Position.Y - banana.part.Position.Y) < 4 then
					local slide = flat(entity.root.AssemblyLinearVelocity)
					if slide.Magnitude < 1 then
						slide = flat(entity.root.CFrame.LookVector)
					end
					CombatService.Push(entity, slide.Unit * 32 + Vector3.yAxis * 30, 1.2, 5, entity ~= banana.owner and banana.owner or nil)
					CombatService.Effect("slip", entity.root.Position)
					banana.part:Destroy()
					table.remove(state.bananas, index)
					break
				end
			end
		end
	end
end

function PowerUpService.StartRound(match)
	local state = { items = {}, bananas = {} }
	rounds[match] = state
	task.spawn(function()
		local started = os.clock()
		local nextSpawn = Config.PowerUpFirstSeconds
		while rounds[match] == state and match.state == "fight" do
			if os.clock() - started >= nextSpawn then
				nextSpawn += Config.PowerUpEverySeconds
				if #state.items < Config.PowerUpMaxOnField then
					spawnOne(match, state)
				end
			end
			local ok, err = pcall(tick, match, state)
			if not ok then
				warn("[PowerUpService] " .. tostring(err))
			end
			task.wait(0.1)
		end
	end)
end

function PowerUpService.EndRound(match)
	local state = rounds[match]
	rounds[match] = nil
	if state then
		for _, item in ipairs(state.items) do
			item.part:Destroy()
		end
		for _, banana in ipairs(state.bananas) do
			banana.part:Destroy()
		end
	end
end

function PowerUpService.Positions(match)
	local list = {}
	local state = rounds[match]
	if state then
		for _, item in ipairs(state.items) do
			table.insert(list, item.position)
		end
	end
	return list
end

return PowerUpService
