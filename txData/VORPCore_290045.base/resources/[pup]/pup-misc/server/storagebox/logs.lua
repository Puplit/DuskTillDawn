-- storagebox | Discord logs. Webhooks come from Secrets.Webhooks.storagebox (server/config.lua);
-- an empty value turns that log off.

local S = PupSBX
local C = StorageBoxConfig

S.Colour = {
    created       = 3447003,
    addedIn       = 5763719,
    takenOut      = 15105570,
    transferred   = 5763719,
    deposited     = 15158332,
    emptyStored   = 3447003,
    packUnloaded  = 5763719,
    packStored    = 3447003,
    placed        = 16753920,
    pickedUp      = 10181046,
    opened        = 3447003,
    given         = 3447003,
    robbed        = 15105570,
    deleted       = 15548997,
    shopTake      = 15105570,
    shopBuy       = 3066993,
    shopConsumed  = 15158332,
    shopStocked   = 15105570,
    society       = { take = 15105570, move = 5763719 },
    typeLog       = 3066993,
}

local function hooks()
    local w = Secrets and Secrets.Webhooks and Secrets.Webhooks.storagebox
    return type(w) == 'table' and w or {}
end

local function post(url, payload)
    if type(url) ~= 'string' or url == '' then return end
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function timestamp() return os.date('!%Y-%m-%dT%H:%M:%SZ') end

local function cut(s, n)
    s = tostring(s or '')
    if #s > n then return s:sub(1, n - 3) .. '...' end
    return s
end

function S.discordMention(src)
    local id = GetPlayerIdentifierByType(src, 'discord')
    if not id then return 'no Discord linked' end
    return ('<@%s>'):format((id:gsub('^discord:', '')))
end

local function playerField(src)
    local ch = S.char(src)
    return ('%s %s\nID: %s | Char: %s'):format(S.charName(ch), S.discordMention(src), tostring(src),
        tostring(ch and ch.charIdentifier or '?'))
end

-- a JSON list of the stacks, cut to fit an embed field
function S.contentsText(list)
    if type(list) ~= 'table' or #list == 0 then return '*(empty)*' end
    local rows = {}
    for _, e in ipairs(list) do
        local r = { item = e.name, amount = e.amount or e.count }
        if type(e.metadata) == 'table' and next(e.metadata) then r.metadata = e.metadata end
        rows[#rows + 1] = r
    end
    return '```json\n' .. cut(json.encode(rows), 900) .. '\n```'
end

-- "<label>:  <before> -> <after>  (+n)" in the module's change-field format
function S.changeText(label, before, after)
    before, after = tonumber(before) or 0, tonumber(after) or 0
    local d = after - before
    local tail
    if before == 0 and d > 0 then tail = ('(new item, +%d)'):format(d)
    elseif d >= 0 then tail = ('(+%d)'):format(d)
    else tail = ('(%d)'):format(d) end
    return ('%s:  %d → %d  %s'):format(tostring(label), before, after, tail)
end

-- main log: fields = { { 'Name', 'value' }, ... }; src adds the Player field first
function S.log(title, colour, src, fields)
    local out = {}
    if src then out[#out + 1] = { name = 'Player', value = cut(playerField(src), 1024), inline = false } end
    for _, f in ipairs(fields or {}) do
        if f[2] ~= nil then
            out[#out + 1] = { name = cut(f[1], 256), value = cut(f[2], 1024), inline = false }
        end
    end
    S.debug(('log: %s'):format(title))
    post(hooks().main, {
        username = C.LogUsername,
        embeds = { { title = cut(title, 256), color = colour, fields = out, timestamp = timestamp() } },
    })
end

------------------------------------------------------------------------------ society (business containers)
-- taken = true for a withdrawal from the business, false for a deposit into it
function S.societyLog(src, containerId, taken, lines, boxId)
    CreateThread(function()
        local job = S.scalar('SELECT name FROM container WHERE id = ? LIMIT 1', { tonumber(containerId) or containerId })
        job = job and tostring(job) or tostring(containerId)
        local own = S.scalar('SELECT webhook FROM society_ledger WHERE job = ? LIMIT 1', { job })
        local ch = S.char(src)
        local who = {}
        if C.Switches.SteamInLogs then who[#who + 1] = ('Steam name: %s'):format(tostring(GetPlayerName(src))) end
        who[#who + 1] = ('Character: %s'):format(S.charName(ch))
        who[#who + 1] = ('Server ID: %s'):format(tostring(src))
        if C.Switches.SteamInLogs then who[#who + 1] = ('Steam ID: %s'):format(tostring(ch and ch.identifier or '?')) end
        local body = {}
        for _, l in ipairs(lines or {}) do
            body[#body + 1] = ('Has Transferred %d %s %s %s Inventory'):format(l.amount, tostring(l.label), taken and 'From' or 'To', job)
        end
        local payload = {
            username = C.LogUsername,
            embeds = { {
                title = taken and 'Take from inventory Log' or 'Move to inventory Log',
                color = taken and S.Colour.society.take or S.Colour.society.move,
                description = cut(table.concat(who, '\n') .. '\n\n' .. table.concat(body, '\n'), 4000),
                footer = { text = ('Box ID: %s'):format(tostring(boxId)) },
                timestamp = timestamp(),
            } },
        }
        if type(own) == 'string' and own:match('^https://') then post(own, payload) end
        post(hooks().societyAdmin, payload)
    end)
end

------------------------------------------------------------------------------ per-type admin logs
local function campName(clanId)
    local info = S.scalar('SELECT info FROM clan WHERE id = ? LIMIT 1', { tonumber(clanId) or -1 })
    local t = S.decodeMeta(info)
    return t.name or t.gang_name or t.clanName or t.label or tostring(clanId)
end

-- kind: 'clan' | 'hideout' | 'house' | 'custom'; action: 'Deposited to:' | 'Withdrew from:' | 'Transferred:'
function S.typeLog(src, kind, invId, action, itemLabel, amount)
    if not C.Switches.TypeWebhooks then return end
    CreateThread(function()
        local h = hooks()
        local ch = S.char(src)
        if kind == 'house' then
            local lines = {
                ('Player: %s'):format(S.charName(ch)),
                C.Switches.SteamInLogs and ('Steam ID: %s'):format(tostring(ch and ch.identifier or '?')) or nil,
                ('Character ID: %s'):format(tostring(ch and ch.charIdentifier or '?')),
                ('%s %d'):format(action, tonumber(amount) or 0),
                ('Item: %s'):format(tostring(itemLabel)),
                ('House: %s'):format(tostring(invId)),
                ('Discord: %s'):format(S.discordMention(src)),
                C.Switches.SteamInLogs and ('Steam name: %s'):format(tostring(GetPlayerName(src))) or nil,
            }
            local body = {}
            for i = 1, 8 do if lines[i] then body[#body + 1] = lines[i] end end
            post(h.housingAdmin, { username = C.LogUsername, embeds = { {
                title = 'Housing Logs', color = S.Colour.typeLog, description = table.concat(body, '\n'), timestamp = timestamp(),
            } } })
            return
        end
        local label, name, url
        if kind == 'clan' then label, name, url = 'Clan Name', campName(invId), h.clanAdmin
        elseif kind == 'hideout' then label, name, url = 'Hideout ID', tostring(invId), h.hideoutAdmin
        else label, name, url = 'Inventory', tostring(invId), h.customAdmin end
        local body = table.concat({
            ('Player: %s'):format(S.charName(ch)),
            ('%s %s %s'):format(action, label, name),
            ('Item: %s'):format(tostring(itemLabel)),
            ('Amount: %d'):format(tonumber(amount) or 0),
            ('Discord: %s'):format(S.discordMention(src)),
        }, '\n')
        post(url, { username = C.LogUsername, embeds = { { color = S.Colour.typeLog, description = body, timestamp = timestamp() } } })
    end)
end

-- which per-type log an inventory belongs to
function S.kindOf(invType, invId)
    if invType == 'clan' then return 'clan' end
    if invType == 'hideout' then return 'hideout' end
    if type(invId) == 'string' and invId:sub(1, 6) == 'house_' then return 'house' end
    return 'custom'
end
