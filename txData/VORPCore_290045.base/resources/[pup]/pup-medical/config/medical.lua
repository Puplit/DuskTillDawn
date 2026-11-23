-- pup-medical | doctors: revive, bandage, cabinets, back-alley syringe, recovery

Config.Keys.cabinet = 0xD9D0E1C0 -- [SPACE] open a cabinet

Config.Medical = {
    doctorJobs = { "doctor", "pharmacist" }, -- /med, cabinets, revive, bandage
    reviveItem = "syringe",
    healItem   = "bandage",

    -- revive with no item
    policeRevive = {
        enabled = false,
        jobs    = { "pharmacist", "doctor" },
    },

    -- shared storage for on-duty doctors, refilled to `stock` when opened
    cabinet = {
        name           = 'Medical Cabinet',
        limit          = 0, -- items it holds, 0 = unlimited
        restockMinutes = 0, -- 0 = refill on every open
        stock = {
            { item = 'syringe', amount = 100 },
        },
        locations = {
            vector3(-283.93, 811.56, 117.78),
            vector3(-3666.48, -2593.86, -13.48),   -- Armadillo
            vector3(-3734.05, -2629.9, -12.3),     -- Armadillo
            vector3(-1806.03, -428.94, 158.83),
            vector3(2721.31, -1233.65, 50.37),
            vector3(-781.352, -1314.000, 43.301),  -- Blackwater
            vector3(2652.1, -1182.1, 53.5),
            vector3(3369.36, -705.89, 45.38),      -- Siska
            vector3(2923.03, 1356.86, 44.58),
        },
    },

    -- black-market revive anyone can use; used up even when it fails
    illegalSyringe = {
        enabled     = true,
        item        = "illegalsyringe",
        reviveRange = 3.0,
        useTimeMs   = 10000,
        failChance  = 25, -- %
    },

    -- after any revive: no sprinting or weapons for a while
    recovery = {
        enabled         = true,
        durationSeconds = 30,
        effect          = "MP_Downed", -- screen effect, "" = none
    },
}
