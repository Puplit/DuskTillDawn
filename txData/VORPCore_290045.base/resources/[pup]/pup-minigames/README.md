# pup-minigames

A library of minigames (skill bar, skill circle, safe crack, pin code, gold pan and more) that other resources start through exports and get a result back in a callback. It is a modified version of BOII Development's minigames pack.

## Features

- Eleven games: anagram, button mash, chip hack, gold pan, hangman, key drop, pin code, safe crack, skill bar, skill circle and wire cut.
- One export per game, each taking a table of options and a callback.
- Restyled to the black / white / blood-red pup-ui look; one CSS block in `html/css/root.css` holds the whole theme.
- Safe crack can use the native RDR2 dial from qadr-safe when it is running, and falls back to the built-in safe.
- Push-to-talk keeps working while a game holds NUI focus.
- Optional `/test_<game>` commands for trying every game.

## Requirements

- `pup-ui` (push-to-talk helper and the bundled fonts)
- `qadr-safe` (optional; native safe-cracking dial)

## Installation

1. Add `ensure pup-minigames` to `server.cfg` after `pup-ui` and before any resource that uses the games.
2. Turn `Config.General.testCommands` off in `config/main.lua` once you are happy with the games.
3. No SQL and no items are needed.
4. RedM caches NUI pages. If you edit one of the game scripts, bump its `?v=` number in `html/index.html` so players load the new file.

## Commands

| Command | Who | What |
|---|---|---|
| `/test_<game>` (e.g. `/test_skill_bar`, `/test_safe_crack`) | Anyone, only while `Config.General.testCommands` is on | Starts that game with example settings and prints the result to F8 |

## Configuration

### config/main.lua

- `Config.General.testCommands`: register the `/test_<game>` chat commands.
- `Config.SafeCrack.useQadrSafe`: use the native RDR2 dial from qadr-safe when that resource is started; `false` = always use the built-in NUI safe.

### Styles

Every game has its own style templates (colours, icons, sounds) at the top of its script, for example `html/scripts/anagram/anagram.js`. Sounds are optional: set one to `undefined` and nothing plays. The skill bar ships silent because many jobs use it; its stock sounds were `assets/audio/beep.ogg` (success), `assets/audio/glitchy.ogg` (perfect) and `assets/audio/system_fault.ogg` (failed).

## For developers

Every game is a client export: `exports['pup-minigames']:<game>(options, callback)`. Only one game runs at a time per game type; a call while that game is already open is ignored.

**anagram** / **hangman**: callback `(success)`.
```lua
exports['pup-minigames']:anagram({
    style = 'default',
    loading_time = 5000, -- ms of loading sequence
    difficulty = 10,     -- picks the word list (see `word_lists` / `hangman_word_lists` in the game's script)
    guesses = 5,         -- guesses until fail
    timer = 30000        -- ms allowed for guessing
}, function(success) end)
```

**button_mash**: callback `(success)`. `difficulty`: higher = each keypress moves the notch less. The game ends on its own after 50 seconds with no result, so it can never hold focus forever.

**chip_hack**: callback `(success)`. `loading_time` (ms), `chips` (chips to find), `timer` (ms allowed).

**gold_pan**: callback `(score)`, a number from 0.0 to 1.0 rather than pass/fail. Swirl the pan in circles: too gentle and the silt never clears, too hard and the gold washes out; shaking back and forth gets nowhere.

| Option | Default | Meaning |
|---|---|---|
| `duration` | 15000 | ms before the pan is called done |
| `target_min` | 2.2 | rad/s; below this the wash is weak |
| `target_max` | 5.0 | rad/s; above this gold washes out |
| `silt_rate` | 16 | silt % cleared per second at full wash |
| `gold_rate` | 9 | gold % lost per second per rad/s of overshoot |
| `hint` | built-in | hint line; `false` = none |
| `slow_text` / `good_text` / `fast_text` | built-in | live coaching under the hint |

**key_drop**: callback `(success)`. `score_limit` (keys needed), `miss_limit` (misses allowed), `fall_delay` (ms for a key to fall), `new_letter_delay` (ms between keys).

**pincode**: callback `(success)`. `difficulty`: digits in the code (level 1 = 4 digits, level 2 = 5 and so on; the UI fits 10 digits, level 6). `guesses`: guesses before fail. Optional `code` (a caller-supplied code, so something found in the world can reveal digits of the real code) and `hint` (a line shown under the attempts counter).

**safe_crack**: callback `(success)`. `difficulty`: number of locks, 1-5 (with qadr-safe, `pins` or the length of `combination` may set it instead). `attempts`: wrong presses allowed (default 3; 0 or below = unlimited). With qadr-safe running, the numbers are always freshly rolled (0-99), and `backdrop` / `freeze` (both default on) are passed to its dial.

**skill_bar**: callback `('perfect' | 'success' | 'failed')`.

| Option | Meaning |
|---|---|
| `icon` | Any Font Awesome icon; the template icon if none |
| `orientation` | `1` = horizontal centre, `2` = vertical right |
| `area_size` / `perfect_area_size` | Size of the target area in % / size of the perfect area in % of the target |
| `speed` | Speed the target area moves |
| `moving_icon` / `icon_speed` | Move the icon randomly; its speed (divided by 100 in the script, so 3 = 0.03) |
| `end_delay` | ms the result stays on screen (default 1500) |
| `hint` | On-screen hint: `nil` = default wording, `false` = none, a string = your own |
| `scale` | Draw size for this call only: `1` = normal, `0.7` = 70% (zone and timing unchanged) |

**skill_circle**: callback `('perfect' | 'success' | 'failed')`. `icon`, `area_size` (target size as `Math.PI / value`), `speed`.

**wire_cut**: callback `(success)`. `timer`: ms allowed.

## Credits

This resource is based on [boii_minigames](https://github.com/boiidevelopment/boii_minigames) by **BOII Development** (now PlayingInTraffic; the newer version is https://github.com/playingintraffic/mgc), released under the GNU General Public License v3. The original BOII banner comments were taken out of the files; this README and the LICENSE file carry the credit and the licence.

The safe crack sounds `html/assets/audio/safe_lock_1.mp3` to `safe_lock_6.mp3` are by [Fesliyan Studios](https://www.fesliyanstudios.com), used under Fesliyan's free-use terms.

The 12 interface sounds in `html/assets/audio/` (`base`, `beep`, `glitchy`, `knob`, `pull_back`, `put_down`, `reinforced`, `slick`, `small_tip`, `succeeded`, `system_fault` and `through_teeth.ogg`) and the 4 images in `html/assets/images/` (`circuit.jpg`, `circuit.png`, `pwcrack_bg.jpg`, `screen.png`, made in Canva) are inherited unchanged from boii_minigames. Their original source is unknown: upstream does not document it.

Modified by Puppet (Dusk Till Dawn), 2026. Changes made in this version:
- Renamed to `pup-minigames`, restyled to the pup-ui look, and the push-to-talk helper added.
- Added the gold pan game.
- Each game keeps its own "active" flag, so one stuck game cannot block the others.
- Safe crack: attempts (so it can be lost), and an optional qadr-safe backend.
- Pin code: optional caller-supplied code and hint.
- Skill bar: hit detection measures the rendered boxes (icon centre, perfect band as drawn), the icon is kept off the extreme ends, the caller's icon no longer leaks into the shared template, and `end_delay`, `hint` and `scale` options; sounds off.
- Skill circle: wrap-safe hit detection, a visible perfect arc, themed canvas colours and the same icon fix.
- Button mash: a hard time limit with a visible countdown.
- Wire cut: decoy colours that cannot be mistaken for the gold wire, and an M:SS timer.

## License

GNU General Public License v3. See LICENSE.
