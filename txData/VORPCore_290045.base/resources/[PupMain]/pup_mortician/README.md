# pup_mortician

The undertaker trade for RedM (VORP Core). Undertakers prepare and bury the dead for pay, collect bodies from a contract board, and dig for treasure with a shovel.

## Features

- **Prep tables** in Rhodes, Saint Denis, Armadillo and Strawberry. Carry a corpse to your table, lay it down, fill the casket with the goods the body asks for, close it, carry it to the burial site and bury it for pay. Each good laid in adds a bonus.
- **Graveyard burials**: bury a carried body straight into any graveyard for a flat rate.
- **Contract board**: each table posts named dead to collect. Take a posting, follow the route, find the bodies and bring them in for a bonus. Casket burials of contract bodies sometimes earn a keepsake from the family.
- **Treasure digging**: use a shovel, pass the skill bar, and dig up a few dollars or an item. Shovels wear out.
- **Business**: the boss of an undertaker business (decided by `pup_business`) sets a house cut on every burial and a Discord webhook for burial reports.
- **Register**: every burial is written down. The Ledger shows the last 40, and bosses see a 7-day summary per undertaker.
- **Burial limit**: a set number of burials per character in a time window (stored in the database) or per server restart.
- Every rule, payment and distance is checked on the server.

All interaction is through on-screen prompts, the `shovel` item and one pup-ui panel, the **Undertaker's Ledger**.

## Requirements

- `vorp_core`, `vorp_inventory`, `oxmysql`, `pup-ui`, `pup-minigames`
- Optional: `pup_business` (bosses, house cut, business webhook), `pup-perks` (dig speed, shorter timed actions, XP), `goldpan` (no digging while panning)

## Installation

1. Put `pup_mortician` in your resources folder.
2. Run `sql/install.sql`. It creates the three tables (they are also created on start if missing) and adds the 21 items with `INSERT IGNORE`, so existing items are never overwritten. Add item images for any of them your inventory does not have yet; images are read from `nui://vorp_inventory/html/img/items/`.
3. Set `logs` in `server/config.lua` to a Discord webhook for the staff log (goods laid in, burials, treasure). Leave it empty to turn the log off. The file is server only and never sent to players.
4. Add `ensure pup_mortician` to `server.cfg` after `vorp_core`, `vorp_inventory`, `oxmysql`, `pup-ui` and `pup-minigames` (and `pup_business` / `pup-perks` if you use them).
5. Give your undertakers one of the jobs in `Config.UndertakerJobs`.

## Commands

There are no chat commands and no ACE permissions.

| Action | Who | What |
|---|---|---|
| `G` at a prep table | undertakers | open the Undertaker's Ledger (table, board, register, business tabs) |
| `G` at the burial site | the undertaker carrying a closed casket | bury the casket |
| `G` at a graveyard | an undertaker carrying a body | bury the body straight into the graveyard |
| use the `shovel` item | jobs in `Config.DigJobs` | take out the shovel and dig for treasure |

## Configuration

Everything lives in `shared/config.lua`. Anything the server decides (pay, distances, limits) is read on the server; the client copy is only used to draw prompts and props. Player text is in `shared/locale.lua` (`%s` / `%d` placeholders are filled in by the script; an unknown key shows as the key itself).

### Who may do what
- `Config.Debug`: extra console output.
- `Config.UndertakerJobs`: characters with one of these jobs are undertakers.
- `Config.DigJobs`: characters with one of these jobs may dig with a shovel. An empty list lets anyone with a shovel dig.
- `Config.AnyUndertakerAnyTable`: `false` = an undertaker may only work the table whose key equals their job.

### Config.Limit (burial limit)
- `perCharacter`: burials allowed per character.
- `mode`:
  - `'window'`: a window of `windowHours` opens on the first burial and is stored in the database (`mortician_shift`), so it survives restarts.
  - `'restart'`: a per-character count kept in memory, reset on every server restart.
- `windowHours`: length of the window in hours.

### Pay
- `Config.Pay.casketBase`: dollars for a casket burial, before goods and the contract bonus.
- `Config.Pay.graveyard`: dollars for a body buried straight into a graveyard.
- `Config.WantedGoods`: how many goods (`min` to `max`) a body asks for.
- `Config.HouseCut`:
  - `enabled`: take a house cut for the business on each burial.
  - `default`: percent, used when the business boss has not set one.
  - `max`: highest percent a boss may set (clamped to 0..100).
  - `bossesKeepAll`: the boss pays no cut on their own burials.
  - `verifyLedgerRow`: before banking a cut, check (read only) that the business has a `society_ledger` row. Without one the cut stays with the undertaker instead of vanishing.

### Config.Shovel
- `items`: item names that count as a shovel.
- `uses`: uses before the shovel breaks. `0` = it never wears.
- `wearOnBurial`: casket and graveyard burials wear the shovel too.

### Map, keys and distances
- `Config.BlipSprite`, `Config.BlipStyle`: map blip sprite and style hashes.
- `Config.ItemImages`: where item images are loaded from.
- `Config.Keys`: `use` (G) is the world prompt; `putAway`, `weaponWheel` and `b` are the keys used while holding the shovel. Change the hash only.
- `Config.Distance` (metres):
  - `tablePrompt` / `tableServer`: prompt range at a prep table, and the range the server accepts.
  - `corpse`: how close a corpse must be to the player.
  - `burialPrompt` / `burialServer`: same pair for the casket burial site.
  - `gravePrompt` / `graveServer`: same pair for graveyards.
  - `propsDraw` / `propsClear`: table props are drawn inside `propsDraw` and removed beyond `propsClear`.
- `Config.AbandonMinutes`: a casket nobody has touched for this many minutes is freed.

### Config.Tables (prep tables)
The key is the undertaker job that works the table.
- `town`: the name shown.
- `pos`, `heading`: where the table stands.
- `bodyRot`, `bodyOffset`: how the body prop lies on the table.
- `burial`: where the closed casket is buried.
- `pickups`: fixed contract pickup points (`vector3`). Empty = generated around the table.

Adding a table: add a job to `Config.UndertakerJobs` and a block with the same key:

```lua
vhundertaker = {
    town = 'Van Horn',
    pos = vector3(0.0, 0.0, 0.0), heading = 0.0,
    bodyRot = vector3(250.0, 10.0, -150.0), bodyOffset = vector3(-0.05, -0.15, 0.2),
    burial = vector3(0.0, 0.0, 0.0),
    pickups = {},
},
```

### Config.Graveyards
`short id = vector3`. The short id is what the register shows as the place of burial.

### Config.Goods (casket goods)
In list order. Each entry is `{ item, label, amount, bonus }`: the inventory item, the name the Ledger shows, how many are taken, and the dollars it adds to the burial pay.

### Config.Towns
Town anchors: used for travel-mode pickups and as the server's no-dig zones (see `Config.Dig.townRadius`). Each is `{ name, pos }`.

### Config.Contracts (the board)
- `enabled`: turn the board on or off.
- `perBoard`: postings per table.
- `refillMinutes`: every this many minutes, old postings are pruned and one new one is added.
- `deadlineMinutes`: time to finish a posting once taken.
- `untakenMinutes`: an untaken posting is removed after this long.
- `bodiesMin` / `bodiesMax`: bodies per posting.
- `bonusPerBody`: dollars added to the pay when a contract body is buried.
- `keepsakeChance`: percent; contract casket burials only.
- `bodiesOnly`: `true` = the prep table only takes the dead from your contract.
- `travel`: `false` = pickups are placed `localMin`..`localMax` metres from the table. `true` = a town `travelMin`..`travelMax` metres away is picked (one of the `travelNearest` nearest) and the pickup is placed `townSpreadMin`..`townSpreadMax` metres from it.
- `spawnRange`: metres; bodies spawn when the player is this close to the pickup.
- `arriveClient` / `arriveServer`: metres; arrival range on the client and the range the server accepts.
- `maxRespots`: how many times a posting may be moved to a new spot.
- `respotThrottle`: seconds between respots.
- `clearMarkerBeyond`: metres; the marker clears once all bodies are collected and the player is this far away.
- `maleModels`, `femaleModels`, `maleNames`, `femaleNames`, `lastNames`, `causes`: what a posting's dead look like and are called.
- `keepsakes`: possible keepsakes, `{ item, label, amount }`.
- `offsets`: body spawn offsets around a pickup (x, y metres), repeating.
- `maxSlope`: the ground normal's z must be at least this for a body to spawn there.

### Config.Dig (treasure digging)
- `findChance`: percent of digs that find something.
- `moneyShare`: percent of finds that are money.
- `moneyMin` / `moneyMax`: dollars per money find.
- `itemMin` / `itemMax`: how many of an item per item find.
- `seconds`: dig time, scaled by the pup-perks `dig_speed` multiplier.
- `dugRadius` / `dugMinutes`: a spot within this many metres of a recent dig cannot be dug again for this many minutes.
- `townRadius`: metres; no digging this close to a `Config.Towns` anchor.
- `groundSnap`: metres; how far the dig scene may snap to the ground.
- `finishShare`: the dig must run at least this share of its time before it can finish.
- `finishRange`: metres the player may move from the dig spot.
- `blockedZones`: game town map zones where the client refuses to dig.
- `treasure`: possible item finds, `{ label, item }`.
- `skillBar`: the pup-minigames skill bar. `difficulty`, `icon`, `scale`, `style`, `orientation` and `movingIcon` set its look; `areaBase` / `areaStep` / `areaMin` / `areaMax` and `speedBase` / `speedStep` / `speedMin` / `speedMax` set the target size and speed by difficulty; `perfectArea` is the perfect zone.

### Models, animations and rate limits
- `Config.Models`, `Config.Anim`: game props and animations referenced by name (Rockstar content, not shipped). Times in `Config.Anim` are in ms; `prepBaseMs + prepPerGoodMs` per extra good, capped at `prepMaxMs`, is the preparation time.
- `Config.RateLimit`: minimum gap in ms between two requests of the same kind from one player.

## For developers

Server exports:

- `exports.pup_mortician:WearShovel(source)`: wears the player's shovel by one use.
- `exports.pup_mortician:BuriesLeft(source)`: burials the active character may still do; `0` without a character.

Client events:

- `shoveling:shoveling` (local, `true` / `false`): fired when a dig starts and ends.
- `panning:panning` (local, listened to): while `true`, digging is refused.

## License

See LICENSE.
