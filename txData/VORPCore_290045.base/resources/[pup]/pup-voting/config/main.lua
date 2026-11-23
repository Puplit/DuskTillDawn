-- pup-voting | main settings (see README.md)

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    command = 'election',
}

Config.Keys = {
    vote = 0x760A9C6F,                 -- G
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
Config.Integrations = {
    vorpAdmin = { action = 'manage_elections' },
}

-------------------------------------------------------------------------------
-- ELECTION
-------------------------------------------------------------------------------
Config.Election = {
    regions = {                        -- menu order
        'New Hanover',
        'Lemoyne',
        'West Elizabeth',
        'Ambarino',
        'New Austin',
    },
    durationsHours = { 24, 48, 72, 168 }, -- hours
    defaultDurationHours = 48,         -- hours
    minVotesForShare = 5,              -- 0 = always show
    defaultEnabled = true,             -- first run only
}

-------------------------------------------------------------------------------
-- POLLING STATIONS
-------------------------------------------------------------------------------
Config.Polling = {
    radius = 2.0,                      -- metres
    locations = {
        vector3(2593.95, -1305.88, 52.71),    -- Saint Denis
        vector3(-797.148, -1199.445, 43.838), -- Blackwater
    },
}

-------------------------------------------------------------------------------
-- LOGGING
-------------------------------------------------------------------------------
Config.Logging = {
    name        = 'Election Office',
    colour      = '3447003',           -- decimal, as a string
    logo        = '',                  -- '' = none
    footer      = '',
    avatar      = '',                  -- '' = none
    votes       = true,
    identifiers = false,
}
