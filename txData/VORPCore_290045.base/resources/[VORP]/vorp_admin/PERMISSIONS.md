# vorp_admin permissions

Every key the admin panel actually checks, what it unlocks, and what to give to
whom. Generated from the call sites in `server/server.lua`, not from memory — if
a key is not in this file, nothing in the resource checks it.

**54 live keys.**

---

## How a permission is resolved

`AllowedToExecuteAction(src, key)` → `HasPermission` in
`server/pup_discordPerms.lua`, which tries two sources in order:

1. **Discord roles** — `Config.DiscordPermissions.roles` in `config/discord.lua`, keyed by
   role ID. A player with several roles gets the **union** of their permissions.
2. **VORP group** — `Config.Permissions.groups` in `config/permissions.lua`, keyed by the
   player's `group` column. Only reached when Discord cannot answer (no bot
   token, no linked Discord, API down) because `Config.DiscordPermissions.fallbackToGroups = true`.

Resolved sets are cached for `Config.DiscordPermissions.cacheSeconds` (60s), so a role
change takes up to a minute to apply.

### Three ways to write a grant

```lua
perms = { "all" }                -- everything, no exceptions
perms = { "players.*" }          -- every key in one group
perms = { "players.kick",        -- friendly names
          "manage_housing" }     -- or raw keys, both work
```

---

## The gatekeepers

Two keys matter more than the rest. Get these wrong and nothing else matters.

| Key | What it really means |
|---|---|
| `open_menu` | **Required for everything.** Without it the panel will not open and no page loads. Every staff role needs it. |
| `admin_actions_menu` | **Far more powerful than the name suggests** — 14 call sites. Gates character height, PO box create/change, **deleting a character**, and creating/editing/deleting rows in the `items` table. Treat as senior-staff only. |

---

## Players

`players.*`

| Key | Friendly | Unlocks | Risk |
|---|---|---|---|
| `check_player_inventory` | `players.view` | Read someone's inventory | low |
| `kick_player` | `players.kick` | Kick | medium |
| `ban_player` | `players.ban` | Ban an online player | high |
| `ban_offline` | `players.banoffline` | Ban by identifier | high |
| `unban_player` | `players.unban` | Lift a ban | high |
| `whitelist_player` | `players.whitelist` | Add/remove whitelist | high |
| `freeze_player` | `players.freeze` | Freeze in place | low |
| `spectate` | `players.spectate` | Spectate | medium |
| `heal_player` | `players.heal` | Heal someone | low |
| `revive_player` | `players.revive` | Revive someone | low |
| `respawn_player` | `players.respawn` | Force respawn | low |
| `clear_inventory` | `players.clearinv` | **Wipe an inventory** | high |
| `clear_currency` | `players.clearcash` | **Wipe money or gold** | high |
| `give_item` | `players.giveitem` | Spawn items | **economy** |
| `give_weapon` | `players.giveweapon` | Spawn weapons | **economy** |
| `give_moneygold` | `players.givemoney` | **Spawn money or gold** | **economy** |
| `give_horse` | `players.givehorse` | Give a horse | economy |
| `give_wagon` | `players.givewagon` | Give a wagon | economy |
| `set_job` | `players.setjob` | Change job and grade | medium |
| `set_group` | `players.setgroup` | **Change someone's admin group — this is "can make anyone an owner". Leadership only.** | **critical** |
| `godmode` | `players.godmode` | Self godmode | medium |
| `infinite_ammo` | `players.ammo` | Self infinite ammo | medium |
| `golden_cores` | `players.cores` | Self golden cores | medium |

## Teleport

`teleport.*`

| Key | Friendly | Unlocks |
|---|---|---|
| `tp_to_player` | `teleport.toplayer` | Go to a player |
| `bring_player` | `teleport.bring` | Bring a player to you |
| `send_player_back` | `teleport.sendback` | Send them back after bringing |
| `tp_player_back` | `teleport.playerback` | Return a player to their last spot |
| `tp_to_coords` | `teleport.coords` | Teleport to coordinates |
| `tp_to_waypoint` | `teleport.waypoint` / `teleport.self` | Teleport to your waypoint |
| `noclip` | `teleport.noclip` | Noclip |

## Self

`self.*` — safe for any staff rank.

| Key | Friendly | Unlocks |
|---|---|---|
| `selfheal` | `self.heal` | Heal yourself |
| `selfrevive` | `self.revive` | Revive yourself |

## Spawn

`spawn.*`

| Key | Friendly | Unlocks |
|---|---|---|
| `spawn_horse` | `spawn.horse` | Spawn a horse |
| `spawn_wagon` | `spawn.wagon` | Spawn a wagon |

## Domain pages

`manage.*` — each one unlocks a whole page. Browsing most of them needs only
`open_menu`; these keys are what allow **writing**.

| Key | Friendly | Unlocks | Notes |
|---|---|---|---|
| `manage_housing` | `manage.housing` | Houses: edit, seize, delete, transfer, auctions | |
| `manage_society` | `manage.society` | Businesses: ranks, salary, tax, shops, hire/fire, delete | Also grants in-world society admin via `isSocietyAdmin` |
| `manage_ranch` | `manage.ranch` | Ranches: hands, production, price and tax | Also grants pup-ranch's `isRanchAdmin` |
| `manage_stores` | `manage.stores` | Player-owned shops: owners, ledgers, tax owed | |
| `manage_crafting` | `manage.crafting` | Recipes and station locations | |
| `manage_gangs` | `manage.gangs` | Gang points, rosters, territory, disband | Points drive **both** map radius and perk level — effectively "can reshape the gang map" |
| `manage_perks` | `manage.perks` | Levels, XP, perk points, resets | **Works on offline characters** |
| `manage_bank` | `manage.bank` | Banks: every character's branch balances and cash; wipe or set them | **Works on offline characters** |
| `manage_hideouts` | `manage.hideouts` | Hideouts: owners, co-owners, ledger, stash, raids, evict, delete | Changes reach players in-game at once |

## Troll

`troll.*` — pure griefing tools. Nothing here is needed to moderate.

`troll_kill_player`, `troll_lightning_strike`, `troll_set_player_on_fire`,
`troll_tp_to_heaven`, `troll_ragdoll_player`, `troll_handcuff_player`,
`troll_invisible`, `troll_drain_player_stam`, `troll_temp_high_player`

Friendly names: `troll.kill`, `troll.lightning`, `troll.fire`, `troll.heaven`,
`troll.ragdoll`, `troll.handcuff`, `troll.invisible`, `troll.stamina`,
`troll.temp`

## Other

| Key | Friendly | Unlocks |
|---|---|---|
| `allow_announce` | `menu.announce` | Server-wide announcements |
| `anticheat_panel` | `security.panel` | Anti-Cheat tab, read-only flag history |
| `anticheat_cleanup` | `cleanup.world` | Anti-Cheat tab: **Clear spawned entities**. Deletes every script-spawned wagon, horse, ped and prop for everyone after a chat countdown. It is in its own group, so no wildcard hands it out. It is not in the moderator set. Head Admin and `all` roles have it. |

## Commands in other resources

These have no page in the panel. Each resource checks the key itself, alongside its own `Config.Staff.groups`.

| Key | Friendly | Resource | Unlocks |
|---|---|---|---|
| `open_menu` | `menu.open` | pup_armory | Save a weapon's default position for everyone from `/wp` |
| `manage_stores` | `manage.stores` | pup_tradepost | Cancel anyone's trading post order |
| `manage_curses` | `manage.curses` | pup_shaman | The panel's Curses page |
| `manage_farms` | `manage.farms` | pup_homestead | The panel's Farms page |
| `manage_staffdesk` | `desk.manage` | pup_staffdesk | **`/parcel` creates cash, items and weapons.** Also `/staffdesk`, `/bounty`, `/rename`. Its own group, so `manage.*` doesn't include it. **economy** |

---

## Ready-made roles

Paste into `Config.DiscordPermissions.roles` in `config/discord.lua` against the role ID.

**Owner / Management**
```lua
perms = { "all" },
```

**Head Admin** — everything except handing out admin
```lua
perms = { "menu.open", "menu.actions", "menu.announce", "security.panel",
          "players.*", "teleport.*", "self.*", "spawn.*", "manage.*" },
-- then remove set_group by NOT using players.* if you want that lock:
-- list players.kick, players.ban, ... individually instead
```

**Admin** — moderate and run the domain pages, no economy spawning
```lua
perms = { "menu.open", "security.panel",
          "players.view", "players.kick", "players.ban", "players.unban",
          "players.banoffline", "players.whitelist", "players.freeze",
          "players.spectate", "players.heal", "players.revive", "players.respawn",
          "teleport.*", "self.*", "spawn.*", "manage.*" },
```

**Moderator** — people problems only
```lua
perms = { "menu.open",
          "players.view", "players.kick", "players.ban", "players.freeze",
          "players.spectate", "players.heal", "players.revive",
          "teleport.toplayer", "teleport.bring", "teleport.sendback",
          "self.*" },
```

**Support** — help, cannot punish
```lua
perms = { "menu.open", "players.view", "players.heal", "players.revive",
          "teleport.toplayer", "self.*" },
```

**Builder / Content** — content pages, no player powers
```lua
perms = { "menu.open", "manage.crafting", "manage.housing", "manage.stores",
          "teleport.coords", "teleport.waypoint", "teleport.noclip", "self.*" },
```

---

## Gotchas

- **`open_menu` is not optional.** A role without it sees nothing at all, no
  matter what else it holds.
- **`admin_actions_menu` includes deleting characters.** Do not hand it out as
  "the actions menu".
- **`set_group` is the keys to the kingdom.** Anyone with it can grant themselves
  or anyone else full admin.
- **`manage_perks` reaches offline characters** — no "they have to be online"
  safety net.
- **Role changes take up to 60 seconds** (`Config.DiscordPermissions.cacheSeconds`).
- **`Config.DiscordPermissions.fallbackToGroups = true`** means a Discord outage falls back to the
  VORP group table rather than locking everyone out. Leave it on unless Discord
  is proven reliable; `false` means an outage removes every admin including you.
- **The `moderator` group preset in `config/permissions.lua` grants 21 keys that nothing
  checks** — `admin_menu`, `boosters_menu`, `teleport_menu`, `database_menu`,
  `devtools_menu`, `players_list_menu`, `view_reports_menu`, `get_coords`,
  `delete_horse`, `invisibility`, `teleport_to_guarma` and similar. Nothing
  checks them, so they do nothing. Harmless, but do not copy them expecting an
  effect.
- **That same preset grants none of the seven `manage_*` keys**, so a
  group-based moderator cannot open any domain page.
- **`players.give` maps to `give_item`.** `give_` on its own is not a key anything
  checks, because the code builds the key as `"give_" .. action`.
  `players.giveweapon` / `givemoney` / `givehorse` / `givewagon` cover the rest. `players.*` grants all five.
