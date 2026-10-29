-- General game settings. Change numbers here to rebalance the game.

local Config = {}

Config.GameName = "Bonk Arena"

-- Saving
Config.DataStoreName = "PlayerData_v1"
Config.WinsStoreName = "Wins_v1"
Config.KosStoreName = "Knockouts_v1"
Config.WeeklyWinsStorePrefix = "WeeklyWins_"
Config.AutosaveSeconds = 120

-- Moving
Config.WalkSpeed = 18
Config.JumpHeight = 7.2
Config.DashSpeed = 75
Config.DashSeconds = 0.18
Config.DashCooldown = 1.3
Config.DodgeSeconds = 0.3 -- bonks miss you for this long after you dash

-- Bonking. Damage is shown as a percentage over each head: the higher it is,
-- the farther the next bonk sends you (like Smash Bros).
Config.BonkRange = 8 -- studs in front of you
Config.BonkArc = 120 -- degrees wide
Config.BonkCooldown = 0.45
Config.BonkMissCooldown = 0.9 -- a swing that hits nobody takes longer to recover (no free spamming)
Config.BonkImpactDelay = 0.17 -- the hammer lands this long after the swing starts (Swing.ImpactSeconds matches it)
-- Aim help: pressing BONK turns you to the closest rival within AimRange and,
-- if they are a little out of reach, lunges you up to LungeDistance towards them.
Config.AimRange = 11
Config.LungeDistance = 4
Config.LungeSeconds = 0.12
Config.BonkDamageMin = 8
Config.BonkDamageMax = 12
Config.MaxDamage = 999

-- Knockback speed = Base + Scale * damage (studs per second)
Config.KnockBase = 16
Config.KnockScale = 0.6
Config.KnockUpBase = 22
Config.KnockUpScale = 0.3
-- Stunned (tumbling, no control) for Base + Scale * damage seconds, up to Max
Config.StunBase = 0.3
Config.StunScale = 0.005
Config.StunMax = 1.2
Config.KoCreditSeconds = 6 -- falling off this soon after a bonk counts as a knockout for the bonker

-- Matches
Config.RoundsToWin = 2 -- best of 3
Config.CountdownSeconds = 3
Config.RoundSeconds = 75 -- then sudden death
Config.SuddenDeathSeconds = 30 -- then whoever has the least damage wins the round
Config.SuddenDeathDamage = 150
Config.BetweenRoundsSeconds = 4
Config.VictorySeconds = 7
Config.OutBelow = 25 -- studs below the arena floor counts as out
Config.OutBeyond = 30 -- studs past the arena edge counts as out

-- Queue pads in the lobby
Config.QueueSeconds = 20 -- wait for more players, then bots fill the empty spots
Config.QueueFullSeconds = 4 -- countdown once the pad is full

-- Power-ups
Config.PowerUpFirstSeconds = 8
Config.PowerUpEverySeconds = 12
Config.PowerUpMaxOnField = 2
Config.PowerUpSeconds = 8 -- how long timed power-ups last

-- Rewards. Coins only buy cosmetics, so they never help you win.
Config.CoinRewards = { play = 20, roundWin = 15, matchWin = 50, ko = 10 }
Config.XpRewards = { play = 30, roundWin = 20, matchWin = 60, ko = 15 }
Config.BotKoShare = 0.5 -- knocking out a bot is worth half
Config.BotOnlyWinShare = 0.6 -- winning against only bots is worth a bit less
Config.VipCoinBonus = 0.25

-- Daily login reward: DailyRewardBase * streak day (streak capped at 7)
Config.DailyRewardBase = 50
Config.DailyStreakCap = 7

-- Set to true to try the VIP pass for free while testing in Roblox Studio.
-- Has no effect in the live game.
Config.TestPassesInStudio = false

function Config.Knockback(damage)
	return Config.KnockBase + Config.KnockScale * damage, Config.KnockUpBase + Config.KnockUpScale * damage
end

function Config.Stun(damage)
	return math.min(Config.StunMax, Config.StunBase + Config.StunScale * damage)
end

return Config
