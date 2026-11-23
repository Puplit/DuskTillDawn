-- pup-perks | config/main.lua

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug   = false,    -- trace xp, rank-ups, equips and effect rolls to the console. OFF for live
    command = 'perks',  -- chat command that opens the perks panel; false or '' disables it
}

-- Prompt keys. This resource has none (the panel is mouse driven).
Config.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
-- Nothing to configure. Exports for other resources are listed in README.md.
Config.Integrations = {}

-------------------------------------------------------------------------------
-- PROGRESSION  (levels and perk points, counted separately on each side)
-------------------------------------------------------------------------------
Config.Progression = {
    requireLevels  = true,  -- true: each perk rank needs its character level; false: levels only hand out points
    pointsPerLevel = 1,     -- perk points per level gained, PER SIDE (level 1 included)

    -- extra points at these levels, on top of pointsPerLevel: [level] = points
    bonusPoints = { [5] = 1, [10] = 2, [15] = 2, [20] = 3, [25] = 2, [30] = 4 },

    -- total XP needed to REACH each level; the list length is the max level
    levelXp = {
        0,      500,    1150,   1950,   2900,   -- 1-5
        4000,   5250,   6650,   8200,   9900,   -- 6-10
        11750,  13750,  15750,  17750,  19750,  -- 11-15
        21750,  23750,  25750,  27750,  29750,  -- 16-20
        32000,  34250,  36750,  39250,  42000,  -- 21-25
        44750,  47750,  50750,  54000,  57250,  -- 26-30
    },
}

-------------------------------------------------------------------------------
-- CARDS  (how owned perks become active)
-------------------------------------------------------------------------------
Config.Cards = {
    autoEquip = true,   -- true: every owned card is active, no loadout; false: cards must be equipped into slots
    maxLevel  = 3,      -- highest rank any card can reach, even if its rank list is longer

    -- loadout slots when autoEquip = false (Red Dead Online's four-card shape)
    loadout = {
        special = 1,    -- signature cards (perks with slot = 'special')
        passive = 3,    -- every other card
    },
}

-------------------------------------------------------------------------------
-- RESET  (respec)
-------------------------------------------------------------------------------
Config.Reset = {
    enabled             = true,              -- false disables both the paid full reset and the free weekly reset
    price               = 500,               -- dollars for the FULL reset (ranks + both trees); 0 = free
    freeCooldownSeconds = 7 * 24 * 60 * 60,  -- wait between FREE weekly resets (ranks only, trees kept): 7 days
}

-- milliseconds between perk actions (upgrade, equip, resets, tree choices) per player
Config.ActionCooldownMs = 2000
