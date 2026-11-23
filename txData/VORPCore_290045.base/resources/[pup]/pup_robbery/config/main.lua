-- pup_robbery | general settings
-- Places live in config/places.lua, banks in config/banks.lua, the fence in config/fence.lua.

Config = Config or {}

-- diagnostics in the console, and /testminigame
Config.Debug = false

-- heist test tools. Keep every switch off on a live server.
Config.TestMode = {
    enabled   = false, -- unlocks /heists, /heiststart, /heistreset, /heistcancel, /heistalarm, /vaultcode and the client test tools
    ignoreLaw = false, -- waives every lawmen count
    soloCrew  = false, -- an admin counts as a full crew at the fence, and skips the introduction gate
}

-- VORP user groups that count as admin
Config.AdminGroups = { admin = true }

-- jobs that may not rob, ask the fence for work or break into a bank
Config.BlockedJobs = { doctor = true, police = true }

-- the interact key (G). Used by every prompt this resource draws, the fence included.
Config.InteractKey = 0x760A9C6F
Config.InteractKeyLabel = 'G'

-- the posse command named in messages (pup-ui's own command label is preferred when it answers)
Config.PosseCommand = 'pose'

-- name of the command that clears a lawman's robbery alert
Config.AlertClearCommand = 'gotalert'
-- true: the command also removes the lawman's robbery alert blips
Config.AlertClearRemovesBlips = true

-- pup-mdt police board alerts
Config.MdtAlerts = true

-- the player's bandana must be up (pup-misc) before anything happens at a place
Config.MaskRequired = true

-- perk keys (pup-perks)
Config.Perks = {
    double   = 'robbery_double',
    cash     = 'robbery_cash',
    cooldown = 'robbery_cooldown',
    solo     = 'solo_robbery',
    access   = 'heist_access',
    fenceCut = 'fence_cut',
    fenceWord = 'fence_word',
    fenceNext = 'fence_next',
    streetword = 'streetword',
    xpRobbery = 'robbery',
    xpFence   = 'fence_sale',
}

-- the Cool Head multiplier is clamped to this range before it shortens a personal clock
Config.CooldownPerkClamp = { min = 0.05, max = 1.0 }

-- personal clocks, minutes
Config.PersonalClocks = {
    walkup = 120, -- set for the whole posse when a walk-up job starts, and for late joiners
    bank   = 480, -- set for every crew character at a break-in
}

-- per-category defaults; a place may override any of them
Config.Categories = {
    bank  = { lawmen = 2, riders = 1, jobLimit = 45 },
    store = { lawmen = 1, riders = 1, jobLimit = nil },
    fort  = { lawmen = 1, riders = 2, jobLimit = 30 },
    other = { lawmen = 2, riders = 1, jobLimit = 30 },
}

Config.Walkup = {
    defaultRiders     = 1,
    timerLowSeconds   = 30,     -- the countdown turns red below this
    lockZeroLawPlacesAtStart = true, -- places needing 0 lawmen start on cooldown
    xpShareRange      = 200.0,  -- posse riders this close to the looter also get XP (0 = any distance)
    joinDistance      = nil,    -- global crew-join radius; nil = each place's stray distance, capped below
    joinDistanceCap   = 200.0,  -- metres
    crewSweepMs       = 8000,
    boxPromptRange    = 3.0,    -- metres
    claimWaitMs       = 3000,
    startSlack        = 30.0,   -- server: start radius + this
    boxReach          = 15.0,   -- server: metres from the box for a reward
    unlockSlack       = 2,      -- server: seconds of slack on the unlock clock
    bandanaPollMs     = 250,
    guardBlips        = true,
    gangPointsDefault = { 10, 25 },
    placeBlip = { sprite = 90287351, scale = 0.8 },
    boxBlip   = { sprite = -1357626643, scale = 0.8 },
    persistPlaceCooldowns = false, -- true: place cooldowns survive a restart
    lawModelsUsePoliceProfile = false, -- true: guards with a model in Config.LawModels use the police profile
    resetLastRiderClock = false, -- true: the last rider's personal clock is set again when the job ends
    warnFarData = true, -- console warning for boxes set past the place's stray distance
}

Config.GuardProfiles = {
    outlaw = { health = 200, accuracy = 35, cover = false },
    police = { health = 320, accuracy = 65, cover = true },
}
Config.GuardAmmo = 1000
Config.GuardModelTimeoutMs = 5000
Config.GuardBlipStyle = 953018525
-- extra ped config flags set on every guard, as { flag, value } pairs (empty by default)
Config.GuardConfigFlags = {}

-- lawman models, used only when Config.Walkup.lawModelsUsePoliceProfile is on
Config.LawModels = {
    U_M_M_RhdBackupDeputy_02 = true,
    S_M_M_DispatchLeaderPolice_01 = true,
    S_M_M_DispatchLeaderRural_01 = true,
    S_M_M_AmbientSDPolice_01 = true,
    S_M_M_AmbientBlWPolice_01 = true,
    S_M_M_DispatchPolice_01 = true,
    U_M_M_SDPoliceChief_01 = true,
}

-- lawman alert blip (map blip shown to on-duty lawmen while a job runs)
Config.LawBlip = { sprite = 639638961, scale = 0.2, modifier = 0x6F85C3CE }

-- the dark box behind 3D labels
Config.LabelSprite = { dict = 'feeds', name = 'hud_menu_4a' }

-- the usable heist tools
Config.UsableTools = { 'lockpick', 'banktools', 'dynamite', 'ironhammer', 'crowbar' }

-- minigame tuning
Config.Minigames = {
    walkup = {
        normal       = { style = 'default', icon = 'fa-solid fa-lock', orientation = 2, area_size = 20, perfect_area_size = 5, speed = 0.5, moving_icon = true, icon_speed = 3 },
        skill_circle = { style = 'default', area_size = 4, speed = 0.02 },
        wire_cut     = { style = 'default', timer = 60000 },
        button_mash  = { style = 'default', difficulty = 10 },
        pincode      = { style = 'default', difficulty = 4, guesses = 5 },
        chip_hack    = { style = 'default', loading_time = 8000, chips = 2, timer = 20000 },
        key_drop     = { style = 'default', score_limit = 5, miss_limit = 5, fall_delay = 1000, new_letter_delay = 2000 },
        anagram      = { style = 'default', loading_time = 5000, difficulty = 10, guesses = 5, timer = 30000 },
        hangman      = { style = 'default', loading_time = 5000, difficulty = 4, guesses = 5, timer = 30000 },
    },
    heist = {
        safe_crack   = { style = 'default', difficulty = 3, attempts = 3 },
        wire_cut     = { style = 'default', timer = 60000 },
        skill_circle = { style = 'default', area_size = 3, speed = 0.02 },
        button_mash  = { style = 'default', difficulty = 5 },
        skill_bar    = { style = 'default', orientation = 1, area_size = 20, perfect_area_size = 5, speed = 0.5, moving_icon = true, icon_speed = 3, position_variance = true },
    },
    tester = { safeDifficulty = 3 },
    wirePauseMs = 700,
    -- a game that never answers is treated as a failure after this long
    timeoutMs = 240000,
}

-- Discord log look (the webhook itself is in server/config.lua)
Config.Discord = {
    username = 'pup_robbery',
    avatar   = '', -- an image URL the owner has the right to use, or empty for none
}
