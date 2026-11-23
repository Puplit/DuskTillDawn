Config = {}

Config.StaffGroups = { admin = true, superadmin = true }   -- vorp_core user groups

Config.Item = 'phonograph'

Config.Model = 'p_phonograph01x'

Config.PerCharacterLimit = 1   -- 0 = no limit

-- links ---------------------------------------------------------------------
Config.PlayersMayPlay = true
Config.StaffSkipSiteCheck = true
Config.MaxLinkLength = 512
Config.ApprovedSites = {
    'youtube.com',
    'youtu.be',
    'soundcloud.com',
    'bandcamp.com',
    'vimeo.com',
    'archive.org',
    'dropbox.com',
    'dropboxusercontent.com',
}

-- sound ---------------------------------------------------------------------
Config.Radius = { default = 30.0, min = 5.0, max = 100.0 }   -- metres
Config.DefaultVolume = 0.3   -- 0.0 to 1.0

Config.Crackle = {
    enabled = false,
    url = '',
    volumeShare = 0.3, -- crackle volume = music volume x this
}

-- records -------------------------------------------------------------------
Config.Records = {}
Config.RecordVolume = 0.3

-- behaviour switches --------------------------------------------------------
Config.LoopToggleInMenu = false
Config.OwnerOnlyControl = false
Config.StopWhenStarterLeaves = false
Config.DiscordLog = false

-- distances (metres) --------------------------------------------------------
Config.Ranges = {
    prompt = 1.0,
    spawn = 50.0,
    control = 10.0,
    place = 60.0,
    pickup = 2.5,
    hearMargin = 25.0,
    leaveMargin = 15.0,
}

-- timers --------------------------------------------------------------------
Config.Timing = {
    playCooldownMs = 2000,      -- ms
    saveLockMs = 5000,          -- ms
    echoGuardSec = 5,           -- seconds
    loopReportGuardSec = 5,     -- seconds
    inputTimeoutMs = 60000,     -- ms
    listenerSyncMs = 2000,      -- ms
    placementTicketSec = 600,   -- seconds
    readyWaitMs = 10000,        -- ms
}

-- placement -----------------------------------------------------------------
Config.Placement = {
    startStep = 0.05,       -- metres
    minStep = 0.01,
    maxStep = 5.0,
    turnDegrees = 5.0,
    previewAlpha = 150,     -- 0 to 255
    previewDistance = 2.5,  -- metres
    confirmDelayMs = 1000,
    repeatFirstMs = 250,
    repeatMs = 60,
}

-- staff placement limits
Config.StaffJobMaxLength = 50
Config.StaffRankMax = 1000

-- RedM control hashes -------------------------------------------------------
Config.Keys = {
    openMenu = 0x760A9C6F,   -- G
    forward = 0x6319DB71,    -- arrow up
    back = 0x05CA7C52,       -- arrow down
    left = 0xA65EBAB4,       -- arrow left
    right = 0xDEB34313,      -- arrow right
    turnLeft = 0xE6F612E4,   -- 1
    turnRight = 0x1CE6D9EB,  -- 2
    step = 0x4F49CC4C,       -- 3
    raise = 0xB03A913B,      -- 7
    lower = 0x42385422,      -- 8
    cancel = 0x156F7119,     -- BACKSPACE
    confirm = 0xC7B5340A,    -- ENTER
}
