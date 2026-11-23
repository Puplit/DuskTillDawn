# pup-bloodmoon

A blood moon for RedM / VORP: a clear night sky, a dominating moon and a red cast. It is raised by a cursed wolf howling at a set site, by staff, or by another resource, and `weathersync` is paused while it is up.

## Features

- **Howl:** a player in wolf form carrying the `lycan` curse howling at a howl site raises the moon, with a server-wide cooldown.
- **Night window:** by default a moon only rises between 20:00 and 05:00 in game, and drops itself at dawn.
- **Optional duration:** a moon can lift after a set number of real minutes instead of at dawn.
- **Looks:** several red sky looks (misty, fog, shower, thunderstorm) that staff can switch live.
- **Weather hand-off:** `weathersync` is suspended while the moon is up and its weather is pushed back to everyone when it lifts.
- Players who join while a moon is up see it straight away.

## Requirements

- `vorp_core`
- `weathersync`
- `pup_shaman` (the wolf form, the howl event and the `GetCurse` export)
- `vorp_admin` (optional; players it allows `open_menu` may also use the command)

## Installation

1. Put `pup-bloodmoon` in your resources folder.
2. Ensure it after its dependencies:
   ```
   ensure vorp_core
   ensure weathersync
   ensure pup_shaman
   ensure pup-bloodmoon
   ```

No SQL, items or webhooks are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/bloodmoon on` | admin groups, or `vorp_admin` `open_menu` | Raise the moon |
| `/bloodmoon off` | same | Lower the moon |
| `/bloodmoon look <n>` | same | Switch to look number `n` (no number lists the looks) |
| `/bloodmoon status` | same | Show whether a moon is up, the look and the minutes left |

The command also works from the server console.

## Configuration

### config/main.lua

**Config.General**
- `command` - name of the admin command (`/bloodmoon on | off | look <n> | status`).
- `adminGroups` - VORP groups allowed to use the command. Players `vorp_admin` allows to `open_menu` may use it too.

**Config.Integrations.shaman** (`pup_shaman` fires the `pup_shaman:howled` event and owns the `GetCurse` export)
- `wolfModels` - ped models that count as a wolf; match `pup_shaman`'s wolf model and MP model.
- `requireCurse` - the curse the howler must carry, checked through `GetCurse`. `nil` skips the check.

**Config.Moon**
- `defaultLook` - index into `Config.Looks` used until staff pick another.
- `transitionInSeconds` / `transitionOutSeconds` - weather blend time in seconds when the moon rises and lifts.
- `durationMinutes` - real minutes a moon lasts. `0` = it runs until dawn.

**Config.Night** - in-game hours, read from `weathersync`. The moon drops itself at dawn, and the howl and the `Raise` export refuse outside the window. If you use `pup-events`' Dead of Night (00:00-05:00), keep that inside this window.
- `enabled` - `true` = a moon is only allowed inside the window.
- `fromHour` - hour the window opens (0-23).
- `toHour` - hour the window closes (0-23). It may wrap past midnight, as in the default 20 to 5.

**Config.Howl**
- `enabled` - `false` = howling never raises the moon.
- `cooldownMinutes` - real minutes, server-wide, before another howl can raise a moon. At a timescale of 30 a game night is about 18 real minutes.
- `sites` - places a howl counts. The first site in range wins. Each entry:
  - `label` - name shown in the console log
  - `coords` - `vector3` centre
  - `radius` - metres from the centre the howler must be within (default 40.0)

  Example of adding a site:
  ```lua
  { label = 'Wolf rock', coords = vector3(-1200.0, 300.0, 80.0), radius = 30.0 },
  ```

**Config.Looks** - the red is a weather *variation* (the Halloween set from Red Dead Online), not a weather type, so a clear sky has no red in it at all. Each variation only takes over its own base type, so a look is a base weather plus a flag. Switch live with `/bloodmoon look <n>`.
- `label` - name shown in the look list
- `weather` - base weather type (`MISTY`, `FOG`, `SHOWER`, `THUNDERSTORM`, or any other weather for a look without red)
- `variation` - `true` to bind the red variation onto it

### config/locale.lua

Text players see: howl replies, the server-wide broadcast and the command replies. `%d` / `%s` are filled in by the code. Set `howlBroadcast` to `''` for no broadcast.

## For developers

Server exports:

| Export | Returns | Use |
|---|---|---|
| `exports['pup-bloodmoon']:IsBloodMoon()` | boolean | Is a moon up |
| `exports['pup-bloodmoon']:Raise(why)` | boolean | Raise the moon. `why` is a label for the console log. Returns `false` if a moon is already up or it is outside the night window |
| `exports['pup-bloodmoon']:Lower(why)` | boolean | Lower the moon. Returns `false` if no moon is up |

The resource listens for the `pup_shaman:howled` client event to detect a howl.

## License

See LICENSE.
