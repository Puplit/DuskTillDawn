-- English wording. Every player-facing line lives here.
Locale = {
    -- prompt and labels
    prompt_craft        = 'Craft',
    panel_title         = 'Crafting',
    bench_prop          = 'Workbench',
    bench_kit           = 'Crafting Kit',

    -- tabs
    tab_favourites      = 'Favourites',
    tab_pending         = 'Pending',
    tab_box             = 'Crafting Box',
    tab_search          = 'Search',

    -- page text
    favs_heading        = 'Favourites',
    favs_sub            = 'The recipes you starred',
    stat_xp             = 'Experience',
    stat_level          = 'Level',
    stat_recipes        = 'Recipes',
    stat_favs           = 'Favourites',
    level_fmt           = 'LV %d / %d',
    search_placeholder  = 'Recipe or item name...',
    search_heading      = 'Search: %s',
    search_sub          = 'Every category at this bench',
    search_clear        = 'Clear search',
    search_none         = 'Nothing matches that.',
    empty_category      = 'Nothing to craft here yet.',
    empty_favs          = 'No favourites yet. Star a recipe to keep it here.',
    pick_recipe         = 'Pick a recipe on the left to see what it needs.',
    chip_canmake        = 'Can make now',
    chip_automax        = 'Auto max',
    chip_remember       = 'Remember amount',
    locked              = 'Locked',
    needs_grade         = 'Needs grade %d',
    needs_xp            = 'Needs %d experience',
    tag_xp              = '+%d XP',
    tag_each            = '%s each',
    needs_heading       = 'Needs',
    tool_kept           = 'tool, kept',
    amount              = 'Amount',
    amount_can          = 'Amount (you can make %d)',
    craft               = 'Craft',
    favourite           = 'Favourite',
    unfavourite         = 'Unfavourite',
    craft_desc          = 'Craft with a description',
    desc_field          = 'Description',
    desc_hint           = 'Written on what you make',
    desc_recent         = 'Recent descriptions',
    desc_pick           = 'Pick a recent one',
    craft_confirm       = 'Craft',
    pending_heading     = 'Pending',
    pending_sub         = 'Crafts in progress. Collect them here when they are done.',
    pending_none        = 'Nothing in progress.',
    fetching            = 'Fetching...',
    ready               = 'Ready',
    time_left           = '%s left',
    collect             = 'Collect',
    collect_all         = 'Collect all',
    box_heading         = 'Crafting Box',
    box_sub             = 'Finished goods wait here so a long run never fills your satchel. Emptied on server restart.',
    box_open            = 'Open the crafting box',

    -- results
    cannot_here         = 'You cannot craft that here.',
    cannot_craft        = 'You cannot craft that.',
    recipe_gone         = 'That recipe is gone.',
    no_materials        = 'You do not have the materials.',
    need_tool           = 'You need a %s for this.',
    too_many_running    = 'You already have %d crafts on the go.',
    not_amount          = 'That is not an amount.',
    banned_words        = 'You cannot use those words.',
    fumbled             = 'You fumbled it.',
    started             = 'Started. Ready in %s.',
    crafted             = 'Crafted.',
    crafted_box         = 'Crafted into your crafting box.',
    double_yield        = 'Craftsman, double yield!',
    cannot_carry        = 'You cannot carry that.',
    collected           = 'Collected %s.',
    collected_n         = 'Collected %d crafts.',
    still_making        = 'That is still being made.',
    craft_gone          = 'That craft is no longer there.',
    nothing_ready       = 'Nothing is ready yet.',
    kept_pending        = 'Your satchel is full, so it waits on the Pending shelf.',
    condition_prefix    = 'Condition = ',
    tool_broke          = 'Your %s broke.',
    crafting_progress   = 'Crafting...',
    busy                = 'Finish what you are doing first.',
    slow_down           = 'Slow down a little.',
    not_ready           = 'The bench is not ready yet, try again in a moment.',

    -- box
    box_name            = 'Crafting Box',
    box_at_station      = 'Your crafting box is waiting at %s.',
    box_far             = 'Your crafting box is waiting %d m away, where you filled it.',
    box_holds_elsewhere = 'Your crafting box already holds goods from %s. Empty it there first.',
    box_elsewhere_far   = 'a spot %d m away',

    -- placeables
    placing             = 'Setting up...',
    already_placed      = 'You already have one set up. Use /%s to pick it up.',
    no_town             = 'You cannot set that up in town.',
    picked_up           = 'Picked it back up.',
    empty_box_first     = 'Empty your crafting box first, %d items still inside.',
    nothing_placed      = 'You have nothing set up.',
    place_failed        = 'You could not set that up.',

    -- staff
    station_saved       = "Saved station '%s' here.",
    station_failed      = 'Could not save, see the console.',
    craftloc_usage      = 'Usage: /craftloc <name>',
    craftloc_console    = 'craftloc needs a position, use it in game.',
}

--- Look up a line and fill it in. Unknown keys come back as the key itself.
function L(key, ...)
    local s = Locale[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
