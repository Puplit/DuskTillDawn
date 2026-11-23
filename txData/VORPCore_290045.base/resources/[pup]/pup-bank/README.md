# pup-bank

Branch banking for RedM / VORP. Each branch is a separate account with deposits, withdrawals and statements, and bank tellers (a job) can move money between accounts with the sender's consent.

## Features

- **One account per branch:** Valentine, Blackwater, Saint Denis, Rhodes, Strawberry, Armadillo and Annesburg by default, each with its own balance.
- **Bank app:** a pup-ui dashboard at the counter with the account, deposit, withdraw and recent transactions.
- **Every branch on one page:** see what you hold at every branch from any counter, plus your total savings.
- **Statements:** a ledger of every transaction. "Clear Statement" hides rows for the player but never deletes them; the server trims rows older than about 90 days.
- **Tellers:** players on the teller job can look up an account (bank balances only, never pocket cash) and move money between two accounts, charging a fee within set limits. They cannot deposit, withdraw or touch the treasury. Every transfer needs the sender to accept it on their own screen while standing at the counter, and a teller cannot move money to or from their own account.
- **Safe balances:** amounts are stored to the cent and every debit checks the balance in the same database update, so two requests at once cannot overdraw an account.
- **Logs:** deposits, withdrawals and teller transfers go to a Discord webhook. Large deposits also show in vorp_admin's Anti-Cheat tab.

## Requirements

- `vorp_core`
- `oxmysql`
- `pup-ui` (the bank app and list menus)
- A job named `bankteller` for tellers (for example from `pup_business`). Optional; only needed for the Teller tab.
- `vorp_admin` (optional; large deposits show in its Anti-Cheat tab)

## Installation

1. Put `pup-bank` in your resources folder.
2. Run `sql/install.sql`. It creates:
   - `bank_users` - one row per character, one balance column per branch
   - `bank_activity` - the transaction ledger, trimmed to about 90 days
   - `bank_statement_clears` - "clear my statement" markers; they hide rows and never delete them
   - `bank_treasury` - the bank's own money, one row. The server also creates this table and its row on start.

   The teller account lookup reads names from VORP's `characters` table. The script is safe to run more than once.
3. For the Discord log, set the webhook URL in `server/config.lua`.
4. Ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure pup-ui
   ensure pup-bank
   ```

No items are needed.

## Commands

None. Players press G at a bank counter to open the bank.

## Configuration

### config/main.lua

- `Config.General.debug` - `true` = trace every request and reply to the server console and F8. Turn it off on a live server.
- `Config.Keys.interact` - prompt key hash for opening the bank at a counter (G by default). Change the hash only.
- `Config.Counter.promptRange` - metres from a counter before the prompt shows (1.5).
- `Config.Counter.serverRange` - metres from a counter the server still accepts a deposit, withdrawal or teller action from (15).
- `Config.Logs.avatarUrl` - avatar on the Discord log posts; `""` = Discord's default. The webhook URL itself is in `server/config.lua`.
- `Config.Logs.pingStaffAbove` - a deposit of at least this many dollars adds `@everyone` to its log post, at most once per 5 minutes per character (30000).
- `Config.Teller` - the teller job. Tellers move money between accounts and nothing else. The teller sets the fee within the bounds below, and both the flat cap and the percentage cap apply.
  - `enabled` - `false` = no Teller tab and no teller transfers.
  - `job` - job name for tellers.
  - `minGrade` - lowest job grade that may serve a counter.
  - `managerGrade` - this grade and above use `transferMaxManager`.
  - `nearbyRange` - metres: how close the sender must stand to the teller.
  - `consentSeconds` - seconds the sender has to accept before the offer lapses.
  - `feeMin` / `feeMax` - smallest and largest fee in dollars a teller may charge.
  - `feeMaxPct` - the fee may also not exceed this percentage of the amount.
  - `transferMin` - smallest transfer in dollars.
  - `transferMax` - largest transfer in dollars for ordinary grades.
  - `transferMaxManager` - largest transfer in dollars for `managerGrade` and above.

### config/banks.lua

The branches, one line each. Every branch is a separate account, and the key is the branch name players see. Other resources (such as `pup_realestate`) read the branch names from this file by path, so keep it at `config/banks.lua` and keep each entry in the `["Name"] = { ... }` form.

- `Config.BankBlip` - map blip sprite hash used for every branch.
- Each branch:
  - `town` - the town the branch is in (for your reference).
  - `counter` - `vector3` of the counter.
  - `blip` - optional sprite hash for this branch only.

The branch name maps to a `bank_users` column: the name lower-cased, with " bank" and spaces removed, plus `_money` (`"Saint Denis Bank"` -> `saintdenis_money`). Adding or renaming a branch therefore needs that column in `bank_users`.

Example:

```lua
["Valentine Bank"] = { town = "Valentine", counter = vector3(-308.50, 776.24, 118.75) },
```

### config/locale.lua

All text players see in the app, the prompt and the tips. Change the words, keep the keys and the `%s` / `%d` placeholders. The teller desk's own lines are in `client/teller.lua` and `server/teller.lua`.

### server/config.lua

Server only, never sent to players.
- `Webhooks.admin` - Discord webhook for deposits, withdrawals and teller transfers. `""` = off.

## For developers

Server exports (`charid` is the VORP character id, `bankname` a key of `Config.Banks`):

| Export | Returns | Use |
|---|---|---|
| `exports['pup-bank']:CreditAccount(charid, amount, bankname, reason)` | `true, balance` or `false, reason` | Pay money straight into an account without any cash changing hands, for example a market paying a seller "to the bank". There is no distance check, and it writes an activity row labelled with `reason`. Once it returns `true` the caller should stop holding the money. |
| `exports['pup-bank']:DebitAccount(charid, amount, bankname, reason)` | `true, balance` or `false, reason` | Take money out of an account without it becoming cash. The balance check is part of the update, so it can never go negative. |
| `exports['pup-bank']:GetAccountBalance(charid, bankname)` | number, or `nil` for an unknown branch | What an account holds at one branch |
| `exports['pup-bank']:GetBankNames()` | sorted list of branch names | For another resource's branch picker |

Files:
- `server/store.lua` - every player-side read and write of `bank_users` and `bank_activity`, and the branch-to-column whitelist.
- `server/main.lua` - the counter requests (`pup-bank:sv:view`, `pup-bank:sv:move`, `pup-bank:sv:clear`), the exports and the Discord log. The server answers every request with one `pup-bank:cl:view` holding this branch, every branch, the statement and the teller flag.
- `server/teller.lua` / `client/teller.lua` - the teller desk (`pup-bank:teller:*` events).
- `client/main.lua` - blips, the counter prompt and the bank app.

The server also fires `vorp_admin:ac:bankDeposit (src, amount, bankname)` after every deposit, for vorp_admin's Anti-Cheat tab.

## Origin

pup-bank started from a free community RedM bank script (author unknown). It has since been rewritten for this server: new storage layer, request flow, app, teller job, ledger, exports and text. The `bank_users` table keeps the original's column layout so existing databases still work. If you wrote the original and want credit or want it removed, contact the repository owner through GitHub.

## License

See LICENSE.
