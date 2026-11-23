-- pup_hideouts | still parts missions: a wagon to stop, charge, blow and strip

local W <const> = Config.Wagons

HX.Wagons = {}
local jobs = {}      -- [hideoutId] = job
local jobOf = {}     -- [src] = hideoutId
local cooldown = {}  -- [hideoutId] = epoch end (memory only: a restart clears it)

function HX.Wagons.onCooldown(id) return (cooldown[id] or 0) > os.time() end
function HX.Wagons.cooldownEnd(id)
    local c = cooldown[id]
    if c and c > os.time() then return c end
    return nil
end

local function posseMembers(src)
    if GetResourceState('pup-ui') ~= 'started' then return { src } end
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

local function posseId(src)
    if GetResourceState('pup-ui') ~= 'started' then return nil end
    local ok, p = pcall(function() return exports['pup-ui']:GetPosse(src) end)
    return ok and type(p) == 'table' and p.inPosse and p.id or nil
end

local function jobData(job)
    local lvl = Config.WagonLevels[job.level]
    return {
        id = job.id, level = job.level, coords = U.plain(job.loc.coords), heading = job.loc.heading,
        model = W.model, escorts = lvl.escorts, weapons = W.weapons, endsAt = job.endsAt,
        netIds = job.netIds, state = job.state, followers = W.followers[job.level] or {},
    }
end

local function crewSend(job, event, ...)
    for s in pairs(job.crew) do
        if GetPlayerName(s) then TriggerClientEvent(event, s, ...) end
    end
end

local function endJob(id, msgKey)
    local job = jobs[id]
    if not job then return end
    jobs[id] = nil
    for s in pairs(job.crew) do
        jobOf[s] = nil
        if GetPlayerName(s) then
            TriggerClientEvent('pup_hideouts:jobEnd', s, id)
            if msgKey then HX.tip(s, L(msgKey)) end
        end
    end
end

local function addCrew(job, s)
    job.crew[s] = true
    jobOf[s] = job.id
    TriggerClientEvent('pup_hideouts:jobStart', s, jobData(job))
end

local function dropCrew(job, s)
    job.crew[s], job.down[s] = nil, nil
    jobOf[s] = nil
    if job.looter == s then job.looter = nil; if job.state == 'stripping' then job.state = 'blown' end end
    if job.charger == s and (job.state == 'charging' or job.state == 'fused') then
        job.charger = nil; job.state = 'spawned'
        crewSend(job, 'pup_hideouts:jobState', job.id, job.state)
    end
    if job.spawner == s and job.state == 'pending' then job.spawner = nil end
    if GetPlayerName(s) then TriggerClientEvent('pup_hideouts:jobEnd', s, job.id) end
end

local function allDown(job)
    local any = false
    for s in pairs(job.crew) do
        any = true
        if not job.down[s] then return false end
    end
    return any
end

HX.rpc('jobStart', function(src, id, level)
    local h = HX.memberInside(src, id)
    level = U.int(level)
    if not h or not level then return false end
    local lvl = Config.WagonLevels[level]
    if not lvl or #lvl.locations == 0 then return false end
    if not U.inList(U.jobsFor(HX.stillLevel(h)), level) then return false end
    if HX.Wagons.onCooldown(h.id) then HX.tip(src, L('job_cooldown')) return false end
    if jobs[h.id] then HX.tip(src, L('job_running')) return false end
    for _, s in ipairs(posseMembers(src)) do
        if jobOf[s] then HX.tip(src, L('job_running')) return false end
    end

    cooldown[h.id] = os.time() + W.cooldownMinutes * 60
    local job = {
        id = h.id, level = level, loc = lvl.locations[math.random(#lvl.locations)],
        crew = {}, down = {}, leader = src, posseId = posseId(src),
        endsAt = os.time() + W.windowMinutes * 60, state = 'pending',
        paidBy = {}, alerted = false,
    }
    jobs[h.id] = job
    for _, s in ipairs(posseMembers(src)) do addCrew(job, s) end
    if not job.crew[src] then addCrew(job, src) end
    HX.changed(h)
    Logs.send('Missions', 'Mission Started', ('Still parts mission %d'):format(level), 'missionStarted', src, {}, nil)
    return true
end, 2000)

----------------------------------------------------------------------------------------------------
-- spawning (one crew member's client spawns, the rest find the same entities)
----------------------------------------------------------------------------------------------------
HX.rpc('jobSpawnClaim', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or not job.crew[src] or job.state ~= 'pending' then return false end
    if HX.bucket(src) ~= 0 or U.dist(HX.pos(src), job.loc.coords) > W.spawnDistance + 25.0 then return false end
    if job.spawner and job.spawner ~= src and GetPlayerName(job.spawner)
        and (GetGameTimer() - (job.spawnAt or 0)) < W.spawnRetrySeconds * 1000 then
        return false
    end
    job.spawner, job.spawnAt = src, GetGameTimer()
    return true
end, 1000)

HX.on('jobSpawned', function(src, id, netIds)
    local job = jobs[tonumber(id)]
    if not job or job.spawner ~= src or job.state ~= 'pending' or type(netIds) ~= 'table' then return end
    local wagon = tonumber(netIds.wagon)
    -- a networked wagon must be the mission's wagon model, close to the mission spot
    if not W.soloOnly then
        local ent
        for _ = 1, 20 do
            ent = wagon and NetworkGetEntityFromNetworkId(wagon)
            if ent and ent ~= 0 and DoesEntityExist(ent) then break end
            ent = nil
            Wait(150)
        end
        if jobs[job.id] ~= job or job.spawner ~= src or job.state ~= 'pending' then return end
        local okModel = ent and GetEntityType(ent) == 2
            and (GetEntityModel(ent) & 0xFFFFFFFF) == (GetHashKey(W.model) & 0xFFFFFFFF)
        if not okModel or U.dist(GetEntityCoords(ent), job.loc.coords) > (W.spawnCheckRadius or 60.0) then
            job.spawner = nil -- let a crew member try again
            return
        end
    end
    job.netIds = { wagon = wagon, peds = {}, extra = {} }
    for _, n in ipairs(type(netIds.peds) == 'table' and netIds.peds or {}) do
        if tonumber(n) then job.netIds.peds[#job.netIds.peds + 1] = tonumber(n) end
    end
    for _, n in ipairs(type(netIds.extra) == 'table' and netIds.extra or {}) do
        if tonumber(n) then job.netIds.extra[#job.netIds.extra + 1] = tonumber(n) end
    end
    job.state = 'spawned'
    crewSend(job, 'pup_hideouts:jobEntities', job.id, job.netIds, job.spawner)
end, 1000)

HX.on('jobSpawnFailed', function(src, id)
    local job = jobs[tonumber(id)]
    if job and job.spawner == src and job.state == 'pending' then job.spawner = nil end
end, 1000)

-- where the wagon is now (server side when networked, else the start spot)
local function wagonPos(job)
    if job.netIds and job.netIds.wagon and not W.soloOnly then
        local ent = NetworkGetEntityFromNetworkId(job.netIds.wagon)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return GetEntityCoords(ent) end
    end
    if job.lastWagonPos then return job.lastWagonPos end
    return job.loc.coords
end

-- solo-only wagons are not networked: the spawner reports where it is
HX.on('jobWagonPos', function(src, id, coords)
    local job = jobs[tonumber(id)]
    local c = U.vec(coords)
    if not job or job.spawner ~= src or not c then return end
    if U.dist(c, HX.pos(src)) > W.failDistance then return end
    job.lastWagonPos = c
end, 900)

----------------------------------------------------------------------------------------------------
-- the charge
----------------------------------------------------------------------------------------------------
HX.rpc('jobPayCharge', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or not job.crew[src] then return false end
    -- only a wagon that is ready for a charge takes a stick; while someone else is charging,
    -- the fuse burns or it is already blown, a second press would eat dynamite for nothing
    if job.state ~= 'spawned' then return false end
    if not W.explosive.required then job.paidBy[src] = true return true end
    if job.paidBy[src] then return true end
    if not HX.removeItem(src, W.explosive.item, W.explosive.count) then HX.tip(src, L('need_explosives')) return false end
    job.paidBy[src] = true
    return true
end, 1000)

HX.rpc('jobChargeStart', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or not job.crew[src] or job.state ~= 'spawned' then return false end
    if U.dist(HX.pos(src), wagonPos(job)) > W.serverReach then HX.tip(src, L('too_far')) return false end
    if not job.paidBy[src] then HX.tip(src, L('need_explosives')) return false end
    job.state, job.charger = 'charging', src
    crewSend(job, 'pup_hideouts:jobState', job.id, job.state) -- the others' Plant prompt goes away
    if not job.alerted and W.alertPolice then
        job.alerted = true
        HX.policeAlert(wagonPos(job), L('wagon_reported'))
    end
    return true
end, 1000)

HX.on('jobChargeResult', function(src, id, ok)
    local job = jobs[tonumber(id)]
    if not job or job.charger ~= src or job.state ~= 'charging' then return end
    if ok ~= true then
        job.state, job.charger = 'spawned', nil
        job.paidBy[src] = nil -- the stick is wasted
        HX.tip(src, L('charge_ruined'))
        crewSend(job, 'pup_hideouts:jobState', job.id, job.state)
        return
    end
    job.fuseAt = os.time()
    job.state = 'fused'
end, 500)

HX.on('jobBlown', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or job.charger ~= src or job.state ~= 'fused' then return end
    if os.time() - (job.fuseAt or 0) < W.fuseSeconds - 1 then return end
    job.state = 'blown'
    job.paidBy[src] = nil
    crewSend(job, 'pup_hideouts:jobState', job.id, job.state)
    for s in pairs(job.crew) do HX.tip(s, L('rob_the_wagon')) end
end, 1000)

----------------------------------------------------------------------------------------------------
-- stripping
----------------------------------------------------------------------------------------------------
HX.rpc('jobRobClaim', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or not job.crew[src] then return false end
    if job.paid or job.state == 'stripped' then HX.tip(src, L('wagon_stripped_already')) return false end
    if job.state == 'stripping' and job.looter and job.looter ~= src then
        local l = job.looter
        if GetPlayerName(l) and job.crew[l] and not job.down[l] and HX.alive(l) then
            HX.tip(src, L('wagon_taken'))
            return false
        end
    elseif job.state ~= 'blown' and not (job.state == 'stripping' and job.looter == src) then
        return false
    end
    if U.dist(HX.pos(src), wagonPos(job)) > W.serverReach then HX.tip(src, L('too_far')) return false end
    job.state, job.looter, job.lootAt = 'stripping', src, os.time()
    return true
end, 1000)

HX.on('jobRobAbort', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or job.looter ~= src or job.state ~= 'stripping' then return end
    job.state, job.looter = 'blown', nil
    HX.tip(src, L('leave_wagon'))
end, 500)

HX.rpc('jobRobDone', function(src, id)
    local job = jobs[tonumber(id)]
    if not job or os.time() > job.endsAt then HX.tip(src, L('not_your_mission')) return false end
    if job.paid or job.state ~= 'stripping' or job.looter ~= src then HX.tip(src, L('not_your_mission')) return false end
    local need = 0.95 * W.stripSeconds * HX.perkMult(src, 'underground_speed') * HX.perkMult(src, 'dig_speed') - 5
    if os.time() - (job.lootAt or 0) < need then return false end
    if U.dist(HX.pos(src), wagonPos(job)) > W.completeReach then HX.tip(src, L('too_far')) return false end
    job.paid = true
    job.state = 'stripped'
    local haul = {}
    for _, r in ipairs(job.loc.rewards) do
        if math.random(1, 10) <= r.chance then
            if HX.canCarry(src, r.item, r.amount) and HX.addItem(src, r.item, r.amount) then
                HX.tip(src, L('you_got', r.label))
                haul[#haul + 1] = ('%s x%d'):format(r.label, r.amount)
            else
                HX.tip(src, L('no_space'))
            end
        end
    end
    HX.perkAward(src, 'wagonrob')
    local text = #haul > 0 and table.concat(haul, ', ') or 'nothing'
    print(('[pup_hideouts] wagon job for hideout #%d paid %s [%d]: %s'):format(job.id, GetPlayerName(src) or '?', src, text))
    Logs.send('Missions', 'Mission Completed', 'The wagon was stripped', 'missionCompleted', src, { { 'Haul', text, false } }, nil)
    endJob(job.id, 'wagon_done')
    return true
end, 1500)

----------------------------------------------------------------------------------------------------
-- crew upkeep
----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(2000)
        local now = os.time()
        for id, job in pairs(jobs) do
            if now > job.endsAt then
                endJob(id, 'job_expired')
            else
                local wpos = wagonPos(job)
                for s in pairs(job.crew) do
                    if not GetPlayerName(s) then
                        job.crew[s], job.down[s] = nil, nil
                        jobOf[s] = nil
                    elseif job.state ~= 'pending' then
                        local reason
                        if not HX.alive(s) then reason = 'failed'
                        elseif HX.bucket(s) == 0 and U.flat(HX.pos(s), wpos) > W.failDistance then reason = 'failed_away' end
                        if reason and not job.down[s] then
                            job.down[s] = reason
                            HX.bottom(s, L(reason))
                            if job.looter == s and job.state == 'stripping' then job.state, job.looter = 'blown', nil end
                        elseif not reason then
                            job.down[s] = nil
                        end
                    end
                end
                if jobs[id] and allDown(job) then endJob(id, 'crew_wiped_job') end
            end
        end
    end
end)

function HX.Wagons.posseChanged(pid, members)
    for _, job in pairs(jobs) do
        if job.posseId and job.posseId == pid then
            local now = {}
            for _, s in ipairs(type(members) == 'table' and members or {}) do
                s = tonumber(s)
                if s then now[s] = true end
            end
            for s in pairs(job.crew) do
                if not now[s] and s ~= job.leader then dropCrew(job, s) end
            end
            for s in pairs(now) do
                if not job.crew[s] and not jobOf[s] and GetPlayerName(s) then addCrew(job, s) end
            end
        end
    end
end

function HX.Wagons.dropped(src)
    local id = jobOf[src]
    local job = id and jobs[id]
    jobOf[src] = nil
    if not job then return end
    job.crew[src], job.down[src] = nil, nil
    if job.looter == src then job.looter = nil; if job.state == 'stripping' then job.state = 'blown' end end
    if job.charger == src and (job.state == 'charging' or job.state == 'fused') then
        job.charger = nil; job.state = 'spawned'
        crewSend(job, 'pup_hideouts:jobState', job.id, job.state)
    end
    if job.spawner == src and job.state == 'pending' then job.spawner = nil end
    if next(job.crew) == nil then jobs[id] = nil return end
    if job.leader == src then job.leader = next(job.crew) end
    if allDown(job) then endJob(id, 'crew_wiped_job') end
end

function HX.Wagons.forget(id)
    endJob(id)
    cooldown[id] = nil
end

-- vorp_admin world cleanup swept the mission wagon: the job goes back to pending, so the
-- crew's client spawns a fresh one when they are near (solo wagons are local and stay)
AddEventHandler('vorp_admin:worldCleanupDone', function()
    if W.soloOnly then return end
    for _, job in pairs(jobs) do
        local net = job.state ~= 'pending' and job.netIds and tonumber(job.netIds.wagon)
        if net and net > 0 then
            local ent = NetworkGetEntityFromNetworkId(net)
            if not ent or ent == 0 or not DoesEntityExist(ent) then
                job.state, job.netIds, job.spawner = 'pending', nil, nil
                job.charger, job.looter = nil, nil
                crewSend(job, 'pup_hideouts:jobState', job.id, job.state)
            end
        end
    end
end)
