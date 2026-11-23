-- pup_shaman | rituals (The Unbinding and The Binding)

Config = Config or {}

Config.Ritual = {
    enabled          = true,
    command          = 'ritual',
    needTree         = false, -- must begin beside an ancient tree
    treeReach        = 15.0,
    beginRange       = 3.0,   -- leader to the person
    stayRange        = 9.0,   -- everyone to the fire (also the join range)
    viewRange        = 60.0,  -- scene sent to players this close
    answerSeconds    = 20,
    kindleSeconds    = 6,
    circleSeconds    = 45,
    verseSeconds     = 25,
    drawSeconds      = 6,
    marks            = 3,
    ringRadius       = 4.0,
    markReach        = 1.6,
    markSlack        = 0.5,
    markResendMs     = 1500,
    maxHelpers       = 4,
    helperWidth      = 4,
    perfectZone      = 6,
    widestZone       = 60,
    points           = { perfect = 2, success = 1, failed = 0 },
    liftAt           = 3,     -- strength needed to lift or bind
    easeAt           = 1,     -- strength needed to ease a harmful curse
    backlash         = { share = 0.25, floor = 50, ragdollMs = 1500, effectMs = 4000 },
    verseMinMs       = 1000,  -- ms; a faster answer scores 0
    perfectMinMs     = 1500,  -- ms; a faster "perfect" counts as a success
    chant = {
        unbinding = {
            'Old earth, you were here before the first fire. Hear this one.',
            'What was tied to this body, we untie. What was fed, we starve.',
            'Let it go down into the ground, and let it stay there.',
        },
        binding = {
            'Old earth, you were here before the first fire. Hear this one.',
            'This one comes willing. What sleeps in the ground, let it wake in them.',
            'Let it take hold, and let it stay.',
        },
    },
    -- presentation (game content names)
    look = {
        pray       = { dict = 'amb_misc@world_human_pray_rosary@base', clip = 'base' },
        crouch     = 'WORLD_HUMAN_CROUCH_INSPECT',
        markCrouchMs = 1200,
        fire       = { model = 'p_campfire02xb', below = 0.9 },
        marker     = { type = 0x6903B113, size = vector3(1.0, 1.0, 0.25), below = 0.95 },
        walked     = { 255, 120, 40 },
        unwalked   = { 230, 220, 200 },
        alphaNext  = 170,
        alphaOther = 80,
        light      = { color = { 255, 130, 50 }, below = 0.3, range = 9.0, intensity = 35.0, flicker = 3.0,
                       drawRange = 16.0, drawIntensity = 90.0 },
        drawEffect = 'PlayerWakeUpInterrogation',
        successEffect = 'RespawnPulse01',
        chime      = { name = 'Ready_Up_Flash', set = 'RDRO_In_Game_Menu_Sounds' },
        bar        = { style = 'default', icon = 'fa-solid fa-fire', scale = 0.7, orientation = 1, movingIcon = false },
        toast      = { symbol = 'fire', ms = 6000 },
    },
}

local RANKS <const> = {
    { grade = 0, title = 'Initiate', lead = false },
    { grade = 1, title = 'Keeper', lead = true, cooldownMinutes = 15, lift = { 'weak' },
      barWidth = 26, barSpeed = 0.30 },
    { grade = 2, title = 'Healer', lead = true, cooldownMinutes = 10, lift = { 'weak' },
      barWidth = 32, barSpeed = 0.26 },
    { grade = 3, title = 'Elder', lead = true, cooldownMinutes = 5, lift = { 'weak', 'lycan', 'vamp', 'bear', 'witch' },
      give = { 'bear', 'lycan' }, barWidth = 38, barSpeed = 0.22 },
}

-- price = cash the person pays the leader if the ritual works
Config.Tribes = {
    shaman = {
        label = 'Shaman',
        lift = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 1 },
            { item = 'Yarrow', label = 'Yarrow', count = 3 },
            { item = 'Wild_Mint', label = 'Wild Mint', count = 2 },
        } },
        bind = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 3 },
            { item = 'Yarrow', label = 'Yarrow', count = 6 },
            { item = 'Wild_Mint', label = 'Wild Mint', count = 4 },
        } },
        ranks = RANKS,
    },
    vttribe = {
        label = 'Valentine Tribe',
        lift = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 1 },
            { item = 'American_Ginseng', label = 'American Ginseng', count = 3 },
            { item = 'Wild_Mint', label = 'Wild Mint', count = 2 },
        } },
        bind = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 3 },
            { item = 'American_Ginseng', label = 'American Ginseng', count = 6 },
            { item = 'Wild_Mint', label = 'Wild Mint', count = 4 },
        } },
        ranks = RANKS,
    },
    bvtribe = {
        label = 'Big Valley Tribe',
        lift = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 1 },
            { item = 'Alaskan_Ginseng', label = 'Alaskan Ginseng', count = 3 },
            { item = 'Creeking_Thyme', label = 'Creeping Thyme', count = 2 },
        } },
        bind = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 3 },
            { item = 'Alaskan_Ginseng', label = 'Alaskan Ginseng', count = 6 },
            { item = 'Creeking_Thyme', label = 'Creeping Thyme', count = 4 },
        } },
        ranks = RANKS,
    },
    bwtribe = {
        label = 'Blackwater Tribe',
        lift = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 1 },
            { item = 'Oleander_Sage', label = 'Oleander Sage', count = 3 },
            { item = 'Red_Sage', label = 'Red Sage', count = 2 },
        } },
        bind = { price = 0, offering = {
            { item = 'herbmed', label = 'Herbal Remedy', count = 3 },
            { item = 'Oleander_Sage', label = 'Oleander Sage', count = 6 },
            { item = 'Red_Sage', label = 'Red Sage', count = 4 },
        } },
        ranks = RANKS,
    },
}
