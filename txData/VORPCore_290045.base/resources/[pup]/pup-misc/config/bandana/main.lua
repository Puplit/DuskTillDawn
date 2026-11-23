-- pup-misc/bandana | main settings (see README)

BandanaConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
BandanaConfig.General = {
    debug   = false,       -- F8 prints
    command = 'bandana',   -- chat command
}

BandanaConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
BandanaConfig.Integrations = {}

-------------------------------------------------------------------------------
-- ANIMATION
-------------------------------------------------------------------------------
BandanaConfig.Animation = {
    enabled = true,   -- false = swap instantly, no hand animation
    waitMs  = 700,    -- ms
}

-------------------------------------------------------------------------------
-- GARMENT
-------------------------------------------------------------------------------
BandanaConfig.Garment = {
    stateUp    = -1829635046,     -- pulled up (hash or name)
    stateDown  = 'base',          -- at the neck (hash or name)
    categories = { 'neckwear', 'masks' },   -- searched in this order
    storedKeys = { 'NeckWear' },  -- character-record slots, in order
}
