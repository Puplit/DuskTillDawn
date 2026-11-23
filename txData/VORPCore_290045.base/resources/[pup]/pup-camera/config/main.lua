Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug   = false,
    command = "cam",
    keybind = "",      -- e.g. "F6"; "" = command only
}

-- Windows virtual-key codes, not control hashes
Config.Keys = {
    menu = 77,    -- M
    help = 114,   -- F3
}

-------------------------------------------------------------------------------
-- MOVEMENT
-------------------------------------------------------------------------------
Config.Movement = {
    speed           = 0.45,   -- metres per frame
    boostMultiplier = 3.0,    -- Shift
    slowMultiplier  = 0.18,   -- V / Ctrl
    lookSensitivity = 6.0,
}

-------------------------------------------------------------------------------
-- LENS
-------------------------------------------------------------------------------
Config.Lens = {
    fovDefault      = 50.0,   -- degrees
    fovMin          = 5.0,    -- degrees
    fovMax          = 110.0,  -- degrees
    fovStep         = 2.0,    -- degrees per frame
    letterboxHeight = 0.11,   -- fraction of the screen, each bar
}

-------------------------------------------------------------------------------
-- DOLLY
-------------------------------------------------------------------------------
Config.Dolly = {
    legSeconds       = 6.0,   -- seconds per leg
    countdownSeconds = 3,     -- seconds
}

-------------------------------------------------------------------------------
-- CARRIER
-------------------------------------------------------------------------------
Config.Carrier = {
    model = "p_door04x",
}
