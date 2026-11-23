-- pup-misc/pets | player-facing text
-- %s / %d are filled in by the code; keep them.

PetsLocale = {
    -- orders
    noPet          = 'You have no pet out.',
    heel           = 'Heel.',
    sit            = 'Sit.',
    wontSit        = 'That animal will not sit.',
    howl           = 'Howl.',
    nothingToSay   = 'That animal has nothing to say.',
    aimFirst       = 'Aim at something first.',
    notAtPlayer    = 'Not at another person.',
    tooFar         = 'Too far.',
    attack         = 'Get him.',
    scentFound     = 'Picked up a scent - %d nearby.',
    scentNone      = 'Nothing worth chasing.',
    scentBlip      = 'Scent',              -- name of the /pettrack map blips
    huntOn         = 'Hunt.',
    huntOff        = 'Hunt off.',
    broughtBack    = 'Your pet brings it back.',
    notAMount      = 'That is a pet, not a mount.',

    -- summon / put away
    yourPet        = 'Your pet',           -- fallback when a pet has no name or label
    following      = '%s is following you.',
    staysBehind    = '%s stays behind.',
    allStayBehind  = 'Your pets stay behind.',
    alreadyOut     = 'You already have a pet out.',
    tooManyOut     = 'You can only have %d pets out at once.',

    -- naming (returned to the naming station, pup_staffdesk)
    namingOff      = 'Pet naming is switched off.',
    nothingToName  = 'Nothing to name.',
    notYourPet     = 'That is not one of your pets.',
    nameFirst      = 'Give them a name first.',
    descTooLong    = 'Too long - %s characters at most.',
}
