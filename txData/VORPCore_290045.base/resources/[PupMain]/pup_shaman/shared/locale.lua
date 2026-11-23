-- pup_shaman | player-facing text (both sides). %s / %d are filled in by L().

Locale = {
    -- curses
    cursed            = '%s has taken hold of you.',
    curse_left        = 'The curse has gone out of you.',
    cure_nothing      = 'There is nothing in you for this to cure.',
    course_effect     = 'The curse tightens its grip.',
    course_walk       = 'Your body grows weak.',
    course_drain      = 'The curse has begun to eat you away.',

    -- shifting
    shift_no_curse    = 'You do not carry the curse for that form.',
    shift_dead        = 'You cannot do that while dead.',
    shift_cooldown    = 'Your body is not ready to change again. (%d s)',
    shift_night       = 'That form only comes at night.',
    shift_busy        = 'You cannot change right now.',
    shifted           = 'You have become a %s (coat %d). Use /%s or hold %s to return.',
    shift_bloodmoon   = 'The blood moon swells you with rage.',
    shift_wears_off   = 'The change wears off.',
    prompt_return     = 'Return to your body',
    strike_spent      = 'You are spent. Strike again in %d s.',
    strike_none       = 'Nothing is close enough to strike.',
    struck            = 'Something tore into you!',

    -- trees
    tree_subtitle     = 'Ancient Tree',
    tree_eat          = 'Eat the fruit',
    tree_eat_desc     = 'Dream as one of the tree\'s spirit animals.',
    tree_give         = 'Give the fruit',
    tree_give_desc    = 'Let the person beside you dream.',
    tree_choose       = 'Choose the spirit',
    tree_nothing      = 'You eat, but nothing happens.',
    tree_no_one       = 'No one is close enough.',
    tree_cooldown     = 'The tree has nothing more for you yet. (%d min)',
    tree_busy         = 'They cannot dream right now.',
    dream_start       = 'You dream as the %s. Use /%s to wake.',
    dream_wake        = 'You wake beneath the tree.',
    dream_reward      = 'You wake holding %d %s.',

    -- rituals: titles
    rit_unbinding     = 'The Unbinding',
    rit_binding       = 'The Binding',
    rit_menu_title    = 'The Old Ways',
    rit_menu_sub      = '%s, %s',
    -- rituals: leading
    rit_no_rank       = 'You do not know the old ways.',
    rit_cannot_lead   = 'A %s can join a ritual, but not lead one.',
    rit_busy          = 'You cannot do that right now.',
    rit_rest          = 'Your spirit needs rest. (%d min)',
    rit_need_tree     = 'This must be done beside an ancient tree.',
    -- rituals: menu
    rit_opt_lift      = 'Lift a curse',
    rit_opt_lift_desc = 'Draw a curse out of someone beside you, if they agree. You can lift: %s.',
    rit_opt_give      = 'Give %s',
    rit_opt_give_desc = 'Bind %s to someone beside you who carries none, if they agree. Failing hurts you.',
    rit_needs         = 'Needs: %s.',
    rit_needs_item    = '%s %d of %d',
    rit_needs_none    = 'Needs no offering.',
    rit_pays          = 'They pay you $%d if it works.',
    -- rituals: choosing the person
    rit_beyond        = 'This curse is beyond your rank.',
    rit_no_help       = 'No one you can help is close enough.',
    rit_cannot_give   = 'Your rank cannot give a curse.',
    rit_has_curse     = 'They already carry a curse.',
    rit_no_receiver   = 'No one is close enough to receive it.',
    rit_need_item     = 'You need %d %s for the ritual.',
    rit_cannot_pay    = 'They cannot pay for the ritual.',
    -- rituals: asking
    rit_asking        = 'You ask %s to stand at the fire.',
    rit_ask_lift      = 'The %s %s offers to draw out your %s. Will you stand at the fire?',
    rit_ask_bind      = 'The %s %s offers to bind %s to you. It stays until someone lifts it. Will you stand at the fire?',
    rit_ask_cost      = ' It will cost you $%d if it works.',
    rit_accept        = 'Stand at the fire',
    rit_refuse        = 'Refuse',
    rit_refused       = '%s refuses the fire.',
    rit_no_answer     = '%s gave no answer.',
    -- rituals: stages
    rit_kindle_leader = 'Lay the fire and burn the offering.',
    rit_kindle_target = 'Stay close to the fire.',
    rit_circle        = 'Walk the circle, each mark in turn.',
    rit_mark          = 'Mark the ground',
    rit_join          = 'Join the circle',
    rit_circle_fail   = 'The circle was never closed. The fire dies.',
    rit_broken        = 'The ritual is broken.',
    rit_gone          = 'The curse has already gone.',
    -- rituals: verdict
    rit_lifted_leader = 'The curse lifts from %s.',
    rit_lifted_target = 'The curse goes out of you and down into the ground.',
    rit_eased_leader  = 'The curse loosens on %s, but it holds.',
    rit_eased_target  = 'The curse loosens its grip on you, but it holds.',
    rit_given_leader  = '%s takes hold of %s.',
    rit_given_target  = '%s takes hold of you. It stays until someone lifts it.',
    rit_failed_leader = 'The fire turns on you.',
    rit_failed_target = 'The fire gutters. Nothing has changed.',
}

--- Formats a locale entry; unknown keys come back as the key itself.
function L(key, ...)
    local text = Locale[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, text, ...)
        if ok then return out end
    end
    return text
end
