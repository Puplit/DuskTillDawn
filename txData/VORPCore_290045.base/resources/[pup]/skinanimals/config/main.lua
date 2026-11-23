-- skinanimals | config/main.lua

Config = {}

Config.Debug = false

Config.Skinning = {
    deleteCarcass = false,
    deletePelt = false,
    peltDelayMs = 1000,

    anyOutfitFallback = true, -- an outfit no row names pays the model's plain yield
}

Config.Rules = {
    cooldownSec = 4,
    reach = 30.0,             -- metres

    -- true lets claims through when the server can't see the carcass, which also lets a
    -- modified client claim without any animal. Legendary rows always need a seen carcass.
    allowUnseen = false,
    unseenMax = 20,           -- per unseenWindowSec
    unseenWindowSec = 600,
    unseenLegendaryMax = 2,   -- per unseenLegendaryWindowSec
    unseenLegendaryWindowSec = 3600,
    limitLegendarySeen = true,
    requireDeadCarcass = true,

    paidLifetimeSec = 600,
    paidSweepSec = 300,

    floodMax = 8,             -- claim events per floodWindowSec
    floodWindowSec = 10,
}

Config.MercyKill = {
    enabled = true,
    startDelayMs = 1000,
    selectDelayMs = 2000,
}

Config.Messages = {
    style = 'tip',            -- 'tip' or 'left'
    refusalMs = 4000,
    resultMs = 5000,
    distinctRefusals = false,
}

Config.Integrations = {
    horseBond = true,
    bondOnlyWhenItemGiven = false,
    perks = true,
}

Config.SkinningLog = {
    enabled = false,          -- webhook in server/config.lua
}
