-- skinanimals | locale/en.lua
-- Player-facing texts. Placeholders (%s) must stay.

Locale = {
    title         = 'Skinning',
    alreadyDone   = 'Someone has already worked this carcass.',
    busy          = 'Give it a moment before the next one.',
    gotPrefix     = 'Collected: ',
    doubled       = ' (doubled)',
    noItems       = 'There is nothing to take from this one.',
    nothing       = 'You could not take anything from this carcass.',
    unknownItem   = 'Unknown item: %s',
    noRoom        = 'No room for: %s',
    refusalJoin   = ' | ',
    listJoin      = ', ',

    -- only shown when Config.Messages.distinctRefusals = true
    tooFar        = 'You are too far from that carcass.',
    wrongAnimal   = 'That carcass does not match what you skinned.',
    notDead       = 'That animal is still alive.',
    tooMany       = 'You have skinned too many carcasses nobody else could see. Wait a while.',
    notAllowed    = 'That carcass cannot be checked, so it pays nothing.',
}
