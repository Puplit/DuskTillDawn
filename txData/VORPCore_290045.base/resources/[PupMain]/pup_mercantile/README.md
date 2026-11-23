# pup_mercantile

Stores for a RedM server running VORP: fixed NPC stores, shops that players own, and shops that businesses own. All buying and selling happens in vorp_inventory's store grid, and owners run their shop from a management dashboard.

## Features

- **NPC stores** set up in `config/stores.lua`. Their stock never runs out. Players buy from the store's sell list and sell to its buy list. A store can be limited to certain jobs, hidden from the map, or gated by another resource.
- **Player shops**, opened by using the `shoptoken` licence. Each shop has its own stock, buy orders, cash ledger, tax ledger, slot capacity, name, blip and position, plus one optional manager.
- **Society shops**, opened by a business boss using the `societytoken` licence. Staff at or above the shop's rank can manage it. Money goes through the business ledger in pup_business. By default every shop of one business shares one stock pool.
- **Management dashboard** (pup-ui app panel) for owners and managers: deposit and withdraw cash, pay into the tax ledger, buy extra slots, set buy orders, set the manager or the rank that may manage, attach a Discord webhook, rename the shop and turn its blip on or off.
- **Grid tools** for owners: stock goods from your inventory, set prices, put rows on or off sale, and change the order rows appear in.
- **Paid move**: an owner pays a fee from the dashboard, walks to the new spot and confirms with `/moveshop`.
- **Tax and repossession**: player shops pay a tax monthly or on set days. Owners get a warning by mail and tip beforehand. A shop that cannot pay is repossessed.
- **Item condition**: stores refuse items whose condition is below a set minimum.
- **Box trade** (with pup-misc): sell the contents of a carried box or pack, buy straight into one, or tip a box onto your own shelves.
- **Law raids** (with pup-mdt): an on-duty lawman of high enough rank holds a key at a player shop's counter to seize contraband that is on sale into the evidence locker.
- **Staff tools**: admin commands, a vorp_admin panel for player shops (including opening any shop's grid with the owner's controls), and pup_business exports for society shops.
- **Discord logs**: a staff log for every store event, and optional per-shop webhooks for owners.
- **Eco Boost** (with pup-misc): adds a bonus to NPC store sales while a boost is active.

## Requirements

- vorp_core
- vorp_inventory, with the store grid this resource opens (`vorp_inventory:OpenStoreInventory` / `ReloadStoreInventory`)
- oxmysql
- pup-ui
- OneSync, for server-side player positions
- Optional: pup-misc (boxes, packs, Eco Boost)
- Optional: pup_postoffice (tax and repossession letters, raid letters)
- Optional: pup_business (society ledger and boss ranks; needed for society shops to pay out)
- Optional: pup-mdt (law raids)
- Optional: pup_robbery (The Fence)
- Optional: vorp_admin (staff shop panel)
- Optional: pup-scene (blocks shopping during scenes)

## Installation

1. Put the `pup_mercantile` folder in your resources.
2. Database: the tables are created and upgraded automatically at start. You can also run `sql/install.sql` by hand (safe to run more than once). It creates `playershops`, `society_shops` and `cron_state`, adds a `discordid` column to `characters`, and adds the store goods and the two licence items (`shoptoken`, `societytoken`) to the `items` table.
3. In `server.cfg`, `ensure pup_mercantile` after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure pup_mercantile
   ```
   Start the optional resources before it too, if you use them.
4. Items: make sure `shoptoken` and `societytoken` exist in your `items` table (the SQL adds them) and give them inventory images in vorp_inventory. Every item listed in `config/stores.lua` must also exist in the `items` table.
5. Staff log (optional): set your Discord webhook URL in `webhooks.admin` in `server/config.lua` (server only, never sent to clients). An empty value turns the staff log off.

## Commands

Command names can be changed in `Config.Commands`.

| Command | Who | What |
|---|---|---|
| `/moveshop` | shop owner or manager during a paid move | place the shop where you stand; `/moveshop cancel` gives up the move |
| `/adminmoveshop <id> <x> <y> <z>` | admin or server console | move a player shop (ignores the spacing rule) |
| `/reposhop <id>` | admin or server console | repossess a player shop |
| `/unreposhop <id>` | admin or server console | give a repossessed shop back |
| `/delshop <id> [player\|society]` | admin or server console | delete a shop permanently; without a kind it looks for a player shop first, then a society shop |

Shops are opened by **using** the `shoptoken` or `societytoken` item, not by a command.

## Configuration

### config/main.lua

**General**

| Setting | Meaning |
|---|---|
| `Config.Debug` | Print debug lines to the server console. |
| `Config.InteractKey` | Key hash for the counter prompt. `0x760A9C6F` is G. |
| `Config.PriceColour` | Colour of the price line in the store grid. |
| `Config.ServerSlack` | Metres the server allows beyond the prompt distance before it refuses a request. |
| `Config.Blacklist` | Item names that can never be stocked or bought in by player and society shops, and are hidden from the Add Items tab. |
| `Config.BlipScale` | Size of shop blips on the map. |

**Config.NpcStores**

| Field | Meaning |
|---|---|
| `promptDistance` | Metres from a store's `Pos` at which the prompt shows. The server allows this plus `Config.ServerSlack`. |
| `shownStock` | Stock figure shown for NPC items (they never run out). |

**Config.Shops** (player and society shops)

| Field | Meaning |
|---|---|
| `promptDistance` | Metres from the shop at which the prompt shows. |
| `boxReach` | Metres: a box trade must happen this close to a player or society shop. |
| `minSpacing` | Metres: new and moved shops must keep this far from every other shop. |
| `pricePerSlot` | Dollars per extra slot bought from the dashboard. |
| `movePrice` | Dollars for a paid move. |
| `ownerWebhooks` | `true` lets owners and managers attach their own Discord webhook. |

**Config.PlayerShops**

| Field | Meaning |
|---|---|
| `maxPerPlayer` | Shops one character may own. Admins are exempt; repossessed shops still count. |
| `token` | Item name of the licence that opens a player shop. |
| `startSlots` | Slot capacity of a new shop (in item units). |
| `blipSprite` | Blip icon hash. |

**Config.SocietyShops**

| Field | Meaning |
|---|---|
| `enabled` | `false` turns off creating society shops. |
| `maxPerBusiness` | Shops one business (job) may have. |
| `token` | Item name of the licence that opens a society shop. Only a boss of the business can use it. |
| `startSlots` | Slot capacity of a new shop. |
| `blipSprite` | Blip icon hash. |
| `sharedStock` | `true`: every shop of one business shares one stock pool (stock, buy orders and slots). |
| `separateStock` | Job names that keep a separate pool per shop even when `sharedStock` is on, e.g. `{ 'blacksmith' }`. |

**Config.Decay**

| Field | Meaning |
|---|---|
| `enabled` | Check item condition before a store takes an item. |
| `minimum` | Percent condition an item needs before a store takes it. |

**Config.Tax** (player shops only)

| Field | Meaning |
|---|---|
| `amount` | Dollars taken from the tax ledger each period. The tax ledger can never hold more than this. |
| `monthly` | `{ enabled, day, hour, minute }`: collect once a month on that day of the month at that server time. |
| `weekly` | `{ enabled, days, hour, minute }`: used only when `monthly` is off. `days` are days of the **month** (e.g. `{ 3, 10, 17, 24 }`), not weekdays. |
| `warnMinutes` | Minutes before collection that owners who are short get a letter and a tip. |
| `checkEvery` | Seconds between schedule checks. |
| `mailFrom` | Sender name on tax letters. |

Collection is recorded in the `cron_state` table before it runs, so a restart cannot collect twice on the same day. A shop whose tax ledger holds less than `amount` is repossessed: it closes, disappears from the map and its owner gets a letter. Staff can give it back with `/unreposhop`.

**Config.Logs**

| Field | Meaning |
|---|---|
| `avatar` | Avatar URL for the Discord embeds; empty uses the Discord default. |
| `poster` | Name the embeds are posted under. |

**Config.Commands**: the command names (`move`, `adminMove`, `repo`, `unrepo`, `delete`).

**Config.Shopkeepers**: optional NPC shopkeepers. Each spawns only while a player is within its radius, and is removed when they move away. Example entry:

```lua
Config.Shopkeepers = {
    { model = 'u_m_m_sdtrapper_01', pos = vector3(0.0, 0.0, 0.0), heading = 0.0, radius = 60.0, snapToGround = true },
}
```

`radius` is in metres (default 60). `snapToGround = true` places the ped on the ground below `pos`.

**Config.V1SocietyShops**: a one-time import of society shops from an older setup. At start each entry is inserted unless a shop with that society and name already exists. Example entry:

```lua
Config.V1SocietyShops = {
    { job = 'blacksmith', name = 'Forge Counter', pos = { x = 0.0, y = 0.0, z = 0.0 }, rank = 0, blip = 1 },
}
```

`rank` is the lowest job grade that may manage the shop; `blip = 1` shows it on the map.

**Config.Misc** (pup-misc integration: boxes, packs and Eco Boost)

`resource` is the pup-misc resource name. `exports` holds the export names this resource calls; change them only if pup-misc names its exports differently. Every box export takes the carried box's **inventory item id**, not its box id.

| Key | Default export | Arguments, and what it returns |
|---|---|---|
| `ecoBonus` | `ApplyEcoBoostSale` | `(src, storeName, total)`: bonus dollars, recorded as earned. Called once per paid NPC sale. |
| `ecoMultiplier` | `EcoBoostMultiplierFor` | `(src, storeName)`: the multiplier, `1` = none. |
| `boxNames` | `BoxItemNames` | `()`: `{ [itemName] = 'box' \| 'pack' }`. |
| `boxContents` | `BoxContents` | `(src, itemId)`: array of `{ craftedId, name, label, amount, percentage, metadata }`, or nil. |
| `boxTake` | `BoxTake` | `(src, itemId, craftedId, amount)`: boolean. |
| `boxPut` | `BoxPut` | `(src, itemId, name, amount, metadata)`: units that landed. |
| `boxFree` | `BoxSpace` | `(src, itemId)`: units that still fit. |
| `boxConsume` | `BoxConsumeIfEmpty` | `(src, itemId)`: true when the box was removed (job packs are kept). |

`fallbackBoxNames` is the list of box and pack item names used until pup-misc answers with its own list. `packCheckTimeout` is in milliseconds.

**Config.Raid** (law raids on player shops, with pup-mdt)

Who may raid comes from pup-mdt: one of its law jobs, on duty. What is seized is pup-mdt's contraband list, and it goes into the pup-mdt evidence locker. Only rows that are **on sale** are looked at; shelved rows and weapons are never touched or mentioned to the lawman.

| Field | Meaning |
|---|---|
| `enabled` | Turn raids on or off. |
| `minGrade` | Lowest law job grade that may raid. |
| `cooldownMinutes` | Minutes before the same shop can be raided again. A raid the locker refused does not start the cooldown. |
| `lawmanSeconds` | Seconds: one raid request per lawman this often. |
| `key` | Key hash held at the counter. `0xE30CD707` is R. |
| `holdMs` | Milliseconds the key must be held. |
| `mdtResource` | The pup-mdt resource name. |
| `mailFrom` | Sender name on raid letters. |

**Config.Admin**: `resource` is the vorp_admin resource name, `permission` is the vorp_admin permission key (`manage_stores`) that is checked again here before staff open a shop's grid.

**Config.Integrations**: resource names of pup_postoffice (`postoffice`) and pup_business (`business`).

### config/stores.lua

The NPC stores. They always exist and their stock never runs out. Player and society shops are not set up here. The file has three tables; `shared/stores.lua` joins them into the store list at start.

**Config.StoreGoods**: every item an NPC store deals in, priced once.

```lua
Config.StoreGoods = {
    water = { 'Water', 1 },                  -- item name = { label shown, price in dollars }
    Fat = { 'Animal Fat', 1 },
    WEAPON_LASSO = { 'Lasso', 5, weapon = true },
}
```

- The item name is the one in the `items` table; for a weapon it is the weapon name and the row needs `weapon = true`.
- Prices are rounded to cents (`0.25` = 25 cents). A store charges this price for what it sells and pays it for what it buys.
- Stores can sell weapons but never buy them from players.

**Config.StoreKinds**: one entry per kind of store (`general`, `farmers`, `mining`, `bait`, `trapper`, `fence`).

```lua
general = {
    blip = 1475879922,                      -- map icon hash
    sells = { 'water', 'campfire' },        -- what players can BUY here
    buys = { 'legbisonhorn' },              -- what players can SELL here
},
```

- Names in `sells` / `buys` must be in `Config.StoreGoods`; one that is not is skipped with a console warning.
- The store window lists them in the order written.
- `buys` rows are only shown when the player carries that item.

**Config.StoreSites**: one row per store. To remove every NPC store, empty this table.

```lua
{ name = 'Valentine General Store', kind = 'general', at = { -325.55, 797.51, 117.73 } },
```

| Field | Meaning |
|---|---|
| `name` | Blip and window title. Must be unique: other resources find stores by their name. |
| `kind` | A key of `Config.StoreKinds`. |
| `at` | `{ x, y, z }` where the prompt appears. The radius is `Config.NpcStores.promptDistance`. |
| `blip = false` | No map icon. `blip = <hash>` uses another icon than the kind's. |
| `jobs = { 'police', 'doctor' }` | Only those jobs may shop here. Leave it out for everyone. |
| `prices = { water = 2 }` | Prices for this store only, by item name. |
| `menuOnly = true` | No walk-up prompt; another resource opens the store from its own menu. |
| `gate = { resource = '...', export = '...' }` | That server export is called with the player's source and decides who may shop here (it must return `true`). |

The last row, **The Fence**, is used by pup_robbery. It has no prompt or blip and is opened from pup_robbery's own menu, which also sets its position and stock (`Config.Fence.stall` in pup_robbery's `config/fence.lua`), so its kind has empty lists. Its `name` must match `Config.Fence.stall.storeName` in pup_robbery.

### config/weaponlabels.lua

Display names for weapons in shop menus and logs. The key is the weapon name, the value is the label shown. The labels are the in-game weapon names, written for this server.

### config/locale.lua

Every sentence a player, the console or a log can see. `%s` and `%d` are filled in by the code; keep them in the same order when you translate.

### server/config.lua

Server-only settings. `webhooks.admin` is the Discord webhook URL for the staff log (every store event lands there). An empty value turns the staff log off.

## For developers

### Server exports

**pup_robbery (The Fence).** Changes last until the next restart.

| Export | Arguments | Returns |
|---|---|---|
| `SetStorePos` | `storeName, pos {x, y, z}` | boolean |
| `SetStoreStock` | `storeName, sellList or nil, buyList or nil` (arrays of store item rows) | boolean |

**pup-misc (stock from a container).**

| Export | Arguments | Returns |
|---|---|---|
| `StockFromContainer` | `src, rows` (array of `{ name, amount or count, metadata, label, type }`) | `{ ok = true, merged, shelved, moved }` or `{ ok = false, reason }`, where reason is `nochar`, `noshop`, `notowner`, `empty`, `weapon`, `blacklisted` or `full` |

The player must be at their own shop (owner or manager). Rows that match an existing stock row are added to it; new rows go onto the shelf, off sale, waiting for a price.

**pup_business (society shops).**

| Export | Arguments | Returns |
|---|---|---|
| `RefreshSocietyBossRanks` | none | nothing |
| `AdminListSocietyShops` | `job` or nil for all | array of `{ id, society, name, coords, rank, blip, slots, level, enabled, items, weapons }` sorted by id (nil while loading) |
| `AdminSetSocietyShopEnabled` | `id, on` | boolean |
| `AdminRenameSocietyShop` | `id, name` | boolean |
| `AdminSetSocietyShopRank` | `id, rank` (0 to 100; 0 = every employee may manage) | boolean |
| `AdminSetSocietyShopSlots` | `id, slots` (1 to 1,000,000; shared by the whole pool) | boolean, applied slot count |
| `AdminSetSocietyShopBlip` | `id, on` | boolean |
| `AdminMoveSocietyShop` | `id, coords {x, y, z}` | boolean, reason (`noshop`, `badcoords`, `tooclose`) |
| `AdminDeleteSocietyShop` | `id` | boolean |
| `AdminClearSocietyShopStock` | `id` | boolean |

**vorp_admin (player shops).**

| Export | Arguments | Returns |
|---|---|---|
| `adminStoreList` | none | nil while loading, else `{ shops = [{ id, name, coords, slots, ledger, taxledger, level, blip, repo, charid, owner, discord, items, weapons }], stats = { total, active, repo, ledger, maxper } }` |
| `adminStoreStock` | `id` | nil, or `{ items = [{ name, label, count, price, forsale }], weapons = [{ name, label, serial, price, forsale }], buying = [{ name, price, amount }] }` |
| `adminStoreAction` | `id, action, value`; action is `repo`, `unrepo`, `rename`, `blip`, `move`, `slots` or `delete` | boolean, error text |
| `adminOpenStock` | `src, id` | boolean, error text. Opens the shop's real grid with the owner's controls for a staff member who holds the `Config.Admin.permission` key. |

### Client export

| Export | Arguments | Returns |
|---|---|---|
| `StoreIdByName` | `storeName` | index of the NPC store with that exact name, or nil |

### Events

Net events the store grid (vorp_inventory) sends to this resource: `pup_mercantile:MoveToStore`, `pup_mercantile:TakeFromStore`, `pup_mercantile:changeorder`, `pup_mercantile:togglesale`, `pup_mercantile:setprice`, `pup_mercantile:box:gridBuy`, `pup_mercantile:box:gridSell`. Every one is checked again on the server.

`pup_mercantile:reloadStoreInventory` (server, net): with an NPC store index the player is not looking at, opens that store through the normal NPC flow (distance, job and gate are checked again). For example pup_robbery opens The Fence with:

```lua
TriggerServerEvent('pup_mercantile:reloadStoreInventory', exports.pup_mercantile:StoreIdByName('The Fence'), {}, 0, {})
```

Without a new store index it redraws the grid the player has open.

`pup_mercantile:openStore` (client): opens an NPC store by index through the normal flow.

`pup_mercantile:setClosedInv` (client, local): vorp_inventory fires it with `true` when the store grid has opened.

Events this resource listens to from others: `vorp:SelectedCharacter`, `pup:closeinv` (vorp_inventory window closed), `pup-scene:stopscene` (`false` blocks shopping), and pup-ui's `pup-ui:client:inputDone`, `appNav`, `appAction` and `appClosed`.

### Database

- `playershops`: one row per player shop. `items`, `weapons` and `buyitems` are JSON arrays; `ledger` is the shop till, `taxledger` the tax savings, `level` the number of slot upgrades bought, `repo = 1` means repossessed, `manager` is the manager's character id (0 = none).
- `society_shops`: one row per society shop. `society` is the owning job, `rank` the lowest grade that may manage, `enabled = 0` hides and closes it. Shops of a sharing business all hold the same stock.
- `cron_state`: the row `stores` records the last tax collection day. The table is shared with other resources.
- `society_ledger` (owned by pup_business) holds whole dollars; cents from sales are carried in memory until they add up to a dollar.

## License

See LICENSE.
