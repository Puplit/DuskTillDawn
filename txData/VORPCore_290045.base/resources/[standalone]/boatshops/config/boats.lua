-- boatshops | boat catalogue and boat sets (shared)
-- The key is the game model name and is saved on every owned boat: never rename one.
--   label, desc, hash, buy, sell, slots, weapons (allowed in storage),
--   ignoreStack (ignore item stack limits in storage), jobs (empty = anyone)

BoatConfig.Boats = {
    rowboat = {
        label = 'Row Boat', desc = 'description', hash = -1613317544,
        buy = 250, sell = 125, slots = 40, weapons = false, ignoreStack = true, jobs = {},
    },
    rowboatSwamp = {
        label = 'Swamp Row Boat', desc = 'description', hash = -397513868,
        buy = 250, sell = 125, slots = 40, weapons = false, ignoreStack = false, jobs = {},
    },
    rowboatSwamp02 = {
        label = 'Swamp Row Boat 2', desc = 'description', hash = -258491284,
        buy = 250, sell = 125, slots = 40, weapons = true, ignoreStack = false, jobs = {},
    },
    canoe = {
        label = 'Regular Canoe', desc = 'description', hash = 1468884243,
        buy = 90, sell = 45, slots = 15, weapons = false, ignoreStack = false, jobs = {},
    },
    pirogue = {
        label = 'Pirogue Boat', desc = 'description', hash = -180755040,
        buy = 120, sell = 60, slots = 25, weapons = false, ignoreStack = false, jobs = {},
    },
    pirogue2 = {
        label = 'Pirogue 2 Boat', desc = 'description', hash = -1375371513,
        buy = 120, sell = 60, slots = 25, weapons = false, ignoreStack = false, jobs = {},
    },
    canoeTreeTrunk = {
        label = 'Tree Trunk Canoe', desc = 'description', hash = -666024656,
        buy = 100, sell = 25, slots = 20, weapons = false, ignoreStack = false, jobs = {},
    },
    keelboat = {
        label = 'Keel Boat', desc = 'fast boat', hash = -275688577,
        buy = 3000, sell = 1500, slots = 150, weapons = true, ignoreStack = false, jobs = {},
    },
    boatsteam02x = {
        label = 'Steam Boat 2', desc = 'Very fast boat', hash = -2022805833,
        buy = 5000, sell = 2500, slots = 150, weapons = true, ignoreStack = true, jobs = {},
    },
    -- cannot be boarded:
    -- horseboat = {
    --     label = 'Horse Boat', desc = 'description', hash = 1975376854,
    --     buy = 1200, sell = 2500, slots = 150, weapons = true, ignoreStack = true, jobs = {},
    -- },
}

-- named lists a shop can sell
BoatConfig.Sets = {
    standard = {
        'rowboat', 'rowboatSwamp', 'rowboatSwamp02', 'canoe', 'pirogue', 'pirogue2',
        'canoeTreeTrunk', 'keelboat', 'boatsteam02x',
    },
}
