# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [VORPCORE/vorp_lib](https://github.com/VORPCORE/vorp_lib), licensed under the GNU General Public License v2.0 (see `license.md`). The modifications are released under the same GPL-2.0 licence as the original.

Lua files that were heavily changed carry a `-- Modified by Puppet (Dusk Till Dawn), 2026` line at the top.

## Changed

- `client/main/selector.lua`, `web/scripts/selector.js`: the player selector re-checks distance every frame and cancels when everyone leaves range
- `client/main/copy.lua`, `web/scripts/copy.js`, `web/index.html`: clipboard copy simplified
- `client/data/gameEvents.lua`, `shared/class.lua`, `shared/notify.lua`, `types/types.lua`, `fxmanifest.lua`: small changes
- `web/fonts/imfell.ttf` with its licence `OFL-IMFellEnglish.txt` (IM Fell English, SIL OFL 1.1) replaces the original font, and the styles in `web/styles` use it

Bundled third-party code: three.js r151 (`web/scripts/gizmo/vendor/three.module.js`, MIT, © 2010-2023 Three.js Authors, header kept), as in upstream vorp_lib.

Compared with the current upstream, this copy has no skill-bar module (`client/main/skillbar.lua`, `web/scripts/skillbar.js`, `web/styles/skillbar.css`) and no `web/styles/copy.css`.
