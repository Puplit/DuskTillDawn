# pup_workbench

Crafting for RedM (VORP Core). Players craft at named stations, at world props such as campfires and stoves, from portable kits, or at a campfire they set down themselves; recipes live in the database and are edited live from vorp_admin's Crafting page.

Every screen is drawn by **pup-ui** (App panel, input dialog, progress bar). This resource ships no HTML, images, fonts or sounds; item pictures come from vorp_inventory's item image folder.

## Features

- **Craft prompt** (G) within 1.5 m of a named station or a station prop. Each prop model has its own label (Campfire, Stove, Furnace...).
- **Bench panel**: one tab per category with recipes here, plus Favourites, Pending, Crafting Box and Search. Category pages show experience, level, unlocked recipes and favourites, a search box and the chips *Can make now*, *Auto max* and *Remember amount*.
- **Recipe detail**: what it makes, what it needs (with have/need), tools that are kept, an amount stepper whose maximum counts tools as well as materials, Favourite, and *Craft with a description*.
- **Skill bar** (pup-minigames) before every craft, harder with the recipe's difficulty.
- **Timed crafting**: goods wait on the Pending shelf; collect one or all. Up to 5 running per character, each batch capped at 2 hours.
- **Crafting box**: a take-only personal inventory that receives finished goods so a long run never fills the satchel. It opens only where it was filled and is emptied when the resource starts.
- **Tool wear** for wrench, skinning knife, handsaw, straight razor and wood plane, with a "Condition = N" line on the tool.
- **Descriptions** written on crafted goods (with a recent list shared with vorp_inventory's description card) and a banned-word filter.
- **Per-category experience** in `characters.crafting`.
- **Access rules**: category job locks, XP requirement, job and grade locks, character and Steam locks, Discord locks. Players are sent only the recipes they may see.
- **Placeable campfire**: set it down and it becomes a bench; `/dc` picks it back up.
- **Discord log** of every craft and every security violation.
- **pup-perks** (optional): the Craftsman perk `craft_double` doubles goods; every craft awards the `craft` XP event.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- OneSync (the server's distance checks read player positions)
- `pup-minigames` (optional: the skill bar; without it every craft passes)
- `pup-perks` (optional: the Craftsman perk and crafting XP events)
- `vorp_admin` (optional: the Crafting page that edits recipes and stations)

## Installation

1. Run `sql/install.sql` (the resource also creates its tables, and the `characters.crafting` column, at start).
2. Set `webhooks.crafting` to a Discord webhook URL in `server/config.lua` (server only, never sent to players) if you want the log. Leave it empty to turn the log off.
3. `ensure pup_workbench` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui`.
4. Every item a recipe uses or gives must exist in vorp_inventory's `items` table, including the `campfire` placeable item and the tools listed in `Config.ToolWear.tools`. Items added to the table only load when vorp_inventory restarts; until then they cannot be given.

## Commands

| Command | Who | What |
|---|---|---|
| `/craftloc <name>` | VORP group `admin` | Save a station at your position, or move and re-enable one with that name |
| `/dc` | everyone | Pick your placed campfire back up (refused while your crafting box still holds goods) |

## Configuration

| File | Holds |
|---|---|
| `config/main.lua` | Prompt, server reach, skill bar, crafting scene, descriptions, crafting box, timed crafting, tool wear, placeables, banned towns, kits, station props, rules, log look |
| `config/categories.lua` | Categories in tab order |
| `config/stations.lua` | Seed stations |
| `locale/en.lua` | Every player-facing line |
| `server/config.lua` | The Discord webhook (server only) |

### `config/main.lua`

| Setting | Meaning |
|---|---|
| `Debug` | print refusals and other detail to the console |
| `Prompt.key` | control hash for the Craft prompt (G) |
| `Prompt.stationReach`, `Prompt.propReach` | metres (client): how close to a named station / a station prop the prompt shows |
| `Prompt.idleCheckMs` | ms between looks around while nothing is near |
| `Server.stationReach` | metres from a named station the server allows when crafting |
| `Server.propReach` | metres from the prop the bench was opened at |
| `DefaultDifficulty` | difficulty used when a recipe has none |
| `MaxUnitsPerCraft` | the largest amount in one craft |
| `TokenLifetime` | seconds a started craft may wait for its finish |

**Skill bar (`SkillBar`)**: `enabled` turns it on. For a recipe of difficulty `d`, the target zone is `baseZone - d * zonePerPoint` (never below `minZone`), the perfect zone is `perfectZone`, and the speed is `baseSpeed + d * speedPerPoint` (never above `maxSpeed`). `timeoutMs`: a bar that never reports back within this many ms counts as a fumble.

**Crafting scene (`CraftScene`)**: the scenario played while crafting, its length in ms (`durationMs`), and how many ms into it the skill bar appears (`skillBarAfterMs`).

**Descriptions (`Descriptions`)**

| Field | Meaning |
|---|---|
| `enabled` | allow player-written descriptions on crafted goods |
| `recentKept` | how many recent descriptions each character keeps |
| `maxLength` | the longest description (bytes) |
| `bannedWords` | case-insensitive words a description may not contain |
| `wholeWordsOnly` | `false` matches a banned word anywhere, even inside other words; `true` matches whole words only |

**Crafting box (`Box`)**

| Field | Meaning |
|---|---|
| `enabled` | send finished goods to the box first |
| `idOffset` | the box's vorp_inventory id is `idOffset + charid` |
| `anchorRadius` | metres: the box opens only within this distance of where an empty box was first filled |
| `stationSearch` | metres: how far to look for a named station to name that place in messages |
| `wipeOnStart` | empty every box (ids `idOffset` to `idOffset + 999999`) when this resource starts |
| `wipeDelayMs` | how long after start the wipe runs |

The start-up wipe is skipped while the id range may still hold gang stashes from pup-gangs: it only runs once pup-gangs has recorded its stash move (`gang_meta` key `stash_offset_13m`).

**Timed crafting (`Timed`)**

| Field | Meaning |
|---|---|
| `enabled` | crafts take time and wait on the Pending shelf |
| `defaultSecondsPerUnit` | seconds per unit when a recipe sets no time |
| `batchCapSeconds` | the longest one batch can take (7200 = 2 hours) |
| `maxRunning` | crafts one character may have running |
| `countReadyTowardLimit` | `false`: only crafts still running count toward `maxRunning`; `true`: finished but uncollected crafts count too |
| `keepCollectedDays` | collected crafts are deleted from the queue table this many days after they were ready |
| `sweepEveryMs` | ms between cleanups |

**Tool wear (`ToolWear`)**

| Field | Meaning |
|---|---|
| `enabled` | tools listed below lose durability |
| `drain` | durability lost per craft |
| `perUnit` | `false`: once per craft whatever the amount; `true`: `drain` times the amount |
| `tools` | the tools that wear, with their maximum durability, e.g. `wrench = 150` |
| `overrides` | per-tool drain, e.g. `{ handsaw = 2 }` |
| `conditionSeparator` | what goes between a tool's description and its "Condition = N" line |

**Placeables (`Placeables`)**: items that put down a world prop which then counts as a station prop. `pickupCommand` is the pick-up command (`dc`), `pickupCooldownMs` the gap between pick-ups, `placeMs` how long setting it down takes. Each entry in `items` is `item_name = { model = 'prop_model', townLock = false }`; `townLock = true` stops it being set up inside any town in `BannedTowns` (map town-zone names). Only one placeable per character is out at a time, and a disconnect forgets it without a refund.

**Kits (`Kits`)**: usable items that open the bench anywhere as "Crafting Kit". None by default. Example: `Config.Kits = { my_kit_item = true }`.

**Station props (`StationProps`)**: world models that count as a bench, with the label shown on the prompt and panel, e.g. `p_furnace02x = 'Furnace'`.

**Rules (`Rules`)**

| Field | Meaning |
|---|---|
| `genericRecipesAtStations` | `false`: recipes with no station list only show at props and kits; `true`: recipes with neither a station nor a prop list also show at named stations |
| `showRecipesAboveXp` | `false`: recipes above the player's XP are hidden; `true`: shown as locked |
| `perkDoublesXp` | `false`: the Craftsman perk doubles goods only; `true`: it also doubles XP |

**Log (`Log`)**: Discord embed title, colours (decimal), bot name and footer. The webhook itself lives in `server/config.lua`.

**`SeedRecipes`**: recipes written into an empty recipe table on first start (ids by position). None by default.

**`BaseXpCategories`**: the categories every experience record starts with.

### `config/categories.lua`

One entry per category, in tab order:

```lua
{ key = 'food', label = 'Food', desc = 'Cook Food', icon = 'heart', picture = 'food' },
```

- `icon`: a pup-ui icon name (key, cross, fire, box, shield, money, heart, home, star, anvil, leaf, goblet ...). `DefaultCategoryIcon` is used when none is set.
- `picture`: kept for reference only; nothing displays it.
- `jobs`: leave it out for no lock, or give a list of job names allowed to see this category, e.g. `jobs = { 'blacksmith' }`.

### `config/stations.lua`

Seed stations, `{ name = 'vtblacksmith', x = ..., y = ..., z = ... }`. They are only used to fill an empty `crafting_locations` table, and as a stand-in when that table cannot be read. The live list is in the database and is edited with `/craftloc` or vorp_admin's Crafting page.

## For developers

Server exports (used by vorp_admin; names and shapes are fixed): `GetRecipesAdmin`, `GetCraftCategories`, `UpsertRecipe`, `SetRecipeEnabled`, `GetLocationsAdmin`, `UpsertLocation`, `SetLocationEnabled`.

Client exports (used by vorp_inventory's description card): `GetSavedDescriptions`, `RememberDescription`. The client also listens for the local event `pup_inventory:savedDescriptions`, which carries the card's edited list back.

## License

See LICENSE.
