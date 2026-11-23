# pup_clothing

Clothing stores and wardrobes for RedM (VORP). Players browse every multiplayer garment per category on their own character, buy the look for a flat price and keep named outfits. The resource also stores what VORP's character record cannot hold (custom garment colours and singleplayer garments) and puts it back whenever VORP rebuilds the ped.

## Features

- **Clothing stores** (14 active points, most with a map blip). Hold SPACE on "Open". One row per garment category, grouped in six tabs (Head, Upper, Lower, Feet, Rig, Extras), each previewed live. Save costs $10; Save As Outfit also keeps it as a named outfit. E/F turn, Shift/Alt zoom, Space/Ctrl move the camera, and holding BACKSPACE for 2 s always leaves.
- **Wardrobes** (16 active points). List, search, wear (free) or delete saved outfits.
- **Garment colours** (off by default): palette 1-25 and three channels 0-254 per garment, with an optional surcharge.
- **Toggle commands**: `/hat`, `/coat`, `/boots` and many more take one garment off; the same command puts it back exactly.
- **Character creator fitting**: vorp_character can open the store as its clothing step (free, saves nothing itself).
- **Free starter fitting** (off by default): one free visit for a brand-new character.
- **Server-checked**: every price, garment, location and write is decided on the server, with per-player rate limits.

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_character`
- `vorp_inventory`
- `pup-ui` (theme and menu side)
- `pup_tailor` (optional, for its singleplayer garments; see `Config.Npc`)
- `fred_hud` (optional; asked to re-announce the menu side at start)

## Installation

1. Run `sql/install.sql`. It creates `clothing_starter`, `clothing_extras` and `clothing_outfits`, and is safe to run more than once (the resource also creates the tables on start).
2. Add `ensure pup_clothing` after `oxmysql`, `vorp_core`, `vorp_inventory`, `vorp_character` and `pup-ui`.
3. Optional: for pup_tailor's singleplayer garments to be put back on the ped, install pup_tailor with its `shared/npc_clothing.lua`.
4. No webhooks or keys are used.

No items or images are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/closeui` | Everyone | Leaves the store or wardrobe, whatever state the page is in. |
| `/reapplyclothes` | Everyone | Puts saved colours and singleplayer garments back on the ped. |
| `/hat`, `/coat`, `/coatclosed`, `/heavycoat`, `/cloak`, `/poncho`, `/cape`, `/shawl`, `/shirt`, `/overshirt`, `/vest`, `/corset`, `/chemise`, `/unionsuit`, `/overalls`, `/suspenders`, `/apron`, `/bonnet`, `/headwear`, `/mask`, `/eyewear`, `/faceprop`, `/neckwear`, `/necktie`, `/neckerchief`, `/necklace`, `/gloves`, `/gauntlets`, `/bracelet`, `/rings`, `/wristwraps`, `/pants`, `/skirt`, `/gown`, `/knickers`, `/stockings`, `/chaps`, `/spats`, `/boots`, `/spurs`, `/anklewraps`, `/belt`, `/buckle`, `/gunbelt`, `/holster`, `/satchel`, `/armor` | Everyone | Takes that garment off, or puts it back. If nothing is worn and nothing was kept (a hat knocked off), asks for the saved garment back. |

## Configuration

### config/main.lua

- **Debug**: `client` prints previews, seeding, extras and camera traces; `server` prints purchases, outfits and extras.
- **Prompt**: `key` (hold to confirm, default SPACE), `holdMs`, `radius` (metres from a point), `tightRadius` (metres, for points with `tight = true`), `nearSleep` / `farSleep` (ms between checks near a point and otherwise), `nearMargin` (metres from a point that count as "near").
- **Blips**: blip style and the sprite and scale for stores and wardrobes.
- **Stores / Wardrobes**: one entry per point: `{ x = ..., y = ..., z = ..., blip = true }`. `blip` shows a map blip, `tight = true` uses the 1 m prompt radius, `enabled = false` keeps the point in the list but unused. To add a store, add a line such as `{ x = 1.0, y = 2.0, z = 3.0, blip = true },`.
- **Store**: `price` (cash per purchase, currency 0), `hideUnnamed` (skip multiplayer garments with no name in the data), `maleForceNone` (VORP slots always saved as none for male characters; add `'bow'` to stop male characters buying hair accessories), `failsafeHoldMs` / `failsafeKey` (holding this key this long always leaves the store).
- **Creator**: `enabled` lets vorp_character's creator open the free fitting (it saves nothing itself).
- **Starter**: `enabled` gives one free store visit to a brand-new character, `delayMs` after creation.
- **Tints**: `enabled`, `defaultPrice` (per recoloured garment), `prices` (`[category key] = price`, overrides the default), `chargeUnchanged` (`true`: every purchase bills every colour the outfit carries; `false`: only new or changed colours are billed), `channelMax` (highest tint channel value).
- **Outfits**: `maxPerCharacter` (0 = no limit; a full wardrobe still buys the clothes but does not keep the outfit), `titleMax` (stored name length, server), `nameBoxMax` (name box length, page).
- **Npc** (pup_tailor's singleplayer garments): `useForExtras` loads the singleplayer garment list so garments reported through `pup_clothing:syncExtras` can be put back on the ped (without the file, only colours come back); `inStore` also lists singleplayer garments in the store; `keepTailorPieces` (`false`: a store purchase replaces the extras row and the login check blanks garment hashes the catalogue does not know; `true`: both leave pup_tailor's pieces alone); `resource` and `file` name the data file.
- **Toggles**: `enabled` registers the toggle commands.
- **Server**: `requireLocation` (store, wardrobe and outfit actions only at a point; `false` accepts them anywhere), `reach` (metres of slack around a point), `passUnknownPosition` (let the check pass when the server cannot see the player, e.g. without OneSync), `payloadMax` (bytes, for clothes, extras and sync JSON), `extrasMaxSlots`, `syncKeyMax` (longest category key), `rate` (minimum ms between two calls of the same kind per player).
- **Camera**: angles, field of view, `sideOffset` (metres the aim point moves sideways at full zoom so the ped stands beside the panel), zoom and height limits, step sizes, `startHeading` and `easeMs`.
- **Light**: range, intensity and offset of the light on the ped in the store.
- **Keys**: store camera keys and the voice keys that keep working while a page is open.
- **DisabledControls**: controls disabled every frame while the store is open.
- **Timing** (all ms): `promptDelayMs` (delay before the prompt is built), `hudAskMs` (when fred_hud is asked to re-announce the menu side), the extras fetch delays after start and character select, and waits around vorp_character's `rc` rebuild.

### config/catalogue.lua

- **SkipCategories**: garment categories never listed in the store.
- **Groups**: the store tabs, in order. A category not listed goes to the group marked `rest = true`. Add a category key to a group's `cats` to move it.
- **Labels**: display names per category key; anything missing is title-cased from its key.
- **SlotNames**: category key to VORP slot name in the clothes JSON. Anything else is saved under its own key.
- **BareBody**: picking None in these categories puts the skin's body (`BodyType`) or legs (`LegsType`) back on.
- **Palettes**: tint palettes in menu order; index 1 is the first, and an unknown index uses palette 1.
- **ToggleCommands**: command name to category key. Add `mycommand = 'category_key',` to register a new toggle.

### locale/en.lua

Every text players see. `%s` and `%d` are filled in by the code.

## For developers

Client exports:

| Export | Returns |
|---|---|
| `OpenCreatorFitting(clothesJson)` | `false` when the creator fitting is off, otherwise opens the store in creator mode and returns `true` |
| `IsCreatorFitting()` | whether creator mode is active |
| `OwnsToggleCommand(command)` | `true` when this resource registers that toggle command |

Events:

- `pup_clothing:syncExtras` (server): one JSON string, category key to a singleplayer drawable or `false`. The latest report wins.
- `pup_clothing:recExtras` (client, local): an extras JSON string to show on the ped (a borrowed look, never kept as the character's own).
- `pup_clothing:client:dressExtras` / `pup_clothing:client:undressExtras` (client, local).
- Fired: `pup_clothing:creatorDone` (clothes JSON, extras JSON), `pup_clothing:creatorCancelled`, `pup_clothing:client:pedRebuilt`.

Tables: `clothing_starter` (charidentifier), `clothing_extras` (charidentifier, extras), `clothing_outfits` (id, charidentifier, identifier, title, comps, extras).

## Credits

The garment hash list in `data/cloth_hash_names.lua` comes from the femga / rdr3_discoveries community research project on GitHub (clothes hash list) and keeps that project's own terms.

## License

See LICENSE.
