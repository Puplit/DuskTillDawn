# pup-gangs

Player-run gangs for RedM / VORP: founding a gang at a gang table, ranks, factions, points and levels, a territory map, wars, blood money, dens, delivery runs, fort raids and each gang's own named drug. It has its own panel and a live map layer.

> [!WARNING]
> **Tested by the developer, not by real players.** It was played through in testing, but no live community has used it yet, so bugs may show up once real players do. Try every part of it on a private server first (founding, ranks, wars, dens, fort raids, drugs) before you open it to players.

## Features

- **Founding.** A player places a gang table inside a house they own or hold keys to, then founds the gang at it (cash, optional item). The table is the gang's HQ.
- **Factions.** Every gang picks one of three factions for good; each gives a points bonus, and faction standings run as a season-long three-way war. Factions can be kept secret from rivals.
- **Ranks.** A default five-rank ladder; the boss can rename ranks, add or remove them and set what each may do (invite, kick, promote, war, bank, territory).
- **Points and levels.** Points come from robberies, missions, wars and anything else that calls the `AwardPoints` export. Lifetime points set the gang level, which offers perks, stash slots and roster places. Idle gangs decay.
- **Territory map.** Each gang's influence circle grows with its points. Forts are claimable ground; a claim is a 20-minute public siege that needs a posse.
- **Wars.** Declared on a rival for cash and blood money, scored on kills, with points for the winner and a consolation for the loser.
- **Blood money.** A gang currency item members bank into a ledger; it buys perks, new members, banner colours and wars.
- **Stashes.** Gang stashes unlocked by perks, with rank gates, whitelists and an armory that takes weapons.
- **Dens.** Fixed moonshine-shack dens found by riding near them and opened with a den key; product brews on a shelf that rivals can raid. Inside: the den panel, the Den Inventory and a powder bench for gang-only explosives. Optional seizing and cooking.
- **Delivery runs.** Pick up a package at your den, plant it on rival ground, survive their search and carry the payday home.
- **Fort raids.** PvE waves of locals, a boss and a strongbox at a fort.
- **Gang drug.** Each gang names and skins its own product, orders seed from the ledger (collected at the pup_robbery fence), grows it through pup_homestead, sells it through pup_hideouts and improves it with a skill tree.
- **Admin bridge** for vorp_admin's Gangs page.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui` (toasts, input dialogs, list menus, push-to-talk, posse counting)
- `pup_realestate` (house access for placing the gang table)
- `vorp_lib` (optional; drag gizmo for placing the gang table, otherwise it drops in front of you)
- `pup_robbery` (optional; awards points and blood money, and runs the seed fence)
- `pup_hideouts` (optional; gang drug sales)
- `pup_homestead` (optional; growing the gang drug)
- `fred_metabolism` (optional; the gang drug's effect)
- `vorp_admin` (optional; Gangs page)

## Installation

1. Run `sql/install.sql`. It creates the `pup_gang_*` tables, seeds the three factions and the claimable forts, and adds the gang items (`gang_table`, `drug_package`, `blood_money`, `den_key`, `gang_seed`, `gang_drug`, `gunpowder`, `paper`) plus the reward and recipe items it hands out. Safe to run more than once.
2. Do a full server restart after adding items: vorp_inventory caches the items table at start-up.
3. Add `ensure pup-gangs` to `server.cfg` after `vorp_core`, `vorp_inventory`, `oxmysql`, `pup-ui` and the optional resources you use.
4. The gang drug icons must exist as PNGs in `vorp_inventory/html/img/items/` (see `Config.GangDrug.icons`).
5. For the gang drug, add the crop named in `Config.Integrations.homestead.cropType` to pup_homestead's `Config.Crops`.

## Commands

| Command | Who | What |
|---|---|---|
| `/gang` | Players | Accepts an invite; opens the panel only when `menuAnywhere` is on (name: `Config.General.panelCommand`) |
| `/creategang` | Players | Starts founding a gang (name: `Config.General.createCommand`; `''` turns it off) |
| `/gangden` | Admin group / console | Places and removes fixed dens |
| `/gangdrug` | Admin group / console | Gang drug admin tools |
| `/gangpoints <gangid> <amount>` | Admin group / console | Adjust a gang's points |
| `/denwhere`, `/gangdendoor <site>` | Debug on | Why is there no den prompt; record where a den door actually is |
| `/raidwhere` | Debug on | Why has nothing spawned in a fort raid |

## Configuration

### config/main.lua

**Config.General**: `debug` (traces to the server console and F8; off on a live server), `createCommand`, `panelCommand`, `menuAnywhere` (`false` = the panel opens only at the gang table).

**Config.Keys**: prompt key hashes; change the hash only. `table` (E, open the gang table), `tablePickup` (G, founder picks the table back up), `denInteract` (E, collect product / raid at a den crate), `denRun` (G, start a delivery run at your own den), `denMenu` (F, panel in den context: claims and raids), `denDoor` (G, use the key / go inside / step outside), `denWorkbench` (E, the den panel inside the shack), `denStores` (E, the den inventory), `fortLoot` (E, hold to crack the strongbox).

**Config.Integrations**: `homestead.cropType` is the pup_homestead `Config.Crops` key for the gang drug. These need no settings: pup_realestate (house access for the gang table), pup_hideouts (gang drug sales), pup_robbery (points, blood money, seed fence), fred_metabolism (gang drug effect) and pup-ui.

**Config.Creation**: `price` (cash to found a gang), `item` (optional item consumed, e.g. `'gang_charter'`; `nil` = none), `minNameLength` / `maxNameLength` (characters), `minShortLength` / `maxShortLength` (tag length, "Valentine Predators" -> "VPR"), `maxMembers` (base roster cap before level and blood-money slots; `0` = unlimited).

**Config.Factions**: every gang picks one when it is founded, permanently. `hidden` (`true` = a gang's faction is intel, not a public label), `order` (order in the creation form), `list` entries: `label`, `blurb` (creation form text), `colorModifier` (blip colour hash name), `bonus = { label, robberyMult, missionMult, warMult }` (1.0 = normal).

**Config.Ranks**: index 1 is the lowest. `list` entries: `id`, `label`, then permissions `invite` / `kick` / `promote` / `war` / `bank` / `territory` (true/false). `unlocks`: per rank index, `label` (panel text) and `stash` (may open gang stashes). Each gang's boss can edit their own ladder in game; this is the starting ladder.

**Config.Map**: `baseRadius` (metres at 0 points, also used for unclaimed ground), `radiusCurve` (radius in metres reached at each points total), `maxRadius` (metres, hard ceiling), `blipSprite` (centre icon; `''` = none), `showName` (label the blip: tag + points + faction), `showRivalTerritory` (`false` = you only see your own turf), `refreshSeconds` (how often clients re-pull the territory list), `worldCircles` (`false` = clean point markers instead of painted circles), `worldBlips` (what reaches the world map at all; `'none'` = nothing).

**Config.Colors**: the colour a gang flies. `default` (key a new gang starts with), `list` entries: `key` (stored on the gang), `label`, `modifier` (blip colour hash name), `hex` (panel colour).

**Config.Wars**: `declareCost` (cash; the blood money cost is `Config.Blood.perWar`), `durationHours`, `pointsPerKill`, `allowSameFaction` (`false` = no wars between gangs of the same faction).

**Config.Table**: the gang table, placed inside a house the placer owns or holds. `item` (consumed on placement, refunded when picked up), `prop`, `interactDistance` (metres).

**Config.Points**: `announce` (tell the player every time their gang scores), `robbery` / `mission` (default awards for those kinds), `warWin`, `warLoss` (consolation), `territoryCap`, `decayEnabled` (idle gangs bleed points), `decayPerDay` (points lost per real day with no activity), `decayFloor`, `dedupeMinutes` (one robbery = one gang award, however many members ran it).

**Config.Activity**: the second indicator next to points. `highWeekly` / `mediumWeekly`: points earned in 7 days for HIGH / MEDIUM; anything less is LOW.

**Config.Blood**: the gang currency. `item` (carried and banked into the ledger). Costs: `perMember` (a new rider, charged when they accept), `perPerk` (unlock one perk your level has made available), `perColour` (changing the banner colour), `perWar` (on top of `Config.Wars.declareCost`). `perksNeedBuying` (`true` = reaching a level only puts its perks on the shelf), `maxExtra` (member slots that can be bought, still capped by level). Income, `{ min, max }` per award: `mission` (plant run, defence, fort raid, den), `robbery` (per box looted), `drugSale` (per sale through pup_hideouts); `robberyChance` / `drugSaleChance` (0-100).

**Config.Missions**: the delivery run. `unlock` (perk flag), `minRank` (to pick up a package), `packageItem`, `minPosse` (members needed), `defendSeconds` (time the defenders get to find the plant), `cooldownMinutes` (per attacking gang), `collectMinutes` (time to get home to the den once it survives), `alertRadius` (metres, how vague the defenders' circle is), `alertColor`, `alertSprite`, `destroyDistance` (metres a defender must get to destroy it). Payouts are in `config/rewards.lua`.

**Config.Claims**: 20-minute public sieges. `durationMinutes` (hold this long and the ground changes hands), `tickSeconds` (presence check interval), `presenceTicks` (consecutive empty checks before the claim fails), `travelGraceMinutes` (time to reach the ground), `cooldownMinutes` (per territory), `defendersOnline` (held ground is only contestable while its holders have someone online), `minPosse`, `startOnArrival` (the clock starts when the posse gets there).

### config/rewards.lua

What a delivery run (`run`), a defence (`defend`) and a fort raid (`fort`) pay. Seizing a den and winning a claim resolve on a server tick with no single player to pay, so they only give the points set in their own sections.

Each entry: `points` (gang points), `cash = { min, max }`, `items` = a list of `{ item, min, max, chance }` where chance is 0-100 per roll, e.g. `{ item = 'gunpowder', min = 2, max = 5, chance = 65 }`. `run.perTargetMember` adds points per online member of the target crew. The strongbox contents of a fort raid are `Config.FortRaid.loot`.

### config/perks.lua

**Config.Perks.levels**: each entry is `level`, `points` (lifetime gang points to reach it), `label`, and `perks`:
- `stashSlots`: extra slots on every stash.
- `pointsMult`: points multiplier (1.0 = normal).
- `members`: extra roster places.
- `unlocks`: perk flags this level puts on the shelf (bought with blood money when `perksNeedBuying` is on).

**Config.Perks.labels**: perk flag -> name shown in the panel. Text after ` (` becomes the chip tooltip.

**Config.Stashes**: `invOffset` (custom inventory id = `invOffset + (gangid * 10) + stash index`). Each `list` entry:

| Field | Meaning |
|---|---|
| `key` / `label` | Id and name |
| `unlock` | Perk flag (`nil` = always available) |
| `slots` | Base slots, before `perks.stashSlots` |
| `minRank` | Rank index needed to open |
| `whitelist` | `{}` = anything, else a list of item names |
| `weapons` | `true` = accepts weapons |
| `den` | `true` = lives at the den; holding a den is the unlock |
| `bare` | `true` = the container header shows only the label, no gang name |

### config/dens.lua

**Config.Dens**: `unlock` (perk flag), `playerDens` (`true` = a gang may make its own house a den), `maxByLevel` (dens per gang level), `prop` (crate that marks a den), `interactDistance` (metres), `minRank` (to collect product), `brewMinutes` (one package every this many minutes), `maxStored` (shelf cap; brewing pauses when full), `raidMinRank`, `raidHoldSeconds` (raider must hold the spot this long), `raidHoldRadius` (metres), `raidCooldownMinutes` (per den), `raidAttackerPoints` / `raidDefenderPoints`, `alertRadius` (metres), `resetOnRestart` (wipe fixed-den ownership and discovery at boot: a den is a lease on the session), `keyItem`, `doorDistance` (metres from the den door).
- `key`: `minRank`, `consume` (the key is spent opening the den), `points`, `announce`.
- `discovery`: `discoverDistance` (metres; ride this close and your gang has found it), `announceToGang`, `keepFound`.
- `seize` (off by default): take an unowned den by holding it. `minRank`, `holdSeconds`, `holdRadius`, `tickSeconds`, `presenceTicks`, `alertRivals`, `points`, `cooldownMinutes`.
- `cook` (off by default): `minRank`, `cookMinutes`, `cooldownMinutes`, `ingredients` (`{ item, count }` consumed per batch), `product` (made per batch), `goesHot` (reveal the den on every gang's map while cooking), `hotRadius`, `points`, `bulkPerkBonus` (extra product with `bulk_cook`).
- `bench`: the powder bench. `unlock`, `minRank`, `cooldownSeconds`, `craftMinutes` (fallback), `recipes` entries: `name` (row label), `give = { item, count }`, `costs` (list of `{ item, count }`), `minutes`.

**Config.Dens.locations**: fixed dens, seeded into the database and matched on label. Entry: `site` (key in `Config.Dens.sites`), `label`, `x, y, z, h` (the crate / door point).

**Config.Dens.sites**: the moonshine shack interiors behind each den door; client/den.lua requests their IMAPs itself. Each entry:

| Field | Meaning |
|---|---|
| `label` | Shack name |
| `verified` | Walked in game |
| `conflicts` | Note: another resource sharing the same shell |
| `outside` | Door point |
| `inside` | Teleport point |
| `menu` / `ped` / `bench` / `stash` | Points inside |
| `interior` | Interior id |
| `interiorSets` | Entity sets switched on |

Unverified sites use offsets from `inside`: menu (-5.04, +18.20, -2.10), ped (-6.36, +19.08, -2.10), bench (+9.46, +2.62, -1.66). Walk a site in game before relying on it (`/gangdendoor <site>` records the real door point). The Lemoyne shell (interior 77313) is shared with pup_hideouts.

### config/fortraid.lua

**Config.FortRaid**: `unlock` (perk flag), `minRank` (to call the raid), `minCrew` (living members on site before the first wave), `cooldownMinutes` (per fort), `gangCooldownMinutes` (per gang), `armMinutes` (called from the den; time to ride out before it lapses; `0` = be on site to call it), `startRadius` (metres), `arenaRadius` (metres; leave this far and the raid is abandoned), `abandonSeconds`, `minRaidMinutes` (the strongbox stays shut until the raid has run this long, shown on the game's timer; `0` = off), `timerRedSeconds`.
- `waves` entries: `count` (peds), `health`, `accuracy` (0-100), `spawnRadius` (metres from the fort), `models` and `weapons` (picked at random). `waveBreakSeconds` between waves.
- `boss`: spawns alone after the last wave. `model`, `name`, `health`, `accuracy` (0-100), `weapon`, `armour` (`true` = no critical hits).
- Strongbox: `lootProp`, `lootSeconds`, `lootDistance` (metres), `lootToDen` (`false` = straight to the satchel of whoever cracked it). `loot.rolls` (at most this many different entries per box) and `loot.table` entries `{ item, min, max, chance }`.
- `forts` entries: `label`, `x, y, z` (the fort centre).

### config/drugs.lua

Every gang that buys the drug perk names and skins its own product. The name and icon travel in vorp_inventory metadata on two shared items, so no per-gang items row is ever needed; the server writes that metadata, never the client.

**Config.GangDrug**: `perk` (must be in `Config.Perks.labels` and a level's unlocks), `managePerm` (rank permission to create, rename, re-skin and spend points; the leader always passes), `buyPerm` (to order seed; `nil` = any member), `seedItem` / `drugItem`, `nameMin` / `nameMax` (characters), `renameCost` (blood money per rename; `0` = free).
- `icons` entries: `key`, `label`, `image` (PNG basename under `vorp_inventory/html/img/items/`; it must exist there or the slot renders blank).
- `seed`: ordered and paid at the gang table, collected in person from the pup_robbery fence. `price` (blood money per batch), `perBuy` (seeds per batch), `maxHeld`, `collectAtFence` (`false` = straight to the satchel), `fenceDistance` (metres), `maxPending`.
- `sale`: through pup_hideouts' NPC prompt. `price` (base per unit), `foreignOnly` (`true` = locals refuse it outside rival ground), `ownTurfSells` / `neutralSells` (sells there but earns no points), `bonusMult` (money multiplier on a qualifying sale), `pointsPerUnit` (drug progression per unit sold on rival ground), `pointsPerSaleCap`.
- `effect`: the base effect through fred_metabolism. `health` / `stamina` / `deadeye` (inner core points, 0-100), `healthGold` / `staminaGold` / `deadeyeGold` (fortified, 0.0-1.0), `durationMs`, `hunger`, `thirst`, `metabolism`, `animation` (an animations key; `''` = none), `prop`, `screen` (screen effect; `''` = none).
- `tree` entries: `id`, `name`, `tier`, `description`, `icon`, `requiredPoints` (cost, taken from the spendable balance), `prerequisites` (node ids that must be unlocked), `effect`, `effectValue`. Effect keys: `health`, `stamina`, `deadeye`, `healthGold`, `staminaGold`, `deadeyeGold`, `duration` (ms), `yield` (+drug per harvest), `saleValue` (+fraction of price), `progression` (+fraction of points), `seedDiscount` (-fraction of seed price).
- `levels` entries: `level`, `points`, `label`. Read off lifetime points earned, never the spendable balance.

### config/locale.lua

Every message, toast and prompt label. Lines with `%d` / `%s` are format strings: keep the same placeholders in the same order.

## For developers

Server exports (`exports['pup-gangs']:...`):

| Export | What |
|---|---|
| `AwardPoints(source, kind, amount?, detail?)` | Award gang points for an activity (`'robbery'`, `'heist'`, `'mission'`, ...). Deduplicated per gang and operation |
| `AwardBloodMoney(source, kind, reason?)` | `kind`: `'mission'`, `'robbery'`, `'drugSale'`, or a `{ min, max }` table |
| `RegisterKill(killerSource, victimSource)` | Scores a war kill between two gangs |
| `GetGangOf(charid)` | `{ id, name, faction, points, rank }` or `nil` |
| `GetGangPoints(gangid)` | The gang's points |
| `GetGangLevel(gangid)` | `{ level, label, points, perks }` |
| `HasPerk(gangid, flag)` | Whether the gang holds a perk |
| `GetFactionStandings()` | Faction season standings |
| `DrugSeedOrder(source)` | `{ count, label }` waiting with the fence |
| `DrugCanPlant(source)` / `DrugTakeSeed(source, amount)` | pup_homestead planting check and cost (the player's own gang seed only) |
| `DrugHarvest(source, baseCount, dryRun)` | pup_homestead harvest; returns `{ count, label }` |
| `DrugSellOffer(source)` / `DrugTakeForSale(source, want)` / `DrugSaleDone(source, sold, pay)` / `DrugSaleMult(source)` | pup_hideouts sale bridge |
| `adminGangList()`, `adminAdjustPoints(gangid, delta)`, `adminResetPoints(what)`, `adminDisbandGang(gangid)` | vorp_admin Gangs page. `what` = `'gangs'`, `'members'`, `'factions'` or `'all'` |

Events and callbacks other resources use:
- `pup-gangs:drugCollectSeed` (client -> server): collect the seed order, fired from the pup_robbery fence menu.
- `pup-gangs:getSeedOrder` (vorp_core callback): what the fence menu asks before drawing its option.
- It listens to `vorp_core:Server:OnPlayerDeath`: a carrier dying loses the delivery run.

## Credits

The map image is loaded at runtime from kibook/webmap's public GitHub repository (`rdr3/map.jpg`); it is not shipped with this resource.

## License

See LICENSE.
