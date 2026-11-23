-- pup_robbery | walk-up robbery places (fields are described in README.md)

local function v(x, y, z) return vector3(x, y, z) end

local fortLoot = {
    { item = 'acid', count = 5, chance = 5 },
    { item = 'stolenmerch', count = 2, chance = 8 },
    { item = 'dynamite', count = 1, chance = 10 },
    { item = 'emerald', count = 1, chance = 2 },
    { item = 'heroin', count = 1, chance = 5 },
    { item = 'goldbar', count = 1, chance = 2 },
    { item = 'moneybag_medium', count = 1, chance = 80 },
    { item = 'moneybag_small', count = 1, chance = 70 },
}

local function mercerLoot(stolen)
    return {
        { item = 'acid', count = 5, chance = 5 },
        { item = 'stolenmerch', count = stolen, chance = 8 },
        { item = 'dynamite', count = 1, chance = 10 },
        { item = 'emerald', count = 1, chance = 2 },
        { item = 'heroin', count = 1, chance = 5 },
        { item = 'goldbar', count = 1, chance = 2 },
        { item = 'moneybag_medium', count = 1, chance = 60 },
        { item = 'moneybag_small', count = 1, chance = 40 },
    }
end

local wallaceLoot = {
    { item = 'acid', count = 5, chance = 5 },
    { item = 'stolenmerch', count = 2, chance = 10 },
    { item = 'dynamite', count = 1, chance = 10 },
    { item = 'emerald', count = 1, chance = 2 },
    { item = 'heroin', count = 1, chance = 5 },
    { item = 'goldbar', count = 1, chance = 2 },
    { item = 'moneybag_large', count = 1, chance = 60 },
    { item = 'moneybag_medium', count = 1, chance = 60 },
    { item = 'moneybag_small', count = 1, chance = 15 },
}

local function bags(med, small)
    return { item = 'moneybag_medium', count = 1, chance = med }, { item = 'moneybag_small', count = 1, chance = small }
end

local function withBags(list, med, small)
    local a, b = bags(med, small)
    list[#list + 1] = a
    list[#list + 1] = b
    return list
end

Config.Places = {
    ['antenor boat'] = {
        category = 'other', anchor = v(2778.78, -1534.30, 48.27), stray = 50, cooldown = 60,
        lawmen = 2, riders = 4, jobLimit = 30, unlockDelay = 5, regions = { 'EAST' },
        boxes = {
            { pos = v(2789.65, -1551.42, 49.39), game = 'normal', loot = withBags({ { item = 'diamond', count = 2, chance = 10 }, { item = 'goldbar', count = 2, chance = 10 } }, 60, 40) },
            { pos = v(2763.64, -1506.38, 48.27), game = 'safe', dials = 3, loot = withBags({ { item = 'emerald', count = 2, chance = 8 }, { item = 'banktools', count = 1, chance = 10 } }, 60, 40) },
            { pos = v(2775.34, -1527.63, 50.38), game = 'safe', dials = 3, loot = withBags({ { item = 'dynamite', count = 2, chance = 10 }, { item = 'alcohol', count = 5, chance = 10 } }, 60, 40) },
            { pos = v(2786.33, -1558.79, 49.36), game = 'safe', dials = 2, loot = withBags({ { item = 'goldbar', count = 2, chance = 8 }, { item = 'sealedpackage', count = 2, chance = 8, label = 'Sealed Package' } }, 60, 40) },
        },
    },

    ['Armadillo Fort'] = {
        category = 'fort', anchor = v(-3224.1, -3047.95, 2.5), stray = 100, cooldown = 90,
        lawmen = 1, riders = 2, jobLimit = 30, unlockDelay = 5, regions = { 'WEST' },
        waves = { count = 5, size = 10, gap = 10 },
        posts = {
            { pos = v(-3216.3, -3052.4, -0.17), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_repeater_evans' },
            { pos = v(-3232.1, -3050.3, -0.25), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(-3230.36, -3069.6, -1.02), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-3215.06, -3066.89, -0.44), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-3229.9, -3083.36, -0.96), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_rifle_boltaction' },
            { pos = v(-3214.13, -3084.19, -0.33), model = 'U_M_M_UniBountyHunter_02', weapon = 'weapon_repeater_henry' },
        },
        boxes = {
            { pos = v(-3224.6, -3033.1, 0.147), game = 'safe', dials = 1, loot = fortLoot },
            { pos = v(-3233.12, -3044.8, -0.09), game = 'safe', dials = 1, loot = fortLoot },
            -- about 960 m from the fort, so it cannot be opened
            { pos = v(-4187.39, -3070.5, -0.39), game = 'safe', dials = 2, loot = fortLoot },
            { pos = v(-3228.69, -3073.18, -0.97), game = 'lockpick', loot = fortLoot },
        },
    },

    ['Blackwater General Store'] = {
        category = 'store', anchor = v(-789.2166, -1322.055, 44.0), stray = 30, cooldown = 60,
        lawmen = 1, riders = 2, unlockDelay = 2, regions = { 'WEST' }, gangPoints = { 4, 10 },
        guards = {
            { pos = v(-751.746, -1260.515, 44.0), model = 'S_M_M_DispatchLeaderPolice_01', weapon = 'weapon_repeater_evans' },
            { pos = v(-834.1995, -1311.683, 44.0), model = 'S_M_M_DispatchLeaderRural_01', weapon = 'weapon_rifle_boltaction' },
            { pos = v(-789.9339, -1270.242, 44.0), model = 'S_M_M_AmbientSDPolice_01', weapon = 'weapon_repeater_henry' },
            { pos = v(-781.9046, -1369.515, 44.0), model = 'S_M_M_AmbientBlWPolice_01', weapon = 'weapon_shotgun_pump' },
            { pos = v(-820.2146, -1383.215, 44.0), model = 'S_M_M_DispatchPolice_01', weapon = 'weapon_shotgun_semiauto' },
            { pos = v(-861.246, -1384.515, 44.0), model = 'U_M_M_SDPoliceChief_01', weapon = 'weapon_revolver_schofield' },
        },
        boxes = {
            { pos = v(-784.19, -1322.28, 43.88), game = 'normal', loot = { { item = 'moneybag_small', count = 1, chance = 70 } } },
            { pos = v(-778.24, -1323.88, 43.88), game = 'normal', loot = { { item = 'moneybag_small', count = 1, chance = 70 } } },
        },
    },

    ['Fort Mercer'] = {
        category = 'fort', anchor = v(-4203.01, -3446.05, 40.02), stray = 100, cooldown = 60,
        lawmen = 1, riders = 2, jobLimit = 30, unlockDelay = 5, regions = { 'WEST' },
        waves = { count = 5, size = 10, gap = 10 },
        posts = {
            { pos = v(-4207.43, -3418.04, 45.63), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_repeater_evans' },
            { pos = v(-4226.46, -3433.72, 41.48), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_rifle_boltaction' },
            { pos = v(-4205.24, -3463.74, 45.20), model = 'U_M_M_UNIONLEADER_02', weapon = 'weapon_repeater_henry' },
            { pos = v(-4193.87, -3476.87, 41.48), model = 'U_M_M_UNIONLEADER_02', weapon = 'weapon_shotgun_pump' },
            { pos = v(-4181.22, -3455.44, 41.47), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_shotgun_semiauto' },
            { pos = v(-4172.59, -3433.10, 42.47), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(-4171.21, -3429.93, 42.48), model = 'U_M_M_UniBountyHunter_02', weapon = 'weapon_repeater_henry' },
            { pos = v(-4176.22, -3438.12, 37.08), model = 'U_M_M_UniBountyHunter_02', weapon = 'weapon_repeater_henry' },
            { pos = v(-4180.33, -3443.76, 37.13), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4247.07, -3475.86, 37.08), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4250.23, -3474.81, 37.08), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4244.14, -3488.77, 37.08), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4213.91, -3499.68, 42.65), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            -- y is probably meant to be about -3504.27; unused at a wave size of 10
            { pos = v(-4216.04, -6504.27, 42.65), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4189.73, -3464.61, 37.28), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4188.89, -3458.89, 37.28), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4236.33, -3478.12, 37.06), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(-4239.42, -3464.06, 41.48), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
        },
        boxes = {
            { pos = v(-4204.85, -3432.45, 37.08), game = 'safe', dials = 1, loot = mercerLoot(3) },
            { pos = v(-4201.40, -3448.92, 37.08), game = 'safe', dials = 1, loot = mercerLoot(3) },
            { pos = v(-4187.39, -3423.03, 37.08), game = 'safe', dials = 2, loot = mercerLoot(3) },
            { pos = v(-4249.82, -3456.37, 37.10), game = 'lockpick', loot = mercerLoot(2) },
            { pos = v(-4234.39, -3478.83, 37.08), game = 'lockpick', loot = mercerLoot(2) },
            { pos = v(-4214.46, -3470.89, 40.95), game = 'normal', loot = mercerLoot(2) },
        },
    },

    ['Fort Wallace'] = {
        category = 'fort', anchor = v(357.7942, 1466.816, 179.2), stray = 100, cooldown = 60,
        lawmen = 2, riders = 2, jobLimit = 30, unlockDelay = 5, regions = { 'EAST' },
        boxes = {
            { pos = v(366.3247, 1490.163, 180.30), game = 'normal', loot = wallaceLoot },
            -- the same spot as box 1
            { pos = v(366.3247, 1490.163, 180.30), game = 'normal', loot = wallaceLoot },
        },
    },

    ['Lemoyne Fort'] = {
        category = 'fort', anchor = v(2454.5, 292.5, 70.35), stray = 100, cooldown = 90,
        lawmen = 1, riders = 2, jobLimit = 30, unlockDelay = 5, regions = { 'EAST' },
        waves = { count = 5, size = 10, gap = 10 },
        posts = {
            { pos = v(2449.12, 300.1, 70.21), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_repeater_evans' },
            { pos = v(2449.93, 280.9, 70.5), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(2459.3, 277.0, 75.4), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2452.2, 277.98, 74.87), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2445.3, 280.1, 74.75), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2440.9, 286.2, 74.19), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2442.5, 293.3, 74.16), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2441.5, 298.9, 74.12), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2446.45, 304.3, 73.8), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2460.2, 300.6, 74.7), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2444.72, 291.59, 70.3), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2463.2, 286.3, 72.52), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(2448.5, 280.93, 70.56), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
        },
        boxes = {
            { pos = v(2452.5, 280.0, 70.49), game = 'safe', dials = 1, loot = fortLoot },
            { pos = v(2460.02, 300.6, 70.2), game = 'safe', dials = 1, loot = fortLoot },
            { pos = v(2448.8, 296.4, 70.1), game = 'safe', dials = 2, loot = fortLoot },
            { pos = v(2445.9, 280.5, 74.7), game = 'lockpick', loot = fortLoot },
        },
    },

    ['Mount Hagen'] = {
        category = 'other', anchor = v(-1415.76, 1167.79, 226.30), stray = 50, cooldown = 60,
        lawmen = 2, riders = 4, jobLimit = 30, unlockDelay = 8, regions = { 'EAST' },
        boxes = {
            { pos = v(-1430.60, 1181.23, 226.05), game = 'normal', loot = withBags({ { item = 'emerald', count = 2, chance = 10 }, { item = 'coal', count = 5, chance = 10 }, { item = 'stolenmerch', count = 1, chance = 10 } }, 60, 40) },
            { pos = v(-1446.87, 1199.86, 226.17), game = 'safe', dials = 1, loot = withBags({ { item = 'goldbar', count = 2, chance = 8 }, { item = 'coal', count = 5, chance = 10 } }, 60, 40) },
            { pos = v(-1417.49, 1185.26, 225.28), game = 'safe', dials = 3, loot = withBags({ { item = 'dynamite', count = 2, chance = 10 }, { item = 'iron', count = 5, chance = 10 } }, 60, 40) },
            { pos = v(-1407.85, 1189.58, 225.30), game = 'safe', dials = 1, loot = withBags({ { item = 'clay', count = 2, chance = 10 }, { item = 'salt', count = 5, chance = 10 } }, 60, 40) },
        },
    },

    ['Oil Rig'] = {
        category = 'other', anchor = v(480.8, 663.8, 117.4), stray = 100, cooldown = 60,
        lawmen = 4, riders = 1, jobLimit = 30, unlockDelay = 5, regions = { 'EAST' },
        guards = {
            { pos = v(494.94, 682.86, 117.37), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_rifle_springfield' },
            { pos = v(496.8, 680.34, 121.03), model = 'U_M_M_UNIONLEADER_01', weapon = 'weapon_rifle_boltaction' },
            { pos = v(466.22, 617.83, 112.52), model = 'U_M_M_UNIONLEADER_02', weapon = 'weapon_repeater_henry' },
            { pos = v(511.82, 611.25, 111.02), model = 'U_M_M_UNIONLEADER_02', weapon = 'weapon_shotgun_pump' },
            { pos = v(559.75, 582.79, 111.71), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_shotgun_semiauto' },
            { pos = v(594.86, 647.29, 115.41), model = 'U_M_M_UniBountyHunter_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(577.8, 645.7, 117.97), model = 'U_M_M_UniBountyHunter_02', weapon = 'weapon_repeater_henry' },
            { pos = v(577.8, 645.7, 117.97), model = 'U_M_M_UniBountyHunter_02', weapon = 'weapon_repeater_henry' },
            { pos = v(526.66, 672.59, 115.16), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
            { pos = v(526.66, 672.59, 115.16), model = 'U_M_M_RhdBackupDeputy_02', weapon = 'weapon_repeater_evans' },
        },
        boxes = {
            { pos = v(494.94, 682.86, 117.37), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 2, chance = 5 }, { item = 'diamond', count = 10, chance = 1 }, { item = 'emerald', count = 1, chance = 3 } }, 40, 36) },
            { pos = v(496.8, 680.34, 121.03), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 10, chance = 5 }, { item = 'dynamite', count = 5, chance = 3 } }, 40, 36) },
            { pos = v(461.7904, 686.0218, 117.1917), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 2, chance = 5 }, { item = 'diamond', count = 1, chance = 1 }, { item = 'emerald', count = 1, chance = 3 } }, 40, 36) },
            { pos = v(461.1844, 675.0370, 120.8540), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 10, chance = 5 }, { item = 'dynamite', count = 5, chance = 3 }, { item = 'diamond', count = 10, chance = 3 } }, 40, 36) },
            -- height 20.87 is about 97 m under the rig (probably meant 120.87)
            { pos = v(487.2207, 672.8643, 20.8683), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 2, chance = 5 }, { item = 'diamond', count = 5, chance = 1 }, { item = 'emerald', count = 5, chance = 3 } }, 40, 36) },
            { pos = v(496.7401, 672.6093, 117.2383), game = 'normal', loot = withBags({ { item = 'acid', count = 5, chance = 5 }, { item = 'alcohol', count = 2, chance = 5 }, { item = 'dynamite', count = 2, chance = 3 } }, 40, 36) },
        },
    },

    ['Saint Denis General Store'] = {
        category = 'store', anchor = v(2826.483, -1314.553, 46.0), stray = 30, cooldown = 60,
        lawmen = 1, riders = 2, unlockDelay = 3, regions = { 'EAST' }, gangPoints = { 4, 10 },
        -- these guards stand up to about 300 m from the store
        guards = {
            { pos = v(2517.564, -1306.546, 50.0), model = 'S_M_M_DispatchLeaderPolice_01', weapon = 'weapon_repeater_evans' },
            { pos = v(2759.264, -1387.546, 46.4), model = 'S_M_M_DispatchLeaderRural_01', weapon = 'weapon_rifle_boltaction' },
            { pos = v(2684.864, -1361.546, 48.0), model = 'S_M_M_AmbientBlWPolice_01', weapon = 'weapon_shotgun_pump' },
            { pos = v(2634.164, -1296.646, 52.3), model = 'S_M_M_DispatchPolice_01', weapon = 'weapon_shotgun_semiauto' },
            { pos = v(2591.564, -1224.546, 53.4), model = 'U_M_M_SDPoliceChief_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(2590.164, -1148.256, 52.2), model = 'U_M_M_SDPoliceChief_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(2823.964, -1150.446, 46.4), model = 'U_M_M_SDPoliceChief_01', weapon = 'weapon_revolver_schofield' },
            { pos = v(2662.764, -1406.546, 46.5), model = 'S_M_M_AmbientSDPolice_01', weapon = 'weapon_repeater_henry' },
        },
        boxes = {
            { pos = v(2829.407, -1315.738, 46.75), game = 'normal', loot = { { item = 'moneybag_small', count = 1, chance = 55 } } },
            { pos = v(2824.457, -1321.065, 46.75), game = 'normal', loot = { { item = 'moneybag_small', count = 1, chance = 55 } } },
            { pos = v(2842.59, -1306.81, 46.48), game = 'normal', loot = { { item = 'moneybag_small', count = 1, chance = 55 } } },
        },
    },

    ['Thieves Landing'] = {
        category = 'other', anchor = v(-1408.50, -2335.60, 42.94), stray = 50, cooldown = 60,
        lawmen = 2, riders = 3, jobLimit = 30, unlockDelay = 5, regions = { 'WEST' },
        boxes = {
            { pos = v(-1413.28, -2329.62, 42.94), game = 'normal', loot = withBags({ { item = 'dynamite', count = 2, chance = 10 } }, 60, 40) },
            { pos = v(-1398.35, -2329.88, 42.88), game = 'safe', dials = 1, loot = withBags({ { item = 'diamond', count = 2, chance = 8 } }, 60, 40) },
            { pos = v(-1396.08, -2341.40, 42.95), game = 'safe', dials = 2, loot = withBags({ { item = 'stolenmerch', count = 2, chance = 8 } }, 60, 40) },
            { pos = v(-1412.82, -2343.14, 42.87), game = 'safe', dials = 3, loot = withBags({ { item = 'goldbar', count = 2, chance = 8 }, { item = 'emerald', count = 2, chance = 8 } }, 60, 40) },
        },
    },
}

-- Nothing to edit below: defaults every place shares
for _, p in pairs(Config.Places) do
    p.start = p.start or 'shoot'
    p.startRadius = p.startRadius or 5.0
    p.placeBlip = p.placeBlip == true
    p.boxBlips = p.boxBlips == true
    for _, b in ipairs(p.boxes) do
        b.tool = b.tool or 'lockpick'
        b.toolLabel = b.toolLabel or 'Lockpick'
        b.cash = b.cash or 0
        b.gold = b.gold or 0
    end
end
