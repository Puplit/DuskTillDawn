# pup-trash

Public bins anyone can open, emptied on every server restart. Each bin is a shared `vorp_inventory` custom inventory.

## Features

- Bins at set positions in each town: walk up and press G to open one.
- Every bin's contents are deleted when the resource starts, so nothing survives a restart.
- A blacklist of exact item names and name prefixes keeps valuables out, so a bin can't be used as a safe deposit.
- The server checks the player is really at the bin before opening it.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`

## Installation

1. Copy `pup-trash` into your resources folder.
2. Add `ensure pup-trash` to `server.cfg` after `oxmysql`, `vorp_core` and `vorp_inventory`.

There is no SQL to import and no items to add. Bin contents are stored by `vorp_inventory` itself.

## Commands

None.

## Configuration

### config/main.lua

| Setting | Meaning |
|---|---|
| `Config.General.wipeOnStart` | `true` deletes every bin's contents when the resource starts, which is what makes bins reset each restart. |
| `Config.Keys.interact` | Control hash for the open prompt (default `0x760A9C6F`, G). Change the hash only. |
| `Config.Integrations` | Empty. The bins only use `vorp_inventory` custom inventories. |
| `Config.Bins.label` | Title of the inventory window. |
| `Config.Bins.slots` | Item slots per bin. |
| `Config.Bins.promptRadius` | Distance in metres from a bin at which the prompt shows. The server allows an extra 1.5 m for lag. |
| `Config.Blacklist.items` | Exact item names that can never go in a bin. |
| `Config.Blacklist.prefixes` | Item name prefixes that can never go in a bin. On start the resource looks up every item in the `items` table that starts with one of these and blacklists it (covers pets, worn props and clothing, for example `pet_`, `pup_`, `pristine_`). |

### config/locations.lua

`Config.BinLocations` holds one entry per bin:

| Field | Meaning |
|---|---|
| `id` | Unique name. The bin's inventory id is `pup_trash_<id>`, so changing an id orphans that bin's inventory. |
| `coords` | `vector3` position of the bin. |

To add a bin, add a line:

```lua
{ id = 'val', coords = vector3(-285.399, 788.340, 118.630) },
```

### config/locale.lua

Text players see. Edit the text on the right and keep the keys.

| Key | Where it shows |
|---|---|
| `prompt` | Prompt button label |
| `group` | Prompt group header |
| `toofar` | Shown when the server refuses because the player is not at the bin |

## For developers

- Client to server event `pup-trash:open (binId)` asks the server to open a bin. The server checks the distance and calls `vorp_inventory:openInventory`.
- Inventory ids are `pup_trash_<id>`. They are removed when the resource stops.

No exports.

## License

See LICENSE.
