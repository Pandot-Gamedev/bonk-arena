-- The arenas. Each one changes during a round so nobody can hide at the edge.
-- ArenaService (server) builds them and runs what happens in them.

local Arenas = {}

Arenas.List = {
	{ id = "ice", name = "Ice Floe", color = Color3.fromRGB(150, 220, 255), description = "Slippery ice that cracks and sinks from the edges inward." },
	{ id = "spin", name = "Spin Cycle", color = Color3.fromRGB(255, 170, 60), description = "The floor spins faster and faster. Jump the sweeper bar!" },
	{ id = "lava", name = "Lava Rise", color = Color3.fromRGB(255, 90, 40), description = "Lava climbs the tower. Get higher, and don't touch it." },
	{ id = "bounce", name = "Bounce House", color = Color3.fromRGB(255, 110, 200), description = "Bouncy walls keep you in, until they fall away one by one." },
}

Arenas.ById = {}
for _, arena in ipairs(Arenas.List) do
	Arenas.ById[arena.id] = arena
end

return Arenas
