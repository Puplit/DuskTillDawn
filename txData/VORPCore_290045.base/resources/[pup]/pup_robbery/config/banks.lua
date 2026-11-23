-- pup_robbery | bank heists (fields are described in README.md)
-- Bank ids (the table keys) are stored in the database: keep them.

local function v(x, y, z) return vector3(x, y, z) end

Config.Heist = {
    tokenLifetime   = 150,     -- seconds a minigame token stays valid
    interactRange   = 4.0,     -- metres; also the server reach for steps before the break-in
    promptDrawRange = 12.0,
    lootDrawRange   = 4.0,
    stagePrompts    = false,   -- draw a 3D label at the current stage (a bank may override)
    lootPrompts     = true,
    timeWarnings    = { 10, 5, 2, 1 }, -- minutes left
    doorGrace       = 45,      -- seconds the doors stay open after a run with a break-in ends
    doorFinalWarn   = 10,
    getawayRange    = 200.0,
    getawayReportMs = 5000,
    escapeZoneSlack = 5.0,
    pinGuesses      = 5,
    pinDifficulty   = 1,       -- digits = 3 + difficulty
    defaultFuse     = 8,
    cooldownScale   = { full = 1.0, partial = 1.0, failed = 0.5, abandoned = 0.25, crew_wipe = 0.5 },
    alarmMax        = 4,
    alarmNames      = { [0] = 'quiet', 'suspicious', 'alarm heard', 'robbery confirmed', 'vault alarm' },
    police = {
        persistent = true,
        fixedText  = 'Bank Robbery', -- empty string: use the per-level texts below
        once       = true,
        fromLevel  = 4,
        levelTexts = {
            [1] = { text = 'Suspicious activity reported near %s', vague = true },
            [2] = { text = 'Possible robbery at %s, alarm heard' },
            [3] = { text = '%s - ROBBERY CONFIRMED' },
            [4] = { text = '%s - VAULT ALARM ACTIVATED' },
        },
    },
    publicAlarm = { enabled = true, fromLevel = 3 },
    effects = { propRange = 75.0, fuseBarRange = 30.0, blastRange = 150.0, smokeSeconds = 12, explosionType = 25, cameraShake = 27.0 },
    losCacheMs   = 250,
    losTolerance = 0.75,
    propRefreshMs = 3000,
    lootPropRefreshMs = 2000,
    walkInDebounceMs = 5000,
    chargeAnimMs = 3500,
    honourEntryNeedsPrep = false, -- true: an entry with needsPrep = false can be used before the prep
    clearTaskOnWipe = true,       -- clear the posse's heist task even when the crew is empty at the end
    reviveRejoins = true,         -- a downed rider who is revived during the run rejoins the crew
    gangPoints = { 28, 60 },
    defaultAnim = { dict = 'script_proc@rustling@olar@player_picklock', name = 'base' },
    inspectAnim = { dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', name = 'idle_c' },
    grabAnim    = { dict = 'mech_pickup@loot@vaults@lrg@grab', name = 'moneybag_right_exit' },
    animLoadMs  = 1500,
    guardLingerMs   = 120000,  -- heist guards are removed this long after the run ends
    guardClearRange = 150.0,   -- or sooner, once the leader is this many metres from the bank
    -- a lockpick used with no heist target is passed on to doorlocks
    lockpickFallback = { item = 'lockpick', resource = 'doorlocks', event = 'pup-doorlocks:client:UseLockpick' },
}

Config.BankOrder = { 'armadillo', 'rhodes', 'saintdenis' }

local INSPECT = { dict = 'amb_work@world_human_crouch_inspect@male_c@idle_a', name = 'idle_c' }

Config.Banks = {
    armadillo = {
        label = 'Armadillo Bank', category = 'bank', lawmen = 2, riders = 4, jobLimit = 45,
        cooldown = 90, insideMinutes = 25, anchor = v(-3663.89, -2623.93, -13.70),
        region = 'WEST', dispatchLabel = 'Armadillo Bank', dispatchLocation = 'Armadillo',
        guardsAtAlarm = 4, getawayRange = 200.0, escapeZones = {}, stageCount = 3,
        vaultDoor = 3550475905,
        securityBox = v(-3668.99, -2639.14, -13.73),
        prep = {
            label = 'Cut the alarm line', game = 'wire_cut', tool = 'lockpick', failStep = 1,
            doneText = 'The alarm line is cut',
            boxes = { { useSecurityBox = true } },
        },
        entries = {
            front = { pos = v(-3663.89, -2623.93, -13.70), label = 'Kick in the front door', alarm = 2, needsPrep = false },
            back  = { pos = v(-3662.605, -2639.631, -13.980), label = 'Pick the back way in', alarm = 0, game = 'skill_circle', tool = 'lockpick', failStep = 1, doors = { 1366165179 } },
        },
        entryOrder = { 'front', 'back' },
        stages = {
            { id = 'charge', label = 'Set a charge', pos = v(-3661.865, -2627.176, -13.612), game = 'dynamite', tool = 'dynamite',
              fuse = 8, onlyVia = { 'front' }, placement = 'skill_bar', failStep = 1, anim = INSPECT },
            { id = 'outer', label = 'Crack the vault door', pos = v(-3665.92, -2628.63, -13.73), game = 'safe_crack', tool = 'banktools',
              failStep = 1, always = true, opensVault = true },
            { id = 'inner', label = 'Open the inner safe', pos = v(-3667.57, -2631.92, -13.73), game = 'skill_bar', tool = 'banktools',
              failStep = 0, always = true, last = true },
        },
        loot = {
            { pos = v(-3668.89, -2623.93, -13.70), prop = { model = 'p_moneystack01x' } },
            { pos = v(-3665.92, -2628.63, -13.73), prop = { model = 'p_moneybag01x' } },
            { pos = v(-3662.08, -2634.55, -13.73), prop = { model = 's_pickup_goldbar01x' } },
            { pos = v(-3667.57, -2631.92, -13.73), prop = { model = 'p_moneystack02x' } },
        },
        lootTable = {
            { item = 'moneybag_large', min = 1, max = 3, chance = 65, label = 'Big Bag of Cash' },
            { item = 'moneybag_medium', min = 1, max = 5, chance = 65 },
            { item = 'goldbar', min = 1, max = 10, chance = 25 },
            { item = 'diamond', min = 1, max = 10, chance = 10 },
        },
        guards = {
            { pos = v(-3666.80, -2626.50, -13.70), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REVOLVER_CATTLEMAN' },
            { pos = v(-3664.20, -2632.00, -13.73), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REPEATER_CARBINE' },
            { pos = v(-3665.50, -2629.20, -13.70), model = 'U_M_M_UniBountyHunter_01', weapon = 'WEAPON_SHOTGUN_PUMP' },
        },
    },

    rhodes = {
        label = 'Rhodes Bank', category = 'bank', lawmen = 2, riders = 4, jobLimit = 45,
        cooldown = 120, insideMinutes = 30, anchor = v(1294.528, -1299.139, 76.890),
        region = 'EAST', dispatchLabel = 'Rhodes Bank', dispatchLocation = 'Rhodes',
        stagePrompts = false, guardsAtAlarm = 4, getawayRange = 250.0, escapeZones = {}, stageCount = 1,
        vaultDoor = 3483244267,
        prep = {
            label = 'Kill the alarm', game = 'wire_cut', tool = 'lockpick', failStep = 1,
            doneText = 'The alarm is dead',
            boxes = { { pos = v(1295.168, -1307.114, 76.740), prop = { model = 'p_electricfielddetector01x', pos = v(1295.583, -1307.189, 77.230), rot = v(0.0, 0.0, -123.749) } } },
        },
        entries = {
            front = { pos = v(1285.712, -1303.091, 76.893), label = 'Pick the inner door', alarm = 1, game = 'lockpick', tool = 'lockpick', failStep = 1, doors = { 2058564250 } },
            back  = { pos = v(1278.593, -1311.606, 76.744), label = 'Pick the back way in', alarm = 0, game = 'lockpick', tool = 'lockpick', failStep = 1, doors = { 2513778780 } },
        },
        entryOrder = { 'front', 'back' },
        stages = {
            { id = 'code', label = 'Work out the vault code', pos = v(1282.275, -1308.373, 76.890), game = 'pincode', tool = 'banktools',
              failStep = 1, always = true, last = true, opensVault = true,
              alt = { label = 'Blow the vault door', game = 'dynamite', tool = 'dynamite', fuse = 8, alarmTo = 3, placement = 'skill_bar', failStep = 1, anim = INSPECT } },
        },
        clue = {
            label = 'Force the desk drawer', pos = v(1290.583, -1306.375, 76.892), game = 'button_mash', tool = 'crowbar', failStep = 1,
            doneText = 'A note tucked in the ledger. The vault code, most of it legible',
            reveal = 2, bonusGuesses = 4, reward = { item = 'banktools', min = 1, max = 2, label = 'Bank Tools' },
        },
        loot = {
            { pos = v(1288.049, -1313.278, 76.890), safe = true, label = 'Crack the safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(1286.303, -1315.431, 76.890), safe = true, label = 'Crack the safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(1287.920, -1314.692, 76.890), safe = true, label = 'Crack the safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(1288.930, -1311.516, 76.890), label = 'Clear the drawer' },
        },
        lootTable = {
            { item = 'moneybag_large', min = 1, max = 3, chance = 65, label = 'Big Bag of Cash' },
            { item = 'moneybag_medium', min = 1, max = 5, chance = 60 },
            { item = 'goldbar', min = 1, max = 5, chance = 28 },
            { item = 'diamond', min = 1, max = 5, chance = 12 },
        },
        guards = {
            { pos = v(1290.989, -1308.662, 76.890), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REVOLVER_CATTLEMAN' },
            { pos = v(1282.798, -1306.434, 76.890), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REPEATER_CARBINE' },
            { pos = v(1288.400, -1303.900, 76.890), model = 'U_M_M_UniBountyHunter_01', weapon = 'WEAPON_SHOTGUN_PUMP' },
        },
    },

    saintdenis = {
        label = 'Saint Denis Bank', category = 'bank', lawmen = 2, riders = 4, jobLimit = 45,
        cooldown = 180, insideMinutes = 35, anchor = v(2646.85, -1298.80, 52.24),
        region = 'EAST', dispatchLabel = 'Saint Denis Bank', dispatchLocation = 'Saint Denis',
        stagePrompts = true, promptRange = 8.0, insideRange = 25.0,
        guardsAtAlarm = 4, getawayRange = 350.0, escapeZones = {}, stageCount = 3,
        vaultDoor = 1751238140,
        -- not yet checked in game
        securityBox = v(2658.18, -1302.80, 52.26),
        prep = {
            label = 'Cut the alarm line', game = 'wire_cut', tool = 'lockpick', failStep = 1,
            doneText = 'The alarm line is cut',
            boxes = {
                { useSecurityBox = true },
                { pos = v(2685.268, -1274.429, 65.100), prop = { model = 'p_electricfielddetector01x', pos = v(2685.268, -1274.429, 65.100), heading = 282.0 } },
            },
        },
        entries = {
            front = { pos = v(2642.305, -1288.417, 52.002), label = 'Storm the front doors', alarm = 0 },
        },
        entryOrder = { 'front' },
        stages = {
            { id = 'office', label = 'Force the office door', pos = v(2647.728, -1300.019, 51.996), game = 'button_mash', tool = 'crowbar',
              failStep = 1, always = true, doors = { 965922748, 1634115439 },
              anim = { { dict = 'amb_camp@prop_camp_foodprep@working@potato_chop@male_b@base', name = 'base' },
                       { dict = 'amb_work@prop_human_pump_water@female_b@idle_a', name = 'idle_a' } } },
            { id = 'code', label = 'Work out the vault code', pos = v(2644.074, -1299.911, 51.996), game = 'pincode', tool = 'banktools',
              failStep = 1, always = true, opensVault = true,
              alt = { label = 'Blow the vault door', game = 'dynamite', tool = 'dynamite', fuse = 10, alarmTo = 3, placement = 'skill_bar', failStep = 1, anim = INSPECT } },
            { id = 'reserve', label = 'Open the reserve safe', pos = v(2644.340, -1306.649, 51.996), game = 'skill_circle', tool = 'banktools',
              failStep = 1, always = true, last = true },
        },
        clue = {
            label = 'Search the desk', pos = v(2650.311, -1305.186, 52.012),
            doneText = 'A note in the drawer. The vault code, half of it legible',
            reveal = 2, bonusGuesses = 4,
        },
        loot = {
            { pos = v(2644.417, -1306.678, 51.996), safe = true, label = 'Crack the first safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(2644.697, -1303.779, 51.996), safe = true, label = 'Crack the second safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(2641.360, -1303.299, 51.996), safe = true, label = 'Crack the third safe', game = 'safe_crack', tool = 'banktools', failStep = 1 },
            { pos = v(2637.222, -1292.480, 52.001) },
            { pos = v(2646.509, -1286.994, 52.008) },
            { pos = v(2647.082, -1303.977, 51.996) },
            { pos = v(2651.402, -1302.196, 51.996) },
        },
        lootTable = {
            { item = 'moneybag_large', min = 1, max = 1, chance = 70, label = 'Large Bag of Cash' },
            { item = 'goldbar', min = 1, max = 10, chance = 45 },
            { item = 'diamond', min = 1, max = 10, chance = 25 },
            { item = 'emerald', min = 1, max = 10, chance = 25 },
            { item = 'moneybag_medium', min = 2, max = 5, chance = 30 },
        },
        guards = {
            { pos = v(2646.00, -1290.00, 52.25), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REPEATER_CARBINE' },
            { pos = v(2649.50, -1296.50, 52.24), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'WEAPON_REVOLVER_SCHOFIELD' },
            { pos = v(2645.50, -1300.50, 52.24), model = 'U_M_M_UniBountyHunter_01', weapon = 'WEAPON_REPEATER_CARBINE' },
            { pos = v(2643.00, -1305.50, 52.24), model = 'U_M_M_UniBountyHunter_01', weapon = 'WEAPON_SHOTGUN_PUMP' },
        },
    },
}

-- Nothing to edit below: fills shared defaults so the code can read every field directly
for id, b in pairs(Config.Banks) do
    b.id = id
    b.extraDoors = b.extraDoors or {}
    b.lockedDoors = b.lockedDoors or {}
    b.escapeZones = b.escapeZones or {}
    b.interactRange = b.interactRange or Config.Heist.interactRange
    b.insideRange = b.insideRange or b.interactRange
    b.promptRange = b.promptRange or Config.Heist.promptDrawRange
    b.lootRange = math.max(Config.Heist.lootDrawRange, b.interactRange)
    if b.stagePrompts == nil then b.stagePrompts = Config.Heist.stagePrompts end
    b.getawayRange = b.getawayRange or Config.Heist.getawayRange
    if b.prep then
        for _, box in ipairs(b.prep.boxes) do
            if box.useSecurityBox then box.pos = b.securityBox end
        end
    end
    for _, s in ipairs(b.stages) do
        s.pos = s.pos or b.securityBox
        s.failStep = s.failStep or 0
        if s.alt then
            if s.alt.opensVault == nil then s.alt.opensVault = s.opensVault end
            s.alt.failStep = s.alt.failStep or 0
        end
    end
    for _, spot in ipairs(b.loot) do
        if not spot.safe then spot.label = spot.label or 'Grab the loot' end
    end
end
