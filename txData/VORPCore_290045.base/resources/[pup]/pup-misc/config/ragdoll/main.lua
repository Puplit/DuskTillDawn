-- pup-misc/ragdoll | settings and text (see README)

RagdollConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
RagdollConfig.General = {
    enabled    = true,
    command    = 'ragdoll',
    cooldownMs = 200,         -- ms
}

-- default key for a new player (a key name, not a hash)
RagdollConfig.Keys = {
    toggle = 'Z',
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
RagdollConfig.Integrations = {}

-------------------------------------------------------------------------------
-- RAGDOLL
-------------------------------------------------------------------------------
RagdollConfig.Ragdoll = {
    pulseMs = 1000,   -- ms
}

-------------------------------------------------------------------------------
-- BLOCKS  (cuffed always blocks)
-------------------------------------------------------------------------------
RagdollConfig.Blocks = {
    hogtied          = true,
    dead             = true,
    mounted          = true,   -- on a horse or in a vehicle
    inWater          = true,   -- swimming
    alreadyRagdolled = true,
}

-------------------------------------------------------------------------------
-- TEXT
-------------------------------------------------------------------------------
RagdollLocale = {
    keyLabel = 'Ragdoll (flop / get up)',   -- row name in the Key Bindings list
}
