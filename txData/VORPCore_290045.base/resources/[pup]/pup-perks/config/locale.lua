-- pup-perks | config/locale.lua
-- Every player-facing message. %s / %d are filled in by the code: keep them, in order.

Locale = {
    -- general
    perksTitle            = 'Perks',                       -- default toast title
    loadFailed            = 'Unable to load perks.',       -- the panel could not be fetched
    treeTitle             = '%s: %s',                      -- toast title: side label, tree label

    -- level up (VORP right-hand tip)
    levelUpPoints         = '%s Level %d - %d perk point%s',
    levelUp               = '%s Level %d',

    -- why a card cannot be bought (shown on the card in the panel)
    blockedNeedsPerk      = 'Needs %s at rank %d',
    blockedCommitted      = 'You committed to %s on your %s side',
    blockedChooseTree     = 'Choose %s as your %s tree first',
    blockedLevel          = 'Requires %s level %d',
    blockedPoints         = 'Requires %d %s point%s',

    -- buying a rank
    maxedTitle            = 'Maxed',
    maxed                 = '%s is already at its highest rank.',
    differentTreeTitle    = 'Different tree',
    committedTo           = 'You committed to %s on your %s side.',
    chooseTreeFirst       = 'Choose a %s tree first.',
    lockedTitle           = 'Locked',
    lockedPrereq          = '%s. %s',
    rankNeedsLevel        = '%s rank %d needs %s level %d.',
    notEnoughPointsTitle  = 'Not enough points',
    rankCosts             = 'Rank %d costs %d %s point%s.',
    perkUnlocked          = 'Perk unlocked.',
    upgradedTo            = 'Upgraded to rank %d.',

    -- equipping (only when Config.Cards.autoEquip = false)
    autoEquipOn           = 'Every perk you unlock is active automatically.',
    notUnlocked           = 'You have not unlocked %s.',
    unequipped            = 'Unequipped.',
    noSlotKind            = 'There is no slot for that kind of card.',
    specialTakenTitle     = 'Signature card taken',
    specialTaken          = 'You may carry one special card. Unequip it to use this one.',
    noFreeSlotTitle       = 'No free slot',
    noFreeSlot            = 'All %d passive slots are full. Unequip a card to make room.',
    equipped              = 'Equipped.',

    -- full (paid) reset
    unavailableTitle      = 'Unavailable',
    resetsDisabled        = 'Perk resets are disabled.',
    nothingToResetTitle   = 'Nothing to reset',
    nothingSpentOrChosen  = 'You have not spent any points or chosen a tree.',
    cannotAffordTitle     = 'Cannot afford',
    resetCosts            = 'A reset costs $%d.',
    resetDoneTitle        = 'Perks reset',
    resetDone             = '%d honest work and %d outlaw point%s returned. Both trees are open again.',

    -- choosing / switching a tree
    alwaysOpenTitle       = 'Always open',
    alwaysOpen            = '%s needs no commitment.',
    alreadyCommittedTitle = 'Already committed',
    alreadyCommitted      = 'Your %s tree is %s. Reset your perks to choose again.',
    treeCommitted         = 'You committed to the %s tree. A reset is the only way to change it.',
    specialistChosen      = 'Specialist chosen.',
    alreadySpecialistTitle = 'Already your specialist',
    alreadySpecialist     = 'You are already a %s.',
    specialistChanged     = 'Specialist changed. %d invested point%s cleared. Your %s level is untouched.',

    -- free weekly reset
    notYetTitle           = 'Not yet',
    nextFreeReset         = 'Your next free reset is in %dd %dh.',
    nothingSpent          = 'You have not spent any perk points.',
    weeklyResetDone       = '%d point%s returned. Your specialists and levels are unchanged.',

    -- admin actions (vorp_admin Perks page), shown to the affected player
    adminPointsTitle      = 'Perk Points',
    adminGrantedPoints    = 'An admin granted you %d %s point%s.',
    adminRemovedPoints    = 'An admin removed %d %s point%s.',
    adminXpTitle          = 'Experience',
    adminGrantedXp        = 'An admin granted you %d %s experience.',
    adminRemovedXp        = 'An admin removed %d %s experience.',
    xpNameCiv             = 'honest work',                 -- fills the %s in the two xp lines above
    xpNameCrime           = 'outlaw',
    adminWipedTitle       = 'Perks wiped',
    adminWiped            = 'An admin reset your perks. All experience, levels and points are back to zero.',
}
