# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp_character-lua](https://github.com/VORPCORE/vorp_character-lua), licensed under the GNU General Public License v2.0 or later (see `LICENSE` and `README.md`). The modifications are released under the same licence as the original.

Lua files that were added or heavily changed carry a `-- Modified by Puppet (Dusk Till Dawn), 2026` line at the top.

## Added

- Character select and creator UI: `ui/**` (`index.html`, `app.js`, `charselect.js`, `charselect.css`, `style.css`, images), `client/creator_scene.lua`, `client/facepage.lua`, `pup_form.lua`
- Character cards and codes: `server/pup_charcards.lua`, `client/pup_charcode.lua`, `server/pup_charcode.lua`, `sql/charcards.sql`, `sql/charcodes.sql`, `sql/install.sql`
- Height, hair tint, overlays and disguise bridges: `client/pup_height.lua`, `server/pup_height.lua`, `client/pup_hairtint.lua`, `client/pup_overlay_api.lua`, `client/pup_disguise.lua`, `client/pup_clothing_bridge.lua`
- Second chance item: `server/pup_secondchance.lua`
- Config split into `config/main.lua`, `config/appearance.lua`, `config/components.lua`, `config/overlays.lua`, `config/shops.lua`, `config/spawns.lua`, and `server/config.lua` (server-only settings)

## Changed

- `client/client.lua`, `client/clothingstore.lua`, `client/commands.lua`, `client/createCharacter.lua`, `client/creator_functions.lua`, `client/functions.lua`, `client/menu.lua`
- `server/server.lua`, `shared/utils.lua`, `fxmanifest.lua`

## Removed

- `config.lua`, `config_shops.lua` (replaced by `config/`), `logs.lua`
