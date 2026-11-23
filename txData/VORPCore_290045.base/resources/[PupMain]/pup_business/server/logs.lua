-- pup_business | Discord logs and the activity feed

COLOUR = {
    green = 65280,
    red = 16711680,
    yellow = 16776960,
    orange = 16753920,
    blue = 3447003,
}

local HOSTS <const> = {
    ['discord.com'] = true,
    ['discordapp.com'] = true,
    ['ptb.discord.com'] = true,
    ['canary.discord.com'] = true,
}

-- only real Discord webhook URLs are accepted anywhere
function ValidWebhook(url)
    if type(url) ~= 'string' or url == '' or #url > 200 then return false end
    local host, id, token = url:match('^https://([%w%.]+)/api/webhooks/(%d+)/([%w_%-]+)$')
    return host ~= nil and HOSTS[host:lower()] == true and id ~= nil and token ~= nil
end

-- the business's own URL, else the secrets fallback; nil when logs are off
function BusinessWebhook(job)
    if not Config.BusinessLogs then return nil end
    local b = Biz[job]
    if not b or not b.webhook then return nil end
    local own = LedgerInfo[job] and LedgerInfo[job].webhook
    if ValidWebhook(own) then return own end
    local fb = Secrets.JobWebhooks[job]
    if ValidWebhook(fb) then return fb end
    return nil
end

local function post(url, embed)
    PerformHttpRequest(url, function(status)
        if status and status >= 300 then Dbg('webhook answered', status) end
    end, 'POST', json.encode({ username = 'Society Logs', embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

-- builds a field list, skipping missing values: F(name, value, inline), ...
function F(name, value, inline)
    if value == nil or value == '' then return false end
    return { name = name, value = tostring(value), inline = inline == true }
end

local function collectFields(fields)
    local out = {}
    if type(fields) ~= 'table' then return out end
    local n = fields.n or #fields
    for i = 1, n do
        local f = fields[i]
        if type(f) == 'table' and #out < 25 then out[#out + 1] = f end
    end
    return out
end

-- fields: table.pack(F(...), F(...)) so missing entries are skipped
function SendLog(job, title, colour, fields, description)
    local embed = {
        title = tostring(title or ''),
        description = description,
        color = colour or Config.DefaultEmbedColour,
        footer = { text = RES },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        fields = collectFields(fields),
    }
    local url = BusinessWebhook(job)
    if url then post(url, embed) end

    if Config.AdminMirror and ValidWebhook(Secrets.AdminWebhook) then
        local copy = {
            title = embed.title, description = embed.description, color = embed.color,
            footer = embed.footer, timestamp = embed.timestamp, fields = {},
        }
        for i, f in ipairs(embed.fields) do copy.fields[i] = f end
        if job and #copy.fields < 25 then copy.fields[#copy.fields + 1] = { name = 'Business', value = tostring(job), inline = true } end
        post(Secrets.AdminWebhook, copy)
    end
end

-- "**Name**\nChar ID: n", or the player name when no character is loaded
function WhoText(src)
    local ch = GetChar(src)
    if ch then return ('**%s**\nChar ID: %s'):format(FullName(ch), tostring(ch.charIdentifier)) end
    return GetPlayerName(src) or ('ID %s'):format(tostring(src))
end

-- before, change and the after read back from the database
function LedgerText(before, delta, after)
    local sign = (delta or 0) < 0 and '-' or '+'
    return ('%s %s%s -> **%s**'):format(PB.money(before or 0), sign, PB.money(math.abs(delta or 0)), PB.money(after or 0))
end

---------------------------------------------------------------------------
-- activity feed
---------------------------------------------------------------------------

function Activity(job, kind, detail, actor)
    if not Biz[job] or kind == 'DUTY' then return end
    detail = tostring(detail or ''):sub(1, 255)
    actor = tostring(actor or ''):sub(1, 100)
    MySQL.insert('INSERT INTO society_activity (job, ts, type, detail, actor) VALUES (?, ?, ?, ?, ?)',
        { job, Now(), tostring(kind):sub(1, 20), detail, actor }, function()
            if math.random(1, math.max(1, Config.ActivityTrimOneIn)) ~= 1 then return end
            MySQL.update([[
                DELETE FROM society_activity WHERE job = ? AND id NOT IN (
                    SELECT id FROM (SELECT id FROM society_activity WHERE job = ? ORDER BY ts DESC, id DESC LIMIT ?) AS keep
                )]], { job, job, Config.ActivityKeep })
        end)
end
