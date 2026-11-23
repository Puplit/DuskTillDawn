# pup-events

A seasonal event framework for RedM / VORP. The server owns the clock and decides when each event is live; it ships with three events: Dead of Night (Halloween), The Purge and The Spring Hunt (Easter).

## Features

- **Server-owned schedule:** every few seconds the server checks each event's saved date window and the in-game hour from `weathersync`, then broadcasts the on/off state to everyone, so nothing drifts between players. Dates are saved from the vorp_admin Events page; an event with no dates saved only runs while staff force it on.
- **Announcements** when an event opens and closes. Starting or restarting the resource never notifies anyone, and open and close lines are rate limited, because the in-game clock runs far faster than real time and an hour window opens and closes several times a real day.
- **Blood moon:** events can raise `pup-bloodmoon` for their whole window. It is put back if it drops while the event is still live, and lowered when the resource stops so `weathersync` is never left suspended.
- **Dead of Night** (midnight to 5 AM in game):
  - **UFO** at Hani's Bethel and Mount Shann: rises out of the ground and holds above the site.
  - **Van Horn lighthouse:** a swept beam drawn from a long way off, no prop to stream.
  - **Bats** circling the towns (scenery, they never attack).
  - **Trick or Treat:** knock on house doors for a sack of sweets, cash, props and rare weapons, or for a trick: mimics that copy the knocker's own face and come at them with a machete. Each round picks fresh doors, each character gets a limited number of knocks per round, and each door has a per-character cooldown.
- **The Purge** (normally forced on by staff):
  - Blood moon and storm weather for the whole event, and a siren broadcast to everyone when it goes live (needs `xsound` and your own siren file, see `siren.file`).
  - Shove, tackle, choke and grapple are off for everyone; head hits land as ordinary damage instead of instant kills.
  - **Posse:** members see each other on the map and your shots cannot hurt them.
  - **Loot caches:** one at a time, announced in chat. Players need a lockpick, beat a minigame, then pry the crate open. Cash goes to whoever cracked it and the items stay in the crate for the crew, which stays open for a while. Sites can be defended by guards.
- **The Spring Hunt:** egg patches are rolled at random inside broad regions every reset, with rabbits and a map blip for each area. Eggs in water or off the walkable ground are skipped. Picking up eggs gives normal or (rarely) golden eggs; opening one gives weighted loot. Golden egg finds and openings can go to Discord.
- **Admin panel exports** for the vorp_admin Events page: status, saved windows, force on/off and setting the in-game hour.
- **`/eventhere`** prints the spot you stand on, ready to paste into a config, and appends it to `coords.txt`.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `weathersync`
- `pup-bloodmoon` (optional; the blood moon for events with `bloodMoon = true`)
- `pup-ui` (progress bars for the knock and the cache pry, and the posse list for purge posses)
- `pup-minigames` (optional; purge cache minigames)
- `lockpick` (optional, included in `[standalone]`. It is the pin-and-tension purge cache game; `safe_crack` from pup-minigames stands in when it is not running)
- `xsound` (optional; the purge siren)
- `pup-misc` and `pup-medical` (optional; their purge status is shown on the admin page, and pup-misc's brawl knockout is paused while Trick or Treat mimics are out)
- `vorp_admin` (optional; the Events page and its `open_menu` permission)
- A stream resource providing the custom Easter egg models `easteregg1` to `easteregg8` (not included). Without it no eggs spawn, and the client warns once in F8.

## Installation

1. Put `pup-events` in your resources folder.
2. Run `sql/install.sql`. It creates `event_windows` (saved date and hour windows per event) and `easter_limits` (Spring Hunt per-character pickup counts per patch, cleared every reset); the server also creates both on start. It adds the Spring Hunt eggs, the Trick or Treat sweets and the other items the loot tables give or use, and `fred_consumables` rows for the five sweets (that last section needs `fred_metabolism`). A few loot items are not inserted and must be added yourself if you use them: `bm_cross_necklace`, `puffofbadmanners`, `sipofbadmanners`, `pinchofbadmanners`, `dragofbadmanners`. Safe to run more than once. Do a full server restart afterwards, because vorp_inventory caches items.
3. Add inventory images for the new items.
4. For Discord logs, set the webhook URLs in `server/config.lua`.
5. Ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure weathersync
   ensure pup-bloodmoon
   ensure pup-events
   ```
6. Save each event's dates on the vorp_admin Events page, or use `/event on <key>`.

## Commands

| Command | Who | What |
|---|---|---|
| `/event` | admin groups, or vorp_admin `open_menu` | Status of every event and the current in-game hour |
| `/event on <key>` | same | Force an event live, ignoring the schedule |
| `/event off <key>` | same | Force it off |
| `/event auto <key>` | same | Put it back on its schedule |
| `/eventhere [note]` | anyone (writing to `coords.txt` is staff only) | Print your position to F8 as a `vector4` line and a bat-town `centre =` line |
| `/purgesirentest` | staff | Play the purge siren now, to check the file decodes |

`<key>` is the table key in `Config.Events`: `deadofnight`, `purge` or `easter`.

## Configuration

### config/main.lua

- `Config.General`
  - `debug` - `true` = print debug info to the server console.
  - `command` - staff command: `/event on|off|auto <key>`, or no arguments for the status.
  - `adminGroups` - VORP groups allowed to use the command and the vorp_admin Events page actions.
  - `adminPermission` - vorp_admin permission key, checked as a fallback.
  - `tickSeconds` - how often the server re-checks whether an event should be running (minimum 5).
  - `announceCooldownMinutes` - an event's open or close line is sent at most once per this many real minutes.
- `Config.Keys` - change the hash only.
  - `easterPickup` - G: pick up an Easter egg (hold).
  - `purgeCache` - G: force a purge loot cache.
  - `trickOrTreat` - control name (hashed in code): knock on a door (hold).
- `Config.Logs` - Discord embed styling; the webhook URLs are in `server/config.lua`.
  - `serverName` - shown in the embed footer.
  - `easter.pingEveryone` - `true` = @everyone on a golden egg find. `colorGold` / `colorOpenGold` - embed colours for a golden egg found / opened.
  - `trickOrTreat.pingEveryone` - `true` = @everyone on a weapon draw. `colorTreat` (sack opened), `colorRare` (weapon drawn), `colorTrick` (pumpkin door), `colorRound` (new round of doors).

### config/events.lua

One entry per event. The key is what `/event` and the vorp_admin Events page use. Dates live on the admin panel (table `event_windows`), not here; with no dates saved an event only runs while an admin forces it on.

Fields:
- `label` - name shown in announcements and on the panel.
- `enabled` - `false` = never starts on its schedule (an admin can still force it).
- `hourFrom` - in-game hour the window opens (0-24); the default for the panel.
- `hourTo` - in-game hour the window closes (0-24); may wrap past midnight.
- `bloodMoon` - `true` = raise pup-bloodmoon for the whole window.
- `openLine` / `closeLine` - shown to everyone when it goes live / ends.

`deadofnight` runs midnight to 5 AM; the UFO, lighthouse, bats and Trick or Treat run inside it. pup-bloodmoon only rises inside its own night window (20:00 to 05:00 by default) and drops itself at its dawn, so if you widen Dead of Night past 05:00, widen pup-bloodmoon's `Config.Night` to match.

`purge` runs all day (0-24), so the blood moon holds for the whole thing rather than lifting at the in-game dawn. Extra settings:
- `posse.blips` - show posse members on the map.
- `posse.noFriendlyFire` - your shots cannot hurt your posse. Hogtie is left alone on purpose.
- `posse.blipSprite` - map blip sprite hash for posse members.
- `siren.enabled` - `false` = no siren.
- `siren.file` - no siren ships with this resource: add your own siren file to `sounds/` (one you have the rights to; .ogg or .mp3 decode most reliably) and put its path here, e.g. `'sounds/siren.ogg'`. Everything in `sounds/` is served. Left blank (or if the file is missing), the purge starts in silence. `/purgesirentest` plays it on demand.
- `siren.volume` - 0.0 - 1.0.

`easter` runs all day: the eggs are the event, not the hour.

Adding another event: add an entry to `Config.Events`, write its own config and client/server files, and gate everything on `EVC.isLive('yourkey')` on the client or `exports['pup-events']:IsLive('yourkey')` on the server.

### config/deadofnight.lua

All local to each client; it runs while `deadofnight` is live. The coordinates are estimates; `/eventhere` prints a ready-to-paste line for a real spot.

- `ufo` - the two sites from the game's sermon.
  - `enabled` - `false` = no UFO.
  - `hourFrom` / `hourTo` - in-game hours inside the event. `nil` = the whole event, so a forced event at any hour still gets the UFO. The clock runs about 30 times real time, so a two-hour window is only about four real minutes.
  - `radius` - metres: how close you must be to see it.
  - `height` - metres: it rises from this far below to this far above the site.
  - `riseSeconds` / `holdSeconds` - seconds the rise takes and how long it holds at the top.
  - `model` - prop model; `nil` = draw only the light.
  - `light` - colour (`r`, `g`, `b`), `range` (metres) and `intensity`.
  - `sites` - `name`, `coords` (vector3) and the `line` shown when you are near.
- `lighthouse`
  - `enabled` - `false` = no beam.
  - `coords` - the lamp.
  - `drawDistance` - metres; seen from a long way off on purpose.
  - `sweepSeconds` - seconds for one full sweep.
  - `beam` - colour, `range` (metres) and `intensity`.
  - `reach` - metres: how far the swept glow is thrown from the tower.
- `bats` - scenery: they circle a town while you are in it and never attack.
  - `enabled`, `model` (ped model).
  - `count` - how many over a town at once (min, max).
  - `drawDistance` - metres: how close you must be to see them.
  - `radius` - metres from the town centre they wheel around (min, max).
  - `height` - metres above the centre (min, max).
  - `lapSeconds` - seconds for one circuit, per bat (min, max).
  - `hourFrom` / `hourTo` - in-game hours inside the event; `nil` = the whole event.
  - `towns` - `name` and `centre` (vector3) of each town they circle. `/eventhere` prints a `centre =` line for this.

### config/tricktreat.lua and config/tricktreat_doors.lua

Trick or Treat runs inside Dead of Night. Knock for a sack, or for the people who live there. The key is `Config.Keys.trickOrTreat`.

- `enabled` - `false` = no Trick or Treat.
- `doorsPerNight` - how many doors are live each round, `{ min, max }`. `nil` = every door is knockable and the per-character cap is what limits a round.
- `knocksPerCharacter` - knocks one character may make in one Dead of Night, rolled per character on their first knock, `{ min, max }`. `nil` = no cap. They are told when they have had their share. The allowance is renewed when the event starts or ends, not by a new round.
- `resetMinutes` - minutes between rounds (fresh doors). Door cooldowns are not cleared by a new round, so `cooldownMinutes` can be longer than this and still hold.
- `detectRadius` - metres: props and blips stream in at this range.
- `promptDistance` - metres: knock prompt range.
- `promptHoldMs` - ms the knock key is held.
- `knock` - the knock itself: turn to the door, rap on it, wait out the bar. Nothing is decided until the bar fills, so the scare lands on the beat. `scenario` (knock scenario), `sound` (knock sound), `seconds` (how long the bar runs), `label` (progress bar text).
- `cooldownMinutes` - minutes, per character per door. Anyone else can knock that door straight after.
- `trickChance` - percent chance a knock goes badly.
- `blips` - `enabled`, `sprite` (blip sprite name, hashed in code), `label` (blip name on the map).
- `props` - props beside the door, one picked at random: `treat` (sacks) and `trick` (pumpkins). The prop shows what is behind the door.
- `treat` - the sack.
  - `rolls` - draws per sack (min, max).
  - `loot` - each entry:
    - `item` - item name; must exist in `items` (or be a vorp_inventory weapon for `kind = 'weapon'`).
    - `amount` - how many (not used for weapons).
    - `chance` - percent; the whole list should total 100 (the server warns at start if not).
    - `kind` - `'item'` (default), `'money'` or `'weapon'`.
    - `once` - a bucket name: only one draw from that bucket per character per night.
    - `announce` - optional line shown to the player when it is drawn.

    Example: `{ item = 'pup_skull', amount = 1, chance = 3, announce = 'It was not a sweet. You are holding somebody.' },`

    The shipped list has common sweets and cash, uncommon pup-misc props, and rare items (2.95% together): the skull cane has its own `once` bucket so it does not eat a blade draw.
  - `weaponOncePerNight` - a character never gets more than one weapon from the sacks a night.
  - `rerollTries` - a prop they already hold (props are limit 1) or a spent `once` bucket is a dead draw: re-roll this many times...
  - `deadDrawPay` - ...then pay this much cash in dollars instead.
- `trick` - mimics: `ClonePed` copies the knocker, so there are no models here.
  - `count` - mimics per trick (min, max).
  - `health` - easily killable on purpose.
  - `sense` - metres: how far they notice you.
  - `stareMs` - ms each one stands wearing your face before it comes (min, max).
  - `noCriticals`, `noRagdoll`, `noShove` - all `false` by default: criticals land, they stagger when shot, and they react to melee.
  - `moveRate` - movement speed (1.0 = normal).
  - `weapon` - always melee, never your own gun.
  - `maxHitFraction` - one blow may never take more than this share of your health.
  - `damageModifier` - their hit strength (1.0 = a full player-strength hit).
  - `gore` - `true` = a bloodied copy.
  - `despawnSeconds` - seconds before it gives up and wanders off.

`config/tricktreat_doors.lua` lists every door that can be knocked, as `vector4(x, y, z, heading)`, grouped by town. The heading faces out so the prop sits on the step. Capture a door with `/eventhere` and paste only the `vector4` line from `coords.txt` (its `centre =` line is for the bat towns). Example: `vector4( -260.21,  843.88, 123.23, 285.0),`

### config/purgecaches.lua and config/purgecache_sites.lua

During the purge one cache at a time turns up and is announced in chat. Every site gets one turn per cycle, in a shuffled order. The key is `Config.Keys.purgeCache`.

- `enabled` - `false` = no caches during the purge.
- `distance` - metres: how close you stand to get the prompt.
- `limit` - inventory slots per cache (0 = unlimited).
- `firstCacheMinutes` - minutes after the purge opens before the first cache (keeps the two announcements apart).
- `respawnMinutes` - minutes between one being cracked and the next appearing.
- `expireMinutes` - minutes an untouched cache waits before the rotation moves on. `0` = never (stalls the rotation).
- `lingerSeconds` - seconds a cracked crate stays open (no tool, no minigame) before it vanishes.
- `minigame` - `'lockpick'` is the pin-and-tension game from the `lockpick` resource (when it is not running, `safe_crack` stands in). Otherwise any pup-minigames export: `safe_crack`, `wire_cut`, `skill_circle`, `skill_bar`, `pincode`, `key_drop`, `button_mash`, `chip_hack`, `anagram`, `hangman`, `gold_pan`. `nil` = no minigame, straight to the pry bar.
- `difficulty` - minigame difficulty.
- `lockpickitem` - item needed to start, lost on failure (checked on the server).
- `pryTime` - ms the crate takes to lever open once the lock gives.
- `guardDefaults` - add a `guards` block to a site and it is defended. One client runs the guards for everyone; the server picks who. A site's `guards` block overrides these: `count`, `radius` (metres from the crate they are posted), `trigger` (metres: a player this close wakes them), `models`, `weapons`.
- `blip` - `sprite` (blip sprite hash) and `scale`.
- `prop` - the crate model; `nil` = blip only, no prop.

`config/purgecache_sites.lua` holds the sites. Add one with `/eventhere` for the coords, then copy a block. Fields:
- `key` - inventory id; must be unique.
- `label` - name in announcements and on the blip.
- `pos` - vector3 of the crate; `0,0,0` = not filled in yet, so it is skipped.
- `heading` - optional, which way the crate faces.
- `snapToGround` - `false` inside an MLO, or the crate drops to the terrain below.
- `minigame` / `difficulty` / `lockpickitem` / `pryTime` - per-site overrides of `Config.PurgeCaches`.
- `guards` - optional `{ count, radius, ... }`: the site is defended (see `guardDefaults`).
- `money` - cash in dollars paid to whoever cracked it; items stay in the crate.
- `items` - `{ name, amount, chance }`: `chance` is a per-item percent, rolled once on first open.
- `weapons` - `{ name, chance }`: separate from items (weapons live in the loadout), name only.

Example:

```lua
{
    key          = 'valentine',
    label        = 'Valentine Cache',
    pos          = vector3(-293.155, 791.560, 118.227),
    heading      = 275.74,
    money        = 250,
    items   = { { name = 'moneybag_small', amount = 2, chance = 80 } },
    weapons = { { name = 'WEAPON_PISTOL_VOLCANIC', chance = 18 } },
},
```

### config/easter.lua

The Spring Hunt. Egg patches are rolled fresh inside the regions every reset, never fixed.

- `itemName` / `goldItemName` - items given for a normal / golden egg.
- `itemAmount` - eggs given per pickup.
- `goldEggChance` - percent chance a picked egg is golden (`0.5` = 0.5%).
- `regions` - broad boxes of walkable land; a patch centre is rolled inside one. Anything landing in water or off-mesh is dropped, so a loose box is fine. Each: `name`, then the two corners `x1`/`y1` and `x2`/`y2`.
- `patches`
  - `count` - patches per reset (min, max).
  - `radius` - metres: eggs scatter this far from a patch centre.
  - `eggs` - eggs per patch (min, max).
  - `minSpacing` - metres: eggs no closer than this to each other.
  - `resetMinutes` - minutes between re-rolls; pickup limits reset with them.
  - `detectRadius` - metres: a player this close gets the eggs streamed in.
  - `pickupLimit` - most eggs one character may take from one patch per reset.
- `blips` - a patch is somewhere new every time, so the blip marks the area, not the eggs. `enabled`, `sprite` (blip sprite name, hashed in code), `label`.
- `rabbits` - `enabled`, `model` (use `a_c_rabbit_01`, not `mp_a_c_rabbit_01`, which renders as an invisible ped), `count` (per patch, min, max), `spawnRadius` (metres from the patch centre), `scale` (1.0 = normal).
- `pickup` - the key is `Config.Keys.easterPickup`.
  - `distance` - metres: prompt range.
  - `validationDistance` - metres: the server rejects a pickup further than this.
  - `promptHoldMs` - ms the key is held.
  - `anim` - the pickup animation: `dict`, `name`, `flag`, `handoffMs` (ms before the egg is handed over), `propRemoveMs` (ms before the held egg prop is removed), `handBone` (bone the egg prop attaches to), `attachOffset` / `attachRotation` (prop position on the bone).
- `eggModels` - egg prop models, one picked at random per egg.
- `normalLoot` - opening a normal egg; weight based (higher weight = more common). Each: `item` (`'money'` pays cash), `amount`, `weight`.
- `goldLoot` - golden egg rewards; a reward the character already owns is re-rolled.

### config/locale.lua

Player-facing text, one table per feature. Change the text, keep the keys. `%s` / `%d` are filled in by the code. Event open and close lines are in `config/events.lua`; per-site and per-loot lines stay with their entries in the data files.

### server/config.lua

Server only, never sent to players. Leave a URL empty to turn that log off. Embed styling is `Config.Logs`.
- Spring Hunt: one webhook for someone finding a golden egg, one for someone opening one and what they got.
- Trick or Treat: one channel for everything.

### coords.txt

Written by `/eventhere` (staff only): each capture is appended with the time and the character's name, followed by a `vector4` line and a `centre =` line to paste into the configs.

## For developers

Server exports:

| Export | Use |
|---|---|
| `exports['pup-events']:IsLive(key)` | `true` while the event is live |
| `exports['pup-events']:PanelSnapshot()` | Everything the vorp_admin Events page draws: each event's window, state and override, plus Dead of Night, Spring Hunt and Purge detail |
| `exports['pup-events']:PanelSetWindow(key, from, to, hourFrom, hourTo)` | Save an event's window. Empty dates clear it (admin-only again). Returns `false, reason` on a bad value. Saving drops any manual override |
| `exports['pup-events']:PanelForce(key, mode)` | `mode` = `'on'`, `'off'` or `'auto'` |
| `exports['pup-events']:PanelSetHour(hour)` | Move the whole server's in-game clock (through weathersync), so an hour window can be reached without waiting |

Server events:

- `pup-events:server:state` `(key, on)` - fired when an event goes live or ends. Hook this rather than polling `IsLive`.
- `pup-events:purgeloot:spawned` `(siteKey)` / `pup-events:purgeloot:despawned` `(siteKey, reason)` - a purge cache appeared / went away.

Client:

- `EVC.isLive(key)` inside this resource, and the `pup-events:state` `(key, on)` client event for other resources.

For the purge status on the admin page, the resource asks `pup-misc`'s `PurgeSearchStatus` and `pup-medical`'s `PurgeDeathStatus` exports when those resources are running.

## License

See LICENSE.
