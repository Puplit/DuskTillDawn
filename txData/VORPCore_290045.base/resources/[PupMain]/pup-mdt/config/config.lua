-- pup-mdt | general settings, jobs, duty, permissions (shared)

Config = {}

Config.Locale = 'en-us'
Config.Debug = false
Config.NuiDebug = false

-- open by command; with UseCommand = false the inventory item opens it instead
Config.UseCommand = true
Config.Command = 'mdt'
Config.ItemName = 'mdt'

Config.LawJobs = { 'police' }
Config.InventoryImagePath = 'nui://vorp_inventory/html/img/items/'

-- notifications: toast inside the MDT while open, vorp right tip otherwise
Config.Notify = { title = 'MDT', defaultMs = 4000 }

Config.AllowSelfExpungementApproval = true

-- developer aid: prints the caller's position to the server console. Admins only (ace
-- command.mycoords) unless Debug is on; false turns it off
Config.CoordsCommand = 'mycoords'

---------------------------------------------------------------------------
-- Duty
---------------------------------------------------------------------------
Config.Duty = {
    enabled = true,
    startOnDuty = false,
    onCommand = 'onduty',
    offCommand = 'offduty',
    afkMinutes = 20,          -- 0 turns the AFK clock-off off
    afkPollSeconds = 10,
    afkMoveMetres = 1.5,
    serverAfkMetres = 3.0,    -- the server's own check: no wage and clocked off after afkMinutes within this distance; 0 turns it off
    regionPicker = true,
    regions = {
        { id = 'EAST', label = 'EAST', description = 'Valentine, Rhodes, Annesburg, Saint Denis', boardColor = '#6b4a2b' },
        { id = 'WEST', label = 'WEST', description = 'Blackwater, Strawberry, Armadillo, Tumbleweed', boardColor = '#7a5a36' },
    },
    restartLockMinutes = 5,   -- 0 turns the restart lock off
    trackTime = true,
    trackIntervalMinutes = 1,
    onlineListSeconds = 30,
}

---------------------------------------------------------------------------
-- Lawman profiles
---------------------------------------------------------------------------
Config.Profiles = {
    autoCreate = true,
    strictJobCheck = true,
    editGrade = { police = 5 },
    terminationSetsJob = true,
    terminatedJob = 'unemployed',
    terminatedGrade = 0,
    trainings = { 'Shootout', 'Robbery', 'Hostage Negotiation', 'Field Training Officer', 'Detective' },
    bossGrade = 4,
}

---------------------------------------------------------------------------
-- Features
---------------------------------------------------------------------------
Config.Features = {
    mostWanted = true,
    bounty = true,
    bountyAutoWanted = true,
    bountyDefaultFine = 1000,
    bountyDefaultJail = 30,
    bountyAutoExpire = true,
    bountySuggestedExpiryDays = 14,
    reports = true,
    reportTitleMax = 100,
    reportMaxSuspects = 25,           -- suspects named on one report
    reportMaxChargesPerSuspect = 25,  -- charge lines per suspect on one report
    reportSaveCooldownSeconds = 4,    -- per officer, between report saves/edits
    statements = true,
    tips = true,
    expungements = true,
    prisons = true,
    evidences = true,
    fines = true,
}

Config.Audit = {
    enabled = true,
    database = true,
    discord = true,
    retentionDays = 90,       -- 0 keeps entries forever
    actions = {
        duty_changed = false,
    },
}

---------------------------------------------------------------------------
-- Jail limits and arrest processing
---------------------------------------------------------------------------
Config.Jail = {
    minMinutes = 1,
    maxMinutes = 999,
    arrestCooldownSeconds = 10,
    maxDiscountPercent = 100,
    targetDistance = 10.0,    -- metres: /jail and a processed arrest need the citizen this close
}

-- /mdtbill: direct fines
Config.Fines = {
    maxDirectBill = 5000,
    billDistance = 10.0,      -- metres from the officer
    billCooldownSeconds = 60, -- seconds before the same citizen can be billed again
}

-- bounties posted in the MDT; the reward is paid from the police ledger
Config.Bounties = {
    maxReward = 5000,
    ledgerJob = 'police',     -- whose ledger pays; must be in Config.LawJobs
}

---------------------------------------------------------------------------
-- Permissions: a number = that grade or higher, a list = exactly those grades.
-- Lawyer grades are merged from Config.Legal.permissions for every lawyer job.
---------------------------------------------------------------------------
Config.Permissions = {
    dashboard          = { police = 0 },
    reports            = { police = 0 },
    deletereports      = { police = 6 },
    bolos              = { police = 0 },
    deletebolos        = { police = 6 },
    evidences          = { police = 5 },
    deleterecords      = { police = 11 },
    criminals          = { police = 0 },
    warrants           = { police = 0 },
    mostwanted         = { police = 0 },
    managemostwanted   = { police = 5 },
    issuewarrants      = { police = 10 },
    deletewarrants     = { police = 10 },
    fines              = { police = 0 },
    managecharges      = { police = 6 },
    lawmen             = { police = 0 },
    viewlawmen         = { police = 5 },
    createlawmen       = { police = 5 },
    prisons            = { police = 0 },
    arrest             = { police = 0 },
    viewexpungements   = { police = 0 },
    requestexpungement = { police = 5 },
    approveexpungement = { police = 11 },
    viewbail           = { police = 0 },
    requestbail        = { police = 5 },
    approvebail        = { police = 11 },
    viewappeals        = { police = 0 },
    requestappeal      = { police = 5 },
    approveappeal      = { police = 11 },
    viewdefense        = { police = 0 },
    assigndefense      = { police = 5 },
    filedefense        = { police = 5 },
    viewtips           = { police = 0 },
    deletetips         = { police = 6 },
    managepermissions  = { police = 12 },
    viewauditlog       = { police = 12 },
    settings           = { police = 5 },
    ledger             = { police = 5 },
    ledgerdeposit      = { police = 0 },
    ledgerwithdraw     = { police = 11 },
    firmhome           = {},
    firmledger         = {},
    viewbarroster      = {},
    viewlawyerprofile  = {},
    firelawyers        = {},
    firmsettings       = {},
}

-- fallback rank ladders, used only when a grade has no locale name
Config.FallbackRanks = {
    police = { 'trainee', 'deputy', 'lawman', 'sergeant', 'chief' },
    sheriff = { 'deputy_sheriff', 'sheriff' },
    marshal = { 'deputy_marshal', 'marshal', 'senior_marshal', 'chief_marshal' },
}
