-- pup-mdt | bail, appeals, expungements

Legal = {}

local PER_PAGE = 15
local BAIL = Config.Legal.bail
local POLICE_JOB = Config.LawJobs[1]

-- may this actor rule on bail or appeals
local function canRule(actor, perm)
    if not MDT.can(actor, perm) then return false end
    if actor.isLawyer and not Config.Legal.judgeApproves then return false end
    return true
end

local function toolOn(name) return Config.Legal.enabled and Config.Legal.tools[name] end

local function listQuery(tbl, p, extraOrder)
    local status = MDT.str(p.status, 20)
    local search = MDT.str(p.search, 60)
    local where, params = {}, {}
    if status ~= '' and status ~= 'all' then where[#where + 1] = 'status = ?'; params[#params + 1] = status end
    if search ~= '' then
        where[#where + 1] = '(LOWER(citizen_name) LIKE ? OR citizen_identity = ?)'
        params[#params + 1] = MDT.like(search); params[#params + 1] = search
    end
    local w = #where > 0 and (' WHERE ' .. table.concat(where, ' AND ')) or ''
    local total = tonumber(DB.val('SELECT COUNT(*) FROM ' .. tbl .. w, params)) or 0
    local page, offset, pages = MDT.paging(p.page, PER_PAGE, total)
    local p2 = {}
    for _, v in ipairs(params) do p2[#p2 + 1] = v end
    p2[#p2 + 1] = PER_PAGE; p2[#p2 + 1] = offset
    local rows = DB.q('SELECT * FROM ' .. tbl .. w .. " ORDER BY (status = 'pending') DESC, " .. (extraOrder or '') .. ' id DESC LIMIT ? OFFSET ?', p2)
    return rows, page, pages, total
end

local function pushAll(action)
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if Duty.isOn(src) then MDT.nui(src, { action = action }) end
    end
end

---------------------------------------------------------------------------
-- Bail
---------------------------------------------------------------------------
-- money owed back to a citizen (paid = 3) is paid when they are online
-- Each row is claimed (3 -> 2) before any money moves, so two callers at once (login and
-- a ruling, or the sweep) can never pay the same refund twice; a failed payout puts the
-- claim back. The refund comes out of the ledger only when the bail went into it.
function Legal.payRefunds(cid)
    cid = tostring(cid or '')
    if cid == '' or not MDT.findByCid(cid) then return end
    local rows = DB.q('SELECT id, amount FROM mdt_bail WHERE citizen_identity = ? AND paid = 3', { cid })
    for _, r in ipairs(rows) do
        local amount = tonumber(r.amount) or 0
        if amount <= 0 then
            DB.upd('UPDATE mdt_bail SET paid = 2 WHERE id = ? AND paid = 3', { r.id })
        elseif DB.upd('UPDATE mdt_bail SET paid = 2 WHERE id = ? AND paid = 3', { r.id }) == 1 then
            local fromLedger = BAIL.intoLedger == true
            local covered = not fromLedger or Ledger.debit(POLICE_JOB, amount, 'bail_refund', 'Court', 'Bail returned #' .. r.id)
            -- the debit waited on the database: pay only the character the refund belongs to
            local src = covered and MDT.findByCid(cid)
            local ch = src and MDT.char(src)
            if ch and tostring(ch.charIdentifier) == cid and pcall(ch.addCurrency, 0, amount) then
                MDT.notify(src, L('bail_refunded', amount), 6000)
            else
                if covered and fromLedger then Ledger.credit(POLICE_JOB, amount, 'bail', 'Court', 'Refund could not be paid #' .. r.id) end
                DB.upd('UPDATE mdt_bail SET paid = 3 WHERE id = ? AND paid = 2', { r.id })
            end
        end
    end
end

-- owed refunds of everyone online (the 5-minute sweep)
function Legal.payOnlineRefunds()
    local rows = DB.q('SELECT DISTINCT citizen_identity FROM mdt_bail WHERE paid = 3')
    if #rows == 0 then return end
    local online = MDT.onlineMap()
    for _, r in ipairs(rows) do
        local cid = tostring(r.citizen_identity)
        if online[cid] then Legal.payRefunds(cid) end
    end
end

AddEventHandler('vorp:SelectedCharacter', function(src)
    SetTimeout(5000, function()
        local a = MDT.player(src)
        if a then Legal.payRefunds(a.cid) end
    end)
end)

-- puts the rest of a jumped bail back on the citizen
function Legal.reimpose(row)
    local secs = math.max(60, tonumber(row.remaining_seconds) or 0)
    local cid = tostring(row.citizen_identity)
    local active = DB.one("SELECT id FROM mdt_prison_records WHERE charidentifier = ? AND status = 'active' ORDER BY id DESC LIMIT 1", { cid })
    if active then
        Prison.adjust(active.id, secs, 'extended', math.ceil(secs / 60))
        return
    end
    local n = 0
    if row.prison_record_id then
        n = DB.upd([[UPDATE mdt_prison_records SET status = 'active', jail_time = ?, reason = ?, imprisoned_by = 'Court', imprisoned_at = NOW()
            WHERE id = ?]], { secs, L('bail_jumped_reason'), row.prison_record_id })
    end
    if n == 0 then
        DB.ins([[INSERT INTO mdt_prison_records (player_name, charidentifier, jail_time, sentence_minutes, imprisoned_by, fine_amount, reason, is_bounty_claim, status)
            VALUES (?, ?, ?, ?, 'Court', 0, ?, 0, 'active')]], { row.citizen_name or '', cid, secs, math.ceil(secs / 60), L('bail_jumped_reason') })
    end
    local src = MDT.findByCid(cid)
    if src then Prison.resume(src) end
end

MDT.rpc('getBail', { perm = 'viewbail', staff = true, deny = { bail = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(actor, p)
    if not toolOn('bail') then return { bail = {}, currentPage = 1, totalPages = 1, totalRecords = 0, canApprove = false } end
    local rows, page, pages, total = listQuery('mdt_bail', p, "(status = 'active') DESC,")
    return { bail = rows, currentPage = page, totalPages = pages, totalRecords = total, canApprove = canRule(actor, 'approvebail') }
end)

MDT.rpc('lookupBailPrisoner', { perm = 'requestbail', staff = true, deny = { found = false } }, function(_, p)
    if not toolOn('bail') then return { found = false } end
    local cid = MDT.str(p.citizenIdentity, 50)
    local info = Prison.infoByCid(cid)
    if not info then return { found = false, citizenid = cid } end
    local open = DB.val("SELECT id FROM mdt_bail WHERE citizen_identity = ? AND status IN ('pending', 'processing', 'active') LIMIT 1", { cid })
    return { found = true, citizenid = cid, name = MDT.charName(cid) or info.playerName, prisonRecordId = info.recordId,
        remainingSeconds = info.secondsLeft, remainingMinutes = info.minutesLeft, alreadyHasBail = open ~= nil }
end)

MDT.rpc('requestBail', { perm = 'requestbail', staff = true, duty = true }, function(actor, p)
    if not toolOn('bail') then return { success = false, message = L('bail_disabled') } end
    local cid = MDT.str(p.citizenIdentity, 50)
    local amount = MDT.int(p.amount, 0, nil, nil)
    if not amount or tonumber(p.amount) ~= amount then return { success = false, message = L('bail_bad_amount') } end
    if amount < BAIL.minAmount or (BAIL.maxAmount > 0 and amount > BAIL.maxAmount) then
        return { success = false, message = L('bail_amount_range', BAIL.minAmount, BAIL.maxAmount) }
    end
    local info = Prison.infoByCid(cid)
    if not info then return { success = false, message = L('bail_not_jailed') } end
    -- a pending petition for an earlier sentence can never be granted: close it
    DB.upd("UPDATE mdt_bail SET status = 'denied', reviewed_at = NOW() WHERE citizen_identity = ? AND status = 'pending' AND (prison_record_id IS NULL OR prison_record_id <> ?)", { cid, info.recordId })
    if DB.val("SELECT id FROM mdt_bail WHERE citizen_identity = ? AND status IN ('pending', 'processing', 'active') LIMIT 1", { cid }) then
        return { success = false, message = L('bail_already_open') }
    end
    local name = MDT.charName(cid) or MDT.str(p.citizenName, 100)
    local id = DB.ins([[INSERT INTO mdt_bail (prison_record_id, citizen_identity, citizen_name, amount, reason, status, remaining_seconds, paid,
        requested_by_citizenid, requested_by_name) VALUES (?, ?, ?, ?, ?, 'pending', ?, 0, ?, ?)]],
        { info.recordId, cid, name, amount, MDT.str(p.reason, 1000, true), info.secondsLeft, actor.cid, actor.name })
    MDT.audit(actor, 'bail_requested', cid, name, ('$%d'):format(amount))
    pushAll('updateBail')
    return { success = true, id = id, action = 'requested', message = L('bail_requested') }
end)

MDT.rpc('approveBail', { perm = 'approvebail', staff = true, duty = true }, function(actor, p)
    if not toolOn('bail') then return { success = false, message = L('bail_disabled') } end
    if not canRule(actor, 'approvebail') then return { success = false, message = L('bail_no_judge') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local row = id and DB.one('SELECT * FROM mdt_bail WHERE id = ?', { id })
    if not row or row.status ~= 'pending' then return { success = false, message = L('bail_not_pending') } end
    if tostring(row.requested_by_citizenid) == actor.cid or tostring(row.citizen_identity) == actor.cid then return { success = false, message = L('bail_self_rule') } end
    if DB.upd("UPDATE mdt_bail SET status = 'processing', reviewed_at = NOW() WHERE id = ? AND status = 'pending'", { id }) == 0 then
        return { success = false, message = L('bail_not_pending') }
    end
    local function back(msg)
        DB.upd("UPDATE mdt_bail SET status = 'pending' WHERE id = ? AND status = 'processing'", { id })
        return { success = false, message = msg }
    end
    local cid = tostring(row.citizen_identity)
    local info = Prison.infoByCid(cid)
    -- only the sentence the bail was filed for
    if not info or tonumber(row.prison_record_id) ~= tonumber(info.recordId) then return back(L('bail_not_jailed')) end
    local amount = tonumber(row.amount) or 0
    local paid = false
    local src = MDT.findByCid(cid)
    -- a refund still owed on this row (an earlier approval that failed) is money already
    -- held: it is used again rather than charging twice and losing the refund
    if amount > 0 and tonumber(row.paid) == 3 and DB.upd('UPDATE mdt_bail SET paid = 1 WHERE id = ? AND paid = 3', { id }) == 1 then
        paid = true
    elseif BAIL.clientPays and amount > 0 then
        local ch = src and MDT.char(src)
        if not ch then return back(L('bail_citizen_offline')) end
        if (tonumber(ch.money) or 0) < amount then return back(L('bail_cannot_pay')) end
        ch.removeCurrency(0, amount)
        DB.upd('UPDATE mdt_bail SET paid = 1 WHERE id = ?', { id })
        if BAIL.intoLedger then Ledger.credit(POLICE_JOB, amount, 'bail', actor.name, 'Bail #' .. id) end
        paid = true
    end
    local ok = Prison.releaseRecord(info.recordId, 'forced')
    if not ok then
        if paid then
            -- owed back through the one refund path (now if they are loaded, else sweep/login)
            DB.upd('UPDATE mdt_bail SET paid = 3 WHERE id = ? AND paid = 1', { id })
        end
        local reply = back(L('release_failed'))
        if paid then Legal.payRefunds(cid) end
        return reply
    end
    DB.upd([[UPDATE mdt_bail SET status = 'active', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(), review_notes = ?,
        remaining_seconds = ?, court_due = DATE_ADD(NOW(), INTERVAL ? HOUR) WHERE id = ?]],
        { actor.cid, actor.name, MDT.str(p.notes, 1000, true), info.secondsLeft, BAIL.courtHours, id })
    if src then MDT.notify(src, L('bail_granted', BAIL.courtHours), 8000) end
    MDT.audit(actor, 'bail_approved', cid, row.citizen_name, ('$%d, %d s remaining'):format(amount, info.secondsLeft))
    pushAll('updateBail')
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return { success = true, id = id, action = 'approved', message = L('bail_approved') }
end)

MDT.rpc('denyBail', { perm = 'approvebail', staff = true, duty = true }, function(actor, p)
    if not toolOn('bail') then return { success = false, message = L('bail_disabled') } end
    if not canRule(actor, 'approvebail') then return { success = false, message = L('bail_no_judge') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local row = id and DB.one('SELECT id, citizen_identity, citizen_name, requested_by_citizenid FROM mdt_bail WHERE id = ?', { id })
    if not row then return { success = false, message = L('bail_not_pending') } end
    if tostring(row.requested_by_citizenid) == actor.cid or tostring(row.citizen_identity) == actor.cid then return { success = false, message = L('bail_self_rule') } end
    local n = DB.upd([[UPDATE mdt_bail SET status = 'denied', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(), review_notes = ?
        WHERE id = ? AND status = 'pending']], { actor.cid, actor.name, MDT.str(p.notes, 1000, true), id })
    if n == 0 then return { success = false, message = L('bail_not_pending') } end
    MDT.audit(actor, 'bail_denied', row.citizen_identity, row.citizen_name, MDT.str(p.notes, 200))
    pushAll('updateBail')
    return { success = true, id = id, action = 'denied', message = L('bail_denied') }
end)

local function resolveBail(actor, row, outcome, auto)
    local n = DB.upd("UPDATE mdt_bail SET status = ?, resolved_at = NOW(), review_notes = IF(?, CONCAT(COALESCE(review_notes, ''), ' [automatic]'), review_notes) WHERE id = ? AND status = 'active'",
        { outcome, auto and 1 or 0, row.id })
    if n == 0 then return false end
    if outcome == 'appeared' then
        if BAIL.refundOnAppear and (row.paid == true or tonumber(row.paid) == 1) then
            DB.upd('UPDATE mdt_bail SET paid = 3 WHERE id = ?', { row.id })
            Legal.payRefunds(tostring(row.citizen_identity))
        end
    elseif outcome == 'skipped' and BAIL.skipReimposes then
        Legal.reimpose(row)
    end
    MDT.audit(actor, outcome == 'appeared' and 'bail_appeared' or 'bail_skipped', row.citizen_identity, row.citizen_name, auto and 'automatic forfeit' or '')
    return true
end

MDT.rpc('resolveBail', { perm = 'approvebail', staff = true, duty = true }, function(actor, p)
    if not toolOn('bail') then return { success = false, message = L('bail_disabled') } end
    if not canRule(actor, 'approvebail') then return { success = false, message = L('bail_no_judge') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local outcome = MDT.enum(p.outcome, { 'appeared', 'skipped' }, nil)
    if not id or not outcome then return { success = false, message = L('bail_bad_outcome') } end
    local row = DB.one("SELECT * FROM mdt_bail WHERE id = ? AND status = 'active'", { id })
    if row and tostring(row.citizen_identity) == actor.cid then return { success = false, message = L('bail_self_rule') } end
    if not row or not resolveBail(actor, row, outcome, false) then return { success = false, message = L('bail_not_active') } end
    pushAll('updateBail')
    return { success = true, id = id, action = outcome, message = L('bail_resolved_' .. outcome) }
end)

function Legal.sweepBail()
    if not toolOn('bail') then return end
    DB.upd(("UPDATE mdt_bail SET status = 'pending', paid = IF(paid = 1, 3, paid) WHERE status = 'processing' AND reviewed_at < DATE_SUB(NOW(), INTERVAL %d MINUTE)")
        :format(math.floor(BAIL.processingTimeoutMinutes)))
    if BAIL.autoForfeit then
        local rows = DB.q("SELECT * FROM mdt_bail WHERE status = 'active' AND court_due IS NOT NULL AND court_due < NOW()")
        for _, r in ipairs(rows) do resolveBail(nil, r, 'skipped', true) end
        if #rows > 0 then pushAll('updateBail') end
    end
    Legal.payOnlineRefunds()
end

---------------------------------------------------------------------------
-- Appeals
---------------------------------------------------------------------------
MDT.rpc('getAppeals', { perm = 'viewappeals', staff = true, deny = { appeals = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(actor, p)
    if not toolOn('appeals') then return { appeals = {}, currentPage = 1, totalPages = 1, totalRecords = 0, canApprove = false } end
    local rows, page, pages, total = listQuery('mdt_appeals', p)
    return { appeals = rows, currentPage = page, totalPages = pages, totalRecords = total, canApprove = canRule(actor, 'approveappeal') }
end)

MDT.rpc('lookupAppealPrisoner', { perm = 'requestappeal', staff = true, deny = { found = false } }, function(_, p)
    if not toolOn('appeals') then return { found = false } end
    local cid = MDT.str(p.citizenIdentity, 50)
    local info = Prison.infoByCid(cid)
    if not info then return { found = false, citizenid = cid } end
    local pending = DB.val("SELECT id FROM mdt_appeals WHERE citizen_identity = ? AND status = 'pending' LIMIT 1", { cid })
    return { found = true, citizenid = cid, name = MDT.charName(cid) or info.playerName, remainingMinutes = info.minutesLeft, alreadyPending = pending ~= nil }
end)

MDT.rpc('requestAppeal', { perm = 'requestappeal', staff = true, duty = true }, function(actor, p)
    if not toolOn('appeals') then return { success = false, message = L('appeal_disabled') } end
    local cid = MDT.str(p.citizenIdentity, 50)
    local commute = MDT.bool(p.commute)
    local mins = MDT.int(p.reductionMinutes, 0, Config.Jail.maxMinutes, 0)
    if not commute and mins <= 0 then return { success = false, message = L('appeal_need_reduction') } end
    local info = Prison.infoByCid(cid)
    if not info then return { success = false, message = L('appeal_not_jailed') } end
    -- a pending appeal against an earlier sentence can never be granted: close it
    DB.upd("UPDATE mdt_appeals SET status = 'denied', reviewed_at = NOW() WHERE citizen_identity = ? AND status = 'pending' AND (prison_record_id IS NULL OR prison_record_id <> ?)", { cid, info.recordId })
    if DB.val("SELECT id FROM mdt_appeals WHERE citizen_identity = ? AND status = 'pending' LIMIT 1", { cid }) then
        return { success = false, message = L('appeal_already_pending') }
    end
    local name = MDT.charName(cid) or MDT.str(p.citizenName, 100)
    local id = DB.ins([[INSERT INTO mdt_appeals (prison_record_id, citizen_identity, citizen_name, reduction_minutes, commute, reason, status,
        requested_by_citizenid, requested_by_name) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?)]],
        { info.recordId, cid, name, commute and 0 or mins, commute and 1 or 0, MDT.str(p.reason, 1000, true), actor.cid, actor.name })
    MDT.audit(actor, 'appeal_requested', cid, name, commute and 'commute' or ('-%d minutes'):format(mins))
    pushAll('updateAppeals')
    return { success = true, id = id, action = 'requested', message = L('appeal_requested') }
end)

MDT.rpc('approveAppeal', { perm = 'approveappeal', staff = true, duty = true }, function(actor, p)
    if not toolOn('appeals') then return { success = false, message = L('appeal_disabled') } end
    if not canRule(actor, 'approveappeal') then return { success = false, message = L('appeal_no_judge') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local row = id and DB.one("SELECT * FROM mdt_appeals WHERE id = ? AND status = 'pending'", { id })
    if not row then return { success = false, message = L('appeal_not_pending') } end
    if tostring(row.requested_by_citizenid) == actor.cid or tostring(row.citizen_identity) == actor.cid then return { success = false, message = L('appeal_self_rule') } end
    local cid = tostring(row.citizen_identity)
    local info = Prison.infoByCid(cid)
    -- only the sentence the appeal was filed for
    if not info or tonumber(row.prison_record_id) ~= tonumber(info.recordId) then return { success = false, message = L('appeal_not_jailed') } end
    if DB.upd([[UPDATE mdt_appeals SET status = 'approved', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(), review_notes = ?
        WHERE id = ? AND status = 'pending']], { actor.cid, actor.name, MDT.str(p.notes, 1000, true), id }) == 0 then
        return { success = false, message = L('appeal_not_pending') }
    end
    local reduce = tonumber(row.reduction_minutes) or 0
    local released = (row.commute == true or tonumber(row.commute) == 1) or reduce * 60 >= info.secondsLeft
    local reduced
    if released then
        reduced = info.minutesLeft
        if not Prison.releaseRecord(info.recordId, 'forced') then
            DB.upd("UPDATE mdt_appeals SET status = 'pending' WHERE id = ? AND status = 'approved'", { id })
            return { success = false, message = L('release_failed') }
        end
        local src = MDT.findByCid(cid)
        if src then MDT.notify(src, L('appeal_commuted'), 8000) end
    else
        reduced = reduce
        Prison.adjust(info.recordId, -reduce * 60, 'appeal', reduce)
    end
    DB.upd('UPDATE mdt_appeals SET minutes_reduced = ? WHERE id = ?', { reduced, id })
    MDT.audit(actor, 'appeal_approved', cid, row.citizen_name, released and 'released' or ('-%d minutes'):format(reduced))
    pushAll('updateAppeals')
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return { success = true, id = id, action = 'approved', minutesReduced = reduced, released = released, message = L('appeal_approved') }
end)

MDT.rpc('denyAppeal', { perm = 'approveappeal', staff = true, duty = true }, function(actor, p)
    if not toolOn('appeals') then return { success = false, message = L('appeal_disabled') } end
    if not canRule(actor, 'approveappeal') then return { success = false, message = L('appeal_no_judge') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local row = id and DB.one('SELECT id, citizen_identity, citizen_name, requested_by_citizenid FROM mdt_appeals WHERE id = ?', { id })
    if not row then return { success = false, message = L('appeal_not_pending') } end
    if tostring(row.requested_by_citizenid) == actor.cid or tostring(row.citizen_identity) == actor.cid then return { success = false, message = L('appeal_self_rule') } end
    local n = DB.upd([[UPDATE mdt_appeals SET status = 'denied', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(), review_notes = ?
        WHERE id = ? AND status = 'pending']], { actor.cid, actor.name, MDT.str(p.notes, 1000, true), id })
    if n == 0 then return { success = false, message = L('appeal_not_pending') } end
    MDT.audit(actor, 'appeal_denied', row.citizen_identity, row.citizen_name, MDT.str(p.notes, 200))
    pushAll('updateAppeals')
    return { success = true, id = id, action = 'denied', message = L('appeal_denied') }
end)

---------------------------------------------------------------------------
-- Expungements
---------------------------------------------------------------------------
local function hasRecord(cid)
    local n = tonumber(DB.val([[SELECT
        (SELECT COUNT(*) FROM mdt_criminals WHERE identity = ?) +
        (SELECT COUNT(*) FROM mdt_arrests WHERE citizen_identity = ?) +
        (SELECT COUNT(*) FROM mdt_reports_warrants WHERE citizenid = ?) +
        (SELECT COUNT(*) FROM mdt_reports_charges WHERE citizenid = ?) +
        (SELECT COUNT(*) FROM mdt_prison_records WHERE charidentifier = ?) AS n]], { cid, cid, cid, cid, cid })) or 0
    return n > 0
end

-- the five tables, a few safe columns each
local previewTables = {
    { key = 'mdt_criminals', sql = 'SELECT id, status, registered_by, registered_at FROM mdt_criminals WHERE identity = ?' },
    { key = 'mdt_arrests', sql = 'SELECT id, charges, final_fine, final_months, lawman_name, created_at FROM mdt_arrests WHERE citizen_identity = ?' },
    { key = 'mdt_reports_warrants', sql = 'SELECT id, charges, status, created_at FROM mdt_reports_warrants WHERE citizenid = ?' },
    { key = 'mdt_reports_charges', sql = 'SELECT id, reportid, charge_label, count, jail_time, fine FROM mdt_reports_charges WHERE citizenid = ?' },
    { key = 'mdt_prison_records', sql = 'SELECT id, sentence_minutes, status, imprisoned_by, imprisoned_at, reason FROM mdt_prison_records WHERE charidentifier = ?' },
}

MDT.rpc('getExpungements', { perm = 'viewexpungements', staff = true, deny = { expungements = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(_, p)
    if not toolOn('expungements') then return { expungements = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } end
    local rows, page, pages, total = listQuery('mdt_expungements', p)
    for _, r in ipairs(rows) do r.snapshot = nil end
    return { expungements = rows, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('getExpungementSnapshot', { perm = 'viewexpungements', staff = true }, function(_, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local r = id and DB.one([[SELECT id, citizen_identity, citizen_name, reason, requested_by_name, reviewed_by_name, review_notes, reviewed_at,
        records_cleared, snapshot FROM mdt_expungements WHERE id = ? AND status = 'approved']], { id })
    if not r then return { success = false, message = L('exp_not_found') } end
    return { success = true, snapshot = { id = r.id, citizenIdentity = r.citizen_identity, citizenName = r.citizen_name,
        reason = r.reason, requestedBy = r.requested_by_name, reviewedBy = r.reviewed_by_name, reviewNotes = r.review_notes,
        reviewedAt = r.reviewed_at, recordsCleared = r.records_cleared, snapshot = MDT.jdec(r.snapshot, {}) } }
end)

-- only a pending request, only to someone who may rule on it or who filed it
MDT.rpc('getExpungementPreview', { perm = 'viewexpungements', staff = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local r = id and DB.one("SELECT id, citizen_identity, citizen_name, requested_by_citizenid FROM mdt_expungements WHERE id = ? AND status = 'pending'", { id })
    if not r then return { success = false, message = L('exp_not_found') } end
    if not MDT.can(actor, 'approveexpungement') and tostring(r.requested_by_citizenid) ~= actor.cid then
        return { success = false, message = L('no_permission') }
    end
    local cap, out, count, capped = 100, {}, 0, false
    for _, t in ipairs(previewTables) do
        local rows = DB.q(t.sql .. ' LIMIT ' .. (cap + 1), { r.citizen_identity })
        if #rows > cap then capped = true; rows[#rows] = nil end
        local total = tonumber(DB.val('SELECT COUNT(*) FROM (' .. t.sql .. ') x', { r.citizen_identity })) or #rows
        count = count + total
        out[t.key] = { count = total, rows = rows }
    end
    return { success = true, snapshot = { id = r.id, citizenIdentity = r.citizen_identity, citizenName = r.citizen_name,
        recordsCleared = count, capped = capped, rowCap = cap, snapshot = out, isPreview = true } }
end)

MDT.rpc('lookupExpungementCitizen', { perm = 'requestexpungement', staff = true, deny = { found = false } }, function(_, p)
    local cid = MDT.str(p.citizenIdentity, 50)
    local name, row = MDT.charName(cid)
    if not name then return { found = false, citizenid = cid } end
    return { found = true, citizenid = cid, firstname = row.firstname, lastname = row.lastname, name = name, hasRecord = hasRecord(cid) }
end)

MDT.rpc('requestExpungement', { perm = 'requestexpungement', staff = true, duty = true }, function(actor, p)
    if not toolOn('expungements') then return { success = false, message = L('exp_disabled') } end
    local cid = MDT.str(p.citizenIdentity, 50)
    local name = MDT.charName(cid)
    if not name then return { success = false, message = L('exp_not_found') } end
    if not hasRecord(cid) then return { success = false, message = L('exp_no_record') } end
    if DB.val("SELECT id FROM mdt_expungements WHERE citizen_identity = ? AND status = 'pending' LIMIT 1", { cid }) then
        return { success = false, message = L('exp_already_pending') }
    end
    local id = DB.ins([[INSERT INTO mdt_expungements (citizen_identity, citizen_name, reason, requested_by_citizenid, requested_by_name, status)
        VALUES (?, ?, ?, ?, ?, 'pending')]], { cid, name, MDT.str(p.reason, 2000, true), actor.cid, actor.name })
    MDT.audit(actor, 'expungement_requested', cid, name, '')
    pushAll('updateExpungements')
    return { success = true, id = id, message = L('exp_requested') }
end)

MDT.rpc('approveExpungement', { perm = 'approveexpungement', law = true, duty = true }, function(actor, p)
    if not toolOn('expungements') then return { success = false, message = L('exp_disabled') } end
    local id = MDT.int(p.id, 1, nil, nil)
    local r = id and DB.one("SELECT * FROM mdt_expungements WHERE id = ? AND status = 'pending'", { id })
    if not r then return { success = false, message = L('exp_not_found') } end
    local self = tostring(r.requested_by_citizenid) == actor.cid
    if self and not Config.AllowSelfExpungementApproval then return { success = false, message = L('exp_self') } end
    local cid = tostring(r.citizen_identity)
    -- never one's own record, whatever the config says
    if cid == actor.cid then return { success = false, message = L('exp_self') } end
    if Prison.infoByCid(cid) then return { success = false, message = L('exp_serving') } end

    -- summary snapshot
    local snap = {
        profiles = tonumber(DB.val('SELECT COUNT(*) FROM mdt_criminals WHERE identity = ?', { cid })) or 0,
        arrests = tonumber(DB.val('SELECT COUNT(*) FROM mdt_arrests WHERE citizen_identity = ?', { cid })) or 0,
        prisonTerms = tonumber(DB.val('SELECT COUNT(*) FROM mdt_prison_records WHERE charidentifier = ?', { cid })) or 0,
        bounties = tonumber(DB.val('SELECT COUNT(*) FROM mdt_reports_warrants WHERE citizenid = ?', { cid })) or 0,
        charges = tonumber(DB.val('SELECT COUNT(*) FROM mdt_reports_charges WHERE citizenid = ?', { cid })) or 0,
        totalFines = tonumber(DB.val('SELECT COALESCE(SUM(final_fine), 0) FROM mdt_arrests WHERE citizen_identity = ?', { cid })) or 0,
        totalMonths = tonumber(DB.val('SELECT COALESCE(SUM(final_months), 0) FROM mdt_arrests WHERE citizen_identity = ?', { cid })) or 0,
        chargeNames = {},
    }
    local seen = {}
    for _, a in ipairs(DB.q('SELECT charges FROM mdt_arrests WHERE citizen_identity = ?', { cid })) do
        for _, c in ipairs(MDT.jdec(a.charges, {})) do
            local label = tostring(c.label or c.code or '')
            if label ~= '' and not seen[label] and #snap.chargeNames < 40 then seen[label] = true; snap.chargeNames[#snap.chargeNames + 1] = label end
        end
    end
    local cleared = snap.profiles + snap.arrests + snap.prisonTerms + snap.bounties + snap.charges

    if DB.upd([[UPDATE mdt_expungements SET status = 'approved', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(),
        review_notes = ?, snapshot = ?, records_cleared = ? WHERE id = ? AND status = 'pending']],
        { actor.cid, actor.name, MDT.str(p.notes, 1000, true), MDT.jenc(snap), cleared, id }) == 0 then
        return { success = false, message = L('exp_nothing_cleared') }
    end

    DB.q('DELETE FROM mdt_criminals WHERE identity = ?', { cid })
    DB.q('DELETE FROM mdt_arrests WHERE citizen_identity = ?', { cid })
    DB.q('DELETE FROM mdt_reports_warrants WHERE citizenid = ?', { cid })
    DB.q('DELETE FROM mdt_reports_charges WHERE citizenid = ?', { cid })
    DB.q("DELETE FROM mdt_prison_records WHERE charidentifier = ? AND status <> 'active'", { cid })
    -- reports where they are the only person involved, then their other involvement rows
    DB.q([[DELETE r FROM mdt_reports r WHERE EXISTS (SELECT 1 FROM mdt_reports_involved i WHERE i.reportid = r.id AND i.citizenid = ?)
        AND NOT EXISTS (SELECT 1 FROM mdt_reports_involved j WHERE j.reportid = r.id AND (j.citizenid IS NULL OR j.citizenid <> ?))]], { cid, cid })
    DB.q('DELETE FROM mdt_reports_involved WHERE citizenid = ?', { cid })
    -- closed cases where they are the only person involved; their rows on cases that are not live
    DB.q([[DELETE c FROM mdt_cases c WHERE c.status = 'closed'
        AND EXISTS (SELECT 1 FROM mdt_cases_involved i WHERE i.caseid = c.id AND i.citizenid = ?)
        AND NOT EXISTS (SELECT 1 FROM mdt_cases_involved j WHERE j.caseid = c.id AND (j.citizenid IS NULL OR j.citizenid <> ?))]], { cid, cid })
    DB.q([[DELETE i FROM mdt_cases_involved i JOIN mdt_cases c ON c.id = i.caseid
        WHERE i.citizenid = ? AND c.status NOT IN ('open', 'active')]], { cid })
    DB.q('DELETE FROM mdt_most_wanted WHERE citizen_identity = ?', { cid })
    DB.q('DELETE FROM mdt_bolos WHERE po_number = ?', { cid })

    if self then print(('^3[pup-mdt]^7 SELF-APPROVED expungement #%d by %s (%s)'):format(id, actor.name, actor.cid)) end
    MDT.audit(actor, 'expungement_approved', cid, r.citizen_name, (self and 'SELF-' or '') .. ('approved, %d records cleared'):format(cleared))
    Records.broadcast()
    pushAll('updateExpungements')
    return { success = true, id = id, action = 'approved', recordsCleared = cleared, message = L('exp_approved', cleared) }
end)

MDT.rpc('denyExpungement', { perm = 'approveexpungement', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local r = id and DB.one('SELECT id, citizen_identity, citizen_name FROM mdt_expungements WHERE id = ?', { id })
    if not r then return { success = false, message = L('exp_not_found') } end
    local n = DB.upd([[UPDATE mdt_expungements SET status = 'denied', reviewed_by_citizenid = ?, reviewed_by_name = ?, reviewed_at = NOW(), review_notes = ?
        WHERE id = ? AND status = 'pending']], { actor.cid, actor.name, MDT.str(p.notes, 1000, true), id })
    if n == 0 then return { success = false, message = L('exp_not_found') } end
    MDT.audit(actor, 'expungement_denied', r.citizen_identity, r.citizen_name, MDT.str(p.notes, 200))
    pushAll('updateExpungements')
    return { success = true, id = id, action = 'denied', message = L('exp_denied') }
end)
