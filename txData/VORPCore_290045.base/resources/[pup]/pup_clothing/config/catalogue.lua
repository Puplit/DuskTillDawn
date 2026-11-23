-- pup_clothing | catalogue settings

Config.SkipCategories = {
    BODIES_LOWER = true, BODIES_UPPER = true, heads = true, hair = true, eyes = true,
    beards_chin = true, beards_chops = true, beards_mustache = true,
}

Config.Groups = {
    { id = 'head', label = 'Head', cats = {
        'hats', 'masks', 'masks_large', 'eyewear', 'eyewear2', 'headwear', 'face_props',
        'hat_accessories', 'hair_accessories', 'hair_bonnet' } },
    { id = 'upper', label = 'Upper', cats = {
        'coats', 'coats_closed', 'coats_heavy', 'shirts_full', 'shirts_full_overpants', 'vests', 'suspenders',
        'unionsuits_full', 'overalls_full', 'overalls_modular_uppers', 'cloaks', 'ponchos', 'capes', 'shawls',
        'corsets', 'chemises', 'outfits', 'neckwear', 'neckties', 'neckerchiefs', 'jewelry_necklaces' } },
    { id = 'lower', label = 'Lower', cats = {
        'pants', 'overalls_modular_lowers', 'dresses', 'skirts', 'unionsuit_legs', 'knickers', 'stockings', 'chaps' } },
    { id = 'feets', label = 'Feet', cats = { 'boots', 'boot_accessories', 'spats' } },
    { id = 'weapons', label = 'Rig', cats = {
        'gunbelts', 'gunbelt_accs', 'holsters_left', 'holsters_right', 'holsters_knife', 'holsters_crossdraw',
        'holsters_center', 'holsters_quivers', 'loadouts', 'ammo_pistols', 'ammo_rifle', 'ammo_shotgun',
        'bandoliers', 'talisman_holster', 'talisman_satchel', 'talisman_wrist' } },
    { id = 'accs', label = 'Extras', rest = true, cats = {} },
}

Config.Labels = {
    boot_accessories = 'Spurs', pants = 'Pants', teeth = 'Teeth', cloaks = 'Cloak', hats = 'Hat', vests = 'Vest',
    chaps = 'Chaps', shirts_full = 'Shirt', badges = 'Badge', masks = 'Mask', spats = 'Spats',
    neckwear = 'Neckwear', boots = 'Boots', accessories = 'Accessories',
    jewelry_rings_right = 'Jewelry Right', jewelry_rings_left = 'Jewelry Left',
    jewelry_bracelets = 'Bracelets', gauntlets = 'Gauntlets', neckties = 'Necktie',
    holsters_knife = 'Knife Holster', talisman_holster = 'Talisman Holster', loadouts = 'Loadouts',
    suspenders = 'Suspenders', talisman_satchel = 'Talisman Satchel', satchels = 'Satchel',
    gunbelts = 'Gunbelt', belts = 'Belt', belt_buckles = 'Belt Buckle', holsters_left = 'Holster Left',
    holsters_right = 'Holster Right', talisman_wrist = 'Wrist Talisman', coats = 'Coat',
    coats_closed = 'Coat Closed', ponchos = 'Poncho', eyewear = 'Eyewear', gloves = 'Gloves',
    holsters_crossdraw = 'Crossdraw Holster', aprons = 'Aprons', skirts = 'Skirts',
    gunbelt_accs = 'Gunbelt Accessories', armor = 'Armor', neckerchiefs = 'Neckerchief',
    shirts_full_overpants = 'Shirt Over Pants', unionsuits_full = 'Union Suit',
    unionsuit_legs = 'Union Suit Legs', overalls_full = 'Overalls', overalls_modular_uppers = 'Overalls Top',
    overalls_modular_lowers = 'Overalls Bottom', vest_accessories = 'Vest Accessory',
    coat_accessories = 'Coat Accessory', pants_accessories = 'Pants Accessory',
    hat_accessories = 'Hat Accessory', hair_accessories = 'Hair Accessory', satchel_straps = 'Satchel Strap',
    jewelry_necklaces = 'Necklace', jewelry_earrings = 'Earrings', jewelry_rings = 'Rings',
    coats_heavy = 'Heavy Coat', masks_large = 'Large Mask', face_props = 'Face Prop', headwear = 'Headwear',
    holsters_center = 'Holster Center', holsters_quivers = 'Quiver', wrist_bindings = 'Wrist Wraps',
    ankle_bindings = 'Ankle Wraps', hair_bonnet = 'Bonnet', chemises = 'Chemise', corsets = 'Corset',
    knickers = 'Knickers', stockings = 'Stockings', shawls = 'Shawl', capes = 'Cape', dresses = 'Dress',
    eyewear2 = 'Eyewear 2',
}

Config.SlotNames = {
    pants = 'Pant', accessories = 'Accessories', belt_buckles = 'Buckle', boot_accessories = 'Spurs',
    belts = 'Belt', boots = 'Boots', chaps = 'Chap', skirts = 'Skirt', gunbelts = 'Gunbelt',
    coats_closed = 'CoatClosed', gunbelt_accs = 'GunbeltAccs', hair_accessories = 'bow', armor = 'armor',
    teeth = 'teeth', satchels = 'Satchels', loadouts = 'Loadouts', gauntlets = 'Gauntlets', spats = 'Spats',
    holsters_left = 'Holster', jewelry_rings_left = 'RingLh', jewelry_rings_right = 'RingRh', gloves = 'Glove',
    cloaks = 'Cloak', ponchos = 'Poncho', coats = 'Coat', vests = 'Vest', suspenders = 'Suspender',
    shirts_full = 'Shirt', neckties = 'NeckTies', neckwear = 'NeckWear', eyewear = 'EyeWear', masks = 'Mask',
    hats = 'Hat', jewelry_bracelets = 'Bracelet',
}

Config.BareBody = { pants = 'LegsType', boots = 'LegsType', shirts_full = 'BodyType' }

Config.Palettes = {
    0x0105607B, 0x17CBCC83, 0x29F81B2A, 0x3385C5DB, 0x37CD36D4,
    0x3F6E70FF, 0x4101ED87, 0x63838A81, 0x6765BC15, 0x8BA18876,
    0x9AC34F34, 0x9E4803A0, 0xA4041CEF, 0xA4CFABD0, 0xAA65D8A3,
    0xB562025C, 0xB9E7F722, 0xBBF43EF8, 0xD1476963, 0xD799E1C2,
    0xDC6BC93B, 0xDFB1F64C, 0xF509C745, 0xF93DB0C8, 0xFB71527B,
}

Config.ToggleCommands = {   -- command = category key
    coat = 'coats', coatclosed = 'coats_closed', heavycoat = 'coats_heavy', cloak = 'cloaks',
    poncho = 'ponchos', cape = 'capes', shawl = 'shawls', shirt = 'shirts_full',
    overshirt = 'shirts_full_overpants', vest = 'vests', corset = 'corsets', chemise = 'chemises',
    unionsuit = 'unionsuits_full', overalls = 'overalls_full', suspenders = 'suspenders', apron = 'aprons',
    hat = 'hats', bonnet = 'hair_bonnet', headwear = 'headwear', mask = 'masks', eyewear = 'eyewear',
    faceprop = 'face_props', neckwear = 'neckwear', necktie = 'neckties', neckerchief = 'neckerchiefs',
    necklace = 'jewelry_necklaces', gloves = 'gloves', gauntlets = 'gauntlets', bracelet = 'jewelry_bracelets',
    rings = 'jewelry_rings', wristwraps = 'wrist_bindings', pants = 'pants', skirt = 'skirts', gown = 'dresses',
    knickers = 'knickers', stockings = 'stockings', chaps = 'chaps', spats = 'spats', boots = 'boots',
    spurs = 'boot_accessories', anklewraps = 'ankle_bindings', belt = 'belts', buckle = 'belt_buckles',
    gunbelt = 'gunbelts', holster = 'holsters_left', satchel = 'satchels', armor = 'armor',
}
