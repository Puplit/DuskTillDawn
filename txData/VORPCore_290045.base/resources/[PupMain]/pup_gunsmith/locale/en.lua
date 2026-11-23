-- pup_gunsmith | English text
-- %s / %d placeholders are filled in by the code; keep them when translating.

Locale = {
    -- prompts and titles
    prompt_customize     = 'Customize Weapons',
    prompt_craft         = 'Craft Weapons',
    prompt_shop          = 'Weapons Shop',
    group_customize      = 'Weapon Customization - %s',
    group_craft          = 'Crafting',
    shop_title           = 'Weapons Shop',
    craft_form_title     = 'Weapon Crafting',
    box_name             = 'Weapon Crafting Box',

    -- shop
    shop_ammo_desc       = 'Price per box - pick how many you want',
    shop_bought_weapon   = 'You bought a %s.',
    shop_bought_ammo     = 'You bought %d x %s.',
    shop_not_sold        = "This counter doesn't stock that.",
    stand_counter        = 'Step up to the counter first.',
    confirm              = 'Buy it',
    cancel               = 'Leave it',
    amount               = 'How many?',

    -- shared refusals
    no_money             = "You can't afford that.",
    cant_carry_weapon    = 'You have no room for another weapon.',
    cant_carry_items     = 'You have no room for that many items.',
    invalid_amount       = "That isn't a usable amount.",

    -- crafting
    app_title            = 'GUNSMITH',
    app_subtitle         = 'WEAPON & AMMO CRAFTING',
    xp_level             = 'Experience Level : %d',
    xp_after             = 'Experience Level : %d (+%d)',
    section_weapons      = 'Weapons',
    section_ammo         = 'Ammo',
    section_storage      = 'Storage',
    section_search       = 'Search',
    tab_results          = 'Results',
    ammo_suffix          = ' Ammo',
    search_placeholder   = 'Weapon, ammo or material',
    filter_off           = 'Can make now',
    filter_on            = 'Show all',
    craft_button         = 'Craft',
    search_heading       = 'Search: %s',
    search_sub           = 'Weapons and ammo, every category.',
    search_matches       = 'Matches',
    search_none          = 'Nothing matches that.',
    box_heading          = 'Weapon Crafting Box',
    box_sub              = 'Collect everything you have crafted',
    box_row              = 'Open Weapon Crafting Box',
    box_open             = 'Open',
    no_job_craft         = "You don't have the job or rank to craft here.",
    no_job_bench         = "You don't have the job or rank to work this bench.",
    stand_station        = 'Stand at the crafting station.',
    no_materials         = "You're short on materials.",
    craft_failed         = 'The piece came out wrong. The craft failed.',
    craft_cant           = "That can't be crafted right now.",
    craft_success        = 'Crafted!',
    craft_into_box       = 'Your crafting went into the crafting box.',
    custom_serial        = 'Custom serial',
    custom_label         = 'Custom label',
    custom_desc          = 'Custom description',

    -- ammo boxes
    belt_full            = 'Your belt is full for that ammo.',
    box_unusable         = "That box can't be opened right now.",

    -- bench
    stand_bench          = 'Stand at the bench.',
    not_carrying         = "You aren't carrying that weapon.",
    part_doesnt_fit      = "That part doesn't fit this weapon.",
    preset_need_name     = 'Give the preset a name.',
    preset_need_parts    = 'Fit at least one part before saving a preset.',
    preset_limit         = 'You can keep %d presets. Delete one first.',
    repaired_fee         = 'Weapon repaired for $%s.',
    repaired             = 'Weapon repaired.',
    repair_failed        = 'Could not repair that weapon.',
    tier_max             = 'This weapon is already at the maximum tier.',
    tier_needs           = 'Tier %d also needs: %s',
    tier_done            = 'Weapon upgraded to Tier %d - condition wears %d%% slower.',
    tier_failed          = 'Could not upgrade that weapon.',

    -- admin commands
    cmd_usage            = 'Usage: /weaponcraftloc <name> [job1,job2,...]',
    cmd_ingame           = 'Run this in game - it saves your current position.',
    cmd_saved            = "Station '%s' saved here. It is live now - no restart.",
    cmd_failed           = 'Could not save it: %s',
    cmd_off              = 'Station %s switched off.',
    cmd_on               = 'Station %s switched on.',
    cmd_unknown          = 'No station is called %s.',
    cmd_usage_toggle     = 'Usage: /%s <name>',

    -- unused today, kept so translations have a home for them
    yes = 'Yes', no = 'No', remove = 'Remove', total = 'Total', cost = 'Cost',
    count = 'Count', price = 'Price', label = 'Label', weapons = 'Weapons',
}

---@param key string
---@return string
function L(key, ...)
    local s = Locale[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end

-- the bench page's own wording (sent to the page with every open)
BenchText = {
    pickTitle     = 'Gunsmith',
    pickSub       = 'Lay a weapon on the bench',
    pickAction    = 'Set on bench',
    pickFooter    = '↑↓ to look · Enter to lay it down · Esc to leave',
    pickEmpty     = "You aren't carrying a weapon. Equip the one you want worked on, then come back to the bench.",
    serialShort   = 'No. %s',
    serialLong    = 'Serial No. %s',
    partsFitted   = '%d part(s) fitted',
    factoryFit    = 'Factory fit',
    sheetKicker   = 'Gunsmith · %s',
    tabs          = { parts = 'Parts', finish = 'Finish', engraving = 'Engraving', tints = 'Tints', presets = 'Presets', workshop = 'Workshop' },
    none          = 'None',
    currentPart   = 'Current part',
    fittedNow     = 'Fitted now',
    free          = 'Free',
    removeTag     = 'Remove',
    ofCount       = ' · %d of %d',
    toChoose      = ' · %d to choose from',
    nothingHere   = 'Nothing to fit here.',
    changes       = '%d change(s)',
    noChanges     = 'No changes',
    wallet        = 'You carry %s',
    undoAll       = 'Undo all',
    fitParts      = 'Fit parts',
    payAndFit     = 'Pay and fit',
    receiptKicker = "Gunsmith's Receipt",
    removed       = 'Removed',
    total         = 'Total',
    notYet        = 'Not yet',
    working       = 'Fitting the parts...',
    repairing     = 'Repairing weapon...',
    upgrading     = 'Upgrading weapon...',
    workDone      = 'The work is done.',
    workDonePaid  = 'The work is done. Paid %s.',
    spawnFailed   = "The gun couldn't be set on the bench.",
    presetSaveRow = 'Save this look as a preset',
    presetParts   = '%d part(s)',
    presetName    = 'Name this look',
    presetHolder  = 'e.g. Gold Cattleman',
    presetHint    = 'Enter to save · Esc to cancel · the same name replaces it',
    presetHeading = 'Your presets for this gun',
    presetEmpty   = 'None yet. Set up a gun the way you like it, then save the look here. Next time, one press puts the whole look on.',
    presetApply   = 'Apply',
    presetOnBench = 'On the bench',
    presetArmed   = 'Press Delete again',
    presetFitted  = ' · already fitted',
    presetCosts   = ' · fitting costs %s',
    presetLaid    = 'Preset laid out. Check the bill, then fit the parts.',
    presetSaved   = 'Preset "%s" saved.',
    presetUpdated = 'Preset "%s" updated.',
    wearOff       = 'Weapon condition is switched off on this server, so there is nothing to repair and tier upgrades would change nothing. The server owner can turn it on in vorp_inventory.',
    noWear        = "This weapon doesn't wear, so it never needs repairing.",
    condition     = 'Condition',
    gauges        = { degradation = 'Wear', damage = 'Damage', dirt = 'Dirt', soot = 'Soot' },
    repairRow     = 'Repair to like-new',
    tierHeading   = 'Tier',
    temperRow     = 'Temper to Tier %d',
    wearsSlower   = 'Wears %d%% slower at Tier %d.',
    fullyTempered = 'This weapon is fully tempered.',
    materials     = 'Materials',
    keys = {
        { 'A / D', 'Turn' }, { 'W / S', 'Raise / lower view' }, { 'Q / E', 'Roll' },
        { 'Scroll', 'Zoom' }, { 'Drag', 'Turn & tilt' }, { 'R', 'Reset view' },
        { '↑ / ↓', 'Part' }, { '← / →', 'Change' }, { 'Tab', 'Section' }, { 'Esc', 'Put away' },
    },
}
