# pup-perks

Character progression for RedM / VORP: two XP ladders (Honest Work and Outlaw), perk points and a deck of perk cards, shown on its own panel. Other resources award XP and read perk effects through exports.

## Features

- Two progressions that never mix: civ ("Honest Work") and crime ("Outlaw"), each with its own level, XP bar and point pool.
- Specialisation trees: a character commits to one tree per side; XP from that side's work feeds the committed tree.
- Perk cards with up to three ranks, level requirements, prerequisites and point costs.
- Cards are active as soon as they are bought, or (optionally) equipped into a loadout of one special and three passive slots.
- A free weekly respec (points back, trees kept), a paid full reset (ranks and both trees), and switching specialisation.
- An in-panel Guide whose numbers are filled in from the real settings.
- Admin bridge for vorp_admin's Perks page: list characters, view detail, grant or take points and XP, reset perks, online or offline.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup-ui` (toasts)
- `vorp_admin` (optional; its Perks page uses the admin exports)

## Installation

1. Run `sql/install.sql`. It creates `perks` (one row per character, created on first login). Newer columns are also added automatically at start, so it never has to be re-imported. No items are needed.
2. Add `ensure pup-perks` to `server.cfg` after `vorp_core`, `oxmysql` and `pup-ui`.

## Commands

| Command | Who | What |
|---|---|---|
| `/perks` | Anyone | Opens the perks panel (name set by `Config.General.command`) |

## Configuration

### config/main.lua

**Config.General**
- `debug`: trace XP, rank-ups, equips and effect rolls to the console. Keep it off on a live server.
- `command`: chat command that opens the perks panel; `false` or `''` disables it.

`Config.Keys` and `Config.Integrations` are empty: the panel is mouse-driven and there is nothing to configure for integrations.

**Config.Progression** (levels and perk points, counted separately on each side)
- `requireLevels`: `true` = each perk rank needs its character level; `false` = levels only hand out points.
- `pointsPerLevel`: perk points per level gained, per side (level 1 included).
- `bonusPoints`: extra points at these levels, on top of `pointsPerLevel`: `[level] = points`.
- `levelXp`: total XP needed to reach each level; the list length is the max level.

**Config.Cards** (how owned perks become active)
- `autoEquip`: `true` = every owned card is active, no loadout; `false` = cards must be equipped into slots.
- `maxLevel`: highest rank any card can reach, even if its rank list is longer.
- `loadout.special` / `loadout.passive`: loadout slots when `autoEquip = false` (signature cards with `slot = 'special'`, and every other card).

**Config.Reset** (respec)
- `enabled`: `false` disables both the paid full reset and the free weekly reset.
- `price`: dollars for the full reset (ranks + both trees). `0` = free.
- `freeCooldownSeconds`: wait between free weekly resets (ranks only, trees kept). Default 7 days.

### config/trees.lua

The perk trees (the panel's left sidebar) and what the two sides are called. A character commits to one civ tree and one crime tree; the other trees on that side stay visible but cannot be bought from. A `side = 'both'` tree is always open.

- `sideLabels`: what each side is called in the panel, toasts and level-up tips.
- `list`: the trees, in sidebar order.

| Field | Meaning |
|---|---|
| `key` | Tree id. Stored in `perks` (`civtree` / `crimetree` / `treexp`): never rename one |
| `label` | Name shown in the panel |
| `glyph` | pup-ui icon name |
| `side` | `'civ'`, `'crime'` or `'both'` (always open, no commitment) |
| `desc` | One-line pitch shown on the tree |

A tree with no perks in `config/perks.lua` is hidden automatically. Example:

```lua
{ key = 'hunting', label = 'Hunting', glyph = 'paw', side = 'civ', desc = '...' },
```

### config/xp.lua

How much XP each activity pays, and to which side. Other resources call `exports['pup-perks']:Award(source, '<kind>')`; the key is that kind, so never rename one (the calling resource has it hard-coded).

| Field | Meaning |
|---|---|
| `track` | `'civ'`, `'crime'` or `'both'` |
| `min` / `max` | Lowest / highest XP rolled per action (or a flat `xp = N` instead) |
| `split` | `track = 'both'` only: `true` halves the roll between the two sides (an odd spare point goes to crime); `false` pays the full roll to each side |

XP always lands in the tree the character committed to on that side. Example:

```lua
skin = { track = 'civ', min = 4, max = 9 },
```

If you add or move an XP source, update the "Earning Experience" section in `config/guide.lua` too.

### config/perks.lua

The perk deck: every card, its ranks, costs and the effect other resources read. Panel order = list order.

| Field | Meaning |
|---|---|
| `id` | Perk id. Stored in `perks.ranks` / `equipped`: never rename one |
| `cat` | Tree key from `config/trees.lua` |
| `side` | Only for cards in a `side = 'both'` tree: `'civ'` or `'crime'` (which pool pays) |
| `slot` | `'special'` marks a signature card (`Config.Cards.loadout.special`); default passive |
| `glyph` | pup-ui icon name |
| `req` | Character level (on the card's side) needed for rank 1 |
| `name` / `desc` | Card title / flavour text |
| `effect` | `{ key = '<effect key>' }`: the key other resources ask about through the `Roll` / `Mult` / `Bonus` / `Has` / `Timed` exports. Never rename one |
| `requires` | Optional `{ perk = '<id>', rank = N }` prerequisite |
| `ranks` | One row per rank (capped at `Config.Cards.maxLevel`) |

Each rank: `cost` (perk points for this rank), `req` (level for this rank, default the card's `req`), `text` (what this rank gives, shown in the panel), and one of `chance` (0-100, highest wins), `mult` (1.0 = normal, multiplied together) or `add` (summed).

Example:

```lua
{ id = 'skinner', cat = 'hunting', glyph = 'paw', req = 1,
  name = 'Practiced Hand', desc = '...', effect = { key = 'skin_double' },
  ranks = { { cost = 1, text = '5% chance of double items', chance = 5 } } },
```

Effect keys and the resources that read them:

| Effect keys | Read by |
|---|---|
| `skin_double`, `skin_legendary_double` | skinanimals |
| `legendary_call_speed` | legendaryhunt (Mult on the trap wait) |
| `bird_xp` | huntingbirds |
| `farm_bonus`, `farm_speed`, `farm_water_radius`, `farm_limit` (and `farm_fert_radius`, no card) | pup_homestead (stacks with its job bonus) |
| `dig_speed` | gravedigging, pup_mortician |
| `pan_luck` | goldpan (added to the 1-100 roll) |
| `gather_yield` | miner_lumber |
| `ranch_bonus` | pup_ranchero |
| `craft_double` | pup_workbench |
| `robbery_double`, `robbery_cooldown`, `solo_robbery`, `robbery_cash`, `fence_cut`, `fence_word`, `fence_next` | pup_robbery |
| `underground_bonus`, `still_yield`, `cook_speed`, `underground_speed`, `drug_payout`, `sale_quiet`, `sale_scam` | pup_hideouts |
| `clan_supply_bonus`, `clan_sale_bonus` | pup_camps |
| `civ_xp`, `crime_xp` | pup-perks itself (XP multiplier) |

Tuning notes:
- `legendary_call_speed`: the stock wait is 10 minutes (legendaryhunt call 30 s + activation 570 s).
- `farm_speed`: multiplies with the pup_homestead farmer job bonus.
- `farm_water_radius`: the better of the perk and job radius is used; it does not stack.
- `farm_limit`: adds to the pup_homestead job bonus limits.
- `farm_fert_radius`: no card on purpose (radius fertilising is a farmer job perk, pup_homestead `Config.JobBonus.fertRadius`). The farming code still reads this key, so a card can be added.
- `pan_luck`: added to goldpan's 1-100 roll (shrinks the 50% "nothing" band).
- `fence_cut`: multiplies what the fence pays (pup_robbery cut 0.70: 1.10 -> 0.77).
- `fence_word`: added to pup_robbery's fence tip chance; rank 3 names the landmark.
- `fence_next`: rolled by pup_robbery after a sale at the fence.
- `sale_quiet`: percentage points off pup_hideouts' sale report chance.
- `drug_payout`: the drug price list stays a hard ceiling.
- `sale_scam`: added to pup_hideouts' haggling tolerance. A total that clamps it to 1.0 makes every ask a guaranteed yes, so keep it small.

### config/guide.lua

The Guide panel players read inside the perks menu. Change the wording freely. These placeholders are filled in from the real settings, so the guide cannot fall out of step:

| Placeholder | Value | From |
|---|---|---|
| `{pointsPerLevel}` | Points per level | `Config.Progression.pointsPerLevel` |
| `{bonusLevels}` | Levels with extra points | `Config.Progression.bonusPoints` |
| `{maxLevel}` | Highest level | `Config.Progression.levelXp` |
| `{maxRank}` | Highest perk rank | `Config.Cards.maxLevel` |
| `{resetDays}` | Days between free resets | `Config.Reset.freeCooldownSeconds` |
| `{resetPrice}` | Full reset price | `Config.Reset.price` |

A section can have any of: `text` (paragraphs), `steps` (a numbered list), `list` (rows of `{ label, text }`) and `resets` (the three ways to start over, with their buttons).

### config/locale.lua

Every player-facing message. `%s` / `%d` are filled in by the code: keep them, in order.

## For developers

Server exports (`exports['pup-perks']:...`):

| Export | What |
|---|---|
| `Award(source, kind)` | Pays the XP for an activity from `config/xp.lua` |
| `AddXP(source, track, amount)` | Adds a raw XP amount on `'civ'` or `'crime'` |
| `Roll(source, key)` | `true` if the effect's chance hits |
| `Has(source, key)` | `true` if the effect is active |
| `Mult(source, key)` | Multiplier, `1.0` when not active |
| `Bonus(source, key)` | Added amount, `0` when not active |
| `GetLevel(source, side?)` | The better side's level, or that side's specialist level |
| `GetTree(source, side)` | The committed tree key on that side, or `nil` |
| `GetXP(source, track?)` | XP on a side, or the total |
| `GetRank(source, perkId)` | The rank a perk sits at (0 = not owned) |
| `adminPerkList(search)` | Characters that have earned anything, newest activity first |
| `adminPerkGet(charid)` | Full detail for one character |
| `adminAdjustPoints(charid, side, delta)` | Grant or take perk points on one side |
| `adminAddXP(charid, track, amount)` | Grant XP on a track (also into the committed tree) |
| `adminResetPerks(charid)` | Wipe every rank, equip and both tree choices |

Client exports: `Roll(key)`, `Has(key)`, `Mult(key)`, `Bonus(key)`, `Timed(ms, key?)` (returns the perk-adjusted duration; with no key it uses `dig_speed` and `underground_speed`) and `OpenPanel()`.

Client events: `pup-perks:toast (title, msg, tone)` shows a toast through pup-ui. The panel closes on `pup-ui:HideAllUI`.

## Credits

The UI textures in `html/img/western/` are Red Dead Redemption 2 art © Rockstar Games, taken from Rexshack-RedM's ox_lib build. `inkroller_1a.png` is an edited version. They are not covered by this resource's licence.

## License

See LICENSE.
