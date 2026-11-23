-- pup-mdt | incident reports, case files, witness statements, evidence items

local PER_PAGE = 25

local REPORT_TYPES = { 'Incident Report', 'Arrest Report', 'Investigation Report', 'Use of Force Report', 'Stolen Property Report', 'Missing Person Report', 'Other' }
local INVOLVED_REPORT = { 'suspect', 'victim', 'witness', 'lawman' }
local INVOLVED_CASE = { 'suspect', 'victim', 'witness', 'person_of_interest' }
local LAWMAN_ROLES = { 'lead', 'assisting', 'supervisor', 'consulting' }
local EVIDENCE_TYPES = { 'bloodstain', 'boot print', 'horse track', 'spent casing', 'weapon', 'document', 'contraband', 'item', 'photograph', 'fingerprint', 'fabric', 'other' }
local EVIDENCE_STATUS = { 'collected', 'analyzed', 'stored', 'destroyed' }

local function enumExact(v, list, default)
    if type(v) ~= 'string' then return default end
    for _, x in ipairs(list) do if x:lower() == v:lower() then return x end end
    return default
end

local function people(list, types, typeKey)
    local out = {}
    if type(list) ~= 'table' then return out end
    for i, x in ipairs(list) do
        if i > 50 then break end
        if type(x) == 'table' then
            local name = MDT.str(x.name, 100)
            if name ~= '' then
                out[#out + 1] = {
                    citizenid = MDT.str(x.citizenid, 50), name = name,
                    kind = MDT.enum(x[typeKey], types, types[1]), notes = MDT.str(x.notes, 500, true),
                }
            end
        end
    end
    return out
end

-- next "<PREFIX>-<year>-<0000>" number, from the highest used this year
local function nextNumber(tbl, col, prefix)
    local year = os.date('%Y')
    local stem = ('%s-%s-'):format(prefix, year)
    local top = DB.val(('SELECT MAX(CAST(SUBSTRING(%s, ?) AS UNSIGNED)) FROM %s WHERE %s LIKE ?'):format(col, tbl, col), { #stem + 1, stem .. '%' })
    return ('%s%04d'):format(stem, (tonumber(top) or 0) + 1)
end

---------------------------------------------------------------------------
-- Reports
---------------------------------------------------------------------------
local function attachPeople(rows, invTbl, lawTbl, key)
    if #rows == 0 then return end
    local ids, map = {}, {}
    for _, r in ipairs(rows) do ids[#ids + 1] = r.id; map[r.id] = r; r.involved = {}; r.lawmen = {} end
    local marks = string.rep('?,', #ids):sub(1, -2)
    for _, i in ipairs(DB.q(('SELECT * FROM %s WHERE %s IN (%s)'):format(invTbl, key, marks), ids)) do
        local r = map[i[key]]
        if r then r.involved[#r.involved + 1] = i end
    end
    for _, l in ipairs(DB.q(('SELECT * FROM %s WHERE %s IN (%s)'):format(lawTbl, key, marks), ids)) do
        local r = map[l[key]]
        if r then r.lawmen[#r.lawmen + 1] = l end
    end
end

MDT.rpc('getReports', { perm = 'dashboard', law = true, deny = { reports = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(_, p)
    local search = MDT.str(p.search, 100)
    local typeF = MDT.str(p.typeFilter, 50)
    local where, params = {}, {}
    -- optional id: one record opened on demand (a # link or a profile row)
    local oneId = MDT.int(p.id, 1, nil, nil)
    if oneId then where[#where + 1] = 'id = ?'; params[#params + 1] = oneId; search, typeF = '', '' end
    if search ~= '' then
        local like = MDT.like(search)
        where[#where + 1] = '(LOWER(title) LIKE ? OR LOWER(author_name) LIKE ? OR LOWER(report_number) LIKE ? OR LOWER(location) LIKE ?)'
        for _ = 1, 4 do params[#params + 1] = like end
    end
    if typeF ~= '' and typeF ~= 'all' then where[#where + 1] = 'type = ?'; params[#params + 1] = typeF end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local total = tonumber(DB.val('SELECT COUNT(*) FROM mdt_reports' .. w, params)) or 0
    local page, offset, pages = MDT.paging(p.page, PER_PAGE, total)
    local p2 = {}
    for _, v in ipairs(params) do p2[#p2 + 1] = v end
    p2[#p2 + 1] = PER_PAGE; p2[#p2 + 1] = offset
    local rows = DB.q('SELECT * FROM mdt_reports' .. w .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?', p2)
    for _, r in ipairs(rows) do
        r.crimes = MDT.jdec(r.crimes_json, {})
        r.confiscatedItems = MDT.jdec(r.confiscated_items, {})
    end
    attachPeople(rows, 'mdt_reports_involved', 'mdt_reports_lawmen', 'reportid')
    return { reports = rows, currentPage = page, totalPages = pages, totalRecords = total }
end)

local function reportFields(p)
    return {
        title = MDT.str(p.title, Config.Features.reportTitleMax),
        type = enumExact(p.type, REPORT_TYPES, 'Incident Report'),
        location = MDT.str(p.location, 200),
        content = MDT.html(p.content, 60000),
        plain = MDT.plain(p.content_plaintext ~= nil and p.content_plaintext or p.content, 20000),
        crimes = MDT.list(p.crimes, 50, 200),
        red = MDT.int(p.reduction_percent, 0, 100, 0),
        jailRed = MDT.int(p.jail_reduction_percent, 0, 100, 0),
        fineRed = MDT.int(p.fine_reduction_percent, 0, 100, 0),
        confiscated = MDT.list(p.confiscatedItems, 100, 100),
        involved = people(p.involved, INVOLVED_REPORT, 'type'),
        lawmen = people(p.reportLawmen, LAWMAN_ROLES, 'role'),
    }
end

local function saveReportPeople(id, f)
    DB.q('DELETE FROM mdt_reports_involved WHERE reportid = ?', { id })
    DB.q('DELETE FROM mdt_reports_lawmen WHERE reportid = ?', { id })
    for _, i in ipairs(f.involved) do
        DB.ins('INSERT INTO mdt_reports_involved (reportid, citizenid, name, type, notes) VALUES (?, ?, ?, ?, ?)', { id, i.citizenid, i.name, i.kind, i.notes })
    end
    for _, l in ipairs(f.lawmen) do
        DB.ins('INSERT INTO mdt_reports_lawmen (reportid, citizenid, name, role) VALUES (?, ?, ?, ?)', { id, l.citizenid, l.name, l.kind })
    end
    -- charges are kept per citizen: the one a charge names, else every suspect on the report
    DB.q('DELETE FROM mdt_reports_charges WHERE reportid = ?', { id })
    for _, r in ipairs(f.chargeRows) do
        local pc, count = r.pc, r.count
        DB.ins('INSERT INTO mdt_reports_charges (reportid, citizenid, charge_label, charge_code, charge_class, count, jail_time, fine) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            { id, r.cid, pc.label, pc.code, pc.charge_class, count, pc.months * count, pc.fine * count })
    end
end

-- builds the charge rows and checks them against the per-report limits; returns an error message or nil
local function buildCharges(f)
    local maxSuspects = tonumber(Config.Features.reportMaxSuspects) or 25
    local maxCharges = tonumber(Config.Features.reportMaxChargesPerSuspect) or 25
    local codes = Penal.byCode()
    local suspects = {}
    for _, i in ipairs(f.involved) do
        if i.kind == 'suspect' and i.citizenid ~= '' then suspects[#suspects + 1] = i.citizenid end
    end
    if #suspects > maxSuspects then return L('rep_too_many_suspects', maxSuspects) end
    local rows, perCid = {}, {}
    for _, c in ipairs(f.crimes) do
        if type(c) == 'table' and codes[c.code or ''] then
            local pc = codes[c.code]
            local count = MDT.int(c.count, 1, 20, 1)
            local who = (c.citizenid and c.citizenid ~= '') and { MDT.str(c.citizenid, 50) } or suspects
            for _, cid in ipairs(who) do
                perCid[cid] = (perCid[cid] or 0) + 1
                if perCid[cid] > maxCharges then return L('rep_too_many_charges', maxCharges) end
                rows[#rows + 1] = { cid = cid, pc = pc, count = count }
            end
        end
    end
    f.chargeRows = rows
    return nil
end

-- one report save or edit per officer every few seconds
local lastSave = {}
local function saveTooSoon(actor)
    local gap = (tonumber(Config.Features.reportSaveCooldownSeconds) or 4) * 1000
    local last = lastSave[actor.cid]
    return last ~= nil and GetGameTimer() - last < gap
end

MDT.rpc('saveReport', { perm = 'reports', law = true, duty = true }, function(actor, p)
    if saveTooSoon(actor) then return { success = false, message = L('arrest_wait') } end
    local f = reportFields(p)
    if f.title == '' then return { success = false, message = L('rep_title_required') } end
    local err = buildCharges(f)
    if err then return { success = false, message = err } end
    lastSave[actor.cid] = GetGameTimer()
    local number = nextNumber('mdt_reports', 'report_number', 'RPT')
    local id = DB.ins([[INSERT INTO mdt_reports (report_number, title, type, location, content, content_plaintext, crimes_json, reduction_percent,
        jail_reduction_percent, fine_reduction_percent, author_citizenid, author_name, confiscated_items) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        { number, f.title, f.type, f.location, f.content, f.plain, MDT.jenc(f.crimes), f.red, f.jailRed, f.fineRed, actor.cid, actor.name, MDT.jenc(f.confiscated) })
    if not id then return { success = false, message = L('rep_save_failed') } end
    saveReportPeople(id, f)
    MDT.audit(actor, 'report_saved', nil, nil, number .. ' ' .. f.title)
    MDT.log('reports', 'Report filed', ('%s filed %s: %s'):format(actor.name, number, f.title), 'blue')
    Cache.clear('dashboard')
    return { success = true, id = id, report_number = number }
end)

MDT.rpc('updateReport', { perm = 'reports', law = true, duty = true }, function(actor, p)
    if saveTooSoon(actor) then return { success = false, message = L('arrest_wait') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local old = id and DB.one('SELECT id, report_number, author_citizenid FROM mdt_reports WHERE id = ?', { id })
    if not old then return { success = false, message = L('rep_not_found') } end
    local isAuthor = tostring(old.author_citizenid) == actor.cid
    local onReport = DB.val('SELECT id FROM mdt_reports_lawmen WHERE reportid = ? AND citizenid = ? LIMIT 1', { id, actor.cid }) ~= nil
    if not isAuthor and not onReport and not MDT.can(actor, 'deletereports') then
        return { success = false, message = L('rep_not_author') }
    end
    local f = reportFields(p)
    if f.title == '' then return { success = false, message = L('rep_title_required') } end
    local err = buildCharges(f)
    if err then return { success = false, message = err } end
    lastSave[actor.cid] = GetGameTimer()
    DB.upd([[UPDATE mdt_reports SET title = ?, type = ?, location = ?, content = ?, content_plaintext = ?, crimes_json = ?, reduction_percent = ?,
        jail_reduction_percent = ?, fine_reduction_percent = ?, confiscated_items = ? WHERE id = ?]],
        { f.title, f.type, f.location, f.content, f.plain, MDT.jenc(f.crimes), f.red, f.jailRed, f.fineRed, MDT.jenc(f.confiscated), id })
    saveReportPeople(id, f)
    MDT.audit(actor, 'report_saved', nil, nil, 'Edited ' .. tostring(old.report_number))
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('deleteReport', { perm = 'deletereports', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local old = id and DB.one('SELECT id, report_number, title FROM mdt_reports WHERE id = ?', { id })
    if not old then return { success = false, id = id, message = L('rep_not_found') } end
    DB.q('DELETE FROM mdt_reports WHERE id = ?', { id })
    MDT.audit(actor, 'report_deleted', nil, nil, tostring(old.report_number) .. ' ' .. tostring(old.title))
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('getReportLinkables', { perm = 'dashboard', law = true, deny = { cases = {}, bounties = {}, evidence = {}, reports = {} } }, function()
    local out = { cases = {}, bounties = {}, evidence = {}, reports = {} }
    for _, r in ipairs(DB.q('SELECT id, case_number, title FROM mdt_cases ORDER BY created_at DESC LIMIT 200')) do
        out.cases[#out.cases + 1] = { id = r.id, ref = r.case_number, label = r.title }
    end
    for _, r in ipairs(DB.q("SELECT id, citizen_name FROM mdt_reports_warrants WHERE status = 'active' ORDER BY created_at DESC LIMIT 200")) do
        out.bounties[#out.bounties + 1] = { id = r.id, ref = 'BW-' .. r.id, label = r.citizen_name }
    end
    for _, r in ipairs(DB.q('SELECT id, label FROM mdt_evidence_items ORDER BY created_at DESC LIMIT 200')) do
        out.evidence[#out.evidence + 1] = { id = r.id, ref = 'EVD-' .. r.id, label = r.label }
    end
    for _, r in ipairs(DB.q('SELECT id, report_number, title FROM mdt_reports ORDER BY created_at DESC LIMIT 200')) do
        out.reports[#out.reports + 1] = { id = r.id, ref = r.report_number, label = r.title }
    end
    return out
end)

---------------------------------------------------------------------------
-- Cases
---------------------------------------------------------------------------
MDT.rpc('getCases', { perm = 'dashboard', law = true, deny = { cases = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(_, p)
    local status = MDT.enum(p.status, { 'open', 'active', 'suspended', 'closed' }, nil)
    local search = MDT.str(p.search, 100)
    local where, params = {}, {}
    local oneId = MDT.int(p.id, 1, nil, nil)
    if oneId then where[#where + 1] = 'id = ?'; params[#params + 1] = oneId; status, search = nil, '' end
    if status then where[#where + 1] = 'status = ?'; params[#params + 1] = status end
    if search ~= '' then
        where[#where + 1] = '(LOWER(title) LIKE ? OR LOWER(case_number) LIKE ?)'
        params[#params + 1] = MDT.like(search); params[#params + 1] = MDT.like(search)
    end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local total = tonumber(DB.val('SELECT COUNT(*) FROM mdt_cases' .. w, params)) or 0
    local page, offset, pages = MDT.paging(p.page, PER_PAGE, total)
    local p2 = {}
    for _, v in ipairs(params) do p2[#p2 + 1] = v end
    p2[#p2 + 1] = PER_PAGE; p2[#p2 + 1] = offset
    local rows = DB.q('SELECT * FROM mdt_cases' .. w .. ' ORDER BY updated_at DESC LIMIT ? OFFSET ?', p2)
    for _, r in ipairs(rows) do
        r.assignedLawmen = MDT.jdec(r.assigned_lawmen, {})
        r.linkedReports = MDT.jdec(r.linked_reports, {})
        r.linkedEvidence = MDT.jdec(r.linked_evidence, {})
        r.confiscatedItems = MDT.jdec(r.confiscated_items, {})
    end
    attachPeople(rows, 'mdt_cases_involved', 'mdt_cases_lawmen', 'caseid')
    return { cases = rows, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('getCasesList', { perm = 'dashboard', law = true, deny = {} }, function()
    return DB.q('SELECT id, case_number, title, status FROM mdt_cases ORDER BY created_at DESC LIMIT 200')
end)

MDT.rpc('saveCase', { perm = 'evidences', law = true, duty = true }, function(actor, p)
    local title = MDT.str(p.title, 150)
    if title == '' then return { success = false, message = L('case_title_required') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local v = {
        title = title, location = MDT.str(p.location, 200), description = MDT.str(p.description, 8000, true),
        status = MDT.enum(p.status, { 'open', 'active', 'suspended', 'closed' }, 'open'),
        priority = MDT.enum(p.priority, { 'low', 'medium', 'high', 'critical' }, 'medium'),
        investigator = MDT.str(p.investigator_name, 100),
    }
    local number
    if id then
        local old = DB.one('SELECT id, case_number FROM mdt_cases WHERE id = ?', { id })
        if not old then return { success = false, message = L('case_not_found') } end
        number = old.case_number
        DB.upd('UPDATE mdt_cases SET title = ?, location = ?, description = ?, status = ?, priority = ?, investigator_name = ? WHERE id = ?',
            { v.title, v.location, v.description, v.status, v.priority, v.investigator, id })
    else
        for attempt = 1, 5 do
            number = nextNumber('mdt_cases', 'case_number', 'CASE')
            local ok, newId = pcall(DB.ins, [[INSERT INTO mdt_cases (case_number, title, location, description, status, priority, created_by, created_citizenid,
                investigator_name, assigned_lawmen, linked_reports, linked_evidence, confiscated_items) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, '[]', '[]', '[]', '[]')]],
                { number, v.title, v.location, v.description, v.status, v.priority, actor.name, actor.cid, v.investigator })
            if ok and newId then id = newId break end
            Wait(50 * attempt)
        end
        if not id then return { success = false, message = L('case_save_failed') } end
    end
    -- lists are only replaced when the page sends them
    if p.assignedLawmen ~= nil then DB.upd('UPDATE mdt_cases SET assigned_lawmen = ? WHERE id = ?', { MDT.jenc(MDT.list(p.assignedLawmen, 50, 100)), id }) end
    if p.linkedReports ~= nil then DB.upd('UPDATE mdt_cases SET linked_reports = ? WHERE id = ?', { MDT.jenc(MDT.list(p.linkedReports, 100, 50)), id }) end
    if p.confiscatedItems ~= nil then DB.upd('UPDATE mdt_cases SET confiscated_items = ? WHERE id = ?', { MDT.jenc(MDT.list(p.confiscatedItems, 100, 100)), id }) end
    local skipped = 0
    if p.linkedEvidence ~= nil then
        local wanted = {}
        for _, x in ipairs(MDT.list(p.linkedEvidence, 200, 20)) do
            local eid = MDT.int(type(x) == 'table' and x.id or x, 1, nil, nil)
            if eid then wanted[#wanted + 1] = eid end
        end
        DB.upd("UPDATE mdt_evidence_items SET linked_case = NULL WHERE linked_case = ?", { number })
        local kept = {}
        for _, eid in ipairs(wanted) do
            -- an item already on another case stays there
            local n = DB.upd("UPDATE mdt_evidence_items SET linked_case = ? WHERE id = ? AND (linked_case IS NULL OR linked_case = '' OR linked_case = ?)", { number, eid, number })
            if n > 0 then kept[#kept + 1] = eid else skipped = skipped + 1 end
        end
        DB.upd('UPDATE mdt_cases SET linked_evidence = ? WHERE id = ?', { MDT.jenc(kept), id })
    end
    if p.involved ~= nil then
        DB.q('DELETE FROM mdt_cases_involved WHERE caseid = ?', { id })
        for _, i in ipairs(people(p.involved, INVOLVED_CASE, 'type')) do
            DB.ins('INSERT INTO mdt_cases_involved (caseid, citizenid, name, type, notes) VALUES (?, ?, ?, ?, ?)', { id, i.citizenid, i.name, i.kind, i.notes })
        end
    end
    if p.caseLawmen ~= nil then
        DB.q('DELETE FROM mdt_cases_lawmen WHERE caseid = ?', { id })
        for _, l in ipairs(people(p.caseLawmen, LAWMAN_ROLES, 'role')) do
            DB.ins('INSERT INTO mdt_cases_lawmen (caseid, citizenid, name, role) VALUES (?, ?, ?, ?)', { id, l.citizenid, l.name, l.kind })
        end
    end
    MDT.audit(actor, MDT.int(p.id, 1, nil, nil) and 'case_updated' or 'case_created', nil, nil, number .. ' ' .. title)
    return { success = true, id = id, caseNumber = number, message = skipped > 0 and L('case_evidence_skipped', skipped) or nil }
end)

MDT.rpc('deleteCase', { perm = 'deleterecords', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local old = id and DB.one('SELECT id, case_number, title FROM mdt_cases WHERE id = ?', { id })
    if not old then return { success = false, message = L('case_not_found') } end
    DB.q('DELETE FROM mdt_cases WHERE id = ?', { id })
    DB.upd('UPDATE mdt_evidence_items SET linked_case = NULL WHERE linked_case = ?', { old.case_number })
    MDT.audit(actor, 'case_deleted', nil, nil, tostring(old.case_number) .. ' ' .. tostring(old.title))
    return { success = true }
end)

---------------------------------------------------------------------------
-- Witness statements (BOLO table)
---------------------------------------------------------------------------
local MAX_ACTIVE_STATEMENTS = 50

MDT.rpc('getBolos', { perm = 'dashboard', law = true, deny = { bolos = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(_, p)
    local search = MDT.str(p.search, 100)
    local where, params = "status = 'active'", {}
    if search ~= '' then
        local like = MDT.like(search)
        where = where .. [[ AND (LOWER(subject_name) LIKE ? OR LOWER(description) LIKE ? OR LOWER(issued_by_name) LIKE ? OR po_number = ?
            OR LOWER(location) LIKE ? OR LOWER(lawman_name) LIKE ? OR LOWER(region) LIKE ?)]]
        params = { like, like, like, search, like, like, like }
    end
    local total = tonumber(DB.val('SELECT COUNT(*) FROM mdt_bolos WHERE ' .. where, params)) or 0
    local page, offset, pages = MDT.paging(p.page, PER_PAGE, total)
    params[#params + 1] = PER_PAGE; params[#params + 1] = offset
    local rows = DB.q('SELECT id, subject_name, po_number, location, description, lawman_name, region, issued_by_name AS issued_by, status, created_at FROM mdt_bolos WHERE '
        .. where .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?', params)
    return { bolos = rows, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('createBolo', { perm = 'bolos', law = true, duty = true }, function(actor, p)
    local subject = MDT.str(p.subject_name, 100)
    if subject == '' then return { success = false, message = L('bolo_subject_required') } end
    if (tonumber(DB.val("SELECT COUNT(*) FROM mdt_bolos WHERE status = 'active'")) or 0) >= MAX_ACTIVE_STATEMENTS then
        return { success = false, message = L('bolo_too_many', MAX_ACTIVE_STATEMENTS) }
    end
    local id = DB.ins([[INSERT INTO mdt_bolos (type, subject_name, po_number, location, description, lawman_name, region, status, issued_by, issued_by_name)
        VALUES ('witness_statement', ?, ?, ?, ?, ?, ?, 'active', ?, ?)]], {
        subject, MDT.str(p.po_number, 50), MDT.str(p.location, 200), MDT.str(p.description, 4000, true),
        MDT.str(p.lawman_name, 100), MDT.str(p.region, 50), actor.cid, actor.name })
    MDT.audit(actor, 'bolo_created', MDT.str(p.po_number, 50), subject, '')
    MDT.log('statements', 'Witness statement', ('%s took a statement about %s'):format(actor.name, subject), 'blue')
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('resolveBolo', { perm = 'bolos', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local n = id and DB.upd("UPDATE mdt_bolos SET status = 'resolved' WHERE id = ? AND status = 'active'", { id }) or 0
    if n == 0 then return { success = false, id = id, message = L('bolo_not_found') } end
    MDT.audit(actor, 'bolo_resolved', nil, nil, '#' .. id)
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('deleteBolo', { perm = 'deletebolos', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local n = id and DB.upd('DELETE FROM mdt_bolos WHERE id = ?', { id }) or 0
    if n == 0 then return { success = false, id = id, message = L('bolo_not_found') } end
    MDT.audit(actor, 'bolo_deleted', nil, nil, '#' .. id)
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('lookupBoloCitizen', { perm = 'dashboard', law = true, deny = { found = false } }, function(_, p)
    local cid = MDT.str(p.citizenIdentity, 50)
    local name = MDT.charName(cid)
    if not name then return { found = false } end
    local region = DB.val('SELECT region FROM mdt_lawman_profiles WHERE citizen_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1', { cid })
    return { found = true, name = name, region = region or '' }
end)

---------------------------------------------------------------------------
-- Evidence items
---------------------------------------------------------------------------
MDT.rpc('getEvidence', { perm = 'evidences', law = true, deny = { evidence = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(_, p)
    local where, params = {}, {}
    local t = enumExact(p.type, EVIDENCE_TYPES, nil)
    local s = MDT.enum(p.status, EVIDENCE_STATUS, nil)
    local search = MDT.str(p.search, 100)
    local oneId = MDT.int(p.id, 1, nil, nil)
    if oneId then where[#where + 1] = 'id = ?'; params[#params + 1] = oneId; t, s, search = nil, nil, '' end
    if t then where[#where + 1] = 'type = ?'; params[#params + 1] = t end
    if s then where[#where + 1] = 'status = ?'; params[#params + 1] = s end
    if search ~= '' then
        where[#where + 1] = '(LOWER(label) LIKE ? OR LOWER(location_found) LIKE ?)'
        params[#params + 1] = MDT.like(search); params[#params + 1] = MDT.like(search)
    end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local total = tonumber(DB.val('SELECT COUNT(*) FROM mdt_evidence_items' .. w, params)) or 0
    local page, offset, pages = MDT.paging(p.page, PER_PAGE, total)
    params[#params + 1] = PER_PAGE; params[#params + 1] = offset
    local rows = DB.q('SELECT * FROM mdt_evidence_items' .. w .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?', params)
    for _, r in ipairs(rows) do r.image_urls = MDT.jdec(r.image_urls, {}) end
    return { evidence = rows, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('getEvidenceItems', { perm = 'evidences', law = true, deny = {} }, function()
    return DB.q('SELECT id, type, label, description, linked_case, status, label AS title FROM mdt_evidence_items ORDER BY created_at DESC LIMIT 500')
end)

MDT.rpc('saveEvidence', { perm = 'evidences', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if id then
        local status = MDT.enum(p.status, EVIDENCE_STATUS, nil)
        if not status then return { success = false, message = L('ev_bad_status') } end
        local n = DB.upd('UPDATE mdt_evidence_items SET status = ? WHERE id = ?', { status, id })
        if n == 0 and not DB.val('SELECT id FROM mdt_evidence_items WHERE id = ?', { id }) then
            return { success = false, message = L('ev_not_found') }
        end
        MDT.audit(actor, 'evidence_status', nil, nil, 'EVD-' .. id .. ' ' .. status)
        return { success = true }
    end
    local label = MDT.str(p.label, 150)
    if label == '' then return { success = false, message = L('ev_label_required') } end
    -- a photo is a URL or { url, caption } (the page sends the second)
    local images = {}
    for _, u in ipairs(MDT.list(p.image_urls, 10, 500)) do
        if type(u) == 'table' then
            local url = MDT.url(u.url)
            if url ~= '' then images[#images + 1] = { url = url, caption = MDT.str(u.caption, 100) } end
        else
            local url = MDT.url(u)
            if url ~= '' then images[#images + 1] = url end
        end
    end
    local linked = MDT.str(p.linked_case, 30)
    if linked ~= '' and not DB.val('SELECT id FROM mdt_cases WHERE case_number = ?', { linked }) then linked = '' end
    DB.ins([[INSERT INTO mdt_evidence_items (type, label, description, location_found, collected_by, linked_case, status, notes, image_urls)
        VALUES (?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?)]], {
        enumExact(p.type, EVIDENCE_TYPES, 'other'), label, MDT.str(p.description, 4000, true), MDT.str(p.location_found, 200),
        actor.name, linked, MDT.enum(p.status, EVIDENCE_STATUS, 'collected'), MDT.str(p.notes, 4000, true), MDT.jenc(images) })
    Lawmen.bumpStat(actor.cid, 'evidences_collected', 1)
    MDT.audit(actor, 'evidence_item_added', nil, nil, label)
    MDT.log('evidence', 'Evidence logged', ('%s logged %s'):format(actor.name, label), 'blue')
    return { success = true }
end)

MDT.rpc('deleteEvidence', { perm = 'deleterecords', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local row = id and DB.one('SELECT id, label FROM mdt_evidence_items WHERE id = ?', { id })
    if not row then return { success = false, message = L('ev_not_found') } end
    DB.q('DELETE FROM mdt_evidence_items WHERE id = ?', { id })
    MDT.audit(actor, 'evidence_deleted', nil, nil, 'EVD-' .. id .. ' ' .. tostring(row.label))
    return { success = true }
end)
