-- pup_railroad | track junctions the train driver can switch
--
-- When a company train comes within Config.Reach.junctionPrompt metres of one of these points,
-- heading the right way, the driver gets "Switch Left" / "Switch Right" prompts. Every player sees
-- the same switch positions.
--
-- HOW TO ADD A JUNCTION
--   1. Drive a train up to the switch and stop just before it, facing the way you want the prompt.
--   2. Note your position (x, y, z) and your heading in degrees.
--   3. Find the track and the junction number (see "Finding the track and junction" below).
--   4. Copy a line from the list, paste it AT THE END of the list (just above the closing } ),
--      and fill in your values.
--   5. Restart pup_railroad and test both buttons. If left and right are the wrong way round,
--      swap the two numbers in switchLeft / switchRight.
--
-- THE FIELDS
--   position     where the switch is: vector3(x, y, z)
--   facing       the train's heading must be between min and max (degrees) for the prompts to show.
--                Keep the range tight (10-20 degrees) so trains going the other way get no prompt.
--                It may run past 360: { min = 355, max = 365 } covers 355 to 5.
--   track        which track the switch is on: one of the names in Tracks below
--   junction     the switch's number on that track (the game numbers them per track, from 0)
--   switchLeft   value set when the driver presses Switch Left  (0 or 1)
--   switchRight  value set when the driver presses Switch Right (0 or 1) - normally the opposite
--
-- RULES
--   * An entry's place in the list is its id: ALWAYS add new junctions at the end and never move
--     or delete lines in the middle. To switch one off, put -- in front of it instead.
--   * Two entries closer than ~50 m to each other fight over the prompt; the nearest one wins.
--
-- FINDING THE TRACK AND JUNCTION
--   The track hashes are the game's train track configs (list in femga/rdr3_discoveries, "trains").
--   Junction numbers have to be found by trial: put the switch on the track you think it is, try
--   numbers from 0 up, and watch which points move.

--------------------------------------------------------------------------------
-- Track names. Add a new track here once, then use its name in the list.
--------------------------------------------------------------------------------
local Tracks = {
    TRAINS3                    = 1499637393,
    TRAINS_NB1                 = -1242669618,
    FREIGHT_GROUP              = -705539859,
    TRAINS_OLD_WEST03          = -1467515357,
    BRAITHWAITES2_TRACK_CONFIG = -760570040,
    TRAINS_INTERSECTION1_ANN   = -154412807,
    TRAINS_OLD_WEST02          = -1763976500,

    -- SPOONI ADD-ON TRACKS (PAID). These tracks only exist on servers that run Spooni's track
    -- add-on maps, which every server owner has to buy from Spooni themselves - they are NOT
    -- included with this resource. Without them the junctions further down that use these
    -- tracks simply do nothing.
    SPOONI_TRACK_A             = -1940325321,
    SPOONI_TRACK_B             = -988268728,
    SPOONI_TRACK_C             = 1983893509,
}

local junctions = {
    ----------------------------------------------------------------------------
    -- Base game track (works on every server)
    ----------------------------------------------------------------------------
    -- TRAINS3
    { position = vector3(1692.86, 544.329, 97.7636),    facing = { min =  90, max = 120 }, track = Tracks.TRAINS3,       junction =  1, switchLeft = 1, switchRight = 0 }, -- id 1
    { position = vector3(1481.54, 648.331, 91.4573),    facing = { min = 225, max = 235 }, track = Tracks.TRAINS3,       junction =  2, switchLeft = 0, switchRight = 1 }, -- id 2
    { position = vector3(613.963, 683.593, 114.517),    facing = { min = 100, max = 120 }, track = Tracks.TRAINS3,       junction =  3, switchLeft = 1, switchRight = 0 }, -- id 3
    { position = vector3(357.959, 596.374, 115.6759),   facing = { min = 310, max = 327 }, track = Tracks.TRAINS3,       junction =  4, switchLeft = 0, switchRight = 1 }, -- id 4
    { position = vector3(31.4046, -29.3296, 102.485),   facing = { min = 150, max = 160 }, track = Tracks.TRAINS3,       junction =  5, switchLeft = 1, switchRight = 0 }, -- id 5

    -- TRAINS_NB1
    { position = vector3(2748.47, -1434.33, 45.0192),   facing = { min = 129, max = 141 }, track = Tracks.TRAINS_NB1,    junction =  1, switchLeft = 0, switchRight = 1 }, -- id 6
    { position = vector3(2654.2, -1477.18, 44.93155),   facing = { min = 269, max = 279 }, track = Tracks.TRAINS_NB1,    junction =  2, switchLeft = 1, switchRight = 0 }, -- id 7
    { position = vector3(2624.16, -1477.2, 45.1535),    facing = { min =  89, max =  95 }, track = Tracks.TRAINS_NB1,    junction =  3, switchLeft = 1, switchRight = 0 }, -- id 8

    -- FREIGHT_GROUP
    { position = vector3(69.6194, -375.174, 90.0691),   facing = { min =  58, max =  62 }, track = Tracks.FREIGHT_GROUP, junction =  1, switchLeft = 0, switchRight = 1 }, -- id 9
    { position = vector3(-281.055, -319.6095, 88.1831), facing = { min = 294, max = 300 }, track = Tracks.FREIGHT_GROUP, junction =  2, switchLeft = 1, switchRight = 0 }, -- id 10
    { position = vector3(556.65, 1725.99, 186.968),     facing = { min = 225, max = 235 }, track = Tracks.FREIGHT_GROUP, junction =  7, switchLeft = 0, switchRight = 1 }, -- id 11
    { position = vector3(610.22, 1662.17, 186.543),     facing = { min =  25, max =  45 }, track = Tracks.FREIGHT_GROUP, junction =  8, switchLeft = 1, switchRight = 0 }, -- id 12
    { position = vector3(3032.64, 1482.22, 48.7368),    facing = { min = 120, max = 145 }, track = Tracks.FREIGHT_GROUP, junction = 10, switchLeft = 0, switchRight = 1 }, -- id 13
    { position = vector3(2873.65, 1199.61, 44.2112),    facing = { min = 313, max = 335 }, track = Tracks.FREIGHT_GROUP, junction = 11, switchLeft = 1, switchRight = 0 }, -- id 14
    { position = vector3(2659.79, -435.711, 42.5659),   facing = { min =   0, max =  10 }, track = Tracks.FREIGHT_GROUP, junction = 13, switchLeft = 1, switchRight = 0 }, -- id 15
    { position = vector3(2855.28, -1314.74, 45.1157),   facing = { min = 128, max = 141 }, track = Tracks.FREIGHT_GROUP, junction = 15, switchLeft = 0, switchRight = 1 }, -- id 16
    { position = vector3(2588.54, -1482.19, 45.2241),   facing = { min = 265, max = 275 }, track = Tracks.FREIGHT_GROUP, junction = 18, switchLeft = 1, switchRight = 0 }, -- id 17
    { position = vector3(2520.46, -1482.19, 45.1254),   facing = { min =  80, max =  95 }, track = Tracks.FREIGHT_GROUP, junction = 19, switchLeft = 0, switchRight = 1 }, -- id 18

    -- TRAINS_OLD_WEST03
    { position = vector3(-4916.56, -3009.53, -19.1817), facing = { min = 200, max = 215 }, track = Tracks.TRAINS_OLD_WEST03, junction = 0, switchLeft = 1, switchRight = 0 }, -- id 19
    { position = vector3(-4951.81, -3083.8, -18.43235), facing = { min = 270, max = 290 }, track = Tracks.TRAINS_OLD_WEST03, junction = 5, switchLeft = 1, switchRight = 0 }, -- id 20

    -- BRAITHWAITES2_TRACK_CONFIG
    { position = vector3(1529.94, 467.529, 89.3801),    facing = { min = 350, max = 360 }, track = Tracks.BRAITHWAITES2_TRACK_CONFIG, junction = 1, switchLeft = 1, switchRight = 0 }, -- id 21
    { position = vector3(2464.55, -1475.74, 45.1397),   facing = { min = 245, max = 270 }, track = Tracks.BRAITHWAITES2_TRACK_CONFIG, junction = 5, switchLeft = 1, switchRight = 0 }, -- id 22

    -- TRAINS_INTERSECTION1_ANN
    { position = vector3(2940.86, 1374.45, 43.0859),    facing = { min = 155, max = 165 }, track = Tracks.TRAINS_INTERSECTION1_ANN, junction = 1, switchLeft = 1, switchRight = 0 }, -- id 23
    { position = vector3(2885.57, 1227.62, 43.845),     facing = { min = 335, max = 345 }, track = Tracks.TRAINS_INTERSECTION1_ANN, junction = 2, switchLeft = 0, switchRight = 1 }, -- id 24

    -- TRAINS_OLD_WEST02
    { position = vector3(-2214.41, -2519.54, 64.8763),  facing = { min = 245, max = 255 }, track = Tracks.TRAINS_OLD_WEST02, junction = 1, switchLeft = 1, switchRight = 0 }, -- id 25
    { position = vector3(-4848.95, -3086.33, -16.5875), facing = { min =  70, max =  80 }, track = Tracks.TRAINS_OLD_WEST02, junction = 6, switchLeft = 1, switchRight = 0 }, -- id 26

    ----------------------------------------------------------------------------
    -- SPOONI ADD-ON TRACK (PAID - NOT INCLUDED)
    -- Everything from here to the end of this block needs Spooni's track add-on maps on the
    -- server. Each server owner has to buy those from Spooni. Without them these switches do
    -- nothing, but leave the lines in place: removing them would change the ids of anything
    -- added after them.
    ----------------------------------------------------------------------------
    { position = vector3(-948.539978, -636.039978, 72.040001),   facing = { min =  90, max = 100 }, track = Tracks.FREIGHT_GROUP,     junction = 3, switchLeft = 1, switchRight = 0 }, -- id 27 (Spooni)
    { position = vector3(-1049.660034, -613.780029, 75.739998),  facing = { min = 200, max = 240 }, track = Tracks.FREIGHT_GROUP,     junction = 4, switchLeft = 0, switchRight = 1 }, -- id 28 (Spooni)
    { position = vector3(-1008.159973, -699.150024, 65.419998),  facing = { min = 355, max = 365 }, track = Tracks.SPOONI_TRACK_A,    junction = 1, switchLeft = 1, switchRight = 0 }, -- id 29 (Spooni)
    { position = vector3(-1007.859985, -1001.849976, 60.419998), facing = { min = 170, max = 180 }, track = Tracks.SPOONI_TRACK_A,    junction = 2, switchLeft = 0, switchRight = 1 }, -- id 30 (Spooni)
    { position = vector3(-953.760010, -1110.369995, 52.209999),  facing = { min =  20, max =  60 }, track = Tracks.SPOONI_TRACK_A,    junction = 3, switchLeft = 1, switchRight = 0 }, -- id 31 (Spooni)
    { position = vector3(-1627.420044, -2326.340088, 44.330002), facing = { min =   1, max =  15 }, track = Tracks.SPOONI_TRACK_B,    junction = 2, switchLeft = 1, switchRight = 0 }, -- id 32 (Spooni)
    { position = vector3(-2510.020020, -2372.770020, 60.020000), facing = { min = 345, max = 365 }, track = Tracks.TRAINS_OLD_WEST02, junction = 2, switchLeft = 0, switchRight = 1 }, -- id 33 (Spooni)
    { position = vector3(-1062.650024, -1087.280029, 60.799999), facing = { min = 280, max = 300 }, track = Tracks.SPOONI_TRACK_C,    junction = 1, switchLeft = 1, switchRight = 0 }, -- id 34 (Spooni)
    { position = vector3(-1307.260010, -291.260010, 100.098000), facing = { min =   1, max =  12 }, track = Tracks.FREIGHT_GROUP,     junction = 5, switchLeft = 1, switchRight = 0 }, -- id 35 (Spooni)
    { position = vector3(-1375.640015, -137.359009, 100.038002), facing = { min = 205, max = 225 }, track = Tracks.FREIGHT_GROUP,     junction = 6, switchLeft = 1, switchRight = 0 }, -- id 36 (Spooni)

    ----------------------------------------------------------------------------
    -- YOUR NEW JUNCTIONS GO HERE (copy a line from above and change the values)
    ----------------------------------------------------------------------------

}

--------------------------------------------------------------------------------
-- Nothing to edit below: this turns the list above into the shape the code reads.
--------------------------------------------------------------------------------
Config.Junctions = {}
for i, j in ipairs(junctions) do
    if not j.track then
        print(('^1[pup_railroad]^7 junction %d has no track (misspelt track name?) - it is skipped'):format(i))
    end
    Config.Junctions[i] = {
        pos     = j.position,
        heading = { j.facing.min, j.facing.max },
        track   = j.track or 0,
        index   = j.junction,
        left    = j.switchLeft,
        right   = j.switchRight,
    }
end
