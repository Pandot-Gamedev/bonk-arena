-- Bonk Arena player script. Builds the screen and starts the controls.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UI = require(script.UI)
local Notifications = require(script.Notifications)
local Controls = require(script.Controls)
local Effects = require(script.Effects)
local Panels = require(script.Panels)
local MatchHud = require(script.MatchHud)
local Hud = require(script.Hud)
local Guide = require(script.Guide)
local TouchButtons = require(script.TouchButtons)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Phones play sideways only (either way round)
playerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local screenGui = UI.new("ScreenGui", {
	Name = "BonkArenaUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- Shrink the whole UI on small screens. Touch screens shrink less, so the
-- buttons stay big enough for fingers, and switch to a compact match screen.
local scale = UI.new("UIScale", { Parent = screenGui })
local function rescale()
	local camera = Workspace.CurrentCamera
	if camera then
		local size = camera.ViewportSize
		if UserInputService.TouchEnabled then
			scale.Scale = math.clamp(math.min(size.X / 950, size.Y / 600), 0.62, 1.2)
		else
			scale.Scale = math.clamp(math.min(size.X / 1100, size.Y / 700), 0.55, 1.2)
		end
		MatchHud.SetCompact(UserInputService.TouchEnabled and size.Y < 700)
	end
end
while not Workspace.CurrentCamera do
	task.wait()
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

Notifications.Init(screenGui)
Controls.Init()
Controls.OnImpact = Effects.Impact
Controls.OnSwing = function(position)
	Effects.Sound("swing", position)
end
TouchButtons.Init()
Effects.Init()
Panels.Init(screenGui)
MatchHud.Init(screenGui)
Hud.Init(screenGui)
Guide.Init(screenGui)
