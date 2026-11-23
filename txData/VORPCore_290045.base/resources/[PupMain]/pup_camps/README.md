# pup_camps

Player camps for RedM (VORP Core, Lua 5.4, OneSync expected). Players found a camp with a flag, run it together with ranks, a safe and a tax ledger, furnish it, keep a camp economy going with missions, and raid other camps with their posse.

## Features

- Found a camp with the `flag` item; move it later for a fee (`/movecamp`).
- Members, invites and three ranks (Member, Trusted, Manager) plus the leader; every action has a configurable minimum rank.
- Camp safe (deposit, withdraw, take all) and a separate tax ledger.
- Calendar-based taxes (monthly or on set days of the month). A camp that cannot pay, or has too few members, is shut down and hidden until staff restore it. The leader gets a warning letter beforehand.
- Furniture: up to 20 placed pieces from a catalogue of props and game prop sets. Functional pieces: storage chest (camp stash in the vorp_inventory clan panel), beer box, water barrel, wardrobe, stable (horses and wagons from pup-stable), stew pot and trapper.
- Camp economy: donated animals become materials, which supplies turn into stock over time; stock is sold through delivery missions.
- Supply missions (ride out, kill the guards, bring the wagon home) and delivery missions (drive a wagon to a drop-off point and fight off an ambush), with posse support.
- Raids: a posse crew, a shared countdown, a lockpick or safe-crack window and a looting window on the target's stash. Defenders get an alert blip.
- Eight public butchers with server-decided prices for carcasses, registered pelts and pelts stowed on horses.
- A per-character hunting-wagon stash for carcasses and pelts.
- Snake-bite poison with cure items.
- Discord logs per camp (leaders can connect their own channel), plus staff mirror, raid and butcher channels.
- vorp_admin "Camps" page support (list, edit, open stash, shut down, delete).

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory`
- `pup-ui` (menus, prompts, progress bars, placement tool, posses)
- Optional:
  - `pup-minigames` (safe-crack minigame in raids when `lockpick` is not running)
  - `lockpick` (lockpick minigame in raids)
  - `pup-stable` (camp stable: horses and wagons, horse pelts)
  - `pup-misc` (Eco Boost bonus on butcher/trapper sales, storage boxes that use the camp stash)
  - `pup-perks` (supply and sale bonuses, XP for supply and delivery runs)
  - `pup_postoffice` (tax and shut-down letters)
  - `vorp_admin` (admin Camps page, spawn guard permits, `delete_camp` permission for the repo commands)
  - `vorp_lib` (drag gizmo for placing furniture)
  - `skinanimals` (skinned-carcass checks)
  - `fred_metabolism` (beer, water and stew effects on hunger, thirst and cores)
  - `pup-scene` (blocks founding inside interior scenes)
  - `poker` (detected only; a camp poker set is decoration, see below)

## Installation

1. Run `sql/install.sql` once. It creates the `clan` and `wagon_stash` tables, the shared `cron_state` table, the `characters.clan` column and the item rows (flag, furniture, lockpick, cure items, stew ingredients). It is safe to run more than once, and the resource also creates its own tables on start.
2. Add inventory images for the items in `sql/install.sql` to vorp_inventory if you do not already have them. The resource itself ships no images, fonts, sounds or HTML.
3. For Discord logs, set your webhook URLs in `server/config.lua` (server only, never sent to players). An empty value switches that channel off.
4. In `server.cfg`, `ensure pup_camps` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui` (and after any optional resources you use).

## Commands

Command names can be changed in `Config.Commands`.

| Command | Who | What |
|---|---|---|
| `/viewinvites` | anyone | Answer camp invites received this session |
| `/movecamp` | camp leader, in moving mode | Pitch the camp at the current spot |
| `/repoclan <camp id>` | console, admin group, or vorp_admin `delete_camp` | Shut a camp down (hidden from the map) |
| `/unrepoclan <camp id>` | console, admin group, or vorp_admin `delete_camp` | Reopen a shut-down camp |
| `/adminresetfurni <camp id>` | console or admin group | Remove every piece except the flag (items are not returned) |
| `/changeleader <player id> <camp id>` | console or admin group | Make an online member the leader |
| `/cycleclans` | console or admin group | Run one camp day |
| `/syncclanmembers` | console or admin group | Repair member lists against `characters.clan` |
| `/resetallraids` | console or admin group | Clear every raid cooldown |

## Configuration

| File | Holds |
|---|---|
| `config/main.lua` | All settings |
| `config/furniture.lua` | Furniture catalogue |
| `config/animals.lua` | Butcher price table |
| `config/missions.lua` | Mission regions, supply missions and delivery missions |
| `config/places.lua` | Public butchers |
| `config/integrations.lua` | Adapters for optional resources |
| `locale/en.lua` | All player-facing text (`string.format` placeholders such as `%s`, `%d`) |

Distances are in metres unless noted.

### config/main.lua

**General**

- `Debug`: extra console output.
- `RestartsPerDay`: server restarts per real day. A camp day runs on every resource start; the "Days Up" shown for a camp is its age divided by this, rounded down.
- `SaveEveryMin`: minutes between full saves of every camp.

**Commands** (`Config.Commands`): the chat/console name of each command above.

**Keys** (`Config.Keys`): control hashes for interact (G), confirm (ENTER), stash (CTRL), inventory (I, blocked while a camp menu is open), hand-in (X) and cancel (BACKSPACE).

**Camp** (`Config.Camp`)

- `flagItem`, `flagProp`: the item that founds a camp and the prop shown for it.
- `maxMembers`: member limit (0 = unlimited).
- `blipSprite`, `blipColours`: camp blip sprite and how many colours the leader can choose from (`BLIP_MODIFIER_MP_COLOR_1` to `_32`).
- `spacing`: minimum distance between camps.
- `renderDistance`: distance at which camp props are spawned.
- `furnitureRadius`: furniture must be placed within this of the flag.
- `roadDistance`: a camp cannot be founded this close to a road.
- `nameMax`, `defaultName`: camp name length limit and default name.
- `blipPrice`, `relocatePrice`: prices for changing the blip and moving the camp.
- `setupSeconds`: how long pitching the camp takes.
- `claimDistance`: the server requires the player to stand this close to the spot they claim.
- `atCampSlack`: "at the camp" means within the furniture radius plus this, measured in 3D from the flag.
- `placeSlack`: the server accepts a piece this far past the furniture radius (flat distance).
- `maxPieces`: placed pieces per camp; the flag does not count.
- `useGizmo`, `gizmoRange`: place furniture with the vorp_lib drag gizmo when vorp_lib is running and `useGizmo` is on; otherwise pup-ui's placement tool is used.
- `setTentModel`: stand-in model shown while placing a prop set.
- `lockRetrySec`: seconds the flag prompt is ignored after "menu in use".
- `regionLock`, `regionDefaultRadius`: empty = camps can be founded anywhere. Otherwise list circles where founding is allowed, e.g. `regionLock = { { x = -300.0, y = 800.0, z = 118.0, radius = 500.0 } }`. `radius` is optional and defaults to `regionDefaultRadius`.
- `webhookPrefixes`: a camp webhook must start with one of these (case-insensitive).
- `unplaceOnRelocate`: true = when a camp moves, every piece except the flag is unplaced (kept, ready to place again); false = pieces stay where they were.
- `stashBlacklist`: items never accepted into the camp stash.

**Ranks** (`Config.Ranks`): listed lowest first. The leader is implicit and passes every check.

**Permissions** (`Config.Permissions`): the minimum rank for each action, using a rank id or `'leader'` (leader only). `ledger` controls whether the Ledger menu is shown at all; `stashOpen` also controls the stash prompt.

**Invites** (`Config.Invites.hours`): how long an invite stays valid.

**Tax** (`Config.Tax`)

- `amount`: tax due each tax time, paid from the tax ledger.
- `ledgerCap`: maximum the tax ledger can hold.
- `checkMembers`, `minMembers`: when on, a camp with fewer members is also shut down at tax time.
- `monthly`: tax time on one day of the month at `hour:minute` (server clock).
- `fourDays`: used only when `monthly` is off; tax time on each listed day of the month.
- `warnMinutesBefore`: the leader is warned (letter and notice) this many minutes before tax time.
- `cronName`: row name in `cron_state` that makes sure a tax run happens only once per day, even across restarts.
- `letterFrom`: sender name of tax letters.

**Raids** (`Config.Raids`)

- `cooldownStarts`: raid cooldown for a camp, in camp days (resource starts). With 4 restarts a day, 12 = 3 days.
- `membersOnly`: the raider must be in a camp.
- `minDefenders`: target camp members that must be online.
- `minRiders`: posse riders that must be online (clamped to pup-ui's maximum posse size).
- `prepMinutes`, `lockpickMinutes`, `lootMinutes`: length of each raid phase.
- `lowSeconds`: the countdown turns red below this.
- `leaveDistance`: a raider further than this from the camp drops out.
- `pickDistance`: the lockpick is accepted within this of the flag.
- `lockpickItem`: used up on every attempt, success or not.
- `alertSprite`, `alertExtraMin`: defender alert blip; it is removed after prep + loot + this many minutes at the latest.
- `resendSeconds`: how often the countdown is sent to the crew.
- `safeCrackDifficulty`, `minigameTimeoutSec`: pup-minigames safe-crack settings.

**Hunting wagon** (`Config.HuntingWagon`): `price` to buy it for the camp, `maxEntries` per character stash, wagon `model` hash, `nearDistance` to use it, `stashCooldown` (seconds; every attempt counts) and `pendingTimeout` (seconds for a take-out to be reported).

**Economy** (`Config.Economy`)

- Every `stockEveryMin` minutes, a camp with materials and at least one supply converts up to `perCycle` materials into stock (capped at `stockCap`) and loses `drainPerCycle` supplies.
- `suppliesPerStock`: the trapper warns about low supplies below `perCycle` x this.
- `supplyPrice`: price of one supply at the trapper.
- `randomPrice`, `priceMin`, `priceMax`, `fixedPrice`: price paid per stock piece on a delivery (random between min and max, or fixed).
- `perkSupply`, `perkSale`, `xpSupply`, `xpDelivery`: pup-perks keys.

**Missions** (`Config.Missions`)

- `blipSprite`, `enemyBlips`: mission and enemy blips.
- `arriveDistance`: distance at which the player counts as arrived; camps cannot be founded within this of a mission region anchor.
- `leaveDistance`: a run fails when the player gets further than this.
- `supplyCooldownMin`, `deliveryCooldownMin`: per-camp cooldowns.
- `returnMin`: a mission in use returns to its pool after this many minutes at the latest.
- `sizes`: stock a delivery of each size needs and carries. Small, medium and large go to the nearest, second-nearest and third-nearest region.
- `wagonModel`: delivery wagon.
- `maxRunHours`: runs (and listed supply wagons) older than this are dropped.
- `acceptRadius`: the server requires the reporting player to be this close to the mission spot.
- `handInDistance`: supply wagon to a placed trapper.
- `posseBlipMin`: minutes posse members see a delivery's blips.
- `wagonListSeconds`: how long the client waits for a wagon to be networked.

**Beer** (`Config.Beer`): `drunkAt` (exactly this many beers: light effect), `strongAt` (exactly this many: stronger), `hallucinateAbove` (above this: hallucination), `durationMin` (effect length in minutes), `decayMin` (the counter drops by one this often, in minutes) and `stats` given per beer.

**Poison** (`Config.Poison`)

- `tickSeconds`: length of one poison tick.
- `effectAfter`, `walkAfter`, `damageAfter`: ticks until the screen effect, the sick walk and health damage start.
- `healthDamage`, `damageDivisor`, `healthFloor`: each tick takes max health / `damageDivisor`, never below `healthFloor`.
- `cureOnDeath`: dying cures the poison.
- `cureItems`, `snakeWeapon`, `snakeModels`: cure items and what counts as a snake bite.
- `persistRestart`: true = poison is also kept across a server restart (server KVP); false = it survives a relog only.

**Pelts** (`Config.Pelts`): `maxRecords` (client pelt records kept), `forgetMin` (minutes before a pelt record is forgotten, client and server), `skinRange` (the skinned carcass must be this close to the player), `peltRange` (the new pelt object must be this close), `maxPerChar` (registered pelts one character may hold at once).

**Butchers** (`Config.Butchers`)

- `rewardItems`: give the `items` listed in `config/animals.lua` when a whole carcass is sold.
- `maxHorsePelts`: pelts a horse can carry, used for the horse-pelt budget.
- `saleCooldown`: seconds between sales per player.
- `range`, `bodyRange`: the server requires the player within `range` of the butcher and the body within `bodyRange` of the player.
- `resaleMemory`: seconds a network id cannot be sold again.
- `budgetRefill`: seconds for the horse-pelt budget to refill.
- `sellDistance`, `mountDistance`, `donateMountDistance`: client prompt distances.
- `npcModel`, `spawnDistance`, `blipSprite`: butcher NPC and blip.

**Stews** (`Config.Stews`): one entry per recipe. `spoilMin` is how many minutes a cooked pot lasts (also across restarts). `stats` is added to hunger, thirst, metabolism and the six core values. `ingredients` lists `{ item, count }`. Example:

```lua
{ name = 'Rabbit Stew', spoilMin = 15, stats = 20,
  ingredients = { { 'water', 5 }, { 'game', 3 }, { 'potato', 2 } } },
```

**Ingredient labels** (`Config.IngredientLabels`): display names for stew ingredients.

**Anim** and **Effects**: scenarios, animations, props and screen effects the client plays, referenced by game name.

**Logs** (`Config.Logs`): `enabled`, `campWebhooks` (leaders may connect their own channel), `senderName`, colours and the `categories` that are logged. Camp logs go to the camp's own channel and the staff mirror; raid and butcher logs go only to their own channels (set in `server/config.lua`).

### config/furniture.lua

One entry per piece, keyed by the inventory item that is used up when the piece is added:

- `model`: game model or prop-set name (hashed at runtime), or a hash number.
- `label`: name shown to players.
- `kind`: `'prop'` (one object) or `'set'` (a game prop set; sets always use `use = 'none'`).
- `use`: `none`, `storage`, `wardrobe`, `stable`, `stew`, `trapper`, `beerbox` or `waterbarrel`.
- `slots`: storage size, for storage pieces only. The camp uses its largest storage piece.
- `stockHint`: informational only.

```lua
['mychest'] = { model = 's_lootablebedchest', label = 'My Chest', kind = 'prop', use = 'storage', slots = 800 },
```

Add a matching item row to the `items` table as well.

### config/animals.lua

One line per animal, or per animal outfit:

- `label`: name shown to players.
- `model`: ped model name (`'a_c_boar_01'`) or its hash number.
- `outfit`: `'any'` matches every outfit of that model; a number matches only that outfit hash. A row with an exact outfit wins over the `'any'` row of the same model.
- `big`: true = a large carcass/pelt that cannot be stowed on a horse.
- `price`: dollars per pelt quality, `{ poor = ..., good = ..., perfect = ... }`. A whole carcass always pays the good price; an unknown quality pays the poor price.
- `quality` (optional): the game's pelt-quality hashes for each grade. Leave out a grade, or the whole field, if you do not know it.
- `items` (optional): reward items when a whole carcass is sold and `Config.Butchers.rewardItems` is on, e.g. `items = { { name = 'item_name', count = 1 } }`.

```lua
{ label = ' Wolf', model = 'a_c_wolf', outfit = 'any', big = false, price = { poor = 1.0, good = 2.0, perfect = 3.0 } },
```

Four values in the table are outside the 32-bit hash range and can never match (the Bear, Black Bear and Cougar models and the Coastal Owl outfit). Correct them if you know the right hashes. The block at the bottom of the file converts the rows for the code and needs no editing.

### config/missions.lua

Missions are grouped by region (`val`, `sd`, `arma`, `bw`, `rhodes`, `annes`, `straw`, `snow`, `tw`). A camp gets supply missions from the region whose anchor point is nearest. To add a mission, copy a whole `{ spot = ..., ... }` block inside the region you want and change the values.

- `CampMissionRegions`: region anchor points `{ x, y, z }`. Camps cannot be founded within `Config.Missions.arriveDistance` of one.
- `CampSupplyMissions`: the camp rides out to a supply wagon, kills the guards and brings it home.
  - `spot`: where the supply wagon waits.
  - `supplies`: `{ min = 25, max = 50 }`. The wagon is worth a random whole number of supplies between min and max, rolled once per resource start, not on every run.
  - `items`: extra reward items, `{ name = 'item_name', label = 'shown name', count = 5 }`.
  - `enemies`: the guards, one line each.
- `CampDeliveryMissions`: the camp drives a wagon to a drop-off point and fights off an ambush.
  - `spot`: the drop-off point.
  - `enemies`: the ambushers, one line each.

Enemy line:

```lua
{ x = 1.0, y = 2.0, z = 3.0, weapon = 'WEAPON_REPEATER_CARBINE', ped = 'g_m_m_unibanditos_01', horse = 'A_C_Horse_Turkoman_Gold' },
```

`x, y, z` is where the enemy spawns; a horse spawns 1.5 m to the side and the enemy mounts it. `weapon` is the weapon given, `ped` the ped model, and `horse` a horse model name or `false` to fight on foot. Add as many lines as you like. The block at the bottom of the file converts the rows for the code and needs no editing.

### config/places.lua

`CampButchers`: one entry per public butcher. `name` is shown to players, `pos` is where selling works (and the blip), `heading` is the NPC heading, and `npc` is the NPC position when it differs from `pos`.

### config/integrations.lua

Adapters for the optional resources. Every adapter runs inside `pcall` and only when its resource is started, so a stopped or renamed resource never breaks a camp; a failing export is reported once in the console. If one of your resources names its exports differently, change the adapter here; nothing else needs editing.

- The pup-misc Eco Boost bonus only counts when the place name contains "Butcher" or "Trapper".
- `pup_postoffice` `SendSystemMail` runs awaited queries, so it is called from a thread.
- When the `lockpick` resource is not running, raids use the pup-minigames safe crack.
- The `poker` resource has no API for adding a table from another resource, so a camp poker set is decoration only (a console warning says so once).
- When vorp_lib cannot be used, placement falls back to pup-ui.

## For developers

### Server exports

| Export | Returns | Use |
|---|---|---|
| `AdminList()` | `{ list = { camp, ... }, now }` | vorp_admin Camps page: every camp with id, name, coords, leader, members, cash, tax, storage, items, furniture count, repo and webhook flags |
| `AdminAction(action, campId, data)` | `ok, message` | Actions: `setledger`, `wipeledger`, `settax`, `wipetax`, `rename`, `setlimit`, `removeitem`, `wipestash`, `removemember`, `addmember`, `setleader`, `repo`, `unrepo`, `delete`. `data` carries `value`, `item` or `charid`. vorp_admin checks its own permissions (`manage_camps` / `delete_camp`) first. |
| `AdminOpenStash(src, campId)` | `true` or `false, reason` | Opens the camp's real stash panel for a staff member, from anywhere, with the leader's controls. Checks `manage_camps` again here and on every take, deposit and reorder. |
| `BoxStashItems(src, clanId)` | list of `{ name, label, count, type, metadata, id, limit }` or nil | Storage boxes: read the stash (needs take permission) |
| `BoxStashTake(src, clanId, entryId, name, metadata, amount)` | `true, list` or `false` | Take from the stash; `entryId` from `BoxStashItems` is matched first, then name + metadata |
| `BoxStashReturn(clanId, name, metadata, amount, label?)` | boolean | Put items back (label is looked up when omitted) |
| `BoxStashPut(src, clanId, items)` | boolean | Deposit `{ name, label, count, metadata }` items; weapons, blacklisted items and over-capacity are refused |

### Events

- `pup_camps:stashtaken_log` (server, local): `(src, clanId, itemName, itemLabel, amount)`. Fire after moving stash items into a storage box so the camp log records it.
- `pup_camps:washedface` (client, local): fired after the player washes at a water barrel.
- `pup_camps:MoveToClan`, `pup_camps:TakeFromClan`, `pup_camps:SortClanInventory`, `pup_camps:ChangeOrderClan` (server, net): sent by the vorp_inventory clan panel.
- Listens to `vorp:SelectedCharacter`, `pup:closeinv`, `pup-scene:stopscene`, `pup-ui:posse:serverChanged` and the pup-ui menu, input and placement events.

All other client/server traffic goes through `pup_camps:sv:req` and `pup_camps:cl:*` and is internal.

### Security model

The server decides everything; nothing the client sends is trusted beyond its shape. Butcher and trapper prices: a whole carcass is identified by its own entity model and paid that row's good price. A pelt is sellable only once registered: when a pelt appears in a player's hands, the client names the carcass it came from, and the server checks that carcass (a real dead ped of a listed model, right beside the player, never used for a pelt before) and the pelt object, then stores the pelt's price itself. Sales, donations, horse stows and the wagon stash use only that record. Horse pelts are paid from the server's own tally of registered pelts.

## License

See LICENSE.
