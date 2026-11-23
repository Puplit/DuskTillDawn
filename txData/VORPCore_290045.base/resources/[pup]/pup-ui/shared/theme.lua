-- pup-ui | theme: turns config/theme.lua into one checked table (GetTheme export, both sides)

local SLOTS <const> = { 'background', 'text', 'textDim', 'accent', 'selected', 'danger', 'good', 'border' }
local FONT_SLOTS <const> = { 'title', 'body' }

-- '#RGB', '#RRGGBB', '#RRGGBBAA', 'rgb(r, g, b)' or 'rgba(r, g, b, a)'
local function isColour(v)
    if type(v) ~= 'string' then return false end
    v = v:gsub('%s', '')
    if v:match('^#%x%x%x$') or v:match('^#%x%x%x%x%x%x$') or v:match('^#%x%x%x%x%x%x%x%x$') then return true end
    if v:match('^rgba?%(%d+,%d+,%d+%)$') or v:match('^rgba%(%d+,%d+,%d+,[%d%.]+%)$') then return true end
    return false
end

-- a plain file name in html/fonts: letters, digits, - _ . and a .ttf/.otf ending
local function isFontFile(v)
    return type(v) == 'string' and v:match('^[%w%-_%.]+%.[ot]tf$') ~= nil
end

local function warn(msg)
    print(('^3[pup-ui theme]^7 %s'):format(msg))
end

local function resolve()
    local cfg = Config.Theme or {}
    local presets = Config.ThemePresets or {}
    local name = tostring(cfg.preset or 'dusk')
    local preset = presets[name]
    if not preset then
        warn(("preset '%s' doesn't exist, using 'dusk'"):format(name))
        name, preset = 'dusk', presets.dusk or { colors = {}, fonts = {} }
    end

    local out = { preset = name, colors = {}, fonts = {} }
    for _, slot in ipairs(SLOTS) do
        local mine = (cfg.colors or {})[slot]
        if mine ~= nil and not isColour(mine) then
            warn(("colors.%s = '%s' isn't a colour, using the preset's"):format(slot, tostring(mine)))
            mine = nil
        end
        out.colors[slot] = mine or (preset.colors or {})[slot]
    end
    for _, slot in ipairs(FONT_SLOTS) do
        local mine = (cfg.fonts or {})[slot]
        if mine ~= nil and not isFontFile(mine) then
            warn(("fonts.%s = '%s' must be a file name like 'myfont.ttf', using the preset's"):format(slot, tostring(mine)))
            mine = nil
        end
        out.fonts[slot] = mine or (preset.fonts or {})[slot]
    end
    return out
end

PupTheme = resolve()

-- on the server, say so once if a named font file isn't in html/fonts (the page then falls back to Georgia)
if IsDuplicityVersion() then
    for slot, file in pairs(PupTheme.fonts) do
        if file and not LoadResourceFile(GetCurrentResourceName(), 'html/fonts/' .. file) then
            warn(("fonts.%s: html/fonts/%s isn't there"):format(slot, file))
        end
    end
end

exports('GetTheme', function()
    return PupTheme
end)
