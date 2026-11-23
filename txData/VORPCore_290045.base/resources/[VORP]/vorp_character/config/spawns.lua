-- Modified by Puppet (Dusk Till Dawn), 2026
-- vorp_character | spawn data
-- Towns a new character can start in, and the character select scenes.

-------------------------------------------------------------------------------
-- SPAWN TOWNS  (spawn picker, only used when Config.SpawnPicker.enabled = true)
-------------------------------------------------------------------------------
-- label    town name on the spawn picker
-- desc     line shown under the town name
-- position vector3 where the character spawns
-- heading  facing on spawn (degrees)
-- example: { label = "Valentine", desc = "...", position = vector3(-171.693, 625.627, 113.682), heading = 251.19 },
-- With picking off, new characters get a random entry. To add a town: uncomment it below AND
-- set Config.SpawnPicker.enabled = true in config/main.lua.
Config.SpawnCoords = {
    {
        label = "Valentine",
        desc = "A cattle town of mud and whiskey, loud from the stockyard to the saloon. Work is easy to find here, and so is trouble.",
        position = vector3(-171.693, 625.627, 113.682),
        heading = 251.19
    },
    -- Annesburg is off for now. Uncomment it AND set Config.SpawnPicker.enabled = true.
    -- {
    --     label = "Annesburg",
    --     desc = "A coal town on the cold edge of the map. The mine pays badly and takes plenty, but nobody up here asks where a man came from.",
    --     position = vector3(2947.580, 1280.055, 44.279),
    --     heading = 180.0
    -- },
    -- Blackwater is off for now. Uncomment it AND set Config.SpawnPicker.enabled = true.
    -- {
    --     label = "Blackwater",
    --     desc = "A clean, lawful town with money moving through it and Pinkertons watching who touches it. Work is steady here, and so is the attention.",
    --     position = vector3(-687.3, -1242.249, 43.1),
    --     heading = 90.58
    -- },
}

-------------------------------------------------------------------------------
-- CHARACTER SELECT SCENES
-------------------------------------------------------------------------------
-- One scene is picked at random each time the select screen opens.
-- options    timecycle {name, strength}, music, weather {type, transition, snow},
--            time {hour, transition}, playerpos (vector3 the hidden player waits at so
--            textures load), mainCam {x, y, z, rotx, roty, rotz, fov}
-- positions  one entry per character slot, in slot order (keep at least as many as the
--            max characters set in vorp_core):
--            spawn vector4 for the ped, camera {x, y, z, rotx, roty, rotz, fov} looking at it,
--            scenario { mp_female = {...}, mp_male = {...} } - one is picked at random.
-- Timecycle and music names: see the RDR3 discoveries GitHub.
Config.SpawnPosition = {
    -- Vanhorn
    {
        options = {
            timecycle = { name = "teaser_trainShot", strength = 1.0 },                                         -- you can find more in RDR3 discoveries github
            music = "REHR_START",                                                                              -- you can find more in RDR3 discoveries github
            weather = { type = "sunny", transition = 10, snow = false },                                       -- weather to choose
            time = { hour = 12, transition = 10 },                                                             -- time to choose
            playerpos = vector3(2967.38, 488.73, 47.21),                                                       -- player spawn for textures to load in
            mainCam = { x = 2967.38, y = 488.73, z = 47.21, rotx = 0.0, roty = 0.0, rotz = 105.0, fov = 60.0 } -- main
        },
        positions = {
            {
                spawn = vector4(2959.76, 483.66, 47.39, 282.33),                                                 --location of ped
                camera = { x = 2963.62, y = 484.0, z = 47.87, rotx = 0.0, roty = 0.0, rotz = 90.0, fov = 60.0 }, --camera to look at ped
                scenario = {
                    -- animations will be random every time you join will choose one from the list
                    mp_female = {
                        "WORLD_HUMAN_SMOKE_CARRYING",
                        "MP_LOBBY_SCENARIO_08",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "WORLD_HUMAN_SMOKE_CARRYING",
                        "MP_LOBBY_SCENARIO_08",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    }
                }
            },
            {
                spawn = vector4(2960.83, 486.49, 46.82, 286.13),
                camera = { x = 2964.67, y = 487.25, z = 46.74, rotx = 0.0, roty = 0.0, rotz = 100.0, fov = 40.0 },
                scenario = {
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
            {
                spawn = vector4(2958.35, 487.81, 47.35, 283.9),
                camera = { x = 2962.18, y = 488.70, z = 46.90, rotx = 0.0, roty = 0.0, rotz = 90.0, fov = 60.0 },
                scenario = {
                    mp_female = {
                        "WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK",
                        "MP_LOBBY_CROUCHING_B",
                        "WORLD_HUMAN_SIT_DRINK",
                        "WORLD_HUMAN_SIT_GROUND_READ_NEWSPAPER"
                    },
                    mp_male = {
                        "WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK",
                        "MP_LOBBY_CROUCHING_B",
                        "WORLD_HUMAN_SIT_DRINK",
                        "WORLD_HUMAN_SIT_GROUND_READ_NEWSPAPER"
                    },
                }
            },
            {
                spawn = vector4(2960.69, 489.96, 46.59, 275.78),
                camera = { x = 2964.19, y = 490.46, z = 46.20, rotx = 0.0, roty = 0.0, rotz = 90.0, fov = 60.0 },
                scenario = {
                    mp_female = {
                        "WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK",
                        "MP_LOBBY_CROUCHING_B",
                        "WORLD_HUMAN_SIT_DRINK",
                        "WORLD_HUMAN_SIT_GROUND_READ_NEWSPAPER"
                    },
                    mp_male = {
                        "WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK",
                        "MP_LOBBY_CROUCHING_B",
                        "WORLD_HUMAN_SIT_DRINK",
                        "WORLD_HUMAN_SIT_GROUND_READ_NEWSPAPER"
                    },
                }
            },
            {
                spawn = vector4(2957.17, 490.24, 47.34, 257.62),                                                  --location of ped
                camera = { x = 2961.37, y = 490.16, z = 47.37, rotx = 0.0, roty = 0.0, rotz = 90.0, fov = 60.0 }, --camera to look at ped
                scenario = {
                    -- animations will be random every time you join will choose one from the list
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "WORLD_HUMAN_SMOKE_CARRYING",
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "WORLD_HUMAN_SMOKE_CARRYING",
                    }
                }
            },
        }
    },
    --Vanhorn 2
    {
        options = {
            timecycle = { name = "Finale1_outrohighhon_bidging2", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(2963.14, 561.10, 44.68),
            mainCam   = { x = 2964.07, y = 558.95, z = 44.42, rotx = 1.76, roty = 0.00, rotz = -169.00, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(2964.51953125, 556.38671875, 44.45668792724609, 0.0),
                camera   = { x = 2963.80, y = 557.96, z = 44.82, rotx = -2.53, roty = 0.00, rotz = -154.64, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(2964.10107421875, 555.77001953125, 44.48249816894531, 45.93),
                camera   = { x = 2962.81, y = 557.48, z = 44.82, rotx = -4.29, roty = 0.00, rotz = -143.99, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                }
            },
            {
                spawn    = vector4(2963.728759765625, 554.9774169921875, 44.50360107421875, 40.43),
                camera   = { x = 2962.59, y = 556.35, z = 44.82, rotx = -2.53, roty = 0.00, rotz = -140.34, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(2965.1533203125, 555.9634399414062, 44.42756271362305, -51.0),
                camera   = { x = 2965.16, y = 557.78, z = 44.82, rotx = -3.09, roty = 0.00, rotz = -179.39, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(2965.91064453125, 555.1605834960938, 44.42335510253906, -56.0),
                camera   = { x = 2966.17, y = 557.13, z = 44.82, rotx = -3.28, roty = 0.00, rotz = 172.17, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- Saloon of Armadillo
    {
        options = {
            timecycle = { name = "teaser_trainShot", strength = 1.0 },                                             -- you can find more in RDR3 discoveries github
            music = "REHR_START",                                                                                  -- you can find more in RDR3 discoveries github
            weather = { type = "sunny", transition = 10, snow = false },                                           -- weather to choose
            time = { hour = 12, transition = 10 },                                                                 -- time to choose
            playerpos = vector3(-3703.26, -2602.17, -13.27),                                                       -- where invisible player needs to spawn for textures to load in location
            mainCam = { x = -3707.83, y = -2599.98, z = -12.80, rotx = 5.0, roty = 0.0, rotz = -20.0, fov = 40.0 } -- main camera position
        },
        positions = {
            {
                spawn = vector4(-3706.8, -2589.74, -13.27, 204.89),                                                    --location of ped
                camera = { x = -3706.97, y = -2594.06, z = -12.90, rotx = -5.0, roty = 0.0, rotz = -3.0, fov = 30.0 }, --camera to look at ped
                scenario = {
                    mp_female = {
                        "WORLD_HUMAN_SMOKE_CARRYING",
                        "MP_LOBBY_SCENARIO_08",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    }, -- animations still animation ,select ,spawn for females
                    mp_male = {
                        "WORLD_HUMAN_SMOKE_CARRYING",
                        "MP_LOBBY_SCENARIO_08",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
            {
                spawn = vector4(-3701.46, -2592.47, -13.27, 139.94),
                camera = { x = -3703.89, y = -2596.37, z = -12.60, rotx = -10.0, roty = 0.0, rotz = -30.0, fov = 35.0 },
                scenario = {
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
            {
                spawn = vector4(-3702.79, -2587.09, -10.24, 176.87),
                camera = { x = -3702.87, y = -2589.9, z = -9.66, rotx = -15.0, roty = 0.0, rotz = 5.0, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
            {
                spawn = vector4(-3702.5, -2589.02, -13.32, 160.76),
                camera = { x = -3702.7, y = -2592.5, z = -12.8, rotx = -15.0, roty = 0.0, rotz = 5.0, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
            {
                spawn = vector4(-3698.99, -2589.17, -10.29, 85.26),
                camera = { x = -3700.80, y = -2590.87, z = -9.59, rotx = -15.0, roty = 0.0, rotz = -50.0, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                    mp_male = {
                        "MP_LOBBY_SCENARIO_02",
                        "MP_LOBBY_SCENARIO_04",
                        "MP_LOBBY_SCENARIO_07",
                        "WORLD_HUMAN_SMOKE_CARRYING"
                    },
                }
            },
        }
    },
    -- Cotorra Springs
    {
        options = {
            timecycle = { name = "finale2_campMoonPos", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(240.46421813964844, 1968.3095703125, 206.56849670410156),
            mainCam   = { x = 241.50, y = 1966.36, z = 205.82, rotx = 0.13, roty = 0.00, rotz = 177.52, fov = 55.0 },
        },
        positions = {
            {
                spawn    = vector4(241.28634643554688, 1963.6492919921875, 205.7147674560547, -13.41),
                camera   = { x = 241.03, y = 1965.26, z = 205.98, rotx = 2.47, roty = 0.00, rotz = -170.29, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A",
                    }
                }
            },
            {
                spawn    = vector4(240.3826904296875, 1962.885986328125, 205.5716094970703, 0.90),
                camera   = { x = 239.81, y = 1964.61, z = 205.92, rotx = 0.27, roty = 0.00, rotz = -160.84, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D",
                    },
                }
            },
            {
                spawn    = vector4(239.3123321533203, 1962.4949951171875, 205.47006225585938, -1.40),
                camera   = { x = 239.01, y = 1964.32, z = 205.58, rotx = 2.46, roty = 0.00, rotz = -168.28, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                }
            },
            {
                spawn    = vector4(242.06687927246094, 1962.82861328125, 205.6053924560547, -47.0),
                camera   = { x = 243.38, y = 1964.55, z = 206.35, rotx = -9.77, roty = 0.00, rotz = 145.23, fov = 60.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C",
                    },
                }
            },
            {
                spawn    = vector4(242.54800415039062, 1961.7637939453125, 205.44102478027344, -44.0),
                camera   = { x = 243.38, y = 1963.29, z = 205.83, rotx = -1.75, roty = 0.00, rotz = 152.17, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "WORLD_HUMAN_SMOKE",
                    },
                    mp_male = {
                        "WORLD_HUMAN_SMOKE",
                    }
                }
            },
        }
    },
    -- Donner Falls
    {
        options = {
            timecycle = { name = "trailer2_shot1", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(394.7771301269531, 1672.5684814453125, 127.14893341064453),
            mainCam   = { x = 397.08, y = 1672.30, z = 128.27, rotx = 4.64, roty = 0.00, rotz = -45.14, fov = 55.0 },
        },
        positions = {
            {
                spawn    = vector4(399.0948791503906, 1674.13623046875, 128.34893798828125, 121.97),
                camera   = { x = 397.62, y = 1672.29, z = 129.09, rotx = -12.06, roty = 0.00, rotz = -33.24, fov = 65.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A",
                    }
                }
            },
            {
                spawn    = vector4(400.1960144042969, 1674.1185302734375, 128.2821807861328, 165.66),
                camera   = { x = 399.36, y = 1672.33, z = 128.59, rotx = -1.39, roty = 0.00, rotz = -24.70, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D",
                    },
                }
            },
            {
                spawn    = vector4(401.34051513671875, 1674.3046875, 128.2012939453125, -158.24),
                camera   = { x = 402.13, y = 1672.52, z = 128.80, rotx = -5.41, roty = 0.00, rotz = 22.56, fov = 60.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A",
                    },
                }
            },
            {
                spawn    = vector4(399.1690979003906, 1675.1075439453125, 128.34046936035156, 78.19),
                camera   = { x = 397.07, y = 1674.74, z = 129.14, rotx = -16.21, roty = 0.00, rotz = -72.96, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C",
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C",
                    },
                }
            },
            {
                spawn    = vector4(399.4101867675781, 1676.465087890625, 128.29788208007812, 97.04),
                camera   = { x = 397.11, y = 1675.48, z = 128.54, rotx = 3.55, roty = 0.00, rotz = -60.97, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "WORLD_HUMAN_SMOKE",
                    },
                    mp_male = {
                        "WORLD_HUMAN_SMOKE",
                    }
                }
            },
        }
    },
    -- The HeartLands 1
    {
        options = {
            timecycle = { name = "martson1_intromod2", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(178.41, 121.52, 105.28),
            mainCam   = { x = 180.76, y = 125.44, z = 104.26, rotx = 4.06, roty = 0.00, rotz = -61.33, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(182.7963409423828, 126.51189422607422, 104.46258544921875, 122.99),
                camera   = { x = 181.80, y = 125.43, z = 104.80, rotx = -5.57, roty = 0.00, rotz = -38.77, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(183.80235290527344, 126.40680694580078, 104.3888931274414, 170.61),
                camera   = { x = 182.81, y = 125.27, z = 104.80, rotx = -8.41, roty = 0.00, rotz = -41.17, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                }
            },
            {
                spawn    = vector4(184.9395294189453, 126.3748779296875, 104.34683990478516, 178.99),
                camera   = { x = 183.94, y = 125.05, z = 104.80, rotx = -6.33, roty = 0.00, rotz = -37.45, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(182.57081604003906, 127.40278625488281, 104.57352447509766, 103.93),
                camera   = { x = 180.71, y = 127.62, z = 105.43, rotx = -11.55, roty = 0.00, rotz = -95.67, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(183.69700622558594, 128.34262084960938, 104.5129165649414, 85.22),
                camera   = { x = 182.57, y = 129.46, z = 104.80, rotx = -1.98, roty = 0.00, rotz = -134.39, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- The HeartLands 2
    {
        options = {
            timecycle = { name = "FINALE2_campMoonPos", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(484.17, -288.31, 144.68),
            mainCam   = { x = 486.16, y = -289.88, z = 144.19, rotx = 1.67, roty = 0.00, rotz = -145.28, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(487.70672607421875, -292.080322265625, 144.1527862548828, 22.96),
                camera   = { x = 486.31, y = -291.28, z = 144.68, rotx = -8.15, roty = 0.00, rotz = -119.39, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(487.6447448730469, -293.106689453125, 144.15354919433594, 65.84),
                camera   = { x = 486.35, y = -292.62, z = 144.68, rotx = -8.22, roty = 0.00, rotz = -110.88, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                }
            },
            {
                spawn    = vector4(487.7176208496094, -294.1673278808594, 144.1559295654297, 61.68),
                camera   = { x = 486.46, y = -293.72, z = 144.68, rotx = -9.48, roty = 0.00, rotz = -110.00, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(488.6108093261719, -292.263916015625, 144.1641082763672, -12.58),
                camera   = { x = 488.30, y = -290.89, z = 144.68, rotx = -11.11, roty = 0.00, rotz = -168.96, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(489.6289367675781, -292.4676208496094, 144.17864990234375, -17.24),
                camera   = { x = 489.19, y = -290.84, z = 144.68, rotx = -8.53, roty = 0.00, rotz = -165.81, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- Swamps 1
    {
        options = {
            timecycle = { name = "Finale1_outrohighhon_bidging2", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(2152.28, -609.59, 41.96),
            mainCam   = { x = 2153.71, y = -611.14, z = 41.40, rotx = 5.92, roty = 0.00, rotz = -135.36, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(2155.578125, -613.0398559570312, 41.54308700561523, 25.46),
                camera   = { x = 2154.30, y = -612.19, z = 41.86, rotx = -1.01, roty = 0.00, rotz = -123.52, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(2155.3779296875, -613.9125366210938, 41.54896926879883, 80.25),
                camera   = { x = 2153.90, y = -613.56, z = 41.86, rotx = -0.63, roty = 0.00, rotz = -103.11, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                }
            },
            {
                spawn    = vector4(2155.763427734375, -615.0479125976562, 41.55394744873047, 70.41),
                camera   = { x = 2154.14, y = -614.62, z = 41.86, rotx = 1.32, roty = 0.00, rotz = -104.81, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(2156.56884765625, -612.965576171875, 41.54000473022461, -9.0),
                camera   = { x = 2156.57, y = -611.24, z = 41.95, rotx = -4.41, roty = 0.00, rotz = -178.63, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(2157.820068359375, -613.3458862304688, 41.55184936523437, 5.29),
                camera   = { x = 2157.74, y = -611.58, z = 41.95, rotx = -3.15, roty = 0.00, rotz = -177.56, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- Colter
    {
        options = {
            timecycle = { name = "mod5_int_lessfog", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(-1325.81, 2474.81, 309.75),
            mainCam   = { x = -1326.78, y = 2472.99, z = 309.75, rotx = 2.17, roty = 0.00, rotz = -165.38, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(-1326.1461181640625, 2470.50244140625, 309.5157165527344, 3.5),
                camera   = { x = -1327.04, y = 2472.75, z = 309.78, rotx = 2.67, roty = 0.00, rotz = -151.38, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(-1326.5155029296875, 2469.6474609375, 309.48480224609375, 27.79),
                camera   = { x = -1327.49, y = 2471.00, z = 309.93, rotx = -9.42, roty = 0.00, rotz = -143.21, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"

                    },
                }
            },
            {
                spawn    = vector4(-1326.728759765625, 2468.68310546875, 309.46185302734375, 46.91),
                camera   = { x = -1327.83, y = 2469.80, z = 309.93, rotx = -4.94, roty = 0.00, rotz = -136.53, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(-1325.2999267578125, 2469.999755859375, 309.5245361328125, -17.53),
                camera   = { x = -1324.98, y = 2471.68, z = 309.93, rotx = -8.09, roty = 0.00, rotz = 168.98, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(-1324.438232421875, 2469.408447265625, 309.5310974121094, -30.19),
                camera   = { x = -1323.99, y = 2470.97, z = 309.93, rotx = -4.63, roty = 0.00, rotz = 164.38, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- Manzanita Post
    {
        options = {
            timecycle = { name = "winter4_ride_sunstrength2", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(-1957.59, -1612.63, 115.69),
            mainCam   = { x = -1959.05, y = -1613.00, z = 115.69, rotx = 10.32, roty = 0.00, rotz = 103.69, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(-1961.74462890625, -1613.662353515625, 115.97038269042969, -91.2),
                camera   = { x = -1960.22, y = -1612.66, z = 116.28, rotx = 0.87, roty = 0.00, rotz = 124.16, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(-1962.37548828125, -1613.1929931640625, 116.01429748535156, -37.79),
                camera   = { x = -1961.40, y = -1611.68, z = 116.28, rotx = -1.33, roty = 0.00, rotz = 148.73, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                }
            },
            {
                spawn    = vector4(-1963.42822265625, -1612.8199462890625, 116.08049011230469, -34.0),
                camera   = { x = -1962.37, y = -1611.23, z = 116.28, rotx = 1.31, roty = 0.00, rotz = 146.08, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },

            {
                spawn    = vector4(-1962.11572265625, -1614.4964599609375, 116.00640869140625, -133.0),
                camera   = { x = -1960.49, y = -1614.82, z = 116.28, rotx = -1.33, roty = 0.00, rotz = 77.92, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(-1962.7508544921875, -1615.2008056640625, 116.0385513305664, -148.0),
                camera   = { x = -1961.18, y = -1615.87, z = 116.28, rotx = 1.12, roty = 0.00, rotz = 68.41, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
    -- Armadillo Cemetery
    {
        options = {
            timecycle = { name = "finale2_campmoonpos", strength = 1.0 },
            music     = "",
            weather   = { type = "sunny", transition = 10, snow = false },
            time      = { hour = 10, transition = 10 },
            playerpos = vector3(-3317.17, -2824.74, -6.07),
            mainCam   = { x = -3320.76, y = -2823.50, z = -6.07, rotx = 3.21, roty = 0.00, rotz = -175.24, fov = 50.0 },
        },
        positions = {
            {
                spawn    = vector4(-3320.525634765625, -2826.189697265625, -6.14256906509399, -12.0),
                camera   = { x = -3320.64, y = -2824.37, z = -5.77, rotx = -8.66, roty = 0.00, rotz = -170.33, fov = 60.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    }
                }
            },
            {
                spawn    = vector4(-3320.9775390625, -2826.91162109375, -6.20029354095459, 38.11),
                camera   = { x = -3321.85, y = -2825.28, z = -5.77, rotx = -3.72, roty = 0.00, rotz = -152.49, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                }
            },
            {
                spawn    = vector4(-3321.275146484375, -2827.922607421875, -6.22911691665649, 39.59),
                camera   = { x = -3322.58, y = -2826.46, z = -5.77, rotx = -6.05, roty = 0.00, rotz = -139.45, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_A"
                    },
                }
            },
            {
                spawn    = vector4(-3319.898681640625, -2826.728271484375, -6.10577821731567, -50.86),
                camera   = { x = -3319.01, y = -2825.16, z = -5.77, rotx = -4.29, roty = 0.00, rotz = 151.13, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_C"
                    },
                }
            },
            {
                spawn    = vector4(-3319.260498046875, -2827.394775390625, -6.08130264282226, -66.57),
                camera   = { x = -3317.02, y = -2826.74, z = -5.11, rotx = -17.32, roty = 0.00, rotz = 105.93, fov = 50.0 },
                scenario = {
                    mp_female = {
                        "MP_COOP_LOBBY_STANDING_D"
                    },
                    mp_male = {
                        "MP_COOP_LOBBY_STANDING_D"
                    }
                }
            },
        }
    },
}
