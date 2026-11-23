# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp_admin](https://github.com/VORPCORE/vorp_admin), licensed under the GNU General Public License v2.0 (see `LICENSE`). The modifications are released under the same GPL-2.0 licence as the original.

Lua files that were added or heavily changed carry a `-- Modified by Puppet (Dusk Till Dawn), 2026` line at the top.

## Added

- Web control panel (NUI): `client/panel.lua`, `client/dashboard.lua`, `html/index.html`, `html/index.js`, `html/panel.js`, `html/panel.css`, `html/img/**`
- Live map: Leaflet (`html/vendor/`, BSD-2-Clause, see its header) and kibook/webmap's map calibration in `html/panel.js`
- Ped menu and stable admin: `client/pedmenu.lua`, `client/datapeds_verified.lua`, `client/stableadmin.lua`
- Anti-cheat and server protection: `client/pup_antiCheat.lua`, `server/pup_antiCheat.lua`, `server/pup_flagStore.lua`, `server/pup_cashWatch.lua`, `server/pup_spawnGuard.lua`, `client/pup_cleanup.lua`, `server/pup_cleanup.lua`
- Bans and connection gates: `server/bans.lua`, `server/pup_steamGate.lua`, `server/pup_vpnGate.lua`
- Permissions, audit log and bridges to other resources: `server/pup_discordPerms.lua`, `server/pup_auditLog.lua`, `server/pup_doorLocks.lua`, `server/pup_events.lua`, `pupmenu.lua`
- Config split into `config/main.lua`, `config/permissions.lua`, `config/discord.lua`, `config/anticheat.lua`, `config/guard.lua`, and `server/config.lua` (server-only settings)
- `sql/install.sql`, `PERMISSIONS.md`

## Changed

- `server/server.lua` (largely rewritten: panel back end, permission checks)
- `client/admin.lua`, `client/boosters.lua`, `client/client.lua`, `client/database.lua`, `client/devTools.lua`, `client/functions.lua`, `client/teleport.lua`, `client/users.lua`
- `fxmanifest.lua`

## Removed

- `config.lua` (replaced by `config/`), `logs.lua`

## Map image

The live map draws kibook/webmap's RDR3 map image (<https://github.com/kibook/webmap>). That repository has no licence, so the image is **not** shipped here. The panel loads it from its public GitHub URL (`https://raw.githubusercontent.com/kibook/webmap/master/http/rdr3/map.jpg`). If it cannot load, the map shows plain parchment and every pin, filter and teleport still works. The world-to-pixel calibration in `html/panel.js` is taken from kibook/webmap.
