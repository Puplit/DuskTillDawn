# pup_library

Players write their own books, newspapers, magazines, letters and contracts in an in-game book with turning pages. They can print copies at a library, put a title up for sale through the newspaper, and collect royalties when other players buy it.

## Features

- Four libraries with map blips. Press **G** within 2.5 m of one to open the library menu.
- **Published titles:** browse the shelf and buy a copy. The price is paid into the author's royalties.
- **Creation:** start a new work of any kind with a title, an author name and an edit rule (Author, My job, Anyone).
- **Print:** make copies of a work you carry. Each print run has its own edit rule. By default only the author may print.
- **Publish:** put one of your titles forward with an asking price. The application fee is paid into the publishing job's ledger (pup_business, when it is running).
- **Publish applications:** members of the publishing job at the minimum grade can approve a title, reject it with a reason, or take a free reading copy.
- **Royalties:** collect what your titles have earned, paid as cash.
- **The book:** a two-page book with animated page turns. Editable books have page tools (write, add, move, delete) and a rich-text writer with styles, fonts, sizes, ink and highlight colours, lists, quotes, links, pictures, dividing lines, page backgrounds and page colours.
- **Safety:** book HTML is cleaned on screen and again on the server, where only allow-listed tags and attributes are kept. Saves are capped at 512 KB and 200 pages. The server accepts a save only for the book it opened in edit mode for that player, and checks every price, distance, rule and owner itself.
- **Discord logs** for applications, approvals, rejections and removals.

## Requirements

- vorp_core
- vorp_inventory
- oxmysql
- pup-ui (menus and input boxes)
- pup_business (optional, receives the publishing application fee in its ledger)
- OneSync is recommended, so the server can check that players are really at a library (see `PassAtWorldOrigin`).

## Installation

1. Run `sql/install.sql`. It creates the `books`, `books_publishing` and `book_royalties` tables and adds the five items (`book`, `newspaper1`, `magazine`, `letter`, `contract`) to `items` if they are missing. It is safe to run more than once.
2. Add inventory images for the five items to vorp_inventory if your inventory does not already have them.
3. For Discord logs, set `Webhooks.publishing` in `server/config.lua` to your webhook address (server only, never sent to players). Leave it empty to turn the logs off.
4. Add `ensure pup_library` to `server.cfg` after vorp_core, vorp_inventory, oxmysql and pup-ui (and after pup_business if you use it).

## Commands

| Command | Who | What |
|---|---|---|
| `/bookunstuck` | anyone | Close a frozen book without saving, clear the writing scenario and unfreeze the player. Holding **Delete** for 1 second while a book is open does the same. |

## Configuration

Settings are in `config/main.lua`. Player-facing wording is in `locale/en.lua`, where `%s` and `%d` are filled in by the game.

### Libraries, blip and prompt

- `Config.Libraries`: one entry per library, `{ name = 'Label', pos = vector3(x, y, z) }`. Each library gets a blip and a press-to-open prompt at `pos`. To add one, add a line such as `{ name = 'Rhodes Library', pos = vector3(1234.5, -1300.0, 76.9) },`.
- `Config.Blip`: `sprite` and `style` are blip hashes; `scale` is the blip size.
- `Config.Prompt`:
  - `distance`: metres from a library position at which the prompt shows (default 2.5).
  - `key`: control hash for the prompt (default `0x760A9C6F`, the G key).
  - `nearScan`: metres. Inside this distance of the nearest library the check runs every frame.
  - `farScanMs`: ms between checks when further away (default 500).
- `Config.ReachDistance`: metres (3D). Every server-checked action needs the player this close to any library (default 10).
- `Config.PassAtWorldOrigin`: without OneSync the server sees every player at the world origin. `true` lets the distance check pass in that case; `false` refuses every library action.

### Works

- `Config.Works`: the kinds of work, each `{ item = 'item name', label = 'Label' }`. All of them are usable items that open the book. To add a kind, add the item to the `items` table and a line such as `{ item = 'pamphlet', label = 'Pamphlet' },`.
- `Config.DefaultWork`: item used when a stored kind is no longer in `Works`.
- `Config.SharedUsableItems`: item names that another resource also registers as usable (pup-misc registers `book`). These are not unregistered when this resource stops, so the other resource's handler stays.
- `Config.MaxBytes`: largest saved book in bytes, pictures included (default 524288, 512 KB).
- `Config.MaxPages`: most pages in one book (default 200).
- `Config.NewBookPages`: blank pages in a new work (default 3).
- `Config.TitleMax`, `Config.AuthorMax`, `Config.ReasonMax`: longest title, author name and rejection reason, in characters.

### Jobs, prices and publishing

- `Config.StaffJobs`: job names counted as library staff (default `{ 'newspaper' }`).
- `Config.StaffOnlyLibrary`: `true` means only staff may open or use a library.
- `Config.CreatePrice`: dollars to create a new work. `Config.StaffCreateFree`: staff create for free.
- `Config.PrintPrice`: dollars per printed copy. `Config.StaffPrintFree`: staff print at $0, even when `StaffCreateFree` is off. `Config.MaxCopies`: most copies in one print run.
- `Config.PrintStaffOnly`: only staff may print. `Config.PrintAuthorOnly`: only the author of a work may print it.
- `Config.PublishJob` and `Config.PublishMinGrade`: the job, and the lowest grade in it, that reviews publish applications.
- `Config.ApplicationFee`: dollars charged to put a title forward. It is paid into the publishing job's ledger.
- `Config.MaxSalePrice`: highest asking price per copy, in dollars.
- `Config.LedgerIntegration`: pay the application fee into pup_business with `AddToLedger` (only when pup_business is started). `Config.LedgerReason` is the ledger entry text.

### Discord

The webhook address itself is the `publishing` entry in `server/config.lua`, not in `config/main.lua`.

- `username`: name shown on the log messages.
- `avatar`: picture address for the messages; empty uses Discord's default picture.
- `colours`: embed colours as decimal numbers for `application`, `published` and `removed` (also used for rejections).

### Timings

- `Config.ServerReplyTimeout`: ms the prompt waits for the server before showing "The librarian is not answering."
- `Config.UnstuckHoldMs`: ms to hold Delete to close a frozen book.
- `Config.LatentRate`: bytes per second for uploading a save to the server.
- `Config.PageTurnMs`: length of the page-turn animation in ms.
- `Config.ScenarioRetryMs`: ms between attempts to restart the writing scenario while a book is open. `Config.Scenario` is the scenario name.
- `Config.Notify`: how long each kind of notification stays on screen, in ms. `refusal` is used when a save is refused.
- `Config.RequestGapMs`: server-side spam guard, the shortest gap in ms between two requests of the same kind from one player.

### Writer

- `Config.Writer.fonts`: font choices, each `{ label = 'Name', stack = 'CSS font-family list' }`.
- `Config.Writer.sizes`: font sizes in pixels.
- `Config.Writer.ink` and `Config.Writer.highlight`: colour swatches as CSS colours.

Everything below the "Nothing to edit below this line" marker in `config/main.lua` is helper code.

## For developers

pup_library has no exports and no events meant for other resources.

- Works are normal vorp_inventory items. Their metadata holds `id` (the `books.id` row), `title`, `author` and `edit` (the copy's edit rule: `author`, `any`, a job name, or `none` for bought and reading copies).
- The `books.data` column is JSON: `{ "pages": [ { "content", "background", "backgroundColor", "color" } ] }`, with optional `frontImage`, `midImage` and `backImage`.
- `books_publishing.publish` is 0 for a pending application and 1 for a published title. `book_royalties.cash` holds unpaid royalties per character.
- Server exports it calls: `vorp_core:GetCore`, vorp_inventory `canCarryItem`, `addItem`, `getUserInventoryItems`, `registerUsableItem` and `unRegisterUsableItem`, and optionally `pup_business:AddToLedger(job, amount, reason, who)`.
- Client exports it calls: pup-ui `OpenInkMenu`, `HideInkMenu` and `OpenInput`. It listens to the pup-ui events `inkMove`, `inkChange`, `inkSelect`, `inkClose` and `inputDone`.
- It triggers `vorp:TipRight`, `vorp:TipBottom` and `vorp_inventory:CloseInv`.
- Browser preview: open `html/index.html?debug=1` in a browser to see a five-page sample book. Add `&edit=1` to make it editable. Saves are logged to the browser console.

## License

See LICENSE.
