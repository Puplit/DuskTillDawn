-- pup-magic | every line of text a player or the console sees
-- Loaded before config/spells.lua, which copies some of these into the spell blocks.
-- %s and %d are filled in by the code; keep them in the text.

Locale = {
    ---------------------------------------------------------------------------
    -- spell kit (config/spells.lua reads these eleven when it loads)
    ---------------------------------------------------------------------------
    smokeCast      = 'A cloud of grey smoke rolls out of your hand.',
    lightningCast  = 'You pull a bolt down out of the sky.',
    shockNoTarget  = 'There is nobody in front of you to jolt.',
    frogNoTarget   = 'There is nobody in front of you to curse.',
    frogOn         = 'A wet croak. Somebody has been turned into a frog.',
    frogOff        = 'The croaking fades and your own shape comes back.',
    pinOn          = 'The pin is pulled. Your kit is live.',
    pinOff         = 'The pin goes back in. Your kit is safe again.',
    bombPunch      = 'Your fist lands like a stick of dynamite.',
    bombToss       = 'You lob a lit charge.',
    detonate       = 'You go up like a powder store.',

    ---------------------------------------------------------------------------
    -- spells
    ---------------------------------------------------------------------------
    aimOn          = 'Aim marker shown.',
    aimOff         = 'Aim marker hidden.',
    noReach        = 'Nobody is within reach.',
    shocked        = 'Shocked: %d s',
    pinFirst       = 'Pull the pin first.',
    notYet         = 'Not ready yet: %d s.',
    tooFar         = 'They are too far away.',
    tooFarThrow    = 'That is further than you can throw.',
    aimMarker      = '»«',

    ---------------------------------------------------------------------------
    -- feeding
    ---------------------------------------------------------------------------
    feedPrompt       = 'Feed',
    tooFull          = 'Your thirst is quiet for now. Try again in %d s.',
    victimDrained    = 'Something is drinking the blood out of you.',
    victimBlur       = 'The last few hours are a fog.',
    victimRecover    = 'Your head starts to clear.',
    feedNpcReward    = 'You drew off a vial of human blood.',
    feedPlayerReward = '',  -- empty: nothing is shown after feeding on a player
    ownCurseOnly     = 'You may only look up your own curse.',
    noSuchPlayer     = 'No player has that server id.',
    curseLine        = 'Curse for %d: "%s"%s',
    curseFeedOn      = ' - feeding enabled',
    curseFeedOff     = ' - feeding disabled',
    consoleNeedsId   = '[pup-magic] /feedcurse from the console needs a server id: feedcurse <id>',

    ---------------------------------------------------------------------------
    -- blood vials and borrowed faces
    ---------------------------------------------------------------------------
    vialLabel        = 'Blood of %s',
    vialDesc         = 'Still warm.<br>Drink it to wear their face for a while.<br>Taken from <b>%s</b>.',
    vialBottled      = 'You stopper a vial of their blood.',
    vialNoRoom       = 'You have no room for another vial.',
    vialFull         = 'You are carrying all the blood you can stomach.',
    vialAlready      = 'You already have their blood in your satchel.',
    alreadyDisguised = 'You are already wearing somebody else\'s face.',
    vialSpoiled      = 'This blood has turned. It is no use to you.',
    vialNobody       = 'You cannot find whoever this blood came from.',
    drinkDown        = 'You tip the vial back and swallow.',
    wearingFace      = 'You are wearing %s\'s face.',
    faceSlipping     = 'The borrowed face is starting to slip.',
    faceGone         = 'The blood wears off. You are yourself again.',
    ownFace          = 'You are wearing your own face.',
    faceTimeLeft     = 'You are wearing %s\'s face, %s left.',
    aStranger        = 'a stranger',
    someone          = 'someone',
    inGameOnly       = '[pup-magic] /bloodtime only works in game.',

    -- time words for /bloodtime
    minuteOne        = '%d minute',
    minuteMany       = '%d minutes',
    secondOne        = '%d second',
    secondMany       = '%d seconds',
}
