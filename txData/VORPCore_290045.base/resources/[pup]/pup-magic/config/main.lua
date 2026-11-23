-- pup-magic | main settings

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug = false,            -- true = EVERY player gets EVERY spell (testing only) and spell debug prints in F8
}

-- Prompt keys. Change the hash only. Each spell's key is on the spell in config/spells.lua.
Config.Keys = {
    feed = 0x4CC0E2FE,        -- B, hold while focusing (right-click) a human to feed
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
-- pup_shaman (who is a vampire) and fred_metabolism (feeding benefits) need no settings here.
Config.Integrations = {
    -- vorp_animations: keys of the two animations in vorp_animations' own config
    animations = {
        feed   = "vampire_feed",     -- the vampire
        victim = "vampire_victim",   -- a player being fed on
    },
}

-------------------------------------------------------------------------------
-- FEEDING  (only characters cursed 'vamp')
-------------------------------------------------------------------------------
Config.Feeding = {
    radius          = 2.5,      -- metres to the victim for the Feed prompt
    holdMs          = 1000,     -- how long the key is held to start feeding
    cooldownMs      = 300000,   -- ms between feeds (5 minutes)
    feedMs          = 5200,     -- how long the vampire feeds
    victimExtraMs   = 10000,    -- victim stays down this much longer than the vampire
    victimDefaultMs = 15200,    -- server fallback victim time if the client sends none
    drunkMs         = 30000,    -- victim staggers this long after getting up
    scareRadius     = 18.0,     -- metres: NPCs this close flee
    scareDurationMs = 12000,    -- how long they flee

    -- Items given per feed. A PLAYER victim gives a named blood vial instead (see Config.Blood).
    npcRewards    = { { name = 'blood_vial', count = 1 } },
    playerRewards = {},
    npcTipMs      = 3000,       -- how long Locale.feedNpcReward shows
    playerTipMs   = 5000,       -- how long Locale.feedPlayerReward shows (empty text = no tip)

    -- fred_metabolism 'fred_meta:consume' values given to the vampire
    benefits = {
        npc = {
            hunger = 60, thirst = 60, metabolism = 0,
            staminaInner = 0, staminaInnerGold = 0, staminaOuterGold = 0,
            healthInner  = 0, healthInnerGold  = 0, healthOuterGold  = 0,
        },
        player = {
            hunger = 95, thirst = 95, metabolism = 0,
            staminaInner = 0, staminaInnerGold = 6000.0, staminaOuterGold = 6000.0,
            healthInner  = 0, healthInnerGold  = 6000.0, healthOuterGold  = 6000.0,
        },
    },
}

-------------------------------------------------------------------------------
-- BLOOD VIALS  (feeding on a PLAYER bottles their blood; drinking it wears their face)
-------------------------------------------------------------------------------
Config.Blood = {
    item                 = "blood_vial",       -- item name in the items table
    durationMs           = 10 * 60 * 1000,     -- how long the borrowed face lasts (10 minutes)
    warnBeforeMs         = 30 * 1000,          -- warn this long before it wears off
    drinkMs              = 3000,               -- drink time before the swap (smoke covers it)
    maxVials             = 5,                  -- vials one vampire may carry at once; 0 = unlimited
    sameVictimCooldownMs = 30 * 60 * 1000,     -- same victim again within this gives no vial (30 minutes)
    maxBiteDistance      = 8.0,                -- metres; server rejects a bite from farther away

    -- smoke burst on drink and on revert (same particle as the smoke spell)
    smoke = {
        asset      = "scr_odd_fellows",
        name       = "scr_river5_magician_smoke_loop",
        scale      = 0.8,
        zOffset    = -0.9,                     -- metres below the player's coords
        durationMs = 4500,
        viewRange  = 60.0,                     -- metres other players can see it from
    },
}
