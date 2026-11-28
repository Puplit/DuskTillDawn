# miner_lumber

Mining and lumberjacking for RedM / VORP. Original author: **Blue**.

Use a pickaxe or an axe from the satchel to hold it, walk up to a gather spot or a rock/tree prop, hold the gather key and swing. Each swing plays a skill-bar minigame; a good swing gives a random reward. Tools lose durability every swing and break at zero.

- Two ways to gather: fixed **spots** (coordinates with a gather limit and a cooldown) and world **props** (any rock or tree model in the list, respawns after a delay).
- Job bonus: listed jobs get extra units per reward.
- Durability is kept in the item metadata and shown as the satchel's durability bar.
- Optional Discord log of every gather (webhook in `server/config.lua`).
- Server checks: gathers at a spot must come from within 10 m of a spot of that type, and prop gathers are rate-limited to the minigame's own swing time.

## Requirements

- `vorp_core`, `vorp_inventory`
- `pup-minigames` (skill bar, required: listed as a dependency)
- Optional, used through guarded calls:
  - `pup-perks`: XP per good swing (`Award`) and extra units from the `gather_yield` perk (`Bonus`)
  - `pup-misc`: rewards go into an equipped job pack first (`PackStore`)

## Install

1. Put `miner_lumber` in your resources and add `ensure miner_lumber` after its requirements.
2. Add the tool and reward items to your items table. Tools need a `durability` value or the durability bar is not written.
3. Set the webhook in `server/config.lua`, or leave it `""` for no log.

## Configuration

All settings live in `config/`. `main.lua` and `data.lua` are shared (client and server).

### General (`config/main.lua`)

| Key | Meaning |
|---|---|
| `Config.Debug` | debug prints |
| `Config.Keys` | `start` (hold to gather), `swing`, `stop` control hashes |
| `Config.Swings` | swings per gather, random `min`..`max` |
| `Config.NodeDefaults` | for spots: `radius` (m), `limit` (gathers before cooldown, random `min`..`max`), `cooldown` (ms) |
| `Config.PropRespawn` | ms before a gathered rock/tree prop can be gathered again |
| `Config.MinigameTuning` | skill-bar `area`, `perfectArea` (%), `speed`, `endDelay`, `swingDelay` (ms) and an `icons` entry per gather type |

The server's prop rate limit is `endDelay + swingDelay - 100` ms (at least 250), so it follows the minigame settings.

### Tools (`Config.Tools`)

One entry per usable item:

```lua
pickaxe = { type = 'mining', durability = 200, drain = 1 },
```

- `type`: the gather type it works on (`mining` or `lumber`)
- `durability`: swings when new
- `drain`: durability lost per swing

To add a tool, add an entry with the item name as the key and add the item to the items table.

### Gather types (`Config.Gather`)

One block per type (`mining`, `lumber`):

```lua
mining = {
    jobs     = { 'rdmine', 'twmine', 'abmine' },
    jobBonus = 4,
    rewards  = {
        { item = 'clay', label = 'Clay', chance = 8, max = 4 },
    },
},
```

- `jobs`: job names that get `jobBonus` extra units on every reward
- `rewards`: on a good swing the server rolls 1-10; every reward whose `chance` is at least the roll is eligible, one of them is picked at random, and it gives 1..`max` units (plus job bonus and perk bonus)

To add a reward, add a line to `rewards`. A `chance` of 10 is always eligible; 1 only on a roll of 1.

### Spots and props (`config/data.lua`)

- `Config.Nodes[type]`: list of spots, `{ x = ..., y = ..., z = ... }`. A spot may also set its own `radius` (m), `limit` (fixed number of gathers) and `cooldown` (ms); anything missing comes from `Config.NodeDefaults`.
- `Config.Props[type]`: model names of rocks (mining) and trees (lumber) that can be gathered wherever they stand.

To add a spot, add a line to the right list:

```lua
{ x = 2763.11, y = 1333.94, z = 70.24 },
{ x = 2756.85, y = 1318.47, z = 70.07, cooldown = 300000, limit = 5 },
```

### Texts (`config/locale.lua`)

Prompt labels and notifications. The prompt label for a gather type is `language[type]`.

## Events

| Event | Side | Purpose |
|---|---|---|
| `pup_miner_lumber:itemused` | server to client | equip / unequip the used tool (item, tool entry, durability, item data) |
| `pup_miner_lumber:forceunequip` | server to client | put the tool away when it left the satchel |
| `pup_miner_lumber:addItem` | client to server | a good swing: checks, then gives a reward |
| `pup_miner_lumber:updateitem` | client to server | save durability left after a gather |
| `pup_miner_lumber:removeitem` | client to server | remove a broken tool |
| `pup_miner_lumber:removeprop` | client only | make a gathered prop available again after `Config.PropRespawn` |
| `pup_miner_lumber:removecoords` | client only | free a spot for its next gather |
| `pup_miner_lumber:startcooldown` | client only | start a spot's cooldown after its limit |

The resource registers no exports.
