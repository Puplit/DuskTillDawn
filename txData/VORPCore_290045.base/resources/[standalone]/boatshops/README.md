# boatshops

Boat shops at the docks. Players buy boats, launch and park them, rename them on purchase, give them to another player, sell them back and fit upgrades (tints, extras, liveries and prop sets). Every owned boat has its own storage.

The server decides everything: prices, reach, job access and opening hours are checked server side, and owned boats are created by the server.

## Dependencies

- `oxmysql`
- `vorp_core`
- `vorp_inventory` (boat storage)
- `pup-ui` (menus, inputs and tips)

## Install

1. Put the folder in `resources/[standalone]` (started by `ensure [standalone]`).
2. Database: the `boats` table is in the fresh SQL, and the resource also creates it on start if it is missing. `sql/install.sql` is the same definition for a manual install.
3. Optional: paste Discord webhooks into `server/config.lua` (see below).

## How to use

- At a shop counter, press **Space** to open the shop: **Purchase Boats**, **Your Boats** (spawn, give to player, sell to store) and **Upgrade Boats**.
- To buy a boat or an upgrade, choose it, then press **Enter** to pay.
- Back at the shop's park point, press **Space** to park the boat.
- While aboard your own boat, press **I** for the boat menu: drop or raise the anchor, and open the boat's storage.

There are no chat commands.

## Config

### `config/main.lua`

| Key | Meaning |
|---|---|
| `General.debug`, `General.lang` | Debug prints; locale |
| `Keys.use`, `Keys.boatMenu` | Control hashes for Space (open, park, arm) and I (boat menu) |
| `Park.deleteOnPark` | Delete the boat when parked (`false` = it stays where it was left) |
| `NoAnchor` | Model hashes with no anchor |
| `Storage` | Title, fallback slot count, `shared` (contents belong to the boat), `requireAboard`, `nearBoatMeters`, `registerWaitMs` |
| `Sell.returnStorage` | Give the storage contents back to the seller first; the sale stops if they can't carry it |
| `Give.maxDistance` | How close the new owner must be (metres) |
| `Reach.extraMeters` | Extra server reach on top of a shop's open radius |
| `Name.min`, `Name.max` | Boat name length |
| `Timings` | Tip durations, fades, spawn waits, lost-boat checks and the per-player rate limit (ms) |
| `Spawn` | `method` (`'rpc'` or `'setter'`; keep `'rpc'` while vorp_admin's spawn guard is on), `guardGrantMs`, `grantMarginMeters` |
| `Blips` | Shop and boat blip scale, styles, sprite and colours |
| `Keeper` | Shop keeper voice and spawn/despawn distances |
| `Categories` | Upgrade categories, in menu order |

### `config/boats.lua`

- `Boats`: the catalogue, keyed by game model name (never rename a key: it is saved on every owned boat). Each entry has `label`, `desc`, `hash`, `buy`, `sell`, `slots`, `weapons` (allowed in storage), `ignoreStack` and `jobs` (empty = anyone).
- `Sets`: named lists of boats a shop can sell.

### `config/shops.lua`

- `ShopDefaults`: used for every field a shop leaves out.
- `Shops`: one entry per shop: `name`, `prompt`, `blip`, `counter`, `launch`, `park`, `exit`, `keeper`, `hours`, `jobs`, `minGrade`, `openRadius`, `parkRadius`, `boats` (a set name or a list) and `overrides` (per-shop `buy`, `sell`, `slots`).

### `config/upgrades.lua`

- `Upgrades[category][boat key]`: the options and prices shown for each boat. `value = 'none'` removes that category's upgrade.

### `config/locale.lua`

All player text.

### `server/config.lua` (server only)

Discord logs for `buy`, `sell`, `give` and `upgrade`. A blank webhook on sell, give or upgrade falls back to the buy webhook; a blank buy webhook turns that log off.

## License

GPL-3.0-or-later, see `LICENSE`.
