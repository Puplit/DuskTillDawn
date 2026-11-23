-- pup_hideouts | Discord logs. Only the server fires these, after the thing happened.

Logs = {}

local RES <const> = GetCurrentResourceName()

local function valid(url) return type(url) == 'string' and U.validWebhook(url) ~= nil end

local function post(url, embed)
    if not valid(url) then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode({
        username = Config.Logs.username,
        embeds = { embed },
    }), { ['Content-Type'] = 'application/json' })
end

local function cut(s, n)
    s = tostring(s or '')
    if #s > n then return s:sub(1, n - 3) .. '...' end
    return s
end

-- player block. full = staff copy (with Steam / Discord identity)
local function playerField(src, full)
    local c = src and HX.char(src)
    local cid = c and c.charIdentifier or '?'
    local name = HX.fullName(c)
    local lines = { ('Char ID: %s'):format(tostring(cid)), ('Name: %s'):format(name) }
    if full and src then
        local steam = GetPlayerIdentifierByType(src, 'steam') or 'Unknown'
        local discord = GetPlayerIdentifierByType(src, 'discord')
        lines[#lines + 1] = ('Steam ID: %s'):format(steam)
        lines[#lines + 1] = ('Discord: %s'):format(discord and ('<@' .. discord:gsub('discord:', '') .. '>') or 'Not Linked')
        lines[#lines + 1] = ('Steam Name: %s'):format(GetPlayerName(src) or 'Unknown')
    end
    return { name = 'Player Information', value = cut(table.concat(lines, '\n'), 1000), inline = false }
end

local function build(title, desc, color, src, fields, h, full)
    local all = { playerField(src, full) }
    for _, f in ipairs(fields or {}) do
        all[#all + 1] = { name = tostring(f[1]), value = cut(f[2], 1000), inline = f[3] == true }
    end
    if h then
        all[#all + 1] = { name = 'Hideout', value = cut(h.name, 200), inline = true }
        all[#all + 1] = { name = 'Hideout ID', value = tostring(h.id), inline = true }
    end
    return {
        title = title, description = cut(desc, 2000),
        color = tonumber(color) or Config.Logs.colors.default,
        fields = all,
        footer = { text = RES },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
end

-- category: Main | Raids | Missions | Ledger | Inventory | Production | Sales
-- fields: { { name, value [, inline] }, ... }
function Logs.send(category, title, desc, colorKey, src, fields, h)
    if not Config.Logs.enabled then return end
    local color = Config.Logs.colors[colorKey] or colorKey
    post(Secrets.Webhooks[category], build(title, desc, color, src, fields, h, true))

    -- the owner's own channel: only for a member's own action, and only for owner categories
    if h and h.webhook and Config.Logs.ownerWebhooks and Config.Logs.ownerCategories[category] then
        local cid = src and HX.charId(src)
        if cid and HX.isMember(h, cid) then
            post(h.webhook, build(title, desc, color, src, fields, h, false))
        end
    end
end

-- one-off post to a single URL (the "connected" message)
function Logs.direct(url, title, desc, colorKey, src, h)
    if not Config.Logs.enabled then return end
    post(url, build(title, desc, Config.Logs.colors[colorKey] or colorKey, src, {}, h, false))
end

-- "Name (charid), Name (charid)" or "Riding alone", cut for Discord
function Logs.posseNames(sources)
    local parts = {}
    for _, s in ipairs(sources or {}) do
        parts[#parts + 1] = ('%s (%s)'):format(HX.nameOf(s), tostring(HX.charId(s) or '?'))
    end
    if #parts <= 1 then return 'Riding alone' end
    return cut(table.concat(parts, ', '), 1000)
end
