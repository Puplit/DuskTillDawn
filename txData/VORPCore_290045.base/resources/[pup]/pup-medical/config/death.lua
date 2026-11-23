-- pup-medical | death screen, respawn and what a respawn costs

Config.Keys.respawn = 0xE30CD707 -- [R] hold to respawn

Config.Death = {
    -- losses only apply in water, or when a medic is on duty and the player wasn't told "no doctors"
    loss = {
        items   = true,
        weapons = true,
        cash    = false,
        gold    = false,
        rol     = false,
    },
    lawJobs     = { "police", "marshal" }, -- never lose weapons
    keepWeapons = { "WEAPON_MELEE_HAMMER", "WEAPON_MELEE_MACHETE_HORROR" },
    keepItems   = { "gutra" },

    prompt = {
        enabled             = true,
        respawnEnabled      = true,
        respawnDelaySeconds = 250, -- 0 = instant
        holdMs              = 2000,
        alertCommand        = "alertmedic", -- shown on the death screen; match the Medical alert's command
    },

    -- respawn goes to the closest
    respawnPoints = {
        vector3(-164.3632, 633.6946, 114.0320),    -- Valentine
        vector3(2721.4562, -1446.0975, 46.2303),   -- Saint Denis
        vector3(-3742.5102, -2600.9843, -13.2332), -- Armadillo
        vector3(-723.9527, -1242.8358, 44.7341),   -- Blackwater
        vector3(1229.0096, -1306.1053, 76.9038),   -- Rhodes
    },
}
