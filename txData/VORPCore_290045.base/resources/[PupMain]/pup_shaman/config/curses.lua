-- pup_shaman | curses and harmful courses
-- The keys are saved on characters and read by other resources: never rename them.

Config = Config or {}

Config.Curses = {
    lycan = { label = 'Lycanthropy',        form = 'wolf', liftOnDeath = false, spreadChance = 0.0 },
    vamp  = { label = 'Vampirism',          form = 'bat',  liftOnDeath = false },
    bear  = { label = 'Spirit of the Bear', form = 'bear', liftOnDeath = false },
    witch = { label = 'Witchcraft',         form = 'cat',  liftOnDeath = false },
    weak  = { label = 'Wasting Curse',      course = 'wasting', cure = 'curse_cure', liftOnDeath = true },
}

Config.Courses = {
    wasting = {
        stepSeconds = 6,    -- seconds per step; "after" values below are steps
        effect      = { after = 10, name = 'DEADEYE' },
        walk        = { after = 20, dict = 'amb_wander@upperbody_idles@sick@both_arms@male_a@idle_a', clip = 'idle_c' },
        drain       = { after = 120, share = 0.20 }, -- share of max health lost per step
        lethal      = true,
        floor       = 100,  -- lowest health the drain reaches when not lethal (never raises health)
        easeToStep  = 5,    -- easing rewinds the course to this step
    },
}
