# pup_realestate

Player housing for a RedM / VORP server: houses with real game doors, marker houses and teleporter interiors, motel rooms, furniture, stashes, wardrobes, ledgers, tax and town hall auctions.

## Features

- **Houses** of three kinds:
  - real-door houses, whose own game doors lock and unlock;
  - marker houses, where a spot acts as the front door;
  - teleporter houses, a private copy of a configured interior that visitors knock to enter.
- **Motel rooms:** bought once at a motel entrance. Each room is a private copy of one shared room with its own stash and wardrobe.
- **Per house:** a money ledger, a tax ledger, an optional Discord log for the owner, furniture placed from inventory items (or bought with cash), a vorp_inventory stash, storage upgrades paid in materials, and a wardrobe spot for saved outfits.
- **Keys:** owners give keys to other characters; switches decide what keyholders may do.
- **Viewings:** a house for sale can be viewed for a short time before buying.
- **Sold Home Ledger:** sellers collect their share of a sale at a ledger point.
- **Tax:** collected on configured days. Owners who cannot cover it get a letter beforehand; houses that cannot pay are repossessed and put back on sale.
- **Auctions:** staff start an auction on an unowned house; players bid at the town hall from a bank branch. Bids are held in escrow and outbid players are refunded at once.
- **Admin bridge:** vorp_admin's Housing page uses this resource's server exports and opens the in-world house creator.
- **Relog safety:** a player who logs out inside an interior comes back outside (or at the house door).

There are no chat commands.

## Requirements

- `oxmysql`
- `vorp_core`
- `vorp_inventory`
- `pup-ui`
- Optional:
  - `pup_business` (realtor share of sales)
  - `pup-bank` (bank branches for auction bids)
  - `pup_postoffice` tables (letters)
  - `pup_hideouts` (last outdoor spot)
  - `weathersync` (fixed weather inside interiors)
  - `vorp_lib` (furniture placement gizmo)
  - `doorlocks` (bridge for real doors, off by default)
  - `pup-scene`, `pup-stable`, `fred_meta`
  - `vorp_admin` (Housing page, creator, auctions)

## Installation

1. Put `pup_realestate` in your resources folder.
2. Run `sql/install.sql` (safe to run more than once). It creates `playerhousing`, `playerhousing_sold_home_ledger`, `housing_activity`, `housing_auctions`, `housing_auction_bids` and `cron_state`, adds `characters.motel`, and inserts the furniture and material items with `INSERT IGNORE`. The server also adds `characters.motel`, `cron_state` and `housing_auctions.topbank` at start if they are missing.
3. Add images for the furniture and material items to `vorp_inventory/html/img/items/` if you do not have them.
4. Set `Webhooks.admin` to a staff Discord webhook (house sales, ledgers, keys, tax, auctions, admin panel) in `server/config.lua` (server only, never sent to players). Empty = no staff log.
5. Add `ensure pup_realestate` to `server.cfg` after its requirements (and after `doorlocks` if you use the bridge).
6. Set `Config.Debug = false` on a live server.

## Setting it up in game

Houses are created and run from vorp_admin's **Housing** page. Open the admin panel with PageDown or
`/adminMenu` (vorp_admin's `Config.Menu.command`), then click **Housing** in the side bar.

### Permissions

pup_realestate and vorp_admin check every action again on the server.

| Step | vorp_admin key | Discord name (`config/discord.lua`) |
|---|---|---|
| Open the admin panel | `open_menu` | `menu.open` |
| See the Housing page, **Create House**, Set Price, Set Tax, Set Furniture Range, Set Storage Slots, Open storage, Create Auction, Cancel Auction | `manage_housing` | `manage.housing` |
| Seize, Transfer To, Mark Repo / Clear Repo Flag, remove a keyholder, Delete House | `manage_housing` and `delete_housing` | `destroy.housing` |

With Discord permissions off, give a VORP group the keys in vorp_admin's `config/permissions.lua`, for example
`yourgroup = { actions = { open_menu = true, manage_housing = true } }`. The default `admin` group has every key;
`moderator` has neither housing key. The wildcard `manage.*` does not include `delete_housing`; name it on its own.

Who may **save** a new house (checked on the server): the VORP `admin` and `superadmin` groups, jobs in
`Config.Jobs.admin`, anyone with `manage_housing`, the realtor job `Config.Jobs.realtor`, and the jobs in
`Config.Jobs.auctionRealtors` when `Config.Jobs.realtorsMayCreate` is on. The creator itself only opens from the
Housing page's button, though, and there is no command for it, so in practice the person also needs the panel
and `manage_housing`.

### 1. Create a house

1. Go to the house. For a house with real doors, stand by its front door.
2. On the Housing page, click **Create House (starts the in-world door capture)**. The panel closes and the
   **Create House Menu** form opens:
   - **Price**: in dollars, above 0. The house is for sale at this price as soon as it is saved.
   - **Tax rate**: a dollar amount taken at every tax collection (not a percentage). 0 means no tax.
   - **Furniture range**: metres around the front door where furniture, the stash spot and the wardrobe spot
     may be placed. The default is 20. Inside a teleporter house, the interior's own `range` in
     `Config.Interiors` is used instead.
   - **Inventory space**: the storage size in slots, at least 1. `Config.MaxSlots` caps it when it is above 0.
   - **House type**: **Normal house (real doors)**, **No Door House** (a prompt spot acts as the front door) or
     **Teleporter House: *name*** (one entry per interior in `Config.Interiors`).
3. For a house with real doors, capture its doors:
   1. Look at the front door, within about `Config.Creator.probeDistance` metres past you, and press **G**. The
      first door you capture is the front door. A label over the door shows whether the creator knows it.
   2. For a double door, the creator tells you where the other half is. Look at it and press **G**.
   3. Look at every other outside door (back door, side door) and press **G** on each. Up to 16 extra doors.
   4. Press **ENTER** to go on, or **BACKSPACE** to cancel.

   You never type a door hash. The creator reads the door's model and position and looks the door up in the
   door list (`client/doors.lua`), within 2 metres. If it says the door "is not in the door list", that door
   cannot be used until you add it to the list or set `Config.Creator.findDoorHash` (see "Doors that are not in
   the door list" below).
4. Place the prompt spot, where players get the house's prompt. It starts at the front door (or where you
   stand, for the other two types). Arrow up and down raise and lower it; arrow left and right, **[** and **]**
   move it sideways. Each press moves it 0.1 m. Press **ENTER** to confirm.
5. The summary shows the type, price, tax, range, space and doors. **Add more doors** and **Move the prompt
   spot** go back a step. **SAVE HOUSE** saves after you confirm. You must be within 60 m of every door when you
   save.
6. You get "You created a house." The house's storage container (`house_<id>`) is made at once. With
   `Config.Rules.creatorIsSeller` on, you are its stored seller and collect `Config.Sale.sellerShare` of its first
   sale at a Sold Home Ledger point.

The **storage spot** and the **wardrobe spot** are not set in the creator. After the house is bought, the owner
(and keyholders, while `Config.Rules.keyholderSpots` is on) opens **Manage House** (at the door, or at the exit
point inside a teleporter house), then **Set Inventory
Location** or **Set Changing Room Location**, stands on the spot and presses **G**. The spot must be within the
house's furniture range of the front door, or inside its interior. Staff can open any house's storage from the
panel with **Open storage**, whether or not a spot is set.

**Furniture limits**: `Config.Furniture.maxPieces` pieces per house (the same for every house), placed within the
house's furniture range. Change one house's range with **Set Furniture Range** (capped at `Config.MaxRange`).

**Tax**: each house has its own amount (**Set Tax**). It is collected on the days set in `Config.Tax`, from the
tax ledger (or the main ledger when `Config.Ledger.taxLedger` is off). An owner who is short gets a letter and a
message one hour before collection. A house that cannot pay is repossessed: the owner and all keys are removed,
the repo flag is set and the house goes back on sale at its price. Its storage and furniture stay with it.

### 2. House blips

There is nothing to place: every house gets a blip at its front door on its own, and there are no per-house
blip settings.

- An unowned house shows **House For Sale** (sprite `Config.Blips.forSale`) to everyone while
  `Config.Blips.forSaleShown` is on.
- An owned house shows **My Home / ID:*id*** (sprite `Config.Blips.owned`) to its owner and keyholders only, and
  to the `Config.Jobs.realtor` job while `Config.Blips.realtorSeesAll` is on.
- The size is `Config.Blips.scale`. Colour cannot be set; the code only sets the sprite, size and name.
- Sold Home Ledger points (`Config.LedgerPoints`) and motels (`Config.Motels`) have their own blip sprite and
  name in config. Town halls have no blip.

A house blip follows the front door. To move it, delete the house and create it again.

### 3. Selling and auctions

- **For sale**: a new house is on the market at once. Players press **G** (Open) at the door and choose **Buy
  House** (cash) or **View Inside** (a short viewing). Change the price with **Set Price**. An unowned house at
  $0 is taken out of the game at the next restart; **Set Price** above $0 lists it again.
- **An owner selling**: **Manage House**, then **Sell House**. The house goes back on the market at its stored
  price and the owner becomes its seller. When someone buys it, the seller collects `Config.Sale.sellerShare` of
  the price at a Sold Home Ledger point, and `Config.Sale.societyShare` goes to the `Config.Sale.societyJob`
  business ledger (pup_business).
- **Taking a house back**: open it on the Housing page, type `SEIZE` and click **Seize (evict to market)**. It goes
  back on sale marked as repossessed, the same as a house taken for unpaid tax, so the next sale pays no seller
  or business share. Click **Clear Repo Flag** afterwards if the stored seller should be paid again.
- **Auction**: the house must be unowned (seize it first). Open it on the Housing page and, in the **Auction**
  card, type the minimum bid (above $0) and the hours (at most `Config.Auctions.maxHours`), then click **Create
  Auction**. While it runs, the house's **Buy House** menu says it is at auction and it cannot be bought.
  - Players bid at a town hall (`Config.TownHalls`, prompt **View Auctions**) from a pup-bank account. A bid
    must beat the last one by `Config.Auctions.minRaise`; with `Config.Auctions.sealed` on, bids are hidden.
    An outbid player is refunded at once.
  - When the time is up (checked every minute) the top bidder gets the house. If they already own
    `Config.MaxHousesPerCharacter` houses, the auction is voided and they are refunded.
  - **Cancel Auction** refunds the top bid.

### 4. Keys

- The owner gives keys from **Manage House**: **Give Keys**, then the **Player ID** (server id) of an
  online player. **Take Keys** lists the keyholders; pick one to take the key back. A house holds up to 50
  keyholders.
- Keyholders can open the house, lock and unlock real doors (**SHIFT** at a door, `Config.Keys.lock`; each door
  locks on its own), and use the stash and the wardrobe. `Config.Rules.keyholderFurniture`,
  `keyholderSpots`, `keyholderUpgrades` and `keyholderArrangeStash` decide whether they may also move
  furniture, move the spots, buy storage upgrades and rearrange the stash. The ledger, tax ledger, keys, house log
  and selling are owner only.
- All keys are cleared when the house is sold, seized, repossessed or transferred.
- Staff can remove a keyholder with **✕** next to their name on the house page.

### 5. Admin tools on the Housing page

Click a house in the list to open it.

| Button | What it does | Needs |
|---|---|---|
| **Create House** | opens the in-world creator (step 1) | `manage_housing` |
| **Set Price** / **Set Tax** | price and tax amount | `manage_housing` |
| **Set Furniture Range** | furniture range in metres, capped at `Config.MaxRange` | `manage_housing` |
| **Set Storage Slots** | storage size, capped by `Config.MaxSlots` when above 0; applies at once | `manage_housing` |
| **Open storage** | opens the house's real storage with the owner's controls, from anywhere; logged | `manage_housing` |
| **Create Auction** / **Cancel Auction** | see step 3 | `manage_housing` |
| **Mark Repo** / **Clear Repo Flag** | the repossessed flag; a house sold while flagged pays no seller or business share | `delete_housing` |
| **Transfer To** | gives the house to a character id; keys are cleared | `delete_housing` |
| **Seize (evict to market)** | removes the owner and marks the house repossessed; type `SEIZE` first | `delete_housing` |
| **✕** next to a keyholder | takes their key | `delete_housing` |
| **Delete House** | unowned houses only (seize first); cancels and refunds any auction and deletes the storage and its contents; type `DELETE` first | `delete_housing` |

In game, the realtor job at grade `Config.Jobs.realtorDeleteGrade` or above, and the VORP `admin` group, also get
**Remove House** in the **Buy House** menu of an unsold house.

Motel rooms are not listed on the Housing page; they are set up in `Config.Motels` and `Config.MotelRoom` only.

## Commands

There are no chat commands. Players use prompts at doors, motel entrances, ledger points and town halls. Staff use vorp_admin's Housing page (`manage_housing` / `delete_housing` permissions); see "Setting it up in game".

## Configuration

### config/main.lua

- `Config.Debug`: console chatter (turn off on a live server).
- `Config.ResyncOnRestart`: clients re-request everything 3 seconds after the resource (re)starts.
- `Config.RenderDistance`: a house counts as "near" within this many metres of its front door.
- `Config.SaveIntervalMinutes`: minutes between the periodic furniture save and storage report rewrite.
- `Config.BucketOffset`: interior routing bucket = `playerhousing` row id + this offset.
- `Config.MaxHousesPerCharacter`: houses one character may own (motel rooms do not count).
- `Config.MaxSlots`: storage slot cap (0 = no cap). `Config.MaxRange`: furniture range cap for the admin panel (0 = no cap).
- `Config.SafeExitOnRelog`: a relog inside an interior puts the player outside instead of back inside.
- `Config.Underground`: remember the last outdoor position through `pup_hideouts`.
- `Config.AllowInteriorChange`: owners may swap their teleporter interior.
- `Config.OwnerWebhooks`: owners may connect their own Discord webhook.
- `Config.Jobs`: `realtor` (sees all owned-house blips; may save a house from the creator, but the creator only opens from vorp_admin's Housing page), `realtorDeleteGrade` (realtor grade that gets **Remove House** on an unsold house), `admin` (jobs with full staff rights in this resource), `auctionRealtors` (jobs the server lets start and cancel auctions; there is no in-game menu for it, so staff use the panel), `realtorsMayCreate` (auction realtors may also save houses).
- `Config.Sale`: `sellerShare` (share of the price paid to the stored seller through the Sold Home Ledger), `societyShare` (share to the realtor business ledger), `society` (pup_business integration), `societyJob`.
- `Config.Ledger`: `disabled`, `cap` (0 = no cap), `taxLedger` (separate tax ledger).
- `Config.Tax`: `monthly` (`enabled`, `day`, `hour`, `minute`) and `weekly` (`enabled`, `days`, `hour`, `minute`). `weekly.days` are days of the month. Owners who are short get a letter one hour before collection.
- `Config.Storage.blacklist`: items that cannot be stored.
- `Config.Furniture`:
  - `useItems`: place from inventory items (the item is used up on placement and returned on removal); `false` = buy with cash.
  - `useGizmo`: use vorp_lib's gizmo when that resource is started, else pup-ui's placement tool.
  - `maxPieces`, `sellRate` (cash-mode refund rate).
  - `extra`: pieces added on top of `config/furniture.lua`, as `['Menu Section'] = { ['Label'] = { cost = 10, hash = 'model_name', item = 'item_name' } }`. Empty by default.
  - `modelOverrides`: `[label or item name] = model` to replace a model that does not exist (for example "Framed Painting", item `painfurni`, still has the placeholder model `kill`).
- `Config.Doorlocks`: `enabled` (hand real doors to the doorlocks resource), `lockpickable`, `resource`. A door that already has a doorlock can't be used for a house (the creator refuses it while doorlocks is running). The bridge only changes or removes doors it registered itself (remembered in this resource's KVP; older bridge doors are recognised by their `House <id>` name); any other doorlocks door is left alone, also with the bridge off.
- `Config.Labels`: floating door labels and "locked" signs (distances and heights in metres).
- `Config.Blips`: `forSaleShown`, the `forSale` and `owned` sprites, `scale`, `realtorSeesAll`. See "House blips" above.
- `Config.Auctions`: `defaultHours`, `maxHours`, `minRaise`, `sealed`, `refundBank` (branch used for refunds), `finishedShown` (finished auctions shown on the board).
- `Config.AdminLog`: title, name, colour, logo and avatar of the staff log embeds.
- `Config.Rules` (behaviour switches):
  - `creatorIsSeller`: the staff member who creates a house collects the first seller share.
  - `sellEmptiesLedgers`: selling to the market sets both ledgers to 0.
  - `repoKeepsLedger`: a repossessed house keeps its ledger balance.
  - `keyholderFurniture`, `keyholderSpots`, `keyholderUpgrades`, `keyholderArrangeStash`: what keyholders may do.
  - `forceInteriorWeather`: sunny and midnight inside a teleporter interior.
  - `guestPassReusable`: a guest pass may be used more than once in its 60 seconds.
  - `currentHouseAnyOwner`: `getCurrentHouseId` falls back to the nearest door of any house.
- `Config.Timers`: units are noted next to each value (`s` or `ms`).
- `Config.Reach`: distances in metres. The `server*` values are server-side checks: `serverDoor` (door toggles must come from this close to the door) and `serverPieceFromPlayer` (a placed piece must be this close to the placer).
- `Config.Keys`: control hashes; the key is noted next to each.
- `Config.Anims`: knock and outfit-change animations (may need in-game tuning).
- `Config.Creator`: `findDoorHash` and `probeDistance` (metres past the player). See "Doors that are not in the door list" below.
- `Config.LedgerPoints`: Sold Home Ledger points (`name`, `coords`, `blip`).
- `Config.TownHalls`: where auctions are bid on.
- `Config.Interiors`: teleporter interiors. The key is the name stored in `playerhousing.otherdoors`. Each has `entry`, `price`, `range` (leash range inside) and `imaps` (map files loaded while someone is inside). Example:

```lua
['Cabin'] = {
    entry = vector3(0.0, 0.0, 0.0),
    price = 5000,
    range = 30.0,
    imaps = { 'my_cabin_imap' },
},
```

- `Config.Fallbacks`: outdoor spots a player can be put at when no better spot is known (the nearest is used).
- `Config.MotelRoom`: the one room every motel shares (`exit`, `wardrobe`, `stash`).
- `Config.Motels`: `enabled`, `labels`, `blip`, `list` and `defaults` (`price`, `slots`, `leash` in metres). The keys of `list` are stored in the database and must not change. Add a motel with a line such as `['vh'] = { name = 'Van Horn Hotel', entrance = vector3(x, y, z) },`.

### config/furniture.lua

The furniture catalogue, shown in the furniture menus and checked by the server on placement. `Config.Furniture.sections` is a list of menu sections, shown in that order; the pieces in a section are sorted by label.

```lua
{ title = 'Chairs & Stools', pieces = {
    { 'wood_chair', 325252933, 10, 'Plain Wooden Chair' }, -- { item, model, price, label }
} },
```

- `item`: the inventory item (used when `Config.Furniture.useItems` is on). Placed pieces store it, so do not rename an item that is in use.
- `model`: a signed number, a backtick hash (`` `model_name` ``) or a quoted name (`'model_name'`).
- `price`: price in cash mode.
- `label`: menu name; must be unique across the catalogue.

### config/upgrades.lua

House storage tiers, bought in order. Materials are taken from the house stash, so a house's starting slot count must be big enough to hold them.

- `Config.UpgradeMaterials`: `[item name] = 'menu label'` for every material.
- `Config.StorageTiers`: one entry per tier (its position is the level), `{ slots = extra slots, { 'item', amount }, ... }`. An optional `name = '...'` replaces the menu text "Storage tier N" (`Locale.upgrade_tier`).

```lua
{ slots = 25, { 'nails', 5 }, { 'wood', 10 }, { 'clay', 5 } },
```

### Doors that are not in the door list

The house creator recognises doors from `client/doors.lua` (`{ model name, model hash, { door hash, x, y, z }, ... }`, one group per door model). A door that is not in that list can only be captured when `Config.Creator.findDoorHash` is set to a client-side function that takes the door entity and returns its door-system hash. With the default `nil` the creator says the door cannot be locked.

### shared/locale.lua

Every player-facing line. Placeholders are `string.format` style (`%s`, `%d`).

## For developers

Server exports (vorp_admin checks `manage_housing` / `delete_housing` before calling the admin ones):

- `adminHousingList()`
- `adminSetHousePrice(id, price)`, `adminSetHouseTax(id, tax)`, `adminSetHouseRange(id, range)`, `adminSetHouseSlots(id, slots)`, `adminSetHouseRepo(id, state)`
- `adminSeizeHouse(id)`, `adminDeleteHouse(id)`, `adminTransferHouse(id, charid)`, `adminRemoveKeyholder(id, charid)`
- `adminOpenStorage(src, id)`: opens the house's real storage container for a staff member, from anywhere, with the owner's controls. Returns `true`, or `false` and a reason.
- `hasHouseAccess(charid, houseId)`, `getHouseInfo(houseId)` (used by pup-gangs)

Client export: `getCurrentHouseId()`.

Events:
- Net events (server): `pup_realestate:auctionCreate`, `pup_realestate:auctionCancel`, `pup_realestate:ReloadHouseInventory` (used by pup-misc's storage box to re-open a house stash).
- Local client event: `pup_realestate:openCreation` opens the house creator.
- Client events fired for other resources: `pup-scene:stopscene` and `pup-stable:deletehorse` when entering an interior.

Storage lives in the vorp_inventory container `house_<id>`. The `playerhousing.items` column is only a report of what the container holds and is rewritten from it; do not write to it.

## Credits

- `client/doors.lua`: door hashes, models and positions (game data) from femga's [rdr3_discoveries](https://github.com/femga/rdr3_discoveries) door list (`doorHashes/doorhashes.lua`, by femga with community additions). That repository states no licence. Two doors used by existing houses were added; the layout is this resource's own.
- Game models, blip sprites and animations are Rockstar assets. Icons, fonts and sounds come from `pup-ui`.

## License

See LICENSE.
