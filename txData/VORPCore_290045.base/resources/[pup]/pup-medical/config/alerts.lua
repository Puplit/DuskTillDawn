-- pup-medical | job alerts (/alertmedic, /alerttrain ...), the /alertmenu, and call pay

Config.Keys.alertAccept  = 0xD9D0E1C0 -- [SPACE] accept
Config.Keys.alertDeny    = 0x156F7119 -- deny
Config.Keys.alertBackOut = 0xD8F73058 -- back to the menu
Config.Keys.stationAlert = 0x43DBF61F -- send from a station

Config.Alerts = {
    requireOnDuty        = true,        -- responders must be on duty
    countSelfAsResponder = false,
    cancelCommand        = "calert",
    menuAlign            = "topcenter",
    noDoctorsNoLoss      = true,        -- nobody on duty: a dead sender respawns free
    freeRespawn = {                     -- unanswered this long: respawn free
        enabled     = true,
        waitMinutes = 10,
    },

    -- Alert types (fields in README.md). Keep the name "Medical": other code uses it.
    types = {
        Medical = {
            command        = "alertmedic",
            suggestion     = "Call for a doctor (works while you are down)",
            jobs           = { "doctor", "pharmacist" },
            mode           = "blip",
            blipSprite     = 2119977580,
            blipColor      = "BLIP_MODIFIER_MP_COLOR_1",
            radius         = 200.0,
            radiusColor    = "BLIP_MODIFIER_MP_COLOR_32",
            notifyJob      = "A patient needs a doctor. Open /alertmenu to answer",
            notifyPlayer   = "A doctor is coming from %",
            alertSent      = "Your call went out. Wait for a doctor to answer",
            deadCanUse     = true,
            stations       = {},
            promptDistance = 2,
            busyOnAccept   = true,
            log            = true,
        },

        TrainService = {
            command         = "alerttrain",
            suggestion      = "call a train (only at a train station)",
            jobs            = { "standardtrain" },
            mode            = "blip",
            blipSprite      = 2119977580,
            blipColor       = "BLIP_MODIFIER_MP_COLOR_3",
            notifyJob       = "someone is waiting for a train, do /alertmenu",
            notifyPlayer    = "a conductor is on the way from %",
            alertSent       = "your request was sent, wait until a conductor replies",
            deadCanUse      = false,
            -- blip = false: pup_railroad already marks the stations
            stations        = {
                { coords = vector3(-176.2, 628.27, 114.09),      blip = false, blipName = "Valentine Train Station" },
                { coords = vector3(2734.654, -1437.456, 45.815), blip = false, blipName = "SD Train Station" },
                { coords = vector3(-1095.6, -576.6, 82.45),      blip = false, blipName = "Riggs Train Station" },
                { coords = vector3(-880.65, -1244.34, 43.92),    blip = false, blipName = "Blackwater Train Station" },
                { coords = vector3(1229.50, -1298.20, 76.95),    blip = false, blipName = "Rhodes Train Station" },
                { coords = vector3(1523.527, 442.676, 90.728),   blip = false, blipName = "Emerald Train Station" },
                { coords = vector3(2939.029, 1280.700, 44.303),  blip = false, blipName = "Annesburg Train Station" },
                { coords = vector3(-3729.02, -2601.26, -12.93),  blip = false, blipName = "Armadillo Train Station" },
                { coords = vector3(-2494.85, -2437.45, 60.7),    blip = false, blipName = "McFarlanes Train Station" },
                { coords = vector3(-5230.2, -3468.1, -20.35),    blip = false, blipName = "Benedict Point Train Station" },
                { coords = vector3(582.49, 1681.31, 187.78),     blip = false, blipName = "Bacchus Train Station" },
                { coords = vector3(-1944.43, -1608.14, 116.69),  blip = false, blipName = "Manzanita Train Station" },
                { coords = vector3(-1299.4, 402.1, 95.39),       blip = false, blipName = "Wallace Train Station" },
            },
            stationDistance = 60.0,
            promptDistance  = 6,
            stationPrompt   = false,
            busyOnAccept    = true,
            log             = true,
        },
    },
}

-- responders are paid by distance travelled, once the job is done
Config.CallPay = {
    enabled          = true,
    jobs             = { doctor = true, pharmacist = true },
    minDistance      = 200.0,  -- at or below: minPay
    maxDistance      = 5000.0, -- at or above: maxPay
    minPay           = 30,
    maxPay           = 500,
    curve            = 1.5,    -- 1.0 = straight line
    variationPercent = 0.20,   -- +/- 20%
    variationFlat    = 0,
    completeDistance = 10.0,   -- metres from the patient to complete
    payOnHeal        = false,  -- a bandage also completes a call
    timeoutMinutes   = 30,
    currency         = 0,      -- 0 cash, 1 gold, 2 rol
}
