# pup_armory

Melee props (swords, clubs, tools and shields) that are carried on the body and swung as base-game melee weapons. Each character can fine-tune where every weapon sits with an in-game position editor, and staff can save a position as the server default.

## Features

- Every weapon is a usable inventory item: use it once to take it out, use it again to put it away.
- One hand weapon and one shield can be carried at a time.
- While put away, the prop hangs on the body (back, spine, hip, belt or forearm). While the base weapon is drawn, the prop moves to the right hand and the real weapon model is hidden.
- Props are local objects on each client (nothing is networked), drawn for every player within range from that player's state bag, so nobody depends on another player's game to see them.
- If a prop model fails to load, the real base weapon shows instead of nothing.
- `/wp` position editor: move and rotate where a carried weapon hangs on your own character, then save it for that character. Everyone else sees your saved position. Where it sits in the hand is staff-only by default (`Config.Rules.playersEditHand`).
- Staff can save a position as the server default for everyone who has not saved their own, or reset it back to the config.
- Weapons can be locked to jobs.
- If the item leaves the inventory (dropped, given, sold, stashed) it is put away automatically.
- If death, a clothing reload or another script strips the base weapon, it is handed back.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui` (the editor's pickers)
- `vorp_admin` (optional: lets a vorp_admin permission count as staff)
- A model pack of your own (optional: only for custom-model weapons, see `config/weapons_custom.example.lua`)

## Installation

1. Run `sql/install.sql`. It creates `armory_offsets` (per-character positions) and `armory_defaults` (server defaults) and adds the 39 weapon items to the `items` table. It is safe to run more than once. The resource also creates both tables on start if they are missing.
2. Add item images for the weapon items to your inventory's image folder (same file name as the item).
3. Ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure my_weapon_models  # only if you add custom-model weapons
   ensure pup_armory
   ```
4. It comes with 39 base-game prop weapons (`config/weapons.lua`). No model pack is included. To add your own (base-game props, custom models or swords with their own positions), see `config/weapons_custom.example.lua`.
5. **Fit the weapons once, in game.** The carry and hold styles are rough starting points, so a new server should place each weapon before players use it: give yourself the item, use it, run `/wp`, move it into place and save it as **Everyone (server default)**. Do it for both spots (put away and in the hand). The defaults are stored in `armory_defaults` and apply to every character who has not saved their own.

There are no webhooks or secrets in this resource.

## Commands

| Command | Who | What |
|---|---|---|
| `/wp` | Everyone | Opens the position editor for the weapon(s) you are carrying. The name is set by `Config.General.editCommand`; the radial menu runs this command. |

Editor keys (default, see `Config.Keys`):

| Key | Action |
|---|---|
| Arrow keys | Move forward/back/left/right (hold SHIFT: tilt and roll) |
| `[` / `]` | Move up/down (hold SHIFT: turn) |
| SHIFT (hold) | The keys above rotate instead of move |
| G | Cycle fine / normal / coarse steps |
| B | Back to the default position |
| ENTER | Save (staff are asked: "My character" or "Everyone (server default)") |
| BACKSPACE | Leave without saving |

The weapon picker also offers "Reset to default" (forget your saved positions for this weapon) and, for staff, "Reset server default".

## Configuration

### config/main.lua

**Config.General**

| Field | Meaning |
|---|---|
| `debug` | Console and F8 traces (equips, saves, attaches). |
| `drawRange` | Metres. Other players' weapons are drawn within this range. |
| `tickMs` | Milliseconds between checks that re-hang carried props. Lower is snappier but costs more. |
| `editCommand` | Name of the position editor command (default `wp`). |

**Config.Keys**: control hashes for the editor (`up`, `down`, `left`, `right`, `raise`, `lower`, `rotate`, `step`, `reset`, `save`, `cancel`). Change the hash only.

**Config.Integrations**: empty; reserved.

**Config.BaseWeapons**: the game weapon a prop is swung as, picked by its kind. The player is handed this weapon, it is hidden, and the prop is drawn over it. A single weapon can override it with `base = '...'`. Shields have no base weapon.

| Kind | Default | Used for |
|---|---|---|
| `blade` | `weapon_melee_machete_collector` | swords, sabres, scythes |
| `knife` | `weapon_melee_knife_rustic` | knives, stakes, spears |
| `blunt` | `weapon_melee_hammer` | clubs, hammers, bats, pans, tools |

**Config.CarryStyles**: where a weapon hangs while put away; a weapon picks one with `carry = '...'`. Each style is a bone plus `pos = { x, y, z, rx, ry, rz }` (metres and degrees from the bone). Styles: `back`, `spine`, `hip`, `belt`, `arm` (shields, the left forearm). These are rough starting points, not a final fit: every prop is shaped differently. `back`, `hip` and `arm` sit exactly on the game's own carry points (all zeros). Take the weapon out, run `/wp` and nudge it into place. Staff can save that as the server default for everyone, so no numbers ever need typing in the config.

**Config.HoldStyles**: how a weapon sits in the right hand; a weapon picks one with `hold = '...'`. Each is `{ x, y, z, rx, ry, rz }`. Styles: `blade` (swords and sabres), `knife` (short blades, stakes), `club` (clubs, hammers, axes, tools), `long` (long handles held low: shovels, rakes, staffs). If a weapon gives no hold style, `blade` uses `blade`, `knife` uses `knife` and `blunt` uses `club`. Like the carry styles, these are starting points for staff to fine-tune in `/wp`.

**Config.Staff**: who may save or reset a server default from `/wp`.

| Field | Meaning |
|---|---|
| `groups` | VORP user groups that count as staff. |
| `permission` | Anyone holding this vorp_admin permission also counts as staff (`open_menu` = all staff). Ignored if vorp_admin is not running. |

**Config.Rules**

| Field | Meaning |
|---|---|
| `maxOffset` | Metres a saved position may sit from its bone on each axis. Rotations are limited to 720 degrees. This stops props being parked across the map or used to hide a player. |
| `playersEditHand` | `false`: only staff can change where a weapon sits in the hand; players can only move where it hangs on the body. Any in-hand position a player saved before is ignored. `true`: everyone can edit both. |

### config/weapons.lua

The weapon list, using base-game RDR2 props. Entries go inside an `add({ ... })` block.

Adding a weapon:

```lua
{
    item  = 'axe_wep',
    label = "Woodcutter's Axe",
    model = 'p_axe02x',
    kind  = 'blade',
    carry = 'back',
    hold  = 'club',
},
```

| Field | Meaning |
|---|---|
| `item` | The usable item. Add it to the `items` table too (see `sql/install.sql`). |
| `label` | The name players see. |
| `model` | Any prop model. |
| `kind` | How it swings: `blade` (machete), `knife`, `blunt` (hammer) or `shield` (worn on the arm, no swing). |
| `carry` | Where it hangs while put away: `back`, `spine`, `hip`, `belt`, `arm` (see `Config.CarryStyles`). Defaults to `arm` for shields and `back` otherwise. |
| `hold` | How it sits in the hand: `blade`, `knife`, `club`, `long` (see `Config.HoldStyles`). |

Optional fields:

| Field | Meaning |
|---|---|
| `jobs = { 'police' }` | Only these jobs may use it. |
| `base = 'weapon_melee_knife'` | Swing it as this weapon instead of its kind's base weapon. |
| `bone`, `worn`, `hand` | Exact positions instead of the styles, e.g. `worn = { x, y, z, rx, ry, rz }` (see the sword example in `config/weapons_custom.example.lua`). |

Then in game: use the item, run `/wp`, and nudge it into place. Staff can save it as the server default there, so it looks right for everyone with no numbers typed in the config. An entry with an unknown kind, carry or hold style is skipped with a console warning.

### config/weapons_custom.example.lua (adding your own)

A commented template with one example for each type. Uncomment a block and fill it in, or copy the file to `config/weapons_custom.lua` (every `config/weapons_custom*.lua` file is loaded).

1. **Base-game props**: any RDR2 prop can be a weapon, no model pack needed. Prop names are in the community object lists (e.g. [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries)).
2. **Custom models**: stream them from your own resource, ensured before `pup_armory`. Include the `.ydr`/`.ytd` and a `.ytyp` declared with `data_file 'DLC_ITYP_REQUEST'`.
3. **Swords with their own positions**: when no carry or hold style suits a sword, give it a bone and its own `worn` and `hand` positions. The `/wp` editor shows the six numbers on screen while you move it, so you can copy them into the config.

```lua
{
    item  = 'cavalry_sword',
    label = 'Cavalry Sword',
    model = 'p_sword01x',
    kind  = 'blade',
    bone  = 'SKEL_Pelvis',
    worn  = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 },
    hand  = { 0.10, 0.02, -0.02, -90.0, 0.0, 0.0 },
},
```

For every new weapon:

1. Add the item to the `items` table (copy a row from `sql/install.sql`).
2. Add an item image named `<item>.png` to `vorp_inventory/html/img/items/`.
3. In game, use the item, run `/wp` and nudge it into place.

### config/locale.lua

All player-facing text. `%s` / `%d` placeholders are filled in by the code, so keep them.

## For developers

This resource has no exports. Other resources can read its state:

| Name | Where | Contents |
|---|---|---|
| `Player(src).state.pup_armory` | Player state bag (replicated) | `{ hand = item, shield = item, pos = { [item] = { [slot] = { x, y, z, rx, ry, rz } } } }`, or nil when nothing is carried. |
| `Player(src).state.pup_armory_staff` | Player state bag (replicated) | `true` if the player may save server defaults. |
| `GlobalState.pup_armory_defaults` | Global state | Server-default positions: `{ [item] = { [slot] = { ... } } }`. |
| `GlobalState.pup_armory_defaults_v` | Global state | Counter bumped whenever the defaults change. |

Slots: `worn` and `hand` for blades, knives and blunt weapons; `worn` for shields.

Events:

| Event | Side | Purpose |
|---|---|---|
| `pup_armory:arm` (item or false) | Client | Server hands over or takes back the base weapon. |
| `pup_armory:hello` | Server | Client asks the server to re-check staff status. |
| `pup_armory:clear` | Server | Client asks to put everything away (sent on character select). |
| `pup_armory:saveSpot` (item, slot, offset) | Server | Save a position for the current character. |
| `pup_armory:resetItem` (item) | Server | Forget the character's positions for an item. |
| `pup_armory:saveDefault` / `pup_armory:resetDefault` | Server | Staff only: save or reset a server default. |

Listened to: `vorp_inventory:Server:OnItemRemoved`, `vorp:SelectedCharacter`, and pup-ui's `pup-ui:client:inkSelect` / `pup-ui:client:inkClose`.

## License

See LICENSE.
