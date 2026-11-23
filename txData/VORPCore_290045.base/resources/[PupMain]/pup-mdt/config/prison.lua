-- pup-mdt | prison, cells, labour and the register board (shared)

Config.Prison = {
    autoJail = true,
    disarm = true,
    label = 'Sisika Prison',
    centre = vector3(3333.70, -700.04, 43.11),
    radius = 150.0,
    arrival = vector4(3333.70, -700.04, 43.11, 307.41),
    cellBlock = vector4(3351.42, -689.94, 43.11, 233.50),
    exit = vector4(2781.26, -1536.23, 48.44, 0.0),
    escapeGraceSeconds = 20,   -- no escape check right after a teleport
    syncSeconds = 60,          -- how often the remaining time is written to the database
    offlineCountdown = true,   -- true = a sentence keeps counting down while the prisoner is offline

    cells = {
        { label = 'Cell 1',   coords = vector4(3351.42, -689.94, 43.11, 233.5) },
        { label = 'Cell 2',   coords = vector4(3355.00, -692.00, 43.11, 233.5) },
        { label = 'Solitary', coords = vector4(3340.00, -695.00, 43.11, 180.0) },
    },

    -- local station cells: { label, coords = vector4, radius, exit = vector4 }. None in use.
    stations = {},

    register = {
        enabled = true,
        coords = vector4(3364.5, -667.15, 46.31, 297.47),
        promptDistance = 2.0,
        serverDistance = 15.0,
        maxRows = 50,
        blip = { enabled = false, label = 'Prison Register', sprite = 'blip_ambient_law', scale = 0.2 },
    },

    labour = {
        enabled = true,
        label = 'Wood Chopping',
        promptDistance = 1.8,
        serverDistance = 3.0,
        secondsOff = 600,
        maxUses = 3,
        floorMinutes = 15,
        cooldownSeconds = 2,
        minScenarioSeconds = 5,    -- a chop shorter than this is not rewarded
        maxScenarioSeconds = 180,  -- a pending chop older than this is dropped
        stumpModel = 'p_stumpwoodsplit02x',
        spots = {
            vector3(3368.75, -660.59, 46.37),
            vector3(3365.84, -657.99, 46.37),
            vector3(3365.30, -653.38, 46.37),
        },
        scenarioRadius = 2.0,
        scenarios = {
            'PROP_HUMAN_WOOD_CHOP', 'PROP_HUMAN_WOOD_CHOP_AND_SHARPEN_AXE',
            'PROP_HUMAN_WOOD_CHOP_AXESTUCK_01_02', 'PROP_HUMAN_WOOD_CHOP_AXESTUCK_03_04',
            'PROP_HUMAN_WOOD_CHOP_AXESTUCK_05_06', 'PROP_HUMAN_WOOD_CHOP_AXESTUCK_07_08',
            'PROP_HUMAN_WOOD_CHOP_AXESTUCK_09_10', 'PROP_HUMAN_WOOD_CHOP_CARRYLOG1_06_03_02',
            'PROP_HUMAN_WOOD_CHOP_CARRYLOG2_12_10_07', 'PROP_HUMAN_WOOD_CHOP_CHOP_FRONT',
            'PROP_HUMAN_WOOD_CHOP_CHOP_FRONT_LAST', 'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_01_02',
            'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_03_04', 'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_05_06',
            'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_07_08', 'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_09_08',
            'PROP_HUMAN_WOOD_CHOP_GRAB_LOG_11_12', 'PROP_HUMAN_WOOD_CHOP_LOGDROP1_06_03_02',
            'PROP_HUMAN_WOOD_CHOP_LOGDROP2_12_10_07', 'PROP_HUMAN_WOOD_CHOP_PICKUPLSIDE1',
            'PROP_HUMAN_WOOD_CHOP_PICKUPLSIDE2', 'PROP_HUMAN_WOOD_CHOP_PICKUPRSIDE1_01_05_04',
            'PROP_HUMAN_WOOD_CHOP_PICKUPRSIDE2_08_09_11', 'PROP_HUMAN_WOOD_CHOP_POST_CHOP_01_02',
            'PROP_HUMAN_WOOD_CHOP_POST_CHOP_03_04', 'PROP_HUMAN_WOOD_CHOP_POST_CHOP_05_06',
            'PROP_HUMAN_WOOD_CHOP_POST_CHOP_07_08', 'PROP_HUMAN_WOOD_CHOP_POST_CHOP_09_08',
            'PROP_HUMAN_WOOD_CHOP_POST_CHOP_11_12', 'PROP_HUMAN_WOOD_CHOP_POST_CHOP_11_12_PLAYER',
            'PROP_HUMAN_WOOD_CHOP_POST_CHOP_TO_WOODROP', 'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_01_02',
            'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_03_04', 'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_05_06',
            'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_07_08', 'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_09_08',
            'PROP_HUMAN_WOOD_CHOP_PRE_CHOP_11_12', 'PROP_HUMAN_WOOD_CHOP_SLING_GRAB',
        },
    },

    attackControls = {
        0x1E7D7275, 0xB5EEEFB7, 0x2277FAE9, 0xADEAF48C, 0x018C47CF, 0x91C9A817,
        0xD0C1FEFF, 0xBE1F4699, 0x67ED272E, 0xB2F377E8, 0x07CE1E61, 0xCEFD9220,
    },
}

Config.Keys = {
    interact = 0x760A9C6F,   -- G
    esc = 0x156F7119,
    backspace = 0x8CC9CD42,
}
