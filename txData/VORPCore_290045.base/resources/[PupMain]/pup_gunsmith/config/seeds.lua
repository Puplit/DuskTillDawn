-- pup_gunsmith | seed data, used only while the database tables are empty (see README)

Seeds = {}

---------------------------------------------------------------------------
-- crafting stations: name, position, and the jobs that may use it
---------------------------------------------------------------------------
Seeds.Stations = {
    { name = 'ValentineGunsmith',     x = -277.0,    y = 780.689,   z = 119.68, jobs = { 'vtgunsmith' } },
    { name = 'RhodesGunsmith',        x = 1330.15,   y = -1321.06,  z = 77.88,  jobs = { 'rdgunsmith' } },
    { name = 'SaintDenisGunsmith',    x = 2708.766,  y = -1284.148, z = 49.63,  jobs = { 'badmanners' } },
    { name = 'AnnesburgGunsmith',     x = 2951.28,   y = 1314.52,   z = 44.82,  jobs = { 'abgunsmith' } },
    { name = 'BlackwaterGunsmith',    x = -828.94,   y = -1269.99,  z = 43.57,  jobs = { 'bwgunsmith' } },
    { name = 'ArmadilloGunsmith',     x = -3679.66,  y = -2596.69,  z = -13.22, jobs = { 'amgunsmith' } },
    { name = 'StrawberryGunsmith',    x = -1844.46,  y = -418.16,   z = 161.3,  jobs = { 'sbgunsmith' } },
    { name = 'StrawberryBlacksmith',  x = -1828.47,  y = -568.41,   z = 156.00, jobs = { 'sbblacksmith' } },
    { name = 'ArmadilloBlacksmith',   x = -3651.06,  y = -2625.3,   z = -13.51, jobs = { 'amblacksmith' } },
    { name = 'MacFarlaneBlacksmith',  x = -2401.61,  y = -2381.74,  z = 61.19,  jobs = { 'mfblacksmith' } },
    { name = 'SaintDenisBlacksmith',  x = 2609.95,   y = -942.63,   z = 42.41,  jobs = { 'sdblacksmith' } },
    { name = 'BlackWaterBlacksmith',  x = -870.12,   y = -1393.34,  z = 43.51,  jobs = { 'bwblacksmith' } },
    { name = 'RhodesBlacksmith',      x = 1311.9,    y = -1351.96,  z = 78.01,  jobs = { 'rdblacksmith' } },
    { name = 'Annesburgblacksmith',   x = 2886.28,   y = 1359.88,   z = 62.73,  jobs = { 'abblacksmith' } },
    { name = 'EmeraldBlacksmith',     x = 1442.17,   y = 266.24,    z = 90.35,  jobs = { 'emblacksmith' } },
    { name = 'ValentineBlacksmith',   x = -370.1,    y = 798.44,    z = 116.27, jobs = { 'vtblacksmith' } },
    { name = 'BigValleyBounty',       x = -2198.69,  y = 714.16,    z = 122.32, jobs = { 'bvbounty' } },
    { name = 'ValentineTribe',        x = 431.7,     y = 2195.59,   z = 246.8,  jobs = { 'vttribe' } },
    { name = 'BigValleyTribe',        x = -1821.2,   y = 428.66,    z = 113.44, jobs = { 'bvtribe' } },
    { name = 'BlackwaterTribe',       x = -2669.88,  y = -1459.41,  z = 146.31, jobs = { 'bwtribe' } },
}

---------------------------------------------------------------------------
-- job sets: recipes name one of these in `jobs`
---------------------------------------------------------------------------
local JobSets = {
    blacksmiths    = { 'sdblacksmith', 'rdblacksmith', 'abblacksmith', 'emblacksmith', 'vtblacksmith', 'bwblacksmith', 'mfblacksmith', 'amblacksmith', 'sbblacksmith' },
    tribes         = { 'vttribe', 'bvtribe', 'bwtribe' },
    gunsmiths      = { 'badmanners', 'rdgunsmith', 'abgunsmith', 'bwgunsmith', 'sbgunsmith', 'vtgunsmith', 'amgunsmith' },
    gunsmiths_ammo = { 'rdgunsmith', 'badmanners', 'abgunsmith', 'bwgunsmith', 'sbgunsmith', 'vtgunsmith', 'amgunsmith' },
    tribes_valentine_bigvalley = { 'vttribe', 'bvtribe' },
    nobody         = { 'noone' },
    none           = {}, -- no jobs listed (with jobOnly = true nobody can make it)
}

---------------------------------------------------------------------------
-- the name shown for each material item (a material can override it with label = ...)
---------------------------------------------------------------------------
local MaterialLabels = {
    ironbar          = 'Iron Bar',
    wooden_boards    = 'Wooden Boards',
    rpelt13          = 'Refined Elk Pelt',
    coal             = 'Coal',
    bolts            = 'Bolts',
    deerskin         = 'Deer Skin',
    bucks            = 'Buck skin',
    fibers           = 'Fibers',
    sap              = 'Sap',
    riflebarrel      = 'Rifle Barrel',
    rpelt5           = 'Refined Bear Pelt',
    riflereceiver    = 'Rifle Receiver',
    riflestock       = 'Rifle Stock',
    rpelt4           = 'Refined Buck Pelt',
    rpelt10          = 'Refined Boar Pelt',
    repeaterbarrel   = 'Repeater Barrel',
    repeaterreceiver = 'Repeater Receiver',
    repeaterstock    = 'Repeater Stock',
    pistolreceiver   = 'Pistol Receiver',
    pistolbarrel     = 'Pistol Barrel',
    rpelt3           = 'Refined Bison Pelt',
    pistolgrip       = 'Pistol Handle',
    rpelt2           = 'Refined Fox Pelt',
    rpelt12          = 'Refined Alligator Pelt',
    rpelt8           = 'Refined Coyote Pelt',
    revolverbarrel   = 'Revolver Barrel',
    revolverhandle   = 'Revolver Handle',
    revolvercylinder = 'Revolver Cylinder',
    hawkt            = 'Hawk claws',
    clay             = 'Clay',
    alcohol          = 'Alcohol',
    glassbottle      = 'Glass Bottle',
    acid             = 'Acid',
    rpelt11          = 'Refined Beaver Pelt',
    rock             = 'Rock',
    nitrite          = 'Nitrite',
    dynamite         = 'Pipe Charge Dynamite',
    rpelt9           = 'Refined Cougar Pelt',
    fertilizerbless  = 'Blessed Fertilizer',
    iron             = 'Iron Ore',
    porkfat          = 'Pork Fat',
    fertilizerpure   = 'Pure Fertilizer',
    salt             = 'Salt',
    rpelt6           = 'Refined Wolf Pelt',
    shotgunbarrel    = 'Shotgun Barrel',
    shotgunstock     = 'Shotgun Stock',
    rpelt7           = 'Refined Panther Pelt',
    copper           = 'Copper',
    rpelt1           = 'Refined Moose Pelt',
    lense            = 'Lenses',
    shellcasing      = 'Shell Casing',
    rubber           = 'Rubber',
    wood             = 'Soft Wood',
    turkeyf          = 'Turkey Feather',
    hawkf            = 'Hawk Feather',
    quailf           = 'Quail Feather',
    Snake_Poison     = 'Snake Poison',
    specialpelt      = 'Special Pelt',
}

---------------------------------------------------------------------------
-- defaults: a recipe only needs to list a field when it differs from these
---------------------------------------------------------------------------
local WeaponDefaults = { xpGained = 25, xpNeeded = 0, difficulty = 3000, craftable = true, jobOnly = true }
local AmmoDefaults   = { xpGained = 1,  xpNeeded = 0, difficulty = 3000, craftable = true, jobOnly = true }

local BOWS <const> = { 'WEAPON_BOW', 'WEAPON_BOW_IMPROVED' }

---------------------------------------------------------------------------
-- weapon recipes
---------------------------------------------------------------------------
local WeaponRecipes = {
    -- Melee -------------------------------------------------------
    { category = 'Melee', name = 'Horror Knife', weapon = 'WEAPON_MELEE_KNIFE_HORROR',
      xpGained = 100, craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 2 }, { item = 'rpelt13', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Bagshot Knife', weapon = 'WEAPON_MELEE_KNIFE_RUSTIC',
      craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 2 }, { item = 'deerskin', amount = 2 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Tradders Knife', weapon = 'WEAPON_MELEE_KNIFE_TRADER',
      craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 2 }, { item = 'deerskin', amount = 2 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Knife', weapon = 'WEAPON_MELEE_KNIFE',
      craftable = false, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wooden_boards', amount = 1 }, { item = 'deerskin', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'JawBone Knife', weapon = 'WEAPON_MELEE_KNIFE_JAWBONE',
      craftable = true, jobs = 'tribes',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wooden_boards', amount = 1 }, { item = 'deerskin', amount = 2 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Cleaver', weapon = 'WEAPON_MELEE_CLEAVER',
      craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 1 }, { item = 'bucks', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Hunter Hatchet', weapon = 'WEAPON_MELEE_HATCHET_HUNTER',
      craftable = true, jobs = 'tribes',
      materials = { { item = 'ironbar', amount = 4 }, { item = 'wooden_boards', amount = 1 }, { item = 'bucks', amount = 2 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Melee', name = 'Machete', weapon = 'WEAPON_MELEE_MACHETE',
      craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 4 }, { item = 'wooden_boards', amount = 1 }, { item = 'bucks', amount = 2 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },

    -- Bows --------------------------------------------------------
    { category = 'Bows', name = 'Bow', weapon = 'WEAPON_BOW',
      craftable = true, jobs = 'tribes',
      materials = { { item = 'deerskin', amount = 2 }, { item = 'wooden_boards', amount = 1 }, { item = 'fibers', amount = 2 } } },
    { category = 'Bows', name = 'Improved Bow', weapon = 'WEAPON_BOW_IMPROVED',
      craftable = true, jobs = 'tribes',
      materials = { { item = 'sap', amount = 1 }, { item = 'wooden_boards', amount = 1 }, { item = 'fibers', amount = 1 } } },

    -- Rifles ------------------------------------------------------
    { category = 'Rifles', name = 'Elephant Rifle', weapon = 'WEAPON_RIFLE_ELEPHANT',
      xpGained = 100, xpNeeded = 10000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'rpelt5', amount = 1 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Rifles', name = 'Varmint Rifle', weapon = 'WEAPON_RIFLE_VARMINT',
      craftable = false, jobs = 'none',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'riflestock', amount = 1 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Rifles', name = 'Rollingblock Rifle', weapon = 'WEAPON_SNIPERRIFLE_ROLLINGBLOCK',
      xpGained = 100, xpNeeded = 50000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'rpelt4', amount = 2 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Rifles', name = 'Carcano Rifle', weapon = 'WEAPON_SNIPERRIFLE_CARCANO',
      xpGained = 100, xpNeeded = 80000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'rpelt10', amount = 2 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Rifles', name = 'Springfield Rifle', weapon = 'WEAPON_RIFLE_SPRINGFIELD',
      xpNeeded = 10000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'riflestock', amount = 1 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Rifles', name = 'Boltaction Rifle', weapon = 'WEAPON_RIFLE_BOLTACTION',
      xpNeeded = 20000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'riflebarrel', amount = 1 }, { item = 'riflestock', amount = 1 }, { item = 'riflereceiver', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },

    -- Repeaters ---------------------------------------------------
    { category = 'Repeaters', name = 'Winchester Repeater', weapon = 'WEAPON_REPEATER_WINCHESTER',
      xpNeeded = 5000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'repeaterbarrel', amount = 1 }, { item = 'repeaterreceiver', amount = 1 }, { item = 'repeaterstock', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Repeaters', name = 'Henry Repeater', weapon = 'WEAPON_REPEATER_HENRY',
      xpNeeded = 500, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'repeaterbarrel', amount = 1 }, { item = 'repeaterreceiver', amount = 1 }, { item = 'repeaterstock', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Repeaters', name = 'Evans Repeater', weapon = 'WEAPON_REPEATER_EVANS',
      xpNeeded = 2500, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'repeaterbarrel', amount = 1 }, { item = 'repeaterreceiver', amount = 1 }, { item = 'repeaterstock', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Repeaters', name = 'Carbine Repeater', weapon = 'WEAPON_REPEATER_CARBINE',
      craftable = false, jobs = 'gunsmiths',
      materials = { { item = 'repeaterbarrel', amount = 1 }, { item = 'repeaterreceiver', amount = 1 }, { item = 'repeaterstock', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },

    -- Pistols -----------------------------------------------------
    { category = 'Pistols', name = 'SemiAuto Pistol', weapon = 'WEAPON_PISTOL_SEMIAUTO',
      xpGained = 100, xpNeeded = 40000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'pistolreceiver', amount = 1 }, { item = 'pistolbarrel', amount = 1 }, { item = 'rpelt3', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'pistolgrip', amount = 1 }, { item = 'bolts', amount = 2 } } },
    { category = 'Pistols', name = 'Mauser Pistol', weapon = 'WEAPON_PISTOL_MAUSER',
      xpNeeded = 30000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'pistolreceiver', amount = 1 }, { item = 'pistolbarrel', amount = 1 }, { item = 'rpelt2', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'pistolgrip', amount = 1 }, { item = 'bolts', amount = 2 } } },
    { category = 'Pistols', name = 'Volcanic Pistol', weapon = 'WEAPON_PISTOL_VOLCANIC',
      xpGained = 100, xpNeeded = 5000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'pistolreceiver', amount = 1 }, { item = 'pistolbarrel', amount = 1 }, { item = 'rpelt12', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'pistolgrip', amount = 1 }, { item = 'bolts', amount = 2 } } },
    { category = 'Pistols', name = 'M1899 Pistol', weapon = 'WEAPON_PISTOL_M1899',
      xpGained = 100, xpNeeded = 50000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'pistolreceiver', amount = 1 }, { item = 'pistolbarrel', amount = 1 }, { item = 'rpelt8', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'pistolgrip', amount = 1 }, { item = 'bolts', amount = 2 } } },

    -- Revolvers ---------------------------------------------------
    { category = 'Revolvers', name = 'Double Action Gambler', weapon = 'WEAPON_REVOLVER_DOUBLEACTION_GAMBLER',
      xpNeeded = 250, craftable = false, jobs = 'none',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Mexican Cattleman', weapon = 'WEAPON_REVOLVER_CATTLEMAN_MEXICAN',
      craftable = false, jobs = 'none',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Navy Revolver Crossover', weapon = 'WEAPON_REVOLVER_NAVY_CROSSOVER',
      xpNeeded = 2500, craftable = false, jobs = 'none',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Schofield Revolver', weapon = 'WEAPON_REVOLVER_SCHOFIELD',
      xpNeeded = 1500, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Lemat Revolver', weapon = 'WEAPON_REVOLVER_LEMAT',
      xpNeeded = 2000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Double Action Revolver', weapon = 'WEAPON_REVOLVER_DOUBLEACTION',
      xpNeeded = 250, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Cattleman Revolver', weapon = 'WEAPON_REVOLVER_CATTLEMAN',
      craftable = false, jobs = 'none',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Revolvers', name = 'Navy Revolver', weapon = 'WEAPON_REVOLVER_NAVY',
      xpNeeded = 2500, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'revolverbarrel', amount = 1 }, { item = 'revolverhandle', amount = 1 }, { item = 'revolvercylinder', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },

    -- Throwable ---------------------------------------------------
    { category = 'Throwable', name = 'Bolas Hawkmoth', weapon = 'WEAPON_THROWN_BOLAS_HAWKMOTH',
      craftable = false, jobs = 'none',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'fibers', amount = 5 }, { item = 'hawkt', amount = 2 } } },
    { category = 'Throwable', name = 'Bolas Iron-Spiked', weapon = 'WEAPON_THROWN_BOLAS_IRONSPIKED',
      craftable = false, jobs = 'none',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'fibers', amount = 5 }, { item = 'deerskin', amount = 2 } } },
    { category = 'Throwable', name = 'Bolas Intertwined', weapon = 'WEAPON_THROWN_BOLAS_INTERTWINED',
      craftable = false, jobs = 'none',
      materials = { { item = 'sap', amount = 2 }, { item = 'fibers', amount = 5 }, { item = 'deerskin', amount = 2 } } },
    { category = 'Throwable', name = 'Tomahawk', weapon = 'WEAPON_THROWN_TOMAHAWK',
      xpGained = 1, craftable = true, jobs = 'tribes',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 2 }, { item = 'fibers', amount = 2 } } },
    { category = 'Throwable', name = 'Knives', weapon = 'WEAPON_THROWN_THROWING_KNIVES',
      xpGained = 1, craftable = false, jobs = 'none',
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wooden_boards', amount = 1 }, { item = 'clay', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'bolts', amount = 2 } } },
    { category = 'Throwable', name = 'Poison Bottle', weapon = 'WEAPON_THROWN_POISONBOTTLE',
      xpGained = 100, xpNeeded = 50000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'alcohol', amount = 3 }, { item = 'glassbottle', amount = 3 }, { item = 'acid', amount = 3 }, { item = 'rpelt11', amount = 1 } } },
    { category = 'Throwable', name = 'Bolas', weapon = 'WEAPON_THROWN_BOLAS',
      craftable = false, jobs = 'none',
      materials = { { item = 'deerskin', amount = 2 }, { item = 'fibers', amount = 2 }, { item = 'rock', amount = 2 } } },
    { category = 'Throwable', name = 'Dynamite', weapon = 'WEAPON_THROWN_DYNAMITE',
      xpGained = 100, xpNeeded = 100000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'nitrite', amount = 10 }, { item = 'acid', amount = 10 }, { item = 'dynamite', amount = 1, label = 'Dynamite' }, { item = 'rpelt9', amount = 1 }, { item = 'clay', amount = 5 }, { item = 'sap', amount = 5 }, { item = 'coal', amount = 5 }, { item = 'fibers', amount = 5 }, { item = 'alcohol', amount = 10 }, { item = 'fertilizerbless', amount = 10 }, { item = 'iron', amount = 10 }, { item = 'porkfat', amount = 10 }, { item = 'fertilizerpure', amount = 10 }, { item = 'salt', amount = 10 } } },
    { category = 'Throwable', name = 'Molotov', weapon = 'WEAPON_THROWN_MOLOTOV',
      xpGained = 100, xpNeeded = 25000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'alcohol', amount = 3 }, { item = 'glassbottle', amount = 3 }, { item = 'rpelt6', amount = 1 }, { item = 'coal', amount = 5 }, { item = 'fibers', amount = 5 }, { item = 'porkfat', amount = 10 }, { item = 'nitrite', amount = 10 } } },

    -- Shotguns ----------------------------------------------------
    { category = 'Shotguns', name = 'Semiauto Shotgun', weapon = 'WEAPON_SHOTGUN_SEMIAUTO',
      xpNeeded = 30000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Shotguns', name = 'Sawedoff Shotgun', weapon = 'WEAPON_SHOTGUN_SAWEDOFF',
      xpGained = 100, xpNeeded = 50000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'rpelt7', amount = 2 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Shotguns', name = 'Repeating Shotgun', weapon = 'WEAPON_SHOTGUN_REPEATING',
      xpNeeded = 5000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Shotguns', name = 'Pump Shotgun', weapon = 'WEAPON_SHOTGUN_PUMP',
      xpNeeded = 20000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Shotguns', name = 'Doublebarrel Shotgun', weapon = 'WEAPON_SHOTGUN_DOUBLEBARREL',
      craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Shotguns', name = 'Exotic Doublebarrel Shotgun', weapon = 'WEAPON_SHOTGUN_DOUBLEBARREL_EXOTIC',
      craftable = false, jobs = 'gunsmiths',
      materials = { { item = 'shotgunbarrel', amount = 1 }, { item = 'shotgunstock', amount = 1 }, { item = 'ironbar', amount = 5 }, { item = 'coal', amount = 5 } } },

    -- Misc. -------------------------------------------------------
    { category = 'Misc.', name = 'Metal Detector', weapon = 'WEAPON_KIT_METAL_DETECTOR',
      xpNeeded = 1000, craftable = false, jobs = 'gunsmiths',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'copper', amount = 2 } } },
    { category = 'Misc.', name = 'Halloween Lantern', weapon = 'WEAPON_MELEE_LANTERN_HALLOWEEN',
      xpGained = 100, xpNeeded = 1000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'deerskin', amount = 2 }, { item = 'rpelt1', amount = 1 }, { item = 'ironbar', amount = 2 } } },
    { category = 'Misc.', name = 'Lasso', weapon = 'WEAPON_LASSO',
      craftable = false, jobs = 'none',
      materials = { { item = 'deerskin', amount = 2 }, { item = 'bucks', amount = 2 }, { item = 'fibers', amount = 5 } } },
    { category = 'Misc.', name = 'Reinforced Lasso', weapon = 'WEAPON_LASSO_REINFORCED',
      xpNeeded = 10000, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'deerskin', amount = 5 }, { item = 'fibers', amount = 10 }, { item = 'copper', amount = 5 }, { item = 'coal', amount = 5 } } },
    { category = 'Misc.', name = 'Improved Binoculars', weapon = 'WEAPON_KIT_BINOCULARS_IMPROVED',
      xpNeeded = 50, craftable = true, jobs = 'gunsmiths',
      materials = { { item = 'ironbar', amount = 5 }, { item = 'copper', amount = 8 }, { item = 'deerskin', amount = 4 } } },
    { category = 'Misc.', name = 'Binoculars', weapon = 'WEAPON_KIT_BINOCULARS',
      craftable = false, jobs = 'gunsmiths',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'copper', amount = 4 }, { item = 'deerskin', amount = 4 } } },
    { category = 'Misc.', name = 'Fishing Rod', weapon = 'WEAPON_FISHINGROD',
      craftable = false, jobs = 'none',
      materials = { { item = 'ironbar', amount = 1 }, { item = 'wooden_boards', amount = 4 }, { item = 'deerskin', amount = 1 } } },
    { category = 'Misc.', name = 'Camera', weapon = 'WEAPON_KIT_CAMERA',
      craftable = false, jobs = 'none',
      materials = { { item = 'ironbar', amount = 2 }, { item = 'copper', amount = 2 }, { item = 'lense', amount = 2 } } },
    { category = 'Misc.', name = 'Advanced Camera', weapon = 'WEAPON_KIT_CAMERA_ADVANCED',
      craftable = true, jobs = 'none',
      materials = { { item = 'ironbar', amount = 5 }, { item = 'copper', amount = 2 }, { item = 'lense', amount = 4 } } },
    { category = 'Misc.', name = 'Lantern', weapon = 'WEAPON_MELEE_LANTERN',
      craftable = false, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 10 }, { item = 'coal', amount = 2 }, { item = 'deerskin', amount = 4 } } },
    { category = 'Misc.', name = 'Davy Lantern', weapon = 'WEAPON_MELEE_DAVY_LANTERN',
      craftable = true, jobs = 'blacksmiths',
      materials = { { item = 'ironbar', amount = 8 }, { item = 'coal', amount = 2 }, { item = 'copper', amount = 5 } } },
}

---------------------------------------------------------------------------
-- ammo recipes (materials are per box)
---------------------------------------------------------------------------
local AmmoRecipes = {
    -- Repeater ----------------------------------------------------
    { category = 'Repeater', name = 'Repeater Ammo Normal', boxItem = 'ammorepeaternormal', ammoType = 'AMMO_REPEATER',
      roundsPerBox = 100, maxAmmo = 200, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'repeater' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Repeater', name = 'Repeater Ammo Express', boxItem = 'ammorepeaterexpress', ammoType = 'AMMO_REPEATER_EXPRESS',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 20, xpNeeded = 1500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'repeater' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'shellcasing', amount = 3 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },
    { category = 'Repeater', name = 'Repeater Ammo Explosive', boxItem = 'ammorepeaterexplosive', ammoType = 'AMMO_REPEATER_EXPRESS_EXPLOSIVE',
      roundsPerBox = 30, maxAmmo = 20, craftable = false, jobs = 'none',
      weaponTypes = { 'repeater' },
      materials = { { item = 'ironbar', amount = 5 }, { item = 'shellcasing', amount = 5 }, { item = 'dynamite', amount = 5 }, { item = 'coal', amount = 1 } } },
    { category = 'Repeater', name = 'Repeater Ammo Velocity', boxItem = 'ammorepeatervelocity', ammoType = 'AMMO_REPEATER_HIGH_VELOCITY',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 10, xpNeeded = 500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'repeater' },
      materials = { { item = 'ironbar', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Repeater', name = 'Repeater Ammo Splitpoint', boxItem = 'ammorepeatersplitpoint', ammoType = 'AMMO_REPEATER_SPLIT_POINT',
      roundsPerBox = 50, maxAmmo = 100, xpGained = 2, xpNeeded = 250, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'repeater' },
      materials = { { item = 'ironbar', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },

    -- Revolver ----------------------------------------------------
    { category = 'Revolver', name = 'Revolver Ammo Normal', boxItem = 'ammorevolvernormal', ammoType = 'AMMO_REVOLVER',
      roundsPerBox = 100, maxAmmo = 200, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'revolver' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Revolver', name = 'Revolver Ammo Express', boxItem = 'ammorevolverexpress', ammoType = 'AMMO_REVOLVER_EXPRESS',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 20, xpNeeded = 1500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'revolver' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'shellcasing', amount = 3 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },
    { category = 'Revolver', name = 'Revolver Ammo Explosive', boxItem = 'ammorevolverexplosive', ammoType = 'AMMO_REVOLVER_EXPRESS_EXPLOSIVE',
      roundsPerBox = 5, maxAmmo = 30, craftable = false, jobs = 'none',
      weaponTypes = { 'revolver' },
      materials = { { item = 'ironbar', amount = 5 }, { item = 'shellcasing', amount = 5 }, { item = 'dynamite', amount = 5 }, { item = 'coal', amount = 1 } } },
    { category = 'Revolver', name = 'Revolver Ammo Velocity', boxItem = 'ammorevolvervelocity', ammoType = 'AMMO_REVOLVER_HIGH_VELOCITY',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 10, xpNeeded = 500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'revolver' },
      materials = { { item = 'ironbar', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Revolver', name = 'Revolver Ammo Splitpoint', boxItem = 'ammorevolversplitpoint', ammoType = 'AMMO_REVOLVER_SPLIT_POINT',
      roundsPerBox = 50, maxAmmo = 100, xpGained = 2, xpNeeded = 250, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'revolver' },
      materials = { { item = 'ironbar', amount = 8 }, { item = 'shellcasing', amount = 8 }, { item = 'nitrite', amount = 8 }, { item = 'coal', amount = 1 } } },

    -- Rifle -------------------------------------------------------
    { category = 'Rifle', name = 'Rifle Ammo Normal', boxItem = 'ammoriflenormal', ammoType = 'AMMO_RIFLE',
      roundsPerBox = 100, maxAmmo = 100, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Rifle', name = 'Elephant Rifle Ammo', boxItem = 'ammoelephant', ammoType = 'AMMO_RIFLE_ELEPHANT',
      roundsPerBox = 10, maxAmmo = 20, xpNeeded = 10000, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Rifle', name = 'Rifle Ammo Express', boxItem = 'ammorifleexpress', ammoType = 'AMMO_RIFLE_EXPRESS',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 20, xpNeeded = 1500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'shellcasing', amount = 3 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },
    { category = 'Rifle', name = 'Rifle Ammo Explosive', boxItem = 'ammorifleexplosive', ammoType = 'AMMO_RIFLE_EXPRESS_EXPLOSIVE',
      roundsPerBox = 5, maxAmmo = 10, craftable = false, jobs = 'none',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 5 }, { item = 'shellcasing', amount = 5 }, { item = 'dynamite', amount = 5 }, { item = 'coal', amount = 1 } } },
    { category = 'Rifle', name = 'Rifle Ammo Velocity', boxItem = 'ammoriflevelocity', ammoType = 'AMMO_RIFLE_HIGH_VELOCITY',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 10, xpNeeded = 500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Rifle', name = 'Rifle Ammo Splitpoint', boxItem = 'ammoriflesplitpoint', ammoType = 'AMMO_RIFLE_SPLIT_POINT',
      roundsPerBox = 50, maxAmmo = 100, xpGained = 2, xpNeeded = 250, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle', 'sniper' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'shellcasing', amount = 3 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },

    -- Shotgun -----------------------------------------------------
    { category = 'Shotgun', name = 'Shotgun Ammo Incendiary', boxItem = 'ammoshotgunincendiary', ammoType = 'AMMO_SHOTGUN_BUCKSHOT_INCENDIARY',
      roundsPerBox = 10, maxAmmo = 50, craftable = false, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'shotgun' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'rock', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Shotgun', name = 'Shotgun Ammo Explosive', boxItem = 'ammoshotgunexplosive', ammoType = 'AMMO_SHOTGUN_SLUG_EXPLOSIVE',
      roundsPerBox = 10, maxAmmo = 50, difficulty = 2000, craftable = false, jobs = 'none',
      weaponTypes = { 'shotgun' },
      materials = { { item = 'ironbar', amount = 5 }, { item = 'rubber', amount = 5 }, { item = 'dynamite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Shotgun', name = 'Shotgun Ammo Normal', boxItem = 'ammoshotgunnormal', ammoType = 'AMMO_SHOTGUN',
      roundsPerBox = 25, maxAmmo = 50, craftable = false, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'shotgun' },
      materials = { { item = 'rubber', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Shotgun', name = 'Shotgun Ammo Slug', boxItem = 'ammoshotgunslug', ammoType = 'AMMO_SHOTGUN_SLUG',
      roundsPerBox = 25, maxAmmo = 50, xpGained = 10, xpNeeded = 500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'shotgun' },
      materials = { { item = 'rubber', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },

    -- Pistol ------------------------------------------------------
    { category = 'Pistol', name = 'Pistol Ammo Normal', boxItem = 'ammopistolnormal', ammoType = 'AMMO_PISTOL',
      roundsPerBox = 100, maxAmmo = 200, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'pistol' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Pistol', name = 'Pistol Ammo Express', boxItem = 'ammopistolexpress', ammoType = 'AMMO_PISTOL_EXPRESS',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 20, xpNeeded = 1500, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'pistol' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'shellcasing', amount = 5 }, { item = 'nitrite', amount = 3 }, { item = 'coal', amount = 1 } } },
    { category = 'Pistol', name = 'Pistol Ammo Explosive', boxItem = 'ammopistolexplosive', ammoType = 'AMMO_PISTOL_EXPRESS_EXPLOSIVE',
      roundsPerBox = 10, maxAmmo = 10, craftable = false, jobs = 'none',
      weaponTypes = { 'pistol' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'nitrite', amount = 1 }, { item = 'dynamite', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Pistol', name = 'Pistol Ammo Velocity', boxItem = 'ammopistolvelocity', ammoType = 'AMMO_PISTOL_HIGH_VELOCITY',
      roundsPerBox = 100, maxAmmo = 200, xpGained = 2, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'pistol' },
      materials = { { item = 'ironbar', amount = 2 }, { item = 'shellcasing', amount = 2 }, { item = 'nitrite', amount = 2 }, { item = 'coal', amount = 1 } } },
    { category = 'Pistol', name = 'Pistol Ammo Splitpoint', boxItem = 'ammopistolsplitpoint', ammoType = 'AMMO_PISTOL_SPLIT_POINT',
      roundsPerBox = 50, maxAmmo = 100, xpGained = 2, xpNeeded = 250, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'pistol' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 3 }, { item = 'nitrite', amount = 1 }, { item = 'coal', amount = 1 } } },

    -- Arrow -------------------------------------------------------
    { category = 'Arrow', name = 'Arrow Normal', boxItem = 'ammoarrmownormal', ammoType = 'AMMO_ARROW',
      roundsPerBox = 20, maxAmmo = 40, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'turkeyf', amount = 2 } } },
    { category = 'Arrow', name = 'Arrow Dynamite', boxItem = 'ammoarrowdynamite', ammoType = 'AMMO_ARROW_DYNAMITE',
      roundsPerBox = 20, maxAmmo = 20, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'hawkf', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'dynamite', amount = 2 }, { item = 'coal', amount = 1 }, { item = 'acid', amount = 5 }, { item = 'alcohol', amount = 5 } } },
    { category = 'Arrow', name = 'Arrow Fire', boxItem = 'ammoarrowfire', ammoType = 'AMMO_ARROW_FIRE',
      roundsPerBox = 5, maxAmmo = 5, xpGained = 30, xpNeeded = 10000, craftable = true, jobs = 'tribes',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'nitrite', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'rpelt2', amount = 1 }, { item = 'coal', amount = 1 }, { item = 'alcohol', amount = 5 }, { item = 'iron', amount = 10 }, { item = 'porkfat', amount = 5 } } },
    { category = 'Arrow', name = 'Arrow Improved', boxItem = 'ammoarrowimproved', ammoType = 'AMMO_ARROW_IMPROVED',
      roundsPerBox = 20, maxAmmo = 40, craftable = false, jobs = 'tribes',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'rock', amount = 2 } } },
    { category = 'Arrow', name = 'Arrow Small Game', boxItem = 'ammoarrowsmallgame', ammoType = 'AMMO_ARROW_SMALL_GAME',
      roundsPerBox = 20, maxAmmo = 40, difficulty = 5000, craftable = true, jobs = 'tribes_valentine_bigvalley',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'quailf', amount = 2 } } },
    { category = 'Arrow', name = 'Arrow Poison', boxItem = 'ammoarrowpoison', ammoType = 'AMMO_ARROW_POISON',
      roundsPerBox = 10, maxAmmo = 20, craftable = true, jobs = 'tribes',
      weaponTypes = { 'none' }, forWeapons = BOWS,
      materials = { { item = 'ironbar', amount = 2 }, { item = 'wood', amount = 2 }, { item = 'Snake_Poison', amount = 2 } } },

    -- Varmint Ammo ------------------------------------------------
    { category = 'Varmint Ammo', name = 'Varmint ammo', boxItem = 'ammovarmint', ammoType = 'AMMO_22',
      roundsPerBox = 50, maxAmmo = 100, craftable = false, jobs = 'none',
      weaponTypes = { 'rifle' },
      materials = { { item = 'ironbar', amount = 5 }, { item = 'shellcasing', amount = 5 }, { item = 'nitrite', amount = 5 }, { item = 'coal', amount = 1 } } },
    { category = 'Varmint Ammo', name = 'Varmint Tranquilizer Ammo', boxItem = 'ammovarminttranq', ammoType = 'AMMO_22_TRANQUILIZER',
      roundsPerBox = 100, maxAmmo = 200, xpNeeded = 100, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'rifle' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'shellcasing', amount = 2 }, { item = 'Snake_Poison', amount = 1 }, { item = 'coal', amount = 1 } } },

    -- Throwing ----------------------------------------------------
    { category = 'Throwing', name = 'Knives ammo', boxItem = 'ammoknives', ammoType = 'AMMO_THROWING_KNIVES',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 5, difficulty = 5000, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_THROWING_KNIVES' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'wood', amount = 1 }, { item = 'clay', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Throwing', name = 'Tomahawk Ammo', boxItem = 'ammotomahawk', ammoType = 'AMMO_TOMAHAWK',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 5, craftable = true, jobs = 'tribes',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_TOMAHAWK' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'wood', amount = 1 }, { item = 'fibers', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Throwing', name = 'Poison Bottle Ammo', boxItem = 'ammopoisonbottle', ammoType = 'AMMO_POISONBOTTLE',
      roundsPerBox = 5, maxAmmo = 5, xpGained = 100, xpNeeded = 50000, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_POISONBOTTLE' },
      materials = { { item = 'glassbottle', amount = 5 }, { item = 'Snake_Poison', amount = 2 }, { item = 'acid', amount = 2 }, { item = 'coal', amount = 1 }, { item = 'rpelt11', amount = 1 } } },
    { category = 'Throwing', name = 'Bolla Ammo', boxItem = 'ammobolla', ammoType = 'AMMO_BOLAS',
      roundsPerBox = 5, maxAmmo = 5, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_BOLAS' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'wood', amount = 1 }, { item = 'rock', amount = 1 } } },
    { category = 'Throwing', name = 'Hawkmoth Bolla Ammo', boxItem = 'ammobolahawk', ammoType = 'AMMO_BOLAS_HAWKMOTH',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 25, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_BOLAS_HAWKMOTH' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'hawkt', amount = 1, label = 'Hawk Claws' }, { item = 'rock', amount = 1 } } },
    { category = 'Throwing', name = 'Interwired Bolla Ammo', boxItem = 'ammobolainterwired', ammoType = 'AMMO_BOLAS_INTERTWINED',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 10, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_BOLAS_INTERTWINED' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'fibers', amount = 1 }, { item = 'rock', amount = 1 } } },
    { category = 'Throwing', name = 'Iron-Spiked Bolla Ammo', boxItem = 'ammobolaironspiked', ammoType = 'AMMO_BOLAS_IRONSPIKED',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 50, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_BOLAS_IRONSPIKED' },
      materials = { { item = 'ironbar', amount = 3 }, { item = 'wood', amount = 1 }, { item = 'clay', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Throwing', name = 'Dynamite Ammo', boxItem = 'ammodynamite', ammoType = 'AMMO_DYNAMITE',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 100000, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_DYNAMITE' },
      materials = { { item = 'nitrite', amount = 10 }, { item = 'acid', amount = 10 }, { item = 'clay', amount = 10 }, { item = 'dynamite', amount = 5 }, { item = 'rpelt9', amount = 1 }, { item = 'coal', amount = 1 }, { item = 'fibers', amount = 10 }, { item = 'alcohol', amount = 5 }, { item = 'fertilizerbless', amount = 5 }, { item = 'iron', amount = 5 }, { item = 'porkfat', amount = 5 }, { item = 'sap', amount = 5 }, { item = 'fertilizerpure', amount = 5 } } },
    { category = 'Throwing', name = 'Volatile Dynamite Ammo', boxItem = 'ammovoldynamite', ammoType = 'AMMO_DYNAMITE_VOLATILE',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 1000, craftable = false, jobs = 'none',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_DYNAMITE' },
      materials = { { item = 'ironbar', amount = 1 }, { item = 'wood', amount = 1 }, { item = 'rock', amount = 1 }, { item = 'coal', amount = 1 } } },
    { category = 'Throwing', name = 'Molotov Ammo', boxItem = 'ammomolotov', ammoType = 'AMMO_MOLOTOV',
      roundsPerBox = 5, maxAmmo = 5, xpGained = 100, xpNeeded = 25000, craftable = true, jobs = 'gunsmiths_ammo',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_MOLOTOV' },
      materials = { { item = 'rpelt6', amount = 1 }, { item = 'alcohol', amount = 5 }, { item = 'coal', amount = 5 }, { item = 'glassbottle', amount = 5 }, { item = 'iron', amount = 5 }, { item = 'porkfat', amount = 5 }, { item = 'sap', amount = 5 } } },
    { category = 'Throwing', name = 'Volatile Molotov Ammo', boxItem = 'ammovolmolotov', ammoType = 'AMMO_MOLOTOV_VOLATILE',
      roundsPerBox = 5, maxAmmo = 5, xpNeeded = 100, craftable = false, jobs = 'nobody',
      weaponTypes = { 'none' }, forWeapons = { 'WEAPON_THROWN_MOLOTOV' },
      materials = { { item = 'glassbottle', amount = 3 }, { item = 'specialpelt', amount = 1 }, { item = 'alcohol', amount = 10 }, { item = 'coal', amount = 1 } } },
}

---------------------------------------------------------------------------
-- Nothing to edit below: turns the lists above into the Seeds.Weapons / Seeds.Ammo
-- rows the server reads (server/recipes.lua stores each row's `data` as JSON).
---------------------------------------------------------------------------

-- 64-bit weapon-type hashes as exact unsigned decimals, kept as strings so they never pass through a float
local GC <const> = {
    repeater = '15974927098149040440', -- 0xDDB2578E95EF7138
    revolver = '13984505670112785083', -- 0xC212F1D05A8232BB
    rifle    = '757222093828899872',   -- 0x0A82317B7EBFC420
    sniper   = '7698451975163376357',  -- 0x6AD66548840472E5
    shotgun  = '14362971071279175125', -- 0xC75386174ECE95D5
    pistol   = '15980547593754041014', -- 0xDDC64F5E31EEDAB6
    none     = '0',
}

local function fail(r, msg)
    error(('[pup_gunsmith] config/seeds.lua: %s (recipe %q)'):format(msg, tostring(r.name)), 0)
end

local function copyList(t)
    local out = {}
    for i, v in ipairs(t) do out[i] = v end
    return out
end

local function jobList(r)
    local jobs = r.jobs
    if type(jobs) == 'string' then
        if not JobSets[jobs] then fail(r, 'unknown job set ' .. jobs) end
        jobs = JobSets[jobs]
    end
    if type(jobs) ~= 'table' then fail(r, 'jobs must be a job set name or a list') end
    return copyList(jobs)
end

local function materials(r)
    if type(r.materials) ~= 'table' then fail(r, 'materials missing') end
    local out = {}
    for i, m in ipairs(r.materials) do
        if type(m.item) ~= 'string' or type(m.amount) ~= 'number' then fail(r, 'material ' .. i .. ' needs item and amount') end
        out['item' .. i] = { amount = m.amount, name = m.item, label = m.label or MaterialLabels[m.item] or m.item }
    end
    return out
end

local function pick(r, def, field)
    if r[field] == nil then return def[field] end
    return r[field]
end

local function common(r, def)
    return {
        expadd = pick(r, def, 'xpGained'), expreq = pick(r, def, 'xpNeeded'), diff = pick(r, def, 'difficulty'),
        letcraft = pick(r, def, 'craftable'), jobonly = pick(r, def, 'jobOnly'),
        jobs = jobList(r), materials = materials(r),
    }
end

Seeds.Weapons = {}
for i, r in ipairs(WeaponRecipes) do
    local data = common(r, WeaponDefaults)
    data.hashname = r.weapon
    Seeds.Weapons[i] = { kind = 'weapon', category = r.category, label = r.name, data = data }
end

Seeds.Ammo = {}
for i, r in ipairs(AmmoRecipes) do
    local data = common(r, AmmoDefaults)
    data.item, data.key, data.qt, data.maxammo = r.boxItem, r.ammoType, r.roundsPerBox, r.maxAmmo
    if r.forWeapons then data.playeritem = copyList(r.forWeapons) end
    local types = r.weaponTypes or { 'none' }
    for _, t in ipairs(types) do
        if not GC[t] then fail(r, 'unknown weapon type ' .. tostring(t)) end
    end
    Seeds.Ammo[i] = {
        kind = 'ammo', category = r.category, label = r.name, data = data,
        rawChecks = { guncheck = GC[types[1]], guncheck2 = types[2] and GC[types[2]] or nil },
    }
end
