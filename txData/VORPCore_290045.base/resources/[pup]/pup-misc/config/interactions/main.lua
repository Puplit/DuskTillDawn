-- pup-misc/interactions | main settings (see README)

InteractionsConfig = {}

-------------------------------------------------------------------------------
-- KEYS
-------------------------------------------------------------------------------
InteractionsConfig.Keys = {
    interact = 0xD8F73058,   -- U: opens the menu, and the get-up prompt uses it too
}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
InteractionsConfig.General = {
    humanOnly       = true,   -- the menu never opens for an animal ped, whatever the entry gates say
    restoreDistance = 5.0,    -- on getting up, go back to the start point only if it is this close (metres)
    standOnKnockdown = true,  -- knocked over, ragdolled or set alight: end the interaction where they land
    restartLimit    = 3,      -- the pose stopped on its own: try again this many times in a row, then give up
    restartGapMs    = 1000,   -- at least this long between two retries
    startGraceMs    = 1500,   -- after starting, wait this long before checking the pose is still playing
    cooldownMs      = 750,    -- after getting up, the key is ignored for this long
    animLoadMs      = 1000,   -- longest wait for an animation dictionary to load
}

-- dancing in the interactions menu: true = a Dance category; false = no dancing (owner choice)
InteractionsConfig.Dance = {
    anywhere = false,
}

-------------------------------------------------------------------------------
-- DANCE
-------------------------------------------------------------------------------
InteractionsConfig.Dance = {
    anywhere = true,   -- false removes the Dance category (it needs no object)
}

-------------------------------------------------------------------------------
-- FIVE FINGER FILLET
-- A menu row next to a Five Finger Fillet table seat that runs a chat command.
-- Off: no resource registers /fff yet. Turn it on once one does.
-------------------------------------------------------------------------------
InteractionsConfig.Fillet = {
    enabled = false,
    command = 'fff',   -- run with ExecuteCommand, no slash
    radius  = 1.5,     -- metres from a seat in Models.filletSeats
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
InteractionsConfig.Integrations = {
    -- pup-stable uses the same key at its wagons, so the key does nothing this close to one
    wagonStateBag = 'pup_stable_wagonID',
    wagonRadius   = 4.0,
}

-------------------------------------------------------------------------------
-- EFFECTS
-- Run once when an entry with `effect = '<id>'` starts. Called with the player's ped.
-------------------------------------------------------------------------------
InteractionsConfig.Effects = {
    clean = function(ped)
        pcall(Citizen.InvokeNative, 0x6585D955A68452A5, ped)              -- dirt
        pcall(Citizen.InvokeNative, 0x523C79AEEFCC4A2A, ped, 10, 'ALL')   -- damage decals, every zone
        pcall(Citizen.InvokeNative, 0x8FE22675A5A45817, ped)              -- blood
    end,
}
