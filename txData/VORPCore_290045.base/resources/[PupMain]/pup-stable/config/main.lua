-- pup-stable | general settings (shared). See README for each block.

Config = Config or {}

Config.General = {
    debug            = false,  -- F8/console diagnostics
    useMouse         = true,   -- the stable menu takes the mouse too
    promptDistance   = 3.0,    -- metres
    stablehandSpawn  = 30.0,   -- metres
    previewLight     = 15.0,   -- light intensity drawn at the preview camera
    horseFallbackPrice = 100,
    wagonFallbackPrice = 100,
    transferDistance = 10.0,   -- metres
    takeOutAnywhere  = true,   -- false = only what is kept at this stable
    busyLockMs       = 15000,  -- ms
    nameMax          = 50,
    useGold          = true,   -- also allow gold prices
    serverIdentifier = 'steam',
}

Config.AdminMovesTack = false

Config.StaffGroups = { admin = true, superadmin = true, owner = true }

Config.ColorAllowList = {}

Config.StableJobs   = { 'mfstable', 'bwstable', 'vtstable', 'emstable', 'vhstable', 'rdstable', 'sdstable', 'sbstable', 'smstable' }
Config.TrainerJobs  = { 'horsetrainer', 'mfstable', 'bwstable', 'vtstable', 'emstable', 'vhstable', 'rdstable', 'sdstable', 'sbstable', 'smstable' }

Config.Transfer = {
    durationMs  = 10000,   -- ms
    flatPrice   = false,   -- a number = flat price; false = by distance
    pricePerKm  = 22,
}

Config.Vet = {
    price          = 25,
    goldPrice      = nil,     -- nil = no gold revive
    deathDelay     = 120,     -- seconds
    autoRevive     = true,
    sweepEvery     = 15,      -- seconds
    remindEvery    = 300,     -- seconds
    whistleResetsCores = false, -- a whistle revive refills the cores
    reviveDeadAfterRestartAtOnce = true, -- dead after a restart: revive on the first sweep
}

Config.Saddlebag = {
    access   = 2,          -- 0 nobody, 1 owner only, 2 anyone
    default  = { weight = 500, slots = 300, weapons = true },
    showSlots = true, showWeight = false,
    serverReach = 5.0,
    enforceWeight = false, -- false = slots only
}

Config.Locker = {
    access   = 2,
    default  = { weight = 1000, slots = 5000, weapons = true },
    showSlots = true, showWeight = false,
    serverReach = 6.0,
}

Config.InventoryWatch = { distance = 8.0, polls = 2, everyMs = 1000 }
Config.Lantern = { serverReach = 6.0, promptReach = 2.8, weapon = 'WEAPON_MELEE_LANTERN' }
Config.CareReach = { client = 3.0, server = 5.0 }

Config.Starter = {
    enabled = true, breed = 13, coat = 1, name = 'Dusty', stable = 'blackwater',
    female = false, favourite = true, speed = 2, acceleration = 2, handling = 2,
    message = 'A horse is waiting for you at the Blackwater stable.',
}

Config.Horse = {
    maxPerCharacter   = 0,      -- 0 = unlimited
    realistic         = false,
    whistleSearch     = 50.0,   -- metres
    whistleAhead      = 25.0,
    whistleTeleport   = 200.0,
    cullDistance      = 500.0,
    instanceResyncMs  = 5000,
    invincibleMs      = 5000,
    allowFlee         = true,
    fleeDeleteMs      = 5000,
    fleeKeepCoresMs   = 60000,
    statsPrompt       = true,
    ownerOnlyMount    = false,
    mountSecurityFlag = nil,    -- ped config flag; nil = off
    noHorseJump       = true,
    shareWaypoint     = true,
    retrieveCutscene  = false,
    stablingCutscene  = true,
    extraFlags        = {},     -- { [flag] = bool }
    badGroundZones    = {},     -- { { x, y, z, radius } }
    noWhistleTowns    = {},     -- game town zone names
    putAwayOnInteriorEvent = false,
    -- ped config flags set on every spawned stable horse
    ownerFlags        = { [6] = true, [297] = true, [300] = false, [312] = false, [419] = false },
}

-- requireObject: a stow only counts when the server sees that pelt object right beside the player
Config.Pelts = { enabled = true, max = 5, visible = 3, serverReach = 10.0, requireObject = true }

Config.Shoes = {
    enabled = false, lifeKm = 300, warnBelow = 0.5, noRunBelow = 0.05, price = 5,
}

Config.Stats = {
    tickMs       = 1000,
    saveMs       = 60000,
    levelToasts  = true,
    walkEvery    = 500,      -- metres
    walkPoints   = 25,
    walkGate     = 'trainers', -- 'trainers' | 'jobs' | 'everyone'
    walkJobs     = { 'mfstable', 'bwstable', 'vtstable', 'emstable', 'vhstable', 'rdstable', 'sdstable', 'sbstable', 'smstable' },
    pointCeiling = 5000,
    bondCeiling  = 5000,
}

Config.Training = {
    trainersOnly  = true,
    trainerDistance = 8.0,
    ceilings      = { speed = 10, acceleration = 10, handling = 4 },
    levels        = { 0, 400, 1000, 1800, 2800, 4000, 5400, 7000, 8800, 10800 },
    rankCost      = { speed = 500, acceleration = 400, handling = 600 },
    capPerLevel   = { 4, 5, 6, 7, 8, 9, 10, 10, 10, 10 },
    rideEvery     = 15,       -- seconds
    rideXP        = 10,
    focusMult     = 2,
    minSpeed      = 1.0,
    maxSpeed      = 50.0,
    xpPerMinute   = 400,
    feedback      = { toast = true, minimum = 140, everySec = 30, nudgeBars = true },
}

Config.Bonding = {
    brave = 800, calm = 1500,
    strangerKickChance = 0.5,
    kickFlag = nil,          -- ped config flag; nil = game default
    commandDistance = 5.0,
    feed  = { points = 30, cooldown = 180, radius = 4.0 },
    brush = { points = 25, cooldown = 300, radius = 4.0 },
    skin  = { points = 15, cooldown = 120, radius = 8.0, ownerOnly = true },
    stow  = { points = 20, cooldown = 180, radius = 10.0, ownerOnly = true },
    feedWhenMounted = true,
    drinkStamina = 30,
    rest = { enabled = true, points = 10, everySec = 10, restoreInner = true },
}

Config.Colors = {
    onCoat = true, onTack = true,
    palettes = {
        { id = 'tint_generic_clean', key = 'pal_classic',  tints = 256 },
        { id = 'tint_hair',          key = 'pal_hair',     tints = 256 },
        { id = 'tint_horse',         key = 'pal_horse',    tints = 256 },
        { id = 'tint_horse_leather', key = 'pal_horseleather', tints = 128 },
        { id = 'tint_leather',       key = 'pal_leather',  tints = 128 },
        { id = 'tint_makeup',        key = 'pal_makeup',   tints = 64 },
    },
    coatChangerItem = 'horse_coat_changer',
    coatChangerStableReach = 15.0,
    coatChangerHorseReach = 10.0,
}

Config.Prices = {
    components = {
        horse_saddles = 5, horse_saddlebags = 5, saddle_stirrups = 5, saddle_horns = 5,
        horse_blankets = 5, horse_bedrolls = 5, horse_manes = 5, horse_tails = 5,
        horse_shoes = 5, horse_accessories = 5, horse_bridles = 5, saddle_lanterns = 5,
        horse_mustache = 5, horse_outfits = 10,
    },
    componentOverrides = { horse_saddles = { [4] = 50 } },
    componentGold = {},       -- { category = goldPrice }
    wagonCustom = { vehicle_tints = 10, vehicle_propsets = 10, vehicle_liveries = 10, vehicle_lantern_propsets = 10, vehicle_extras = 10 },
    wagonCustomOverrides = {},   -- { column = { [index] = price } }
    noneOptionCharged = true,    -- the "No ..." row costs the column price
}

Config.Wagon = {
    maxPerCharacter = 0,
    realistic       = false,
    callAhead       = 20.0,
    callSearch      = 25.0,     -- metres
    promptDistance  = 2.0,
    safeSpawn       = 5.0,
    requireAllHarness = true,
    canBeDamaged    = false,
    retrieveCutscene = false,
    whistle         = true, whistleMs = 1400,
    callLockMs      = 1500,
    noCallTowns     = { 'Annesburg', 'Armadillo', 'Blackwater', 'Rhodes', 'Strawberry', 'Tumbleweed', 'Valentine', 'SaintDenis', 'StDenis', 'VanHorn', 'Siska' },
    fleeRadius      = 300.0,
}

Config.Breeding = {
    enabled      = true,
    cooldownDays = 7,
    litter       = 5,
    gestationHours = 24,
    paddock      = { enabled = true, spacing = 1.2, offset = 5.0, range = 60.0, randomCoat = false,
                     restEvery = 300, restFor = 120, foal = true, foalStart = 0.35, reaskSec = 15 },
    minPrice     = 10000,
    maxPrice     = 0,
    cut          = 0.05,
    foalBag      = { weight = 500, slots = 300, weapons = true },
    names        = { 'Rosa', 'Juniper', 'Cedar', 'Willow', 'Ember', 'Dusty', 'Clover', 'Hazel', 'Sable', 'Rain', 'Scout', 'Banjo',
                     'Copper', 'Flint', 'Marigold', 'Pepper', 'Comet', 'Bramble', 'Ash', 'Winter', 'Sorrel', 'Thistle', 'Dakota', 'Blue' },
    height       = { min = 0.80, max = 1.10, step = 0.01 },
    cross        = { enabled = true, health = 0.05, stamina = 0.05, pointCeiling = 1000 },
    permKey      = 'store',
    minGrade     = 4,
    breederFoal  = true,
    oneListingPerFoal = false,   -- false = one listing per litter
    buyNeedsStable    = false,
    buyReach          = 25.0,
    cooldownIgnoresRetired = false,
}

Config.Wild = {
    enabled      = true,
    blips        = false,
    handInRadius = 12.0, serverHandIn = 18.0,
    salePrice    = { 250, 300 },
    cooldownMin  = 60,
    rounds       = 5,
    skillBar     = { speed = 0.6, icon_speed = 2, area_size = 14, perfect_area_size = 5 },
    refillMin    = 30,
    spawnRange   = 250.0,
    spook        = { sneak = 4.0, normal = 12.0, sneakSpeed = 1.8 },
    fleeDistance = 30.0, throwFlee = 60.0,
    wander       = 15.0,
    keep         = true, defaultName = 'Wild One', nameMax = 24,
    grantSec     = 600,
    tameReach    = 6.0,
    horseNear    = 20.0,
    spots = {
        { coords = vector4(-2578.08, 424.5, 148.6, 90.0),    models = { 'A_C_Horse_Nokota_BlueRoan', 'A_C_Horse_Nokota_ReverseDappleRoan', 'A_C_Horse_Nokota_WhiteRoan' } },
        { coords = vector4(-1680.8, -675.45, 151.9, 180.0),  models = { 'A_C_Horse_Mustang_WildBay', 'A_C_Horse_Mustang_GrulloDun', 'A_C_Horse_Mustang_Buckskin' } },
        { coords = vector4(1673.6, 1314.76, 145.9, 270.0),   models = { 'A_C_Horse_Morgan_Bay', 'A_C_Horse_Morgan_BayRoan', 'A_C_Horse_Morgan_LiverChestnut' } },
        { coords = vector4(2460.4, -222.06, 42.08, 0.0),     models = { 'A_C_Horse_Criollo_Dun', 'A_C_Horse_Criollo_BayFrameOvero', 'A_C_Horse_Criollo_SorrelOvero' } },
        { coords = vector4(-1696.01, 773.4, 160.29, 45.0),   models = { 'A_C_Horse_Mustang_BlackOvero', 'A_C_Horse_Mustang_GoldenDun', 'A_C_Horse_Mustang_ChestnutTovero' } },
        { coords = vector4(1118.95, -1512.35, 54.7, 120.0),  models = { 'A_C_Horse_Criollo_BayBrindle', 'A_C_Horse_Criollo_MarbleSabino', 'A_C_Horse_Criollo_BlueRoanOvero' } },
    },
}

Config.Logs = {
    sendSteamAndDiscord = true,
    colour = 15158332,            -- red
    username = 'Stable Logs',
}

-- side-saddle idle animations (flat ground / uphill / downhill)
Config.SideSaddle = {
    dict = 'script_story@fin1@ig@ig_17_sitsidesaddle',
    flat = 'idle_female', up = 'idle_female_up', down = 'idle_female_down',
}

-- false switches a command off
Config.Commands = {
    sidesaddle = 'sidesaddle', fixWagon = 'fixWagon', fleeHorse = 'fleeHorse', callWagon = 'callWagon',
    fleeWagon = 'fleeWagon', reloadHorse = 'reloadHorse', disableAutoRideFollow = 'disableAutoRideFollow',
    horseRest = 'horseRest', horseSleep = 'horseSleep', horseWallow = 'horseWallow', horseDrink = 'horseDrink',
    fixHorse = false, wildhorses = 'wildhorses',
}

-- control hashes
Config.Keys = {
    enter     = 0x760A9C6F,              -- G (press)
    stableIt  = 0xC7B5340A,              -- Enter (hold)
    stopLead  = 0x8AAA0AD4,              -- left Alt
    saddlebag = 0x4CC0E2FE,              -- B (raw keybind)
    callWagon = 0xF3830D8E,              -- J (raw keybind)
    menu      = 0xD8F73058,              -- U (raw keybind)
    skip      = `INPUT_SKIP_CUTSCENE`,   -- hold 1 s to skip saddling scenes
    peltStow  = 0xCEFD9220,              -- E (hold)
    peltDrop  = 0x8AAA0AD4,              -- left Alt (hold)
    lantern   = `INPUT_HUD_SPECIAL`,
    shoes     = `INPUT_AIM_IN_AIR`,
    takeBag   = `INPUT_FRONTEND_RS`,
    feed      = `INPUT_INTERACT_HORSE_FEED`,
    flee      = `INPUT_HORSE_COMMAND_FLEE`,
    jump      = `INPUT_JUMP`,
    whistle   = `INPUT_WHISTLE`,
    whistleMounted = `INPUT_WHISTLE_HORSEBACK`,
    horseInfo = `INPUT_INTERACT_ANIMAL`,
}

-- server-side hooks
Config.Hooks = {
    horsePrice = function(_src, _breedId, _coatIndex, price) return price end,
    componentPrice = function(_src, _category, _index, price) return price end,
    canAccessStable = function(_src, _stableId) return true end,
    canTransferHorse = function(_src, _horseId, _target) return true end,
}

exports('getConfig', function() return Config end)
