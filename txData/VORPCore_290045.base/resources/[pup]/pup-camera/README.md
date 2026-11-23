# pup-camera

A free-flying photo and cinematic camera for staff on RedM / VORP. Access is by Steam id and is checked on the server.

## Features

- **Free camera** with boost, slow, roll and zoom, bounded to a set range from where it was opened.
- **Smooth movement:** the camera rides an invisible prop, so the game's anti-aliasing stays on while it moves. If the prop cannot be loaded, the camera moves itself instead.
- **Dolly:** save camera points and play a smooth move through them, with a pre-roll countdown so you know when to start recording. Nothing is shown on screen while a dolly moves.
- **World:** time, weather and slow motion presets that apply to you only, through `weathersync`. Live sync comes back when the camera closes.
- **Looks:** colour grades (timecycles), screen effects, depth of field, letterbox bars and a rule-of-thirds grid. A browser lists every timecycle the game has, for finding new looks.
- **Clean frame:** the game HUD stays hidden while the camera is up, the server's own UI is hidden through vorp_core's `/hideUi` switch, and Q hides the camera's own overlays.
- Show or hide your own character for self portraits, and move your character to the camera.
- Every open and close is printed to the server console by name.

## Requirements

- `vorp_core`
- `pup-ui` (the list menu)
- `weathersync` (optional; needed for the time and weather presets)

## Installation

1. Put `pup-camera` in your resources folder.
2. Ensure it after its dependencies:
   ```
   ensure vorp_core
   ensure weathersync
   ensure pup-ui
   ensure pup-camera
   ```
3. Add your staff Steam ids in `server/config.lua` (server only, never sent to players).

No SQL, items or webhooks are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/cam` | Steam ids in `Config.Access.allowed` | Open or close the camera |

Controls while the camera is up:

| Key | Action |
|---|---|
| Mouse / WASD | Look / move |
| Space / Ctrl | Up / down |
| Shift / V | Faster / slower |
| `[` / `]` | Roll left / right, R resets roll |
| PageUp / `=`, PageDown / `-` | Zoom in / out |
| M | Camera menu |
| F3 | Show or hide the controls list |
| E / C | Save a camera point / clear the points |
| P | Play the dolly (P or Backspace stops it) |
| G | Next colour style |
| H | Grid |
| Q | Hide all camera overlays |
| Backspace | Close the camera |

## Configuration

### config/main.lua

- `Config.General`
  - `debug` - print which carrier model was used to F8.
  - `command` - chat command that opens and closes the camera.
  - `keybind` - default key for the command, e.g. `"F6"`. `""` = command only.
- `Config.Keys` - Windows virtual-key codes, not control hashes.
  - `menu` - the camera menu (77 = M). The map is a normal control, so it is blocked and M is free.
  - `help` - show or hide the controls list (114 = F3).
  - Avoid any key another resource binds with `RegisterKeyMapping`: those fire straight through the camera's control block and cannot be stopped from here. Keys bound as plain controls are safe, because the camera disables all control groups while it is up. Usually free: 74 J, 75 K, 77 M, 79 O, 85 U, 86 V, 114 F3, 115 F4.
- `Config.Movement` - the Camera Feel presets overwrite `speed` and `lookSensitivity` while the camera is in use.
  - `speed` - metres per frame at normal speed.
  - `boostMultiplier` - while Shift is held.
  - `slowMultiplier` - while V is held.
  - `lookSensitivity` - mouse look sensitivity.
- `Config.Lens`
  - `fovDefault` - field of view the camera opens with, degrees.
  - `fovMin` / `fovMax` - narrowest and widest zoom, degrees.
  - `fovStep` - degrees per frame while a zoom key is held.
  - `letterboxHeight` - letterbox bar height as a fraction of the screen, for the top and bottom bar each.
- `Config.Dolly`
  - `legSeconds` - seconds one move between two saved points takes (the menu can change it).
  - `countdownSeconds` - pre-roll countdown before the move starts.
- `Config.Carrier.model` - the invisible prop the camera rides. Moving an entity instead of the camera keeps anti-aliasing alive. It is made invisible and non-colliding at once, so its size does not matter, but it must be a model that exists in the game files. If it fails to load, the camera still works and moves itself.

### config/presets.lua

- `Config.TimePresets` - applied to you only, through `weathersync`'s `setMyTime` export, which suspends your weather sync until the camera closes. Each entry: `name` (menu label), `hour` (0-23), `minute` (0-59). Example: `{ name = "Noon", hour = 12, minute = 0 },`
- `Config.WeatherPresets` - `weathersync`'s own weather names. A name not on that list is ignored by the game.
- `Config.TimeScales` - world speed multipliers offered in the menu. `1.0` is normal speed; the first entry is what the camera opens with.
- `Config.Styles` - colour grades (timecycle modifiers). Each `tc` is checked against the game at start and dropped with a console warning if it does not exist. Each entry: `name` (menu label), `tc` (timecycle name; leave out for no grade), `strength` (optional, 0.0-1.0, default 1.0). Example: `{ name = "Sepia", tc = "sepia" },`
- `Config.ScreenFx` - fullscreen effects (animpostfx), layered on top of a style. Each entry: `name` (menu label), `fx` (effect name; leave out for none). Example: `{ name = "Dead Eye", fx = "DeadEye" },`
- `Config.FeelPresets` - each sets movement speed, look sensitivity and FOV. Each entry: `name`, `speed` (metres per frame, replaces `Config.Movement.speed`), `look` (replaces `Config.Movement.lookSensitivity`), `fov` (degrees). Example: `{ name = "Handheld", speed = 0.45, look = 6.0, fov = 50.0 },`

### config/access.lua (server only)

Checked on the server against the player's identifiers, and loaded only as a server script, so the staff list never reaches a player's machine.

- `allowed` - Steam ids that may open the camera, one line per staff member. Set in `server/config.lua`.
- `unlimited` - Steam ids that ignore `maxRange`. Set in `server/config.lua`.
- `maxRange` - metres the camera may travel from where it was opened. An invisible observer that can cross the map works as a wallhack, so it is bounded. `0` = unlimited for everyone (not recommended).

### config/locale.lua

Notifications shown to staff while using the camera. `%d` is a number. Nothing is notified once a dolly is moving.

## For developers

Server export:

| Export | Returns | Use |
|---|---|---|
| `exports['pup-camera']:isAllowed(src)` | boolean | Whether the player may use the camera |

`client/pupmenu.lua` must load before `client/main.lua`.

## License

See LICENSE.
