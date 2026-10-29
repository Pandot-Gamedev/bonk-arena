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
	{ 0.1, 170, 25, 12, "out" },
	{ 0.17, 50, -90, -22, "in" },
	{ 0.24, 50, -90, -22 },
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

local bases = setmetatable({}, { __mode = "k" }) -- [joint target] = its resting CFrame
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

-- A joint to turn. Older rigs use a Motor6D (turn its C0); newer ones an
-- AnimationConstraint (turn the attachment on the parent part instead).
local function joint(part, name, axis)
	local found = part and part:FindFirstChild(name)
	if not found then
		return nil
	end
	local target, property
	if found:IsA("Motor6D") then
		target, property = found, "C0"
	elseif found:IsA("AnimationConstraint") and found.Attachment0 then
		target, property = found.Attachment0, "CFrame"
	else
		return nil
	end
	if not bases[target] then
		bases[target] = target[property]
	end
	return { target = target, property = property, axis = axis }
end

local function rig(model)
	local upperArm = model:FindFirstChild("RightUpperArm")
	if upperArm then
		return {
			poses = POSES,
			shoulder = joint(upperArm, "RightShoulder", Vector3.xAxis),
			wrist = joint(model:FindFirstChild("RightHand"), "RightWrist", Vector3.xAxis),
			waist = joint(model:FindFirstChild("UpperTorso"), "Waist", Vector3.xAxis),
		}
	end
	return { poses = POSES_R6, shoulder = joint(model:FindFirstChild("Torso"), "Right Shoulder", Vector3.zAxis) }
end

local function turn(j, degrees)
	if j and j.target.Parent then
		j.target[j.property] = bases[j.target] * CFrame.fromAxisAngle(j.axis, math.rad(degrees))
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
	turn(swing.rig.shoulder, from[2] + (to[2] - from[2]) * a)
	turn(swing.rig.wrist, from[3] + (to[3] - from[3]) * a)
	turn(swing.rig.waist, from[4] + (to[4] - from[4]) * a)
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
		stepping = RunService.RenderStepped:Connect(step)
	end
end

return Swing
