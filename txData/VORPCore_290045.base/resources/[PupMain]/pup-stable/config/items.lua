-- pup-stable | care items (shared). See README for every field.

Config.Items = {
    sugarcube         = { kind = 'feed',  priority = 1, health = 15, stamina = 15, xp = 2, consume = true, prop = 'p_sugarcube01x' },
    Wild_Carrot       = { kind = 'feed',  priority = 2, health = 15, stamina = 15, xp = 2, consume = true, prop = 'p_carrot01x' },
    consumable_haycube = { kind = 'feed', priority = 3, health = 15, stamina = 15, xp = 3, consume = true, prop = 'p_haycube01x', fromProp = true },
    carrots           = { kind = 'feed',  priority = 4, health = 30, stamina = 30, xp = 4, consume = true, prop = 'p_carrot01x' },
    holgo             = { kind = 'feed',  priority = 5, health = 30, stamina = 30, xp = 4, consume = true, prop = 'p_haycube01x' },
    aplic             = { kind = 'feed',  priority = 6, health = 65, stamina = 65, xp = 6, consume = true, prop = 'p_apple01x' },
    horsebrush        = { kind = 'brush', xp = 3, consume = false, prop = 'p_brushhorse02x' },
    stim              = { kind = 'stim',  health = 50, stamina = 50, overpower = { 1200, 1200 }, consume = true, prop = 'p_cs_syringe01x' },
    unique_horsesupp  = { kind = 'stim',  health = 35, stamina = 35, overpower = { 1000, 1000 }, consume = true, prop = 'p_cs_syringe01x' },
    stim2             = { kind = 'stim',  health = 30, stamina = 30, overpower = { 500, 500 }, consume = true, prop = 'p_cs_syringe01x' },
    horse_coat_changer = { kind = 'coat', consume = true },
}

Config.Reviver = { enabled = false, item = nil }

-- Nothing to edit below: feed items in priority order.
Config.FeedOrder = {}
for name, it in pairs(Config.Items) do
    if it.kind == 'feed' then Config.FeedOrder[#Config.FeedOrder + 1] = name end
end
table.sort(Config.FeedOrder, function(a, b) return Config.Items[a].priority < Config.Items[b].priority end)
