# pup-mdt

The law and justice terminal for a 1904 western RedM server on VORP: a parchment clipboard for lawmen and attorneys, plus the public records kiosk, the bounty hunter board and the prison register.

- **Law:** duty clock with patrol regions, roster and profiles, citizen records, penal code, arrests (totals from the penal code), instant fines, prison (server-owned sentences, labour, cells), bounties, Most Wanted, reports, cases, witness statements, evidence catalogue, physical evidence lockers, alerts and area call-outs, department ledger and payroll, bulletins, audit log.
- **Legal side:** bail, appeals, expungements, case defense, bar roster, firm notice, counsel calls (`/lawyer`).
- **Public:** records kiosk (own record, people search, inmates, bounty board, penal code, tips), bounty hunter board, prison register board.

## Requirements

`oxmysql`, `vorp_core`, `vorp_inventory` (with its evidence bridge and `seizeWeaponToCustomInventory`). Optional: `pup-ui` (menus, prompts), `pup-misc` (search target, cuff release), `pup-events` (purge stand-down).

## Install

1. Run `sql/install.sql` once (safe to run again). It creates every `mdt_*` table, `evidence_lockers`, the `mdt` item and a 64-charge penal code.
2. Fill in `server/config.lua` (Discord bot token, guild and role for the on-duty role; webhook URLs). Blank values switch that part off. Never publish this file filled in.
3. `ensure pup-mdt` after its dependencies.

## Configuration

| File | Holds |
|---|---|
| `config/config.lua` | language, law jobs, duty (regions, AFK, restart lock), profiles, features, audit, jail limits, direct fines, bounty rewards, permission table |
| `config/legal.lua` | attorneys, firm, bail, counsel, ledger, payroll |
| `config/prison.lua` | prison points, cells, local stations, register board, labour |
| `config/world.lua` | alerts, area call-outs, public records, tips, bounty board, evidence lockers, zone lookups |
| `config/confiscation.lua` | confiscation picker lists (contraband also feeds `GetContrabandItems`) |
| `server/config.lua` | server-only: Discord bot and webhooks |
| `locales/en-us.lua` | all player text (`ui_*` screen text in `locales/ui_en-us.lua`) |

## Rules worth knowing

- Every action that changes something needs the lawman or attorney to be **on duty**; reading works off duty.
- The **server owns every sentence**: it counts the time, pulls escapees back, applies labour and releases. Every release teleports the prisoner to the prison exit.
- `Config.Prison.offlineCountdown = true` keeps a sentence counting down while the prisoner is offline (once a minute). One that runs out is released, and the player is walked to the exit when they next load in. The clock only runs while the server is up.
- **Fines** are taken from cash at once and credited to the fining department's ledger. Cash never goes below zero: a citizen who can't cover the fine pays what they have, and only that amount reaches the ledger (the officer is told how much was collected).
- Arrest totals are **recomputed from the penal code**; the target must be the citizen named.
- **Distance:** `/jail` and a processed arrest that fines or jails need the citizen within `Config.Jail.targetDistance` (10 m); `/mdtbill` within `Config.Fines.billDistance` (10 m).
- **`/mdtbill`** is capped at `Config.Fines.maxDirectBill` ($5000), the same citizen can be billed once every `Config.Fines.billCooldownSeconds` (60 s), and every bill goes to the audit log (`fine_direct`).
- **Bounty rewards** are paid from the `Config.Bounties.ledgerJob` ledger (`police`) and capped at `Config.Bounties.maxReward` ($5000). A bounty is only posted (or its reward raised) when the ledger covers it at that moment; nothing is held back, so the payout is an atomic debit and a short ledger refuses the claim. With the ledger off, rewarded bounties cannot be posted or claimed (set `payHunter = false` to post without rewards).
- **Bounty claims:** the hunter must be within `Config.BountyBoard.claimDistance` (3 m) of the target by the server's own check; the target's client answer (hogtied, cuffed, carried or downed) can only refuse a claim.
- Deleting a citizen record or an evidence item needs `deleterecords`. Department settings load and save with `createlawmen`; firm settings load with `viewbarroster` or `firmsettings` and save with `firmsettings`.
- Bail is refunded when the citizen appears in court (`Config.Legal.bail.refundOnAppear`).
- Bail and appeals act only on the sentence they were filed for; a pending one for an earlier sentence is closed when a new one is filed. Nobody rules on their own filing or their own case, and nobody approves the expungement of their own record (`Config.AllowSelfExpungementApproval` only covers approving a petition one filed for someone else).
- Every lawman may edit their own profile (callsign, region, notes, photo); other profiles and certifications need `Config.Profiles.editGrade`, leave needs `createlawmen`. Termination or profile deletion also clears that lawman's permission overrides.

## Commands

`/mdt`, `/onduty`, `/offduty`, `/jail <id> <minutes> [reason]`, `/unjail <id>`, `/jailtime`, `/mdtbill <amount> <id>`, `/down`, `/backup`, `/alertlaw`, `/cancelalert`, `/drugalert` (test alert; off unless `Config.RadiusAlerts.testEnabled`, then admins only, ace `command.drugalert`), `/cleardrugalerts`, `/lawyer`, `/cancellawyer`, `/mycoords` (admins only, ace `command.mycoords`, unless `Config.Debug`; prints your position to the server console; `Config.CoordsCommand = false` turns it off).

## Exports (server)

`IsPlayerOnDuty`, `SetPlayerDuty`, `GetPlayersOnDuty`, `GetDutyRegion`, `GetRankNameByGrade`, `updateLawmanStats`, `SendPoliceAlert`, `SendDetailedAlert`, `SendEmergencyAlert`, `SendBackupAlert`, `SendPoliceAlertFromClient`, `SendRadiusAlert`, `IsAlertSystemEnabled`, `GetAlertConfig`, `GetAlertResponses`, `ZoneNameFromCoords`, `LogDiscord`, `GetEvidenceStationNear`, `GetContrabandItems`, `GetLawJobs`, `SeizeItemToEvidence`, `GetJailInfo`, `IsJailed`, `GetJailTime`, `GetJailMinutes`, `GetJailInfoBySource`, `IsJailedBySource`, `GetJailTimeBySource`, `GetAllJailed`.

Client: `IsOnDuty`, `GetZoneName`, `SendPoliceAlertFromClient`, `SendPoliceAlert`, `GetEvidenceStations`.

## Licence

GPL-3.0-or-later, see `LICENSE`.
