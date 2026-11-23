Config = Config or {}

-- chance % = min(cap, base + perQ * quality)
Config.LootOrder = { 'diamond', 'emerald', 'nugget' }

Config.Loot = {
    diamond = { item = 'diamond',    min = 1, max = 1, base = 0.0,  perQ = 0.06, cap = 0.30, label = 'a diamond' },
    emerald = { item = 'emerald',    min = 1, max = 1, base = 0.0,  perQ = 0.12, cap = 0.60, label = 'an emerald' },
    nugget  = { item = 'goldnugget', min = 1, max = 3, base = 12.0, perQ = 34.0, cap = 85.0, label = 'gold nuggets' },
}

Config.DustFloor = {
    enabled  = true,
    lootKey  = 'nugget',
    minScore = 0.35, -- 0.0 - 1.0
    min      = 1,
    max      = 2,
}

Config.Extras = {
    { item = 'salt', label = 'rock salt', min = 1, max = 2, base = 12.0, perQ = 8.0, cap = 40.0 },
}
