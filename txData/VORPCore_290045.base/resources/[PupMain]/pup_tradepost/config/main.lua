-- pup_tradepost settings. Shared by the client and the server.
-- Money is in dollars here; the server works in whole cents internally.

Config = {}

-- console traces of every request (server) and redraw (client)
Config.Debug = false

-- item picture shown in every list and grid (%s = item name)
Config.ItemImage = 'nui://vorp_inventory/html/img/items/%s.png'

-- the counter prompt
Config.Prompt = {
    distance = 2.0,         -- metres from the counter to show the prompt
    key      = 0x760A9C6F,  -- G
    farPoll  = 750,         -- ms between checks while nowhere near a counter
}

-- the server allows money/goods actions within prompt distance plus this slack
Config.ActionSlack = 4.0

-- panel
Config.Panel = {
    boardPageSize   = 40,
    recentPerPage   = 8,
}

-- optional integrations
Config.Bank = { enabled = true }                              -- pup-bank
Config.Mail = { enabled = true, sender = 'Market Exchange' }  -- pup_postoffice letters
Config.ToastOtherTrader = true                                -- tip to the other side of a trade when online

-- licences and private storage
Config.Licence = {
    price            = 1000.00,
    startSlots       = 100,
    slotPrice        = 10.00,
    maxSlots         = 2000,
    maxSlotsPerBuy   = 2000,
    firstContainerId = 7000001,
    containerName    = 'Market Storage',
}

-- order rules per side
Config.Orders = {
    buy = {
        maxOpen      = 20,
        maxQty       = 1000,
        minPrice     = 0.05,
        maxPrice     = 50000.00,
        lifetimeDays = 7,
    },
    sell = {
        enabled      = true,
        maxOpen      = 20,
        maxQty       = 1000,
        minPrice     = 0.05,
        maxPrice     = 50000.00,
        lifetimeDays = 7,
    },
    -- true = one open-order limit across every market; false = maxOpen per side at each market
    limitAcrossMarkets = true,
}

-- the market's cut, taken from the money paid to whoever supplied the goods
Config.Fees = {
    sale        = 0.05,  -- fraction: 0.05 = 5%
    crossMarket = 0.02,  -- extra when the trade is made away from the order's market
    min         = 0.00,  -- the total fee is clamped between min and max
    max         = 0.90,
}

-- 'ledger' (collect at any counter) or 'bank' (seller's pup-bank branch, else the ledger)
Config.Payout = {
    mode        = 'ledger',
    minWithdraw = 1.00,
    minToBank   = 0.00,  -- 0 = no minimum
}

-- going rate and price history
Config.GoingRate = {
    enabled      = true,
    windowDays   = 30,
    minTrades    = 3,
    cacheSeconds = 60,
    -- imported history (no buyer or seller recorded) counts too
    includeImported = true,
}

Config.Limits = {
    catalogueResults = 60,
    boardRows        = 300,
    recentTrades     = 15,
}

-- expired orders are closed in the background
Config.Sweep = {
    intervalMinutes    = 5,
    batch              = 100,   -- close attempts per pass
    stuckRetryMinutes  = 30,    -- a listing whose goods could not be returned waits this long before the next try
}

-- items that can never be traded (names are exact, case-insensitive; prefixes match the start of the name)
Config.Blacklist = {
    names    = { 'joint' },
    prefixes = { 'weapon_', 'pristine_' },
}

-- who counts as staff (may cancel anyone's order through AdminCancelOrder)
Config.Staff = {
    groups     = { 'admin' },
    permission = 'manage_stores',   -- vorp_admin hasPermission key
}

Config.Discord = {
    botName = 'Market Logs',
    colours = {
        posted    = 16776960,
        trade     = 3066993,
        cancelled = 15158332,
        licence   = 3066993,
        ledger    = 15844367,
    },
}

-- spam guard per player
Config.RateLimit = {
    windowMs     = 3000,  -- sliding window
    maxRequests  = 20,    -- any request, reads included
    writeGapMs   = 350,   -- minimum gap between two money/goods actions
}

-- The market keys are stored in the database and must never change (case included).
-- blip = false hides a market's map blip.
Config.Markets = {
    { key = 'Valentine',  name = 'Valentine Market Place',   coords = vector3(-179.35, 648.28, 113.58),    bank = 'Valentine Bank',   blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'Rhodes',     name = 'Rhodes Market Place',      coords = vector3(1233.84, -1293.57, 76.90),   bank = 'Rhodes Bank',      blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'SD',         name = 'Saint Denis Market Place', coords = vector3(2749.29, -1399.69, 46.19),   bank = 'Saint Denis Bank', blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'blackwater', name = 'Blackwater Market Place',  coords = vector3(-877.87, -1343.73, 43.29),   bank = 'Blackwater Bank',  blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'Strawberry', name = 'Strawberry Market Place',  coords = vector3(-1827.53, -432.96, 159.97),  bank = 'Strawberry Bank',  blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'Armadillo',  name = 'Armadillo Market Place',   coords = vector3(-3641.26, -2593.91, -13.76), bank = 'Armadillo Bank',   blip = { sprite = -272216216, scale = 0.2 } },
    { key = 'Annesburg',  name = 'Annesburg Market Place',   coords = vector3(2936.98, 1290.40, 44.65),    bank = 'Annesburg Bank',   blip = { sprite = -272216216, scale = 0.2 } },
}
