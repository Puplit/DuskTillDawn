-- pup_robbery | walk-up robberies (forts, stores, the riverboat, the oil field, the mine camp, Thieves Landing)

Walkup = {}

local Jobs = {}    -- [placeId] = live job
local OnJob = {}   -- [src] = placeId
Walkup.FenceDeadlines = {} -- [posseId] = { key, at, src } walk-up jobs handed out by the fence

local P = Config.Perks
local W = Config.Walkup

local function place(id) return type(id) == 'string' and Config.Places[id] or nil end

function Walkup.isActive(id) return Jobs[id] ~= nil end
function Walkup.jobOf(src) return OnJob[src] end

--------------------------------------------------------------------------------
-- clocks

function Walkup.placeLeft(id)
    return DB.clockLeft('place', id)
end

function Walkup.setPlaceCooldown(id, minutes)
    DB.setClock('place', id, os.time() + math.floor(minutes * 60), W.persistPlaceCooldowns == true)
end

function Walkup.clearPlaceCooldown(id)
    DB.clearClock('place', id, W.persistPlaceCooldowns == true)
end

function Walkup.personalLeft(charid)
    if not charid then return 0 end
    return DB.clockLeft('walkup', charid)
end

local function setPersonal(src)
    local cid = S.charId(src)
    if not cid then return end
    DB.setClock('walkup', cid, os.time() + S.personalSeconds(Config.PersonalClocks.walkup, src))
end

--------------------------------------------------------------------------------
-- helpers

local function crewList(job)
    local out = {}
    for s in pairs(job.crew) do out[#out + 1] = s end
    return out
end

local function toCrew(job, event, ...)
    for s in pairs(job.crew) do TriggerClientEvent(event, s, ...) end
end

local function joinRadius(p)
    if p.joinDistance then return p.joinDistance end
    if W.joinDistance then return W.joinDistance end
    return math.min(p.stray or 100, W.joinDistanceCap or 200)
end

local function requiredRiders(p)
    local need = U.placeSettings(p).riders
    return U.clamp(math.floor(need), 1, math.max(1, S.posseMax()))
end

local function unlocked(job, p)
    if p.waves then return job.boxesOpen == true end
    local delay = (tonumber(p.unlockDelay) or 0) * 60
    return os.time() >= job.startedAt + delay - (W.unlockSlack or 2)
end

local function stateFor(job, p)
    local unlockIn = 0
    if not p.waves then
        unlockIn = math.max(0, job.startedAt + (tonumber(p.unlockDelay) or 0) * 60 - os.time())
    end
    local opened = {}
    for i in pairs(job.opened) do opened[#opened + 1] = i end
    return {
        unlockIn = unlockIn,
        boxesOpen = unlocked(job, p),
        wave = job.wave,
        opened = opened,
        guards = job.guardNet,
    }
end

local function sendBegin(src, job, p, role)
    TriggerClientEvent('pup_robbery:walkup:begin', src, job.id, stateFor(job, p), role)
end

local function pickNext(job, except)
    for s in pairs(job.crew) do
        if s ~= except and S.online(s) then return s end
    end
    return nil
end

--------------------------------------------------------------------------------
-- pre-check: the client asks before it sends a start (job first, then the law count, count only)

S.callback('pup_robbery:walkup:precheck', function(src, placeId)
    local p = place(placeId)
    if not p then return { ok = false } end
    if S.jobBlocked(src) then return { ok = false, msg = L('blockedJob') } end
    local need = U.placeSettings(p).lawmen
    local ok, have = S.lawOk(p.regions, need)
    if not ok then return { ok = false, law = true, need = need, have = have } end
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- starting a job

local function refuse(src, msg)
    S.tip(src, msg, 5000)
    return false
end

local function fenceHandled(p)
    return Config.Fence.jobs.categories[p.category] == true
end

function Walkup.start(src, placeId)
    local p = place(placeId)
    if not p then return false end
    local cid = S.charId(src)
    if not cid then return false end
    if not S.near(src, p.anchor, (p.startRadius or 5.0) + (W.startSlack or 30)) then return refuse(src, L('tooFar')) end
    if S.jobBlocked(src) then return refuse(src, L('blockedJob')) end
    local mine = Walkup.personalLeft(cid)
    if mine > 0 then return refuse(src, L('personalCooldown', U.minutesUp(mine))) end
    local placeLeft = Walkup.placeLeft(placeId)
    if placeLeft > 0 then return refuse(src, L('placeCooldown', U.minutesUp(placeLeft))) end

    local lone = S.lone(src)
    local members = S.posseMembers(src)
    local posse = S.posseInfo(src)

    if fenceHandled(p) and not lone then
        local ok, allowed, reason = S.call('pup-ui', 'PosseHasTask', src, placeId)
        if not ok then return refuse(src, L('posseService')) end
        if not allowed then
            if reason == 'You need a posse for this.' then return refuse(src, L('noPosse', S.posseCommand())) end
            if reason == 'Your posse has not taken this job.' then return refuse(src, L('posseNoJob')) end
            return refuse(src, tostring(reason or L('posseNoJob')))
        end
        local dl = posse.id and Walkup.FenceDeadlines[posse.id]
        if dl and dl.key == placeId and os.time() > dl.at then
            Walkup.FenceDeadlines[posse.id] = nil
            S.call('pup-ui', 'ClearPosseTask', src)
            return refuse(src, L('tooLate'))
        end
    end

    local need = requiredRiders(p)
    if need > 1 and not lone and #members < need then
        return refuse(src, L('needRiders', need, #members))
    end

    local waiting = {}
    for _, m in ipairs(members) do
        local left = Walkup.personalLeft(S.charId(m))
        if left > 0 then waiting[#waiting + 1] = ('%s (%s)'):format(S.charName(m), U.hm(left)) end
    end
    if #waiting > 0 then return refuse(src, L('crewOnCooldown', table.concat(waiting, ', '))) end

    if Jobs[placeId] then return refuse(src, L('alreadyRunning')) end

    for _, m in ipairs(members) do
        local other = OnJob[m]
        if other and other ~= placeId then return refuse(src, L('posseBusy', S.charName(m), other)) end
    end

    local lawNeed = U.placeSettings(p).lawmen
    local lawOk, lawHave = S.lawOk(p.regions, lawNeed)
    if not lawOk then
        S.tip(src, L('notEnoughLaw', lawNeed), 5000)
        return refuse(src, L('lawCount', lawHave))
    end

    -- every check passed
    local job = {
        id = placeId, leader = src, controller = src, crew = {}, startedAt = os.time(),
        wave = 0, boxesOpen = false, opened = {}, claims = {}, paid = {}, guardNet = {},
        posseId = posse.id, anyOpened = false,
    }
    Jobs[placeId] = job
    if posse.id and Walkup.FenceDeadlines[posse.id] and Walkup.FenceDeadlines[posse.id].key == placeId then
        Walkup.FenceDeadlines[posse.id] = nil
    end

    for _, m in ipairs(members) do setPersonal(m) end

    job.crew[src] = cid
    OnJob[src] = placeId
    sendBegin(src, job, p, { leader = true, controller = true })

    local radius = joinRadius(p)
    local starter = S.charName(src)
    for _, m in ipairs(members) do
        if m ~= src and not OnJob[m] and S.charId(m) and S.near(m, p.anchor, radius) then
            job.crew[m] = S.charId(m)
            OnJob[m] = placeId
            S.tip(m, L('startedBy', starter, placeId), 6000)
            sendBegin(m, job, p, {})
        end
    end

    local skip = {}
    for s in pairs(job.crew) do skip[s] = true end
    Police.alert('walkup:' .. placeId, p.anchor, placeId, p.regions, skip)
    Police.board(p.anchor, L('mdtText', placeId), false, placeId, p.regions and p.regions[1] or nil)

    Logs.send('🚨 Robbery Started', Logs.RED, ('**Place:** `%s`\n**Lawmen on duty:** %d\n\n%s'):format(Logs.clean(placeId), lawHave, Logs.robber(src)))
    return true
end

RegisterNetEvent('pup_robbery:walkup:start', function(placeId)
    local src = source
    if not S.rate(src, 'walkStart', 1500) then return end
    if type(placeId) ~= 'string' or not S.charId(src) then return end
    Walkup.start(src, placeId)
end)

--------------------------------------------------------------------------------
-- late joiners: posse riders who ride in after the start

CreateThread(function()
    while true do
        Wait(W.crewSweepMs or 8000)
        for id, job in pairs(Jobs) do
            local p = place(id)
            local anchorSrc = S.online(job.leader) and job.leader or pickNext(job)
            if p and anchorSrc then
                local radius = joinRadius(p)
                for _, m in ipairs(S.posseMembers(anchorSrc)) do
                    if not job.crew[m] and not OnJob[m] and S.charId(m) and S.near(m, p.anchor, radius) then
                        if Jobs[id] ~= job then break end
                        job.crew[m] = S.charId(m)
                        OnJob[m] = id
                        if Walkup.personalLeft(job.crew[m]) <= 0 then setPersonal(m) end
                        sendBegin(m, job, p, {})
                        S.tip(m, L('joinedLate', id), 6000)
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- boxes

S.callback('pup_robbery:walkup:claim', function(src, placeId, boxIdx)
    local job = Jobs[placeId]
    if not job or OnJob[src] ~= placeId or not job.crew[src] then return { ok = false } end
    local p = place(placeId)
    boxIdx = tonumber(boxIdx)
    local box = p and boxIdx and p.boxes[boxIdx]
    if not box then return { ok = false } end
    if S.itemCount(src, box.tool) < 1 then return { ok = false, msg = L('noTool', S.itemLabel(box.tool, box.toolLabel)) } end
    if job.opened[boxIdx] then return { ok = false, msg = L('boxOpenAlready') } end
    local holder = job.claims[boxIdx]
    if holder and holder ~= src and job.crew[holder] and S.online(holder) then return { ok = false, msg = L('boxHeld') } end
    if not unlocked(job, p) then return { ok = false, msg = L('boxNotReady') } end
    job.claims[boxIdx] = src
    local opts = { game = box.game, dials = box.dials }
    return { ok = true, opts = opts }
end)

local function rollItems(src, box, double)
    local got = false
    for _, line in ipairs(box.loot or {}) do
        if math.random(1, 100) <= (tonumber(line.chance) or 0) then
            local count = math.max(1, math.floor(tonumber(line.count) or 1))
            if double then count = count * 2 end
            local label = S.itemLabel(line.item, line.label)
            if S.canCarry(src, line.item, count) and S.giveItem(src, line.item, count, {}) then
                got = true
                S.tip(src, L('foundItem', count > 1 and (count .. ' x ' .. label) or label), 4000)
            else
                S.tip(src, L('noRoom', label), 4000)
            end
        end
    end
    return got
end

local function payBox(src, job, p, boxIdx, box)
    local cash = U.round((tonumber(box.cash) or 0) * S.perkMult(src, P.cash))
    if cash > 0 and S.addCash(src, cash, 0) then S.tip(src, L('foundCash', cash)) end
    local gold = tonumber(box.gold) or 0
    if gold > 0 and S.addCash(src, gold, 1) then S.tip(src, L('foundGold', gold)) end

    if S.up('pup-gangs') then
        S.call('pup-gangs', 'AwardBloodMoney', src, 'robbery', job.id)
        local pts = S.rollPoints(box.gangPoints or p.gangPoints or W.gangPointsDefault)
        if pts > 0 then S.call('pup-gangs', 'AwardPoints', src, 'robbery', pts, job.id) end
    end

    local double = S.perkRoll(src, P.double)
    if double then S.tip(src, L('doubleLoot'), 5000) end
    local got = rollItems(src, box, double)
    if not got and cash <= 0 and gold <= 0 then S.tip(src, L('nothingFound')) end

    S.awardShared(src, P.xpRobbery)
    Logs.send('📦 Box Looted', Logs.GREEN, ('**Place:** `%s`\n**Box:** #%d\n\n%s'):format(Logs.clean(job.id), boxIdx, Logs.robber(src)))
end

RegisterNetEvent('pup_robbery:walkup:result', function(placeId, boxIdx, success)
    local src = source
    if not S.rate(src, 'walkResult', 750) then return end
    local job = Jobs[placeId]
    if not job or OnJob[src] ~= placeId or not job.crew[src] then return end
    local p = place(placeId)
    boxIdx = tonumber(boxIdx)
    local box = p and boxIdx and p.boxes[boxIdx]
    if not box then return end
    if job.claims[boxIdx] ~= src then return end

    if success ~= true then
        job.claims[boxIdx] = nil
        S.takeItem(src, box.tool, 1)
        S.tip(src, L('pickLost', S.itemLabel(box.tool, box.toolLabel)))
        return
    end

    if job.opened[boxIdx] then return end
    job.paid[src] = job.paid[src] or {}
    if job.paid[src][boxIdx] then return end
    if not unlocked(job, p) then return S.tip(src, L('boxNotReady')) end
    if not S.near(src, box.pos, W.boxReach or 15.0) then return S.tip(src, L('tooFar')) end
    -- confirm the character before the box is spent
    if not S.char(src) then return end

    job.opened[boxIdx] = true
    job.claims[boxIdx] = nil
    job.paid[src][boxIdx] = true
    job.anyOpened = true
    toCrew(job, 'pup_robbery:walkup:boxOpened', placeId, boxIdx)
    S.tip(src, L('pickWon'))
    payBox(src, job, p, boxIdx, box)
end)

--------------------------------------------------------------------------------
-- waves and guards (reported by the controller's client)

RegisterNetEvent('pup_robbery:walkup:wave', function(placeId, n)
    local src = source
    if not S.rate(src, 'walkWave', 500) then return end
    local job = Jobs[placeId]
    local p = place(placeId)
    if not job or not p or not p.waves or job.controller ~= src then return end
    n = math.floor(tonumber(n) or 0)
    if n < 1 or n > p.waves.count or n < job.wave then return end
    job.wave = n
    for s in pairs(job.crew) do
        if s ~= src then TriggerClientEvent('pup_robbery:walkup:wave', s, placeId, n) end
    end
end)

RegisterNetEvent('pup_robbery:walkup:open', function(placeId)
    local src = source
    if not S.rate(src, 'walkOpen', 1000) then return end
    local job = Jobs[placeId]
    local p = place(placeId)
    if not job or not p or not p.waves or job.controller ~= src or job.boxesOpen then return end
    local minimum = (p.waves.count - 1) * (p.waves.gap or 0)
    if os.time() - job.startedAt < minimum then return end
    job.boxesOpen = true
    toCrew(job, 'pup_robbery:walkup:unlocked', placeId)
end)

RegisterNetEvent('pup_robbery:walkup:guards', function(placeId, ids)
    local src = source
    if not S.rate(src, 'walkGuards', 500) then return end
    local job = Jobs[placeId]
    if not job or job.controller ~= src or type(ids) ~= 'table' then return end
    local clean = {}
    for i = 1, math.min(#ids, 40) do
        local n = tonumber(ids[i])
        if n and n > 0 then clean[#clean + 1] = math.floor(n) end
    end
    job.guardNet = clean
    for s in pairs(job.crew) do
        if s ~= src then TriggerClientEvent('pup_robbery:walkup:guards', s, placeId, clean) end
    end
end)

--------------------------------------------------------------------------------
-- leaving and ending

local function finish(job, lastSrc, dropped)
    local p = place(job.id)
    Jobs[job.id] = nil
    local cd = 0
    if not dropped or job.anyOpened then
        cd = tonumber(p and p.cooldown) or 0
        Walkup.setPlaceCooldown(job.id, cd)
        if W.resetLastRiderClock and lastSrc and S.online(lastSrc) then setPersonal(lastSrc) end
    end
    Police.clear('walkup:' .. job.id)
    Logs.send('✅ Robbery Ended', Logs.BLUE, ('**Place:** `%s`\n**Cooldown:** %d min\n\n%s'):format(Logs.clean(job.id), cd, Logs.robber(lastSrc)))
end

function Walkup.leave(src, dropped)
    local id = OnJob[src]
    OnJob[src] = nil
    local job = id and Jobs[id]
    if not job or not job.crew[src] then return end
    job.crew[src] = nil
    for i, holder in pairs(job.claims) do
        if holder == src then job.claims[i] = nil end
    end
    if next(job.crew) == nil then
        return finish(job, src, dropped)
    end
    if job.leader == src then job.leader = pickNext(job) end
    if job.controller == src then
        job.controller = pickNext(job)
        if job.controller then
            TriggerClientEvent('pup_robbery:walkup:control', job.controller, id, job.wave, job.guardNet)
            S.tip(job.controller, L('youRunIt'), 5000)
        end
    end
end

RegisterNetEvent('pup_robbery:walkup:leave', function(placeId)
    local src = source
    if OnJob[src] ~= placeId then return end
    Walkup.leave(src, false)
end)

-- only a disconnect leaves the job here; a character switch is handled in server/main.lua
AddEventHandler('playerDropped', function()
    local src = source
    if OnJob[src] then Walkup.leave(src, true) end
end)

--------------------------------------------------------------------------------
-- start-up and admin

DB.onReady(function()
    if W.lockZeroLawPlacesAtStart then
        for id, p in pairs(Config.Places) do
            if U.placeSettings(p).lawmen == 0 and Walkup.placeLeft(id) <= 0 then
                Walkup.setPlaceCooldown(id, tonumber(p.cooldown) or 0)
            end
        end
    end
    if W.warnFarData then
        for id, p in pairs(Config.Places) do
            for i, b in ipairs(p.boxes) do
                if U.dist(b.pos, p.anchor) > (p.stray or 100) then
                    S.warn('%s box %d is %.0f m from the anchor, past the %d m stray distance: it cannot be opened', id, i, U.dist(b.pos, p.anchor), p.stray or 100)
                end
            end
        end
    end
end)

function Walkup.resetPlaces(name)
    local n = 0
    for id in pairs(Config.Places) do
        if not name or id:lower() == name:lower() then
            if Walkup.placeLeft(id) > 0 then n = n + 1 end
            Walkup.clearPlaceCooldown(id)
        end
    end
    return n
end

function Walkup.shutdown()
    for id in pairs(Jobs) do Police.clear('walkup:' .. id) end
    Jobs, OnJob = {}, {}
end

function Walkup.crewOf(placeId)
    local job = Jobs[placeId]
    return job and crewList(job) or {}
end
