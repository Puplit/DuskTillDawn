-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_character | clothing component data
-- Component category hashes, the categories the clothing menus skip, clothing tint
-- palettes, and the chat commands that toggle each garment.

-------------------------------------------------------------------------------
-- COMPONENT CATEGORIES
-------------------------------------------------------------------------------
-- Saved component key = game category hash. Do not rename the keys (they are saved on characters).
Config.ComponentCategories = {
    BeardsMustache      = `BEARDS_MUSTACHE`,
    Blouses             = `BLOUSES`,
    TalismanHolster     = `TALISMAN_HOLSTER`,
    Scarves             = `SCARVES`,
    TalismanBelt        = `TALISMAN_BELT`,
    EyeBrows            = `EYEBROWS`,
    ShirtsFullOverpants = `SHIRTS_FULL_OVERPANTS`,
    Eyes                = `EYES`,
    CoatsHeavy          = `COATS_HEAVY`,
    TalismanWrist       = `TALISMAN_WRIST`,
    Stockings           = `STOCKINGS`,
    Heads               = `HEADS`,
    BodiesUpper         = `BODIES_UPPER`,
    BodiesLower         = `BODIES_LOWER`,
    MaskLarge           = `MASKS_LARGE`,
    Apron               = `APRONS`,
    Gunbelt             = `GUNBELTS`,
    AmmoPistol          = `AMMO_PISTOLS`,
    AmmoRifle           = `AMMO_RIFLES`,
    Mask                = `MASKS`,
    Holster             = `HOLSTERS_LEFT`,
    Loadouts            = `LOADOUTS`,
    Coat                = `COATS`,
    Cloak               = `CLOAKS`,
    EyeWear             = `EYEWEAR`,
    Bracelet            = `JEWELRY_BRACELETS`,
    Skirt               = `SKIRTS`,
    Poncho              = `PONCHOS`,
    Spats               = `SPATS`,
    NeckTies            = `NECKTIES`,
    Pant                = `PANTS`,
    Suspender           = `SUSPENDERS`,
    Glove               = `GLOVES`,
    Satchels            = `SATCHELS`,
    GunbeltAccs         = `GUNBELT_ACCS`,
    CoatClosed          = `COATS_CLOSED`,
    Buckle              = `BELT_BUCKLES`,
    RingRh              = `JEWELRY_RINGS_RIGHT`,
    Belt                = `BELTS`,
    Accessories         = `ACCESSORIES`,
    Shirt               = `SHIRTS_FULL`,
    Gauntlets           = `GAUNTLETS`,
    Chap                = `CHAPS`,
    NeckWear            = `NECKWEAR`,
    Boots               = `BOOTS`,
    Spurs               = `BOOT_ACCESSORIES`,
    Vest                = `VESTS`,
    RingLh              = `JEWELRY_RINGS_LEFT`,
    Hat                 = `HATS`,
    Dress               = `DRESSES`,
    Badge               = `BADGES`,
    Armor               = `ARMOR`,
    Hair                = `HAIR`,
    Beard               = `BEARDS_COMPLETE`,
    Bow                 = `HAIR_ACCESSORIES`,
    Teeth               = `TEETH`,
}

-- body/hair categories the clothing menus leave out
Config.ComponentCategoriesExclude = {
    Hair = Config.ComponentCategories.Hair,
    Beard = Config.ComponentCategories.Beard,
    BeardsMustache = Config.ComponentCategories.BeardsMustache,
    Teeth = Config.ComponentCategories.Teeth,
    Heads = Config.ComponentCategories.Heads,
    BodiesUpper = Config.ComponentCategories.BodiesUpper,
    BodiesLower = Config.ComponentCategories.BodiesLower,
    Eyes = Config.ComponentCategories.Eyes,
    EyeBrows = Config.ComponentCategories.EyeBrows,
}

-------------------------------------------------------------------------------
-- CLOTHING TINT PALETTES  (keep the order: entries are picked by index)
-------------------------------------------------------------------------------
Config.clothesPalettes = {
    1090645383, 1064202495, -783849117, 864404955, 1669565057, -1952348042
}

-------------------------------------------------------------------------------
-- GARMENT TOGGLE COMMANDS
-------------------------------------------------------------------------------
-- Component key = { command = chat command that takes the garment off / puts it back on }.
-- Whether /rc restores toggled garments: Config.Reload.wearsEverything in config/main.lua.
Config.commands = {
    CoatClosed = { command = "ccoat" },
    Hat = { command = "hat" },
    EyeWear = { command = "eyewear" },
    Mask = { command = "mask" },
    NeckWear = { command = "neckwear" },
    NeckTies = { command = "tie" },
    Shirt = { command = "shirt" },
    Vest = { command = "vest" },
    Coat = { command = "coat" },
    Poncho = { command = "poncho" },
    Cloak = { command = "cloak" },
    Glove = { command = "glove" },
    Bracelet = { command = "bracelet" },
    Buckle = { command = "buckle" },
    Pant = { command = "pant" },
    Skirt = { command = "skirt" },
    Chap = { command = "chap" },
    Boots = { command = "boots" },
    Spurs = { command = "spurs" },
    Spats = { command = "spats" },
    GunbeltAccs = { command = "gunbeltaccs" },
    Gauntlets = { command = "gauntlets" },
    Loadouts = { command = "loadouts" },
    Accessories = { command = "accessories" },
    Satchels = { command = "satchels" },
    Dress = { command = "dresses" },
    Belt = { command = "belt" },
    Holster = { command = "holster" },
    Suspender = { command = "suspender" },
    Armor = { command = "armor" },
    Gunbelt = { command = "gunbelt" },
}
