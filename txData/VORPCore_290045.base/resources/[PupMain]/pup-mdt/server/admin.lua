-- pup-mdt | dashboard, department settings, bulletins, audit log viewer

Admin = {}

---------------------------------------------------------------------------
-- Dashboard
---------------------------------------------------------------------------
local function dashboardBase()
    local c = Cache.get('dashboard')
    if c then return c end
    local base = {
        totalIncidents = tonumber(DB.val('SELECT COUNT(*) FROM mdt_reports WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)')) or 0,
        registeredCriminals = tonumber(DB.val('SELECT COUNT(*) FROM mdt_criminals')) or 0,
        activeBounties = tonumber(DB.val("SELECT COUNT(*) FROM mdt_reports_warrants WHERE status = 'active'")) or 0,
        prisonsToday = tonumber(DB.val('SELECT COUNT(*) FROM mdt_prison_records WHERE imprisoned_at >= CURDATE()')) or 0,
        warrants = DB.q("SELECT id, citizen_name AS subject_name, expiry_date AS expires_at FROM mdt_reports_warrants WHERE status = 'active' ORDER BY created_at DESC LIMIT 10"),
        recentReports = DB.q('SELECT id, title, type, author_name, created_at AS date FROM mdt_reports ORDER BY created_at DESC LIMIT 8'),
        bolos = DB.q("SELECT id, type, subject_name AS subject, description, issued_by_name AS issued_by, created_at FROM mdt_bolos WHERE status = 'active' ORDER BY created_at DESC LIMIT 5"),
        bulletins = DB.q('SELECT id, title, content, type, posted_by_name, created_at FROM mdt_bulletins WHERE is_active = 1 ORDER BY created_at DESC LIMIT 10'),
    }
    Cache.set('dashboard', base, 60)
    return base
end

MDT.rpc('getDashboardData', { perm = 'dashboard', law = true, deny = false }, function(actor)
    local base = dashboardBase()
    local out = {}
    for k, v in pairs(base) do out[k] = v end
    out.activeLawmen = #Duty.lawmen()
    out.alerts = { active = false, message = L('dash_no_alerts') }
    out.policeAlerts = Alerts.forViewer(actor.src)
    return out
end)

---------------------------------------------------------------------------
-- Department settings
---------------------------------------------------------------------------
MDT.rpc('getMdtSettings', { perm = 'createlawmen', law = true, deny = {} }, function()
    return Settings.snapshot()
end)

MDT.rpc('saveMdtSettings', { perm = 'createlawmen', law = true, duty = true }, function(actor, p)
    local changed = {}
    for key, default in pairs(Settings.defaults) do
        local v = p[key]
        if v ~= nil then
            if type(default) == 'boolean' then
                Settings.set(key, MDT.bool(v), actor.name)
            elseif type(default) == 'number' then
                Settings.set(key, MDT.int(v, 0, 100000000, default), actor.name)
            end
            changed[#changed + 1] = key
        end
    end
    if #changed == 0 then return { success = false, message = L('set_nothing_changed') } end
    MDT.audit(actor, 'settings_updated', nil, nil, table.concat(changed, ', '))
    return { success = true, settings = Settings.snapshot() }
end)

---------------------------------------------------------------------------
-- Bulletins
---------------------------------------------------------------------------
local function cleanTitle(s) return MDT.str((tostring(s or '')):match('^[^\r\n]*') or '', 200) end

local function cleanContent(s)
    s = MDT.str(s, 4000, true)
    s = s:gsub('[ \t]*\n[ \t]*', '\n'):gsub('\n\n\n+', '\n\n')
    return s
end

MDT.rpc('getBulletins', { perm = 'lawmen', law = true, deny = {} }, function()
    return DB.q('SELECT id, title, content, type, posted_by_name, created_at FROM mdt_bulletins WHERE is_active = 1 ORDER BY created_at DESC LIMIT 50')
end)

MDT.rpc('createBulletin', { perm = 'createlawmen', law = true, duty = true }, function(actor, p)
    local title, content = cleanTitle(p.title), cleanContent(p.content)
    if title == '' or content == '' then return { success = false, message = L('set_bulletin_required') } end
    local kind = MDT.enum(p.type, { 'general', 'urgent', 'motd' }, 'general')
    DB.upd('UPDATE mdt_bulletins SET is_active = 0 WHERE is_active = 1')
    DB.ins('INSERT INTO mdt_bulletins (title, content, type, posted_by_citizenid, posted_by_name, is_active) VALUES (?, ?, ?, ?, ?, 1)',
        { title, content, kind, actor.cid, actor.name })
    MDT.audit(actor, 'bulletin_created', nil, nil, title)
    MDT.log('bulletins', 'Bulletin: ' .. title, content, kind == 'urgent' and 'red' or 'blue')
    Cache.clear('dashboard')
    return { success = true }
end)

MDT.rpc('deleteBulletin', { perm = 'createlawmen', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local n = id and DB.upd('UPDATE mdt_bulletins SET is_active = 0 WHERE id = ? AND is_active = 1', { id }) or 0
    if n == 0 then return { success = false, message = L('set_bulletin_not_found') } end
    MDT.audit(actor, 'bulletin_deleted', nil, nil, '#' .. id)
    Cache.clear('dashboard')
    return { success = true }
end)

function Admin.cleanBulletins()
    for _, b in ipairs(DB.q('SELECT id, title, content FROM mdt_bulletins')) do
        local t, c = cleanTitle(b.title), cleanContent(b.content)
        if t ~= b.title or c ~= b.content then
            DB.upd('UPDATE mdt_bulletins SET title = ?, content = ? WHERE id = ?', { t, c, b.id })
        end
    end
end

---------------------------------------------------------------------------
-- Audit log viewer and retention
---------------------------------------------------------------------------
local LEGAL_PREFIXES = { 'bail_', 'appeal_', 'defense_', 'expungement_', 'lawyer_', 'duty_', 'ledger_' }

MDT.rpc('getAuditLog', { perm = 'viewauditlog', staff = true, deny = {} }, function(actor, p)
    local page = MDT.int(p.page, 1, 100000, 1)
    local action = MDT.str(p.action, 80)
    local name = MDT.str(p.actor, 100)
    local where, params = {}, {}
    local jobExpr = "JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.actor_job'))"
    local lawyerJobs = Config.Legal.jobs
    local marks = string.rep('?,', #lawyerJobs):sub(1, -2)
    if actor.isLawyer then
        where[#where + 1] = 'actor_citizenid = ?'; params[#params + 1] = actor.cid
        where[#where + 1] = ('%s IN (%s)'):format(jobExpr, marks)
        for _, j in ipairs(lawyerJobs) do params[#params + 1] = j end
        local ors = {}
        for _, pre in ipairs(LEGAL_PREFIXES) do ors[#ors + 1] = 'action LIKE ?'; params[#params + 1] = pre .. '%' end
        where[#where + 1] = '(' .. table.concat(ors, ' OR ') .. ')'
    else
        where[#where + 1] = "action NOT LIKE 'lawyer\\_%'"
        where[#where + 1] = ('(%s IS NULL OR %s NOT IN (%s))'):format(jobExpr, jobExpr, marks)
        for _, j in ipairs(lawyerJobs) do params[#params + 1] = j end
    end
    if action ~= '' then where[#where + 1] = 'action = ?'; params[#params + 1] = action end
    if name ~= '' then where[#where + 1] = 'LOWER(actor_name) LIKE ?'; params[#params + 1] = MDT.like(name) end
    params[#params + 1] = 50; params[#params + 1] = (page - 1) * 50
    return DB.q('SELECT id, action, actor_name, actor_citizenid, target_citizenid, target_name, details, metadata, created_at FROM mdt_audit_log WHERE '
        .. table.concat(where, ' AND ') .. ' ORDER BY id DESC LIMIT ? OFFSET ?', params)
end)

function Admin.auditRetention()
    local days = tonumber(Config.Audit.retentionDays) or 0
    if days <= 0 then return end
    local n = DB.upd('DELETE FROM mdt_audit_log WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)', { math.floor(days) })
    if n > 0 then MDT.debug('audit retention removed', n) end
end
