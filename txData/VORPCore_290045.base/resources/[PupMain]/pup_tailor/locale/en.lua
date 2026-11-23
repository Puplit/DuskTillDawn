-- pup_tailor | English text. Shared. Placeholders are string.format style.
Locale = {
    -- prompt
    promptText = 'Menu',
    promptGroup = 'Tailor',

    -- player tips
    browsingOnly = 'You can browse here. Note each piece\'s number and hand the list to a tailor.',
    onlyTailorMake = 'Only a tailor can make this. Write the numbers down and ask one.',
    onlyTailorDye = 'Only a tailor can dye this. Note the palette and colour numbers and ask one.',
    noAnswer = 'The shop did not answer. Try again.',
    bookFailed = 'The dye book would not open. Try again.',
    cantChangeNow = 'You cannot change clothes right now.',
    madeForMales = 'This was cut for men and will not fit you.',
    madeForFemales = 'This was cut for women and will not fit you.',
    amountWhole = 'The amount must be a whole number, 1 or more.',
    amountMax = 'You can make at most %d at a time.',
    nothingPicked = 'Pick at least one garment first.',
    pickSpFirst = 'Move a slider onto a singleplayer garment first.',
    lostAccess = 'You no longer work at this bench.',

    -- server notifications
    needBench = 'You need to be at your tailor\'s bench.',
    onlyTailor = 'Only a tailor can make this.',
    nothingToCopy = 'You are not wearing anything to copy.',
    cannotCopy = 'Something you are wearing is not sold here and cannot be copied.',
    notEnoughMoney = 'You do not have enough money ($%s).',
    notEnoughMaterials = 'You do not have enough materials',
    forAmount = ' for x%d',
    invalidSelection = 'That clothing selection is not valid.',
    cantCarry = 'You cannot carry any more.',
    clothingCreated = 'Clothing made.',
    alreadyHidden = 'That one is already hidden.',
    hiddenForAll = 'Hidden from the tailor for everyone.',
    hiddenPrinted = '%d hidden garment(s) printed to the server console.',

    -- dye book messages
    alreadyDyed = 'This outfit has already been dyed and cannot be recoloured.',
    nothingDyed = 'Nothing was dyed: no valid colour changes.',
    shortMaterials = 'You are short on materials: %s',
    shortMaterialsPlain = 'You are short on materials.',
    cantCarryDye = 'Your satchel is full. Make room and save again.',
    colourFirst = 'Colour at least one garment first.',
    dyed = 'Clothing dyed. Garments recoloured: %d',

    -- menus
    menuTitle = 'Tailor Menu',
    createItem = 'Create Clothing Item',
    createItemDesc = 'Make a copy of the clothes you are wearing. Price: $%s plus the garments\' cost and materials',
    tailor = 'Tailor',
    tailorDesc = 'Design an outfit on the mannequin',
    customize = 'Customize Color',
    customizeDesc = 'Recolour an outfit you carry',
    male = 'Male',
    maleDesc = 'Design an outfit for a man',
    female = 'Female',
    femaleDesc = 'Design an outfit for a woman',
    finish = 'Finish outfit',
    finishDesc = 'Go to the bill. You cannot come back to edit after confirming.',
    finishNone = 'No garments picked yet.',
    none = 'None',
    showroomHint = 'Q/E turn, SHIFT/CTRL zoom, SPACE/ALT height, X reset, ENTER type a number',
    hideGarment = 'Hide this garment (staff)',
    hideGarmentDesc = 'Removes the previewed singleplayer garment from every tailor menu',
    price = 'Price: $%s',
    priceDesc = 'Cash for one copy',
    perCopy = 'Per copy',
    keepMask = 'Keep Mask & Neckwear : %s',
    on = 'ON',
    off = 'OFF',
    keepMaskDesc = 'ON: whoever wears this keeps the mask and neckwear they have on. OFF: the outfit replaces them.',
    confirm = 'Press ENTER To Confirm',
    confirmDesc = 'Pay and make the item. You cannot go back to editing after this.',
    description = 'Description',
    displayedDescription = 'Displayed Description',
    howMany = 'How many?',
    goToNumber = 'Go to number',
    number = 'Number',
    confirmTitle = 'Confirm',
    submit = 'Confirm',
    changing = 'Changing...',

    -- dye book page
    bookTitle = 'Dye Book',
    bookEmpty = 'You are not carrying anything to dye.',
    bookBack = '\u{2190} Outfits',
    bookPaletteName = 'Name this palette',
    bookNameBtn = 'Name',
    bookCopy = 'Copy',
    bookPaste = 'Paste',
    bookUndye = 'Undye this',
    bookBefore = 'Hold: before',
    bookSave = 'Save and dye',
    bookCost = 'Cost: %s',
    bookFree = 'Free',
    bookPalette = 'Palette %d',
    bookKeys = 'Q/E turn \u{00B7} SHIFT/CTRL zoom \u{00B7} SPACE/ALT height \u{00B7} X reset \u{00B7} W/S garment',
    bookPick = 'Pick an outfit to recolour',
    channels = { 'Primary', 'Secondary', 'Trim' },
}

function L(key, ...)
    local s = Locale[key]
    if s == nil then return key end
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
