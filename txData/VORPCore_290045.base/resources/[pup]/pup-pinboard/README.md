# pup-pinboard

Notice boards in every town. Players pin written or picture notices to a cork board, sorted into sections, and the notices expire on their own.

## Features

- A cork board with the town's name plate. Notices are pinned paper; click one to read it large and use the arrows (or the arrow keys) to page through the rest.
- **Sections** as index tabs with counts: For Sale, Buying & Wanted, Jobs & Services, Notices & Events, plus All and Mine. A notice without a section counts as Notices & Events.
- Black ink, gold and parchment styling with western title and serif fonts. Each notice is taped up in its section's colour, and your own carry a red "Yours" seal.
- **PO box** (optional, with `pup_postoffice`): every notice has a fringe of tear-off slips showing the poster's PO box, looked up fresh each time the board opens. **Tear a Slip** gives you the box number ("Write to them with /mail"); the slip disappears for you until the board closes. A poster with no box has no fringe.
- **Search** by words, section or PO box.
- **Pin a Notice**: choose the section (the open tab is preselected), then:
  - **Write a Notice**: pick one of six papers and write it line by line. Each line is a heading or text, aligned left, centre or right.
  - **Pin a Picture**: paste a direct image link (.png, .jpg, .jpeg, .gif or .webp), check it, then pin it.
- **Unpin** on your own notices, and on everyone's for the groups and jobs allowed to.
- Staff in `Staff.pinToAllBoards` choose "This board only" or "Every board in the state" when pinning.
- **Eco Boost** button, driven entirely by another resource (`pup-misc` by default).
- **Esc** closes whatever is open on top, then the board. A half-written notice is only thrown away with Discard.
- The board is lamp-lit at night (20:00 to 06:00 game time).
- Optional Discord log of every pinned notice, posted under a fixed name with no character details.
- Server-side checks: distance to the board (20 m), one post every 10 seconds, a 20 KB limit per notice, URL validation and refused hosts, per-board job restrictions and a cap on active notices per character. The server saves only the fields it knows, whatever the page sends.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup-ui` (its `ptt.lua` keeps push-to-talk working while the board has focus)
- `pup_postoffice` (optional, for PO boxes on notices)
- `pup-misc` (optional, for the Eco Boost button)

## Installation

1. Import `sql/install.sql` (creates `pinboard_posters`). The server also creates the table on start.
   Upgrading a database made before 2026-11-21: run `sql/migrate_2026-11-21.sql` once, with the server stopped. It renames two columns and the keys inside saved notices, and is safe to run again. Until it has run, the server console says so on start and notices cannot be read.
2. For Discord logging, set `Secrets.Webhooks.posters` in `server/config.lua`. Leave it `""` for no logging.
3. Add `ensure pup-pinboard` to `server.cfg` after `oxmysql`, `vorp_core` and `pup-ui` (and `pup_postoffice` / `pup-misc` if you use them).

No items are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/wipenotices` | admin group or server console | Take down every notice on every board |

## Configuration

The whole `Config` table, boards included, and the `Locale` table are sent to the board page when it opens.

### config/main.lua

| Setting | Meaning |
|---|---|
| `Notices.expireHours` | Hours a notice stays up, counted from when it was pinned. Expired notices are pruned every 15 minutes. |
| `Notices.perCharacter` | Notices one character can have up at once across all boards. `0` = no limit. Does not apply to those who may pin to every board. |
| `Notices.kinds` | `{ text = true, picture = true }`. `false` switches that kind off on every board. |
| `Notices.refusedHosts` | Image hosts never accepted, matched anywhere in the URL, e.g. `{ 'example.com' }`. |
| `Staff.takeDownAny.groups` / `.jobs` | VORP groups and jobs that may take down anybody's notice (`true` = allowed). Your own notices can always be taken down. |
| `Staff.pinToAllBoards.groups` | VORP groups that may pin one notice to every board at once. |
| `Staff.pinToAllBoards.characters` | Character names that may do the same, as `['First Last'] = true`. |
| `Command.wipe` | Name of the admin / console command that takes down every notice. |
| `Prompt.key` | Control hash that opens the board when standing next to it (default G). Change the hash only. |
| `Prompt.radius` | Metres from a board at which the prompt appears. |
| `Blip.show` | `false` = no board blips at all. |
| `Blip.sprite` | Blip sprite drawn on every board: a hash, or a `'blip_*'` name. |
| `Blip.scale` / `Blip.label` | Blip size and map name. |
| `Screen.toastMs` | How long a message stays on screen, in milliseconds. |
| `Screen.confirmToast` | `true` = also show a message after pinning or taking down a notice. Refusals, such as posting too fast, are always shown. |
| `EcoBoost.resource` | Resource that owns the Eco Boost button. It must export `GetEcoBoostStatus(src)` and `ActivateEcoBoost(src)`. |
| `Logging.webhookUsername` | Name the webhook posts under. The character's name is never used. The URL itself is in `server/config.lua`. |

### config/boards.lua

One entry per notice board in `Config.Boards`:

| Field | Meaning |
|---|---|
| `city` | Board name. Notices are saved per city, so renaming a board hides its old notices. The prompt reads "`city` Notice Board". |
| `coords` | `{ x, y, z }` of the board, as a plain list (it is also sent to the page). |
| `jobs` | Optional, e.g. `{ police = 0 }`: only that job at that grade or above may pin here. |
| `kinds` | Optional, e.g. `{ picture = false }`: that kind is off on this board. |
| `refusedHosts` | Optional, e.g. `{ 'example.com' }`: image hosts refused on this board only. |
| `blip` | Optional, `false` = no blip for this board. |

The Valentine, Saint Denis, Rhodes, Blackwater and Strawberry positions are marked `RE-PICK IN GAME`: stand where the board should be and replace them.

Example of adding a board:

```lua
{ city = 'Limpany', coords = { -351.98, -157.65, 50.20 }, kinds = { picture = false } },
```

### config/locale.lua

Every piece of text the board shows. `%s` is filled in by the board (a town name, a count, money or time left). The section ids `sale`, `buying`, `jobs` and `notices` are fixed; change the words freely. `fringe_slip` is printed on each tear-off slip, and the `eco_*` strings get money or time left from the Eco Boost resource. The `scope_*` strings are only shown to those allowed to pin to every board. The refusal keys (`not_allowed`, `too_far`, `too_fast`, `too_many`, `too_long`, `link_*`, `write_first`) are what the server answers with.

### server/config.lua

| Setting | Meaning |
|---|---|
| `Secrets.Webhooks.posters` | Discord webhook that logs every pinned notice. `""` = no logging. |

## For developers

The page talks to the client through NUI callbacks (`listNotices`, `pinText`, `pinPicture`, `unpinNotice`, `isNight`, `ecoStatus`, `ecoActivate`, `close`). A call that wants an answer names a `reply` message type, and the answer is sent back to the page under that type with `ok` and, on a refusal, a locale key in `reason`.

Server events (client to server): `pup-pinboard:wake`, `pup-pinboard:getList (city, data, token)`, `pup-pinboard:saveText (city, data, token)`, `pup-pinboard:saveImage (city, data, token)`, `pup-pinboard:remove (data, token)`, `pup-pinboard:ecoStatus (data, token)`, `pup-pinboard:ecoActivate (data, token)`. Ownership, distance and rate limits are all enforced on the server. Notices sent to the page carry `mine` instead of a character id.

The Eco Boost resource must provide:

- `GetEcoBoostStatus(src)` returning a status table.
- `ActivateEcoBoost(src)` returning `{ ok = bool, status = table, reason = string }`.

Saved notices are JSON in `pinboard_posters.content`: `{ paper, section, lines = { { style, align, text } } }` for text, `{ picture, section }` for pictures. The author is in `author_charid` / `author_name`.

`html/js/preview.js` only runs outside the game: open `html/index.html` through a local web server to see the board with sample notices (add `?night` for the night look).

No exports.

## Credits

The paper drawings in `html/img` (`paper_1.svg` to `paper_6.svg`, and `torn_1.svg` to `torn_3.svg` for a picture that will not load) were made for this resource and are covered by its licence.

The fonts in `html/fonts` are third-party, free fonts and are not covered by this resource's licence; each licence is next to its font:

- `oswald.ttf`: Oswald by The Oswald Project Authors, SIL Open Font License 1.1 (`OFL-Oswald.txt`).
- `imfell.ttf`: IM Fell English by Igino Marini, SIL Open Font License 1.1 (`OFL-IMFellEnglish.txt`).
- `robotoslab.ttf`: Roboto Slab (Google Fonts), Apache License 2.0 (`LICENSE-RobotoSlab.txt`).

## License

See LICENSE.
