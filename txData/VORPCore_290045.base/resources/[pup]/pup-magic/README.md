# pup-magic

Vampire feeding, blood vials that let you wear another character's face, and a staff spell kit, for RedM with VORP. The server checks every feed and every cast; clients only report what was pressed and where they were aiming.

## Features

- **Feeding.** A character whose curse is `vamp` holds the Feed key while focusing a human (an NPC or another player). The victim is put down and drained (never killed), then staggers for a while; nearby NPCs flee. The vampire gets food, water and core boosts through fred_metabolism, and NPC feeds give the items in `Config.Feeding.npcRewards`.
- **Blood vials.** Feeding on a player bottles their blood in a named `blood_vial`. Drinking it makes the drinker look like that character for a while, with a smoke puff on the swap and on the way back. `/bloodtime` shows how long is left.
- **Spell kit.** Characters listed in `server/casters.lua` cast the spells in `config/spells.lua` with Alt plus a key: smoke, lightning, shock, turning someone into a frog, particle auras, an aim marker, an animation and a bomb kit (punch, throw, rocket leap, detonate).
- Refused spell casts are printed to the console and optionally posted to a Discord webhook.

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory`
- `pup_shaman` (optional; decides who is a vampire. Without it the `characters.curse` column is read)
- `vorp_character` (optional; used to turn a frog back and to restore a borrowed face)
- `vorp_animations` (optional; the feeding animations)
- `fred_metabolism` (optional; without it feeding gives no food or water)
- `pup_clothing` (optional; its extra columns are copied with a borrowed face when present)

## Installation

1. Run `sql/install.sql` once. It adds the `blood_vial` item and is safe to run more than once. There are no tables of its own: it reads `characters` and `clothing_extras`.
2. Do a full server restart: vorp_inventory reads the items table only at start-up.
3. Add `ensure pup-magic` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory` and the optional resources you use.
4. Put character ids in `server/casters.lua` for anyone who should cast spells.
5. Optional: set a Discord webhook in `server/config.lua` (server only, never sent to players). Refused spell casts are then posted there as well as printed to the console.
6. To let staff run `/feedcurse` on other players: `add_ace group.admin command.feedcurse allow`.

## Commands

| Command | Who | What |
|---|---|---|
| `/bloodtime` | Anyone | How long a borrowed face has left |
| `/feedcurse [id]` | Anyone for themselves; others need the ACE `command.feedcurse`; console needs an id | Re-reads a player's curse and sends it to them |

## Configuration

### config/main.lua

**Config.General**
- `debug`: `true` gives EVERY player EVERY spell (testing only) and prints spell debug lines in F8.

**Config.Keys**: change the hash only. Each spell's key is set on the spell in `config/spells.lua`.
- `feed`: hold while focusing (right-click) a human to feed (B by default).

**Config.Integrations**
- pup_shaman decides who is a vampire (`characters.curse == 'vamp'`); this resource listens for `pup_shaman:curseChanged` and reads its `GetCurse` export. No setting needed.
- fred_metabolism receives the feeding benefits (`Config.Feeding.benefits`) through `fred_meta:consume`. No setting needed.
- `animations.feed` / `animations.victim`: keys of the vampire's and the victim's animations in vorp_animations' own config.

**Config.Feeding** (only characters cursed `vamp`)
- `radius`: metres to the victim for the Feed prompt.
- `holdMs`: how long the key is held to start feeding, in ms.
- `cooldownMs`: ms between feeds (300000 = 5 minutes).
- `feedMs`: how long the vampire feeds, in ms.
- `victimExtraMs`: the victim stays down this much longer than the vampire.
- `victimDefaultMs`: server fallback victim time if the client sends none.
- `drunkMs`: the victim staggers this long after getting up.
- `scareRadius`: metres; NPCs this close flee. `scareDurationMs`: how long they flee.
- `npcRewards` / `playerRewards`: items given per feed, as `{ name = 'item', count = 1 }`. A player victim also gives a named blood vial (see `Config.Blood`).
- `npcTipMs` / `playerTipMs`: how long `Locale.feedNpcReward` / `Locale.feedPlayerReward` shows (empty text = no tip).
- `benefits.npc` / `benefits.player`: the fred_metabolism `fred_meta:consume` values given to the vampire (hunger, thirst, metabolism, stamina and health inner / gold values).

**Config.Blood** (feeding on a player bottles their blood; drinking it wears their face)
- `item`: item name in the items table.
- `durationMs`: how long the borrowed face lasts (10 minutes by default).
- `warnBeforeMs`: warn this long before it wears off.
- `drinkMs`: drink time before the swap (smoke covers it).
- `maxVials`: vials one vampire may carry at once. `0` = unlimited.
- `sameVictimCooldownMs`: the same victim again within this time gives no vial (30 minutes by default).
- `maxBiteDistance`: metres; the server rejects a bite from farther away.
- `smoke`: smoke burst on drink and on revert (the same particle as the smoke spell). `zOffset` is metres below the player's coords; `viewRange` is the metres other players can see it from.

### config/spells.lua

**Config.Blasts**
- `engineDamage`: `0` = only scripted damage (horses and NPCs are safe).
- `shake`: camera shake strength.

**Config.Spells**: one block per spell, keyed by spell id. Copy a block to add one. A spell with a mistake is removed with a warning at start, so neither side ever acts on it.

| Field | Meaning |
|---|---|
| `key` | `'NUMPAD0'`-`'NUMPAD9'`, `'0'`-`'9'`, `'A'`-`'Z'` or `'F1'`-`'F12'`; or `keys = { ... }` for several. Cast with Alt + key. Two spells cannot share a key |
| `casters` | Caster groups from `server/casters.lua` |
| `effect` | `smoke`, `lightning`, `shock`, `transform`, `aimdot`, `anim`, `aura`, `bombpunch`, `bombtoss`, `rocketleap` or `detonate` |
| `emote` | Optional kit emote played on cast |
| `notif` | Optional message on cast (or `{ on, off }` for toggles and transforms) |
| `requires` | Optional id of an `aura` spell that must be switched on first (the bomb kit requires `pinpull`) |
| `cooldown` | Optional cooldown in seconds |
| `noTarget` | Message when there is nobody to hit |
| `range` | Metres, for `bombpunch` / `bombtoss`; other spells on someone else use `MagicLimits.targetRange` |

Effect-specific fields:
- `smoke`: `fx = { asset, name, radius, duration (s), scale }`.
- `lightning`: `damage`.
- `shock`: `duration` (s), `sparks` (particle name).
- `transform`: `model` (e.g. `'A_C_FrogBull_01'`), `duration` (s).
- `anim`: `anim = { dict, name, dur (ms) }`.
- `aura`: `fx = { dict, name, bone or boneName, off = {x,y,z}, rot = {x,y,z}, scale }`, or a list of those. `self = true` puts it on the caster only. `pop` is an optional blast when it is switched off.
- Blasts (`pop`, `bombpunch`, `bombtoss`, `rocketleap`, `detonate`): `tag` is the explosion type (24 lantern, 25 dynamite, 27 volatile), `size`, `damage` (`0` = knockback only), `radius` and `force`. `bombtoss` has `delay` in ms; `rocketleap` has `launch = { forward, up }`; `detonate` has `ring` (extra blasts in a ring), `ringRadius` and `selfDamage`.

Example:

```lua
lightning = {
    key = 'NUMPAD2', casters = { 'puppet' }, effect = 'lightning',
    emote  = 'KIT_EMOTE_ACTION_SHOOTHIP_1',
    damage = 110,
    notif  = Locale.lightningCast,
},
```

### config/limits.lua

- `targetRange`: metres from the caster for shock, frog, lightning, smoke and auras put on someone else. A spell with its own `range` (bombpunch, bombtoss) uses that instead. `250` = as far as the aim ray reaches.
- `countNpcVials`: `true` = plain vials (from NPC feeds) count against `Config.Blood.maxVials`; `false` = only named vials taken from players count.
- `reloadCommand`: vorp_character's reload command (its `Config.Reload.command`). A frog is turned back with it.

### server/casters.lua

Caster groups, server only. Each group is a list of character ids (`charidentifier`), e.g. `puppet = { 42, 57 }`. Non-integer ids are ignored with a warning. A group named in a spell but missing here is reported at start.

### server/config.lua

Server only, never sent to players:

```lua
MagicSecrets = {
    castWebhook = "", -- Discord webhook for refused spell casts. "" = console only
}
```

A webhook that does not start with `https://` is ignored.

### config/locale.lua

Every message. `%s` and `%d` are filled in by the code; keep them in the text. It loads before `config/spells.lua`, which copies some of these into the spell blocks.

## For developers

Server exports:

| Export | Returns |
|---|---|
| `exports['pup-magic']:EndDisguise(source)` | Nothing; ends that player's borrowed face with the usual message and smoke |
| `exports['pup-magic']:IsDisguised(source)` | `true` while that player wears a borrowed face |

State bags:
- `GlobalState['pup_disguise_<real charid>']` is `true` while a borrowed face is on. vorp_core, vorp_character, pup_realestate and pup_camps check it and do not save that character's look.
- `GlobalState.pup_magic_auras = { ['<server id>'] = { spell ids } }`: the auras currently on. Only the server writes it; each client draws the auras from its own `Config.Spells`.

Events it listens to:
- `pup_shaman:curseChanged (src, key)`: server-local; refreshes that player's curse.

## Credits

Vampire feeding was first based on Jeffy DeTexas' standalone "feed" resource, then rewritten. Some `Config.Feeding` values may still come from its settings.

## License

See LICENSE.
