-- pup-misc/scene | style lists (see README)

SceneConfig.Styles = {
    -- Colour row
    palette = {
        { name = "White",    r = 255, g = 255, b = 255, token = 'COLOR_PURE_WHITE' },
        { name = "Bone",     r = 239, g = 230, b = 213, token = 'COLOR_WHITE' },
        { name = "Gold",     r = 214, g = 173, b =  90, token = 'COLOR_GOLD' },
        { name = "Crimson",  r = 168, g =  50, b =  50, token = 'COLOR_RED' },
        { name = "Rust",     r = 186, g = 100, b =  46, token = 'COLOR_ORANGE' },
        { name = "Moss",     r = 110, g = 140, b =  86, token = 'COLOR_GREEN' },
        { name = "Sky",      r = 108, g = 158, b = 190, token = 'COLOR_BLUE' },
        { name = "Violet",   r = 146, g = 104, b = 178, token = 'COLOR_PURPLE' },
        { name = "Slate",    r = 140, g = 144, b = 148, token = 'COLOR_GREY' },
        { name = "Black",    r =  20, g =  20, b =  20, token = 'COLOR_BLACK' },
    },

    -- Size row (text scale)
    sizes = { 0.22, 0.26, 0.30, 0.35, 0.42, 0.50, 0.60 },

    -- Font row. id = RDR2 font id
    fonts = {
        { name = "Font A", id = 0 },
        { name = "Font B", id = 1 },
        { name = "Font C", id = 2 },
        { name = "Font D", id = 4 },
        { name = "Font E", id = 5 },
    },

    -- Backing row: plate opacity behind the text, 0 = no plate
    backings = {
        { name = "Off",    a = 0.00 },
        { name = "Light",  a = 0.35 },
        { name = "Medium", a = 0.60 },
        { name = "Heavy",  a = 0.85 },
    },

    -- Range row (metres a scene can be read from)
    ranges = { 3.0, 5.0, 8.0, 12.0, 18.0, 25.0, 40.0 },

    -- inline colour tags a player may type, e.g. [red]wanted [gold]dead or alive
    inlineColours = {
        gold   = 'COLOR_GOLD',
        white  = 'COLOR_PURE_WHITE',
        red    = 'COLOR_RED',
        green  = 'COLOR_GREEN',
        blue   = 'COLOR_BLUE',
        yellow = 'COLOR_YELLOW',
        orange = 'COLOR_ORANGE',
        purple = 'COLOR_PURPLE',
        grey   = 'COLOR_GREY',
        black  = 'COLOR_BLACK',
    },

    -- Order the Accent row steps through. Keep it in step with inlineColours.
    accentOrder = { 'gold', 'red', 'white', 'yellow', 'orange', 'green', 'blue', 'purple', 'grey', 'black' },

    -- Effect row: which words take the accent colour (the no-typing way to get two colours)
    patterns = {
        { id = 'none',  name = 'None' },
        { id = 'first', name = 'First word' },
        { id = 'last',  name = 'Last word' },
        { id = 'edges', name = 'First + last' },
        { id = 'rest',  name = 'All but first' },
        { id = 'alt',   name = 'Alternating' },
    },

    -- Look row (presets)
    presets = {
        { name = 'Plain',      colour = 'White',   accent = nil,      effect = 'none',  size = 0.30, font = 1, backing = 'Off' },
        { name = 'Notice',     colour = 'Bone',    accent = 'gold',   effect = 'first', size = 0.35, font = 1, backing = 'Light' },
        { name = 'Wanted',     colour = 'Bone',    accent = 'red',    effect = 'first', size = 0.42, font = 1, backing = 'Medium' },
        { name = 'Saloon',     colour = 'Gold',    accent = 'red',    effect = 'edges', size = 0.42, font = 0, backing = 'Heavy' },
        { name = 'Warning',    colour = 'Crimson', accent = 'yellow', effect = 'first', size = 0.35, font = 1, backing = 'Medium' },
        { name = 'Telegram',   colour = 'Slate',   accent = 'white',  effect = 'rest',  size = 0.26, font = 2, backing = 'Light' },
        { name = 'Storefront', colour = 'Bone',    accent = 'green',  effect = 'last',  size = 0.35, font = 0, backing = 'Medium' },
        { name = 'Whisper',    colour = 'Slate',   accent = nil,      effect = 'none',  size = 0.22, font = 1, backing = 'Off' },
        { name = 'Shout',      colour = 'Crimson', accent = 'white',  effect = 'alt',   size = 0.60, font = 0, backing = 'Heavy' },
    },
}
