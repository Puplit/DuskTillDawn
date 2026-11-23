Config.PurgeCaches = {
    enabled  = true,
    distance = 2.0,  -- metres
    limit    = 40,   -- slots; 0 = unlimited

    firstCacheMinutes = 2,  -- minutes
    respawnMinutes    = 20, -- minutes
    expireMinutes     = 25, -- minutes; 0 = never
    lingerSeconds     = 60, -- seconds

    minigame   = 'lockpick',
    difficulty = 3,
    lockpickitem = { name = 'lockpick', label = 'Lockpick' },
    pryTime    = 8000,                                       -- ms

    guardDefaults = {
        count   = 6,
        radius  = 20.0, -- metres
        trigger = 80.0, -- metres
        models  = { 'U_M_M_UniBountyHunter_01', 'U_M_M_UNIONLEADER_01', 'U_M_M_RhdBackupDeputy_02' },
        weapons = { 'weapon_repeater_henry', 'weapon_rifle_boltaction', 'weapon_shotgun_pump' },
    },

    blip = {
        sprite = -1357626643,
        scale  = 0.2,
    },

    prop = 'P_CRATE01X_VAR02', -- nil = blip only
}
