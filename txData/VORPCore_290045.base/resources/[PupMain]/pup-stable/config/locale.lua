-- pup-stable | every player-facing text (shared). %s / %d are filled in by the code.

Locale = {
    -- prompts and buttons
    stable = 'Stable', back = 'Back', enter = 'Enter', select = 'Select', unselect = 'Unselect', buy = 'Buy',
    rotate = 'Rotate', buyWith = 'Buy with gold', favourite = 'Mark as favourite', manage = 'Manage', unequip = 'Unequip',
    equip = 'Equip', transfer = 'Transfer', release = 'Release', retrieve = 'Retrieve', stableHorse = 'Stable this horse',
    stopLeading = 'Stop leading', openSaddlebag = 'Open Saddlebag', takeSaddlebag = 'Take saddlebag', putSaddlebag = 'Put saddlebag',
    colorPalette = 'Colour palette', delete = 'Delete', checkShoes = 'Check horseshoes', stableWagon = 'Stable this wagon',
    revive = 'Revive', reviveGold = 'Revive with gold', brush = 'Brush', feed = 'Feed', openStorage = 'Open Storage',
    outfitter = 'Outfitter', outfitterDesc = 'Pitch, pack up or throw out your camp kit', skip = 'Skip', takeLantern = 'Take lantern',
    putLantern = 'Put lantern', destroy = 'Destroy', transferName = 'Transfer %s', stowPelt = 'Stow Pelt', removePelt = 'Remove Pelt',
    drop = 'Drop', saveColor = 'Save Colour', close = 'Close', transferHere = 'Transfer here: %s', transferRunning = 'Transfer in progress: %d s',
    setFocus = 'Set focus', navigate = 'Navigate', adjust = 'Adjust', nextSlider = 'Next slider', confirm = 'Confirm',

    -- menu labels
    price = 'Price', priceTransfer = 'Price to transfer', variation = 'Variation', free = 'Free', menu = 'Menu',
    homeDesc = 'Buy or look after your horses and wagons', horseManager = 'Horse manager', wagonManager = 'Wagon manager',
    selectStable = 'Pick the new stable', transferToStable = 'Send it to the %s stable', transferAway = 'Send it to another stable',
    inThisStable = 'Kept at this stable', outside = 'Outside', dead = 'Dead', coat = 'Coat', model = 'Model',
    noStorage = 'No storage', storage = 'Storage', kg = '%s kg', slots = '%s slots', yourHorses = 'Your horses',
    buyHorse = 'Buy a new Horse', buyHorses = 'Buy Horses', manageHorses = 'Manage Owned Horses', manageHorsesDesc = 'Look after the horses you own',
    selectedHorse = 'Your selected horse', listHorses = 'List of horses', noHorse = 'No horse bought yet',
    male = 'Male', female = 'Female', chooseSex = 'Choose the sex', transferDesc = 'Hand this horse to someone else',
    releaseName = 'Release %s', releaseDesc = 'You will lose this horse. (Tack is kept.)', renameHorse = 'Rename Horse',
    renameHorseDesc = 'Give your horse a new name.', changeShoes = 'Change Horseshoes', changeShoesDesc = 'Fit new horseshoes',
    changeCoat = 'Change Coat Colour', reviveFor = 'Revive for', customCoat = 'Custom coat', horseStats = 'Horse statistics',
    speed = 'Speed', acceleration = 'Acceleration', handling = 'Handling', health = 'Health', stamina = 'Stamina', race = 'Breed',
    sex = 'Sex', bondingLevel = 'Bonding Level', shoesState = 'Shoe state', saddlebag = 'Saddlebag', saddlebagSize = 'Saddlebag Size',
    handlingGrades = { 'Heavy', 'Standard', 'Race', 'Elite' },
    buyComponent = 'Buy a new component', buyComponents = 'Buy tack', ownedComponents = 'Your owned components',
    ownedComponentsDesc = 'Look after the tack you already bought', equipedOn = 'Equipped on %s', manageEquiped = 'Manage equipped components',
    categories = 'Categories', noComponent = 'No tack bought yet', number = 'Number %d', nOfM = '%d of %d', special = 'Special Horses',
    specialDesc = 'Bred here, and nowhere else',
    cat = {
        horse_saddles = 'Saddles', horse_saddlebags = 'Saddle bags', saddle_stirrups = 'Stirrups', saddle_horns = 'Horns',
        horse_blankets = 'Blankets', horse_bedrolls = 'Bedrolls', horse_manes = 'Manes', horse_tails = 'Tails', horse_shoes = 'Shoes',
        horse_outfits = 'Accessories', horse_accessories = 'Masks', horse_bridles = 'Bridles', saddle_lanterns = 'Lanterns',
        horse_mustache = 'Mustaches',
    },
    changeHair = 'Change Hair', manageHair = 'Manage the mane, tail and mustache', changeMane = 'Change the mane',
    changeTail = 'Change the tail', changeMustache = 'Change the mustache', customColor = 'Custom colour', color = 'Colour', palette = 'Palette',
    pal_classic = 'Classic', pal_hair = 'Hair', pal_horse = 'Horse', pal_horseleather = 'Horse leather', pal_leather = 'Leather', pal_makeup = 'Makeup',
    tintN = 'Tint %d', headTint = 'Head tint %d', bodyTint = 'Body tint %d',
    outfits = {
        explorer_items = 'Explorer items', prospector_gear = 'Prospector gear', wolf_pelt = 'Wolf pelt',
        hunting_gear_3 = 'Hunting gear 3', hunting_gear_4 = 'Hunting gear 4',
        long_scabbard_l = 'Long scabbard (left)', long_scabbard_r = 'Long scabbard (right)', short_scabbard_r = 'Short scabbard (right)',
        loadout_1 = 'Loadout 1', loadout_2 = 'Loadout 2', loadout_3 = 'Loadout 3', loadout_4 = 'Loadout 4', loadout_5 = 'Loadout 5',
        pelt_bundle_1 = 'Pelt bundle 1', pelt_bundle_2 = 'Pelt bundle 2',
        trapper_set_1 = 'Trapper set 1', trapper_set_2 = 'Trapper set 2', trapper_set_3 = 'Trapper set 3',
        trapper_set_4 = 'Trapper set 4', trapper_set_5 = 'Trapper set 5', trapper_set_6 = 'Trapper set 6',
    },
    wagon = 'Wagon', buyWagon = 'Buy a new Wagon', buyWagons = 'Buy Wagons', manageWagons = 'Manage owned Wagons',
    manageWagonsDesc = 'Look after the wagons you own', yourWagons = 'Your wagons', noWagon = 'No wagon bought yet', callWagon = 'Call a wagon',
    destroyName = 'Destroy %s', destroyDesc = 'You will lose this wagon.', transferWagonDesc = 'Hand this wagon to someone else',
    renameWagon = 'Rename Wagon', renameWagonDesc = 'Give your wagon a new name.', seats = 'Number of Seats', harness = 'Number of Horses',
    tints = 'Tints', tint = 'Tint', propset = 'Propset', livery = 'Livery', lantern = 'Lantern', extra = 'Extra',
    noLivery = 'No livery', noTint = 'No tint', noExtra = 'No extra', noLantern = 'No lantern', noPropset = 'No propset',
    notForSale = 'Not for sale', locked = 'Kept at %s',
    liveries = { livery = 'Livery' },

    -- notifications
    noMoney = "You can't afford that", askHorseName = "Name your horse", askWagonName = "Name your wagon",
    askNewHorseName = 'New name for the horse', askNewWagonName = 'New name for the wagon',
    boughtHorse = 'New horse bought', boughtComponent = 'New tack bought', boughtWagon = 'New wagon bought',
    askTransferTo = 'Hand it to: (player ID)', ownId = "That's your own player ID", playerAbsent = 'That player is not here',
    congrats = 'All done', transferred = 'You handed %s to %s', receivedHorse = '%s gave you a horse', receivedWagon = '%s gave you a wagon',
    tooFar = 'The other player is too far away', transferFailed = 'The transfer could not be saved, try again',
    cantTransfer = "This horse can't change hands right now", released = '%s runs free!', deletedHorse = '%s is gone',
    maxHorses = 'You already keep as many horses as you may', maxWagons = 'You already keep as many wagons as you may',
    addedToStable = '%s added to your stable', disabled = 'The server owner switched this off', nearStable = 'You must be near a stable to use this',
    noFavourite = 'No favourite horse picked', favouriteOut = 'Your favourite horse is already out', favouriteDead = 'Your favourite horse has died',
    goToStable = 'Go to a stable to take out your horse', cantStable = "You can't stable this horse", horseOutside = 'This horse is outside',
    tooFarTo = 'Your horse is too far away to %s', noItemTo = 'You have nothing to %s with', verbWhistle = 'whistle', verbBrush = 'brush', verbFeed = 'feed',
    noSaddlebag = "This horse has no saddlebag", hasSatchel = 'You already carry a satchel', hasSaddlebag = 'This horse already has a saddlebag',
    noHorseNear = 'No horse around you', cantFlee = "You can't send this horse away", fleeOff = 'Sending horses away is switched off',
    horseDead = 'Your horse is dead', notDead = 'The nearest horse is not dead', mustBeOut = 'Your favourite horse must be out to change its colour',
    notYourHorse = "That's not your horse", noPalette = 'No colour palette available',
    shoesReady = 'New horseshoes, good for the next %d km', shoesShattered = 'Shattered horseshoes, the horse cannot run any more.',
    shoesDamaged = 'The horseshoes are badly worn. Buy new ones at a stable.', shoesState = 'Horseshoes: %d%%',
    revived = '%s is back on its feet', vetPaid = 'The vet patched up %s. You paid $%s', vetFree = 'The vet patched up %s',
    vetHolding = 'The vet is keeping %s until you can pay $%s', stillDown = 'Your horse is still down. Try again in %d seconds',
    wagonDeleted = 'Wagon destroyed', spawnBusy = 'Something is blocking the wagon spot', noWagonNear = 'No wagon around you',
    cantFleeWagon = "You can't send this wagon away", cantStableWagon = "You can't stable this wagon", notYourWagon = "That's not your wagon",
    noWagonInTown = "There's no room for a wagon in town. Take it up outside.", wagonOnWay = 'Your wagon is already on its way.',
    levelN = 'Up to level %d', bonding = 'Bonding', horseXP = 'Horse XP', levelUp = 'level up!', healthUp = 'Health improves!',
    staminaUp = 'Stamina improves!', beyondMedicine = 'This horse is past saving', stimWorks = 'The stimulant takes effect',
    horseTraining = 'Horse Training', horseLevel = 'Horse level %d', grewXP = 'Your horse grew more experienced!', level = 'Level', points = 'Points',
    breedLimit = 'Breed limit reached', raiseLevel = "Raise the horse's level to train further", currentFocus = 'CURRENT TRAINING FOCUS (choose it again to clear)',
    focusDesc = {
        speed = 'Top speed: set as focus and ride to build it.', acceleration = 'Off the mark: set as focus and ride to build it.',
        handling = 'Responsiveness: set as focus and ride to build it.', health = 'Toughness: set as focus and ride to build it.',
        stamina = 'Endurance: set as focus and ride to build it.', bonding = 'Trust: feeding, brushing and riding build this. Set as focus to build it faster.',
    },
    sideSaddleHelp = 'Ride side saddle', fixHorseHelp = 'Find your horses again', fixWagonHelp = 'Repair the nearest wagon',
    adminTransferred = 'Staff gave %s to you.', adminDeleted = '%s deleted from the database.',
    autoRideOff = 'Auto ride follow switched off', autoRideOn = 'Auto ride follow switched back on',

    -- misc
    vetRefund = 'The vet could not take that horse. Your money was returned.', horseNotFound = 'That horse could not be found.',
    horseNotDead = 'That horse is not dead.', fullyTrained = 'Fully Trained', fullyTrainedSub = 'This one has nothing left to learn.',
    renamedHorse = 'Horse renamed to %s', renamedWagon = 'Wagon renamed to %s', jobLocked = 'Only the %s job may have this.',
    stabledOnDrop = 'Your horse went back to the stable. Call it again from there.', stableUnreachable = 'Could not reach the stable. Try again.',
    noWhistleHere = 'You cannot call your horse in this area.', controlsOff = 'Your horse controls are switched off',
    dismountFirst = 'Get off your horse first.', needBond = 'Needs bonding level %d.', needWater = 'Your horse must stand in water to drink.',
    noControl = 'Could not take control of the horse. Try again.', peltNoModel = 'That one cannot come back off - its model was not recorded.',
    trainingTip = 'Training - Speed: %s | Accel: %s | Handling: %s | Bond: %d/4 | Stamina core: %d/100',
    infoTitle = 'Horse Statistics', infoHorse = 'Horse', infoOff = 'Horse info is switched off on this server',
    maxed = 'MAXED', noSaddlebagFitted = '%s has no saddlebag fitted', busy = 'Wait a moment, the stable is still working on your last request',
    tooFarHorse = 'Your horse is too far away', noHorseOut = 'You have no horse out', notYourOwn = 'Only on your own horse',
    whistleTooFar = 'Your horse is too far away to hear you', invalidName = 'That name will not do',
    stillTransferring = 'That one is still on its way here',

    -- breeding
    inFoal = 'In Foal', inFoalRow = '%s x %s | %d due in %s', breedHorse = 'Breed a Horse', breedHorseDesc = 'Put a foal of your own on the board',
    bredFoals = 'Bred Foals', boardEmpty = 'Nothing on the board', lineage = 'Lineage', remaining = 'Remaining %d of %d',
    sire = 'The sire (father)', dam = 'The dam (mother)', whichLine = 'Which line does it take after?', afterSire = 'Takes after the sire',
    afterDam = 'Takes after the dam', hairPalette = 'Mane and tail palette', hairTint = 'Mane and tail %d', height = 'Height',
    heightDesc = 'Left and right to change', heightStd = 'Standard', taller = 'Taller +%d%%', shorter = 'Shorter %d%%',
    priceIt = 'Done, price it', priceItDesc = 'Puts the foal up for sale', askPrice = 'Price, at least $%d', notPrice = 'That is not a price.',
    priceFloor = 'The least you can ask is $%d.', pickBreed = 'Pick a breed first.', pickSire = 'Pick a sire first.',
    lookParents = 'Look over both parents first, then try again.', leaveHer = 'That one is in foal. Leave her be.',
    br_off = 'Breeding is switched off.', br_noStable = 'No such stable.', br_noOwner = 'Nobody owns this stable.',
    br_noService = 'The society service is not running.', br_notYours = 'You do not run this stable.', br_grade = 'You need rank %d or above here to breed.',
    br_cooldown = 'Nothing ready yet. %d day(s) to go.', br_busy = 'Someone is already breeding here.', br_noBreed = 'Nobody keeps that breed.',
    br_inFoal = 'In foal with %d. %dh to go.', br_yours = ' One of them is yours to keep.', br_onBoard = '%d foals are on the board.',
    br_gone = 'That one has already gone.', br_notHere = 'That foal is not kept here.', br_spoken = 'That foal is spoken for.',
    br_failed = 'That foal could not be stabled. Your money was returned.', br_retired = 'Taken off the board.', retire = 'Take off the board',
    askFoalName = 'Name your foal',

    -- wild horses
    wh_notMounted = "You aren't on a horse", wh_notWild = 'That is not one of the wild horses', wh_breakFirst = 'Break it in first',
    wh_notTamer = 'You did not tame this one', wh_noSkill = "You don't know how to handle a wild horse",
    wh_cooldown = 'You worked a horse recently, come back later', wh_sold = 'Thanks for the deal! You got $%d',
    wh_tamed = 'Horse tamed - ride it to any stable', wh_title = 'The Stablehand', wh_keep = 'Keep it',
    wh_keepDesc = 'Registers it to this stable. It takes a slot.', wh_sell = 'Sell it', wh_sellDesc = 'They take it off your hands for cash.',
    wh_name = 'Name the horse', wh_yours = 'It is yours. Collect it from your stable.', wh_noPapers = 'The stablehand cannot make papers for that one.',
    wh_thrown = 'It threw you off - catch it and try again', wh_hold = 'Hold on - %d / %d', wh_blip = 'Wild Horses',

    -- blips
    blipStable = 'Stable', blipHorse = 'Your Horse', blipLastHorse = 'Your last Horse', blipFollow = 'Your last Horse (follow)',
    blipWagon = 'Your wagon', blipWaypoint = 'Waypoint',
}

function L(key, ...)
    local s = Locale[key]
    if s == nil then return key end
    if select('#', ...) > 0 and type(s) == 'string' then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
