# pup_id

A character identity paper, drawn as a card-sized frontier certificate of about 1899. Players can look at their own, hand it to someone nearby, or read the paper of a restrained or dead person. Every detail is read live from the active VORP character; there is no item, price, job lock or database write.

## Features

- Shows full name, a matching signature line, occupation, age, the character number as a serial, and an issue date.
- The paper sits in the middle of the screen and never takes the mouse or keyboard.
- Occupation is the job key for "plain" jobs, otherwise the name of that job's society shop (the lowest-id shop with a name), otherwise the job key.
- Age is shown as "N years"; the row is hidden when the age is missing or zero.
- All papers are built on the server from VORP data. Clients only name a target, and never supply text that gets printed.
- Range checks, per-player cooldowns and an optional server-side restraint check stop misuse. An inspect from too far away is printed to the server console.
- Its fonts and the logo watermark are bundled in `html/`; it does not use pup-ui's theme fonts.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup_mercantile` (optional; its `society_shops` table supplies shop names for occupations. Without it the job key is printed.)

## Installation

1. Nothing to import into the database. `sql/install.sql` only explains that pup_id reads `society_shops` and creates nothing.
2. Add `ensure pup_id` after `vorp_core` and `oxmysql`.
3. No items, images or webhooks are needed.

## Commands

| Command | Who | What |
|---|---|---|
| `/myid` | Everyone | Shows your own paper to you only. |
| `/idcard` | Everyone | Hands your paper to the closest person within `HandOverRange`. Both of you see it. |
| `/takeid` | Everyone | Reads the paper of the closest person within `InspectRange` if they are hog-tied, cuffed or dead. Only you see it. With a paper on screen, it closes the paper instead. |

While a paper is on screen, `/myid` and `/idcard` do nothing. Release the close control or type `/takeid` to put it away.

## Configuration

All settings are in `config/main.lua`, shared by the client and the server. Change a value, then restart the resource.

| Setting | Meaning |
|---|---|
| `Commands.own` / `handOver` / `inspect` | The chat command names. pup-loading's help text names `/myid` and `/idcard`, so keep these unless you change that too. |
| `CloseControl` | Rockstar input hash. Releasing it closes the paper on screen. |
| `HandOverRange`, `InspectRange` | How close, in metres, the other person must be (checked on your own game). |
| `ServerRange` | The server refuses a hand-over or inspect when the two people are further apart than this, in metres. |
| `HandOverCooldownMs`, `InspectCooldownMs`, `OwnCooldownMs` | Per-player limits in milliseconds. Extra requests inside the window are dropped quietly. |
| `ServerRestraintCheck` | `true`: the server also confirms that the inspected person is dead, or asks that person's own game whether they are hog-tied or cuffed. `false`: trust the inspector's game alone. |
| `RestraintReplyTimeoutMs` | How long, in milliseconds, the server waits for that answer before refusing. |
| `IssueDate` | Text printed as the issue date on every paper. |
| `PlainJobs` | Job keys printed as they are, without looking up a society shop name. Add a line such as `ranger = true,`. |
| `TipMs` | How long the "not restrained" message stays, in milliseconds. |
| `Fonts` | No longer used by the paper, which has its own bundled fonts. |

The words on the paper and the "not restrained" tip are in `locale/en.lua`.

## For developers

Network events (all handled with server-side checks):

| Event | Direction | Purpose |
|---|---|---|
| `pup_id:requestOwn` | client to server | Ask for your own paper. |
| `pup_id:handOver` (targetId) | client to server | Hand your paper to a player. |
| `pup_id:inspect` (targetId) | client to server | Read a restrained player's paper. |
| `pup_id:show` (paper) | server to client | Display a paper. |
| `pup_id:restraintQuery` / `pup_id:restraintReply` | server to client / back | The server's restraint check. |

## Fonts

All bundled in `html/fonts/` under the SIL Open Font License 1.1; each licence text sits next to its font.

| Font | Use | Author | Licence file |
|---|---|---|---|
| Rye | Title | Sorkin Type Co | `OFL-Rye.txt` |
| IM FELL English (Roman and Italic) | Body text | Igino Marini | `OFL-IMFellEnglish.txt` |
| Mrs Saint Delafield | Signature | Alejandro Paul (Sudtipos) | `OFL-MrsSaintDelafield.txt` |

## License

See LICENSE. The fonts keep their own licence (above). `html/img/logo.png` is the Dusk Till Dawn logo.
