# pup_staffdesk

A staff desk for RedM / VORP. Players visit a counter in town to collect what staff leave for them, pay for character changes, spend bug bounty points and check their playtime, and staff can do most of it from a Discord channel too.

## Features

- **Parcels:** staff leave cash, items or weapons for one character (by charid) or for a whole Discord account. Players collect them at any desk, one at a time or all at once.
  - A parcel can only be collected once, even with double clicks or two characters on one account.
  - If the satchel only has room for part of a stack, the player takes what fits and the rest keeps waiting.
  - The player gets a tip if online, and a letter through `pup_postoffice` if it is running.
- **Character changes** (paid, checked on the server):
  - Height, with a short preview before paying.
  - Name, with capitalisation fixed for you ("o'brien" becomes "O'Brien"), blocked words, an optional unique-name rule and a cooldown.
  - Pet whistle names (needs `pup-misc` pets).
  - Weapon names and descriptions, with a cooldown per weapon.
- **Bug bounty:** staff award points for reported bugs; players spend them on rewards. Every change is kept in a history, balances never go below 0 and two clicks cannot spend the same points.
- **Playtime:** counted a minute at a time per character and written to `characters.hours`. Optional milestone rewards.
- **Staff tab:** send parcels, see and cancel waiting parcels, award or take points, see who is online.
- **Discord bridge:** staff type `!commands` in one channel and the server runs them. Look-ups only show sections whose tables exist, so they work on any server. Every action can be written to an audit table.
- On first start, data from the older recomp station (`recomps`, `bug_points`, `recomp_namecd`) is copied in once. The old tables are only read, never changed.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- Optional: `pup_postoffice` (letters), `pup-misc` (pet naming), `vorp_character` with `RefreshHeight` (height applies without a relog)
- Optional for the Discord look-ups: tables from `pup_business`, `pup_camps`, `pup_mercantile`, `pup_ranchero` and `pup_realestate`

## Installation

1. Put `pup_staffdesk` in your resources folder.
2. Run `sql/install.sql` on your database. It creates the `staffdesk_*` tables and adds the bounty reward items (`cane`, `clamp01`, `club03`, `club06`, `crowbar01`, `pup_cane_wood`, `pup_cigar`, `shovel_weapon`, `bread`). The resource also creates its tables on start, so the tables part is optional; the items are not.
3. Add item images for those items to `vorp_inventory/html/img/items/` if you do not have them already.
4. Fill in `server/config.lua` (see below). It is loaded only on the server and never sent to players.
5. Add `ensure pup_staffdesk` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui`.
6. Give staff access in one of two ways:
   - a VORP group listed in `Config.Staff.groups` (default `admin`), or
   - the vorp_admin permission named in `Config.Staff.permission` on their role. It can create cash and items, so give it with care.

### server/config.lua

| Field | Meaning |
|---|---|
| `Webhooks.log` | Discord webhook URL for the desk's log (parcels, renames, bounty, bridge actions) |
| `Discord.botToken` | bot token, from https://discord.com/developers/applications -> your app -> Bot -> Token |
| `Discord.channelId` | the channel the bot reads commands from and answers in |
| `Discord.guildId` | your Discord server id (needed for role checks) |
| `Discord.users` | Discord user ids allowed to run commands, e.g. `{ '123456789012345678' }` |
| `Discord.roles` | Discord role ids allowed to run commands. With `users` and `roles` both empty the bridge stays off, so it can never be open to everyone in the channel |
| `Discord.banUsers` / `Discord.banRoles` | who may use `!ban` and `!unban`. With both empty, everyone allowed by `users` / `roles` may |

Blank values switch the matching feature off. The bot needs **Read Message History** and **Send Messages** in the channel, and the **Server Members Intent** if you limit commands to roles.

## Commands

| Command | Who | What |
|---|---|---|
| `/staffdesk` | staff | open the panel anywhere (with the staff tab) |
| `/parcel <charid\|discordid> cash <amount> [note]` | staff | leave cash |
| `/parcel <charid\|discordid> item <name> <count> [note]` | staff | leave an item stack |
| `/parcel <charid\|discordid> weapon <HASH> [note]` | staff | leave a weapon |
| `/parcels [charid\|discordid\|word]` | staff | list waiting parcels |
| `/bounty add\|take\|check <charid> [points] [reason]` | staff | bug bounty points |
| `/rename <serverid> <first> <last>` | staff | free rename with no cooldown, for fixing names |
| `/recomp`, `/addPoints`, `/removePoints`, `/checkPoints` | staff | older command names, only with `Config.Staff.legacyCommands = true` |
| `/playtime` | everyone | your hours on this character and the whole account |
| `deskcmd <line>` | server console | run a Discord bridge command without Discord (answers go to the channel) |

Command names (except the older ones and `deskcmd`) can be changed in `Config.Staff.commands` and `Config.Playtime.command`.

### Discord commands

Type `!help` in the channel for the live list. With the default `!` prefix:

- **Parcels and points:** `!parcel`, `!parcels`, `!cancel <id>`, `!points <charid> [+n|-n] [reason]`, `!recomp <discordid> <cash|item|weapon> <value> [count]`
- **Give now (player online):** `!givecash`, `!giveitem`, `!givewep`
- **Player:** `!online`, `!res`, `!hp`, `!tp <id> <spot|x y z>`, `!kick`, `!setjob`, `!namechange`
- **Look up:** `!bank`, `!info`, `!inv`, `!playtime`
- **Organisations:** `!society`, `!camp`, `!ranch`
- **Spawn codes:** `!items <search>`, `!ammo`, `!weapons` (rebuilt every 15 minutes, or with `!items reload`)
- **Bans (needs `vorp_admin`):** `!ban`, `!unban <ban id>`, `!banlist [page|search]`, `!baninfo <ban id|discord|steam:hex>`
- **Other:** `!audit`, `!help`

#### Bans

The bans are vorp_admin's (`admin_bans`, checked when a player connects), so a ban from Discord and one from the admin panel are the same record, with the same ban id the player sees.

- `!ban <who> <length> <reason>`
  - `<who>` is a server id (online), `char:<charid>`, a Discord id or mention, or `steam:<hex>`. An offline player is banned by their steam and Discord ids; vorp_admin adds their licence and hardware tokens from their last connect.
  - `<length>` is `30m`, `12h`, `7d`, `2w` or `perm`.
  - Example: `!ban char:42 7d combat logging`
- `!unban <ban id>` lifts it and keeps the record, so a repeat offence reuses the same ban id.
- `!banlist` shows the bans in force, newest first, 8 per page: ban id, player, character, Discord id, reason, who banned them and when, when it ends and the offence number. `!banlist 2` is the next page; `!banlist <name or id>` searches.
- `!baninfo <ban id|discord|steam:hex>` shows one ban in full, including lifted ones and who lifted them.

To announce bans and unbans publicly, fill in `bansPublic` in vorp_admin's `server/config.lua`.

## Configuration

### config/main.lua

- **Config.General**
  - `deskDistance`: how close a player must stand to a desk, in metres.
  - `imagePath`: where item pictures for the panel are loaded from.
  - `logAvatar`: avatar URL for webhook log posts (`''` uses the webhook's own).
- **Config.Keys.open**: the prompt key hash (default `0x760A9C6F`, G). Change the hash only.
- **Config.Staff**
  - `groups`: VORP user groups counted as staff.
  - `permission`: anyone holding this vorp_admin permission also counts as staff.
  - `commands`: the names of `/staffdesk`, `/parcel`, `/parcels`, `/bounty` and `/rename`.
  - `legacyCommands`: also answer the older `/recomp`, `/addPoints`, `/removePoints` and `/checkPoints`.
- **Config.Desks**: where the panel opens. Each entry is `key = { name = 'Map label', coords = vector3(x, y, z), blip = spriteHash }`; `blip = nil` shows no blip. To add a desk, add a line such as
  `tumbleweed = { name = 'Staff Desk', coords = vector3(-5512.0, -2937.0, -2.0), blip = -426139257 },`
- **Config.Parcels**
  - `maxCash`: the largest cash parcel staff may send in one go.
  - `maxItems`: the largest item stack in one parcel.
  - `noteLength`: the longest note on a parcel, in characters.
  - `mail`: send a letter when something is waiting (`enabled`, `fromName`; needs `pup_postoffice`).
- **Config.Height**: `enabled`, `price` (cash), `min` / `max` (ped scale, 1.0 = normal), `previewSeconds` (how long "Preview" shows the new height before paying).
- **Config.Rename**: `enabled`, `price` (cash), `cooldownDays` (days between renames of the same character, 0 = none), `minLength` / `maxLength` (per name), `unique` (refuse a first + last name another character already has), `blocked` (words refused anywhere in a name, case ignored).
- **Config.PetName**: `enabled`, `price`, `cooldownDays` (per pet). Needs `pup-misc` pets; the name is written onto the whistle the player carries.
- **Config.WeaponName**: `enabled`, `price`, `cooldownDays` (per weapon), `maxNameLength`, `maxDescLength`.
- **Config.Bounty**: `enabled` and `rewards`. Each reward is `{ item = 'inventory_item', label = 'Shown name', cost = points, maxHeld = n }`. `cost = 0` hides the reward; `maxHeld` refuses the purchase if the player already carries that many. Example:
  `{ item = 'bread', label = 'Bread', cost = 10, maxHeld = 5 },`
- **Config.Playtime**
  - `command`: the playtime command name.
  - `milestones.enabled` and `milestones.list`: each entry is `{ hours = n, cash = n, items = { { name = 'item', count = n } }, note = 'text' }`. A milestone pays a parcel when a character crosses the mark while playing. Hours played before milestones were switched on never pay out, so turning them on later is safe. Each milestone pays once per character, even across restarts.

### config/discord.lua (server only)

- `enabled`: master switch. The bridge also stays off while the token or channel in `server/config.lua` is blank.
- `prefix`: command prefix (default `!`).
- `intervalSeconds`: seconds between channel reads.
- `reply`: post each command's result back into the channel.
- `audit`: keep every command in the `staffdesk_audit` table.
- `spots`: named places for `!tp`, as `name = { x, y, z, heading }` (the older `{ x = ..., y = ..., z = ..., h = ... }` form still works). The defaults are a town centre or sheriff's office in each town: `valentine`, `annesburg`, `vanhorn`, `saintdenis`, `rhodes`, `blackwater`, `strawberry`, `riggs`, `armadillo`, `tumbleweed`.

### config/weapons.lua

`Config.WeaponLabels` maps a weapon hash name to its display label, used in menus, logs and the Discord give-weapon command. Only weapons listed here can be sent or given. Add one as `WEAPON_LASSO = "Lasso",`.

### config/locale.lua

Every word players and staff see. `%s` and `%d` are filled in by the script, so keep them when translating.

## For developers

Server exports:

```lua
exports.pup_staffdesk:SendParcel({ charid = 12, kind = 'item', name = 'bread', amount = 5, note = 'Thanks!', by = 'My Script' })
exports.pup_staffdesk:SendParcel({ discordid = '123456789012345678', kind = 'cash', amount = 50 })
exports.pup_staffdesk:GetBountyPoints(charid)                 -- points
exports.pup_staffdesk:AddBountyPoints(charid, delta, reason, by)
exports.pup_staffdesk:GetPlaytime(charid)                     -- hours
exports.pup_staffdesk:ModifyCharName(serverId, first, last)   -- no price, no checks beyond a valid name
exports.pup_staffdesk:AddDiscordCommand('ping', { group = 'MY SCRIPT', usage = '', help = 'Replies pong' },
    function(args, who) return true, 'pong' end)
```

`SendParcel` takes `kind = 'cash' | 'item' | 'weapon'` and either `charid` or `discordid`. A Discord command handler returns `ok, text`; the text is posted as a reply.

Server event: `pup_staffdesk:recfromdiscord (content, args, who, msg)` fires for every bridge command line that passes the permission check, known or not, so other resources can listen for their own words.

Tables: `staffdesk_parcels`, `staffdesk_bounty`, `staffdesk_ledger` (point history), `staffdesk_renames` (cooldowns), `staffdesk_milestones`, `staffdesk_audit`. The desk also writes these VORP columns: `characters.firstname`, `lastname`, `skinPlayer` (height), `hours`, `job` and `jobgrade`.

## License

See LICENSE.
