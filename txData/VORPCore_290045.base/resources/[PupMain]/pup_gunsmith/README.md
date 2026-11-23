# pup_gunsmith

The gunsmith for a RedM server on VORP Core: gun store counters, weapon and ammo crafting,
usable ammo boxes, and a customization bench where players fit parts to their guns with a live
3D preview, save looks as presets, repair and temper them.

## Features

- **Gun store counters**: fixed stock at fixed prices, shown on pup-ui's shop screen. Prices and
  stock are checked on the server.
- **Crafting stations**: weapons and ammo boxes made from materials, with a pup-minigames skill bar
  and gunsmith experience. Stations and recipes live in the database and can be edited live from
  vorp_admin or with the `/weaponcraftloc` commands, with no restart.
- **Crafting box**: crafted ammo can go into a personal storage box opened from the station.
- **Optional custom text** on crafted weapons (serial, label, description).
- **Ammo boxes**: using a box item loads rounds onto the belt, up to the belt cap.
- **Customization bench**: lay a carried gun on the bench, turn it under a camera, fit parts with a
  live preview that nearby players also see, pay, and save looks as presets.
- **Workshop tab**: weapon condition, repair, and tier upgrades ("tempering") that make a weapon
  wear more slowly.
- **Refit on equip**: saved parts are put back on the gun in hand whenever vorp_inventory equips it.
- **Staff Discord log** of crafting attempts, repairs and tier upgrades.

## Requirements

- `vorp_core`
- `vorp_inventory`, a build that provides the weapon component, condition, tier and ammo belt cap
  exports used here (`getWeaponComponents`, `addWeaponComponents`, `subWeaponComponents`,
  `GetWeaponStatusById`, `RepairWeaponById`, `GetWeaponTier`, `SetWeaponTier`,
  `IsWeaponDegradationEnabled`, `getMaxAmmoBelt`, `setMaxAmmoBeltBulk`) and that sends
  `pup_gunsmith:weaponused` when a weapon is equipped
- `oxmysql` (MariaDB 10.0.2 or newer for the install script)
- `pup-ui` (shop screen, app screen, input forms, list menus, theme)
- `pup-minigames` (skill bar)
- OneSync, so the server can check player positions
- Optional: `vorp_admin` (recipe and station editing, and the permission for the admin commands)
- Optional: `pup-perks` (awards "gunsmith" perk XP on every successful craft)

## Installation

1. Run `sql/install.sql` once. It is safe to run again. It creates `weapon_recipes`,
   `weapon_craft_locations` and `gunsmith_presets`, adds `characters.gunsmith` and
   `loadout.used2`, `loadout.dropped`, `loadout.comps` and `loadout.tier` when they are missing,
   and adds the crafting materials and ammo box items (existing items are left alone).
2. Restart vorp_inventory after adding items: it reads the items table only when it starts.
3. Item pictures are read from `vorp_inventory/html/img/items/<item>.png`. Weapons in the shop and
   crafting lists use the lower-case weapon name, for example `weapon_revolver_cattleman.png`.
4. Set the staff Discord webhook in `Webhooks.admin` in `server/config.lua` (server only, never sent
   to clients). Leave it empty to switch the log off.
5. Add `ensure pup_gunsmith` to your server.cfg after `oxmysql`, `vorp_core`, `vorp_inventory`,
   `pup-ui` and `pup-minigames`.

On first start the recipe and station tables are filled from `config/seeds.lua` if they are empty.
After that the database is the live list.

## Commands

| Command | Who | What |
|---|---|---|
| `/weaponcraftloc <name> [job1,job2,...]` | Admins (vorp_admin `manage_crafting`), in game only | Saves a crafting station at your position. Creates it, or moves an existing one. Without jobs, an existing station keeps its job list. |
| `/weaponcraftloc_off <name>` | Admins, or the server console | Switches a station off. |
| `/weaponcraftloc_on <name>` | Admins, or the server console | Switches a station on. |
| `/weaponcraftdebug` | Anyone (client), only with `Config.Debug.general = true` | Prints the crafting stations your client knows to the F8 console. |

## Configuration

All player-facing wording, including the bench page's, is in `locale/en.lua`. Keep the `%s` and
`%d` placeholders when translating.

### config/main.lua

**Config.Debug**: console traces, all `false` in normal running.

- `general`: step-by-step server logs and the seeding message.
- `components`: part fitting traces (client and server), including a per-part check after each refit.
- `ammo`: ammo box traces (belt, ceiling, box size, outcome).

**General**

- `InteractKey`: the prompt key (default `0x760A9C6F`, G).
- `PromptDistance`: how close, in metres, the player must be for a prompt to show.
- `JobOnly`: when `true`, benches and crafting stations need one of their listed jobs and the
  minimum grade below. When `false`, anyone may use them.

**Config.Craft** (crafting stations)

- `minGrade`: minimum job grade to use a station.
- `reach`: server-side distance check, in metres.
- `scenario`, `scenarioMs`: the animation played while crafting, and how long (ms).
- `failConsumes`: a lost skill bar still uses up the materials.
- `useBox`: crafted ammo goes into the personal crafting box instead of the satchel. If the box
  refuses it, the satchel is tried; with no room there either, the materials are handed back.
- `boxBase`: the crafting box id is `boxBase + character id`. vorp_inventory reserves
  12000000-12999999 for these.
- `ticketSeconds`: how long a started craft stays valid before it must be finished.
- `maxAmount`: most ammo boxes per craft (weapons are always one at a time).
- `perksAward`: ask pup-perks for its "gunsmith" XP on every win.
- `custom`: switch on player-chosen `serial`, `label` and `description` text on crafted weapons.
- `customMax`: the longest each of those may be, in characters.
- `noSerial`: weapons that never carry a serial number (compared ignoring case).

**Config.SkillBar** (pup-minigames skill bar)

A recipe's `difficulty` becomes a level: `(difficulty - 2000) / 1000`, so 2000 is level 0 and 3000
is level 1 (values of 20 or less are used as the level directly).

- The target zone is `baseZone - zoneLossPerLvl * level`, never below `minZone`.
- The speed is `baseSpeed + speedPerLvl * level`, never above `maxSpeed`.
- `perfectZone`: size of the perfect area.
- `iconWeapon`, `iconAmmo`: Font Awesome icons shown on the bar.

A skill bar that never reports back within two minutes counts as lost.

**Config.Bench** (customization bench)

- `minGrade`, `reach` (metres): grade needed and distance allowed at the bench.
- `scenario`: the animation played while at the bench.
- `partCash`, `partGold`: one price for every part. `nil` uses the prices in
  `shared/parts.lua` ($10 each as shipped); `0` makes parts free.
- `workMs`: how long fitting parts takes (ms).
- `watchRange`: players this close (metres) to the bench see the gun and its parts.
- `watchRefresh`: ms between watcher refreshes, for players walking up or away.
- `presetLimit`: presets per character, across all guns.
- `maxParts`: most part categories stored on one gun.
- `camera`: `fov`; `easeIn`/`easeOut` (ms); `startElev`, `minElev`, `maxElev` (camera height
  angle, degrees); `zoomMin`/`zoomMax`; `turnSpeed` (deg/s for A/D and Q/E); `tiltSpeed` (deg/s for
  W/S); `glide` (each frame the camera covers `min(1, frame time * glide)` of the remaining
  distance, so higher is snappier).
- `light`: colour (`r`, `g`, `b`), `height` above the gun, `range` and `intensity` of the bench light.

**Config.Refit** (putting saved parts back on the gun in hand)

- `waitForWeaponMs`: how long to wait for the player to actually hold the weapon (ms).
- `pollMs`: how often to check meanwhile (ms).
- `settleMs`: pause between clearing the slots and fitting the parts (ms).
- `gripTint`: the grip tint has to be added to the game's own inventory under the weapon's grip.
  Switch this off if it ever misbehaves; the other parts are unaffected.
- `gripTintSkipTag`: an item tag that marks tints the game refuses on a grip (`nil` = no tag check).
- `tintSlots`: the slot the grip tint goes into, per family (shotguns count as long arms here).
- `inventorySlots`: how the tint's parents are found in the game inventory
  (character, then weapon, then grip). Only change these if grip tints do not apply.

**Config.Repair**

- `kitItem`: not used here; the repair kit item is handled by vorp_inventory.
- `fee`: dollars charged for a bench repair; `0` or `nil` means free.
- `workMs`: how long a repair takes (ms).
- `scenario`: not used; the bench keeps its own scenario.

**Config.Shop** (gun store counters)

- `enabled`: switch all counters on or off.
- `reach`: server-side distance check, in metres.
- `maxAmount`: most ammo boxes in one purchase.
- `blipSprite`, `blipScale`: map blip for counters that have `blip = true`.
- `confirmTimeoutMs`: how long the buy confirmation stays open before it counts as No (ms).

**Config.Security**

- `kickLegacyPayment`: a client that fires the old `pup_gunsmith:checkmoney` payment event is
  kicked. Other retired events are only logged.

**Config.ItemImage**: the item picture path; `%s` is the item name.

### config/locations.lua (customization benches)

Each entry in `Config.Benches`:

- `id`: unique name of the bench (shown when there is no `label`).
- `stand`: where the player stands (`vector3`).
- `gun`: where the gun is laid (`vector3`), usually about 0.7 m from `stand` and 0.3 m up.
- `jobs`: jobs that may use it.
- `label`: optional display name.

```lua
{ id = 'Valentine', stand = vector3(-277.22, 778.922, 119.50), gun = vector3(-276.47, 778.922, 119.80), jobs = { 'vtgunsmith' } },
```

### config/shop.lua (gun store counters)

Each entry in `Config.ShopCounters`: `id` (unique), `name` (shown on the prompt and screen),
`coords`, `blip` (`true` for a map blip) and an optional `stock` list. A counter without its own
`stock` sells `Config.ShopStock`.

Each stock entry:

- `kind`: `'weapon'` or `'ammo'`.
- `group`: the heading it is listed under.
- `label`: the name shown. `kind`, `group` and `label` together must be unique on a counter.
- `weapon`: the game weapon name (for `kind = 'weapon'`).
- `item`: the ammo box item (for `kind = 'ammo'`).
- `price`: dollars; for ammo this is per box.

```lua
{ kind = 'weapon', group = 'Starter Weapons', label = 'Bow', weapon = 'WEAPON_BOW', price = 9 },
{ kind = 'ammo',   group = 'Starter Ammo', label = 'Rifle Ammo Normal', item = 'ammoriflenormal', price = 1.5 },
```

### config/tiers.lua (tempering)

- `max`: highest tier.
- `slowPerTier`: how much each tier slows wear (0.10 = 10% per tier). It must match
  vorp_inventory's own client value (`SLOW_PER_TIER`).
- `workMs`: how long an upgrade takes (ms).
- `scenario`: not used; the bench keeps its own scenario.
- `costs`: `[tier reached] = { cash = dollars, materials = { { item, label, amount }, ... } }`.
  A tier with no entry is free.

### config/names.lua

- `Config.WeaponNames`: the label shown for a gun that has none of its own.
- `Config.CategoryNames`: the names of the part-category rows on the bench.

### config/seeds.lua (first-start recipes and stations)

These rows are copied into the database only when the matching table is empty. After that the
database is the live list, edited from vorp_admin; changing this file later does nothing on a
server that has already been seeded. Order matters: on a fresh seed the recipes get database ids
in the order written.

**Seeds.Stations**: `name`, `x`, `y`, `z` and `jobs` for each crafting station.

**JobSets**: named job lists that recipes refer to in `jobs`. `gunsmiths_ammo` has the same jobs
as `gunsmiths` in a different order. `none` lists no jobs (with `jobOnly = true` nobody can make
it); `nobody` lists a job no one has.

**MaterialLabels**: the name shown for each material item. A material can override it with
`label = ...`.

**Weapon recipes** (`WeaponRecipes`):

- `category`: tab the recipe is listed under ('Melee', 'Rifles', ...).
- `name`: name shown to players; must be unique inside its category.
- `weapon`: the game weapon it makes, e.g. `'WEAPON_RIFLE_SPRINGFIELD'`.
- `xpGained`: crafting XP earned per weapon made (default 25).
- `xpNeeded`: crafting XP the player must already have (default 0).
- `difficulty`: skill bar difficulty: 2000 = easy, 3000 = normal, each +1000 is one level harder
  (default 3000).
- `craftable`: `true` = can be made; `false` = locked for everyone.
- `jobOnly`: `true` = only the jobs in `jobs` can make it (default `true`).
- `jobs`: a job set name from `JobSets`, or a list like `{ 'vtgunsmith', 'rdgunsmith' }`.
- `materials`: what one weapon costs, in order, as `{ item = 'ironbar', amount = 3 }`. Add
  `label = 'Some Name'` only to show a different name than `MaterialLabels` gives.

```lua
{ category = 'Rifles', name = 'Springfield Rifle', weapon = 'WEAPON_RIFLE_SPRINGFIELD',
  xpGained = 50, xpNeeded = 500, jobs = 'gunsmiths',
  materials = { { item = 'riflebarrel', amount = 1 }, { item = 'riflestock', amount = 1 } } },
```

**Ammo recipes** (`AmmoRecipes`): the same fields as a weapon, without `weapon`, plus:

- `boxItem`: the inventory item the player gets (one box per craft).
- `ammoType`: the game ammo it loads, e.g. `'AMMO_REPEATER'`.
- `roundsPerBox`: rounds one box adds when used.
- `maxAmmo`: a box will not fill the player's ammo of this type above this (the belt cap).
- `weaponTypes`: one or two of `'repeater'`, `'revolver'`, `'rifle'`, `'sniper'`, `'shotgun'`,
  `'pistol'` or `'none'`.
- `forWeapons`: optional list of exact weapons, e.g. `BOWS` or `{ 'WEAPON_THROWN_TOMAHAWK' }`.

Ammo defaults: `xpGained` 1, `xpNeeded` 0, `difficulty` 3000, `jobOnly` true. Materials are per box.

```lua
{ category = 'Repeater', name = 'Repeater Ammo Normal', boxItem = 'ammorepeaternormal', ammoType = 'AMMO_REPEATER',
  roundsPerBox = 100, maxAmmo = 200, jobs = 'gunsmiths_ammo', weaponTypes = { 'repeater' },
  materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 } } },
```

Everything below the "Nothing to edit below" line turns these lists into database rows.

### shared/parts.lua (part catalogue)

`GunParts.models` lists the parts of each weapon model and `GunParts.families` the parts every gun
of a family can take (`SHORTARM`, `LONGARM`, `SHOTGUN`, `MELEE_BLADE`), each grouped by slot
(`GRIP`, `BARREL`, `WRAP_TINT`, ...).

```lua
GRIP = {
    { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP', 'Standard' },          -- { component, label }
    { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL', 'Pearl', cash = 25 },
},
FRAME_MATERIAL = {
    -- one part per number: COMPONENT_SHORTARM_FRAME_MATERIAL_1 .. _10, labelled Finish 1 .. Finish 10
    { range = 'COMPONENT_SHORTARM_FRAME_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
},
```

- A part costs `GunParts.price` (`cash = 10, gold = 0` as shipped) unless it sets its own `cash` /
  `gold`. All of these are ignored when `Config.Bench.partCash` / `partGold` are set.
- Parts show on the bench in the order written. The first `GRIP` of a model is its default grip.
- Component names are the game's own; the labels are this resource's.

## For developers

### Exports (server)

Used by vorp_admin's crafting editor:

| Export | Returns |
|---|---|
| `GetWeaponRecipesAdmin()` | Every recipe (enabled or not) with its fields and materials. |
| `GetWeaponCategories()` | `{ weapon = { ... }, ammo = { ... } }` category names. |
| `UpsertWeaponRecipe(form)` | Creates or updates a recipe; `true` on success. |
| `SetWeaponRecipeEnabled(id, enabled)` | `true` when the recipe exists and was switched. |
| `GetWeaponCraftLocations()` | Every station row (`name, x, y, z, job, enabled`). |
| `UpsertWeaponCraftLocation(name, x, y, z, jobs)` | The saved name, or `false, reason`. `jobs` is a list or comma string; `nil` keeps the stored list. |
| `SetWeaponCraftLocationEnabled(name, enabled)` | `true` when the station exists and was switched. |
| `DeleteWeaponCraftLocation(name)` | `true` when a station was deleted. |

All changes take effect at once and are pushed to every client.

### Events

| Event | Side | Sent by | Purpose |
|---|---|---|---|
| `pup_gunsmith:weaponused` (payload `{ type = 'item_weapon', id }`) | server (net) | vorp_inventory client | A weapon was equipped or restored at spawn; its saved parts are refitted. |
| `pup_gunsmith:applyDupeTint` | server (net) | vorp_inventory | Dual-wield equip; only traced. |
| `pup_gunsmith:registerWeapon` (weaponId) | server (local) | vorp_inventory | After a loadout insert; only traced. |
| `pup_gunsmith:removeallammo` | client (net) | vorp_inventory, vorp_admin | Weapon/ammo wipe: clears the ped's ammo and the character's stored ammo. |
| `pup_gunsmith:refit` (parts, weaponId, weaponHash) | client (net) | this resource | Fits a parts set to the weapon in the player's hands. |

Listened to from other resources: `vorp:SelectedCharacter` (ends any open screen and clears the
second-slot flag on the character's guns), the pup-ui `pup-ui:client:*` and `pup-ui:HideAllUI`
events, and `onResourceStart` for vorp_inventory (ammo boxes and belt caps are registered again).

Older network events of this resource are still registered but only log a warning; see
`Config.Security`.

## Credits

- Weapon and component names (`WEAPON_*`, `COMPONENT_*`) are Red Dead Redemption 2 game names,
  used so the game can find them. The part catalogue layout, part labels and weapon labels were
  written for this resource.
- Built on VORP Core and vorp_inventory, which it talks to through their exports and events.

## License

See LICENSE.
