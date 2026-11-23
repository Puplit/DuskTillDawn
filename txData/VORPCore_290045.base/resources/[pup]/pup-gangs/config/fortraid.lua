-- pup-gangs | fort raids
-- A gang rides on a fort held by locals, fights off waves of them, kills the boss and cracks the strongbox.

-------------------------------------------------------------------------------
-- FORT RAID
-------------------------------------------------------------------------------
Config.FortRaid = {
    enabled             = true,
    unlock              = 'fort_raid',  -- gang perk flag required (level 3+)
    minRank             = 2,            -- rank needed to call the raid
    minCrew             = 1,            -- living gang members on site before the first wave spawns
    cooldownMinutes     = 45,           -- per fort
    gangCooldownMinutes = 30,           -- per gang, whichever fort they hit
    armMinutes          = 6,            -- called from the den; time to ride out before it lapses (0 = be on site to call it)
    startRadius         = 60.0,         -- metres, how close the crew must be for it to begin
    arenaRadius         = 120.0,        -- metres, leave this far and the raid is abandoned
    abandonSeconds      = 45,           -- grace before leaving counts as abandoning
    minRaidMinutes      = 8,            -- the strongbox stays shut until the raid has run this long, shown on the game's timer; 0 = off
    timerRedSeconds     = 30,           -- the timer turns red for the last this many seconds

    -- waves entry: count (peds), health, accuracy (0-100), spawnRadius (metres from the fort),
    -- models (ped models picked at random), weapons (picked at random)
    waves = {
        {
            count = 10, health = 200, accuracy = 35, spawnRadius = 45.0,
            models  = { 'U_M_M_UNIONLEADER_01', 'U_M_M_UNIONLEADER_02' },
            weapons = { 'weapon_repeater_carbine', 'weapon_shotgun_doublebarrel' },
        },
        {
            count = 12, health = 250, accuracy = 45, spawnRadius = 52.0,
            models  = { 'U_M_M_UNIONLEADER_02', 'U_M_M_UniBountyHunter_01' },
            weapons = { 'weapon_repeater_henry', 'weapon_shotgun_semiauto' },
        },
        {
            count = 14, health = 300, accuracy = 55, spawnRadius = 58.0,
            models  = { 'U_M_M_UniBountyHunter_01', 'U_M_M_UniBountyHunter_02' },
            weapons = { 'weapon_rifle_boltaction', 'weapon_repeater_evans' },
        },
    },
    waveBreakSeconds    = 12,           -- breathing room between waves

    -- the boss spawns alone once the last wave is cleared
    boss = {
        enabled  = true,
        model    = 'S_M_M_DispatchLeaderRural_01',
        name     = 'The Fort Boss',
        health   = 900,
        accuracy = 70,                  -- 0-100
        weapon   = 'weapon_shotgun_pump',
        armour   = true,                -- true = shrugs off a single lucky shot (no critical hits)
    },

    -- the strongbox appears where the boss falls; loot it to finish the raid
    lootProp     = 'p_chestmetal01x',
    lootSeconds  = 8,                   -- how long cracking it takes
    lootDistance = 2.5,                 -- metres
    lootToDen    = true,                -- false = straight to the satchel of whoever cracked it

    -- loot.table entry: { item, min, max, chance } (chance 0-100)
    loot = {
        rolls = 5,                      -- at most this many different entries per box
        table = {
            -- bench materials
            { item = 'gunpowder',       min = 4, max = 10, chance = 85 },
            { item = 'paper',           min = 2, max = 6,  chance = 70 },
            -- sellables
            { item = 'goldbar',         min = 1, max = 2,  chance = 30 },
            { item = 'emerald',         min = 1, max = 2,  chance = 25 },
            { item = 'stolenmerch',     min = 2, max = 5,  chance = 55 },
            { item = 'moneybag_medium', min = 1, max = 3,  chance = 45 },
            -- contraband
            { item = 'heroin',          min = 1, max = 2,  chance = 20 },
            { item = 'acid',            min = 2, max = 5,  chance = 20 },
            -- finished goods
            { item = 'dynamite',        min = 1, max = 3,  chance = 25 },
        },
    },

    -- forts entry: label, x, y, z (the fort centre)
    forts = {
        {
            label = 'Fort Mercer',
            x = -4203.01, y = -3446.05, z = 40.02,
        },
        {
            label = 'Fort Wallace',
            x = 357.79, y = 1466.82, z = 179.20,
        },
        {
            label = 'Lemoyne Fort',
            x = 2454.50, y = 292.50, z = 70.35,
        },
    },
}
