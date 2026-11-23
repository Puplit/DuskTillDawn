# Changes made to third-party resources

Several resources this server runs have no licence, so they are not in this repository. Install each one from its author's page (see the README, "Install these separately"). Then, in `server.cfg`, replace its `# install separately: <name> (see README)` line with `ensure <name>`; a resource with no such line is started by its folder's `ensure [standalone]` / `ensure [maps]`, except vorp_imapviewtool, which needs its own `ensure vorp_imapviewtool`. This server runs modified versions, and this file describes those changes so you can make them yourself.

It contains only instructions and lines written for Dusk Till Dawn, never the original authors' code. Line numbers are approximate.

Unchanged (install as published): **prop_weed**, **macfarlanes_ranch**, **vorp_imapviewtool**.

---

## weathersync (kibook)

Upstream: https://github.com/kibook/weathersync

1. **Ace-gate the admin events** (security). In `server.lua`, replace the block of `AddEventHandler("weathersync:setWeather", setWeather)` ... `AddEventHandler("weathersync:resetWind", resetWind)` lines with:

   ```lua
   -- each admin event needs the same ace as its command
   local EVENT_ACE <const> = {
       setWeather = "command.weather",  resetWeather = "command.weather",
       setWeatherPattern = "command.weather", resetWeatherPattern = "command.weather",
       setTime = "command.time",        resetTime = "command.time",
       setTimescale = "command.timescale", resetTimescale = "command.timescale",
       setSyncDelay = "command.syncdelay", resetSyncDelay = "command.syncdelay",
       setWind = "command.wind",        resetWind = "command.wind",
   }

   local function gated(name, fn)
       local ace <const> = EVENT_ACE[name]
       AddEventHandler("weathersync:" .. name, function(...)
           local src <const> = source
           if src and src > 0 and not IsPlayerAceAllowed(src, ace) then
               print(("^1[weathersync] %s (%s) triggered weathersync:%s without '%s' - denied^7")
                   :format(GetPlayerName(src) or "?", src, name, ace))
               return
           end
           return fn(...)
       end)
   end

   gated("setWeather", setWeather)
   gated("resetWeather", resetWeather)
   gated("setWeatherPattern", setWeatherPattern)
   gated("resetWeatherPattern", resetWeatherPattern)
   gated("setTime", setTime)
   gated("resetTime", resetTime)
   gated("setTimescale", setTimescale)
   gated("resetTimescale", resetTimescale)
   gated("setSyncDelay", setSyncDelay)
   gated("resetSyncDelay", resetSyncDelay)
   gated("setWind", setWind)
   gated("resetWind", resetWind)
   ```

2. In the `weathersync:requestUpdatedAdminUi` handler, return early unless `IsPlayerAceAllowed(source, "command.weatherui")` (console, source 0, is allowed).
3. In `client.lua`, in the sync toggle function, delete the `chat:addMessage` "Weather Sync on/off" message. Other resources (interiors, character creator, blood moon) toggle sync, and the message would spam chat.
4. **Optional pup-ui panel.** This server's version adds a `pupui.lua` client script (its own file, loaded after `client.lua`) and `Config.usePupUi = true`. At the top of the `weathersync:openAdminUi` handler it adds:

   ```lua
   if Config.usePupUi and WeatherSyncOpenPupUi then
       return WeatherSyncOpenPupUi()
   end
   ```

   Without `pupui.lua`, the stock `/weatherui` page works as before. The vorp_admin **Weather** page drives weathersync's server events directly, so it works with the stock resource.
5. **Optional winter pattern.** `config.lua` gained a `Config.winterRdrWeatherPattern` table, used by the winter preset. It is a copy of the RDR pattern with snow states (`snowlight`, `snow`, `blizzard`, `groundblizzard`, `whiteout`) mixed in. Every snow state needs its own exit row, or the weather never leaves it.
6. `permissions.cfg`: there is no functional change. `server.cfg` already grants `group.admin` all commands.

Used by (all guarded, all optional): vorp_character (creator and selection sky), pup-bloodmoon, pup-events (hour windows), pup_homestead (rain watering), pup_realestate (interior weather), pup-camera, vorp_admin's Weather page. Restore `exec resources/[standalone]/weathersync/permissions.cfg` in `server.cfg` after installing.

## poodlechat (kibook)

Upstream: https://github.com/kibook/poodlechat

1. `fxmanifest.lua`: remove `dependency "discord_rest"` (it is optional, and the hard dependency stops chat starting). Add `'@pup-ui/ptt.lua',` as the first `client_scripts` entry, so push-to-talk keeps working while the chat box has focus.
2. `server/common.lua`: make the Discord report and bridge checks also require `GetResourceState('discord_rest') == 'started'`.
3. `client/config.lua`: add a per-command switch, and register each command only when its entry is not `false`:

   ```lua
   ClientConfig.Commands = {
       global = false, me = false, whisper = false, reply = false, staff = false,
       report = true, clear = true, togglechat = true, toggleoverhead = true, mute = true,
   }
   ClientConfig.Suggest = { say = false, nick = true, emoji = false }
   ```

   In `client/client.lua`, wrap each `RegisterCommand` in a helper that checks `ClientConfig.Commands[flag] ~= false`. Do the same for `TriggerEvent('chat:addSuggestion', ...)` with `ClientConfig.Suggest`.
4. `server/config.lua`: this server adds a **job lock**, `ServerConfig.JobLock`. Text chat (Local, Global, `/me`, `/w`) is allowed only for listed jobs (law, medical, press, judges, undertakers, rail) and staff. Staff are recognised by a vorp_admin permission key, the `group` column or a server.cfg ace. The server handler for each channel checks the sender's `characters.job` against the list and refuses with a configurable message.
5. `html/config.js` and `html/index.css`: western colours and fonts only.

Without poodlechat the server has no chat box. Install it, or another chat resource, for chat to work.

## objectloader (kibook)

Upstream: https://github.com/kibook/redm-objectloader (the `objectloader/` folder). Included in this repository at `[objectloader]/objectloader`.

The only change: the console `print` lines in `client.lua` (map added/removed, model missing, restart, entity limit) and the `pi` handler print in `slaxml.lua` were commented out to keep F8 quiet.

`[objectloader]/mymap` holds `example_map.xml`; copy it for your own maps. `server.cfg` runs `ensure objectloader` before `ensure [objectloader]`.

## gravedigging (devchacha)

Upstream: https://github.com/Devchacha01/devchacha-graverobbery (an RSG-Core script that needs ox_lib and ox_target)

This server's version is a VORP port. To reproduce it:

| Original call | Replace with |
|---|---|
| `lib.progressCircle` | `exports['pup-ui']:Progress({ label = ..., duration = ms })` |
| `lib.skillCheck` | `exports['pup-minigames']:skill_bar({...})`, wrapped into a blocking true/false |
| `exports.ox_target:addModel` (gravestones) | scan the object pool for the gravestone models, and add a RedM prompt group (G = rob, B = pray) |
| `lib.notify` | `TriggerClientEvent('vorp:TipRight', src, text, ms)` |
| `lib.callback` | a request event and a finish event: the server checks the shovel, cooldown and distance, reserves the grave, and pays only against its own reservation |
| `lib.locale()` | `Config.Language` strings |
| RSG player/items/money | `vorp_core` and `vorp_inventory` |
| own police job list and blip | `exports['pup-mdt']:SendPoliceAlert(coords, 'Grave robbery reported - ' .. graveyard, false, src or false, graveyard, nil)`, gated on `GetResourceState('pup-mdt') == 'started'` and wrapped in `pcall` |

Lines this server adds:

```lua
-- client: Prospector perk shortens the dig
local ok, res = pcall(function() return exports['pup-perks']:Timed(ms, 'dig_speed') end)

-- server, after a dig
pcall(function() exports['pup_mortician']:WearShovel(src) end)
pcall(function() exports['pup-perks']:Award(src, 'graverob') end)

-- server, rare curse (Config.GraveCurse)
if GetResourceState('pup_shaman') ~= 'started' then return end
if exports['pup_shaman']:GetCurse(src) ~= '' then return false end
return exports['pup_shaman']:SetCurse(src, c.curse)
```

Other changes: night-only digging (`Config.NightOnly`, 22:00-05:00). Cooldowns expire (`Config.CooldownMinutes`). An optional webhook in `server/config.lua`. A witness roll (`Config.Police.AlertChance`, `AlertRadius`) that needs a living NPC nearby. The graveyard name comes from `Config.Graveyards`. The original `shared/items.lua` became `sql/install.sql` (INSERT IGNORE into `items`). Copy `html/images/*` into `vorp_inventory/html/img/items/`.

## miner_lumber (Blue)

Upstream: no public source found. The resource was supplied as `author 'Blue'` with no link.

This server's changes: renamed from `pup_miner_lumber` (its events keep the `pup_miner_lumber:` prefix). The config was reshaped into `Config.Tools`, `Config.Gather`, `Config.Nodes`, `Config.Props` and `Config.NodeDefaults`. `data.lua` moved to shared scripts, so the server can distance-check a gather (10 m). Prop gathers are rate-limited to the minigame's swing time. The swing is `pup-minigames` `skill_bar` (a hard dependency). Durability is kept in item metadata.

Guarded calls this server adds:

```lua
pcall(function() exports['pup-perks']:Award(src, thetype) end)                       -- xp per good swing
local ok, res = pcall(function() return exports['pup-perks']:Bonus(src, 'gather_yield') end)
packed, packLabel = exports['pup-misc']:PackStore(src, thetype, item, count)          -- job pack first
```

vorp_inventory needs `miner_lumber = true` in `ApiGiveIgnore` in `config/config_server.lua`. This server's copy in [vorp_inventory/vorp_inventory/](vorp_inventory/vorp_inventory/) already has it.

## vorp_barbershop (VORP @blue)

Upstream: https://github.com/VORPCORE/vorp_barbershop_lua (no LICENSE file)

This server's version is heavily extended. The menu moved to the pup-ui ink menu (no NUI focus, so the seated ped stays visible), with `dependency 'pup-ui'`. This server adds these files: `client/pup_camera.lua` (chair orbit camera), `client/pup_barberjob.lua` and `server/pup_barberjob.lua` (a barber cuts another player's hair with the `barberscissors` item), `server/pup_pocketmirror.lua` (`pocketmirror` usable item, a portable barbershop), `client/npc_hair.lua` and `client/npc_beard.lua` (story-ped style tables), and `sql/install.sql` (the two items).

Config blocks this server adds: `Config.hairTintCustom`, `Config.hairTintPalettes`, `Config.colourAccess { chairs = false, mirror = true, jobs = { "barber" } }`, `Config.pocketMirror { jobs, price = 10, consume = false, cooldown = 5 }`, `Config.barberJob { range = 2.5, cancelRange = 3.5, inviteTime = 15, freeze = true, price = 0, payBarber = true }`, `Config.hairColours`, `Config.useNpcHair`, `Config.useNpcBeard`, `Config.hiddenNpcHair` and `Config.hiddenNpcBeard`. Face overlays (stubble, brows) and hair tints go through vorp_character's `OverlayInfo`, `OverlayApply`, `OverlayRestore`, `OverlayPayload` and `HairTintInfo` exports, each in `pcall`.

The add-on files are not included in this repository, because they hook into the original `client.lua`.

## vorp_fishing (VORP, refactored by @blackpegasus)

Upstream: https://github.com/VORPCORE/vorp_fishing (no LICENSE file)

- Add `'client/pupmenu.lua'` to `client_scripts` (copy it from any pup resource, e.g. `[pup]/pup-camera/client/pupmenu.lua`), and add `'pup-ui'` to `dependencies`.
- Legendary fish, rolled on the server: add `Config.LegendaryChance = 0.03` and `Config.LegendaryFish = { [legendary model] = regular model }`. In `server/server.lua`, a failed roll turns the catch into the regular variant at 0.6x weight.
- Reject a reported weight above 25 kg.
- XP per catch: `pcall(function() exports['pup-perks']:Award(src, 'fishing') end)`.
- This server adds daily and weekly challenges and a leaderboard (`client/challenges.lua`, `server/challenges.lua`, `config/challenges.lua`, and the `fishing_stats` and `fishing_challenge_claims` tables in `sql/install.sql`). Those files are not included in this repository.

## vorp_walkanim (VORP @outsider)

Upstream: https://github.com/VORPCORE/Vorp_walkanim (no LICENSE file)

- Replace `vorp_menu` with pup-ui. Add `'pupmenu.lua'` (from any pup resource) before `client/client.lua`, add `dependency 'pup-ui'`, and set `PupMenu.OnClose = function() isInMenu = false; DisplayRadar(true) end`.
- `OpenMenu()` opens the walk list directly with `PupMenu.Open(...)`. The clothes sub-menu is not wired, because pup_clothing owns those toggles.
- `sql/install.sql`: `ALTER TABLE characters ADD COLUMN IF NOT EXISTS walk varchar(50) DEFAULT 'noanim';`. The fresh SQL in this repo already has the column.

pup-misc's walk-style commands fall back to setting the style locally when vorp_walkanim is not running.

## vorp_lootnpcs (VORP @outsider31000)

Upstream: https://github.com/VORPCORE/vorp_lootnpcs (no LICENSE file)

- `config.lua`: `Config.useNotifyRight = true`. Delete the gold settings (`canReceiveGold`, `receiveGold`, `chanceGettingGold`, `gold`).
- `server/server.lua`: delete the gold block. Gold is not a loot reward on this server.
- `translation.lua` (English): the "nothing found" lines were wrong. They should read "This person had no money on them.", "This person had no weapon on them." and "This person had no items on them.". Drop `noGold` and `nugget`.
- `fxmanifest.lua`: `vorp_checker 'no'`.
