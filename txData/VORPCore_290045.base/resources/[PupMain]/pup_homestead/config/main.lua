-- pup_homestead | main config (every setting is explained in the README)
Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    almanacCommand = 'farm',    -- opens the Almanac (your plots, the crop guide, your ledger)
    dropCanCommand = 'cbucket', -- puts away the can you are holding
    imagePath      = 'nui://vorp_inventory/html/img/items/',
}

-- Prompt keys. Change the hash only.
Config.Keys = {
    harvest   = 0x760A9C6F, -- G
    water     = 0xCEFD9220, -- E
    trim      = 0xB2F377E8, -- F
    fertilise = 0x8AAA0AD4, -- LALT
    remove    = 0x156F7119, -- BACKSPACE (hold)
    pump      = 0x760A9C6F, -- G at a water pump
    wagonFill = 0x760A9C6F, -- G: pour your can into a water wagon
    wagonDraw = 0xC7B5340A, -- ENTER: fill an empty can from a water wagon
}

-------------------------------------------------------------------------------
-- ITEMS  (must exist in vorp_inventory)
-------------------------------------------------------------------------------
Config.Items = {
    hoe           = 'hoe',                    -- needed to plant (kept)
    trimmer       = 'planttrimmer',           -- needed to trim (kept)
    emptyCan      = 'wateringcan_empty',
    cleanWaterCan = 'wateringcan',            -- from a pump or a water wagon
    dirtyWaterCan = 'wateringcan_dirtywater', -- from a river
    wateringCans  = { 'wateringcan', 'wateringcan_dirtywater' },
}

-------------------------------------------------------------------------------
-- PLANTING
-------------------------------------------------------------------------------
Config.Planting = {
    maxPlantsTotal = 20,  -- per character, all crops together (perk / job limit adds limit x 2)
    minSpacing     = 1.5, -- metres between plants
    blockedTowns   = { 'Annesburg', 'Armadillo', 'Blackwater', 'Rhodes', 'Siska', 'StDenis', 'Strawberry', 'Tumbleweed', 'Valentine', 'Vanhorn' },
    RestartLockMinutes = 5, -- minutes before a txAdmin scheduled restart (fires on its 30/15/10/5/4/3/2/1 min warnings); 0 = off
}

-------------------------------------------------------------------------------
-- PLANTS IN THE WORLD
-------------------------------------------------------------------------------
Config.Plants = {
    -- what other people may do to YOUR plants (the owner can always do everything)
    others = { water = true, fertilise = true, trim = true, harvest = true, check = true, remove = false },
    reach          = 2.5,   -- metres: how close you must be to work a plant
    renderDistance = 25,    -- metres: props spawn inside this
    syncDistance   = 120,   -- metres: the server sends you plants inside this
    syncSeconds    = 20,    -- how often your client asks for nearby plants
    blips          = true,  -- your own plants on the map
    blipSprite     = -675651933,
    lifetimeRestarts = 6,   -- a plant is pulled up after surviving this many restarts
    witherMinutes  = 0,     -- a ripe plant left this long rots (0 = never)

    -- how a plant's state is shown
    status = {
        show     = 'drawtext', -- 'drawtext' = coloured text over every plant near you
                               -- 'prompt'   = only in the title of the prompt at the plant
                               -- 'both'     = both
        distance = 6.0,        -- metres: the coloured text shows inside this
        height   = 0.4,        -- metres above the plant's spot
        scale    = 0.35,       -- text size
        colours  = {           -- { red, green, blue }
            growing = { 255, 255, 255 }, -- white: growing
            thirsty = { 220, 60, 50 },   -- red: needs water (it has stopped growing)
            watered = { 90, 160, 240 },  -- blue: watered and growing
            ready   = { 235, 195, 80 },  -- gold: ready to harvest
        },
    },
}

-------------------------------------------------------------------------------
-- WATER
-------------------------------------------------------------------------------
Config.Watering = {
    rain      = true,  -- rain waters every dry plant (needs weathersync; checked by the server)
    rainTypes = { 'rain', 'drizzle', 'shower', 'thunder', 'thunderstorm', 'hurricane' },
    pumpModel = -40350080,
    -- water wagons: model = how many cans they hold (kept while the wagon exists)
    wagons = { oilWagon01x = 160, oilWagon02x = 160, cart05 = 40 },
}

Config.Fertiliser = {
    bonus = 2, -- extra produce per reward on a fed plant (a crop's own fertBonus wins)
}

-------------------------------------------------------------------------------
-- SKILL BAR  (pup-minigames)
-------------------------------------------------------------------------------
Config.Minigame = {
    enabled       = true,
    ragdollOnFail = true,
}

Config.MinigameTuning = {
    baseArea = 30, areaLoss = 1.2, minArea = 17,
    baseSpeed = 0.52, speedGain = 0.035, maxSpeed = 0.82,
    perfectArea = 6,
}

-------------------------------------------------------------------------------
-- PLANT HEALTH  (a failed skill bar hurts the plant)
-------------------------------------------------------------------------------
Config.PlantHealth = {
    lossOnFail      = 10,  -- health lost per failed task
    unhealthyAt     = 50,  -- at or below this the harvest is smaller...
    unhealthyLoss   = 2,   -- ...by this much per reward (never below 1)
    hardAfterFail   = 1000, -- the skill bar difficulty after a failure (higher = harder)
    failCooldown    = 8,     -- seconds: one player's failed tasks count at most this often
    othersCanKill   = false, -- false = failed tasks by someone who is not the owner never take a plant below 1 health
}

-------------------------------------------------------------------------------
-- JOB BONUS  (stacks with pup-perks farming perks)
-------------------------------------------------------------------------------
-- limit = extra plants per crop, speed = time multiplier, radius / fertRadius = metres
local farmhand = { limit = 10, speed = 0.55, radius = 3.0, fertRadius = 3.0 }
Config.JobBonus = {
    speedFloor = 0.25, -- tasks never get faster than 25% of their base time
    jobs = {
        emfarm = farmhand, -- Emerald Ranch
        rdfarm = farmhand, -- Rhodes
        bwfarm = farmhand, -- Blackwater
        bvfarm = farmhand, -- Big Valley
    },
}
