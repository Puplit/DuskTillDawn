-- pup-mdt | public records kiosk and citizen tips (any player, at a records office)

Public = { last = {}, tipCooldown = {} }

local function atOffice(src)
    local c = MDT.coords(src)
    if not c then return false end
    for _, spot in ipairs(Config.PublicRecords.spots) do
        if MDT.dist(c, spot) <= Config.PublicRecords.serverDistance then return true end
    end
    return false
end

-- presence and a light rate limit for every kiosk request
local function kiosk(actor)
    if not Config.PublicRecords.enabled then return false, L('cl_records_unavailable') end
    if not atOffice(actor.src) then return false, L('pr_not_at_office') end
    local now = GetGameTimer()
    if Public.last[actor.src] and now - Public.last[actor.src] < Config.PublicRecords.rateLimitMs then
        return false, L('rate_limited')
    end
    Public.last[actor.src] = now
    return true
end

AddEventHandler('playerDropped', function() Public.last[source] = nil end)

-- the record a citizen may see (never the lawmen's notes)
local function publicRecord(cid)
    local name, ch = MDT.charName(cid)
    if not name then return nil end
    local m = DB.one('SELECT status, photo_url FROM mdt_criminals WHERE identity = ?', { cid })
    local arrests = DB.q('SELECT id, charges, final_fine, final_months, lawman_name, created_at FROM mdt_arrests WHERE citizen_identity = ? ORDER BY created_at DESC LIMIT 50', { cid })
    for _, a in ipairs(arrests) do a.charges = MDT.jdec(a.charges, {}) end
    local terms = DB.q('SELECT id, sentence_minutes, status, imprisoned_by, imprisoned_at, reason, fine_amount FROM mdt_prison_records WHERE charidentifier = ? ORDER BY imprisoned_at DESC LIMIT 50', { cid })
    -- a bounty tied to another citizen id is never shown here, even under the same name
    local bounties = DB.q([[SELECT id, charges, bounty_fine, bounty_jailtime, bounty_reward, expiry_date, image_url, issued_by, created_at
        FROM mdt_reports_warrants WHERE status = 'active' AND (citizenid = ? OR ((citizenid IS NULL OR citizenid = '') AND citizen_name = ?))
        ORDER BY created_at DESC LIMIT 10]], { cid, name })
    local totals = DB.one('SELECT COUNT(*) AS n, COALESCE(SUM(IF(fine_applied = 1, final_fine, 0)), 0) AS fines FROM mdt_arrests WHERE citizen_identity = ?', { cid }) or {}
    local status = (m and m.status) or 'clear'
    if #bounties > 0 then status = 'wanted' end
    return {
        citizenid = cid, name = name, firstname = ch.firstname, lastname = ch.lastname,
        status = status, photoUrl = m and m.photo_url or '',
        arrests = arrests, prisonTerms = terms, bounties = bounties,
        totalFines = tonumber(totals.fines) or 0, totalArrests = tonumber(totals.n) or 0,
        isWanted = status == 'wanted',
    }
end

MDT.rpc('getCivilianRecord', {}, function(actor)
    local ok, msg = kiosk(actor)
    if not ok then return { ok = false, message = msg } end
    local rec = publicRecord(actor.cid)
    if not rec then return { ok = false, message = L('cl_no_record') } end
    return {
        ok = true, recordData = rec,
        tips = { enabled = Config.Tips.enabled, allowAnonymous = Config.Tips.allowAnonymous, maxLength = Config.Tips.maxLength },
        penalCode = { enabled = Config.PublicRecords.showPenalCode },
    }
end)

MDT.rpc('civSearchPerson', { deny = { results = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(actor, p)
    local ok, msg = kiosk(actor)
    if not ok then return { results = {}, currentPage = 1, totalPages = 1, totalRecords = 0, message = msg } end
    local q = MDT.str(p.query, 60)
    -- an empty query lists every citizen (the tab opening); one letter is too broad to search
    if #q == 1 then return { results = {}, currentPage = 1, totalPages = 1, totalRecords = 0, message = L('pr_query_short') } end
    local per = Config.PublicRecords.searchPerPage
    local like = MDT.like(q)
    local where = "(LOWER(CONCAT(c.firstname, ' ', c.lastname)) LIKE ? OR CAST(c.charidentifier AS CHAR) = ?)"
    local total = tonumber(DB.val('SELECT COUNT(*) FROM characters c WHERE ' .. where, { like, q })) or 0
    local page, offset, pages = MDT.paging(p.page, per, total)
    local rows = DB.q(([[SELECT c.charidentifier, c.firstname, c.lastname, m.status, m.photo_url,
            (SELECT COALESCE(SUM(IF(a.fine_applied = 1, a.final_fine, 0)), 0) FROM mdt_arrests a WHERE a.citizen_identity = CAST(c.charidentifier AS CHAR)) AS fines,
            (SELECT COUNT(*) FROM mdt_reports_warrants w WHERE w.citizenid = CAST(c.charidentifier AS CHAR) AND w.status = 'active') AS bounties
        FROM characters c LEFT JOIN mdt_criminals m ON m.identity = CAST(c.charidentifier AS CHAR)
        WHERE %s ORDER BY c.lastname, c.firstname LIMIT ? OFFSET ?]]):format(where), { like, q, per, offset })
    local out = {}
    for _, r in ipairs(rows) do
        local b = tonumber(r.bounties) or 0
        out[#out + 1] = {
            identity = tostring(r.charidentifier), firstname = r.firstname, lastname = r.lastname,
            name = MDT.str((r.firstname or '') .. ' ' .. (r.lastname or ''), 100),
            status = b > 0 and 'wanted' or (r.status or 'clear'), photoUrl = r.photo_url or '',
            totalFines = tonumber(r.fines) or 0, activeBounties = b,
        }
    end
    return { results = out, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('civViewPerson', { deny = { data = false } }, function(actor, p)
    local ok, msg = kiosk(actor)
    if not ok then return { data = false, message = msg } end
    local rec = publicRecord(MDT.str(p.identity, 50))
    return { data = rec or false }
end)

MDT.rpc('civGetPrisonRecords', { deny = { records = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(actor, p)
    local ok, msg = kiosk(actor)
    if not ok then return { records = {}, currentPage = 1, totalPages = 1, totalRecords = 0, message = msg } end
    local per = Config.PublicRecords.inmatesPerPage
    local total = tonumber(DB.val("SELECT COUNT(*) FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0")) or 0
    local page, offset, pages = MDT.paging(p.page, per, total)
    local rows = DB.q("SELECT id, player_name, charidentifier, jail_time, sentence_minutes, reason, imprisoned_at FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0 ORDER BY imprisoned_at DESC LIMIT ? OFFSET ?", { per, offset })
    local out = {}
    for _, r in ipairs(rows) do
        local secs = Prison.liveSeconds(r.id, r.jail_time)
        out[#out + 1] = { id = r.id, name = r.player_name, sentenceMinutes = r.sentence_minutes, minutesLeft = math.ceil(secs / 60), reason = r.reason, imprisonedAt = r.imprisoned_at }
    end
    return { records = out, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('civGetBountyBoard', { deny = { bounties = {}, currentPage = 1, totalPages = 1, totalRecords = 0 } }, function(actor, p)
    local ok, msg = kiosk(actor)
    if not ok then return { bounties = {}, currentPage = 1, totalPages = 1, totalRecords = 0, message = msg } end
    local per = Config.PublicRecords.bountiesPerPage
    local search = MDT.str(p.search, 60)
    local where, params = "status = 'active'", {}
    if search ~= '' then
        where = where .. ' AND (LOWER(citizen_name) LIKE ? OR LOWER(charges) LIKE ?)'
        params = { MDT.like(search), MDT.like(search) }
    end
    local total = tonumber(DB.val('SELECT COUNT(*) FROM mdt_reports_warrants WHERE ' .. where, params)) or 0
    local page, offset, pages = MDT.paging(p.page, per, total)
    params[#params + 1] = per; params[#params + 1] = offset
    local rows = DB.q('SELECT id, citizen_name, charges, bounty_fine, bounty_jailtime, bounty_reward, image_url, expiry_date, created_at FROM mdt_reports_warrants WHERE '
        .. where .. ' ORDER BY created_at DESC LIMIT ? OFFSET ?', params)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = r.id, name = r.citizen_name, charges = r.charges, fine = r.bounty_fine, jailtime = r.bounty_jailtime,
            reward = r.bounty_reward, image = r.image_url, expires = r.expiry_date, createdAt = r.created_at }
    end
    return { bounties = out, currentPage = page, totalPages = pages, totalRecords = total }
end)

MDT.rpc('civGetPenalCode', { deny = { fines = {} } }, function(actor)
    if not Config.PublicRecords.showPenalCode then return { fines = {} } end
    local ok, msg = kiosk(actor)
    if not ok then return { fines = {}, message = msg } end
    return { fines = Penal.all() }
end)

---------------------------------------------------------------------------
-- Tips
---------------------------------------------------------------------------
MDT.rpc('submitTip', {}, function(actor, p)
    if not Config.Tips.enabled then return { success = false, message = L('tip_disabled') } end
    if not atOffice(actor.src) then return { success = false, message = L('pr_not_at_office') } end
    local msg = MDT.str(p.message, Config.Tips.maxLength, true)
    if msg == '' then return { success = false, message = L('tip_empty') } end
    local last = Public.tipCooldown[actor.cid]
    if last and os.time() - last < Config.Tips.cooldownSeconds then
        return { success = false, message = L('tip_cooldown', Config.Tips.cooldownSeconds - (os.time() - last)) }
    end
    Public.tipCooldown[actor.cid] = os.time()
    local anon = Config.Tips.allowAnonymous and MDT.bool(p.anonymous)
    local location = PupMdtZones.nameFromCoords(MDT.coords(actor.src))
    local id = DB.ins("INSERT INTO mdt_tips (citizen_identity, citizen_name, anonymous, message, location, status) VALUES (NULLIF(?, ''), ?, ?, ?, ?, 'new')",
        { anon and '' or actor.cid, anon and 'Anonymous' or actor.name, anon and 1 or 0, msg, location })
    if Config.Tips.notifyLawmen then
        for _, s in ipairs(Duty.lawmen()) do MDT.notify(s, L('cl_new_tip', location), 6000) end
    end
    Duty.nuiLawmen({ action = 'newTip', tip = { id = id, citizen_name = anon and 'Anonymous' or actor.name, anonymous = anon, message = msg, location = location, status = 'new' } })
    if Config.Tips.discord then
        MDT.log('audit', 'Citizen tip', ('%s at %s:\n%s'):format(anon and 'Anonymous' or actor.name, location, msg), 'blue')
    end
    return { success = true, message = L('tip_submitted') }
end)

MDT.rpc('getTips', { perm = 'viewtips', law = true, deny = { tips = {} } }, function()
    local rows = DB.q("SELECT id, citizen_identity, citizen_name, anonymous, message, location, status, created_at FROM mdt_tips ORDER BY (status = 'new') DESC, created_at DESC LIMIT 100")
    return { tips = rows }
end)

MDT.rpc('markTipRead', { perm = 'viewtips', law = true, duty = true }, function(_, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not id then return { success = false } end
    local n = DB.upd("UPDATE mdt_tips SET status = 'read' WHERE id = ?", { id })
    return { success = n > 0 }
end)

MDT.rpc('deleteTip', { perm = 'deletetips', law = true, duty = true }, function(_, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not id then return { success = false } end
    local n = DB.upd('DELETE FROM mdt_tips WHERE id = ?', { id })
    return { success = n > 0 }
end)
