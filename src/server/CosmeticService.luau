-- How everyone looks: name tags (name, level, title, VIP and damage %), hammers,
-- trails, the VIP crown, victory dances and knockout effects.
-- Also hands out the free cosmetics players unlock by levelling up or playing.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)
local Remotes = require(Shared.Remotes)
local Level = require(Shared.Level)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local ShopService = require(script.Parent.ShopService)

local CosmeticService = {}

local VIP_GOLD = Color3.fromRGB(255, 200, 40)
local applied = {} -- [player] = signature of what is shown, to skip needless rebuilds
local tagConnections = {} -- [model] = connections that keep the damage line up to date

local function isVip(player)
	return ShopService.HasPass(player, "VIP")
end

-- The cosmetic a player shows for a kind (falls back to the free default)
function CosmeticService.Equipped(player, kind)
	local data = DataService.Get(player)
	if not data then
		return Cosmetics.ById[Cosmetics.Defaults[kind] or ""]
	end
	return Cosmetics.Equipped(data, kind, isVip(player))
end

------------------------------------------------------------------ Hammers
local function piece(hammer, hand, gripY, props)
	local p = Instance.new("Part")
	p.Name = props.Name or "Piece"
	p.Size = props.Size
	p.Shape = props.Shape or Enum.PartType.Block
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = p
	weld.C0 = CFrame.new(0, gripY, 0) * props.CFrame
	weld.Parent = p
	p.CFrame = hand.CFrame * weld.C0
	p.Parent = hammer
	return p
end

-- Builds the hammer in the model's right hand. The handle points forward from
-- the hand, so swinging the arm brings the head down in front of you.
-- scale > 1 for the Giant Hammer power-up.
function CosmeticService.BuildHammer(model, item, scale)
	scale = scale or 1
	item = item or Cosmetics.ById[Cosmetics.Defaults.hammer]
	local old = model:FindFirstChild("BonkHammer")
	if old then
		old:Destroy()
	end
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local gripY = hand.Name == "RightHand" and -0.15 or -0.9
	local hammer = Instance.new("Model")
	hammer.Name = "BonkHammer"
	local s = scale
	local forward = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's length runs forward
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's length runs up and down

	if item.shape == "chicken" then
		piece(hammer, hand, gripY, { Name = "Legs", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2 * s, 0.3, 0.3), CFrame = CFrame.new(0, 0, -0.9 * s) * forward, Color = item.handle })
		piece(hammer, hand, gripY, { Name = "Head", Mesh = true, Size = Vector3.new(1.4, 1.4, 3.2) * s, CFrame = CFrame.new(0, 0, -3.4 * s), Color = item.head, Material = item.material })
		piece(hammer, hand, gripY, { Name = "Neck", Mesh = true, Size = Vector3.new(0.8, 0.8, 1.8) * s, CFrame = CFrame.new(0, 0.3 * s, -5.3 * s) * CFrame.Angles(math.rad(-20), 0, 0), Color = item.head, Material = item.material })
		piece(hammer, hand, gripY, { Name = "Comb", Size = Vector3.new(0.2, 0.6, 0.8) * s, CFrame = CFrame.new(0, 0.85 * s, -6 * s), Color = Color3.fromRGB(230, 40, 40) })
		piece(hammer, hand, gripY, { Name = "Beak", Size = Vector3.new(0.4, 0.3, 0.6) * s, CFrame = CFrame.new(0, 0.5 * s, -6.6 * s), Color = item.handle })
	elseif item.shape == "fish" then
		piece(hammer, hand, gripY, { Name = "Tail", Size = Vector3.new(0.2, 1.4, 1) * s, CFrame = CFrame.new(0, 0, -0.3 * s), Color = item.handle })
		piece(hammer, hand, gripY, { Name = "Head", Mesh = true, Size = Vector3.new(1, 1.8, 4.2) * s, CFrame = CFrame.new(0, 0, -2.9 * s), Color = item.head, Material = item.material })
		piece(hammer, hand, gripY, { Name = "Fin", Size = Vector3.new(0.15, 0.8, 1.2) * s, CFrame = CFrame.new(0, 0.95 * s, -2.8 * s), Color = item.handle })
		for _, side in ipairs({ -1, 1 }) do
			piece(hammer, hand, gripY, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.35 * s, CFrame = CFrame.new(0.42 * side * s, 0.25 * s, -4.4 * s), Color = Color3.new(1, 1, 1) })
		end
	else
		piece(hammer, hand, gripY, { Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4 * s, 0.35 * s, 0.35 * s), CFrame = CFrame.new(0, 0, -1.4 * s) * forward, Color = item.handle, Material = item.material == Enum.Material.Neon and Enum.Material.SmoothPlastic or item.material })
		if item.shape == "mallet" then
			piece(hammer, hand, gripY, { Name = "Head", Size = Vector3.new(1.5, 2.6, 1.5) * s, CFrame = CFrame.new(0, 0, -3.3 * s), Color = item.head, Material = item.material })
		else
			piece(hammer, hand, gripY, { Name = "Head", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6 * s, 1.6 * s, 1.6 * s), CFrame = CFrame.new(0, 0, -3.3 * s) * upright, Color = item.head, Material = item.material })
			for _, side in ipairs({ -1, 1 }) do
				piece(hammer, hand, gripY, { Name = "Cap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25 * s, 1.75 * s, 1.75 * s), CFrame = CFrame.new(0, 1.3 * side * s, -3.3 * s) * upright, Color = item.handle, Material = item.material == Enum.Material.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic })
			end
		end
	end
	hammer.Parent = model
	return hammer
end

------------------------------------------------------------------ Name tags
-- info = { name, nameColor, title (cosmetic item or nil), subtitle }
function CosmeticService.Tag(model, info)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("BonkTag")
	if old then
		old:Destroy()
	end
	if tagConnections[model] then
		for _, connection in ipairs(tagConnections[model]) do
			connection:Disconnect()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "BonkTag"
	gui.Size = UDim2.fromOffset(220, 96)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 140
	gui.Adornee = head
	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local order = 0
	local function line(name, text, color, height)
		order += 1
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextStrokeTransparency = 0.3
		label.LayoutOrder = order
		label.Parent = gui
		return label
	end
	local damage = line("Damage", "0%", Color3.new(1, 1, 1), 30)
	if info.title then
		line("Title", info.title.text, info.title.color, 16)
	end
	line("PlayerName", info.name, info.nameColor or Color3.new(1, 1, 1), 22)
	line("Sub", info.subtitle or "", Color3.fromRGB(150, 220, 255), 16)

	local function refresh()
		local value = math.floor(model:GetAttribute("Damage") or 0)
		damage.Text = value .. "%"
		damage.TextColor3 = Format.DamageColor(value)
		damage.Visible = model:GetAttribute("ShowDamage") == true
	end
	tagConnections[model] = {
		model:GetAttributeChangedSignal("Damage"):Connect(refresh),
		model:GetAttributeChangedSignal("ShowDamage"):Connect(refresh),
		model.Destroying:Connect(function()
			tagConnections[model] = nil
		end),
	}
	refresh()
	gui.Parent = head
end

------------------------------------------------------------------ VIP crown
-- A real king's crown built from parts: a gold band with a darker rim,
-- five tall points with pearls on top and five small ones between them,
-- jewels on the band, a red velvet cap inside and a gold orb on top.
local CROWN_GOLD = Color3.fromRGB(255, 196, 45)
local CROWN_RIM = Color3.fromRGB(214, 140, 22)
local CROWN_VELVET = Color3.fromRGB(170, 20, 45)
local PEARL = Color3.fromRGB(255, 250, 235)
local JEWELS = { Color3.fromRGB(235, 30, 60), Color3.fromRGB(40, 120, 255), Color3.fromRGB(235, 30, 60), Color3.fromRGB(40, 200, 110), Color3.fromRGB(40, 120, 255) }
local CROWN_SIDES = 10

local function buildCrown(character, head)
	local crown = Instance.new("Model")
	crown.Name = "BonkCrown"

	-- Sized to the head, so it fits big and small avatars alike
	local s = math.clamp(math.min(head.Size.X, head.Size.Z) / 1.2, 0.75, 1.5)
	local radius = 0.56 * s
	local bandHeight = 0.3 * s
	local thickness = 0.07 * s
	local sideWidth = 2 * radius * math.tan(math.pi / CROWN_SIDES) + 0.03 * s
	-- Center of the band: a little above the head, so it sits on top of most hair
	local bandY = head.Size.Y / 2 + 0.14 * s + bandHeight / 2

	local function add(className, size, offset, color, material, props)
		local part = Instance.new(className)
		part.Name = "CrownPiece"
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.Metal
		part.Reflectance = material == nil and 0.15 or 0
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.CFrame = head.CFrame * offset
		for key, value in pairs(props or {}) do
			part[key] = value
		end
		local weld = Instance.new("Weld")
		weld.Part0 = head
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = part
		part.Parent = crown
		return part
	end

	-- A triangle point standing on the band, made of two mirrored wedges
	local function point(side, height, width)
		local half = width / 2
		local base = side * CFrame.new(0, bandHeight / 2 + height / 2, 0)
		local size = Vector3.new(thickness, height, half)
		add("WedgePart", size, base * CFrame.new(-half / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), CROWN_GOLD)
		add("WedgePart", size, base * CFrame.new(half / 2, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0), CROWN_GOLD)
	end

	local jewel = 0
	for index = 0, CROWN_SIDES - 1 do
		-- Side 0 faces forward (-Z); each side's own Z points away from the center
		local angle = math.pi + index * 2 * math.pi / CROWN_SIDES
		local side = CFrame.new(0, bandY, 0) * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, radius)
		add("Part", Vector3.new(sideWidth, bandHeight, thickness), side, CROWN_GOLD)
		-- Rim along the bottom
		add("Part", Vector3.new(sideWidth + 0.02 * s, 0.07 * s, thickness * 1.6), side * CFrame.new(0, -bandHeight / 2 + 0.035 * s, 0), CROWN_RIM)

		if index % 2 == 0 then
			local height = 0.38 * s
			point(side, height, sideWidth)
			add("Part", Vector3.one * 0.13 * s, side * CFrame.new(0, bandHeight / 2 + height + 0.03 * s, 0), PEARL, Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Ball, Reflectance = 0.3 })
			jewel += 1
			local gemSize = (index == 0 and 0.15 or 0.11) * s
			add("Part", Vector3.one * gemSize, side * CFrame.new(0, 0.01 * s, thickness / 2), JEWELS[jewel], Enum.Material.Neon, { Shape = Enum.PartType.Ball })
		else
			point(side, 0.17 * s, sideWidth * 0.8)
		end
	end

	-- Velvet cap inside the band, and a gold orb on its top
	local capHeight = 0.42 * s
	local cap = add("Part", Vector3.one, CFrame.new(0, bandY + bandHeight / 2 - 0.04 * s, 0), CROWN_VELVET, Enum.Material.Fabric)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(radius * 1.9, capHeight * 2, radius * 1.9)
	mesh.Parent = cap
	local orbY = bandY + bandHeight / 2 - 0.04 * s + capHeight + 0.05 * s
	add("Part", Vector3.one * 0.16 * s, CFrame.new(0, orbY, 0), CROWN_GOLD, nil, { Shape = Enum.PartType.Ball })
	-- A little cross on the orb
	add("Part", Vector3.new(0.04, 0.16, 0.04) * s, CFrame.new(0, orbY + 0.14 * s, 0), CROWN_GOLD)
	add("Part", Vector3.new(0.12, 0.04, 0.04) * s, CFrame.new(0, orbY + 0.16 * s, 0), CROWN_GOLD)

	-- Now and then a glint of light
	local glint = Instance.new("ParticleEmitter")
	glint.Name = "CrownGlint"
	glint.Color = ColorSequence.new(Color3.fromRGB(255, 240, 180))
	glint.LightEmission = 1
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35 * s), NumberSequenceKeypoint.new(1, 0) })
	glint.Lifetime = NumberRange.new(0.4, 0.6)
	glint.Rate = 1.5
	glint.Speed = NumberRange.new(0)
	glint.Rotation = NumberRange.new(0, 90)
	glint.LockedToPart = true
	glint.Parent = cap

	crown.Parent = character
	return crown
end

------------------------------------------------------------------ Players
local function clearOld(character)
	for _, item in ipairs(character:GetDescendants()) do
		if item.Name == "BonkTrail" or item.Name == "BonkCrown" or item.Name == "BonkTrailTop" or item.Name == "BonkTrailBottom" then
			item:Destroy()
		end
	end
end

local function applyToCharacter(player)
	local data = DataService.Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local head = character:WaitForChild("Head", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if not head or not root or not character.Parent then
		return
	end
	clearOld(character)

	local vip = isVip(player)
	local title = Cosmetics.Equipped(data, "title", vip)
	CosmeticService.Tag(character, {
		name = player.DisplayName,
		nameColor = vip and VIP_GOLD or nil,
		title = title,
		subtitle = string.format("%sLv %d", vip and "VIP  " or "", Level.FromXp(data.xp)),
	})

	if not character:GetAttribute("GiantHammer") then
		CosmeticService.BuildHammer(character, Cosmetics.Equipped(data, "hammer", vip))
	end

	if vip then
		buildCrown(character, head)
	end

	local trailItem = Cosmetics.Equipped(data, "trail", vip)
	if trailItem then
		local top = Instance.new("Attachment")
		top.Name = "BonkTrailTop"
		top.Position = Vector3.new(0, 0.8, 0.5)
		top.Parent = root
		local bottom = Instance.new("Attachment")
		bottom.Name = "BonkTrailBottom"
		bottom.Position = Vector3.new(0, -0.8, 0.5)
		bottom.Parent = root
		local keypoints = {}
		for index, color in ipairs(trailItem.colors) do
			table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #trailItem.colors - 1), color))
		end
		local trail = Instance.new("Trail")
		trail.Name = "BonkTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(keypoints)
		trail.Lifetime = 0.6
		trail.LightEmission = 0.6
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.Parent = root
	end
end

-- Rebuilds a player's hammer (after the Giant Hammer power-up ends, for example)
function CosmeticService.RefreshHammer(player, scale)
	local character = player.Character
	if character then
		CosmeticService.BuildHammer(character, CosmeticService.Equipped(player, "hammer"), scale)
	end
end

local function signature(data, runtime)
	local equipped = data.cosmetics.equipped
	return table.concat({
		tostring(equipped.title),
		tostring(equipped.trail),
		tostring(equipped.hammer),
		tostring(runtime.passes and runtime.passes.VIP),
		tostring(Level.FromXp(data.xp)),
	}, "|")
end

------------------------------------------------------------------ Free unlocks
local function unlocked(item, data)
	if item.source == "level" then
		return Level.FromXp(data.xp) >= item.level
	elseif item.source == "earned" then
		return (data.stats[item.rule] or 0) >= item.amount
	end
	return false
end

local function checkUnlocks(player, data)
	local new = {}
	for _, item in ipairs(Cosmetics.List) do
		if (item.source == "level" or item.source == "earned") and not data.cosmetics.owned[item.id] and unlocked(item, data) then
			table.insert(new, item)
		end
	end
	if #new == 0 then
		return
	end
	DataService.Update(player, function(saved)
		for _, item in ipairs(new) do
			saved.cosmetics.owned[item.id] = true
		end
	end)
	for _, item in ipairs(new) do
		Remotes.Notify:FireClient(player, "Unlocked: " .. item.name .. "! Equip it in the Locker.", "rare")
	end
end

------------------------------------------------------------------ Victory dances
-- Each dance moves the whole character for a few seconds: t = seconds since the
-- start, returns an offset from where the character stands.
local DANCES = {
	dance_cheer = function(t)
		local hop = math.abs(math.sin(t * math.pi * 1.6)) * 2.5
		return CFrame.new(0, hop, 0)
	end,
	dance_jump = function(t)
		local cycle = t % 2
		local height = math.max(0, math.sin(cycle / 1.2 * math.pi)) * 9
		local turn = cycle < 1.2 and cycle / 1.2 * math.pi * 2 or 0
		return CFrame.new(0, height, 0) * CFrame.Angles(0, turn, 0)
	end,
	dance_spin = function(t)
		return CFrame.Angles(0, t * math.pi * 3, 0)
	end,
	dance_hop = function(t)
		local hop = math.abs(math.sin(t * math.pi * 2.5)) * 1.8
		local side = math.sin(t * math.pi * 1.25) * 2
		return CFrame.new(side, hop, 0)
	end,
	dance_flip = function(t)
		local cycle = t % 1.6
		local height = math.max(0, math.sin(cycle / 1.1 * math.pi)) * 6
		local flip = cycle < 1.1 and cycle / 1.1 * math.pi * 2 or 0
		return CFrame.new(0, height, 0) * CFrame.Angles(flip, 0, 0)
	end,
	dance_heli = function(t)
		local height = math.sin(math.min(t, 5) / 5 * math.pi) * 7
		return CFrame.new(0, height, 0) * CFrame.Angles(0, t * math.pi * 8, 0)
	end,
}

-- Plays a victory dance on a model standing at standCFrame, for seconds.
function CosmeticService.Dance(model, danceId, standCFrame, seconds)
	local root = model:FindFirstChild("HumanoidRootPart")
	local dance = DANCES[danceId] or DANCES.dance_cheer
	if not root then
		return
	end
	root.Anchored = true
	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t >= seconds or not root.Parent then
			connection:Disconnect()
			if root.Parent then
				model:PivotTo(standCFrame)
				root.Anchored = false
			end
			return
		end
		model:PivotTo(standCFrame * dance(t))
	end)
end

function CosmeticService.Start()
	DataService.OnChanged(function(player, data, runtime)
		checkUnlocks(player, data)
		local current = signature(data, runtime)
		if applied[player] ~= current then
			applied[player] = current
			applyToCharacter(player)
		end
	end)

	local function watch(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			applyToCharacter(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		applied[player] = nil
	end)
end

return CosmeticService
