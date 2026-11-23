-- pup-gangs | dens
-- A gang's drug operation: the fixed dens gangs have to find, the key, seizing, the cook,
-- the powder bench, and the moonshine shack interiors behind each den door.

-------------------------------------------------------------------------------
-- DENS
-------------------------------------------------------------------------------
Config.Dens = {
    enabled             = true,
    unlock              = 'den',     -- gang perk flag required to run a den (level 3+)
    playerDens          = false,     -- true = a gang may designate its own house as a den
    maxByLevel          = { [1] = 0, [2] = 0, [3] = 1, [4] = 2, [5] = 3 }, -- dens a gang may hold per gang level
    prop                = 'p_crate06x', -- crate that marks a den in the world
    interactDistance    = 2.0,       -- metres
    minRank             = 2,         -- rank needed to collect product
    brewMinutes         = 45,        -- one package accumulates every this many minutes
    maxStored           = 3,         -- shelf cap; brewing pauses when full
    raidMinRank         = 3,         -- rival rank needed to start a raid
    raidHoldSeconds     = 120,       -- raider must hold the spot this long
    raidHoldRadius      = 12.0,      -- metres the raider may stray and still count
    raidCooldownMinutes = 60,        -- per den, after any raid outcome
    raidAttackerPoints  = 75,        -- gang points when a raid succeeds (product stolen)
    raidDefenderPoints  = 50,        -- gang points when a raid is beaten off
    alertRadius         = 90.0,      -- metres, defender alert circle
    resetOnRestart      = true,      -- wipe fixed-den ownership and every gang's discovery record at boot
    keyItem             = 'den_key', -- item that opens a fixed den
    doorDistance        = 3.0,       -- metres from the den door (the site's `outside` point)

    -- the key, and how long a den lasts
    key = {
        minRank  = 2,      -- rank needed to turn the key
        consume  = true,   -- the key is spent opening the den
        points   = 80,     -- gang points for opening one
        announce = true,   -- tell the whole crew their gang has a den
    },

    -- finding a fixed den
    discovery = {
        discoverDistance = 35.0,  -- metres; ride this close and your gang has found it
        announceToGang   = true,  -- tell the whole gang when a member finds one
        keepFound        = true,  -- a found den stays on your gang's map for good
    },

    -- seizing an unowned den by holding it (off)
    seize = {
        enabled         = false,
        minRank         = 3,      -- rank needed to seize
        holdSeconds     = 180,    -- hold an unowned den this long to take it
        holdRadius      = 15.0,   -- metres a seizer may stray
        tickSeconds     = 10,     -- presence check interval
        presenceTicks   = 3,      -- consecutive empty checks before the seize fails
        alertRivals     = true,   -- every gang that has found this den is told
        points          = 80,     -- gang points for taking a den
        cooldownMinutes = 30,     -- per den, after any seize attempt
    },

    -- the cook: the den's own mission (off)
    cook = {
        enabled         = false,
        minRank         = 2,
        cookMinutes     = 12,     -- how long a batch takes
        cooldownMinutes = 20,     -- per den, between batches
        ingredients     = {       -- consumed per batch: { item, count }
            { item = 'drug_package', count = 1 },
        },
        product         = { item = 'drug_package', count = 3 }, -- made per batch
        goesHot         = true,   -- reveal the den on every gang's map while cooking
        hotRadius       = 90.0,   -- metres, the vague circle rivals get
        points          = 55,     -- gang points for a finished batch
        bulkPerkBonus   = 1,      -- extra product when the gang has 'bulk_cook'
    },

    -- the powder bench: gang-only explosives
    -- recipes entry: name (row label), give = { item, count } produced,
    -- costs = list of { item, count } consumed, minutes (craft time; craftMinutes if unset)
    bench = {
        enabled         = true,
        unlock          = 'powder_work', -- gang perk flag (Empire)
        minRank         = 3,
        cooldownSeconds = 30,     -- between batches at the same den
        craftMinutes    = 8,      -- fallback when a recipe does not set minutes
        recipes         = {
            {
                name    = 'Gang Package',
                give    = { item = 'drug_package', count = 1 },
                costs   = {
                    { item = 'moonshine',   count = 3 },
                    { item = 'paper',       count = 2 },
                    { item = 'stolenmerch', count = 1 },
                },
                minutes = 5,
            },
            {
                name    = 'Dynamite',
                give    = { item = 'dynamite', count = 1 },
                costs   = {
                    { item = 'gunpowder', count = 8 },
                    { item = 'paper',     count = 4 },
                    { item = 'acid',      count = 1 },
                },
                minutes = 8,
            },
            {
                name    = 'Dynamite Ammo',
                give    = { item = 'ammodynamite', count = 1 },
                costs   = {
                    { item = 'dynamite',  count = 3 },
                    { item = 'gunpowder', count = 6 },
                    { item = 'paper',     count = 2 },
                },
                minutes = 6,
            },
            {
                name    = 'Volatile Dynamite Ammo',
                give    = { item = 'ammovoldynamite', count = 1 },
                costs   = {
                    { item = 'dynamite',  count = 5 },
                    { item = 'gunpowder', count = 10 },
                    { item = 'acid',      count = 3 },
                    { item = 'emerald',   count = 1 },
                },
                minutes = 10,
            },
        },
    },
}

-------------------------------------------------------------------------------
-- FIXED DEN LOCATIONS  (seeded into the database; matched on label)
-------------------------------------------------------------------------------
-- entry: site (key in Config.Dens.sites), label, x, y, z, h (the crate / door point)
Config.Dens.locations = {
    {
        site = 'lemoyne', label = 'The Lemoyne Shack',
        x = 1784.90, y = -821.65, z = 42.86, h = 0.0,
    },
    {
        site = 'cattail_pond', label = 'The Cattail Pond Shack',
        x = -1085.63, y = 714.14, z = 103.32, h = 0.0,
    },
    {
        site = 'new_austin', label = 'The New Austin Shack',
        x = -2769.23, y = -3048.90, z = 11.38, h = 0.0,
    },
    {
        site = 'hanover', label = 'The Hanover Shack',
        x = 1627.64, y = 822.90, z = 144.03, h = 0.0,
    },
    {
        site = 'manzanita_post', label = 'The Manzanita Post Shack',
        x = -1861.70, y = -1722.17, z = 108.35, h = 0.0,
    },
}

-------------------------------------------------------------------------------
-- DEN SITES  (the moonshine shack interiors; client/den.lua requests their IMAPs itself)
-------------------------------------------------------------------------------
-- entry fields are listed in README.md. The lemoyne shell (interior 77313) is shared with pup_hideouts.
Config.Dens.sites = {
    lemoyne = {
        label        = 'The Lemoyne Shack',
        conflicts    = 'pup-underground moonshine hideout',
        verified     = true,
        outside      = { x = 1784.90,   y = -821.65,   z = 42.86,    h = 0.0 },
        inside       = { x = 1785.01,   y = -821.53,   z = 191.01,   h = 0.0 },
        menu         = { x = 1779.9707, y = -803.3311, z = 188.9099, h = 46.0309 },
        ped          = { x = 1778.6456, y = -802.4518, z = 188.9094, h = 226.2637 },
        bench        = { x = 1776.189,  y = -804.654,  z = 188.609,  h = 0.0 },
        stash        = { x = 1784.363,  y = -816.706,  z = 189.054,  h = 0.0 },
        interior     = 77313,
        interiorSets = {
            'mp006_mshine_band2', 'mp006_mshine_bar_benchAndFrame',
            'mp006_mshine_dressing_3', 'mp006_mshine_hidden_door_open',
            'mp006_mshine_location2', 'mp006_mshine_pic_04',
            'mp006_mshine_shelfwall1', 'mp006_mshine_shelfwall2',
            'mp006_mshine_Still_03', 'mp006_mshine_still_hatch',
            'mp006_mshine_theme_hunter',
        },
    },

    cattail_pond = {
        label        = 'The Cattail Pond Shack',
        verified     = false,
        outside      = { x = -1085.63,   y = 714.14,   z = 103.32,  h = 0.0 },
        inside       = { x = -1085.63,   y = 714.14,   z = 83.23,   h = 0.0 },
        menu         = { x = -1090.6693, y = 732.3389, z = 81.1299, h = 46.0309 },
        ped          = { x = -1091.9944, y = 733.2182, z = 81.1294, h = 226.2637 },
        bench        = { x = -1076.1717, y = 716.7584, z = 81.5717, h = 224.7653 },
        interior     = 77569,
        interiorSets = {
            'mp006_mshine_band2', 'mp006_mshine_bar_benchAndFrame',
            'mp006_mshine_dressing_1', 'mp006_mshine_hidden_door_open',
            'mp006_mshine_location1', 'mp006_mshine_pic_09',
            'mp006_mshine_shelfwall1', 'mp006_mshine_shelfwall2',
            'mp006_mshine_Still_02', 'mp006_mshine_still_hatch',
            'mp006_mshine_theme_goth',
        },
    },

    new_austin = {
        label        = 'The New Austin Shack',
        verified     = false,
        outside      = { x = -2769.23,   y = -3048.90,   z = 11.38,    h = 0.0 },
        inside       = { x = -2769.30,   y = -3048.87,   z = -9.70,    h = 0.0 },
        menu         = { x = -2774.3393, y = -3030.6711, z = -11.8001, h = 46.0309 },
        ped          = { x = -2775.6644, y = -3029.7918, z = -11.8006, h = 226.2637 },
        bench        = { x = -2759.8417, y = -3046.2516, z = -11.3583, h = 224.7653 },
        interior     = 78337,
        interiorSets = {
            'mp006_mshine_band2', 'mp006_mshine_bar_benchAndFrame',
            'mp006_mshine_dressing_1', 'mp006_mshine_hidden_door_open',
            'mp006_mshine_location1', 'mp006_mshine_pic_09',
            'mp006_mshine_shelfwall1', 'mp006_mshine_shelfwall2',
            'mp006_mshine_Still_02', 'mp006_mshine_still_hatch',
            'mp006_mshine_theme_refined',
        },
    },

    hanover = {
        label        = 'The Hanover Shack',
        verified     = false,
        outside      = { x = 1627.64,   y = 822.90,   z = 144.03,   h = 0.0 },
        inside       = { x = 1627.64,   y = 822.90,   z = 123.94,   h = 0.0 },
        menu         = { x = 1622.6007, y = 841.0989, z = 121.8399, h = 46.0309 },
        ped          = { x = 1621.2756, y = 841.9782, z = 121.8394, h = 226.2637 },
        bench        = { x = 1637.0983, y = 825.5184, z = 122.2817, h = 224.7653 },
        interior     = 78593,
        interiorSets = {
            'mp006_mshine_band2', 'mp006_mshine_bar_benchAndFrame',
            'mp006_mshine_dressing_1', 'mp006_mshine_hidden_door_open',
            'mp006_mshine_location1', 'mp006_mshine_pic_09',
            'mp006_mshine_shelfwall1', 'mp006_mshine_shelfwall2',
            'mp006_mshine_Still_02', 'mp006_mshine_still_hatch',
            'mp006_mshine_theme_floral',
        },
    },

    manzanita_post = {
        label        = 'The Manzanita Post Shack',
        verified     = false,
        outside      = { x = -1861.70,   y = -1722.17,  z = 108.35,  h = 0.0 },
        inside       = { x = -1861.70,   y = -1722.17,  z = 88.35,   h = 0.0 },
        menu         = { x = -1866.7393, y = -1703.9711, z = 86.2499, h = 46.0309 },
        ped          = { x = -1868.0644, y = -1703.0918, z = 86.2494, h = 226.2637 },
        bench        = { x = -1852.2417, y = -1719.5516, z = 86.6917, h = 224.7653 },
        interior     = 77825,
        interiorSets = {
            'mp006_mshine_band2', 'mp006_mshine_bar_benchAndFrame',
            'mp006_mshine_dressing_1', 'mp006_mshine_hidden_door_open',
            'mp006_mshine_location1', 'mp006_mshine_pic_09',
            'mp006_mshine_shelfwall1', 'mp006_mshine_shelfwall2',
            'mp006_mshine_Still_03', 'mp006_mshine_still_hatch',
            'mp006_mshine_theme_hunter',
        },
    },
}
