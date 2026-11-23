-- search | settings, read on both sides (see README). Server-only values are in
-- config/search/server.lua, which never reaches clients.

SearchConfig = {}

SearchConfig.General = {
    debug = false,                -- console tracing on both sides
    searchKey = 0x760A9C6F,       -- G
    promptDistance = 1.0,         -- client: metres to the closest player
}

-- who can be targeted (the purge switches dead on)
SearchConfig.Targets = {
    cuffed = true,
    hogtied = true,
    dead = false,
}

SearchConfig.Law = {
    jobs = { 'police', 'marshal' },
    searchOnly = false,      -- only law (and the super-bypass account) may search anywhere
    cashOnly = false,        -- only law may use the Cash row
    cashBypass = false,      -- law may take cash even when Steal.cash is off
    itemBypass = false,      -- law may take items even when Steal.items is off
    weaponBypass = true,     -- law may take weapons even when Steal.weapons is off
    -- true = every law privilege needs duty
    requireDutyForAll = false,
}

-- what anyone may take; weapons always need on-duty law
SearchConfig.Steal = {
    cash = true,
    items = true,
    weapons = false,
}

SearchConfig.Limits = {
    maxStacks = 3,             -- item stacks + weapons per victim character per window
    windowMinutes = 15,
    -- false = the window starts at the first theft; true = it slides
    slidingWindow = false,
    reach = 5.0,               -- server: metres between searcher and target (0 = off)
    lockSeconds = 5,           -- "being searched" lock after a search opens
    -- true = one robber per victim for the whole session
    exclusiveVictim = false,
    bypassJobs = { 'police' }, -- skip the limit and the shield while on duty
    shieldMinutes = 1440,      -- new-character shield (0 = off)
}

SearchConfig.Duty = {
    enabled = true,                       -- off = everyone counts as on duty
    protectedJobs = { 'police', 'marshal', 'doctor' },
    -- false = every protected job is checked through pup-mdt, then pup_business
    doctorViaMedical = false,
    medicalJobs = { 'doctor' },           -- used only when doctorViaMedical is on
    -- true = pup_business not running counts as on duty
    businessMissingMeansOnDuty = true,
    resources = {
        mdt = 'pup-mdt',
        business = 'pup_business',
        medical = 'pup-medical',
        events = 'pup-events',
    },
}

-- ask the target's own client whether it is really restrained before opening
-- (no answer in time = cannot be searched)
SearchConfig.VerifyTarget = {
    enabled = true,
    timeoutMs = 1500,
}

SearchConfig.Sisika = {
    block = true,   -- inside, only law and the super-bypass account may search
    minZ = 40.0,
    maxZ = 58.0,
    points = {
        { x = 3080.3,  y = -900.316 },
        { x = 3051.77, y = -306.54 },
        { x = 3483.8,  y = -312.06 },
        { x = 3524.33, y = -849.71 },
    },
}

SearchConfig.Cash = {
    -- asking for at least everything the victim holds takes the whole balance, cents included
    takeAllIncludesCents = true,
}

SearchConfig.Database = {
    checkColumnDelayMs = 2000,
    -- when this module adds character_created, existing characters get an old date
    backfillOnCreate = true,
    backfillDate = '2000-01-01 00:00:00',
}

SearchConfig.Webhook = {
    enabled = true,
    username = 'Search Logs',
    avatar = '',   -- '' = Discord default
    footer = 'Dusk Till Dawn RP - VORP Search/Robbery System',
    colours = { cash = 16776960, item = 65280, weapon = 16711680 },
}

SearchConfig.Notify = {
    normalMs = 3000,
    longMs = 4000,   -- protected job and new-character refusals
}

SearchConfig.Anim = {
    dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a',
    clip = 'idle_c',
    flags = 1 + 16 + 32, -- loop, upper body, keep player control
}

SearchConfig.Controls = {
    inventory = { 0xC1989F95, 0x3C0A40F2 }, -- disabled every frame while restrained
}

SearchConfig.Timings = {
    hogtiedPromptDelayMs = 500,
    permissionRecheckMs = 500,
    jobFirstAskMs = 2000,
    jobRetryMs = 1000,
    jobRefreshMs = 60000,       -- re-read the job even when one is known
    promptGroupDelayMs = 1000,
    openReplyTimeoutMs = 6000,  -- client gives up waiting for the server's answer
    panelOpenTimeoutMs = 4000,  -- client gives up waiting for the steal panel
    inputLostMs = 1500,         -- amount panel gone with no answer: back to the menu
    afterItemMs = 100,
    afterWeaponMs = 100,
    purgeFirstPollMs = 8000,
    purgePollMs = 10000,
}

-- per-source minimum gap between net requests, milliseconds
SearchConfig.RateLimit = {
    getjob = 800,
    getinfo = 1000,
    takecash = 1000,
    reload = 500,
    transfer = 150,   -- a refused-for-speed drag still gets its panel refresh
}

-- what changes while pup-events has 'purge' live
SearchConfig.Purge = {
    eventKey = 'purge',
    deadSearch = true,
    shieldMinutes = 0,
    protectedJobs = {},
    maxStacks = 999,
    windowMinutes = 0,
    blacklistItems = {},
    blacklistPrefixes = {},
    blacklistWeapons = {},
}
