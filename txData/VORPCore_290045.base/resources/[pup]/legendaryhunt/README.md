# legendaryhunt

Baited hunting traps that call legendary animals, for RedM / VORP. Set a trap on a hunting ground, put in the lure a legendary there wants and wait for the right hour. A Fur Buyer NPC sells traps and plant lures, and pays for legendary hides, pelts, antlers and horns.

## Features

- **Take a trap out:** use a Hunting Trap (`beartrap`) from the satchel with no weapon drawn. You hold it, and a faint copy on the ground shows where it will land. **Set Down** puts it down (not in water); **Pack Up** returns it to the satchel.
- **Lure it:** stand by your trap and pick a lure. One lure per trap, and it is used up when a legendary comes.
- **Arm it:** opens or shuts the trap. The label over the trap shows the lure and the hunting ground.
- **Hunting grounds:** each ground (a map district or region) has one or more legendaries. Which one answers depends on the lure and the in-game hour; a ground can hold a day beast and a night beast on the same lure.
- **Wait:** once the trap is open on a ground with a legendary for that lure and hour, the call goes out after 30 seconds and the animal appears about 9.5 minutes later (shorter with the pup-perks call-speed perk). It turns up 50 to 80 metres away, a blip marks the spot for a minute, and it walks towards the trap.
- **Cooldowns:** once a legendary is out, that legendary (for everyone) and that character both rest for 120 minutes. Right after you lure a trap, a tip tells you if what it would call is resting.
- **Take the trap back** at any time. A call that has not yet produced an animal is dropped; an animal already out stays out.
- **Fur Buyer:** stands at his post (map blip "Fur Buyer"), sells traps, salt, corn, wild carrots and honeycomb, and buys legendary trophies in eight groups.
- **Discord log** when a hunt starts.
- **Server checks:** shop actions only within 10 m of the Fur Buyer, with lists and prices from the server's copy (a purchase is refunded if the item cannot be added). Only configured lures are accepted. A trap only comes back if the server saw it leave that character's satchel. A trap that was out when its hunter left, switched character or the resource stopped is owed to that character and handed back automatically next time (kept across restarts in resource KVP). Only a spawn-time approval can start a cooldown or a log line, each approval works once, and a check that comes sooner than the call and activation waits allow is refused.

The animal itself is made by the hunter's game client; the server controls the cooldowns and the log. Cooldowns are kept in server memory and clear on restart. A character's cooldown follows the character, not the connection.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `pup-ui` (list menus)
- `skinanimals` (optional, but it is what hands out the legendary trophies when a legendary is skinned)
- `pup-perks` (optional; shorter waits with the `legendary_call_speed` perk)
- `pup-misc` (optional; Eco Boost extra on Fur Buyer sales)

## Installation

1. Put `legendaryhunt` in your resources folder.
2. Run `sql/install.sql` once. It only adds item rows that are missing (the trap, trap oil, the lures and every legendary trophy) and creates no tables. Other resources use the same item ids, so do not rename them. vorp_inventory caches items, so restart the whole server afterwards.
3. Add inventory images for the items if your inventory does not already have them.
4. For the hunt log, set `HuntSecrets.hunts` to a Discord webhook URL in `server/config.lua` (server only; `""` = no log).
5. Ensure it after its requirements:
   ```
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure legendaryhunt
   ```

## Commands

None. Everything is done with the trap item, the trap prompts and the Fur Buyer.

## Configuration

### config/main.lua

Loaded first: it creates the global `Config` table that the other config files fill in.

- `Config.Items.trap` - the trap item. `Config.Items.oil` - trap oil; the item stays for existing satchels, no feature uses it.
- `Config.Lures` - lures in menu order. Only these item names can go into a trap; the label is shown on the trap. Each entry: `{ item = 'salt', label = 'Salt lick' }`.
- `Config.Keys` - control hashes: `shop` (G, talk to the Fur Buyer), `place` (ENTER, put the held trap down), `putAway`, `take`, `lure`, `activate` (ENTER, open or shut the placed trap).
- `Config.Integrations` - `perks` / `perkKey` (perk that shortens the trap waits), `ecoBoost` / `ecoBoostPlace` (resource paying the Eco Boost extra on sales, and the place name sent to it; it must contain "Trapper" for pup-misc to count it).
- `Config.Hunt`
  - `legendaryHealth` - health of a spawned legendary.
  - `cooldownMinutes` - real minutes, per legendary (everyone) and per hunter (character).
  - `callSeconds` - seconds from an open, lured trap with a matching beast until the call.
  - `activateSeconds` - seconds after the call until the legendary appears.
  - `spawnMin` / `spawnMax` - metres added on X and on Y, picked at random between these.
  - `alertSprite` / `alertModifier` / `alertSeconds` - the spawn blip's sprite, colour modifier and how many seconds it stays.
  - `wanderFirstMs`, `reachTrapMetres`, `roamRadius` - how the legendary wanders, when it starts roaming round the trap and how far.
  - `replyTimeoutMs` - ms the client waits for the server's cooldown answer.
  - `serverMinWait` - the server refuses a spawn check that comes sooner after the trap left the satchel than the call plus activation wait allows (perk-scaled, 10% margin). `false` turns this guard off.
  - `fighters` - ped models that get combat attributes 5 and 58.
- `Config.Trap` - the trap prop, its open and shut animations, where it sits in the hand, the placement ghost, `useRange` (metres) and the place, pick-up and lure animations (`ms` = duration in ms).
- `Config.Trapper` - the Fur Buyer NPC: `model`, `coords` (vector4 with heading), `name`, `showBlip`, `blipSprite`, `useRange` and `serverRange` (metres).
- `Config.Discord` - `avatar` and `rateLimitSeconds`.
- `Config.Options.tellWhyNothingComes` - `true` = arming a trap tells the hunter when the ground, lure or hour cannot call anything.
- `Config.LocaleOverrides` - replaces lines of `config/locale.lua` without editing that file.
- `Config.Text` - extra player text that is not in `config/locale.lua`.

### config/animals.lua

Every legendary a trap can call, keyed by beast id. The names, models and outfit presets are the game's own legendaries.

```lua
[52] = { name = "Legendary Snowflake Moose", model = `mp_a_c_moose_01`, outfit = 1, lure = 'Wild_Carrot', hours = { 4, 12 } },
```

- `name` - shown on the alert blip and in the Discord log.
- `model`, `outfit` - ped model and outfit preset index.
- `lure` - the item from `Config.Lures` that calls it.
- `hours` - `{ from, to }` in-game hours, `from <= hour < to`. When `from` is bigger than `to` the window runs past midnight (`{ 20, 6 }` = 20:00 to 06:00). `{ 0, 24 }` = any hour.

### config/grounds.lua

Where a trap stands decides which legendaries can come. The game is asked for the area, district and region at the trap, in that order, and the first one listed here wins, so a district beats the region around it.

```lua
{ zone = 'P_4_LAKE_ISABELLA', label = 'Lake Isabella', beasts = { 52, 33 } },
```

- `zone` - the game's zone name (the hash is worked out from it).
- `label` - shown on the trap and in the log.
- `beasts` - beast ids. The first one whose lure and hours fit answers the trap. A beast may roam several grounds.

### config/shop.lua

- `buy.rows` - what the Fur Buyer sells: `{ item, label, price }`.
- `sell.groups` - what he pays for, as `{ label = 'Bears', rows = { { item, label, price }, ... } }`. Every group shows, in the order written.
- Prices are dollars and are checked again on the server.

### config/locale.lua

Player-facing text. Change the wording freely; keep the keys and any `%d` / `%s` placeholders.

## For developers

No exports or events for other resources. It listens to pup-ui's list menu events and sends `vorp:TipRight` / `vorp:TipBottom` tips.

## License

See LICENSE.
