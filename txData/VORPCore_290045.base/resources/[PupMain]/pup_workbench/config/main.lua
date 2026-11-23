-- pup_workbench: main settings (shared by server and client; no secrets here)
Config = {}

Config.Debug = false              -- print refusals and other detail to the console

-- the Craft prompt
Config.Prompt = {
    key = 0x760A9C6F,             -- G
    stationReach = 1.5,           -- metres, client: how close to a named station
    propReach = 1.5,              -- metres, client: how close to a station prop
    idleCheckMs = 600,            -- how often to look around while nothing is near
}

-- server-side distance checks
Config.Server = {
    stationReach = 4.0,           -- metres from a named station when crafting
    propReach = 4.0,              -- metres from the prop the bench was opened at
}

-- skill bar (pup-minigames) shown before every craft
Config.SkillBar = {
    enabled = true,
    baseZone = 34, zonePerPoint = 1.5, minZone = 14,
    perfectZone = 6,
    baseSpeed = 0.18, speedPerPoint = 0.02, maxSpeed = 0.55,
    timeoutMs = 30000,            -- a bar that never reports back counts as a fumble
}

Config.DefaultDifficulty = 3000
Config.MaxUnitsPerCraft = 1000
Config.TokenLifetime = 300        -- seconds a started craft may wait for its finish

-- the crouch-and-inspect scene played while crafting
Config.CraftScene = {
    scenario = 'WORLD_HUMAN_CROUCH_INSPECT',
    durationMs = 15000,
    skillBarAfterMs = 3000,
}

-- player-written descriptions on crafted goods
Config.Descriptions = {
    enabled = true,
    recentKept = 20,
    maxLength = 300,
    bannedWords = { 'fag', 'nigger', 'faggot', 'nigga', 'racist' },
    wholeWordsOnly = false,       -- false = match anywhere inside words
}

-- the personal crafting box (take-only custom inventory)
Config.Box = {
    enabled = true,
    idOffset = 9000000,
    anchorRadius = 15.0,
    stationSearch = 30.0,
    wipeOnStart = true,           -- empty every box when this resource starts
    wipeDelayMs = 3000,
}

-- timed crafting with the Pending shelf
Config.Timed = {
    enabled = true,
    defaultSecondsPerUnit = 10,
    batchCapSeconds = 7200,       -- 2 hours
    maxRunning = 5,
    countReadyTowardLimit = false, -- false = only crafts still running count
    keepCollectedDays = 7,
    sweepEveryMs = 3600000,
}

-- tool wear (only these tools wear; values are the maximum durability)
Config.ToolWear = {
    enabled = true,
    drain = 1,
    perUnit = false,              -- false = once per craft whatever the amount
    tools = {
        wrench = 150,
        skinning_knife = 120,
        handsaw = 120,
        unique_straightrazor = 60,
        wood_plane = 100,
    },
    overrides = {},               -- per-tool drain, e.g. { handsaw = 2 }
    conditionSeparator = '<br>',
}

-- items that put down a world prop which then counts as a station prop
Config.Placeables = {
    pickupCommand = 'dc',
    pickupCooldownMs = 3000,
    placeMs = 5000,
    items = {
        campfire = { model = 'p_campfire02x', townLock = false },
    },
}

-- map town-zone names a town-locked placeable cannot be set up in
Config.BannedTowns = {
    'Annesburg', 'Armadillo', 'Blackwater', 'BeechersHope', 'Breaithwaite', 'Butcher',
    'Caliga', 'Cornwall', 'Emerald', 'Lagras', 'Manzanita', 'Rhodes', 'Siska', 'StDenis',
    'Strawberry', 'Tumbleweed', 'Valentine', 'Vanhorn', 'Wallace', 'Wapiti',
    'AguasducesFarm', 'AguasdulcesRuins', 'AguasdulcesVilla', 'Manico',
}

-- usable items that open the bench anywhere ("Crafting Kit"); none at present
Config.Kits = {}

-- world models that count as a bench, with the label shown on the prompt and panel
Config.StationProps = {
    p_campfire02x = 'Campfire',
    p_campfire02x_script = 'Campfire',
    p_campfirecombined02x = 'Campfire',
    p_campfirecombined04x = 'Campfire',
    p_campfirerocksml02x = 'Campfire',
    kettle_stove = 'Stove',
    p_cast_iron_pot_001 = 'Cooking Pot',
    p_syringecase01x = 'Medical Case',
    p_trashbin01x = 'Workbench',
    p_table44x = 'Work Table',
    p_furnace02x = 'Furnace',
}

-- recipe and perk rules
Config.Rules = {
    genericRecipesAtStations = false, -- false = recipes with no station list only show at props and kits
    showRecipesAboveXp = false,       -- false = recipes above the player's XP are hidden
    perkDoublesXp = false,            -- the Craftsman perk doubles goods only
}

-- Discord log look (the webhook itself lives in server/config.lua)
Config.Log = {
    title = 'Crafting log',
    colour = 16711680,
    violationColour = 16711680,
    botName = 'Crafting Bot',
    footer = 'pup_workbench',
}

-- recipes seeded into an empty recipe table (none at present)
Config.SeedRecipes = {}

-- the base categories every experience record starts with
Config.BaseXpCategories = { 'medical', 'blacksmith', 'basic', 'survival', 'brewing', 'food' }
