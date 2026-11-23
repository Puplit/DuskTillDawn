-- pup_gunsmith | gun store counters and their stock (see README)

Config.ShopCounters = {
    { id = 'Valentine',  name = 'Weapons Shop', coords = vector3(-279.52, 783.21, 119.52),      blip = false },
    { id = 'Strawberry', name = 'Weapons Shop', coords = vector3(-1840.928, -421.832, 161.935), blip = false },
    { id = 'Blackwater', name = 'Weapons Shop', coords = vector3(-833.56, -1265.21, 43.57),     blip = false },
    { id = 'Rhodes',     name = 'Weapons Shop', coords = vector3(1328.54, -1317.83, 77.94),     blip = false },
    { id = 'SaintD',     name = 'Weapons Shop', coords = vector3(2715.53, -1281.09, 49.63),     blip = false },
    { id = 'Annesburg',  name = 'Weapons Shop', coords = vector3(2944.70, 1318.51, 44.82),      blip = false },
    { id = 'Tumbleweed', name = 'Weapons Shop', coords = vector3(-5508.61, -2961.96, -0.64),    blip = false },
    { id = 'Armadillo',  name = 'Weapons Shop', coords = vector3(-3672.8, -2595.57, -13.34),    blip = false },
}

Config.ShopStock = {
    { kind = 'weapon', group = 'Starter Weapons', label = 'Carbine Repeater',     weapon = 'WEAPON_REPEATER_CARBINE',       price = 75 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Varmint Rifle',        weapon = 'WEAPON_RIFLE_VARMINT',          price = 30 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Cattleman Revolver',   weapon = 'WEAPON_REVOLVER_CATTLEMAN',     price = 25 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Bow',                  weapon = 'WEAPON_BOW',                    price = 9 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Knife',                weapon = 'WEAPON_MELEE_KNIFE',            price = 2 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Knives',               weapon = 'WEAPON_THROWN_THROWING_KNIVES', price = 9 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Fishing Rod',          weapon = 'WEAPON_FISHINGROD',             price = 5 },
    { kind = 'weapon', group = 'Starter Weapons', label = 'Lasso',                weapon = 'WEAPON_LASSO',                  price = 30 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Revolver Ammo Normal', item = 'ammorevolvernormal',              price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Repeater Ammo Normal', item = 'ammorepeaternormal',              price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Rifle Ammo Normal',    item = 'ammoriflenormal',                 price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Shotgun Ammo Normal',  item = 'ammoshotgunnormal',               price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Arrow Normal',         item = 'ammoarrmownormal',                price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Arrow Small Game',     item = 'ammoarrowsmallgame',              price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Varmint ammo',         item = 'ammovarmint',                     price = 1.5 },
    { kind = 'ammo',   group = 'Starter Ammo',    label = 'Knives ammo',          item = 'ammoknives',                      price = 4 },
}
