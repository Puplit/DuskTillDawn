# pup-stable

Town stables for RedM / VORP. Players buy horses, tack and wagons from a stablehand, keep them at a stable and call them out in the world; horses bond with their owner, earn XP and can be trained by stable staff.

## Features

- Horse shop by breed and coat, with tack, coat and tack colours, renaming, release and favourites
- Wagon shop with tints, liveries, propsets, lanterns and extras, and a wagon locker
- Whistle and follow, flee, call a wagon (J), and a horse menu and wagon menu on U
- Saddlebags and wagon lockers (VORP custom inventories); carry the saddlebag or lantern on foot
- Feeding, brushing and stims; bonding, riding XP, training levels and horseshoe wear
- Automatic vet: dead horses are revived after a delay for a fee
- Player to player transfers, and stable to stable transfers in realistic mode
- A free starter horse per character
- Wild horses to tame (skill bar) and sell or keep at a stable
- Society breeding: pairings, a foal board, foals growing in a paddock
- Pelts stowed on a horse, side saddle, waypoint sharing with a passenger
- Discord logs for purchases, transfers and wild horse sales
- Staff exports for vorp_admin

## Requirements

- RedM with OneSync
- `oxmysql`, `vorp_core`, `vorp_inventory`, `pup-ui`
- Optional: `pup_business` (breeding permissions), `pup-misc` (outfitter rows in the horse and wagon menus), `pup-minigames` (`skill_bar` for taming), `pup-perks` ("tame" award)

## Installation

1. Put the folder in `resources` and `ensure pup-stable` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui`.
2. Tables, columns and triggers are created and upgraded on start (`server/schema.lua`). If the database user may not create tables or triggers, run `sql/install.sql` by hand.
3. `sql/install.sql` also adds the care items to the `items` table: `sugarcube`, `Wild_Carrot`, `consumable_haycube`, `carrots`, `holgo`, `aplic`, `horsebrush`, `stim`, `unique_horsesupp`, `stim2`, `horse_coat_changer`. Add inventory images for them.
4. For Discord logs, set the webhooks in `server/config.lua` (empty = off). It is a server script, so it is never sent to clients.

## Commands

Every name can be changed or switched off (`false`) in `Config.Commands`.

| Command | Who | What |
|---|---|---|
| `/sidesaddle` | players | Ride side saddle |
| `/fleeHorse` | players | Send your horse away |
| `/callWagon` (also J) | players | Call your wagon |
| `/fleeWagon` | players | Send your wagon away |
| `/fixWagon` | players | Repair the nearest wagon of yours |
| `/reloadHorse` | players | Re-apply the tack on your nearest horse (within 10 m) |
| `/disableAutoRideFollow` | players | Switch auto ride follow off; `/disableAutoRideFollow 0` turns it back on |
| `/horseRest`, `/horseSleep`, `/horseWallow`, `/horseDrink` | players | Bond commands on your own horse |
| `/fixHorse` | players | Find your horses again (off by default) |
| `wildhorses` | server console | List wild horse spots and tamed horses |

Keys (in `Config.Keys`): G enter the stable, Enter (hold) stable the horse, B saddlebag, J call wagon, U horse/wagon menu, E (hold) stow a pelt, left Alt (hold) drop a pelt, hold the skip key 1 s to skip saddling scenes.

## Configuration

### config/main.lua

**Config.General**
- `debug`: print diagnostics to F8/console.
- `useMouse`: the stable menu takes the mouse too.
- `promptDistance`: metres from the stablehand for the Enter prompt. `stablehandSpawn`: metres from a stable before its stablehand appears.
- `previewLight`: light intensity at the preview camera.
- `horseFallbackPrice`, `wagonFallbackPrice`: price used when an entry has none.
- `transferDistance`: metres, player to player transfer reach.
- `takeOutAnywhere`: `true` = take a horse or wagon out at any stable; `false` = only where it is kept.
- `busyLockMs`: one buy/transfer at a time per player; the lock expires after this many ms.
- `nameMax`: longest horse or wagon name.
- `useGold`: also allow gold prices (entries with `gold = n`).
- `serverIdentifier`: reserved, not read by the current code.

**Config.AdminMovesTack**: `true` = a staff transfer also moves the horse's tack and saddlebag/locker contents to the new owner; `false` = they stay with the original character.

**Config.StaffGroups**: VORP groups that count as staff (breeding without a job, the wild horse console list).

**Config.ColorAllowList**: Steam identifiers allowed to pick custom coat and tack colours. Empty = nobody.

**Config.StableJobs / Config.TrainerJobs**: job names of stable staff and of horse trainers.

**Config.Transfer** (stable to stable, realistic mode only): `durationMs` how long "Transfer here" makes the horse/wagon unavailable (ms, memory only); `flatPrice` a number for a flat price or `false` to price by distance; `pricePerKm` dollars per km.

**Config.Vet**: `price` (dollars), `goldPrice` (`nil` = no "Revive with gold"), `deathDelay` seconds before any revive, `autoRevive` revive dead horses automatically, `sweepEvery` seconds between sweeps, `remindEvery` seconds between "cannot pay" reminders, `whistleResetsCores` a whistle revive refills the cores (otherwise they stay as they were), `reviveDeadAfterRestartAtOnce` horses dead at a restart are revived and charged on the first sweep.

**Config.Saddlebag / Config.Locker**: `access` 0 nobody, 1 owner only, 2 anyone; `default` slots, weight and whether weapons fit; `showSlots`/`showWeight` in the inventory header; `serverReach` metres the server allows; `enforceWeight` (saddlebag) `false` = slots only.

**Config.InventoryWatch**: an open saddlebag/locker closes when the player is further than `distance` metres for `polls` checks, `everyMs` ms apart.

**Config.Lantern**: `serverReach` and `promptReach` in metres, `weapon` the lantern weapon. **Config.CareReach**: feeding/brushing reach in metres on the client and server.

**Config.Starter**: the free starter horse. `breed` and `coat` refer to `config/horses.lua` (breed id, coat position); `stable` is a stable id; `speed`, `acceleration`, `handling` starting ranks; `message` is shown to the player.

**Config.Horse**
- `maxPerCharacter`: 0 = unlimited. `realistic`: realistic keeping (stable to stable transfers).
- `whistleSearch`: metres, road search radius for a whistled horse. `whistleAhead`: metres ahead of the player it arrives. `whistleTeleport`: metres beyond which the horse is brought closer instead of running in.
- `cullDistance`: metres; a horse further than this is put away.
- `instanceResyncMs`: ms between looks for your horses after leaving a routing bucket.
- `invincibleMs`: ms a fresh horse is invincible.
- `allowFlee`, `fleeDeleteMs` (ms before a fled horse is removed), `fleeKeepCoresMs` (ms its cores are remembered).
- `statsPrompt`: the game's Info prompt on any horse (own, other players', wild) opens the game's horse info card (speed, acceleration, handling, health, stamina, bond); press Info again or look away to close it. Trainers also get a training tip on their own horse. `false` = off.
- `ownerOnlyMount` with `mountSecurityFlag`: ped config flag that blocks strangers mounting (`nil` = off).
- `noHorseJump`: no jumping from horse to horse. `shareWaypoint`: share your waypoint with a passenger.
- `retrieveCutscene`, `stablingCutscene`: play the saddling scenes.
- `extraFlags`: `{ [flag] = bool }` ped config flags applied on spawn. `badGroundZones`: `{ { x, y, z, radius } }` (metres) where a called horse appears straight ahead instead of on the nearest road. `noWhistleTowns`: game town zone names where whistling is off.
- `putAwayOnInteriorEvent`: put the horse away when another resource fires `pup-stable:deletehorse`.
- `ownerFlags`: ped config flags set on every spawned stable horse.

**Config.Pelts**: `max` pelts stowed, `visible` how many are drawn, `serverReach` metres.

**Config.Shoes** (off by default): `lifeKm` km a set lasts, `warnBelow` warn below this share left (0.5 = half), `noRunBelow` the horse cannot run below this share, `price` of new shoes.

**Config.Stats**: `tickMs`, `saveMs` (ms), `levelToasts`, `walkEvery` metres walked per `walkPoints`, `walkGate` who earns walking points (`'trainers'`, `'jobs'` = `walkJobs`, or `'everyone'`), `pointCeiling` and `bondCeiling` (stat points out of 5000).

**Config.Training**: `trainersOnly` and `trainerDistance` (metres), `ceilings` highest rank per stat, `levels` XP for each horse level, `rankCost` XP per rank, `capPerLevel` highest rank allowed at each level, `rideEvery` seconds of riding per payout of `rideXP`, `focusMult` multiplier on the focused stat, `minSpeed`/`maxSpeed` speeds that count as riding, `xpPerMinute` cap, `feedback` toast and bar nudge settings.

**Config.Bonding**: `brave`/`calm` bond points from which a horse ignores shocking events / does not flee, `strangerKickChance` (0.5 = 50 %), `kickFlag` (`nil` = game default), `commandDistance` metres for bond commands, `feed`/`brush`/`skin`/`stow` points, cooldown (seconds) and radius (metres), `feedWhenMounted`, `drinkStamina` stamina added by drinking, `rest` points every `everySec` seconds while resting.

**Config.Colors**: `onCoat`/`onTack` allow colouring, `palettes` the tint palettes (`id`, locale `key`, number of `tints`), `coatChangerItem` and its reach (metres from a stable and from the horse).

**Config.Prices**: `components` price per tack category, `componentOverrides` `{ category = { [index] = price } }`, `componentGold` `{ category = goldPrice }`, `wagonCustom` price per customisation column, `wagonCustomOverrides` `{ column = { [index] = price } }`, `noneOptionCharged` the "No ..." row costs the column price.

**Config.Wagon**: `maxPerCharacter` (0 = unlimited), `realistic`, `callAhead` and `callSearch` metres (the road search radius is twice `callSearch`), `promptDistance`, `safeSpawn` metres that must be clear, `requireAllHarness` (reserved, not read by the current code), `canBeDamaged`, `retrieveCutscene`, `whistle`/`whistleMs`, `callLockMs`, `noCallTowns`, `fleeRadius` metres.

**Config.Breeding**: `cooldownDays` between pairings, `litter` foals per pairing, `gestationHours`, `paddock` scenery (spacing and offset in metres, `range` metres it is drawn from, rest cycle in seconds, foal growth start), `minPrice`/`maxPrice` (0 = no maximum), `cut` share the society keeps (0.05 = 5 %), `foalBag`, `names` random foal names, `height` range, `cross` cross-breed bonus, `permKey` the `pup_business` permission, `minGrade` job grade, `breederFoal` the breeder gets one foal too, `oneListingPerFoal` (`false` = one listing per litter), `buyNeedsStable` and `buyReach` (metres), `cooldownIgnoresRetired`.

**Config.Wild**: `blips`, `handInRadius`/`serverHandIn` metres, `salePrice` `{ min, max }`, `cooldownMin` minutes between sales, `rounds` skill bar rounds, `skillBar` settings, `refillMin` minutes before a spot refills, `spawnRange`, `spook` distances (sneaking / normal), `fleeDistance`/`throwFlee`, `wander`, `keep` (may keep the horse), `defaultName`, `nameMax`, `grantSec` seconds to keep a tamed horse at a stable, `tameReach`, `horseNear`, and `spots` (`coords` vector4 and the `models` that can appear there).

**Config.Logs**: `sendSteamAndDiscord` include identifiers, `colour` embed colour, `username`.

**Config.SideSaddle**: the side saddle idle animations (flat ground, uphill, downhill).

**Config.Keys**: control hashes for every prompt and raw keybind.

**Config.Hooks** (server side): `horsePrice`, `componentPrice`, `canAccessStable`, `canTransferHorse`. Return a changed value to override, or `nil` to keep it.

### config/stables.lua

One entry per stable. The key is the stable id stored on every horse and wagon: never change it. Each point is `v4(x, y, z, heading)`.

- `name`, `job` (the stable's staff job, or `nil`)
- `location` stablehand, `horsePreview` shop preview, `ownPreview` own horses preview, `retrieve` where a horse is handed out, `wagonPreview`, `wagonSpawn`, `saddleStore` where the saddle is carried in the stabling scene
- `paddock = { sire, dam, foal }` points for breeding (leave it out for no breeding at that stable)
- `polygon`: the stable area as `{ { x, y }, ... }`
- Optional, defaulting as in `DEFAULTS`: `stablehand` model, `blip` sprite, `horseMenu`, `wagonMenu`, `sellHorses`, `sellWagons`, `sellComponents`, `needsInstance` (a private routing bucket while in the menu)

### config/horses.lua

`Config.HorseDefaults` applies to every breed unless a breed sets its own: `saddlebag = { slots, weight, weapons }`, `age`, `neverDies` (only used by an optional horse-age add-on).

`Config.Breeds` is a list of breeds. Each breed has:
- `id`: a number of its own. Never change it once players own that breed (bred horses save it).
- `name`: the breed name players see.
- `coats`: every horse sold in this breed, in shop order: `model` (game model), `name`, `price` in dollars. The breed list shows the cheapest one. Add new coats at the end of the list: the position is saved on bred-horse listings.

Optional on a breed or a single coat: `gold = 10` (also sell for gold; needs `useGold`), `job = 'police'` (only that job can buy it), `saddlebag = { slots = 100, weight = 100, weapons = true }`.

```lua
{
    id = 40, name = 'My Breed', gold = 5,
    coats = {
        { model = 'A_C_Horse_Arabian_White', name = 'White', price = 900 },
    },
},
```

Below the "Nothing to edit below" line the list is turned into lookups.

### config/horse_stats.lua (server only)

`Config.HorseBirthStats` sets the starting ranks of every new horse by model: `['a_c_horse_arabian_white'] = { speed, acceleration, handling }`. The server decides a new horse's ranks (shop, tamed wild horse or foal) and ignores what a player's game reports, so these numbers are what players get. A model not listed uses the most common ranks of its breed's other coats, then `Config.Starter`'s ranks (the console says which model). Ardennes, Kladruber, Suffolk Punch and the mule have no numbers yet. A breed or coat in `config/horses.lua` can also set `stats = { speed = 4, acceleration = 3, handling = 2 }`, which wins over this file.

### config/wagons.lua

`Config.WagonCategories`: categories (`id`, `name`) each with a `wagons` list. Each wagon has `model`, `name` (shop name and the default name of an owned wagon), `price` in dollars, `storage` locker slots (leave out for no locker), and `seats`/`horses` shown in the shop when the game does not say. Optional: `forSale = false` (hidden from the shop; owned ones keep working), `job = 'police'`, `gold = 10`. Keep categories and wagons in the same order: menus refer to them by position.

```lua
{ model = 'wagon03x', name = 'Standard Wagon', price = 1500, storage = 750, seats = 2, horses = 2 },
```

`Config.WagonExtraNames`: names for owned wagons whose model is not sold.

### config/items.lua

`Config.Items`, keyed by item name:
- `kind`: `feed`, `brush`, `stim` or `coat`
- `priority`: the order the game's feed interaction picks a feed item in
- `health`, `stamina`: core points added (rings are 0-100)
- `overpower = { health, stamina }`: gold core overpower added
- `xp`, `consume` (item is used up), `prop` held while using it, `fromProp`

`Config.Reviver`: an optional revive item (off).

### config/locale.lua

Every player-facing text. `%s` / `%d` are filled in by the code.

## For developers

Server exports:
- `HorseCareReward(playerServerId, kind, item, horseId)`: give bonding for care (used by skinning).
- `GetPlayerStableAssets(charid)`
- `AdminGiveHorse(targetServerId, model, name, isFemale)`: create a new horse for a player (vorp_admin's Give Horse). `model` must be a horse model from the coat catalogue; returns `true` or `false, reason`.
- `AdminTransferHorse(horseId, targetServerId)`, `AdminTransferWagon(wagonId, targetServerId)`, `AdminFullyTrainHorse(horseId)`, `AdminResetHorseColor(horseId)`, `AdminOpenStorage(kind, assetId, staffServerId)`, `AdminDeleteHorse(horseId, staffServerId)`, `AdminDeleteWagon(wagonId, staffServerId)`
- `DescribeStableInventory(inventoryName)`: text for vorp_inventory logs.

Shared export: `getConfig()`.

Client exports: `getMyHorses(wait, forceRefresh)`, `getMyWagons(wait, forceRefresh)`, `SpawnHorse(horseRow, location, fixLocation, withComponents, networked)`, `SpawnWagon(wagonRow, location, fixLocation, networked)`, `ClearStowedPelts(horse)`, `GetMyHorsePed()`.

Server events: `pup-stable:server:newFavourite(horseId)`, `pup-stable:server:renameHorse(horseId, name)`, `pup-stable:server:renameWagon(wagonId, name)`.

Client events: `pup-stable:deletehorse` (local; puts the horse away when `putAwayOnInteriorEvent` is on), `pup-stable:horsesUpdated`, `pup-stable:zoneEntered` / `pup-stable:zoneLeft`, `pup-stable:closeAll`. The menus fire `pup-misc:outfitter:shop` and `pup-misc:outfitter:kit` for the outfitter.

## License

See LICENSE.
