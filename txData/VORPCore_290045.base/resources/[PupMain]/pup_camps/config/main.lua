-- pup_camps | main settings

Config = {}

Config.Debug          = false
Config.RestartsPerDay = 4      -- "Days Up" = camp age / this, rounded down
Config.SaveEveryMin   = 30     -- full save of every camp

Config.Commands = {
    invites     = 'viewinvites',
    moveCamp    = 'movecamp',
    repo        = 'repoclan',
    unrepo      = 'unrepoclan',
    resetFurni  = 'adminresetfurni',
    changeLead  = 'changeleader',
    cycle       = 'cycleclans',
    syncMembers = 'syncclanmembers',
    resetRaids  = 'resetallraids',
}

Config.Keys = {
    interact  = 0x760A9C6F, -- G
    confirm   = 0xC7B5340A, -- ENTER
    stash     = 0xDB096B85, -- CTRL
    inventory = 0xC1989F95, -- I (blocked while a camp menu is open)
    handIn    = 0x8CC9CD42, -- X
    cancel    = 0x156F7119, -- BACKSPACE
}

Config.Camp = {
    flagItem        = 'flag',
    flagProp        = 'mp001_s_mpcorona01x',
    maxMembers      = 12,      -- 0 = unlimited
    blipSprite      = 1754365229,
    blipColours     = 32,      -- BLIP_MODIFIER_MP_COLOR_1 .. _32
    spacing         = 200.0,   -- minimum distance between camps
    renderDistance  = 100.0,
    furnitureRadius = 50.0,
    roadDistance    = 20.0,
    nameMax         = 40,
    defaultName     = 'Camp',
    blipPrice       = 500,
    relocatePrice   = 800,
    setupSeconds    = 5,
    claimDistance   = 10.0,    -- server: player must stand this close to the spot they claim
    atCampSlack     = 15.0,    -- "at the camp" = furniture radius + this, from the flag (3D)
    placeSlack      = 2.0,     -- server accepts a piece this far past the furniture radius (flat)
    maxPieces       = 20,      -- the flag does not count
    useGizmo        = true,    -- false = always use pup-ui's placement tool
    gizmoRange      = 200.0,
    setTentModel    = 'mp005_s_posse_tent_bountyhunter07x', -- stand-in shown while placing a prop set
    lockRetrySec    = 5,       -- prompt ignored this long after "menu in use"
    regionLock          = {},  -- empty = anywhere
    regionDefaultRadius = 400.0,
    webhookPrefixes = {
        'https://discord.com/api/webhooks/',
        'https://discordapp.com/api/webhooks/',
        'https://ptb.discord.com/api/webhooks/',
        'https://canary.discord.com/api/webhooks/',
    },
    unplaceOnRelocate = true,
    stashBlacklist = { wood = true, stone = true, metal = true, p_ambpack02x = true },
}

-- lowest first; the leader is implicit and passes every check
Config.Ranks = {
    { id = 'member',  label = 'Member' },
    { id = 'trusted', label = 'Trusted' },
    { id = 'manager', label = 'Manager' },
}

-- minimum rank per action ('leader' = leader only)
Config.Permissions = {
    ledger      = 'manager', -- see the Ledger menu at all
    deposit     = 'member',
    tax         = 'member',
    withdraw    = 'manager',
    takeAll     = 'leader',
    stashOpen   = 'trusted', -- also shows the stash prompt
    stashPut    = 'member',
    stashTake   = 'manager',
    furniture   = 'manager',
    blip        = 'manager',
    buyWagon    = 'manager',
    buySupplies = 'manager',
    invite      = 'manager',
    kick        = 'manager',
    relocate    = 'leader',
    webhook     = 'leader',
    setRank     = 'leader',
}

Config.Invites = { hours = 24 }

Config.Tax = {
    amount     = 2500,
    ledgerCap  = 5000,
    minMembers = 1,
    checkMembers = true,
    monthly = { enabled = true, day = 15, hour = 18, minute = 0 },
    -- used only when monthly is off
    fourDays = { enabled = false, days = { 3, 10, 17, 24 }, hour = 6, minute = 10 },
    warnMinutesBefore = 60,
    cronName = 'clan',
    letterFrom = 'Camp Office',
}

Config.Raids = {
    enabled         = true,
    cooldownStarts  = 12,     -- resource starts (camp days); 4 a day = 3 days
    membersOnly     = true,   -- the raider must be in a camp
    minDefenders    = 2,      -- target members online
    minRiders       = 3,      -- posse riders online (clamped to pup-ui's maximum posse size)
    prepMinutes     = 10,
    lockpickMinutes = 5,
    lowSeconds      = 30,     -- countdown turns red
    lootMinutes     = 10,
    leaveDistance   = 100.0,  -- a raider further than this from the camp drops out
    pickDistance    = 60.0,   -- lockpick accepted within this of the flag
    lockpickItem    = 'lockpick',
    alertSprite     = 1754365229,
    alertExtraMin   = 2,      -- alert blip removed after prep + loot + this at the latest
    resendSeconds   = 2,
    safeCrackDifficulty = 3,
    minigameTimeoutSec  = 120,
}

Config.HuntingWagon = {
    enabled        = true,
    price          = 1000,
    maxEntries     = 30,
    model          = -1698498246,
    nearDistance   = 4.0,
    stashCooldown  = 2,       -- seconds; every attempt counts
    pendingTimeout = 30,      -- seconds for a take-out to be reported
}

Config.Economy = {
    stockEveryMin   = 30,
    perCycle        = 10,     -- materials converted per cycle
    suppliesPerStock = 1,     -- warning threshold = perCycle * this
    drainPerCycle   = 1,      -- flat supplies drained per cycle
    stockCap        = 100,
    supplyPrice     = 5,
    randomPrice     = true,
    priceMin        = 15,
    priceMax        = 20,
    fixedPrice      = 10,
    perkSupply      = 'clan_supply_bonus',
    perkSale        = 'clan_sale_bonus',
    xpSupply        = 'clan_supply',
    xpDelivery      = 'clan_delivery',
}

Config.Missions = {
    blipSprite       = 1754365229,
    arriveDistance   = 100.0,
    leaveDistance    = 300.0,
    enemyBlips       = true,
    supplyCooldownMin   = 30,
    deliveryCooldownMin = 30,
    returnMin        = 30,     -- a mission in use returns to its pool after this at the latest
    sizes            = { small = 25, medium = 50, large = 100 },
    wagonModel       = 'wagon05x',
    maxRunHours      = 3,      -- runs (and listed supply wagons) older than this are dropped
    acceptRadius     = 150.0,  -- server: reporter must be this close to the mission spot
    handInDistance   = 25.0,   -- supply wagon to a placed trapper
    posseBlipMin     = 45,
    wagonListSeconds = 5,
}

Config.Beer = {
    drunkAt          = 2,     -- exactly this many: light effect
    strongAt         = 4,     -- exactly this many: stronger
    hallucinateAbove = 5,     -- above this: hallucination
    durationMin      = 1,
    decayMin         = 1,     -- counter drops by one this often
    stats = { hunger = 0, thirst = 5, metabolism = 5, cores = 0 },
}

Config.Poison = {
    enabled       = true,
    tickSeconds   = 6,
    healthDamage  = true,
    damageDivisor = 5,       -- max health / this per tick
    healthFloor   = 100,
    cureOnDeath   = false,
    effectAfter   = 30,      -- ticks
    walkAfter     = 60,      -- ticks
    damageAfter   = 120,     -- ticks
    cureItems     = { 'antipoison2', 'unique_helper' },
    drinkProp     = 'p_bottlewine01x', -- bottle the antidote is drunk from (same as bottled water)
    snakeWeapon   = 'WEAPON_SNAKE',
    snakeModels   = { 'a_c_snake_01', 'a_c_snakeblacktailrattle_01', 'a_c_snakeferdelance_01',
                      'a_c_snakeredboa_01', 'a_c_snakeredboa10ft_01', 'a_c_snakewater_01' },
    persistRestart = false,  -- false = poison survives a relog only
}

Config.Pelts = {
    maxRecords = 200,   -- client: pelt records kept
    forgetMin  = 30,    -- client and server: a pelt record is forgotten after this
    skinRange  = 6.0,   -- the skinned carcass must be this close to the player
    peltRange  = 4.0,   -- the new pelt object must be this close to the player
    maxPerChar = 40,    -- registered pelts one character may hold at once
}

Config.Butchers = {
    enabled        = true,
    rewardItems    = false,
    maxHorsePelts  = 6,
    saleCooldown   = 2,       -- seconds per player
    range          = 12.0,    -- server: player within this of the butcher
    bodyRange      = 10.0,    -- server: body within this of the player
    resaleMemory   = 300,     -- seconds a network id cannot be sold again
    budgetRefill   = 300,     -- seconds for the horse-pelt budget to refill
    sellDistance   = 5.0,     -- client prompt distance
    mountDistance  = 5.0,
    donateMountDistance = 10.0,
    npcModel       = 'S_M_M_UNIBUTCHERS_01',
    spawnDistance  = 100.0,
    blipSprite     = 1369919445,
}

Config.Stews = {
    { name = 'Veggie Stew', spoilMin = 10, stats = 10,
      ingredients = { { 'water', 5 }, { 'Wild_Carrot', 3 }, { 'potato', 2 }, { 'Crows_Garlic', 1 } } },
    { name = 'Minced Meat Stew', spoilMin = 15, stats = 20,
      ingredients = { { 'Wild_Carrot', 3 }, { 'water', 5 }, { 'potato', 2 }, { 'Crows_Garlic', 1 }, { 'game', 3 } } },
    { name = 'Ash Reshteh', spoilMin = 15, stats = 20,
      ingredients = { { 'Wild_Carrot', 3 }, { 'water', 5 }, { 'Crows_Garlic', 2 }, { 'game', 3 }, { 'beef', 3 }, { 'bird', 2 } } },
    { name = 'Beef, Meat And Veggies Stew', spoilMin = 20, stats = 30,
      ingredients = { { 'Wild_Carrot', 3 }, { 'water', 5 }, { 'potato', 2 }, { 'Crows_Garlic', 1 }, { 'game', 3 }, { 'beef', 4 } } },
    { name = 'Salmon and Veggies Stew', spoilMin = 30, stats = 40,
      ingredients = { { 'Wild_Carrot', 3 }, { 'water', 5 }, { 'potato', 2 }, { 'Crows_Garlic', 1 }, { 'Oregano', 1 },
                      { 'Parasol_Mushroom', 5 }, { 'a_c_fishsalmonsockeye_01_ms', 3 } } },
}

Config.IngredientLabels = {
    water = 'Water', Wild_Carrot = 'Wild Carrot', potato = 'Potatos', Crows_Garlic = 'Garlic',
    game = 'Game Meat', beef = 'Beef', bird = 'Bird Meat', Oregano = 'Oregano',
    Parasol_Mushroom = 'Parasol Mushroom', a_c_fishsalmonsockeye_01_ms = 'Sockeye Salmon',
}

Config.Anim = {
    hammer     = 'WORLD_HUMAN_CROUCH_INSPECT',
    notebook   = 'WORLD_HUMAN_WRITE_NOTEBOOK',
    drink      = 'WORLD_HUMAN_DRINKING',
    eat        = 'WORLD_HUMAN_SIT_GROUND_EAT',
    crouch     = 'WORLD_HUMAN_CROUCH_INSPECT',
    washMale   = { 'amb_misc@world_human_wash_face_bucket@ground@male_a@idle_d', 'idle_l' },
    washFemale = { 'amb_misc@world_human_wash_face_bucket@ground@female_a@idle_d', 'idle_l' },
    lockpick   = { 'script_proc@robberies@shop@rhodes@gunsmith@inside_upstairs', 'handle_door' },
    sickWalk   = 'injured_general',
    bottleProp = 'p_bottlebeer01x',
    bowlProp   = 'p_bowl04x_stew',
    spoonProp  = 'p_spoon01x',
}

Config.Effects = {
    drunkLight  = 'PlayerDrunk01',
    drunkStrong = 'PlayerDrunk01_PassOut',
    hallucinate = 'PlayerDrugsPoisonWell',
    poison      = 'PoisonDartPassOut',
}

Config.Logs = {
    enabled       = true,
    campWebhooks  = true,     -- leaders may connect their own channel
    senderName    = 'Camp Logs',
    defaultColour = 10506797,
    categories = {
        money = true, members = true, stash = true, camp = true,
        raid = true, supplies = true, missions = true, furniture = true,
    },
    colours = { green = 3066993, red = 15158332, blue = 3447003, orange = 15105570, purple = 10038562 },
}
