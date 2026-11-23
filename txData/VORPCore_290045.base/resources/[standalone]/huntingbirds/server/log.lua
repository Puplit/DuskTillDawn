-- huntingbirds | Discord log: purchases, sell-backs, trades and refused requests

BirdLog = {}

local COLOURS <const> = { green = 3066993, blue = 3447003, red = 15158332 }
local recent = {} -- [src] = { times }

-- text from players (bird names): no control, markdown or mention characters, at most 40 characters
function BirdLog.clean(v)
    local s = tostring(v or ''):gsub('%c', ''):gsub('[@<>`*_~|\\#%[%]]', '')
    s = s:sub(1, 40)
    if s == '' then return '?' end
    return s
end

local function allowed(src)
    local max, window = tonumber(Config.Discord.maxPosts) or 0, tonumber(Config.Discord.windowSec) or 10
    if max <= 0 then return true end
    local now = os.time()
    local keep = {}
    for _, t in ipairs(recent[src] or {}) do
        if now - t < window then keep[#keep + 1] = t end
    end
    if #keep >= max then recent[src] = keep return false end
    keep[#keep + 1] = now
    recent[src] = keep
    return true
end

function BirdLog.who(src, char)
    if not char then return ('Server ID: %s'):format(tostring(src)) end
    return ('%s %s (char %s, server ID %s)'):format(
        BirdLog.clean(char.firstname), BirdLog.clean(char.lastname), tostring(char.charIdentifier), tostring(src))
end

-- colour: 'green' | 'blue' | 'red'; lines: list of { label, value }
function BirdLog.post(src, title, colour, lines)
    local url = BirdSecrets and BirdSecrets.webhook or ''
    if url == '' then return end
    if src and not allowed(src) then return end

    local text = {}
    for _, l in ipairs(lines or {}) do
        text[#text + 1] = ('**%s:** %s'):format(l[1], tostring(l[2]))
    end
    local payload = {
        username = Config.Discord.username or 'Hunting Birds',
        embeds = { {
            title = title,
            color = COLOURS[colour] or COLOURS.blue,
            description = table.concat(text, '\n'),
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        } },
    }
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

function BirdLog.refused(src, char, what, detail)
    BirdLog.post(src, 'Refused request', 'red', {
        { 'Player', BirdLog.who(src, char) },
        { 'Request', what },
        { 'Detail', detail or '-' },
    })
end

AddEventHandler('playerDropped', function()
    recent[tonumber(source) or -1] = nil
end)
