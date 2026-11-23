-- pup-mdt | server core: players, database, request channel, text, audit, Discord

Core = exports.vorp_core:GetCore()
MDT = {}

---------------------------------------------------------------------------
-- Database
---------------------------------------------------------------------------
DB = {}
function DB.q(sql, p) return MySQL.query.await(sql, p or {}) or {} end
function DB.one(sql, p) return MySQL.single.await(sql, p or {}) end
function DB.val(sql, p) return MySQL.scalar.await(sql, p or {}) end
function DB.ins(sql, p) return MySQL.insert.await(sql, p or {}) end
function DB.upd(sql, p) return MySQL.update.await(sql, p or {}) or 0 end

---------------------------------------------------------------------------
-- Text and numbers
---------------------------------------------------------------------------

-- cut to max bytes without splitting a UTF-8 character
local function cut(s, max)
    if #s <= max then return s end
    local i = max
    while i > 0 do
        local b = s:byte(i + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        i = i - 1
    end
    return s:sub(1, i)
end

-- trimmed string without control characters (newlines kept when multiline)
function MDT.str(v, max, multiline)
    if v == nil or v == false then return '' end
    if type(v) ~= 'string' and type(v) ~= 'number' then return '' end
    local s = tostring(v)
    if multiline then
        s = s:gsub('\r', ''):gsub('[%z\1-\8\11\12\14-\31\127]', '')
    else
        s = s:gsub('[%z\1-\31\127]', ' ')
    end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if max then s = cut(s, max) end
    return s
end

function MDT.int(v, min, max, default)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return default end
    n = math.floor(n)
    if min and n < min then n = min end
    if max and n > max then n = max end
    return n
end

function MDT.bool(v)
    return v == true or v == 1 or v == '1' or v == 'true'
end

function MDT.enum(v, list, default)
    v = type(v) == 'string' and v:lower() or nil
    for _, x in ipairs(list) do if x == v then return v end end
    return default
end

function MDT.jdec(s, default)
    if type(s) ~= 'string' or s == '' then return default end
    local ok, v = pcall(json.decode, s)
    if ok and v ~= nil then return v end
    return default
end

function MDT.jenc(v)
    local ok, s = pcall(json.encode, v)
    return ok and s or '[]'
end

-- a JSON-safe list of strings or small tables from the client
function MDT.list(v, maxItems, maxLen)
    local out = {}
    if type(v) ~= 'table' then return out end
    for _, x in ipairs(v) do
        if #out >= (maxItems or 50) then break end
        if type(x) == 'string' or type(x) == 'number' then
            local s = MDT.str(x, maxLen or 200)
            if s ~= '' then out[#out + 1] = s end
        elseif type(x) == 'table' then
            local t = {}
            for k, val in pairs(x) do
                if type(k) == 'string' and #k <= 40 and (type(val) == 'string' or type(val) == 'number' or type(val) == 'boolean') then
                    t[k] = type(val) == 'string' and MDT.str(val, maxLen or 200) or val
                end
            end
            out[#out + 1] = t
        end
    end
    return out
end

function MDT.url(v)
    local s = MDT.str(v, 500)
    if s == '' then return '' end
    if not s:match('^https?://') then return '' end
    if s:find('[%s"\'<>`]') then return '' end
    return s
end

-- rich text: only plain formatting tags survive; attributes are dropped except a
-- small safe set (class, data-ref, data-kind) with restricted characters
local allowedTags = {
    b = true, i = true, u = true, s = true, strong = true, em = true, p = true, br = true,
    ul = true, ol = true, li = true, h1 = true, h2 = true, h3 = true, h4 = true,
    blockquote = true, span = true, div = true, hr = true,
}
local allowedAttrs = { class = '^[%w%-_ ]+$', ['data-ref'] = '^[%w%-_#]+$', ['data-kind'] = '^[%w%-_]+$' }

function MDT.html(v, max)
    local s = MDT.str(v, max or 60000, true)
    s = s:gsub('<%s*[sS][cC][rR][iI][pP][tT].-<%s*/%s*[sS][cC][rR][iI][pP][tT]%s*>', '')
    s = s:gsub('<%s*[sS][tT][yY][lL][eE].-<%s*/%s*[sS][tT][yY][lL][eE]%s*>', '')
    local kept = {}
    s = s:gsub('<(/?)%s*([%a][%w]*)([^<>]*)>', function(close, tag, rest)
        tag = tag:lower()
        if not allowedTags[tag] then return '' end
        local attrs = ''
        if close == '' then
            for name, val in rest:gmatch('([%w%-]+)%s*=%s*"([^"]*)"') do
                name = name:lower()
                local pat = allowedAttrs[name]
                if pat and val:match(pat) then attrs = attrs .. ' ' .. name .. '="' .. val .. '"' end
            end
        end
        kept[#kept + 1] = '<' .. close .. tag .. attrs .. '>'
        return '\1' .. #kept .. '\2'
    end)
    s = s:gsub('&', '&amp;'):gsub('&amp;(#?%w+;)', '&%1'):gsub('<', '&lt;'):gsub('>', '&gt;')
    s = s:gsub('\1(%d+)\2', function(n) return kept[tonumber(n)] or '' end)
    return s
end

function MDT.plain(v, max)
    local s = MDT.str(v, max or 20000, true)
    return (s:gsub('<[^>]*>', ''))
end

---------------------------------------------------------------------------
-- Players
---------------------------------------------------------------------------
local function inList(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end
MDT.inList = inList

function MDT.isLawJob(job) return inList(Config.LawJobs, job) end
function MDT.isLawyerJob(job) return Config.Legal.enabled and inList(Config.Legal.jobs, job) end

function MDT.online(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

function MDT.char(src)
    if not MDT.online(src) then return nil end
    local user = Core.getUser(tonumber(src))
    if not user then return nil end
    local ch = user.getUsedCharacter
    if not ch or not ch.charIdentifier then return nil end
    return ch
end

-- the caller as one table, or nil when no character is loaded
function MDT.player(src)
    local ch = MDT.char(src)
    if not ch then return nil end
    local job = ch.job or 'unemployed'
    local first, last = ch.firstname or '', ch.lastname or ''
    return {
        src = tonumber(src),
        cid = tostring(ch.charIdentifier),
        firstname = first,
        lastname = last,
        name = MDT.str(first .. ' ' .. last, 100),
        job = job,
        grade = tonumber(ch.jobGrade) or 0,
        jobLabel = ch.jobLabel or job,
        age = tonumber(ch.age) or 0,
        gender = ch.gender,
        char = ch,
        isLaw = MDT.isLawJob(job),
        isLawyer = MDT.isLawyerJob(job),
    }
end

function MDT.findByCid(cid)
    cid = tostring(cid or '')
    if cid == '' then return nil end
    for _, s in ipairs(GetPlayers()) do
        local ch = MDT.char(s)
        if ch and tostring(ch.charIdentifier) == cid then return tonumber(s) end
    end
    return nil
end

-- citizen id -> server id for every loaded player
function MDT.onlineMap()
    local map = {}
    for _, s in ipairs(GetPlayers()) do
        local ch = MDT.char(s)
        if ch then map[tostring(ch.charIdentifier)] = tonumber(s) end
    end
    return map
end

function MDT.coords(src)
    local ped = GetPlayerPed(tonumber(src) or -1)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c then return nil end
    return vector3(c.x, c.y, c.z)
end

function MDT.dist(a, b)
    if not a or not b then return math.huge end
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function MDT.near(src, point, radius)
    local c = MDT.coords(src)
    if not c or not point then return false end
    return MDT.dist(c, point) <= radius
end

-- character names from the database
function MDT.charName(cid)
    local row = DB.one('SELECT firstname, lastname FROM characters WHERE charidentifier = ?', { tonumber(cid) or -1 })
    if not row then return nil end
    return MDT.str((row.firstname or '') .. ' ' .. (row.lastname or ''), 100), row
end

---------------------------------------------------------------------------
-- Messages to clients
---------------------------------------------------------------------------
function MDT.notify(src, text, ms)
    if not src or not text then return end
    TriggerClientEvent('pup-mdt:client:notify', src, text, ms or Config.Notify.defaultMs)
end

function MDT.nui(src, msg)
    TriggerClientEvent('pup-mdt:client:nui', src, msg)
end

---------------------------------------------------------------------------
-- Department settings (key/value store)
---------------------------------------------------------------------------
Settings = { values = {} }

Settings.defaults = {
    default_fine = 250,
    default_jailtime = 10,
    bounty_fine = Config.Features.bountyDefaultFine,
    bounty_jailtime = Config.Features.bountyDefaultJail,
    feature_reports = Config.Features.reports,
    feature_bolos = Config.Features.statements,
    feature_warrants = Config.Features.bounty,
    feature_fines = Config.Features.fines,
    feature_evidences = Config.Features.evidences,
    feature_tips = Config.Tips.enabled,
    feature_expungements = Config.Features.expungements,
    feature_prisons = Config.Features.prisons,
    feature_prisonregister = Config.Prison.register.enabled,
}
Settings.firmKeys = { firm_motd = 500, firm_name = 40, firm_accept_requests = 1 }

function Settings.load()
    local rows = DB.q('SELECT setting_key, setting_value, updated_by FROM mdt_settings')
    Settings.values, Settings.by = {}, {}
    for _, r in ipairs(rows) do
        Settings.values[r.setting_key] = r.setting_value
        Settings.by[r.setting_key] = r.updated_by
    end
end

function Settings.get(key)
    local v = Settings.values[key]
    local d = Settings.defaults[key]
    if v == nil then return d end
    if type(d) == 'boolean' then return v == '1' or v == 'true' end
    if type(d) == 'number' then return tonumber(v) or d end
    return v
end

function Settings.set(key, value, by)
    local s = value
    if type(value) == 'boolean' then s = value and '1' or '0' end
    s = tostring(s)
    DB.q('INSERT INTO mdt_settings (setting_key, setting_value, updated_by) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_by = VALUES(updated_by)',
        { key, s, by or 'system' })
    Settings.values[key] = s
    Settings.by = Settings.by or {}
    Settings.by[key] = by
end

function Settings.snapshot()
    local out = {}
    for k in pairs(Settings.defaults) do out[k] = Settings.get(k) end
    return out
end

---------------------------------------------------------------------------
-- Discord
---------------------------------------------------------------------------
local colours = { green = 3066993, red = 15158332, orange = 15105570, blue = 3447003, grey = 9807270, gold = 15844367 }

local function hook(key) return (ServerConfig.Webhooks or {})[key] or '' end

local function post(url, embed)
    if not url or url == '' then return end
    if ServerConfig.Discord.footerIcon ~= '' then embed.footer = embed.footer or {}; embed.footer.icon_url = ServerConfig.Discord.footerIcon end
    if ServerConfig.Discord.thumbnail ~= '' then embed.thumbnail = { url = ServerConfig.Discord.thumbnail } end
    PerformHttpRequest(url, function() end, 'POST',
        json.encode({ username = ServerConfig.Discord.username or 'MDT', embeds = { embed } }),
        { ['Content-Type'] = 'application/json' })
end

-- plain log to a named channel
function MDT.log(key, title, message, colour)
    local c = colours[colour] or tonumber(colour) or colours.green
    post(hook(key), {
        title = tostring(title or ''):sub(1, 250),
        description = tostring(message or ''):sub(1, 4000),
        color = c,
        footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
    })
end

function MDT.logAlert(alert)
    local c = alert.coords or {}
    post(hook('alerts'), {
        title = 'Alert: ' .. tostring(alert.text):sub(1, 200),
        color = colours.orange,
        fields = {
            { name = 'Location', value = tostring(alert.location or '-'), inline = false },
            { name = 'X', value = string.format('%.2f', c.x or 0), inline = true },
            { name = 'Y', value = string.format('%.2f', c.y or 0), inline = true },
            { name = 'Z', value = string.format('%.2f', c.z or 0), inline = true },
            { name = 'Sender', value = tostring(alert.sender or 'System'), inline = true },
            { name = 'Rank', value = tostring(alert.senderRank or '-'), inline = true },
        },
        footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
    })
end

exports('LogDiscord', function(key, title, message, colour) MDT.log(key, title, message, colour) end)

-- server-only wrapper (not a net event); a client sender is ignored anyway
AddEventHandler('LogDiscordSRV', function(key, title, message, colour)
    local src = source
    if tonumber(src) and tonumber(src) > 0 then return end
    MDT.log(key, title, message, colour)
end)

---------------------------------------------------------------------------
-- Audit log
---------------------------------------------------------------------------
local policeRoute = {
    report = 'reports', case = 'cases', bolo = 'statements', warrant = 'bounties', criminal = 'criminals',
    arrest = 'arrest', fine = 'fines', evidence = 'evidence', lawman = 'lawmen', prison = 'prison',
    release = 'prison', transfer = 'prison', bulletin = 'bulletins', mostwanted = 'mostwanted', duty = 'duty',
    expungement = 'expungements', permission = 'permissions', penal = 'fines', settings = 'audit', ledger = 'audit',
}
local firmRoute = {
    bail = 'legal_bail', appeal = 'legal_appeals', defense = 'legal_defense', expungement = 'legal_expunge',
    counsel = 'legal_counsel', fired = 'legal_roster', ledger = 'legal_ledger', firm = 'legal_notices', duty = 'legal_duty',
}

local function routeAudit(action, isLawyer)
    if isLawyer or action:sub(1, 7) == 'lawyer_' then
        local rest = action:gsub('^lawyer_', '')
        local first = rest:match('^([^_]+)') or rest
        if first == 'counsel' then return firmRoute.counsel, 'legal' end
        return firmRoute[first] or 'legal', 'legal'
    end
    local first = action:match('^([^_]+)') or action
    return policeRoute[first] or 'audit', 'audit'
end

function MDT.audit(actor, action, targetCid, targetName, details, meta)
    if not Config.Audit.enabled then return end
    if Config.Audit.actions[action] == false then return end
    meta = type(meta) == 'table' and meta or {}
    meta.actor_job = actor and actor.job or 'system'
    local actorCid = actor and actor.cid or nil
    local actorName = actor and actor.name or 'System'
    details = tostring(details or '')
    if Config.Audit.database then
        MySQL.insert([[INSERT INTO mdt_audit_log (action, actor_citizenid, actor_name, target_citizenid, target_name, details, metadata)
            VALUES (?, NULLIF(?, ''), ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?)]],
            { action, actorCid or '', actorName, targetCid and tostring(targetCid) or '', targetName and tostring(targetName) or '', details:sub(1, 2000), MDT.jenc(meta) })
    end
    if Config.Audit.discord then
        local isLawyer = actor and actor.isLawyer or false
        local key, catchAll = routeAudit(action, isLawyer)
        local who = isLawyer and 'Attorney' or (actor and actor.isLaw and 'Lawman' or 'Client')
        local embed = {
            title = 'MDT Audit — ' .. action:upper(),
            color = action:find('delete') and colours.red or colours.blue,
            fields = {
                { name = who, value = string.format('%s (%s)', actorName, actorCid or '-'), inline = true },
                { name = 'Target', value = string.format('%s (%s)', targetName or '-', targetCid or '-'), inline = true },
                { name = 'Action', value = details ~= '' and details:sub(1, 1000) or action, inline = false },
            },
            footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
        }
        local url = hook(key)
        post(url, embed)
        local all = hook(catchAll)
        if all ~= '' and all ~= url then post(all, embed) end
    end
end

---------------------------------------------------------------------------
-- Request channel: one reply per request id
---------------------------------------------------------------------------
local handlers = {}
local rate = {}
MDT.handlers = handlers

-- opts: perm (string or list = any of), duty (must be on duty), law (law jobs only),
-- staff (law or lawyer), deny (reply template on refusal; false = reply false)
function MDT.rpc(name, opts, fn)
    handlers[name] = { opts = opts or {}, fn = fn }
end

local function denyReply(h, msg)
    local d = h.opts.deny
    if d == false then return false end
    local out = {}
    if type(d) == 'table' then for k, v in pairs(d) do out[k] = v end end
    out.success = false
    out.denied = true
    out.message = msg
    return out
end
MDT.denyReply = denyReply

function MDT.allowed(actor, opts)
    if not actor then return false, L('no_character') end
    if opts.law and not actor.isLaw then return false, L('no_permission') end
    if opts.staff and not actor.isLaw and not actor.isLawyer then return false, L('no_permission') end
    if opts.perm then
        local ok = false
        if type(opts.perm) == 'table' then
            for _, p in ipairs(opts.perm) do if MDT.can(actor, p) then ok = true break end end
        else
            ok = MDT.can(actor, opts.perm)
        end
        if not ok then return false, L('no_permission') end
    end
    if opts.duty and not Duty.isOn(actor.src) then return false, L('must_be_on_duty_action') end
    return true
end

RegisterNetEvent('pup-mdt:server:rpc', function(reqId, name, payload)
    local src = source
    reqId = tonumber(reqId)
    if not reqId or type(name) ~= 'string' then return end
    local function reply(r) TriggerClientEvent('pup-mdt:client:rpc', src, reqId, r) end
    local h = handlers[name]
    if not h then return reply({ success = false, message = 'unknown request' }) end

    local now = GetGameTimer()
    local r = rate[src]
    if not r or now - r.t > 1000 then r = { t = now, n = 0 }; rate[src] = r end
    r.n = r.n + 1
    if r.n > 20 then return reply(denyReply(h, L('rate_limited'))) end

    if type(payload) ~= 'table' then payload = {} end
    local actor = MDT.player(src)
    local ok, msg = MDT.allowed(actor, h.opts)
    if not ok then return reply(denyReply(h, msg)) end

    local okc, res = pcall(h.fn, actor, payload)
    if not okc then
        print(('^1[pup-mdt]^7 request %s failed: %s'):format(name, tostring(res)))
        return reply(denyReply(h, L('server_error')))
    end
    if res == nil then res = {} end
    reply(res)
end)

AddEventHandler('playerDropped', function()
    rate[source] = nil
end)

---------------------------------------------------------------------------
-- Paging
---------------------------------------------------------------------------
function MDT.paging(page, perPage, total)
    perPage = perPage or 25
    total = tonumber(total) or 0
    local pages = math.max(1, math.ceil(total / perPage))
    page = MDT.int(page, 1, pages, 1)
    return page, (page - 1) * perPage, pages
end

function MDT.like(s)
    s = MDT.str(s, 100):lower():gsub('[%%_\\]', '\\%0')
    return '%' .. s .. '%'
end

---------------------------------------------------------------------------
-- Small in-memory caches with a lifetime
---------------------------------------------------------------------------
Cache = { store = {} }
function Cache.get(key)
    local c = Cache.store[key]
    if c and c.expires > os.time() then return c.value end
    return nil
end
function Cache.set(key, value, ttl)
    Cache.store[key] = { value = value, expires = os.time() + (ttl or 60) }
end
function Cache.clear(prefix)
    for k in pairs(Cache.store) do
        if k:sub(1, #prefix) == prefix then Cache.store[k] = nil end
    end
end

function MDT.debug(...)
    if Config.Debug then print('[pup-mdt]', ...) end
end

-- the keys of a table, so a loop that waits on the database never walks a table
-- other handlers change meanwhile
function MDT.keys(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = k end
    return out
end
