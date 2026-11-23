-- pup_gunsmith | weapon tiers ("tempering", see README)

Config.Tier = {
    max         = 5,
    slowPerTier = 0.10, -- must match vorp_inventory's SLOW_PER_TIER
    workMs      = 8000, -- ms
    scenario    = 'WORLD_HUMAN_WRITE_NOTEBOOK', -- not used: the bench keeps its own scenario
    costs = { -- [tier reached] = { cash, materials }; no entry = free
        [1] = { cash = 150,  materials = { { item = 'coal', label = 'Coal', amount = 3 }, { item = 'nails', label = 'Nails', amount = 5 } } },
        [2] = { cash = 350,  materials = { { item = 'coal', label = 'Coal', amount = 5 }, { item = 'hwood', label = 'Hard Wood', amount = 3 }, { item = 'nails', label = 'Nails', amount = 8 } } },
        [3] = { cash = 700,  materials = { { item = 'gun_barrel', label = 'Gun Barrel', amount = 1 }, { item = 'coal', label = 'Coal', amount = 8 }, { item = 'pipecopper', label = 'Copper Pipe', amount = 2 } } },
        [4] = { cash = 1200, materials = { { item = 'gun_barrel', label = 'Gun Barrel', amount = 2 }, { item = 'pipecopper', label = 'Copper Pipe', amount = 3 }, { item = 'ironhammer', label = 'Iron Hammer', amount = 1 } } },
        [5] = { cash = 2000, materials = { { item = 'gun_barrel', label = 'Gun Barrel', amount = 3 }, { item = 'pipecopper', label = 'Copper Pipe', amount = 5 }, { item = 'goldbar', label = 'Gold Bar', amount = 1 } } },
    },
}
