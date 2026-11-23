-- pup-mdt | prison: the server owns every sentence (time, release, escape, labour)

Prison = {
    serving = {},    -- src -> { recordId, cid, remaining, last, synced, pushed, place, grace }
    labour = {},     -- recordId -> { used = { [spot] = true }, count, last, pending = { token, spot, at } }
    actionCooldown = {},
}

local P = Config.Prison

local function pt(v)
    if not v then return nil end
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0, h = (v.w or v.h or 0.0) + 0.0 }
end

local function fmt(secs)
    secs = math.max(0, math.floor(secs or 0))
    return ('%dm %ds'):format(math.floor(secs / 60), secs % 60)
end
Prison.fmt = fmt

-- where a sentence is served: main prison, a station, or a stored cell
local function placeFor(stationIdx)
    local st = stationIdx and P.stations[stationIdx]
    if st then
        return {
            station = stationIdx, arrival = pt(st.coords), cell = pt(st.coords), centre = pt(st.coords),
            radius = st.radius or 25.0, exit = pt(st.exit or P.exit),
        }
    end
    return { arrival = pt(P.arrival), cell = pt(P.cellBlock), centre = pt(P.centre), radius = P.radius, exit = pt(P.exit) }
end

local function placeFromRow(row)
    local place = placeFor(nil)
    if row.cell_x then
        place.cell = { x = row.cell_x, y = row.cell_y, z = row.cell_z, h = row.cell_h or 0.0 }
        if row.exit_x then
            place.station = true
            place.centre = { x = row.cell_x, y = row.cell_y, z = row.cell_z }
            place.radius = tonumber(row.escape_radius) or 25.0
            place.exit = { x = row.exit_x, y = row.exit_y, z = row.exit_z, h = row.exit_h or 0.0 }
        end
    end
    return place
end

-- the used spots of a sentence are also kept in a resource KVP, so restarting the
-- resource never hands a prisoner a fresh set of chops
local LABOUR_KVP = 'pupmdt_labour_'

local function labourState(recordId)
    local l = Prison.labour[recordId]
    if not l then
        l = { used = {}, count = 0, last = 0 }
        local raw = GetResourceKvpString(LABOUR_KVP .. tostring(recordId))
        local ok, saved = pcall(json.decode, raw or '')
        if raw and ok and type(saved) == 'table' then
            for _, spot in ipairs(saved) do
                spot = tonumber(spot)
                if spot and not l.used[spot] then l.used[spot] = true; l.count = l.count + 1 end
            end
        end
        Prison.labour[recordId] = l
    end
    return l
end

local function saveLabour(recordId, l)
    local list = {}
    for spot in pairs(l.used) do list[#list + 1] = spot end
    SetResourceKvp(LABOUR_KVP .. tostring(recordId), json.encode(list))
end

-- a sentence ended or a row is reused for a new one: its chops start again
local function resetLabour(recordId)
    Prison.labour[recordId] = nil
    DeleteResourceKvp(LABOUR_KVP .. tostring(recordId))
end

local function usedList(recordId)
    local out = {}
    for spot in pairs(labourState(recordId).used) do out[#out + 1] = spot end
    table.sort(out)
    return out
end

---------------------------------------------------------------------------
-- Serving state
---------------------------------------------------------------------------
function Prison.isServing(src) return Prison.serving[tonumber(src) or -1] ~= nil end

function Prison.liveSeconds(recordId, dbSeconds)
    for _, s in pairs(Prison.serving) do
        if s.recordId == recordId then return math.max(0, math.floor(s.remaining)) end
    end
    return math.max(0, tonumber(dbSeconds) or 0)
end

local function persist(s)
    s.synced = os.time()
    DB.upd("UPDATE mdt_prison_records SET jail_time = ? WHERE id = ? AND status = 'active'", { math.max(0, math.floor(s.remaining)), s.recordId })
end

local function pushTime(src, s, reasonKey, minutes)
    s.pushed = os.time()
    TriggerClientEvent('pup-mdt:client:jailTime', src, math.max(0, math.floor(s.remaining)), reasonKey, minutes)
end

-- begin (or resume) serving on an online player's client
function Prison.start(src, cid, recordId, seconds, place, resume, reason, sentenceMinutes)
    local now = os.time()
    Prison.clearPendingExit(cid)
    Prison.exitSent[src] = nil
    Prison.serving[src] = {
        recordId = recordId, cid = cid, remaining = seconds, last = now, synced = now, pushed = now,
        place = place, grace = now + P.escapeGraceSeconds,
    }
    TriggerClientEvent('pup-mdt:client:jailStart', src, {
        recordId = recordId,
        seconds = math.floor(seconds),
        sentenceMinutes = sentenceMinutes,
        reason = reason,
        arrival = P.autoJail and (resume and place.cell or place.arrival) or nil,
        centre = place.centre,
        radius = place.radius,
        exit = place.exit,
        resume = resume == true,
        labourUsed = usedList(recordId),
        labourMax = P.labour.maxUses,
    })
end

-- ends a sentence for an online prisoner and moves them to the exit
local function releaseOnline(src, kind)
    local s = Prison.serving[src]
    if not s then return end
    Prison.serving[src] = nil
    TriggerClientEvent('pup-mdt:client:jailRelease', src, kind, s.place.exit)
end

local function completeRow(recordId)
    return DB.upd("UPDATE mdt_prison_records SET status = 'completed', jail_time = 0 WHERE id = ? AND status = 'active'", { recordId })
end

-- served in full
local function finishServed(src)
    local s = Prison.serving[src]
    if not s then return end
    resetLabour(s.recordId)
    releaseOnline(src, 'served')
    MDT.notify(src, L('sentence_ended'), 6000)
    completeRow(s.recordId)
    Records.clearWanted(s.cid)
end

---------------------------------------------------------------------------
-- Releases while the prisoner is offline: the exit is kept (resource KVP, survives
-- restarts and expungements) and sent when their client next asks "am I serving?"
---------------------------------------------------------------------------
local EXIT_KVP = 'pupmdt_exit_'
Prison.exitSent = {}   -- src -> { at, exit }: re-sent to late jailChecks for a short while

local function setPendingExit(cid, exit)
    if not cid or cid == '' or not exit then return end
    SetResourceKvp(EXIT_KVP .. cid, json.encode(exit))
end

local function takePendingExit(cid)
    local raw = GetResourceKvpString(EXIT_KVP .. cid)
    if not raw or raw == '' then return nil end
    DeleteResourceKvp(EXIT_KVP .. cid)
    local ok, exit = pcall(json.decode, raw)
    if ok and type(exit) == 'table' and tonumber(exit.x) then return exit end
    return nil
end

function Prison.clearPendingExit(cid)
    if cid and cid ~= '' then DeleteResourceKvp(EXIT_KVP .. cid) end
end

-- release a record by id: lawman release, bail, appeal commute, mass release
function Prison.releaseRecord(recordId, kind)
    local row = DB.one("SELECT * FROM mdt_prison_records WHERE id = ? AND status = 'active'", { recordId })
    if not row then return false end
    if completeRow(recordId) == 0 then return false end
    resetLabour(recordId)
    local cid = tostring(row.charidentifier)
    local online = false
    for _, src in ipairs(MDT.keys(Prison.serving)) do
        local s = Prison.serving[src]
        if s and s.recordId == recordId then
            online = true
            releaseOnline(src, kind or 'forced')
        end
    end
    -- not on the server (or between characters): walk them out next time they load in
    if not online then setPendingExit(cid, placeFromRow(row).exit) end
    Records.clearWanted(cid)
    return true, cid
end

-- add (or with a negative value remove) seconds; returns the new remaining time
function Prison.adjust(recordId, delta, reasonKey, minutes)
    for _, src in ipairs(MDT.keys(Prison.serving)) do
        local s = Prison.serving[src]
        if s and s.recordId == recordId then
            s.remaining = math.max(0, s.remaining + delta)
            persist(s)
            if s.remaining <= 0 then
                Prison.releaseRecord(recordId, 'forced')
                return 0
            end
            pushTime(src, s, reasonKey, minutes)
            return s.remaining
        end
    end
    DB.upd("UPDATE mdt_prison_records SET jail_time = GREATEST(0, jail_time + ?) WHERE id = ? AND status = 'active'", { delta, recordId })
    local left = tonumber(DB.val('SELECT jail_time FROM mdt_prison_records WHERE id = ?', { recordId })) or 0
    if left <= 0 then Prison.releaseRecord(recordId, 'forced') end
    return left
end

---------------------------------------------------------------------------
-- Jailing
---------------------------------------------------------------------------
-- opts: seconds, minutes, reason, by, fine, bounty, station
function Prison.jail(target, opts)
    local a = MDT.player(target)
    if not a then return false end
    local seconds = MDT.int(opts.seconds, 60, Config.Jail.maxMinutes * 60, nil)
    if not seconds then return false end
    local minutes = MDT.int(opts.minutes, 1, Config.Jail.maxMinutes, math.ceil(seconds / 60))
    local place = placeFor(opts.station)
    local reason = MDT.str(opts.reason, 1000, true)
    local params = {
        a.name, a.cid, seconds, minutes, MDT.str(opts.by, 100), MDT.int(opts.fine, 0, nil, 0), reason, opts.bounty and 1 or 0,
    }
    local row = DB.one("SELECT id FROM mdt_prison_records WHERE charidentifier = ? AND status = 'active' ORDER BY id DESC LIMIT 1", { a.cid })
    local id
    if row then
        id = row.id
        params[#params + 1] = id
        DB.upd([[UPDATE mdt_prison_records SET player_name = ?, charidentifier = ?, jail_time = ?, sentence_minutes = ?, imprisoned_by = ?,
            imprisoned_at = NOW(), fine_amount = ?, reason = ?, is_bounty_claim = ? WHERE id = ?]], params)
    else
        id = DB.ins([[INSERT INTO mdt_prison_records (player_name, charidentifier, jail_time, sentence_minutes, imprisoned_by, fine_amount, reason,
            is_bounty_claim, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active')]], params)
    end
    if not id then return false end
    -- a new sentence never keeps an old cell or exit (only a configured station writes them)
    if place.station then
        DB.upd('UPDATE mdt_prison_records SET cell_x = ?, cell_y = ?, cell_z = ?, cell_h = ?, escape_radius = ?, exit_x = ?, exit_y = ?, exit_z = ?, exit_h = ? WHERE id = ?',
            { place.cell.x, place.cell.y, place.cell.z, place.cell.h, place.radius, place.exit.x, place.exit.y, place.exit.z, place.exit.h, id })
    else
        DB.upd('UPDATE mdt_prison_records SET cell_x = NULL, cell_y = NULL, cell_z = NULL, cell_h = NULL, escape_radius = NULL, exit_x = NULL, exit_y = NULL, exit_z = NULL, exit_h = NULL WHERE id = ?', { id })
    end
    resetLabour(id)
    TriggerEvent('pup-misc:police:server:release', a.src)
    Prison.start(a.src, a.cid, id, seconds, place, false, reason, minutes)
    MDT.notify(a.src, L('imprisoned_by', MDT.str(opts.by, 100), minutes, reason), 8000)
    MDT.log('prison', 'Prisoner booked', ('%s jailed %s (%s) for %d min: %s'):format(MDT.str(opts.by, 100), a.name, a.cid, minutes, reason), 'red')
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return true, id
end

-- reconnect / character select: pick up the newest active sentence.
-- fromClient: the client asked (its ped is loaded), so a release that happened while
-- they were away can walk them to the exit now
function Prison.resume(src, fromClient)
    src = tonumber(src)
    local a = MDT.player(src)
    if not a then return end
    local cur = Prison.serving[src]
    if cur then
        if cur.cid == a.cid then return end
        Prison.serving[src] = nil
        persist(cur)
    end
    local row = DB.one("SELECT * FROM mdt_prison_records WHERE charidentifier = ? AND status = 'active' AND jail_time > 0 ORDER BY id DESC LIMIT 1", { a.cid })
    if not row then
        if not fromClient then return end
        local exit = takePendingExit(a.cid)
        local sent = Prison.exitSent[src]
        if exit then
            Prison.exitSent[src] = { at = os.time(), exit = exit, cid = a.cid }
        elseif sent and sent.cid == a.cid and os.time() - sent.at <= 30 then
            exit = sent.exit   -- an earlier check may have come before the ped could move
        end
        if exit then
            -- third argument: the client is not serving, act anyway (released while away)
            TriggerClientEvent('pup-mdt:client:jailRelease', src, 'forced', exit, true)
        end
        return
    end
    if Prison.serving[src] then return end   -- another check got there during the query
    Prison.start(src, a.cid, row.id, tonumber(row.jail_time) or 0, placeFromRow(row), true, row.reason, row.sentence_minutes)
    local left = tonumber(row.jail_time) or 0
    MDT.notify(src, L('still_serving', math.floor(left / 60), left % 60), 8000)
end

RegisterNetEvent('pup-mdt:server:jailCheck', function()
    local src = source
    local last = Prison.actionCooldown['check:' .. src]
    if last and os.time() - last < 2 then return end
    Prison.actionCooldown['check:' .. src] = os.time()
    Prison.resume(src, true)
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    local cur = Prison.serving[src]
    Prison.exitSent[src] = nil
    if cur then Prison.serving[src] = nil; persist(cur) end
    SetTimeout(3000, function() Prison.resume(src) end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local s = Prison.serving[src]
    Prison.serving[src] = nil
    Prison.exitSent[src] = nil
    Prison.actionCooldown['check:' .. src] = nil
    if s then
        local now = os.time()
        s.remaining = math.max(0, s.remaining - (now - s.last))
        persist(s)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, s in pairs(Prison.serving) do
        s.remaining = math.max(0, s.remaining - (os.time() - s.last))
        persist(s)
    end
end)

---------------------------------------------------------------------------
-- The clock (server-side, one second at a time while online)
---------------------------------------------------------------------------
-- one prisoner's second; the database writes wait, so the entry is checked again after each
local function tick(src, now, escapeCheck)
    local s = Prison.serving[src]
    if not s then return end
    if not MDT.online(src) then
        Prison.serving[src] = nil
        persist(s)
        return
    end
    s.remaining = s.remaining - (now - s.last)
    s.last = now
    if s.remaining <= 0 then
        s.remaining = 0
        finishServed(src)
        return
    end
    if now - s.pushed >= 60 then pushTime(src, s, 'sync') end
    if escapeCheck and now >= s.grace then
        local c = MDT.coords(src)
        if c and MDT.dist(c, s.place.centre) > s.place.radius + 2.0 then
            s.grace = now + P.escapeGraceSeconds
            TriggerClientEvent('pup-mdt:client:jailReturn', src, s.place.cell)
        end
    end
    if now - s.synced >= P.syncSeconds then persist(s) end
end
Prison.tick = tick

-- the keys are copied first and every prisoner runs in its own pcall: one bad entry or
-- a database error can never stop the clock for everyone
CreateThread(function()
    local escapeTick = 0
    while true do
        Wait(1000)
        local now = os.time()
        escapeTick = escapeTick + 1
        for _, src in ipairs(MDT.keys(Prison.serving)) do
            local ok, err = pcall(tick, src, now, escapeTick % 3 == 0)
            if not ok then print('^1[pup-mdt]^7 prison clock: ' .. tostring(err)) end
        end
    end
end)

-- Offline time (Config.Prison.offlineCountdown): once a minute, every active sentence whose prisoner
-- is not on the server loses a minute. One that runs out is released now and the player is walked
-- to the exit when they next load in (the pending-exit path above).
local OFFLINE_STEP <const> = 60

-- checked per row, at that moment: the query and every write wait on the database, and a
-- prisoner who loads in meanwhile is counted by the online clock instead
local function servedOnline(recordId)
    for _, s in pairs(Prison.serving) do
        if s.recordId == recordId then return true end
    end
    return false
end

CreateThread(function()
    while true do
        Wait(OFFLINE_STEP * 1000)
        if P.offlineCountdown then
            local ok, err = pcall(function()
                local released = 0
                for _, r in ipairs(DB.q("SELECT id, jail_time FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0")) do
                    if not servedOnline(r.id) then
                        if (tonumber(r.jail_time) or 0) <= OFFLINE_STEP then
                            if Prison.releaseRecord(r.id, 'served') then released = released + 1 end
                        else
                            DB.upd("UPDATE mdt_prison_records SET jail_time = GREATEST(0, jail_time - ?) WHERE id = ? AND status = 'active'", { OFFLINE_STEP, r.id })
                        end
                    end
                end
                if released > 0 then Duty.nuiLawmen({ action = 'updatePrisons' }) end
            end)
            if not ok then print('^1[pup-mdt]^7 offline prison clock: ' .. tostring(err)) end
        end
    end
end)

---------------------------------------------------------------------------
-- Prison labour
---------------------------------------------------------------------------
RegisterNetEvent('pup-mdt:server:labourStart', function(spot)
    local src = source
    local s = Prison.serving[src]
    local cfg = P.labour
    if not s or not cfg.enabled then return end
    spot = MDT.int(spot, 1, #cfg.spots, nil)
    if not spot then return end
    local l = labourState(s.recordId)
    local now = os.time()
    if l.pending and now - l.pending.at < cfg.maxScenarioSeconds then return end
    if now - l.last < cfg.cooldownSeconds then return end
    if l.count >= cfg.maxUses then return MDT.notify(src, L('ps_chop_limit'), 6000) end
    if s.remaining <= cfg.floorMinutes * 60 then return MDT.notify(src, L('ps_chop_floor'), 6000) end
    if l.used[spot] or spot ~= l.count + 1 then return MDT.notify(src, L('ps_chop_used'), 4000) end
    if not MDT.near(src, cfg.spots[spot], cfg.serverDistance) then return end
    local token = ('%d-%d-%d'):format(s.recordId, spot, math.random(100000, 999999))
    l.pending = { token = token, spot = spot, at = now }
    l.last = now
    TriggerClientEvent('pup-mdt:client:labourGo', src, spot, token)
end)

RegisterNetEvent('pup-mdt:server:labourAbort', function(token)
    local src = source
    local s = Prison.serving[src]
    if not s then return end
    local l = labourState(s.recordId)
    if l.pending and l.pending.token == token then l.pending = nil end
end)

RegisterNetEvent('pup-mdt:server:labourDone', function(token)
    local src = source
    local s = Prison.serving[src]
    local cfg = P.labour
    if not s then return end
    local l = labourState(s.recordId)
    local pend = l.pending
    if not pend or pend.token ~= token then return end
    l.pending = nil
    local now = os.time()
    if now - pend.at < cfg.minScenarioSeconds or now - pend.at > cfg.maxScenarioSeconds then return end
    if not MDT.near(src, cfg.spots[pend.spot], cfg.serverDistance + 2.0) then return end
    local floor = cfg.floorMinutes * 60
    local cut = math.max(0, math.min(cfg.secondsOff, s.remaining - floor))
    l.used[pend.spot] = true
    l.count = l.count + 1
    l.last = now
    saveLabour(s.recordId, l)
    if cut > 0 then
        s.remaining = s.remaining - cut
        persist(s)
        s.pushed = now
    end
    TriggerClientEvent('pup-mdt:client:labourResult', src, {
        spotIndex = pend.spot, reducedMinutes = math.floor(cut / 60), used = l.count, max = cfg.maxUses,
        seconds = math.floor(s.remaining), atLimit = l.count >= cfg.maxUses, atFloor = s.remaining <= floor,
    })
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
local function lawGate(src, perm)
    local a = MDT.player(src)
    if not a or not a.isLaw then MDT.notify(src, L('no_permission'), 4000) return nil end
    if not Duty.isOn(src) then MDT.notify(src, L('cmd_must_be_on_duty'), 4000) return nil end
    if not MDT.can(a, perm) then MDT.notify(src, L('cmd_no_jail_permission'), 4000) return nil end
    return a
end

-- a lawman serving time may not release anyone, and nobody releases their own record
local function releaseBlocked(a, targetCid)
    if targetCid and tostring(targetCid) == a.cid then return true end
    if Prison.isServing(a.src) then return true end
    return DB.val("SELECT id FROM mdt_prison_records WHERE charidentifier = ? AND status = 'active' LIMIT 1", { a.cid }) ~= nil
end

RegisterCommand('jail', function(src, args)
    if src <= 0 then return end
    local a = lawGate(src, 'arrest')
    if not a then return end
    local target = MDT.int(args[1], 1, nil, nil)
    local minutes = tonumber(args[2])
    if not target or not minutes then return MDT.notify(src, L('cmd_jail_usage'), 5000) end
    minutes = math.floor(minutes)
    if minutes < Config.Jail.minMinutes then return MDT.notify(src, L('jail_min_time', Config.Jail.minMinutes), 4000) end
    if minutes > Config.Jail.maxMinutes then return MDT.notify(src, L('jail_max_time', Config.Jail.maxMinutes), 4000) end
    local t = MDT.player(target)
    if not t then return MDT.notify(src, L('player_not_found'), 4000) end
    if t.src == src then return MDT.notify(src, L('jail_invalid_data'), 4000) end
    if MDT.dist(MDT.coords(src), MDT.coords(target)) > Config.Jail.targetDistance then
        return MDT.notify(src, L('target_too_far', Config.Jail.targetDistance), 4000)
    end
    -- a new sentence would replace (and could shorten) the one being served: use extend
    if Prison.isServing(target) then return MDT.notify(src, L('arr_already_serving'), 5000) end
    local reason = MDT.str(table.concat(args, ' ', 3), 500)
    if reason == '' then reason = L('arrested_by', a.name) end
    if Prison.jail(target, { seconds = minutes * 60, minutes = minutes, reason = reason, by = a.name }) then
        Lawmen.bumpStat(a.cid, 'arrests_made', 1)
        MDT.notify(src, L('jailed_player', t.name, minutes), 5000)
        MDT.log('arrest', 'Jailed by command', ('%s jailed %s for %d min: %s'):format(a.name, t.name, minutes, reason), 'red')
    else
        MDT.notify(src, L('jail_invalid_data'), 4000)
    end
end, false)

RegisterCommand('unjail', function(src, args)
    if src <= 0 then return end
    local a = lawGate(src, 'arrest')
    if not a then return end
    local target = MDT.int(args[1], 1, nil, nil)
    if not target then return MDT.notify(src, L('cmd_unjail_usage'), 5000) end
    local t = MDT.player(target)
    if not t then return MDT.notify(src, L('player_not_found'), 4000) end
    if releaseBlocked(a, t.cid) then return MDT.notify(src, L('release_self'), 5000) end
    local s = Prison.serving[target]
    local recordId = s and s.recordId or DB.val("SELECT id FROM mdt_prison_records WHERE charidentifier = ? AND status = 'active' ORDER BY id DESC LIMIT 1", { t.cid })
    if not recordId or not Prison.releaseRecord(recordId, 'forced') then
        return MDT.notify(src, L('not_in_prison'), 4000)
    end
    MDT.notify(target, L('you_released'), 6000)
    MDT.notify(src, L('you_released_player', t.name), 5000)
    MDT.log('prison', 'Prisoner released', ('%s released %s by command'):format(a.name, t.name), 'green')
    Duty.nuiLawmen({ action = 'updatePrisons' })
end, false)

RegisterCommand('jailtime', function(src)
    if src <= 0 then return end
    local s = Prison.serving[src]
    if not s then return MDT.notify(src, L('not_serving'), 5000) end
    if s.place.station then
        return MDT.notify(src, L('ps_time_left', math.floor(s.remaining / 60), math.floor(s.remaining) % 60), 6000)
    end
    if Settings.get('feature_prisonregister') and P.register.enabled then
        return MDT.notify(src, L('jailtime_board'), 6000)
    end
    MDT.notify(src, L('jailtime_denied'), 6000)
end, false)

---------------------------------------------------------------------------
-- Register board
---------------------------------------------------------------------------
MDT.rpc('getJailRoster', {}, function(actor)
    if not (P.register.enabled and Settings.get('feature_prisonregister')) then
        return { ok = false, message = L('register_taken_down') }
    end
    if not MDT.near(actor.src, P.register.coords, P.register.serverDistance) then
        return { ok = false, message = L('pr_not_at_board') }
    end
    local rows = DB.q("SELECT id, player_name, jail_time FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0 ORDER BY jail_time DESC LIMIT ?", { P.register.maxRows })
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = { name = r.player_name, seconds = Prison.liveSeconds(r.id, r.jail_time) } end
    table.sort(out, function(x, y) return x.seconds > y.seconds end)
    return { ok = true, roster = out }
end)

---------------------------------------------------------------------------
-- Lawman prison screen
---------------------------------------------------------------------------
local function cooldown(key, secs)
    local last = Prison.actionCooldown[key]
    if last and os.time() - last < secs then return false end
    Prison.actionCooldown[key] = os.time()
    return true
end

local function result(ok, msg) return { result = { success = ok, message = msg } } end

MDT.rpc('getPrisons', { perm = 'arrest', law = true, deny = {} }, function()
    local rows = DB.q([[SELECT p.*, m.firstname, m.lastname, m.photo_url FROM mdt_prison_records p
        LEFT JOIN mdt_criminals m ON m.identity = p.charidentifier
        WHERE p.status = 'active' AND p.jail_time > 0 ORDER BY p.imprisoned_at DESC LIMIT 200]])
    local online = MDT.onlineMap()
    local out = {}
    for _, r in ipairs(rows) do
        local cid = tostring(r.charidentifier or '')
        local secs = Prison.liveSeconds(r.id, r.jail_time)
        local total = (tonumber(r.sentence_minutes) or 0) * 60
        local src = online[cid]
        local name = (r.firstname and (r.firstname .. ' ' .. (r.lastname or ''))) or r.player_name
        local cellLabel = L('cell') .. ' ' .. tostring((r.id % 12) + 1)
        if r.cell_x then
            for _, c in ipairs(P.cells) do
                if math.abs(c.coords.x - r.cell_x) < 0.5 and math.abs(c.coords.y - r.cell_y) < 0.5 then cellLabel = c.label end
            end
        end
        out[#out + 1] = {
            id = r.id, prisoner_name = name, citizen_id = cid, playerId = src, photo = r.photo_url or '',
            status = r.status, sentence_time = tonumber(r.sentence_minutes) or 0, time_remaining = math.ceil(secs / 60),
            timeRemaining = fmt(secs), totalTime = fmt(total), fine_amount = tonumber(r.fine_amount) or 0,
            charges = r.reason, arrest_date = r.imprisoned_at, release_date = (os.time() + secs) * 1000,
            lawman = r.imprisoned_by, notes = r.reason, isOnline = src ~= nil, location = L('valentine_prison'),
            cell = cellLabel, behavior = L('behavior_normal'), playerIdentifier = cid, sentenceTime = tonumber(r.sentence_minutes) or 0,
            remainingTime = secs, imprisonedBy = r.imprisoned_by, imprisonedAt = r.imprisoned_at, is_bounty_claim = (r.is_bounty_claim == true or tonumber(r.is_bounty_claim) == 1),
        }
    end
    return out
end)

MDT.rpc('releasePrisoner', { perm = 'arrest', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    if not id then return result(false, L('prison_not_found')) end
    if not cooldown('rel:' .. id, 5) then return result(false, L('arrest_wait')) end
    local row = DB.one("SELECT id, player_name, charidentifier FROM mdt_prison_records WHERE id = ? AND status = 'active'", { id })
    if not row then return result(false, L('prison_not_found')) end
    if releaseBlocked(actor, row.charidentifier) then return result(false, L('release_self')) end
    local ok = Prison.releaseRecord(id, 'forced')
    if not ok then return result(false, L('release_failed')) end
    local t = MDT.findByCid(row.charidentifier)
    if t then MDT.notify(t, L('you_released'), 6000) end
    MDT.log('prison', 'Prisoner released', ('%s released %s'):format(actor.name, row.player_name or '?'), 'green')
    MDT.audit(actor, 'release_prisoner', row.charidentifier, row.player_name, 'Released from prison')
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return result(true, L('prison_released', row.player_name or ''))
end)

MDT.rpc('extendSentence', { perm = 'arrest', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local mins = MDT.int(p.extension, 1, Config.Jail.maxMinutes, nil)
    if not id or not mins then return result(false, L('jail_invalid_data')) end
    if not cooldown('ext:' .. id, 5) then return result(false, L('arrest_wait')) end
    local row = DB.one("SELECT id, player_name, charidentifier, jail_time FROM mdt_prison_records WHERE id = ? AND status = 'active'", { id })
    if not row then return result(false, L('prison_not_found')) end
    local current = Prison.liveSeconds(id, row.jail_time)
    if current + mins * 60 > Config.Jail.maxMinutes * 60 then return result(false, L('jail_max_time', Config.Jail.maxMinutes)) end
    Prison.adjust(id, mins * 60, 'extended', mins)
    local t = MDT.findByCid(row.charidentifier)
    if t then MDT.notify(t, L('ps_extended', mins), 6000) end
    MDT.audit(actor, 'prison_extended', row.charidentifier, row.player_name, ('+%d minutes'):format(mins))
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return result(true, L('prison_extended', mins))
end)

-- a destination is a configured cell or station label
MDT.rpc('transferPrisoner', { perm = 'arrest', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local dest = MDT.str(p.destination, 60):lower()
    if not id or dest == '' then return result(false, L('jail_invalid_data')) end
    local row = DB.one("SELECT id, player_name, charidentifier FROM mdt_prison_records WHERE id = ? AND status = 'active'", { id })
    if not row then return result(false, L('prison_not_found')) end
    local cell, stationIdx
    for _, c in ipairs(P.cells) do if c.label:lower() == dest then cell = c end end
    for i, st in ipairs(P.stations) do if (st.label or ''):lower() == dest then stationIdx = i end end
    if not cell and not stationIdx then
        local names = {}
        for _, c in ipairs(P.cells) do names[#names + 1] = c.label end
        for _, st in ipairs(P.stations) do names[#names + 1] = st.label end
        return result(false, L('prison_unknown_destination', table.concat(names, ', ')))
    end
    local place = stationIdx and placeFor(stationIdx) or placeFor(nil)
    if cell then place.cell = pt(cell.coords) end
    if stationIdx then
        DB.upd('UPDATE mdt_prison_records SET cell_x = ?, cell_y = ?, cell_z = ?, cell_h = ?, escape_radius = ?, exit_x = ?, exit_y = ?, exit_z = ?, exit_h = ? WHERE id = ?', {
            place.cell.x, place.cell.y, place.cell.z, place.cell.h, place.radius, place.exit.x, place.exit.y, place.exit.z, place.exit.h, id })
    else
        DB.upd('UPDATE mdt_prison_records SET cell_x = ?, cell_y = ?, cell_z = ?, cell_h = ?, escape_radius = NULL, exit_x = NULL, exit_y = NULL, exit_z = NULL, exit_h = NULL WHERE id = ?', {
            place.cell.x, place.cell.y, place.cell.z, place.cell.h, id })
    end
    for src, s in pairs(Prison.serving) do
        if s.recordId == id then
            s.place = place
            s.grace = os.time() + P.escapeGraceSeconds
            TriggerClientEvent('pup-mdt:client:jailToCell', src, place.cell, place.centre, place.radius)
            MDT.notify(src, L('you_transferred', cell and cell.label or P.stations[stationIdx].label), 6000)
        end
    end
    MDT.audit(actor, 'transfer_prisoner', row.charidentifier, row.player_name, 'Transferred to ' .. dest)
    return result(true, L('player_transferred_you', row.player_name or '', cell and cell.label or P.stations[stationIdx].label))
end)

MDT.rpc('sendPrisonerToCell', { perm = 'arrest', law = true, duty = true }, function(actor, p)
    local id = MDT.int(p.id, 1, nil, nil)
    local idx = MDT.int(p.cell, 1, #P.cells, nil)
    if not id or not idx then return result(false, L('jail_invalid_data')) end
    local row = DB.one("SELECT id, player_name, charidentifier FROM mdt_prison_records WHERE id = ? AND status = 'active'", { id })
    if not row then return result(false, L('prison_not_found')) end
    local cellPt = pt(P.cells[idx].coords)
    local moved = false
    for src, s in pairs(Prison.serving) do
        if s.recordId == id then
            if not s.place.station then
                s.place.cell = cellPt
                s.grace = os.time() + P.escapeGraceSeconds
                TriggerClientEvent('pup-mdt:client:jailToCell', src, cellPt, s.place.centre, s.place.radius)
                moved = true
            end
        end
    end
    if not moved then return result(false, L('prisoner_offline')) end
    DB.upd('UPDATE mdt_prison_records SET cell_x = ?, cell_y = ?, cell_z = ?, cell_h = ? WHERE id = ? AND exit_x IS NULL',
        { cellPt.x, cellPt.y, cellPt.z, cellPt.h, id })
    return result(true, L('moved_to_cell', P.cells[idx].label))
end)

MDT.rpc('massRelease', { perm = 'managepermissions', law = true, duty = true }, function(actor)
    local rows = DB.q("SELECT id FROM mdt_prison_records WHERE status = 'active'")
    local n = 0
    for _, r in ipairs(rows) do
        if Prison.releaseRecord(r.id, 'forced') then n = n + 1 end
    end
    for _, src in ipairs(MDT.keys(Prison.serving)) do
        local s = Prison.serving[src]
        if s then
            releaseOnline(src, 'forced')
            Records.clearWanted(s.cid)
        end
    end
    MDT.log('prison', 'MASS RELEASE', ('%s released every prisoner (%d)'):format(actor.name, n), 'red')
    MDT.audit(actor, 'release_mass', nil, nil, ('%d prisoners released'):format(n))
    Duty.nuiLawmen({ action = 'updatePrisons' })
    return result(true, L('mass_release_done', n))
end)

---------------------------------------------------------------------------
-- Read exports (synchronous)
---------------------------------------------------------------------------
local function infoFromRow(row)
    if not row then return nil end
    local secs = Prison.liveSeconds(row.id, row.jail_time)
    if secs <= 0 then return nil end
    local at = tonumber(row.at) or 0
    return {
        jailed = true, recordId = row.id, charid = tostring(row.charidentifier), playerName = row.player_name,
        secondsLeft = secs, minutesLeft = math.ceil(secs / 60), sentenceMinutes = tonumber(row.sentence_minutes) or 0,
        reason = row.reason, fine = tonumber(row.fine_amount) or 0, imprisonedBy = row.imprisoned_by,
        imprisonedAt = at, releaseAt = at + secs,
    }
end

function Prison.infoByCid(cid)
    local row = DB.one([[SELECT id, charidentifier, player_name, jail_time, sentence_minutes, reason, fine_amount, imprisoned_by,
        UNIX_TIMESTAMP(imprisoned_at) AS at FROM mdt_prison_records
        WHERE charidentifier = ? AND status = 'active' AND jail_time > 0 ORDER BY id DESC LIMIT 1]], { tostring(cid or '') })
    return infoFromRow(row)
end

local function cidOf(src)
    local ch = MDT.char(src)
    return ch and tostring(ch.charIdentifier) or nil
end

exports('GetJailInfo', function(charid) return Prison.infoByCid(charid) end)
exports('IsJailed', function(charid) return Prison.infoByCid(charid) ~= nil end)
exports('GetJailTime', function(charid) local i = Prison.infoByCid(charid) return i and i.secondsLeft or 0 end)
exports('GetJailMinutes', function(charid) local i = Prison.infoByCid(charid) return i and i.minutesLeft or 0 end)
exports('GetJailInfoBySource', function(src) local c = cidOf(src) return c and Prison.infoByCid(c) or nil end)
exports('IsJailedBySource', function(src) local c = cidOf(src) return c ~= nil and Prison.infoByCid(c) ~= nil end)
exports('GetJailTimeBySource', function(src)
    local c = cidOf(src)
    local i = c and Prison.infoByCid(c)
    return i and i.secondsLeft or 0
end)
exports('GetAllJailed', function()
    local rows = DB.q("SELECT id, charidentifier, player_name, jail_time, reason FROM mdt_prison_records WHERE status = 'active' AND jail_time > 0 ORDER BY id DESC")
    local out = {}
    for _, r in ipairs(rows) do
        local secs = Prison.liveSeconds(r.id, r.jail_time)
        out[#out + 1] = { charid = tostring(r.charidentifier), playerName = r.player_name, secondsLeft = secs, minutesLeft = math.ceil(secs / 60), reason = r.reason }
    end
    return out
end)
