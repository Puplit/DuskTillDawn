Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    writeLogFiles = true,
    dropLogFile   = 'pup-drops.log',  -- flat filename: SaveResourceFile cannot create folders
    serverLogFile = 'pup-server.log',
}

-------------------------------------------------------------------------------
-- DROPS
-------------------------------------------------------------------------------
Config.Drops = {
    beaconPreSessionMs = 2000,  -- ms, while getting in
    beaconInSessionMs  = 30000, -- ms, once in the world

    hitchMs = 1000,             -- ms

    creatorCoords = vector3(-558.5, -3781.1, 238.6),
    creatorRadius = 80.0, -- metres

    onlyPreSession = true,
}

-------------------------------------------------------------------------------
-- SERVER LOAD
-------------------------------------------------------------------------------
Config.ServerLoad = {
    tickIntervalMs = 100,  -- ms
    warnMs         = 500,  -- ms late
    alertMs        = 2000, -- ms late
    reportSeconds  = 300,  -- seconds
}

-------------------------------------------------------------------------------
-- RESOURCES
-------------------------------------------------------------------------------
Config.Resources = {
    enabled            = true,
    stormCount         = 3,
    stormWindowSeconds = 300,  -- seconds
}

-------------------------------------------------------------------------------
-- SYNC CHECK
-------------------------------------------------------------------------------
Config.SyncCheck = {
    enabled         = true,
    graceSeconds    = 45,   -- seconds
    intervalSeconds = 5,    -- seconds
    timeoutSeconds  = 10,   -- seconds
    maxProbes       = 36,
    strikes         = 3,
    clearSamples    = 3,

    color = { 168, 50, 50 }, -- { r, g, b }
    x     = 0.5,             -- 0.0 - 1.0 from the left
    y     = 0.18,            -- 0.0 - 1.0 from the top
}
