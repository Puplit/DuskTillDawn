-- search | player-facing text, read on both sides.
-- Strings with %s / %d are format strings; keep the placeholders in order.

SearchLocale = {
    -- prompt
    prompt = 'Search',
    promptGroup = 'Search',

    -- menu
    menuTitle = 'Search Menu',
    menuSubtitle = 'Search Person',
    cashLabel = 'Cash: $%s',
    cashDesc = 'Take Cash',
    inventoryLabel = 'Inventory',
    inventoryDesc = 'Search Inventory',
    amountTitle = 'Amount',
    amountField = 'Amount',
    amountPlaceholder = '0',
    amountTooSmall = 'Enter at least $1',

    -- steal panel
    panelTitle = 'Inventory',

    -- results
    cashGot = 'You Got $%s',
    cashLost = 'You Lost $%s',
    itemGot = 'You got an Item: %dx %s',
    itemLost = 'Item was taken from you: %dx %s',
    weaponGot = 'You got a weapon: %s',
    weaponLost = 'Weapon was taken from you: %s',

    -- refusals
    beingSearched = 'Being Searched By Someone',
    targetBusy = 'Target is busy!',
    cantSearchJob = 'Cant Search This Job',
    newPlayer = 'You Cant Rob New Players, You Cant Rob As a New player, make sure you read the rules!',
    cantCarry = 'Cant Carry Any More Items',
    cantWeapons = 'You cant steal weapons',
    blacklisted = 'You Cant Take This Item',
    limitReached = 'You reached the item limit for this robbery',
    stealFailed = 'Failed to steal item',
    carryFailed = 'Failed to carry item',
    cantGive = 'You cannot put things into their satchel',

    -- server console
    purgeOn = 'purge rules ON: nothing is protected',
    purgeOff = 'purge rules OFF: normal search rules',
}
