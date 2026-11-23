Config = Config or {}

Config.Items = {
    trap = 'beartrap',
    oil  = 'trapoil', -- kept as an item for existing satchels; no feature uses it
}

-- lures in bait-menu order (item ids are shared with other resources, so they stay as they are)
Config.Lures = {
    { item = 'biggame',     label = 'Raw big game cut' }, -- bears at night, wolves, the big cats
    { item = 'stringy',     label = 'Stringy scraps' },   -- coyotes, the boa
    { item = 'game',        label = 'Fresh game meat' },  -- foxes
    { item = 'fishmeat',    label = 'Fish guts' },        -- gators, the river bear
    { item = 'honey',       label = 'Honeycomb' },        -- bears by day
    { item = 'corn',        label = 'Cracked corn' },     -- boars
    { item = 'Wild_Carrot', label = 'Wild carrots' },     -- deer, elk, moose, beavers
    { item = 'salt',        label = 'Salt lick' },        -- rams, bison, pronghorn
}

Config.Keys = {
    shop     = 0x760A9C6F, -- G
    place    = 0xC7B5340A, -- ENTER
    putAway  = 0x156F7119,
    take     = 0x156F7119,
    lure     = 0x05CA7C52,
    activate = 0xC7B5340A, -- ENTER
}

Config.Integrations = {
    perks         = 'pup-perks',
    perkKey       = 'legendary_call_speed',
    ecoBoost      = 'pup-misc',
    ecoBoostPlace = 'Legendary Trapper',
}

Config.Hunt = {
    legendaryHealth  = 250.0,
    cooldownMinutes  = 120,  -- real minutes
    callSeconds      = 30,   -- seconds
    activateSeconds  = 570,  -- seconds
    spawnMin         = 50.0, -- metres
    spawnMax         = 80.0,
    alertSprite      = -1085232344,
    alertModifier    = 0x5426DAB6,
    alertSeconds     = 60,
    wanderFirstMs    = 10000, -- ms
    reachTrapMetres  = 10.0,  -- metres
    roamRadius       = 40.0,
    replyTimeoutMs   = 15000, -- ms
    serverMinWait    = true,
    fighters = {
        'mp_a_c_bear_01', 'mp_a_c_wolf_01', 'mp_a_c_panther_01', 'mp_a_c_cougar_01',
        'mp_a_c_alligator_01', 'a_c_alligator_02', 'mp_a_c_boar_01', 'a_c_boarlegendary_01',
        'a_c_bear_01', 'A_C_Wolf', 'a_c_cougar_01', 'a_c_boar_01', 'a_c_snakeredboa10ft_01',
    },
}

Config.Trap = {
    model         = 's_beartrapanimated01x',
    poseDict      = 'script_re@bear_trap',
    openClip      = 'recover_loop_b_trap',
    shutClip      = 'callout_back_l_trap',
    boneMale      = 299,
    boneFemale    = 366,
    handOffset    = vector3(0.11, -0.08, -0.01),
    handRotation  = vector3(0.0, -13.0, 0.0),
    ghostAlpha    = 51,
    ghostForward  = 0.5,
    ghostDown     = 0.8,
    useRange      = 1.5,
    placeAnim     = { dict = 'mini_games@story@beechers@build_roof@john_part2', clip = 'putdowntile_m', ms = 3000 },
    pickupAnim    = { dict = 'amb_work@world_human_box_pickup@1@male_a@stand_exit_withprop', clip = 'exit_front', ms = 1500 },
    baitAnim      = { dict = 'amb_player@world_player_place_bait@crouch_rest@base', clip = 'base', ms = 1400 },
}

Config.Trapper = {
    model       = 'u_m_m_sdtrapper_01',
    coords      = vector4(1251.39, 1156.23, 150.2, 306.22),
    name        = 'Fur Buyer',
    showBlip    = true,
    blipSprite  = -1406874050,
    useRange    = 2.0,
    serverRange = 10.0, -- metres
}

Config.Discord = {
    avatar = '', -- '' = Discord's default
    rateLimitSeconds = 60,
}

Config.Options = {
    tellWhyNothingComes = false,
}

Config.LocaleOverrides = {}

Config.Text = {
    baitLine      = 'Lure: %s',
    areaLine      = 'Ground: %s',
    none          = 'None',
    fallbackName  = 'That one',
    noRoomReturn  = 'No room in your satchel for the trap. It will come back to you once there is space.',
    trapOwed      = 'A hunting trap you left set has been put back in your satchel.',
    replyTimeout  = 'Nothing stirs. Take the trap up and set it again later.',
    whyNoBeast    = 'No legendary roams this ground.',
    whyWrongLure  = 'Nothing that roams here will come for this lure.',
    whyWrongHour  = 'Wrong time of day. What this lure calls here is not out now.',
    busy          = 'Wait a moment.',
}
