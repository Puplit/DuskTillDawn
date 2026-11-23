-- pup-mdt | case defense, bar roster, the firm, counsel requests

Firm = { counsel = {}, counselCooldown = {}, nextId = 0 }

local function defenseOn() return Config.Legal.enabled and Config.Legal.tools.defense end
local LAWYER_JOB = Config.Legal.jobs[1]

---------------------------------------------------------------------------
-- Case defense
---------------------------------------------------------------------------
local function assigned(caseId, cid)
    return DB.val('SELECT id FROM mdt_case_defense WHERE case_id = ? AND lawyer_citizenid = ? LIMIT 1', { caseId, cid }) ~= nil
end

MDT.rpc('getDefenseCases', { perm = 'viewdefense', staff = true, deny = { cases = {} } }, function(actor, p)
    if not defenseOn() then return { cases = {}, canAssign = false, canFile = false, isLawyer = actor.isLawyer } end
    local search = MDT.str(p.search, 60)
    local where, params = {}, {}
    if actor.isLawyer then where[#where + 1] = 'd.lawyer_citizenid = ?'; params[#params + 1] = actor.cid end
    if search ~= '' then
        where[#where + 1] = '(LOWER(c.case_number) LIKE ? OR LOWER(c.title) LIKE ? OR LOWER(d.lawyer_name) LIKE ?)'
        local like = MDT.like(search)
        params[#params + 1] = like; params[#params + 1] = like; params[#params + 1] = like
    end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local rows = DB.q([[SELECT d.id, d.case_id, d.lawyer_citizenid, d.lawyer_name, d.assigned_by_name, d.assigned_at,
            c.case_number, c.title, c.status AS case_status,
            (SELECT COUNT(*) FROM mdt_case_statements s WHERE s.case_id = d.case_id) AS statement_count
        FROM mdt_case_defense d JOIN mdt_cases c ON c.id = d.case_id]] .. w .. ' ORDER BY d.assigned_at DESC LIMIT 100', params)
    return { cases = rows, canAssign = MDT.can(actor, 'assigndefense'), canFile = MDT.can(actor, 'filedefense'), isLawyer = actor.isLawyer }
end)

MDT.rpc('lookupDefenseCase', { perm = 'assigndefense', staff = true, deny = { found = false } }, function(_, p)
    local num = MDT.str(p.caseNumber, 30)
    local r = DB.one('SELECT id, case_number, title, status FROM mdt_cases WHERE case_number = ?', { num })
    if not r then return { found = false } end
    return { found = true, caseId = r.id, caseNumber = r.case_number, title = r.title, status = r.status }
end)

MDT.rpc('lookupDefenseLawyer', { perm = 'assigndefense', staff = true, deny = { found = false } }, function(_, p)
    local cid = MDT.str(p.citizenIdentity, 50)
    local row = DB.one('SELECT firstname, lastname, job FROM characters WHERE charidentifier = ?', { tonumber(cid) or -1 })
    if not row or not MDT.isLawyerJob(row.job) then return { found = false, citizenid = cid } end
    return { found = true, citizenid = cid, name = MDT.str((row.firstname or '') .. ' ' .. (row.lastname or ''), 100) }
end)

MDT.rpc('getDefenseCaseDetail', { perm = 'viewdefense', staff = true }, function(actor, p)
    if not defenseOn() then return { success = false, message = L('def_disabled') } end
    local caseId = MDT.int(p.caseId, 1, nil, nil)
    if not caseId then return { success = false, message = L('def_case_not_found') } end
    if actor.isLawyer and not assigned(caseId, actor.cid) then return { success = false, message = L('def_not_assigned') } end
    local c = DB.one([[SELECT id, case_number, title, location, description, status, priority, created_by, investigator_name, created_at
        FROM mdt_cases WHERE id = ?]], { caseId })
    if not c then return { success = false, message = L('def_case_not_found') } end
    local involved = DB.q('SELECT citizenid, name, type, notes FROM mdt_cases_involved WHERE caseid = ?', { caseId })
    local statements = DB.q('SELECT id, author_name, author_role, statement, filed_at FROM mdt_case_statements WHERE case_id = ? ORDER BY filed_at ASC, id ASC', { caseId })
    return { success = true, detail = { caseInfo = c, involved = involved, statements = statements } }
end)

MDT.rpc('assignDefense', { perm = 'assigndefense', law = true, duty = true }, function(actor, p)
    if not defenseOn() then return { success = false, message = L('def_disabled') } end
    local caseId = MDT.int(p.caseId, 1, nil, nil)
    local lcid = MDT.str(p.lawyerCitizenId, 50)
    local c = caseId and DB.one('SELECT id, case_number FROM mdt_cases WHERE id = ?', { caseId })
    if not c then return { success = false, message = L('def_case_not_found') } end
    local row = DB.one('SELECT firstname, lastname, job FROM characters WHERE charidentifier = ?', { tonumber(lcid) or -1 })
    if not row or not MDT.isLawyerJob(row.job) then return { success = false, message = L('def_not_lawyer') } end
    if assigned(caseId, lcid) then return { success = false, message = L('def_already_assigned') } end
    local name = MDT.str((row.firstname or '') .. ' ' .. (row.lastname or ''), 100)
    local id = DB.ins('INSERT INTO mdt_case_defense (case_id, lawyer_citizenid, lawyer_name, assigned_by_citizenid, assigned_by_name) VALUES (?, ?, ?, ?, ?)',
        { caseId, lcid, name, actor.cid, actor.name })
    MDT.audit(actor, 'defense_assigned', lcid, name, 'Case ' .. tostring(c.case_number))
    local src = MDT.findByCid(lcid)
    if src then MDT.notify(src, L('def_you_assigned', c.case_number), 6000); MDT.nui(src, { action = 'updateDefenseCases' }) end
    return { success = true, id = id, action = 'assigned', message = L('def_assigned') }
end)

MDT.rpc('unassignDefense', { perm = 'assigndefense', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local r = id and DB.one('SELECT d.id, d.lawyer_citizenid, d.lawyer_name, c.case_number FROM mdt_case_defense d JOIN mdt_cases c ON c.id = d.case_id WHERE d.id = ?', { id })
    if not r then return { success = false, message = L('def_not_found') } end
    DB.q('DELETE FROM mdt_case_defense WHERE id = ?', { id })
    MDT.audit(actor, 'defense_unassigned', r.lawyer_citizenid, r.lawyer_name, 'Case ' .. tostring(r.case_number))
    return { success = true, action = 'unassigned', message = L('def_unassigned') }
end)

MDT.rpc('fileDefenseStatement', { perm = 'filedefense', staff = true, duty = true }, function(actor, p)
    if not defenseOn() then return { success = false, message = L('def_disabled') } end
    local caseId = MDT.int(p.caseId, 1, nil, nil)
    local text = MDT.str(p.statement, 4000, true)
    if not caseId or not DB.val('SELECT id FROM mdt_cases WHERE id = ?', { caseId }) then return { success = false, message = L('def_case_not_found') } end
    if text == '' then return { success = false, message = L('def_empty') } end
    local role
    if actor.isLawyer then
        if not assigned(caseId, actor.cid) then return { success = false, message = L('def_not_assigned') } end
        role = 'defense'
    else
        role = 'law'
    end
    local id = DB.ins('INSERT INTO mdt_case_statements (case_id, author_citizenid, author_name, author_role, statement) VALUES (?, ?, ?, ?, ?)',
        { caseId, actor.cid, actor.name, role, text })
    MDT.audit(actor, 'defense_statement', nil, nil, ('Case #%d (%s)'):format(caseId, role))
    return { success = true, id = id, action = 'filed', message = L('def_filed') }
end)

---------------------------------------------------------------------------
-- Bar roster and attorney profiles
---------------------------------------------------------------------------
local function lawyerJobsSql()
    local jobs = Config.Legal.jobs
    return string.rep('?,', #jobs):sub(1, -2), jobs
end

MDT.rpc('getBarRoster', { perm = 'viewbarroster', staff = true, deny = { rows = {} } }, function(actor)
    local marks, jobs = lawyerJobsSql()
    local rows = DB.q(([[SELECT c.charidentifier, c.firstname, c.lastname, c.jobgrade,
            (SELECT COUNT(*) FROM mdt_case_defense d WHERE d.lawyer_citizenid = CAST(c.charidentifier AS CHAR)) AS cases,
            ((SELECT COUNT(*) FROM mdt_bail b WHERE b.requested_by_citizenid = CAST(c.charidentifier AS CHAR) AND b.status IN ('pending', 'processing')) +
             (SELECT COUNT(*) FROM mdt_appeals a WHERE a.requested_by_citizenid = CAST(c.charidentifier AS CHAR) AND a.status = 'pending') +
             (SELECT COUNT(*) FROM mdt_expungements e WHERE e.requested_by_citizenid = CAST(c.charidentifier AS CHAR) AND e.status = 'pending')) AS petitions
        FROM characters c WHERE c.job IN (%s) ORDER BY c.jobgrade DESC, c.lastname ASC LIMIT 100]]):format(marks), jobs)
    local online = MDT.onlineMap()
    local out, seen = {}, {}
    for _, r in ipairs(rows) do
        local cid = tostring(r.charidentifier)
        seen[cid] = true
        local src = online[cid]
        local grade = tonumber(r.jobgrade) or 0
        out[#out + 1] = {
            citizenid = cid, name = MDT.str((r.firstname or '') .. ' ' .. (r.lastname or ''), 100), grade = grade,
            rank = Perms.rankName(LAWYER_JOB, grade), online = src ~= nil, onDuty = src ~= nil and Duty.isOn(src),
            isMe = cid == actor.cid, cases = tonumber(r.cases) or 0, petitions = tonumber(r.petitions) or 0,
        }
    end
    -- online attorneys not yet saved to the character table
    for _, s in ipairs(GetPlayers()) do
        local a = MDT.player(s)
        if a and a.isLawyer and not seen[a.cid] then
            out[#out + 1] = { citizenid = a.cid, name = a.name, grade = a.grade, rank = Perms.rankName(a.job, a.grade),
                online = true, onDuty = Duty.isOn(a.src), isMe = a.cid == actor.cid, cases = 0, petitions = 0 }
        end
    end
    return { rows = out, canFire = MDT.can(actor, 'firelawyers'), myGrade = actor.grade, myOnDuty = Duty.isOn(actor.src) }
end)

MDT.rpc('getLawyerProfile', { perm = 'viewbarroster', staff = true, deny = { found = false } }, function(actor, p)
    local cid = MDT.str(p.citizenid, 50)
    if cid == '' then cid = actor.cid end
    if cid ~= actor.cid and not MDT.can(actor, 'viewlawyerprofile') then return { found = false, denied = true } end
    local row = DB.one('SELECT firstname, lastname, job, jobgrade FROM characters WHERE charidentifier = ?', { tonumber(cid) or -1 })
    if not row or not MDT.isLawyerJob(row.job) then return { found = false } end
    local src = MDT.findByCid(cid)
    local grade = tonumber(row.jobgrade) or 0
    local stats = DB.one('SELECT duty_minutes FROM mdt_lawyer_stats WHERE citizenid = ?', { cid })
    local counts = DB.q([[SELECT 'bail' AS src, status, COUNT(*) AS n FROM mdt_bail WHERE requested_by_citizenid = ? GROUP BY status
        UNION ALL SELECT 'appeals', status, COUNT(*) FROM mdt_appeals WHERE requested_by_citizenid = ? GROUP BY status
        UNION ALL SELECT 'expungements', status, COUNT(*) FROM mdt_expungements WHERE requested_by_citizenid = ? GROUP BY status]], { cid, cid, cid })
    return {
        found = true, citizenid = cid, name = MDT.str((row.firstname or '') .. ' ' .. (row.lastname or ''), 100), grade = grade,
        rank = Perms.rankName(row.job, grade), online = src ~= nil, onDuty = src ~= nil and Duty.isOn(src),
        defense = DB.q([[SELECT d.id, d.case_id, d.assigned_at, c.case_number, c.title, c.status FROM mdt_case_defense d
            JOIN mdt_cases c ON c.id = d.case_id WHERE d.lawyer_citizenid = ? ORDER BY d.assigned_at DESC LIMIT 25]], { cid }),
        bail = DB.q('SELECT id, citizen_name, amount, status, requested_at FROM mdt_bail WHERE requested_by_citizenid = ? ORDER BY requested_at DESC LIMIT 25', { cid }),
        appeals = DB.q('SELECT id, citizen_name, reduction_minutes, commute, status, requested_at FROM mdt_appeals WHERE requested_by_citizenid = ? ORDER BY requested_at DESC LIMIT 25', { cid }),
        expungements = DB.q('SELECT id, citizen_name, status, requested_at FROM mdt_expungements WHERE requested_by_citizenid = ? ORDER BY requested_at DESC LIMIT 25', { cid }),
        dutyMinutes = stats and tonumber(stats.duty_minutes) or 0,
        counts = counts,
    }
end)

MDT.rpc('getFirmHome', { perm = 'firmhome', staff = true, deny = false }, function()
    local marks, jobs = lawyerJobsSql()
    local total = tonumber(DB.val(('SELECT COUNT(*) FROM characters WHERE job IN (%s)'):format(marks), jobs)) or 0
    local onDuty = {}
    for _, src in ipairs(Duty.lawyers()) do
        local a = MDT.player(src)
        if a then onDuty[#onDuty + 1] = { name = a.name, rank = Perms.rankName(a.job, a.grade) } end
    end
    local pending = (tonumber(DB.val("SELECT COUNT(*) FROM mdt_bail WHERE status IN ('pending', 'processing')")) or 0)
        + (tonumber(DB.val("SELECT COUNT(*) FROM mdt_appeals WHERE status = 'pending'")) or 0)
        + (tonumber(DB.val("SELECT COUNT(*) FROM mdt_expungements WHERE status = 'pending'")) or 0)
    local recent = DB.q([[SELECT * FROM (
            SELECT 'bail' AS kind, requested_by_name, citizen_name, status, requested_at FROM mdt_bail
            UNION ALL SELECT 'appeal', requested_by_name, citizen_name, status, requested_at FROM mdt_appeals
            UNION ALL SELECT 'expungement', requested_by_name, citizen_name, status, requested_at FROM mdt_expungements
        ) x ORDER BY requested_at DESC LIMIT 8]])
    local requests = {}
    local window = Config.Legal.counsel.homeWindowMinutes * 60
    for _, r in ipairs(Firm.counsel) do
        local age = os.time() - r.at
        if age <= window then requests[#requests + 1] = { id = r.id, ago = age, respondedBy = r.respondedBy } end
    end
    return {
        totalAttorneys = total, onDuty = onDuty,
        openCases = tonumber(DB.val('SELECT COUNT(*) FROM mdt_case_defense')) or 0,
        pendingPetitions = pending, recent = recent, requests = requests,
    }
end)

-- the Firm Office banner reads it with viewbarroster; the settings form with firmsettings
MDT.rpc('getFirmSettings', { perm = { 'viewbarroster', 'firmsettings' }, staff = true }, function(actor)
    return {
        motd = Settings.values.firm_motd or '',
        postedBy = Settings.by and Settings.by.firm_motd or nil,
        firmName = Settings.values.firm_name or '',
        acceptRequests = Settings.values.firm_accept_requests ~= '0',
        canEdit = MDT.can(actor, 'firmsettings'),
    }
end)

MDT.rpc('saveFirmMotd', { perm = 'firmsettings', staff = true, duty = true }, function(actor, p)
    Settings.set('firm_motd', MDT.str(p.motd, 500, true), actor.name)
    Settings.set('firm_name', MDT.str(p.name, 40), actor.name)
    Settings.set('firm_accept_requests', MDT.bool(p.acceptRequests) and '1' or '0', actor.name)
    MDT.audit(actor, 'lawyer_firm_motd', nil, nil, 'Firm notice updated')
    return { success = true, action = 'motd', message = L('bar_settings_saved') }
end)

MDT.rpc('fireLawyer', { perm = 'firelawyers', staff = true, duty = true }, function(actor, p)
    local cid = MDT.str(p.citizenid, 50)
    if cid == '' or cid == actor.cid then return { success = false, message = L('bar_cannot_fire_self') } end
    local row = DB.one('SELECT firstname, lastname, job, jobgrade FROM characters WHERE charidentifier = ?', { tonumber(cid) or -1 })
    local src = MDT.findByCid(cid)
    local live = src and MDT.player(src)
    local job = live and live.job or (row and row.job)
    local grade = live and live.grade or (row and tonumber(row.jobgrade)) or 0
    if not job or not MDT.isLawyerJob(job) then return { success = false, message = L('bar_not_attorney') } end
    if grade >= actor.grade then return { success = false, message = L('bar_only_lower') } end
    local name = live and live.name or MDT.str(((row and row.firstname) or '') .. ' ' .. ((row and row.lastname) or ''), 100)
    if live then
        live.char.setJob(Config.Legal.firedJob, true)
        live.char.setJobGrade(Config.Legal.firedGrade, true)
        if live.char.setJobLabel then live.char.setJobLabel(Config.Legal.firedJob) end
        Duty.clockOff(src, 'fired', true)
        MDT.notify(src, L('bar_you_fired', actor.name), 8000)
    else
        DB.upd('UPDATE characters SET job = ?, jobgrade = ? WHERE charidentifier = ?', { Config.Legal.firedJob, Config.Legal.firedGrade, tonumber(cid) })
    end
    MDT.audit(actor, 'lawyer_fired', cid, name, 'Dismissed from the firm')
    return { success = true, name = name, message = L('bar_fired', name) }
end)

---------------------------------------------------------------------------
-- Counsel requests (/lawyer)
---------------------------------------------------------------------------
local CS = Config.Legal.counsel

local function findCounsel(id)
    for i, r in ipairs(Firm.counsel) do if r.id == id then return r, i end end
end

local function removeCounsel(id)
    local _, i = findCounsel(id)
    if i then table.remove(Firm.counsel, i) end
    for _, src in ipairs(Duty.lawyers()) do TriggerClientEvent('pup-mdt:client:counselCancel', src, id) end
end

if CS.enabled then
    RegisterCommand(CS.command, function(src)
        if src <= 0 then return end
        local a = MDT.player(src)
        if not a then return end
        local last = Firm.counselCooldown[a.cid]
        if last and os.time() - last < CS.cooldownSeconds then
            return MDT.notify(src, L('counsel_cooldown', CS.cooldownSeconds - (os.time() - last)), 5000)
        end
        if Settings.values.firm_accept_requests == '0' then return MDT.notify(src, L('counsel_not_accepting'), 5000) end
        local c = MDT.coords(src)
        if not c then return end
        Firm.counselCooldown[a.cid] = os.time()
        Firm.nextId = Firm.nextId + 1
        local req = { id = Firm.nextId, src = src, cid = a.cid, name = a.name, coords = { x = c.x, y = c.y, z = c.z }, at = os.time() }
        table.insert(Firm.counsel, 1, req)
        while #Firm.counsel > CS.keep do table.remove(Firm.counsel) end
        local lawyers = Duty.lawyers()
        for _, l in ipairs(lawyers) do
            TriggerClientEvent('pup-mdt:client:counselAlert', l, { id = req.id, coords = req.coords, expires = CS.blipSeconds })
            MDT.notify(l, L('counsel_new', PupMdtZones.nameFromCoords(c)), 7000)
        end
        MDT.audit(a, 'lawyer_counsel_request', a.cid, a.name, PupMdtZones.nameFromCoords(c))
        if #lawyers > 0 then MDT.notify(src, L('counsel_sent', #lawyers), 6000) else MDT.notify(src, L('counsel_none'), 6000) end
    end, false)

    RegisterCommand(CS.cancelCommand, function(src)
        if src <= 0 then return end
        local a = MDT.player(src)
        if not a then return end
        for _, r in ipairs(Firm.counsel) do
            if r.cid == a.cid then
                removeCounsel(r.id)
                for _, l in ipairs(Duty.lawyers()) do MDT.notify(l, L('counsel_cancelled_by_client'), 5000) end
                return MDT.notify(src, L('counsel_cancelled'), 5000)
            end
        end
        MDT.notify(src, L('counsel_none_open'), 4000)
    end, false)
end

MDT.rpc('respondCounsel', { perm = 'firmhome', staff = true, duty = true }, function(actor, p)
    local r = findCounsel(MDT.int(p.id, 1, nil, 0))
    if not r then return { success = false, message = L('counsel_gone') } end
    if r.respondedBy then return { success = false, message = L('counsel_taken', r.respondedBy) } end
    r.respondedBy = actor.name
    -- the caller may have left: a reused server id must not get the notice
    local caller = MDT.findByCid(r.cid)
    if caller then MDT.notify(caller, L('counsel_on_way'), 7000) end
    for _, l in ipairs(Duty.lawyers()) do
        if l ~= actor.src then MDT.notify(l, L('counsel_taken', actor.name), 5000) end
    end
    TriggerClientEvent('pup-mdt:client:counselRoute', actor.src, r.id, r.coords)
    MDT.audit(actor, 'lawyer_counsel_response', r.cid, r.name, 'Responded to counsel request')
    return { success = true, action = 'counselResponded' }
end)

MDT.rpc('cancelCounsel', { perm = 'firmhome', staff = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, 0)
    local r = findCounsel(id)
    if not r then return { success = false, message = L('counsel_gone') } end
    removeCounsel(id)
    MDT.audit(actor, 'lawyer_counsel_cancel', r.cid, r.name, 'Dismissed counsel request')
    return { success = true }
end)
