-- pup-misc/outfitter | main settings (see README)

OutfitterConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
OutfitterConfig.General = {
    enabled = true,    -- false = no shop, no wagon menu
    debug   = false,   -- F8 / console prints
}

-- keys
OutfitterConfig.Keys = {
    openKit   = 0xD8F73058,   -- U beside your stable wagon
    place     = 0x760A9C6F,   -- G
    cancel    = 0x156F7119,   -- BACKSPACE
    turnLeft  = 0x430593AA,   -- [
    turnRight = 0xA5BDCD3C,   -- ]
    nearer    = 0x05CA7C52,   -- DOWN arrow
    further   = 0x6319DB71,   -- UP arrow
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
OutfitterConfig.Integrations = {}

-------------------------------------------------------------------------------
-- SHOP
-------------------------------------------------------------------------------
OutfitterConfig.Shop = {
    moneyType      = 0,      -- 0 cash, 1 gold
    stableDistance = 40.0,   -- metres
}

-------------------------------------------------------------------------------
-- WAGON
-------------------------------------------------------------------------------
OutfitterConfig.Wagon = {
    range = 4.0,   -- metres
}

-------------------------------------------------------------------------------
-- WORLD
-------------------------------------------------------------------------------
OutfitterConfig.World = {
    spawnLimit     = 10,
    renderDistance = 180.0,   -- metres
    renderPollMs   = 2000,    -- ms
}

-------------------------------------------------------------------------------
-- PLACEMENT
-------------------------------------------------------------------------------
OutfitterConfig.Placement = {
    startDistance   = 3.0,    -- metres
    minDistance     = 1.5,    -- metres
    maxDistance     = 10.0,
    stepDistance    = 0.25,   -- metres
    turnStepDegrees = 5.0,    -- degrees

    -- town names (matched on their hash)
    bannedTowns = {
        'Annesburg', 'Armadillo', 'Blackwater', 'BeechersHope', 'Breaithwaite',
        'Butcher', 'Caliga', 'Cornwall', 'Emerald', 'Lagras', 'Manzanita',
        'Rhodes', 'Siska', 'StDenis', 'Strawberry', 'Tumbleweed', 'Valentine',
        'Vanhorn', 'Wallace', 'Wapiti', 'AguasducesFarm', 'AguasdulcesRuins',
        'AguasdulcesVilla', 'Manico',
    },
}
