-- pup-medical | main settings

Config = {}
Config.Keys = {} -- each config file adds its own prompt keys

Config.General = {
    language = 'en',      -- text is in config/locale.lua
    debug = {             -- console / F8 traces per module
        alerts  = false,
        callPay = false,
        death   = false,
        duty    = false,
        medical = false,
    },
}

Config.Integrations = {
    business = { resource = 'pup_business' }, -- duty roster fallback; /med needs its on-duty state
    events   = { resource = 'pup-events' },   -- purge event (Config.Purge)
}

Config.Logs = {
    avatarUrl = "", -- Discord avatar for revive / duty logs ("" = webhook default)
}

-- built-in /duty
Config.Duty = {
    command = "duty",
    jobs    = { "doctor", "pharmacist", "drbarber", "standardtrain" },
    RestartLockMinutes = 5, -- minutes before a txAdmin scheduled restart (fires on its 30/15/10/5/4/3/2/1 min warnings); 0 = off
}

-- while the pup-events purge is live, these replace keys of Config.Death.prompt
Config.Purge = {
    eventKey  = 'purge',
    overrides = {
        respawnDelaySeconds = 10,
    },
}
