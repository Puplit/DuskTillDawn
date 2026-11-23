-- pup-misc/knockout | settings and text (see README)

KnockoutConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
KnockoutConfig.General = {}

KnockoutConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
KnockoutConfig.Integrations = {}

-------------------------------------------------------------------------------
-- MELEE
-------------------------------------------------------------------------------
KnockoutConfig.Melee = {
    healthThreshold = 75,    -- in melee combat and under this health = knocked out
    shieldMs        = 3000,  -- ms you cannot be hurt right after going down (0 = killable at once)
}

-------------------------------------------------------------------------------
-- HORSE KICK
-------------------------------------------------------------------------------
KnockoutConfig.HorseKick = {
    enabled         = true,
    healthThreshold = 150,
    graceMs         = 2000,   -- ms
    protectMs       = 2500,   -- ms
}

-------------------------------------------------------------------------------
-- RECOVERY
-------------------------------------------------------------------------------
KnockoutConfig.Recovery = {
    startHealth = 116,   -- health set the moment you go down
    steps       = 16,    -- heal steps; you get up right after the last one
    stepMs      = 1000,  -- ms between two heal steps (steps x stepMs = time on the ground)
    healPerStep = 4,     -- health added per step
}

-------------------------------------------------------------------------------
-- DISPLAY
-------------------------------------------------------------------------------
KnockoutConfig.Display = {
    labelMs = 3300,      -- ms the knocked-out text stays on screen
}

-------------------------------------------------------------------------------
-- TEXT
-------------------------------------------------------------------------------
KnockoutLocale = {
    knockedOut = '~r~Out cold. Lie still and get your breath back.',   -- drawn on your own screen when you go down
}
