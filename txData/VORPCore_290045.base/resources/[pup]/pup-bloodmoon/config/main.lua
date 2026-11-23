
Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    command     = 'bloodmoon',
    adminGroups = { admin = true, superadmin = true },
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
Config.Integrations = {
    shaman = {
        wolfModels   = { 'A_C_Wolf', 'MP_A_C_WOLF_01' },
        requireCurse = 'lycan',                          -- nil = no curse check
    },
}

-------------------------------------------------------------------------------
-- MOON
-------------------------------------------------------------------------------
Config.Moon = {
    defaultLook          = 1,     -- index into Config.Looks
    transitionInSeconds  = 30.0,  -- seconds
    transitionOutSeconds = 30.0,  -- seconds
    durationMinutes      = 0,     -- real minutes; 0 = until dawn
}

-------------------------------------------------------------------------------
-- NIGHT WINDOW
-------------------------------------------------------------------------------
Config.Night = {
    enabled  = true,
    fromHour = 20,     -- in-game hour, 0-23
    toHour   = 5,      -- in-game hour, 0-23; may wrap past midnight
}

-------------------------------------------------------------------------------
-- HOWL
-------------------------------------------------------------------------------
Config.Howl = {
    enabled         = true,
    cooldownMinutes = 120,    -- real minutes, server-wide
    sites = {
        { label = 'The howling ground', coords = vector3(1003.714, 1703.744, 379.191), radius = 40.0 },
    },
}

-------------------------------------------------------------------------------
-- LOOKS
-------------------------------------------------------------------------------
Config.Looks = {
    { label = 'Misty - lightest, moon stays visible', weather = 'MISTY',        variation = true },
    { label = 'Fog - heaviest',                       weather = 'FOG',          variation = true },
    { label = 'Shower - rain',                        weather = 'SHOWER',       variation = true },
    { label = 'Thunderstorm',                         weather = 'THUNDERSTORM', variation = true },
    { label = 'Clear sky, no red',                    weather = 'sunny' },
}
