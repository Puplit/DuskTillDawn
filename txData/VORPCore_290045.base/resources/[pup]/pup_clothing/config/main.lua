-- pup_clothing | settings

Config = {}

Config.Debug = {
    client = false,
    server = false,
}

---------------------------------------------------------------------------
-- prompt and points
---------------------------------------------------------------------------
Config.Prompt = {
    key         = 0xD9D0E1C0, -- SPACE
    holdMs      = 1000,
    radius      = 2.0,        -- metres
    tightRadius = 1.0,        -- metres, for points with tight = true
    nearSleep   = 0,          -- ms
    farSleep    = 1000,       -- ms
    nearMargin  = 10.0,       -- metres
}

Config.Blips = {
    style = 1664425300,
    store    = { sprite = 1195729388, scale = 0.2 },
    wardrobe = { sprite = 1496995379, scale = 0.2 },
}

Config.Stores = {
    { x = -329.37,         y = 774.65,          z = 121.63,          blip = true },
    { x = 1332.03,         y = -1372.8,         z = 80.49,           blip = true },
    { x = 2549.635,        y = -1167.984,       z = 53.434,          blip = true },
    { x = -767.507,        y = -1295.332,       z = 43.490,          blip = true },  -- Blackwater
    { x = -1794.89,        y = -385.22,         z = 160.33,          blip = true },
    { x = 1791.12,         y = -815.78,         z = 192.64,          blip = false },
    { x = 1005.8,          y = -1776.9,         z = 52.04,           blip = false },
    { x = 2945.92,         y = 1330.31,         z = 44.45,           blip = true },
    { x = 1420.2,          y = 375.5,           z = 90.3,            blip = false }, -- Emerald
    { x = -391.9547,       y = -138.4168,       z = 48.2675,         blip = true },
    { x = 3292.5070800781, y = -1331.955078125, z = 42.863586425781, blip = false }, -- Saint Denis boat
    { x = 1296.739,        y = -6917.921,       z = 51.605,          blip = false }, -- Guarma
    { x = 2977.59,         y = 572.38,          z = 44.39,           blip = true },
    { x = 474.779,         y = 2269.831,        z = 248.881,         blip = true },  -- Wapiti
    { x = -1427.478,       y = -2268.923,       z = 43.344,          blip = false, enabled = false }, -- Thieves Landing
}

Config.Wardrobes = {
    { x = -325.29,    y = 766.24,     z = 117.48,  blip = true },  -- Valentine motel
    { x = -297.930,   y = 808.418,    z = 118.883, blip = true },  -- Valentine tailor
    { x = -764.1127,  y = -1294.7044, z = 43.9356, blip = true },
    { x = -1817.11,   y = -368.77,    z = 166.54,  blip = true },
    { x = -825.40,    y = -1323.76,   z = 47.91,   blip = true },  -- Blackwater saloon
    { x = 1331.86,    y = -1377.35,   z = 80.55,   blip = true },  -- Rhodes
    { x = 2628.8,     y = -1221.59,   z = 59.58,   blip = false }, -- Saint Denis saloon, upstairs
    { x = 2384.15,    y = -1210.36,   z = 51.81,   blip = false }, -- Saint Denis big house
    { x = 1790.56,    y = -819.13,    z = 192.64,  blip = false }, -- hideout
    { x = 1005.54,    y = -1767.8,    z = 52.04,   blip = false }, -- Braithwaite Manor
    { x = 1015.64,    y = -1777.85,   z = 52.04,   blip = false }, -- Braithwaite Manor
    { x = 2956.74,    y = 1330.18,    z = 44.21,   blip = false }, -- Annesburg
    { x = 1423.23,    y = 383.5,      z = 90.3,    blip = false }, -- Emerald
    { x = 2552.72,    y = -1312.78,   z = 49.21,   blip = false }, -- Saint Denis theatre
    { x = 2978.23,    y = 575.84,     z = 44.38,   blip = true },  -- Van Horn
    { x = 2556.3623,  y = -1160.2585, z = 53.3517, blip = true },
    { x = -392.1686,  y = -131.5727,  z = 48.2675, blip = false, enabled = false }, -- Limpany
    { x = -1431.232,  y = -2267.971,  z = 43.344,  blip = false, enabled = false }, -- Thieves Landing
    { x = 1289.524,   y = -6919.844,  z = 51.583,  blip = false, enabled = false }, -- Guarma
}

---------------------------------------------------------------------------
-- store
---------------------------------------------------------------------------
Config.Store = {
    price             = 10,   -- cash
    hideUnnamed       = false,
    maleForceNone     = { 'Skirt' },
    failsafeHoldMs    = 2000,
    failsafeKey       = 0x156F7119, -- BACKSPACE
}

Config.Creator = { enabled = true }

Config.Starter = { enabled = false, delayMs = 3000 }

Config.Tints = {
    enabled       = false,
    defaultPrice  = 0,   -- per recoloured garment
    prices        = {},  -- [category key] = price
    chargeUnchanged = false,
    channelMax    = 254,
}

Config.Outfits = {
    maxPerCharacter = 50, -- 0 = no limit
    titleMax        = 255, -- characters
    nameBoxMax      = 50,  -- characters
}

Config.Npc = {
    useForExtras     = true,
    inStore          = false,
    keepTailorPieces = false,
    resource         = 'pup_tailor',
    file             = 'shared/npc_clothing.lua',
}

Config.Toggles = { enabled = true }

---------------------------------------------------------------------------
-- server rules
---------------------------------------------------------------------------
Config.Server = {
    requireLocation     = true,
    reach               = 6.0,  -- metres
    passUnknownPosition = true,
    payloadMax          = 16000, -- bytes
    extrasMaxSlots      = 128,
    syncKeyMax          = 64,
    rate = {                    -- ms
        open   = 1000,
        buy    = 1500,
        list   = 500,
        wear   = 1500,
        delete = 400,
        extras = 500,
        sync   = 250,
        starter = 5000,
    },
}

---------------------------------------------------------------------------
-- camera, light and keys while the store is open
---------------------------------------------------------------------------
Config.Camera = {
    angle        = 45.0,
    fov          = 40.0,
    creatorAngle = 180.0,
    creatorFov   = 30.0,
    sideOffset   = 0.45,  -- metres
    zoomMin      = 0.7,  zoomMax = 2.8,  zoomDefault = 2.8,
    heightMin    = -1.0, heightMax = 1.2, heightDefault = -0.15,
    turnStep     = 2.0,  zoomStep = 0.03, heightStep = 0.02,
    startHeading = 334.0,
    easeMs       = 500,
}

Config.Light = { range = 2.5, intensity = 10.0, offset = 1.0 }

Config.Keys = {
    turnLeft  = `INPUT_ENTER`,        -- E
    turnRight = `INPUT_MELEE_ATTACK`, -- F
    zoomIn    = `INPUT_SPRINT`,       -- SHIFT
    zoomOut   = 0x8AAA0AD4,           -- ALT
    raise     = `INPUT_JUMP`,         -- SPACE
    lower     = `INPUT_DUCK`,         -- CTRL
    pushToTalk = `INPUT_PUSH_TO_TALK`,
    radioTalk  = 249,
}

Config.DisabledControls = {
    `INPUT_ATTACK`, `INPUT_AIM`, `INPUT_JUMP`, `INPUT_MELEE_ATTACK`, `INPUT_RELOAD`, `INPUT_ENTER`,
    `INPUT_WHISTLE`, `INPUT_COVER`, `INPUT_QUICK_USE_ITEM`, `INPUT_OPEN_JOURNAL`, `INPUT_OPEN_SATCHEL_MENU`,
    `INPUT_OPEN_WHEEL_MENU`, `INPUT_OPEN_EMOTE_WHEEL`, `INPUT_MAP`, `INPUT_PLAYER_MENU`,
    `INPUT_SELECT_NEXT_WEAPON`, `INPUT_SELECT_PREV_WEAPON`, `INPUT_INTERACT_ANIMAL`,
    `INPUT_MOVE_LR`, `INPUT_MOVE_UD`, `INPUT_MOVE_UP_ONLY`, `INPUT_MOVE_DOWN_ONLY`,
    `INPUT_MOVE_LEFT_ONLY`, `INPUT_MOVE_RIGHT_ONLY`, `INPUT_DUCK`, `INPUT_SPRINT`, 0x8AAA0AD4,
}

---------------------------------------------------------------------------
-- timings
---------------------------------------------------------------------------
Config.Timing = {           -- all ms
    promptDelayMs    = 0,
    hudAskMs         = 1500,
    extrasAfterStart = 8000,
    extrasAfterSelect = 8000,
    beforeRcMs       = 500,
    pedSwapMaxMs     = 5000,
    streamMaxMs      = 5000,
    settleMs         = 300,
    cancelRcMs       = 200,
    outfitReapplyMs  = 2000,
    deleteRefreshMs  = 300,
}
