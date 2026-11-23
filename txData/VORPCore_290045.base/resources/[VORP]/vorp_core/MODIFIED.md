# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp-core-lua](https://github.com/VORPCORE/vorp-core-lua), licensed under the GNU General Public License v2.0 (see `license.md`). The modifications are released under the same GPL-2.0 licence as the original.

Lua files that were added or heavily changed carry a `-- Modified by Puppet (Dusk Till Dawn), 2026` line at the top.

## Added

- `client/pup_heightTrace.lua` (height debugging trace), `client/pup_timerui.lua` (mission countdown helper), `client/pupmenu.lua`
- `server/config.lua` (server-only settings: webhooks)
- `ui/hud.html`, `ui/assets/icons/gold_2.png`
- `ui/assets/fonts/imfell.ttf` with its licence `OFL-IMFellEnglish.txt` (IM Fell English, SIL OFL 1.1), used by `ui/assets/css/style.css` in place of the original font

## Changed

- `server/logs.lua`, `server/loadusers.lua`, `server/whitelist.lua`: Discord connection logging (connecting, joined, leave with session length)
- `server/class/character.lua`: appearance writes refused while a borrowed look is worn, and failed writes reported
- `client/uicore.lua`: set (not toggle) UI visibility, `SetAllUI` export, movable HUD layout
- `client/ref/vorp_notifications.lua`, `ui/assets/css/style.css`, `config/config.lua`, `config/commands.lua`, `config/logs.lua`
- Small changes: `client/clientapi.lua`, `client/commands.lua`, `client/discrichpresence.lua`, `client/exports/exp_notifications.lua`, `client/miscellanea.lua`, `client/notifications.lua`, `client/respawnsystem.lua`, `client/spawnplayer.lua`, `server/commands.lua`, `server/init.lua`, `server/instance.lua`, `fxmanifest.lua`

## Removed

- `ui/index.html` (replaced by `ui/hud.html`)
