-- pup-misc/guarma | main settings (see README)

GuarmaConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
GuarmaConfig.General = {
    debug = false,   -- server console prints
}

-- prompt keys
GuarmaConfig.Keys = {
    board = 0x760A9C6F,   -- G
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
GuarmaConfig.Integrations = {}

-------------------------------------------------------------------------------
-- DOCKS
-------------------------------------------------------------------------------
GuarmaConfig.Docks = {
    mainland       = { x = 2670.822, y = -1552.93, z = 45.47 },
    island         = { x = 1274.28,  y = -6857.23, z = 43.36 },
    promptDistance = 2.0,   -- metres
}

-------------------------------------------------------------------------------
-- CROSSING
-------------------------------------------------------------------------------
GuarmaConfig.Crossing = {
    price      = 0,     -- 0 = free
    moneyType  = 0,     -- 0 cash, 1 gold
    ticketItem = nil,   -- nil = no ticket
    jobs       = {},    -- jobs allowed to cross; empty = anyone
}
