-- pup-gangs | the level ladder, perk labels and gang stashes
-- Gang levels, what each one puts on the perk shelf, and the stashes those perks open.

-------------------------------------------------------------------------------
-- PERKS
-------------------------------------------------------------------------------
-- levels: level, points (lifetime gang points to reach it), label, perks (fields in README.md)
-- labels: perk flag -> name shown in the panel. Text after " (" becomes the chip tooltip.
Config.Perks = {
    levels = {
        {
            level = 1, points = 0, label = 'Crew',
            perks = {
                stashSlots = 0, pointsMult = 1.00, members = 0,
                unlocks = {},
            },
        },
        {
            level = 2, points = 250, label = 'Outfit',
            perks = {
                stashSlots = 5, pointsMult = 1.00, members = 2,
                unlocks = { 'stash_drugs', 'lookouts' },
            },
        },
        {
            level = 3, points = 750, label = 'Ring',
            perks = {
                stashSlots = 10, pointsMult = 1.05, members = 4,
                unlocks = { 'stash_drugs', 'lookouts', 'missions', 'den', 'fort_raid' },
            },
        },
        {
            level = 4, points = 1500, label = 'Syndicate',
            perks = {
                stashSlots = 20, pointsMult = 1.10, members = 7,
                unlocks = {
                    'stash_drugs', 'lookouts', 'missions', 'den', 'fort_raid',
                    'stash_stolen', 'bulk_cook', 'drug_production',
                },
            },
        },
        {
            level = 5, points = 3000, label = 'Empire',
            perks = {
                stashSlots = 35, pointsMult = 1.20, members = 10,
                unlocks = {
                    'stash_drugs', 'lookouts', 'missions', 'den', 'fort_raid',
                    'stash_stolen', 'bulk_cook', 'drug_production',
                    'armory', 'supply_lines', 'powder_work',
                },
            },
        },
    },

    labels = {
        stash_drugs     = 'Drug Operations (drug stash)',
        lookouts        = 'Lookouts (warned when rivals move on your ground)',
        missions        = 'Drug Planting & Deliveries',
        den             = 'Den (drug ops hub)',
        fort_raid       = 'Fort Raids (take a fort off the locals)',
        stash_stolen    = 'Stolen Goods Fence',
        bulk_cook       = 'Bulk Cooking (+1 product per batch)',
        drug_production = 'Gang Drug Production (your own named product)',
        armory          = 'Gang Armory (weapon stash)',
        supply_lines    = 'Supply Lines (half delivery cooldown)',
        powder_work     = 'Powder Work (the dynamite bench)',
    },
}

-------------------------------------------------------------------------------
-- STASHES
-------------------------------------------------------------------------------
-- list entry fields are listed in README.md
Config.Stashes = {
    invOffset = 13000000,   -- custom inventory id = invOffset + (gangid * 10) + stash index
    list      = {
        {
            key       = 'drugs',
            label     = 'Drug Stash',
            unlock    = 'stash_drugs',
            slots     = 15,
            minRank   = 2,
            whitelist = {},
        },
        {
            key       = 'stolen',
            label     = 'Stolen Goods',
            unlock    = 'stash_stolen',
            slots     = 20,
            minRank   = 3,
            whitelist = {},
        },
        {
            key       = 'armory',
            label     = 'Gang Armory',
            unlock    = 'armory',
            slots     = 10,
            minRank   = 3,
            weapons   = true,
            whitelist = {},
        },
        {
            key       = 'den',
            label     = 'Den Inventory',
            unlock    = nil,
            slots     = 25,
            minRank   = 2,
            den       = true,
            weapons   = true,
            bare      = true,
            whitelist = {},
        },
    },
}
