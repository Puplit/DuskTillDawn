-- pup_camps | Discord logging
-- Camp logs: the camp's own channel (only while the actor is still a member, or no actor)
-- plus the staff mirror. Raid logs: raid channel only. Butcher logs: butcher channel only.

local C = Config.Logs.colours
LogColour = C

local function post(url, embed)
    if not U.isWebhook(url) then return end
    local body = json.encode({ username = Config.Logs.senderName, embeds = { embed } })
    PerformHttpRequest(url, function(status)
        if status and status >= 400 and status ~= 429 then
            U.debug('webhook post failed', status)
        end
    end, 'POST', body, { ['Content-Type'] = 'application/json' })
end

local function clip(s, n)
    s = tostring(s or '')
    if #s > n then return s:sub(1, n - 3) .. '...' end
    return s
end
Clip = clip

-- the "who" block for a player
function Who(src, camp)
    if not src or src == 0 then return 'Console' end
    local p = Players[src]
    local ch = CharOf(src)
    local lines = {}
    lines[#lines + 1] = ('**%s**'):format(ch and FullName(ch) or (p and p.name) or 'Unknown')
    local charid = ch and ch.charIdentifier or (p and p.charid)
    lines[#lines + 1] = ('Char ID: %s'):format(tostring(charid or '?'))
    if camp and charid then
        local rank, leader = RankOf(camp, charid)
        if leader then lines[#lines + 1] = 'Rank: Leader'
        elseif rank then lines[#lines + 1] = 'Rank: ' .. U.rankLabel(rank) end
    end
    local discord = GetPlayerIdentifierByType(tostring(src), 'discord')
    if discord then lines[#lines + 1] = ('<@%s>'):format(discord:gsub('^discord:', '')) end
    lines[#lines + 1] = ('Player: %s'):format(GetPlayerName(src) or '?')
    lines[#lines + 1] = ('Source ID: %d'):format(src)
    return table.concat(lines, '\n')
end

function PosseNames(src)
    if not src or not Integrations.running('pup-ui') then return 'Riding alone' end
    local ok, p = pcall(function() return exports['pup-ui']:GetPosse(src) end)
    if not ok or type(p) ~= 'table' or not p.inPosse or type(p.members) ~= 'table' then return 'Riding alone' end
    local names = {}
    for _, m in ipairs(p.members) do names[#names + 1] = tostring(m.name or '?') end
    if #names == 0 then return 'Riding alone' end
    return clip(table.concat(names, ', '), 1000)
end

local function embed(title, colour, fields, description)
    local list = {}
    for i, f in ipairs(fields or {}) do
        if i > 25 then break end
        list[#list + 1] = { name = clip(f[1], 256), value = clip(f[2] ~= nil and f[2] ~= '' and f[2] or '-', 1024), inline = f[3] == true }
    end
    return {
        title = clip(title, 256),
        description = description and clip(description, 4000) or nil,
        color = colour or Config.Logs.defaultColour,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = GetCurrentResourceName() },
        fields = list,
    }
end

local function enabled(category)
    if not Config.Logs.enabled then return false end
    if category == 'always' then return true end
    return Config.Logs.categories[category] == true
end

-- opts: actor (src), system (true = treat as no actor for routing), description
function CampLog(camp, category, title, colour, fields, opts)
    if not enabled(category) or not camp then return end
    opts = opts or {}
    local e = embed(title, colour, fields, opts.description)

    local actor = (not opts.system) and opts.actor or nil
    local ownOk = Config.Logs.campWebhooks and camp.webhook and camp.webhook ~= ''
    if ownOk and actor and actor ~= 0 then
        local p = Players[actor]
        ownOk = p ~= nil and RankOf(camp, p.charid, p.identifier) ~= nil
    end
    if ownOk then post(camp.webhook, e) end

    if Secrets.campLogMirror ~= '' then
        local m = embed(title, colour, fields, opts.description)
        m.fields[#m.fields + 1] = { name = 'Camp', value = ('%s #%d'):format(clip(camp.name, 200), camp.id), inline = false }
        if #m.fields > 25 then table.remove(m.fields, 25) end
        post(Secrets.campLogMirror, m)
    end
end

function RaidLog(camp, title, colour, fields)
    if not enabled('raid') or Secrets.raids == '' then return end
    local f = {}
    for _, x in ipairs(fields or {}) do f[#f + 1] = x end
    f[#f + 1] = { 'Camp', camp and camp.name or '?', true }
    f[#f + 1] = { 'Camp ID', tostring(camp and camp.id or '?'), true }
    post(Secrets.raids, embed(title, colour or C.purple, f))
end

function ButcherLog(title, colour, fields)
    if not Config.Logs.enabled or Secrets.butcher == '' then return end
    post(Secrets.butcher, embed(title, colour, fields))
end

-- the one-off test message when a leader connects a channel
function ConnectLog(camp, src)
    if not enabled('always') then return end
    post(camp.webhook, embed('Camp Log Connected', C.blue, { { 'Set by', Who(src, camp) } }))
end

function MoneyText(n) return U.money(n) end
