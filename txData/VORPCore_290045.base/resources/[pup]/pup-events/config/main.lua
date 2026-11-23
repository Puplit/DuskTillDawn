Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug   = false,
    command = 'event',

    adminGroups     = { admin = true, superadmin = true },
    adminPermission = 'open_menu',

    tickSeconds = 15, -- seconds, min 5

    announceCooldownMinutes = 120, -- real minutes
}

Config.Keys = {
    easterPickup = 0x760A9C6F,              -- G
    purgeCache   = 0x760A9C6F,              -- G
    trickOrTreat = 'INPUT_FRONTEND_ACCEPT', -- control name, not a hash
}

-------------------------------------------------------------------------------
-- LOGS
-------------------------------------------------------------------------------
Config.Logs = {
    serverName = 'Dusk Till Dawn',

    easter = {
        pingEveryone  = false,
        colorGold     = 16766720,
        colorOpenGold = 15844367,
    },

    trickOrTreat = {
        pingEveryone = false,
        colorTreat   = 16747520,
        colorRare    = 10181046,
        colorTrick   = 10038562,
        colorRound   = 3092790,
    },
}
