-- pup_staffdesk | Discord ban commands: !ban, !unban, !banlist, !baninfo
-- The bans themselves live in vorp_admin (admin_bans, checked on connect). This file only drives them
-- from Discord, so a ban placed here and one placed in game are the same record.
local code = Bridge.code
local PER_PAGE <const> = 8

local function usage(name)
    local c = Bridge.commands[name]
    return Locale.dUsage:format(code(Bridge.prefix() .. name .. (c.usage ~= '' and (' ' .. c.usage) or '')))
end

local function adminUp()
    return GetResourceState('vorp_admin') == 'started' and Desk.hasTable('admin_bans')
end

local function clip(s, n)
    s = tostring(s or '')
    if #s > n then s = s:sub(1, n - 3) .. '...' end
    return s
end

-- 30m, 12h, 7d, 2w, perm -> seconds (0 = permanent); nil when it is not a length
local UNITS <const> = { m = 60, h = 3600, d = 86400, w = 604800 }
local function parseLength(s)
    s = tostring(s or ''):lower()
    if s == 'perm' or s == 'permanent' or s == 'forever' then return 0 end
    local n, u = s:match('^(%d+)([mhdw])$')
    n = tonumber(n)
    if not n or n < 1 then return nil end
    return n * UNITS[u]
end

local function lengthText(seconds)
    if seconds == 0 then return 'permanent' end
    for _, u in ipairs({ { 604800, 'week' }, { 86400, 'day' }, { 3600, 'hour' }, { 60, 'minute' } }) do
        if seconds % u[1] == 0 then
            local n = seconds // u[1]
            return ('%d %s%s'):format(n, u[2], n == 1 and '' or 's')
        end
    end
    return seconds .. ' seconds'
end

-- the online player holding this identifier, if any
local function onlineBy(kind, value)
    for _, s in ipairs(GetPlayers()) do
        local id = GetPlayerIdentifierByType(s, kind)
        if id and (id == value or id == kind .. ':' .. value) then return tonumber(s) end
    end
    return nil
end

-- <id | char:charid | discord id | steam:hex> -> a vorp_admin ban target (server id or identifier table), a label
local function resolve(arg)
    arg = tostring(arg or '')
    local low = arg:lower()

    local sid = low:match('^%d+$') and #low < 15 and tonumber(low)
    if sid then
        if not GetPlayerName(sid) then return nil, Locale.dNobody:format(sid) end
        return sid, ('%s (server id %d)'):format(GetPlayerName(sid), sid)
    end

    local charid = tonumber(low:match('^char:(%d+)$') or low:match('^c(%d+)$'))
    if charid then
        local s = Desk.sourceOfChar(charid)
        if s then return s, ('%s (charid %d, online)'):format(GetPlayerName(s) or '?', charid) end
        local row = MySQL.single.await('SELECT identifier, discordid, firstname, lastname FROM characters WHERE charidentifier = ?', { charid })
        if not row then return nil, Locale.noSuchChar:format(charid) end
        local discord = tostring(row.discordid or ''):gsub('^discord:', '')
        return { steam = row.identifier or '', discord = discord, name = Desk.trim((row.firstname or '') .. ' ' .. (row.lastname or '')) },
            ('%s %s (charid %d, offline)'):format(row.firstname or '', row.lastname or '', charid)
    end

    if low:match('^steam:%x+$') then
        local s = onlineBy('steam', low)
        if s then return s, ('%s (online)'):format(GetPlayerName(s) or low) end
        return { steam = low }, low .. ' (offline)'
    end

    local discord = arg:match('^<@!?(%d+)>$') or (arg:match('^%d+$') and #arg >= 15 and arg)
    if discord then
        local s = onlineBy('discord', discord)
        if s then return s, ('%s (online)'):format(GetPlayerName(s) or discord) end
        -- their steam id from a character, so vorp_admin can add the licence and hardware from their last connect
        local row = MySQL.single.await('SELECT identifier FROM characters WHERE discordid = ? OR discordid = ? LIMIT 1', { discord, 'discord:' .. discord })
        return { steam = row and row.identifier or '', discord = discord }, ('<@%s> (offline)'):format(discord)
    end

    return nil, Locale.dBanWho
end

-------------------------------------------------------------------------------
Bridge.add('ban', { group = 'BANS', ban = true, usage = '<id|char:charid|discord|steam:hex> <30m|12h|7d|perm> <reason>', help = 'Ban a player' },
    function(a, who)
        if not adminUp() then return false, Locale.dBanNoAdmin end
        local seconds = parseLength(a[3])
        local reason = Desk.trim(table.concat(a, ' ', 4))
        if not a[2] or not seconds or reason == '' then return false, usage('ban') end
        local target, label = resolve(a[2])
        if not target then return false, label end
        local banId, err = exports.vorp_admin:BanPlayer(target, clip(reason, 500), who, seconds)
        if not banId then return false, Locale.dBanFailed:format(tostring(err or '?')) end
        return true, Locale.dBanned:format(label, lengthText(seconds), code(banId), reason)
    end)

Bridge.add('unban', { group = 'BANS', ban = true, usage = '<ban id>', help = 'Lift a ban' }, function(a, who)
    if not adminUp() then return false, Locale.dBanNoAdmin end
    if not a[2] then return false, usage('unban') end
    local ok, err = exports.vorp_admin:UnbanPlayer(a[2], who)
    if not ok then return false, tostring(err or '?') end
    return true, Locale.dUnbanned:format(code(a[2]:upper()))
end)

-- one ban as an embed field
local function banField(r)
    local exp = tonumber(r.expires) or 0
    local lines = {
        ('**Character:** %s'):format(r.charname ~= '' and r.charname or 'none loaded'),
        ('**Discord:** %s'):format((r.discord or '') ~= '' and ('<@%s> `%s`'):format(r.discord, r.discord) or 'not captured'),
        ('**Reason:** %s'):format(clip(r.reason ~= '' and r.reason or 'no reason given', 200)),
        ('**By:** %s, <t:%d:d>'):format(clip(r.staff ~= '' and r.staff or 'unknown', 60), tonumber(r.createdTs) or 0),
        ('**Ends:** %s'):format(exp == 0 and 'never (permanent)' or ('<t:%d:R>'):format(exp)),
    }
    if (tonumber(r.ban_count) or 1) > 1 then lines[#lines + 1] = ('**Offence:** #%d'):format(tonumber(r.ban_count)) end
    return {
        name = clip(('%s  ·  %s'):format(r.ban_id, r.playername ~= '' and r.playername or 'unknown player'), 250),
        value = clip(table.concat(lines, '\n'), 1020),
    }
end

local LIVE_SQL <const> = 'active = 1 AND (expires = 0 OR expires > UNIX_TIMESTAMP())'

Bridge.add('banlist', { group = 'BANS', usage = '[page|search]', help = 'Bans in force, newest first', audit = false }, function(a, who)
    if not adminUp() then return false, Locale.dBanNoAdmin end
    local page = math.max(1, math.floor(tonumber(a[2]) or 1))
    local term = (not tonumber(a[2])) and Desk.trim(table.concat(a, ' ', 2)) or ''
    local where, params = LIVE_SQL, {}
    if term ~= '' then
        where = where .. ' AND (ban_id = ? OR discord = ? OR steam = ? OR playername LIKE ? OR charname LIKE ?)'
        local like = '%' .. term:gsub('[%%_]', '') .. '%'
        params = { term:upper(), term, term:lower(), like, like }
    end
    local total = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM admin_bans WHERE ' .. where, params)) or 0
    local pages = math.max(1, math.ceil(total / PER_PAGE))
    page = math.min(page, pages)
    local q = params
    q[#q + 1] = (page - 1) * PER_PAGE
    local rows = MySQL.query.await(('SELECT *, UNIX_TIMESTAMP(created) AS createdTs FROM admin_bans WHERE %s ORDER BY created DESC LIMIT %d OFFSET ?')
        :format(where, PER_PAGE), q) or {}

    local fields = {}
    for _, r in ipairs(rows) do fields[#fields + 1] = banField(r) end
    Bridge.embed({
        title = term ~= '' and ('Bans matching "%s" (%d)'):format(clip(term, 40), total) or ('Bans in force (%d)'):format(total),
        description = total == 0 and 'nobody is banned' or
            ('Page %d of %d. More: %s  ·  Detail: %s'):format(page, pages, code(Bridge.prefix() .. 'banlist ' .. math.min(page + 1, pages)), code(Bridge.prefix() .. 'baninfo <ban id>')),
        color = 15158332,
        fields = fields,
        footer = { text = 'asked by ' .. who },
    })
end)

Bridge.add('baninfo', { group = 'BANS', usage = '<ban id|discord|steam:hex>', help = 'One ban in full, lifted ones too', audit = false }, function(a, who)
    if not adminUp() then return false, Locale.dBanNoAdmin end
    local key = a[2] and (a[2]:match('^<@!?(%d+)>$') or a[2])
    if not key then return false, usage('baninfo') end
    local r = MySQL.single.await([[
        SELECT *, UNIX_TIMESTAMP(created) AS createdTs, UNIX_TIMESTAMP(first_banned) AS firstTs, UNIX_TIMESTAMP(unbanned_at) AS liftedTs
        FROM admin_bans WHERE ban_id = ? OR (discord <> '' AND discord = ?) OR (steam <> '' AND steam = ?)
        ORDER BY active DESC, id DESC LIMIT 1
    ]], { key:upper(), key, key:lower() })
    if not r then return false, Locale.dNoBan:format(code(key)) end

    local active = r.active == true or tonumber(r.active) == 1
    local exp = tonumber(r.expires) or 0
    local live = active and (exp == 0 or exp > os.time())
    local tokens = 0
    local ok, t = pcall(json.decode, r.tokens or '[]')
    if ok and type(t) == 'table' then tokens = #t end

    local state = live and 'IN FORCE' or (active and 'ran out' or 'lifted')
    local lines = {
        ('**Status:** %s'):format(state),
        ('**Player:** %s'):format(r.playername ~= '' and r.playername or 'unknown'),
        ('**Character:** %s%s'):format(r.charname ~= '' and r.charname or 'none loaded', r.charid and (' (charid %s)'):format(r.charid) or ''),
        ('**Discord:** %s'):format((r.discord or '') ~= '' and ('<@%s> `%s`'):format(r.discord, r.discord) or 'not captured'),
        ('**Steam:** %s'):format((r.steam or '') ~= '' and code(r.steam) or 'not captured'),
        ('**Licence:** %s  ·  **Hardware tokens:** %d'):format((r.license or '') ~= '' and 'captured' or 'NOT captured', tokens),
        ('**Reason:** %s'):format(clip(r.reason ~= '' and r.reason or 'no reason given', 400)),
        ('**Banned by:** %s, <t:%d:f>'):format(r.staff ~= '' and r.staff or 'unknown', tonumber(r.createdTs) or 0),
        ('**Ends:** %s'):format(exp == 0 and 'never (permanent)' or ('<t:%d:f> (<t:%d:R>)'):format(exp, exp)),
        ('**Offences:** %d, first <t:%d:d>'):format(tonumber(r.ban_count) or 1, tonumber(r.firstTs) or tonumber(r.createdTs) or 0),
    }
    if not active then
        lines[#lines + 1] = ('**Lifted by:** %s, <t:%d:f>'):format(r.unbanned_by or 'unknown', tonumber(r.liftedTs) or 0)
    end
    Bridge.embed({
        title = 'Ban ' .. r.ban_id,
        description = clip(table.concat(lines, '\n'), 4000),
        color = live and 15158332 or 3066993,
        footer = { text = 'asked by ' .. who },
    })
end)
