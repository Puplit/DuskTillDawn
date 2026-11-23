# pup_railroad

Railroad companies for a RedM / VORP server. Company members buy trains and keys at their stations, bring trains out onto the tracks, keep them fed with coal, repair and upgrade them, carry cargo in each train's lockbox and run paid delivery routes.

## Features

- Company-owned trains, bought at company stations from a train shop with original SVG pictures.
- Train keys: players without a key are made to leave the driver seat (or any seat, see `Config.KeyCheckOnBoarding`).
- Driving aids: throttle lock, cruise control, coal burn while moving, track junction switching.
- Maintenance: trains wear as they burn coal and are repaired with materials; speed and engine upgrades in tiers.
- A lockbox per train for cargo, stored with the train.
- Paid delivery routes grouped by circuit, with a stop-by-stop cargo hand-over.
- Dispatch board: drivers call ahead to stations; status calls (stop, clear, turnaround) reach the platforms.
- Anyone can sit on train seats and on the Saint Denis platform chairs.
- Abandoned or vanished trains are cleaned up by a server sweep.
- The server decides every amount, price, payout and permission; the client only reports what it sees.
- Optional Discord log of train and delivery events.

## Requirements

- OneSync (the server's distance checks depend on it)
- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- Optional: `pup_business` (company Discord webhooks; it handles the container reload event while `Config.BusinessIntegration` is on)

## Installation

1. Put `pup_railroad` in your resources folder.
2. Run `sql/install.sql` (safe to run more than once). It creates `player_trains` and, if missing, the shared `container` table, and adds the items it needs: `alcohol`, `bolts`, `clay`, `coal`, `copper`, `copper_bar`, `fertilizer`, `fibers`, `ironbar`, `ironhammer`, `legbisons`, `legprongs`, `medical_box_bag`, `rock`, `shellcasing`, `stim2`, `string`, `trainkey`, `wooden_boards`, `wool`.
3. Add images for those items to `vorp_inventory/html/img/items/` if you do not have them.
4. Add `ensure pup_railroad` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui` (and after `pup_business` if you use it).
5. Optional Discord log: set `Webhooks.train` to a staff Discord webhook URL in `server/config.lua` (server only, never sent to players). Leave it empty to turn the log off.
6. Make a job for your company (default `standardtrain`) and give it to your railroad staff.

## Commands

| Command | Who | What |
|---|---|---|
| `/dv` | anyone | put away your current or last vehicle; for trains the server checks what may be deleted. The name is `Config.DeleteCommand` |

Everything else is done with prompts at stations and in the driver seat (keys in `Config.Keys`).

## Configuration

All files are in `config/`. Text is in `locale/en.lua`.

### config/main.lua

- `Config.Debug`: extra console output.
- `Config.DeleteCommand`: the delete-vehicle command name.
- `Config.KeyItem`, `Config.CoalItem`: item names for the train key and coal. `Config.KeyPrice`: cash price of a key.
- `Config.LockboxBlacklist`: items that can never be put in a train lockbox.
- `Config.CruiseControl`: allow cruise control.
- `Config.KeyCheckOnBoarding`: anyone without a key who climbs into any train is made to leave it. `false` = only the driver seat is checked.
- `Config.Maintenance`:
  - `wearPerCoal`: wear lost per coal burned (a train starts at 100).
  - `jobs`: jobs that may repair.
  - `repairAtOrBelow`: a repair is only allowed at or below this wear.
  - `promptAtOrBelow`: the maintenance prompt shows at or below this wear.
  - `materialSets`: `[wear] = { { item, count }, ... }`. The set whose key is nearest the train's current wear is used.
- `Config.Upgrades`:
  - `jobs`: jobs that may upgrade.
  - `speedCap`: highest top speed in MPH.
  - `speed`: one entry per tier; `amount` is the MPH added, `materials` its cost.
  - `engine`: one entry per tier; `amount` is the seconds per coal added. A train that burns no coal cannot get engine upgrades.
  - `exitAfterWork`: repair and upgrade work ends by making the player step out of the train.
- `Config.Announcements`:
  - `enabled`, `boardEnabled` (the dispatch board in the driver seat), `job` (who may use it).
  - `cooldown`: seconds per player.
  - `platformRadius`: status calls reach players this many metres from a station.
  - `hearingDistance`: default reach in metres of a route call around the destination (a station's `hearing` overrides it).
  - `statusEverywhere`: status calls reach every platform on the map; `false` = only the platform of the station the call comes from.
  - `statuses`: the status calls offered (`key`, `label`, `description`, `text` = locale key).
- `Config.Reach`: distances in metres (server checks are full 3D): `station`, `train`, `stopPlayer`, `stopTrain`, `junction`, and `junctionPrompt` (client, horizontal).
- `Config.MinRouteDistance`: a route can only be started at least this many metres from its first stop. The same value is used by the client route picker and the server check.
- `Config.AbandonedSeconds`: a train with no driver and no running route for this long is put away.
- `Config.BusinessIntegration`: while on, `pup_business` owns `pup-Container:reloadContainerInventory` and this resource does not register it.
- `Config.Timings`: each value has its unit next to it (`s`, `ms` or `m`). `spawnPermit` (how long a spawn permission lasts), `burnSlack`, `sweep` (seconds between server sweeps), `missingDrop` (a train the server cannot see for this long is dropped), `switchGap`, `stationPrompt`, `lastStation` (radius for "last station passed"), `keyRecheck`, `stopped` and `movingAtStop` (speeds), `stopPrompt`, `workDuration` (repair/upgrade work), `announceNotice`, `inputTimeout`, `deliverAnswer`.
- `Config.Seats`: the train seat and chair scenarios (spelt as the game spells them), the Saint Denis chair area (`chairCentre`, `chairRadius`), `searchRadius`, `maxPoints`, and `settleGrace` / `pressCooldown` in ms.
- `Config.Keys`: control hashes for each prompt; the key is noted next to each.
- `Config.Blips`: sprites, scales, modifier and GPS colour for stations, trains and stops.
- `Config.WorkScenario`: the scenario played during repair/upgrade work.
- `Config.StartupSwitches`: switch states every client applies at start (`track`, `index`, `value`).
- `Config.SpawnSetsCruiseSpeed`: the stored top speed is also written as the train's cruise speed when it is created. Turn off if trains roll away on their own.
- `Config.Natives`: the track switch and direction native hashes, kept here so they can be changed without touching code.

### config/stations.lua

`Config.StationBlipSprite` and `Config.Stations`. Each station is `{ key, name, coords, job, circuit, hearing }`:

- `key`: internal name used by announcements.
- `name`: shown on the blip and menus.
- `job`: the company that uses it.
- `circuit`: the route circuit served from it.
- `hearing`: optional route-call reach in metres.

### config/trains.lua

Trains for sale, in shop order. Copy one line inside `trains` and change the values:

| Field | Meaning |
|---|---|
| `name` | name on the shop card and the train's default name once bought |
| `picture` | art key: `html/img/<picture>.svg` is shown on the shop card |
| `hash` | the train configuration hash, as the game gives it. Hex (`0x3EDA466D`) or decimal (`-1464742217`) both work; it is stored as its unsigned decimal |
| `topSpeedMph` | top speed a newly bought train starts with (speed upgrades add to it) |
| `price` | cash price in the shop |
| `secondsPerCoal` | seconds of movement one coal lasts (0 = burns no coal) |
| `coalCapacity` | how much coal the train can hold |
| `disabled` | optional; `true` = not sold and not recognised as a shop train |

Example: `{ name = 'Train 1', picture = 'Train1', hash = -1464742217, topSpeedMph = 20, price = 500, secondsPerCoal = 10, coalCapacity = 1000 },`

Below the list is a block marked "Nothing to edit below" that converts it for the code.

### config/routes.lua

Delivery routes, grouped by circuit (`newhanover`, `newaustin`, `ambarino`). A circuit is just a group of routes; you can add a new one. Copy a whole route block (from `{ name = ...` to its closing `},`) inside a circuit and change it:

- `name`: must be unique across all circuits (a route is chosen by its name).
- `description`: the line shown under the route in the picker.
- `shownTotal`: the reward shown in the picker and logs only; it is not what is paid.
- `stops`: in the order they must be driven. The route can only be started at least `Config.MinRouteDistance` from the first stop.

Each stop:

- `stop`: the stop's name (map blip and menus).
- `position`: where the train and the player must be to deliver.
- `pay`: cash paid when this stop is delivered (the real money).
- `cargo`: items handed over at this stop, each `{ item = 'inventory_item', label = 'Shown name', count = n }`.

```lua
{
    name = 'My Route', description = 'Short run to Rhodes.', shownTotal = 300,
    stops = {
        { stop = 'Rhodes', position = vector3(1229.50, -1298.20, 76.95), pay = 300, cargo = {
            { item = 'wool', label = 'Wool', count = 10 },
        } },
    },
},
```

### config/junctions.lua

Track junctions the driver can switch. The top of the file has step-by-step instructions. In short:

1. Stop a train just before the switch, facing the way you want the prompt, and note your position and heading.
2. Copy a line from the list and paste it at the end, under **YOUR NEW JUNCTIONS GO HERE**.
3. Fill in the values, restart the resource and test both buttons. If left and right are the wrong way round, swap `switchLeft` and `switchRight`.

| Field | Meaning |
|---|---|
| `position` | where the junction is; the Switch Left / Switch Right prompts show when a train is near the closest junction (`Config.Reach.junctionPrompt`, flat distance) |
| `facing` | the train's heading must be between `min` and `max` degrees for the prompts to show. The range may run past 360: `{ min = 355, max = 365 }` covers 355 to 5 |
| `track` | a track name from the `Tracks` table at the top of the file (add a new track there once, then use its name) |
| `junction` | the junction's number on that track |
| `switchLeft` / `switchRight` | the switch value set when the driver presses Switch Left / Switch Right |

An entry's place in the list is its id (shown as `-- id N` at the end of each line), so always add new junctions at the end and never move or delete lines in the middle. To switch one off, put `--` in front of it.

**Spooni add-on track (paid):** the entries in the **SPOONI ADD-ON TRACK** block (ids 27-36), the `SPOONI_TRACK_*` names in `Tracks`, and the two `Config.StartupSwitches` lines in `config/main.lua` need Spooni's track add-on maps, which each server owner has to buy from Spooni. They are not included. Without them those switches do nothing; leave the lines in place.

Other known FREIGHT_GROUP junction points, not active (left out because they were replaced by the Spooni entries or sit too close to others):

| Junction | Position | Facing | Left | Right |
|---|---|---|---|---|
| 4 | -1307.26, -291.26, 100.096 | 5-15 | 1 | 0 |
| 5 | -1375.64, -137.358, 100.036 | 210-225 | 0 | 1 |
| 16 | 2842.43, -1330.06, 45.1738 | 141-151 | 0 | 0 |
| 17 | 2765.4, -1421.54, 45.10255 | 300-321 | 0 | 0 |

## For developers

- Client to server requests use one event: `TriggerServerEvent('pup_railroad:call', name, reqId | nil, ...)`, answered with `TriggerClientEvent('pup_railroad:reply', src, reqId, result)`. Handlers can set a minimum gap between calls per player.
- Lockboxes are `vorp_inventory` custom inventories backed by the `container` table; their contents are also copied to `player_trains.items`.
- The resource listens for `pup-Container:reloadContainerInventory` only while `Config.BusinessIntegration` is off.
- No exports.

## License

See LICENSE.
