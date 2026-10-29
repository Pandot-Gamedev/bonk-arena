-- The first-time guide. Each step points at a place in the world (a part with the
-- matching "GuideTarget" attribute) and finishes on a game event.

local Tutorial = {}

Tutorial.Steps = {
	{ event = "BonkDummy", text = "Welcome to Bonk Arena! Bonk a practice dummy: click, or tap the BONK button.", target = "Practice" },
	{ event = "Dash", text = "Nice hit! Now dash: press Q, or tap DASH. A dash also dodges bonks.", target = "Practice" },
	{ event = "Queue", text = "Ready to brawl? Step on a glowing pad to join a match.", target = "Pads" },
	{ event = "Match", text = "Knock everyone off the arena! The higher their %, the farther they fly.", target = nil },
}

Tutorial.Done = #Tutorial.Steps + 1
Tutorial.RewardCoins = 200

return Tutorial
