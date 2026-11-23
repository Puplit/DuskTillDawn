-- pup-misc/props | main settings (see README)

PropsConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
PropsConfig.General = {
    command             = "pa",
    startupDelaySeconds = 120,    -- seconds
}

-- /pa editor keys
PropsConfig.Keys = {
    up       = 0x6319DB71,   -- Arrow Up: move +y (with rotate held: +ry)
    down     = 0x05CA7C52,   -- Arrow Down: move -y (with rotate held: -ry)
    left     = 0xA65EBAB4,   -- Arrow Left: move -x (with rotate held: -rx)
    right    = 0xDEB34313,   -- Arrow Right: move +x (with rotate held: +rx)
    raise    = 0x430593AA,   -- [ : move +z (with rotate held: -rz)
    lower    = 0xA5BDCD3C,   -- ] : move -z (with rotate held: +rz)
    rotate   = 0x8FFC75D6,   -- Shift: hold to rotate instead of move
    reset    = 0x4CC0E2FE,   -- B: back to the position the edit started from
    stepSize = 0x760A9C6F,   -- G: cycle the step size
    save     = 0xC7B5340A,   -- Enter: open the save menu
    cancel   = 0x156F7119,   -- Backspace: cancel and revert
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
PropsConfig.Integrations = {}

-------------------------------------------------------------------------------
-- EDITOR
-------------------------------------------------------------------------------
PropsConfig.Editor = {
    moveRepeatMs = 70,    -- ms
    moveDelayMs  = 250,   -- ms
}
