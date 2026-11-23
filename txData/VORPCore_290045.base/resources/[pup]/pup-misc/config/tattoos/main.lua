-- pup-misc/tattoos | main settings (see README)

TattooConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
TattooConfig.General = {
    debug = false,   -- console prints
}

-- prompt keys
TattooConfig.Keys = {
    openMenu    = 0x760A9C6F,   -- G          open the mirror at a shop
    resetCamera = 0xCEFD9220,   -- E
    cameraUp    = 0xA1FDE2A6,   -- 6
    cameraDown  = 0xAB62E997,   -- 5
    zoomIn      = 0xE6F612E4,   -- 1
    zoomOut     = 0x1CE6D9EB,   -- 2
    rotateLeft  = 0x4F49CC4C,   -- 3
    rotateRight = 0x8F9F9E58,   -- 4
    back        = 0x156F7119,   -- BACKSPACE
}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
TattooConfig.Integrations = {}

-------------------------------------------------------------------------------
-- PRICES  (dollars, charged on save)
-------------------------------------------------------------------------------
TattooConfig.Prices = {
    layers          = 5,     -- all overlay layers at once
    bodyAdjustments = 100,
}

-------------------------------------------------------------------------------
-- SHOPS
-------------------------------------------------------------------------------
TattooConfig.Shops = {
    radius = 2.0,             -- metres
    blip   = {
        sprite = 1451797164,
        scale  = 0.2,
    },
    locations = {
        { name = 'Valentine',  coords = vector3(-325.08, 760.24, 117.43),    showBlip = true },
        { name = 'Rhodes',     coords = vector3(1339.75, -1379.51, 84.28),   showBlip = true },
        { name = 'Saint Denis', coords = vector3(2550.1, -1160.0, 53.73),    showBlip = true },
        { name = 'MK',         coords = vector3(1020.73, -1778.6, 52.04),    showBlip = false },
        { name = 'Strawberry', coords = vector3(-1820.57, -366.92, 166.50),  showBlip = true },
    },
}

-------------------------------------------------------------------------------
-- LAYERS
-------------------------------------------------------------------------------
TattooConfig.Layers = {
    -- overlay names this menu must not touch, as { name = true }
    excluded = {},
    -- the layers grouped under Makeup
    makeup = {
        "lipsticks",
        "blush",
        "eyeliners",
        "shadows",
    },
}

-------------------------------------------------------------------------------
-- MIRROR
-------------------------------------------------------------------------------
TattooConfig.Mirror = {
    -- icon strip across the top of the page; unlisted layers land in the last category
    categories = {
        { id = "tattoos",   label = "Tattoos",   layers = { "disc", "paintedmasks" } },
        { id = "makeup",    label = "Makeup",    layers = { "lipsticks", "blush", "eyeliners", "shadows", "foundation" } },
        { id = "lifestyle", label = "Lifestyle", layers = {} },
    },
}
