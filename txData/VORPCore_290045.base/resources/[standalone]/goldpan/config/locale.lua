Config = Config or {}

Config.Messages = {
    WrongArea  = 'Nothing to pan here. Find a known river, creek, lake or pond.',
    NoPan      = 'You cannot work the pan right now.',
    Digging    = 'Your hands are full with the shovel.',
    CantCarry  = 'Your satchel cannot hold any more.',
    Sloppy     = 'You tipped the whole load back into the water.',
    TooSoon    = 'Let the silt settle a moment.',
    NoItem     = 'You need a gold pan for that.',
    Drained    = 'This stretch is panned out. Move along the water.',
    Working    = 'You are already working a load.',

    Found      = 'Your pan holds %s x%d.', -- label, amount
    AlsoFound  = 'Also %s.',               -- list of extras
    OnlyExtras = 'No colour, but the pan held %s.',
    ListItem   = '%s x%d',
    ListAnd    = ' and ',

    HintDead   = 'Dead water. Nothing settles out but black sand.',
    HintNone   = 'Black sand and grit. Nothing down here.',
    HintFaint  = 'A faint glint of colour. Something lies further on.',
    HintClose  = 'A few specks of colour. You are getting close.',
    HintHot    = 'The pan is heavy with colour. This is the spot.',
}

-- ms on screen
Config.MessageMs = {
    WrongArea = 5000,
    NoPan     = 5000,
    Digging   = 5000,
    CantCarry = 5000,
    Sloppy    = 5000,
    TooSoon   = 4000,
    NoItem    = 5000,
    Drained   = 6000,
    Working   = 4000,
    Found     = 6000,
    Nothing   = 5000,
}

-- refusals use the red tone, everything else gold
Config.RedMessages = {
    WrongArea = true, NoPan = true, Digging = true, CantCarry = true,
    Sloppy = true, TooSoon = true, NoItem = true, Working = true,
}
