# pup_homestead

Homestead farming for RedM / VORP. Players plant seeds anywhere outside town, then water, feed and trim their crops and harvest them, and track it all in the Almanac.

## Features

**Growing**
- 35 crops ready to use, from vegetables and herbs to fruit trees, tea, coffee and tobacco. Add your own in `config/crops.lua`.
- Use a seed (with a hoe in your satchel) and plant it with a short skill bar. Growth stops at the crop's watering point until someone waters it.
- **Fertilise** to skip ahead to the watering point and get a bigger harvest. **Trim** for a bigger harvest too.
- Failing the skill bar hurts the plant; a plant at 0 health dies. Unhealthy plants give less.
- Optional **withering**: ripe crops left in the ground too long rot.
- Plants survive restarts, up to a limit you set.

**Water**
- Fill empty cans at a pump (clean water), in a river (dirty water), or from a water wagon.
- Water wagons (oil wagons and the water cart) store the cans you pour in, and fill up by themselves when parked in a river.
- **Rain waters every dry plant.** The server checks weathersync itself.

**Bonuses**
- **pup-perks** farming perks: speed, plant limits, yield, and radius watering or feeding.
- **Farm jobs** in `Config.JobBonus`: one can waters the bed around it, one bag feeds it.

**The Almanac** (`/farm`, a pup-ui menu)
- **My Plots:** every plant you have (ready ones first), its state, time left, distance and health. Choose one to get a GPS route to it.
- **Crop Guide:** each crop's seeds, time, water point, yield and job lock, plus your own bonuses.
- **Ledger:** what you have planted and harvested, by crop.

**Fair play**
- Every action is checked on the server: items, reach, ownership, limits and spacing. The client only asks.
- You need a full can in hand to water, and you must be next to a plant to touch it.
- `Config.Plants.others` sets what other people may do to your plants.

## Requirements

- Required: `vorp_core`, `vorp_inventory`, `oxmysql`, `pup-ui`
- Required unless the skill bar is off (`Config.Minigame.enabled = false`): `pup-minigames`
- Optional (found automatically):
  - `weathersync`: rain watering
  - `pup-perks`: farming perks, plus XP for planting, watering, trimming and harvesting
  - `pup-gangs`: the Gang Crop
  - `pup-misc`: the harvest goes into a farming pack if the player carries one
  - `vorp_admin`: the staff Farms page
- Some crop props (Hemp, Gang Crop) need the `[maps]/prop_weed` resource.

## Installation

1. Put `pup_homestead` in your resources folder.
2. Run `sql/install.sql`. It creates `homestead_plants` and `homestead_stats` and adds the 84 items (seeds, produce, fertilisers, cans). It is safe to run more than once. `gang_seed` and `gang_drug` must match `pup-gangs/config/drugs.lua`.
3. Make sure the tools exist in `vorp_inventory`: `hoe`, `planttrimmer`, `wateringcan_empty`, `wateringcan`, `wateringcan_dirtywater`. Item images are read from `nui://vorp_inventory/html/img/items/`.
4. Optional: set `Webhooks.admin` in `server/config.lua` to a Discord webhook for the farm log (planted, harvested, pulled up). `''` turns it off.
5. Add `ensure pup_homestead` to `server.cfg` after its requirements (and after `pup-minigames` and any optional resources you use).

If an older server still has the `playerfarms` table, every plant in it is copied over once on the first start, keeping its id and progress. `playerfarms` is only read, never changed.

## Commands

| Command | Who | What |
|---|---|---|
| `/farm` | everyone | open the Almanac (command name: `Config.General.almanacCommand`) |
| `/cbucket` | everyone | put away the can in your hand (`Config.General.dropCanCommand`) |

Staff manage plants from the Farms page in the `vorp_admin` staff panel. It needs the `manage.farms` permission on their role.

## Configuration

| File | What is in it |
|---|---|
| `config/main.lua` | keys, items, plant limits, what others may do, distances, water, skill bar, plant health, job bonuses |
| `config/crops.lua` | the crops and their shared defaults |
| `config/locale.lua` | every word players see; `%s` / `%d` are filled in by the script |

### config/main.lua

**Config.General**
- `almanacCommand`: the command that opens the Almanac (your plots, the crop guide, your ledger).
- `dropCanCommand`: the command that puts away the can you are holding.
- `imagePath`: where item images are loaded from.

**Config.Keys**: prompt keys. Change the hash only. Defaults: harvest G, water E, trim F, fertilise LALT, remove BACKSPACE (hold), pump G at a water pump, `wagonFill` G (pour your can into a water wagon), `wagonDraw` ENTER (fill an empty can from a water wagon).

**Config.Items**: item names, which must exist in vorp_inventory.
- `hoe`: needed to plant; it is kept.
- `trimmer`: needed to trim; it is kept.
- `emptyCan`: the empty watering can.
- `cleanWaterCan`: the can you get from a pump or a water wagon.
- `dirtyWaterCan`: the can you get from a river.
- `wateringCans`: the full cans that can be used to water.

**Config.Planting**
- `maxPlantsTotal`: most plants per character, all crops together. A perk or job `limit` adds `limit x 2` to this.
- `minSpacing`: metres between plants.
- `blockedTowns`: towns where planting is not allowed.

**Config.Plants**
- `others`: what other people may do to YOUR plants (`water`, `fertilise`, `trim`, `harvest`, `check`, `remove`). The owner can always do everything. By default others can do everything except pull plants up.
- `reach`: metres; how close you must be to work a plant.
- `renderDistance`: metres; props spawn inside this.
- `syncDistance`: metres; the server sends you the plants inside this.
- `syncSeconds`: how often (seconds) your client asks for nearby plants.
- `blips`: show your own plants on the map; `blipSprite` is the blip icon.
- `lifetimeRestarts`: a plant is pulled up after surviving this many restarts (the oldest go first).
- `witherMinutes`: a ripe plant left this many minutes rots. `0` = never.
- `status`: how a plant's state is shown.
  - `show`: `'drawtext'` = coloured text over every plant near you (the prompt title then shows only the crop); `'prompt'` = the state only in the prompt title at the plant; `'both'` = both.
  - `distance`: metres; the coloured text shows inside this. `height`: metres above the plant's spot. `scale`: text size.
  - `colours` (`{ red, green, blue }`): `growing` white, `thirsty` red (needs water, growth has stopped), `watered` blue (watered and growing), `ready` gold (ready to harvest).

**Config.Watering**
- `rain`: rain waters every dry plant. Needs weathersync; checked by the server.
- `rainTypes`: the weathersync weather types that count as rain.
- `pumpModel`: the water pump model hash.
- `wagons`: water wagons as `model = how many cans they hold`. The stored water is kept while the wagon exists. Example: `cart05 = 40`.

**Config.Fertiliser**
- `bonus`: extra produce per reward on a fed plant. A crop's own `fertBonus` wins over this.

**Config.Minigame** (pup-minigames)
- `enabled`: use the skill bar. Off = every task succeeds without one.
- `ragdollOnFail`: knock the player over on a failed skill bar.

**Config.MinigameTuning**: skill bar shape, scaled by the crop's difficulty `d`. Target area = `baseArea - d x areaLoss`, never below `minArea`. Marker speed = `baseSpeed + d x speedGain`, never above `maxSpeed`. `perfectArea` is the size of the perfect zone.

**Config.PlantHealth** (a failed skill bar hurts the plant)
- `lossOnFail`: health lost per failed task.
- `unhealthyAt`: at or below this health the harvest is smaller...
- `unhealthyLoss`: ...by this much per reward (never below 1).
- `hardAfterFail`: the skill bar difficulty after a failure (higher = harder).

**Config.JobBonus** (stacks with pup-perks farming perks; the best of job and perk is used)
- `speedFloor`: tasks never get faster than this share of their base time (`0.25` = 25%).
- `jobs`: job name = bonus table. Each bonus table has:
  - `limit`: extra plants per crop (and `limit x 2` in total).
  - `speed`: task time multiplier (`0.55` = 55% of the normal time).
  - `radius`: one can waters every plant this many metres around.
  - `fertRadius`: one bag feeds every plant this many metres around (same fertiliser only).

Adding a farm job: `myfarm = { limit = 10, speed = 0.55, radius = 3.0, fertRadius = 3.0 },` inside `jobs`, or reuse the `farmhand` table.

### config/crops.lua

`Config.CropDefaults` holds the values used when a crop leaves a field out. `Config.Crops` lists every crop players can grow.

The key (the name in brackets) is saved on every planted plant: renaming a crop pulls up the plants of it already in the ground.

| Field | Meaning |
|---|---|
| `prop` | model shown in the ground |
| `seed` | seed item that plants it |
| `seeds` | seeds used per plant |
| `yield` | what a harvest gives: a list of `{ item = inventory item, label = shown name, count = how many }` |
| `grow` | minutes to grow |
| `waterAt` | growth stops this many minutes from the end until the plant is watered |
| `max` | most of this crop one character may have growing (perks and farm jobs add more) |
| `sink` | metres to push the prop into the ground (raise it if the plant floats) |
| `fertiliser` | item that feeds it (skips the wait up to the watering point and adds produce) |
| `fertBonus` | optional: extra produce when fed (otherwise `Config.Fertiliser.bonus`) |
| `trimBonus` | extra produce per reward when trimmed |
| `health` | starting health |
| `difficulty` | skill bar difficulty (higher = harder) |
| `jobs` | `nil` = anyone, or a list like `{ 'emfarm', 'rdfarm' }` |
| `gang` | `true` = pup-gangs handles the seed and the harvest |

The Gang Crop's key, seed and product must match `pup-gangs/config/drugs.lua`, and its prop comes from the `[maps]/prop_weed` resource.

Adding a crop: copy any block, give it a new name in brackets and change the values, then add its seed and produce items to the `items` table. For example (the item names here are placeholders):

```lua
['My Ginseng'] = {
    prop       = 'ginseng_p',
    seed       = 'My_Ginseng_Seed',
    seeds      = 2,
    yield      = { { item = 'My_Ginseng', label = 'My Ginseng', count = 5 } },
    grow       = 30,
    waterAt    = 15,
    max        = 10,
    sink       = 0.2,
    fertiliser = 'fertilizer',
    trimBonus  = 2,
    health     = 100,
    difficulty = 5,
    jobs       = nil,
},
```

## For developers

Server exports:

```lua
exports.pup_homestead:GetPlants(charid)   -- { { id, crop, x, y, z, left, watered, fert, trim, health }, ... }
exports.pup_homestead:RemovePlant(id)     -- true if the plant was there
exports.pup_homestead:IsRaining()         -- the rain check the farm uses
```

`AdminList()` and `AdminAction(action, data)` are used by the vorp_admin Farms page (`action` = `'remove'` with `data.id`, or `'clearchar'` with `data.charid`; returns `ok, message`).

Database:

| Table | Holds |
|---|---|
| `homestead_plants` | one row per plant in the ground |
| `homestead_stats` | planted / harvested / gathered per character and crop |

State changes (water, feed, trim, health) are written as they happen. The growth countdown ticks in memory once a minute and is written every 5 minutes, so a crash loses minutes at most.

## License

GPL-3.0-or-later, see LICENSE.
