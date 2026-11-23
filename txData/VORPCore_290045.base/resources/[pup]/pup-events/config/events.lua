Config.Events = {

    deadofnight = {
        label     = 'Dead of Night',
        enabled   = true,
        hourFrom  = 0,
        hourTo    = 5,
        bloodMoon = true,
        openLine  = 'Something is wrong with the dark tonight.',
        closeLine = 'The night lets go of you. Dawn, and still breathing.',
    },

    purge = {
        label     = 'The Purge',
        enabled   = true,
        hourFrom  = 0,
        hourTo    = 24,
        bloodMoon = true,
        openLine  = 'The law has stood down. Whatever happens tonight, happens.',
        closeLine = 'It is over. The law is back on the roads.',

        posse = {
            blips          = true,
            noFriendlyFire = true,
            blipSprite     = 953018525,
        },

        siren = {
            enabled = true,
            file    = '',                       -- add your own siren file here, e.g. 'sounds/siren.ogg' ('' = silent)
            volume  = 0.2,                      -- 0.0 - 1.0
        },
    },

    easter = {
        label     = 'The Spring Hunt',
        enabled   = true,
        hourFrom  = 0,
        hourTo    = 24,
        bloodMoon = false,
        openLine  = 'Word is there are painted eggs hidden out in the country.',
        closeLine = 'The last of the eggs have been found. Until next spring.',
    },

}
