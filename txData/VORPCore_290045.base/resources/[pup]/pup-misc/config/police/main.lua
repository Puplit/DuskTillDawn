-- pup-misc/police | main settings (see README)

PoliceConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
PoliceConfig.General = {
    -- chat commands (/mmenu is always an alias of the menu)
    commands = {
        menu        = 'lawmenu',
        badge       = 'badge',         -- pin on / take off the badge
        adjustBadge = 'adjustbadge',   -- the badge editor
    },
}

-- keys; remove hotkeyModifier, or both cuff and escort, to turn the hotkeys off
PoliceConfig.Keys = {
    -- hold the modifier, tap the key
    hotkeyModifier = 0x8AAA0AD4,   -- ALT
    cuff           = 0xE30CD707,   -- R   cuff / uncuff the nearest player
    escort         = 0x760A9C6F,   -- G   escort (drag) the nearest cuffed player

    -- badge editor (/adjustbadge)
    editorMode     = 0x8F9F9E58,   -- 4          MOVE / ROTATE / BONE
    editorLeft     = 0xA65EBAB4,   -- LEFT
    editorRight    = 0xDEB34313,   -- RIGHT
    editorUp       = 0x6319DB71,   -- UP
    editorDown     = 0x05CA7C52,   -- DOWN
    editorRaise    = 0xE6F612E4,   -- 1          height / roll
    editorLower    = 0x1CE6D9EB,   -- 2
    editorFine     = 0x8FFC75D6,   -- SHIFT      hold for finer steps
    editorReset    = 0x4CC0E2FE,   -- B          back to Badges.default
    editorSave     = 0x760A9C6F,   -- G
    editorCancel   = 0x156F7119,   -- BACKSPACE
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
PoliceConfig.Integrations = {}

-------------------------------------------------------------------------------
-- JOBS
-------------------------------------------------------------------------------
PoliceConfig.Jobs = {
    law = {   -- law jobs (while on duty in pup-mdt)
        'police',
        'marshal',
    },
}

-------------------------------------------------------------------------------
-- RESTRAINT
-------------------------------------------------------------------------------
PoliceConfig.Restraint = {
    interactDistance = 2.0,   -- metres
}

-- ESCORT
PoliceConfig.Escort = {
    sideMetres    = 0.38,     -- metres to the right
    forwardMetres = 0.18,     -- metres ahead (negative = behind)
    -- the lawman's upper-body hold animation; holdAnim = false turns it off
    holdAnim = {
        dict = 'mech_loco_m@generic@injured@unarmed@right_arm@idle',
        name = 'idle',
    },
}
