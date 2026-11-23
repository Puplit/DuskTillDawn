# goldpan

Gold panning for RedM and VORP. A player with a gold pan wades into a known river, creek, lake, pond or swamp, scoops a load of gravel and works it in a swirl minigame. The server turns the score, the richness of the water, hidden pay streaks and the player's perks into gold nuggets, the odd gemstone and some rock salt. After each pan a short hint tells the player whether they are getting closer to a pay streak, so prospecting becomes a hot and cold search along the water.

## Features

- The `goldpan` item is used from the inventory and never consumed. The pan is held in hand with a two-key prompt group (Search, Stop).
- Two minigames: the pup-minigames swirl game (score 0.0 to 1.0), or the skill bar. The skill bar is also the fallback when the swirl game cannot start.
- The server decides everything. Each pan is a session the server opens: it checks that the player owns a pan, that the water is known, the cooldown and that the player is alive. A reward is only paid for an open session, within a minimum and maximum time and close to where the pan started. The water is the one given when the pan started, never one sent with the reward.
- Pay streaks: hidden rich cells in each water. They are seeded where people actually pan, worked out after a number of pans, and expire after a while.
- Richness per water type, a guaranteed nugget for a decent pan, a byproduct table, and an amount bonus at high quality.
- pup-perks `pan_luck` bonus and `pan` XP, both optional.
- All messages go through pup-ui toasts: gold for finds and hints, red for refusals.
- No commands, menus, NUI pages or database queries of its own.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `pup-minigames` (`gold_pan` and `skill_bar` client exports)
- `pup-ui` (`Toast` export and the `pup-ui:toast` client event). If pup-ui is not running, messages fall back to VORP's right-hand tip.
- `pup-perks` (optional: the `pan_luck` bonus and `pan` XP). If it is stopped, panning still works with no bonus and no XP.

## Installation

1. Keep the folder name `goldpan`.
2. Run `sql/install.sql` once if the items do not exist yet. It only adds `goldpan`, `goldnugget`, `diamond`, `emerald` and `salt` to the VORP `items` table (`INSERT IGNORE`), so existing rows are left alone. Do a full server restart afterwards, because vorp_inventory reads the items table at start.
3. Add `ensure goldpan` after `vorp_core`, `vorp_inventory`, `pup-minigames` and `pup-ui` (and after `pup-perks` if you use it).

## How to pan

1. Use the gold pan from the inventory. The pan comes out in the right hand. This does not work while mounted, swimming, climbing, falling or dead.
2. Wade into a known water and press **Search**. The player scoops gravel (6 s), lets it settle (1.5 s) and then swirls it.
3. Swirl game: move the mouse in steady circles. Too slow and the gravel does not wash; too fast and gold goes over the lip. ENTER tips the pan out early, and the score is whatever gold is left.
4. The server pays the pan and shows what it held, followed by a hint about the nearest pay streak.
5. **Stop** puts the pan away. Mounting, swimming, climbing, falling or dying also put it away, and a load being worked at that moment is lost.

Hints, from cold to hot: black sand and grit, a faint glint, a few specks, a pan heavy with colour. Hints never give a distance or a direction. When a streak has been panned out, a message says so and the player must look elsewhere.

## Commands

None.

## Configuration

All files in `config/` are shared by client and server.

### config/main.lua

`PanItem`: the usable item name (`goldpan`).

**Options**

| Setting | Meaning |
|---|---|
| `WorkTimer` | Seconds the swirl animation runs when the skill bar is used. |
| `SettleMs` | Pause (ms) between the scoop and the minigame. |
| `ScoopMs` | Length (ms) of the scoop animation. |
| `SwirlExtraMs` | Extra ms added to the swirl animation so it covers the whole minigame. |
| `RewardDelayMs` | Wait (ms) after a good score before the reward is requested. |
| `ReplyTimeoutMs` | How long (ms) the client waits for the server to open a session. No answer means no pan. |
| `MinigameGraceMs` | Added to the minigame length (ms) before the client gives up waiting. A minigame that never answers counts as score 0. |
| `PanModel` | Prop model of the pan. |
| `BoneIndex` | Bone the pan is attached to: a bone name (`SKEL_R_HAND`) or a bone index. |
| `PanAttach.carry`, `PanAttach.work` | Attachment offsets `{ x, y, z, rotX, rotY, rotZ }` for carrying and for working. |
| `StartPanningInfo` | Scoop animation: `dict`, `name`, `flag`. |
| `StartShakeInfo` | Swirl animation: `dict`, `name`, `flag`. |

`UseSwirl`: `true` uses the swirl game, `false` the skill bar.

**Swirl** (the swirl game)

| Setting | Meaning |
|---|---|
| `duration` | ms before the swirl ends on its own. |
| `target_min` | rad/s below which the wash is weak. |
| `target_max` | rad/s above which gold is lost. |
| `silt_rate` | Silt % cleared per second at a good pace. |
| `gold_rate` | Gold % lost per second for each rad/s over `target_max`. |
| `hint` | Instruction line. `false` hides it, `nil` uses the minigame's own wording. |
| `slow_text`, `good_text`, `fast_text` | Live coaching lines for too slow, right pace and too fast. Same `false` / `nil` rules. |

**Minigame** (the skill bar): `Difficulty` from 0 (easy) to about 7 (hardest), and `Icon` (Font Awesome class shown on the bar).

**MinigameTuning** (how difficulty shapes the skill bar)

| Setting | Meaning |
|---|---|
| `baseArea`, `areaLoss`, `minArea` | Hit zone % at difficulty 0, shrink per difficulty point, smallest zone. |
| `baseSpeed`, `speedGain`, `maxSpeed` | Sweep speed at difficulty 0, gain per point, ceiling. |
| `perfectArea` | Size of the perfect zone (%). |

The hit zone is `baseArea - Difficulty * areaLoss`, kept between `minArea` and `baseArea`; the speed is `baseSpeed + Difficulty * speedGain`, kept between `baseSpeed` and `maxSpeed`. Perfect counts as a score of 1.0, success as 0.7, a miss as 0.

**Panning**

| Setting | Meaning |
|---|---|
| `TypeRichness` | Richness multiplier per water type (`creek`, `river`, `lake`, `pond`, `swamp`). 0 or less means dead water that never pays. |
| `DefaultRichness` | Richness of a water whose type is not in `TypeRichness`. |
| `Cooldown` | Seconds between paid pans per player. |
| `MinSessionMs` | A reward requested sooner than this (ms) after the pan started is ignored. Keep it below scoop + settle + the quickest minigame + `RewardDelayMs`. |
| `MaxSessionMs` | A reward later than this (ms) is ignored. An unclosed session also expires after this long. |
| `MaxDrift` | Metres (flat distance) the player may move between starting the pan and the reward. |

**Panning.Streaks** (pay streaks, kept in server memory and reset on restart)

| Setting | Meaning |
|---|---|
| `cell` | Size of a grid cell in metres. Streaks sit at cell centres. |
| `perWater` | Live streaks each water keeps. A paid pan seeds at most one new one. |
| `radius` | Metres from a streak centre within which the pan gets the full streak bonus. |
| `falloff` | Metres at which the streak effect reaches 0. It is always at least `radius + 1`. |
| `bonus` | Quality multiplier at a streak centre. It falls linearly to 1 at `falloff`. |
| `pansToDrain` | Paid pans a streak lasts before it is worked out. |
| `spread` | How far (in cells, either way on both axes) from the player a new streak may be seeded. Keep `spread * cell` below `falloff` (the console warns otherwise). |
| `lifetimeMin` | Minutes before a streak expires even when not worked out. 0 = never. |
| `memory` | How many recently panned cells are remembered per water. New streaks prefer those cells, so they land where people can actually stand and pan. |

**Prompts**: `Title` (prompt group title), `PanPrompt` / `PanName` (Search control and label), `StopPrompt` / `StopName` (Stop control and label).

**BlockedWhileWorking**: controls disabled while a load is worked (weapon wheel, B, mount).

### config/loot.lua

The chance of any row, in percent, is `min(cap, base + perQ * quality)`. Quality is `richness * streak bonus * score * (1 + pan_luck / 100)`.

| Setting | Meaning |
|---|---|
| `LootOrder` | Order in which the main rows are tried. The first that hits is the main find, and no further main rows are rolled. |
| `Loot.<key>` | A main row: `item`, `min` / `max` amount, `base`, `perQ`, `cap` (chance), and `label` (shown to the player). |
| `DustFloor.enabled` | When no main row hits and the score is at least `minScore`, give the floor row anyway. |
| `DustFloor.lootKey` | Which `Loot` row the floor gives (its item and label). |
| `DustFloor.minScore` | Lowest score (0.0 to 1.0) that earns the floor. |
| `DustFloor.min`, `DustFloor.max` | Floor amount range (it replaces the row's own range). |
| `Extras` | Byproduct rows, each rolled on its own and given on top: `item`, `label`, `min`, `max`, `base`, `perQ`, `cap`. |

Every find gets `floor(quality - 1)` extra pieces when quality is above 1. If the main find does not fit in the satchel, nothing is given and the player is told the satchel is full. A byproduct that does not fit is skipped.

### config/waters.lua

`WaterTypes`: the known waters. Each row has `hash` (the game's water zone name, for example `WATER_DAKOTA_RIVER`), `name` and `type` (a key of `TypeRichness`). Hashes are compared as unsigned 32-bit numbers on both sides. A number can be given in place of the name.

### config/locale.lua

| Setting | Meaning |
|---|---|
| `Messages` | All player texts. `Found` takes a label and an amount, `AlsoFound` and `OnlyExtras` a list, and `ListItem` / `ListAnd` build that list. `HintDead`, `HintNone`, `HintFaint`, `HintClose` and `HintHot` are the streak hints. |
| `MessageMs` | How long (ms) each message stays. `Found` is used for any pan that gave something, `Nothing` for a pan that only shows a hint. |
| `RedMessages` | Messages shown in the red tone. Everything else is gold. |

## pup-perks

`pan_luck` is a percentage added to quality: a bonus of 20 makes every pan 1.2 times as rich. It is not added to a dice roll. Each pan that gives at least one item calls `Award(src, 'pan')`, and pup-perks decides the XP amount.

## For developers

Network events (all used by goldpan only):

- `pup_goldpan:add` (server to client): take the pan out, sent when the item is used.
- `pup_goldpan:begin` (client to server, `waterHash`): asks to open a pan session.
- `pup_goldpan:begun` (server to client, `token` or `false, reason`): the server's answer.
- `pup_goldpan:cancel` (client to server, `token`): the load was dropped.
- `pup_goldpan:reward` (client to server, `token, score`): the load was worked; the server decides the payout.

Local client events:

- `panning:panning` (fired, `true` / `false`): `true` while a load is worked. The shovel refuses to dig while it is `true`. It is fired with `false` whenever work stops.
- `shoveling:shoveling` (listened, `true` / `false`): while `true`, Search is refused. Local only.

Limits: the server cannot read water zones, so the water named when a pan starts comes from the client. The session rules (time, distance, cooldown, pan ownership) limit how often any pan can pay.

## License

See LICENSE.
