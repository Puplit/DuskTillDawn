# huntingbirds

Trained birds for RedM and VORP. Players buy a bird at a bird shop, keep it on their character, call it out with a bird call, carry it on the shoulder and send it out. Hunting birds bring back prey from the area the player is in, scavengers bring back an inventory item, and fishing birds bring back a fish. Every trip earns the bird XP, and more XP unlocks better catches. Parrots, parakeets and ravens can talk once fully trained. A bird can be sold back to the shop for part of its price, or sold to another player face to face.

The server decides everything that matters. Prices, models, outfits, XP, catches, items, ownership and permissions all come from the server's config and the database. A client only sends ids and choices, and the server checks each one.

## Features

- Two bird shops with a live preview of every bird, a species slider and per-shop tax.
- One bird out per player. It circles overhead, lands on the shoulder and leaves it when the player climbs, falls, swims, ragdolls or is tied up.
- Trips: the server picks the catch from the bird's XP and the map zone, starts the cooldown, and pays once, only after the full flight and hunt time.
- Talking birds play a random voice line once they reach the talk XP.
- A bird's-eye camera.
- Selling back to the shop: the server deletes the bird first and pays only if that worked.
- Selling to a player at a sell point: the server keeps the point, uses its own coordinates and price, moves the bird first and the money after. The sale ends if the seller walks away, dies or leaves.
- Optional Discord log of purchases, sell-backs, trades and refused requests.
- All messages go through pup-ui toasts.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui` (menus, inputs, toasts)
- `pup-perks` (optional: the `bird_xp` multiplier on every XP gain; 1.0 when it is not running)

## Installation

1. Keep the folder name `huntingbirds`. The radial menu checks for a resource by that name and fires `huntingbirds:callowneds`.
2. Run `sql/install.sql` once. It creates the `birds` table if it is missing and adds the bird call and every scavenge item to `items` with `INSERT IGNORE`. It is safe to run twice. Restart the whole server afterwards, because vorp_inventory reads the items table at start.
3. Add `ensure huntingbirds` after `vorp_core`, `vorp_inventory`, `oxmysql` and `pup-ui`.
4. Optional Discord log: set the webhook URL in `birds` in `server/config.lua` (server only, never sent to players). Empty = no log.

## How players use it

| Action | How |
|---|---|
| Open a shop | Stand on the shop point and press the Browse Birds prompt. Left/right on the first row changes the species, up/down previews a bird, Enter asks for a name and buys. |
| Open the owned-birds menu | `/callbird`, use the `birdcall` item, or the radial menu slot. |
| Call a bird | "<name> - Call" in the owned-birds menu. |
| Sell a bird to the shop | "<name> - Sell to shop", then type the confirm word (default `delete`). |
| Send the bird home | The Send Home prompt, or the last row of the owned-birds menu. Dying also sends it home. |
| Circling bird | Call Down (land on the shoulder), Bird View (camera on or off). |
| Bird on the shoulder | Talk, Send Home, Let Fly, Send Out (trip), Sell (to a player). |
| Buy from a player | Walk up to their sell point and press Buy Bird. |

Bird prompts are hidden while the player stands at a carcass, so the loot and skin prompts take priority.

## Commands

| Command | Effect |
|---|---|
| `/callbird` | Opens the owned-birds menu (name set by `Config.General.callCommand`). |

## Configuration

### config/main.lua

| Setting | Meaning | Default |
|---|---|---|
| `Debug` | Extra console output on the server (refusals, trips). | `false` |
| `General.callCommand` | Chat command that opens the owned-birds menu. `''` turns it off. | `'callbird'` |
| `General.callItem` | Usable item that opens the menu. `''` turns it off. | `'birdcall'` |
| `Keys.talk` / `sendHome` / `follow` / `hunt` / `sell` | Control hashes of the shoulder prompts. | see file |
| `Keys.land` / `camera` | Control hashes of the circling-bird prompts. | see file |
| `Keys.openShop` | Control hash of the shop prompt. | `0xC7B5340A` |
| `Keys.stopSell` | Control hash of the seller's Stop Selling prompt. | `0xD8CF0C95` |
| `Keys.buy` | Control hash of the buyer's prompt at a sell point. | `0xD8CF0C95` |
| `Progression.maxXp` | Highest XP a bird can reach. | `1000` |
| `Hunting.jobRequired` | `true`: only characters with a job in `Hunting.jobs` can send birds out. | `false` |
| `Hunting.jobs` | Jobs for `jobRequired` and `extraXp`. | `{ 'birdtrainer', 'wapiti' }` |
| `Hunting.extraXp` | Bonus XP per return for those jobs. `nil` = none. | `nil` |
| `Hunting.cooldownMs` | Milliseconds between trip starts, per character. The server enforces it and keeps it across reconnects until the resource restarts. | `180000` |
| `Hunting.flyAwaySeconds` | Seconds the bird flies off before it vanishes. | `20` |
| `Hunting.huntSeconds` | Seconds it stays away before coming back. A return is paid only after `flyAwaySeconds + huntSeconds - 5` seconds. | `60` |
| `Talking.xpRequired` | XP a bird needs to talk. | `1000` |
| `Talking.models` | Bird models that can talk. | parakeet, parrot, raven |
| `SellBack.confirmWord` | Word to type to confirm a sell-back, any case. | `'delete'` |
| `SellBack.divisor` | A sell-back pays the price paid divided by this. | `3` |
| `Trade.jobs` | Jobs allowed to sell to players. `nil` = anyone. | `nil` |
| `Trade.maxPrice` | Highest asking price accepted, in dollars. | `100000` |
| `Trade.buyDistance` | Metres a buyer may be from the sell point. | `3.0` |
| `Trade.leaveDistance` | Metres the seller may move before the sale ends. | `3.0` |
| `Shop.useDistance` | Metres the server allows between the player and the shop. | `5.0` |
| `Markers.color` | Marker colour, `{ r, g, b }`. | `{ 128, 200, 0 }` |
| `Markers.showAtShops` | Draw a marker at the shop points. | `false` |
| `Markers.showAtSellPoints` | Draw a marker at player sell points. | `true` |
| `Discord.webhookKey` | Key of the webhook in `server/config.lua`. | `'birds'` |
| `Discord.username` | Sender name of the log posts. | `'Hunting Birds'` |
| `Discord.maxPosts`, `Discord.windowSec` | At most this many posts per player per window (seconds); extra posts are dropped. `0` = no limit. | `5`, `10` |

### data/*.json

The game data is plain JSON, loaded and hashed at start. Edit these files to change what is sold and caught.

| File | Content |
|---|---|
| `bird_catalog.json` | Shop categories and their variants: `name`, `model`, outfit `preset`, base `price`, `startXp`, `type` label. |
| `bird_roles.json` | Which models hunt, scavenge or fish. A model in no list flies the trip and brings nothing. |
| `shoulder_offsets.json` | Per model and player sex: bone index, offset and rotation for the shoulder. Models without an entry use the hawk entry. |
| `shops.json` | Shops: `name`, `jobRequired`, `jobs`, `blip` (`show`, `sprite`), `taxPercent`, `coords`, `previewPos` (with heading `h`). Final price = base + `taxPercent` % of base, two decimals. |
| `prey_lists.json` | Named prey lists (`model`, `preset`, `xp`, `xpRequired`) used by hunt zones. Server only. |
| `scavenge_items.json` | Items a scavenger can bring (`item`, `amount`, `xp`, `xpRequired`). An item listed twice has double the odds. Server only. |
| `fish_catches.json` | Fish a fishing bird can bring (`model`, `xp`, `xpRequired`). Server only. |
| `hunt_zones.json` | `fallbackHash`, then `places`, `areas` and `districts`, each with `hash`, `huntable`, `prey` (a list name, or `false` to use the fallback zone) and `label`. The first match from places to districts wins. |
| `parrot_speech.json` | Voice banks and line names a talking bird picks from. |

At start the server prints a warning for catalog models without a role or shoulder offset, zones that name a missing prey list, and entries that need more XP than `maxXp` (they can never drop).

### locale/en.lua

Every player-facing text. Keep the `%s` placeholders. `itemLabels` maps an item name to the label shown when a scavenger brings it back; items not listed show their item name.

## Database

`birds`: `id`, `identifier`, `charid`, `model` (signed 32-bit model hash), `name`, `preset`, `xp`, `price` (what was paid). Every query is parameterised and always filtered by the owning identifier and character id.

## For developers

- Client event `huntingbirds:callowneds` (no arguments) opens the owned-birds menu; the radial menu fires it locally.
- The LocalPlayer state bag `pup_cam_owned` is `true` while the bird camera renders and `false` otherwise (read by the vorp_admin anti-cheat).
- Network events (client to server): `huntingbirds:getOwnedBirds`, `checkmenujob`, `buybird`, `DeleteBird`, `callbird`, `birdhome`, `checkhunt`, `addxp`, `addscavengeditem`, `sell:create`, `sell:stop`, `sell:buyoffer`, `sell:getpoints`, and `pup_huntingbirds:check_sell`. All take ids or choices only.
- `huntingbirds:getOwnedDB (identifier, charid, cb)` is a server-local event, not a network event.
- No exports.

## Credits

`client/dataview.lua` is DataView for Lua by gottfriedleibniz, used to build the struct for the talk native.

## License

See LICENSE.
