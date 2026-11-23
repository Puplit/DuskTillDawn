Config = Config or {}

Config.Debug = false

Config.General = {
    callCommand = 'callbird', -- chat command; '' = off
    callItem    = 'birdcall', -- usable item; '' = off
}

Config.Keys = {
    talk     = 0x06052D11,
    sendHome = 0xC7B5340A, -- ENTER
    follow   = 0x05CA7C52,
    hunt     = 0x156F7119,
    sell     = 0xD8CF0C95,
    land     = 0x156F7119,
    camera   = 0x05CA7C52,
    openShop = 0xC7B5340A, -- ENTER
    stopSell = 0xD8CF0C95,
    buy      = 0xD8CF0C95,
}

Config.Progression = {
    maxXp = 1000, -- XP cap per bird
}

Config.Hunting = {
    jobRequired    = false,
    jobs           = { 'birdtrainer', 'wapiti' },
    extraXp        = nil,    -- bonus XP per return for those jobs; nil = none
    cooldownMs     = 180000, -- ms between trip starts
    flyAwaySeconds = 20,     -- seconds
    huntSeconds    = 60,     -- seconds
}

Config.Talking = {
    xpRequired = 1000,
    models = { 'a_c_carolinaparakeet_01', 'a_c_parrot_01', 'a_c_raven_01' },
}

Config.SellBack = {
    confirmWord = 'delete', -- case-insensitive
    divisor     = 3,        -- pays price / divisor
}

Config.Trade = {
    jobs        = nil,    -- nil = anyone
    maxPrice    = 100000, -- dollars
    buyDistance = 3.0,    -- metres
    leaveDistance = 3.0,  -- metres the seller may move before the sale ends
}

Config.Shop = {
    useDistance = 5.0, -- metres
}

Config.Markers = {
    color            = { 128, 200, 0 }, -- RGB
    showAtShops      = false,
    showAtSellPoints = true,
}

Config.Discord = {
    webhookKey = 'birds',
    username   = 'Hunting Birds',
    maxPosts   = 5,  -- per player per window; 0 = off
    windowSec  = 10, -- seconds
}

-- data/*.json is turned into Config.BirdCatalog, Config.BirdRoles, Config.ShoulderOffsets, Config.Shops,
-- Config.HuntZones and Config.ParrotSpeech by shared/data.lua (server also loads the catch lists)
