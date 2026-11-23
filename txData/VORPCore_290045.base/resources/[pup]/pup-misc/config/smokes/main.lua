-- pup-misc/smokes | main settings (see README)

SmokesConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
SmokesConfig.General = {}

-- prompt keys while smoking
SmokesConfig.Keys = {
    putAway = 0x3B24C470,   -- F            put away / finish
    use     = 0x07B8BEAF,   -- LEFT MOUSE   inhale / use
    stance  = 0xD51B784F,   -- E            pose / change stance
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
SmokesConfig.Integrations = {}

-------------------------------------------------------------------------------
-- PIPE  (needed for a smoke marked "pipe"; not used up)
-------------------------------------------------------------------------------
SmokesConfig.Pipe = {
    item = "pipe",
}
