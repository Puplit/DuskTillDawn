-- pup-misc/ecoboost | main settings (see README)

EcoBoostConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
EcoBoostConfig.General = {
    enabled        = true,    -- false = no sale is boosted
    notifyProgress = false,   -- a tip after every boosted sale
}

EcoBoostConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
EcoBoostConfig.Integrations = {}

-------------------------------------------------------------------------------
-- BOOST
-------------------------------------------------------------------------------
EcoBoostConfig.Boost = {
    multiplier      = 2.5,            -- 1.0 = no bonus
    bonusCap        = 500,            -- dollars per activation
    windowSeconds   = 24 * 60 * 60,   -- seconds
    cooldownSeconds = 24 * 60 * 60,   -- seconds
}

-------------------------------------------------------------------------------
-- SALES
-------------------------------------------------------------------------------
EcoBoostConfig.Sales = {
    eligible = {
        Mining  = true,
        Trapper = true,
        Fishing = true,
    },
    storeCategories = {
        Mining  = { 'Mining Company' },
        Trapper = { 'Trapper', 'Butcher' },
        Fishing = { 'Bait Shop' },
    },
}
