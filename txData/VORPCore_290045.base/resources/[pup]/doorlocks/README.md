# doorlocks

A door lock system for RedM / VORP. Staff create locks in game on any door the game knows about (no hash list needed), and players with a key, job or item lock and unlock them with a floating key cap.

## Features

- **Single and double doors**, gates included, picked in game with `/createdoor`.
- **Access by job and grade, by character, or by item.**
- **Floating key cap** on the door (pup-ui) showing Lock, Unlock or Locked, with a lock / unlock click sound.
- **Lockpicking:** using the lockpick item next to a lockpickable door starts a minigame (pup-minigames: safe-crack dial, skill bar or skill circle), or a short animation if the minigame is off. The server checks the door, the item and the distance before it starts, and decides the result and the lockpick itself.
- **Law alerts:** picking a door marked "alert law" can alert lawmen, through pup-mdt when it is running, or with a notification and map blip otherwise. The alert never names the lockpicker.
- **Enforcement:** locked doors near each player are re-closed and re-locked if they drift open.
- **Staff override:** staff can open or lock any door, logged to the console.
- **Custom MLO doors:** doors the game's door system never reports can be listed in a config file so they can be selected.
- **Live updates:** every change reaches all clients at once, no relog needed.
- **Server API** for other resources to read, add and update doors.

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory`
- `pup-ui` (menus, text input, floating key cap, door sounds)
- `pup-minigames` (the lockpicking minigame; set `Config.Lockpicking.minigame = false` to do without it)
- `vorp_admin` (optional; its permission system decides who is door staff when it is running)
- `pup-mdt` (optional; break-in alerts go through it when it is running)

## Installation

1. Put the `doorlocks` folder in your resources.
2. Run `sql/install.sql` once. It creates the `doorlock_doors` table and the `lockpick` item, and is safe to run again. The resource also creates the table on start if it is missing.
3. Ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure pup-minigames
   ensure doorlocks
   ```
4. Give your staff the `manage_doorlocks` permission in vorp_admin (for example on a Discord role in `vorp_admin/config/discord.lua`, or in its group config).
5. Add an image for the `lockpick` item to your inventory's item images if it does not have one.
6. Restart the server, then use `/createdoor` in game.

## Commands

| Command | Who | What |
|---|---|---|
| `/createdoor` | staff | Create a single or double door lock: name, job and grade access, character access, required item, locked on start, lockpickable, alert law |
| `/editdoor` | staff | Edit the closest door: everything above, or delete it (type the confirm word) |
| `/togglelock` | anyone | Toggle the closest door; the server still checks access |

Players lock and unlock doors with E at the key cap. Lockpicking starts by using the lockpick item from the inventory next to a lockpickable door.

Staff are decided by vorp_admin's `manage_doorlocks` permission when vorp_admin is running. Otherwise the ACE and VORP group fallbacks in `Config.Admin` apply.

## Configuration

### config/main.lua

**Config.General**
- `debug` - print debug info to the server console and F8. With it on, `/createdoor` also prints the entity and model hash the camera points at.
- `locale` - language file to load: `locales/<locale>.json`.
- `toggleCommand` - name of the command that toggles the closest door (the server still checks access).

**Config.Keys** - prompt key hashes; change the hash only.
- `selectDoor` - E: pick a door while creating a lock or using the `GetDoorId` export.
- `cancel` - X: cancel door selection.
- `toggleLock` - E: lock or unlock the door in front of you (shown on the key cap).

**Config.Integrations**
- `vorpAdmin.permission` - anyone holding this vorp_admin permission may create, edit, delete and open every door. Grant it to a Discord role in `vorp_admin/config/discord.lua`. The ACE and group fallbacks in `Config.Admin` only apply when vorp_admin is not running.
- `pupUi.doorSound` - the pup-ui lock / unlock / denied click. `false` = silent doors.

**Config.Interaction**
- `markerRadius` - metres; within this the floating key cap appears.
- `reachRadius` - metres; within this the key or lockpick works (capped at `markerRadius`).

**Config.Marker** - the floating key cap drawn on the door by pup-ui.
- `enabled` - `false` = no cap at all (the key still works).
- `key` - letter shown on the cap; keep it in step with `Config.Keys.toggleLock`.
- `labels.locked` - shown to a player with no key on a locked door. `false` = show nothing.
- `labels.unlock` / `labels.lock` - shown to a keyholder on a locked / open door.

**Config.Notifications** - which notifications are shown. `false` = silent for that kind.
- `interaction` - every lock, unlock, "no permission" and "no door nearby".
- `admin` - create, edit, delete and door-selection feedback for staff.
- `lockpick` - replies to using a lockpick (no door, cannot pick, wait, failed).

**Config.Enforcement** - keeps locked doors shut on every client.
- `enabled` - re-close and re-lock drifted locked doors near the player.
- `radius` - metres; only locked doors this close are watched.
- `intervalMs` - ms between checks. Lower is snappier but more work.

**Config.Lockpicking** - using the lockpick item on a lockpickable door.

How a pick works: using the item next to a locked, lockpickable door asks the server. The server checks the door, that you carry the item, that you stand within `reach` of the door and that `cooldownMs` has passed, then hands out a one-time ticket and the game starts. The result goes back with that ticket. The door only opens if the ticket is yours and for that door, at least `minTimeMs` and at most `maxTimeMs` have passed, and you are still at the door with the lockpick. A win that comes back too quickly counts as a fail. The server, not the player's game, uses up the lockpick.

- `itemName` - usable item that starts a pick. `''` disables lockpicking.
- `minigame` - `true` = play the game below; `false` = a 2.5 second animation and the door opens.
- `pinGame` - `true` = while the `lockpick` resource is running, its pin game is played (turn the pick to the sweet spot, then turn the lock). `pinHint` is the tip shown before it.
- `game` - the pup-minigames game used without the pin game: `'safe_crack'` (dial), `'skill_bar'` or `'skill_circle'`.
- `difficultyLocks` - safe crack: number of locks on the dial (1-5).
- `attempts` - safe crack: wrong presses allowed before the pick fails. `0` = unlimited.
- `skillBar` - skill bar: `areaSize` (target size in %), `perfectAreaSize` (% of the target), `speed`.
- `skillCircle` - skill circle: `areaSize` (target size as `Math.PI / value`, higher = smaller), `speed`.
- `hint` - tip shown before the game.
- `removeOnUse` - use up one lockpick on every successful pick.
- `removeOnFail` - use up one lockpick when the pick fails.
- `reach` - metres; how close to the door the server wants you, at the start and at the end.
- `cooldownMs` - ms a player waits between pick attempts.
- `minTimeMs` - ms; the quickest real pick. About 3 s go on the animation and the tip, then the game, then its 1.5-2 s result screen. Lower it if honest players get refused. With `minigame = false` it is capped at 2000.
- `maxTimeMs` - ms; a ticket with no answer by then expires.

**Config.LawAlert** - the alert used when a door with "alert law" is picked and pup-mdt is not running.
- `chance` - 0-100, chance an alert is sent per pick attempt.
- `radius` - metres; only lawmen this close to the door are alerted.
- `jobs` - job names that receive the alert.
- `notification` - `title` (shown as both the title and the text, and as the blip name), `dict` (texture dictionary of the icon), `icon` (icon texture), `color` (notification colour), `durationMs` (ms on screen).
- `blip` - `hash` (radius blip style hash), `radius` (blip radius), `durationMs` (ms before the blip is removed).

**Config.Admin** - staff commands and the open-everything override. With vorp_admin running, `Config.Integrations.vorpAdmin.permission` decides; `ace` and `group` are the fallback when it is not.
- `openAll` - `enabled` (staff can open or lock any door), `ace`, `group`, `consoleLog` (print to the server console when staff use the override).
- `create` - `enabled` (register the command), `command` (`/createdoor`), `ace` (also gates the edit and delete server events), `group`.
- `edit` - `enabled`, `command` (`/editdoor`, edits the closest door), `ace`, `group`, `deleteConfirm` (word staff must type to delete a door).

**Config.CustomDoors**
- `matchRadius` - metres; a door prop counts as a listed custom door within this distance of its coords.

### config/custom_doors.lua

Doors that an MLO or map pack adds but the game's door system never reports, so `/createdoor` cannot see them. Listing a door here only makes it selectable in `/createdoor`; the lock itself is still created in game and saved like any other door. Empty by default, which is fine.

How to add an MLO's doors:

1. Find each door's name (the `<Id>` of its `CExtensionDefScriptEntityId` in the MLO's ymap / ytyp) or its door hash (often given by the map author), its prop model and its position. With `Config.General.debug = true`, `/createdoor` prints the entity and model hash the camera points at to F8.
2. Add one entry per door leaf to `Config.CustomDoorList` (a double door is two entries).
3. Restart doorlocks, then use `/createdoor` and pick the door as usual.

Fields:
- `door` (string) - door name baked into the MLO; hashed with `GetHashKey`. Use this or `hash`.
- `hash` (number) - resolved door hash, when the map pack ships the hash instead of the name. If both are given, `hash` wins.
- `model` (string, required) - prop model name of the door.
- `coords` (vector3, required) - position of the door prop.
- `radius` (number, optional) - metres; overrides `Config.CustomDoors.matchRadius` for this entry. Use a smaller value (such as 0.6) for paired leaves that sit close together.

Examples:

```lua
Config.CustomDoorList = {
    { door = 'my_mlo_front_door', model = 'p_door04x', coords = vector3(-300.0, 800.0, 118.0) },
    { hash = 1988748538, model = 'p_door_val_jail02x', coords = vector3(-276.01, 802.59, 118.41) },
    { door = 'my_mlo_gate_l', model = 'p_gate01x', coords = vector3(-310.0, 805.0, 118.0), radius = 0.6 },
}
```

### config/doors.lua

Doors in `Config.StartupDoors` are written to the database on every server start. A door that already exists (matched by its door hash) is overwritten with these settings; a new one is inserted. Doors made in game with `/createdoor` do not need to be listed. Empty by default.

Fields:
- `name` (string) - door name (also used by the `DoorsByName` API).
- `lockedOnStart` (boolean) - locked after every server start.
- `jobAccess` (table) - `{ [jobName] = minimumGrade }`; empty = no job restriction.
- `charAccess` (table) - list of character ids with a key; empty = no character restriction.
- `itemNameAccess` (string or false) - item that opens the door; `false` = none.
- `canLockpick` (boolean) - can be picked with `Config.Lockpicking.itemName`.
- `alertLaw` (boolean) - picking it may alert the law (`Config.LawAlert` or pup-mdt).
- `showPrompt` (boolean) - kept for stored records; always `true`.
- `door` (table) - single door: `{ coords = vector3, hash = number, model = string }`.
- `doors` (table) - double door: two of the above, instead of `door`.

Example:

```lua
Config.StartupDoors = {
    {
        name           = 'Sheriff Office',
        lockedOnStart  = true,
        jobAccess      = { ['ValSheriff'] = 0 },
        charAccess     = { 1, 3, 10 },
        itemNameAccess = false,
        canLockpick    = true,
        alertLaw       = true,
        showPrompt     = true,
        door = { coords = vector3(0.0, 0.0, 0.0), hash = 0, model = 'p_door04x' },
    },
}
```

### locales/en.json

Player-facing text. Pick the file with `Config.General.locale`.

### Door isn't detected?

Doors are detected without a hash list, but the door needs an id inside the YMAP it is placed in. If it has none, add one and stream the modified ymap, or list the door in `config/custom_doors.lua`:

```xml
<Item type="CExtensionDefScriptEntityId">
  <name>some_model_name</name>
  .....
  <Id>needs_an_id_here</Id>
</Item>
```

## For developers

### Client exports

| Export | Returns |
|---|---|
| `exports.doorlocks:CreateDoor()` | Opens the create-door menu; returns the new door id, or `nil` if cancelled |
| `exports.doorlocks:GetDoorId()` | Lets the player select a door; returns its id, or `nil` if cancelled |
| `exports.doorlocks:ClosestDoor(dist)` | The closest door id, or `nil` if none |

### Server exports

| Export | Use |
|---|---|
| `exports.doorlocks:GetAPI()` | The door API (below) |
| `exports.doorlocks:GetDoorList()` | Plain rows of every door (used by the vorp_admin door panel) |
| `exports.doorlocks:SetDoorJobs(doorid, { [job] = minGrade })` | Replace a door's job access |
| `exports.doorlocks:SetDoorLocked(doorid, bool)` | Lock or unlock a door |

```lua
local DoorLocks = exports.doorlocks:GetAPI()

local Door = DoorLocks:Door(doorid)          -- best: by door id
local Door = DoorLocks:DoorByHash(hash)      -- by door hash
local Doors = DoorLocks:DoorsByName(name)    -- every door with that name (e.g. all bank doors)

-- data
Door.Data.doorid       -- number
Door.Data.name         -- string
Door.Data.locked       -- boolean
Door.Data.coords       -- vector3
Door.Data.charAccess   -- list of character ids
Door.Data.jobAccess    -- { [jobName] = minimumGrade }
Door.Data.canLockpick  -- boolean

-- functions
Door.fn.SetLock(true|false)
Door.fn.SetName(name)
Door.fn.SetLockOnStart(true|false)
Door.fn.SetCanLockpick(true|false)
Door.fn.ShowUIPrompt(true|false)
Door.fn.SetJobAccess(access)
Door.fn.AddJob(name)
Door.fn.RemoveJob(name)
Door.fn.SetCharAccess(access)   -- e.g. { 1, 4, 2 }
Door.fn.AddChar(charId)
Door.fn.RemoveChar(charId)
Door.fn.Update({ name = 'Door', locked = true, coords = vec3(0, 0, 0), charAccess = {}, jobAccess = {},
                 lockedOnStart = true, canLockpick = true, showPrompt = true }) -- every field optional
```

Adding a door from another resource:

```lua
local DoorLocks = exports.doorlocks:GetAPI()

local doorid = DoorLocks:AddNewDoor({
    name = 'Doctor Office Front',
    lockedOnStart = false,
    jobAccess = { ['ValDoctor'] = 0 },
    charAccess = {},
    itemNameAccess = false,
    canLockpick = false,
    alertLaw = false,
    showPrompt = true,
    door = {
        coords = vector3(-282.8079528808594, 803.954833984375, 118.39317321777344),
        hash = 3588026089,
        model = 'p_door62x',
    },
})
```

### Server events

```lua
AddEventHandler('pup-doorlocks:Ready', function()
    -- doors are loaded
end)
```

## Credits / License

Based on [gs_doorlocks](https://github.com/GlitchOo/gs_doorlocks) v1.0.5 by _G[S]cripts (GlitchOo), licensed under the GNU General Public License v3. This version was modified by Puppet (Dusk Till Dawn), 2026: pup-ui menus and key cap, pup-minigames lockpicking, enforcement of locked doors, custom MLO doors and pup-mdt alerts.

This resource is distributed under the same licence. See LICENSE.
