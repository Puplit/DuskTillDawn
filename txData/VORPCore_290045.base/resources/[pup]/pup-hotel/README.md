# pup-hotel

Hotel rooms for RedM / VORP. A clerk at the front desk lets a room to a player for a number of days; the room door stays locked unless the guest holding it opens it, and the stay runs out on its own after a warning.

## Features

- Front desk menu for clerks: let a free room, extend a stay, turn a guest out, pick the guest from a list of nearby players.
- The guest has to accept the offer and pays from their own pocket; nobody can be charged without agreeing.
- Office menu for staff: change the nightly rate of each room tier and see the current guests.
- Guests can check their own stay at the desk.
- Room doors are locked by default and re-locked on eviction and expiry, with an optional key-in-the-lock animation and optional auto re-lock.
- Stays expire automatically, with a warning before they run out.
- Optional share of every payment paid into a pup_business ledger; the rest leaves the economy.
- In-game setup commands to find door names, print coordinates and add rooms without editing files.

## Requirements

- `oxmysql`
- `vorp_core`
- `pup-ui` (menus and input boxes)
- `vorp_admin` (optional; its permission system is used for staff checks, otherwise the admin groups are used)
- `pup_business` (optional; only needed for the ledger cut)

> **The example hotel needs a paid interior.** The Saint Denis hotel in `config/hotels.lua` and `config/rooms_custom.lua` uses the door names (`chav_hotel_*`) of Nello's paid Chevalier hotel interior, which is not included. Without that map its doors don't exist, so replace the example with your own hotel: `/hoteldoor` (see Commands) names the door you are aiming at, and `/hotelroom` adds it as a room.

## Installation

1. Run `sql/install.sql`, or let the resource create its two tables on first start. It is safe to run more than once.
2. Add `ensure pup-hotel` to `server.cfg` after `oxmysql`, `vorp_core`, `pup-ui` and (if used) `pup_business`.
3. No items or images are needed.
4. The setup commands are ACE-restricted. Allow them for your staff group, for example:
   ```
   add_ace group.admin command.hotelcoords allow
   add_ace group.admin command.hoteldoor allow
   add_ace group.admin command.hotelroom allow
   ```
5. The server writes rooms added in game to `config/rooms_custom.lua`, so the resource folder must be writable.

## Commands

| Command | Who | What |
|---|---|---|
| `/hotelcoords` | ACE | Prints your current position, ready to paste into the config |
| `/hoteldoor` | ACE | Names the door you are aiming at (its MLO name or hash) |
| `/hotelroom <hotel> <id> <tier> [door] [label...]` | ACE | Adds a room at the door you are standing at, live and saved to `config/rooms_custom.lua` |

## Configuration

### config/main.lua

**Config.General**
- `debug`: print debug info to the server console.

**Config.Keys**: prompt key hashes. Change the hash only.
- `desk`: front desk / office prompt (E by default, the same control doorlocks uses).
- `door`: lock / unlock a room door (SHIFT by default).

**Config.Integrations.society**: share of every room payment paid into a pup_business ledger; the rest is a money sink.
- `job`: business ledger the cut is paid into.
- `cutPercent`: percent of each payment. `0` turns it off.

**Config.Desk**
- `promptRadius`: desk / office prompt range in metres. Keep it under half the distance between the desk and the office points.

**Config.Staff**: who may work the desk.
- `permission`: vorp_admin permission that counts as staff.
- `jobs`: `{ [job] = minimum grade }`. Anyone on one of these jobs at this grade or above may work the desk. This is the only gate: the same grade also sets prices and evicts guests, so raise it to restrict those.
- `allowFreeAssign`: staff may waive the charge entirely.

**Config.Rent**
- `daySeconds`: real seconds one day of rent lasts (`86400` = a real 24 hours).
- `maxDays`: most days a clerk may sell in one go.
- `roomsPerCharacter`: rooms one guest may hold at once, across every hotel.
- `currency`: `0` = cash, `1` = gold.
- `sweepSeconds`: how often, in seconds, expired stays are swept up.
- `warnBeforeSeconds`: warn the guest this many seconds before their stay runs out.

**Config.Tiers**: room types, `{ label, price }`, price per day charged to the guest. Prices set in the hotel office override these and are stored in `hotel_settings` (key `price:<tier>`); an empty table means the config prices are used.

**Config.Doors**: room doors stay locked unless the guest holding the room opens one.
- `enabled`: `false` leaves room doors alone.
- `promptRadius`: metres. Keep it under half the distance between two neighbouring doors.
- `animation`: key-in-the-lock animation; `false` goes straight to the click.
- `relockSeconds`: re-lock a room this many seconds after it was opened. `0` = never.
- `enforceRadius`: lock state is lost when a door streams out, so it is re-asserted for doors within this many metres.
- `enforceIntervalMs`: milliseconds between re-asserts.

### config/hotels.lua

One entry per hotel, keyed by hotel id (the id used by `/hotelroom` and stored in the database).

| Field | Meaning |
|---|---|
| `label` | Hotel name, shown on menus |
| `desk` | `vector3`, front desk prompt (clerks let rooms, guests check their stay) |
| `office` | `vector3`, office prompt (staff: rates and current guests) |
| `blip` | `{ show = true/false, sprite = blip hash, name = map label }` |
| `rooms` | List of rooms, see below |

Each room:

| Field | Meaning |
|---|---|
| `id` | Room id, stored in the database. Never change it while rooms are let |
| `label` | Room name on menus and prompts |
| `tier` | A key of `Config.Tiers` (sets the price) |
| `door` | Door name from the MLO door list, or the hash `/hoteldoor` reports |
| `coords` | `vector3` at the door, where the lock prompt shows |

Example room:

```lua
{ id = 'room_12', label = 'Room 12', tier = 'basic', door = 'chav_hotel_room_12',
  coords = vector3(2749.854, -1353.306, 51.987) },
```

### config/rooms_custom.lua

Rooms added in game by `/hotelroom`. The server only ever appends to this file, so it must stay at this path, but it is ordinary config: lines can be edited or deleted by hand. Each line looks like:

```lua
HotelAddRoom('<hotel>', { id = ..., label = ..., tier = ..., door = ..., coords = ... })
```

### config/locale.lua

All text players see. `%s` / `%d` are filled in by the code; keep them in the same order.

## For developers

Server exports:

| Export | Returns |
|---|---|
| `exports['pup-hotel']:HasRoom(charid, hotelId, roomId)` | `true` if that character holds that room right now |
| `exports['pup-hotel']:RoomHolder(hotelId, roomId)` | `{ charid, guest, expiresat }` for the current stay, or `nil` |

Shared global `HotelAddRoom(hotelId, room)` adds a room at load time (this is what `config/rooms_custom.lua` calls).

Database tables: `hotel_rentals` (live room stays) and `hotel_settings` (office price overrides). The guest lookup uses the VORP `characters` table.

## License

See LICENSE.
