# Bonk Arena

A Roblox party brawler for 2 to 4 players: knock your rivals off floating arenas with a foam
hammer. Every bonk adds damage %, and the higher it is, the farther the next bonk sends you
flying. Built on the Dig Legends code base (saving, shop, menus and notices).

The ready-to-open game file is [build/BonkArena.rbxlx](build/BonkArena.rbxlx).

## The live game

Public since 2026-10-29 (ages 16+) as **Bonk Arena**: game id 10773598334, place id 73590219706077,
https://www.roblox.com/games/73590219706077/Bonk-Arena

## How to test in Roblox Studio

1. Open `build/BonkArena.rbxlx` in Roblox Studio and press **Play**. Or, without the file: open
   a new Baseplate, run `python3 tools/studio_install.py` and paste the line it prints into the
   command bar (it downloads the scripts at the current commit from this repo).
2. Follow the guide at the top of the screen: bonk a practice dummy (click), dash (Q), then
   step on a glowing pad. A match starts after 20 seconds, with bots in the empty spots.
3. Knock everyone off the arena to win the round. Win 2 rounds to win the match.
4. Saving only works after the place is published with "Enable Studio Access to API Services" on.

Test helpers (Studio only, never in the live game): pick the **Server** view while playing and
run these in the command bar:

```
game.ServerStorage.BonkArenaTest:Invoke("match", 2)        -- start a match on pad 2 right away (you + bots)
game.ServerStorage.BonkArenaTest:Invoke("arena", "lava")   -- every round on one arena: ice, spin, lava, bounce ("random" to undo)
game.ServerStorage.BonkArenaTest:Invoke("damage", 120)     -- set your damage %
game.ServerStorage.BonkArenaTest:Invoke("coins", 5000)
game.ServerStorage.BonkArenaTest:Invoke("xp", 10000)
```

To try a real 4-player match, use Studio's **Test > Clients and Servers** with 2 to 4 players
and put them on the same pad. To see a bot step aside, start a match with one player, then put
a second player on the same pad: they take a bot's place when the next round starts.

## What's in the game

- **Bonking:** click or tap BONK to swing. Pressing BONK turns you to the closest rival within
  11 studs and lunges you up to 4 studs if they are just out of reach. The swing (wind-up,
  slam, hammer streak, dust) is drawn on each player's screen; the server still checks every hit
  (in front of you, within reach). Each bonk adds 8 to 12% damage. A swing that hits nobody
  takes 0.9 s to recover instead of 0.45 s, so swinging nonstop doesn't wall people off.
- **Dash:** Q or the DASH button, every 1.3 seconds. Bonks miss you for 0.3 s after a dash.
- **Phones:** landscape only, with big round BONK and DASH buttons placed around Roblox's jump
  button (they fill up while recharging; hold BONK to keep swinging) and smaller match cards.
- **Matches:** three queue pads in the lobby (a 1 v 1 duel and two brawls for up to 4). A match
  starts when a pad is full, or after 20 seconds with bots filling the empty spots. Best of 3
  rounds, a different arena each round. Knocked-out players watch from a deck next to the
  arena, and the winner dances on the podium.
- **Bots** are a bit slower and less accurate than people, say BOT on their name tag and are
  worth half as much to knock out. When a real player steps on a pad during a match with bots,
  a bot steps aside for them at the start of the next round.
- **4 arenas:** Ice Floe (slippery tiles crack and sink from the edge in), Spin Cycle (the
  floor spins faster and faster, with a sweeper bar to jump), Lava Rise (lava climbs a stepped
  tower) and Bounce House (bouncy walls throw you back in, then fall away one by one).
- **No stalling:** after 75 seconds it's sudden death (everyone at 150%), and 30 seconds after
  that the player with the least damage wins the round.
- **6 power-ups** drop during a round for anyone to grab: Giant Hammer, Bounce Shield, Speed
  Boots, Iron Boots, Magnet Bonk and Banana Peel. Never sold.
- **Levels** (up to 50) from XP, coins for every level, and free cosmetics at levels 5, 10, 15,
  20, 25, 30, 40 and 50.
- **Coins** from every match (more for wins and knockouts) buy cosmetics in the Locker.
- **3 daily quests**, a daily login reward, a practice ring with dummies, and leaderboards for
  most wins (all time and this week) and most knockouts.
- **Private servers:** the owner can pick the arena every round uses (Arena button).

## Monetization (never pay-to-win)

| Item | Type | Effect |
|---|---|---|
| VIP | Game pass | Golden name tag, crown, Royal Hammer, +25% coins (coins only buy looks) |
| Hammer skins (5) | Developer products | Golden, Neon, Galaxy, Rubber Chicken, Big Fish |
| Knockout effects (4) | Developer products | Confetti Blast, Cartoon Star, Fireworks, Lightning Strike |
| Victory dances (4) | Developer products | Spin, Bunny Hop, Backflip, Helicopter |
| Titles (3) | Developer products | Hammer Time, Unbonkable, Bonk Master |
| Private servers | Monthly | Play with friends only and pick the arena |

Nothing sold for Robux changes how hard you bonk, how far you fly, or what power-ups you get.
Pass and product ids go in `src/shared/Shop.luau` and `src/shared/Cosmetics.luau` (0 means
"Coming soon" in the shop). All of them were created on 2026-10-29 with
`tools/create_shop_items.luau`: the VIP pass is 2060495027 and the 16 developer products are
3723464586 to 3723464724.

## Roblox settings to set when publishing

- Max players per server: **12** (three arena spots of up to 4).
- Avatar type: **R15** is best (R6 works too).

## Project layout (Rojo)

```
default.project.json     Rojo project: maps src/ into the game
src/shared/              ReplicatedStorage.Shared (used by server and players)
  Config.luau            knockback, damage, round and queue timings, rewards
  Arenas.luau, PowerUps.luau, Quests.luau, Cosmetics.luau, Shop.luau, Level.luau
src/server/              ServerScriptService.Server
  CombatService.luau     bonks, dashes, knockback and damage for players, bots and dummies
  MatchService.luau      queue pads, matches, rounds, knockouts, rewards, bots stepping aside
  ArenaService.luau      builds each arena and runs what happens in it during a round
  BotService.luau        bot players and how they think
  PowerUpService.luau    power-ups dropping and what they do
  ProgressService.luau   coins, XP, levels, quests, Locker purchases
  MapBuilder.luau        builds the sky lobby and the three arena spots
src/client/              StarterPlayerScripts.Client
  Controls.luau          bonk and dash, aim help and lunge, flying when bonked
  Swing.luau             the hammer swing animation, drawn on every screen
  TouchButtons.luau      the BONK and DASH buttons on phones and tablets
  MatchHud.luau          round, timer, player cards, announcements, watching a match
  Effects.luau           hit sparks, damage numbers, knockout effects, screen shake
tools/build_place.py     rebuilds build/BonkArena.rbxlx from src/
tools/studio_install.py  prints a command-bar line that installs src/ into an open Studio place
tools/make_store_art.py  draws the shop icons into store/ (and older drawn icon/thumbnails into store/drawn/)
tools/create_shop_items.luau  creates the VIP pass and shop items through Open Cloud
```
