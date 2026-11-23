Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug         = false,
    locale        = 'en',         -- locales/<locale>.json
    toggleCommand = 'togglelock',
}

Config.Keys = {
    selectDoor = 0x17BEC168, -- E
    cancel     = 0x8CC9CD42, -- X
    toggleLock = 0x17BEC168, -- E
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
Config.Integrations = {
    vorpAdmin = { permission = 'manage_doorlocks' },

    pupUi = { doorSound = true },
}

-------------------------------------------------------------------------------
-- INTERACTION
-------------------------------------------------------------------------------
Config.Interaction = {
    markerRadius = 2.0, -- metres
    reachRadius  = 1.5, -- metres; capped at markerRadius
}

Config.Marker = {
    enabled = true,
    key     = 'E',  -- keep in step with Config.Keys.toggleLock
    labels  = {
        locked = 'Locked', -- false = show nothing
        unlock = 'Unlock',
        lock   = 'Lock',
    },
}

Config.Notifications = {
    interaction = false,
    admin       = true,
    lockpick    = true,
}

-------------------------------------------------------------------------------
-- ENFORCEMENT
-------------------------------------------------------------------------------
Config.Enforcement = {
    enabled    = true,
    radius     = 25.0, -- metres
    intervalMs = 200,  -- ms
}

-------------------------------------------------------------------------------
-- LOCKPICKING
-------------------------------------------------------------------------------
Config.Lockpicking = {
    itemName        = 'lockpick', -- '' = no lockpicking
    minigame        = true,
    pinGame         = true,         -- use the pin game from the `lockpick` resource while it is running
    pinHint         = 'Turn the pick to find the sweet spot, then turn the lock',
    game            = 'safe_crack', -- without the pin game: 'safe_crack', 'skill_bar' or 'skill_circle'
    difficultyLocks = 3,          -- safe_crack: 1-5
    attempts        = 3,          -- safe_crack: wrong presses allowed; 0 = unlimited
    skillBar        = { areaSize = 20, perfectAreaSize = 5, speed = 0.5 },
    skillCircle     = { areaSize = 4, speed = 0.02 },
    hint            = 'Turn the dial slowly - stop when you feel the lock give',
    removeOnUse     = false,
    removeOnFail    = true,
    reach           = 3.0,        -- metres from the door, checked by the server
    cooldownMs      = 5000,       -- ms between pick attempts
    minTimeMs       = 4000,       -- ms; a win sooner than this counts as a fail
    maxTimeMs       = 180000,     -- ms; an unanswered pick expires
}

-------------------------------------------------------------------------------
-- LAW ALERT
-------------------------------------------------------------------------------
Config.LawAlert = {
    chance = 60,     -- percent, 0-100
    radius = 500.0,  -- metres
    jobs   = {
        'SDPolice',
        'ValSheriff',
        'RhoSheriff',
    },
    notification = {
        title      = 'Breakin Attempt',
        dict       = 'generic_textures',
        icon       = 'lock',
        color      = 'COLOR_WHITE',
        durationMs = 8000,               -- ms
    },
    blip = {
        hash       = -1282792512,
        radius     = 5,
        durationMs = 60000,       -- ms
    },
}

-------------------------------------------------------------------------------
-- ADMIN
-------------------------------------------------------------------------------
Config.Admin = {
    openAll = {
        enabled    = true,
        ace        = 'doorlocks.openall',
        group      = 'admin',
        consoleLog = true,
    },
    create = {
        enabled = true,
        command = 'createdoor',
        ace     = 'doorlocks.create',
        group   = 'admin',
    },
    edit = {
        enabled       = true,
        command       = 'editdoor',
        ace           = 'doorlocks.edit',
        group         = 'admin',
        deleteConfirm = 'delete',
    },
}

-------------------------------------------------------------------------------
-- CUSTOM DOORS
-------------------------------------------------------------------------------
Config.CustomDoors = {
    matchRadius = 1.5, -- metres
}
