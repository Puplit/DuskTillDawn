-- pup-misc/outfitter | player-facing text (%s / %d are filled in by the code)

OutfitterLocale = {
    -- menus
    title         = 'Outfitter',
    counts        = '%d in the wagon  -  %d pitched',          -- carried, pitched
    camps         = 'Camps',
    campsDesc     = 'Tents, wagons and whole camps',
    gear          = 'Gear',
    gearMenuDesc  = 'Single pieces to set down',
    campDesc      = 'A whole camp, pitched in one go',         -- each camp row in the shop
    gearDesc      = 'A single piece of gear',                  -- each gear row in the shop
    kit           = 'Your Kit',
    kitDesc       = 'Pitch what you own, or pack it up',
    valuePitched  = 'pitched',
    pitchedDesc   = 'Standing out there. Choose it to pack it up.',
    valueInWagon  = 'in the wagon',
    inWagonDesc   = 'Choose it to pitch it where you stand.',
    emptyKit      = 'Nothing yet',
    emptyKitDesc  = 'Buy something from the counter first.',
    scrap         = 'Throw Out',
    scrapMenuDesc = 'Be rid of a piece for good',
    scrapDesc     = 'Thrown out for good. No money back.',
    emptyScrap    = 'Nothing packed away',
    emptyScrapDesc = 'Pack a piece up before you throw it out.',

    -- wagon hint and placement
    wagonHint       = 'Press U for the outfitter',
    pitching        = 'Pitching %s. G to set it down, Backspace to think better of it.',             -- label
    hudPlace        = '%s   -   G to pitch, [ ] to turn, Up/Down to move it, Backspace to cancel',   -- label
    hudCounter      = '%s   -   step away from the counter',                                         -- label
    hudTown         = '%s   -   too close to town',                                                  -- label
    cancelled       = 'Left it packed.',
    awayFromCounter = 'Step away from the stable counter to pitch it.',
    tooCloseToTown  = 'You cannot pitch camp this close to town.',

    -- server replies
    notAtCounter = 'You are not at an outfitters counter.',
    tooPoor      = 'That costs $%d.',                                  -- price
    bought       = '%s is in your wagon.',                             -- label
    tooFar       = 'Too far from you to pitch.',
    limit        = 'You already have %d pitched. Pack one up first.',  -- count
    packed       = 'Packed up.',
    packFirst    = 'Pack it up before you get rid of it.',
    scrapped     = 'Thrown out.',
}
