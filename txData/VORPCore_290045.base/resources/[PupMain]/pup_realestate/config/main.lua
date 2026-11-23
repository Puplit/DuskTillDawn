-- pup_realestate | main settings

Config = {}

-- console chatter (turn off on a live server)
Config.Debug = false

-- clients re-request everything 3 s after the resource (re)starts
Config.ResyncOnRestart = true

-- a house counts as "near" within this many metres of its front door
Config.RenderDistance = 50.0

-- minutes between the periodic furniture save and storage report rewrite
Config.SaveIntervalMinutes = 30

-- interior routing bucket = playerhousing row id + this offset
Config.BucketOffset = 9959

-- houses one character may own (motel rooms do not count)
Config.MaxHousesPerCharacter = 2

-- storage slot cap (0 = no cap)
Config.MaxSlots = 0

-- furniture range cap for the admin panel (0 = no cap)
Config.MaxRange = 100

-- relog inside an interior: put the player outside instead of back inside
Config.SafeExitOnRelog = true

-- remember the last outdoor position through pup_hideouts
Config.Underground = true

-- owners may swap their teleporter interior
Config.AllowInteriorChange = true

-- owners may connect their own Discord webhook
Config.OwnerWebhooks = true

Config.Jobs = {
    realtor = 'realestate',      -- sees all owned-house blips, creates houses
    realtorDeleteGrade = 2,      -- grade needed to remove an unsold house
    admin = { 'admin' },         -- full staff rights
    auctionRealtors = { 'realtor', 'realestate' },
    realtorsMayCreate = false,   -- auction realtors may also create houses
}

Config.Sale = {
    sellerShare = 0.5,           -- of the price, to the stored seller (Sold Home Ledger)
    societyShare = 0.0,          -- of the price, to the realtor business ledger
    society = true,              -- pup_business integration on/off
    societyJob = 'realestate',
}

Config.Ledger = {
    disabled = false,
    cap = 5000,                  -- 0 = no cap
    taxLedger = true,            -- separate tax ledger
}

Config.Tax = {
    monthly = { enabled = true, day = 15, hour = 16, minute = 0 },
    weekly = { enabled = false, days = { 3, 10, 17, 24 }, hour = 6, minute = 10 },
}

Config.Storage = {
    blacklist = { 'lockpick', 'thermite', 'thermitecharge' },
}

-- vorp_inventory side: catalogue settings are filled in by config/furniture.lua
Config.Furniture = {
    useItems = true,             -- place from inventory items (false = buy with cash)
    useGizmo = true,             -- vorp_lib gizmo when that resource is started
    maxPieces = 200,
    sellRate = 1.0,              -- money mode refund rate
    -- pieces added on top of config/furniture.lua:
    -- ['Menu Section'] = { ['Label'] = { cost = 10, hash = `model_name`, item = 'item_name' } }
    extra = {},
    modelOverrides = {}, -- [label or item name] = model
}

Config.Doorlocks = {
    enabled = false,             -- hand real doors to the doorlocks resource
    lockpickable = false,
    resource = 'doorlocks',
}

Config.Labels = {
    floatingDoorLabels = false,
    lockedSign = true,
    lockedSignDistance = 6.0,
    lockedSignHeight = 1.3,
    lockedSignPairGap = 2.6,
}

Config.Blips = {
    forSaleShown = true,
    forSale = -235048253,
    owned = -235048253,
    scale = 0.2,
    realtorSeesAll = true,       -- the realtor job sees every owned house
}

Config.Auctions = {
    defaultHours = 24,
    maxHours = 168,
    minRaise = 10,
    sealed = true,
    refundBank = 'Valentine Bank',
    finishedShown = 15,
}

Config.AdminLog = {
    title = 'Housing Logs',
    name = 'Housing Logs',
    color = 16711680,
    logo = '',
    avatar = '',
}

Config.Rules = {
    creatorIsSeller = true,      -- the staff member who creates a house collects the first seller share
    sellEmptiesLedgers = true,   -- selling to the market sets both ledgers to 0
    repoKeepsLedger = true,      -- a repossessed house keeps its ledger balance
    keyholderFurniture = true,   -- keyholders may place and remove furniture
    keyholderSpots = true,       -- keyholders may move the stash and wardrobe spots
    keyholderUpgrades = true,    -- keyholders may buy storage upgrades
    keyholderArrangeStash = false, -- keyholders may rearrange the stash grid
    forceInteriorWeather = true, -- sunny and midnight inside a teleporter interior
    guestPassReusable = true,    -- a guest pass may be used more than once in its 60 s
    currentHouseAnyOwner = true, -- getCurrentHouseId falls back to the nearest door of any house
}

Config.Timers = {
    menuLock = 300,              -- s
    knockWindow = 60,            -- s
    guestPass = 60,              -- s
    viewing = 60,                -- s
    reportBatch = 1500,          -- ms
    clientReply = 5000,          -- ms
    clientJobReply = 8000,       -- ms
    inputGiveUp = 120000,        -- ms
    motelGuard = 10000,          -- ms
    stashGuard = 15000,          -- ms
    blipDelay = 1000,            -- ms
}

Config.Reach = {
    door = 1.6,
    motelEntrance = 1.6,
    exit = 1.6,
    houseSpot = 2.0,
    interiorSpot = 1.0,
    motelSpot = 2.0,
    ledger = 2.0,
    townHall = 2.5,
    -- server side
    serverStash = 3.5,
    serverSpot = 5.0,
    serverDoor = 3.0,            -- door toggles must come from this close to the door
    serverPieceFromPlayer = 30.0, -- a placed piece must be this close to the placer
}

Config.Keys = {
    interact = 0x760A9C6F,       -- G
    confirm = 0xC7B5340A,        -- ENTER
    back = 0x156F7119,           -- BACKSPACE
    lock = 0x8FFC75D6,           -- SHIFT
    decline = 0x8AAA0AD4,        -- ALT
    up = 0x6319DB71,
    down = 0x05CA7C52,
    left = 0xA65EBAB4,
    right = 0xDEB34313,
    yPlus = 0x430593AA,          -- [
    yMinus = 0xA5BDCD3C,         -- ]
}

-- animations (game assets, may need in-game tuning)
Config.Anims = {
    knock = { dict = 'script_common@jail_cell@knock', name = 'knock_door_loop', ms = 3000 },
    outfit = { dict = 'mech_inventory@clothing@bandana', name = 'neck_2_satchel', ms = 1500 },
}

Config.Creator = {
    findDoorHash = nil,          -- nil = doors missing from client/doors.lua are refused
    probeDistance = 6.0,         -- metres past the player
}

Config.LedgerPoints = {
    { name = 'Sold Home Ledger (Valentine)', coords = vector3(-180.54, 634.79, 114.08), blip = -1656531561 },
}

Config.TownHalls = {
    { name = 'Valentine Town Hall', coords = vector3(-362.622, 825.977, 117.008) },
}

-- teleporter interiors; the key is the name stored in playerhousing.otherdoors
Config.Interiors = {
    ['Penthouse'] = {
        entry = vector3(2816.0, -1232.49, 21.18),
        price = 10000,
        range = 50.0,
        imaps = { 'Rustys_Saint_Denis_Apartment_RedM' },
    },
}

Config.Fallbacks = {
    { label = 'Valentine', coords = vector3(-283.83, 806.4, 119.38) },
    { label = 'Saint', coords = vector3(2721.4562, -1446.0975, 46.2303) },
    { label = 'Armadillo', coords = vector3(-3687.84, -2631.09, -13.64) },
    { label = 'bw', coords = vector3(-790.48, -1270.66, 43.63) },
    { label = 'rhodes', coords = vector3(1229.0, -1306.1, 76.9) },
    { label = 'anned', coords = vector3(2955.95, 1304.94, 44.53) },
    { label = 'vanhorn', coords = vector3(2973.06, 562.55, 44.5) },
    { label = 'vanhorn (duplicate)', coords = vector3(2973.06, 562.55, 44.5) },
    { label = 'straw', coords = vector3(-1747.29, -362.9, 169.5) },
    { label = 'snow', coords = vector3(-1459.6, 1634.11, 243.2) },
    { label = 'tumbleweed', coords = vector3(-5513.53, -2930.86, -2.23) },
}

-- every motel shares one room; the key is stored in the database and must not change
Config.MotelRoom = {
    exit = vector3(-323.707, 767.1247, 121.5827),
    wardrobe = vector3(-326.82, 764.62, 122.0866),
    stash = vector3(-325.4, 767.02, 122.0866),
}

Config.Motels = {
    enabled = true,
    labels = false,
    blip = 1116438174,
    list = {
        ['Valentine'] = { name = 'Valentine Hotel', entrance = vector3(-322.14, 767.47, 121.63) },
        ['tw'] = { name = 'Tumbleweed Hotel', entrance = vector3(-5498.9, -2932.3, -0.36) },
        ['Armadillo'] = { name = 'Armadillo Hotel', entrance = vector3(-3687.92, -2630.93, -13.44) },
        ['bw'] = { name = 'Blackwater Hotel', entrance = vector3(-780.758, -1263.734, 43.295) },
        ['strawberry'] = { name = 'Strawberry Hotel', entrance = vector3(-1831.3, -401.44, 162.23) },
        ['rhodes'] = { name = 'Rhodes Hotel', entrance = vector3(1343.5, -1301.3, 77.4) },
        ['sd'] = { name = 'Saint Denis Hotel', entrance = vector3(2593.6, -1163.8, 53.53) },
        ['annes'] = { name = 'Annesburg Hotel', entrance = vector3(2911.58, 1325.57, 45.1) },
    },
    defaults = { price = 20, slots = 100, leash = 20.0 },
}
