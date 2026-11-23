-- pup-hotel | hotels and their rooms
-- One entry per hotel, keyed by hotel id. Fields and an example are in README.md.

Config.Hotels = {
    chav = {
        label  = 'Saint Denis Hotel',
        desk   = vector3(2764.675, -1335.949, 46.114),
        office = vector3(2761.622, -1336.604, 46.110),
        -- its room doors need the Chevalier hotel interior (see README); show the blip once it is installed
        blip   = { show = false, sprite = -1282792512, name = 'Hotel' },
        rooms  = {
            { id = 'room_12', label = 'Room 12', tier = 'basic',
              door = 'chav_hotel_room_12', coords = vector3(2749.854, -1353.306, 51.987) },
            { id = 'room_14', label = 'Room 14', tier = 'basic',
              door = 'chav_hotel_room_14', coords = vector3(2745.538, -1357.561, 51.987) },
            { id = 'room_15', label = 'Room 15', tier = 'basic',
              door = 'chav_hotel_room_15', coords = vector3(2741.280, -1361.841, 51.987) },
            { id = 'room_16', label = 'Room 16', tier = 'vip',
              door = 'chav_hotel_room_16', coords = vector3(2758.187, -1338.801, 56.217) },
            { id = 'room_17', label = 'Room 17', tier = 'vip',
              door = 'chav_hotel_room_17', coords = vector3(2760.550, -1339.053, 56.217) },
            { id = 'room_18', label = 'Room 18', tier = 'vip',
              door = 'chav_hotel_room_18', coords = vector3(2763.198, -1340.885, 56.217) },
        },
    },
}
