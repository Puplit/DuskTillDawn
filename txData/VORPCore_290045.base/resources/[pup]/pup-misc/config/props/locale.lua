-- pup-misc/props | player-facing text
-- Every string a player sees from the wearable props and the /pa editor. %s is filled in by the code.

PropsLocale = {
    -- wearing
    prop_equipped     = "Prop equipped.",
    prop_removed      = "Prop removed.",
    prop_load_failed  = "Failed to load prop.",

    -- /pa picker
    picker_title      = "Adjust prop",
    no_props_worn     = "You are not wearing any props.",
    prop_not_on_you   = "That prop is not on you right now.",

    -- /pa editor overlay
    editing           = "Editing: %s",
    help_move         = "Arrows: move x/y  [ ]: move z  Shift+keys: rotate",
    help_keys         = "G: step  B: reset  Enter: save menu  Backspace: cancel",

    -- /pa save menu
    confirm_title     = "Prop position",
    option_save       = "Save position",
    option_resume     = "Keep editing",
    option_reset      = "Reset to default",
    option_cancel     = "Cancel (revert)",
    position_saved    = "Prop position saved.",
    position_reset    = "Prop position reset.",
}
