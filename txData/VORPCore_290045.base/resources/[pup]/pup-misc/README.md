# pup-misc

Many small everyday systems for a RedM / VORP server in one resource. Each module has its own folder under `client/`, `server/`, `config/` (and `shared/` or `sql/` where needed), and can be tuned on its own.

## Features

- **bandana**: pull the neckwear you are wearing up over the face, or back down.
- **bathing**: the bathhouse minigame, with an optional deluxe service.
- **bountyhunting**: kill, capture and escort contracts from the town boards, solo or in a party.
- **cannon**: senior law can place mounted weapons (cannons, gatling guns) and turn them.
- **coordtool**: developer coordinate helpers (readout, clipboard copy, server list).
- **ecoboost**: a per-character sale bonus on mining, trapper and fishing sales, with a cap and a cooldown.
- **emotes**: chat commands for emotes, animations, scenarios, walk styles and photo poses.
- **erp**: paired animations, by invitation only and limited to allowed zones.
- **gestures**: hands up and point on a key.
- **grandmas**: NPC doctors that revive a dead player for a fee.
- **guarma**: a boat crossing to Guarma and back.
- **hogtie**: a non-law player loses the lasso they hogtied someone with; no breaking free while somebody is close.
- **instance**: routing buckets, instanced zones and character-creator isolation.
- **interactions**: sit, lie down, play piano, bathe and dance on real world objects.
- **knockout**: losing a melee fight (or a horse kick) knocks you out instead of killing you.
- **outfitter**: camps and trail gear bought at the stable, carried in the wagon, pitched in the wild.
- **pets**: animals summoned by a whistle item, with sit, track, hunt, howl and naming.
- **police**: law menu, cuffs, escort, wagon loading and rank badges with an in-world editor.
- **pomade**: an item that slicks the hair back.
- **props**: wearable props from items (canes, pipes, instruments ...) and the `/pa` position editor.
- **ragdoll**: flop on a key, get up again.
- **river**: drink and wash at water, water bottles, dirty-water poisoning and its antidote.
- **scenario**: a scenario menu and gun-spin tricks.
- **scene**: floating world text and the `/me`, `/ooc`, `/id`, `/cash` and `/status` labels.
- **search**: search and rob a restrained player, with limits, duty checks and a new-character shield.
- **smokes**: pipes, cigars, cigarettes and chew, edited from the vorp_admin panel.
- **storagebox**: portable storage boxes and job packs.
- **tattoos**: the tattoo and makeup mirror, and body adjustments.
- **traffic**: ambient ped, animal and vehicle density.

## Requirements

- `vorp_core`, `vorp_inventory`, `oxmysql`, `PolyZone`, `pup-ui`
- `pup-stable` for the outfitter (and the stable-wagon checks in interactions)
- Optional, used when present: `pup-mdt` (police duty and ranks, cannon access, search duty checks), `pup_business` (job changes, duty), `pup-medical`, `pup-events` (purge, scripted fights), `pup-perks` (bounty award), `pup_staffdesk` (pet naming), `pup_hideouts`, `pup_camps`, `pup_mercantile`, `pup-pinboard` (Eco Boost button), `vorp_admin` (smokes panel, staff overrides), `vorp_character`, `vorp_walkanim`, `fred_metabolism` (river, grandmas), `fred_hud` (Eco Boost gauge, weakness countdown), `redem_roleplay` (optional bounty notifier)

## Installation

1. Put the folder in `resources` and `ensure pup-misc` after `oxmysql`, `vorp_core`, `vorp_inventory`, `PolyZone` and `pup-ui` (and after `pup-stable` if you use the outfitter).
2. Import the `sql/<module>/install.sql` files for the modules you use. Most tables are also created on start; the SQL files add the inventory items, so import them before the first start so vorp_inventory loads the items.
   - `ecoboost`: table `ecoboost`
   - `outfitter`: table `outfitter`
   - `pets`: table `pet_coats` and one whistle item per pet (`usable` must be 1; item_group row 1 and item_rarity row 5 must exist)
   - `police`: table `police_badge_offsets`
   - `props`: table `prop_offsets` and every wearable prop item plus `pomade` (item_group row 1 and item_rarity rows 1 and 5 must exist)
   - `river`: the dirty and clean water bottles, the empty bottle (`water_bottle_empty`, skip it if `Items.emptyBottle = false`) and the antidote
   - `scene`: table `playerscenes`
   - `search`: the `character_created` column on `characters` (see the optional line in the file for a first install)
   - `smokes`: table `smokes` with the stock smokes, and every smoke item plus `pipe`
   - `storagebox`: the box table and the box / pack items
   - `tattoos`: the `overlay` and `expressions` columns on `characters` (MariaDB syntax)
3. Add inventory images for the new items.
4. For Discord logs, fill in the webhooks in `server/config.lua` (empty = that log is off). Keys: `Webhooks.storagebox.main`, `.societyAdmin`, `.housingAdmin`, `.clanAdmin`, `.hideoutAdmin`, `.customAdmin`; `Webhooks.search.admin`; `Webhooks.scene.log`. The file is a server script only and never reaches players.
5. Set the super-bypass identifier for searches in `config/search/server.lua`.

Some modules share globals, so the order of the lines in `fxmanifest.lua` matters; its comments say which ones must stay in order.

## Commands

Most command names are set in the module's `config/<module>/main.lua`.

| Module | Command | Who | What |
|---|---|---|---|
| bandana | `/bandana` | players | Mask up / down |
| bathing | `/exitbath` | players | Leave the bath |
| cannon | `/gat <n>` | law, grade 5+, on duty | Place a mounted weapon |
| cannon | `/gatremove` | the placer | Take your nearest (or oldest) piece away |
| coordtool | `/coords` | players | Show / hide your coordinates |
| coordtool | `/cc`, `/cc 1`, `/cc x y z` | players | Copy coordinates to the clipboard |
| coordtool | `/xcc` | staff | Record your position in the server list |
| coordtool | `/coordslist`, `/coordsclear` | staff, console | Print / clear the server list |
| emotes | one per entry in `config/emotes/emotes.lua` | players | Play that emote, scenario, animation or walk style |
| emotes | `/sa` | players | Stop any emote, animation or scenario |
| emotes | `/emotelist` | players | Print every emote command to F8 |
| emotes | `/photopose <id>`, `/photoposes` | players | Strike a photo pose / list the poses |
| erp | `/erp` | players | Pick a paired pose and invite the nearest player |
| gestures | `/handsupkey` (X), `/point` (L) | players | Toggle hands up / pointing |
| grandmas | `/rev` | dead players at a doctor | Pay for a revive |
| pets | `/petsit`, `/pettrack`, `/pethunt`, `/pethowl` | pet owners | Orders for your pets |
| pets | `/petattack` | pet owners | Only when `Attack.enabled` is on |
| pets | `/petvariant`, `/petscan` | players, debug only | Coat finders |
| police | `/lawmenu`, `/mmenu` | law on duty | The law menu |
| police | `/badge`, `/adjustbadge` | law on duty | Pin the badge on / off, move it |
| police | Alt + R / Alt + G | law on duty | Cuff / escort the nearest player |
| props | `/pa` | players | Move a worn prop and save the position |
| ragdoll | `/ragdoll` (Z) | players | Flop / get up |
| scenario | `/scenario` | players | The scenario menu |
| scene | `/scene`, `/scenes` | allowed jobs, staff | Place a scene / aim-to-remove mode |
| scene | `/me`, `/ooc`, `/id`, `/cash`, `/status`, `/cstatus` | players | Labels over your head |

## Configuration

Every module has a `config/<module>/main.lua` (settings) and usually a `locale.lua` (player text) and data files. Keys are control hashes unless noted: change the hash only. Below, every setting group is explained per module.

### bandana

`/bandana` pulls the neckwear the character is wearing up over the face, or back down.

**config/bandana/main.lua**
- `General.debug`: F8 prints. `General.command`: the chat command.
- `Keys`: none (it is a chat command).
- `Integrations`: nothing to switch. pup_robbery listens for the `pup-misc:bandanaState` event and the `IsBandanaUp` export; vorp_character puts the garment dye back afterwards.
- `Animation`: `enabled` plays the KIT_BANDANA hand animation (false = swap instantly); `waitMs` lets the hand reach the face before the garment swaps (ms).
- `Garment`: `stateUp` / `stateDown` are the neckwear wearable states (pulled up over the face / hanging at the neck; hash or name); `categories` are the categories searched, in order; `storedKeys` are the character-record slots the garment hash is read from, in order.

**config/bandana/locale.lua**: player-facing text.

### bathing

The bathhouse minigame: pay at the bathhouse, soak, scrub, and optionally order the deluxe
service. The config is read on both sides; the server takes the prices and keeps one bather
per bathhouse.

**config/bathing/main.lua**
- `Prices`: `regular` (a bath) and `deluxe` (the deluxe service, on top of the bath), in dollars, cash.
- `Prompts`: `start`, `scrub`, `deluxe`, `exit`, each with an optional `control` (hash or input name;
  default `PromptDefaults.control`, E), `hold` in ms (default 1000) and `price` (a `Prices` key shown in
  the label). The scrub prompt's control is also the key held down to scrub.
- `BodyParts`: the scrub order. `state` (move-network state), `speed` (scrub speed), `deluxe` (true:
  the attendant scrubs it; parts without it are skipped while the attendant is there, so she does the
  arms and legs), `step` (progress per 100 ms, default `DefaultStep`), `zone` (the damage-decal zone
  cleaned when the part is finished). The player is fully cleaned when the last part is finished.
- `Distances`: `prompt` (start prompt), `serverStart` (the server's distance check), `clientLeave` and
  `serverLeave` (moving this far from the bathhouse ends the bath / frees it).
- `ExitKey`: the key at the exit spots (G).
- `Commands`: `exit` (`exitbath`), `dress` (vorp_character's reload command), `stopAnim`.
- `Attendants`: the attendant model for a male / a female character.
- `Assets`, `Timings`: game asset names and waits; leave them unless you know the game files.

**config/bathing/houses.lua**: one entry per bathhouse, keyed by town (the key is the occupancy key):
- `dict`: the town's bathing intro/outro anim-scene dictionary
- `rag`, `ragHeading`: where the wash rag is anchored
- `consumer`: where you stand for the "Take a bath" prompt (vector3); also the blip
- `door`: the bath-room door hash (locked here unless another script registered it first)
- `landing`: where `/exitbath` and the exit spot put you
- `exitSpot` (optional): `at` and `radius` of a "Press G To Exit" spot, active only while you sit in that tub

The game also has bathhouses in Annesburg, Van Horn, Rhodes and Tumbleweed (dictionaries
`script@mini_game@bathing@BATHING_INTRO_OUTRO_<TOWN>`); add them in the same shape to use them.

**config/bathing/locale.lua**: prompt labels by prompt id (`%s` = the price), the blip name, the
exit-spot hint and the messages (`%.2f` = the price).

A bathhouse is freed when the bath ends, on `/exitbath`, when the bather dies, leaves, changes
character or disconnects. There are no refunds.

### bountyhunting

Kill, capture and escort contracts taken from the town boards, solo or as a party of up to four. Loaded on both sides: the server decides who may start a contract, which contract is rolled and what it pays; the client only spawns the peds and shows the markers. Cooldowns and open contracts are held in server memory and are gone after a restart.

**config/bountyhunting/main.lua** (creates `BountyConfig`; `peds.lua`, `kill.lua`, `arrest.lua` and `escort.lua` load after it and fill `PedPools`, `Kill`, `Arrest` and `Escort`)
- `Debug`: contract tracing in the client F8 and server consoles.
- `Notifier`: `'vorp'` (vorp bottom tip, `vorp:TipBottom`) or `'redem'` (redem_roleplay objective, `redem_roleplay:ShowObjective`). The payment tip always uses `vorp:TipRight` from the server.
- `Keys`: `Interact` (G) read the board / hand a bounty over, `End` (F) call the contract off at the drop point.
- `Jobs`: `Lock` (false = anyone may use the boards), `Law` and `Hunter` job lists.
- `Boards`: `{ town, coords }`; the town keys must match the keys used in the contract files. `BoardPromptDistance` metres from a board to see the prompt; `BoardServerSlack` extra metres the server allows when it re-checks.
- `Blips`: `BoardsForEveryone` (civilians see the boards even with the job lock on), `Scale`, marker styles (`CoordStyle` for map points, `EntityStyle` for markers on peds), sprites (board, kill/capture start, escort client start, drop point, marked peds) and colours.
- `Cooldown`: `Minutes` per character (0 = none), `StartsAt` `'approval'` (when the board hands out the contract) or `'end'`, `Partners` (partners get the same cooldown as the leader).
- `Party`: `MaxHunters`, `PartnersNeedJob` (every named partner must hold a law / hunter job too).
- `Contracts`: `HostileMarkers` (outlaws get map markers; wanted men and the escort client always do), `ArriveDistance` metres from the start at which the contract spawns, `HandoverDistance` drop-point radius for the Hand Over / Call It Off prompts, `EscortArriveDistance` client distance to the destination that completes an escort, `EscortFollowRefresh` seconds between follow orders, `EscortRandomTarget` (attackers pick the leader or the client 50/50; false = always the client), `FirstWaveSeconds` (nil = the first wave waits the block's full interval), `ShareAttackerMarkers` (partners see escort attackers too), `DeadTargetFails` (a dead wanted man fails the contract instead of just closing it), `DeathFailsAfterClear` (the leader dying fails a kill / capture even after every guard is down), `EndPauseSeconds` (end message shown before the peds are removed), `HandoverPause` seconds between two hand-over presses, `ModelLoadTimeout` ms per model, `SpawnAttempts` models tried per ped before it is skipped.
- `Payout`: `Multiplier`, `MaxCash` / `MaxGold` per payment after the multiplier (`MaxGold = 0` = gold never paid), `Radius` metres (leader to the drop point, and partners to the leader, to be paid), `SplitAmongPresent` (false = every present hunter gets the full share; true = the share is divided), `PerkKey` the pup-perks Award key (once per paid hunter per hand-over).
- `PartnerMarkerRetryMs` / `PartnerMarkerRetries`: how often and how long a partner looks for a marked ped that has not streamed in yet.
- `WeaponFixes`: weapon names the game does not know, mapped to the intended one (empty by default).
- `Tiers`: what a contract's `tier` means. Each tier lists, per party size (`[1]` solo ... `[4]` four hunters): `hostiles` (outlaws at a kill camp; at a capture camp the wanted men are taken out of this count and the rest are guards), `targets` (wanted men), `attackers` (escort ambushers per wave) and `purse` (total cash before `Payout.Multiplier`, split per body / wanted man). It also sets `arms` (a key in `Arms`), `styles` (combat movement handed out in turn: 0 stationary, 1 defensive, 2 offensive, 3 rushes you), `wave` (seconds between escort waves) and `health` (escort client).
- `KindPay`: purse factor per kind (`kill`, `arrest`, `escort`).
- `Spread`: metres from the contract point for kill camps (`kill`), capture guards (`guards`) and the wanted men themselves (`wanted`).
- `Arms`: weapon lists; each ped takes the next weapon in its tier's list, and wanted men always take one from `sidearm`.

**config/bountyhunting/peds.lua**: named lists of ped models. A contract names a list as its `gang` (outlaws, wanted men, ambushers) or its `client`, and every spawned ped gets a random model from it. A model listed twice is picked twice as often. Editing a list changes every contract that uses it.

**config/bountyhunting/kill.lua, arrest.lua, escort.lua**: the contracts, one line each, listed under the board town that posts them. One is picked at random when a hunter takes work at that board. `BountyConfig.build` (bottom of `main.lua`) turns each line into the per-party-size blocks the code reads. The outlaws' spots are laid out on a spiral around `at` and worked out from the contract's name, so the client and server always build the same contract. The client sets each spot on the ground when it spawns.
- every kind: `name` and `notice` (shown when the contract starts; the name also labels the start marker), `at` (the camp, or where the escort client waits), `tier`, `gang`, and optional `extra` (peds added at every party size, negative removes them) and `pay` (purse factor)
- kill and capture: `drop` (where bodies / prisoners are handed in; defaults to that town's board), optional `spread`
- escort: `client` pool and `drop` (the destination, required; the client must get within `EscortArriveDistance` of it), optional `wave` / `health` to override the tier
- a line with an unknown tier, pool or a missing point is skipped with a console warning

```lua
-- kill contract
{ name = 'The Tallow Creek Gang', tier = 1, gang = 'roadagents',
  notice = 'Wanted dead for burning out two homesteads.',
  at = vector3(0.0, 0.0, 0.0) },

-- capture contract (drop given: hand him in somewhere other than the board)
{ name = 'Silas Thorne', tier = 2, gang = 'roadagents', extra = 1,
  notice = 'Wanted alive for stealing a payroll.',
  at = vector3(0.0, 0.0, 0.0), drop = vector3(0.0, 0.0, 0.0) },

-- escort contract (start -> destination)
{ name = 'Tobias Reed, Cattle Buyer', tier = 1, client = 'workfolk', gang = 'roadagents',
  notice = 'Carries a purse to the station.',
  at = vector3(0.0, 0.0, 0.0), drop = vector3(0.0, 0.0, 0.0) },
```

**config/bountyhunting/locale.lua**: player-facing text (both sides read it). `briefLine` is the start notice (kind, contract name, notice, objective).

### cannon

`/gat` places one of the game's mounted weapons for senior law; the placer can turn it and take it away. The config is read on both sides: the server gates on `Access`, the client reads the models and placement.

**config/cannon/main.lua**
- `General.command`: `/gat <key>` places a piece (no number = the first entry in `Models`). `General.removeCommand`: takes the nearest one of yours away (or your oldest).
- `Keys.rotateLeft` / `rotateRight`: turning keys, held while standing beside your own piece (left / right arrow).
- `Access` (checked on the server): `jobs` allowed to place a piece, `minGrade` the lowest job grade for a piece that does not set its own. The player must also be on duty in pup-mdt.
- `Models`: `key` is the number typed after `/gat`, `model` a vehicle-class model name (that is what makes it mannable), `label` the name shown in messages, `minGrade` the job grade for this piece (leave out to use `Access.minGrade`). Example: `{ key = 5, model = 'gatling_gun', label = 'Gatling', minGrade = 6 }`.
- `Placement`: `maxPerPlayer` pieces out at once, `spawnForward` metres in front of the placer, `rotateStepDegrees` degrees per frame while a turning key is held, `rotateDistance` metres within which the keys turn a piece, `despawnMinutes` minutes until a piece is removed (0 = never; still removed on resource stop or `/gatremove`).

### coordtool

Developer coordinate helpers: an on-screen readout, copy to clipboard, and a server-side list of recorded spots (kept in memory until restart).

**config/coordtool/main.lua**
- `General.commands`: `toggle` show/hide X Y Z H on screen, `copy` copy "x y z" to the clipboard (`/cc 1` = table form, `/cc x y z` = those values), `record` send your position to the server list, `list` print the server list in chat, `clear` empty the server list.
- `CoordtoolLocale`: chat lines from `/coordslist`.

### ecoboost

Eco Boost: a per-character sale bonus on mining, trapper and fishing sales, with a cap and a cooldown. The server does every calculation.

**config/ecoboost/main.lua**
- `General.enabled`: false = the pinboard button shows "disabled" and no sale is boosted. `General.notifyProgress`: a tip after every boosted sale (bonus and progress).
- `Keys`: none; the boost is switched on from the pup-pinboard button.
- `Integrations`: nothing to switch. pup-pinboard uses `GetEcoBoostStatus` / `ActivateEcoBoost`; pup_mercantile, pup_camps and legendaryhunt use `ApplyEcoBoostSale` / `EcoBoostMultiplierFor`. fred_hud draws the gauge from the `pup-misc:ecoboost` event.
- `Boost` (one activation): `multiplier` applied to the sale value while active (1.0 = no bonus), `bonusCap` total bonus dollars one activation can pay, `windowSeconds` how long an activation lasts (unfinished progress resets after it), `cooldownSeconds` wait after the cap is reached before the next activation, per character.
- `Sales`: `eligible` = activity -> `true` counts toward the boost; `storeCategories` = activity -> place-name fragments (case-insensitive, plain text) that identify a sale point as that activity, e.g. `Fishing = { 'Bait Shop' }`.

**config/ecoboost/locale.lua**: text shown as "<title>. <text>" in a VORP tip.

### emotes

Chat commands for emotes, animations, scenarios, walk styles and photo poses (client only).

**config/emotes/main.lua**
- `General`: `stopCommand` stops any emote, animation or scenario; `listCommand` prints every registered command to F8; `poseCommand` (`/photopose <id>`, called by the radial menu; not `/pose`, which pup-ui owns); `poseListCommand` prints every pose id to F8.
- `Integrations.walkanimCommands`: vorp_walkanim's own commands. They are not registered here; `/emotelist` lists them (while vorp_walkanim runs) so they are findable.

**config/emotes/emotes.lua**: every key becomes a chat command (`/wave`, `/dance1`, `/walkdrunk` ...) and is what pup-emote's wheel and the `PlayEmoteCommand` export use. Command names must be unique across all four lists.
- `WalkStyles`: command = walk style. Handed to vorp_walkanim when it runs, so the style syncs and persists; `'noanim'` resets to the default walk.
- `Emotes`: command = `KIT_EMOTE_*` name, played with TaskEmote. The category (reaction / action / taunt / greet / dance) is read from the name.
- `Scenarios`: command = scenario name, played with TaskStartScenarioInPlace.
- `Anims`: TaskPlayAnim. `dict` / `name` the clip, `fdict` / `fname` an optional female variant (the male pair is used when absent), `flag` optional TaskPlayAnim flags (default 1). Example: `clap = { dict = '...', name = '...', fdict = '...', fname = '...' },`

**config/emotes/poses.lua**: the photo poses for `/photopose <id>`: the game's own posed-portrait animations (photo studio sets, the Gunslinger photo scenes and the online end-of-round photo poses). The radial menu calls `/photopose <id>`, so keep the ids.
- `cat`: group name `/photoposes` prints them under; `label`: what `/photoposes` prints
- `dict` / `name`: the male clip; `fdict` / `fname`: the female one. Many studio sets ship a `@male` and a `@female` dictionary for the same pose; where only one exists the same clip is used for both.
- Example: `flex = { cat = 'studio', label = 'Flex', dict = STUDIO .. 'fun@male', name = 'idle_m02', fdict = STUDIO .. 'fun@female', fname = 'idle_f01' },`

**config/emotes/locale.lua**: player-facing text.

### erp

Paired adult animations, by invitation only. Nothing plays on anybody who has not pressed accept, and both players must stand somewhere the zone list allows. Read on both sides.

**config/erp/main.lua**
- `General.command`: opens the pose menu and invites the nearest player.
- `Keys`: `accept` (G) and `decline` (B) on the invitation prompt.
- `Integrations`: nothing to switch. pup-ui draws the menu; ped heights are flattened and restored for poses with `level`.
- `Invite`: `range` metres the two of you must be within (the server allows 0.5 more), `cooldownSeconds` between invites per player, `timeoutSeconds` before an invite lapses.
- `Zones` (where poses without `anywhere` may be used): `districts` map-area hashes, checked on each client; `spots` anywhere within `radius` metres (default 20) of a point, checked on the server too, e.g. `{ label = 'Valentine Hotel', x = 0.0, y = 0.0, z = 0.0, radius = 30.0 }`; `enforce = false` allows every pose anywhere and ignores both lists.

**config/erp/emotes.lua**: the paired poses, in menu order.
- `key`: unique id sent between the two clients (do not reuse); `label`: menu text; `ms`: how long the pose plays
- `level`: flatten both heights to 1.0 for the pose, then restore (a scaled ped will not line up, so leave it on for anything that touches)
- `anywhere`: ignores `ErpConfig.Zones` (hug and kiss are ordinary roleplay; slap uses the spanking animation, so it is held to the zone list)
- `player`: plays on whoever sent the invite (they never move); `target`: plays on whoever accepted, placed relative to the sender with `posX` right(+)/left(-), `posY` forward(+)/back(-), `posZ` up(+), `rotZ` turn in degrees
- `dict` / `anim` / `flag`: the TaskPlayAnim clip and flags

```lua
{ key = 'hug', label = 'Hug', ms = 20000, level = true, anywhere = true,
  player = { dict = '...', anim = '...', flag = 1 },
  target = { dict = '...', anim = '...', flag = 1, posX = 0.0, posY = 0.39, posZ = 0.0, rotZ = 180.0 } },
```

**config/erp/locale.lua**: player-facing text.

### gestures

Hands up and point on a key.

**config/gestures/main.lua**
- `General`: `handsUpCommand` and `pointCommand` toggle the gestures. They are also bound through RegisterKeyMapping, so they show up under Settings -> Key Bindings -> FiveM and still work typed in chat for anyone whose bind is cleared.
- `Keys`: the default keys for a player who has never had the bind (key names, not hashes). Players rebind them in their own settings; changing these does not move an existing bind.
- `Integrations`: nothing to switch. Uses the emotes module's `EmotesCanPlay` / `EmotesConsuming` and the storagebox `IsCarrying` export.
- `HandsUp.anim`: `dict` / `name` the clip, `flag` the TaskPlayAnim flags, `blend` blend-in speed. `holsterWeapon` forces unarmed when the hands go up; `blockFiring` keeps firing and melee blocked the whole time.
- `Point.anim`: as in `HandsUp`.

**config/gestures/locale.lua**: the row names in the Key Bindings list.

### grandmas

NPC doctors that revive a dead player for a fee: stand at one while dead and type `/rev`. Read on both sides: the server re-checks the distance to a doctor and takes its price.

**config/grandmas/main.lua**
- `General.command`: the chat command a dead player types at a doctor.
- `Integrations`: nothing to switch. pup-ui draws the progress bar; fred_metabolism gets +50 food / +50 water after a revive.
- `Treatment`: `durationMs` how long the treatment takes (ms), `leashDistance` metres the body may drift from the doctor before the treatment is cancelled, `cooldownMinutes` between two revives per player (keep the locale's cooldown text in step).

**config/grandmas/doctors.lua**: one entry per doctor, keyed by a unique id.
- `coords`: where the NPC stands (`x, y, z, h`; `h` = heading, may be left out)
- `blip = { sprite, show, name }`
- `price`: what a revive costs here (0 = free; cash can go negative, gold cannot); `gold = true` charges gold instead of cash
- `model`: ped model of the doctor

```lua
val = { coords = { x = 378.22, y = -11.25, z = 107.9, h = 67.53 },
        blip = { sprite = 2107754879, show = false, name = 'Val' },
        price = 30, gold = false, model = 'am_valentinedoctors_females_01' },
```

**config/grandmas/locale.lua**: player-facing text.

### guarma

A boat crossing to Guarma and back. Read on both sides: the server re-checks the dock distance, the job, the ticket and the price.

**config/guarma/main.lua**
- `General.debug`: a server console line when someone asks to sail.
- `Keys.board`: the prompt key (G).
- `Integrations`: nothing to switch; vorp_inventory is used for the optional ticket.
- `Docks`: `mainland` and `island` points (the prompt appears at both ends; you land on the other one), `promptDistance` metres from a dock (the server allows 3 more).
- `Crossing`: `price` per crossing (0 = free), `moneyType` 0 cash / 1 gold, `ticketItem` item consumed on boarding, e.g. `'boat_ticket'` (nil = no ticket), `jobs` allowed to cross (empty = anyone).

### hogtie

A non-law player loses the lasso they hogtied someone with, and a hogtied player cannot break free while somebody is close. Also provides the restrained checks other modules use.

**config/hogtie/main.lua**
- `General.debug`: server console trace of every lasso-removal decision.
- `Integrations`: nothing to switch; vorp_inventory takes the lasso away.
- `Lasso`: `removeWeapons` weapons taken from the hogtier after use (e.g. add `'WEAPON_LASSO_REINFORCED'`), `keepJobs` jobs that keep their lasso.
- `BreakFree.blockRadius`: metres; the break-free control is disabled while another living, untied player is this close.

### instance

Routing buckets: the `instanceplayer:*` events, instanced zones and character-creator isolation.

**config/instance/main.lua**
- `General.debug`: F8 prints for zone enter / leave / bucket changes.
- `Integrations`: nothing to switch; PolyZone draws the zone shapes.
- `Buckets.creatorBase` (server): character creator isolation uses bucket = this + server id.
- `Indicator`: the on-screen notice while inside an instanced zone (text in `InstanceLocale.indicator`). `x` / `y` screen position (0-1), `scale`, `colour` `{ r, g, b, a }`.

**config/instance/zones.lua**: walking into one of these zones puts you in its own routing bucket (a private copy of the world); walking out puts you back in your home bucket. It ships with one example zone ("Example Saloon"); replace it with your own.
- `channelId`: the routing bucket, unique per zone (the example uses 30; give each new zone the next number)
- `name`: shown in the on-screen notice
- `points`: the zone outline, `vector2` corners in order; `minZ` / `maxZ`: height band
- `allowErp`: true / false sets the love-zone flag on enter (leave out = untouched)
- `dungeon = true`: sets the dungeon stance while inside
- `debugGrid`: PolyZone debug grid; `gridDivisions`: its resolution

```lua
{ channelId = 31, name = "My Saloon",
  points = { vector2(-312.4, 797.4), vector2(-302.5, 799.8), vector2(-306.1, 819.9), vector2(-316.9, 818.2) },
  minZ = 117.0, maxZ = 123.5, debugGrid = false, gridDivisions = 20, allowErp = false },
```

### interactions

Press U near a chair, stool, bench, couch, bed, cot, bedroll, piano or bathtub and pick what to do from a pup-ui menu; dancing works anywhere. The player is placed on the object and stays in the pose until they press the get-up prompt (the same key), die, or another resource fires `pup_worldint:clear` / `pup-misc:interactions:clear`. Client only: no server part, items or database.

The key does nothing while pup-ui is stopped, while dead, fighting, mounted, leading a horse, in any vehicle, swimming, ragdolled, falling, hogtied or cuffed, within 4 m of a pup-stable wagon (U is the wagon menu there), and for non-human peds.

**config/interactions/main.lua**
- `Keys.interact`: opens the menu; the get-up prompt uses the same key.
- `General`: `humanOnly` (the menu never opens for an animal ped), `restoreDistance` (on getting up the player goes back to where they started only if it is this many metres away or less), `standOnKnockdown` (knocked over, ragdolled or set alight ends the pose where they land instead of putting them back in the seat), `restartLimit` / `restartGapMs` (a pose that stops on its own is retried this many times in a row, this far apart, then the player stands up), `startGraceMs`, `cooldownMs`, `animLoadMs`.
- `Dance.anywhere`: `false` removes the Dance category.
- `Fillet`: a Five Finger Fillet row next to a seat in `Models.filletSeats`. `enabled` (off by default: no resource registers `/fff` yet), `command` (run with ExecuteCommand, no slash), `radius`.
- `Integrations`: `wagonStateBag` and `wagonRadius` for the pup-stable wagon check.
- `Effects`: effect id = function run once with the player's ped when an entry with that `effect` starts. `clean` (every bath) washes off dirt, damage decals and blood.

**config/interactions/models.lua**: named model lists. Names, backtick hashes and numbers (signed or unsigned) all work. `seatSingle` (one-person seats), `seatWide` (two-person seats; the menu calls them "bench"), `filletSeats`. A model in two lists gets the entries of both.

**config/interactions/interactions.lua**
- `Scenarios`: named lists, each item `{ scenario = 'NAME', ped = 'male' }`.
- `Animations`: named lists. A single anim is `{ id = 'bath_soak', dict = '...', clip = '...' }` and plays looped. A layered anim is `{ id = '...', parts = { { dict, clip, flag, delay }, ... } }`: each part starts `delay` ms after the previous one with its own anim `flag`, so the parts stack.
- `Interactions`: the list of entries.
  - On a prop: `objects` (a model list), `radius` (metres from the prop), `x` / `y` / `z` (offset in the prop's frame: x right, y forward, z up), `heading` (added to the prop's heading).
  - A world spot (bathtubs built into the map): no `objects`; `x` / `y` / `z` / `heading` are world values and `radius` is metres from that point.
  - Anywhere: `anywhere = true`, played where the player stands.
  - Also: `scenarios` or `animations` (one of the lists above), `category` (`sit`, `rest`, `piano`, `bathe`, `dance`), `side` (`left` / `right` on two-person props: each side is its own spot), `effect`, `ped`.
  - Example: `{ objects = { 'p_chair02x' }, radius = 1.5, x = 0.0, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'adult' },`
- Ped gates (`ped` on an entry hides the whole entry, on a scenario or anim hides that one row): `any`, `human`, `adult`, `child`, `male`, `female`, `adult_male`, `adult_female`. A function works too: `ped = function(ped) return IsPedMale(ped) end`. Every tag except `any` also requires a human ped.

**config/interactions/locale.lua**: all player text. Keep the `%s`, `%d` and `%.1f` placeholders. `actions` holds the menu row for every scenario (keyed by scenario name) and anim (keyed by its `id`); a missing one shows the raw name, so add a line here when adding a scenario or anim.

### knockout

Losing a melee fight (or a horse kick) knocks you out instead of killing you: you ragdoll, slowly heal and get back up. A dead player is left to pup-medical.

**config/knockout/main.lua**
- `Integrations`: nothing to switch. pup-events raises `LocalPlayer.state.pupNoMeleeKO` to opt a scripted fight out; the scene module shows the KO label; vorp_inventory is locked while you are out.
- `Melee.healthThreshold`: in melee combat and under this health = knocked out. `Melee.shieldMs`: how long you cannot be hurt right after a melee knockout (0 = killable at once).
- `HorseKick`: `enabled`, `healthThreshold` (take the KO if a horse hit leaves you under this), `graceMs` how long after the hit that still applies, `protectMs` how long you stay invincible so it cannot kick you again.
- `Recovery`: `startHealth` set the moment you go down, `steps` heal steps (you get up right after the last one), `stepMs` ms between two heal steps, `healPerStep` health added per step. Time on the ground is `steps` x `stepMs` and runs on the clock, so it is the same at any framerate.
- `Display.labelMs`: how long the knocked-out text stays on screen.
- `KnockoutLocale.knockedOut`: drawn on your own screen when you go down.

### outfitter

Camps and trail gear: bought at the stable, carried in the wagon, pitched out in the wild. Read on both sides: the server re-checks the price, the limit and the stable distance.

**config/outfitter/main.lua**
- `General.enabled`: false = no shop and no wagon menu (pup-stable hides its Outfitter row too). `General.debug`: F8 / console prints.
- `Keys`: `openKit` U beside your stable wagon (stands down while pup-stable's wagon menu owns U), `place` G, `cancel` Backspace, `turnLeft` / `turnRight` `[` / `]`, `nearer` / `further` Down / Up arrow.
- `Integrations`: nothing to switch. pup-stable is required: its `getConfig` export gives the stable counters (selling and the "step away" check), its wagons carry the `pup_stable_wagonID` state bag, its menu fires `pup-misc:outfitter:shop` / `pup-misc:outfitter:kit`, and it reads `LocalPlayer.state.pupOutfitterEnabled` / sets `pupWagonMenu`.
- `Shop` (the stable sells): `moneyType` 0 cash / 1 gold, `stableDistance` metres from a pup-stable counter a purchase is accepted (server check).
- `Wagon` (the wagon carries; press `Keys.openKit` beside it to pitch, pack or throw out): `range` metres for the "Press U" hint.
- `World`: `spawnLimit` how many of your own pieces may stand in the world at once, `renderDistance` metres before a placed piece is drawn for you (propsets are not networked), `renderPollMs` how often the draw/forget check runs.
- `Placement`: `startDistance` metres in front of you the piece starts, `minDistance` / `maxDistance` nudge range in metres (the server allows `maxDistance` + 6), `stepDistance` metres per nudge, `turnStepDegrees` per turn step, `bannedTowns` town names (matched on their hash) where no camp may be pitched.

**config/outfitter/items.lua**: what the stable sells. Camps (`OutfitterConfig.Camps`) are propsets: one hash builds a whole scene. Gear is a single object placed on the ground.
- `sku`: what the database stores (`outfitter.sku`). Renaming a piece is safe; changing a sku orphans what people already own.
- `model`: propset name (camps) or object model (gear); `label`: menu / message text; `price`: in `Shop.moneyType`.
- Example: `{ sku = 'tent_leanto', model = 'pg_ambcamp01x_tent_canvas_leanto01', label = 'Simple Tent', price = 25 },`

**config/outfitter/locale.lua**: player-facing text.

### pets

An animal that follows you around, summoned by a whistle item.

**config/pets/main.lua**
- `General`: `debug` console prints plus the `/petvariant` and `/petscan` coat finders (turn off for live); `maxPets` how many pets one player can have out at once (each whistle item is its own pet); `consumeItem` false = the item is a permanent whistle (use it again to put the pet away); `commands` the chat commands for the orders (`sit` toggles sit and stay, `track` sniffs and marks nearby animals, `hunt` toggles fetching your kills, `howl` only for animals in `PetsConfig.Anims.howl`, `attack` only registered while `Attack.enabled` is true).
- `Integrations`: nothing to switch. Used when present: pup-stable (calms your own horse around the pet), vorp_admin (spawn-guard allow window), pup_staffdesk (naming station; it owns the naming price and cooldown).
- `Follow`: `offset` metres from you (negative y = behind), `spread` metres sideways between pets, `recallRange` metres beyond which the pet is teleported back, `recallCheckMs` how often the check runs.
- `Behaviour`: `invincible` the pet cannot be hurt or ragdolled, `despawnOnDeath` your death puts every pet away, `allowRiding` lets a rideable pet (donkey, mule) be used as a mount.
- `Scale`: `default` for a pet with no `scale`, `min` / `max` clamp (1.0 = natural size).
- `Naming` (done at a pup_staffdesk station; written onto the whistle item's metadata): `maxNameLength` / `maxDescLength` in characters (markup not counted), `renameItem` true = the satchel label becomes the name; false = the breed stays and the name is only used in tips.
- `Sit.freezePet`: sit also freezes the pet, so it doubles as stay.
- `Howl.cooldownSeconds`: between howls.
- `Attack`: `enabled` (no command while false), `allowPlayers` lets a pet be sent at another player, `range` metres to the target.
- `Track`: `radius` metres, `durationSeconds` how long the blips last (min 5), `dict` / `clip` the sniff animation, `blipSprite` the animal icon (without a sprite the blip draws the default icon), `blipScale`.
- `Hunt`: `radius` metres around you to look for a carcass, `bone` the jaw bone the carcass attaches to, `skipModels` animals too big to carry (matched on hash).

**config/pets/pets.lua**: one entry per whistle item. The key is the item name (it must exist in the items table with `usable = 1`; see `sql/pets/install.sql`).
- `label`: breed name shown in tips (and in the satchel while the pet is unnamed); `model`: ped model; `scale`: size, 1.0 = natural (clamped by `Scale.min` / `max`)
- Coats, in priority order: `variant = 3` one fixed coat (everybody's looks the same); `variants = { 0, 1, 2 }` a pool, each character draws one the first time they whistle it and keeps it (table `pet_coats`); neither = coat 0, which every model has
- Only use coat numbers you have seen with `/petscan` (debug on). An index the model does not have leaves the random coat on, and it re-rolls on every summon.

```lua
['pet_shepherd_red'] = { label = 'Red Australian Shepherd', model = 'A_C_DogAustralianSheperd_01', variant = 1, scale = 0.5 },
```

Predators (coyote, wolf, cougar, panther, bear) work the same way but are not listed by default.

Coat finders (debug only): with a pet out, `/petvariant` steps to the next outfit variant, `/petvariant 7` jumps to 7, `/petvariant -1` goes back to a random coat; `/petscan [max]` walks 0..max on the pet and prints a paste-ready config line per index (run it again to stop).

**config/pets/anims.lua**: order animations (animations, not scenarios: a scenario redraws the ped and drops its scale). Each row is `{ model match, clip, dict, dict, ... }`: the model match is lower-case text searched for in the pet's model name (first matching row wins), the clip is the animation clip, and one or more dicts follow (the first that loads is used). Example: `{ 'wolf', 'base', 'amb_creature_mammal@world_wolf_sitting@wolf_small@base' }`.
- `sit`: bear, cat, fox and wolf are confirmed; the rest follow the same naming and print a line naming the dict if it does not load. `'lion'` sits after `'dog'` so `A_C_DogLion_01` still matches the dog row.
- `howl`: a pet with no row answers `/pethowl` with "nothing to say". An alternative growl is dict `creatures_mammal@wolf@melee@taunts` with clip `taunt_d`.

**config/pets/locale.lua**: player-facing text; keep the `%s` / `%d` placeholders.

### police

The lawman's toolkit: `/lawmenu`, cuff and escort hotkeys, wagon loading, and the rank badge with its in-world editor. Duty and ranks come from pup-mdt. Read on both sides: the server gates on `Jobs.law`.

**config/police/main.lua**
- `General.commands`: `menu`, `badge` (pin on / take off), `adjustBadge` (the badge editor). `/mmenu` is always kept as an alias of the menu.
- `Keys`: hold `hotkeyModifier` (Alt) and tap `cuff` (R, nearest player) or `escort` (G, nearest cuffed player); remove `hotkeyModifier`, or both cuff and escort, to turn the hotkeys off. Badge editor keys: `editorMode` (4: move / rotate / bone), arrows, `editorRaise` / `editorLower` (1 / 2: height / roll), `editorFine` (Shift, finer steps), `editorReset` (B, back to `Badges.default`), `editorSave` (G), `editorCancel` (Backspace).
- `Integrations`: nothing to switch. Used when present: pup-mdt (duty state, rank names, and it releases prisoners through `pup-misc:police:server:release`), pup-ui (menu, editor panel, progress bar).
- `Jobs.law`: every job that gets the law menu, cuffs, escort and a badge (while on duty in pup-mdt).
- `Restraint.interactDistance`: metres to the other player; the nearest wagon is looked for at 4x this.
- `Escort`: `sideMetres` how far to the lawman's right the cuffed person walks, `forwardMetres` how far ahead (negative = a step behind), `holdAnim` the lawman's upper-body hold (any dict/name; if it fails to load the escort runs without it; `false` turns it off).

**config/police/badges.lua**
- `ranks[job][grade] = { rank, prop }`: the rank name used when pup-mdt has none, and the badge model. pup-mdt's ladder runs to grade 12.
- `fallback`: worn by any law job with no table of its own and any grade above the ladder.
- `default`: the starting position, and what `Keys.editorReset` snaps back to (`bone`, offsets in metres, rotation in degrees).
- `editor`: `bones` where the badge may be pinned (cycled with Left/Right in BONE mode), `moveStep` metres per arrow tap, `rotateStep` degrees per tap, `fineFactor` step multiplier while `Keys.editorFine` is held.

**config/police/locale.lua**: player-facing text; keep `%s`.

### pomade

A usable item that slicks the hair back (the "POMADE" hair wearable state) with the apply animation.

**config/pomade/main.lua**
- `Item`: `name` (must match the items table; the row is written on start with limit 10, usable) and `label`.
- `Use.maleOnly`: the slicked-hair state only exists on the male hair models.
- `PomadeLocale.denyFemale`: shown when a female character uses the item.

### props

Usable items that attach a prop to the player (canes, pipes, necklaces, instruments ...), and the `/pa` editor that lets a player nudge a worn prop and save the position per character.

**config/props/main.lua**
- `General.command`: `/pa`, pick a worn prop and move it. `General.startupDelaySeconds`: after character select, wait this long before drawing other players' props (your own apply at once).
- `Keys` (`/pa` editor): arrows move x / y (with `rotate` held they rotate), `raise` / `lower` (`[` / `]`) move z, `rotate` (Shift) hold to rotate instead of move, `reset` (B) back to where the edit started, `stepSize` (G) cycle the step size, `save` (Enter) open the save menu, `cancel` (Backspace) cancel and revert.
- `Editor`: `moveRepeatMs` ms between steps while a key is held (higher = slower), `moveDelayMs` ms after the first press before it repeats, so a tap moves one step. Steps run on a clock, so the speed is the same at any framerate.

**config/props/props.lua**: one entry per usable item: the item row (synced into the items table on start) and where its prop sits on the ped.
- `item`: item name (unique); `label`: item label, also shown in the `/pa` picker; `limit`: `items.limit` (default 1)
- `model`, or `model_male` + `model_female` for a model per body type
- `bone`: ped bone name; `"ENTITY_ROOT"` = body root (stays still while the ped animates)
- `attach = { x, y, z, rx, ry, rz }` offset from the bone, or `attach_male` + `attach_female`
- `anim`: optional looping idle on the wearer `{ dict, clip [, durationMs, flag, rate] }`; `animOnly`: play the pose only and attach nothing (the pose brings its own prop)
- `scenario`: optional scenario to pose the wearer (`scenarioSeatZ` = seat height offset)
- `extra`: extra objects for a set `{ { model, bone, attach }, ... }`

```lua
{
    item = "pup_cane_wood", label = "Wooden Cane", limit = 1,
    model  = "cane_wood",
    bone   = "skel_l_hand",
    attach = { 0.0539, 0.1546, -0.1073, -139.7477, 0.0, 0.0 },
},
```

**Custom models not included.** The canes (`pup_cane_wood`, `pup_cane_diamond`, `pup_cane_claw`, `pup_cane_skull`) and `pup_cross_necklace` use custom prop models (`cane_wood`, `cane_diamond`, `cane_claw`, `cane_skull`, `cross_neck_m` / `cross_neck_f`) that are not in this repository. Without them the items still work but show nothing on the player. Stream your own models under those names, or set `model` on those entries to any prop the game already has. The items also appear in pup-events loot and pup_staffdesk bounty rewards.

**config/props/locale.lua**: player-facing text.

### ragdoll

Press the key (default Z) to flop, press it again to get up. Getting up is always allowed.

**config/ragdoll/main.lua**
- `General`: `enabled`, `command` (also bound through RegisterKeyMapping: Settings -> Key Bindings -> FiveM), `cooldownMs` debounce so a held key does not flicker the toggle.
- `Keys.toggle`: the default key for a player who has never had the bind (a key name, not a hash).
- `Ragdoll.pulseMs`: SetPedToRagdoll duration per pulse (ms), re-applied every frame while down.
- `Blocks`: states another system owns; a ragdoll cannot start in them and is dropped if one takes over. Cuffed always blocks. `hogtied`, `dead`, `mounted` (horse or vehicle; ragdolling there desyncs), `inWater` (swimming), `alreadyRagdolled` (cannot start while already limp for another reason).
- `RagdollLocale.keyLabel`: the row name in the Key Bindings list.

### river

Drink from and wash in rivers and lakes, fill, boil and drink water bottles, and get poisoned by dirty water (cured with the antidote or after a while). Also face-washing at water troughs and barrels. Stat changes go through `fred_meta:consume`; both washes fire `pup_camps:washedface`, so fred_metabolism clears its drunk / high state.

**config/river/main.lua**
- `Keys`: `riverWash` (B) and `riverDrink` (U) in water, `barrelWash` (E) at a trough or barrel, `modifier` (Alt, only with `Prompts.requireModifier`).
- `Prompts`: `holdMs` (how long a prompt is held), `requireModifier` (true = the prompts only show while Alt is held).
- `Items` (registered as usable; names must match `sql/river/install.sql`): `dirtyBottle` (`bottle_river_water`), `cleanBottle` (`bottle_boiled_water`; an older install with the earlier bottle ids runs `sql/river/rename-bottles.sql` once, and players keep their bottles), `emptyBottle` (filled in water, given back after a drink; `false` = no empty bottle, a dirty bottle used in water is refilled and a drink keeps nothing), `antidote` (only used while poisoned).
- `Poison`: the chance is 1 in `<odds>`: `bottleOdds` for a dirty bottle, `riverOdds` for drinking straight from the river; `vomitIntervalMs`; `durationMinutes` (poison wears off after this, 0 = only the antidote); `skipWhen` (no vomiting while dead, mounted or in a vehicle). Poison is kept per character and survives a relog.
- `Stats`: `drink` and `poisoned`, the nine `fred_meta:consume` values (food, thirst, metabolism, then the six core values).
- `River`: `drinkCooldownSeconds` (between drinks straight from the river), `restrictZones` and `zones` (only these water-map zones count; false = any water), timings.
- `Spots`: extra places that count as water, even when dry (`coords`, `radius` in metres).
- `Bottles`: fill window and timings, and the bottle prop / interaction used for the drinking animation.
- `Boil`: `enabled`, `radius` (metres from a fire model), `durationMs`, `moveLimit` (moving this far cancels), `models` (the fires that count).
- `Barrel`: `radius` (0.8 m), `scanMs`, `models` (troughs and barrels), `effects` (the screen effects a barrel wash stops; others are left alone).
- `Anims`: game animation and scenario names; leave them unless you know the game files.

**config/river/locale.lua**: prompt labels and messages.

A dirty bottle used within 2 m of a campfire or cooking fire is boiled into a clean bottle. Anywhere else it is drunk (and can poison). A clean bottle is always drunk. A trough or barrel in reach takes the wash, so the river prompts are hidden there.

### scenario

`/scenario`: a pup-ui list of scenario poses (nearby world spots plus play-in-place categories), and the revolver/pistol gun-spin tricks. Client only.

**config/scenario/main.lua**
- `General.command`: opens the menu.
- `Keys` (gun spin): `trickToggle` turns trick mode on / off, `trickDo` (Up) does the selected trick, `trickEnd` (Down) leaves trick mode, `trickPrev` / `trickNext` (Left / Right) pick a trick.
- `GunSpin.tricks`: `{ hash = kit emote, label = shown after "Trick: " }`. Order matters: the first two are played as emotes; every entry from the third on is played as a variation of the last emote by its position in the list. Have a revolver or pistol in hand and press `trickToggle`.

**config/scenario/scenarios.lua**: every scenario type name the game knows, one per line (e.g. `"WORLD_HUMAN_SIT_GROUND"`). The menu files the `WORLD_HUMAN_*` and `PROP_HUMAN_*` ones into its categories by name (MUSIC / SIT / LEAN / DRINK / SMOK), and the nearby scan uses the whole list to name the world spots around you.

**config/scenario/locale.lua**: player-facing text; keep `%d`.

### scene

`/scene` floating text placed in the world, plus the `/me`, `/ooc`, `/id`, `/cash` and `/status` labels and the "Knocked Out" tag. Read on both sides.

**config/scene/main.lua**
- `General.commands`: `place` (type a text, then place it), `removeAim` (toggles aim-to-remove mode), `me`, `ooc`, `status` (a label over your head until `cstatus`), `stopStatus`, `id`, `cash`.
- `Keys`: a raw control hash (number) or an `"INPUT_..."` name (string). `place` (G) places the scene / removes the aimed one in `/scenes` mode; `mode` (4) cycles AIM / MOVE / STYLE and also removes a scene you stand at; arrows move in MOVE mode or step rows / values in STYLE mode; `raise` / `lower` (1 / 2) move up / down; `cancel` (B) cancels placement or leaves `/scenes` mode.
- `Integrations`: nothing to switch. Used when present: pup-ui (draws every label), vorp_admin (staff override of the job lock), knockout (sends `pup-scene:setKO`).
- `Access` (admins always may): `jobLock` true = only `allowJobs` may place scenes; `allowJobs` may place (and remove their own); `removeJobs` may remove anyone's scene; `hideout` no scenes are drawn or placed within `radius` metres of `coords`.
- `Removal` (`/scenes`, aim and press `Keys.place`): `aimRange` metres, `aimDot` how tight the aim cone is (0.995 is about 6 degrees).
- `Display.defaultRange`: metres; the view distance of a new scene, and how close you read a `/status`.
- `Place`: `aimDistance` metres the camera ray reaches in AIM mode before the text floats in mid air, `surfaceOffset` metres lifted off the surface so the text does not z-fight, `moveSpeed` / `moveSpeedMax` m/s and `moveRamp` seconds of holding to reach full speed (MOVE mode), `previewHz` updates per second and `previewRange` metres for the ghost preview other players see while you place.
- `KnockedOut`: the tag over a knocked-out player (`r, g, b`, `scale`, `font`, `back` backing plate opacity with 0 = off, `range` metres, `height` metres above the ped). Text is `SceneLocale.knockedOut`.
- `Limits` (enforced by the server): `maxTextLength` characters, `maxPlaceDistance` metres from the player, `maxScenesPerChar` (0 = unlimited), `minScale` / `maxScale`, `maxRange` metres.

**config/scene/styles.lua**: what the STYLE row of the placement bar offers.
- `palette`: the Colour row; `name` shown, `r/g/b` text colour, `token` the game colour token used when an Effect paints the other words.
- `sizes` (text scale), `fonts` (`id` = game font id), `backings` (plate opacity behind the text, 0 = no plate), `ranges` (metres a scene can be read from).
- `inlineColours`: tags a player may type, e.g. `[red]wanted [gold]dead or alive`. Text before the first tag uses the scene's own colour; the value is the game colour token.
- `accentOrder`: the order the Accent row steps through; keep it in step with `inlineColours`.
- `patterns`: the Effect row, which words take the accent colour (the no-typing way to get two colours).
- `presets`: the Look row. One pick sets `colour` (palette name), `accent` (`inlineColours` key or nil), `effect` (patterns id), `size`, `font` id and `backing` (backings name).

**config/scene/locale.lua**: player-facing text; keep `%s`.

Placed scenes are logged to Discord when `Webhooks.scene.log` is set in `server/config.lua`.

### search

Search and rob a cuffed or hogtied player. The settings are read on both sides; the server re-checks every rule, and the client only uses them to decide whether to draw the prompt and which rows to offer.

**config/search/main.lua**
- `General`: `debug` console tracing on both sides, `searchKey` (G), `promptDistance` metres to the closest player (client).
- `Targets`: who can be targeted (`cuffed`, `hogtied`, `dead`; the purge switches `dead` on).
- `Law`: `jobs`; `searchOnly` only law (and the super-bypass account) may search; `cashOnly` only law may use the Cash row; `cashBypass` / `itemBypass` / `weaponBypass` law may take cash / items / weapons even when `Steal` has them off; `requireDutyForAll` false = a law job gets past Sisika, the law-only switches, the bypasses and the new-character shield without being on duty, true = every law privilege needs duty.
- `Steal`: what anyone may take (`cash`, `items`, `weapons`). Weapons always need on-duty law, whatever this says.
- `Limits`: `maxStacks` item stacks plus weapons per victim character per window, `windowMinutes`, `slidingWindow` (false = the window starts at the first theft and stays fixed; true = the last N minutes), `reach` metres between searcher and target (server; 0 = off), `lockSeconds` "being searched" lock after a search opens, `exclusiveVictim` (true = one robber per victim for as long as the session lasts), `bypassJobs` skip the limit and the shield while on duty, `shieldMinutes` new-character shield (0 = off).
- `Duty`: `enabled` (off = everyone counts as on duty), `protectedJobs` cannot be robbed while on duty, `doctorViaMedical` (false = every protected job is looked up through pup-mdt, then pup_business; true = `medicalJobs` go through pup-medical), `businessMissingMeansOnDuty` (true = pup_business not running means on duty), `resources` the resource names used for the duty checks.
- `VerifyTarget`: the server asks the target's own client whether it is really hogtied, cuffed or dead before opening; a target that does not answer within `timeoutMs` cannot be searched. Turn off to trust the searcher's client.
- `Sisika`: `block` (inside, only law and the super-bypass account may search), height band `minZ` / `maxZ`, and the `points` polygon.
- `Cash.takeAllIncludesCents`: asking for at least everything the victim holds takes the whole balance, cents included; smaller requests stay whole dollars.
- `Database`: `checkColumnDelayMs`; `backfillOnCreate` / `backfillDate`: when this module has to add the `character_created` column, existing characters get an old date so they are not shielded.
- `Webhook`: `enabled`, `username`, `avatar` ('' = Discord default), `footer`, embed `colours`. The URL is `Webhooks.search.admin` in `server/config.lua`.
- `Notify`: tip durations in ms (`longMs` for protected-job and new-character refusals).
- `Anim`: the crouch animation while searching; `Controls.inventory`: controls disabled every frame while restrained.
- `Timings`: client and server timings in ms (prompt delays, job refresh, reply and panel timeouts, purge polling).
- `RateLimit`: per-source minimum gap between net requests, in ms.
- `Purge`: what changes while pup-events has the `purge` event live (`deadSearch`, `shieldMinutes`, `protectedJobs`, `maxStacks`, `windowMinutes` and empty blacklists).

**config/search/blacklist.lua**: what a robber can never take (the super-bypass account ignores all of it). `prefixes` any item whose name starts with one of these, `weapons` exact weapon names (compared upper-case), `items` exact item names. The purge swaps these for the empty lists in `SearchConfig.Purge`.

**config/search/server.lua** (server only, never sent to clients): `SuperBypass` is the account that ignores every search restriction: one identifier string (`steam:...`, `license:...`, `discord:...`) or a list of them. Empty = nobody. Set it in `server/config.lua`.

**config/search/locale.lua**: player-facing text; keep the `%s` / `%d` placeholders in order.

### smokes

Usable pipes, cigars, cigarettes and chew. The smokes live in the `smokes` table and are edited from the vorp_admin panel. Read on both sides.

**config/smokes/main.lua**
- `Keys` (prompts while smoking): `putAway` (F) put away / finish, `use` (left mouse) inhale / use, `stance` (E) change stance.
- `Integrations`: nothing to switch. vorp_admin's smokes panel calls the `smokesList` / `smokesSave` / `smokesDelete` exports; vorp_inventory registers the usable items.
- `Pipe.item`: a smoke marked `pipe` needs this item in the satchel; it is not used up.

**config/smokes/smokes.lua**: `SmokesConfig.Seed`, written into `smokes` only when that table is empty, and used as the whole list when the database cannot be reached. Normally empty: the table owns the data (the stock list is in `sql/smokes/install.sql`). One entry per usable item, keyed by item name:
- `pipe = true`: needs `SmokesConfig.Pipe.item`
- `subitem`: stored for the panel (the item is always used up)
- `typeof`: `'cigar'`, `'cigarette'`, `'pipe'`, `'chew'` or `'peace'` (which animation set)
- `high = true`: plays the camera effect `hightype` for `highduration` seconds
- `boost = true`: applies `healthboost` / `staminaboost`
- `drunkamount`, `drunkscreen`, `drunkwalk`: drunk strength, screen wobble, walk sway
- `turbo = true`: cycles the `effects` list (extra camera effect names) every `effectinterval` seconds

```lua
joint = { pipe = false, subitem = true, typeof = 'cigarette', high = true, hightype = 'PlayerRPGcore',
          highduration = 60, boost = true, healthboost = 1000, staminaboost = 1000, drunkamount = 100,
          drunkscreen = 5, drunkwalk = 0, turbo = false, effectinterval = 10, effects = {} },
```

Camera effect names are listed in the community `rdr3_discoveries` animpostfx list (see Credits).

**config/smokes/locale.lua**: player-facing text.

### storagebox

Portable storage boxes and job packs. The server enforces every rule; the client only draws.

**config/storagebox/main.lua**
- `Debug`: extra console lines on the server. `LogUsername`: Discord username on log posts (webhooks: `Webhooks.storagebox` in `server/config.lua`).
- Timings and distances: `HideoutBucketFrom` (a routing bucket this or higher = inside a pup_hideouts hideout), `HideoutPollMs`, `ServerReach` and `PromptRadius` (metres), and the `...Ms` throttles and delays (all in ms): put-down throttle, deposit guard, new-box lock, give check, depositing/placing flags, open delay, state resend, placed-box sync and inventory registration delays.
- `WriteConfirmTimeoutMs` / `WriteConfirmStepMs`: vorp_inventory writes some stack merges asynchronously; reads are retried until they settle.
- `Keys`: `putDown` (put the carried box down), `pickUp` (pick a placed box up), `open` (E, open a placed box).
- `Carry`: `maxStamped` opened boxes and packs one satchel may hold (also the default item limit), `extraBoxFactor` each extra loaded box multiplies the move rate by this (compounding), `defaultMoveRate`, `defaultModel` crate model (`p_crate02x` is an alternative), `restoreMoveRate` movement cap given back when carrying stops; `anim`, `bone`, `offset` and `rotation` were tuned together, so change them together; `resetFlag`, `blockedControls`; `handFlagNative` / `handFlags` ped carrying flags switched off while carrying (empty = off); the wagon block timings (`wagonEjectMs`, `ragdollMinMs` / `ragdollMaxMs`, `wagonDebounceMs`).
- `Anims`: inspect, put-down and pick-up animations; `InspectFocusWaitMs` / `PollMs` / `GraceMs` watch the panel focus while crouched at a placed box.
- `PutDown`: ray cast `rayHeight` above the feet and `rayLength` forward, `wallMargin` subtracted from the hit distance, `minDistance` / `maxDistance` (also the distance when nothing is hit), in metres.
- Inventory types: `DepositTypes`, `TransferSourceTypes`, `PocketPanelTypes` (a pack unloads into the pockets there) and `ShopPanelTypes` (counts as "at a shop"). Shops must never be added to the deposit types: they go through the shop path.
- `InventoryDefaults`: custom inventory defaults for every box and pack. `ItemDefaults`: item rows synced into vorp's `items` table at start.
- `Switches`: `OneUsedBoxPerType` one opened box of each item type per player; `EmptyBoxDirectInsert` last resort for an empty box tipped into an unregistered inventory (write it into the database); `VerifyDepositArrival` read the target back before destroying a deposited box; `LoadedDroppedBox` `'keep'` (recoverable by whoever picks the item up, and by staff from the log) or `'delete'` the inventory and contents of a loaded box that leaves a satchel by a drop or delete; `SteamInLogs` society and house logs show Steam name and id; `TypeWebhooks` also post to the per-type admin webhooks (house, camp, hideout, custom).

**config/storagebox/boxes.lua**: the box and pack item types. Boxes are carried in both arms when loaded, can be put down in the world, and can be tipped whole into a container. Packs are job satchels that only take their own materials; they are never carried, never put down and never used up.
- `label`, `desc`: item label and description (synced into the `items` table at start)
- `capacity`: slot limit of the box's custom inventory (0 = unlimited)
- `moveRate` (boxes): max movement blend ratio while carrying it (lower = slower); `model` (boxes): crate model in the hands and on the ground (nil = `Carry.defaultModel`)
- `limit`, `rarity`: item row values (nil = `ItemDefaults`)
- `gather` (packs): `'mining'`, `'lumber'` or `'farming'` (what PackStore callers pass); `jobs` (packs): jobs that may open it (`{}` = anyone); `materials` (packs): exact item names the pack accepts

Box rows reference the item name, so never rename a box once it is in use.

```lua
storage_box_500 = { label = 'Small Storage Box', desc = 'Holds up to 500 item slots.', capacity = 500, moveRate = 0.9 },
```

**config/storagebox/locale.lua**: player text; keep the `%s` / `%d` placeholders in the same order.

### tattoos

The tattoo and makeup mirror: face overlays bought at a shop and Body Adjustments (MetaPed expressions). Read on both sides: the server charges the prices.

**config/tattoos/main.lua**
- `General.debug`: console prints on both sides (loads, saves, row counts).
- `Keys`: `openMenu` (G) opens the mirror at a shop. The camera keys (`resetCamera`, `cameraUp` / `cameraDown`, `zoomIn` / `zoomOut`, `rotateLeft` / `rotateRight`, `back`) belong to the older camera screen.
- `Integrations`: nothing to switch. Used when present: pup-ui (menus), vorp_character (draws the layers listed in `Layers.excluded` through its OverlayRaw export).
- `Prices` (dollars, charged by the server on save): `layers` for saving tattoos, makeup and every other overlay layer (all layers at once), `bodyAdjustments` for saving Body Adjustments.
- `Shops`: `radius` metres from a shop for the prompt, `blip` sprite and scale (the blip name is `TattooLocale.blipName`), `locations` with `name` (for you only), `coords` (vector3 where the prompt appears) and `showBlip` (false keeps the shop off the map). Example: `{ name = 'Valentine', coords = vector3(-325.08, 760.24, 117.43), showBlip = true },`
- `Layers`: `excluded` overlay names this menu must not touch (another system owns them), as `{ name = true }`; `makeup` the layers grouped under Makeup.
- `Mirror.categories`: the icon strip across the top of the mirror page. `id` internal key, `label` shown on the page, `layers` overlay names. A layer not listed lands in the last category. The page title is `TattooLocale.menuTitle`.

**config/tattoos/locale.lua**: player-facing text, including the labels shown instead of raw overlay names; keep `%s`.

### traffic

Ambient population density, applied every frame on the client.

**config/traffic/main.lua**
- `Density`: multipliers, 1.0 = the game's normal amount, 0.0 = none. `peds` (ambient and scenario peds and humans), `animals` (ambient and scenario animals), `vehicles` (parked, random and moving vehicles such as wagons and coaches), `noAnimalTowns` towns where the animal density is forced to 0.0.

## For developers

All exports are called as `exports['pup-misc']:Name(...)`.

### bandana
- Client export `IsBandanaUp()`. Client event `pup-misc:bandanaState` (fired on this client when the state changes; the server can also force the state).

### ecoboost
- Server exports: `GetEcoBoostStatus(src)`, `ActivateEcoBoost(src)`, `ApplyEcoBoostSale(src, placeName, total)` (called by a store during the sale; returns the bonus to pay on top), `EcoBoostMultiplierFor(src, placeName)` (the multiplier a store may show, else 1), `EndEcoBoost(src)`.
- Client event `pup-misc:ecoboost` drives the fred_hud gauge.

### emotes
- Client exports: `GetEmoteList()`, `PlayKitEmote(kitHash, mode)`, `PlayScenario(scenarioHash)`, `PlayAnim(anim)` (`anim = { dict, name, flag?, fdict?, fname? }`), `PlayEmoteCommand(cmd, mode)`, `StopEmote()`.
- Client event `pup-misc:stopAnim` is fired when an emote is stopped.
- Shared client globals (one Lua state for the whole resource): `EmotesPlayAnim`, `EmotesCanPlay`, `EmotesConsuming`.

### hogtie
- Client exports `IsRestrained(ped)` and `BlockIfRestrained(message)` (returns true when the caller should refuse; shows `message` or the default text). The same checks are available inside pup-misc as `PupIsRestrained` / `PupBlockIfRestrained`.

### instance
- Server exports `SetInstance(src, bucket)` and `GetInstance(src)`.
- Events `instanceplayer:setNamed` (from players: into a zone they are at, or back out of one) and `instanceplayer:setNamed2` (server side only, any source).
- Client exports `IsInLoveZone()`, `GetCurrentLoveZone()`, `GetLoveZoneConfig()`.

### knockout
- Set `LocalPlayer.state.pupNoMeleeKO = true` to keep a scripted fight from knocking players out.

### outfitter
- Client events `pup-misc:outfitter:shop` (open the stable shop) and `pup-misc:outfitter:kit` (open the wagon kit), fired by pup-stable's menus. `LocalPlayer.state.pupOutfitterEnabled` tells pup-stable whether to show its Outfitter row.

### pets
- Server exports `PetWhistles(src)` (every pet whistle in the satchel, with `namedAt`), `PetWhistleById(src, itemId)`, `SetPetName(src, itemId, name, desc)` (returns ok, errorMessage; the caller owns any price and cooldown).

### police
- Server event `pup-misc:police:server:release` (server side only: `TriggerEvent('pup-misc:police:server:release', targetSrc)`) frees a player from cuffs and any drag, e.g. when a sentence starts.
- Client export `isplayerinjail()` always answers `false, 0` (imprisonment is handled by pup-mdt).

### scene
- Server event `pup-scene:setKO` (sent by the knockout module) shows the Knocked Out tag.

### search
- Server exports `GetSearchTarget(searcher)` (who this player is searching right now), `RefreshSearchView(searcher, target)` (redraw the searcher's panel after a seizure), `PurgeSearchStatus()`, and `getPlayTime()` / `getHWIDCount()`.
- Inside pup-misc, `PupStorageBoxNoteTransfer` (storagebox) is called before an item is moved from a robbed player.

### smokes
- Server exports for the vorp_admin panel: `smokesList()`, `smokesSave(data)`, `smokesDelete(name)`.
- `LocalPlayer.state.pupSmoking` is set while a smoke runs.

### storagebox
- Client export `IsCarrying()`.
- Server exports for traders and gatherers (every export takes the satchel item id of the box and proves the player holds it): `BoxItemNames()`, `BoxInfo(src, itemId)`, `BoxContents(src, itemId)`, `BoxesOnPlayer(src)`, `BoxSpace(src, itemId)`, `BoxTake(src, itemId, craftedId, amount)`, `BoxPut(src, itemId, name, amount, metadata)`, `BoxConsumeIfEmpty(src, itemId)`, `PackStore(src, gatherType, itemName, amount)`, `PackCanStore(src, gatherType, itemName, amount)`.
- Client event `pup:promptYield(ms)`: another resource owns the prompt bar for a while.

### tattoos
- Client export `ReapplyOverlayTexture()`: rebuilds the overlay texture after a ped rebuild.

## Credits

- `shared/dataview.lua` is the community DataView module for CfxLua (a Lua port of the JavaScript DataView API) by gottfriedleibniz, shared through femga/rdr3_discoveries; not written for this project, and the same module ships with VORP. No licence is stated upstream.
- gestures: the hands-up and point gestures were first ported from an `rm` emote resource (author not recorded). The code has since been rewritten; only the game animation names remain.
- coordtool: the coordinate readout and the `/cc` clipboard copy are based on free CopyCoords snippets shared in the FiveM / RedM community (authors not recorded). The server list and its staff checks are this project's own.
- scenario: the menu, the label function and the nearby-point scan were rewritten for this project; the first version came from a community scenario script (author not recorded). The scenario name list is game data.
- knockout: the first version followed the widely shared free "Player Knockout" script; the current state machine is a rewrite with the same player-facing behaviour.
- Propset and camera-effect names used in the outfitter and smokes configs come from the community `femga/rdr3_discoveries` research project.

## License

See LICENSE.
