Config.TrickOrTreat = {
    enabled = true,

    doorsPerNight = nil, -- nil = every door; otherwise { min, max }

    knocksPerCharacter = { 5, 10 }, -- min, max; nil = no cap

    resetMinutes   = 10,   -- minutes
    detectRadius   = 70.0, -- metres
    promptDistance = 2.2,  -- metres
    promptHoldMs   = 700,  -- ms

    knock = {
        scenario = 'PROP_PLAYER_KNOCK_SECURITY_DOOR',
        sound    = 'BATHING_DOOR_KNOCK_MASTER',
        seconds  = 3.5,                               -- seconds
        label    = 'Knocking...',
    },

    cooldownMinutes = 30, -- minutes, per character per door

    trickChance = 45, -- percent

    blips = {
        enabled = true,
        sprite  = 'blip_ambient_ghost',
        label   = 'Trick or Treat',
    },

    props = {
        treat = { 'p_cs_lootsack01x', 'p_cs_lootsack02x', 'p_cs_lootsack03x' },
        trick = { 'p_pumpkin_01x', 'p_pumpkin_01bx', 'p_pumpkin_02x' },
    },

    -------------------------------------------------------------------------------
    -- TREAT
    -------------------------------------------------------------------------------
    treat = {
        rolls = { 1, 3 }, -- min, max
        loot = {
            -- what is in the sack most of the time
            { item = 'berry_goodness', amount = 1, chance = 11.6 },
            { item = 'dirty_grave',    amount = 1, chance = 11.6 },
            { item = 'ginger_dracula', amount = 1, chance = 10.6 },
            { item = 'sour_souls',     amount = 1, chance = 10.6 },
            { item = 'witches_brew',   amount = 1, chance = 10.6 },
            { item = 'money',          amount = 35, chance = 19, kind = 'money' },
            { item = 'stim',           amount = 1, chance = 5 },

            -- uncommon: pup-misc props (ordinary items that place or hold a prop)
            { item = 'pup_candle',      amount = 1, chance = 6 },
            { item = 'pup_candle_lamp', amount = 1, chance = 5 },
            { item = 'pup_ring5',       amount = 1, chance = 4 },
            {
                item = 'pup_skull', amount = 1, chance = 3,
                announce = 'It was not a sweet. You are holding somebody.',
            },

            -- rare, 2.95% together
            {
                item = 'pup_cane_skull', amount = 1, chance = 0.25, once = 'cane',
                announce = 'A cane, too fine for this porch, with a skull for a head.',
            },
            {
                item = 'WEAPON_MELEE_MACHETE_HORROR', chance = 0.5, kind = 'weapon',
                announce = 'There is something heavy in the bottom of the sack.',
            },
            {
                item = 'WEAPON_MELEE_KNIFE_HORROR', chance = 1, kind = 'weapon',
                announce = 'Whatever this was used for, it was not food.',
            },
            {
                item = 'WEAPON_MELEE_CLEAVER', chance = 1, kind = 'weapon',
                announce = 'Still wet. You decide not to think about it.',
            },
            {
                item = 'WEAPON_MELEE_LANTERN_HALLOWEEN', chance = 0.2, kind = 'weapon',
                announce = 'A lantern, and the skull it was cut from is still looking at you.',
            },
        },

        weaponOncePerNight = true,
        rerollTries = 3,
        deadDrawPay = 25,          -- $
    },

    -------------------------------------------------------------------------------
    -- TRICK
    -------------------------------------------------------------------------------
    trick = {
        count   = { 2, 3 },     -- min, max
        health  = 100,
        sense   = 60.0,         -- metres
        stareMs = { 900, 1800 },-- ms, min, max
        noCriticals = false,
        noRagdoll   = false,
        noShove     = false,
        moveRate    = 1.15,     -- 1.0 = normal
        weapon  = 'WEAPON_MELEE_MACHETE_HORROR',
        maxHitFraction = 0.2,   -- share of your health
        damageModifier = 0.25,  -- 1.0 = full player-strength hit
        gore    = false,
        despawnSeconds = 90,    -- seconds
    },
}
