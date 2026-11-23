-- pup_shaman | ancient trees (sink is in metres)

Config = Config or {}

local TRIBES <const> = { 'vttribe', 'bvtribe', 'bwtribe' }

Config.Trees = {
    {
        name = 'The Tree Of Innocence',
        coords = vector3(2733.59, 2304.38, 156.77), prop = 'p_tree_orange_01', sink = 0.5,
        jobs = TRIBES, curse = nil, blip = false, reward = nil,
        destinations = {
            vector3(3585.27, 1451.0, 47.54), vector3(1370.12, 1694.8, 213.07), vector3(2736.53, 1947.44, 160.59),
            vector3(1518.84, 2194.84, 334.06), vector3(776.71, 2434.68, 290.19), vector3(320.06, -1316.15, 44.38),
            vector3(675.17, -1815.8, 43.73), vector3(3147.11, -776.85, 44.24), vector3(-873.88, 1868.46, 405.63),
        },
        visions = {
            { label = 'Duck',    model = 'A_C_Duck_01',             filter = 'PhotoMode_FilterModern01' },
            { label = 'Crane',   model = 'A_C_CraneWhooping_01',    filter = 'PhotoMode_FilterModern03' },
            { label = 'Owl',     model = 'A_C_Owl_01',              filter = 'PhotoMode_FilterGame16' },
            { label = 'Vulture', model = 'A_C_Vulture_01',          filter = 'PhotoMode_FilterGame12' },
            { label = 'Condor',  model = 'A_C_CaliforniaCondor_01', filter = 'PhotoMode_FilterGame13' },
            { label = 'Eagle',   model = 'A_C_Eagle_01',            filter = 'PhotoMode_FilterGame11' },
        },
    },
    {
        name = 'The Tree Of Rebirth',
        coords = vector3(-2014.88, 57.61, 331.33), prop = 'rdr2_bush_bigberrymanzanita', sink = 0.5,
        jobs = TRIBES, curse = nil, blip = false, reward = nil,
        destinations = {
            vector3(-2863.61, 287.32, 192.21), vector3(-2794.07, -715.66, 267.89), vector3(-1828.78, 1889.77, 253.48),
            vector3(-460.3, 2246.9, 289.97), vector3(-70.83, 1579.02, 113.87), vector3(-1417.17, 2989.51, 419.82),
            vector3(-2775.4, -1430.57, 164.0), vector3(-2370.26, -1823.32, 108.34),
        },
        visions = {
            { label = 'Raccoon', model = 'A_C_Raccoon_01', filter = 'MP_BountyLagrasSwamp' },
            { label = 'Elk',     model = 'A_C_Elk_01',     filter = 'PlayerRPGCore' },
            { label = 'Deer',    model = 'A_C_Deer_01',    filter = 'PlayerRPGCore' },
            { label = 'Fox',     model = 'A_C_Fox_01',     filter = 'KingCastleBlue' },
            { label = 'Wolf',    model = 'A_C_Wolf',       filter = nil },
        },
    },
    {
        name = 'The Tree Of Echoes',
        coords = vector3(-3470.0, -1966.11, -0.84), prop = 'rdr_bush_neat_bc_sim', sink = 0.5,
        jobs = TRIBES, curse = nil, blip = false, reward = nil,
        destinations = {
            vector3(-4711.68, -2587.41, -2.37), vector3(-5610.85, -3802.33, -23.44), vector3(-3410.17, -2123.56, -5.85),
            vector3(-3138.7, -3565.62, 11.73), vector3(-3481.29, -2898.38, -1.23), vector3(-5808.95, -2695.6, -13.46),
            vector3(-3812.84, -3651.87, 40.84),
        },
        visions = {
            { label = 'Pronghorn', model = 'A_C_Pronghorn_01',     filter = 'PhotoMode_FilterGame08' },
            { label = 'Boar',      model = 'A_C_Boar_01',          filter = 'KingCastleBlue' },
            { label = 'Coyote',    model = 'A_C_Coyote_01',        filter = 'PhotoMode_FilterGame05' },
            { label = 'Ram',       model = 'MP_A_C_BIGHORNRAM_01', filter = 'PlayerRPGCore' },
            { label = 'Panther',   model = 'A_C_Panther_01',       filter = nil },
        },
    },
    {
        name = 'The Tree Of Memories',
        coords = vector3(2281.21, -641.63, 40.4), prop = 'p_tree_banana_01_md_crt', sink = 0.0,
        jobs = TRIBES, curse = nil, blip = false, reward = nil,
        destinations = {
            vector3(2214.74, -548.61, 41.44), vector3(2040.44, -293.11, 41.42), vector3(2334.37, -317.88, 41.21),
            vector3(2292.1, -989.58, 41.49), vector3(1705.5, -568.26, 42.85), vector3(2478.55, 103.82, 45.09),
            vector3(1962.5, -456.23, 40.83), vector3(2109.94, -1029.32, 42.06),
        },
        visions = {
            { label = 'Turtle',          model = 'A_C_TurtleSnapping_01', filter = 'PhotoMode_FilterGame18' },
            { label = 'Snake',           model = 'A_C_Snake_01',          filter = 'PhotoMode_FilterGame12' },
            { label = 'Small Alligator', model = 'MP_A_C_Alligator_01',   filter = 'PhotoMode_FilterGame14' },
            { label = 'Alligator',       model = 'A_C_Alligator_01',      filter = 'PhotoMode_FilterGame07' },
            { label = 'Large Alligator', model = 'A_C_Alligator_03',      filter = 'MP_DeathInk_Color10' },
        },
    },
    {
        name = 'Tree of Immortality',
        coords = vector3(3614.58, 1452.76, 48.39), prop = 'rdr_bush_neat_bb_sim', sink = 0.0,
        jobs = { 'vampire' }, curse = 'vamp', blip = false, reward = nil,
        destinations = {
            vector3(2617.36, -1230.67, 53.37), vector3(2768.26, -1252.33, 48.43), vector3(2553.75, -1416.81, 46.15),
            vector3(2762.76, -1078.82, 46.89), vector3(2692.06, -1068.0, 46.84),
        },
        visions = {
            { label = 'Bat',   model = 'a_c_bat_01',   filter = 'MP_DeathInk_Color10' },
            { label = 'Raven', model = 'A_C_Raven_01', filter = nil },
        },
    },
    {
        name = 'Tree of Magic',
        coords = vector3(1185.89, 2036.21, 323.59), prop = 'p_tree_orange_01', sink = 0.0,
        jobs = { 'witch' }, curse = 'witch', blip = false, reward = nil,
        destinations = {
            vector3(-2200.94, -1436.36, 137.81), vector3(356.47, 1301.61, 204.34), vector3(2687.22, 1633.86, 148.19),
        },
        visions = {
            { label = 'Cat', model = 'A_C_Cat_01', filter = 'PhotoMode_FilterModern03' },
            { label = 'Owl', model = 'A_C_Owl_01', filter = 'PhotoMode_FilterModern03' },
        },
    },
}
