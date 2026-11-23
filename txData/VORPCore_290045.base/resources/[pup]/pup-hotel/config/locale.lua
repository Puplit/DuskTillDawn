-- pup-hotel | player-facing text
-- %s / %d are filled in by the code; keep them in the same order.

Locale = {
    -- general
    hotelFallback      = 'Hotel',                 -- hotel with no label (menus, blip)
    roomFallback       = 'Room',                  -- room with no tier label
    expired            = 'expired',
    perDay             = '%s per day',            -- price
    notYourRoom        = "This isn't your room.",

    -- prompts
    promptDesk         = 'Front Desk',
    promptOffice       = 'Office',
    promptUnlock       = 'Unlock',
    promptLock         = 'Lock',

    -- guest menu
    myStay             = 'My stay',
    myStayDesc         = 'What you are paying for',
    nothingBooked      = 'Nothing booked',
    notStaying         = 'You are not staying anywhere.',
    runsOutIn          = 'Runs out in',
    untilTime          = 'Until %s',              -- date

    -- clerk menu
    inputConfirm       = 'Confirm',
    ledgerWontOpen     = 'The desk ledger would not open.',
    deskClosed         = 'The desk is closed.',
    subtitleOffice     = 'Office',
    subtitleFrontDesk  = 'Front desk',
    subtitleGuest      = 'Guest',
    subtitleVacant     = 'Vacant',
    occupied           = 'occupied',
    guest              = 'Guest',
    characterId        = 'Character ID',
    characterN         = 'Character %d',          -- char id
    extendStay         = 'Extend the stay',
    howManyMoreDays    = 'How many more days?',
    howManyDays        = 'How many days?',
    revokeAccess       = 'Revoke access',
    revokeAccessDesc   = 'Ends the stay and re-locks the door',
    atDeskId           = 'At the desk - ID %d',   -- char id
    byCharacterId      = 'By character ID',
    byCharacterIdDesc  = 'For someone not at the desk',
    giveAway           = 'Give it away',
    giveAwayDesc       = 'No charge (staff)',
    staffOnly          = 'Staff only.',
    letVacant          = '%d let, %d vacant',
    everyoneStaying    = 'Everyone staying here',
    nightlyRates       = 'Nightly rates',
    nightlyRatesDesc   = 'What each kind of room costs',
    ratesSubtitle      = 'Applies to every room of that kind',
    fromConfig         = ' (from the config)',
    pricePerDayTitle   = '%s - price per day',    -- tier label
    noTiers            = 'No room types configured',
    nobodyHere         = 'Nobody is staying here',
    noRooms            = 'No rooms configured',
    allLet             = 'Every room is let',

    -- server replies
    notRunHotel        = 'You do not run this hotel.',
    noSuchRoomType     = 'No such room type.',
    notAPrice          = 'That is not a price.',
    priceSet           = '%s is now $%d a day.',          -- tier, price
    notYourDesk        = 'You do not work this desk.',
    noSuchRoom         = 'No such room.',
    notDays            = 'That is not a number of days.',
    noCharacter        = 'No character with that ID.',
    roomTaken          = '%s is taken until %s.',         -- room, date
    alreadyHoldsRoom   = 'They already hold a room.',
    mustBeOnline       = 'They have to be online to pay for it.',
    cannotAffordStay   = 'They cannot afford that stay.',
    guestNeedsMoney    = 'You need $%d for that room.',   -- price
    assigned           = '%s is now in %s until %s.',     -- guest, room, date
    guestAssigned      = '%s is yours until %s.',         -- room, date
    cannotAfford       = 'They cannot afford that.',
    nobodyStaying      = 'Nobody is staying there.',
    extended           = '%s now runs to %s.',            -- room, date
    roomFreed          = '%s is free again.',             -- room
    guestEvicted       = 'Your room has been given up.',
    stayEndingSoon     = 'Your room runs out at %s.',     -- time
    stayEnded          = 'Your stay has ended.',
    roomBusy           = 'The ledger is open on that room. Try again.',
    guestHasOffer      = 'They are already looking at an offer.',
    offerSent          = 'Waiting for them to agree.',
    offerExpired       = 'The offer ran out.',
    offerDeclined      = 'They turned it down.',

    -- what the guest is asked
    offerTitle         = 'The clerk is offering',
    offerRoom          = '%s for %d day(s)',              -- room, days
    offerMore          = '%d more day(s) in %s',          -- days, room
    offerAccept        = 'Pay %s',                        -- total
    offerAcceptDesc    = 'Taken from your pocket now',
    offerDecline       = 'No thanks',

    -- setup commands (staff)
    hotelroomUsage     = '/hotelroom <hotel> <id> <tier> [doorName] [label]',
    noHotelByName      = 'No hotel by that name.',
    badRoomId          = 'The id must be letters, numbers and underscores.',
    noTierByName       = 'No tier by that name.',
    roomIdTaken        = 'That room id is already taken.',
    roomWriteFailed    = 'Could not write the room to the config.',
    roomAdded          = '%s added to %s.',               -- room, hotel
    lookAtDoor         = 'Look straight at the door.',
    doorHashFound      = 'Door hash %s - see F8',         -- hash
    doorNotRegistered  = 'Not a registered door - see F8',
}
