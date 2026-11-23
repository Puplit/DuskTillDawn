# skinanimals

Pays out inventory items when a player skins or loots an animal carcass the normal game way. The server checks every claim, each carcass pays out only once, and every animal kind has its own yield.

## Features

- Yields by kind of animal (up to three items each), one row per ped model, and separate rows for the game's legendary animals matched on model and outfit.
- Server-checked claims: cooldown, reach, dead-carcass check, flood guard, and one payout per carcass.
- Limits for carcasses the server cannot see, with a separate, stricter limit for Legendary animals.
- Optional game mercy kill, carcass deletion and carried-pelt deletion after a skin.
- Optional pup-perks double-yield roll and XP, and pup-stable horse bond reward.
- Optional Discord skinning log; the webhook never leaves the server.
- No commands, menus, NUI screens or permissions. The resource never writes to the database.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-perks` (optional: `skin_double` and `skin_legendary_double` rolls, `skin` and `skin_legendary` XP)
- `pup-stable` (optional: horse bond reward, kind `skin`)

If an optional resource is missing, its part is skipped and the console warns once.

## Installation

1. Keep the folder name `skinanimals`. pup_camps calls its exports by that name, and vorp_inventory's `ApiGiveIgnore` list names it.
2. Run `sql/install.sql` once, and `legendaryhunt/sql/install.sql` for the legendary trophies. Both only add item rows (`INSERT IGNORE`) and are safe to run twice. Do a full server restart afterwards, because vorp_inventory reads the items table at start.
3. Add `ensure skinanimals` after `vorp_core`, `vorp_inventory` and `oxmysql` (and after pup-perks and pup-stable if you use them).
4. Optional Discord log: set `SkinSecrets.skinningLog` in `server/config.lua` and set `Config.SkinningLog.enabled = true`. `server/config.lua` is a server script only and never reaches a client.

## Commands

None.

## Configuration

### config/main.lua

`Debug`: prints each step of every skinning claim to the server console (plus a read-only check that each item exists in `items`).

**Skinning**

| Setting | Meaning |
|---|---|
| `deleteCarcass` | Delete the carcass once the server has answered the claim. Only when this machine owns the carcass or can take control of it. |
| `deletePelt` | After `peltDelayMs` (ms), delete the pelt object the player is carrying. Only an object is deleted; a carried whole carcass is left alone. |
| `anyOutfitFallback` | When the game reports an outfit no legendary row names, pay the model's plain yield. `false`: only when the game reports no outfit at all. |

**Rules** (server checks on every claim)

| Setting | Meaning |
|---|---|
| `cooldownSec` | Seconds per player between accepted skins. |
| `reach` | Metres between the player and a carcass the server can see. |
| `allowUnseen` | Claims for a networked carcass the server cannot see. `false` (default): refuse them. `true`: pay them within the limits below, but the server then has no model, death or distance check, so a modified client can claim from anywhere without an animal. A carcass with no network id is always refused, and a Legendary row is only paid for a carcass the server can see, whatever this is set to. |
| `unseenMax`, `unseenWindowSec` | Unseen claims allowed per player per window (seconds). |
| `unseenLegendaryMax`, `unseenLegendaryWindowSec` | Legendary claims allowed per player per window (seconds), counted separately. |
| `limitLegendarySeen` | `true`: Legendary claims count against the Legendary limit even when the server can see the carcass. The server cannot read outfits, so without this a modified client could claim a common carcass as the legendary row of its model. legendaryhunt allows one hunt per player per 120 minutes, so honest hunters stay well inside 2 per hour. |
| `requireDeadCarcass` | Refuse a visible "carcass" whose health is above 0. If a skin is ever refused with `notDead` in the debug trace although the animal was dead, set this to `false`. |
| `paidLifetimeSec`, `paidSweepSec` | How long a paid carcass id is remembered, and how often old ids are dropped (seconds). |
| `floodMax`, `floodWindowSec` | More claim events than `floodMax` per window (seconds) are dropped silently. |

**MercyKill**: `enabled` turns on the game's mercy kill for the player; `startDelayMs` is the delay after the resource starts on the client, `selectDelayMs` the delay after every character select.

**Messages**

| Setting | Meaning |
|---|---|
| `style` | `'tip'`: VORP right-hand tip, text only. `'left'`: VORP left notification with the title above the text, red for refusals. |
| `refusalMs`, `resultMs` | How long refusal and result messages stay (ms). |
| `distinctRefusals` | `false`: cooldown, wrong animal, too far and too many unseen claims all show the "busy" text. `true`: each shows its own text. |

**Integrations**: `horseBond` (pup-stable bond reward, kind `skin`), `bondOnlyWhenItemGiven` (`false` gives the bond as soon as a claim is accepted, `true` only when at least one item was given), `perks` (pup-perks double-yield roll and XP).

**SkinningLog**: `enabled` turns on the Discord log. The webhook URL lives in `server/config.lua` (`SkinSecrets.skinningLog`).

### config/animals.lua

Four tables:

- `Config.Yields` - a kind of animal and the item ids it gives, paid in order (one to three):
  ```lua
  elk = { 'venison', 'elks', 'elkantler' },
  ```
  Small animals simply list one item.
- `Config.Animals` - `{ name, model, yield }`, one row per ped model, any outfit. The name is only used in the Discord log.
  ```lua
  { 'Elk', `a_c_elk_01`, 'elk' },
  ```
- `Config.Fish` - fish model names. A fish carcass pays the item of the same name.
- `Config.Legendaries` - `{ name, model, outfit, { meat, trophy, part } }`. `outfit` is the meta ped outfit hash the game reports, or `false` for a model that only exists as a legendary. These rows count as Legendary for the perks, XP and the Legendary claim limit, and are checked before the plain row of the same model.
  ```lua
  { 'Legendary Snowflake Moose', `mp_a_c_moose_01`, 538065295, { 'biggame', 'legmooses1', 'legmooseantler' } },
  ```
- `Config.Labels` - the item names shown to the player in the "you got" message.

Every item must exist in the database `items` table (see the two install files).

### locale/en.lua

Player-facing texts. Keep the `%s` placeholders. `tooFar`, `wrongAnimal`, `notDead`, `tooMany` and `notAllowed` are only shown when `Config.Messages.distinctRefusals = true`.

## For developers

Server exports:

- `exports.skinanimals:IsCarcassSkinned(netId)`: `true` when the carcass has already been paid out.
- `exports.skinanimals:MarkCarcassSkinned(netId)`: records the carcass as paid out and sets its `skinned` state bag.

The `skinned` entity state bag (`true` means paid out) is shared with pup_camps.

Network events: `skinanimals:claim` (client to server: row index, net id), `skinanimals:claimDone` and `skinanimals:notify` (server to client). The row index counts through `Config.Legendaries`, then `Config.Fish`, then `Config.Animals`.

## License

See LICENSE.
