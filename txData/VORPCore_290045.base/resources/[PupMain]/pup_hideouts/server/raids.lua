-- pup_hideouts | raids: the warning countdown, the break-in, the open window, protection,
-- the stolen ledger and the still teardown

local R <const> = Config.Raids
local T <const> = Config.Teardown

HX.Raids = {}
local runs = {}      -- [hideoutId] = { leader, crew = { [src] = true }, down = { [src] = reason }, posseId, endsAt }
local crewOf = {}    -- [src] = hideoutId
local loot = {}      -- [hideoutId] = { [charid] = true }  (kept in KVP so it survives a restart)
local teardowns = {} -- [hideoutId] = { charid, src, endsAt, done }

local function posseUp() return GetResourceState('pup-ui') == 'started' end

local function posseInfo(src)
    if not posseUp() then return nil end
    local ok, p = pcall(function() return exports['pup-ui']:GetPosse(src) end)
    return ok and type(p) == 'table' and p or nil
end

local function posseMembers(src)
    if not posseUp() then return { src } end
    local ok, list = pcall(function() return exports['pup-ui']:GetPosseMembers(src) end)
    if not ok or type(list) ~= 'table' or #list == 0 then return { src } end
    local out, seen = {}, {}
    for _, s in ipairs(list) do
        s = tonumber(s)
        if s and not seen[s] and GetPlayerName(s) then seen[s] = true; out[#out + 1] = s end
    end
    if not seen[src] then out[#out + 1] = src end
    return out
end

local function maxPosse()
    if not posseUp() then return 5 end
    local ok, cfg = pcall(function() return exports['pup-ui']:GetPosseLocalConfig() end)
    return ok and type(cfg) == 'table' and tonumber(cfg.maxSize) or 5
end

local function requiredPosse()
    local need = tonumber(R.posseSize) or 0
    if need <= 0 then return 0 end
    local max = maxPosse()
    if need > max then
        print(('^3[pup_hideouts]^7 Raids.posseSize %d is above the posse maximum %d - capped'):format(need, max))
        need = max
    elseif need == max then
        print(('^3[pup_hideouts]^7 Raids.posseSize %d equals the full posse size - every raid needs a full posse'):format(need))
    end
    return need
end

----------------------------------------------------------------------------------------------------
-- loot crew (persisted)
----------------------------------------------------------------------------------------------------
local function lootKey(id) return ('crew:%d'):format(id) end

local function saveLoot(id)
    local l = loot[id]
    if not l then return DeleteResourceKvp(lootKey(id)) end
    local list = {}
    for cid in pairs(l) do list[#list + 1] = cid end
    SetResourceKvp(lootKey(id), json.encode(list))
end

function HX.Raids.isLootCrew(id, charid)
    charid = tonumber(charid)
    return charid ~= nil and loot[id] ~= nil and loot[id][charid] == true
end

function HX.Raids.restoreLoot()
    for id, h in pairs(HX.hideouts) do
        if h.justraided then
            local list = U.decode(GetResourceKvpString(lootKey(id)), nil)
            if type(list) == 'table' then
                loot[id] = {}
                for _, cid in ipairs(list) do
                    if tonumber(cid) then loot[id][tonumber(cid)] = true end
                end
            end
        else
            DeleteResourceKvp(lootKey(id))
        end
    end
end

----------------------------------------------------------------------------------------------------
-- runs
----------------------------------------------------------------------------------------------------
local function crewList(run)
    local out = {}
    for s in pairs(run.crew) do out[#out + 1] = s end
    return out
end

local function endRun(id, msgFn)
    local run = runs[id]
    if not run then return end
    runs[id] = nil
    for s in pairs(run.crew) do
        crewOf[s] = nil
        if GetPlayerName(s) then
            TriggerClientEvent('pup_hideouts:raidEnd', s, id)
            local m = msgFn and msgFn(s)
            if m then HX.tip(s, m) end
        end
    end
end

local function addToCrew(id, run, s)
    run.crew[s] = true
    crewOf[s] = id
    local h = HX.hideouts[id]
    TriggerClientEvent('pup_hideouts:raidJoin', s, id, h and h.coords, math.max(0, run.endsAt - os.time()))
end

local function dropFromCrew(id, run, s)
    run.crew[s], run.down[s] = nil, nil
    crewOf[s] = nil
    if GetPlayerName(s) then TriggerClientEvent('pup_hideouts:raidEnd', s, id) end
end

local function checkAllDown(id)
    local run = runs[id]
    if not run then return end
    local any = false
    for s in pairs(run.crew) do
        any = true
        if not run.down[s] then return end
    end
    if not any then runs[id] = nil return end
    endRun(id, function() return L('crew_wiped_raid') end)
end

local function raidPossible(src)
    if R.mode == 'off' then return false end
    if R.mode == 'police' then return HX.isPoliceJob(src) end
    return true
end

HX.rpc('raidStart', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h then return false end
    local cid = HX.charId(src)
    local function no(key, ...) HX.tip(src, L(key, ...)) return false end
    if not raidPossible(src) then return no('raid_off_mode') end
    if R.mode == 'anyone' then
        local total = HX.countsFor(cid)
        h = HX.hideouts[h.id]
        if not h then return false end
        if total < 1 then return no('raid_need_own') end
    end
    if not h.owned then return no('raid_unowned') end
    if HX.isMember(h, cid) then return no('raid_own') end
    if h.raidcooldown or h.justraided then return no('raid_recent') end
    if R.ownersOnline and #HX.memberSources(h) == 0 then return no('raid_nobody_home') end
    if U.dist(HX.pos(src), h.coords) > Config.Hideouts.doorReach then return no('too_far') end
    if crewOf[src] then return no('raid_busy') end
    local need = requiredPosse()
    local members = posseMembers(src)
    if need > 0 then
        if not posseUp() then HX.bottom(src, L('raid_no_posse_svc')) return false end
        if #members < need then HX.bottom(src, L('raid_posse_small', need, #members)) return false end
    end
    if runs[h.id] then return no('raid_busy') end

    local p = posseInfo(src)
    local run = { leader = src, crew = {}, down = {}, posseId = p and p.inPosse and p.id or nil,
        endsAt = os.time() + R.warningMinutes * 60 }
    runs[h.id] = run
    for _, s in ipairs(members) do
        if not crewOf[s] then addToCrew(h.id, run, s) end
    end
    if not run.crew[src] then addToCrew(h.id, run, src) end

    local text = L('raid_alert', h.name, R.warningMinutes)
    local pos = U.plain(HX.pos(src))
    for _, s in ipairs(HX.memberSources(h)) do
        if s ~= src then TriggerClientEvent('pup_hideouts:ownerAlert', s, pos, text) end
    end
    Logs.send('Raids', 'Hideout Raid Started', ('A raid started on %s'):format(h.name), 'raidStarted', src,
        { { 'Posse', Logs.posseNames(crewList(run)), false }, { 'Warning', R.warningMinutes .. ' minutes', true } }, h)
    return true
end, 2000)

HX.on('raidStop', function(src, id)
    id = tonumber(id)
    local run = id and runs[id]
    if not run or not run.crew[src] then return end
    local name = HX.nameOf(src)
    endRun(id, function(s)
        if s == src then return L('you_called_off') end
        return L('raid_called_off', name)
    end)
end, 1000)

HX.rpc('lockpickCount', function(src)
    return HX.itemCount(src, R.lockpickItem)
end, 500)

HX.on('pickSnapped', function(src)
    local id = crewOf[src]
    local run = id and runs[id]
    if not run or os.time() < run.endsAt then return end
    HX.removeItem(src, R.lockpickItem, 1)
end, 2000)

-- the open window closes; crew rights end
local function closeOpen(h)
    h.justraided = false
    h.raidopenedat = 0
    loot[h.id] = nil
    saveLoot(h.id)
    HX.save(h, { 'justraided', 'raidopenedat' })
    TriggerClientEvent('pup_hideouts:lootRevoked', -1, h.id)
    local td = teardowns[h.id]
    if td and not td.done and td.src and GetPlayerName(td.src) then
        TriggerClientEvent('pup_hideouts:teardownCancel', td.src, h.id)
    end
    teardowns[h.id] = nil
    HX.changed(h)
end

local function startProtection(h)
    if h.raidcooldown then return end
    h.raidcooldown = true
    h.raidday = os.time()
    HX.save(h, { 'raidcooldown', 'raidday' })
end

HX.rpc('breakIn', function(src, id)
    id = tonumber(id)
    local run = id and runs[id]
    local h = id and HX.hideouts[id]
    if not run or not h then HX.tip(src, L('no_raid_here')) return false end
    if not run.crew[src] then HX.tip(src, L('not_on_raid')) return false end
    if os.time() < run.endsAt then HX.tip(src, L('door_not_ready')) return false end
    if U.dist(HX.pos(src), h.coords) > Config.Hideouts.doorReach then HX.tip(src, L('too_far')) return false end
    if HX.itemCount(src, R.lockpickItem) < 1 then HX.tip(src, L('need_lockpick_for')) return false end
    run = runs[id]
    if not run then return false end

    local crew = crewList(run)
    loot[id] = {}
    for _, s in ipairs(crew) do
        local c = HX.charId(s)
        if c then loot[id][c] = true end
    end
    saveLoot(id)
    for _, s in ipairs(crew) do HX.tip(s, L('can_loot')) end
    h.justraided = true
    h.raidopenedat = os.time()
    HX.save(h, { 'justraided', 'raidopenedat' })
    -- protection starts with the break-in itself, not on a later client request
    startProtection(h)
    HX.pushAll()
    endRun(id, function(s) if s ~= src then return L('door_open') end end)
    Logs.send('Raids', 'Hideout Broken Open', ('%s was broken open'):format(h.name), 'brokenOpen', src,
        { { 'Posse', Logs.posseNames(crew), false }, { 'Open', R.openMinutes .. ' minutes', true } }, h)
    return true
end, 1500)

-- kept for the client's follow-up; protection already started at the break-in
HX.on('startProtection', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or not h.justraided or not HX.Raids.isLootCrew(h.id, HX.charId(src)) then return end
    startProtection(h)
end, 2000)

HX.rpc('takeLedger', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    local cid = HX.charId(src)
    if not h or not HX.isCrew(h, cid) or HX.isMember(h, cid) or not HX.isInside(src, h) then return false end
    local amount = U.round2(h.ledger)
    if amount <= 0 then HX.tip(src, L('no_money_ledger')) return false end
    h.ledger = 0
    HX.save(h, { 'ledger' })
    HX.giveCash(src, amount)
    HX.tip(src, L('took_cash', U.money(amount)))
    HX.changed(h)
    Logs.send('Raids', 'Ledger Stolen', ('$%s taken from the ledger'):format(U.money(amount)), 'ledgerStolen', src,
        { { 'Amount', '$' .. U.money(amount), true }, { 'Posse', Logs.posseNames(HX.sourcesOfLoot(h.id)), false } }, h)
    return true
end, 1500)

function HX.sourcesOfLoot(id)
    local out = {}
    for cid in pairs(loot[id] or {}) do
        local s = HX.srcOfChar(cid)
        if s then out[#out + 1] = s end
    end
    return out
end

----------------------------------------------------------------------------------------------------
-- posse changes mid-raid
----------------------------------------------------------------------------------------------------
AddEventHandler('pup-ui:posse:serverChanged', function(posseId, members)
    for id, run in pairs(runs) do
        if run.posseId and run.posseId == posseId then
            local now = {}
            for _, s in ipairs(type(members) == 'table' and members or {}) do
                s = tonumber(s)
                if s then now[s] = true end
            end
            for s in pairs(run.crew) do
                if not now[s] and s ~= run.leader then dropFromCrew(id, run, s) end
            end
            for s in pairs(now) do
                if not run.crew[s] and not crewOf[s] and GetPlayerName(s) then addToCrew(id, run, s) end
            end
        end
    end
    if HX.Wagons then HX.Wagons.posseChanged(posseId, members) end
end)

----------------------------------------------------------------------------------------------------
-- clock: sync the crew, mark riders down/up (decided on the server from the real ped)
----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(R.syncSeconds * 1000)
        local now = os.time()
        for id, run in pairs(runs) do
            local h = HX.hideouts[id]
            if not h then
                endRun(id)
            else
                local left = math.max(0, run.endsAt - now)
                for s in pairs(run.crew) do
                    if not GetPlayerName(s) then
                        run.crew[s], run.down[s] = nil, nil
                        crewOf[s] = nil
                    else
                        TriggerClientEvent('pup_hideouts:raidClock', s, id, left)
                        local reason
                        if not HX.alive(s) then reason = 'dead'
                        elseif HX.bucket(s) == 0 and U.dist(HX.pos(s), h.coords) > R.downDistance then reason = 'far' end
                        if reason and not run.down[s] then
                            run.down[s] = reason
                            if reason == 'dead' then HX.tip(s, L('died_raid')) else HX.bottom(s, L('left_area')) end
                        elseif not reason and run.down[s] then
                            run.down[s] = nil
                        end
                    end
                end
                if runs[id] then checkAllDown(id) end
            end
        end
    end
end)

function HX.Raids.dropped(src)
    local id = crewOf[src]
    crewOf[src] = nil
    local run = id and runs[id]
    if not run then return end
    run.crew[src], run.down[src] = nil, nil
    if next(run.crew) == nil then runs[id] = nil return end
    if run.leader == src then run.leader = next(run.crew) end
    checkAllDown(id)
end

function HX.Raids.forget(id)
    endRun(id)
    loot[id] = nil
    saveLoot(id)
    teardowns[id] = nil
end

-- admin "end raid now"
function HX.Raids.endOpen(h) if h.justraided then closeOpen(h) end end

----------------------------------------------------------------------------------------------------
-- open window and protection sweeps
----------------------------------------------------------------------------------------------------
local function sweepOpen()
    local now = os.time()
    for _, h in pairs(HX.hideouts) do
        if h.justraided and (h.raidopenedat <= 0 or now >= h.raidopenedat + R.openMinutes * 60) then
            closeOpen(h)
        end
    end
end

local function sweepProtection()
    local now = os.time()
    for _, h in pairs(HX.hideouts) do
        if h.raidcooldown and not h.justraided and now - h.raidday >= R.protectionDays * 86400 then
            h.raidcooldown = false
            h.raidday = 0
            HX.save(h, { 'raidcooldown', 'raidday' })
            HX.changed(h)
        end
    end
end

function HX.Raids.startup()
    sweepOpen()
    sweepProtection()
end

CreateThread(function()
    while true do
        Wait(10000)
        if HX.ready then sweepOpen() end
    end
end)

CreateThread(function()
    while true do
        Wait(5 * 60000)
        if HX.ready then sweepProtection() end
    end
end)

----------------------------------------------------------------------------------------------------
-- still teardown
----------------------------------------------------------------------------------------------------
local function tdTrace(...)
    if Config.DebugTeardown then print('[pup_hideouts:teardown]', ...) end
end

HX.rpc('hasTool', function(src)
    return HX.itemCount(src, T.tool) > 0
end, 500)

-- shared gates; returns h, charid or nil (message already sent)
local function tdGates(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or not h.owned or not h.justraided then HX.tip(src, L('td_not_raided')) return nil end
    if not HX.isInside(src, h) then HX.tip(src, L('too_far')) return nil end
    local cid = HX.charId(src)
    if HX.isMember(h, cid) then HX.tip(src, L('td_own')) return nil end
    if HX.stillLevel(h) <= 0 then HX.tip(src, L('td_nothing')) return nil end
    return h, cid
end

HX.rpc('teardownStart', function(src, id)
    local h, cid = tdGates(src, id)
    if not h then return false end
    local td = teardowns[h.id]
    if td and not td.done then
        if td.charid ~= cid then HX.tip(src, L('td_busy')) end
        return false
    end
    if HX.itemCount(src, T.tool) < 1 then HX.tip(src, L('missing_tool')) return false end
    if T.consumeTool and not HX.removeItem(src, T.tool, 1) then HX.tip(src, L('missing_tool')) return false end
    local secs = math.max(T.minSeconds, math.floor(T.seconds * HX.perkMult(src, 'underground_speed')))
    teardowns[h.id] = { charid = cid, src = src, endsAt = os.time() + secs, done = false }
    tdTrace('start', h.id, cid, secs)
    return true, secs
end, 1500)

HX.rpc('teardownClaim', function(src, id)
    local h, cid = tdGates(src, id)
    if not h then return false end
    local td = teardowns[h.id]
    if not td then HX.tip(src, L('td_not_started')) return false end
    if os.time() < td.endsAt then HX.tip(src, L('td_not_loose')) return false end
    if td.charid ~= cid then HX.tip(src, L('td_not_yours')) return false end

    local level = HX.stillLevel(h)
    local bonus = math.max(0, math.floor(HX.perkBonus(src, 'underground_bonus')))
    local haul, order, sum = {}, {}, 0
    for lvl = level, 1, -1 do
        for _, p in ipairs((Config.Stills[lvl] or {}).parts or {}) do
            if not haul[p.name] then haul[p.name] = 0; order[#order + 1] = p.name end
            haul[p.name] = haul[p.name] + p.amount + bonus
            sum = sum + p.amount + bonus
        end
    end
    if not HX.canCarryTotal(src, sum) then HX.tip(src, L('td_cant_carry')) return false end
    for _, name in ipairs(order) do
        if not HX.canCarry(src, name, haul[name]) then HX.tip(src, L('td_cant_carry')) return false end
    end
    -- claim it before the item awaits, so a double press cannot pay twice
    teardowns[h.id] = nil
    h.still = nil
    HX.save(h, { 'still' })
    for _, name in ipairs(order) do HX.addItem(src, name, haul[name]) end
    if bonus > 0 then HX.tip(src, L('td_bonus', bonus)) end
    HX.perkAward(src, 'still')
    HX.tip(src, L('td_done'))
    HX.changed(h)
    TriggerEvent('pup_hideouts:stillStripped', src, h.id, level, cid)
    tdTrace('claimed', h.id, cid, level)
    return true
end, 1500)

-- the teardown holds only while the player stays inside, near the still room and alive
CreateThread(function()
    while true do
        Wait(1000)
        for id, td in pairs(teardowns) do
            if not td.done then
                local h = HX.hideouts[id]
                local s = td.src
                local fail
                if not h or not GetPlayerName(s) or not HX.isInside(s, h) then fail = 'td_left'
                elseif not HX.alive(s) then fail = 'td_died'
                elseif U.dist(HX.pos(s), U.zone(h.zone).inside) > T.tether then fail = 'td_left' end
                if fail then
                    teardowns[id] = nil
                    tdTrace('cancelled', id, fail)
                    if GetPlayerName(s) then
                        HX.tip(s, L(fail))
                        TriggerClientEvent('pup_hideouts:teardownCancel', s, id)
                    end
                elseif os.time() >= td.endsAt then
                    td.done = true
                    TriggerClientEvent('pup_hideouts:teardownLoose', s, id)
                end
            end
        end
    end
end)

-- a finished (loose) teardown stays claimable by its owner while the window is open
function HX.Raids.onBucket(src, nowInId)
    for id, td in pairs(teardowns) do
        if td.src == src and not td.done and nowInId ~= id then
            teardowns[id] = nil
            HX.tip(src, L('td_left'))
            TriggerClientEvent('pup_hideouts:teardownCancel', src, id)
        end
    end
end

function HX.Raids.teardownDropped(src)
    for id, td in pairs(teardowns) do
        if td.src == src then teardowns[id] = nil end
    end
end
