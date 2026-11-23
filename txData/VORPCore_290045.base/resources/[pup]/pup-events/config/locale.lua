Locale = {

    -- The Spring Hunt
    easter = {
        promptGroup    = 'Spring Hunt',
        promptLabel    = 'Pick Up Egg',
        pickupNormal   = 'You picked up an egg.',
        pickupGold     = 'You found a Golden Egg!',
        patchLimit     = 'You have taken all you can from this patch.',
        eggGone        = 'That egg has already been collected.',
        eggReserved    = 'Someone else is already picking that one up.',
        eggVerifyFail  = 'Could not verify that pickup.',
        eggTooFar      = 'You are too far from that egg.',
        charNotReady   = 'Character data is not ready yet.',
        down           = 'Not while you are down.',
        inventoryFull  = 'You cannot carry any more eggs.',
        eggUnavailable = 'That egg is no longer available.',
        openNormal     = 'You cracked open an egg and found %s x%d!',
        openGold       = 'You cracked open a Golden Egg and found %s x%d!',
        goldRerolled   = 'Your reward was rerolled - you already own that one.',
        goldAllOwned   = 'You already own every Golden Egg reward. Give it to a friend.',
        animFailed     = 'Failed to load the pickup animation.',
        busy           = 'One at a time.',
    },

    -- Trick or Treat
    trickOrTreat = {
        prompt         = 'Knock',
        promptName     = 'Trick or Treat',
        treat          = 'A sack is pushed into your hands.',
        trick          = 'The door opens. That was a mistake.',
        onCooldown     = 'You have already worked this door tonight.',
        doneForTonight = 'You have had your share tonight. Nobody else is answering.',
        full           = 'You cannot carry any more.',
        -- one of these is shown with a treat, picked at random
        flavour = {
            'Nobody says a word. The door closes again.',
            'A hand you do not want to look at passes it out.',
            'Something inside is laughing. It does not stop when the door shuts.',
            'The porch light was never lit. You are sure of it.',
            'They knew your name. You have never been here before.',
            'It smells of candle wax and something older.',
            'A child thanks you. There are no children out here.',
            'The sack is warm.',
        },
    },

    -- Purge loot caches
    purgeCaches = {
        group     = 'Cache',
        prompt    = 'Force',
        toofar    = 'You are not at the cache.',
        noitem    = 'You need a %s for this.',
        broke     = 'The %s snapped.',
        opened    = 'The lid gives.',
        prying    = 'Levering it open',
        busy      = 'Somebody is already on it.',
        tookmoney = 'There was $%s loose in the bottom.',
        -- chat announcements. %s is the cache label.
        chatTitle = 'PURGE',
        spawned   = 'A cache has turned up at %s. It will not be there long.',
        cracked   = 'The cache at %s has been cracked open.',
        movedon   = 'Nobody came for the cache at %s. It is gone.',
    },
}
