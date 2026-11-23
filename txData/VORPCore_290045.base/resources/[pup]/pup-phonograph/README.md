# pup-phonograph

Players set down a phonograph from the `phonograph` item and play a web link on it. Everyone close enough hears it with positional sound through xsound. Staff can place permanent phonographs with `/addphono` and lock them to a job and a minimum grade.

## Features

- Place a phonograph with a see-through preview: arrow keys move it relative to the camera, 7/8 raise and lower it, 1/2 turn it, 3 changes the step size, ENTER sets it down and BACKSPACE cancels.
- Press G next to a phonograph to open its menu: volume, distance, stop, play a link, pick it up (owner or staff), and stop all music (staff).
- Player links must come from an approved site list; staff can be allowed to skip it.
- Music is only sent to players within hearing range, and players who walk up later join at the right point of the track.
- Staff phonographs can be locked to a job and minimum grade.
- Per-character limit on phonographs set down at once.
- Optional loop toggle, owner-only control, stop-when-the-starter-leaves, Discord logging of played links, a quiet crackle track under the music, and record items that carry a fixed link.
- Props are local, non-networked objects spawned only near the player.
- What is playing, the volume and the distance live in server memory only: after a restart each phonograph comes back silent at the default distance.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `xsound` (must start before this resource)
- `pup-ui` (menus, input panels and the placement help panel)

## Installation

1. Import `sql/install.sql`. It creates the `phonographs` table if it is missing and adds the `phonograph` item; it changes no existing rows. The table is also created on start if it is missing.
2. Add a `phonograph.png` image to vorp_inventory's item image folder (none ships with this resource).
3. Optional Discord logging: set `Config.DiscordLog = true`, set the webhook in `server/config.lua`.
4. Add `ensure pup-phonograph` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory`, `xsound` and `pup-ui`.

## Commands

| Command | Who | What |
|---|---|---|
| `/addphono` | staff (`Config.StaffGroups`) | Place a permanent phonograph, then choose its job lock and minimum rank |

## Configuration

Everything is in `shared/config.lua`. All player-facing text is in `shared/locale.lua`.

### General

| Setting | Meaning |
|---|---|
| `StaffGroups` | vorp_core **user** groups (not character groups) that count as staff. |
| `Item` | Inventory item that is set down as a phonograph. |
| `Model` | Game prop used for the phonograph (ships with the game). |
| `PerCharacterLimit` | How many phonographs one character may have set down at once. `0` = no limit. |

### Links

| Setting | Meaning |
|---|---|
| `PlayersMayPlay` | `false` = only staff may play links. |
| `StaffSkipSiteCheck` | `true` = staff links skip the approved-site list (they must still be http/https). |
| `MaxLinkLength` | Longest link accepted, in characters. |
| `ApprovedSites` | A link's host must equal one of these, or end with `.` plus one of these (so `music.youtube.com` matches `youtube.com`). |

### Sound

| Setting | Meaning |
|---|---|
| `Radius` | Hearing distance in metres: `default`, and the `min` / `max` players may set. |
| `DefaultVolume` | Starting volume, 0.0 to 1.0. |
| `Crackle.enabled` / `Crackle.url` | A second, quieter crackle track played under the music. Leave it off until you have a link you hold the rights to. |
| `Crackle.volumeShare` | Crackle volume = music volume x this. |

### Records

`Config.Records` lists inventory items that carry a fixed link. Empty = records are off and no record entries appear in the menu. Each entry:

```lua
Config.Records = {
    { item = 'record_item_name', label = 'Shown name', url = 'https://...' },
}
```

`RecordVolume` is the volume records play at (0.0 to 1.0). A record left on the turntable goes back to the player when the phonograph is picked up.

### Behaviour switches

| Setting | Meaning |
|---|---|
| `LoopToggleInMenu` | Show a loop on/off entry in the phonograph menu. |
| `OwnerOnlyControl` | `true` = only the owner (and staff) may play, stop or adjust a player's phonograph. |
| `StopWhenStarterLeaves` | `true` = music a player started stops when that player disconnects. |
| `DiscordLog` | `true` = played links are also sent to Discord (webhook in `server/config.lua`). Played links are always printed to the server console. |

### Ranges (metres)

| Setting | Meaning |
|---|---|
| `prompt` | Stand this close to a phonograph to see "Open Menu". |
| `spawn` | Phonograph props exist on a client inside this distance. |
| `control` | Non-staff must be this close to play, stop or adjust. |
| `place` | A placed spot must be this close to the player. |
| `pickup` | Must be this close to pick a phonograph up. |
| `hearMargin` | Players inside radius + this are sent the music. |
| `leaveMargin` | Players are told to drop the music beyond radius + `hearMargin` + this. |

### Timing

| Setting | Meaning |
|---|---|
| `playCooldownMs` | One accepted play per player per this many ms. |
| `saveLockMs` | Per-player placement save lock, in ms. |
| `echoGuardSec` | A now-playing record younger than this many seconds is never forgotten. |
| `loopReportGuardSec` | Loop-restart reports reset the start time at most this often, in seconds. |
| `inputTimeoutMs` | Input panels count as cancelled after this many ms. |
| `listenerSyncMs` | How often the server checks who is in hearing range, in ms. |
| `placementTicketSec` | A placement must be confirmed within this many seconds. |
| `readyWaitMs` | An item use waits this long for the database load at start, in ms. |

### Placement

| Setting | Meaning |
|---|---|
| `startStep`, `minStep`, `maxStep` | Movement step in metres: starting value and the range accepted from the step input. |
| `turnDegrees` | Degrees turned per key press. |
| `previewAlpha` | Preview transparency, 0 to 255. |
| `previewDistance` | Metres in front of the player where the preview starts. |
| `confirmDelayMs` | Wait after ENTER before saving, in ms. |
| `repeatFirstMs` / `repeatMs` | Holding a key repeats after `repeatFirstMs`, then every `repeatMs`. |
| `StaffJobMaxLength` / `StaffRankMax` | Longest job name and highest rank staff may set on a permanent phonograph. |

### Keys

`Config.Keys` holds RedM control hashes for the menu prompt and placement keys. Change the hash only.

### server/config.lua

Server only. `PH.Secrets.webhook` is the Discord webhook for played links; `''` = no log.

## For developers

No exports. Net events used between client and server are all prefixed `pup-phonograph:server:` (requests: `openMenu`, `play`, `stop`, `volume`, `radius`, `toggleLoop`, `stopAll`, `pickup`, `savePlayer`, `saveStaff`, `insertRecord`, `playRecord`, `removeRecord`, `requestList`, `requestStaff`, `resync`, `ended`, `looped`) and `pup-phonograph:client:` (pushes). The server re-checks every request; client values are only hints.

Each sound is an xsound sound named after the phonograph id (the crackle track adds `_effect`).

## License

See LICENSE.
