# pup_robbery

Walk-up robberies, multi-stage bank heists and a travelling fence for RedM on VORP. Masked riders hit forts, stores and camps, posses take bank jobs from the fence, and the fence buys the stolen goods and pays out later by letter.

## Features

- **Walk-up robberies** at ten places: Armadillo Fort, Fort Mercer, Fort Wallace, Lemoyne Fort, the Blackwater and Saint Denis general stores, the Antenor riverboat, the oil rig, the Mount Hagen camp and Thieves Landing.
  - A masked rider starts a job by firing a gun near the place (or by pressing G, if the place is set to `press`).
  - On-duty lawmen in the region get a tip and a blinking map blip, and pup-mdt gets a board alert.
  - Boxes unlock after a delay or once every wave of guards is down. Each box is a minigame, and the server rolls the loot.
  - Personal and per-place cooldowns, posse rider counts, perk bonuses (double loot, extra cash, shorter cooldowns, solo jobs) and gang points.
- **Bank heists** at Armadillo, Rhodes and Saint Denis, handed out by the fence.
  - An optional prep step (cut the alarm line), several ways in, a vault plan drawn at random for each run, an optional clue that reveals part of the vault code, loot spots and a getaway.
  - A five-level alarm (quiet to vault alarm), guards, police board alerts, a time limit inside, dynamite charges with a fuse.
  - Bank doors are held locked unless a live run has opened them.
  - Each run is written to a history table, and bank cooldowns are stored in the database.
- **The fence.**
  - Moves between six stops and pays a different rate at each one.
  - Hands out jobs by letter, buys stolen goods through a drop crate and pays later, and tracks a reputation that lowers his cut.
  - Says a "sin of the day", drops rumours of his next stop when players sell drugs, and writes to past sellers when he moves.
  - Runs "The Fence" tool stall in pup_mercantile.
- **Discord logs** for robbery starts, boxes looted, robbery ends, heist results, fence sales and payouts.

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory`
- `pup-ui` (posse, menus, toasts)
- `pup-minigames`
- Optional:
  - `pup-mdt`: lawman counts and police board alerts. Without it the lawman count is always 0, so places that need lawmen cannot be robbed.
  - `pup-perks`: perks and XP.
  - `pup-gangs`: gang points, blood money, crew seed orders at the fence.
  - `pup-misc`: the bandana check.
  - `pup_postoffice`: job and payout letters, and move notices.
  - `pup_mercantile`: the fence's stall. A store named "The Fence" must exist there.
  - `pup_hideouts`: drug sales trigger the fence rumours.
  - `lockpick`: the lockpick minigame. Without it, walk-up lockpick boxes use the wire cut.
  - `doorlocks`: a lockpick used away from a heist is passed on to doorlocks.
  - `fred_hud`: the heist timer and alarm gauges.

## Installation

1. Run `sql/install.sql`. It creates the four tables (`robbery_cooldowns`, `robbery_history`, `robbery_fence_rep`, `robbery_fence_payouts`) and adds the items. The resource also creates the tables at start-up if they are missing, but not the items. The script is safe to run more than once.
2. Add `ensure pup_robbery` to `server.cfg` after `oxmysql`, `vorp_core`, `vorp_inventory`, `pup-ui` and `pup-minigames`, and after any optional resources you use.
3. Fully restart the server so vorp_inventory loads the new items.
4. Item images: the items are lockpick, banktools, crowbar, dynamite, ironhammer, hideout_plans, the money bags, gems, coins and jewellery the fence buys, and `sealedpackage`. Add `sealedpackage.png` to vorp_inventory's item image folder. Until then it shows vorp_inventory's missing-image look.
5. Discord logging (optional): set `Secrets.webhook` in `server/config.lua`. An empty webhook turns logging off. The file is a server script only, so it is never sent to players.

## Commands

| Command | Who | What |
|---|---|---|
| `/gotalert` | Lawmen | Clears your robbery alert and its blips. The name is set by `Config.AlertClearCommand`. |
| `/markjob` | Posse members | Marks your posse's current job on the map with a GPS route |
| `/fenceface` | Admin | Turns the fence to face the way you face. Save the heading it prints into the stop data. |
| `/resetrobbery [place]` | Admin | Clears the cooldown of one walk-up place, or of all of them |
| `/fencemove` | Admin | Moves the fence to his next stop now |
| `/fencejob [key]` | Admin, in game | With no key, lists the banks and their state. With a key (a place id or `heist:<bank>`), hands that job to your posse. |
| `/heists` | Admin, test mode | Lists every bank, its cooldown and whether it is running |
| `/heiststart <bank>` | Admin, test mode | Clears the bank's cooldown and hands its job to your posse |
| `/heistreset [bank]` | Admin, test mode | Clears one bank's cooldown, or every bank cooldown plus every rider clock |
| `/heistcancel <bank>` | Admin, test mode | Ends a live run as abandoned |
| `/heistalarm <1-4> [bank]` | Admin, test mode | Raises the alarm of a live run |
| `/vaultcode [bank]` | Admin, test mode | Shows the vault code of a live run and the clue note |
| `/heistpreview <bank>` | Admin, test mode | Labels every configured point of a bank and prints the plan to the console. Run it again to turn it off. |
| `/heistloot safe\|grab [quiet] \| list \| undo \| clear` | Test mode | Builds a draft list of loot spots at your position and prints it to the console. Nothing is saved. |
| `/heistmark [name]` | Test mode | Prints your position and heading to the console |
| `/doorhash` | Test mode | Prints the hash of the nearest door-system door |
| `/vaultdoor [open\|close]` | Test mode | Opens or closes the nearest door-system door |
| `/testminigame [game]` | Debug mode | Plays one minigame |
| `/testenemy [police]` | Admin, debug mode | Spawns one hostile guard in front of you |

Test mode is `Config.TestMode.enabled`. Debug mode is `Config.Debug`.

## Configuration

| File | What is in it |
|---|---|
| `config/main.lua` | Switches, permissions, keys, perks, personal clocks, categories, walk-up settings, guards, minigame tuning, Discord look |
| `config/places.lua` | The walk-up places, their boxes, loot and guards |
| `config/banks.lua` | Heist engine settings and the three banks |
| `config/fence.lua` | The fence's ped, stops, prices, jobs, stall stock, rumours, sins, reputation and letters |
| `locale/en.lua` | Every line players see. `%s` and `%d` are filled in by the code, in the order shown. |

### config/main.lua

- `Config.Debug`: console diagnostics, and enables `/testminigame` and `/testenemy`.
- `Config.TestMode`: heist test tools. Keep every switch off on a live server.
  - `enabled` unlocks the test commands listed above.
  - `ignoreLaw` waives every lawman count.
  - `soloCrew` makes an admin count as a full crew at the fence, and skips the introduction gate.
- `Config.AdminGroups`: VORP user groups that count as admin.
- `Config.BlockedJobs`: jobs that may not rob, ask the fence for work or break into a bank.
- `Config.InteractKey` / `InteractKeyLabel`: the key used by every prompt in this resource, the fence included (G by default).
- `Config.PosseCommand`: the posse command named in messages. pup-ui's own command name is used when pup-ui provides one.
- `Config.AlertClearCommand`: the name of the command that clears a lawman's robbery alert. `AlertClearRemovesBlips = true` also removes the lawman's alert blips.
- `Config.MdtAlerts`: send pup-mdt police board alerts.
- `Config.MaskRequired`: the player's bandana (pup-misc) must be up before anything happens at a place.
- `Config.Perks`: the pup-perks keys this resource reads:
  - `double`: double loot.
  - `cash`: a box cash multiplier.
  - `cooldown`: Cool Head, which shortens personal clocks.
  - `solo`: rob without a full posse.
  - `access`: the fence's introduction gate.
  - `fenceCut`: a better fence rate.
  - `fenceWord`: a better rumour chance.
  - `fenceNext`: the sale tip names the exact next stop.
  - `streetword`: rank-based landmark rumours.
  - `xpRobbery` / `xpFence`: the XP award kinds.
- `Config.CooldownPerkClamp`: the Cool Head multiplier is clamped to this range before it shortens a personal clock.
- `Config.PersonalClocks` (minutes):
  - `walkup` is set for the whole posse when a walk-up job starts, and for late joiners.
  - `bank` is set for every crew character at a break-in.
- `Config.Categories`: defaults per place category (`bank`, `store`, `fort`, `other`): `lawmen` needed, `riders` needed, and `jobLimit` (minutes a fence job stays open; nil = none). A place can override any of them.
- `Config.Walkup`:
  - `defaultRiders`: used when neither the place nor its category sets riders.
  - `timerLowSeconds`: the unlock countdown turns red below this.
  - `lockZeroLawPlacesAtStart`: places that need 0 lawmen start on cooldown.
  - `xpShareRange` (metres): posse riders this close to the looter also get XP. 0 = any distance.
  - `joinDistance`: a global crew-join radius. nil = each place's stray distance, capped at `joinDistanceCap` (metres).
  - `crewSweepMs`: how often late joiners are picked up.
  - `boxPromptRange` (metres): how close you must be to a box to see its prompt.
  - `claimWaitMs`: how long the client waits for the server to confirm a box claim.
  - `startSlack` (metres): the server allows the start radius plus this.
  - `boxReach` (metres): the server's reach from a box for a reward.
  - `unlockSlack` (seconds): slack on the unlock clock.
  - `bandanaPollMs`: how often the bandana state is polled.
  - `guardBlips`: blips on guards.
  - `gangPointsDefault`: `{ min, max }` gang points per box when the place sets none.
  - `placeBlip` / `boxBlip`: blip sprite and scale.
  - `persistPlaceCooldowns`: true stores place cooldowns so they survive a restart.
  - `lawModelsUsePoliceProfile`: true makes guards with a model in `Config.LawModels` use the police profile.
  - `resetLastRiderClock`: true sets the last rider's personal clock again when the job ends.
  - `warnFarData`: a console warning at start-up for any box set further out than its place's stray distance (such a box cannot be opened).
- `Config.GuardProfiles`: health, accuracy and whether guards take cover, for `outlaw` and `police` guards.
- `Config.GuardAmmo`, `GuardModelTimeoutMs`, `GuardBlipStyle`: guard ammo, model load timeout and blip style.
- `Config.GuardConfigFlags`: extra ped config flags set on every guard, as `{ flag, value }` pairs. Empty by default.
- `Config.LawModels`: lawman models, used only when `lawModelsUsePoliceProfile` is on.
- `Config.LawBlip`: the alert blip shown to on-duty lawmen while a job runs.
- `Config.LabelSprite`: the dark box drawn behind 3D labels.
- `Config.UsableTools`: the items registered as usable heist tools.
- `Config.Minigames`: pup-minigames tuning for walk-up boxes (`walkup`) and heist steps (`heist`).
  - `tester.safeDifficulty` is used by `/testminigame safe`.
  - `wirePauseMs` is the pause before a heist wire cut opens.
  - `timeoutMs`: a game that never answers counts as a failure after this long.
- `Config.Discord`: the log's `username` and `avatar`. The avatar is an image URL you have the right to use, or empty for none. The webhook itself lives in `server/config.lua`.

### config/places.lua

`Config.Places` is keyed by place id. The id is shown in messages and logs, and pup-ui posse tasks use it. Any field left out comes from `Config.Categories[category]`.

| Field | Meaning |
|---|---|
| `category` | `bank`, `store`, `fort` or `other` |
| `anchor` | The centre of the place |
| `startRadius` | How close (metres) a rider must be to start. Default 5.0. |
| `start` | `'shoot'` (fire a gun, the default) or `'press'` (press the interact key) |
| `stray` | Metres from the anchor before the job ends for you |
| `cooldown` | Minutes the place is locked after a job |
| `lawmen`, `riders` | On-duty lawmen and posse riders needed |
| `jobLimit` | Minutes a fence-handed job stays open (fence jobs only) |
| `unlockDelay` | Minutes before the boxes open (places without waves) |
| `waves` | `{ count, size, gap }`: number of waves, guards per wave, seconds between waves. The boxes open when the last wave is down. |
| `posts` | Guard posts the waves use: `{ pos, model, weapon }`. Duplicate positions are merged, and posts are reused when there are fewer than `size`. |
| `guards` | Guards spawned once at the start: `{ pos, model, weapon, type }`, where `type` is `outlaw` or `police` |
| `regions` | Lawman regions, e.g. `{ 'EAST' }` |
| `joinDistance` | Crew-join radius for this place |
| `gangPoints` | `{ min, max }` gang points per box |
| `placeBlip`, `boxBlips` | true shows a blip on the place, or on each locked box. Off by default. |
| `boxes` | The loot boxes, see below |

A box is `{ pos, game, dials, tool, cash, gold, loot }`:

- `game`: `normal`, `safe`, `lockpick`, `skill_circle`, `button_mash`, `pincode`, `chip_hack`, `key_drop`, `anagram` or `hangman`.
- `dials`: safes only. It sets the difficulty.
- `tool`: the item needed. Default `lockpick`, and one is lost on a failed game.
- `cash` / `gold`: a fixed payout. Default 0.
- `loot`: a list of `{ item, count, chance }`, where `chance` is out of 100 and rolled per line. A `label` may be given for items that may be missing from the items table.

Example: a box that needs a lockpick and may give a gold bar.

```lua
{ pos = vector3(0.0, 0.0, 0.0), game = 'normal', loot = { { item = 'goldbar', count = 1, chance = 10 } } },
```

Some of the shipped coordinates look wrong, and each one is marked with a comment in the file:

- One Armadillo Fort box is about 960 m from the fort, so it cannot be opened.
- One Fort Mercer wave post has a y value that is probably a typo (unused at a wave size of 10).
- Fort Wallace's two boxes share one spot.
- One oil rig box is about 97 m under the rig.
- The Saint Denis store's guards stand up to about 300 m away.

### config/banks.lua

`Config.Heist` holds the engine settings:

- `tokenLifetime` (seconds): how long a minigame attempt stays valid. An attempt not reported in time counts as a failure.
- `interactRange` (metres): also the server's reach for steps before the break-in.
- `promptDrawRange` and `lootDrawRange` (metres).
- `stagePrompts`: draw a 3D label at the current stage. A bank may override it.
- `lootPrompts`: draw loot prompts.
- `timeWarnings` (minutes left): when the crew is warned.
- `doorGrace` (seconds): how long the doors stay open after a run with a break-in ends. `doorFinalWarn` is the last warning before they seal.
- `getawayRange` (metres): the default distance from the bank that counts as a getaway. `getawayReportMs` sets how often it is reported.
- `escapeZoneSlack` (metres): added to an escape zone's radius on the server.
- `pinGuesses` and `pinDifficulty`: the vault code has 3 + difficulty digits.
- `defaultFuse` (seconds).
- `cooldownScale`: multiplies the bank's cooldown by outcome (`full`, `partial`, `failed`, `abandoned`, `crew_wipe`). A run abandoned before the break-in sets no cooldown.
- `alarmMax` and `alarmNames`: the alarm levels, from 0 (quiet) to 4 (vault alarm).
- `police`: the pup-mdt board alert.
  - `fixedText` is used for every level. An empty string uses the per-level `levelTexts` instead.
  - `fromLevel` is the first level that sends an alert.
  - `once` sends a single alert per run.
  - `persistent` keeps the alert on the board.
  - `vague` texts name only the region.
- `publicAlarm`: from this level, on-duty lawmen also get the chat tip and map blip.
- `effects`:
  - `propRange`, `fuseBarRange` and `blastRange` (metres): how far the charge prop, the fuse bar and the blast are seen.
  - `smokeSeconds`: how long the smoke lasts.
  - `explosionType` and `cameraShake`: the blast itself.
- `losCacheMs` and `losTolerance`: the line-of-sight check for clue and loot prompts.
- `propRefreshMs`, `lootPropRefreshMs`, `walkInDebounceMs`, `chargeAnimMs` and `animLoadMs`: client timings in ms.
- `honourEntryNeedsPrep`: true lets an entry marked `needsPrep = false` be used before the prep is done.
- `clearTaskOnWipe`: clear the posse's heist task even when the crew is empty at the end.
- `reviveRejoins`: a downed rider who is revived during the run rejoins the crew.
- `gangPoints`: `{ min, max }` per loot spot.
- `defaultAnim`, `inspectAnim` and `grabAnim`: the animations used.
- `guardLingerMs` and `guardClearRange`: the leader's client removes the heist guards it spawned this long after the run ends, or sooner once it is this many metres from the bank.
- `lockpickFallback`: doorlocks also registers `lockpick` as a usable item, and vorp_inventory keeps only one handler per item. A lockpick used with no heist target is passed on to doorlocks through this event.

`Config.BankOrder` lists the banks in display order. `Config.Banks` is keyed by bank id. The ids are stored in the database, so do not rename them. Each bank has:

- **Basics:**
  - `label`, `category`, `lawmen`, `riders`.
  - `jobLimit`: minutes from the claim to the break-in.
  - `cooldown`: minutes.
  - `insideMinutes`: the time limit after the break-in.
- **Location and dispatch:**
  - `anchor`, `region`.
  - `dispatchLabel` and `dispatchLocation`: used in alerts.
- **Guards and getaway:**
  - `guardsAtAlarm`: guards spawn when the alarm reaches this level, or at the break-in if it is already that high.
  - `getawayRange`: metres.
  - `escapeZones`: optional `{ pos, radius, label }` points. When set, the crew must reach one of them instead of riding out of range.
- `stageCount`: how many stages the vault plan uses. Stages marked `always` are always in, and the rest are drawn at random.
- `vaultDoor`: a door hash.
- `securityBox`: a point that prep boxes and stages can reuse.
- Optional overrides: `stagePrompts`, `promptRange`, `insideRange` (reach after the break-in) and `interactRange`.
- `prep`: an optional step before the break-in, `{ label, game, tool, failStep, doneText, boxes }`. Each box is `{ pos, prop }` or `{ useSecurityBox = true }`. Doing the prep makes the run "quiet".
- `entries`: the ways in, keyed by name, `{ pos, label, alarm, game, tool, failStep, doors, needsPrep, walkIn, noPrepAlarm }`.
  - With no `game`, the entry is a plain prompt (or a walk-in when `walkIn = true`).
  - `alarm` is the level the alarm is set to at the break-in.
  - `entryOrder` sets the order they are listed in.
- `stages`: the vault steps, `{ id, label, pos, game, tool, failStep, always, last, opensVault, doors, anim, alt }`.
  - `last` stages run at the end of the plan.
  - `opensVault` opens the vault door when the stage is done.
  - `alt` is an alternative way through the same stage, e.g. blowing the door instead of working out the code.
- A dynamite stage, or a dynamite `alt`, may carry:
  - `placement`: a minigame to place the charge.
  - `fuse`: seconds.
  - `alarmTo`: the alarm level it sets.
- `clue`: optional, `{ label, pos, game, tool, failStep, doneText, reveal, bonusGuesses, reward }`.
  - It shows `reveal` digits of the vault code and adds `bonusGuesses` to the pincode.
  - `reward` is an optional `{ item, min, max, label }`.
- `extraDoors` (optional): `{ pos, label, game, tool, doors, doneText, failStep }`. `lockedDoors` (optional): door hashes that are kept locked.
- `loot`: the loot spots.
  - A plain spot is a grab.
  - A spot with `safe = true` is a minigame (`label`, `game`, `tool`, `failStep`).
  - `prop` places a model there (`model`, `offset`, `rot`, `heading`, `ground`).
- `lootTable`: what each spot rolls, `{ item, min, max, chance, label }`, with `chance` out of 100 per line.
- `guards`: `{ pos, model, weapon }`.

`failStep` is how much the alarm rises when that minigame fails.

Game types are `wire_cut`, `lockpick`, `skill_circle`, `skill_bar`, `safe_crack`, `button_mash`, `pincode` and `dynamite`.

Route limits can be put on stages, alternatives, extra doors and loot spots:

| Field | Meaning |
|---|---|
| `onlyVia = { 'front' }` | Only when the crew came in through one of these entries |
| `neverVia = { 'back' }` | Never when they came in through one of these |
| `quietOnly = true` | Only when the prep was done before the break-in |
| `loudOnly = true` | Only when it was not |

### config/fence.lua

- `npc`:
  - `model` and `fallbackModel`.
  - The prompt: `promptGroup`, `promptText`, `promptRange` (metres) and `pressThrottleMs`.
  - `sinkMetres`: the ped is placed this far under the stop's height so his feet meet the ground.
- `stayMinutes`: how long he stays at a stop.
- `reach` (metres): the server's reach from the fence, or his prompt point, for every fence action.
- `askThrottleMs`, `whereRetries`, `whereRetryMs`: request timings.
- `stops`: `{ label, region, pos, heading, prompt }`. `prompt` is an optional separate prompt point. He visits the stops in a shuffled order and never starts a new round on the stop he just left.
- `payRate`: the share of the goods' value he pays, either a fixed number or `{ min, max }`, rolled at each stop.
- `jobs`:
  - `categories`: the place categories he hands out.
  - `posseRequired`.
  - `needsPerk`: the introduction gate, using perk `Config.Perks.access`. Off by default.
  - `letterSubject`.
  - `blipMinutes`: how long the `/markjob` blip lasts.
- `buyer`:
  - `payoutMinutes`: how long until the money is ready.
  - `crateSlots` and `crateName`.
  - `cratePrefix`: keep it, because existing crates are stored under this id.
  - `sweepSeconds`: how often payout letters are sent.
  - `tipDelayMs`.
  - `prices`: what he pays per item. Items not in this list are handed back.
- `stall`: `storeName` (the pup_mercantile store), `pushDelayMs` and the `stock` pushed to that store.
- `rumours`:
  - When a player sells drugs (pup_hideouts), there is a `chance` out of 100 of a rumour about his next stop. The chance is limited by `cooldownMinutes`.
  - Riders with `streetword` rank `landmarkRank` or higher hear the exact stop rather than the region.
  - `moveNotice` and `moveMail` tell past sellers where he went.
  - The lines use `{region}`, `{label}` and `{where}` placeholders.
- `sins`: the sin of the day shown in his menu. One line per day, in order.
- `brushOffs`: what he says to strangers when the introduction gate is on.
- `reputation`:
  - Each sale adds `perDollar` rep per dollar of value, and at least `minPerSale`.
  - `levels` are `{ from, name, keeps }`. `keeps` is the share of his normal cut he still takes, so 1.00 is his full cut and 0.00 means he takes nothing.
- `letters`: the sender name and the payout letter subject.

## For developers

Exports (server):

| Export | Returns |
|---|---|
| `exports.pup_robbery:FenceKnowsYou(src)` | true when the fence deals with this player (pup_mercantile uses it to gate the stall) |
| `exports.pup_robbery:FenceSpot()` | `{ coords = { x, y, z, h }, promptcoords = { x, y, z }, label, region }`, or nil |

Events and exports it uses from other resources:

- Listens for `pup-misc:bandanaState` (client) and `pup-ui:posse:serverChanged` (server).
- Listens for `pup_hideouts:drugsale_log` (server), which triggers the rumours.
- Triggers the client event `fred_hud:heist` with `{ active, timer, alarm, alarmMax }` for the HUD gauges.
- Calls the pup-ui posse exports: `GetPosse`, `GetPosseMembers`, `GetPosseTask`, `SetPosseTask`, `ClearPosseTask`, `PosseHasTask`, `IsPosseLeader` and `GetPosseLocalConfig`.
- pup-mdt: `GetPlayersOnDuty` and `SendPoliceAlert`.
- pup-perks: `Has`, `Roll`, `Mult`, `Bonus`, `GetRank` and `Award`.
- pup-gangs: `AwardBloodMoney`, `AwardPoints` and the `pup-gangs:getSeedOrder` callback.
- pup_mercantile: `SetStoreStock`, `SetStorePos` and `StoreIdByName`.
- pup_postoffice: `SendSystemMail`. Letters are also written straight into its `mail` and `mails` tables.
- vorp_core: the timer exports `TimerStart`, `TimerUpdate` and `TimerStop`.

All calls into optional resources are guarded, and each failure logs one console warning.

## License

See LICENSE.
