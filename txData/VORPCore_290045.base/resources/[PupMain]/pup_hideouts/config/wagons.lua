-- pup_hideouts | still parts missions (wagon robberies)

Config = Config or {}

Config.Wagons = {
    soloOnly = false,       -- true = entities are local to the spawner (not networked)
    escortsPerWagon = 6,
    cooldownMinutes = 30,
    windowMinutes = 120,
    failDistance = 1000.0,  -- flat distance from the wagon
    serverReach = 15.0,
    completeReach = 30.0,
    stripSeconds = 480,
    alertPolice = true,
    explosive = { required = true, item = 'dynamite', count = 1 },
    fuseSeconds = 10,
    spawnDistance = 100.0,
    promptDistance = 5.0,
    spawnRetrySeconds = 10,
    spawnCheckRadius = 60.0, -- the reported wagon must be this close to the mission spot (it starts driving at once)

    charge = {
        icon = 'fa-solid fa-bomb', zone = 24, perfect = 6, speed = 0.7, iconSpeed = 1.5,
        roundsMin = 2, roundsMax = 5, misses = 0,
        zoneStep = 2, speedStep = 0.05, minZone = 12, maxSpeed = 1.2,
    },

    -- still level -> job levels it may run
    allowed = {
        [0] = { 1 },
        [1] = { 1, 2 },
        [2] = { 2, 3 },
        [3] = { 2, 3 },
    },
    -- extra escort wagons behind the main one, by job level (metres back)
    followers = { [1] = {}, [2] = { 20.0 }, [3] = { 20.0, 10.0 } },

    model = 'coach3',
    weapons = { 'WEAPON_REPEATER_WINCHESTER', 'WEAPON_REVOLVER_DOUBLEACTION', 'WEAPON_RIFLE_SPRINGFIELD', 'WEAPON_RIFLE_BOLTACTION' },

    blipSprite = 1612913921, blipColor = 0x6F85C3CE, wagonBlipStyle = 953018525,
    explosionType = 25,
    dynamiteProp = 'p_dynamite01x', bagProp = 'p_moneybag01x',
    crouchDict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', crouchAnims = { 'idle_a', 'idle_c' },
    doorBone = 'door_dside_f',
}

----------------------------------------------------------------------------------------------------
-- Wagon loot (chance is out of 10, not percent)
----------------------------------------------------------------------------------------------------

local LEVEL1_LOOT = {
    { item = 'condenser',  label = 'Condenser',      amount = 1, chance = 10 },
    { item = 'pipecopper', label = 'Copper Pipe',    amount = 1, chance = 10 },
    { item = 'pot',        label = 'Distillery Pot', amount = 1, chance = 5 },
    { item = 'rubbertube', label = 'Rubber Tube',    amount = 1, chance = 5 },
    { item = 'dynamite',   label = 'dynamite',       amount = 1, chance = 2 },
}

local LEVEL2_LOOT = {
    { item = 'condenser',  label = 'Condenser',      amount = 1, chance = 6 },
    { item = 'pipecopper', label = 'Copper Pipe',    amount = 1, chance = 6 },
    { item = 'pot',        label = 'Distillery Pot', amount = 1, chance = 10 },
    { item = 'rubbertube', label = 'Rubber Tube',    amount = 1, chance = 10 },
    { item = 'stillkit',   label = 'Still Kit',      amount = 1, chance = 5 },
    { item = 'barrel',     label = 'Barrel',         amount = 1, chance = 5 },
    { item = 'dynamite',   label = 'dynamite',       amount = 1, chance = 2 },
}

local LEVEL3_LOOT = {
    { item = 'condenser',  label = 'Condenser',      amount = 1, chance = 5 },
    { item = 'pipecopper', label = 'Copper Pipe',    amount = 1, chance = 5 },
    { item = 'pot',        label = 'Distillery Pot', amount = 1, chance = 6 },
    { item = 'rubbertube', label = 'Rubber Tube',    amount = 1, chance = 6 },
    { item = 'stillkit',   label = 'Still Kit',      amount = 1, chance = 10 },
    { item = 'barrel',     label = 'Barrel',         amount = 1, chance = 10 },
    { item = 'dynamite',   label = 'dynamite',       amount = 1, chance = 2 },
    { item = 'alcohol',    label = 'Alcohol',        amount = 5, chance = 5 },
    { item = 'apple',      label = 'Apple',          amount = 5, chance = 5 },
}

-- loot(LIST, extra, extra, ...) = the list's items followed by any extras (the list itself is not changed)
local function loot(list, ...)
    local out = {}
    for _, v in ipairs(list) do out[#out + 1] = v end
    for _, v in ipairs({ ... }) do out[#out + 1] = v end
    return out
end

-- the first escort model drives
Config.WagonLevels = {
    [1] = {
        escorts = { 'U_M_M_ODriscollBrawler_01', 'U_M_M_BHT_ODRISCOLLMAULED', 'U_M_M_BHT_ODRISCOLLDRUNK', 'CS_ColmODriscoll' },
        locations = {
            { coords = vector3(1599.916625, 855.404, 140.00874), heading = 155.27587, rewards = loot(LEVEL1_LOOT,
                { item = 'alcohol', label = 'Alcohol', amount = 5, chance = 5 }) },
            { coords = vector3(2550.3593, -214.27009, 42.95154), heading = 167.73382, rewards = loot(LEVEL1_LOOT) },
            { coords = vector3(2830.57, 931.54, 48.52), heading = 204.55, rewards = loot(LEVEL1_LOOT) },
        },
    },
    [2] = {
        escorts = { 'U_M_M_ODriscollBrawler_01', 'U_M_M_BHT_ODRISCOLLMAULED', 'U_M_M_BHT_ODRISCOLLDRUNK' },
        locations = {
            { coords = vector3(477.62918, 527.40332, 109.8955), heading = 174.6644, rewards = loot(LEVEL2_LOOT,
                { item = 'apple', label = 'Apple', amount = 5, chance = 8 }) },
            { coords = vector3(-1156.0123, 730.9919, 108.8246), heading = 108.8246, rewards = loot(LEVEL2_LOOT,
                { item = 'alcohol', label = 'Alcohol', amount = 5, chance = 5 }) },
            { coords = vector3(-1719.8168, -66.1011, 176.6823), heading = 8.0801, rewards = loot(LEVEL2_LOOT,
                { item = 'alcohol', label = 'Alcohol', amount = 5, chance = 5 },
                { item = 'apple',   label = 'Apple',   amount = 5, chance = 5 }) },
        },
    },
    [3] = {
        escorts = { 'U_M_M_ODriscollBrawler_01', 'U_M_M_BHT_ODRISCOLLMAULED', 'U_M_M_BHT_ODRISCOLLDRUNK' },
        locations = {
            { coords = vector3(-2539.9277, -1369.6427, 151.1600), heading = 287.4328, rewards = loot(LEVEL3_LOOT) },
            { coords = vector3(-1854.0235, -1686.9230, 106.8346), heading = 107.21614, rewards = loot(LEVEL3_LOOT) },
            { coords = vector3(-881.3605, -742.6576, 59.6162), heading = 110.9699, rewards = loot(LEVEL3_LOOT) },
        },
    },
}
