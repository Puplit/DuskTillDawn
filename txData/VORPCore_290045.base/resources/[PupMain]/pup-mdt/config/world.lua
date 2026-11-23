-- pup-mdt | alerts, public records, tips, bounty board, evidence lockers, zones (shared)

Config.Alerts = {
    enabled = true,
    timer = 900,                 -- seconds before a non-persistent alert expires
    gps = false,
    blip = { sprite = 2119977580, scale = 0.2 },
    popupMs = 7000,
    maxClient = 10,
    maxTextLength = 200,
    clientExportCooldown = 30,   -- seconds between client-export alerts per player
    clientExportMaxDistance = 100.0,
    commands = {
        { command = 'down',     message = 'Lawman Down',   persistent = true, cooldown = 0,  lawOnly = true },
        { command = 'backup',   message = 'Backup Needed', persistent = true, cooldown = 0,  lawOnly = true },
        { command = 'alertlaw', message = 'Lawman Alert',  persistent = true, cooldown = 60, lawOnly = false },
    },
    cancelCommand = 'cancelalert',
}

Config.RadiusAlerts = {
    enabled = true,
    testCommand = 'drugalert',
    testEnabled = false,   -- the test command; when on, admins only (ace command.<testCommand>)
    testCooldown = 30,
    clearCommand = 'cleardrugalerts',
    label = 'Suspected Drug Deal',
    radius = 80.0,
    colour = 'BLIP_MODIFIER_MP_COLOR_2',
    sprite = 'blip_attention',
    duration = 120,
    lawOnly = true,
    notify = true,
    notifyText = 'Suspected drug sale reported',
    notifyMs = 8000,
    exportChance = 35,
}

Config.PublicRecords = {
    enabled = true,
    showPenalCode = true,
    promptDistance = 2.0,
    serverDistance = 6.0,         -- the server's own presence check
    label = 'View Criminal Record',
    header = 'Public Records',
    blip = { enabled = true, label = 'Public Records', sprite = 'blip_ambient_sheriff', scale = 0.2 },
    spots = {
        vector3(2511.95, -1308.98, 48.95),
        vector3(-353.860, 833.540, 117.017),
    },
    searchPerPage = 18,
    inmatesPerPage = 20,
    bountiesPerPage = 8,
    rateLimitMs = 750,
}

Config.Tips = {
    enabled = true,
    allowAnonymous = true,
    cooldownSeconds = 60,
    maxLength = 300,
    notifyLawmen = false,
    discord = true,
}

Config.BountyBoard = {
    enabled = true,
    extraJobs = { 'bvbounty' },
    coords = vector3(2513.25, -1305.1, 48.95),
    promptDistance = 2.0,
    label = 'Bounty Board',
    blip = { enabled = true, label = 'Bounty Board', sprite = 'blip_ambient_bounty_hunter', scale = 0.2 },
    captureRadius = 6.0,
    claimDistance = 3.0,          -- the server's own check: hunter and target this close
    hintLevel = 'region',
    hintCooldownMinutes = 30,
    onlineOnly = true,
    reviveOnCapture = true,
    payHunter = true,
    fineCriminal = true,
    claimCooldownMinutes = 60,
    checkTimeoutSeconds = 8,
}

Config.Evidence = {
    enabled = true,
    jobs = { 'police' },
    requireDuty = true,
    stationRadius = 30.0,
    promptDistance = 2.5,
    targetDistance = 10.0,
    stations = {
        { id = 'valentine',  label = 'Valentine',  coords = vector3(-283.816, 808.153, 115.001) },
        { id = 'rhodes',     label = 'Rhodes',     coords = vector3(1361.327, -1305.834, 77.411) },
        { id = 'annesburg',  label = 'Annesburg',  coords = vector3(2906.829, 1315.414, 44.588) },
        { id = 'strawberry', label = 'Strawberry', coords = vector3(-1813.876, -354.970, 164.299) },
        { id = 'blackwater', label = 'Blackwater', coords = vector3(-764.851, -1272.531, 43.691) },
        { id = 'armadillo',  label = 'Armadillo',  coords = vector3(-3623.466, -2602.065, -13.693) },
        { id = 'tumbleweed', label = 'Tumbleweed', coords = vector3(-5526.588, -2928.456, -1.711) },
    },
}

-- zone lookups: native zone types checked by the client, and the bounty hint types
Config.Zones = {
    lookupTypes = { 0, 12, 13, 10, 1 },
    hintTypes = { town = { 1, 10, 0 }, region = { 0, 10, 1 } },
    nearRange = 3000.0,
}

-- screen theme hints (the page owns the look)
Config.Theme = {
    name = 'Dusk County Law',
    boardColor = '#6b4a2b',
}
