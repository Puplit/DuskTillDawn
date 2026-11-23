-- boatshops | shops (shared)
-- A shop takes every field it leaves out from BoatConfig.ShopDefaults.
--   name        menu title and park prompt label
--   prompt      open prompt label (defaults to name)
--   blip        { show, name (defaults to name), sprite }
--   counter     { x, y, z, h }  prompt, blip and shop keeper
--   launch      { x, y, z, h }  where boats are launched and previewed
--   park        { x, y, z }     park point (defaults to launch)
--   exit        { x, y, z, h }  where the player lands after parking (defaults to counter)
--   keeper      { show, model, walkIn = { x, y, z } }
--   hours       { enabled, open, close } on the game clock
--   jobs        list of jobs allowed to use the shop (empty = everyone)
--   minGrade    lowest job grade allowed (only with jobs)
--   openRadius, parkRadius (metres)
--   boats       a set name from BoatConfig.Sets, or a list of boat keys
--   overrides   [boatKey] = { buy, sell, slots } for this shop only

BoatConfig.ShopDefaults = {
    blip = { show = false, sprite = 2033397166 },
    keeper = { show = false, model = 'A_M_M_UniBoatCrew_01', walkIn = { x = -733.0, y = -1221.75, z = 44.73 } },
    hours = { enabled = false, open = 7, close = 21 },
    jobs = {},
    minGrade = nil,
    openRadius = 3.0,
    parkRadius = 4.0,
    boats = 'standard',
    overrides = {},
}

-- the steam boat at the bigger docks
local steamDock = { boatsteam02x = { buy = 10000, slots = 500 } }

BoatConfig.Shops = {
    Guarma = {
        name = 'Dock Boats',
        blip = { show = true },
        counter = { x = 1292.13, y = -6848.81, z = 43.09, h = 139.695175109 },
        launch = { x = 1263.95, y = -6830.66, z = 40.28, h = 135.70881652832 },
        keeper = { walkIn = { x = 1292.13, y = -6848.81, z = 43.09 } },
        overrides = steamDock,
    },
    shadybell = {
        name = 'Dock Boats',
        counter = { x = 2101.30712, y = -1811.39038, z = 42.19664, h = 139.695175109 },
        launch = { x = 2108.35595, y = -1803.37573, z = 40.6, h = 135.70881652832 },
        keeper = { walkIn = { x = 2101.30712, y = -1811.39038, z = 42.19664 } },
        overrides = steamDock,
    },
    phantomdocks = {
        name = 'Dock Boats',
        counter = { x = 369.67, y = -1349.99, z = 41.44, h = 139.695175109 },
        launch = { x = 369.38, y = -1381.49, z = 43.44, h = 135.70881652832 },
        keeper = { walkIn = { x = 369.67, y = -1349.99, z = 44.1 } },
        overrides = steamDock,
    },
    tommydock2 = {
        name = 'Dock Boats',
        counter = { x = 3280.1, y = -1278.58, z = 44.1, h = 139.695175109 },
        launch = { x = 3255.8, y = -1303.01, z = 40.2, h = 135.70881652832 },
        keeper = { walkIn = { x = 3280.1, y = -1278.58, z = 44.1 } },
        overrides = steamDock,
    },
    tommydock = {
        name = 'Dock Boats',
        counter = { x = 337.12457275391, y = -684.76361083984, z = 43.059169769287, h = 139.695175109 },
        launch = { x = 327.56295776367, y = -683.86071777344, z = 41.063053131104, h = 135.70881652832 },
        keeper = { walkIn = { x = 337.12457275391, y = -684.76361083984, z = 43.059169769287 } },
        overrides = steamDock,
    },
    siska = {
        name = 'Siska Boats',
        blip = { show = true, name = 'Sisika Boats' },
        counter = { x = 3274.9, y = -712.3, z = 43.03, h = 186.24 },
        launch = { x = 3256.323, y = -709.05, z = 41.39, h = 354.84 },
        keeper = { walkIn = { x = 3274.9, y = -712.3, z = 43.03 } },
        jobs = { 'police', 'doctor', 'marshal', 'sisika' },
        overrides = steamDock,
    },
    saintdenis = {
        name = 'Saint Denis Boats',
        blip = { show = true },
        counter = { x = 2949.77, y = -1250.18, z = 42.411, h = 95.39 },
        launch = { x = 2947.5, y = -1257.21, z = 41.58, h = 274.14 },
        keeper = { walkIn = { x = 2892.57, y = -1242.28, z = 45.97 } },
        overrides = steamDock,
    },
    blackwater = {
        name = 'Blackwater Boats',
        blip = { show = true },
        counter = { x = -682.36, y = -1242.97, z = 42.11, h = 88.9 },
        launch = { x = -688.04, y = -1251.69, z = 40.18, h = 88.9 },
    },
    annesburg = {
        name = 'Annesburg Boat.CO',
        prompt = 'Annesburg BOAT shop',
        blip = { show = true, name = 'annesburg' },
        counter = { x = 3013.15, y = 1329.76, z = 42.71, h = 328.34 },
        launch = { x = 3021.35, y = 1327.58, z = 40.18, h = 164.33 },
        exit = { x = 3013.92, y = 1333.07, z = 42.71, h = 328.34 },
        keeper = { walkIn = { x = 3018.0, y = 1353.55, z = 42.72 } },
    },
    blues = {
        name = 'Secret Boats',
        counter = { x = -2574.89, y = -1383.82, z = 149.23, h = 104.48 },
        launch = { x = -2565.23, y = -1436.89, z = 144.89, h = 230.7 },
    },
    house = {
        name = 'House Boats',
        counter = { x = 2266.569, y = -1217.02, z = 42.26, h = 104.48 },
        launch = { x = 2265.68, y = -1196.84, z = 40.3, h = 56.42 },
    },
    house2 = {
        name = 'House Boats',
        counter = { x = 886.18, y = -1780.25, z = 42.18, h = 104.48 },
        launch = { x = 858.16, y = -1771.0, z = 40.18, h = 56.42 },
    },
    roanokevalley = {
        name = 'Roanoke Boats',
        blip = { show = true },
        counter = { x = 2450.49, y = 1753.93, z = 85.57, h = 93.77 },
        launch = { x = 2444.15, y = 1753.37, z = 84.94, h = 196.64 },
    },
    elysian = {
        name = 'Elysian Boats',
        blip = { show = true },
        counter = { x = 2481.05, y = 776.17, z = 67.34, h = 93.77 },
        launch = { x = 2475.68, y = 789.99, z = 66.26, h = 134.7 },
    },
    thieveslanding = {
        name = 'Thieveslanding Boats',
        blip = { show = true },
        counter = { x = -1361.36, y = -2338.8, z = 42.84, h = 267.39 },
        launch = { x = -1349.11, y = -2337.78, z = 40.37, h = 180.0 },
    },
    secret2 = {
        name = 'Secret Boats',
        counter = { x = -1420.93, y = -2685.68, z = 40.8, h = 267.39 },
        launch = { x = -1416.86, y = -2691.04, z = 39.01, h = 180.0 },
    },
    tribal = {
        name = 'Tribal Boats',
        counter = { x = -1557.05, y = -1042.84, z = 65.65, h = 292.71 },
        launch = { x = -1546.31, y = -1040.23, z = 65.27, h = 269.83 },
    },
    limpany = {
        name = 'Limpany Boats',
        blip = { show = true },
        counter = { x = -433.39, y = -108.3, z = 41.85, h = 65.15 },
        launch = { x = -442.93, y = -103.1, z = 40.89, h = 54.05 },
    },
    caliga = {
        name = 'Caliga Boats',
        blip = { show = true },
        counter = { x = 1821.97, y = -1201.46, z = 42.22, h = 65.15 },
        launch = { x = 1816.22, y = -1197.25, z = 40.3, h = 31.84 },
    },
    vanhorn = {
        name = 'Vanhorn Boats',
        blip = { show = true },
        counter = { x = 2988.53, y = 501.88, z = 41.69, h = 271.19 },
        launch = { x = 3000.66, y = 498.81, z = 40.26, h = 256.97 },
    },
    secret3 = {
        name = 'Secret Boats',
        counter = { x = 2265.77, y = -1225.92, z = 42.21, h = 86.75 },
        launch = { x = 2255.54, y = -1225.17, z = 40.25, h = 84.94 },
    },
    highland = {
        name = 'Highland Boats',
        counter = { x = -410.17, y = -1112.25, z = 42.17, h = 87.65 },
        launch = { x = -423.3, y = -1102.04, z = 40.29, h = 71.22 },
        keeper = { walkIn = { x = 2892.57, y = -1242.28, z = 45.97 } },
    },
    secret4 = {
        name = 'Secret Boats',
        counter = { x = 2014.28, y = -756.95, z = 41.89, h = 34.97 },
        launch = { x = 2007.34, y = -750.6, z = 40.24, h = 34.97 },
    },
}
