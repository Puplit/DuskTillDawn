# pup_tailor

Tailor benches for RedM (VORP Core). Tailors design clothing on a mannequin and turn it into inventory items, copy the outfit they are wearing, and dye a clothing item once; anyone can browse a bench to note garment numbers for a tailor.

## Features

- **Four benches** (Emerald, Blackwater, Saint Denis, Valentine). Each is job-locked, and its blip shows only to that bench's job.
- **Prompt** (G, "Menu") within 1 m of a bench. A player without the job gets a preview-only session.
- **Create Clothing Item**: copies the clothes you wear into a `clothingset` item for $5 (garments only, never dye).
- **Tailor**: pick Male or Female, then build an outfit on a lit mannequin with one slider per garment category. Q/E turn, SHIFT/CTRL zoom, SPACE/ALT height, X reset, ENTER types a garment number.
  - The bill lists cash and materials per copy, a **Keep Mask & Neckwear** switch, a description and an amount (1 to 100).
  - The server prices every garment, checks it belongs to the chosen sex and slot, and refuses hidden garments.
- **Customize Color**: the dye book, a page with a mannequin. Pick a carried outfit, choose one of 25 palettes and three channels (0 to 255) per garment, and save. Dyeing costs 2 leather and 2 wool, plus 1 acid per garment. A dyed item becomes its `pristine_` variant when that item exists.
- **Palette names**: tailors can name the 25 palettes. Names are shared with every player and saved.
- **Wearing**: using any clothing item changes your clothes (a 3.5 s change on foot) and saves the result to VORP's character record and to pup_clothing. Items are not consumed.
- **Staff**: can hide a broken singleplayer garment from every tailor menu, and list or restore hidden garments.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `vorp_character` (stores the worn clothing and tints)
- `oxmysql`
- `pup-ui`
- `pup_clothing` (optional: receives the singleplayer garments you wear)
- `vorp_admin` (optional: the staff permission check)

## Installation

1. Run `sql/install.sql` once. It creates the two tables (the resource also creates them on start) and adds the 75 clothing items, leaving existing rows alone.
2. Make sure the dye materials exist as items: `leather`, `wool` and `acid` (see `Config.DyeMaterials`).
3. Add item images for the clothing items to vorp_inventory if you want pictures in the satchel.
4. `ensure pup_tailor` after `vorp_core`, `vorp_inventory`, `vorp_character`, `oxmysql` and `pup-ui`.

There are no webhooks or secrets.

Tables:

- `palette_names` (palette, name)
- `clothing_hidden` (drawable, label, hidden_by, hidden_at)

## Commands

| Command | Who | What |
|---|---|---|
| `/hiddengarments` | server console, or staff in game | prints every hidden garment to the server console |
| `/hiddengarments restore <drawable>` | server console, or staff in game | brings a hidden garment back (signed or unsigned number) |

Staff means a VORP group in `Config.StaffGroups` (`admin`, `superadmin`), or anyone vorp_admin's `hasPermission` grants `Config.StaffPermissionKey` (`admin_actions_menu`).

## Configuration

### `config/main.lua` (shared)

| Setting | Meaning |
|---|---|
| `Debug` | console tracing |
| `CopyPrice` | cash for "Create Clothing Item" (copy what you wear) |
| `BenchReach` | metres: how close the server wants you to a bench for paid work |
| `PromptDistance` | metres: how close you must be for the prompt to show |
| `MaxAmount` | the most copies one make request may ask for; more is refused with a message |
| `PassUnknownPosition` | when the server cannot see a player's position, a player with the bench's job passes the bench check anyway |
| `DyeMaterials.flat` | materials taken once per dye job: `{ name, label, count }` |
| `DyeMaterials.perGarment` | materials taken once for every garment recoloured |
| `Keys` | control hashes for the bench prompt and the showroom keys (open G, reset X, camera up SPACE, down LEFT ALT, zoom in SHIFT, zoom out CTRL, turn Q/E) |
| `ShowroomExtraDisabled` | extra game controls switched off while the showroom keys are live |
| `Blip` | blip style hash and scale |
| `StaffGroups`, `StaffPermissionKey` | who counts as staff (see Commands) |
| `DefaultTeeth` | teeth put back (per sex) when a whole clothing set would leave none |
| `Camera` | mannequin camera: field of view, ease time (ms), zoom and raise ranges, `sideOffset` (metres the look-at point sits beside the ped so the menu does not cover it), `showroom` steps per frame, `book` steps per key press in the dye book |

#### Benches (`Config.Benches`)

```lua
{
    name = 'Valentine Tailor', sprite = 990667866, jobLocked = true,
    prompt = vector3(-295.747, 810.454, 118.842),
    jobs = { 'vttailor' },
    mannequin = vector4(-298.233, 810.559, 118.842, 281.97),
    floorZ = 118.192,
},
```

- `prompt`: where the prompt shows.
- `jobs`: the jobs that may work there. `jobLocked = false` lets everyone work there.
- `mannequin`: where the mannequin stands and its heading.
- `floorZ` (optional): exact ground height for the mannequin, for benches inside an interior. Without it the mannequin stands at `mannequin.z - 0.98`.
- `sprite`: blip sprite hash.

To add a bench, add another block like the one above.

### `config/catalogue.lua` (shared)

| Setting | Meaning |
|---|---|
| `ItemCategories` | the 33 categories that are real inventory items, each wearable as a single garment |
| `HiddenSPCategories` | singleplayer categories never offered |
| `HiddenSPDrawables` | single singleplayer drawables never offered, e.g. `{ [-123456] = true }` |
| `HideUnnamedCategories` | true also hides every `research_*` category |
| `BodyPartCategories` | multiplayer categories that are body parts and never offered |
| `CategoryLabels` | display labels. A category without a label shows its raw key and cannot be dyed |
| `ResearchLabelPrefix`, `ResearchLabelSuffix`, `ResearchCategories` | unnamed singleplayer categories are labelled `<prefix> N<suffix>` in list order |
| `CategorySlot` | category key to outfit slot name. This is the save format: never change it. Other categories use the key itself |
| `SlotCategoryHash` | slot to game category hash (the first place looked) |
| `VorpSlots` | slot names vorp_character knows; only these reach the worn-clothing save |
| `VorpAliases` | lower-case slots also written under vorp_character's spelling |
| `KeepSlots` | slots kept by the Keep Mask & Neckwear switch |
| `ConflictSlots` | garments that cannot be worn together |
| `MaskItems`, `NeckwearItems` | items that may dye their mask / neckwear slot |
| `Mannequin` | the fresh mannequin: models, drop below the bench, base body pieces, categories removed, light |
| `Anims` | animations for wearing a clothing item |

### `locale/en.lua`

Every text the players see. Placeholders are `string.format` style.

### Data files

`shared/cloth_hash_names.lua` (multiplayer garments and their prices), `shared/npc_clothing.lua` (singleplayer garments) and `shared/palettes.lua` (the 25 palettes) are data only.

- In `shared/cloth_hash_names.lua`, rows that are commented out are not offered.
- The palette order is part of the save format: add to the end, never reorder.
- The order of the garment lists decides the numbers tailors use.

## For developers

The resource has no exports. It works with other resources through events:

- Client: `vorpcharacter:savenew` and `vorpcharacter:savetints` (worn clothing and tints for vorp_character).
- Server: `pup_clothing:syncExtras` (the singleplayer garments worn, for pup_clothing).
- `shared/palettes.lua` is a plain list other resources can read; `applyTint` accepts either an index or a hash.

## Credits

`shared/cloth_hash_names.lua` is the RDR2 garment name and hash list from femga's community research project [rdr3_discoveries](https://github.com/femga/rdr3_discoveries), with a price field added to each row. It is game data and not covered by this resource's licence.

## License

See LICENSE.
