-- river + wash barrel | settings, read on both sides (the server registers the items
-- and rolls the poison from these values)

WaterConfig = {}

WaterConfig.General = {
    debug = false,   -- console tracing on both sides
}

-- prompt keys (control hashes). The river and the trough/barrel use different wash keys,
-- and the trough/barrel wins when both apply, so one press never washes twice.
WaterConfig.Keys = {
    riverWash = 0x4CC0E2FE,    -- B
    riverDrink = 0xD8F73058,   -- U
    barrelWash = 0xDFF812F9,   -- E
    modifier = 0x8AAA0AD4,     -- Alt, only used when Prompts.requireModifier is on
}

WaterConfig.Prompts = {
    holdMs = 800,              -- how long a prompt key is held
    requireModifier = false,   -- true = the prompts only show while Keys.modifier is held
}

-- item names: must match sql/river/install.sql. Servers that still have the older bottle
-- names in their database can run sql/river/rename-bottles.sql to move them over.
WaterConfig.Items = {
    dirtyBottle = 'bottle_river_water',
    cleanBottle = 'bottle_boiled_water',
    -- filled at the river, given back after a drink. false = no empty bottle (the old way):
    -- the item is not registered or handed out, a dirty bottle used in water is refilled
    -- with dirty water, a clean bottle is always drunk, and drinking keeps nothing.
    emptyBottle = false,   -- 'water_bottle_empty' to turn it on (import its row from sql/river/install.sql)
    antidote = 'antipoison',
}

-- the chance is 1 in <odds>
WaterConfig.Poison = {
    bottleOdds = 2,            -- a dirty bottle
    riverOdds = 3,             -- drinking straight from the river
    vomitIntervalMs = 30000,
    durationMinutes = 30,      -- poison wears off after this (0 = only the antidote cures it)
    -- no vomiting in these states; the vomit waits until they end
    skipWhen = { dead = true, mounted = true, vehicle = true },
}

-- fred_meta:consume values: food, thirst, metabolism, inner stamina, inner stamina gold,
-- outer stamina gold, inner health, inner health gold, outer health gold
WaterConfig.Stats = {
    drink = { 0, 20, 0, 0, 0, 0, 0, 0, 0 },
    poisoned = { -20, -20, -20, 0, 0, 0, 0, 0, 0 },
}

WaterConfig.River = {
    scanMs = 500,                  -- how often the water check runs while not in water
    recheckMs = 250,               -- how often it re-checks while in water
    washMs = 5000,
    drinkMs = 10000,
    drinkCooldownSeconds = 20,     -- between two drinks straight from the river (server)
    -- only these water-map zones count as river / lake water (the custom Spots always count)
    restrictZones = true,
    zones = {
        231313522, 2005774838, -1287619521, -196675805, -1308233316, 1755369577,
        -2040708515, -557290573, -247856387, 370072007, -1504425495, -1369817450,
        -1356490953, -1781130443, -1300497193, -1276586360, -1410384421, 650214731,
        592454541, -804804953, 1245451421, -218679770, -1817904483, -811730579,
        -1229593481, -105598602,
    },
}

-- extra places that count as water even when dry (radius in metres)
WaterConfig.Spots = {
    { coords = vector3(2642.3, -1176.04, 53.37), radius = 3.0 },
    { coords = vector3(2629.41, -1223.69, 59.67), radius = 2.0 },
}

WaterConfig.Bottles = {
    fillMs = 5000,
    -- the server accepts a fill / drink this long after the bottle was used (seconds)
    fillWindow = { min = 4, max = 20 },
    useWindowSeconds = 20,
    drinkAnimMs = 4000,
    vomitDelayMs = 6000,           -- a poisoned bottle: pause before vomiting
    prop = 'p_bottlejd01x',
    itemKey = -1199896558,         -- the game's coffee consumable, the one that works
    grip = 'p_bottleJD01x_ph_r_hand',
    interaction = 'DRINK_BOTTLE@Bottle_Cylinder_D1-3_H30-5_Neck_A13_B2-5_TABLE_HOLD',
    -- the game names this bottle's prompt from this text entry; it is set to
    -- WaterLocale.bottleName for the drink and put back afterwards (false = leave it)
    labelEntry = 'WHISKEY',
}

-- boiling dirty water into clean water at a fire
WaterConfig.Boil = {
    enabled = true,
    radius = 2.0,                  -- metres from a fire model
    durationMs = 10000,
    moveLimit = 2.5,               -- moving this far from the start cancels it
    serverSlackMs = 15000,         -- extra time the server allows after durationMs
    models = {
        'p_campfire01x', 'p_campfire02x', 'p_campfire02xb', 'p_campfire02x_script',
        'p_campfire02x_dynamic', 'p_campfire03x', 'p_campfire04x', 'p_campfire05x',
        'p_campfire05x_script', 'p_campfire_win2_01x', 'p_campfirecombined01x',
        'p_campfirecombined02x', 'p_campfirecombined03x', 'p_campfirecombined04x',
        'p_campfirecook01x', 'p_campfirecook02x', 'p_campfirerocksml02x',
        'p_cookfirestructure02x', 's_sav_cookfire01x',
        -1279776992,               -- pup_camps crafting fire
    },
}

WaterConfig.Barrel = {
    radius = 0.8,
    scanMs = 500,                  -- how often troughs / barrels are looked for
    turnMs = 1000,
    afterTurnMs = 1000,
    cleanDelayMs = 2000,
    models = {
        1781823699, 'p_watertrough01x', 'p_watertrough01x_new', 'p_watertrough02x',
        'p_watertrough03x', 'p_watertroughsml01x', 'p_barrel_ladle01x',
        'p_barrelladle1x_survivor',
    },
    -- the screen effects a barrel wash stops (drunk, drug, poison looks); others are left alone
    effects = {
        'PlayerDrunk01', 'PlayerDrunk01_PassOut', 'PlayerDrunkAberdeen',
        'PlayerDrugsHalluc01', 'playerdrugshalluc01', 'Playerdrughalluc01',
        'PlayerDrugsPoisonWell', 'PlayerRPGcore',
    },
}

WaterConfig.Anims = {
    riverWash = { dict = 'amb_misc@world_human_wash_face_bucket@ground@male_a@idle_d', clip = 'idle_l' },
    barrelMale = { dict = 'mp_amb_player@prop_player_wash_face_barrel@sober@male_a@base', clip = 'base' },
    barrelFemale = { dict = 'amb_misc@world_human_wash_face_bucket@table@female_a@idle_d', clip = 'idle_j' },
    fill = 'WORLD_HUMAN_CROUCH_INSPECT',
    boil = 'WORLD_HUMAN_CROUCH_INSPECT',
    riverDrink = 'WORLD_HUMAN_BUCKET_DRINK_GROUND',
    vomit = 'WORLD_HUMAN_VOMIT',
    vomitMs = 8000,
}
