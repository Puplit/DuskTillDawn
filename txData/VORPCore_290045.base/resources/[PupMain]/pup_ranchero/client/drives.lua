-- pup_ranchero | herding and sale drives on the client (the server settles everything that matters)

Drive = { active = false }
local D = nil                -- the running drive
local lastStrayAt = -1e9     -- stray and wolf cooldowns carry over between drives
local lastWolfAt = -1e9
local lastCallAt = -1e9      -- /onme cooldown (client only)

local H, S, HZ = Config.Herding, Config.Sales, Config.Hazards

------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------
local function v3(p) return vector3(p.x, p.y, p.z) end

local function pedPos(ped) return GetEntityCoords(ped) end

local function goTo(ped, p)
    FreezeEntityPosition(ped, false)
    TaskGoToCoordAnyMeans(ped, p.x, p.y, p.z, 1.6, 0, false, 0, 0.0)
end

local function follow(ped, target, i)
    FreezeEntityPosition(ped, false)
    local ang = (i or 1) * 1.1
    TaskFollowToOffsetOfEntity(ped, target, math.cos(ang) * 2.5, -2.0 + math.sin(ang), 0.0, 1.8, -1, 1.5, true, false, false, false, false, false)
end

local function halt(ped)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
end

local function goalPoint()
    return D.goals[D.goalIdx]
end

local function removeGoalBlip()
    if D and D.goalBlip then RemoveBlip(D.goalBlip) D.goalBlip = nil end
end

local function setGoal(idx)
    D.goalIdx = idx
    removeGoalBlip()
    local p = D.goals[idx]
    if not p then return end
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.x, p.y, p.z)
    SetBlipSprite(b, GetHashKey(Config.Blips.goalSprite), true)
    SetBlipScale(b, 0.6)
    local name = idx < #D.goals and L('stageBlip', Locale.ordinals[idx] or tostring(idx)) or L('enclosure')
    Citizen.InvokeNative(0x9CB1A1623062F402, b, name)
    D.goalBlip = b
    TipBottom(Locale.stages[idx] or '', 8000)
    for _, a in ipairs(D.animals) do
        if a.alive and not a.stray and not a.frozen then goTo(a.ped, p) end
    end
end

local function aliveAnimals()
    local list = {}
    for _, a in ipairs(D.animals) do
        if a.alive then list[#list + 1] = a end
    end
    return list
end

local function clearDrive()
    if not D then Drive.active = false return end
    local d = D
    D = nil
    Drive.active = false
    if d.goalBlip then RemoveBlip(d.goalBlip) end
    for _, a in ipairs(d.animals) do
        if a.alive then DeletePedSafe(a.ped) elseif DoesEntityExist(a.ped) then SetEntityAsNoLongerNeeded(a.ped) end
    end
    DeletePedSafe(d.dog)
    for _, w in ipairs(d.wolves or {}) do
        if w.blip then RemoveBlip(w.blip) end
        DeletePedSafe(w.ped)
    end
end

Cleanups[#Cleanups + 1] = function()
    if Activity and Activity.kind == 'herd' then EndActivity() end
    clearDrive()
end

------------------------------------------------------------------------------
-- quality as the client sees it (the server only lets it go down)
------------------------------------------------------------------------------
local function roadQuality(alive, arrived)
    local lv = Config.Livestock
    local q = D.startQ * (lv.deathFactor ^ D.deaths)
    if arrived < alive then q = q * (1 - lv.strayPenalty * (alive - arrived)) end
    return math.max(0, q)
end

------------------------------------------------------------------------------
-- ending
------------------------------------------------------------------------------
local function finishSuccess()
    if not D or D.finishing then return end
    D.finishing = true
    local alive = #aliveAnimals() + D.arrived
    local rq = roadQuality(alive, D.arrived)
    local report
    if D.kind == 'herd' then
        report = { arrived = D.arrived, quality = U.herdQuality(rq, D.arrived, D.dist, D.env), deaths = D.deaths }
    else
        report = { arrived = D.arrived, quality = rq, deaths = D.deaths }
    end
    TipBottom(L('working'))
    Deadlines[D.kind == 'herd' and 'herd' or 'sell'] = -1
    CreateThread(function()
        local ok = Call('driveFinish', report)
        if not ok and D then
            clearDrive()
            TipBottom(L('failedPrefix'))
        end
    end)
end

local function finishFail()
    if not D or D.finishing then return end
    D.finishing = true
    local alive = #aliveAnimals()
    local left = alive > 1 and U.round(alive / 2) or 0
    local q = D.startQ * (Config.Livestock.deathFactor ^ D.deaths) / 2
    local report = { failed = true, left = 0, quality = 0 }
    if left > 0 and q > 0 then report.left, report.quality = left, q end
    if left > 0 then TipBottom(L('survivedPart', left, D.deaths)) else TipBottom(L('allDied')) end
    CreateThread(function()
        local ok = Call('driveFinish', report)
        if not ok and D then clearDrive() end
    end)
end

-- the server's verdict is what the player sees
RegisterNetEvent('pup_ranchero:driveOver', function(data)
    if type(data) ~= 'table' then return end
    clearDrive()
    if data.msg then TipBottom(tostring(data.msg), 8000) end
    if data.ok and data.reward then
        CreateThread(function() Call('claimReward', data.animal, data.count) end)
    end
end)

------------------------------------------------------------------------------
-- deaths and kill reports
------------------------------------------------------------------------------
-- the dog stops chasing an animal that is gone (dead or delivered) and comes back to heel
local function releaseDog(a)
    if D.dogChasing ~= a then return end
    D.dogChasing = nil
    if D.dog and DoesEntityExist(D.dog) then
        TaskFollowToOffsetOfEntity(D.dog, PlayerPedId(), 1.0, -1.0, 0.0, 2.0, -1, 2.0, true, false, false, false, false, false)
    end
end

local function onDeath(a)
    a.alive = false
    D.deaths = D.deaths + 1
    releaseDog(a)
    if DoesEntityExist(a.ped) then
        SetEntityAsNoLongerNeeded(a.ped) -- the body stays in the world
        if Config.Livestock.killReward then
            local killer = GetPedSourceOfDeath(a.ped)
            if killer and killer ~= 0 and IsEntityAVehicle(killer) then killer = GetPedInVehicleSeat(killer, -1) end
            if killer and killer ~= 0 and killer ~= PlayerPedId() and IsPedAPlayer(killer) then
                TipBottom(L('herdAnimalDied'))
                Send('driveKill', D.animal, GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer)))
            end
        end
    end
end

------------------------------------------------------------------------------
-- hazards: strays and wolves
------------------------------------------------------------------------------
local strayIndex = 0

local function tryStray()
    local cd = D.kind == 'herd' and HZ.strayCooldownHerd or HZ.strayCooldownSale
    if GetGameTimer() - lastStrayAt < cd then return end
    local n = #D.animals
    for _ = 1, n do
        strayIndex = strayIndex % n + 1
        local a = D.animals[strayIndex]
        if a.alive and not a.frozen and not a.stray then
            if math.random(1, HZ.strayRollMax) > HZ.strayAbove then
                lastStrayAt = GetGameTimer()
                local from = pedPos(a.ped)
                local sx, sy = (math.random(0, 1) * 2 - 1), (math.random(0, 1) * 2 - 1)
                local off = HZ.strayDistance / math.sqrt(2)
                a.stray = { from = { x = from.x, y = from.y, z = from.z } }
                goTo(a.ped, { x = from.x + sx * off, y = from.y + sy * off, z = from.z })
                if D.dog and DoesEntityExist(D.dog) then
                    D.dogChasing = a
                    TaskGoToEntity(D.dog, a.ped, -1, 2.0, 2.5, 0, 0)
                end
            end
            return
        end
    end
end

local function tryWolves()
    if GetGameTimer() - lastWolfAt < HZ.wolfCooldown then return end
    if math.random(1, HZ.wolfRollMax) <= HZ.wolfAbove then return end
    local live = aliveAnimals()
    local n = math.floor(#live / 2)
    if n < 1 then return end
    lastWolfAt = GetGameTimer()
    local me = GetEntityCoords(PlayerPedId())
    for i = 1, n do
        local ang = math.random() * math.pi * 2
        local pos = { x = me.x + math.cos(ang) * HZ.wolfDistance, y = me.y + math.sin(ang) * HZ.wolfDistance, z = me.z }
        local _, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 10.0, false)
        if gz and gz ~= 0 then pos.z = gz end
        local wolf = SpawnPed(HZ.wolfModel, pos, 0.0, true)
        if wolf then
            local target = live[((i - 1) % #live) + 1]
            TaskCombatPed(wolf, target.ped, 0, 16)
            local blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, Config.Blips.wolfStyle, wolf) -- blip for entity
            D.wolves[#D.wolves + 1] = { ped = wolf, blip = blip }
        end
    end
end

------------------------------------------------------------------------------
-- the drive loop
------------------------------------------------------------------------------
local function nearAnyBarn(p)
    for _, b in ipairs(Config.SaleBarns) do
        if not b.disabled and #(p - vector3(b.x, b.y, b.z)) <= S.deliveryRadius then return true end
    end
    return false
end

local function arrive(a)
    a.alive = false
    a.arrived = true
    D.arrived = D.arrived + 1
    releaseDog(a)
    DeletePedSafe(a.ped)
    D.closingUntil = GetGameTimer() + H.closingSeconds * 1000
end

local function logicTick(now)
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)

    -- deaths first
    for _, a in ipairs(D.animals) do
        if a.alive and (not DoesEntityExist(a.ped) or IsEntityDead(a.ped)) then onDeath(a) end
    end

    local closing = D.closingUntil ~= nil
    if closing and now >= D.closingUntil then return finishSuccess() end
    if not closing then
        if IsEntityDead(ped) then return finishFail() end
        if now > D.deadline then return finishFail() end
    end

    local live = aliveAnimals()
    if #live == 0 then
        if D.arrived > 0 then return finishSuccess() end
        return finishFail()
    end

    local dog = D.dog and DoesEntityExist(D.dog) and D.dog or nil
    local dogPos = dog and GetEntityCoords(dog) or nil
    local calling = D.callUntil and now < D.callUntil

    if D.callUntil and not calling then
        D.callUntil = nil
        for _, a in ipairs(live) do
            if not a.stray then
                if D.kind == 'herd' then goTo(a.ped, goalPoint()) else follow(a.ped, ped, a.i) end
            end
        end
    end

    -- strays: caught by the player or the dog, walked back, rejoin after a while
    for _, a in ipairs(live) do
        local s = a.stray
        if s then
            local ap = pedPos(a.ped)
            if not s.returning then
                if #(ap - me) <= HZ.strayCatch or (dogPos and #(ap - dogPos) <= HZ.strayCatch) then
                    s.returning = true
                    s.rejoinAt = now + HZ.strayRejoinMs
                    goTo(a.ped, s.from)
                    if dog and D.dogChasing == a then
                        D.dogChasing = nil
                        TaskFollowToOffsetOfEntity(dog, ped, 1.0, -1.0, 0.0, 2.0, -1, 2.0, true, false, false, false, false, false)
                    end
                end
            elseif now >= s.rejoinAt then
                a.stray = nil
                if D.kind == 'herd' then goTo(a.ped, goalPoint()) else follow(a.ped, ped, a.i) end
            end
        end
    end

    if D.kind == 'herd' then
        local goal = goalPoint()
        local gv = v3(goal)
        local final = D.goalIdx == #D.goals
        local nudge = now >= (D.nextNudge or 0)
        if nudge then D.nextNudge = now + H.nudgeMs end
        local allThere, counted = true, 0
        for _, a in ipairs(live) do
            if not a.stray then
                local ap = pedPos(a.ped)
                local dGoal = #(ap - gv)
                if final and dGoal <= H.checkDistance / 2 then
                    arrive(a)
                elseif not calling then
                    local dP = #(ap - me)
                    local dD = dogPos and #(ap - dogPos) or math.huge
                    if not a.frozen and dP > H.freezeFromPlayer and dD > H.freezeFromDog then
                        a.frozen = true
                        halt(a.ped)
                    elseif a.frozen and (dP < H.resumeNearPlayer or dD < H.resumeNearDog) then
                        a.frozen = false
                        goTo(a.ped, goal)
                    elseif nudge and not a.frozen then
                        goTo(a.ped, goal)
                    end
                    counted = counted + 1
                    if dGoal > H.checkDistance / 2 then allThere = false end
                end
            end
        end
        if not final and not calling and counted > 0 and allThere then
            Send('driveCheckpoint', D.goalIdx)
            setGoal(D.goalIdx + 1)
        end
    else
        local followNow = now >= (D.nextFollow or 0)
        if followNow then D.nextFollow = now + S.followMs end
        for _, a in ipairs(live) do
            local ap = pedPos(a.ped)
            if nearAnyBarn(ap) then
                arrive(a)
            elseif not a.stray then
                local dP = #(ap - me)
                if not a.frozen and dP > S.freezeFromPlayer then
                    a.frozen = true
                    halt(a.ped)
                elseif a.frozen and dP < S.resumeNearPlayer then
                    a.frozen = false
                    follow(a.ped, ped, a.i)
                elseif followNow and not a.frozen then
                    follow(a.ped, ped, a.i)
                end
            end
        end
    end

    -- dog heels when it drifts
    if dog and not D.dogChasing and now >= (D.nextDogCheck or 0) then
        D.nextDogCheck = now + H.dogCheckMs
        if #(dogPos - me) > H.dogHeelDistance then
            TaskFollowToOffsetOfEntity(dog, ped, 1.0, -1.0, 0.0, 2.0, -1, 2.0, true, false, false, false, false, false)
        end
    end

    -- hazards (no failures and no new trouble during the closing countdown)
    if not closing and now - D.liveAt >= HZ.startAfter * 1000 then
        if now >= (D.nextStrayRoll or 0) then
            D.nextStrayRoll = now + HZ.strayEveryMs
            tryStray()
        end
        if D.kind == 'herd' and now >= (D.nextWolfRoll or 0) then
            D.nextWolfRoll = now + HZ.wolfEveryMs
            tryWolves()
        end
    end
end

local function runDrive()
    local d = D
    CreateThread(function()
        local nextLogic = 0
        while D == d and not d.finishing do
            Wait(0)
            local now = GetGameTimer()
            local target = d.closingUntil or d.deadline
            DrawTxt(L('timer', math.max(0, math.ceil((target - now) / 1000))), 0.5, 0.04, 0.42)
            if d.kind == 'sell' and not d.closingUntil then DrawTxt(L('leadToBarn'), 0.5, 0.08, 0.32) end
            if now >= nextLogic then
                nextLogic = now + 250
                logicTick(now)
            end
        end
    end)
end

------------------------------------------------------------------------------
-- spawning
------------------------------------------------------------------------------
local function spawnHerd()
    local ped = PlayerPedId()
    local me = GetEntityCoords(ped)
    local lv = Config.Livestock
    local size = lv.scaleMin + (math.min(D.startQ, lv.maxQuality) / lv.maxQuality) * (lv.scaleMax - lv.scaleMin)
    local spawned = 0
    for i = 1, D.count do
        local animalPed
        for _ = 1, 5 do
            local ang = math.random() * math.pi * 2
            local pos = { x = me.x + math.cos(ang) * 3.0, y = me.y + math.sin(ang) * 3.0, z = me.z }
            animalPed = SpawnPed(D.model, pos, math.random(0, 359) + 0.0, true)
            if animalPed then break end
            Wait(1000)
        end
        if animalPed then
            spawned = spawned + 1
            SetBlockingOfNonTemporaryEvents(animalPed, true)
            if D.outfit then Citizen.InvokeNative(0x77FF8D35EEC6BBC4, animalPed, D.outfit, false) end -- fixed outfit preset
            if lv.scaleByQuality then Citizen.InvokeNative(0x25ACFC650B65C538, animalPed, size + 0.0) end -- ped scale
            D.animals[#D.animals + 1] = { ped = animalPed, alive = true, i = i }
        end
    end
    D.unspawned = D.count - spawned
    if spawned == 0 then return false end

    if D.dogModel then
        for _ = 1, 5 do
            local dog = SpawnPed(D.dogModel, { x = me.x + 1.0, y = me.y - 1.0, z = me.z }, 0.0, true)
            if dog then
                SetBlockingOfNonTemporaryEvents(dog, true)
                TaskFollowToOffsetOfEntity(dog, ped, 1.0, -1.0, 0.0, 2.0, -1, 2.0, true, false, false, false, false, false)
                D.dog = dog
                break
            end
            Wait(1000)
        end
    end
    return spawned
end

function StartDriveRequest(kind, animal)
    if Drive.active or D then return end
    local res = Call(kind == 'herd' and 'herdStart' or 'sellStart', animal)
    if type(res) ~= 'table' then return end
    Menu.closeAll()
    local goals = {}
    if kind == 'herd' and res.trail then
        for i, idx in ipairs(U.ROUTE) do goals[i] = res.trail[idx] end
    end
    D = {
        kind = kind, animal = res.animal, count = res.count, model = res.model, outfit = res.outfit,
        dogModel = res.dog, startQ = tonumber(res.quality) or 0, env = tonumber(res.env) or 0,
        dist = tonumber(res.dist) or 1, limit = tonumber(res.limit) or H.timeLimit, ranch = res.coords,
        goals = goals, goalIdx = 1, animals = {}, wolves = {}, deaths = 0, arrived = 0, unspawned = 0,
    }
    Drive.active = true
    if D.dogModel then TipBottom(L('dogTip'), 8000) end
    local d = D
    StartActivity({
        kind = 'herd',
        tick = function(a)
            if D ~= d then EndActivity() return end
            local dist = d.ranch and #(GetEntityCoords(PlayerPedId()) - v3(d.ranch)) or 0
            if dist <= Config.Reach.herdSpawn then
                DrawTxt(L('distRead', U.round(dist)), 0.5, 0.08, 0.36)
                a.pill, a.ready = L('pillHerd'), true
            else
                DrawTxt(L('outOfRange'), 0.5, 0.08, 0.36, true, 230, 120, 100)
            end
        end,
        interact = function()
            EndActivity()
            local spawned = spawnHerd()
            if D ~= d then return end
            if not spawned then
                TipBottom(L('spawnFailed'))
                Send('driveCancel')
                clearDrive()
                return
            end
            local ok = Call('driveLive', spawned)
            if not ok or D ~= d then
                Send('driveCancel')
                clearDrive()
                return
            end
            d.live = true
            d.liveAt = GetGameTimer()
            d.deadline = d.liveAt + d.limit * 1000
            if d.kind == 'herd' then
                setGoal(1)
            else
                TipBottom(L('leadToBarn'), 8000)
                for _, an in ipairs(d.animals) do follow(an.ped, PlayerPedId(), an.i) end
            end
            runDrive()
        end,
        cancel = function()
            if D == d and not d.live then
                Send('driveCancel')
                clearDrive()
            end
        end,
    })
end

------------------------------------------------------------------------------
-- /onme: the dog brings the herd to you (live herding drive with a dog, no closing countdown)
------------------------------------------------------------------------------
RegisterCommand(Config.Dog.command, function()
    if not D or not D.live or D.finishing or D.kind ~= 'herd' then return end
    if not (D.dog and DoesEntityExist(D.dog)) or D.closingUntil then return end
    local now = GetGameTimer()
    if now - lastCallAt < Config.Dog.cooldown * 1000 then return end
    lastCallAt = now
    D.callUntil = now + Config.Dog.duration * 1000
    local me = GetEntityCoords(PlayerPedId())
    for _, a in ipairs(aliveAnimals()) do
        if not a.stray then
            a.frozen = false
            ClearPedTasks(a.ped)
            goTo(a.ped, { x = me.x, y = me.y, z = me.z })
        end
    end
end, false)
