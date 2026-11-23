# pup-props

Permanent world props. Staff place props from the `vorp_admin` prop placer and they stay in the world across restarts. Each prop only exists as an object near a player and is deleted again when they walk away, so hundreds of props stay cheap.

## Features

- Props are saved in the database with position, rotation, frozen and collision flags, and an optional label.
- Distance streaming: only props within the render radius are spawned on each client.
- A grid of buckets keeps the per-pass cost the same whether there are 50 or 5000 props.
- Props are not networked: every client builds its own copy, so there is no entity ownership to fight over.
- Models that do not exist, or never finish streaming, are reported once in the F8 console.
- Who placed a prop is only visible to staff, never sent to clients.

## Requirements

- `vorp_core`
- `vorp_admin` (permission keys `place_world_props` and `delete_world_prop`, and the World Props page)
- `oxmysql`

## Installation

1. Import `sql/install.sql` (creates `world_props`). The server also creates the table on start if it is missing.
2. Add `ensure pup-props` to `server.cfg` after `oxmysql`, `vorp_core` and `vorp_admin`.
3. Give staff the `place_world_props` and `delete_world_prop` permissions in `vorp_admin`.

No items are needed.

## Commands

None. Props are placed and deleted from `vorp_admin`.

## Configuration

### config/main.lua

| Setting | Meaning |
|---|---|
| `Config.General.warnMissingModels` | `true` prints a model that does not exist or will not stream to F8, once, not every pass. |
| `Config.Streaming.radius` | Metres. Props inside this distance exist on the client. Spawning every placed prop on every client fills the object pool and can bring a server down, so raise this with care. |
| `Config.Streaming.scanIntervalMs` | Milliseconds between proximity passes. |
| `Config.Streaming.bucketSize` | Metres. Size of a grid cell used to find nearby props quickly. |

### config/locale.lua

Text staff see. `%s` and `%d` are filled in by the code, so keep them in the same order (`placed` and `removed` take the model, then the prop id).

## For developers

| Name | Side | Use |
|---|---|---|
| `NearestProp(maxDist)` | client export | The nearest placed prop within `maxDist` metres (default 10), and its distance |
| `PlacedCount()` | client export | How many placed props this client knows about |
| `adminList()` | server export | Every placed prop, sorted by id, including who placed it |
| `adminCount()` | server export | How many props are placed |
| `adminDelete(id, bySrc)` | server export | Delete a prop; returns `true` on success |

Net events:

- `pup-props:place (data)` client to server. `data` has `model`, `x`, `y`, `z`, optional `rx`, `ry`, `rz`, `frozen`, `collision`, `label`. Needs `place_world_props`.
- `pup-props:delete (id)` client to server. Needs `delete_world_prop`.
- `pup-props:hello` client to server. Asks for the full list (rate-limited to once per 5 seconds).
- `pup-props:all`, `pup-props:added`, `pup-props:removed` server to client.

## License

See LICENSE.
