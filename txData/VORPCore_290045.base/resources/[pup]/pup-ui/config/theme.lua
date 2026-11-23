-- pup-ui | theme: colours and fonts of everything pup-ui draws (see README, Theme)

Config = Config or {}

Config.Theme = {
    preset = 'dusk', -- 'dusk', 'classic', 'blood' or 'frontier'

    colors = {
        -- background = '#080808',               -- panels, menus, prompts
        -- text       = '#F5F1E8',               -- the main words
        -- textDim    = '#9A9184',               -- hints, descriptions, prices
        -- accent     = '#C9A24D',               -- highlights, lines, key caps, headers
        -- selected   = '#AC0B10',               -- the focused menu row
        -- danger     = '#A83232',               -- warnings, red zones, "can't afford"
        -- good       = '#5E8A3C',               -- success, money gained, "owned"
        -- border     = 'rgba(201, 162, 77, 0.35)', -- thin lines around panels and rows
    },

    fonts = {
        -- title = 'oswald.ttf',     -- headings and menu titles
        -- body  = 'imfell.ttf',     -- everything else
    },
}

-- presets; to restyle your server, set colors/fonts above instead
Config.ThemePresets = {
    -- ink and gold: Dusk Till Dawn's own look
    dusk = {
        colors = {
            background = '#080808', text = '#F5F1E8', textDim = '#9A9184', accent = '#C9A24D',
            selected = '#AC0B10', danger = '#A83232', good = '#5E8A3C', border = 'rgba(201, 162, 77, 0.35)',
        },
        fonts = { title = 'oswald.ttf', body = 'imfell.ttf' },
    },
    -- black and white, like RDR2 Online's menus
    classic = {
        colors = {
            background = '#000000', text = '#FFFFFF', textDim = '#9A9A9A', accent = '#FFFFFF',
            selected = '#AC0B10', danger = '#A83232', good = '#7DC98F', border = 'rgba(255, 255, 255, 0.22)',
        },
        fonts = { title = 'oswald.ttf', body = 'imfell.ttf' },
    },
    -- dark with blood red
    blood = {
        colors = {
            background = '#0A0606', text = '#F2E6E0', textDim = '#9A8580', accent = '#B3242A',
            selected = '#7A0A0E', danger = '#D04040', good = '#6C8F4A', border = 'rgba(179, 36, 42, 0.4)',
        },
        fonts = { title = 'oswald.ttf', body = 'imfell.ttf' },
    },
    -- warm brown leather and cream
    frontier = {
        colors = {
            background = '#1E140C', text = '#F3E6CC', textDim = '#A8957A', accent = '#D29A4A',
            selected = '#8E2B20', danger = '#B04030', good = '#6A8A3C', border = 'rgba(210, 154, 74, 0.4)',
        },
        fonts = { title = 'oswald.ttf', body = 'robotoslab.ttf' },
    },
}
