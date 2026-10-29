-- Hit sparks, damage numbers, knockout effects, screen shake and sounds. The
-- server says what happened and where (the Effect remote); every player draws
-- it on their own screen.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Cosmetics = require(Shared.Cosmetics)
local PowerUps = require(Shared.PowerUps)
local Remotes = require(Shared.Remotes)

local Swing = require(script.Parent.Swing)

local Effects = {}

local player = Players.LocalPlayer

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
-- { sound, volume, pitch, random pitch +/- }
local SOUNDS = {
	bonk = { "rbxasset://sounds/collide.wav", 0.9, 1, 0.12 },
	thump = { "rbxasset://sounds/collide.wav", 0.35, 0.6, 0.08 },
	swing = { "rbxasset://sounds/swordslash.wav", 0.3, 1.1, 0.1 },
	dodge = { "rbxasset://sounds/swordlunge.wav", 0.4, 1.4 },
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
	sound.PlaybackSpeed = (info[3] or 1) + (info[4] and (math.random() * 2 - 1) * info[4] or 0)
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

-- Shakes your camera a little (when you land a bonk or get bonked)
local shakeUntil, shakeSeconds, shakeStrength = 0, 1, 0
function Effects.Shake(strength, seconds)
	local now = os.clock()
	local left = now < shakeUntil and shakeStrength * (shakeUntil - now) / shakeSeconds or 0
	if strength >= left then
		shakeStrength, shakeSeconds, shakeUntil = strength, seconds, now + seconds
	end
end

local function shakeCamera()
	local now = os.clock()
	if now >= shakeUntil then
		return
	end
	local camera = Workspace.CurrentCamera
	local s = shakeStrength * (shakeUntil - now) / shakeSeconds
	-- Only move sideways and roll, so the camera's own aiming is never thrown off
	camera.CFrame = camera.CFrame * CFrame.new((math.random() * 2 - 1) * s, (math.random() * 2 - 1) * s, 0) * CFrame.Angles(0, 0, (math.random() * 2 - 1) * s * 0.03)
end

-- A white flash over a character that just got bonked
local function flash(model)
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.15
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = folder
	TweenService:Create(highlight, TweenInfo.new(0.22), { FillTransparency = 1 }):Play()
	Debris:AddItem(highlight, 0.25)
end

-- Dust and a thump where a hammer hits the ground
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
function Effects.Impact(model, position)
	local ignore = CollectionService:GetTagged("Bonkable")
	table.insert(ignore, folder)
	table.insert(ignore, model)
	groundParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -7, 0), groundParams)
	local at = hit and hit.Position or position
	ring(at + Vector3.new(0, 0.15, 0), Color3.fromRGB(255, 245, 225), 3)
	Effects.Burst(at, { Color3.fromRGB(240, 230, 210) }, 8, 10, SMOKE, 1.4)
	Effects.Sound("thump", at)
	if model == player.Character then
		Effects.Shake(0.08, 0.1)
	end
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

local BIG_WORDS = { "BONK!", "WHAM!", "POW!", "BOING!" }

local handlers = {
	hit = function(position, extra)
		extra = extra or {}
		local total = extra.total or 0
		Effects.Burst(position, { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 60) }, extra.big and 45 or 25, 32)
		Effects.Popup(position + Vector3.new(0, 3, 0), "+" .. (extra.damage or 0) .. "%", Color3.fromRGB(255, 220, 80), 34)
		if extra.big or total >= 80 then
			Effects.Popup(position + Vector3.new(0, 5, 0), BIG_WORDS[math.random(#BIG_WORDS)], Color3.fromRGB(255, 120, 60), 56, 0.8)
		end
		Effects.Sound("bonk", position)
		flash(extra.target)
		local character = player.Character
		if character and extra.target == character then
			Effects.Shake(0.25 + math.min(total, 150) / 500, 0.25)
		elseif character and extra.by == character then
			Effects.Shake(0.18, 0.12)
		end
	end,
	dodge = function(position)
		Effects.Popup(position + Vector3.new(0, 3, 0), "DODGE!", Color3.fromRGB(120, 230, 255), 34)
		Effects.Sound("dodge", position)
	end,
	block = function(position)
		Effects.Burst(position, { Color3.fromRGB(90, 200, 255), Color3.new(1, 1, 1) }, 30, 25)
		Effects.Popup(position + Vector3.new(0, 3, 0), "BLOCKED", Color3.fromRGB(120, 210, 255), 30)
		Effects.Sound("block", position)
	end,
	swing = function(position, extra)
		-- Your own swing already played the moment you pressed BONK
		local model = extra and extra.model
		if typeof(model) == "Instance" and model ~= player.Character then
			Swing.Play(model, Effects.Impact)
			Effects.Sound("swing", position)
		end
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
	RunService:BindToRenderStep("BonkShake", Enum.RenderPriority.Camera.Value + 1, shakeCamera)
	Remotes.Effect.OnClientEvent:Connect(function(kind, position, extra)
		local handler = handlers[kind]
		if handler and typeof(position) == "Vector3" then
			handler(position, extra)
		end
	end)
end

return Effects
