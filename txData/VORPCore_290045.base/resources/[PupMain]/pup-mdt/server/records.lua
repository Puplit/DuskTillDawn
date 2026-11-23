-- pup-mdt | citizens, criminal records, wanted status, citizen profile

Records = { hasCreated = false }

local PER_PAGE = 20

---------------------------------------------------------------------------
-- Wanted status
---------------------------------------------------------------------------
local function hasActiveBounty(cid)
    return (tonumber(DB.val("SELECT COUNT(*) FROM mdt_reports_warrants WHERE citizenid = ? AND status = 'active'", { tostring(cid) })) or 0) > 0
end
Records.hasActiveBounty = hasActiveBounty

-- wanted when a bounty is active or a lawman marked it by hand; returns true on change
function Records.syncWanted(cid)
    cid = tostring(cid or '')
    if cid == '' or not Config.Features.bountyAutoWanted then return false end
    local row = DB.one('SELECT id, status, wanted_by_hand FROM mdt_criminals WHERE identity = ?', { cid })
    if not row then return false end
    local want = hasActiveBounty(cid) or (row.wanted_by_hand == true or tonumber(row.wanted_by_hand) == 1)
    local new = row.status
    if want then new = 'wanted' elseif row.status == 'wanted' then new = 'clear' end
    if new ~= row.status then
        DB.upd('UPDATE mdt_criminals SET status = ? WHERE id = ?', { new, row.id })
        Records.broadcast()
        return true
    end
    return false
end

-- after an arrest or a release: clear unless a bounty is still active
function Records.clearWanted(cid)
    cid = tostring(cid or '')
    if cid == '' then return end
    local active = hasActiveBounty(cid)
    local n = DB.upd("UPDATE mdt_criminals SET wanted_by_hand = 0, status = IF(?, 'wanted', IF(status = 'wanted', 'clear', status)) WHERE identity = ?",
        { active and 1 or 0, cid })
    if n > 0 then Records.broadcast() end
end

function Records.sweepWanted()
    if not Config.Features.bountyAutoWanted then return end
    local a = DB.upd([[UPDATE mdt_criminals m SET m.status = 'clear'
        WHERE m.status = 'wanted' AND m.wanted_by_hand = 0
        AND NOT EXISTS (SELECT 1 FROM mdt_reports_warrants w WHERE w.citizenid = m.identity AND w.status = 'active')]])
    local b = DB.upd([[UPDATE mdt_criminals m SET m.status = 'wanted'
        WHERE m.status <> 'wanted'
        AND EXISTS (SELECT 1 FROM mdt_reports_warrants w WHERE w.citizenid = m.identity AND w.status = 'active')]])
    if a + b > 0 then Records.broadcast() end
end

function Records.syncNames()
    local n = DB.upd([[UPDATE mdt_criminals m JOIN characters c ON c.charidentifier = m.identity
        SET m.firstname = c.firstname, m.lastname = c.lastname
        WHERE (m.firstname <> c.firstname OR m.lastname <> c.lastname)]])
    if n > 0 then Records.broadcast() end
end

---------------------------------------------------------------------------
-- Citizen list
---------------------------------------------------------------------------
local function listQuery(search, filter, limit, offset)
    local where, params = {}, {}
    if search ~= '' then
        local like = MDT.like(search)
        where[#where + 1] = "(LOWER(c.firstname) LIKE ? OR LOWER(c.lastname) LIKE ? OR LOWER(CONCAT(c.firstname, ' ', c.lastname)) LIKE ? OR CAST(c.charidentifier AS CHAR) = ?)"
        params[#params + 1] = like; params[#params + 1] = like; params[#params + 1] = like; params[#params + 1] = search
    end
    if filter == 'flagged' then where[#where + 1] = 'm.id IS NOT NULL' end
    if filter == 'wanted' then where[#where + 1] = "m.status = 'wanted'" end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local created = Records.hasCreated and 'c.character_created' or 'NULL'
    local count = tonumber(DB.val('SELECT COUNT(*) FROM characters c LEFT JOIN mdt_criminals m ON m.identity = CAST(c.charidentifier AS CHAR)' .. w, params)) or 0
    local sql = ([[SELECT c.charidentifier, c.firstname, c.lastname, c.age, %s AS character_created,
            m.id AS mid, m.player_id, m.photo_url, m.description, m.status, m.registered_by, m.registered_at,
            (SELECT COUNT(*) FROM mdt_arrests a WHERE a.citizen_identity = CAST(c.charidentifier AS CHAR) AND a.final_fine > 0) AS fine_count,
            (SELECT COALESCE(SUM(a.final_fine), 0) FROM mdt_arrests a WHERE a.citizen_identity = CAST(c.charidentifier AS CHAR) AND a.fine_applied = 1) AS fine_total,
            (SELECT COUNT(*) FROM mdt_arrests a WHERE a.citizen_identity = CAST(c.charidentifier AS CHAR)) AS arrest_count,
            EXISTS (SELECT 1 FROM mdt_reports_warrants w WHERE w.citizenid = CAST(c.charidentifier AS CHAR) AND w.status = 'active') AS has_bounty,
            EXISTS (SELECT 1 FROM mdt_cases_involved ci JOIN mdt_cases cs ON cs.id = ci.caseid
                    WHERE ci.citizenid = CAST(c.charidentifier AS CHAR) AND cs.status IN ('open', 'active')) AS has_case
        FROM characters c LEFT JOIN mdt_criminals m ON m.identity = CAST(c.charidentifier AS CHAR)%s
        ORDER BY c.lastname ASC, c.firstname ASC LIMIT ? OFFSET ?]]):format(created, w)
    local p2 = {}
    for _, v in ipairs(params) do p2[#p2 + 1] = v end
    p2[#p2 + 1] = limit; p2[#p2 + 1] = offset
    return DB.q(sql, p2), count
end

local function criminalRow(r, online, hideNotes)
    local cid = tostring(r.charidentifier)
    local src = online[cid]
    local status = r.status or 'clear'
    if Config.Features.bountyAutoWanted and tonumber(r.has_bounty) == 1 then status = 'wanted' end
    return {
        id = r.mid,
        playerId = src or r.player_id,
        identity = cid,
        photoUrl = r.photo_url or '',
        firstname = r.firstname or '',
        lastname = r.lastname or '',
        age = tonumber(r.age) or 0,
        characterCreated = r.character_created,
        description = hideNotes and '' or (r.description or ''),
        status = status,
        registeredBy = r.registered_by,
        registeredAt = r.registered_at,
        totalFines = tonumber(r.fine_count) or 0,
        totalFineAmount = tonumber(r.fine_total) or 0,
        hasRecord = r.mid ~= nil or (tonumber(r.arrest_count) or 0) > 0,
        hasActiveBounty = tonumber(r.has_bounty) == 1,
        hasOpenCase = tonumber(r.has_case) == 1,
        isOnline = src ~= nil,
    }
end

local function buildList(page, search, filter, hideNotes)
    local total = 0
    local rows
    page = MDT.int(page, 1, nil, 1)
    rows, total = listQuery(search, filter, PER_PAGE, (page - 1) * PER_PAGE)
    local pages = math.max(1, math.ceil(total / PER_PAGE))
    local online = MDT.onlineMap()
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = criminalRow(r, online, hideNotes) end
    return { criminals = out, currentPage = page, totalPages = pages, totalRecords = total, recordsPerPage = PER_PAGE }
end

local pendingBroadcast = false
-- a fresh page 1 to every on-duty lawman (debounced)
function Records.broadcast()
    Cache.clear('criminals')
    if pendingBroadcast then return end
    pendingBroadcast = true
    SetTimeout(1000, function()
        pendingBroadcast = false
        local list = buildList(1, '', 'all', false)
        Cache.set('criminals:p1', list, 60)
        local msg = { action = 'updateCriminals' }
        for k, v in pairs(list) do msg[k] = v end
        Duty.nuiLawmen(msg)
    end)
end

MDT.rpc('getCriminals', { perm = 'criminals', staff = true,
    deny = { criminals = {}, currentPage = 1, totalPages = 1, totalRecords = 0, recordsPerPage = PER_PAGE } }, function(actor, p)
    local search = MDT.str(p.search, 100)
    local filter = MDT.enum(p.status, { 'all', 'flagged', 'wanted' }, 'all')
    local page = MDT.int(p.page, 1, nil, 1)
    local hide = actor.isLawyer
    if page == 1 and search == '' and filter == 'all' and not hide then
        local c = Cache.get('criminals:p1')
        if c then return c end
        local list = buildList(1, '', 'all', false)
        Cache.set('criminals:p1', list, 60)
        return list
    end
    return buildList(page, search, filter, hide)
end)

---------------------------------------------------------------------------
-- Record actions
---------------------------------------------------------------------------
local function noLawyer(actor, resultKey)
    if actor.isLawyer then
        local r = { success = false, message = L('no_permission') }
        if resultKey then return { result = r } end
        return r
    end
end

MDT.rpc('getCriminalDetails', { perm = 'criminals', staff = true, deny = { data = false } }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not id then return { data = false } end
    local m = DB.one('SELECT * FROM mdt_criminals WHERE id = ?', { id })
    if not m then return { data = false } end
    local incidents = DB.q('SELECT id, title, description, created_by, created_at FROM mdt_evidence WHERE criminal_id = ? ORDER BY created_at DESC LIMIT 200', { id })
    local bounty = DB.val("SELECT id FROM mdt_reports_warrants WHERE citizenid = ? AND status = 'active' ORDER BY id ASC LIMIT 1", { m.identity })
    local age = DB.val('SELECT age FROM characters WHERE charidentifier = ?', { tonumber(m.identity) or -1 })
    local data = {
        id = m.id, player_id = m.player_id, identity = m.identity, photo_url = m.photo_url or '',
        firstname = m.firstname, lastname = m.lastname, age = tonumber(age) or m.age,
        description = actor.isLawyer and '' or (m.description or ''),
        status = (bounty and Config.Features.bountyAutoWanted) and 'wanted' or m.status,
        registered_by = m.registered_by, registered_at = m.registered_at, updated_at = m.updated_at,
        total_incidents = #incidents, active_bounty_id = bounty, incidents = incidents,
    }
    return { data = data }
end)

MDT.rpc('saveCriminal', { perm = 'criminals', staff = true, duty = true }, function(actor, p)
    local deny = noLawyer(actor, true)
    if deny then return deny end
    local target = MDT.int(p.playerId, 1, nil, nil)
    local ta = target and MDT.player(target)
    if not ta then return { result = { success = false, message = L('crim_player_offline') } } end
    local cid = MDT.str(p.identity, 50)
    if cid ~= '' and cid ~= ta.cid then return { result = { success = false, message = L('crim_identity_mismatch') } } end
    cid = ta.cid
    if DB.val('SELECT id FROM mdt_criminals WHERE identity = ?', { cid }) then
        return { result = { success = false, message = L('crim_already_registered') } }
    end
    local status = (Config.Features.bountyAutoWanted and hasActiveBounty(cid)) and 'wanted' or 'clear'
    local id = DB.ins([[INSERT INTO mdt_criminals (player_id, identity, photo_url, firstname, lastname, age, description, status, registered_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        target, cid, MDT.url(p.photoUrl), MDT.str(p.firstname, 50) ~= '' and MDT.str(p.firstname, 50) or ta.firstname,
        MDT.str(p.lastname, 50) ~= '' and MDT.str(p.lastname, 50) or ta.lastname,
        MDT.int(p.age, 0, 200, ta.age), MDT.str(p.description, 4000, true), status, actor.name })
    Lawmen.bumpStat(actor.cid, 'criminals_registered', 1)
    MDT.log('criminals', 'Criminal registered', ('%s registered %s (%s)'):format(actor.name, ta.name, cid), 'blue')
    MDT.audit(actor, 'criminal_added', cid, ta.name, 'Record registered')
    Records.broadcast()
    return { result = { success = true, message = L('crim_registered'), criminalId = id } }
end)

MDT.rpc('updateCriminal', { perm = 'criminals', staff = true, duty = true }, function(actor, p)
    local deny = noLawyer(actor, true)
    if deny then return deny end
    local id = MDT.int(p.criminalId, 1, nil, nil)
    local m = id and DB.one('SELECT id, identity FROM mdt_criminals WHERE id = ?', { id })
    if not m then return { result = { success = false, message = L('crim_not_found') } } end
    DB.upd([[UPDATE mdt_criminals SET player_id = ?, photo_url = ?, firstname = ?, lastname = ?, age = ?, description = ? WHERE id = ?]], {
        MDT.int(p.playerId, 0, nil, 0), MDT.url(p.photoUrl), MDT.str(p.firstname, 50), MDT.str(p.lastname, 50),
        MDT.int(p.age, 0, 200, 0), MDT.str(p.description, 4000, true), id })
    Records.syncWanted(m.identity)
    MDT.audit(actor, 'criminal_updated', m.identity, MDT.str(p.firstname, 50) .. ' ' .. MDT.str(p.lastname, 50), 'Record updated')
    Records.broadcast()
    return { result = { success = true, message = L('crim_updated'), criminalId = id } }
end)

MDT.rpc('deleteCriminal', { perm = 'deleterecords', staff = true, duty = true }, function(actor, p)
    local deny = noLawyer(actor, true)
    if deny then return deny end
    local id = MDT.int(p.criminalId or p.id, 1, nil, nil)
    local m = id and DB.one('SELECT id, identity, firstname, lastname FROM mdt_criminals WHERE id = ?', { id })
    if not m then return { result = { success = false, message = L('crim_not_found') } } end
    local n = DB.upd('DELETE FROM mdt_criminals WHERE id = ?', { id })
    if n == 0 then return { result = { success = false, message = L('crim_delete_failed') } } end
    MDT.audit(actor, 'criminal_deleted', m.identity, (m.firstname or '') .. ' ' .. (m.lastname or ''), 'Record deleted')
    Records.broadcast()
    return { result = { success = true, message = L('crim_deleted'), criminalId = id } }
end)

MDT.rpc('updateCriminalInfo', { perm = 'criminals', staff = true, duty = true }, function(actor, p)
    local deny = noLawyer(actor, true)
    if deny then return deny end
    local status = MDT.enum(p.status, { 'wanted', 'clear', 'released' }, nil)
    local desc = MDT.str(p.description, 4000, true)
    local id = MDT.int(p.criminalId, 1, nil, nil)
    local row
    if id then
        row = DB.one('SELECT id, identity, status FROM mdt_criminals WHERE id = ?', { id })
        if not row then return { result = { success = false, message = L('crim_not_found') } } end
    else
        local cid = MDT.str(p.identity, 50)
        if cid == '' then return { result = { success = false, message = L('crim_not_found') } } end
        local name, ch = MDT.charName(cid)
        if not name then return { result = { success = false, message = L('crim_not_found') } } end
        row = DB.one('SELECT id, identity, status FROM mdt_criminals WHERE identity = ?', { cid })
        if not row then
            local newId = DB.ins('INSERT INTO mdt_criminals (player_id, identity, firstname, lastname, age, description, status, registered_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                { MDT.findByCid(cid) or 0, cid, ch.firstname or '', ch.lastname or '', tonumber(DB.val('SELECT age FROM characters WHERE charidentifier = ?', { tonumber(cid) })) or 0, desc, 'clear', actor.name })
            row = { id = newId, identity = cid, status = 'clear' }
        end
    end
    status = status or row.status
    DB.upd('UPDATE mdt_criminals SET status = ?, description = ?, wanted_by_hand = ? WHERE id = ?',
        { status, desc, status == 'wanted' and 1 or 0, row.id })
    Records.syncWanted(row.identity)
    local final = DB.one('SELECT id, status, description FROM mdt_criminals WHERE id = ?', { row.id })
    MDT.audit(actor, 'criminal_info_updated', row.identity, MDT.charName(row.identity), 'Status: ' .. tostring(final and final.status))
    Records.broadcast()
    return { result = { success = true, message = L('crim_info_updated'), criminal = final } }
end)

MDT.rpc('updateCriminalPhoto', { perm = 'criminals', staff = true, duty = true }, function(actor, p)
    local deny = noLawyer(actor, true)
    if deny then return deny end
    local url = MDT.url(p.photoUrl)
    local id = MDT.int(p.criminalId, 1, nil, nil)
    if not id then
        local cid = MDT.str(p.identity, 50)
        if cid == '' then return { result = { success = false, message = L('crim_not_found') } } end
        id = DB.val('SELECT id FROM mdt_criminals WHERE identity = ?', { cid })
        if not id then
            local name, ch = MDT.charName(cid)
            if not name then return { result = { success = false, message = L('crim_not_found') } } end
            id = DB.ins('INSERT INTO mdt_criminals (player_id, identity, firstname, lastname, age, status, registered_by) VALUES (?, ?, ?, ?, ?, ?, ?)',
                { MDT.findByCid(cid) or 0, cid, ch.firstname or MDT.str(p.firstname, 50), ch.lastname or MDT.str(p.lastname, 50), MDT.int(p.age, 0, 200, 0), 'clear', actor.name })
        end
    end
    local n = DB.upd('UPDATE mdt_criminals SET photo_url = ? WHERE id = ?', { url, id })
    if n == 0 and not DB.val('SELECT id FROM mdt_criminals WHERE id = ?', { id }) then
        return { result = { success = false, message = L('crim_not_found') } }
    end
    MDT.audit(actor, 'criminal_photo_updated', nil, nil, 'Record #' .. tostring(id))
    Records.broadcast()
    return { result = { success = true, message = L('crim_photo_updated'), criminal = { id = id, photoUrl = url } } }
end)

MDT.rpc('validatePlayerIdentity', { perm = 'criminals', staff = true }, function(actor, p)
    local t = MDT.player(MDT.int(p.playerId, 1, nil, 0))
    if not t then return { result = { success = false, message = L('crim_player_offline') } } end
    return { result = {
        success = true, playerId = t.src, identity = t.cid, firstname = t.firstname, lastname = t.lastname, age = t.age,
        job = actor.isLawyer and nil or t.job,
    } }
end)

MDT.rpc('getCriminalHistory', { perm = 'criminals', staff = true, deny = { data = { incidents = {}, arrests = {} } } }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local m = id and DB.one('SELECT id, identity FROM mdt_criminals WHERE id = ?', { id })
    -- a citizen with no record row is looked up by citizen id: no incidents, but their prison terms
    local cid = m and tostring(m.identity) or MDT.str(p.identity, 50)
    if cid == '' then return { data = { criminalId = id, incidents = {}, arrests = {} } } end
    local incidents = m and DB.q('SELECT id, title, description, created_by, created_at FROM mdt_evidence WHERE criminal_id = ? ORDER BY created_at DESC LIMIT 200', { m.id }) or {}
    local terms = DB.q('SELECT id, sentence_minutes, status, imprisoned_by, imprisoned_at, reason, fine_amount FROM mdt_prison_records WHERE charidentifier = ? ORDER BY imprisoned_at DESC LIMIT 200', { cid })
    -- the page reads arrests as mdt_arrests rows; prison terms go with the incidents (it reads both shapes there)
    local arrests = DB.q('SELECT id, charges, final_fine, final_months, lawman_name, created_at FROM mdt_arrests WHERE citizen_identity = ? ORDER BY created_at DESC LIMIT 200', { cid })
    for _, t in ipairs(terms) do incidents[#incidents + 1] = t end
    return { data = { criminalId = id, incidents = incidents, arrests = arrests } }
end)

MDT.rpc('getCitizenProfile', { perm = { 'dashboard', 'criminals' }, staff = true }, function(actor, p)
    local cid = MDT.str(p.identity, 50)
    local name = MDT.str(p.name, 100)
    if cid == '' then return { success = false, message = L('crim_not_found') } end
    local reports = DB.q([[SELECT r.id, r.report_number, r.title, r.type, r.created_at, MIN(i.type) AS involvement
        FROM mdt_reports r JOIN mdt_reports_involved i ON i.reportid = r.id
        WHERE i.citizenid = ? GROUP BY r.id ORDER BY r.created_at DESC LIMIT 10]], { cid })
    local warrants = DB.q([[SELECT id, citizen_name, citizenid, charges, status, expiry_date, bounty_fine, bounty_jailtime, bounty_reward, issued_by, created_at
        FROM mdt_reports_warrants WHERE citizenid = ? OR (? <> '' AND citizen_name = ?) ORDER BY created_at DESC LIMIT 10]], { cid, name, name })
    local bolos = DB.q([[SELECT id, subject_name, location, description, lawman_name, created_at
        FROM mdt_bolos WHERE status = 'active' AND (po_number = ? OR (? <> '' AND subject_name = ?)) ORDER BY created_at DESC LIMIT 5]], { cid, name, name })
    local cases = DB.q([[SELECT c.id, c.case_number, c.title, c.status, c.priority, c.created_at, MIN(i.type) AS involvement
        FROM mdt_cases c JOIN mdt_cases_involved i ON i.caseid = c.id
        WHERE i.citizenid = ? GROUP BY c.id ORDER BY c.created_at DESC LIMIT 10]], { cid })
    local totals = DB.one('SELECT COUNT(*) AS n, COALESCE(SUM(IF(fine_applied = 1, final_fine, 0)), 0) AS fines FROM mdt_arrests WHERE citizen_identity = ?', { cid }) or {}
    local arrests = DB.q('SELECT id, charges, final_fine, final_months, lawman_name, notes, created_at FROM mdt_arrests WHERE citizen_identity = ? ORDER BY created_at DESC LIMIT 100', { cid })
    local tally, order = {}, {}
    for _, a in ipairs(arrests) do
        for _, c in ipairs(MDT.jdec(a.charges, {})) do
            local label = tostring(c.label or c.code or '?')
            local t = tally[label]
            if not t then t = { label = label, count = 0, fine = 0, months = 0 }; tally[label] = t; order[#order + 1] = t end
            local n = tonumber(c.count) or 1
            t.count = t.count + n
            t.fine = t.fine + (tonumber(c.fine) or 0) * n
            t.months = t.months + (tonumber(c.months) or 0) * n
        end
    end
    local info = Prison.infoByCid(cid)
    local exps = DB.q("SELECT id, citizen_name, reason, reviewed_by_name, reviewed_at, records_cleared FROM mdt_expungements WHERE citizen_identity = ? AND status = 'approved' ORDER BY reviewed_at DESC LIMIT 10", { cid })
    return {
        reports = reports, warrants = warrants, bolos = bolos, cases = cases,
        arrests = arrests, arrestsTotal = tonumber(totals.n) or 0, charges = order,
        totalFines = tonumber(totals.fines) or 0,
        isServing = info ~= nil, prisonInfo = info,
        hasActiveBounty = hasActiveBounty(cid),
        expungements = exps,
        summary = { cases = #cases, reports = #reports, charges = #order, totalFines = tonumber(totals.fines) or 0 },
    }
end)

MDT.rpc('lookupCitizen', { perm = 'dashboard', staff = true, deny = { found = false } }, function(actor, p)
    local cid = MDT.str(p.citizenid, 50)
    local name, row = MDT.charName(cid)
    if not name then return { found = false, citizenid = cid } end
    return { found = true, citizenid = cid, firstname = row.firstname, lastname = row.lastname, fullname = name, name = name }
end)

MDT.rpc('getOnlinePlayers', { perm = { 'dashboard', 'criminals' }, staff = true, deny = {} }, function()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local a = MDT.player(s)
        if a then out[#out + 1] = { serverId = a.src, name = a.name } end
    end
    table.sort(out, function(x, y) return x.serverId < y.serverId end)
    return out
end)
