-- Power-ups drop onto the arena during a round. Anyone can grab them, and they
-- are never sold, so every player has the same chance.

local PowerUps = {}

PowerUps.List = {
	{ id = "giant", name = "Giant Hammer", letter = "G", color = Color3.fromRGB(255, 80, 80), description = "Your bonks hit 60% harder and reach further for 8 seconds." },
	{ id = "shield", name = "Bounce Shield", letter = "S", color = Color3.fromRGB(90, 200, 255), description = "Blocks the next 2 bonks that hit you." },
	{ id = "speed", name = "Speed Boots", letter = ">", color = Color3.fromRGB(255, 220, 60), description = "Run much faster for 8 seconds." },
	{ id = "iron", name = "Iron Boots", letter = "I", color = Color3.fromRGB(160, 160, 175), description = "Bonks push you only half as far for 8 seconds." },
	{ id = "magnet", name = "Magnet Bonk", letter = "M", color = Color3.fromRGB(200, 90, 255), description = "Pulls rivals toward you, and your next bonk hits all around you." },
	{ id = "banana", name = "Banana Peel", letter = "B", color = Color3.fromRGB(255, 240, 90), description = "Drops a banana behind you. Rivals who step on it slip!" },
}

PowerUps.ById = {}
for _, powerUp in ipairs(PowerUps.List) do
	PowerUps.ById[powerUp.id] = powerUp
end

PowerUps.GiantPower = 1.6
PowerUps.GiantReach = 3 -- extra studs of reach
PowerUps.ShieldHits = 2
PowerUps.SpeedWalkSpeed = 28
PowerUps.IronShare = 0.5
PowerUps.MagnetRange = 30
PowerUps.MagnetBonkRange = 11
PowerUps.MagnetBonkSeconds = 5
PowerUps.BananaSeconds = 20

return PowerUps
