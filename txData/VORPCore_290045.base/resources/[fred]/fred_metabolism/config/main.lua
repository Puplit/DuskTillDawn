-- fred_metabolism | config/main.lua
-- Hunger, thirst, metabolism and temperature: drains, damage and clothing warmth.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug       = false,   -- print consume / restore / damage lines in the server console and F8
    tempCommand = 'temp',  -- chat command: itemised temperature readout for the player
}

-- Framework the notifications and status sync use. Only ONE may be true.
Config.Framework = {
    vorp  = true,   -- VORP: vorp:Tip / vorp:NotifyLeft, status saved every metabolism tick
    redEm = false,  -- RedEM: redem_roleplay:Tip / NotifyLeft, status saved once the player loaded
}

-------------------------------------------------------------------------------
-- NEEDS  (food and water bars, 0-100)
-------------------------------------------------------------------------------
Config.Needs = {
    initialFood  = 100,    -- food for a first-time character (or when no save exists)
    initialWater = 100,    -- water for a first-time character (or when no save exists)
    tickMs       = 60000,  -- milliseconds between drain ticks; tune the drains below, not the tick

    -- amount drained per tick, by what the player is doing
    foodDrain  = { idle = 0.125, walking = 1.0, running = 2.0 },
    waterDrain = { idle = 0.15,  walking = 1.2, running = 2.4 },

    lowFoodWarnAt  = 20,   -- "belly rumbling" tip at or below this food value
    lowWaterWarnAt = 20,   -- "thirsty" tip at or below this water value
}

-------------------------------------------------------------------------------
-- STARVATION  (health damage while food or water is empty)
-------------------------------------------------------------------------------
Config.Starvation = {
    foodAt          = 5,    -- damage starts when food is AT or BELOW this
    waterAt         = 5,    -- damage starts when water is AT or BELOW this
    damagePct       = 2.0,  -- % of max health lost per damage tick (vorp_core max is 600)
    intervalSeconds = 4,    -- seconds between starvation damage ticks
}

-------------------------------------------------------------------------------
-- METABOLISM  (0 skinny, 10000 normal, 20000 fat)
-------------------------------------------------------------------------------
Config.Metabolism = {
    initial     = 3500,    -- metabolism for a first-time character
    tickMs      = 200000,  -- milliseconds between metabolism ticks (also when status is saved)
    loss        = { idle = 1, walking = 2, running = 4 },  -- metabolism lost per tick, by movement
    bodyChanges = false,   -- true = body size and waist follow the metabolism value
}

-------------------------------------------------------------------------------
-- TEMPERATURE  (effective temperature = ambient + clothing warmth, in C)
-------------------------------------------------------------------------------
Config.Temperature = {
    enabled       = true,  -- false = no cold / heat drains, warnings or cold damage
    coldBelow     = -2,    -- extra food drain and "very cold" warning below this; the drain steps up 10, 12 and 14 degrees lower
    hotAbove      = 30,    -- extra water drain above this
    hotWaterLoss  = 3,     -- extra water drained per needs tick while too hot
    coldFoodLoss  = 3,     -- extra food drained per needs tick at the coldest step (25/50/75/100% steps)
}

-------------------------------------------------------------------------------
-- COLD DAMAGE  (health loss from exposure, separate from coldBelow above)
-------------------------------------------------------------------------------
-- Damage is a % of max health per 6 second tick. All three tiers are equal on
-- purpose: cold hurts at the same rate however far it falls; the tiers differ in
-- the warning text only. 1% of 600 = 6 hp per tick, about 10 minutes to go down.
Config.ColdDamage = {
    hurtAt    = -4,    -- tier 1 damage and "you're cold" warning at or below this temperature
    worseAt   = -6,    -- tier 2 damage at or below this temperature
    dyingAt   = -8,    -- tier 3 damage and "you will die" warning at or below this temperature
    hurtPct   = 1.0,   -- % of max health per tick at tier 1
    worsePct  = 1.0,   -- % of max health per tick at tier 2
    dyingPct  = 1.0,   -- % of max health per tick at tier 3
    canKill   = true,  -- true = exposure can down a player; false = damage stops at floorPct
    floorPct  = 50,    -- % of max health cold damage cannot go below when canKill = false
}

-------------------------------------------------------------------------------
-- WARMTH  (degrees each worn garment adds to the effective temperature)
-------------------------------------------------------------------------------
Config.Warmth = {
    hat        = 1,
    shirt      = 1,
    pants      = 1,
    boots      = 1,
    coat       = 4,   -- an open coat; a closed coat uses closedCoat instead
    closedCoat = 8,
    gloves     = 1,
    vest       = 2,
    poncho     = 4,   -- counted once for each of the two poncho / cloak slots
    mask       = 1,
    interior   = 2,   -- bonus while inside any interior; 0 disables

    -- SUBTRACTED while no coat is worn, and they stack
    rolledSleevesPenalty = 10,  -- /sleeves
    openCollarPenalty    = 5,   -- /sleeves2
}

-------------------------------------------------------------------------------
-- SMOKING
-------------------------------------------------------------------------------
Config.Smoking = {
    defaultProp = 'P_CIGAR01X',  -- prop used when a smoke item has no PropName; '' = smoke empty-handed
}
