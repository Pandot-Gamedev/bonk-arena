-- Bonk and dash controls, and flying when you get bonked.
--   Bonk: click, F, R2 on a controller, or the BONK button on phones
--   Dash: Q, X on a controller, or the DASH button on phones
-- While a menu (Shop, Locker, Quests, Arena) is open you stand still and
-- can't bonk, dash or jump.
-- Pressing BONK turns you to the closest rival in reach (and lunges you a
-- little if they are just out of reach), then swings straight away on your
-- screen. The server still decides who gets hit.

local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Swing = require(script.Parent.Swing)
local UI = require(script.Parent.UI)

local Controls = {}

local player = Players.LocalPlayer
local lastBonk = 0
local lastDash = 0
local stunToken = 0
local stunnedUntil = 0
local moving = nil -- the dash or lunge pushing you right now
local turnToken = 0

local function parts()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

local function flat(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function stopMoving()
	if moving then
		moving.mover:Destroy()
		moving.attachment:Destroy()
		moving = nil
	end
end

-- Pushes your character along the ground for a moment (dash and lunge)
local function push(root, velocity, seconds)
	stopMoving()
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "Dash"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	mover.VectorVelocity = velocity
	mover.Parent = root
	local this = { mover = mover, attachment = attachment }
	moving = this
	task.delay(seconds, function()
		if moving == this then
			stopMoving()
		end
	end)
end

-- The closest rival you could bonk: in a match, the others in your match;
-- in the lobby, the practice dummies. Rivals you are already facing count as
-- a little closer.
local function aimTarget(root)
	local character = player.Character
	local mySpace = character:GetAttribute("Space")
	local look = flat(root.CFrame.LookVector)
	look = look.Magnitude > 0.1 and look.Unit or Vector3.new(0, 0, -1)
	local best, bestScore, bestOffset = nil, math.huge, nil
	for _, model in ipairs(CollectionService:GetTagged("Bonkable")) do
		local allowed
		if mySpace ~= nil then
			allowed = model:GetAttribute("Space") == mySpace
		else
			allowed = model:GetAttribute("BonkKind") == "dummy"
		end
		local otherRoot = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if allowed and model ~= character and otherRoot and humanoid and humanoid.Health > 0 then
			local offset = otherRoot.Position - root.Position
			local distance = flat(offset).Magnitude
			if distance <= Config.AimRange and math.abs(offset.Y) <= 6 then
				local facing = distance > 0.1 and look:Dot(flat(offset).Unit) or 1
				local score = distance - facing * 3
				if score < bestScore then
					best, bestScore, bestOffset = model, score, flat(offset)
				end
			end
		end
	end
	return best, bestOffset
end

-- Seconds until the server lets you swing again after a miss
local function missWait()
	local character = player.Character
	local readyAt = character and character:GetAttribute("BonkReadyAt")
	return readyAt and math.max(0, readyAt - Workspace:GetServerTimeNow()) or 0
end

function Controls.Bonk()
	local now = os.clock()
	local root, humanoid = parts()
	if not root or UI.IsWindowOpen() or now - lastBonk < Config.BonkCooldown or now < stunnedUntil or missWait() > 0.05 then
		return
	end
	if humanoid.WalkSpeed <= 0 then
		return -- frozen for the countdown
	end
	lastBonk = now

	local aim = flat(root.CFrame.LookVector)
	local target, offset = aimTarget(root)
	if target and offset.Magnitude > 0.1 then
		aim = offset.Unit
		-- Face them for the whole swing, even while walking another way
		root.CFrame = CFrame.lookAt(root.Position, root.Position + aim)
		humanoid.AutoRotate = false
		turnToken += 1
		local token = turnToken
		task.delay(Swing.ImpactSeconds + 0.1, function()
			if turnToken == token and humanoid.Parent then
				humanoid.AutoRotate = true
			end
		end)
		local gap = offset.Magnitude - 3.5
		if gap > 0.5 then
			push(root, aim * math.min(gap, Config.LungeDistance) / Config.LungeSeconds, Config.LungeSeconds)
		end
	end
	Swing.Play(player.Character, Controls.OnImpact)
	if Controls.OnSwing then
		Controls.OnSwing(root.Position)
	end
	Remotes.Bonk:FireServer(aim.Magnitude > 0.1 and aim.Unit or nil)
end

function Controls.Dash()
	local now = os.clock()
	local root, humanoid = parts()
	if not root or UI.IsWindowOpen() or now - lastDash < Config.DashCooldown or now < stunnedUntil or humanoid.WalkSpeed <= 0 then
		return
	end
	local direction = flat(humanoid.MoveDirection)
	if direction.Magnitude < 0.1 then
		direction = flat(root.CFrame.LookVector)
	end
	if direction.Magnitude < 0.1 then
		return
	end
	lastDash = now
	push(root, direction.Unit * Config.DashSpeed, Config.DashSeconds)
	Remotes.Dash:FireServer()
end

-- 0 to 1: how ready each move is (for the phone buttons)
function Controls.Cooldowns()
	local now = os.clock()
	local bonk = math.clamp((now - lastBonk) / Config.BonkCooldown, 0, 1)
	local miss = missWait()
	if miss > 0 then
		bonk = math.min(bonk, 1 - miss / Config.BonkMissCooldown)
	end
	return math.clamp(bonk, 0, 1), math.clamp((now - lastDash) / Config.DashCooldown, 0, 1)
end

local function onLaunch(velocity, stun, spin)
	local root, humanoid = parts()
	if not root then
		return
	end
	stopMoving()
	stunToken += 1
	local token = stunToken
	stunnedUntil = os.clock() + stun
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = spin or Vector3.zero
	task.delay(stun, function()
		if stunToken ~= token or not humanoid.Parent then
			return
		end
		humanoid.PlatformStand = false
		root.AssemblyAngularVelocity = Vector3.zero
		-- Stand back up straight, facing the same way
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.1 then
			look = Vector3.new(0, 0, -1)
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
	end)
end

------------------------------------------------------------------ Menu freeze
-- Roblox's own movement controls (keyboard, thumbstick, controller)
local robloxControls = nil
local function getRobloxControls()
	if robloxControls == nil then
		local ok, controls = pcall(function()
			local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
			return require(module):GetControls()
		end)
		robloxControls = ok and controls or false
	end
	return robloxControls or nil
end

local function onMenuChanged()
	local open = UI.IsWindowOpen()
	local controls = getRobloxControls()
	if controls then
		if open then
			controls:Disable()
		else
			controls:Enable()
		end
	end
	if open then
		stopMoving()
		local _, humanoid = parts()
		if humanoid then
			humanoid:Move(Vector3.zero)
			humanoid.Jump = false
		end
	end
end

-- Runs right after Roblox reads the controls each frame, so nothing can
-- walk or jump you while a menu is open (even a controller plugged in later)
local function holdStill()
	if not UI.IsWindowOpen() then
		return
	end
	local _, humanoid = parts()
	if humanoid then
		humanoid:Move(Vector3.zero)
		humanoid.Jump = false
	end
end

function Controls.Init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- Keyboard, mouse and controller. Phones get their own big buttons (TouchButtons.luau).
	ContextActionService:BindAction("BonkArenaBonk", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Bonk()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("BonkArenaDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Dash()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)

	Remotes.Launch.OnClientEvent:Connect(onLaunch)
	player.CharacterAdded:Connect(function()
		stunToken += 1
		stunnedUntil = 0
		moving = nil
		task.defer(onMenuChanged)
	end)

	UI.WindowChanged:Connect(function()
		task.defer(onMenuChanged) -- after a switch from one menu to another settles
	end)
	RunService:BindToRenderStep("BonkArenaMenuFreeze", Enum.RenderPriority.Input.Value + 1, holdStill)
end

return Controls
