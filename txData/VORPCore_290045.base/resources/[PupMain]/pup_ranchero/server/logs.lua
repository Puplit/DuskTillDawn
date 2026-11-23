-- pup_ranchero | activity feed, per-character stats and Discord logs

------------------------------------------------------------------------------
-- activity feed (ranch_activity); vorp_admin filters on the type strings
------------------------------------------------------------------------------
local ACTIVITY_TYPES = {}
for _, t in ipairs({ 'BUY', 'TRANSFER', 'HIRE', 'QUIT', 'FIRE', 'WITHDRAW', 'DEPOSIT', 'SPEND', 'INCOME', 'CATTLE_BUY',
    'HERD', 'HERD_FAIL', 'SALE', 'SALE_FAIL', 'PVP_LOSS', 'CHEAT_REPORT', 'CHORE', 'MILK', 'EGGS', 'TAX', 'REPO',
    'ADMIN_MOVE', 'ADMIN_TRANSFER', 'ADMIN_DELETE', 'ADMIN_HIRE', 'ADMIN_FIRE', 'ADMIN_RANK' }) do
    ACTIVITY_TYPES[t] = true
end

function Activity(rid, kind, detail, actor)
    if not ACTIVITY_TYPES[kind] then print('[pup_ranchero] unknown activity type ' .. tostring(kind)) return end
    local now = os.time()
    MySQL.insert('INSERT INTO ranch_activity (ranchid, ts, type, detail, actor) VALUES (?, ?, ?, ?, ?)',
        { tonumber(rid) or 0, now, kind, U.cut(detail, 191), U.cut(actor, 100) })
    if math.random(1, 10) == 1 then
        MySQL.update('DELETE FROM ranch_activity WHERE ts < ?', { now - Config.Timers.activityDays * 86400 })
    end
end

------------------------------------------------------------------------------
-- per-character stats (ranch_stats); period columns p_* are reset by an external bot
------------------------------------------------------------------------------
local STAT_FIELDS = {
    milk = true, eggs = true, chores = true, chore_score = false, herds = true,
    herd_animals = true, herd_lost = true, herd_quality = true, cattle_money = true,
}

local function discordId(src)
    local id = src and GetPlayerIdentifierByType(tostring(src), 'discord')
    if not id then return '' end
    return (tostring(id):match('^discord:(%d+)$')) or ''
end

-- fields: { milk = 5, chores = 1, ... }
function Stat(ctx, rid, fields)
    if not ctx or not ctx.charid or not rid or rid == 0 then return end
    local cols, vals, updates = {}, {}, {}
    for field, amount in pairs(fields) do
        local hasPeriod = STAT_FIELDS[field]
        if hasPeriod ~= nil and tonumber(amount) then
            cols[#cols + 1] = ('`%s`'):format(field)
            vals[#vals + 1] = amount
            updates[#updates + 1] = ('`%s` = `%s` + VALUES(`%s`)'):format(field, field, field)
            if hasPeriod then
                cols[#cols + 1] = ('`p_%s`'):format(field)
                vals[#vals + 1] = amount
                updates[#updates + 1] = ('`p_%s` = `p_%s` + VALUES(`p_%s`)'):format(field, field, field)
            end
        end
    end
    if #cols == 0 then return end
    local now = os.time()
    local params = { ctx.charid, rid, U.cut(ctx.name, 100), discordId(ctx.src), now, now }
    for _, v in ipairs(vals) do params[#params + 1] = v end
    local marks = {}
    for _ = 1, #vals do marks[#marks + 1] = '?' end
    local sql = ('INSERT INTO ranch_stats (charid, ranchid, name, discord, first_ts, last_ts, %s) VALUES (?, ?, ?, ?, ?, ?, %s) '
        .. "ON DUPLICATE KEY UPDATE name = VALUES(name), last_ts = VALUES(last_ts), "
        .. "discord = IF(VALUES(discord) = '', discord, VALUES(discord)), %s")
        :format(table.concat(cols, ', '), table.concat(marks, ', '), table.concat(updates, ', '))
    MySQL.insert(sql, params)
end

------------------------------------------------------------------------------
-- Discord
------------------------------------------------------------------------------
local function usable(url)
    return type(url) == 'string' and #url > 10
end

local function post(url, payload)
    if not usable(url) then return end
    payload.allowed_mentions = { parse = {} }
    PerformHttpRequest(url, function() end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

-- dest: 'ledger' | 'general' ; ranchToo = also the ranch's own webhook
local function targets(dest, r, ranchToo)
    local list = { Secrets[dest] }
    if ranchToo and r and r.webhook then list[#list + 1] = r.webhook end
    return list
end

-- plain titled message under "pup-ranch"
function LogPlain(dest, r, title, lines, ranchToo)
    if ranchToo == nil then ranchToo = true end
    local body = ('**%s**\n%s'):format(title, table.concat(lines, '\n'))
    for _, url in ipairs(targets(dest, r, ranchToo)) do
        post(url, { username = 'pup-ranch', content = U.cut(body, 1900) })
    end
end

LogColors = {
    green = 3066993, orange = 15105570, red = 15158332, blue = 3447003, yellow = 16776960,
}

-- embed under "Ranch Management System"; always the general webhook plus the ranch's own
function LogEmbed(r, title, color, fields)
    local f = {}
    for _, kv in ipairs(fields) do
        f[#f + 1] = { name = U.cut(kv[1], 250), value = U.cut(tostring(kv[2]), 1000), inline = kv[3] == true }
    end
    local embed = {
        title = title,
        color = color,
        fields = f,
        footer = { text = ('Ranch Management System | Ranch ID %d'):format(r and r.id or 0) },
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    for _, url in ipairs(targets('general', r, true)) do
        post(url, { username = 'Ranch Management System', embeds = { embed } })
    end
end

-- ledger movement shortcut: withdraw / deposit / purchase / income
function LogLedger(r, title, who, amount, what)
    local lines = {
        ('Who: %s'):format(who),
        ('Amount: $%s'):format(U.money(amount)),
    }
    if what then lines[#lines + 1] = ('For: %s'):format(what) end
    lines[#lines + 1] = ('Ranch ID: %d'):format(r.id)
    lines[#lines + 1] = ('Ledger now: $%s'):format(U.money(r.ledger))
    LogPlain('ledger', r, title, lines)
end

-- charge the ranch ledger; false when it cannot pay
function ChargeLedger(r, ctx, amount, what)
    amount = U.cents(amount)
    if amount < 0 or r.ledger + 1e-6 < amount then return false end
    r.ledger = U.cents(r.ledger - amount)
    Save(r, 'ledger')
    Activity(r.id, 'SPEND', ('%s for $%s (ledger $%s)'):format(what, U.money(amount), U.money(r.ledger)), ctx.name)
    LogLedger(r, 'Ranch Purchase', ctx.name, amount, what)
    return true
end
