# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp_herbs](https://github.com/VORPCORE/vorp_herbs), licensed under the GNU General Public License v2.0 (see `LICENSE`). The modifications are released under the same GPL-2.0 licence as the original.

Lua files that were heavily changed carry a `-- Modified by Puppet (Dusk Till Dawn), 2026` line at the top.

## Changed

- `config.lua`: plant list and locations reworked
- `server/server.lua`: plant cooldowns shared with every client, distance check on picking, Farmer's Pack support (pup-misc)
- `client/client.lua`: picked plants hide their bush and prompt, pick animation and progress bar (pup-ui)
- `fxmanifest.lua`
