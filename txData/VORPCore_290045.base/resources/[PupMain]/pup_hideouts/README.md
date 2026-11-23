# pup_hideouts

Moonshine hideouts for RedM (VORP Core, Lua 5.4, OneSync). Players buy or found a shack, brew
moonshine in an instanced interior, sell contraband to locals, raid each other's hideouts and rob
wagons for still parts.

The resource name must stay `pup_hideouts`: other resources call it by name.

## Features

- Hideouts for sale on the map, or founded anywhere (outside towns) with a Hideout Plans item
- Each hideout is its own instance (routing bucket) of the Lemoyne moonshine shack
- Owner and co-owners, with consent prompts for adding a co-owner or handing the hideout over
- Knock at the door; a member inside can let you in
- The books: rename, ledger (deposit / withdraw), stash upgrades, themes and decorations,
  co-owners, moving the shack, the owner's own Discord channel
- Three still levels crafted from parts in the stash; mash and distill recipes on timers
- A stash (vorp_inventory hideout panel), also usable from storage boxes near the door
- Raids by a posse: a warning countdown, picking the lock, an open window to loot the stash and
  the ledger, raid protection afterwards, and tearing down the still for its parts
- Still parts missions: stop an escorted wagon, plant a charge, blow it and strip it for loot
- Selling contraband to locals with haggling on a price picker, police reports and a sting
  (uniformed lawman, undercover buyer or a crooked lawman who drinks the evidence)
- A bare-knuckle betting table, a bar (drinks, almonds, getting drunk, washing up) and a piano
  skill check
- Discord logs per category, staff tools through vorp_admin, recovery for players stuck in an
  interior after a restart

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory` with the hideout stash panel. It must send the panel actions to
  `pup_hideouts:MoveToHideout`, `pup_hideouts:TakeFromHideout`, `pup_hideouts:SortHideoutInventory`
  and `pup_hideouts:ChangeOrderHideout`, and fire the client event `pup:closeinv` when the panel closes
- `pup-ui` (menus, input boxes, progress bar, price picker, 3D text, posses)
- `pup-minigames` (skill bar, safe crack, button mash)
- Optional: `pup-perks` (perk multipliers and awards), `pup-gangs` (gang drug sales), `pup-mdt`
  (police alerts and duty), `vorp_admin` (staff panel and the "Open storage" view), `lockpick`
  (lock minigame; the safe-crack minigame is used without it), `fred_meta` (hunger and thirst),
  `pup-misc` (storage boxes, scene blocking), `pup_realestate` (shares the last-position column)

Every optional call is guarded: if the resource is not started or its call fails, this resource
carries on and prints a console warning (at most once a minute per call).

## Installation

1. Run `sql/install.sql`. It creates the `underground` table, adds `characters.moonshineenty`
   (the last world position before entering an interior) and inserts every item. It is safe to
   run more than once. The resource also adds `webhook`, `raidopenedat` and `moonshineenty` on
   start if they are missing.
2. Add an inventory image for each item in `sql/install.sql` to vorp_inventory (for example
   `hideout_plans`, `condenser`, `pipecopper`, `moonshine`, `crowbar`, `lockpick`, `dynamite`).
3. For Discord logs, set the webhook URLs in `server/config.lua` (`Main`, `Raids`, `Missions`,
   `Ledger`, `Inventory`, `Production`, `Sales`). It is server only and never sent to players. An
   empty URL switches that category off.
4. In `server.cfg`, ensure it after its dependencies:

   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure pup-minigames
   ensure pup_hideouts
   ```

## Commands

| Command | Who | What |
|---|---|---|
| `/createhideout` | admin or a `Config.StaffJobs` job | create a hideout for sale at your position (price and name) |
| `/relocate` | owner with a move under way | place the shack where you stand |
| `/relocate cancel` | owner with a move under way | call the move off; the fee goes back to the ledger |
| `/getout` | anyone | leave the hideout you are in, or get out of a stuck interior |
| `/calert2` | anyone | clear police / raid alerts from the screen (`Config.AlertCommand`) |
| `/stilltest [id]` | admin, `Config.Debug` only | arm a hideout (given id, the one you are in, or the nearest) for a teardown test |
| `/stilltestreset [id]` | admin, `Config.Debug` only | reset that hideout again |
| `/themecheck` | anyone, `Config.Debug` only | print which theme sets exist in the interior |

The `hideout_plans` item is usable: it starts founding a hideout where you stand.

## Configuration

| File | What |
|---|---|
| `config/main.lua` | general settings, logs, hideout rules, stash, raids, teardown, bar, piano, bookie, optional integrations |
| `config/interior.lua` | the interior layout, recovery spots, imaps, animation names |
| `config/production.lua` | stills, mash and distill recipes, storage tiers, themes and decorations |
| `config/sales.lua` | contraband prices, bargaining and the sting |
| `config/wagons.lua` | still parts missions |
| `locale/en.lua` | every player-facing line; `%s` / `%d` are filled in by the code in the order written. Also `Config.CrookedLines`, what a crooked lawman says |

Distances are in metres, times in the unit named by the setting (`Seconds`, `Minutes`, `Ms`).

### config/main.lua

General:

- `Debug` - enables `/stilltest`, `/stilltestreset` and `/themecheck`. `DebugTeardown` - console
  trace of still teardowns.
- `InstanceOffset` - a hideout's routing bucket is its id plus this. pup-misc treats bucket 2553
  and up as "in a hideout", so do not change it.
- `RestartTimes` - HHMM times, one minute before each real server restart. At those minutes every
  betting table is refunded and everyone is put outside.
- `StaffJobs` - jobs that act as hideout staff: they see every blip, can use `/createhideout` and
  can delete unowned hideouts. Admins can do all of that too (admins delete owned hideouts as well).
- `PoliceJobs` - jobs that count as police (alerts, `minPolice`, `Raids.mode = 'police'`).
- `Keys` / `KeyLabels` - control hashes and their labels: `interact` (G), `secondary` (Enter),
  `cancel` (Backspace, stops stripping a wagon).
- `FredMeta` - send hunger / thirst changes from the bar to fred_meta.
- `SkillBar` - tuning for the piano's difficulty-driven skill bar. Each value `nil` uses the
  default: `baseZone` 34 (% of the bar), `zonePerStep` 1.5 (% lost per difficulty point),
  `minZone` 14, `perfectZone` 6, `baseSpeed` 0.18, `speedStep` 0.02, `maxSpeed` 0.55.
- `AlertMinutes` - police and owner alerts clear themselves after this many minutes.
  `AlertCommand` - the command that clears them.

`Logs`:

- `enabled` - master switch for Discord logs.
- `ownerWebhooks` - owners may connect their own Discord channel from the books. It only receives
  members' own actions in the `ownerCategories` (`Main`, `Ledger`, `Inventory`, `Production`);
  raids are never sent there. Handing the hideout over removes it.
- `username` - the name the posts appear under. `colors` - embed colour per log type (decimal).

`Hideouts`:

- `maxTotal`, `maxOwned`, `maxCoOwned` - how many hideouts one character may have in total, own,
  and co-own.
- `consentRange`, `consentSeconds` - for adding a co-owner or a transfer, both players must be in
  the hideout within this distance; the target has this many seconds to answer.
- `doorReach` - how close to the door you must be to buy, start a raid, pick the lock or enter.
  `promptRange` - distance at which door prompts show.
- `relocateMinutes`, `relocatePrice`, `relocateCommand` - a move must be placed within this many
  minutes or the fee (taken from the ledger) is refunded. A pending move survives a restart and is
  refunded on the next start.
- `adminsSeeAllBlips` - admins see every hideout blip (staff jobs always do).
- `renamePrice` (cash), `nameMax` (characters).
- `townBlock`, `blockedTowns` - plans and relocation are refused inside these towns.
- `plansItem`, `plansPrice` (price stored on a hideout founded with plans), `spacingOwned`,
  `spacingUnowned` (minimum distance from an owned / unowned hideout), `plansReach` (the submitted
  spot must be this close to the player).
- `knockWait` (seconds the knock waits for an answer, also the client cooldown between knocks),
  `knockRadius` (the knocker must stay this close), `inviteSeconds` (how long an answered knock
  lets you in).
- `getoutCommand`, `getoutPoint` (where `/getout` puts a stuck player), `nearInterior` (a player
  this close to an interior point while not marked inside counts as stuck).
- `lastPosReach` - a saved last position must be this close to the real ped.
- `blipSprite`, `blipStyle` - the map blip.

`Storage`:

- `doorReach` - members using storage boxes may be this close to the door instead of inside.
- `blacklist` - items the stash refuses. Weapons are always refused.

`Raids`:

- `mode` - `'anyone'` (the raider must own or co-own a hideout), `'police'` (police jobs only) or
  `'off'`.
- `ownersOnline` - a member of the target must be online.
- `posseSize` - posse members needed to start (0 = none). Capped at the pup-ui posse maximum.
- `warningMinutes` - countdown before the lock can be picked; members get an alert.
- `redAtSeconds` - the on-screen timer turns red at this many seconds left.
- `openMinutes` - how long a broken-open hideout stays open to the crew.
- `protectionDays` - no new raid on that hideout for this many days after a break-in.
- `lockpickItem` - needed to pick the lock; a failed attempt snaps one.
- `safeCrackLevel` - difficulty of the safe-crack minigame used when the `lockpick` resource is not running.
- `downDistance` - a crew member further than this from the door counts as down; if the whole crew
  is down the raid ends.
- `syncSeconds`, `crackHintMs` - crew clock sync interval and how long the lock hint shows.

`Teardown` (raiders stripping the still in a broken-open hideout):

- `seconds`, `minSeconds` - how long it takes, and the floor after perks.
- `tether` - the raider must stay this close to the interior entry point.
- `tool`, `consumeTool` - the item needed and whether it is used up.
- `mashLevel` - button-mash difficulty to start. `range` - distance from the still for the prompt.
- The raider gets every part of the still's level and the levels below it.

`Bar`:

- `almonds`, `moonshine` - `hunger`, `thirst`, `metabolism` sent to fred_meta.
- `drunkPerDrink`, `distortPerDrink`, `distortCap` - drunkenness and screen distortion per drink.
- `wearEvery` (seconds), `wearDrunk`, `wearDistort` - how it wears off.
- `thresholds` - drunkenness for light, medium and heavy effects.
- `pourSeconds`, `almondSeconds`, `drinkSeconds`, `washSeconds` - animation lengths.
- `scenarioPoints`, `drinkScenario`, `drunkScenario`, `drunkFx`, `lensFx` - game names.

`Piano`:

- `enabled`, `everySeconds` (a skill check this often while playing), `restMinutes` (pause after
  you stop playing).
- `startDifficulty`, `dropMin`, `dropMax`, `floor` - the difficulty starts at 5000 and drops by a
  random amount each check down to the floor; 5000 maps to the easiest bar, 1000 to the hardest.
  The piano pays nothing.
- `scenarios` - the piano scenarios that count as playing.

`Bookie`:

- `price` - cash to buy the betting table.
- `houseCut` - share of the pot that goes to the ledger (0.1 = 10%). If nobody backed the winner,
  the whole pot goes to the ledger.
- `healthMin`, `healthMax` - fighter health. `fightMin`, `fightMax` - fight length in seconds. The
  server picks the winner.
- `betExpiryMinutes` - bets are refunded if no fight starts within this time.
- `startDelay` (seconds before they fight), `pullBack` (metres apart beyond their start spots
  before they are put back), `models`.

`Integrations` - small adapter functions for the optional resources. Each one is called through
`pcall`, so a failure is logged and skipped. Change them only if those resources' exports change:

- `mdtAlert(coords, text)` - pup-mdt `SendPoliceAlert(coords, text, persistent, forcedSource)`;
  `forcedSource = false` sends it anonymously. If it fails or returns false, this resource shows its
  own blip and text to on-duty police instead.
- `mdtRadius(coords, text, radius)` - pup-mdt `SendRadiusAlert(coords, { label, radius })`, used for
  sale reports. A `false` result means pup-mdt's own chance roll said no, which is accepted.
- `mdtOnDuty(src)` - pup-mdt `IsPlayerOnDuty`. Without pup-mdt every police job counts as on duty.
- `mdtZone(coords)` - pup-mdt `ZoneNameFromCoords` (server side); `'Unknown Zone'` becomes nil.
- `gangOffer(src)` - pup-gangs `DrugSellOffer`; must return `{ item, label, price, count }` or nil.
- `gangTake(src, item, qty)` - pup-gangs `DrugTakeForSale`; must return the units actually taken.
- `gangMultiplier(src, coords)` - pup-gangs `DrugSaleMult`, a payout multiplier of 1 or more.
- `gangSaleDone(src, item, qty, paid, coords)` - pup-gangs `DrugSaleDone(src, sold, pay)`.
- `gangBloodMoney(src, kind, amount)` - pup-gangs `AwardBloodMoney(src, kind, reason)`; kind
  `'drugSale'` rolls its own chance.
- `adminAllowed(src, action)` - vorp_admin `allowedToExecuteAction`; used by "Open storage"
  (action `manage_hideouts`).
- `lockpick()` - client side, the `lockpick` resource's `lockpick()` export; it blocks until the
  minigame ends and returns true on success.

### config/interior.lua

- `Zones` - the interior layouts. `lemoyne` holds the interior id, the inside entry point and
  heading, the seat at the books, the mash and still work spots and their animation, the ledger
  text, stash, bar, wash barrel, bookie and fighter spots, the still, and the doors kept shut or
  opened by a theme. `outside` is not used as a door: every hideout has its own door coords.
- `DefaultZone` - the layout new hideouts use.
- `FallbackSpots` - where a stuck player is put: the spot nearest their saved last position; the
  first one is the default.
- `Imaps`, `Anims` (lock picking, the trade, the crooked lawman's drink), `AlertBlip`, `Lasso`.

### config/production.lua

Every item row in this file (still parts, ingredients, upgrade materials) has the same shape:

```lua
{ name = 'water', label = 'Water', amount = 1 },
```

`name` is the inventory item (it must exist in your items table), `label` the name shown in menus,
`amount` how many are needed.

- `DistilleryJobs` - jobs whose mash of `DoubleYieldItem` gives double.
- `Stills[level]` - `model` and the `parts` taken from the hideout stash to craft that level.
  Levels go 1 to 3 and are crafted in order.
- `Mash` and `Distill` - recipes. Fields: `label` (menu name), `resultitem` (the item made),
  `limit` (stack limit given to it in the stash), `qt` (how many one batch gives), `minutes` (how
  long a batch takes), `stilllevel` (lowest still level that can brew it), `items` (ingredients,
  taken from the stash). In `Distill`, `distill = true` marks a brewable recipe; entries without it
  only exist so locals buy them, and the sale scan follows the list order. `sellprice` is the
  optional price handed to the gang drug-sale offer for that batch. A finished batch goes into
  the stash, as much as fits.
- `StorageTiers` - stash upgrades. `name` (menu name), `level` (the storage level the hideout must
  be at; buying sets it to level + 1), `slots` (stash slots added), `price` (cash), `items`
  (materials taken from the buyer). Several tiers at the same level are offered as a choice.
- `Themes` - `label`, interior entity `set`, `price`. `DecorCategories`, `DecorCategoryLabels` and
  `Decorations` (`label`, `category`, `set`, `price`; one decoration per category is active).

Example of a new mash recipe:

```lua
{ label = 'Peach Mash', resultitem = 'mashpeach', limit = 20, qt = 5, minutes = 15, stilllevel = 2, items = {
    { name = 'water', label = 'Water', amount = 1 },
    { name = 'peach', label = 'Peach', amount = 3 },
} },
```

### config/sales.lua

`Sales`:

- `enabled`; `minPolice` (police needed online for a sale, `false` = no check);
  `minPoliceOnDuty` (count police by pup-mdt duty rather than job alone).
- `offerCooldown` - seconds between offers from one player.
- `instantRefuse` - out of 10: the chance a local refuses outright (only when bargaining is off).
- `report`, `reportChance` (percent), `reportRadius` - a finished sale of an illegal item may be
  reported to the police.
- `prices` - price per unit; an item missing here is never sold (the startup check names it).
- `legal` - never stung or reported, still haggled.
- `overrides` - per item: `{ maxUnits, weights, floor, ceiling, opening, jitter, legal }`.
- `buyerRange`, `sessionRange` - how close the buyer must be to start, and to stay in the deal.
- `sessionClientSeconds` - how long the buyer stands still. `firstScreenMs` - how long the client
  waits for the server's offer.
- `pedTypes` - ped types that may buy (lawmen always may).

`Bargain` (the price picker):

- `enabled`; `counters` - counter-offers before the buyer walks off.
- `maxUnits`, `weights` - how many units a buyer wants, weighted (`{ 65, 35 }` = 65% one, 35% two).
- `floor`, `ceiling` - the price band as a fraction of list price times quantity.
- `opening`, `jitter` - the buyer's opening offer as a fraction, plus or minus jitter.
- `notches` - steps on the picker. `sessionSeconds` - how long the haggle lasts.
- `handoffMs` - length of the handover. `walkAbove` - asking above this fraction of the band makes
  the buyer walk.
- `fallback` - used when a per-item or global value is missing.

`Sting`:

- `enabled`, `chance` (percent per illegal sale), `lawmanAlways` (selling to a uniformed lawman is
  always a sting).
- `struggleSeconds`, `ropeDelayMs`, `ropeRange`, `tieRange` - the lasso and hogtie.
- `crookedChance` (percent), `crookedDrinks` - a crooked lawman drinks some and lets you go.
- `lootMinutes`, `lootRange` - kill and loot the lawman within this time and distance to get the
  goods back.

`LawmanModels` - ped models that count as lawmen.

### config/wagons.lua

`Wagons`:

- `soloOnly` - true = the wagon and escorts are local to the spawner (not networked).
- `escortsPerWagon`, `cooldownMinutes` (per hideout, kept in memory only, so a restart clears it),
  `windowMinutes` (time to finish the job).
- `failDistance` - a crew member further than this (flat distance) from the wagon fails.
- `serverReach`, `completeReach` - distance to the wagon for the charge / the finish.
- `stripSeconds` - how long stripping takes (before perks).
- `alertPolice` - police get an alert when the charge is started.
- `explosive` - `{ required, item, count }` taken per charge. `fuseSeconds`.
- `spawnDistance`, `promptDistance`, `spawnRetrySeconds`.
- `charge` - the charge skill bars: `roundsMin`-`roundsMax` rounds, `misses` allowed, and the bar
  `zone`, `perfect`, `speed`, `iconSpeed`, getting harder by `zoneStep` / `speedStep` per round
  down to `minZone` / up to `maxSpeed`.
- `allowed` - still level -> job levels it may run.
- `followers` - extra escort wagons behind the main one, by job level (metres back).
- `model`, `weapons`, blip, explosion, prop and animation names.

`WagonLevels[level]`:

- `escorts` - ped models; the first one drives.
- `locations` - `{ coords, heading, rewards }`; a job picks one at random.

Loot rows look like this:

```lua
{ item = 'condenser', label = 'Condenser', amount = 1, chance = 10 },
```

`item` is the inventory item, `label` the name the player sees ("You got Condenser"), `amount` how
many drop. `chance` is out of 10, not percent: 10 = always, 5 = half the time, 1 = one time in ten.
Every row is rolled on its own, so one robbery can give several items.

Each level has a loot list (`LEVEL1_LOOT` and so on) that its locations share. A location uses it as
it is with `loot(LEVEL1_LOOT)`, or adds extra rows on top with
`loot(LEVEL1_LOOT, { extra row }, { another extra row })`; the shared list itself is not changed.

## For developers

Server exports:

| Export | What |
|---|---|
| `GetPlayerHideoutCount(charId)` | returns `total, owned, coOwned` |
| `AdminList()` | every hideout with owner, co-owners, players inside, stash, ledger, raid and production state (for vorp_admin) |
| `AdminAction(action, hideoutId, data)` | returns `ok, message`. Actions: `setledger` (`data.value`), `wipeledger`, `removeitem` (`data.name`, `data.amount`), `movehere` (`data.coords`), `wipestash`, `setowner` (`data.charid`), `addcoowner` (`data.charid`), `removecoowner` (`data.charid`), `endraid`, `resetcooldown`, `clearproduction`, `rename` (`data.name`), `evict`, `delete`. It trusts its caller; vorp_admin checks permissions |
| `AdminOpenStash(src, hideoutId)` | opens the hideout's stash panel for a staff member anywhere, with full controls; checks `manage_hideouts` through vorp_admin. Returns `true` or `false, reason` |
| `BoxStashItems(src, hideoutId)` | copy of the stash rows, or nil without access (pup-misc storage boxes) |
| `BoxStashTake(src, hideoutId, entryId, name, metadata, amount)` | take from the stash; returns `true, rows` |
| `BoxStashReturn(hideoutId, name, metadata, amount, label)` | give back items a box could not hold |
| `BoxStashPut(src, hideoutId, items)` | put `{ name, count, label, metadata, type }` rows into the stash if they fit |

Server events this resource fires (`AddEventHandler` to use them):

- `pup_hideouts:stillStripped` `(src, hideoutId, stillLevel, charId)` - a raider tore down a still.
- `pup_hideouts:drugsale_log` `(src, label, qty, paid, how, coords)` - a sale or sting; `how` is
  `'instant'`, `'haggled'` or `'sting'`.

Server events it listens to:

- `pup_hideouts:stashtaken_log` `(actor, hideoutId, item, qty)` - lets pup-misc log storage-box
  withdrawals.
- `pup-ui:posse:serverChanged` `(posseId, members)` - keeps raid and wagon crews in step with posses.
- Net events `pup_hideouts:sendlastcoords` `(_, coords)` and `pup_hideouts:getlastshinecoords`
  (answered with client events `pup_hideouts:reclastshinecoords` and
  `pup_realestate:reclastshinecoords`) - the last world position shared with pup_realestate.

Client events it fires:

- `pup_hideouts:enteredHideout` `(id)`, `pup_hideouts:leavingHideout` `(id)`.
- `pup-scene:stopscene` `(allowed)` - false on entering (blocks scenes inside), true on leaving.
- `pup-stable:deletehorse` on entering.
- `fred_meta:consume` from the bar.

Other:

- Server to client `pup-instance:bucket` `(bucket)` after every instance change.
- Client state bag `undergroundBusy` is true while planting a charge or stripping a wagon.
- Players inside hideout `id` are in routing bucket `id + Config.InstanceOffset`.
- pup-perks keys read: `still_yield`, `cook_speed`, `underground_speed`, `underground_bonus`,
  `dig_speed`, `drug_payout`, `sale_quiet`, `sale_scam`; awards: `still`, `drugsale`, `wagonrob`.

## License

See LICENSE.
