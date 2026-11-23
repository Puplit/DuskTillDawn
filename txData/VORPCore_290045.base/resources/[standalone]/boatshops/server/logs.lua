-- boatshops | Discord logs for buys, sales, transfers and upgrades (server)

BoatLog = {}

local function webhookFor(kind)
    local s = BoatLogs[kind]
    local url = s and s.webhook
    if type(url) ~= 'string' or url == '' then
        url = BoatLogs.buy and BoatLogs.buy.webhook
    end
    if type(url) ~= 'string' or url == '' then return nil end
    return url
end

local function ident(src, kind)
    local id = GetPlayerIdentifierByType(src, kind)
    if type(id) ~= 'string' or id == '' then return nil end
    return id
end

function BoatLog.player(src, ch)
    local discord = ident(src, 'discord')
    discord = discord and ('<@%s>'):format((discord:gsub('^discord:', ''))) or 'N/A'
    local licence = ident(src, 'license') or ident(src, 'steam') or 'N/A'
    local pos = 'N/A'
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local c = GetEntityCoords(ped)
        pos = ('%.1f, %.1f, %.1f'):format(c.x, c.y, c.z)
    end
    return table.concat({
        ('**Character:** %s %s (id %s)'):format(tostring(ch and ch.firstname or '?'), tostring(ch and ch.lastname or ''), tostring(ch and ch.charIdentifier or '?')),
        ('**Job:** %s (grade %s)'):format(tostring(ch and ch.job or '?'), tostring(ch and ch.jobGrade or '?')),
        ('**Discord:** %s'):format(discord),
        ('**Player:** %s [%s]'):format(tostring(GetPlayerName(src) or '?'), tostring(src)),
        ('**Licence:** %s'):format(licence),
        ('**Position:** %s'):format(pos),
    }, '\n')
end

function BoatLog.boat(row, comps)
    local parts = {}
    for _, c in ipairs(BoatConfig.Categories) do
        if comps and comps[c] ~= nil then parts[#parts + 1] = ('%s=%s'):format(c, tostring(comps[c])) end
    end
    return table.concat({
        ('**Name:** %s'):format(tostring(row.name)),
        ('**Model:** %s'):format(tostring(row.boat)),
        ('**Row id:** %s'):format(tostring(row.id)),
        ('**Fitted:** %s'):format(#parts > 0 and table.concat(parts, ', ') or 'none'),
    }, '\n')
end

-- kind: buy | sell | give | upgrade; fields: { { name, value, inline } }
function BoatLog.send(kind, src, description, fields)
    local s = BoatLogs[kind]
    local url = webhookFor(kind)
    if not s or not url then return end

    local all = {}
    for _, f in ipairs(fields or {}) do
        all[#all + 1] = { name = tostring(f[1]), value = tostring(f[2]):sub(1, 1024), inline = f[3] == true }
    end
    all[#all + 1] = { name = 'Resource', value = GetCurrentResourceName(), inline = true }
    all[#all + 1] = { name = 'Server Time', value = os.date('%Y-%m-%d %H:%M:%S'), inline = true }

    local embed = {
        title = s.title,
        color = s.colour,
        description = description:format(tostring(GetPlayerName(src) or '?')),
        fields = all,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = s.name },
    }
    if s.footerIcon and s.footerIcon ~= '' then embed.footer.icon_url = s.footerIcon end
    if s.logo and s.logo ~= '' then embed.thumbnail = { url = s.logo } end

    local payload = { embeds = { embed } }
    if s.name and s.name ~= '' then payload.username = s.name end
    if s.avatar and s.avatar ~= '' then payload.avatar_url = s.avatar end

    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end
