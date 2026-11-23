-- pup-misc/gestures | main settings (see README)

GesturesConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
GesturesConfig.General = {
    handsUpCommand = 'handsupkey',   -- toggles hands up
    pointCommand   = 'point',        -- toggles pointing
}

-- default keys for a new player (key names, not hashes)
GesturesConfig.Keys = {
    handsUp = 'X',
    point   = 'L',
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
GesturesConfig.Integrations = {}

-------------------------------------------------------------------------------
-- HANDS UP
-------------------------------------------------------------------------------
GesturesConfig.HandsUp = {
    anim = {
        dict  = 'script_proc@robberies@shop@rhodes@gunsmith@inside_upstairs',
        name  = 'handsup_register_owner',
        flag  = 31,
        blend = 2.0,
    },
    holsterWeapon = true,   -- force WEAPON_UNARMED when the hands go up
    blockFiring   = true,   -- keep firing and melee blocked the whole time
}

-------------------------------------------------------------------------------
-- POINT
-------------------------------------------------------------------------------
GesturesConfig.Point = {
    anim = {
        dict  = 'script_common@other@unapproved',
        name  = 'loop_0',
        flag  = 30,
        blend = 1.0,
    },
}
