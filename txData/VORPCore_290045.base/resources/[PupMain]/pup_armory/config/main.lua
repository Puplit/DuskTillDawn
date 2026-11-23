-- pup_armory | main config (see README for every setting)

Config = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
Config.General = {
    debug       = false,   -- console + F8 traces (equips, saves, attaches)
    drawRange   = 80.0,    -- metres: other players' weapons are drawn within this range
    tickMs      = 100,     -- how often carried props are checked and re-hung (lower = snappier, costs more)
    editCommand = "wp",    -- opens the position editor for what you are carrying (radialmenu runs this one)
}

-------------------------------------------------------------------------------
-- KEYS  (the position editor). Change the hash only.
-------------------------------------------------------------------------------
Config.Keys = {
    up      = 0x6319DB71,   -- UP          forward (with SHIFT: tilt)
    down    = 0x05CA7C52,   -- DOWN        back (with SHIFT: tilt)
    left    = 0xA65EBAB4,   -- LEFT        left (with SHIFT: roll)
    right   = 0xDEB34313,   -- RIGHT       right (with SHIFT: roll)
    raise   = 0x430593AA,   -- [           up (with SHIFT: turn)
    lower   = 0xA5BDCD3C,   -- ]           down (with SHIFT: turn)
    rotate  = 0x8FFC75D6,   -- SHIFT       hold: the keys above rotate instead of move
    step    = 0x760A9C6F,   -- G           cycle fine / normal / coarse steps
    reset   = 0x4CC0E2FE,   -- B           back to the default position
    save    = 0xC7B5340A,   -- ENTER       save this position for your character
    cancel  = 0x156F7119,   -- BACKSPACE   leave without saving
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
Config.Integrations = {}

-------------------------------------------------------------------------------
-- BASE WEAPONS  (the game weapon a prop is swung as, picked by its kind)
-------------------------------------------------------------------------------
Config.BaseWeapons = {
    blade  = "weapon_melee_machete_collector",   -- swords, sabres, scythes
    knife  = "weapon_melee_knife_rustic",        -- knives, stakes, spears
    blunt  = "weapon_melee_hammer",              -- clubs, hammers, bats, pans, tools
}

-------------------------------------------------------------------------------
-- CARRY STYLES  (where a weapon hangs while put away - pick one with carry = '...')
-------------------------------------------------------------------------------
-- pos = { x, y, z, rx, ry, rz }: metres and degrees from the bone.
-- These are STARTING POINTS. Every prop is shaped differently: give yourself the item, use it,
-- run /wp, nudge it into place and (as staff) save it as the server default for everyone.
-- CP_ and PH_ bones are the game's own carry points, so 0 there means "where the game carries things".
Config.CarryStyles = {
    back      = { bone = "CP_BACK",      pos = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 } },         -- across the back
    spine     = { bone = "SKEL_Spine0",  pos = { 0.0, -0.18, 0.05, 0.0, 90.0, 0.0 } },     -- down the spine, handle up
    hip       = { bone = "PH_R_Hip",     pos = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 } },         -- at the right hip
    belt      = { bone = "SKEL_Spine0",  pos = { 0.12, -0.10, -0.15, 0.0, 0.0, -45.0 } },  -- small blade at the belt
    arm       = { bone = "CP_L_Forearm", pos = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 } },         -- shields: the left forearm
}

-------------------------------------------------------------------------------
-- HOLD STYLES  (how a weapon sits in the right hand - pick one with hold = '...')
-------------------------------------------------------------------------------
-- Starting points as well: staff fine-tune the hand position in /wp.
Config.HoldStyles = {
    blade = { 0.10, 0.02, -0.02, -90.0, 0.0, 0.0 },   -- swords and sabres
    knife = { 0.08, 0.02, -0.02, -90.0, 0.0, 0.0 },   -- short blades, stakes
    club  = { 0.10, 0.02, -0.02, -90.0, 0.0, 0.0 },   -- clubs, hammers, axes, tools
    long  = { 0.10, 0.00, -0.30, -90.0, 0.0, 0.0 },   -- long handles held low: shovels, rakes, staffs
}

-------------------------------------------------------------------------------
-- STAFF  (who may save a position as the server default from /wp)
-------------------------------------------------------------------------------
Config.Staff = {
    groups = { "admin" },              -- VORP user groups
    permission = "open_menu",          -- or anyone holding this vorp_admin permission (menu.open: all staff)
}

-------------------------------------------------------------------------------
-- RULES
-------------------------------------------------------------------------------
Config.Rules = {
    maxOffset = 1.5,   -- metres a saved position may sit from the bone
    playersEditHand = false, -- true: players may also move where they hold a weapon in /wp; staff always can
}
