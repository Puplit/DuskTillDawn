-- pup-misc/pets | main settings (see README)

PetsConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
PetsConfig.General = {
    debug       = false,    -- also enables /petvariant and /petscan
    maxPets     = 2,
    consumeItem = false,   -- false = permanent whistle

    -- chat commands for the orders
    commands = {
        sit    = 'petsit',     -- toggles sit + stay
        track  = 'pettrack',   -- sniff and mark nearby animals
        hunt   = 'pethunt',    -- toggles fetching your kills
        howl   = 'pethowl',    -- animals listed in PetsConfig.Anims.howl only
        attack = 'petattack',  -- only registered while PetsConfig.Attack.enabled is true
    },
}

PetsConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
PetsConfig.Integrations = {}

-------------------------------------------------------------------------------
-- FOLLOW
-------------------------------------------------------------------------------
PetsConfig.Follow = {
    offset        = { x = 0.0, y = -1.5, z = 0.0 },  -- metres from you; negative y = behind
    spread        = 1.2,     -- metres
    recallRange   = 60.0,    -- metres
    recallCheckMs = 3000,    -- ms
}

-------------------------------------------------------------------------------
-- BEHAVIOUR
-------------------------------------------------------------------------------
PetsConfig.Behaviour = {
    invincible       = true,   -- the pet cannot be hurt or ragdolled
    despawnOnDeath   = true,   -- YOUR death puts every pet away
    allowRiding      = false,
}

-------------------------------------------------------------------------------
-- SCALE  (1.0 = natural size)
-------------------------------------------------------------------------------
PetsConfig.Scale = {
    default = 1.0,   -- used when a pet has no scale
    min     = 0.2,
    max     = 3.0,
}

-------------------------------------------------------------------------------
-- NAMING
-------------------------------------------------------------------------------
PetsConfig.Naming = {
    enabled       = true,
    maxNameLength = 24,    -- characters
    maxDescLength = 200,   -- characters
    renameItem    = true,
}

-------------------------------------------------------------------------------
-- SIT  (/petsit)
-------------------------------------------------------------------------------
PetsConfig.Sit = {
    freezePet = true,
}

-------------------------------------------------------------------------------
-- HOWL  (/pethowl)
-------------------------------------------------------------------------------
PetsConfig.Howl = {
    cooldownSeconds = 8,
}

-------------------------------------------------------------------------------
-- ATTACK
-------------------------------------------------------------------------------
PetsConfig.Attack = {
    enabled      = false,
    allowPlayers = false,
    range        = 30.0,   -- metres
}

-------------------------------------------------------------------------------
-- TRACK  (/pettrack)
-------------------------------------------------------------------------------
PetsConfig.Track = {
    enabled         = true,
    radius          = 150.0,   -- metres
    durationSeconds = 30,      -- seconds, min 5
    dict            = 'amb_creature_mammal@world_dog_sniffing_ground@base',
    clip            = 'base',
    blipSprite      = -1085232344,
    blipScale       = 0.8,
}

-------------------------------------------------------------------------------
-- HUNT  (/pethunt)
-------------------------------------------------------------------------------
PetsConfig.Hunt = {
    enabled = true,
    radius  = 60.0,    -- metres
    bone    = 21030,   -- jaw bone
    -- too big for a pet to carry (matched on hash)
    skipModels = {
        'A_C_Bear_01', 'mp_a_c_bear_01', 'a_c_buffalo_01', 'mp_a_c_buffalo_01',
        'a_c_buffalo_tatanka_01', 'a_c_moose_01', 'mp_a_c_moose_01',
        'a_c_elk_01', 'mp_a_c_elk_01', 'A_C_Cow', 'A_C_Ox_01', 'A_C_Bull_01',
        'A_C_Donkey_01', 'A_C_Cougar_01', 'mp_a_c_cougar_01',
        'A_C_Panther_01', 'mp_a_c_panther_01', 'A_C_LionMangy_01',
        'a_c_alligator_02', 'mp_a_c_alligator_01',
    },
}
