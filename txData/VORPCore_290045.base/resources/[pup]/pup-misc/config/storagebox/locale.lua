-- storagebox | player text. %s / %d placeholders must stay in the same order.

StorageBoxLocale = {
    -- deposits and storing
    boxEmptyHere      = 'This storage box is empty. Close the storage you have open, then use the box to open it.',
    deposited         = 'Your storage box was emptied into the storage.',
    noRoom            = 'That storage does not have room for everything.',
    boxFull           = 'The storage box is full.',
    boxShort          = 'There is not enough room left in this box.',
    boxInBox          = 'A box cannot go inside another box.',
    typeNotAllowed    = 'Storage boxes do not work with this kind of storage.',
    -- the world
    placed            = 'You set the storage box down.',
    pickedUp          = 'You lift the storage box.',
    wall              = 'There is a wall in the way, so the box goes down closer to you.',
    noWagon           = 'You cannot climb onto a wagon with a box in your arms.',
    -- limits
    alreadyHave       = 'You are already using a %s. Empty it first.',
    tooMany           = 'You cannot carry more boxes (%d/%d).',
    -- transfers
    notFound          = 'That storage box could not be found.',
    sourceGone        = 'That item could not be taken out of the storage.',
    initFailed        = 'The storage box could not be set up.',
    transferred       = 'Moved %dx %s into the storage box.',
    usedBoxAtShop     = 'A storage box that is in use cannot be put up for sale.',
    -- packs
    wrongJob          = 'You do not know how to pack this properly.',
    notForPack        = 'That does not belong in this pack.',
    unloaded          = 'Unloaded %d item(s) from your pack.',
    nothingFits       = 'Nothing in the pack fits in there.',
    packEmpty         = 'The pack is empty.',
    leftInPack        = '%d did not fit and stay in your pack.',
    emptyPackStored   = 'Empty pack stored. Use it again to start packing.',
    packAtShop        = 'Shops do not take packs. Unload it at your storage or wagon.',
    filterSaved       = 'Pack filter saved.',
    -- prompts and dialogs
    promptGroup       = 'Storage Box',
    promptPutDown     = 'Put Down Box',
    promptOpen        = 'Open',
    promptPickUp      = 'Pick Up',
    filterSubtitle    = 'Ticked materials go into the pack while you work',
    filterAll         = 'Tick everything',
    filterSave        = 'Save',
    filterNote        = 'Unticked materials go to your pockets instead',
}
