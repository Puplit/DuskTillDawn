# pup-medical

Job alerts, call pay, duty, doctors and the death screen for a VORP RedM server. Players call for a doctor or any other service, responders accept and get a route, doctors revive and bandage, and dying runs through its own death screen and respawn rules.

## Features

- **Job alerts.** Players call for a doctor (`/alertmedic`), a train conductor (`/alerttrain`) or any other service set up in `config/alerts.lua`. Job holders who are on duty get a notice, open the calls with `/alertmenu`, and pick Accept, Deny or Back. Accepting marks the caller on the map (exact blip or a search circle) and sets a GPS route. `/calert` withdraws your calls.
- **Free respawn.** If nobody is on duty, or a downed caller is not answered in time, the respawn costs nothing.
- **Call pay.** Responders who answer a call and then treat the caller are paid by the distance they rode.
- **Duty.** `/duty` puts doctor, pharmacist, barber-surgeon and conductor jobs on or off duty. `/dutycheck` prints a duty report to the server console. pup_business is used as a fallback roster.
- **Doctors.** `/med` opens the treatment menu with revive (uses a syringe) and bandage. Shared medical cabinets refill themselves when opened.
- **Back-alley syringe.** Anyone can use it. It may fail, and it is used up either way.
- **Weakness.** After a revive the player cannot sprint or draw weapons for a while.
- **Death.** Its own death screen, free-look death camera and hold-to-respawn prompt, with respawn at the nearest point. What a respawn takes is written to `death_losses`, and staff can give it back from vorp_admin.
- **Purge.** While the pup-events purge is live, the respawn rules in `Config.Purge.overrides` apply.
- Discord logs for alerts, paid calls, respawn losses, duty and revives.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui` (menus)
- `pup_business` (optional; fallback duty roster)
- `pup-events` (optional; the purge event)
- `pup_railroad` (optional; marks the train stations the TrainService alert uses)

## Installation

1. Run `sql/install.sql` once. It creates `death_losses` and adds the `bandage`, `syringe` and `illegalsyringe` items. It is safe to run more than once, and the resource also creates the table at start if it is missing.
2. Set the Discord webhooks you want in `server/config.lua` (see below).
3. Add `ensure pup-medical` to `server.cfg` after `vorp_core`, `vorp_inventory`, `oxmysql` and `pup-ui`.
4. In vorp_core, the respawn button must stay off (`CanRespawn` returns false) and so must its death camera (`UseDeathCam = false`). This resource handles both.
5. Restart the whole server after adding the items, so vorp_inventory loads them.

## Commands

| Command | Who | What |
|---|---|---|
| `/alertmedic` | Anyone (also while dead) | Call a doctor |
| `/alerttrain` | Anyone near a train station | Call a conductor |
| `/calert` | Anyone | Withdraw your open calls |
| `/alertmenu` | On-duty responders | The list of open calls: Accept, Deny or Back |
| `/duty` | Duty jobs (`Config.Duty.jobs`) | Go on or off duty |
| `/dutycheck` | Anyone, or the ACE in `Config.Switches.dutycheckAce` | Prints a duty report to the server console |
| `/med` | Doctor jobs | Treatment menu: revive and bandage |
| `/callpay` | Server console | Lists open paid calls |

Alert commands come from `config/alerts.lua`; the duty command name is `Config.Duty.command`.

## Configuration

### config/main.lua

- `Config.General.language`: which language from `config/locale.lua`.
- `Config.General.debug`: console / F8 traces per module (`alerts`, `callPay`, `death`, `duty`, `medical`).
- `Config.Integrations.business.resource`: duty roster fallback; `/med` needs its on-duty state.
- `Config.Integrations.events.resource`: the resource that runs the purge event.
- `Config.Logs.avatarUrl`: Discord avatar for revive / duty logs (`""` = webhook default).
- `Config.Duty`: the built-in `/duty` command name and the `jobs` it applies to.
- `Config.Purge`: while the purge with `eventKey` is live, `overrides` replace the same keys of `Config.Death.prompt`; the saved values come back afterwards.

### config/alerts.lua

**Keys**: `alertAccept` (SPACE), `alertDeny`, `alertBackOut` (back to the menu), `stationAlert` (send from a station).

**Config.Alerts**
- `requireOnDuty`: responders must be on duty.
- `countSelfAsResponder`: whether the sender counts as a responder for their own alert.
- `cancelCommand`: the command that withdraws your calls.
- `menuAlign`: where the call list opens.
- `noDoctorsNoLoss`: if nobody is on duty, a dead sender respawns free.
- `freeRespawn.enabled` / `freeRespawn.waitMinutes`: a downed call left unanswered this many minutes means a free respawn.

**Alert types** (`Config.Alerts.types`): copy one to add another. Keep the name `Medical`; other code and the death rules look for it.

| Field | Meaning |
|---|---|
| `command` / `suggestion` | Chat command and its help text |
| `jobs` | Jobs that receive it |
| `senderJobs` | Optional; who may send it |
| `mode` | `"blip"` (exact blip + GPS) or `"radius"` (search area, using `radius` and `radiusColor`) |
| `blipSprite` / `blipColor` | Map blip for the call |
| `notifyJob` | Notice sent to responders |
| `notifyPlayer` | Sent to the caller when someone accepts; `%` = where help set off from |
| `alertSent` | Shown to the caller when the alert goes out |
| `deadCanUse` | May be sent while dead |
| `stations` | `{}` = send from anywhere, or a list of `{ coords, blip, blipName }` to send only near one (within `stationDistance` metres). `blip = false` hides the station blip |
| `stationPrompt` | Hold a prompt at the station instead of typing the command |
| `promptDistance` | Metres for the station prompt |
| `busyOnAccept` | A responder handles one alert at a time |
| `log` | Post to Discord |

**Config.CallPay**: responders are paid by distance travelled, once the job is done.
- `enabled`, `jobs` (`{ job = true }`).
- `minDistance` / `maxDistance`: at or below `minDistance` pays `minPay`; at or above `maxDistance` pays `maxPay`.
- `curve`: `1.0` = straight line between the two.
- `variationPercent`: random spread, `0.20` = +/- 20%. `variationFlat`: a flat random spread.
- `completeDistance`: metres from the patient to complete the call.
- `payOnHeal`: a bandage also completes a call.
- `timeoutMinutes`: open calls are voided after this.
- `currency`: `0` cash, `1` gold, `2` rol.

### config/death.lua

- `Config.Keys.respawn`: hold to respawn (R).
- `loss`: what a respawn takes (`items`, `weapons`, `cash`, `gold`, `rol`). Losses only apply in water, or when a medic is on duty and the player was not told "no doctors".
- `lawJobs`: never lose weapons. `keepWeapons` / `keepItems`: never taken.
- `prompt.respawnDelaySeconds`: `0` = instant. `prompt.holdMs`: how long R is held. `prompt.alertCommand`: shown on the death screen; match the Medical alert's command.
- `respawnPoints`: the respawn goes to the closest one.

### config/medical.lua

- `Config.Keys.cabinet`: open a cabinet (SPACE).
- `doctorJobs`: may use `/med`, cabinets, revive and bandage. `reviveItem` / `healItem`: the items used.
- `policeRevive`: revive with no item, for the listed `jobs`.
- `cabinet`: shared storage for on-duty doctors, refilled to `stock` when opened. `limit` = items it holds (`0` = unlimited); `restockMinutes` (`0` = refill on every open); `locations`.
- `illegalSyringe`: black-market revive anyone can use; used up even when it fails. `reviveRange` (metres), `useTimeMs`, `failChance` (%).
- `recovery`: after any revive, no sprinting or weapons for `durationSeconds`. `effect` is a screen effect (`""` = none).

### config/zones.lua

Map zone names, keyed by the zone hash the game returns for a position: `[<zone hash>] = "<display name>"`, for example `[-1004072985] = "LOWER MONTANA RIVER",`. They name where an alert was sent from (alert menu, logs, "help is on the way from ..."), and the server checks a client-sent zone name against this list. Add a zone by adding a line; a position with no entry shows as "Unknown".

### config/locale.lua

Every line of player text. Pick the language with `Config.General.language`. Any key a language leaves out falls back to English. `%s` / `%d` are filled in by the code.

### shared/switches.lua

Behaviour switches. To keep these with your own settings, define `Config.Switches` in one of the config files; any key set there wins over the default.

- `busyBlocksAccept`: a responder who is already busy on a call may not take a second one.
- `medicsFromAlertType`: respawn losses count every job of the Medical alert type as a medic (`false`: only doctor and pharmacist).
- `recoveryOnRespawn`: a respawn (not just a doctor's revive) starts the weakness period.
- `dutycheckAce`: ACE permission needed for `/dutycheck`; `""` = any player may run it.
- `mergeDutyLogs`: one duty log per toggle: the per-job channel when it is set, else the general one.

### server/config.lua (webhooks)

Server only, never sent to players. An empty string switches that log off. The values go in the `Hooks` table.

- `alertDefault` and `alerts.<type>.default` / `alerts.<type>.jobs.<job>`: job alerts. The type's own channel beats `alertDefault`; a job entry beats both.
- `callPay` and `callPayByJob`: completed paid calls; the responder's job channel first, then `callPay`.
- `death`: respawn losses.
- `duty` and `dutyByJob`: every `/duty` toggle, plus a per-job channel.
- `reviveAdmin` and `reviveByJob`: every revive, plus a per-job channel (`illegal` = back-alley syringe).
## For developers

Server exports (`exports['pup-medical']:...`):

| Export | What |
|---|---|
| `IsPlayerOnDuty(source, job)` | `true` if on duty (own register, then pup_business) |
| `GetOnDutyPlayers(job?)` | `{ { source, job, since } }`, optionally for one job |
| `GetOnDutyCount(job?)` | Number of players on duty |
| `GetAlertNumbersForJob(job)` | Open alerts that job can answer |
| `GetCloseRegion(job, coords, distance)` | Open alerts within `distance`: `{ id, jobType, coords, distance }` |
| `GetCurrentAlertedJobs()` | Every job that receives some alert type |
| `GetCurrentAlertedJobsByIndex(typeKey)` | Jobs of one alert type, or `false` |
| `GetAllCurrentAlerts()` | `{ [typeKey] = { [id] = alert } }` |
| `GetCurrentAlertByIndex(typeKey)` | `{ [typeKey] = { [id] = alert } }`, or `false` |
| `FinishAlert(typeKey, src)` / `RemoveAlert(src, typeKey)` | Removes that player's alert of that type |
| `InsertAlert(src, command)` | Sends an alert for a player by its command (e.g. `'alertmedic'`) and notifies responders |
| `GetDeathLosses(limit?, charid?)` | Recent `death_losses` rows (used by vorp_admin) |
| `RestoreDeathLoss(id, adminName)` | Gives a loss back to an online character; returns `ok, reason` |
| `PurgeDeathStatus()` | Whether the purge overrides are applied |

Client exports: `SkipNextRecovery()` (the next revive skips the weakness), `CancelRecovery()` (ends a running weakness period) and `PurgeDeathStatus()`.

Events it listens to: `pup-events:server:state (key, on)` on the server and `pup-events:state (key, on)` on the client, for the purge.

## License

See LICENSE.
