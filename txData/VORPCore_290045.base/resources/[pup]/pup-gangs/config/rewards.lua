-- pup-gangs | mission payouts

-------------------------------------------------------------------------------
-- REWARDS
-------------------------------------------------------------------------------
-- entry: points, cash = { min, max }, items = { { item, min, max, chance (0-100) } }
Config.Rewards = {
    -- delivery run: planted on a rival, survived, carried home alive
    run = {
        points          = 60,
        perTargetMember = 10,   -- extra points per online member of the target crew
        cash            = { min = 150, max = 300 },
        items           = {
            { item = 'drug_package', min = 1, max = 2, chance = 100 },
            { item = 'gunpowder',    min = 2, max = 5, chance = 65 },
            { item = 'paper',        min = 1, max = 3, chance = 60 },
            { item = 'stolenmerch',  min = 1, max = 3, chance = 40 },
            { item = 'goldbar',      min = 1, max = 1, chance = 12 },
        },
    },

    -- found and destroyed a plant on your own ground
    defend = {
        points = 45,
        cash   = { min = 100, max = 200 },
        items  = {
            { item = 'gunpowder', min = 1, max = 3, chance = 50 },
            { item = 'paper',     min = 1, max = 2, chance = 45 },
        },
    },

    -- fort raid cleared (the strongbox contents are Config.FortRaid.loot in config/fortraid.lua)
    fort = {
        points = 120,
        cash   = { min = 400, max = 750 },
        items  = {},
    },
}
