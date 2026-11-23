# pup-spawnselect

Shows a map picker when a character loads, so the player chooses where to wake up: where they logged out, a town, their job's spawn, or a house they own or hold a key to.

## Features

- **Map picker:** a full-screen map of the territory with a pin and a card for every spawn.
- **Where you left off:** the first card resumes from the saved position, with nothing moved.
- **Town cards:** any number of towns, each with a region, description and optional photo.
- **Job spawns:** one extra card for characters with a given job.
- **House cards:** one card per house the character owns or holds a key to, at its front door (with pup_realestate).
- **Exploit guards:** the teleport is client side, so the server decides whether the picker is offered at all:
  - relogging soon after a disconnect gets no picker;
  - after a pick that moves the character, later logins resume where they left off until the cooldown ends;
  - characters who logged out dead never get the picker;
  - characters serving a pup-mdt sentence never get the picker.
- **Resumes are free:** carrying on from where they logged out never spends the cooldown. A resume is re-checked a few seconds later, and a character found far from the saved spot by then counts as having moved.
- **Discord log:** optional, one message per pick with the time since the last move and the last disconnect.

## Requirements

- `vorp_core`
- `oxmysql`
- `vorp_admin` (Leaflet is loaded from it)
- Internet access for the map image: kibook/webmap's rdr3 `map.jpg`, loaded from its public GitHub URL (not shipped, as it has no licence; the picker shows plain parchment without it)
- `pup-ui` (fonts are loaded from it)
- Optional: `pup_realestate` (house cards)
- Optional: `pup-mdt` (jailed characters get no picker)

## Installation

1. Run `sql/install.sql`, or let the resource create its `spawnselect` table on start.
2. Optional, for the Discord log: set `Secrets.Webhooks.spawnPicked` in `server/config.lua`.
3. Add `ensure pup-spawnselect` to `server.cfg` after `vorp_core`, `oxmysql`, `vorp_admin` and `pup-ui` (and `pup_realestate` / `pup-mdt` if you use them).

No items or local images are needed.

## Commands

None.

## Configuration

### config/main.lua

**Config.General**

| Field | Meaning |
|---|---|
| `enabled` | `false` never shows the picker. |
| `everySpawn` | `true` shows it on every character load; `false` only on the first spawn of the session. |

**Config.Integrations**

| Field | Meaning |
|---|---|
| `realestate.enabled` | Adds a card per house the character owns or holds a key to, at its front door. Only used while `pup_realestate` is started. |

The pup-mdt check (no picker while serving an active sentence) is automatic and has no setting.

**Config.Menu**

| Field | Meaning |
|---|---|
| `accentColor` | CSS colour of the highlights in the picker, e.g. `"#b8863b"`. |
| `timeoutSeconds` | Seconds before the first card is picked automatically. `0` waits forever. |

**Config.LastLocation**

| Field | Meaning |
|---|---|
| `enabled` | Offers where they logged out as the first card. |

**Config.Guards** (`0` turns a guard off)

| Field | Meaning |
|---|---|
| `cooldownMinutes` | Minutes after a pick that moved the character during which later logins resume where they left off. |
| `dropGraceSeconds` | Relogging within this many seconds of a disconnect gets no picker. |

**Config.Logging**

| Field | Meaning |
|---|---|
| `webhookName` | Username shown on the Discord message. `""` uses "Spawn Select". The webhook URL itself is `Secrets.Webhooks.spawnPicked` in `server/config.lua`. |

### config/spawns.lua

**Config.JobSpawns** gives characters with a job one extra card, keyed by job name.

| Field | Meaning |
|---|---|
| `label` | Card name. |
| `coords` | `vector3` spawn position. |
| `heading` | Facing, in degrees. |
| `blurb` | Optional description text. |

```lua
Config.JobSpawns = {
    doctor = { label = "Saint Denis Hospital", coords = vector3(0.0, 0.0, 0.0), heading = 0.0 },
}
```

**Config.Spawns** lists the town cards, in display order.

| Field | Meaning |
|---|---|
| `label` | Card and pin name. |
| `area` | Region shown under the name. |
| `blurb` | Description text. |
| `coords` | `vector3` spawn position. |
| `heading` | Facing, in degrees. |
| `image` | Optional `"https://..."` photo shown at the top of the panel. |
| `labelAngle` | Optional direction of the map name plate, in screen degrees: `-90` north, `0` east, `90` south, `180` west (`135` = down-left). Use it when the automatic direction lands on a name already printed on the map. |
| `labelDist` | Optional distance of the name plate from the pin, in pixels (default 100). |

```lua
{ label = "Valentine", area = "Heartlands", blurb = "...", coords = vector3(-168.3, 629.5, 113.7), heading = 249.7 },
```

### config/locale.lua

All text players see: the header, the last-location card, the house cards and the job card. Edit the text and keep the keys. Town card text lives in `config/spawns.lua`.

### server/config.lua

| Field | Meaning |
|---|---|
| `Webhooks.spawnPicked` | Discord webhook URL for the pick log. `""` turns the log off. |

## For developers

| Event | Side | Use |
|---|---|---|
| `pup-spawnselect:open` | client | Trigger to open the picker again (the server still decides whether it is allowed). |
| `pup-spawnselect:done` | client | Fired locally once the player has picked and been placed. |

Database: `spawnselect` holds, per character, the last pick time, last disconnect time, pick count and last label.

## Credits

The map image is loaded at runtime from kibook/webmap's public GitHub repository (`rdr3/map.jpg`); it is not shipped with this resource.

## License

See LICENSE.
