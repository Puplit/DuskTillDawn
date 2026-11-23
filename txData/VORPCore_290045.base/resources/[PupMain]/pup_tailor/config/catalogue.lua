-- pup_tailor | what the tailor offers and how garments are named. Shared.

-- The 33 categories that are real inventory items, each wearable as a single garment.
Config.ItemCategories = {
    'pants', 'accessories', 'belt_buckles', 'boot_accessories', 'belts', 'boots',
    'chaps', 'skirts', 'gunbelts', 'hair_accessories', 'armor', 'coats_closed',
    'gunbelt_accs', 'satchels', 'loadouts', 'gauntlets', 'spats', 'holsters_left',
    'jewelry_rings_left', 'jewelry_rings_right', 'gloves', 'cloaks', 'ponchos',
    'coats', 'vests', 'suspenders', 'shirts_full', 'neckties', 'neckwear',
    'eyewear', 'masks', 'hats', 'jewelry_bracelets',
}

-- Singleplayer catalogue filters
Config.HiddenSPCategories = {
    heads = true, eyes = true, hair = true, bodies_upper = true, bodies_lower = true,
    beards_complete = true, beards_chin = true, beards_chops = true, beards_mustache = true,
    teeth = true, research_n1394906584 = true,
}
Config.HiddenSPDrawables = {}      -- single drawables never offered, e.g. { [-123456] = true }
Config.HideUnnamedCategories = false -- true also hides every research_* category

-- Multiplayer categories that are body parts, never offered
Config.BodyPartCategories = {
    heads = true, teeth = true, beards_complete = true, bodies_lower = true,
    bodies_upper = true, eyes = true, hair = true, [''] = true,
}

-- Display labels. A category without a label shows its raw key, and cannot be dyed.
Config.CategoryLabels = {
    pants = 'Pants', accessories = 'Accessories', belt_buckles = 'Buckle', boot_accessories = 'Spurs',
    belts = 'Belts', boots = 'Boots', chaps = 'Chaps', skirts = 'Skirts', gunbelts = 'Gunbelts',
    hair_accessories = 'Bows', armor = 'Armor', coats_closed = 'Closed Coats', gunbelt_accs = 'Gunbelt Accs',
    satchels = 'Satchels', loadouts = 'Loadouts', gauntlets = 'Gauntlets', spats = 'Spats',
    holsters_left = 'Holster', jewelry_rings_left = 'Ring Lh', jewelry_rings_right = 'Ring Rh',
    gloves = 'Gloves', cloaks = 'Cloaks', ponchos = 'Ponchos', coats = 'Coats', vests = 'Vests',
    suspenders = 'Suspenders', shirts_full = 'Shirts', neckties = 'NeckTies', neckwear = 'NeckWear',
    eyewear = 'EyeWear', masks = 'Masks', hats = 'Hats', jewelry_bracelets = 'Bracelets',
    neckerchiefs = 'Neckerchiefs', shirts_full_overpants = 'Shirts Over Pants', unionsuits_full = 'Union Suits',
    unionsuit_legs = 'Union Suit Legs', overalls_full = 'Overalls', overalls_modular_uppers = 'Overalls Tops',
    overalls_modular_lowers = 'Overalls Bottoms', vest_accessories = 'Vest Accessories',
    coat_accessories = 'Coat Accessories', pants_accessories = 'Pants Accessories',
    hat_accessories = 'Hat Accessories', satchel_straps = 'Satchel Straps', jewelry_necklaces = 'Necklaces',
    jewelry_earrings = 'Earrings', jewelry_rings = 'Rings', coats_heavy = 'Heavy Coats',
    masks_large = 'Large Masks', face_props = 'Face Props', headwear = 'Headwear',
    holsters_center = 'Center Holsters', holsters_quivers = 'Quivers', holsters_right = 'Holster Right',
    wrist_bindings = 'Wrist Wraps', ankle_bindings = 'Ankle Wraps', hair_bonnet = 'Bonnets',
    chemises = 'Chemises', corsets = 'Corsets', knickers = 'Knickers', stockings = 'Stockings',
    shawls = 'Shawls', capes = 'Capes', dresses = 'Dresses', aprons = 'Aprons', eyewear2 = 'Eyewear 2',
    underwear_top = 'Undergarment Top', underwear_bottom = 'Undergarment Bottom',
    ammo_rifles = 'Ammo Rifles', ammo_pistols = 'Ammo Pistols', badges = 'Badges',
    holsters_crossdraw = 'Crossdraw Holster', holsters_knife = 'Knife Holster',
    talisman_holster = 'Talisman Holster', talisman_belt = 'Talisman Belt',
    talisman_satchel = 'Talisman Satchel', talisman_wrist = 'Talisman Wrist',
    teeth = 'Teeth',
}

-- Unnamed research categories: labelled "<prefix> N<suffix>"
Config.ResearchLabelPrefix = 'Puppets New Addon '
Config.ResearchLabelSuffix = ' - Do Not Make'
Config.ResearchCategories = {
    'research_n126114541', 'research_1163341077', 'research_n562932933', 'research_246385598',
    'research_n510698175', 'research_1820468724', 'research_725125637', 'research_n372138959',
    'research_1799186100', 'research_1431760203', 'research_1524025505', 'research_n242465481',
    'research_425108158', 'research_1065202434', 'research_1397506638', 'research_n106096122',
    'research_n1087668073', 'research_1026208467', 'research_n2130987730', 'research_n1593369262',
    'research_923771890', 'research_n691549501', 'research_n1057211637', 'research_n390732739',
    'research_1650293524', 'research_300733975', 'research_1666268640', 'research_796023660',
    'research_306537471', 'research_2112357414', 'research_n1505611915', 'research_1404466585',
    'research_1250560851', 'research_539656276', 'research_n2087420491', 'research_n885414156',
    'research_n407765147', 'research_n668168749', 'research_1937338194', 'research_870584092',
    'research_1377798597', 'research_n396748211', 'research_452400678', 'research_n1250802524',
    'research_1093217135', 'research_n381968613', 'research_934639145', 'research_n597921511',
    'research_1122564391', 'research_n676459261', 'research_1018031031', 'research_2071466316',
    'research_n1136503325', 'research_1527726350', 'research_n885716670', 'research_1353811319',
    'research_584268482', 'research_1881452427', 'research_n321513900', 'research_n332108634',
    'research_n347372847', 'research_n1459825906', 'research_n1783800278', 'research_n1358949707',
    'research_692999710', 'research_1156892435', 'research_275767583', 'research_468881670',
    'research_n728330651', 'research_n1223513441', 'research_n1168358466', 'research_850630244',
    'research_1462771622', 'research_1515417123', 'research_n1254721609', 'research_513671579',
    'research_n12177793', 'research_828269641',
}
for i, key in ipairs(Config.ResearchCategories) do
    Config.CategoryLabels[key] = Config.CategoryLabels[key]
        or (Config.ResearchLabelPrefix .. i .. Config.ResearchLabelSuffix)
end

-- Category key -> outfit slot name (save format, never change). Others use the key itself.
Config.CategorySlot = {
    pants = 'Pant', accessories = 'Accessories', belt_buckles = 'Buckle', boot_accessories = 'Spurs',
    belts = 'Belt', boots = 'Boots', chaps = 'Chap', skirts = 'Skirt', gunbelts = 'Gunbelt',
    hair_accessories = 'bow', armor = 'armor', teeth = 'teeth', coats_closed = 'CoatClosed',
    gunbelt_accs = 'GunbeltAccs', satchels = 'Satchels', loadouts = 'Loadouts', gauntlets = 'Gauntlets',
    spats = 'Spats', holsters_left = 'Holster', jewelry_rings_left = 'RingLh', jewelry_rings_right = 'RingRh',
    gloves = 'Glove', cloaks = 'Cloak', ponchos = 'Poncho', coats = 'Coat', vests = 'Vest',
    suspenders = 'Suspender', shirts_full = 'Shirt', neckties = 'NeckTies', neckwear = 'NeckWear',
    eyewear = 'EyeWear', masks = 'Mask', hats = 'Hat', jewelry_bracelets = 'Bracelet',
}

-- Slot -> game category hash (first place looked)
Config.SlotCategoryHash = {
    Gunbelt = 0x9B2C8B89, Mask = 0x7505EF42, Holster = 0xB6B6122D, Loadouts = 0x83887E88,
    Coat = 0xE06D30CE, Cloak = 0x3C1A74CD, EyeWear = 0x5E47CA6, Bracelet = 0x7BC10759,
    Skirt = 0xA0E3AB7F, Poncho = 0xAF14310B, Spats = 0x514ADCEA, NeckTies = 0x7A96FACA,
    Spurs = 0x18729F39, Pant = 0x1D4C528A, Suspender = 0x877A2CF7, Glove = 0xEABE0032,
    Satchels = 0x94504D26, GunbeltAccs = 0xF1542D11, CoatClosed = 0x662AC34, Buckle = 0xFAE9107F,
    RingRh = 0x7A6BBD0B, Belt = 0xA6D134C6, Accessories = 0x79D7DF96, Shirt = 0x2026C46D,
    Gauntlets = 0x91CE9B20, Chap = 0x3107499B, NeckWear = 0x5FC29285, Boots = 0x777EC6EF,
    Vest = 0x485EE834, RingLh = 0xF16A1D23, Hat = 0x9925C067, Dress = 0xA2926F9B,
    Badge = 0x3F7F3587, armor = 0x72E6EF74, Armor = 0x72E6EF74, Hair = 0x864B03AE,
    Beard = 0xF8016BCA, bow = 0x8E84A2AA, Bow = 0x8E84A2AA,
}

-- Slot names vorp_character knows; only these reach the worn-clothing save.
Config.VorpSlots = {}
for _, s in ipairs({
    'Accessories', 'AmmoPistol', 'AmmoRifle', 'Apron', 'Armor', 'Badge', 'Beard', 'BeardsMustache', 'Belt', 'Blouses',
    'BodiesLower', 'BodiesUpper', 'Boots', 'Bow', 'Bracelet', 'Buckle', 'Chap', 'Cloak', 'Coat', 'CoatClosed',
    'CoatsHeavy', 'Dress', 'EyeBrows', 'Eyes', 'EyeWear', 'Gauntlets', 'Glove', 'Gunbelt', 'GunbeltAccs', 'Hair',
    'Hat', 'Heads', 'Holster', 'Loadouts', 'Mask', 'MaskLarge', 'NeckTies', 'NeckWear', 'Pant', 'Poncho',
    'RingLh', 'RingRh', 'Satchels', 'Scarves', 'Shirt', 'ShirtsFullOverpants', 'Skirt', 'Spats', 'Spurs', 'Stockings',
    'Suspender', 'TalismanBelt', 'TalismanHolster', 'TalismanWrist', 'Teeth', 'Vest',
}) do Config.VorpSlots[s] = true end

-- Lower-case slots also written under vorp_character's spelling
Config.VorpAliases = { armor = 'Armor', teeth = 'Teeth', bow = 'Bow' }

-- Keep Mask & Neckwear, and garments that cannot be worn together
Config.KeepSlots = { Mask = true, NeckWear = true }
Config.ConflictSlots = { Skirt = 'Pant', Pant = 'Skirt', CoatClosed = 'Coat', Coat = 'CoatClosed' }

-- Items that may dye their mask / neckwear slot
Config.MaskItems = { masks = true, pristine_masks = true }
Config.NeckwearItems = { neckwear = true, pristine_neckwear = true }

-- Fresh mannequin body
Config.Mannequin = {
    models = { male = 'mp_male', female = 'mp_female' },
    zDrop = 0.98,
    basePieces = {
        female = { 0x928DAD43, 0xAA25ECA7, 0x9D251F06 },
        male   = { 0xF6496128, 0x0A615E02, 0xF0FB1DF0 },
    },
    removeCategories = { 0x1D4C528A, 0x3F1F01E5, 0xDA0E2C55 },
    light = { range = 2.5, intensity = 10.0 },
}

Config.Anims = {
    unholster = { dict = 'mech_inventory@equip@fallback@base@satchel_item@rh@cylinder@d8-2_h10-5_inspecty@unarmed', clip = 'unholster' },
    change    = { dict = 'mech_inventory@clothing@outfit_change', clip = 'outfit_change_unarmed' },
}
