Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    command = 'emotes',
}

Config.Keys = {
    openWheel = nil, -- control hash; nil = players bind it themselves

    quickSlots = {
        0xF311100C, -- 1
        0x72BAD5AA, -- 2
        0x661857B3, -- 3
        0x470DC190, -- 4
    },
}

-------------------------------------------------------------------------------
-- WHEEL
-------------------------------------------------------------------------------
Config.Wheel = {
    sets  = 4, -- max 16
    slots = 4, -- max 16; quick keys cover the first 4
}
