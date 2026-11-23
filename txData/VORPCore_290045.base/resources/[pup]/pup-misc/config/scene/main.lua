-- pup-misc/scene | main settings (see README)

SceneConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
SceneConfig.General = {
    -- chat commands
    commands = {
        place      = "scene",     -- type a text, then place it
        removeAim  = "scenes",    -- toggles aim-to-remove mode
        me         = "me",
        ooc        = "ooc",
        status     = "status",    -- a label over your head until /cstatus
        stopStatus = "cstatus",
        id         = "id",
        cash       = "cash",
    },
}

-- keys: a raw control hash or an "INPUT_..." name
SceneConfig.Keys = {
    place  = 0x760A9C6F,   -- G      place the scene / remove the aimed one in /scenes mode
    mode   = 0x8F9F9E58,   -- 4      cycle AIM / MOVE / STYLE; also removes a scene you stand at
    up     = 0x6319DB71,   -- UP     MOVE forward / STYLE previous row
    down   = 0x05CA7C52,   -- DOWN   MOVE back / STYLE next row
    left   = 0xA65EBAB4,   -- LEFT   MOVE left / STYLE previous value
    right  = 0xDEB34313,   -- RIGHT  MOVE right / STYLE next value
    raise  = 0xE6F612E4,   -- 1      MOVE up
    lower  = 0x1CE6D9EB,   -- 2      MOVE down
    cancel = 0x4CC0E2FE,   -- B      cancel placement / leave /scenes mode
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
SceneConfig.Integrations = {}

-------------------------------------------------------------------------------
-- ACCESS  (admins always may)
-------------------------------------------------------------------------------
SceneConfig.Access = {
    jobLock    = true,             -- true = only allowJobs may place scenes
    allowJobs  = { "newspaper" },  -- may place (and remove) scenes
    removeJobs = { "newspaper" },  -- may remove ANYONE's scene
    -- no scenes are drawn or placed near the hideout
    hideout = {
        enabled = true,
        coords  = vector3(1785.01, -821.53, 191.01),
        radius  = 100,             -- metres
    },
}

-------------------------------------------------------------------------------
-- REMOVAL  (/scenes)
-------------------------------------------------------------------------------
SceneConfig.Removal = {
    aimRange = 60.0,    -- metres the aim reaches
    aimDot   = 0.995,   -- 0.995 is about 6 degrees
}

-------------------------------------------------------------------------------
-- DISPLAY
-------------------------------------------------------------------------------
SceneConfig.Display = {
    defaultRange = 5,   -- metres
}

-------------------------------------------------------------------------------
-- PLACE
-------------------------------------------------------------------------------
SceneConfig.Place = {
    aimDistance   = 12.0,  -- metres
    surfaceOffset = 0.04,  -- metres

    -- MOVE mode
    moveSpeed     = 0.55,  -- m/s at the start of a hold
    moveSpeedMax  = 3.20,  -- m/s once fully ramped
    moveRamp      = 1.20,  -- seconds

    -- ghost preview
    previewHz     = 6,     -- updates per second
    previewRange  = 30.0,  -- metres
}

-------------------------------------------------------------------------------
-- KNOCKED OUT
-------------------------------------------------------------------------------
SceneConfig.KnockedOut = {
    r      = 168, g = 50, b = 50,   -- crimson
    scale  = 0.32,
    font   = 1,
    back   = 0.35,                  -- backing plate opacity, 0 = off
    range  = 12.0,                  -- metres
    height = 1.0,                   -- metres
}

-------------------------------------------------------------------------------
-- LIMITS  (enforced by the server)
-------------------------------------------------------------------------------
SceneConfig.Limits = {
    maxTextLength    = 400,    -- characters
    maxPlaceDistance = 25.0,   -- metres
    maxScenesPerChar = 25,     -- 0 = unlimited
    minScale         = 0.15,
    maxScale         = 0.80,
    maxRange         = 40.0,   -- metres
}
