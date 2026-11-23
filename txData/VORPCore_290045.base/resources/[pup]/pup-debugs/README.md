# pup-debugs

Server and client diagnostics for RedM / VORP, so you can find out why things go wrong instead of guessing. It records why players drop before reaching the world, server stalls, resource starts and stops, and players who end up "instanced" (in the world but invisible to everyone else).

## Features

- **Drops:** every client reports its load stage (loading, character selection, creator, playing), its worst freeze and its streaming flags. When a player leaves before reaching the world, the report says which stage they were in, whether they were stuck on streaming, and, for a crash, the faulting module FiveM reports (ntdll, d3d or heap point at memory; a resource dll points at that resource).
- **Server load:** a thread asks to wake at a fixed interval, and however late it wakes is how far behind the server is. Stalls are logged, big ones go to a webhook, and a rolling summary is written to the log.
- **Resources:** every start and stop is logged, and a restart storm (one resource starting several times in a short window) is sent to a webhook.
- **Instanced-player check:** a player whose ped never registers with the server sees a normal world, but nobody can see them and only a relog fixes it. The client compares its own view with the server's, and only when a complete failure repeats several times does it draw a warning on screen and log the fault.
- **Profiler and resource monitor shortcuts:** per-resource CPU is not available to server Lua, so `/pupdebug profile` records a profile with the built-in profiler and `/pupdebug resmon` opens the Windows server GUI resource monitor. See https://docs.fivem.net/docs/scripting-manual/debugging/using-profiler/
- No per-event console output: reports go to log files and webhooks only, plus one startup line and whatever `/pupdebug` is asked for.

## Requirements

- No other resources. It only reads public natives and never reaches into `vorp_character`, so it cannot break the character creator.

## Installation

1. Put `pup-debugs` in your resources folder and `ensure pup-debugs` (early is best, so it sees other resources start).
2. For Discord reports, set the webhook URLs in `server/config.lua`. Empty URLs mean file and console only.
3. Give staff the ace for the command, for example:
   ```
   add_ace group.admin command.pupdebug allow
   ```

No SQL or items are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/pupdebug load` | ace `command.pupdebug`, or the console | How far behind the server scheduler is: average, worst, stalls |
| `/pupdebug resources` | same | Resources not started, plus restart counts in the storm window |
| `/pupdebug joins` | same | Players stuck short of the world, live: stage, last beacon, freeze, streaming flags |
| `/pupdebug profile [n]` | same | Record `n` frames (default 500) to `pup-debugs-profile.json` in the server's working folder (where `FXServer.exe` was started from). Open it in Chrome DevTools (Performance > Load profile) |
| `/pupdebug resmon` | same | Open the server GUI resource monitor (Tools > Resource Monitor), live per-resource ms and memory. Windows only |

Output is printed to the server console.

## Configuration

### config/main.lua

**Config.General**
- `writeLogFiles` - `true` = append reports to the log files below.
- `dropLogFile` - player drops and instanced players.
- `serverLogFile` - server stalls, load summaries, resource starts and stops.
- The log files are written at the top level of the resource on purpose: `SaveResourceFile` will not create a missing folder, so keep the names flat.

**Config.Drops** - why a player left before reaching the world.
- `beaconPreSessionMs` - ms between client reports during loading, selection and the creator.
- `beaconInSessionMs` - ms between reports once in the world.
- `hitchMs` - a frame longer than this (ms) is a hitch; the client reports the worst one per window.
- `creatorCoords` / `creatorRadius` - centre of the character creator area (from `vorp_character`) and its radius in metres. Only used to name the stage.
- `onlyPreSession` - `true` = report only drops that happened before the player reached the world.

**Config.ServerLoad**
- `tickIntervalMs` - ms between wake-ups.
- `warnMs` - ms late that is logged as a stall.
- `alertMs` - ms late that is also sent to the load webhook.
- `reportSeconds` - seconds between rolling load summaries in the server log.

**Config.Resources**
- `enabled` - `true` = watch resource starts and stops.
- `stormCount` / `stormWindowSeconds` - this many starts of one resource within this many seconds is a restart storm (sent to the webhook).

**Config.SyncCheck** - the instanced-player check. The warning text is `Locale.instancedWarning`.
- `enabled` - `false` = never probe.
- `graceSeconds` - seconds after character select before probing starts.
- `intervalSeconds` - seconds between probes.
- `timeoutSeconds` - seconds before an unanswered probe is discarded.
- `maxProbes` - give up after this many probes if nothing is confirmed.
- `strikes` - consecutive matching failures before the warning shows.
- `clearSamples` - consecutive good samples before the check stops for good.
- `color` - warning colour `{ r, g, b }`.
- `x` / `y` - warning position on screen, 0.0 - 1.0 from the left and from the top.

### config/locale.lua

Player-facing text. Change the text, keep the keys. `instancedWarning` is drawn on screen when the sync check confirms the fault.

### server/config.lua

Server only, never sent to players.
- `Webhooks.drops` - Discord webhook for player drops before the world and instanced players.
- `Webhooks.load` - Discord webhook for server stalls and restart storms (can be the same URL).

## For developers

No exports. Client and server talk over the resource's own events only.

## License

See LICENSE.
