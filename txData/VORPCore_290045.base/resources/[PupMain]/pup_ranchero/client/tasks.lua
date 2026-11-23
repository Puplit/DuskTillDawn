-- pup_ranchero | chores, milking / eggs, spot registration and trail recording

local REACH = Config.Reach

local function markerAt(c)
    Citizen.InvokeNative(0x2A32FAA57B937173, 0x94FDAE17, c.x, c.y, c.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        1.2, 1.2, 0.2, 120, 200, 120, 110, false, false, 2, false, nil, nil, false)
end

local function distTo(c)
    local p = GetEntityCoords(PlayerPedId())
    return #(p - vector3(c.x, c.y, c.z))
end

-- frozen and safe while a round is played, then released
local function playRound(game, overrideKey, label, roundsKind, anim)
    Working = true
    local ped = PlayerPedId()
    SetFrozen(true)
    SetEntityInvincible(ped, true)
    local score = PlayMinigame(game, overrideKey, label, roundsKind)
    local secs = tonumber(Config.Chores.workSeconds) or 0
    if secs > 0 and anim then
        if anim.scenario then
            TaskStartScenarioInPlace(ped, GetHashKey(anim.scenario), secs * 1000, true, false, false, false)
        elseif anim.dict and LoadAnim(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.name, 4.0, -4.0, secs * 1000, 1, 0, false, false, false)
        end
        Wait(secs * 1000)
        ClearPedTasks(ped)
    end
    SetEntityInvincible(ped, false)
    SetFrozen(false)
    Working = false
    return score
end

function LoadAnim(dict)
    RequestAnimDict(dict)
    local stop = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > stop then return false end
        Wait(50)
    end
    return true
end

------------------------------------------------------------------------------
-- chores
------------------------------------------------------------------------------
function StartChoreActivity(name)
    local chore = Ranch.me and Ranch.me.chores and Ranch.me.chores[name]
    if not chore then return end
    local spot = chore.loc
    local def = Config.Chores.list[name]
    StartActivity({
        kind = 'chore',
        tick = function(a)
            markerAt(spot)
            local d = distTo(spot)
            if d > REACH.taskStart then
                Text3D(vector3(spot.x, spot.y, spot.z + 0.6), L('goToTask', U.round(d)))
            else
                a.pill, a.ready = L('pillTask'), true
            end
        end,
        interact = function()
            local ok = Call('choreStart', name)
            EndActivity()
            if not ok then return end
            local score = playRound(def.art, name, U.choreLabel(name), 'chore', { scenario = def.scenario })
            Call('choreFinish', name, score)
        end,
    })
end

------------------------------------------------------------------------------
-- pen animals (one cow, or four chickens)
------------------------------------------------------------------------------
local penAnimals = { milk = nil, eggs = nil } -- kind -> { peds = {}, releaseAt }

function PenAnimalsOut(kind)
    return penAnimals[kind] ~= nil
end

function RemovePenAnimals(kind)
    local set = penAnimals[kind]
    penAnimals[kind] = nil
    if not set then return end
    for _, ped in ipairs(set.peds) do DeletePedSafe(ped) end
end

Cleanups[#Cleanups + 1] = function()
    RemovePenAnimals('milk')
    RemovePenAnimals('eggs')
end

-- vorp_admin world cleanup: the pen cow is swept, so drop a round not yet started
-- and remove the (local) chickens with it
RegisterNetEvent('vorp_admin:worldCleanup', function()
    local a = Activity
    if a and (a.kind == 'milk' or a.kind == 'eggs') and not a.running then
        EndActivity()
        Send('produceCancel')
    end
    RemovePenAnimals('milk')
    RemovePenAnimals('eggs')
end)

local function spawnPenAnimals(kind, loc)
    RemovePenAnimals(kind)
    local model = kind == 'milk' and Config.Produce.cowModel or Config.Produce.chickenModel
    local count = kind == 'milk' and 1 or Config.Produce.chickens
    local set = { peds = {} }
    for i = 1, count do
        local off = kind == 'milk' and { x = 0.0, y = 0.0 } or { x = math.cos(i * 1.57) * 1.2, y = math.sin(i * 1.57) * 1.2 }
        local ped = SpawnPed(model, { x = loc.x + off.x, y = loc.y + off.y, z = loc.z }, math.random(0, 359) + 0.0, kind == 'milk')
        if ped then
            SetBlockingOfNonTemporaryEvents(ped, true)
            set.peds[#set.peds + 1] = ped
            local frozenPed = ped
            SetTimeout(1000, function()
                if DoesEntityExist(frozenPed) then FreezeEntityPosition(frozenPed, true) end
            end)
        end
        if kind == 'eggs' and i < count then Wait(1000) end
    end
    if #set.peds == 0 then return nil end
    penAnimals[kind] = set
    return set
end

-- watch the pen cow; report a death once (own kill or another player's)
local function watchCow(set)
    local cow = set.peds[1]
    CreateThread(function()
        while penAnimals.milk == set and DoesEntityExist(cow) do
            if IsEntityDead(cow) then
                local killer = GetPedSourceOfDeath(cow)
                if killer and killer ~= 0 and IsEntityAVehicle(killer) then killer = GetPedInVehicleSeat(killer, -1) end
                if killer == PlayerPedId() then
                    Send('penKilled', 0)
                elseif killer and killer ~= 0 and IsPedAPlayer(killer) then
                    Send('penKilled', GetPlayerServerId(NetworkGetPlayerIndexFromPed(killer)))
                end
                if Activity and Activity.kind == 'milk' then
                    EndActivity()
                    Send('produceCancel')
                end
                penAnimals.milk = nil
                SetEntityAsNoLongerNeeded(cow)
                return
            end
            Wait(1000)
        end
    end)
end

-- after a completed round the animals stay until the cooldown ends, unless in use
CreateThread(function()
    while true do
        Wait(5000)
        for kind, set in pairs(penAnimals) do
            if set and set.releaseAt and GetGameTimer() >= set.releaseAt and not (Activity and Activity.kind == kind) then
                RemovePenAnimals(kind)
            end
        end
    end
end)

function StartProduceActivity(kind)
    local res = Call('produceStart', kind)
    if type(res) ~= 'table' or not res.loc then return end
    local set = spawnPenAnimals(kind, res.loc)
    if not set then
        TipBottom(L('spawnFailed'))
        Send('produceCancel')
        return
    end
    if kind == 'milk' then watchCow(set) end
    local isMilk = kind == 'milk'
    local loc = res.loc
    local function giveUp()
        RemovePenAnimals(kind)
        Send('produceCancel')
    end
    StartActivity({
        kind = kind,
        expiresIn = Config.Produce.clientSession * 1000,
        tick = function(a)
            local target = loc
            local first = set.peds[1]
            if first and DoesEntityExist(first) then
                local c = GetEntityCoords(first)
                target = { x = c.x, y = c.y, z = c.z }
            end
            local d = distTo(target)
            if d > REACH.taskStart then
                Text3D(vector3(target.x, target.y, target.z + 1.0), isMilk and L('goToCow', U.round(d)) or L('goToChickens', U.round(d)))
            else
                a.pill, a.ready = isMilk and L('pillMilk') or L('pillEggs'), true
            end
        end,
        interact = function()
            local anim = isMilk and Config.Produce.milkAnim or Config.Produce.eggAnim
            local score = playRound(isMilk and 'pails' or 'basket', isMilk and 'milk' or 'eggs', isMilk and L('milkShort') or L('eggShort'), kind, anim)
            EndActivity()
            local ok = Call('produceFinish', kind, score)
            local s = penAnimals[kind]
            if s then
                if ok then
                    local cd = isMilk and Config.Produce.milkCooldown or Config.Produce.eggCooldown
                    s.releaseAt = GetGameTimer() + cd * 1000
                else
                    RemovePenAnimals(kind)
                end
            end
        end,
        cancel = giveUp,
        expire = giveUp,
    })
end

------------------------------------------------------------------------------
-- registering a spot (chore spots, pen, coop)
------------------------------------------------------------------------------
function StartSpotRegistration(label, extra, onPick)
    StartActivity({
        kind = 'spot',
        tick = function(a)
            DrawTxt(L('registerHint', label), 0.5, 0.08, 0.42)
            if extra then DrawTxt(extra, 0.5, 0.12, 0.34) end
            local p = MyPos()
            markerAt(p)
            a.pill, a.ready = L('pillRegister'), true
        end,
        interact = function()
            local pos = MyPos()
            EndActivity()
            onPick(pos)
        end,
    })
end

------------------------------------------------------------------------------
-- trail recording: four points, each 12-100 m (flat) from the previous one
------------------------------------------------------------------------------
function StartTrailRecording()
    if not Ranch.me or not Ranch.me.coords then return end
    local points = {}
    local lim = Config.Herding.trail
    StartActivity({
        kind = 'trail',
        noHint = true,
        tick = function(a)
            DrawTxt(L('trailStop'), 0.5, 0.06, 0.38)
            DrawTxt(L('trailPoint', #points + 1), 0.5, 0.10, 0.42)
            if Pressed(Config.Keys.stop) then
                EndActivity()
                TipBottom(L('trailStopped'))
                return
            end
            local prev = points[#points] or Ranch.me.coords
            local d = U.dist2(prev, MyPos())
            if d <= lim.minLeg then
                DrawTxt(L('trailTooClose'), 0.5, 0.14, 0.36, true, 230, 120, 100)
            elseif d >= lim.maxLeg then
                DrawTxt(L('outOfRange'), 0.5, 0.14, 0.36, true, 230, 120, 100)
            else
                DrawTxt(L('distRead', U.round(d)), 0.5, 0.14, 0.36)
                a.pill, a.ready = L('pillRegister'), true
            end
        end,
        interact = function()
            points[#points + 1] = MyPos()
            if #points >= 4 then
                EndActivity()
                Call('setTrail', points)
            end
        end,
    })
end
