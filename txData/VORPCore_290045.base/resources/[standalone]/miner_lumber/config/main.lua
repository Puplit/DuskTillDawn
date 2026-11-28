Config = {}

----------------------------------------------------------------
-- General
----------------------------------------------------------------
Config.Debug = false -- debug prints

Config.Keys = {
    start = 0xD9D0E1C0, -- Space (hold)
    swing = 0x07B8BEAF, -- left click
    stop  = 0x3B24C470, -- F
}

Config.Swings = { min = 2, max = 5 } -- swings per gather, random

-- Gather spots (config/data.lua). A spot can override any of these.
Config.NodeDefaults = {
    radius   = 1.5,                  -- m, prompt range
    limit    = { min = 2, max = 3 }, -- gathers before cooldown, random
    cooldown = 120000,               -- ms
}

Config.PropRespawn = 120000 -- ms, world rock/tree props

-- Swing minigame (pup-minigames skill bar)
Config.MinigameTuning = {
    area        = 20,   -- target zone, % of bar
    perfectArea = 6,    -- perfect strip, % of zone
    speed       = 0.75, -- sweep speed
    endDelay    = 400,  -- ms result is shown
    swingDelay  = 150,  -- ms before next swing

    -- Font Awesome 6 free icons
    icons = {
        mining = 'fa-solid fa-hammer',
        lumber = 'fa-solid fa-tree',
    },
}

----------------------------------------------------------------
-- Tools (usable items)
----------------------------------------------------------------
-- type: gather type it works on; durability: swings when new; drain: per swing
Config.Tools = {
    pickaxe   = { type = 'mining', durability = 200, drain = 1 },
    pickaxe1  = { type = 'mining', durability = 250, drain = 1 },
    pickaxe2  = { type = 'mining', durability = 500, drain = 1 },
    pickaxe3  = { type = 'mining', durability = 750, drain = 1 },
    hatchet   = { type = 'lumber', durability = 150, drain = 1 },
    lumberaxe = { type = 'lumber', durability = 300, drain = 1 },
}

----------------------------------------------------------------
-- Gather types
----------------------------------------------------------------
-- jobs: get jobBonus extra units per reward
-- rewards: each good swing rolls 1-10; entries with chance >= roll are
-- eligible, one is picked at random and gives 1..max units
Config.Gather = {
    mining = {
        jobs     = { 'rdmine', 'twmine', 'abmine' },
        jobBonus = 4, -- units
        rewards  = {
            { item = 'clay',       label = 'Clay',         chance = 8,  max = 4 },
            { item = 'coal',       label = 'Coal',         chance = 10, max = 7 },
            { item = 'copper',     label = 'Copper',       chance = 6,  max = 8 },
            { item = 'iron',       label = 'Iron',         chance = 6,  max = 12 },
            { item = 'nitrite',    label = 'Nitrite',      chance = 8,  max = 4 },
            { item = 'rock',       label = 'Rocks',        chance = 10, max = 4 },
            { item = 'salt',       label = 'Salt',         chance = 8,  max = 3 },
            { item = 'goldnugget', label = 'Gold Nuggets', chance = 3,  max = 2 },
        },
    },

    lumber = {
        jobs     = { 'sdlumber', 'vtlumber', 'bwlumber', 'sblumber' },
        jobBonus = 4, -- units
        rewards  = {
            { item = 'sap',    label = 'Sap',       chance = 10, max = 4 },
            { item = 'honey',  label = 'Honey',     chance = 5,  max = 2 },
            { item = 'wood',   label = 'Soft Wood', chance = 10, max = 5 },
            { item = 'hwood',  label = 'Hard Wood', chance = 8,  max = 5 },
            { item = 'rubber', label = 'Rubber',    chance = 8,  max = 4 },
            { item = 'fibers', label = 'Fibers',    chance = 10, max = 7 },
            { item = 'pulp',   label = 'Pulp',      chance = 10, max = 3 },
        },
    },
}
