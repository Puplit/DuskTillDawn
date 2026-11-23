-- pup-mdt | bounties (warrant rows), Most Wanted board, bounty hunter board

Bounty = { claiming = {}, claimCooldown = {}, hintCooldown = {}, checks = {}, zones = {}, nextId = 0 }

local F = Config.Features
local BB = Config.BountyBoard

---------------------------------------------------------------------------
-- Bounties
---------------------------------------------------------------------------
local function expiry(v)
    local s = MDT.str(v, 25)
    local d, t = s:match('^(%d%d%d%d%-%d%d%-%d%d)[T ]?(%d?%d?:?%d?%d?)')
    if d then
        if t and t:match('^%d%d:%d%d$') then return d .. ' ' .. t .. ':00' end
        return d .. ' 23:59:59'
    end
    return os.date('%Y-%m-%d %H:%M:%S', os.time() + F.bountySuggestedExpiryDays * 86400)
end

-- felony / misdemeanor / infraction counts from penal codes named in the text
local function classCounts(text)
    local f, m, i = 0, 0, 0
    local lower = (text or ''):lower()
    for _, pc in ipairs(Penal.all()) do
        if lower:find(pc.code:lower(), 1, true) or (pc.label ~= '' and lower:find(pc.label:lower(), 1, true)) then
            if pc.charge_class == 'felony' then f = f + 1 elseif pc.charge_class == 'infraction' then i = i + 1 else m = m + 1 end
        end
    end
    return f, m, i
end

local function warrantRow(r)
    r.source = 'mdt'
    r.fine, r.jailtime, r.reward, r.imgurl = r.bounty_fine, r.bounty_jailtime, r.bounty_reward, r.image_url
    return r
end

MDT.rpc('getWarrants', { perm = 'warrants', law = true, deny = {} }, function()
    local rows = DB.q('SELECT * FROM mdt_reports_warrants ORDER BY created_at DESC LIMIT 100')
    for _, r in ipairs(rows) do warrantRow(r) end
    return rows
end)

local function fields(p)
    local fine = MDT.int(p.fine, 0, 10000000, nil) or MDT.int(Settings.get('bounty_fine'), 0, nil, F.bountyDefaultFine)
    local jail = MDT.int(p.jailtime, 0, Config.Jail.maxMinutes, nil) or MDT.int(Settings.get('bounty_jailtime'), 0, nil, F.bountyDefaultJail)
    local reward = math.min(MDT.int(p.reward, 0, nil, nil) or fine, Config.Bounties.maxReward)
    local charges = MDT.str(p.charges, 2000, true)
    local f, m, i = classCounts(charges)
    return {
        name = MDT.str(p.citizen_name, 100), cid = MDT.str(p.citizenid, 50), charges = charges,
        notes = MDT.str(p.notes, 2000, true), expiry = expiry(p.expiry_date), image = MDT.url(p.image_url),
        fine = fine, jail = jail, reward = reward, f = f, m = m, i = i,
    }
end

-- rewards come out of the police ledger: a bounty is only posted if the ledger covers it now
-- (nothing is held back; the payout itself is an atomic debit and refuses when short)
local function rewardFunded(reward)
    if reward <= 0 or not BB.payHunter then return true end
    if not Config.Ledger.enabled then return false end
    return Ledger.balance(Config.Bounties.ledgerJob) >= reward
end

MDT.rpc('createWarrant', { perm = 'issuewarrants', law = true, duty = true }, function(actor, p)
    if not F.bounty then return { success = false, message = L('warr_disabled') } end
    local v = fields(p)
    if v.name == '' then return { success = false, message = L('warr_name_required') } end
    if not rewardFunded(v.reward) then return { success = false, message = L('warr_reward_unfunded', v.reward) } end
    local id = DB.ins([[INSERT INTO mdt_reports_warrants (citizenid, citizen_name, charges, notes, felonies, misdemeanors, infractions, expiry_date,
        issued_by, status, image_url, bounty_fine, bounty_jailtime, bounty_reward) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?)]],
        { v.cid, v.name, v.charges, v.notes, v.f, v.m, v.i, v.expiry, actor.name, v.image, v.fine, v.jail, v.reward })
    MDT.audit(actor, 'warrant_issued', v.cid, v.name, ('Fine $%d, %d min, reward $%d'):format(v.fine, v.jail, v.reward))
    MDT.log('bounties', 'Bounty posted', ('%s posted a bounty on %s: %s'):format(actor.name, v.name, v.charges), 'orange')
    if v.cid ~= '' then Records.syncWanted(v.cid) end
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

MDT.rpc('updateWarrant', { perm = 'issuewarrants', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local old = id and DB.one('SELECT * FROM mdt_reports_warrants WHERE id = ?', { id })
    if not old then return { success = false, message = L('warr_not_found') } end
    local status = MDT.enum(p.status, { 'active', 'expired', 'served', 'revoked' }, old.status)
    if (status == 'revoked' or old.status == 'revoked') and status ~= old.status and not MDT.can(actor, 'deletewarrants') then
        return { success = false, message = L('warr_only_senior_revoke') }
    end
    if status == 'served' or status == 'expired' then
        DB.q('DELETE FROM mdt_reports_warrants WHERE id = ?', { id })
        MDT.audit(actor, 'warrant_deleted', old.citizenid, old.citizen_name, 'Marked ' .. status)
        if old.citizenid ~= '' then Records.syncWanted(old.citizenid) end
        Cache.clear('dashboard')
        return { success = true, id = id, removed = true, status = status }
    end
    local v = fields(p)
    if v.name == '' then v.name = old.citizen_name end
    if v.reward > (tonumber(old.bounty_reward) or 0) and not rewardFunded(v.reward) then
        return { success = false, message = L('warr_reward_unfunded', v.reward) }
    end
    DB.upd([[UPDATE mdt_reports_warrants SET citizenid = ?, citizen_name = ?, charges = ?, notes = ?, felonies = ?, misdemeanors = ?, infractions = ?,
        expiry_date = ?, status = ?, image_url = ?, bounty_fine = ?, bounty_jailtime = ?, bounty_reward = ? WHERE id = ?]],
        { v.cid, v.name, v.charges, v.notes, v.f, v.m, v.i, v.expiry, status, v.image, v.fine, v.jail, v.reward, id })
    if status == 'revoked' then
        DB.upd('UPDATE mdt_reports_warrants SET revoked_by = ?, revoked_at = NOW() WHERE id = ?', { actor.name, id })
    else
        DB.upd('UPDATE mdt_reports_warrants SET revoked_by = NULL, revoked_at = NULL WHERE id = ?', { id })
    end
    MDT.audit(actor, 'warrant_updated', v.cid, v.name, 'Status ' .. status)
    if old.citizenid ~= '' then Records.syncWanted(old.citizenid) end
    if v.cid ~= '' and v.cid ~= tostring(old.citizenid) then Records.syncWanted(v.cid) end
    Cache.clear('dashboard')
    return { success = true, id = id, status = status }
end)

MDT.rpc('deleteWarrant', { perm = 'deletewarrants', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local old = id and DB.one('SELECT id, citizenid, citizen_name FROM mdt_reports_warrants WHERE id = ?', { id })
    if not old then return { success = false, id = id, message = L('warr_not_found') } end
    DB.q('DELETE FROM mdt_reports_warrants WHERE id = ?', { id })
    MDT.audit(actor, 'warrant_deleted', old.citizenid, old.citizen_name, 'Deleted')
    if old.citizenid ~= '' then Records.syncWanted(old.citizenid) end
    Cache.clear('dashboard')
    return { success = true, id = id }
end)

function Bounty.sweep()
    DB.q("DELETE FROM mdt_reports_warrants WHERE status IN ('served', 'expired')")
    if F.bountyAutoExpire then
        DB.q("DELETE FROM mdt_reports_warrants WHERE status <> 'revoked' AND expiry_date < NOW()")
    end
    Records.sweepWanted()
end

---------------------------------------------------------------------------
-- Most Wanted board (display only)
---------------------------------------------------------------------------
MDT.rpc('getMostWanted', { perm = 'mostwanted', law = true, deny = { rows = {}, canManage = false } }, function(actor, p)
    if not F.mostWanted then return { rows = {}, canManage = false } end
    local status = MDT.enum(p.status, { 'active', 'captured', 'all' }, 'active')
    local where = status == 'all' and '' or ' WHERE status = ?'
    local rows = DB.q('SELECT * FROM mdt_most_wanted' .. where .. [[ ORDER BY (status = 'active') DESC,
        FIELD(danger, 'extreme', 'high', 'medium', 'low'), reward DESC, added_at DESC LIMIT 100]], status == 'all' and {} or { status })
    return { rows = rows, canManage = MDT.can(actor, 'managemostwanted') }
end)

MDT.rpc('lookupMostWantedCitizen', { perm = 'managemostwanted', law = true, deny = { found = false } }, function(_, p)
    local cid = MDT.str(p.citizenIdentity, 50)
    local m = DB.one('SELECT firstname, lastname, photo_url FROM mdt_criminals WHERE identity = ?', { cid })
    if m then return { found = true, name = MDT.str((m.firstname or '') .. ' ' .. (m.lastname or ''), 100), photoUrl = m.photo_url or '' } end
    local name = MDT.charName(cid)
    if not name then return { found = false } end
    return { found = true, name = name, photoUrl = '' }
end)

MDT.rpc('addMostWanted', { perm = 'managemostwanted', law = true, duty = true }, function(actor, p)
    if not F.mostWanted then return { success = false, message = L('mw_add_failed') } end
    local name = MDT.str(p.name, 100)
    if name == '' then return { success = false, message = L('mw_name_required') } end
    local id = DB.ins([[INSERT INTO mdt_most_wanted (citizen_identity, name, crimes, danger, reward, notes, photo_url, status, added_by_citizenid, added_by_name)
        VALUES (NULLIF(?, ''), ?, ?, ?, ?, ?, ?, 'active', ?, ?)]], {
        MDT.str(p.citizenIdentity, 50), name, MDT.str(p.crimes, 1000, true), MDT.enum(p.danger, { 'low', 'medium', 'high', 'extreme' }, 'high'),
        MDT.int(p.reward, 0, 100000000, 0), MDT.str(p.notes, 1000, true), MDT.url(p.photoUrl), actor.cid, actor.name })
    if not id then return { success = false, message = L('mw_add_failed') } end
    MDT.audit(actor, 'mostwanted_added', MDT.str(p.citizenIdentity, 50), name, '')
    return { success = true, id = id, action = 'added' }
end)

MDT.rpc('resolveMostWanted', { perm = 'managemostwanted', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local action = MDT.enum(p.action, { 'remove', 'capture' }, nil)
    local row = id and DB.one('SELECT id, citizen_identity, name FROM mdt_most_wanted WHERE id = ?', { id })
    if not row or not action then return { success = false, message = L('mw_not_found') } end
    if action == 'capture' then
        DB.upd("UPDATE mdt_most_wanted SET status = 'captured', captured_by_name = ?, captured_at = NOW() WHERE id = ?", { actor.name, id })
        MDT.audit(actor, 'mostwanted_captured', row.citizen_identity, row.name, '')
        return { success = true, id = id, action = 'captured' }
    end
    DB.q('DELETE FROM mdt_most_wanted WHERE id = ?', { id })
    MDT.audit(actor, 'mostwanted_removed', row.citizen_identity, row.name, '')
    return { success = true, id = id, action = 'removed' }
end)

---------------------------------------------------------------------------
-- Bounty hunter board
---------------------------------------------------------------------------
local function hasAccess(actor)
    if not BB.enabled or not actor then return false end
    if MDT.can(actor, 'arrest') and actor.isLaw then return true end
    return MDT.inList(BB.extraJobs, actor.job)
end

local function atBoard(src)
    return MDT.near(src, BB.coords, BB.promptDistance + 4.0)
end

MDT.rpc('bountyAccess', {}, function(actor) return { access = hasAccess(actor) } end)

AddEventHandler('vorp:playerJobChange', function(src)
    SetTimeout(500, function()
        local a = MDT.player(src)
        if a then TriggerClientEvent('pup-mdt:client:bountyAccess', src, hasAccess(a)) end
    end)
end)

MDT.rpc('getBountyBoard', {}, function(actor)
    if not hasAccess(actor) then return { ok = false, message = L('bb_not_authorised') } end
    if not atBoard(actor.src) then return { ok = false, message = L('bb_not_at_board') } end
    local rows = DB.q("SELECT * FROM mdt_reports_warrants WHERE status = 'active' ORDER BY bounty_reward DESC, created_at DESC LIMIT 100")
    local online = MDT.onlineMap()
    local out = {}
    local last = Bounty.hintCooldown[actor.cid]
    local canHint = not last or os.time() - last >= BB.hintCooldownMinutes * 60
    for _, r in ipairs(rows) do
        local cid = tostring(r.citizenid or '')
        local on = cid ~= '' and online[cid] ~= nil
        if on or not BB.onlineOnly then
            out[#out + 1] = { id = r.id, name = r.citizen_name, charges = r.charges, fine = r.bounty_fine, reward = r.bounty_reward,
                jailtime = r.bounty_jailtime, image = r.image_url, online = on, canHint = on and canHint }
        end
    end
    return { ok = true, bounties = out }
end)

-- ask a client something and wait for the answer
local function ask(target, event, store, timeoutMs, ...)
    Bounty.nextId = Bounty.nextId + 1
    local id = Bounty.nextId
    local p = promise.new()
    store[id] = { p = p, target = target }
    TriggerClientEvent(event, target, id, ...)
    SetTimeout(timeoutMs, function()
        if store[id] then store[id] = nil; p:resolve(nil) end
    end)
    return Citizen.Await(p)
end

RegisterNetEvent('pup-mdt:server:captureAnswer', function(id, ok, isDead)
    local src = source
    local w = Bounty.checks[tonumber(id) or -1]
    if not w or w.target ~= src then return end
    Bounty.checks[tonumber(id)] = nil
    w.p:resolve({ ok = ok == true, dead = isDead == true })
end)

RegisterNetEvent('pup-mdt:server:zoneAnswer', function(id, name)
    local src = source
    local w = Bounty.zones[tonumber(id) or -1]
    if not w or w.target ~= src then return end
    Bounty.zones[tonumber(id)] = nil
    w.p:resolve(type(name) == 'string' and MDT.str(name, 60) or false)
end)

MDT.rpc('bhTip', {}, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not hasAccess(actor) or not atBoard(actor.src) or not id then return { id = id, hint = false } end
    local last = Bounty.hintCooldown[actor.cid]
    if last and os.time() - last < BB.hintCooldownMinutes * 60 then
        return { id = id, hint = false, message = L('bb_hint_cooldown', math.ceil((BB.hintCooldownMinutes * 60 - (os.time() - last)) / 60)) }
    end
    -- held before the waits below, so parallel requests cannot each get a hint
    Bounty.hintCooldown[actor.cid] = os.time()
    local function none() Bounty.hintCooldown[actor.cid] = last return { id = id, hint = false } end
    local r = DB.one("SELECT citizenid FROM mdt_reports_warrants WHERE id = ? AND status = 'active'", { id })
    local target = r and MDT.findByCid(r.citizenid)
    if not target then return none() end
    local name = ask(target, 'pup-mdt:client:zoneQuery', Bounty.zones, 3000, BB.hintLevel)
    if not name or name == '' or name == PupMdtZones.unknown then
        local fallback = PupMdtZones.nameFromCoords(MDT.coords(target))
        name = fallback ~= PupMdtZones.unknown and fallback or nil
    end
    if not name then return none() end
    return { id = id, hint = name }
end)

MDT.rpc('bhClaim', {}, function(actor, p)
    local function fail(msg) MDT.notify(actor.src, msg, 6000) return { success = false, message = msg } end
    if not BB.enabled then return fail(L('bb_disabled')) end
    if not hasAccess(actor) then return fail(L('bb_not_authorised')) end
    -- a lawman claims as a lawman: on duty, like every other law action that changes something
    if actor.isLaw and not MDT.inList(BB.extraJobs, actor.job) and not Duty.isOn(actor.src) then
        return fail(L('must_be_on_duty_action'))
    end
    if not atBoard(actor.src) then return fail(L('bb_not_at_board')) end
    local last = Bounty.claimCooldown[actor.cid]
    if last and os.time() - last < BB.claimCooldownMinutes * 60 then
        return fail(L('bb_cooldown', math.ceil((BB.claimCooldownMinutes * 60 - (os.time() - last)) / 60)))
    end
    -- the cooldown is held while this claim runs (it waits), and given back if it fails
    Bounty.claimCooldown[actor.cid] = os.time()
    local function undo(msg) Bounty.claimCooldown[actor.cid] = last return fail(msg) end
    local id = MDT.int(p.id, 1, nil, nil)
    -- a claim that died on an error never blocks the bounty for longer than a minute
    if not id or (Bounty.claiming[id] and os.time() - Bounty.claiming[id] < 60) then return undo(L('bb_gone')) end
    local w = DB.one("SELECT * FROM mdt_reports_warrants WHERE id = ? AND status = 'active'", { id })
    if not w then return undo(L('bb_gone')) end
    local target = MDT.findByCid(w.citizenid)
    if not target then return undo(L('bb_target_offline')) end
    if target == actor.src then return undo(L('bb_self')) end
    if Prison.isServing(target) then return undo(L('arr_already_serving')) end

    Bounty.claiming[id] = os.time()
    local answer = ask(target, 'pup-mdt:client:captureCheck', Bounty.checks, BB.checkTimeoutSeconds * 1000, actor.src)
    -- the target's own answer can only refuse a claim; the server's distance check must also pass
    local near = MDT.dist(MDT.coords(target), MDT.coords(actor.src)) <= BB.claimDistance
    if not answer or not answer.ok or not near then
        Bounty.claiming[id] = nil
        return undo(L('bb_must_be_restrained'))
    end
    -- the check waited up to several seconds: both sides must still be the same characters
    local tNow, hNow = MDT.player(target), MDT.player(actor.src)
    if not tNow or tNow.cid ~= tostring(w.citizenid) or not hNow or hNow.cid ~= actor.cid or Prison.isServing(target) then
        Bounty.claiming[id] = nil
        return undo(L('bb_gone'))
    end
    -- the reward leaves the police ledger first; a short ledger refuses the claim
    local reward = math.min(tonumber(w.bounty_reward) or 0, Config.Bounties.maxReward)
    local job = Config.Bounties.ledgerJob
    local paid = BB.payHunter and reward > 0
    if paid and (not Config.Ledger.enabled or not Ledger.debit(job, reward, 'bounty', actor.name, 'Bounty on ' .. tostring(w.citizen_name))) then
        Bounty.claiming[id] = nil
        return undo(L('bb_no_funds'))
    end
    -- the bounty is taken before anything is paid out
    if DB.upd("UPDATE mdt_reports_warrants SET status = 'served', claimed_by = ? WHERE id = ? AND status = 'active'", { actor.name, id }) == 0 then
        if paid then Ledger.credit(job, reward, 'bounty_refund', actor.name, 'Bounty already taken') end
        Bounty.claiming[id] = nil
        return undo(L('bb_gone'))
    end
    Bounty.claiming[id] = nil
    Bounty.claimCooldown[actor.cid] = os.time()

    local t = MDT.player(target)
    if answer.dead and BB.reviveOnCapture then Core.Player.Revive(target) end
    local fine = tonumber(w.bounty_fine) or 0
    local collected = 0
    if BB.fineCriminal and fine > 0 then collected = Penal.applyFine(target, fine, L('bb_fine_reason'), { name = actor.name, job = Config.LawJobs[1] }) end
    local fined = collected > 0
    -- 0 minutes = a fine-only bounty
    local minutes = MDT.int(w.bounty_jailtime, 0, Config.Jail.maxMinutes, F.bountyDefaultJail)
    local jailed = minutes > 0 and Prison.jail(target, { seconds = minutes * 60, minutes = minutes, reason = w.charges ~= '' and w.charges or L('bb_fine_reason'),
        by = actor.name, fine = collected, bounty = true }) or false
    DB.ins([[INSERT INTO mdt_arrests (citizen_identity, citizen_name, lawman_citizenid, lawman_name, charges, total_fine, total_months,
        discount_percent, fine_discount_percent, jail_discount_percent, final_fine, final_months, notes, fine_applied, jail_applied)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?)]], {
        w.citizenid, t and t.name or w.citizen_name, actor.cid, actor.name,
        MDT.jenc({ { code = 'BOUNTY', label = w.charges ~= '' and w.charges or 'Bounty', count = 1, fine = fine, months = minutes } }),
        fine, minutes, fine, minutes, L('bb_captured_note', actor.name), fined and 1 or 0, jailed and 1 or 0 })
    if paid then
        -- the character loaded now, and only if it is still the hunter's; otherwise the ledger gets it back
        local ch = MDT.char(actor.src)
        local ok = ch ~= nil and tostring(ch.charIdentifier) == actor.cid and pcall(ch.addCurrency, 0, reward)
        if not ok then
            Ledger.credit(job, reward, 'bounty_refund', actor.name, 'Bounty reward could not be paid out')
            reward = 0
        end
    else
        reward = 0
    end
    MDT.audit(actor, 'warrant_claimed', w.citizenid, w.citizen_name, ('Reward $%d from the %s ledger'):format(reward, job))
    Records.clearWanted(w.citizenid)
    MDT.log('bounties', 'BOUNTY CLAIMED', ('%s brought in %s. Reward $%d, %d min, fine $%d (collected $%d)'):format(actor.name, w.citizen_name, reward, minutes, fine, collected), 'gold')
    MDT.notify(actor.src, L('bounty_reward', reward, w.citizen_name), 8000)
    Cache.clear('dashboard')
    return { success = true, message = L('bounty_reward', reward, w.citizen_name) }
end)
