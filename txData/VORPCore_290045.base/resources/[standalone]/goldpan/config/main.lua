Config = Config or {}

Config.PanItem = 'goldpan' -- usable item, never consumed

Config.Options = {
    WorkTimer      = 10,    -- seconds (swirl animation length with the skill bar)
    SettleMs       = 1500,  -- ms
    ScoopMs        = 6000,  -- ms
    SwirlExtraMs   = 1500,  -- ms added to the swirl animation
    RewardDelayMs  = 1200,  -- ms
    ReplyTimeoutMs = 5000,  -- ms
    MinigameGraceMs = 10000, -- ms added to the minigame wait before giving up

    PanModel  = 'P_CS_MININGPAN01X',
    BoneIndex = 'SKEL_R_HAND', -- bone name or index
    PanAttach = {
        carry = { 0.25, 0.01, -0.09, 0.0, -1.0, 91.0 },   -- x, y, z, rotX, rotY, rotZ
        work  = { 0.2, 0.0, -0.2, -100.0, -50.0, 0.0 },
    },
    StartPanningInfo = { dict = 'script_rc@cldn@ig@rsc2_ig1_questionshopkeeper', name = 'inspectfloor_player', flag = 1 },
    StartShakeInfo   = { dict = 'script_re@gold_panner@gold_success', name = 'SEARCH02', flag = 31 },
}

Config.UseSwirl = true -- false = skill bar

Config.Swirl = {
    duration   = 15000, -- ms
    target_min = 2.2,   -- rad/s
    target_max = 6.0,   -- rad/s
    silt_rate  = 16,    -- % per second
    gold_rate  = 9,     -- % per second per rad/s over
    -- false = hidden, nil = minigame default
    hint      = 'Circle the mouse slow and steady, any size, anywhere. Hurry it and the gold rides out with the water. ENTER tips the pan early.',
    slow_text = 'Too slow. The gravel is just sitting there.',
    good_text = 'That is the rhythm. Hold it.',
    fast_text = 'Easy now, colour is slopping over the lip.',
}

Config.Minigame = {
    Difficulty = 3, -- 0 easy .. 7 hardest
    Icon       = 'fa-solid fa-coins',
}

Config.MinigameTuning = {
    baseArea    = 34,   -- %
    areaLoss    = 1.5,  -- % per difficulty point
    minArea     = 16,   -- %
    baseSpeed   = 0.18,
    speedGain   = 0.02, -- per difficulty point
    maxSpeed    = 0.8,
    perfectArea = 6,    -- %
}

Config.Panning = {
    TypeRichness = {
        creek = 1.35,
        river = 1.15,
        lake  = 0.70,
        pond  = 0.55,
        swamp = 0.25,
    },
    DefaultRichness = 0.6,

    Streaks = {
        cell        = 60,   -- metres
        perWater    = 2,
        radius      = 55,   -- metres
        falloff     = 220,  -- metres
        bonus       = 3.0,  -- multiplier at the centre
        pansToDrain = 14,
        spread      = 3,    -- cells
        lifetimeMin = 45,   -- minutes, 0 = never expire
        memory      = 64,   -- panned cells kept per water
    },

    Cooldown     = 3,     -- seconds between paid pans
    MinSessionMs = 9000,  -- ms
    MaxSessionMs = 60000, -- ms
    MaxDrift     = 8.0,   -- metres
}

Config.Prompts = {
    Title      = 'Goldpan',
    PanPrompt  = 0x39336A4F,
    PanName    = 'Search',
    StopPrompt = 0x5966D52A,
    StopName   = 'Stop',
}

Config.BlockedWhileWorking = {
    0xAC4BD4F1, -- weapon wheel
    0x4CC0E2FE, -- B
    0xCEFD9220, -- mount
}
