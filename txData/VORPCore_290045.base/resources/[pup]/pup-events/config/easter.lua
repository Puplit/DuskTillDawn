Config.Easter = {
    itemName     = 'easter_egg',
    goldItemName = 'easter_egg_gold',
    itemAmount   = 1,
    goldEggChance = 0.5,              -- percent (0.5 = 0.5%)

    -------------------------------------------------------------------------------
    -- REGIONS
    -------------------------------------------------------------------------------
    regions = {
        { name = 'The Heartlands', x1 =  -400.0, y1 =  -200.0, x2 =  1900.0, y2 =  1600.0 },
        { name = 'New Hanover',    x1 =  1500.0, y1 =   200.0, x2 =  3100.0, y2 =  1900.0 },
        { name = 'Lemoyne',        x1 =  1100.0, y1 = -1900.0, x2 =  3000.0, y2 =  -200.0 },
        { name = 'West Elizabeth', x1 = -2400.0, y1 = -1400.0, x2 =  -700.0, y2 =  1000.0 },
        { name = 'Big Valley',     x1 = -2200.0, y1 =   100.0, x2 =  -900.0, y2 =  1400.0 },
        { name = 'Great Plains',   x1 = -2100.0, y1 = -1900.0, x2 =  -900.0, y2 =  -700.0 },
        { name = 'Ambarino',       x1 =  -900.0, y1 =  1500.0, x2 =  1200.0, y2 =  2300.0 },
        { name = 'New Austin',     x1 = -4200.0, y1 = -3200.0, x2 = -2400.0, y2 = -1600.0 },
    },

    -------------------------------------------------------------------------------
    -- PATCHES
    -------------------------------------------------------------------------------
    patches = {
        count        = { 6, 8 },   -- min, max
        radius       = 55.0,       -- metres
        eggs         = { 14, 20 }, -- min, max
        minSpacing   = 2.0,        -- metres
        resetMinutes = 60,         -- minutes
        detectRadius = 180.0,      -- metres
        pickupLimit  = 5,          -- per character, per patch, per reset
    },

    blips = {
        enabled = true,
        sprite  = 'blip_mp_animal_rabbit',
        label   = 'Egg Hunt',
    },

    -------------------------------------------------------------------------------
    -- RABBITS
    -------------------------------------------------------------------------------
    rabbits = {
        enabled     = true,
        -- not mp_a_c_rabbit_01, which renders invisible
        model       = 'a_c_rabbit_01',
        count       = { 6, 9 },        -- min, max
        spawnRadius = 30.0,            -- metres
        scale       = 1.4,             -- 1.0 = normal
    },

    -------------------------------------------------------------------------------
    -- PICKUP
    -------------------------------------------------------------------------------
    pickup = {
        distance           = 1.6, -- metres
        validationDistance = 3.0, -- metres
        promptHoldMs       = 800, -- ms
        anim = {
            dict = 'script_proc@robberies@homestead@lonnies_shack@stash@floor@l',
            name = 'base',
            flag = 0,
            handoffMs      = 3500,                             -- ms
            propRemoveMs   = 2300,                             -- ms
            handBone       = 'SKEL_R_HAND',
            attachOffset   = vector3(0.0976, 0.0256, -0.1413),
            attachRotation = vector3(0.0, 0.0, 0.0),
        },
    },

    eggModels = {
        'easteregg1', 'easteregg2', 'easteregg3', 'easteregg4',
        'easteregg5', 'easteregg6', 'easteregg7', 'easteregg8',
    },

    -------------------------------------------------------------------------------
    -- LOOT  (higher weight = more common)
    -------------------------------------------------------------------------------
    normalLoot = {
        { item = 'cakecarrot',        amount = 1,   weight = 30 },
        { item = 'lemonad',           amount = 3,   weight = 30 },
        { item = 'stim2',             amount = 2,   weight = 25 },
        { item = 'money',             amount = 100, weight = 15 },
    },

    goldLoot = {
        { item = 'shovel_weapon',      amount = 1, weight = 25 },
        { item = 'pup_cross_necklace', amount = 1, weight = 25 },
        { item = 'horse_coat_changer', amount = 1, weight = 25 },
    },
}
