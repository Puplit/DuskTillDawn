-- pup_shaman | general settings

Config = Config or {}

Config.Debug = false -- extra console tracing (unknown curse keys, refused requests)

-- the key used at trees and in rituals (G)
Config.ActionKey = 0x760A9C6F
Config.ActionKeyLabel = 'G'

-- pup-bloodmoon integration: bigger forms and harder strikes while its blood moon is up
Config.BloodMoon = {
    enabled  = true,
    resource = 'pup-bloodmoon',
}

-- pup-misc instances: put each dreamer in their own routing bucket for the vision
Config.Instances = {
    enabled = false,
    offset  = 3000, -- bucket = server id + offset
}

-- animal forms
Config.Shift = {
    invincible       = true,  -- forms cannot be hurt
    timeLimitMinutes = 30,    -- 0 = no limit
    cooldownSeconds  = 120,   -- between accepted shifts, per server id
    returnCommand    = 'human',
    returnKey        = 0x4CC0E2FE, -- B
    returnKeyLabel   = 'B',
    returnHoldMs     = 1000,  -- how long B is held to complete the prompt
    jumpControl      = 0xD9D0E1C0, -- disabled for forms marked noJump
    fadeMs           = 800,   -- ms
    minSize          = 0.3,
    maxSize          = 3.0,
    modelTimeoutMs   = 5000,
    pedTimeoutMs     = 5000,
    humanTimeoutMs   = 15000, -- waiting for vorp_character's rc to rebuild the body
    weaponsBackMs    = 1500,  -- extra wait before ammo writes resume
    rebuildCommand   = 'rc',  -- vorp_character's rebuild command
    sizeReapplyMs    = { 250, 600, 1500 }, -- ms after a change
    -- controls disabled in a form and while dreaming
    disabledControls = {
        0x760A9C6F, 0x24978A28, 0xC1989F95, 0x4BC9DABB, 0xCEFD9220, 0xC7B5340A, 0x3C0A40F2, 0xB2F377E8,
        `INPUT_WHISTLE`, `INPUT_WHISTLE_HORSEBACK`, `INPUT_OPEN_HORSE_RADIAL`, `INPUT_MP_TEXT_CHAT_ALL`,
    },
    serverHour       = nil,  -- nil = use the hour the client reports
    -- struck player's camera shake
    struckShake      = { name = 'DEATH_FAIL_IN_EFFECT_SHAKE', amplitude = 0.4 },
    -- attack values used when a form's attack leaves one out
    attackDefaults   = { range = 3.0, damage = 45, cooldownSeconds = 150, ragdollMs = nil },
    attackSlack      = 2.0,  -- metres the server allows beyond the range
    attackResendMs   = 1500, -- client ignores presses this soon after the last send
}

-- ancient trees (general; the trees themselves are in config/trees.lua)
Config.TreeRules = {
    jobLock          = true,   -- only the tree's jobs (or carriers of its curse) can use it
    blipJobs         = { 'shaman' }, -- jobs that see tree blips while the job lock is on
    propDistance     = 25.0,
    reach            = 2.5,
    reachSlack       = 2.0,
    giveRange        = 2.0,
    giveSlack        = 1.5,
    wakeCommand      = 'wakeup',
    cooldownMinutes  = 5,      -- per character, per tree
    startTimeoutSec  = 20,     -- a vision the client never confirms is cleared after this
    collisionWaitMs  = 3000,   -- waiting for the far place to load before the swap
    returnAfterJoinMs = 4000,  -- after a reconnect, wait this long past the spawn before moving them back to the tree
    pick   = { dict = 'mech_pickup@plant@berries', clip = 'base', ms = 2500 },
    fruit  = { model = 's_peach01x', bone = 'SKEL_L_Finger12' },
    bite   = { dict = 'mech_inventory@eating@multi_bite@sphere_d8-2_sandwich', clip = 'quick_left_hand', ms = 2500 },
    give   = { dict = 'script_re@new_love@give_ring', clip = 'give_ring_player', ms = 2500 },
    blip   = { style = 1664425300, sprite = 669307703, scale = 0.2 },
}

-- cure drink played when a cure item is used
Config.CureDrink = {
    prop        = 'p_bottlejd01x',
    grip        = 'p_bottleJD01x_ph_r_hand',
    interaction = 'DRINK_BOTTLE@Bottle_Cylinder_D1-3_H30-5_Neck_A13_B2-5_TABLE_HOLD',
    ms          = 5000,
}
