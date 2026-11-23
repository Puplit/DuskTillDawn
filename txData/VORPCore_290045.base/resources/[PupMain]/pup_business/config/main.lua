-- pup_business | general settings
-- Every switch below is true (on) or false (off). The note next to it says what each one does.

Config = {}

Config.Framework = 'vorp'        -- only 'vorp' is supported

Config.Debug = false             -- true = print admin create / update / delete traces in the console | false = quiet

---------------------------------------------------------------------------
-- WHO COUNTS AS AN ADMIN
---------------------------------------------------------------------------

-- true  = the plain VORP 'admin' group also counts as a society admin
-- false = only people vorp_admin allows 'manage_society' count
Config.AdminBypass = false

-- jobs that may use the admin actions (create, edit, ranks, shops); add one with  jobname = true
Config.PanelAdminJobs = { govt = true }

-- lowest job grade in PanelAdminJobs that counts: a number (0 = any grade), or
-- 'boss' = the boss grade of that job's business (no business = nobody on that job counts)
Config.PanelAdminMinGrade = 'boss'

-- jobs a PanelAdminJobs admin may not create or set ranks in (the VORP admin groups and
-- manage_society still can); PanelAdminJobs themselves are always included
Config.PanelAdminLockedJobs = { police = true, marshal = true }

-- true  = the VORP 'admin' group may deposit into any business, set webhooks, open any stash,
--         buy slots, delete any bill and /viewduty for any job
-- false = admins follow the same member rules as everyone else
Config.GroupAdminShortcuts = true

---------------------------------------------------------------------------
-- JOBS
---------------------------------------------------------------------------

Config.UnemployedJob = 'unemployed'  -- job given when someone is fired or a business is deleted

Config.InteractKey = 0x760A9C6F  -- G
Config.InteractLabel = 'G'
-- how the job-menu and duty-station prompts look:
-- 'native' = the game's own prompt (bottom right, press G) | 'pill' = pup-ui's key pill
Config.PromptStyle = 'native'

-- jobs whose /onduty and /offduty go through pup-mdt (while it runs); add one with  jobname = true
Config.MdtJobs = { police = true }

Config.DefaultRecruiterGrade = 0 -- grade a new business starts with for hiring and firing (changeable per business)

---------------------------------------------------------------------------
-- STORAGE
---------------------------------------------------------------------------

Config.BaseSlots = 1500          -- slots every business stash starts with
Config.SlotPrice = 3             -- dollars per bought slot, paid from the ledger
Config.MaxSlotPurchase = 100000  -- most slots in one purchase
Config.StashBlacklist = {}       -- item names that can't go in a stash, e.g. { 'dynamite', 'gold_bar' }

Config.StashManageGrade = 3      -- this grade and up may set stash access and buy slots

---------------------------------------------------------------------------
-- MONEY
---------------------------------------------------------------------------

Config.PaydayMinutes = 15        -- minutes between paydays
Config.PaydayGraceSeconds = 5    -- seconds of slack the server allows on that interval
Config.MaxSalary = 250           -- dollars per payday, highest salary a rank can have

-- true  = jobs in Config.DutyJobs are only paid while on duty
-- false = they are paid whether on duty or not
Config.DutyJobsPaidOnDutyOnly = true

-- bills
-- true  = bills written by Config.AutoCollectJobs are taken straight from the target's cash
-- false = every bill waits until the player pays it with /paybills
Config.AutoCollect = true
Config.AutoCollectJobs = { doctor = true, police = true, marshal = true, pharmacist = true }

-- true  = auto-collect takes the full bill even if the target's cash goes below zero (unlimited debt)
-- false = auto-collect only takes the bill when the target has the cash; otherwise it waits on /paybills
Config.AllowDebt = false

Config.MaxBill = 1000            -- dollars, largest bill
Config.BillCooldownSeconds = 30  -- seconds before the same business can bill the same person again, 0 = off

-- true  = a rank needs the Billing permission to write bills
-- false = any member can write bills
Config.BillingNeedsPerm = false

Config.BillReachServer = 5.0     -- metres, most distance between biller and target
Config.BillReachClient = 2.0     -- metres, search radius for the closest player when /bill has no id

---------------------------------------------------------------------------
-- DUTY
---------------------------------------------------------------------------

-- jobs that use the duty roster; add one with  jobname = true
Config.DutyJobs = {
    doctor = true, marshal = true, pharmacist = true,
    rdundertaker = true, sdundertaker = true, amundertaker = true,
    standardtrain = true, newspaper = true,
}

Config.DutyCommands = { on = 'onduty', off = 'offduty', check = 'checkduty', view = 'viewduty' }

-- true  = /onduty clocks the player on at once
-- false = they wait Config.DutyDelaySeconds first
Config.InstantDuty = true
Config.DutyDelaySeconds = 150    -- seconds (only used when InstantDuty = false)

Config.AfkMinutes = 5            -- minutes standing still before being clocked off, 0 = off
Config.AfkMoveMetres = 1.0       -- metres; moving less than this in a minute counts as standing still

-- true  = only members of a business can go on duty
-- false = anyone who asks is recorded as on duty
Config.DutyRequiresBusiness = false

Config.RestartLockMinutes = 5    -- minutes before a txAdmin scheduled restart (fires on its 30/15/10/5/4/3/2/1 min warnings); 0 = off

-- duty stations (config/stations.lua)
-- true  = the stations in config/stations.lua are used: Config.StationJobs clock on at a station
-- false = stations are off; everyone clocks on with /onduty anywhere
Config.DutyStationsEnabled = false

-- true  = /onduty shows a list of regions for station jobs (no need to stand at a station)
-- false = station jobs must stand at a station to clock on
Config.RegionMenu = false

Config.StationJobs = { police = true }  -- jobs that clock on at stations (only while stations are on)
Config.StationReach = 3.0        -- metres from a station to clock on

---------------------------------------------------------------------------
-- LOGS
---------------------------------------------------------------------------

-- true  = send each business's logs to its own Discord webhook (the boss's, or the fallback in server/config.lua)
-- false = no business logs
Config.BusinessLogs = true

-- true  = also copy every log to AdminWebhook in server/config.lua
-- false = no admin copy
Config.AdminMirror = true

Config.DefaultEmbedColour = 16777215  -- Discord embed colour as a decimal number (16777215 = white)

Config.ActivityKeep = 50         -- newest activity rows kept per business
Config.ActivityTrimOneIn = 10    -- old rows are trimmed after roughly one insert in this many
Config.AdminActivityPerBusiness = 25  -- activity rows per business shown in the admin app

---------------------------------------------------------------------------
-- DISTANCES AND LOOKS
---------------------------------------------------------------------------

Config.JobMenuDistance = 2.0     -- metres; the job-menu prompt shows this close
Config.JobMenuRestDistance = 15.0 -- metres; further than this the check runs slowly to save work

-- true  = the fallback deposit / withdraw menus refuse while another player stands within LegacyTooCloseDistance
-- false = no check
Config.LegacyTooClose = true
Config.LegacyTooCloseDistance = 4.0 -- metres

Config.HirePrefillDistance = 6.0 -- metres; the closest player's id is filled in on the Hire box
Config.HireReachServer = 6.0     -- metres; a recruiter (not an admin) can only hire someone this close
Config.HireCooldownSeconds = 60  -- seconds before the same person can be hired again by a recruiter

Config.DefaultBlipSprite = 778811758  -- blip of a new business (it shows once a Management Point is added)
Config.BusinessBlipScale = 0.2
Config.StationBlipSprite = -1656531561
Config.StationBlipScale = 0.8

-- left empty on purpose: read by pup_mercantile, the database holds the businesses
Config.Businesses = {}
