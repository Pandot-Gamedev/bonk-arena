-- Bonk and dash controls, and flying when you get bonked.
--   Bonk: click, F, R2 on a controller, or the BONK button on phones
--   Dash: Q, X on a controller, or the DASH button on phones
-- The server decides who gets hit; this script only asks to swing.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Controls = {}

local player = Players.LocalPlayer
local lastBonk = 0
local lastDash = 0
local stunToken = 0
local stunnedUntil = 0
local dashing = nil

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

local function stopDash()
	if dashing then
		dashing.mover:Destroy()
		dashing.attachment:Destroy()
		dashing = nil
	end
end

function Controls.Bonk()
	local now = os.clock()
	if now - lastBonk < Config.BonkCooldown or now < stunnedUntil or not parts() then
		return
	end
	lastBonk = now
	Remotes.Bonk:FireServer()
end

function Controls.Dash()
	local now = os.clock()
	local root, humanoid = parts()
	if not root or now - lastDash < Config.DashCooldown or now < stunnedUntil or humanoid.WalkSpeed <= 0 then
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
	stopDash()
	local attachment = Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root
	local mover = Instance.new("LinearVelocity")
	mover.Name = "Dash"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = Vector3.new(1e6, 0, 1e6)
	mover.VectorVelocity = direction.Unit * Config.DashSpeed
	mover.Parent = root
	local this = { mover = mover, attachment = attachment }
	dashing = this
	task.delay(Config.DashSeconds, function()
		if dashing == this then
			stopDash()
		end
	end)
	Remotes.Dash:FireServer()
end

-- 0 to 1: how ready each move is (for the phone buttons)
function Controls.Cooldowns()
	local now = os.clock()
	return math.clamp((now - lastBonk) / Config.BonkCooldown, 0, 1), math.clamp((now - lastDash) / Config.DashCooldown, 0, 1)
end

local function onLaunch(velocity, stun, spin)
	local root, humanoid = parts()
	if not root then
		return
	end
	stopDash()
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

function Controls.Init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	ContextActionService:BindAction("BonkArenaBonk", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Bonk()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("BonkArenaBonk", "BONK")
	ContextActionService:SetPosition("BonkArenaBonk", UDim2.new(1, -150, 1, -150))

	ContextActionService:BindAction("BonkArenaDash", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Dash()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("BonkArenaDash", "DASH")
	ContextActionService:SetPosition("BonkArenaDash", UDim2.new(1, -230, 1, -100))

	Remotes.Launch.OnClientEvent:Connect(onLaunch)
	player.CharacterAdded:Connect(function()
		stunToken += 1
		stunnedUntil = 0
		dashing = nil
	end)
end

return Controls
