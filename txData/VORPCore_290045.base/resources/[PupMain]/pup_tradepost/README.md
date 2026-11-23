# pup_tradepost

A player exchange for RedM (VORP Core). Seven market counters share one board of buy orders and sell listings, so players can trade goods with each other without being online at the same time.

## Features

- **Buy orders**: "I will pay $X each for N of this item." The money is held when the order is posted. Goods that sellers deliver go into the poster's private market storage at the market where the order was posted.
- **Sell listings**: "I am selling N of this item at $X each." The goods are held when the listing is posted. Buyers get them straight into their inventory.
- A Trading Post panel (pup-ui App) with five tabs: Market Board, Post, My Orders, Price Check and Account.
- Board search, filter (All / Wanted / For Sale), sort (Newest / Cheapest / Best paying) and pages of 40 rows.
- A licence per market ($1,000). You need one to post at that market. It comes with a private storage container of 100 slots; extra slots cost $10 each, up to 2,000.
- A per-character ledger for sale earnings. Withdraw it as cash at any counter, or send it to a pup-bank branch.
- Pay with cash or from a pup-bank branch.
- Market fee: 5% of every sale, plus 2% when the trade is made at a different market from the order's. The fee comes off the money paid to whoever supplied the goods.
- Orders expire after 7 days. Leftover goods or money are returned automatically and the owner gets a letter.
- A going rate for each item: the quantity-weighted average over 30 days, needing at least 3 trades. It feeds the Price Check screen.
- Only plain stacks can be traded: no custom name, description or wear.
- Letters through pup_postoffice, tips to the other trader when they are online, and Discord logs.
- A one-time import of the legacy `market`, `market_ledger` and `market_trades` tables. It runs once, guarded by the resource KVP `pup_tradepost:migrated`, and only reads the old tables.

## Requirements

- `vorp_core`
- `vorp_inventory`
- `oxmysql`
- `pup-ui`
- `pup-bank` (optional: bank payments and bank payouts)
- `pup_postoffice` (optional: letters)
- `vorp_admin` (optional: the staff permission check)

## Installation

1. Run `sql/install.sql`. The tables are also created on start if they are missing.
2. Set `Webhooks.market` to a Discord webhook URL in `server/config.lua` (server only, never sent to players). Leave it empty to switch logging off.
3. `ensure pup_tradepost` after `oxmysql`, `vorp_core`, `vorp_inventory` and `pup-ui` (and after `pup-bank` and `pup_postoffice` if you use them).

No items are needed.

## Commands

There are no chat commands. Players use the prompt (G) at a market counter.

## Configuration

Everything is in `config/main.lua`, shared by the client and the server. Money values are in dollars; the server works in whole cents internally.

| Setting | Meaning |
|---|---|
| `Debug` | console traces of every request (server) and redraw (client) |
| `ItemImage` | item picture shown in every list and grid; `%s` is replaced by the item name |
| `Prompt.distance` | metres from the counter at which the prompt shows (2.0) |
| `Prompt.key` | control hash for the prompt (G) |
| `Prompt.farPoll` | ms between checks while the player is nowhere near a counter |
| `ActionSlack` | extra metres the server allows, on top of `Prompt.distance`, for money and goods actions (4.0) |
| `Panel.boardPageSize`, `Panel.recentPerPage` | rows per board page and per recent-trades page |
| `Bank.enabled` | use pup-bank for payments and payouts |
| `Mail.enabled`, `Mail.sender` | send letters through pup_postoffice, and the sender name on them |
| `ToastOtherTrader` | show a tip to the other side of a trade when they are online |
| `Limits.*` | most catalogue search results, board rows read, and recent trades shown |
| `Discord.botName`, `Discord.colours` | Discord log name and embed colours (decimal colour numbers) |

### Licences and storage (`Licence`)

| Field | Meaning |
|---|---|
| `price` | licence price for one market |
| `startSlots` | storage slots that come with a licence |
| `slotPrice` | price of one extra slot |
| `maxSlots` | the most slots one storage can have |
| `maxSlotsPerBuy` | the most slots one purchase can add |
| `firstContainerId` | first vorp_inventory custom container id used for market storage; every licence gets the next free id |
| `containerName` | name shown on the storage container |

### Orders (`Orders`)

`Orders.buy` and `Orders.sell` each have:

| Field | Meaning |
|---|---|
| `maxOpen` | the most open orders one character may have on that side |
| `maxQty` | the largest quantity on one order |
| `minPrice`, `maxPrice` | allowed price per unit, in dollars |
| `lifetimeDays` | days before the order expires |
| `enabled` (sell only) | false switches sell listings off |

`Orders.limitAcrossMarkets`: `true` means the `maxOpen` limit counts every market together; `false` gives each market its own limit of `maxOpen` per side.

### Fees (`Fees`)

Fees are fractions of the sale (0.05 = 5%) and are taken from the money paid to whoever supplied the goods.

| Field | Meaning |
|---|---|
| `sale` | the market's cut on every sale |
| `crossMarket` | added to `sale` when the trade is made away from the order's market |
| `min`, `max` | the total fee is clamped between these |

### Payouts (`Payout`)

| Field | Meaning |
|---|---|
| `mode` | `'ledger'`: seller earnings go to the character's ledger, collected at any counter. `'bank'`: earnings go straight to the seller's remembered pup-bank branch, falling back to the ledger when that is not possible. Refunds always go to the ledger, because the character may be offline. |
| `minWithdraw` | smallest cash withdrawal from the ledger |
| `minToBank` | smallest ledger-to-bank transfer (0 = no minimum) |

### Going rate (`GoingRate`)

| Field | Meaning |
|---|---|
| `enabled` | show going rates at all |
| `windowDays` | days of trade history in the average |
| `minTrades` | trades needed before a rate is shown |
| `cacheSeconds` | how long a computed rate list is reused |
| `includeImported` | count trades imported from the legacy tables, which have no buyer or seller recorded |

### Expiry sweep (`Sweep`)

Expired orders are closed in the background, and their leftover goods or money are returned.

| Field | Meaning |
|---|---|
| `intervalMinutes` | minutes between sweeps (the first one runs one interval after start) |
| `batch` | close attempts per pass |
| `stuckRetryMinutes` | a listing whose goods could not be returned waits this long before the next try |

### Blacklist (`Blacklist`)

Items that can never be traded or kept in market storage. `names` are exact item names, `prefixes` match the start of a name; both are case-insensitive. Example: add `'moonshine'` to `names`, or `'ammo_'` to `prefixes`.

### Staff (`Staff`)

Who may cancel anyone's order through `AdminCancelOrder`: VORP groups in `groups`, or anyone vorp_admin's `hasPermission` grants the `permission` key (`manage_stores`).

### Spam guard (`RateLimit`)

| Field | Meaning |
|---|---|
| `windowMs` | sliding window in ms |
| `maxRequests` | requests allowed in that window, reads included |
| `writeGapMs` | minimum ms between two money/goods actions |

### Markets (`Markets`)

One entry per counter:

```lua
{ key = 'Valentine', name = 'Valentine Market Place', coords = vector3(-179.35, 648.28, 113.58), bank = 'Valentine Bank', blip = { sprite = -272216216, scale = 0.2 } },
```

- `key` is stored in the database and must never change (case included).
- `bank` is the pup-bank branch for this town; the Account tab lists this branch first.
- `blip = false` hides the market's map blip.

To add a market, add a row with a new `key`.

## For developers

Server exports:

- `exports.pup_tradepost:AdminListOrders(query, side)`: open orders (unexpired, remaining > 0), newest first, at most 300. Each row has `id`, `charid`, `market`, `side`, `item`, `label`, `remaining`, `price_each` and `expires_at`.
- `exports.pup_tradepost:AdminCancelOrder(adminSrc, orderId)`: returns `success, message`. It returns `false, 'not staff'` when the caller has no active character or is not staff.

The argument order and return shapes of both exports are fixed.

## License

See LICENSE.
