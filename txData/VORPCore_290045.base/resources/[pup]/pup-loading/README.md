# pup-loading

A themed loading screen for RedM / VORP. Everything on it (text, images, music, colours, tips, staff list and new-player guides) is set from one file, and it closes by itself when character select or spawn starts.

## Features

- Title, subtitle and optional logo over a background image or a cross-fading slideshow with a slow zoom.
- Rotating tips, a staff panel and a page-turning guide panel for new players.
- Progress bar driven by the game's real load events, with a fallback creep if the game sends none.
- Optional background music (bring your own track) with pause and volume controls; the volume is remembered between loads.
- Closes on character creation, character select or spawn, with a timer as a backstop so nobody is stuck on it.

## Requirements

- `vorp_core` / `vorp_character` (the screen closes on their character events; it also closes on `playerSpawned` and on the backstop timer)

## Installation

1. Add `ensure pup-loading` to `server.cfg`.
2. Edit `html/config.js`, save and restart the resource. No other file needs touching.
3. Images, music and fonts go in `html/img`, `html/audio` and `html/fonts`. Everything in those folders is sent to players automatically, so new files only need dropping in and naming in `html/config.js`. Avoid spaces and brackets in file names.

## Commands

None.

## Configuration

### config/main.lua

- `Config.WatchdogSeconds`: seconds before the screen closes anyway, in case character select or spawn never fires.

### html/config.js

**Text**
- `title`: big name in the middle.
- `subtitle`: line under the name (`''` = hidden).
- `showRule`: thin gold line between the two.
- `logo.image`: optional logo above the title, e.g. `'img/logo.png'` (`''` = no logo). `logo.height` is a percentage of screen height.

**Colours and fonts**
- `colors.text` (title, tips), `colors.textDim` (subtitle, labels, status), `colors.accent` (progress bar, rule, music meter), `colors.accentDark` (start of the progress bar gradient), `colors.background` (behind the image while it loads).
- `titleFont`: font for the title and labels (`''` = Georgia). Ships with `fonts/oswald.ttf` (title) and `fonts/imfell.ttf` (body text), both SIL OFL 1.1; the licences are next to them.

**Background**
- `images`: `[]` = plain dark background (no image ships with the release), one image = static, several = slideshow.
- `slideSeconds`: time per image in a slideshow.
- `drift`: slow zoom so a still image never looks frozen.
- `darken`: overlay strength. `0` = none, `1` = default, `1.5` = darker.

**Tips**
- `enabled`, `label`, `rotateSeconds`, `randomStart` (start on a random tip each load) and `list` (the tip lines).

**Team** (right-hand panel)
- `enabled`, `label` and `groups`. Each group is `{ rank: 'Admins', names: ['Sam', 'Alex'] }`. Add names in quotes, separated by commas. A group with no names is hidden, and so is the whole panel if every group is empty.

**Guides** (left-hand panel)
- `enabled`, `label`, `rotateSeconds` and `pages`. Each page has a `title`, then any of:
  - `intro`: one line of text
  - `rows`: `{ key: 'I', text: 'what it does' }`
  - `lines`: plain lines of text
- Pages turn by themselves, and players can click the arrows or use the left and right arrow keys. If you change a command in a script, change it here too.

**Progress bar**
- `enabled`, `statusStart` (first status line) and `statuses` (text shown at each loading stage the game reports).

**Music**
- No music ships with this resource. Put your own `theme.mp3` (a track you have the rights to) in `html/audio/` and list it: `tracks: ['audio/theme.mp3']`. With `tracks: []` the screen is silent and the music controls are hidden; a listed file that is missing also hides them.
- `tracks`: one track loops; several play in order.
- `shuffle`: random order for several tracks.
- `volume`: starting volume, 0-100 (players can change it).
- `fadeInSeconds`, `showControls` (pause / volume box, bottom-right).

**Links** (bottom-left, text only)
- A list of `{ label, value }`, for example:
  ```js
  links: [
      { label: 'DISCORD', value: 'discord.gg/yourserver' },
      { label: 'WEBSITE', value: 'example.com' },
  ],
  ```

## For developers

No exports or events. `loadscreen_manual_shutdown` is set in the manifest, so `client/main.lua` closes the screen itself on `vorpcharacter:startCharacterCreator`, `vorpcharacter:selectCharacter`, `vorpcharacter:spawnUniqueCharacter`, `vorp:initCharacter`, `vorp:SelectedCharacter` or `playerSpawned`.

## License

See LICENSE.
