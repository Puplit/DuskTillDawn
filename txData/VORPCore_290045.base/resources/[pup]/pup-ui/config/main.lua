-- pup-ui | main settings

Config = Config or {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug = false,                   -- client F8 traces
}

-------------------------------------------------------------------------------
-- PROGRESS BAR
-------------------------------------------------------------------------------
Config.Progress = {
    style = 'line',                  -- default look: 'line' (label and a thin line) or 'ring' (round fill); players pick their own in /hud
}

-------------------------------------------------------------------------------
-- POSSE
-------------------------------------------------------------------------------
Config.Posse = {
    maxSize       = 5,               -- leader included
    commands      = { 'pose', 'posse' },
    commandLabel  = 'pose',
    inviteRadius  = 20.0,            -- metres; nil = anywhere
    debug         = false,
}
