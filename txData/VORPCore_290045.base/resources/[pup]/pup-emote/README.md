# pup-emote

An emote wheel for RedM / VORP: a few saved emotes on a radial wheel, kept per character. The emotes themselves are played by `pup-misc`; this resource picks and plays them.

## Features

- **Sets and slots:** each character has 4 sets of 4 slots by default, and picks which set is live.
- **Wheel:** opens from a key each player binds in Settings > Key Bindings, or from a fixed key you set.
- **Quick keys:** while you focus a person (another player or an NPC), the live set's slots show as prompts on them, and keys 1 to 4 fire them. Animals (horses included) never get them.
- **Editor:** `/emotes` lets players choose sets, fill slots by category, and choose upper or full body for game emotes.
- Emotes play through `pup-misc`, so its safety checks (hogtied, ragdoll, eating and so on) still apply.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup-ui` (wheel and list menus)
- `pup-misc` with the `PlayScenario` and `PlayAnim` exports (plays the emotes)

## Installation

1. Put `pup-emote` in your resources folder.
2. Ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure pup-ui
   ensure pup-misc
   ensure pup-emote
   ```
3. `sql/install.sql` creates the `emotewheel` table (one row per character). The server also runs it on start, so no manual step is needed. Keep it a single statement for that reason.

No items or webhooks are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/emotes` | anyone | Open the set and slot editor |
| `pupemotewheel` | anyone | Open the wheel. This is the command behind the "Emote wheel" keybind |

## Configuration

### config/main.lua

- `Config.General.command` - chat command that opens the set and slot editor. The wheel itself is a keybind.
- `Config.Keys` - control hashes; change the hash only.
  - `openWheel` - a key that opens the wheel for everybody. `nil` = no fixed key: players bind it themselves in Settings > Key Bindings (the name shown there is `Locale.wheelLabel`).
  - `quickSlots` - the keys that fire the live set's slots 1 to 4 while focusing someone (the number row by default).
- `Config.Wheel`
  - `sets` - number of sets each character has (the server caps it at 16).
  - `slots` - slots per set (capped at 16; quick keys exist for the first 4).

### config/emotes.lua

Everything a wheel slot can hold, grouped into the categories players browse in `/emotes`. Categories show in the order they are written.

**Adding an emote:** copy a line into a category and change it. Every entry needs:

- `id` - a unique name in lower case, letters, digits and `_` only. Saved wheels store this, so never change an id once players use it. The label is free to change.
- `label` - what players see.
- exactly one of these, saying what plays:
  - `kit = 'KIT_EMOTE_...'` - a game emote; can play upper or full body
  - `scenario = 'WORLD_HUMAN_...'` - a scenario; always full body
  - `anim = { dict = '...', name = '...' }` - an animation; always full body. Optional inside `anim`: `flag = 1` (loop) or `0` (once), and `fdict` / `fname` for a female version.

Optional:

- `mode = 'upper'` or `'full'` - kit emotes only: skips the "how should it play?" question.

Examples:

```lua
{ id = 'hat_tip', label = 'Hat Tip',   kit = 'KIT_EMOTE_GREET_HAT_TIP_1' },
{ id = 'mirror',  label = 'Mirror',    scenario = 'WORLD_HUMAN_POCKET_MIRROR' },
{ id = 'drunk',   label = 'Drunk Jig', anim = { dict = 'amb_misc@world_human_drunk_dancing@male@male_b@idle_a', name = 'idle_b' } },
```

**Adding a category:** add a `{ category = 'Name', emotes = { ... } }` block.

Mistakes (a missing id, a duplicate id, nothing to play) are skipped with a warning in F8 or the server console. Wheels saved under the older upper-case labels (such as `HAT TIP`) still load and are rewritten with ids on the next save.

### config/locale.lua

Text players see. Change the text, keep the keys. `%d` / `%s` are filled in by the code. `wheelLabel` is the name shown in Settings > Key Bindings.

## For developers

`shared/emotes.lua` turns `config/emotes.lua` into checked lookups, available on both client and server:

- `EmoteList.categories` - `{ { name = 'Greetings', ids = { 'fancy_bow', ... } }, ... }`
- `EmoteList.byId[id]` - `{ id, label, category, kind = 'kit' | 'scenario' | 'anim', play = <what plays>, mode }`
- `EmoteList.find(saved)` - the entry a saved slot points at, or `nil`

The wheel is stored as JSON in `emotewheel.emotes`, keyed by the VORP character id.

## License

See LICENSE.
