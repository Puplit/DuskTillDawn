-- pup-misc/police | badges (see README)

PoliceConfig.Badges = {
    -- ranks[job][grade] = { rank, prop }
    ranks = {
        ['police'] = {
            [0]  = { rank = 'Deputy Cadet',  prop = 's_badgedeputy01x' },
            [1]  = { rank = 'Deputy',        prop = 's_badgedeputy01x' },
            [2]  = { rank = 'Senior Deputy', prop = 's_badgedeputy01x' },
            [3]  = { rank = 'Corporal',      prop = 's_badgedeputy01x' },
            [4]  = { rank = 'Sergeant',      prop = 's_badgedeputy01x' },
            [5]  = { rank = 'Marshal',       prop = 's_badgedeputy01x' },
            [6]  = { rank = 'Secretary',     prop = 's_badgedeputy01x' },
            [7]  = { rank = 'Captain',       prop = 's_badgesherif01x' },
            [8]  = { rank = 'Instructor',    prop = 's_badgesherif01x' },
            [9]  = { rank = 'Sheriff',       prop = 's_badgesherif01x' },
            [10] = { rank = 'Professor',     prop = 's_badgesherif01x' },
            [11] = { rank = 'BOL/Chiefs',    prop = 's_badgesherif01x' },
            [12] = { rank = 'BOC',           prop = 's_badgesherif01x' },
        },
    },

    -- any law job with no table of its own, and any grade above the ladder, wears this
    fallback = { rank = 'Lawman', prop = 's_badgeusmarshal01x' },

    -- starting position, and what Keys.editorReset restores (metres / degrees)
    default = {
        bone = 'SKEL_L_CLAVICLE',
        x = 0.07, y = 0.15, z = 0.09,
        pitch = 176.0, roll = 0.0, yaw = -20.0,
    },

    -- the editor (/adjustbadge)
    editor = {
        -- bones, cycled in BONE mode
        bones = {
            { label = 'L CHEST', bone = 'SKEL_L_CLAVICLE' },
            { label = 'R CHEST', bone = 'SKEL_R_CLAVICLE' },
            { label = 'STERNUM', bone = 'SKEL_Spine3' },
            { label = 'BELT',    bone = 'SKEL_Spine2' },
        },
        moveStep   = 0.005,   -- metres per arrow tap
        rotateStep = 2.0,     -- degrees per arrow tap
        fineFactor = 0.2,     -- step multiplier while Keys.editorFine is held
    },
}
