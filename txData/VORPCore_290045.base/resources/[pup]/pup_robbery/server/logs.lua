-- pup_robbery | Discord logs: one webhook (server/config.lua), one embed per event

Logs = {}

Logs.RED, Logs.GREEN, Logs.BLUE, Logs.BANK_GREEN, Logs.ORANGE, Logs.GOLD = 16711680, 3066993, 255, 65280, 16744192, 15844367

local function clean(s)
    return (tostring(s or ''):gsub('`', "'"))
end
Logs.clean = clean

local function discordMention(src)
    local id = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, 'discord') or nil
    if not id then
        for _, ident in ipairs(GetPlayerIdentifiers(src) or {}) do
            if ident:sub(1, 8) == 'discord:' then id = ident break end
        end
    end
    if not id then return nil end
    return '<@' .. id:gsub('^discord:', '') .. '>'
end

-- who did it, and who rode with them
function Logs.robber(src)
    if not src or not S.online(src) then return '**Robber:** disconnected' end
    local lines = {}
    lines[#lines + 1] = ('**Character:** `%s`'):format(clean(S.charName(src)))
    local mention = discordMention(src)
    if mention then lines[#lines + 1] = ('**Discord:** %s'):format(mention) end
    lines[#lines + 1] = ('**Char ID:** `%s`'):format(tostring(S.charId(src) or '?'))
    lines[#lines + 1] = ('**Player:** `%s` (ID %d)'):format(clean(GetPlayerName(src)), src)
    local p = S.pos(src)
    if p then lines[#lines + 1] = ('**Position:** `%.1f, %.1f, %.1f`'):format(p.x, p.y, p.z) end
    local others = {}
    for _, m in ipairs(S.posseMembers(src)) do
        if m ~= src then
            others[#others + 1] = ('- `%s` (char %s, ID %d)'):format(clean(S.charName(m)), tostring(S.charId(m) or '?'), m)
        end
    end
    lines[#lines + 1] = '**POSSE**'
    lines[#lines + 1] = #others > 0 and table.concat(others, '\n') or 'riding alone'
    return table.concat(lines, '\n')
end

function Logs.send(title, colour, description)
    local hook = Secrets and Secrets.webhook or ''
    if hook == '' then return end
    local body = {
        username = Config.Discord.username,
        embeds = { {
            title = title,
            color = colour,
            description = tostring(description or ''):sub(1, 4000),
            footer = { text = ('pup_robbery | %s'):format(os.date('%Y-%m-%d %H:%M:%S')) },
        } },
    }
    if Config.Discord.avatar ~= '' then body.avatar_url = Config.Discord.avatar end
    PerformHttpRequest(hook, function() end, 'POST', json.encode(body), { ['Content-Type'] = 'application/json' })
end
