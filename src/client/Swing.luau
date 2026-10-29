-- The hammer swing, drawn on every player's own screen so it stays smooth:
-- the arm winds up over the head, slams the hammer down in front with a lean,
-- holds for a moment, then springs back. Your own swing starts the moment you
-- press BONK (Controls.luau); everyone else's starts when the server says they
-- swung (the "swing" effect in Effects.luau).

local RunService = game:GetService("RunService")

local Swing = {}

-- Joint angles in degrees at each moment of the swing:
-- { seconds, shoulder, wrist, waist, easing into this pose }
-- Shoulder: + lifts the arm forward and up. Wrist: - tips the hammer down so it
-- carries on the line of the arm. Waist: + leans back, - leans forward.
local POSES = {
	{ 0, 0, 0, 0 },
	{ 0.1, 165, 30, 10, "out" },
	{ 0.17, 60, -80, -15, "in" },
	{ 0.24, 60, -80, -15 },
	{ 0.46, 0, 0, 0, "back" },
}
-- Old blocky avatars (R6) have no wrist or waist, so the arm goes further down
local POSES_R6 = {
	{ 0, 0, 0, 0 },
	{ 0.1, 170, 0, 0, "out" },
	{ 0.17, -25, 0, 0, "in" },
	{ 0.24, -25, 0, 0 },
	{ 0.46, 0, 0, 0, "back" },
}
Swing.ImpactSeconds = 0.17 -- when the hammer hits the ground (Config.BonkImpactDelay matches it)
Swing.Seconds = 0.46
local TAKE_OVER = 0.05

local rigs = setmetatable({}, { __mode = "k" }) -- [model] = its joints, kept between swings
local active = {} -- [model] = the swing playing on it
local stepping = nil

local function ease(style, a)
	if style == "out" then
		return 1 - (1 - a) ^ 2
	elseif style == "in" then
		return a ^ 3
	elseif style == "back" then
		local c1 = 1.70158
		return 1 + (c1 + 1) * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end
	return a
end

-- A joint to turn: a Motor6D on older rigs, an AnimationConstraint on newer
-- avatars. Both are turned through their Transform, which the character's
-- Animator sets every frame, so the swing is added on top of whatever
-- animation is playing (the joint's own C0 or attachments can be ignored).
local function joint(part, name, axis)
	local found = part and part:FindFirstChild(name)
	if found and (found:IsA("Motor6D") or found:IsA("AnimationConstraint")) then
		return { joint = found, axis = axis }
	end
	return nil
end

local function rig(model)
	local cached = rigs[model]
	if cached and cached.shoulder and cached.shoulder.joint:IsDescendantOf(model) then
		return cached
	end
	local found
	local upperArm = model:FindFirstChild("RightUpperArm")
	if upperArm then
		found = {
			poses = POSES,
			shoulder = joint(upperArm, "RightShoulder", Vector3.xAxis),
			wrist = joint(model:FindFirstChild("RightHand"), "RightWrist", Vector3.xAxis),
			waist = joint(model:FindFirstChild("UpperTorso"), "Waist", Vector3.xAxis),
		}
	else
		found = { poses = POSES_R6, shoulder = joint(model:FindFirstChild("Torso"), "Right Shoulder", Vector3.zAxis) }
	end
	rigs[model] = found
	return found
end

-- Turns the joint `degrees` from its resting pose. `weight` (0 to 1) is how
-- much the swing takes over from the animation playing on it, so a running
-- arm doesn't throw the swing off.
local function turn(j, degrees, weight)
	if not j or not j.joint.Parent then
		return
	end
	local current = j.joint.Transform
	-- Unchanged since our last turn means no animation moved it this frame,
	-- so start again from the pose it had before, or the turns would pile up
	if current ~= j.written then
		j.animated = current
	end
	local from = weight >= 1 and CFrame.identity or j.animated:Lerp(CFrame.identity, weight)
	j.joint.Transform = CFrame.fromAxisAngle(j.axis, math.rad(degrees)) * from
	j.written = j.joint.Transform
end

-- Hands the joint back to its animation
local function release(j)
	if j and j.written then
		if j.joint.Parent and j.joint.Transform == j.written then
			j.joint.Transform = j.animated
		end
		j.written = nil
	end
end

local function pose(swing, t)
	local poses = swing.rig.poses
	local from, to = poses[1], poses[#poses]
	for index = 2, #poses do
		if t <= poses[index][1] then
			from, to = poses[index - 1], poses[index]
			break
		end
	end
	local span = to[1] - from[1]
	local a = span > 0 and ease(to[5], math.clamp((t - from[1]) / span, 0, 1)) or 1
	-- Take over within TAKE_OVER seconds, and hand back during the last pose
	local handBack = poses[#poses - 1][1]
	local weight = math.clamp(math.min(t / TAKE_OVER, 1 - (t - handBack) / (poses[#poses][1] - handBack)), 0, 1)
	turn(swing.rig.shoulder, from[2] + (to[2] - from[2]) * a, weight)
	turn(swing.rig.wrist, from[3] + (to[3] - from[3]) * a, weight)
	turn(swing.rig.waist, from[4] + (to[4] - from[4]) * a, weight)
end

-- A short streak behind the hammer head while it moves
local function trail(model)
	local hammer = model:FindFirstChild("BonkHammer")
	local head = hammer and hammer:FindFirstChild("Head")
	local hand = model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")
	if not head or not hand then
		return nil
	end
	local existing = head:FindFirstChild("SwingTrail")
	if existing then
		return existing
	end
	-- The streak runs across the hammer's path, so put its two edges on either side of the head
	local half = head.CFrame:VectorToObjectSpace(hand.CFrame.RightVector) * math.max(head.Size.Y, head.Size.Z) * 0.5
	local a0 = Instance.new("Attachment")
	a0.Position = half
	a0.Parent = head
	local a1 = Instance.new("Attachment")
	a1.Position = -half
	a1.Parent = head
	local streak = Instance.new("Trail")
	streak.Name = "SwingTrail"
	streak.Attachment0 = a0
	streak.Attachment1 = a1
	streak.Lifetime = 0.16
	streak.MinLength = 0.05
	streak.LightEmission = 0.6
	streak.Color = ColorSequence.new(Color3.new(1, 1, 1), head.Color)
	streak.Transparency = NumberSequence.new(0.25, 1)
	streak.WidthScale = NumberSequence.new(1, 0.3)
	streak.Enabled = false
	streak.Parent = head
	return streak
end

-- Where the hammer head is right now (for the dust when it lands)
function Swing.HeadPosition(model)
	local hammer = model:FindFirstChild("BonkHammer")
	local head = hammer and hammer:FindFirstChild("Head")
	if head then
		return head.Position
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return root and (root.Position + root.CFrame.LookVector * 3 - Vector3.new(0, 2.5, 0)) or nil
end

local function step()
	local now = os.clock()
	for model, swing in pairs(active) do
		local t = now - swing.started
		if not model.Parent then
			active[model] = nil
		else
			pose(swing, math.min(t, Swing.Seconds))
			if swing.streak then
				swing.streak.Enabled = t >= 0.06 and t <= Swing.ImpactSeconds + 0.03
			end
			if not swing.landed and t >= Swing.ImpactSeconds then
				swing.landed = true
				local position = Swing.HeadPosition(model)
				if swing.onImpact and position then
					task.spawn(swing.onImpact, model, position)
				end
			end
			if t >= Swing.Seconds then
				if swing.streak then
					swing.streak.Enabled = false
				end
				active[model] = nil
			end
		end
	end
	if next(active) == nil and stepping then
		stepping:Disconnect()
		stepping = nil
	end
end

-- Plays one swing on a character. onImpact(model, position) runs when the
-- hammer lands. A new swing on the same character restarts it.
function Swing.Play(model, onImpact)
	if not model or not model.Parent then
		return
	end
	local found = rig(model)
	if not found.shoulder then
		return
	end
	active[model] = { started = os.clock(), rig = found, onImpact = onImpact, streak = trail(model) }
	if not stepping then
		-- Stepped runs just after the Animator has posed everyone for this frame
		stepping = RunService.Stepped:Connect(step)
	end
end

return Swing
