-- pup_shaman | animal forms
-- The keys are replicated in the pup_form state bag: never rename them.

Config = Config or {}

Config.Forms = {
    wolf = {
        command = 'wolf', label = 'Wolf',
        model = 'A_C_Wolf', altModel = 'MP_A_C_WOLF_01',
        defaultCoat = 4, maxCoat = 12,
        size = 1.5, coatSizes = { [0] = 1.4, [4] = 1.5, [7] = 2.2, [12] = 2.1 },
        nightOnly = false, night = { from = 20, to = 5 },
        bloodMoon = { size = 1.25, damage = 1.5 },
        noJump = false,
        abilities = {
            howl   = { dict = 'amb_creature_mammal@world_wolf_howling@wolf_small@idle0', clip = 'idle_d', ms = 4000 },
            sit    = { dict = 'amb_creature_mammal@world_wolf_sitting@wolf_small@base', clip = 'base' },
            attack = {
                dict = 'script_re@animal_attack@wolf@rock', clip = 'wolf_01_attack_female_defending_loop', ms = 1200,
                range = 3.0, damage = 45, ragdollMs = 2500, cooldownSeconds = 150,
            },
        },
    },
    bear = {
        command = 'bear', label = 'Bear',
        model = 'a_c_bear_01',
        size = 1.0,
        nightOnly = false,
        noJump = true,
        abilities = {
            attack = { range = 3.5, damage = 60, ragdollMs = 3000, cooldownSeconds = 180 },
        },
    },
    bat = {
        command = 'bat', label = 'Bat',
        model = 'a_c_bat_01',
        size = 1.0,
        nightOnly = false,
        noJump = false,
        abilities = {},
    },
    cat = {
        command = 'cat', label = 'Cat',
        model = 'A_C_Cat_01',
        size = 1.0,
        nightOnly = false,
        noJump = false,
        abilities = {},
    },
}

-- key-mapped abilities (keep the command names: players' rebinds are tied to them)
Config.AbilityKeys = {
    { command = 'shaman_howl',   ability = 'howl',   key = 'Y', description = 'Howl (animal form)' },
    { command = 'shaman_sit',    ability = 'sit',    key = 'H', description = 'Sit (animal form)' },
    { command = 'shaman_attack', ability = 'attack', key = 'G', description = 'Attack (animal form)' },
}
