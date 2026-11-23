-- pup_hideouts | contraband sales to locals, bargaining and the sting

Config = Config or {}

Config.Sales = {
    enabled = true,
    minPolice = 0,          -- false = no check at all
    minPoliceOnDuty = true, -- count police by pup-mdt duty (when pup-mdt runs) rather than by job alone
    offerCooldown = 5,      -- seconds between offers from one player
    instantRefuse = 7,      -- out of 10: the local refuses and walks off (only when bargaining is off)
    report = true, reportChance = 40, reportRadius = 50,

    -- price per unit; an item missing here is never sold (the startup check names it)
    prices = { moonshine = 60, moonshineapple = 40, moonshineraspberry = 30, heroin = 50, pure = 25, hemp = 15 },
    legal = { hemp = true }, -- never stung or reported, still haggled
    -- per-item overrides: { maxUnits, weights, floor, ceiling, opening, jitter, legal }
    overrides = {},

    buyerRange = 2.5,
    sessionRange = 12.0,
    sessionClientSeconds = 180,
    firstScreenMs = 1500,
    pedTypes = { [4] = true, [5] = true },
}

Config.Bargain = {
    enabled = true,
    counters = 3,
    maxUnits = 2,
    weights = { 65, 35 },
    floor = 0.50, ceiling = 1.00,
    opening = 0.60, jitter = 0.08,
    notches = 12,
    sessionSeconds = 120,
    handoffMs = 3000,
    walkAbove = 0.90,
    -- used when a per-item or global value above is missing
    fallback = { maxUnits = 5, floor = 0.60, ceiling = 1.60, opening = 0.75, jitter = 0.12 },
}

Config.Sting = {
    enabled = true,
    chance = 20,
    lawmanAlways = true,
    struggleSeconds = 25,
    ropeDelayMs = 900,
    ropeRange = 25.0,
    tieRange = 4.0,
    crookedChance = 30,
    crookedDrinks = 1,
    lootMinutes = 15,
    lootRange = 60.0,
}

Config.LawmanModels = {
    'u_m_m_valsheriff_01', 'u_m_m_rhdsheriff_01', 'u_m_o_asbsheriff_01', 's_m_m_valdeputy_01',
    's_m_m_marshallsrural_01', 's_m_m_ambientsdpolice_01', 'u_m_m_sdpolicechief_01', 's_m_m_ambientblwpolice_01',
    'u_m_o_blwpolicechief_01', 'a_m_m_valdeputyresident_01', 'a_m_m_armdeputyresident_01', 'a_m_m_asbdeputyresident_01',
    'a_m_m_rhddeputyresident_01', 'a_m_m_strdeputyresident_01',
}
