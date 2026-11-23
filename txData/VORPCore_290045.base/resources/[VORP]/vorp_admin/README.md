# **VORP ADMIN**

#### **Admin Menu for VORP Core**

----

## Features
- Built in database permissions
- Permissions for all actions
- Administration tools
- Scoreboard
and many more

<img width="280" alt="image" src="https://user-images.githubusercontent.com/87246847/176924806-692cb9ab-9e5b-4c91-ae22-76a6cbe3faf8.png">

Theres also a menu for users

<img width="280" alt="image" src="https://user-images.githubusercontent.com/87246847/176924596-959f8642-f5d2-40f5-a966-aef59346407a.png">

## Installation

- Add `ensure vorp_admin` to your file called `server.cfg`/ `resources.cfg`
- Restart server, enjoy.

## Dependencies
- `vorp_core`, `vorp_inventory` and `vorp_lib`
- `oxmysql`
- `pup-ui` (menus and inputs; vorp_menu and vorp_inputs are no longer used)
- `pup-stable` for Give Horse (while `Config.Integrations.vorpStables.enabled = false`). The horse field takes a model name from pup-stable's coat catalogue (raw hashes are refused); sex `1` or `female` gives a mare.

## Discord roles
`config/discord.lua` ships with placeholder role keys (`OWNER_ROLE_ID` and so on). Replace them with your own Discord role ids. Until then, `fallbackToGroups = true` keeps the VORP group permissions working.

## License
- GPL-2.0, see `LICENSE` and `MODIFIED.md`

## World cleanup (Anti-Cheat tab)
**Clear spawned entities** is on the Anti-Cheat tab of the web panel and the in-game dashboard. You need `anticheat_cleanup` (Discord: `cleanup.world`).
- After you confirm, everyone is told in chat that spawned wagons, horses, objects and peds will be deleted. The countdown is announced at 10, 5, 3, 2 and 1 seconds. Only one cleanup can run at a time.
- On the server it deletes every script-created vehicle, ped and networked prop (population type 7, and type 0 for props). It never deletes:
  - player peds
  - the horse, wagon or boat a player is on, or the horses in its harness
  - anything attached to a player
  - anything carrying a `keepStateKeys` state bag key
  - the game's ambient townspeople and wildlife
- Props that exist only on one player's game are not touched. Each resource clears its own.
- Settings are in `config/worldcleanup.lua`: seconds, announce marks, cooldown, keep lists and the chat text.
- The log goes to the `spawnGuard` webhook (falling back to `default`) and to the server console.
- `/worldcleanup` starts one from the console. `/worldcleanup cancel` stops a countdown.
- Other resources listen for `vorp_admin:worldCleanup` (fired just before deleting) and `vorp_admin:worldCleanupDone` (fired after), on both the server and the client.
  - For example, pup-stable counts swept horses and wagons as put away.
  - To protect one of your entities, set `Entity(ent).state.worldCleanupKeep = true`.

## SUPPORT

Support is offered but not `guaranteed` in the official `Discord`

[VORP Core Discord](https://discord.gg/JjNYMnDKMf)