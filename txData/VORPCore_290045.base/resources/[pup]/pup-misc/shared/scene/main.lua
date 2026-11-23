-- pup-misc / scene - inline colour markup (client and server), on top of the style bar's one colour:
--     [red]wanted [gold]dead or alive
-- Each tag switches the colour from that point on; anything before the first tag uses the scene's style colour

local function colourMap()
    return (SceneConfig and SceneConfig.Styles.inlineColours) or {}
end

--- Which word indices take the accent colour, per effect id.
local PATTERN <const> = {
    first = function(i) return i == 1 end,
    last  = function(i, n) return i == n end,
    edges = function(i, n) return i == 1 or i == n end,
    rest  = function(i) return i > 1 end,
    alt   = function(i) return i % 2 == 0 end,
}

--- Does this text carry a colour tag the player typed themselves?
local function hasManualTag(text)
    local map <const> = colourMap()
    for name in text:gmatch('%[([%a_]+)%]') do
        if map[name:lower()] then return true end
    end
    return false
end

-- The base colour as a TOKEN
local function baseToken(st)
    for _, c in ipairs((SceneConfig and SceneConfig.Styles.palette) or {}) do
        if c.r == st.r and c.g == st.g and c.b == st.b then
            return c.token or 'COLOR_PURE_WHITE'
        end
    end
    return 'COLOR_PURE_WHITE'
end

-- Paint whole words, no typing required
local function applyPattern(text, st)
    local pick <const> = PATTERN[st.pattern]
    if not pick then return text end

    local accent <const> = colourMap()[tostring(st.accent):lower()]
    if not accent then return text end

    local words = {}
    for w in text:gmatch('%S+') do words[#words + 1] = w end
    local n <const> = #words
    if n == 0 then return text end

    local base <const> = baseToken(st)
    local out = {}
    for i, w in ipairs(words) do
        out[i] = '~' .. (pick(i, n) and accent or base) .. '~' .. w
    end
    return table.concat(out, ' ')
end

-- '[red]wanted [gold]dead' -> '~COLOR_RED~wanted ~COLOR_GOLD~dead' An unrecognised tag is left exactly as typed
function SceneMarkupApply(text, st)
    if type(text) ~= 'string' then return '' end

    local manual <const> = hasManualTag(text)

    local map <const> = colourMap()
    local tagged <const> = text:gsub('%[([%a_]+)%]', function(name)
        local token = map[name:lower()]
        if token then return '~' .. token .. '~' end
        return '[' .. name .. ']'
    end)

    if manual or type(st) ~= 'table' then return tagged end
    if not st.accent or st.accent == '' then return tagged end
    if not st.pattern or st.pattern == 'none' then return tagged end

    return applyPattern(tagged, st)
end

-- Colour tokens as rgb, for the overlay renderer
local TOKEN_RGB <const> = {
    COLOR_PURE_WHITE = { 255, 255, 255 }, COLOR_WHITE  = { 239, 230, 213 }, COLOR_GOLD   = { 214, 173, 90 },
    COLOR_RED        = { 168, 50, 50 },   COLOR_ORANGE = { 186, 100, 46 },  COLOR_GREEN  = { 110, 140, 86 },
    COLOR_BLUE       = { 108, 158, 190 }, COLOR_PURPLE = { 146, 104, 178 }, COLOR_GREY   = { 140, 144, 148 },
    COLOR_BLACK      = { 20, 20, 20 },    COLOR_YELLOW = { 226, 196, 84 },
}

-- The label as coloured runs: { { t = 'wanted ', r, g, b }, ... }. Runs before the first tag use the style colour.
function SceneMarkupSegments(text, st)
    local shown <const> = SceneMarkupApply(text, st)
    local base <const> = { st and st.r or 255, st and st.g or 255, st and st.b or 255 }
    local segs, cur, pos = {}, base, 1
    local function push(s)
        if s ~= '' then segs[#segs + 1] = { t = s, r = cur[1], g = cur[2], b = cur[3] } end
    end
    while true do
        local a, b, token = shown:find('~([%w_]+)~', pos)
        if not a then break end
        push(shown:sub(pos, a - 1))
        cur = TOKEN_RGB[token] or cur
        pos = b + 1
    end
    push(shown:sub(pos))
    if #segs == 0 then segs[1] = { t = '', r = base[1], g = base[2], b = base[3] } end
    return segs
end

-- Length of what actually APPEARS on screen, tags removed
function SceneMarkupVisibleLength(text)
    if type(text) ~= 'string' then return 0 end
    local map <const> = colourMap()
    local stripped <const> = text:gsub('%[([%a_]+)%]', function(name)
        if map[name:lower()] then return '' end
        return '[' .. name .. ']'
    end)
    return #stripped
end

--- Server-side gate: no raw game text token ever reaches storage.
function SceneMarkupSanitise(text)
    if type(text) ~= 'string' then return '' end
    local out <const> = text:gsub('~', '')
    return out
end
