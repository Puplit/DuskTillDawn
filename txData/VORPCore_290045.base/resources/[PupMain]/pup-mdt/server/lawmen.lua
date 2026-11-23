-- pup-mdt | lawman profiles, roster, stats

Lawmen = { busy = {} }

local statColumns = {
    criminals_registered = true, arrests_made = true, fines_applied = true, evidences_collected = true,
}

function Lawmen.ensureStats(cid, playerId)
    DB.q('INSERT IGNORE INTO mdt_lawman_stats (player_id, citizen_id) VALUES (?, ?)', { playerId or 0, tostring(cid) })
end

function Lawmen.bumpStat(cid, stat, amount)
    if not cid or not statColumns[stat] then return end
    amount = MDT.int(amount, -1000, 1000, 1)
    Lawmen.ensureStats(cid, 0)
    DB.q(('UPDATE mdt_lawman_stats SET %s = GREATEST(0, %s + ?), last_updated = NOW() WHERE citizen_id = ?'):format(stat, stat), { amount, tostring(cid) })
end

exports('updateLawmanStats', function(cid, stat, amount) Lawmen.bumpStat(cid, stat, amount or 1) end)

-- job and grade of a citizen: live if online, else from the character table
function Lawmen.jobOf(cid)
    local src = MDT.findByCid(cid)
    if src then
        local a = MDT.player(src)
        if a then return a.job, a.grade, a.jobLabel, a end
    end
    local row = DB.one('SELECT job, jobgrade FROM characters WHERE charidentifier = ?', { tonumber(cid) or -1 })
    if not row then return nil end
    return row.job, tonumber(row.jobgrade) or 0, row.job, nil
end

-- reactivate, re-sync or create the profile of an online lawman
function Lawmen.ensureProfile(a)
    if not a or not a.isLaw then return end
    if Lawmen.busy[a.cid] then return end
    Lawmen.busy[a.cid] = true
    local ok, err = pcall(function()
        local rank, dept = Perms.rankName(a.job, a.grade), a.jobLabel
        local row = DB.one('SELECT id, is_active, `rank`, department FROM mdt_lawman_profiles WHERE citizen_id = ? ORDER BY is_active DESC, id DESC LIMIT 1', { a.cid })
        if row then
            if not (row.is_active == true or tonumber(row.is_active) == 1) or row.rank ~= rank or row.department ~= dept then
                DB.upd('UPDATE mdt_lawman_profiles SET is_active = 1, `rank` = ?, department = ?, player_id = ? WHERE id = ?', { rank, dept, a.src, row.id })
                Cache.clear('roster')
            end
        else
            for attempt = 1, 4 do
                local okIns = pcall(DB.ins, [[INSERT INTO mdt_lawman_profiles
                    (player_id, citizen_id, `rank`, department, region, trainings, description, is_active)
                    VALUES (?, ?, ?, ?, '', '[]', ?, 1)]], { a.src, a.cid, rank, dept, 'Automatically created profile' })
                if okIns then break end
                Wait(200 * attempt)
                if DB.val('SELECT id FROM mdt_lawman_profiles WHERE citizen_id = ? LIMIT 1', { a.cid }) then break end
            end
            Cache.clear('roster')
        end
        Lawmen.ensureStats(a.cid, a.src)
    end)
    Lawmen.busy[a.cid] = nil
    if not ok then print('^1[pup-mdt]^7 profile sync failed: ' .. tostring(err)) end
end

local function autoProfile(src, delay)
    if not Config.Profiles.autoCreate then return end
    SetTimeout(delay, function()
        local a = MDT.player(src)
        if a and a.isLaw then Lawmen.ensureProfile(a) end
    end)
end

AddEventHandler('vorp_core:Server:OnPlayerSpawned', function(src) autoProfile(tonumber(src) or source, 2500) end)
AddEventHandler('vorp_core:Server:OnCharacterLoaded', function(src) autoProfile(tonumber(src) or source, 2500) end)
AddEventHandler('vorp:SelectedCharacter', function(src) autoProfile(tonumber(src), 3000) end)
AddEventHandler('vorp:playerJobChange', function(src) autoProfile(tonumber(src), 1000) end)
AddEventHandler('vorp:playerJobGradeChange', function(src) autoProfile(tonumber(src), 1000) end)

-- every law character without an active profile gets one
function Lawmen.backfill()
    if not Config.Profiles.autoCreate then return end
    local jobs = Config.LawJobs
    if #jobs == 0 then return end
    local marks = string.rep('?,', #jobs):sub(1, -2)
    local rows = DB.q(([[SELECT c.charidentifier, c.job FROM characters c
        WHERE c.job IN (%s) AND NOT EXISTS (
            SELECT 1 FROM mdt_lawman_profiles p WHERE p.citizen_id = CAST(c.charidentifier AS CHAR) AND p.is_active = 1)]]):format(marks), jobs)
    for _, r in ipairs(rows) do
        local cid = tostring(r.charidentifier)
        DB.ins([[INSERT INTO mdt_lawman_profiles (player_id, citizen_id, `rank`, department, region, trainings, description, is_active)
            VALUES (0, ?, 'Deputy', ?, '', '[]', 'Backfilled from character table', 1)]], { cid, r.job })
        Lawmen.ensureStats(cid, 0)
    end
    if #rows > 0 then print(('^2[pup-mdt]^7 backfilled %d lawman profiles.'):format(#rows)) end
end

---------------------------------------------------------------------------
-- Formatting
---------------------------------------------------------------------------
local function fmtDuty(mins)
    mins = tonumber(mins) or 0
    return ('%dh %dm'):format(math.floor(mins / 60), mins % 60), ('%dd'):format(math.floor(mins / 1440))
end

local function badge(first, last)
    local i = ((first or ''):sub(1, 1) .. (last or ''):sub(1, 1)):upper()
    return i .. tostring(math.random(100, 999))
end

local function profileRow(r, online)
    local cid = tostring(r.citizen_id)
    local src = online[cid]
    local dutyTime, dutyDays = fmtDuty(r.duty_time_minutes)
    local grade = tonumber(r.jobgrade)
    return {
        id = r.id,
        playerId = src or r.player_id,
        citizenid = cid,
        name = (r.firstname and MDT.str(r.firstname .. ' ' .. (r.lastname or ''), 100)) or ('Lawman ' .. cid:sub(-4)),
        photo = r.photo_url or '',
        rank = r.rank,
        gradeNum = grade,
        callsign = r.callsign or '',
        department = r.department or '',
        region = r.region or '',
        trainings = MDT.jdec(r.trainings, {}),
        description = r.description or '',
        loaUntil = r.loa_until,
        isOnline = src ~= nil,
        onDuty = src ~= nil and Duty.isLawOnDuty(src),
        dutyRegion = src and Duty.region(src) or nil,
        createdAt = r.created_at,
        updatedAt = r.updated_at,
        lastDutyUpdate = r.last_duty_update,
        stats = {
            criminals = tonumber(r.criminals_registered) or 0,
            arrests = tonumber(r.arrests_made) or 0,
            fines = tonumber(r.fines_applied) or 0,
            evidences = tonumber(r.evidences_collected) or 0,
            dutyTime = dutyTime,
            dutyDays = dutyDays,
        },
    }
end

local profileSelect = [[
    SELECT p.*, c.firstname, c.lastname, c.jobgrade, s.criminals_registered, s.arrests_made, s.fines_applied, s.evidences_collected
    FROM mdt_lawman_profiles p
    LEFT JOIN characters c ON c.charidentifier = p.citizen_id
    LEFT JOIN mdt_lawman_stats s ON s.citizen_id = p.citizen_id
]]

---------------------------------------------------------------------------
-- Screen requests
---------------------------------------------------------------------------
MDT.rpc('getMyProfile', { perm = 'lawmen', law = true, deny = { profile = false } }, function(actor)
    local r = DB.one(profileSelect .. ' WHERE p.citizen_id = ? AND p.is_active = 1 ORDER BY p.id DESC LIMIT 1', { actor.cid })
    local identity = {
        exists = r ~= nil, citizenid = actor.cid, name = actor.name, firstname = actor.firstname, lastname = actor.lastname,
        rank = Perms.rankName(actor.job, actor.grade), gradeNum = actor.grade, department = actor.jobLabel,
        badge = badge(actor.firstname, actor.lastname),
    }
    if not r then return { profile = identity } end
    local row = profileRow(r, { [actor.cid] = actor.src })
    for k, v in pairs(identity) do if row[k] == nil or k == 'rank' or k == 'exists' or k == 'badge' then row[k] = v end end
    return { profile = row }
end)

MDT.rpc('getLawmen', { perm = 'viewlawmen', law = true, deny = {} }, function()
    local cached = Cache.get('roster')
    if cached then
        -- online state changes faster than the cache
        local online = MDT.onlineMap()
        for _, row in ipairs(cached) do
            local src = online[row.citizenid]
            row.isOnline = src ~= nil
            row.playerId = src or row.playerId
            row.onDuty = src ~= nil and Duty.isLawOnDuty(src)
            row.dutyRegion = src and Duty.region(src) or nil
        end
        return cached
    end
    local rows = DB.q(profileSelect .. [[ WHERE p.is_active = 1
        AND p.id = (SELECT MAX(p2.id) FROM mdt_lawman_profiles p2 WHERE p2.citizen_id = p.citizen_id AND p2.is_active = 1)
        ORDER BY c.jobgrade DESC, c.lastname ASC LIMIT 500]])
    local online = MDT.onlineMap()
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = profileRow(r, online) end
    Cache.set('roster', out, 60)
    return out
end)

local function canEdit(actor)
    local need = Config.Profiles.editGrade[actor.job]
    return need ~= nil and actor.grade >= need
end
Lawmen.canEdit = canEdit

MDT.rpc('saveLawmanProfile', { perm = 'lawmen', law = true, duty = true }, function(actor, p)
    local target = MDT.str(p.targetCitizenId, 50)
    if target == '' then target = actor.cid end
    -- anyone may edit their own profile; others' profiles need the edit grade
    local manager = canEdit(actor)
    if target ~= actor.cid and not manager then
        return { result = { success = false, message = L('lm_no_edit_permission') } }
    end
    local job, grade, jobLabel = Lawmen.jobOf(target)
    if not job or not MDT.isLawJob(job) then
        return { result = { success = false, message = L('lm_target_not_lawman') } }
    end
    local existing = DB.one('SELECT id, loa_until, trainings FROM mdt_lawman_profiles WHERE citizen_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1', { target })
    -- certifications are set by managers only; everyone else keeps what they have
    local trainingsJson = existing and existing.trainings or '[]'
    if manager and p.trainings ~= nil then
        local trainings = {}
        local known = {}
        for _, t in ipairs(Config.Profiles.trainings) do known[t] = true end
        for _, t in ipairs(MDT.list(p.trainings, 20, 60)) do
            if type(t) == 'string' and known[t] then trainings[#trainings + 1] = t end
        end
        trainingsJson = MDT.jenc(trainings)
    end
    local fields = {
        callsign = MDT.str(p.callsign, 20),
        region = MDT.str(p.region, 50),
        description = MDT.str(p.description, 2000, true),
        photo = MDT.url(p.photo),
        trainings = trainingsJson,
    }
    -- rank and department always come from the target's own job
    local rank, dept = Perms.rankName(job, grade), jobLabel or job

    -- leave of absence needs createlawmen
    local loa = nil
    local loaChange = false
    if p.loaUntil ~= nil and MDT.can(actor, 'createlawmen') then
        local s = MDT.str(p.loaUntil, 10)
        if s == '' then loa, loaChange = nil, true
        elseif s:match('^%d%d%d%d%-%d%d%-%d%d$') then loa, loaChange = s, true end
    end

    local id
    if existing then
        id = existing.id
        DB.upd([[UPDATE mdt_lawman_profiles SET callsign = ?, region = ?, description = ?, photo_url = ?, trainings = ?,
            `rank` = ?, department = ? WHERE id = ?]],
            { fields.callsign, fields.region, fields.description, fields.photo, fields.trainings, rank, dept, id })
        if loaChange then DB.upd("UPDATE mdt_lawman_profiles SET loa_until = NULLIF(?, '') WHERE id = ?", { loa or '', id }) end
        MDT.audit(actor, 'lawman_updated', target, MDT.charName(target), 'Profile updated')
    else
        id = DB.ins([[INSERT INTO mdt_lawman_profiles (player_id, citizen_id, photo_url, `rank`, department, region, trainings, description, callsign, loa_until, is_active)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULLIF(?, ''), 1)]],
            { MDT.findByCid(target) or 0, target, fields.photo, rank, dept, fields.region, fields.trainings, fields.description, fields.callsign, (loaChange and loa) or '' })
    end
    Lawmen.ensureStats(target, MDT.findByCid(target) or 0)
    Cache.clear('roster')
    MDT.log('lawmen', 'Lawman profile saved', ('%s saved the profile of %s'):format(actor.name, MDT.charName(target) or target), 'blue')
    if loaChange then Duty.nuiLawmen({ action = 'refreshLawmenList' }) end
    local r = DB.one(profileSelect .. ' WHERE p.id = ?', { id })
    return { result = { success = true, message = L('lm_profile_saved'), profile = r and profileRow(r, MDT.onlineMap()) or nil } }
end)

MDT.rpc('terminateLawman', { perm = 'createlawmen', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not id then return { success = false, message = L('perm_invalid_profile_data') } end
    local row = DB.one('SELECT id, citizen_id FROM mdt_lawman_profiles WHERE id = ? AND is_active = 1', { id })
    if not row then return { success = false, message = L('lm_profile_not_found') } end
    local cid = tostring(row.citizen_id)
    if cid == actor.cid then return { success = false, message = L('lm_cannot_terminate_self') } end
    local job, grade = Lawmen.jobOf(cid)
    if job and MDT.isLawJob(job) and (grade or 0) >= actor.grade then
        return { success = false, message = L('perm_only_higher_delete') }
    end
    DB.upd('UPDATE mdt_lawman_profiles SET is_active = 0 WHERE citizen_id = ?', { cid })
    -- permission overrides never outlive the job
    DB.q('DELETE FROM mdt_permissions_overrides WHERE citizenid = ?', { cid })
    Perms.overrides[cid] = nil
    local name = MDT.charName(cid) or cid
    -- only a lawman loses the job: someone who already left law keeps whatever job they have now
    if Config.Profiles.terminationSetsJob and job and MDT.isLawJob(job) then
        local src = MDT.findByCid(cid)
        if src then
            local ch = MDT.char(src)
            if ch then
                ch.setJob(Config.Profiles.terminatedJob, true)
                ch.setJobGrade(Config.Profiles.terminatedGrade, true)
                if ch.setJobLabel then ch.setJobLabel(Config.Profiles.terminatedJob) end
            end
            Duty.clockOff(src, 'fired', true)
            MDT.notify(src, L('lm_you_terminated'), 8000)
        else
            DB.upd('UPDATE characters SET job = ?, jobgrade = ? WHERE charidentifier = ?', { Config.Profiles.terminatedJob, Config.Profiles.terminatedGrade, tonumber(cid) })
        end
    end
    Cache.clear('roster')
    MDT.log('lawmen', 'LAWMAN TERMINATED', ('%s terminated %s'):format(actor.name, name), 'red')
    MDT.audit(actor, 'lawman_updated', cid, name, 'Terminated')
    Duty.nuiLawmen({ action = 'refreshLawmenList' })
    return { success = true, message = L('lm_terminated', name) }
end)

MDT.rpc('deleteLawmanProfile', { perm = 'createlawmen', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.profileId, 1, nil, nil)
    local cid = MDT.str(p.citizenid, 50)
    if not id or cid == '' then return { result = { success = false, message = L('perm_invalid_profile_data') } } end
    if cid == actor.cid then return { result = { success = false, message = L('lm_cannot_terminate_self') } } end
    local job, grade = Lawmen.jobOf(cid)
    if job and MDT.isLawJob(job) and (grade or 0) >= actor.grade then
        return { result = { success = false, message = L('perm_only_higher_delete') } }
    end
    local n = DB.upd('DELETE FROM mdt_lawman_profiles WHERE id = ? AND citizen_id = ?', { id, cid })
    if n == 0 then return { result = { success = false, message = L('perm_error_delete_profile') } } end
    DB.q('DELETE FROM mdt_lawman_stats WHERE citizen_id = ?', { cid })
    DB.q('DELETE FROM mdt_permissions_overrides WHERE citizenid = ?', { cid })
    Perms.overrides[cid] = nil
    Cache.clear('roster')
    MDT.log('lawmen', 'Lawman profile deleted', ('%s deleted profile %d (%s)'):format(actor.name, id, cid), 'red')
    MDT.audit(actor, 'lawman_updated', cid, MDT.charName(cid), 'Profile deleted')
    Duty.nuiLawmen({ action = 'refreshLawmenList' })
    return { result = { success = true, message = L('perm_profile_deleted') } }
end)

MDT.rpc('getDutyStats', { perm = 'lawmen', law = true, deny = { stats = { success = false } } }, function(actor)
    local s = Duty.state[actor.src]
    if s and s.on then Duty.bankLawman(actor.src, s) end
    local r = DB.one('SELECT duty_time_minutes, created_at, last_duty_update FROM mdt_lawman_profiles WHERE citizen_id = ? AND is_active = 1 ORDER BY id DESC LIMIT 1', { actor.cid })
    if not r then return { stats = { success = false, message = L('lm_profile_not_found') } } end
    local m = tonumber(r.duty_time_minutes) or 0
    return { stats = {
        success = true,
        totalMinutes = m,
        totalHours = math.floor(m / 60),
        totalDays = math.floor(m / 1440),
        formattedTime = ('%dd %dh %dm'):format(math.floor(m / 1440), math.floor(m / 60) % 24, m % 60),
        joinDate = r.created_at,
        lastUpdate = r.last_duty_update,
    } }
end)
