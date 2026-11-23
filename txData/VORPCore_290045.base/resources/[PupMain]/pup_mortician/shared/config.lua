-- pup_mortician | settings shared by client and server (every setting is explained in the README)

Config = {}

Config.Debug = false

---------------------------------------------------------------------------
-- Who may do what
---------------------------------------------------------------------------
-- characters with one of these jobs are undertakers
Config.UndertakerJobs = { 'rdundertaker', 'sdundertaker', 'amundertaker', 'sbundertaker' }

-- characters with one of these jobs may dig with a shovel; an empty list lets anyone with a shovel dig
Config.DigJobs = { 'rdundertaker', 'sdundertaker', 'amundertaker', 'sbundertaker' }

-- false: an undertaker may only work the table whose key equals their job
Config.AnyUndertakerAnyTable = false

---------------------------------------------------------------------------
-- Burial limit
---------------------------------------------------------------------------
Config.Limit = {
    perCharacter = 8,
    mode = 'restart', -- 'window' or 'restart'
    windowHours = 24,
}

---------------------------------------------------------------------------
-- Pay
---------------------------------------------------------------------------
Config.Pay = {
    casketBase = 15, -- a casket burial, before goods and contract bonus
    graveyard = 15,  -- a body buried straight into a graveyard
}

Config.WantedGoods = { min = 3, max = 5 }

Config.HouseCut = {
    enabled = true,
    default = 10,      -- percent, when the business has not set one
    max = 20,          -- percent, clamped to 0..100
    bossesKeepAll = true,
    verifyLedgerRow = true, -- no society_ledger row = the cut stays with the undertaker
}

---------------------------------------------------------------------------
-- Shovel
---------------------------------------------------------------------------
Config.Shovel = {
    items = { 'shovel' },
    uses = 100,          -- 0 = never wears
    wearOnBurial = true, -- casket and graveyard burials wear the shovel too
}

---------------------------------------------------------------------------
-- Map, keys, art
---------------------------------------------------------------------------
Config.BlipSprite = 350569997
Config.BlipStyle = 1664425300
Config.ItemImages = 'nui://vorp_inventory/html/img/items/'

Config.Keys = {
    use = 0x760A9C6F,    -- G
    putAway = 0x05CA7C52,
    weaponWheel = 0xAC4BD4F1,
    b = 0x4CC0E2FE,
}

Config.Distance = { -- metres
    tablePrompt = 2.2,
    tableServer = 6.0,
    corpse = 6.0,
    burialPrompt = 5.0,
    burialServer = 15.0,
    gravePrompt = 4.0,
    graveServer = 15.0,
    propsDraw = 50.0,
    propsClear = 60.0,
}

Config.AbandonMinutes = 30

---------------------------------------------------------------------------
-- Prep tables (key = undertaker job)
---------------------------------------------------------------------------
Config.Tables = {
    rdundertaker = {
        town = 'Rhodes',
        pos = vector3(1284.63, -1213.64, 82.17), heading = 301.28,
        bodyRot = vector3(250.0, 10.0, -150.0), bodyOffset = vector3(-0.05, -0.15, 0.2),
        burial = vector3(1276.90, -1229.43, 80.84),
        pickups = {}, -- fixed contract pickup points (vector3); empty = generated
    },
    sdundertaker = {
        town = 'Saint Denis',
        pos = vector3(2735.81, -1095.83, 46.64), heading = 0.0,
        bodyRot = vector3(250.0, 10.0, -150.0), bodyOffset = vector3(-0.05, -0.15, 0.2),
        burial = vector3(2737.39, -1084.97, 47.15),
        pickups = {},
    },
    amundertaker = {
        town = 'Armadillo',
        pos = vector3(-3654.05, -2588.68, -13.15), heading = 85.12,
        bodyRot = vector3(250.0, 10.0, -180.0), bodyOffset = vector3(-0.05, -0.15, 0.2),
        burial = vector3(-3652.7553, -2580.7209, -13.6168),
        pickups = {},
    },
    sbundertaker = {
        town = 'Strawberry',
        pos = vector3(-1836.935, -621.409, 155.341), heading = 0.0,
        bodyRot = vector3(250.0, 10.0, 90.0), bodyOffset = vector3(-0.05, -0.15, 0.2),
        burial = vector3(-1845.290, -619.453, 155.548),
        pickups = {},
    },
}

---------------------------------------------------------------------------
-- Graveyards (short id = what the register shows as the place)
---------------------------------------------------------------------------
Config.Graveyards = {
    val    = vector3(-238.22, 820.13, 123.89),
    sd     = vector3(2737.39, -1084.97, 47.15),
    rhodes = vector3(1276.90, -1229.43, 80.84),
    bw     = vector3(-993.35, -1193.28, 58.90),
    strw   = vector3(-1756.98, -240.66, 182.89),
    dillo  = vector3(-3652.7553, -2580.7209, -13.6168),
}

---------------------------------------------------------------------------
-- Casket goods, in list order (label is what the Ledger shows)
---------------------------------------------------------------------------
Config.Goods = {
    { item = 'burialoil',         label = 'Burial Perfume Oil',           amount = 1, bonus = 80 },
    { item = 'burialwraps',       label = 'Burial Wraps',                 amount = 1, bonus = 100 },
    { item = 'goodbyliquor',      label = 'Good-bye Liquor',              amount = 1, bonus = 80 },
    { item = 'flowerarrangement', label = 'Flower Arrangement',           amount = 1, bonus = 130 },
    { item = 'luckycoin',         label = 'Hunters Gold Eye Cover-Coins', amount = 1, bonus = 100 },
    { item = 'honey',             label = 'Honey',                        amount = 1, bonus = 5 },
    { item = 'acid',              label = 'Acid',                         amount = 1, bonus = 5 },
    { item = 'joint',             label = 'Joint',                        amount = 1, bonus = 10 },
    { item = 'wine',              label = 'Wine',                         amount = 1, bonus = 20 },
    { item = 'goldbar',           label = 'GoldBar',                      amount = 1, bonus = 40 },
    { item = 'diamond',           label = 'Diamond',                      amount = 1, bonus = 60 },
}

---------------------------------------------------------------------------
-- Town anchors: travel-mode pickups and the server's no-dig zones
---------------------------------------------------------------------------
Config.Towns = {
    { name = 'Valentine',     pos = vector3(-278.4, 805.3, 119.3) },
    { name = 'Rhodes',        pos = vector3(1361.95, -1298.9, 77.76) },
    { name = 'Saint Denis',   pos = vector3(2511.99, -1309.1, 48.95) },
    { name = 'Annesburg',     pos = vector3(2908.3, 1308.9, 44.9) },
    { name = 'Blackwater',    pos = vector3(-761.7, -1268.1, 44.0) },
    { name = 'Strawberry',    pos = vector3(-1814.0, -354.8, 164.6) },
    { name = 'Armadillo',     pos = vector3(-3620.92, -2606.35, -13.33) },
    { name = 'Emerald Ranch', pos = vector3(1436.0, 352.0, 88.0) }, -- not verified in game
}

---------------------------------------------------------------------------
-- Contract board
---------------------------------------------------------------------------
Config.Contracts = {
    enabled = true,
    perBoard = 3,
    refillMinutes = 15,
    deadlineMinutes = 45,
    untakenMinutes = 60,
    bodiesMin = 1, bodiesMax = 3,
    bonusPerBody = 10,
    keepsakeChance = 6, -- percent, contract casket burials only
    bodiesOnly = false, -- true: the prep table only takes the dead from your contract

    travel = false,
    travelMin = 800.0, travelMax = 2200.0, travelNearest = 2,
    townSpreadMin = 150.0, townSpreadMax = 380.0,
    localMin = 80.0, localMax = 260.0,

    spawnRange = 90.0,
    arriveClient = 25.0, arriveServer = 30.0,
    maxRespots = 8,
    respotThrottle = 5, -- seconds
    clearMarkerBeyond = 60.0,

    maleModels = { 'a_m_m_valfarmer_01', 'a_m_m_rhdtownfolk_01', 'a_m_m_asbtownfolk_01', 'a_m_m_lowersdtownfolk_02', 'a_m_m_nbxslums_01', 'a_m_y_asbminer_02' },
    femaleModels = { 'a_f_m_strtownfolk_01', 'a_f_m_middlesdtownfolk_01', 'a_f_m_bynfancytravellers_01' },
    maleNames = { 'Arthur', 'Cornelius', 'Edmund', 'Ezra', 'Gideon', 'Horace', 'Jasper', 'Josiah', 'Mordecai', 'Obadiah', 'Rufus', 'Silas', 'Thaddeus', 'Virgil', 'Zebediah' },
    femaleNames = { 'Abigail', 'Beatrice', 'Dorothea', 'Eliza', 'Florence', 'Hattie', 'Ida', 'Lavinia', 'Mabel', 'Nettie', 'Prudence', 'Tabitha', 'Ursula', 'Wilhelmina' },
    lastNames = { 'Ashcroft', 'Barlow', 'Callahan', 'Dunmore', 'Ellery', 'Faraday', 'Grimes', 'Hollis', 'Ingram', 'Jessup', 'Kettering', 'Lambourne', 'Marsh', 'Nash', 'Ockley', 'Pemberton', 'Quill', 'Radcliffe', 'Sowerby', 'Thackeray', 'Underwood', 'Vance', 'Whitlock', 'Yarrow' },
    causes = { 'Consumption', 'A fall from horseback', 'Snakebite', 'Fever', 'Old age', 'A saloon disagreement', 'Drowning', 'Exposure', 'A mining accident', 'Gunshot' },

    keepsakes = {
        { item = 'burialoil',         label = 'Burial Perfume Oil', amount = 1 },
        { item = 'burialwraps',       label = 'Burial Wraps',       amount = 1 },
        { item = 'goodbyliquor',      label = 'Good-bye Liquor',    amount = 1 },
        { item = 'flowerarrangement', label = 'Flower Arrangement', amount = 1 },
        { item = 'luckycoin',         label = 'Lucky Coin',         amount = 1 },
        { item = 'holywater',         label = 'Holy Water',         amount = 1 },
        { item = 'honey',             label = 'Honey',              amount = 1 },
        { item = 'joint',             label = 'Joint',              amount = 1 },
        { item = 'wine',              label = 'Wine',               amount = 1 },
    },

    -- body spawn offsets around a pickup (x, y metres), repeating
    offsets = { { 0.0, 0.0 }, { 1.6, 0.9 }, { -1.5, 1.1 }, { 0.8, -1.7 }, { -1.8, -0.8 } },
    maxSlope = 0.7, -- the ground normal's z must be at least this
}

---------------------------------------------------------------------------
-- Treasure digging
---------------------------------------------------------------------------
Config.Dig = {
    findChance = 100,  -- percent
    moneyShare = 50,   -- percent of finds that are money
    moneyMin = 1, moneyMax = 5,
    itemMin = 1, itemMax = 4,
    seconds = 10,      -- scaled by the pup-perks dig_speed multiplier
    dugRadius = 6.0, dugMinutes = 30,
    townRadius = 180.0,
    groundSnap = 2.0,
    finishShare = 0.85, finishRange = 5.0,

    -- game town map zones where the client refuses to dig
    blockedZones = { 'Annesburg', 'Armadillo', 'Blackwater', 'Rhodes', 'Siska', 'StDenis', 'Strawberry', 'Tumbleweed', 'Valentine', 'Vanhorn' },

    treasure = {
        { label = 'Gold Nugget', item = 'goldnugget' },
        { label = 'Sap',         item = 'sap' },
        { label = 'Emerald',     item = 'emerald' },
        { label = 'Diamond',     item = 'diamond' },
        { label = 'Coal',        item = 'coal' },
        { label = 'Copper',      item = 'copper' },
        { label = 'Wool',        item = 'wool' },
        { label = 'Potato',      item = 'potato' },
        { label = 'Wild Carrot', item = 'Wild_Carrot' },
    },

    skillBar = {
        difficulty = 3,
        icon = 'fa-solid fa-person-digging',
        scale = 0.7,
        style = 'default',
        orientation = 1,
        movingIcon = false,
        areaBase = 34.0, areaStep = 1.5, areaMin = 16.0, areaMax = 34.0,
        perfectArea = 6.0,
        speedBase = 0.18, speedStep = 0.02, speedMin = 0.18, speedMax = 0.8,
    },
}

---------------------------------------------------------------------------
-- Game assets, referenced by name (Rockstar content, not shipped)
---------------------------------------------------------------------------
Config.Models = {
    table = 'p_table02x',
    coffinClosed = 'p_coffin01x',
    coffinDecorated = 'mp004_s_mp_coffindecor01x',
    coffinEmpty = 'p_coffinempty01x',
    body = 'p_dis_roa_deadchaingang06',
    shovel = 'mp005_p_collectorshovel01',
}

Config.Anim = {
    carryDict = 'mech_carry_box', carryClip = 'idle',
    carryBone = 'SKEL_R_Finger12',
    carryOffset = vector3(0.20, 0.028, -0.50), carryRot = vector3(-10.0, 10.0, 50.0),
    prepDict = 'amb_camp@prop_camp_foodprep@working@potato_chop@male_b@base', prepClip = 'base',
    prepBaseMs = 4000, prepPerGoodMs = 900, prepMaxMs = 10000,
    buryScenario = 'WORLD_HUMAN_SHOVEL_COAL_PICKUP', buryMs = 6500, buryScenarioShare = 0.77,
    sceneGrabDict = 'script@mech@treasure_hunting@grab', sceneGrabList = 'PBL_GRAB_01',
    sceneNothingDict = 'script@mech@treasure_hunting@nothing', sceneNothingList = 'PBL_NOTHING_01',
    sceneLoadMs = 1000, failSceneMs = 4000,
    shovelBoneMale = 311, shovelBoneFemale = 371,
    shovelOffset = vector3(0.0, -0.04, 0.22), shovelRot = vector3(-5.0, 180.0, 0.0),
}

-- minimum gap between two requests of the same kind from one player (ms)
Config.RateLimit = { default = 400, status = 1000, ledger = 300 }
