-- pup_mortician | every player-facing line. %s / %d placeholders are filled by L().

Lang = {
    -- prompts, blips, progress bars
    promptUse = 'Use',
    ledgerTitle = "Undertaker's Ledger",
    buryCasket = 'Lower the casket',
    buryBody = 'Put this one in the ground',
    burialSite = 'Burial Site',
    shovelGroup = 'Shovel',
    dig = 'Dig',
    putAway = 'Put away',
    progBury = 'BURYING...',
    progPrep = 'PREPARING...',
    progDig = 'DIGGING...',

    -- ledger tabs
    tabTable = 'Table',
    tabBoard = 'Board',
    tabRegister = 'Register',
    tabBusiness = 'Business',

    -- table tab
    buriesLeft = '%d of %d burials left today',
    noBuriesUntil = 'no burials left - more from %s',
    emptyCarrying = 'Set down the one you are carrying on the table.',
    emptyHint = 'The table stands bare. Bring the departed here.',
    btnLayDown = 'Lay the body down',
    unknownSoul = 'an unknown soul',
    subOpen = 'what goes in with them',
    subClosed = 'sealed and ready - take it to the burial site',
    tagMine = 'yours',
    tagOther = "another undertaker's",
    laidIn = 'laid in',
    bonus = '+$%d',
    btnLayIn = 'Lay in what I carry',
    btnClose = 'Close the casket',
    btnCarry = 'Carry the casket',
    warnEarly = 'Closing it now sends them off without the rest - the pay is smaller.',

    -- board tab
    boardHeading = 'Board',
    boardSub = 'the departed waiting to be brought in',
    boardEmpty = 'Nobody is waiting to be collected right now.',
    bodies = '%d bodies',
    timeLeft = '%d:%02d left',
    taken = 'taken',
    btnTake = 'Take it',
    btnGiveUp = 'Give it up',
    blipCollect = 'Collect the dead',
    foundThem = 'You found them. Bring them back to the table.',
    carryToSite = 'Carry it to the burial site marked on your map.',

    -- register tab
    registerHeading = 'Register',
    registerSub = 'everyone this house has laid to rest',
    registerEmpty = 'No burials written down yet.',
    colWhen = 'When', colDeceased = 'Deceased', colCause = 'Cause', colUndertaker = 'Undertaker',
    colPaid = 'Paid', colWhere = 'Where', colBurials = 'Burials', colHouse = 'House',

    -- business tab
    businessHeading = 'Business',
    businessSub = 'what the house keeps, and where the reports go',
    statCut = 'house cut',
    statReports = 'burial reports',
    on = 'on', off = 'off',
    btnSetCut = 'Set the house cut',
    btnWebhook = 'Burial reports webhook',
    last7 = 'the last 7 days',
    cutTitle = 'House cut',
    cutSub = 'The share the business keeps from each burial its people do (0 to %d).',
    cutField = 'Percent',
    hookTitle = 'Burial reports',
    hookSub = 'A Discord webhook. Leave it empty to stop the reports.',
    hookField = 'Webhook URL',
    hookPlaceholder = 'https://discord.com/api/webhooks/...',
    save = 'Save',

    -- results
    notUndertaker = 'That is undertaker work.',
    notYourTable = 'This is not your table.',
    tooFar = 'You are too far away.',
    tableBusy = 'Someone already lies on this table.',
    noBurialsLeft = 'You have no burials left for now.',
    notCarrying = 'You are not carrying a body.',
    contractOnly = 'This table only takes the dead from your contract.',
    laidOnTable = 'You lay them on the table.',
    noOpenCasket = 'There is no open casket here.',
    notYoursTend = 'That casket is not yours to tend.',
    missingGoods = 'You do not have: %s',
    nothingLeft = 'Nothing is left to lay in.',
    goodsLaid = 'Laid in: %s',
    casketClosed = 'The lid is shut.',
    noClosedCasket = 'There is no sealed casket to bury.',
    notYoursBury = 'That casket belongs to someone else.',
    needShovel = 'You need a shovel.',
    laidToRest = '%s is laid to rest. You were paid $%d.',
    toHouse = ' ($%d to the house)',
    keepsake = ' The family left you %s x%d.',
    onlyOwner = 'Only the owner can change that.',
    cutSet = 'House cut set to %d%%.',
    notWebhook = 'That is not a Discord webhook URL.',
    reportsOn = 'Burial reports will go to your channel.',
    reportsOff = 'Burial reports are switched off.',
    busy = 'Finish what you are doing first.',

    -- contracts
    alreadyContract = 'You already hold a contract.',
    postingGone = 'That posting is gone.',
    tookContract = 'You took the contract for %s.',
    gaveUp = 'You gave the contract up.',
    noPlace = 'Nobody can say where they lie. Give this one up and take another.',
    contractsOff = 'The board is closed.',

    -- digging
    cannotDigNow = 'You cannot dig right now.',
    panning = 'You are panning for gold.',
    noDigTown = 'You cannot dig in town.',
    dugRecently = 'Someone has dug here recently.',
    tooSoon = 'You stopped digging too soon.',
    wandered = 'You wandered off from the hole.',
    nothingDown = 'Nothing down there.',
    dugMoney = 'You dug up $%d.',
    dugItem = 'You dug up %dx %s.',
    cannotCarryFind = 'You found something but cannot carry it.',
    shovelSnapped = 'Your shovel snapped.',
    durability = 'Durability: %d / %d',
}

-- format a line; unknown keys come back as the key so nothing silently vanishes
function L(key, ...)
    local s = Lang[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
