Config.DeadOfNight = {

    -------------------------------------------------------------------------------
    -- UFO
    -------------------------------------------------------------------------------
    ufo = {
        enabled  = true,
        hourFrom = nil,     -- nil = the whole event
        hourTo   = nil,
        radius   = 120.0,   -- metres
        height      = 65.0, -- metres
        riseSeconds = 25.0, -- seconds
        holdSeconds = 90.0, -- seconds
        model = 'S_UFO01X', -- nil = light only
        light = { r = 90, g = 255, b = 140, range = 45.0, intensity = 4.0 }, -- range in metres

        sites = {
            {
                name   = "Hani's Bethel",
                coords = vector3(1330.0, 400.0, 92.0),
                line   = 'Green light, under the roof beams. It is not a lamp.',
            },
            {
                name   = 'Mount Shann',
                coords = vector3(-1720.0, 100.0, 300.0),
                line   = 'The stones are humming. Something is holding station above you.',
            },
        },
    },

    -------------------------------------------------------------------------------
    -- VAN HORN LIGHTHOUSE
    -------------------------------------------------------------------------------
    lighthouse = {
        enabled = true,
        coords  = vector3(3038.0, 545.0, 84.0),
        drawDistance = 2200.0,                  -- metres
        sweepSeconds = 8.0,                     -- seconds
        beam  = { r = 255, g = 236, b = 190, range = 60.0, intensity = 10.0 }, -- range in metres
        reach = 180.0,                          -- metres
    },

    -------------------------------------------------------------------------------
    -- BATS
    -------------------------------------------------------------------------------
    bats = {
        enabled = true,
        model   = 'A_C_Bat_01',

        count        = { 6, 11 },     -- min, max
        drawDistance = 160.0,         -- metres
        radius       = { 25.0, 70.0 },-- metres, min, max
        height       = { 12.0, 26.0 },-- metres, min, max
        lapSeconds   = { 14.0, 26.0 },-- seconds, min, max

        hourFrom = nil, -- nil = the whole event
        hourTo   = nil,

        towns = {
            { name = 'Saint Denis', centre = vector3( 2700.0, -1200.0,  50.0) },
            { name = 'Valentine',   centre = vector3( -280.0,   800.0, 120.0) },
            { name = 'Blackwater',  centre = vector3( -820.0, -1300.0,  44.0) },
            { name = 'Rhodes',      centre = vector3( 1360.0, -1300.0,  77.0) },
            { name = 'Annesburg',   centre = vector3( 2930.0,  1310.0,  45.0) },
            { name = 'Strawberry',  centre = vector3(-1790.0,  -370.0, 160.0) },
        },
    },
}
