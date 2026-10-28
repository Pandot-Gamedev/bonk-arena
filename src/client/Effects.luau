-- Hit sparks, damage numbers, knockout effects and sounds. The server says what
-- happened and where (the Effect remote); every player draws it on their own screen.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)
local PowerUps = require(Shared.PowerUps)
local Remotes = require(Shared.Remotes)

local Effects = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SOUNDS = {
	bonk = { "rbxasset://sounds/collide.wav", 0.8 },
	swing = { "rbxasset://sounds/swordslash.wav", 0.25 },
	dash = { "rbxasset://sounds/swordlunge.wav", 0.3 },
	ko = { "rbxasset://sounds/uuhhh.mp3", 0.6 },
	block = { "rbxasset://sounds/electronicpingshort.wav", 0.5 },
	crack = { "rbxasset://sounds/glassbreak.wav", 0.35 },
	powerup = { "rbxasset://sounds/electronicpingshort.wav", 0.6 },
}

local folder

local function anchor(position)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	p.Parent = folder
	return p
end

function Effects.Sound(name, position)
	local info = SOUNDS[name]
	if not info then
		return
	end
	local holder = anchor(position)
	local sound = Instance.new("Sound")
	sound.SoundId = info[1]
	sound.Volume = info[2]
	sound.RollOffMaxDistance = 200
	sound.Parent = holder
	sound:Play()
	Debris:AddItem(holder, 3)
end

-- A burst of particles in the given colors
function Effects.Burst(position, colors, count, speed, texture, size)
	local holder = anchor(position)
	local keypoints = {}
	for index, color in ipairs(colors) do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture or SPARKLE
	emitter.Color = ColorSequence.new(keypoints)
	emitter.Size = NumberSequence.new(size or 1, 0)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Drag = 3
	emitter.LightEmission = 0.5
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, 2)
	return holder
end

-- Text that floats up and fades, like "+10%" or "KO!"
function Effects.Popup(position, text, color, size, seconds)
	local holder = anchor(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 4, size)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextStrokeTransparency = 0
	label.Parent = gui
	seconds = seconds or 0.9
	TweenService:Create(holder, TweenInfo.new(seconds), { Position = position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(holder, seconds + 0.1)
end

local function ring(position, color, radius)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.new(0.4, 2, 2)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = folder
	TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	Debris:AddItem(p, 0.4)
end

local function lightning(position, colors)
	local top = position + Vector3.new(0, 40, 0)
	local previous = top
	for step = 1, 6 do
		local nextPoint = top:Lerp(position, step / 6) + (step < 6 and Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)) or Vector3.zero)
		local length = (nextPoint - previous).Magnitude
		local bolt = Instance.new("Part")
		bolt.Anchored = true
		bolt.CanCollide = false
		bolt.CanQuery = false
		bolt.CanTouch = false
		bolt.Material = Enum.Material.Neon
		bolt.Color = colors[1]
		bolt.Size = Vector3.new(0.6, 0.6, length)
		bolt.CFrame = CFrame.lookAt((previous + nextPoint) / 2, nextPoint)
		bolt.Parent = folder
		TweenService:Create(bolt, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		Debris:AddItem(bolt, 0.6)
		previous = nextPoint
	end
	Effects.Burst(position, colors, 40, 30)
end

-- The knockout effect the knocker has equipped
function Effects.Knockout(position, effectId)
	local item = Cosmetics.ById[effectId or ""] or Cosmetics.ById["ko_poof"]
	local colors = item.colors
	if item.id == "ko_poof" then
		Effects.Burst(position, colors, 30, 15, SMOKE, 4)
	elseif item.id == "ko_bubbles" then
		Effects.Burst(position, colors, 40, 12, SPARKLE, 3)
	elseif item.id == "ko_hearts" then
		Effects.Burst(position, colors, 50, 25, SPARKLE, 2.5)
		Effects.Popup(position + Vector3.new(0, 2, 0), "<3", colors[1], 60, 1.2)
	elseif item.id == "ko_confetti" then
		Effects.Burst(position, colors, 120, 45, SPARKLE, 1.5)
	elseif item.id == "ko_star" then
		Effects.Burst(position, colors, 60, 35, SPARKLE, 3)
		Effects.Popup(position + Vector3.new(0, 3, 0), "*", colors[1], 120, 1.2)
	elseif item.id == "ko_fireworks" then
		for index = 1, 4 do
			task.delay(index * 0.18, function()
				local at = position + Vector3.new(math.random(-8, 8), math.random(6, 14), math.random(-8, 8))
				Effects.Burst(at, { colors[(index % #colors) + 1], colors[1] }, 50, 40, SPARKLE, 2)
			end)
		end
	elseif item.id == "ko_lightning" then
		lightning(position, colors)
	else
		Effects.Burst(position, colors, 60, 30)
	end
	Effects.Popup(position + Vector3.new(0, 5, 0), "KO!", Color3.fromRGB(255, 90, 60), 70, 1.4)
	Effects.Sound("ko", position)
end

local handlers = {
	hit = function(position, extra)
		Effects.Burst(position, { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 60) }, extra and extra.big and 40 or 20, 30)
		Effects.Popup(position + Vector3.new(0, 3, 0), "+" .. (extra and extra.damage or 0) .. "%", Color3.fromRGB(255, 220, 80), 34)
		Effects.Sound("bonk", position)
	end,
	block = function(position)
		Effects.Burst(position, { Color3.fromRGB(90, 200, 255), Color3.new(1, 1, 1) }, 30, 25)
		Effects.Popup(position + Vector3.new(0, 3, 0), "BLOCKED", Color3.fromRGB(120, 210, 255), 30)
		Effects.Sound("block", position)
	end,
	swing = function(position)
		Effects.Sound("swing", position)
	end,
	dash = function(position)
		Effects.Burst(position - Vector3.new(0, 2, 0), { Color3.new(1, 1, 1) }, 12, 8, SMOKE, 2)
		Effects.Sound("dash", position)
	end,
	ko = function(position, extra)
		Effects.Knockout(position, extra and extra.effect)
	end,
	powerup = function(position, extra)
		local powerUp = PowerUps.ById[extra and extra.id or ""]
		if powerUp then
			Effects.Burst(position, { powerUp.color, Color3.new(1, 1, 1) }, 40, 25)
			Effects.Popup(position + Vector3.new(0, 4, 0), powerUp.name .. "!", powerUp.color, 36, 1.3)
		end
		Effects.Sound("powerup", position)
	end,
	shockwave = function(position, extra)
		ring(position - Vector3.new(0, 2.5, 0), Color3.fromRGB(200, 90, 255), extra and extra.range or 10)
	end,
	slip = function(position)
		Effects.Popup(position + Vector3.new(0, 3, 0), "SLIP!", Color3.fromRGB(255, 240, 90), 36)
	end,
	bounce = function(position)
		Effects.Burst(position, { Color3.fromRGB(255, 110, 200) }, 15, 15)
		Effects.Popup(position + Vector3.new(0, 3, 0), "BOING", Color3.fromRGB(255, 140, 220), 28)
	end,
	crack = function(position)
		Effects.Sound("crack", position)
	end,
}

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "BonkEffects"
	folder.Parent = Workspace
	Remotes.Effect.OnClientEvent:Connect(function(kind, position, extra)
		local handler = handlers[kind]
		if handler and typeof(position) == "Vector3" then
			handler(position, extra)
		end
	end)
end

return Effects
