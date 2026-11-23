# pup_shaman

The supernatural side of a RedM / VORP server: curses, animal forms, ancient trees that send you dreaming as a spirit animal, and tribe rituals that lift or give curses.

## Features

- **Curses.** Each character carries at most one, saved in `characters.curse`. A curse can grant an animal form, run a harmful course that worsens over time, or both. A harmful course keeps going across relogs, because the server stores when it began (`shaman_afflictions`). A cure item can lift a curse, and some curses lift on death.
- **Animal forms.** `/wolf`, `/bear`, `/bat`, `/cat` for carriers of the matching curse. Hold B or type `/human` to return. The wolf can howl, sit and attack; the bear can attack. A strike may pass the curse on if the curse is set to spread.
- **Ancient trees.** Eat the fruit, or give it to the person beside you, and you dream as a spirit animal somewhere far off until `/wakeup`. Some trees bind their curse to whoever eats.
- **Rituals.** Tribe members of a high enough rank lead The Unbinding to lift a curse. At the top rank they can also lead The Binding, which gives a curse to a willing person who carries none. The person must agree first. The leader burns an offering and walks a ring of marks around a fire; the chant then runs as a skill bar, one verse per line, and ranked bystanders may join to widen it. The ceremony is invented for this server and is not any real people's practice.
- **Staff tools.** vorp_admin's Curses page lists carriers and can give, ease or cleanse curses through this resource's exports. vorp_admin checks its own permission (`manage_curses`) and does the Discord logging.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- Optional: `pup-minigames` (ritual skill bar), `pup-bloodmoon` (blood moon bonus), `pup-misc` (vision instances, off by default), `vorp_character` (its `rc` command rebuilds the human body)

## Installation

1. Put `pup_shaman` in your resources folder.
2. Run `sql/install.sql`. It creates `shaman_afflictions` and adds the `curse_cure` item. The resource also checks its schema on every start and adds the `characters.curse` column itself if it is missing (the matching `ALTER TABLE` is in the file, commented out, if you prefer to run it by hand).
3. Add an image for `curse_cure` to `vorp_inventory/html/img/items/`, plus any offering or reward items you configure.
4. Add `ensure pup_shaman` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui`.
5. No webhooks or keys are needed: this resource sends no Discord logs.

## Commands

| Command | Who | What |
|---|---|---|
| `/wolf [coat] [mp]` | lycan carriers | become a wolf (coat 0 to 12; `mp` uses the alternative model) |
| `/bear`, `/bat`, `/cat` | matching carriers | take that form |
| `/human` | in a form | return to your body (or hold B) |
| `/wakeup` | dreaming | wake from a vision |
| `/ritual` | tribe ranks that may lead | open The Old Ways menu |
| `shaman_howl` (Y), `shaman_sit` (H), `shaman_attack` (G) | in a form | rebindable ability keys |

## Configuration

### config/main.lua

Every value is read by both the client and the server unless noted.

- `Config.Debug`: extra console tracing (unknown curse keys, refused requests).
- `Config.ActionKey` / `Config.ActionKeyLabel`: the key used at trees and in rituals (G).
- `Config.BloodMoon`: `enabled` and `resource`. While pup-bloodmoon's blood moon is up, forms grow and strike harder (see `bloodMoon` in `config/forms.lua`).
- `Config.Instances`: put each dreamer in their own routing bucket during a vision (needs `pup-misc`). `offset`: bucket = server id + offset.
- `Config.Shift` (animal forms):
  - `invincible`: forms cannot be hurt.
  - `timeLimitMinutes`: 0 = no limit.
  - `cooldownSeconds`: between accepted shifts, per server id. A model that never loads does not cost the cooldown.
  - `returnCommand`, `returnKey`, `returnKeyLabel`, `returnHoldMs` (how long the return key is held, in ms).
  - `jumpControl`: the control disabled for forms marked `noJump`.
  - `fadeMs`, `modelTimeoutMs`, `pedTimeoutMs`: screen fade and load timeouts, in ms.
  - `minSize` / `maxSize`: limits for the ped scale.
  - `humanTimeoutMs`: how long to wait for vorp_character's rebuild of the human body; `rebuildCommand` is that command (`rc`).
  - `weaponsBackMs`: extra wait before ammo writes resume after returning to human.
  - `sizeReapplyMs`: the size is set again this many ms after a change, because the game drops a size set on a ped that is still being built.
  - `disabledControls`: controls disabled in a form and while dreaming.
  - `serverHour`: for night-only forms the server needs the in-game hour. Set it to a function that returns the hour (0-23) from your time-sync resource, or leave it `nil` to use the hour the client reports. No form is night-only by default.
  - `struckShake`: camera shake for a player who is struck.
  - `attackDefaults`: attack values used when a form's attack leaves one out (`range` in metres, `damage`, `cooldownSeconds`, `ragdollMs`).
  - `attackSlack`: metres the server allows beyond the attack range.
  - `attackResendMs`: the client ignores attack presses this soon after the last one.
- `Config.TreeRules` (all trees):
  - `jobLock`: only the tree's jobs (or carriers of its curse) can use it. `blipJobs`: jobs that see tree blips while the lock is on.
  - `propDistance`, `reach`, `giveRange`: metres. `reachSlack` and `giveSlack` are the extra metres the server allows.
  - `wakeCommand`: the wake-up command.
  - `cooldownMinutes`: per character, per tree.
  - `startTimeoutSec`: a vision the client never confirms is cleared after this.
  - `collisionWaitMs`: wait for the far place to load before the swap.
  - `returnAfterJoinMs`: after a reconnect mid-vision, wait this long past the spawn before moving the player back to the tree.
  - `pick`, `fruit`, `bite`, `give`, `blip`: animations, prop and blip style.
- `Config.CureDrink`: the prop and interaction played when a cure item is used (`ms` = duration).

### config/curses.lua

The curse keys are saved on characters and read by other resources: never rename them. A new curse needs only a new block in `Config.Curses`:

| Field | Meaning |
|---|---|
| `label` | what players and staff see |
| `form` | key in `config/forms.lua` the curse lets its carrier take (nil = none) |
| `course` | key in `Config.Courses` it runs (nil = harmless) |
| `cure` | usable item that lifts it (nil = none) |
| `liftOnDeath` | any death of the carrier lifts it |
| `spreadChance` | 0 to 1 chance a strike by its form passes it on (nil or 0 = never) |

Example: `ghoul = { label = 'Ghoul', course = 'wasting', cure = 'curse_cure', liftOnDeath = true },`

`Config.Courses` holds harmful courses. The server tracks how many seconds a course has run; that is divided into steps of `stepSeconds`.

- `effect = { after = step, name = 'screen effect' }`: full-screen effect after that step.
- `walk = { after = step, dict, clip }`: sick upper-body idle after that step.
- `drain = { after = step, share = fraction }`: each step after that loses `share` of max health.
- `lethal`: whether the drain can kill. If not, health never drops below `floor` (and is never raised to it).
- `easeToStep`: easing (by ritual or staff) rewinds the course to this step.

### config/forms.lua

Form keys (`wolf`, `bear`, `bat`, `cat`) are replicated in the `pup_form` state bag: never rename them. pup-bloodmoon recognises the wolf by `A_C_Wolf` and `MP_A_C_WOLF_01`, so keep those as the wolf's models.

| Field | Meaning |
|---|---|
| `command` | chat command that takes the form |
| `label` | name shown to the player |
| `model` / `altModel` | `altModel` is used with `/wolf <coat> mp` |
| `defaultCoat` / `maxCoat` | coat used when none is given / highest coat (nil = no upper limit) |
| `size` / `coatSizes` | ped scale, optionally per coat |
| `nightOnly` + `night` | only between `night.from` and `night.to` (in-game hours, may wrap midnight) |
| `bloodMoon` | `{ size = factor, damage = factor }` while the blood moon is up |
| `noJump` | jumping disabled |
| `abilities` | `howl`, `sit` and `attack` (dict, clip, ms; attack also takes `range`, `damage`, `ragdollMs`, `cooldownSeconds`) |

`Config.AbilityKeys` maps the ability commands to default keys. Keep the command names: players' rebinds are tied to them.

### config/trees.lua

Each tree in `Config.Trees`:

| Field | Meaning |
|---|---|
| `name`, `coords`, `prop` | tree name, position and prop model |
| `sink` | metres the prop is pushed into the ground |
| `jobs` | who may use the tree while `Config.TreeRules.jobLock` is on |
| `curse` | curse the tree binds to someone who eats its fruit and carries none (nil = none) |
| `blip` | show a map blip (only to `Config.TreeRules.blipJobs` while the job lock is on) |
| `reward` | `{ item = 'name', label = 'Label', count = 1, minutes = 10 }` given on waking after a dream of at least `minutes` (nil = none) |
| `destinations` | where the spirit wakes; one is picked at random |
| `visions` | `{ label, model, filter, minutes }`: `filter` is an animpostfx (nil = none), `minutes` nil = until the wake command |

### config/rituals.lua

- `Config.Ritual`:
  - `enabled`, `command`.
  - `needTree` / `treeReach`: must begin within that many metres of an ancient tree.
  - `beginRange` (leader to the person), `stayRange` (everyone to the fire, also the join range), `viewRange` (scene sent to players this close): metres.
  - `answerSeconds`, `kindleSeconds`, `circleSeconds`, `verseSeconds`, `drawSeconds`: stage timings in seconds.
  - `marks`, `ringRadius`, `markReach`, `markSlack`, `markResendMs`: the ring of marks walked around the fire (metres, ms).
  - `maxHelpers`: bystanders who may join. Each helper widens the skill bar zone by `helperWidth`, up to `widestZone`; `perfectZone` is the size of the perfect zone.
  - `points`: score per verse for perfect, success and failed answers. `liftAt`: total strength needed to lift or bind. `easeAt`: strength needed to ease a harmful curse.
  - `backlash`: what a failed ritual does to the leader (`share` of max health, `floor`, `ragdollMs`, `effectMs`).
  - `verseMinMs` / `perfectMinMs`: the skill bar answer is checked against how long the verse took. Faster than `verseMinMs` scores 0; a "perfect" faster than `perfectMinMs` counts as a success.
  - `chant`: the chant lines for `unbinding` and `binding`, one verse per line. A tribe may override either with its own `chant = { unbinding = {...}, binding = {...} }`.
  - `look`: animations, props, marker, light, screen effects, sound, skill bar style and toast.
- `RANKS`: shared by every tribe by default. Each rank has a job `grade`, a `title`, whether it may `lead`, `cooldownMinutes` between rituals, the curses it may `lift` and `give`, and the skill bar `barWidth` and `barSpeed`. A tribe can use its own list instead of `RANKS`.
- `Config.Tribes`: one block per job. `lift` and `bind` each have a `price` (cash the person pays the leader if the ritual works) and an `offering` list of `{ item = 'name', label = 'Label', count = n }` burned at the start. A tribe without a bind price uses its lift price for the binding. Example:

```lua
mytribe = {
    label = 'My Tribe',
    lift = { price = 0, offering = { { item = 'herbmed', label = 'Herbal Remedy', count = 1 } } },
    bind = { price = 0, offering = { { item = 'herbmed', label = 'Herbal Remedy', count = 3 } } },
    ranks = RANKS,
},
```

### shared/locale.lua

Every player-facing line. `%s` and `%d` are filled in by the script.

## For developers

Server exports:

| Export | Returns |
|---|---|
| `GetCurse(src)` | curse key, `''` for none |
| `SetCurse(src, curse)` | `true`, or `false` without a character or for an unknown key |
| `ClearCurse(src)` | `true` |
| `IsTransformed(src)` | form key or `false` |
| `AdminList()` | `{ curses, players, offline }` for vorp_admin |
| `AdminAction(action, data)` | `ok, message` for vorp_admin (`give`, `cleanse`, `ease`) |

Events:
- `pup_shaman:curseChanged` (server-local): `src, curseKey` (`''` for none).
- `pup_shaman:client:curseUpdated` (client-local): `curseKey`.
- `pup_shaman:howled` (client-local): the wolf howled.

State bags on the player (replicated, absent when none): `pup_curse` (curse key) and `pup_form` (form key).

## License

See LICENSE.
