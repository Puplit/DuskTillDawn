# pup_business

Businesses for a RedM / VORP server. Every job can be a business stored in the database, with ranks,
permissions, a money ledger, salaries, tax, bills, a shared stash, an on-duty roster and Discord logs,
all run from an in-game management dashboard.

## Features

- Ranks from grade 0 up to a boss grade, each with eight permissions: hire, fire, set ranks,
  manage pay, open storage, manage storage, billing and mail
- A business ledger with deposits and withdrawals; salaries are paid from it every payday
- Optional per-rank tax (daily, weekly or monthly) that members pay from the job menu
- Bills (`/bill`, `/paybills`), with on-the-spot collection for chosen jobs (doctors, police and so on)
- A shared business stash (a vorp_inventory container) with buyable extra slots, an access grade,
  logs of every item moved and a readable copy of its contents on the container row
- An on/off duty roster, merged with pup-mdt's when it runs, with an AFK clock-off and optional duty stations
- Discord logs per business, an optional admin copy of every log, and an activity feed
- A management dashboard (a pup-ui app) opened from each business's job-menu point
- Staff create, edit and delete businesses on vorp_admin's Society page, through exports and events this resource offers
- Map blips for businesses and duty stations

## Requirements

- [oxmysql](https://github.com/overextended/oxmysql)
- vorp_core
- vorp_inventory
- pup-ui

Optional:

- vorp_admin: the Society page, where businesses are created and managed, and the admin rights
  `manage_society` and `delete_society`. Without it, businesses can only be added by SQL.
- pup_mercantile: society shops shown and managed in the admin app
- pup-mdt: police duty runs through the MDT, and its roster is merged in
- pup-events: going on duty is refused during a purge, and the purge clocks everyone off
- pup_postoffice: the Mail tab (a business PO box)
- pup-misc: the police badge is taken off with `/offduty`

## Installation

1. Put the `pup_business` folder in your resources.
2. Run `sql/install.sql` once. The resource also creates missing tables and adds missing columns when it starts.
   No items are needed.
3. In `server.cfg`, ensure it after its dependencies:
   ```
   ensure oxmysql
   ensure vorp_core
   ensure vorp_inventory
   ensure pup-ui
   ensure pup_business
   ```
4. For Discord logs, set the webhook links you want in `server/config.lua` (server only, never sent to a
   client). Leave a value empty to switch that log off.
5. Adjust `config/main.lua` and `config/stations.lua`, then restart the resource.
6. Create businesses in game on vorp_admin's Society page. See the next section.

## Setting it up in game

Businesses are created and run from vorp_admin's **Society** page. Open the admin panel with PageDown or
`/adminMenu` (vorp_admin's `Config.Menu.command`), then click **Society** in the side bar.

### Permissions

pup_business checks every action again on the server, so hiding a button is never the only guard.

| Step | vorp_admin key | Discord name (`config/discord.lua`) |
|---|---|---|
| Open the admin panel | `open_menu` | `menu.open` |
| See the Society page, create a business, change its settings, blip, points, staff and stash slots, open its stash, manage its society shops | `manage_society` | `manage.society` |
| Delete a business, Clear Storage, Clear Shop Fronts, delete a society shop | `delete_society` | `destroy.society` |
| Give the society shop licence item (step 6) | `give_item` | `players.giveitem` |

With Discord permissions off, give a VORP group the keys in vorp_admin's `config/permissions.lua`, for example
`yourgroup = { actions = { open_menu = true, manage_society = true } }`. The default `admin` group has every key;
`moderator` has neither society key. The wildcard `manage.*` does not include `delete_society`; name it on its own.

### 1. Create the business

1. Stand where the staff should open their job menu, for example behind the counter.
2. On the Society page, fill in the **Create Business** card:
   - **Job name**: the job code, in lowercase letters, numbers and `_`, for example `butcher`. This is the job
     the members' characters get. It must not exist yet and cannot be changed later.
   - **Display name**: the name players see, on the blip and on the prompts. Left empty, the job name is used.
   - **Boss rank**: the highest grade, held by the owner. The default is 5.
   - **Recruit rank**: the lowest grade that may hire, fire lower grades and change lower ranks. It cannot be
     higher than the boss rank.
3. Click **Create Business Here**.

That one click creates everything the business needs. No SQL is needed:

- the business, with billing on, salary on, Discord logs off, tax off and the blip switched on (but no blip
  point yet, see step 3);
- one rank for every grade from 0 up to the boss rank, with $0 salary. The boss grade has all eight permissions,
  the others none;
- the ledger, at $0;
- the stash, a vorp_inventory container called "*Display name* Inv." with `Config.BaseSlots` slots;
- one **job-menu point** where you are standing.

VORP has no job list to fill in: a job is just text on the character, and grades are numbers from 0 to the boss
rank. Grades have no names; the dashboard shows them as "Grade 2", "Grade 5 - Boss" and so on.

### 2. Put in the owner and staff

1. Click the business in the list to open it.
2. In the **Staff** card, type a player's server id and click **Hire (online player)**. They join at grade 0.
3. Type a grade in the box next to their name and click **Set Rank**. Setting someone to the boss rank makes
   them the owner. A business has one boss: anyone else already at the boss rank is moved one grade down.
4. **Fire** puts the character back on `Config.UnemployedJob`, online or offline.

vorp_admin's own Set Job (`set_job`) works too; pup_business picks up the change.

### 3. Place and edit the blip

The blip is drawn at every **Management Point** of the business. Everyone sees business blips.

**A new business has no blip on the map until you add at least one Management Point.** This is on purpose:
creating the business only places the job-menu point, so you choose where the blip goes.

1. Open the business and stand where the blip should be.
2. In the **Management Points** card, click **+ Add My Position**. Add more points for more blips; **✕** removes one.
3. In **Settings**:
   - **Blip sprite**: type a sprite hash (a whole number, it may be negative) and click **Set**. New businesses
     use `Config.DefaultBlipSprite`.
   - **Blip: ON / OFF** shows or hides all of the business's blips.
   - **Name** changes the display name, which is also the blip's name. Renaming also renames the stash to
     "*new name* Inv.".
4. The blip size is `Config.BusinessBlipScale`, the same for every business.

Blip colour cannot be set: the code only sets the sprite, the size and the name.

### 4. Job menu, stash and duty points

- **Job menu**: use the **Job Menu Points** card (**+ Add My Position**, **✕**). Only members of that business
  see the prompt, within `Config.JobMenuDistance` metres; the key is `Config.InteractKey` (G). The menu offers
  **Inventory** (the stash), **Business Tax** (when the member owes tax) and **Management** (the dashboard).
- **Stash**: it has no point of its own. Members open it from the job menu's **Inventory** when their grade is at
  or above the stash access grade, or their rank holds the storage permission; the boss always can. The boss
  sets the access grade on the dashboard's Storage tab. Staff can open it from anywhere with **Open storage** on
  the business page.
- **Stash size**: type the total you want in **Total stash slots** and click **Set**. The smallest total is
  `Config.BaseSlots`, and at most `Config.MaxSlotPurchase` slots can be added. Setting it here costs the business
  nothing; slots the boss buys in game are paid from the ledger.
- **Duty stations**: there is no panel tool for these; they are config only. Set
  `Config.DutyStationsEnabled = true`, add the job to `Config.StationJobs`, add a station to
  `config/stations.lua` (see Configuration below) and restart the resource. Add the job to `Config.DutyJobs` as
  well if it should use the on-duty roster. Without stations, members go on duty anywhere with `/onduty`.

### 5. Settings, ranks and money

On the business page, the **Settings** card sets: Name, Boss rank, Recruit rank, Blip sprite, PO address (with
pup_postoffice: 3 letters then 3 numbers, for example `val556`) and Total stash slots. The buttons switch
**Billing**, **Salary**, **Webhook** (Discord logs), **Blip** and **Tax** on or off.

The owner sets the rest in game, on the dashboard (job menu, then **Management**):

- **Ranks** tab: the salary, the tax and the eight permissions of each grade.
- **Ledger** tab: deposits, withdrawals, and **Set Webhook** for the business's Discord log. Saving a webhook
  switches the Webhook flag on. A fallback per job can also be set in `JobWebhooks` in `server/config.lua`.
- **Storage** tab: the stash access grade and buying slots.

The Society page cannot set salaries, rank permissions or tax amounts. A staff member who wants to must hold the
job themselves (for example with vorp_admin's Set Job) and use the dashboard.

Raising the boss rank gives the new top grade every permission and adds any missing grades.

### 6. Society shop (optional, needs pup_mercantile)

Staff cannot create a society shop from the panel. The owner opens it in game:

1. Make sure the owner is at the boss rank.
2. Give the owner the item `societytoken` ("Society Shop Creation License"), for example with vorp_admin's give
   item. The item name is `Config.SocietyShops.token` in pup_mercantile.
3. The owner stands where the shop should be, uses the item and types a shop name. The shop opens there.
   pup_mercantile limits each business to `Config.SocietyShops.maxPerBusiness` shops and refuses a spot too close
   to another shop.
4. The business page's **Shops** card then manages it: **Rename**, **Slots**, **Blip: ON / OFF**, **Move Here**
   (moves it to where you stand) and **Delete** (needs `delete_society`). The shop's blip sprite is
   `Config.SocietyShops.blipSprite` in pup_mercantile.

### 7. Edit or delete a business

- **Edit**: open the business and change it in Settings, the points cards, Staff or Shops. Every change reaches all
  players at once.
- **Hand it to a new owner**: **Clear Storage** empties the stash and **Clear Shop Fronts** empties the shops'
  stock; staff, ranks and the ledger stay. Both need `delete_society`.
- **Delete**: in the **Danger Zone**, type `DELETE`, click **Delete Business** and confirm. Every member, online or
  offline, is moved to `Config.UnemployedJob` at grade 0. The stash and everything in it, the ledger, ranks, tax
  records, bills, activity history and society shops are removed. This cannot be undone. Without
  `delete_society` the Danger Zone only says that deleting is Management only.
- To change a job code, delete the business and create it again.

## Commands

| Command | Who | What |
|---|---|---|
| `/bill amount [id]` | members of a business with billing on | bill the closest player, or the given server id |
| `/paybills` | anyone | list and pay your unpaid bills |
| `/onduty` | anyone | go on duty (jobs in `Config.MdtJobs` go through pup-mdt while it runs) |
| `/offduty` | anyone | go off duty |
| `/checkduty` | anyone | shows whether you are on duty here or in pup-mdt |
| `/viewduty [job]` | the boss of a business; the VORP `admin` group for any job | list who is on duty |
| `/refreshjob` | anyone | re-read your job and grade from the server |
| `/showjob` | anyone | show your job and grade |
| `/societywebhook job` | server console or the VORP `admin` group | print a log-delivery check for a business and send a test log |

The four duty command names can be changed in `Config.DutyCommands`.

## Configuration

Restart the resource after any change. Both config files are loaded on the server and on the client.

### config/main.lua

**General**

- `Config.Framework`: only `'vorp'` is supported.
- `Config.Debug`: prints console traces for admin create / update / delete.

**Who counts as an admin**

- `Config.AdminBypass`: a society admin is someone vorp_admin allows `manage_society`. With this on, the
  plain VORP group `admin` also counts as a society admin.
- `Config.PanelAdminJobs`: characters with one of these jobs, at `Config.PanelAdminMinGrade` or higher, pass
  pup_business's own admin check for the admin
  actions (create, edit, ranks, shops), for example `{ govt = true, sheriff = true }`. The VORP `admin` and
  `superadmin` groups and anyone with `manage_society` always pass it. vorp_admin's Society page itself still
  needs `manage_society`. Deleting a business, clearing storage or shop stock and deleting shops also need
  vorp_admin's `delete_society`.
- `Config.PanelAdminMinGrade` (default `'boss'`): the lowest grade on a `PanelAdminJobs` job that passes the
  admin check. A number is that grade (`0` = any grade); `'boss'` is the boss grade of that job's business, so
  the job must also be a business. It does not affect the admin groups or `manage_society`.
- `Config.PanelAdminLockedJobs` (default `{ police = true, marshal = true }`): jobs a `PanelAdminJobs` admin may
  not create or set ranks in. The `PanelAdminJobs` themselves are always included. The VORP `admin` and
  `superadmin` groups and anyone with `manage_society` are not limited by it.
- `Config.GroupAdminShortcuts`: when true, several player actions accept the plain VORP `admin` group directly:
  depositing into any business, setting a webhook, stash access, buying slots, deleting any bill and
  `/viewduty` for any job. Set false to make those actions follow the member rules only.

**Jobs**

- `Config.UnemployedJob`: the job given when someone is fired or a business is deleted.
- `Config.InteractKey` / `Config.InteractLabel`: the key hash for the job-menu and duty-station prompts
  (`0x760A9C6F` is G) and the label shown on the prompt.
- `Config.PromptStyle`: `'native'` (default) shows the game's own prompt, titled with the business name;
  `'pill'` shows pup-ui's key pill instead.
- `Config.MdtJobs`: `/onduty` and `/offduty` for these jobs are handed to pup-mdt while it runs.
- `Config.DefaultRecruiterGrade`: members at or above a business's recruiter grade may hire, fire lower
  grades and change lower ranks. Each business has its own value, set in the admin tool; new businesses start
  at this one.

**Storage**

- `Config.BaseSlots`: every business stash starts with this many slots.
- `Config.SlotPrice`: dollars per bought slot, paid from the ledger.
- `Config.MaxSlotPurchase`: the most slots in one purchase or one admin set.
- `Config.StashBlacklist`: item names that cannot be put in a business stash, for example `{ 'dynamite', 'gold_bar' }`.
- `Config.StashManageGrade`: members at this grade or higher (and holders of the Manage Storage permission) may
  set the stash access grade and buy slots. It is a fixed number, whatever the business's boss grade is.

**Money**

- `Config.PaydayMinutes`: how often, in minutes, a client asks for its salary.
- `Config.PaydayGraceSeconds`: slack, in seconds, the server allows on that interval.
- `Config.MaxSalary`: the highest salary per rank per payday, in dollars.
- `Config.DutyJobsPaidOnDutyOnly`: jobs listed in `Config.DutyJobs` are only paid while on duty.
- `Config.AutoCollect` / `Config.AutoCollectJobs`: bills written by these jobs are taken straight from the
  target's cash into the ledger instead of waiting on `/paybills`. Add a job with `jobname = true`.
- `Config.AllowDebt` (default false): when true, auto-collect takes the full bill even if it pushes the target's
  cash below zero, with no limit. When false, auto-collect only takes the bill if the target has that much
  cash; otherwise nothing is taken, the biller is told, and the bill waits on `/paybills`.
- `Config.MaxBill`: the largest bill, in dollars. Bills are whole dollars.
- `Config.BillCooldownSeconds` (default 30): seconds before the same business can bill the same character
  again. `0` turns it off.
- `Config.BillingNeedsPerm`: when true, a rank needs the Billing permission to write bills.
- `Config.BillReachServer`: the most distance, in metres, between biller and target, checked on the server.
- `Config.BillReachClient`: the search radius, in metres, for the closest player when `/bill` has no id.

**Duty**

- `Config.DutyJobs`: jobs that use the duty roster (and, with `Config.DutyJobsPaidOnDutyOnly`, are paid only on
  duty). Add one with `jobname = true`.
- `Config.DutyCommands`: the command names for on, off, check and view.
- `Config.InstantDuty`: when false, the player waits `Config.DutyDelaySeconds` seconds before being clocked on.
- `Config.AfkMinutes`: minutes standing still before being clocked off; `0` switches it off.
- `Config.AfkMoveMetres`: moving less than this many metres in a minute counts as standing still.
- `Config.DutyRequiresBusiness`: when false, the server records anyone who asks to go on duty; when true, the
  player must be a member of a business.
- `Config.DutyStationsEnabled`: switches the duty stations in `config/stations.lua` on.
- `Config.RegionMenu`: `/onduty` shows a region list for station jobs instead of requiring them to stand at a station.
- `Config.StationJobs`: jobs that clock on at stations while stations are enabled.
- `Config.StationReach`: how close, in metres, the player must be to a station when clocking on (checked on the server).

**Logs**

- `Config.BusinessLogs`: send logs to each business's own webhook (the one the boss saved, or the fallback in
  `server/config.lua`).
- `Config.AdminMirror`: copy every log to `AdminWebhook` in `server/config.lua`.
- `Config.DefaultEmbedColour`: the Discord embed colour as a decimal number (16777215 is white).
- `Config.ActivityKeep`: the newest activity rows kept per business.
- `Config.ActivityTrimOneIn`: old rows are trimmed after roughly one insert in this many.
- `Config.AdminActivityPerBusiness`: activity rows per business shown in the admin app.

**Distances and looks**

- `Config.JobMenuDistance`: metres from a job-menu point (and a duty station) at which the prompt shows.
- `Config.JobMenuRestDistance`: metres beyond which the job-menu check runs slowly to save work.
- `Config.LegacyTooClose` / `Config.LegacyTooCloseDistance`: the fallback deposit and withdraw menus refuse
  while another player is within this many metres.
- `Config.HirePrefillDistance`: metres within which the closest player's id is filled in on the Hire box.
- `Config.DefaultBlipSprite` / `Config.BusinessBlipScale`: the blip of a new business and the blip size.
- `Config.StationBlipSprite` / `Config.StationBlipScale`: the blip and size of duty stations.
- `Config.Businesses`: left empty on purpose. pup_mercantile reads this table looking for boss ranks, but the
  database is the real source of businesses.

### config/stations.lua

Used only when `Config.DutyStationsEnabled` is true. Each entry is one station:

- `region`: the name stored with the duty record
- `coords`: where the station stands (`vector3`)
- `jobs`: the jobs that may clock on here
- `label`: the name on the blip and in the region list
- `blip`: show a map blip (only for players with one of the jobs)

Example:

```lua
{ region = 'tumbleweed', coords = vector3(-5527.0, -2930.0, -2.0), jobs = { 'police', 'marshal' }, label = 'Tumbleweed Duty Station', blip = true },
```

### server/config.lua

Server-only settings:

- `AdminWebhook`: every business log is copied here when `Config.AdminMirror` is on.
- `JobWebhooks`: a fallback webhook per job code, used when the boss has not saved one, for example
  `doctor = 'https://discord.com/api/webhooks/...'`.

Only real Discord webhook links (`https://discord.com/api/webhooks/...`) are accepted.

### Per-business settings

Name, blip, boss rank, recruiter rank, billing, salary, tax and webhook logs are set per business on
vorp_admin's Society page (see "Setting it up in game"). The storage name follows the business name.
Salaries, permissions and tax per rank are set by the boss on the Ranks tab of the dashboard.
Changing a rank's tax amount or period restarts that grade's tax cycle from that day.

### locale/en.lua

All player-facing text. `%s` and `%d` are filled in by the code, in order.

## For developers

### Server exports

From `server/exports.lua`:

| Export | Returns |
|---|---|
| `AddToLedger(job, amount, reason, who)` | Credits money another resource already took from a player. Whole dollars; logged and added to the activity feed. Returns `true`, or `false, reason`. |
| `IsPlayerOnDuty(src)` | `true` when on duty here or in pup-mdt |
| `SetPlayerDuty(src, on, region)` | Sets duty quietly (no tip to the player) |
| `GetPlayersOnDuty(job)` | Sorted list of server ids on duty, for one job or all when `job` is nil |
| `GetDutyRegion(src)` | The region of the player's duty record, or nil |
| `HasPerm(src, key)` | Whether the player's rank holds a permission (`hire`, `fire`, `setranks`, `managepay`, `stash`, `store`, `billing`, `mail`) |
| `GetBusinessName(job)` | The display name, or nil |
| `GetJobWebhook(job)` | The webhook the business's logs go to, or nil |
| `GetBusinessInfo(src)` | `{ job, name, grade, bossrank, isBoss, canSend }` for the player's business, or nil |

From `server/admin.lua` (used by vorp_admin):

| Export | Returns |
|---|---|
| `adminOverview()` | Every business with staff, ledger, slots, locations and recent activity |
| `adminShops(job)` | `{ ready, shops }`: the business's pup_mercantile society shops |
| `adminOpenStash(src, job)` | Opens a business stash for a staff member with the boss's controls; `true`, or `false, reason` |
| `adminSetSocietySlots(job, slots)` | Sets the bought slots of a stash; `{ ok, slots, total }` or `{ ok = false, err }` |

### Events

Server net events other resources may trigger:

- `pup_business:hire` `(targetServerId, job)`: hire a player (used by vorp_admin; permissions are checked)
- `pup_business:fire` `(charid, job)`: fire a character, online or offline (used by vorp_admin)
- `pup-Container:reloadContainerInventory` `(containerId)`: re-register a business stash and rebuild its contents copy

Client events:

- `pup_business:openAdminTool` (local event): opens an older in-world admin app; the server answers panel admins
  only. Nothing in this release triggers it (vorp_admin's Society page does the same work), so call it yourself
  if you want it.
- `pup_business:client:jobChanged` `(oldJob, newJob)`: raised when the player's job changes
- `pup_business:client:businessesChanged`: raised when the business list arrives from the server
- `pup_business:client:refreshDashboard`: re-reads the open dashboard
- `pup_business:dutyState` `(on, region)`: sent by the server whenever the player's duty changes

Events this resource sends to other resources:

- `pup-medic:onduty` `(on)` (client) when duty changes
- `pup-misc:police:takeoffbadge` (client) on `/offduty`
- `mdt:server:dutyCommand` `(on)` (server) for jobs in `Config.MdtJobs`
- `mail:business:request`, `mail:business:register`, `mail:business:setHandle` (server) for the Mail tab

It listens to `pup-events:server:state` (`'purge'`) and to vorp_core's `vorp:playerJobChange`,
`vorp:playerJobGradeChange` and `vorp:SelectedCharacter`.

### Database

Tables: `society_business`, `society_ranks`, `society_tax`, `society_ledger`, `society_activity`, `bills`,
`society` (per-grade salary table, also read by pup_mercantile) and `container` (shared with vorp_inventory
stashes; only `invslots` belongs to this resource). A unique key on `society_ledger.job` is added at start
only when no job has two ledger rows.

## License

See LICENSE.
