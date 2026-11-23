-- pup_mercantile | main settings (every setting is described in README.md)

Config = Config or {}

Config.Debug = false  -- true = print trade traces in the server console

Config.InteractKey = 0x760A9C6F -- G
Config.PriceColour = 'green'

Config.NpcStores = {
    promptDistance = 1.5, -- metres
    shownStock = 9999,    -- stock figure shown for NPC items (they never run out)
}

Config.Shops = {
    promptDistance = 1.5, -- metres
    boxReach = 6.0,       -- metres
    minSpacing = 5.0,     -- metres
    pricePerSlot = 3,     -- dollars per extra slot
    movePrice = 10000000, -- dollars
    ownerWebhooks = true,
}

Config.ServerSlack = 6.0 -- metres beyond the prompt distance

Config.Blacklist = { 'bountylicns', 'orden_presidente', 'medcert' }

Config.PlayerShops = {
    maxPerPlayer = 1, -- admins are exempt; repossessed shops still count
    token = 'shoptoken',
    startSlots = 500,
    blipSprite = -242384756,
}

Config.SocietyShops = {
    enabled = true,
    maxPerBusiness = 6,
    token = 'societytoken',
    startSlots = 1500,
    blipSprite = 249721687,
    sharedStock = true,
    separateStock = {},   -- job names, e.g. { 'blacksmith' }
}

Config.BlipScale = 0.8

Config.Decay = {
    enabled = true,
    minimum = 70, -- percent
}

Config.Tax = {
    amount = 1500, -- dollars per period
    monthly = { enabled = true, day = 15, hour = 11, minute = 5 },
    -- days of the month, not weekdays; used only when monthly is off
    weekly = { enabled = false, days = { 3, 10, 17, 24 }, hour = 6, minute = 10 },
    warnMinutes = 60,
    checkEvery = 30, -- seconds
    mailFrom = 'Store Office',
}

Config.Logs = {
    avatar = '',       -- empty = Discord default
    poster = 'Stores',
}

Config.Commands = {
    move = 'moveshop',
    adminMove = 'adminmoveshop',
    repo = 'reposhop',
    unrepo = 'unreposhop',
    delete = 'delshop',
}

Config.Shopkeepers = {}

Config.V1SocietyShops = {}

Config.Misc = {
    resource = 'pup-misc',
    exports = {
        ecoBonus = 'ApplyEcoBoostSale',
        ecoMultiplier = 'EcoBoostMultiplierFor',
        boxNames = 'BoxItemNames',
        boxContents = 'BoxContents',
        boxTake = 'BoxTake',
        boxPut = 'BoxPut',
        boxFree = 'BoxSpace',
        boxConsume = 'BoxConsumeIfEmpty',
    },
    fallbackBoxNames = { 'miner_pack', 'lumber_pack', 'farmer_pack', 'storage_box_1000' },
    packCheckTimeout = 3000, -- ms
}

-- law contraband searches of player shops. Only goods ON SALE (what a customer can see) are
-- searched and seized; shelved stock and weapons are never touched, and a shop with nothing
-- on sale cannot be searched at all.
Config.Raid = {
    enabled = true,           -- true = lawmen can search shops; false = no prompt and no searches
    minGrade = 5,             -- lowest law job grade that may search
    cooldownMinutes = 30,     -- per shop, after a search that went ahead
    lawmanSeconds = 10,       -- one raid request per lawman this often
    key = 0xE30CD707,         -- R
    holdMs = 1000,            -- ms
    mdtResource = 'pup-mdt',
    mailFrom = 'Sheriff\'s Office',
}

Config.Admin = {
    resource = 'vorp_admin',
    permission = 'manage_stores',
}

Config.Integrations = {
    postoffice = 'pup_postoffice',
    business = 'pup_business',
}
