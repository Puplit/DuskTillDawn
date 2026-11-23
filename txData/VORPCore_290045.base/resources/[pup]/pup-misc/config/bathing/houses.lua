-- bathing | the bathhouses, keyed by town (the key is the occupancy key the
-- client sends). Loaded after config/bathing/main.lua.
--   dict     : the town's intro/outro anim-scene dictionary
--   rag      : rag position (vector3) and ragHeading
--   consumer : where the player stands to order a bath; also the blip
--   door     : bath-room door hash (locked here unless another script registered it)
--   landing  : where /exitbath and the exit spot put the player
--   exitSpot : optional trigger point and radius for the "press G" exit

BathhouseConfig.Houses = {
    SaintDenis = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_ST_DENIS',
        rag = vector3(2629.4, -1223.33, 58.57), ragHeading = -92.66,
        consumer = vector3(2632.6, -1223.79, 59.59),
        door = 779421929,
        landing = vector3(2632.84, -1223.89, 59.64),
        exitSpot = { at = vector3(2631.26, -1223.82, 59.64), radius = 1.0 },
    },
    Valentine = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_VALENTINE',
        rag = vector3(-317.37, 761.8, 116.44), ragHeading = 10.365,
        consumer = vector3(-320.56, 762.41, 117.44),
        door = 142240370,
        landing = vector3(-320.5, 762.26, 116.43),
        exitSpot = { at = vector3(-319.0, 762.52, 117.43), radius = 1.0 },
    },
    Strawberry = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_STRAWBERRY',
        rag = vector3(-1812.83, -373.23, 165.5), ragHeading = 1.206,
        consumer = vector3(-1816.45, -372.44, 166.50),
        door = 1256786197,
        landing = vector3(-1816.45, -372.44, 166.50),
    },
    Blackwater = {
        dict = 'script@mini_game@bathing@BATHING_INTRO_OUTRO_BLACKWATER',
        rag = vector3(-823.86, -1318.84, 42.68), ragHeading = -0.459,
        consumer = vector3(-822.82, -1315.72, 43.58),
        door = 1523300673,
        landing = vector3(-822.82, -1315.72, 43.58),
    },
}
