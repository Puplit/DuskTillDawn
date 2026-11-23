-- pup_camps | raids: posse crew, shared countdown, lockpick window, looting window

RaidRuns = {}   -- [campId] = run
RaidOpen = {}   -- [campId] = { untilTime, chars = {[charid]=true}, posseId, opener }
local Alerts = {}  -- [campId] = { srcs = {}, expires }

local R = Config.Raids

local function requiredRiders()
    local need = R.minRiders
    local max = 5
    if Integrations.running('pup-ui') then
        local ok, cfg = pcall(function() return exports['pup-ui']:GetPosseLocalConfig() end)
        if ok and type(cfg) == 'table' and tonumber(cfg.maxSize) then max = tonumber(cfg.maxSize) end
    end
    if need > max then need = max end
    return need, max
end

CreateThread(function()
    Wait(5000)
    local need, max = requiredRiders()
    if R.minRiders > max then
        print(('^3[pup_camps]^7 raids need %d riders but a posse holds at most %d - clamped to %d'):format(R.minRiders, max, need))
    elseif R.minRiders == max then
        print(('^3[pup_camps]^7 raids need a FULL posse (%d riders)'):format(max))
    end
end)

local function posseOf(src)
    if not Integrations.running('pup-ui') then return nil end
    local ok, p = pcall(function() return exports['pup-ui']:GetPosse(src) end)
    if ok and type(p) == 'table' and p.inPosse then return p end
    return nil
end

local function posseMembers(src)
    local ok, list = pcall(function() return exports['pup-ui']:GetPosseMembers(src) end)
    if ok and type(list) == 'table' then return list end
    return { src }
end

local function crewList(run)
    local out = {}
    for s in pairs(run.crew) do out[#out + 1] = s end
    return out
end

local function tellCrew(run, msg, except)
    for s in pairs(run.crew) do
        if s ~= except and GetPlayerName(s) then Notify(s, msg) end
    end
end

local function clearAlerts(campId)
    local a = Alerts[campId]
    if not a then return end
    for _, s in ipairs(a.srcs) do
        if GetPlayerName(s) then TriggerClientEvent('pup_camps:cl:raidAlertClear', s, campId) end
    end
    Alerts[campId] = nil
end

-- end a run; reason is a locale key told to the crew (nil = silent)
local function endRun(campId, reason, opened)
    local run = RaidRuns[campId]
    if not run then return end
    RaidRuns[campId] = nil
    for s in pairs(run.crew) do
        if GetPlayerName(s) then
            TriggerClientEvent('pup_camps:cl:raidEnd', s, campId, opened == true)
            if reason then Notify(s, L(reason)) end
        end
    end
    if not opened then clearAlerts(campId) end
end
RaidEnd = endRun

local function addCrew(run, src)
    local p = Players[src]
    if not p or run.crew[src] then return end
    run.crew[src] = p.charid
    local camp = Camps[run.campId]
    local now = os.time()
    local phase = now < run.prepEnd and 'prep' or 'lock'
    local left = (phase == 'prep' and run.prepEnd or run.lockEnd) - now
    TriggerClientEvent('pup_camps:cl:raid', src, run.campId, phase, left, camp and camp.coords)
end

local function dropCrew(run, src, reason)
    if not run.crew[src] then return end
    run.crew[src] = nil
    if GetPlayerName(src) then
        TriggerClientEvent('pup_camps:cl:raidEnd', src, run.campId, false)
        if reason then Notify(src, L(reason)) end
    end
    if next(run.crew) == nil then
        endRun(run.campId, 'crew_wiped')
        return
    end
    if run.leader == src then
        run.leader = next(run.crew)
    end
end

Handle('raidStart', function(ctx, campId)
    if not R.enabled then return false end
    local camp = Camps[tonumber(campId) or -1]
    if not camp or camp.repo then return false end
    if RaidRuns[camp.id] or (RaidOpen[camp.id] and os.time() < RaidOpen[camp.id].untilTime) then
        return false, L('raid_running')
    end
    if R.cooldownStarts > 0 and camp.raid > 0 then return false, L('raid_cooldown') end
    if R.membersOnly and not ctx.camp then return false, L('raid_need_camp') end
    if ctx.camp == camp.id or RankOf(camp, ctx.charid, ctx.identifier) ~= nil or IsLeader(camp, ctx.charid) then
        return false, L('raid_own_camp')
    end
    for _, run in pairs(RaidRuns) do
        if run.crew[ctx.src] then return false, L('raid_running') end
    end
    if not AtCamp(ctx.src, camp) then return false, L('too_far') end
    local defenders = OnlineMembers(camp)
    if #defenders < R.minDefenders then return false, L('not_enough_defenders') end
    if not Integrations.running('pup-ui') then return false, L('raid_no_posse') end
    local need = requiredRiders()
    local posse = posseOf(ctx.src)
    local online = posse and tonumber(posse.online) or 1
    if online < need then return false, L('raid_riders', need, online) end

    local now = os.time()
    local run = {
        campId = camp.id, leader = ctx.src, leaderCharid = ctx.charid, leaderCamp = ctx.camp,
        posseId = posse and posse.id or nil, crew = {},
        prepEnd = now + R.prepMinutes * 60, lockEnd = now + (R.prepMinutes + R.lockpickMinutes) * 60,
        phaseSent = 'prep',
    }
    RaidRuns[camp.id] = run
    for _, s in ipairs(posseMembers(ctx.src)) do addCrew(run, s) end
    addCrew(run, ctx.src)
    tellCrew(run, L('raid_by_posse', ctx.name, camp.name), ctx.src)
    Notify(ctx.src, L('raid_started'))

    Alerts[camp.id] = { srcs = defenders, expires = now + (R.prepMinutes + R.lockpickMinutes + R.lootMinutes + R.alertExtraMin) * 60 }
    local warn = L('raid_warning', camp.name, R.prepMinutes)
    for _, s in ipairs(defenders) do
        NotifyBottom(s, warn, 15000)
        Notify(s, warn, 10000)
        TriggerClientEvent('pup_camps:cl:raidAlert', s, camp.id, camp.coords, Alerts[camp.id].expires - now)
    end

    RaidLog(camp, 'Raid Started', LogColour.purple, {
        { 'Raider', Who(ctx.src) }, { 'Posse', PosseNames(ctx.src) },
        { 'Defenders online', tostring(#defenders), true }, { 'Posse required', tostring(need), true },
    })
    return true
end, { gapMs = 3000 })

-- a crew member died or rode too far
Handle('raidOut', function(ctx, campId)
    local run = RaidRuns[tonumber(campId) or -1]
    if not run or not run.crew[ctx.src] then return false end
    dropCrew(run, ctx.src, 'raid_failed')
    return true
end, { gapMs = 500 })

-- before the minigame: is this player allowed to try right now?
Handle('raidPickCheck', function(ctx, campId)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false end
    local run = RaidRuns[camp.id]
    if not run then return false, L('raid_not_started') end
    if not run.crew[ctx.src] then return false, L('not_on_raid') end
    local now = os.time()
    if now < run.prepEnd then return false, L('camp_not_open') end
    if now >= run.lockEnd then
        endRun(camp.id, 'raid_window_over')
        return false
    end
    if (tonumber(exports.vorp_inventory:getItemCount(ctx.src, nil, R.lockpickItem)) or 0) < 1 then
        return false, L('need_lockpick')
    end
    if not NearPoint(ctx.src, camp.coords, R.pickDistance) then return false, L('too_far') end
    return true
end, { gapMs = 1000 })

Handle('raidPick', function(ctx, campId, success)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false end
    local run = RaidRuns[camp.id]
    if not run then return false, L('raid_not_started') end
    if not run.crew[ctx.src] then return false, L('not_on_raid') end
    local now = os.time()
    if now < run.prepEnd then return false, L('camp_not_open') end
    if now >= run.lockEnd then
        endRun(camp.id, 'raid_window_over')
        return false
    end
    if (tonumber(exports.vorp_inventory:getItemCount(ctx.src, nil, R.lockpickItem)) or 0) < 1 then
        return false, L('need_lockpick')
    end
    if not NearPoint(ctx.src, camp.coords, R.pickDistance) then return false, L('too_far') end
    -- every attempt uses a lockpick, success or not
    exports.vorp_inventory:subItem(ctx.src, R.lockpickItem, 1)
    if success ~= true then return false, L('raid_lockpick_broke') end
    -- re-check after the inventory call
    if RaidRuns[camp.id] ~= run or Camps[camp.id] ~= camp then return false end

    local chars = {}
    for _, cid in pairs(run.crew) do chars[cid] = true end
    local opener = posseOf(ctx.src)
    RaidOpen[camp.id] = {
        untilTime = now + R.lootMinutes * 60, chars = chars,
        posseId = opener and opener.id or run.posseId, opener = ctx.charid,
    }
    tellCrew(run, L('camp_open_go'), ctx.src)
    endRun(camp.id, nil, true)
    camp.raid = R.cooldownStarts
    Save(camp)
    Notify(ctx.src, L('box_unlocked'))
    RaidLog(camp, 'Camp Broken Open', LogColour.red, {
        { 'Opener', Who(ctx.src) }, { 'Posse', PosseNames(ctx.src) },
        { 'Open for', ('%d min'):format(R.lootMinutes), true }, { 'Stash at risk', ('%d stacks'):format(#camp.inventory), true },
    })
    local a = Alerts[camp.id]
    if a then a.expires = math.min(a.expires, RaidOpen[camp.id].untilTime) end
    PushCamp(camp)
    return true
end, { gapMs = 1500 })

Handle('raidTakeCash', function(ctx, campId)
    local camp = Camps[tonumber(campId) or -1]
    if not camp then return false end
    if RankOf(camp, ctx.charid, ctx.identifier) ~= nil or IsLeader(camp, ctx.charid) then return false end
    if not LootAllowed(camp, ctx.src, ctx.charid) then return false end
    if not AtCamp(ctx.src, camp) then return false, L('too_far') end
    local amount = math.floor(camp.cash)
    if amount <= 0 then return false, L('nothing_to_take') end
    camp.cash = U.round(camp.cash - amount, 2)
    if not GiveCash(ctx, amount) then
        camp.cash = U.round(camp.cash + amount, 2)
        return false
    end
    Save(camp)
    Notify(ctx.src, L('took_all', U.money(amount)))
    RaidLog(camp, 'Ledger Stolen', LogColour.red, {
        { 'Thief', Who(ctx.src) }, { 'Posse', PosseNames(ctx.src) }, { 'Amount', U.money(amount), true },
    })
    PushCamp(camp)
    return true
end, { gapMs = 1500 })

-- riders who leave the posse drop out; riders who join are added (only the raid's own posse)
AddEventHandler('pup-ui:posse:serverChanged', function(posseId, online)
    if type(online) ~= 'table' then return end
    for _, run in pairs(RaidRuns) do
        if run.posseId and run.posseId == posseId then
            local set = {}
            for _, s in ipairs(online) do set[tonumber(s)] = true end
            for _, s in ipairs(crewList(run)) do
                if not set[s] and s ~= run.leader then dropCrew(run, s, nil) end
            end
            if RaidRuns[run.campId] == run then
                for s in pairs(set) do addCrew(run, s) end
            end
        end
    end
end)

------------------------------------------------------------------------------ ticker

CreateThread(function()
    while true do
        Wait(R.resendSeconds * 1000)
        local now = os.time()
        for campId, run in pairs(RaidRuns) do
            for _, s in ipairs(crewList(run)) do
                if not GetPlayerName(s) then dropCrew(run, s, nil) end
            end
            if RaidRuns[campId] == run then
                if now >= run.lockEnd then
                    endRun(campId, 'raid_window_over')
                else
                    local phase = now < run.prepEnd and 'prep' or 'lock'
                    local left = (phase == 'prep' and run.prepEnd or run.lockEnd) - now
                    for s in pairs(run.crew) do
                        TriggerClientEvent('pup_camps:cl:raidTick', s, campId, phase, left)
                    end
                end
            end
        end
        for campId, open in pairs(RaidOpen) do
            if now >= open.untilTime then
                RaidOpen[campId] = nil
                clearAlerts(campId)
                StashPrune(campId)
                local camp = Camps[campId]
                if camp then PushCamp(camp) end
            end
        end
        for campId, a in pairs(Alerts) do
            if now >= a.expires then clearAlerts(campId) end
        end
    end
end)

------------------------------------------------------------------------------ cleanup hooks

function RaidsForget(src)
    for _, run in pairs(RaidRuns) do
        if run.crew[src] then dropCrew(run, src, nil) end
    end
end

function RaidsCampGone(campId)
    endRun(campId, nil)
    RaidOpen[campId] = nil
    Alerts[campId] = nil
    for id, run in pairs(RaidRuns) do
        if run.leaderCamp == campId then endRun(id, 'crew_wiped') end
    end
end

function RaidsMemberLost(charid, campId)
    for id, run in pairs(RaidRuns) do
        if R.membersOnly and run.leaderCharid == charid and run.leaderCamp == campId then
            endRun(id, 'crew_wiped')
        end
    end
end
