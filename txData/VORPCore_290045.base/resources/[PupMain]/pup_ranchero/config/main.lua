-- pup_ranchero | configuration (webhook URLs are in server/config.lua)

Config = {}

Config.General = {
    debug          = false,
    createCommand  = 'createranch', -- vorp group 'admin' only
    adminJobs      = { 'admin' },   -- character jobs that may open the in-game ranch dashboard
    allowTransfer  = true,          -- owners may hand their ranch to another player
    maxNameLength  = 50,
}

Config.Keys = {
    interact = 0x760A9C6F, -- G
    stop     = 0x8CC9CD42, -- X (ends trail recording)
    cancel   = 0x156F7119, -- Backspace
    interactLabel = 'G',
}

-- how the G prompts look (ranch point, tasks, herding):
-- 'native' = the game's own prompt (bottom right, titled with the ranch) | 'pill' = pup-ui's key pill
Config.PromptStyle = 'native'
-- the floating "Ranch ID" text over the marker before you are close enough for the prompt
Config.ShowRanchIdText = false

-- distances in metres
Config.Reach = {
    ranch        = 30.0,  -- menu actions measured from the ranch point (3D)
    register     = 30.0,  -- a sent spot must be this close to the player
    work         = 20.0,  -- chores and finishing milk/egg rounds, from the spot
    enclosure    = 30.0,  -- a cow pen / chicken coop must be this close to the ranch point
    checkpoint   = 120.0, -- herding checkpoint, from the matching trail point
    driveEnd     = 200.0, -- end of a herding drive, from trail point 1
    barn         = 200.0, -- a sale claim, from any sale barn
    bounty       = 300.0, -- kill bounty: killer to the reporting driver
    marker       = 5.0,   -- ranch marker shows inside this
    prompt       = 2.0,   -- the G pill shows inside this
    crowd        = 2.0,   -- "someone is too close"
    herdSpawn    = 25.0,  -- the Spawn Herd pill shows inside this (from the ranch point)
    taskStart    = 3.0,   -- chore / cow / chickens start pill
}

Config.Blips = {
    scale        = 0.2,
    forSale      = 552659337,
    owned        = 263099185,
    barn         = -569968788,
    goalSprite   = 'blip_ambient_herd', -- name, hashed on the client
    wolfStyle    = 953018525,
    rebuildDelay = 1000, -- ms debounce after any ranch data change
}

Config.Environment = {
    max          = 300, -- 0 = no cap (the yield then scales against 300)
    decay        = 10,  -- removed from every owned ranch above 0 per tick
    decayMinutes = 30,  -- ticks land on fixed wall-clock slots (:00 and :30)
}

Config.Livestock = {
    maxPerType     = 5,
    boughtQuality  = 0.1,
    maxQuality     = 200,
    boostOn        = true,
    boostMult      = 0.5,
    scaleByQuality = true,
    scaleMin       = 0.5,
    scaleMax       = 1.0,
    killReward     = true,  -- outsiders who kill a drive animal get half its price
    chargeOwnCow   = true,  -- killing your own pen cow costs cash
    ownCowCharge   = 100,
    deathFactor    = 0.9,   -- road quality x this per death
    strayPenalty   = 0.1,   -- road quality -10% per alive animal that did not arrive
    verifyAnimals  = true,  -- the server watches the drive animals: no more can arrive than it saw alive, minus those it saw die
    unseenAsFailed = false, -- true = a drive whose animals the server never saw counts nothing as arrived (check the console first)
}

Config.Herding = {
    checkDistance  = 12.0, -- herd waits beyond this; checkpoints trigger at half
    closingSeconds = 10,
    cooldown       = 900,  -- seconds
    timeLimit      = 3600, -- seconds
    rewardsToStore = false, -- true = herding items go straight to the produce store
    voucherSeconds = 120,
    minSeconds     = 20,
    sanitySpeed    = 15.0, -- m/s used to check that a drive did not finish impossibly fast
    nudgeMs        = 15000,
    freezeFromPlayer = 12.0,
    freezeFromDog    = 15.0,
    resumeNearPlayer = 8.0,
    resumeNearDog    = 15.0,
    dogHeelDistance  = 8.0,
    dogCheckMs       = 3000,
    trail = { minLeg = 12.0, maxLeg = 100.0 }, -- the same limits on both sides
}

Config.Sales = {
    deliveryRadius = 12.0,
    cooldown       = 900,  -- seconds
    timeLimit      = 3600, -- seconds
    chickenFactor  = 1.5, -- chickens get 1.5x the time
    payoutMult     = 2,   -- 0 or nil = x1
    followMs       = 1000,
    freezeFromPlayer = 20.0,
    resumeNearPlayer = 6.0,
    requireHerdAfterPurchase = true, -- a newly bought herd must finish a herding trip before it can be sold
}

Config.Hazards = {
    startAfter      = 100,     -- seconds after the drive goes live
    strayEveryMs    = 5000,
    strayRollMax    = 10,
    strayAbove      = 8,
    strayCooldownHerd = 300000,
    strayCooldownSale = 300000,
    strayDistance   = 28.0,
    strayCatch      = 5.0,
    strayRejoinMs   = 10000,
    wolfEveryMs     = 9000,
    wolfRollMax     = 15,
    wolfAbove       = 14,
    wolfCooldown    = 600000,
    wolfDistance    = 15.0,
    wolfModel       = 'a_c_wolf',
}

Config.Dog = {
    command      = 'onme',
    cooldown     = 300,  -- seconds, per client
    duration     = 10,   -- seconds
    breeds = {
        { label = 'Huskey',               model = 'A_C_DogHusky_01',             price = 1000 },
        { label = 'Chesbay Retriever',    model = 'A_C_DogChesBayRetriever_01',  price = 300 },
        { label = 'Labrador Retriever',   model = 'A_C_DogLab_01',               price = 300 },
        { label = 'Labrador Retriever 2', model = 'A_C_DogRufus_01',             price = 300 },
        { label = 'Coon Hound',           model = 'A_C_DogBluetickCoonhound_01', price = 300 },
        { label = 'Border Collie',        model = 'A_C_DogCollie_01',            price = 300 },
        { label = 'Foxhound',             model = 'A_C_DogAmericanFoxhound_01',  price = 300 },
        { label = 'Catahoula Cur',        model = 'a_c_dogcatahoulacur_01',      price = 75 },
    },
}

-- stored names are the database keys: never rename them
Config.Chores = {
    order = { 'racking', 'hayscope', 'feed', 'hayspread', 'water' },
    list = {
        racking   = { label = 'Raking',       art = 'bales',  scenario = 'WORLD_HUMAN_FARMER_RAKE' },
        hayscope  = { label = 'Shovel',       art = 'dung',   scenario = 'WORLD_HUMAN_SHOVEL_COAL_PICKUP' },
        feed      = { label = 'Feed',         art = 'sack',   scenario = 'WORLD_HUMAN_FEED_CHICKEN' },
        hayspread = { label = 'Hay Spread',   art = 'hay',    scenario = 'WORLD_HUMAN_PITCH_HAY_SCATTER' },
        water     = { label = 'Water Bucket', art = 'bucket', scenario = 'WORLD_HUMAN_BUCKET_POUR_HIGH' },
    },
    cooldown     = 1800, -- seconds, per character, per ranch, per chore
    maxScore     = 10,
    capScore     = true,
    workSeconds  = 0,    -- chore animation after a round; 0 = off
}

Config.Minigame = {
    collectGame = true, -- false = pup-minigames skill bar fallback
    roundSeconds = 30,
    graceSeconds = 5,   -- server accepts a round this long before its full length
    fallbackMinSeconds = 3,
    spawnMs     = 700,
    catchRatio  = 0.6,
    riseMin     = 1.8,
    riseMax     = 4.2,
    speedUp     = 0.30, -- items up to 30% quicker by the end
    spawnShrink = 0.65, -- spawn interval shrinks to 65% by the end
    safetySeconds = 8,
    overrides = {
        water     = { spawnMs = 900, catchRatio = 0.55 },
        hayspread = { spawnMs = 620 },
        eggs      = { spawnMs = 580, catchRatio = 0.65 },
    },
    skillBar = {
        rounds = { chore = 3, eggs = 3, milk = 4 },
        baseZone = 34, zoneStep = 1.5, minZone = 14, perfectZone = 6,
        baseSpeed = 0.18, speedStep = 0.02, maxSpeed = 0.55,
        difficulty = 1, roundTimeout = 30,
    },
}

Config.Produce = {
    maxYield     = 42,
    milkItem     = 'milk',
    eggItem      = 'egg',
    milkCooldown = 900, -- seconds, per character; starts when a round is completed
    eggCooldown  = 900, -- seconds
    startGap     = 30,  -- seconds between two starts by one character (anti-spam; not the cooldown)
    session      = 600, -- seconds
    clientSession = 590, -- seconds
    cowModel     = 'a_c_cow',
    chickenModel = 'a_c_chicken_01',
    chickens     = 4,
    milkAnim     = { dict = 'amb_work@world_human_milk_cow@male_a@idle_a', name = 'idle_a' },
    eggAnim      = { dict = 'mech_pickup@loot@ground', name = 'loot' },
    reportGap    = 30, -- seconds between cow-kill reports per player
}

Config.Upgrades = {
    cowPen      = 2000,
    chickenCoop = 1500,
}

Config.Store = {
    idBase = 8000000, -- produce container id = idBase + ranch id; never change it once items are stored
}

Config.Tax = {
    enabled    = true,
    deleteRepo = false, -- true = delete unpaid ranches instead of selling them again
    mode       = 'monthly',
    monthly    = { days = { 15 }, hour = 19, minute = 0 },
    weekly     = { days = { 3, 10, 17, 24 }, hour = 6, minute = 10 },
    warnMinutes = 60,
    mailFrom   = 'Ranch Office',
}

Config.Timers = {
    menuLock     = 0,   -- seconds one player may hold the ranch menu alone; 0 = everyone can use it at once
    sweepEvery   = 60,  -- seconds
    abandonExtra = 600, -- seconds
    activityDays = 30,
    infoDelayMs  = 3000,
}

-- Boss Actions > Who Is Working / Ranch Leaderboard
Config.Board = {
    nearRanch = 150,  -- metres from the ranch point that count as "at the ranch"
    refreshMs = 4000, -- how often an open Who Is Working list updates itself
    maxRows   = 50,   -- most people listed on the leaderboard
}

-- type names are database keys (case-sensitive). job = 'none' means anyone; a type without a job cannot be bought.
Config.Animals = {
    goats     = { model = 'a_c_goat_01',       job = 'none', price = 20, rewards = { { item = 'fibers', per = 1 } } },
    sheep     = { model = 'a_c_sheep_01',      job = 'none', price = 30, rewards = { { item = 'wool', per = 1 } } },
    cow       = { model = 'a_c_cow',           job = 'none', price = 40, rewards = { { item = 'cows', per = 2 } } },
    chicken   = { model = 'a_c_chicken_01',    job = 'none', price = 10, rewards = { { item = 'chickenf', per = 1 } } },
    pig       = { model = 'a_c_pig_01',        job = 'none', price = 30, rewards = { { item = 'porkfat', per = 1 } } },
    Pronghorn = { model = 'A_C_Pronghorn_01',  job = 'none', price = 20, rewards = { { item = 'prongs', per = 1 }, { item = 'venison', per = 1 } }, outfit = 1 },
    Bison     = { model = 'A_C_Buffalo_01',    job = 'none', price = 40, rewards = { { item = 'bisons', per = 1 }, { item = 'beef', per = 1 } } },
    Ram       = { model = 'A_C_BigHornRam_01', job = 'none', price = 20, rewards = { { item = 'rams', per = 1 } } },
    Deer      = { model = 'A_C_Deer_01',       job = 'none', price = 30, rewards = { { item = 'deerskin', per = 1 } } },
}

-- item labels used in Discord logs (vorp_inventory does not pass labels with its container events)
Config.ItemLabels = {
    beef = 'Beef', bisons = 'Bison pelt', chickenf = 'Chicken feather', cows = 'Cow pelt',
    deerskin = 'Deer pelt', egg = 'Egg', fibers = 'Fibers', milk = 'Milk', porkfat = 'Pig fat',
    prongs = 'Pronghorn Skin', rams = 'Ram Pelt', venison = 'Venison', wool = 'Wool',
}

Config.SaleBarns = {
    { town = 'Valentine',       x = -217.18,  y = 634.94,   z = 113.20 },
    { town = 'Rhodes',          x = 1320.8,   y = -1260.3,  z = 77.33 },
    { town = 'Blackwater',      x = -853.13,  y = -1337.95, z = 43.48 },
    { town = 'Strawberry',      x = -1837.10, y = -438.56,  z = 159.53 },
    { town = 'Armadillo',       x = -3660.93, y = -2564.88, z = -13.75 },
    { town = 'Saint Denis',     x = 2393.30,  y = -1416.46, z = 45.76 },
    { town = 'Annesburg',       x = 2930.7,   y = 1313.5,   z = 44.27 },
    { town = 'Tumbleweed',      x = -5410.35, y = -2934.25, z = 0.92 },
    { town = 'Thieves Landing', x = -1428.76, y = -2324.58, z = 43.24 },
    { town = 'Emerald Ranch',   x = 1402.94,  y = 292.41,   z = 88.62, disabled = true },
}
