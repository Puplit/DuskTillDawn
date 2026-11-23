Config = {}

-------------------------------------------------------------------------------
-- NOTICES: what can be pinned, and for how long
-------------------------------------------------------------------------------
Config.Notices = {
    expireHours  = 48,              -- hours a notice stays up
    perCharacter = 10,              -- notices one character may have up at once, 0 = no limit
    kinds        = { text = true, picture = true },  -- false = that kind is off on every board
    refusedHosts = {},              -- image hosts refused everywhere, e.g. { 'example.com' }
}

-------------------------------------------------------------------------------
-- STAFF: who may do more than pin and take down their own notices
-------------------------------------------------------------------------------
Config.Staff = {
    takeDownAny = {
        groups = { admin = true, moderator = true },
        jobs   = { police = false, sheriff = false },
    },
    pinToAllBoards = {
        groups     = { admin = true },
        characters = {},            -- ['First Last'] = true
    },
}

-------------------------------------------------------------------------------
-- COMMAND (admin group or the server console)
-------------------------------------------------------------------------------
Config.Command = {
    wipe = 'wipenotices',           -- takes down every notice on every board
}

-------------------------------------------------------------------------------
-- PROMPT AND BLIPS
-------------------------------------------------------------------------------
Config.Prompt = {
    key    = 0x760A9C6F,            -- G
    radius = 1.6,                   -- metres
}

Config.Blip = {
    show   = true,                  -- false = no board blips at all (one board: blip = false in boards.lua)
    sprite = 1735233562,            -- game blip sprite hash, or a 'blip_*' name
    scale  = 1.0,
    label  = 'Town Notices',
}

-------------------------------------------------------------------------------
-- SCREEN
-------------------------------------------------------------------------------
Config.Screen = {
    toastMs      = 4000,            -- ms
    confirmToast = false,           -- true = a message after pinning or taking down (refusals always show)
}

-------------------------------------------------------------------------------
-- ECO BOOST BUTTON
-------------------------------------------------------------------------------
Config.EcoBoost = {
    resource = 'pup-misc',
}

-------------------------------------------------------------------------------
-- LOGGING (webhook URL is in server/config.lua)
-------------------------------------------------------------------------------
Config.Logging = {
    webhookUsername = 'Somebody',
}
