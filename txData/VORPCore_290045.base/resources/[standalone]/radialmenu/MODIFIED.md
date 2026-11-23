# Modifications

Modified by Puppet (Dusk Till Dawn), 2026.

This resource is based on [murphy_radialmenu](https://github.com/levraimurphy/murphy_radialmenu) by Murphy Workshop, licensed under the GNU General Public License v3.0 (see `LICENSE`). This notice is given under section 5a of that licence. The modifications are released under the same GPL-3.0 licence.

Changed files (each change is marked with a `-- pup:` comment):

- `shared/config.lua`: the open key (F1) registered through the game's keybind system, the Murphy Workshop integrations turned off, and this server's wheel slots (posse, law tools gated on pup-mdt duty, clothing toggles, emotes, poses, scenarios, props, weapon offsets), which call commands from other resources.
- `client/client.lua`: no wheel while dead or bleeding out, the wheel closes on death so NUI focus is not left stuck, `/radial` bound through the game's keybind system, and no ragdoll action (pup-misc owns `/ragdoll`).
