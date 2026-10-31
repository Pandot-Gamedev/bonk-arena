-- Every cosmetic in the game. Cosmetics are looks only: they never change how
-- hard you bonk, how far you fly or anything else about winning.
--
-- kind:   "hammer" (your hammer's look), "ko" (effect when you knock someone out),
--         "dance" (your victory dance), "title" (text above your head), "trail"
-- source: "default" (everyone has it), "coins" (buy with coins in the Locker),
--         "level" (free at that level), "robux" (developer product, see productId),
--         "vip" (comes with the VIP pass), "earned" (unlocked by playing, see rule),
--         "community" (free for joining our community, see Shared/OurGames)
--
-- HOW TO FILL IN THE PRODUCT IDS (step 5 of the build plan):
--   Creator Dashboard > your game > Monetization > Developer Products.
-- A productId of 0 means "not set up yet": the item shows as "Coming soon".

local Cosmetics = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Cosmetics.Kinds = {
	{ id = "hammer", name = "Hammers", short = "Hammers" },
	{ id = "ko", name = "Knockout effects", short = "KO effects" },
	{ id = "dance", name = "Victory dances", short = "Dances" },
	{ id = "title", name = "Titles", short = "Titles" },
	{ id = "trail", name = "Trails", short = "Trails" },
}

-- Hammer looks: shape "hammer" (foam hammer), "mallet" (wooden mallet),
-- "chicken" (rubber chicken), "fish" (a big fish)
Cosmetics.List = {
	-- Hammers
	{ id = "hammer_foam", kind = "hammer", name = "Foam Hammer", source = "default", shape = "hammer", head = rgb(235, 60, 60), handle = rgb(255, 210, 60), material = Enum.Material.SmoothPlastic },
	{ id = "hammer_blue", kind = "hammer", name = "Blue Foam Hammer", source = "coins", price = 300, shape = "hammer", head = rgb(60, 140, 255), handle = rgb(240, 240, 240), material = Enum.Material.SmoothPlastic },
	{ id = "hammer_green", kind = "hammer", name = "Green Foam Hammer", source = "coins", price = 300, shape = "hammer", head = rgb(80, 200, 90), handle = rgb(250, 240, 200), material = Enum.Material.SmoothPlastic },
	{ id = "hammer_purple", kind = "hammer", name = "Purple Foam Hammer", source = "coins", price = 500, shape = "hammer", head = rgb(160, 80, 230), handle = rgb(255, 200, 240), material = Enum.Material.SmoothPlastic },
	{ id = "hammer_mallet", kind = "hammer", name = "Wooden Mallet", source = "coins", price = 800, shape = "mallet", head = rgb(170, 120, 70), handle = rgb(120, 80, 45), material = Enum.Material.Wood },
	{ id = "hammer_ice", kind = "hammer", name = "Ice Hammer", source = "coins", price = 1500, shape = "hammer", head = rgb(170, 230, 255), handle = rgb(220, 245, 255), material = Enum.Material.Ice },
	{ id = "hammer_bronze", kind = "hammer", name = "Bronze Hammer", source = "level", level = 5, shape = "hammer", head = rgb(205, 127, 50), handle = rgb(90, 60, 40), material = Enum.Material.Metal },
	{ id = "hammer_silver", kind = "hammer", name = "Silver Hammer", source = "level", level = 15, shape = "hammer", head = rgb(200, 205, 215), handle = rgb(60, 60, 70), material = Enum.Material.Metal },
	{ id = "hammer_diamond", kind = "hammer", name = "Diamond Hammer", source = "level", level = 30, shape = "hammer", head = rgb(140, 240, 255), handle = rgb(255, 255, 255), material = Enum.Material.Glass },
	{ id = "hammer_royal", kind = "hammer", name = "Royal Hammer", source = "vip", shape = "hammer", head = rgb(255, 200, 40), handle = rgb(150, 20, 60), material = Enum.Material.Foil },
	{ id = "hammer_golden", kind = "hammer", name = "Golden Hammer", source = "robux", productId = 3723464595, suggestedPrice = 99, shape = "hammer", head = rgb(255, 190, 30), handle = rgb(255, 230, 120), material = Enum.Material.Foil },
	{ id = "hammer_neon", kind = "hammer", name = "Neon Hammer", source = "robux", productId = 3723464607, suggestedPrice = 75, shape = "hammer", head = rgb(255, 60, 200), handle = rgb(60, 255, 230), material = Enum.Material.Neon },
	{ id = "hammer_galaxy", kind = "hammer", name = "Galaxy Hammer", source = "robux", productId = 3723464586, suggestedPrice = 149, shape = "hammer", head = rgb(110, 60, 255), handle = rgb(30, 20, 60), material = Enum.Material.ForceField },
	{ id = "hammer_chicken", kind = "hammer", name = "Rubber Chicken", source = "robux", productId = 3723464593, suggestedPrice = 129, shape = "chicken", head = rgb(255, 225, 60), handle = rgb(255, 150, 40), material = Enum.Material.SmoothPlastic },
	{ id = "hammer_fish", kind = "hammer", name = "Big Fish", source = "robux", productId = 3723464615, suggestedPrice = 49, shape = "fish", head = rgb(80, 170, 220), handle = rgb(240, 120, 60), material = Enum.Material.SmoothPlastic },

	-- Knockout effects
	{ id = "ko_poof", kind = "ko", name = "Poof", source = "default", colors = { rgb(255, 255, 255), rgb(200, 200, 200) } },
	{ id = "ko_bubbles", kind = "ko", name = "Bubbles", source = "coins", price = 600, colors = { rgb(120, 220, 255), rgb(255, 255, 255) } },
	{ id = "ko_hearts", kind = "ko", name = "Hearts", source = "level", level = 10, colors = { rgb(255, 80, 140), rgb(255, 170, 200) } },
	{ id = "ko_confetti", kind = "ko", name = "Confetti Blast", source = "robux", productId = 3723464639, suggestedPrice = 49, colors = { rgb(255, 70, 70), rgb(255, 220, 50), rgb(70, 200, 255), rgb(120, 255, 120), rgb(220, 100, 255) } },
	{ id = "ko_star", kind = "ko", name = "Cartoon Star", source = "robux", productId = 3723464632, suggestedPrice = 75, colors = { rgb(255, 230, 40), rgb(255, 170, 0) } },
	{ id = "ko_fireworks", kind = "ko", name = "Fireworks", source = "robux", productId = 3723464626, suggestedPrice = 99, colors = { rgb(255, 90, 60), rgb(80, 160, 255), rgb(255, 240, 120) } },
	{ id = "ko_lightning", kind = "ko", name = "Lightning Strike", source = "robux", productId = 3723464620, suggestedPrice = 129, colors = { rgb(140, 220, 255), rgb(255, 255, 255) } },

	-- Victory dances
	{ id = "dance_cheer", kind = "dance", name = "Cheer", source = "default" },
	{ id = "dance_jump", kind = "dance", name = "Victory Jump", source = "level", level = 20 },
	{ id = "dance_spin", kind = "dance", name = "Spin", source = "robux", productId = 3723464673, suggestedPrice = 25 },
	{ id = "dance_hop", kind = "dance", name = "Bunny Hop", source = "robux", productId = 3723464659, suggestedPrice = 49 },
	{ id = "dance_flip", kind = "dance", name = "Backflip", source = "robux", productId = 3723464653, suggestedPrice = 75 },
	{ id = "dance_heli", kind = "dance", name = "Helicopter", source = "robux", productId = 3723464647, suggestedPrice = 99 },

	-- Titles
	{ id = "title_brawler", kind = "title", name = "Brawler", text = "Brawler", source = "level", level = 10, color = rgb(150, 220, 255) },
	{ id = "title_star", kind = "title", name = "Arena Star", text = "Arena Star", source = "level", level = 25, color = rgb(255, 220, 90) },
	{ id = "title_legend", kind = "title", name = "Bonk Legend", text = "Bonk Legend", source = "level", level = 50, color = rgb(255, 140, 40) },
	{ id = "title_firstwin", kind = "title", name = "First Win", text = "First Win", source = "earned", rule = "wins", amount = 1, color = rgb(140, 230, 140) },
	{ id = "title_champion", kind = "title", name = "Champion", text = "Champion", source = "earned", rule = "wins", amount = 50, color = rgb(255, 200, 40) },
	{ id = "title_koking", kind = "title", name = "Knockout King", text = "Knockout King", source = "earned", rule = "kos", amount = 100, color = rgb(255, 90, 90) },
	{ id = "title_hammertime", kind = "title", name = "Hammer Time", text = "Hammer Time", source = "robux", productId = 3723464724, suggestedPrice = 25, color = rgb(120, 200, 255) },
	{ id = "title_unbonkable", kind = "title", name = "Unbonkable", text = "Unbonkable", source = "robux", productId = 3723464707, suggestedPrice = 49, color = rgb(160, 255, 160) },
	{ id = "title_bonkmaster", kind = "title", name = "Bonk Master", text = "Bonk Master", source = "robux", productId = 3723464691, suggestedPrice = 99, color = rgb(255, 170, 60) },

	-- Trails
	{ id = "trail_sparkle", kind = "trail", name = "Sparkle Trail", source = "coins", price = 1000, colors = { rgb(0, 170, 255), rgb(0, 255, 200) } },
	{ id = "trail_fire", kind = "trail", name = "Fire Trail", source = "coins", price = 2000, colors = { rgb(255, 220, 0), rgb(255, 40, 0) } },
	{ id = "trail_rainbow", kind = "trail", name = "Rainbow Trail", source = "level", level = 40, colors = { rgb(255, 0, 0), rgb(255, 255, 0), rgb(0, 255, 0), rgb(0, 120, 255), rgb(200, 0, 255) } },

	-- Free for joining our community (the Free Gift menu)
	{ id = "community_hammer", kind = "hammer", name = "Crew Hammer", source = "community", shape = "hammer", head = rgb(0, 220, 200), handle = rgb(150, 80, 255), material = Enum.Material.Neon },
	{ id = "community_title", kind = "title", name = "Pandot Crew", text = "Pandot Crew", source = "community", color = rgb(0, 230, 210) },
}

Cosmetics.Defaults = {
	hammer = "hammer_foam",
	ko = "ko_poof",
	dance = "dance_cheer",
}

Cosmetics.ById = {}
Cosmetics.ByProductId = {}
for index, item in ipairs(Cosmetics.List) do
	item.order = index
	Cosmetics.ById[item.id] = item
	if item.productId and item.productId ~= 0 then
		Cosmetics.ByProductId[item.productId] = item
	end
end

-- True if the player can use this item. vip = owns the VIP pass.
function Cosmetics.Owns(data, item, vip)
	if item.source == "default" then
		return true
	elseif item.source == "vip" then
		return vip == true
	end
	return data.cosmetics.owned[item.id] == true
end

-- The item the player shows for a kind (falls back to the free default)
function Cosmetics.Equipped(data, kind, vip)
	local item = Cosmetics.ById[data.cosmetics.equipped[kind] or ""]
	if item and Cosmetics.Owns(data, item, vip) then
		return item
	end
	return Cosmetics.ById[Cosmetics.Defaults[kind] or ""]
end

return Cosmetics
