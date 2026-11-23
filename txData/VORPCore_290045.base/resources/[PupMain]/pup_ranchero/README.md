# pup_ranchero

Player ranches for RedM / VORP. Staff place ranches on the map and players buy them; owners hire hands, keep livestock, run herding and sale drives, do chores, collect milk and eggs, and pay tax.

## Features

- **Ranches and roles.** Each character belongs to at most one ranch, as its owner or as a hired hand. A hand can be made a manager. Owners may transfer their ranch to another player.
- **Ledger.** The ranch's own money. It pays for livestock and upgrades, takes in sale income and pays tax.
- **Livestock.** Up to 5 head of each of 9 types. Each type has its own herd quality, from 0 to 200.
- **Herding.** A manager lays a 4-point trail. Members lead a herd out along it and back (points 1-2-3-4-3-2-1). A good drive raises herd quality and pays out items such as wool, pelts and meat. If the satchel is full, the rest goes to the produce store.
- **Sale drives.** Lead the herd to any sale barn. The payout goes to the ledger. A newly bought herd cannot be sold until it has finished one herding trip (configurable).
- **Hazards.** Animals stray, wolves attack on herding drives, and other players can shoot your animals. Anyone who kills another ranch's drive animal gets a bounty.
- **Chores.** Five spots: raking, shovelling, feeding, spreading hay and carrying water. Each one is a click-the-items minigame (or a pup-minigames skill bar) and raises the ranch **environment**, which decays on fixed half-hour slots.
- **Cow pen and chicken coop.** Upgrades paid from the ledger. Milk and eggs depend on the minigame score and the environment. The cooldown only starts once a round is finished.
- **Produce store.** A shared container that only bosses can open. Uncollected milk and eggs move into it the first time it is opened.
- **Herding dog.** Helps keep the herd together; `/onme` calls every animal to you.
- **Tax.** Collected on a schedule (monthly by default). A ranch whose ledger cannot pay is repossessed and put back on sale (or deleted). The owner gets a mail warning beforehand when `pup_postoffice` is running.
- **Logs.** An activity feed in `ranch_activity`, per-character stats in `ranch_stats`, two global Discord webhooks and an optional webhook per ranch.
- **Managers' tools** (Boss Actions, owner and managers only):
  - **Who Is Working** lists every member with what they are doing right now (a chore, milking, collecting eggs, herding, a sale drive, at the ranch, away, offline) and when they last worked. The list updates itself while open.
  - **Ranch Leaderboard** shows milk, eggs, chores and herding trips per person, with the top chore-doer in the subtitle. Select the first row to change the sort. People who have left are marked.
- **Shared menu.** The whole ranch can use the menu at the same time (`Config.Timers.menuLock = 0`).
- **Drive timers name the driver.** The herding and selling lines in the menu show who is out on the drive and the time left, or who ran the last one while the cooldown runs.
- **Staff dashboard.** An in-game ranch dashboard opened from vorp_admin, plus server exports for vorp_admin's ranch tools.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- Optional: `pup-minigames` (skill bar fallback), `pup-perks`, `pup_postoffice` (tax warning mail), `vorp_admin` (dashboard and ranch tools)

## Installation

1. Put `pup_ranchero` in your resources folder.
2. Run `sql/install.sql` (safe to run more than once). It creates `player_ranch`, `ranch_activity`, `ranch_stats`, `ranch_stats_meta`, `ranch_paycfg`, `ranch_herds`, `cron_state` and `ranch_fresh`, and adds the items `beef`, `bisons`, `chickenf`, `cows`, `deerskin`, `egg`, `fibers`, `milk`, `porkfat`, `prongs`, `rams`, `venison`, `wool` with `INSERT IGNORE`. The resource also creates the stats, herd-history, cron and fresh-herd tables at start-up.
3. Add images for those items to `vorp_inventory/html/img/items/` if you do not have them.
4. Set the webhook URLs in `server/config.lua` (server only, never sent to players):
   - `ledger`: ledger movements, purchases, sale income, tax and repossessions.
   - `general`: everything else (purchases, staff, herding, chores, produce, kills).
   Leave either empty to switch it off.
5. Add `ensure pup_ranchero` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui`.

## Commands

| Command | Who | What |
|---|---|---|
| `/createranch` | VORP group `admin` | create a ranch at your position (name, price, tax; 0 is allowed for a free or untaxed ranch) |
| `/onme` | anyone on a live herding drive with a dog | the herd walks to you for `Config.Dog.duration` seconds (`Config.Dog.cooldown` seconds cooldown) |

The ranch dashboard opens from vorp_admin's panel (local client event `pup_ranchero:openAdminTool`). It needs the `admin` group, the vorp_admin permission `manage_ranch`, or a job listed in `Config.General.adminJobs`.

## Configuration

### config/main.lua

- **Config.General**: `debug`, `createCommand` (VORP group `admin` only), `adminJobs` (character jobs that may open the dashboard), `allowTransfer` (owners may hand their ranch to another player), `maxNameLength`.
- **Config.Keys**: `interact` (G), `stop` (X, ends trail recording), `cancel` (Backspace), `interactLabel`.
- **Config.PromptStyle**: `'native'` (default) shows the G prompts (ranch point, tasks, herding) as the game's own prompt, titled with the ranch name or ID; `'pill'` shows pup-ui's key pill instead.
- **Config.ShowRanchIdText**: `true` also floats "Ranch ID" text over the marker before you are close enough for the prompt (always on with `'pill'`).
- **Config.Reach** (metres):
  - `ranch`: menu actions, measured from the ranch point (3D).
  - `register`: a spot sent by the client must be this close to the player.
  - `work`: chores and finishing milk/egg rounds, from the spot.
  - `enclosure`: a cow pen or chicken coop must be this close to the ranch point (milking starts within `ranch` of the ranch point, so a far pen could never be used).
  - `checkpoint`: herding checkpoint, from the matching trail point.
  - `driveEnd`: end of a herding drive, from trail point 1.
  - `barn`: a sale claim, from any sale barn.
  - `bounty`: kill bounty, killer to the reporting driver.
  - `marker`, `prompt`, `crowd` ("someone is too close"), `herdSpawn` (Spawn Herd pill, from the ranch point), `taskStart` (chore / cow / chickens start pill).
- **Config.Blips**: sprites and scale; `goalSprite` is a name hashed on the client; `rebuildDelay` is a ms debounce after any ranch data change.
- **Config.Environment**:
  - `max`: cap for the environment (0 = no cap; the yield then scales against 300).
  - `decay`: points removed from every owned ranch above 0 per tick.
  - `decayMinutes`: ticks land on fixed wall-clock slots, so with 30 they are always at :00 and :30, no matter when the resource started.
- **Config.Livestock**: `maxPerType`, `boughtQuality` (quality of newly bought animals, averaged into the herd), `maxQuality`, `boostOn` / `boostMult`, `scaleByQuality` with `scaleMin` / `scaleMax` (ped scale), `killReward` (outsiders who kill a drive animal get half its price), `chargeOwnCow` / `ownCowCharge` (killing your own pen cow costs cash), `deathFactor` (drive quality is multiplied by this per death), `strayPenalty` (drive quality -10% per living animal that did not arrive).
- **Config.Herding**: `checkDistance` (the herd waits beyond this; checkpoints trigger at half), `closingSeconds`, `cooldown` and `timeLimit` (seconds), `rewardsToStore` (herding items go straight to the produce store), `voucherSeconds`, `minSeconds` and `sanitySpeed` (m/s; a drive that finishes impossibly fast is refused), `nudgeMs`, freeze/resume distances for the player and dog, `dogHeelDistance`, `dogCheckMs`, and `trail` (`minLeg` / `maxLeg` in metres between trail points, flat).
- **Config.Sales**: `deliveryRadius`, `cooldown` and `timeLimit` (seconds), `chickenFactor` (chickens get this much more time), `payoutMult` (0 or nil = x1), `followMs`, freeze/resume distances, `requireHerdAfterPurchase`.
- **Config.Hazards**: strays and wolves. `startAfter` is seconds after the drive goes live; `*EveryMs` is how often a roll happens, `*RollMax` / `*Above` the roll (a roll above the value triggers it), `*Cooldown*` in ms, distances in metres, `wolfModel`. No hazards start during the closing countdown.
- **Config.Dog**: `command`, `cooldown` (seconds, per client), `duration` (seconds), and `breeds` (`{ label, model, price }`). Add a breed with a line such as `{ label = 'Collie', model = 'A_C_DogCollie_01', price = 300 },`.
- **Config.Chores**: `order` and `list` (`label`, `art` = minigame picture: bales, dung, sack, hay, bucket, pails or basket; `scenario`). The keys are database keys: never rename them. `cooldown` (seconds, per character, per ranch, per chore), `maxScore`, `capScore`, `workSeconds` (chore animation after a round; 0 = off).
- **Config.Minigame**: `collectGame` (false = pup-minigames skill bar instead), `roundSeconds`, `graceSeconds` (the server accepts a round this long before its full length), `fallbackMinSeconds`, `spawnMs`, `catchRatio`, `riseMin` / `riseMax`, `speedUp` (items get up to this much quicker by the end), `spawnShrink` (spawn interval shrinks to this by the end), `safetySeconds`, `overrides` per chore name, `milk` or `eggs`, and `skillBar` settings for the fallback.
- **Config.Produce**: `maxYield`, `milkItem`, `eggItem`, `milkCooldown` / `eggCooldown` (seconds per character; they start only when a round is completed, so cancelling, failing to start, disconnecting or switching character costs nothing), `startGap` (anti-spam gap between two starts, not the cooldown), `session` / `clientSession` (seconds), pen models, `chickens` (how many), animations, `reportGap` (seconds between cow-kill reports per player).
- **Config.Upgrades**: `cowPen` and `chickenCoop` prices.
- **Config.Store.idBase**: produce container id = `idBase + ranch id` (default 8000000). Never change it once items are stored: existing items live under it.
- **Config.Tax**: `enabled`, `deleteRepo` (true = delete unpaid ranches instead of selling them again), `mode` (`monthly` or `weekly`), `monthly` / `weekly` schedules (`days`, `hour`, `minute`), `warnMinutes` (warning mail before collection), `mailFrom`. Ranches with tax 0 are skipped. The day is marked before collection runs, so a restart later the same day never collects twice.
- **Config.Timers**: `menuLock` (0 = the whole ranch can use the menu at once; above 0 = seconds one player may hold it alone), `sweepEvery` (seconds), `abandonExtra` (seconds past twice the time limit before a drive counts as abandoned), `activityDays` (activity feed kept this many days), `infoDelayMs`.
- **Config.Board**: `nearRanch` (metres from the ranch point that count as "at the ranch" in Who Is Working), `refreshMs` (how often an open Who Is Working list updates), `maxRows` (most people on the leaderboard).
- **Config.Animals**: type names are database keys (case-sensitive). `job = 'none'` means anyone may buy; a type without a job cannot be bought. `rewards` lists items paid per animal after a herding drive; `outfit` picks a fixed outfit preset. Example:
  `goats = { model = 'a_c_goat_01', job = 'none', price = 20, rewards = { { item = 'fibers', per = 1 } } },`
- **Config.ItemLabels**: item labels for Discord logs (vorp_inventory does not pass labels with its container events). Add one for every reward item.
- **Config.SaleBarns**: `{ town, x, y, z }`; `disabled = true` hides one.

### config/locale.lua

Every player-facing message. `%s` and `%d` are filled in by the code; keep them.

## For developers

Server exports for vorp_admin. vorp_admin checks its own permissions; these exports only validate input. Each returns `{ ok, err }` plus the fields its caller expects.

| Export | Arguments |
|---|---|
| `adminRanchList` | none: every ranch with its owner, hands and uncollected milk/egg counters |
| `adminSetRanchPrice` | `id, price` |
| `adminSetRanchTax` | `id, tax` |
| `adminMoveRanch` | `id, coords, actor` |
| `adminTransferRanch` | `id, charid, actor` |
| `adminDeleteRanch` | `id, actor` |
| `adminHireToRanch` | `id, charid, actor` |
| `adminFireFromRanch` | `id, charid, actor` |
| `adminSetRanchManager` | `id, charid, makeManager, actor` |

Client event `pup_ranchero:openAdminTool` (local) opens the dashboard. The activity feed type strings in `ranch_activity` are read by vorp_admin's filters, and the `p_*` period columns in `ranch_stats` are meant to be reset by an external tool.

## License

See LICENSE.
