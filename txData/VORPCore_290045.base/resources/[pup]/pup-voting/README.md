# pup-voting

Mayoral elections across the regions of the territory. One election covers every region on one clock, and each account gets one vote per region, cast at a polling station.

## Features

- **Polling stations:** walk up to one and press G for the ballot. There is no `/vote`; a station is the only way to vote.
- **One vote per account, per region:** a second character on the same account does not get a second ballot. Enforced by a unique key in the database.
- **Confirmed votes:** a vote cannot be changed, so the player confirms it first.
- **Sealed counting:** while the polls are open nobody, staff included, sees a tally or the voter list. The numbers never leave the server until the polls close.
- **Results:** players see each candidate's share and the winner. Raw vote counts are staff only, and a region with too few votes shows players the winner without percentages.
- **Election office:** staff set up a draft, put real characters forward region by region, choose a run length, open the polls, close or reopen them, reschedule, delete, and see who voted for whom.
- **Master switch:** staff can turn voting off everywhere; polling stations disappear until it is turned back on. The state survives a restart.
- **Automatic close:** an election closes itself when its clock runs out, and the result is posted to the log.
- **Discord log:** optional, covering votes, opening, closing, rescheduling, deleting and results.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup-ui` (menus and input)
- Optional: `vorp_admin` (permission key for staff; without it only the admin group can run elections)

## Installation

1. Run `sql/install.sql`, or let the resource run it on start. The server splits that file on semicolons, so do not put semicolons in its comments.
2. Optional, for the Discord log: set `Secrets.Webhooks.election` in `server/config.lua`.
3. Optional: register the `manage_elections` action in `vorp_admin` (its `config/discord.lua` has it as `elections.manage`) and give it to your election staff.
4. Add `ensure pup-voting` to `server.cfg` after `vorp_core`, `oxmysql` and `pup-ui`.

No items or images are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/election` | Staff with `manage_elections` in `vorp_admin`, or the admin group | Opens the election office |

## Configuration

### config/main.lua

**Config.General**

| Field | Meaning |
|---|---|
| `command` | Staff chat command that opens the election office. |

**Config.Keys**

| Field | Meaning |
|---|---|
| `vote` | Control hash of the key that opens the ballot at a polling station (default G). Change the hash only. |

**Config.Integrations**

| Field | Meaning |
|---|---|
| `vorpAdmin.action` | `vorp_admin` permission key that covers everything in the office, including deleting. Falls back to the admin group. |

**Config.Election**

| Field | Meaning |
|---|---|
| `regions` | The regions a mayor can be elected for. The order here is the menu order. |
| `durationsHours` | Run lengths staff can pick, in hours. One clock covers every region. |
| `defaultDurationHours` | Run length of a new draft, in hours. |
| `minVotesForShare` | A region with fewer votes than this shows players the winner but no percentages. `0` always shows them. |
| `defaultEnabled` | Starting state of the master switch. Only used the first time the server runs; after that the state is kept in `election_settings`. |

**Config.Polling**

| Field | Meaning |
|---|---|
| `radius` | Distance from a station, in metres, at which the prompt shows. The player must also be within 3 m in height. |
| `locations` | List of `vector3` station positions. Add a line to add a station, e.g. `vector3(2593.95, -1305.88, 52.71), -- Saint Denis`. |

**Config.Logging**

| Field | Meaning |
|---|---|
| `name` | Webhook username. |
| `colour` | Embed colour, as a decimal number in a string, e.g. `'3447003'`. |
| `logo` | Embed thumbnail URL. `''` = none. |
| `footer` | Embed footer text. |
| `avatar` | Webhook avatar URL. `''` = none. |
| `votes` | Logs each vote as it is cast. |
| `identifiers` | Adds the account identifier to log lines. Off by default; only turn it on if the channel is staff only. |

### config/locale.lua

Every string players and staff see. Keep the `%s` / `%d` placeholders in the same order.

### server/config.lua

| Field | Meaning |
|---|---|
| `Webhooks.election` | Discord webhook URL for the election log. `''` turns logging off. |

## For developers

The client and server talk over `pup-voting:server:*` and `pup-voting:client:*` events; none of them are meant for other resources. There are no exports.

Database tables:

| Table | Purpose |
|---|---|
| `election_settings` | Key/value settings, including the `enabled` master switch |
| `election` | One row per election. `open = 0` with no `started_at` is a draft still being set up |
| `election_candidates` | Candidates, each a real character standing in one region per election |
| `election_votes` | Votes, unique per election, region and account |

## License

See LICENSE.
