-- legendaryhunt | hunting grounds
-- zone   = the game's map zone name (district or region; the hash is worked out from the name)
-- label  = what the trap shows as "Ground"
-- beasts = ids from config/animals.lua that can answer a trap here. Which one comes depends on
--          the lure and the hour; the first id in the list that fits both wins.
-- A district listed here takes priority over the region around it (Lagras wins over Bluewater Marsh).

Config.Grounds = {
    -- the high north
    { zone = 'GrizzliesWest',        label = 'Grizzlies West',     beasts = { 1, 48, 6 } },
    { zone = 'P_4_LAKE_ISABELLA',    label = 'Lake Isabella',      beasts = { 52, 33 } },
    { zone = 'P_4_COTORRA_SPRINGS',  label = 'Cotorra Springs',    beasts = { 2, 57 } },
    { zone = 'P_3_BARROW_LAGOON',    label = 'Barrow Lagoon',      beasts = { 53, 34 } },
    { zone = 'P_4_DONNER_FALLS',     label = 'Donner Falls',       beasts = { 7, 24 } },
    { zone = 'GrizzliesEast',        label = 'Grizzlies East',     beasts = { 3, 49, 58 } },
    { zone = 'P_4_CALUMET_RAVINE',   label = 'Calumet Ravine',     beasts = { 8, 25 } },
    { zone = 'P_5_BRANDYWINE_DROP',  label = 'Brandywine Drop',    beasts = { 4, 54 } },
    { zone = 'P_4_BEARTOOTH_BECK',   label = 'Beartooth Beck',     beasts = { 5, 50 } },

    -- forests and ridges of the east
    { zone = 'roanoke',              label = 'Roanoke Ridge',      beasts = { 10, 43, 35 } },
    { zone = 'P_3_ROANOKE_VALLEY',   label = 'Roanoke Valley',     beasts = { 44, 26 } },
    { zone = 'Cumberland',           label = 'Cumberland Forest',  beasts = { 46, 11, 37 } },

    -- the open middle
    { zone = 'Heartlands',           label = 'The Heartlands',     beasts = { 62, 65, 20 } },
    { zone = 'P_3_HEARTLAND_OVERFLOW', label = 'Heartland Overflow', beasts = { 36, 21 } },
    { zone = 'P_3_DEWBERRY_CREEK',   label = 'Dewberry Creek',     beasts = { 45 } },

    -- swamps and southern fields
    { zone = 'BluewaterMarsh',       label = 'Bluewater Marsh',    beasts = { 28, 17 } },
    { zone = 'P_4_LAGRAS',           label = 'Lagras',             beasts = { 29, 32 } },
    { zone = 'BayouNwa',             label = 'Bayou Nwa',          beasts = { 30, 18, 41 } },
    { zone = 'P_3_LAKAY',            label = 'Lakay',              beasts = { 31 } },
    { zone = 'scarlettMeadows',      label = 'Scarlett Meadows',   beasts = { 38, 39, 42 } },
    { zone = 'P_3_SOUTHFIELD_FLATS', label = 'Southfield Flats',   beasts = { 40, 47 } },
    { zone = 'P_3_MATTOCK_POND',     label = 'Mattock Pond',       beasts = { 19 } },

    -- the west
    { zone = 'bigvalley',            label = 'Big Valley',         beasts = { 59, 51, 12 } },
    { zone = 'P_3_OWANJILA',         label = 'Lake Owanjila',      beasts = { 22, 55 } },
    { zone = 'TallTrees',            label = 'Tall Trees',         beasts = { 9, 13, 14, 27 } },
    { zone = 'greatPlains',          label = 'Great Plains',       beasts = { 56, 63, 66 } },

    -- the desert
    { zone = 'GaptoothRidge',        label = 'Gaptooth Ridge',     beasts = { 15, 60 } },
    { zone = 'ChollaSprings',        label = 'Cholla Springs',     beasts = { 23, 61 } },
    { zone = 'HennigansStead',       label = "Hennigan's Stead",   beasts = { 64 } },
}
