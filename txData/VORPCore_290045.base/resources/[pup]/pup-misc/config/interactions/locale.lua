-- pup-misc/interactions | player-facing text
-- Keep every %s / %d / %.1f: the code fills them in.

InteractionsLocale = {
    -- menu headings
    title        = 'Take a Moment',
    subtitle     = 'What would you like to do?',
    pickSeat     = 'Pick a spot',
    pickAction   = 'Pick what to do',
    withCount    = '%s (%d)',        -- %s = a name, %d = how many choices it holds
    takeSide     = '%s side.',       -- %s = sideLeft / sideRight
    distanceAway = '%.1f m away.',   -- %.1f = metres from the player
    sideLeft     = 'Left',
    sideRight    = 'Right',
    hereDesc     = 'Right where you stand.',   -- rows that need no object (dance)

    -- Five Finger Fillet row (only when InteractionsConfig.Fillet.enabled is on)
    fff     = 'Five Finger Fillet',
    fffDesc = 'Pull up to the table and test your nerve with a knife.',

    -- categories
    catSit        = 'Sit',
    catSitDesc    = 'Chairs, stools, benches and couches close by.',
    catRest       = 'Lie down',
    catRestDesc   = 'Beds, cots and bedrolls close by.',
    catPiano      = 'Piano',
    catPianoDesc  = 'Take the stool and play something.',
    catBathe      = 'Bathe',
    catBatheDesc  = 'Climb into the tub and wash the trail off.',
    catDance      = 'Dance',
    catDanceDesc  = 'Dance right where you stand.',

    -- what a spot is called in the spot list
    typePiano = 'Piano',
    typeBed   = 'Bed',
    typeBath  = 'Bathtub',
    typeDance = 'Right here',
    typeBench = 'Bench',
    typeChair = 'Chair',

    -- the prompt shown while in a pose
    promptGroup = 'Taking it easy',
    exit        = 'Get up',
    exitDance   = 'Stop dancing',

    -- one menu row per scenario (keyed by scenario name) or anim (keyed by its id)
    actions = {
        -- sitting
        GENERIC_SEAT_BENCH_SCENARIO                   = 'Sit down',
        GENERIC_SEAT_CHAIR_SCENARIO                   = 'Lean back',
        GENERIC_SEAT_CHAIR_TABLE_SCENARIO             = 'Sit up to the table',
        MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_DRINKING = 'Sip from a bottle',
        MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_SMOKING  = 'Have a smoke',
        MP_LOBBY_PROP_HUMAN_SEAT_CHAIR                = 'Lounge',
        MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS   = 'Spin a knife, looking mean',
        MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_WHITTLE        = 'Whittle a stick',
        PROP_CAMP_FIRE_SEAT_CHAIR                     = 'Warm your hands',
        PROP_HUMAN_CAMP_FIRE_SEAT_BOX                 = 'Hunch forward',
        PROP_HUMAN_SEAT_BENCH_CONCERTINA              = 'Play the concertina',
        PROP_HUMAN_SEAT_BENCH_FIDDLE                  = 'Play the fiddle',
        PROP_HUMAN_SEAT_BENCH_JAW_HARP                = 'Play the jaw harp',
        PROP_HUMAN_SEAT_BENCH_MANDOLIN                = 'Play the mandolin',
        PROP_HUMAN_SEAT_CHAIR                         = 'Sit up straight',
        PROP_HUMAN_SEAT_CHAIR_BANJO                   = 'Play the banjo',
        PROP_HUMAN_SEAT_CHAIR_CIGAR                   = 'Smoke a cigar',
        PROP_HUMAN_SEAT_CHAIR_CLEAN_RIFLE             = 'Clean a rifle',
        PROP_HUMAN_SEAT_CHAIR_CLEAN_SADDLE            = 'Oil a saddle',
        PROP_HUMAN_SEAT_CHAIR_CRAB_TRAP               = 'Mend a crab trap',
        PROP_HUMAN_SEAT_CHAIR_GROOMING_GROSS          = 'Tidy up, roughly',
        PROP_HUMAN_SEAT_CHAIR_GROOMING_POSH           = 'Tidy up, neatly',
        PROP_HUMAN_SEAT_CHAIR_GUITAR                  = 'Play the guitar',
        PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS            = 'Toy with a knife',
        PROP_HUMAN_SEAT_CHAIR_KNITTING                = 'Knit',
        PROP_HUMAN_SEAT_CHAIR_PORCH                   = 'Put your feet up',
        PROP_HUMAN_SEAT_CHAIR_READING                 = 'Read a book',
        PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING          = 'Drink at the table',
        PROP_HUMAN_SEAT_CHAIR_DRINKING                = 'Nurse a drink',
        PROP_HUMAN_SEAT_CHAIR_FAN                     = 'Fan yourself',
        PROP_HUMAN_SEAT_BENCH_HARMONICA               = 'Play the harmonica',

        -- lying down
        PROP_HUMAN_SLEEP_BED_PILLOW      = 'Sleep',
        PROP_HUMAN_SLEEP_BED_PILLOW_HIGH = 'Sleep propped up',
        WORLD_HUMAN_SIT_FALL_ASLEEP      = 'Nod off sitting up',
        WORLD_HUMAN_SLEEP_GROUND_ARM     = 'Sleep on your arm',
        WORLD_HUMAN_SLEEP_GROUND_PILLOW  = 'Curl up and sleep',
        WORLD_PLAYER_SLEEP_BEDROLL       = 'Turn in for the night',
        WORLD_PLAYER_SLEEP_GROUND        = 'Stretch out',

        -- piano
        PROP_HUMAN_ABIGAIL_PIANO = 'Play the piano',
        PROP_HUMAN_PIANO         = 'Play the piano',

        -- bath
        bath_soak      = 'Soak',
        bath_left_arm  = 'Scrub your left arm',
        bath_left_leg  = 'Scrub your left leg',
        bath_right_arm = 'Scrub your right arm',
        bath_right_leg = 'Scrub your right leg',

        -- dance
        dance_sway         = 'Gentle sway',
        dance_twirl        = 'Twirl',
        dance_acrobat      = 'Acrobatics',
        dance_cancan_1     = 'Cancan',
        dance_cancan_2     = 'Cancan kicks',
        dance_flourish     = 'Stage flourish',
        dance_showgirl     = 'Showgirl',
        dance_fire         = 'Fire dance',
        dance_performer    = 'Showman',
        dance_snake_slow   = 'Snake dance, slow',
        dance_snake_fast   = 'Snake dance, quick',
        dance_sword        = 'Sword dance',
        dance_tipsy_cancan = 'Tipsy cancan',
        dance_limp_sway    = 'Floppy sway',
        dance_prayer       = 'Prayerful sway',
        dance_weepy        = 'Weepy shuffle',
        dance_stagger      = 'Wounded stagger',
        dance_jig          = 'Prospector jig',
    },
}
