-- pup-gangs | main settings
-- Player-run gangs: creation, factions, ranks, the territory map, wars, points, blood money and missions.

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug         = false,        -- print [pup-gangs] traces to the server console and F8. Off on a live server
    createCommand = 'creategang', -- chat command that starts founding a gang ('' = no command)
    panelCommand  = 'gang',       -- chat command that accepts invites; opens the panel only when menuAnywhere = true
    menuAnywhere  = false,        -- false = the gang panel opens ONLY at the gang table
}

-- Prompt keys. Change the hash only.
Config.Keys = {
    table        = 0xCEFD9220,    -- E  open the gang table
    tablePickup  = 0x760A9C6F,    -- G  founder picks the gang table back up
    denInteract  = 0xCEFD9220,    -- E  collect product / raid at a den crate
    denRun       = 0x760A9C6F,    -- G  start a delivery run at your own den
    denMenu      = 0x3B24C470,    -- F  open the panel in den context (claims and raids)
    denDoor      = 0x760A9C6F,    -- G  use the key / go inside / step outside at a den door
    denWorkbench = 0xCEFD9220,    -- E  the den's own panel, inside the shack
    denStores    = 0xCEFD9220,    -- E  the den inventory, inside the shack
    fortLoot     = 0xCEFD9220,    -- E  crack the fort raid strongbox (hold)
}

-------------------------------------------------------------------------------
-- INTEGRATIONS  (other resources this one talks to)
-------------------------------------------------------------------------------
-- Other integrations need no settings here (see README.md).
Config.Integrations = {
    homestead = {
        cropType = 'Gang Crop',   -- pup_homestead Config.Crops key for the gang drug (shown in the panel)
    },
}

-------------------------------------------------------------------------------
-- CREATION  (founding a gang at the gang table)
-------------------------------------------------------------------------------
Config.Creation = {
    price          = 5000,   -- cash charged to found a gang
    item           = nil,    -- optional item consumed on creation, e.g. 'gang_charter' (nil = none)
    minNameLength  = 3,      -- gang name length, characters
    maxNameLength  = 24,
    minShortLength = 2,      -- short name / tag length ("Valentine Predators" -> "VPR")
    maxShortLength = 5,
    maxMembers     = 10,     -- base roster cap before level and blood-money slots (0 = unlimited)
}

-------------------------------------------------------------------------------
-- FACTIONS  (every gang picks ONE when it is founded, permanently)
-------------------------------------------------------------------------------
-- list entry: label, blurb (creation form text), colorModifier (blip colour hash name),
-- bonus = { label, robberyMult, missionMult, warMult } (1.0 = normal)
Config.Factions = {
    hidden = true,                                -- true = a gang's faction is intel, not a public label
    order  = { 'outlaws', 'syndicate', 'reapers' }, -- order in the creation form (keys of list)
    list   = {
        outlaws = {
            label         = 'The Outlaws',
            blurb         = 'Take what you please. Answer to no one.',
            colorModifier = 'BLIP_MODIFIER_MP_COLOR_2',
            bonus         = { label = 'Robbery points +25%', robberyMult = 1.25, missionMult = 1.0, warMult = 1.0 },
        },
        syndicate = {
            label         = 'The Syndicate',
            blurb         = 'Business first. Violence is a line item.',
            colorModifier = 'BLIP_MODIFIER_MP_COLOR_5',
            bonus         = { label = 'Mission points +25%', robberyMult = 1.0, missionMult = 1.25, warMult = 1.0 },
        },
        reapers = {
            label         = 'The Reapers',
            blurb         = 'Blood earns ground. Ground earns respect.',
            colorModifier = 'BLIP_MODIFIER_MP_COLOR_8',
            bonus         = { label = 'War points +25%', robberyMult = 1.0, missionMult = 1.0, warMult = 1.25 },
        },
    },
}

-------------------------------------------------------------------------------
-- RANKS  (index 1 is the lowest)
-------------------------------------------------------------------------------
-- list entry: id, label, then permissions invite / kick / promote / war / bank / territory (true/false)
-- unlocks: what each rank index unlocks for the member: label (panel text), stash (may open gang stashes)
Config.Ranks = {
    list = {
        {
            id = 1, label = 'Prospect',
            invite = false, kick = false, promote = false,
            war = false, bank = false, territory = false,
        },
        {
            id = 2, label = 'Soldier',
            invite = false, kick = false, promote = false,
            war = false, bank = false, territory = false,
        },
        {
            id = 3, label = 'Enforcer',
            invite = true, kick = false, promote = false,
            war = false, bank = false, territory = false,
        },
        {
            id = 4, label = 'Underboss',
            invite = true, kick = true, promote = true,
            war = true, bank = true, territory = true,
        },
        {
            id = 5, label = 'Boss',
            invite = true, kick = true, promote = true,
            war = true, bank = true, territory = true,
        },
    },
    unlocks = {
        [1] = { label = 'Run deliveries',                               stash = false },
        [2] = { label = 'Access the drug stash',                        stash = true  },
        [3] = { label = 'Invite members, plant on rivals',              stash = true  },
        [4] = { label = 'Declare wars, claim ground, spend the ledger', stash = true  },
        [5] = { label = 'Everything',                                   stash = true  },
    },
}

-------------------------------------------------------------------------------
-- MAP  (territory circles and the live map layer)
-------------------------------------------------------------------------------
Config.Map = {
    enabled            = true,
    baseRadius         = 60.0,   -- metres at 0 points (also used for unclaimed ground)
    -- influence curve: radius in metres reached at each points total
    radiusCurve        = {
        { points = 0,    radius = 60.0  },
        { points = 250,  radius = 75.0  },
        { points = 750,  radius = 90.0  },
        { points = 1500, radius = 110.0 },
        { points = 3000, radius = 130.0 },
    },
    maxRadius          = 140.0,  -- metres, hard ceiling however rich the gang gets
    blipSprite         = 'blip_mp_hideout', -- centre icon ('' = none)
    showName           = true,   -- label the blip (short name + points + faction)
    showRivalTerritory = true,   -- false = you only see your own gang's turf
    refreshSeconds     = 30,     -- how often clients re-pull the territory list
    worldCircles       = false,  -- false = clean point markers on the world map instead of painted circles
    worldBlips         = 'none', -- what reaches the world map at all ('none' = nothing)
}

-------------------------------------------------------------------------------
-- COLOURS  (the colour a gang flies)
-------------------------------------------------------------------------------
-- list entry: key (stored on the gang), label, modifier (blip colour hash name), hex (panel colour)
Config.Colors = {
    default = 'red',             -- key a new gang starts with
    list    = {
        {
            key = 'red', label = 'Blood Red',
            modifier = 'BLIP_MODIFIER_MP_COLOR_2', hex = '#c0392b',
        },
        {
            key = 'blue', label = 'Union Blue',
            modifier = 'BLIP_MODIFIER_MP_COLOR_5', hex = '#2980b9',
        },
        {
            key = 'green', label = 'Bottle Green',
            modifier = 'BLIP_MODIFIER_MP_COLOR_8', hex = '#27ae60',
        },
        {
            key = 'purple', label = 'Deep Purple',
            modifier = 'BLIP_MODIFIER_MP_COLOR_7', hex = '#8e44ad',
        },
        {
            key = 'orange', label = 'Rust Orange',
            modifier = 'BLIP_MODIFIER_MP_COLOR_3', hex = '#d35400',
        },
        {
            key = 'yellow', label = 'Gold',
            modifier = 'BLIP_MODIFIER_MP_COLOR_4', hex = '#d4a017',
        },
        {
            key = 'pink', label = 'Dusty Rose',
            modifier = 'BLIP_MODIFIER_MP_COLOR_6', hex = '#c2557a',
        },
        {
            key = 'teal', label = 'Verdigris',
            modifier = 'BLIP_MODIFIER_MP_COLOR_9', hex = '#16a085',
        },
        {
            key = 'white', label = 'Bone White',
            modifier = 'BLIP_MODIFIER_MP_COLOR_31', hex = '#d8d0c0',
        },
        {
            key = 'black', label = 'Coal Black',
            modifier = 'BLIP_MODIFIER_MP_COLOR_32', hex = '#4a4a4a',
        },
    },
}

-------------------------------------------------------------------------------
-- WARS
-------------------------------------------------------------------------------
Config.Wars = {
    enabled          = true,
    declareCost      = 2500,   -- cash to declare (blood money cost is Config.Blood.perWar)
    durationHours    = 24,     -- how long a war runs
    pointsPerKill    = 5,      -- gang points per enemy kill during a war
    allowSameFaction = false,  -- false = no wars between gangs repping the same faction
}

-------------------------------------------------------------------------------
-- GANG TABLE  (a gang is founded at a table placed inside a house the placer owns or holds)
-------------------------------------------------------------------------------
Config.Table = {
    item             = 'gang_table',  -- consumed on placement, refunded when picked up
    prop             = 'p_table04x',  -- prop spawned for the table
    interactDistance = 2.0,           -- metres
}

-------------------------------------------------------------------------------
-- POINTS  (awarded through the AwardPoints export so any resource can feed the system)
-------------------------------------------------------------------------------
Config.Points = {
    announce      = false,  -- tell the player every time their gang scores
    robbery       = 25,     -- default award for kind = 'robbery' when no amount is given
    mission       = 15,     -- default award for kind = 'mission'
    warWin        = 150,
    warLoss       = 25,     -- consolation, so losing a war is not purely punishing
    territoryCap  = 50,
    decayEnabled  = true,   -- gangs bleed points when idle, so the map reflects who is active
    decayPerDay   = 10,     -- points lost per real day with no activity
    decayFloor    = 0,      -- never decay below this
    dedupeMinutes = 10,     -- one robbery = one gang award, however many members ran it
}

-------------------------------------------------------------------------------
-- ACTIVITY  (second indicator next to points: how much has this gang done lately)
-------------------------------------------------------------------------------
Config.Activity = {
    highWeekly   = 300,  -- points earned in 7 days for HIGH
    mediumWeekly = 75,   -- points earned in 7 days for MEDIUM; anything less is LOW
}

-------------------------------------------------------------------------------
-- BLOOD MONEY  (the gang currency and what it buys)
-------------------------------------------------------------------------------
Config.Blood = {
    enabled         = true,
    item            = 'blood_money',  -- the item members carry and bank into the ledger

    -- what it buys
    perMember       = 25,    -- taking a new rider on, charged when they accept
    perPerk         = 50,    -- unlock one perk your level has made available
    perColour       = 15,    -- changing the banner colour
    perWar          = 200,   -- declaring war on a rival, on top of Config.Wars.declareCost
    perksNeedBuying = true,  -- true = reaching a level only puts its perks on the shelf
    maxExtra        = 5,     -- member slots that can be bought (still capped by the gang level)

    -- where it comes from: { min, max } per award
    mission         = { min = 1, max = 5 },  -- gang missions: plant run, defend, fort raid, den
    robbery         = { min = 1, max = 3 },  -- per box looted (pup_robbery)
    drugSale        = { min = 1, max = 2 },  -- per sale through pup_hideouts
    robberyChance   = 55,    -- chance (0-100) per box
    drugSaleChance  = 45,    -- chance (0-100) per sale
}

-------------------------------------------------------------------------------
-- MISSIONS  (the delivery run: plant a package on rival ground, hold it, get home)
-------------------------------------------------------------------------------
Config.Missions = {
    enabled         = true,
    unlock          = 'missions',      -- gang perk flag required to start one
    minRank         = 3,               -- rank needed to pick up a package
    packageItem     = 'drug_package',
    minPosse        = 5,               -- gang members needed for a run
    defendSeconds   = 900,             -- time the defenders get to find the plant
    cooldownMinutes = 30,              -- per attacking gang
    collectMinutes  = 10,              -- time allowed to get home to the den once it survives
    alertRadius     = 90.0,            -- metres, how vague the defenders' circle is
    alertColor      = 'BLIP_MODIFIER_MP_COLOR_2',
    alertSprite     = 'blip_attention',
    destroyDistance = 2.0,             -- metres a defender must get to destroy it
    -- what a run and a defence pay is in config/rewards.lua
}

-------------------------------------------------------------------------------
-- CLAIMS  (20-minute public sieges for territory)
-------------------------------------------------------------------------------
Config.Claims = {
    enabled            = true,
    durationMinutes    = 20,    -- hold this long and the ground changes hands
    tickSeconds        = 10,    -- presence check interval
    presenceTicks      = 3,     -- consecutive empty checks before the claim fails
    travelGraceMinutes = 5,     -- time allowed to reach the ground before the claim collapses
    cooldownMinutes    = 15,    -- per territory, after any attempt
    defendersOnline    = true,  -- a held ground is only contestable while its holders have someone online
    minPosse           = 5,     -- gang members needed to call a claim
    startOnArrival     = true,  -- the clock starts when the posse gets there
}
