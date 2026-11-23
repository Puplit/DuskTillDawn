-- bathing | settings, loaded on both sides. The server takes Prices and the
-- distances from here; the client reads everything.

BathhouseConfig = {}

-- dollars, cash. The deluxe service is charged on top of the bath.
BathhouseConfig.Prices = {
    regular = 1.99,
    deluxe  = 5.47,
}

-- prompts: id, control (hash or input name, default PromptDefaults.control),
-- hold in ms (default PromptDefaults.hold), price (a Prices key shown in the label).
-- The scrub prompt's control is also the key held down to scrub.
BathhouseConfig.PromptDefaults = { control = 0xDFF812F9, hold = 1000 } -- E
BathhouseConfig.Prompts = {
    { id = 'start',  price = 'regular' },
    { id = 'scrub',  control = 'INPUT_CONTEXT_X', hold = 2000 },
    { id = 'deluxe', price = 'deluxe' },
    { id = 'exit',   control = 'INPUT_INTERACT_NEG' },
}

-- scrub order. state = move-network state, speed = scrub_freq signal,
-- deluxe = the attendant scrubs this part (others are skipped while she is there),
-- step = progress per 100 ms tick while held (default DefaultStep),
-- zone = damage-decal zone cleared when the part is finished.
BathhouseConfig.DefaultStep = 0.01
BathhouseConfig.BodyParts = {
    { state = 'Scrub_Head',      speed = 0.75, deluxe = false, zone = 1 },
    { state = 'Scrub_Left_Arm',  speed = 0.7,  deluxe = true,  zone = 2 },
    { state = 'Scrub_Right_Arm', speed = 0.5,  deluxe = true,  zone = 3 },
    { state = 'Scrub_Right_Leg', speed = 0.6,  deluxe = true,  zone = 5 },
    { state = 'Scrub_Left_Leg',  speed = 0.7,  deluxe = true,  zone = 4 },
}
BathhouseConfig.AllZones = 10 -- decal zone meaning "everywhere", used by the final clean

BathhouseConfig.Distances = {
    prompt      = 1.0,  -- client: start prompt shows this close to a consumer point
    serverStart = 5.0,  -- server: a start request must come from this close
    clientLeave = 25.0, -- client: farther than this from the consumer point ends the bath
    serverLeave = 30.0, -- server: farther than this frees the bathhouse
}

BathhouseConfig.ExitKey = 0x760A9C6F -- G, used at the exit spots

BathhouseConfig.Commands = {
    exit     = 'exitbath', -- player command: leave the bath from anywhere in it
    dress    = 'rc',       -- vorp_character's reload command
    stopAnim = 'sa',       -- stop-animation command, run by the emergency exit
}

BathhouseConfig.Blip = {
    style  = 0xB04092F8,
    sprite = 'blip_bath_house',
    spacingMs = 10,
}

BathhouseConfig.Attendants = {
    forMale   = 'CS_BATHINGLADIES_01', -- sent to a male character
    forFemale = 'CS_LeviSimon',        -- sent to a female character
    heightAbove = 5.0,                 -- spawned this far above the player, the scene places it
}

BathhouseConfig.Rag = 'P_CS_RAG02X'

-- game assets, by name; the game depends on these exact names
BathhouseConfig.Assets = {
    dicts = {
        'MINI_GAMES@BATHING@REGULAR@ARTHUR',
        'MINI_GAMES@BATHING@REGULAR@RAG',
        'MINI_GAMES@BATHING@DELUXE@ARTHUR',
        'MINI_GAMES@BATHING@DELUXE@MAID',
    },
    clipsets = {
        regularPlayer = 'CLIPSET@MINI_GAMES@BATHING@REGULAR@ARTHUR',
        regularRag    = 'CLIPSET@MINI_GAMES@BATHING@REGULAR@RAG',
        deluxePlayer  = 'CLIPSET@MINI_GAMES@BATHING@DELUXE@ARTHUR',
        deluxeMaid    = 'CLIPSET@MINI_GAMES@BATHING@DELUXE@MAID',
    },
    networks = {
        regular = 'Script_Mini_Game_Bathing_Regular',
        deluxe  = 'Script_Mini_Game_Bathing_Deluxe',
    },
    clipsetVariable = 'DEFAULT',
    startState      = 'BATHING',
    scenes = {
        regularIntro = 's_regular_intro',
        regularOutro = 's_regular_outro',
        deluxeIntro  = 's_deluxe_intro',
        deluxeOutro  = 's_deluxe_outro',
    },
    roles = { player = 'ARTHUR', door = 'Door', attendant = 'Female' },
    music = { start = 'MG_BATHING_START', stop = 'MG_BATHING_STOP' },
    knock = { name = 'BATHING_DOOR_KNOCK_MASTER', set = 0 }, -- set = 0 passes no sound set
}

BathhouseConfig.Timings = {
    orderLoopMs       = 100,   -- start-prompt loop
    farExtraMs        = 250,   -- added when no consumer point is near
    afterRequestMs    = 500,
    replyTimeoutMs    = 8000,  -- no answer from the server: give the prompt back
    assetTimeoutMs    = 10000,
    sceneLoadTimeoutMs = 10000,
    sceneMaxMs        = 90000, -- a scene that never finishes is given up after this
    undressAt         = 0.3,   -- progress of the intro scene
    dressAt           = 0.35,  -- progress of the outro scene
    camEaseMs         = 500,
    tubTickMs         = 10,
    readyPollMs       = 100,
    transitionRetryMs = 200,
    transitionTimeoutMs = 5000,
    scrubTickMs       = 100,
    restRetryMs       = 500,
    restTimeoutMs     = 10000,
    deluxeFinishPauseMs = 750,
    knockLeadMs       = 1000,
    afterDressMs      = 1500,  -- rc rebuilds the ped; wait before touching it again
    reviveWaitMs      = 900000, -- after dying in the bath, dress once alive again within this
    tipMs             = 5000,
    requestGapMs      = 1000,  -- server: minimum gap between a player's requests
    sweepMs           = 10000, -- server: how often held bathhouses are checked
}
