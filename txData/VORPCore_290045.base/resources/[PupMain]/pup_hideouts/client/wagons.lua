-- pup_hideouts | still parts missions on the client: route, spawning, the charge, the strip

local W <const> = Config.Wagons

local N <const> = {
    blipForEntity = 0x23F74C2FDA6E7C61, -- BLIP_ADD_FOR_ENTITY
    blipModifier = 0x662D364ABF16DE2F,  -- BLIP_ADD_MODIFIER
    setBlipName = 0x9CB1A1623062F402,   -- _SET_BLIP_NAME
}

local job = nil -- { id, level, coords, heading, escorts, weapons, followers, state, net, spawner, own = {...}, blips }
local acting = false

local function setBusy(on) LocalPlayer.state:set('undergroundBusy', on == true, false) end

----------------------------------------------------------------------------------------------------
-- route and blips
----------------------------------------------------------------------------------------------------
local function addBlip(style, x, y, z, entity)
    local b
    if entity then b = Citizen.InvokeNative(N.blipForEntity, style, entity)
    else b = BlipAddForCoords(style, x, y, z) end
    if not b or b == 0 then return nil end
    SetBlipSprite(b, W.blipSprite, true)
    Citizen.InvokeNative(N.blipModifier, b, W.blipColor)
    Citizen.InvokeNative(N.setBlipName, b, CreateVarString(10, 'LITERAL_STRING', L('marked_location')))
    return b
end

local function clearMarks()
    if not job then return end
    for _, b in ipairs(job.blips or {}) do if DoesBlipExist(b) then RemoveBlip(b) end end
    job.blips = {}
    ClearGpsMultiRoute()
end

local function markRoute()
    local c = job.coords
    job.blips = job.blips or {}
    local b = addBlip(1664425300, c.x, c.y, c.z)
    if b then job.blips[#job.blips + 1] = b end
    ClearGpsMultiRoute()
    StartGpsMultiRoute(joaat('COLOR_RED'), true, true)
    AddPointToGpsMultiRoute(c.x, c.y, c.z)
    SetGpsMultiRouteRender(true)
end

----------------------------------------------------------------------------------------------------
-- entities
----------------------------------------------------------------------------------------------------
local function entityOf(net)
    net = tonumber(net)
    if not net or not NetworkDoesNetworkIdExist(net) then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

local function wagonEntity()
    if not job then return nil end
    if job.own and job.own.wagon and DoesEntityExist(job.own.wagon) then return job.own.wagon end
    if job.net and job.net.wagon then return entityOf(job.net.wagon) end
    return nil
end

local function deleteOwn()
    if not job or not job.own then return end
    for _, e in ipairs(job.own.all or {}) do
        if DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteEntity(e)
        end
    end
    job.own = nil
end

local relGroup = nil
local function hostileGroup()
    if relGroup then return relGroup end
    local _, g = AddRelationshipGroup('PUP_HIDEOUT_ESCORTS')
    relGroup = g
    SetRelationshipBetweenGroups(5, g, joaat('PLAYER'))
    SetRelationshipBetweenGroups(5, joaat('PLAYER'), g)
    SetRelationshipBetweenGroups(0, g, g)
    return g
end

local function armPed(ped)
    local w = job.weapons[math.random(#job.weapons)]
    GiveWeaponToPed(ped, joaat(w), 100, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    SetPedRelationshipGroupHash(ped, hostileGroup())
    SetPedCombatAttributes(ped, 46, true)
    SetPedFleeAttributes(ped, 0, false)
end

-- one wagon with its driver and escorts; returns the wagon or nil
local function spawnWagon(at, heading, networked, own)
    local wHash = HX.loadModel(W.model)
    if not wHash then return nil end
    local wagon = CreateVehicle(wHash, at.x, at.y, at.z, heading, networked, true, false, false)
    if not wagon or wagon == 0 then return nil end
    own.all[#own.all + 1] = wagon
    SetVehicleOnGroundProperly(wagon)
    for i = 0, W.escortsPerWagon do
        -- seat -1 is the driver (the first escort model), then the escorts
        local model = i == 0 and job.escorts[1] or job.escorts[math.random(#job.escorts)]
        local pHash = HX.loadModel(model)
        if pHash then
            local seat = i - 1
            local ped = CreatePedInsideVehicle(wagon, pHash, seat, networked, true, false)
            if not ped or ped == 0 then
                ped = CreatePed(pHash, at.x + 2.0, at.y + 2.0, at.z, heading, networked, true, false, false)
            end
            if ped and ped ~= 0 then
                Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SET_RANDOM_OUTFIT_VARIATION
                own.all[#own.all + 1] = ped
                own.peds[#own.peds + 1] = ped
                if i ~= 0 then armPed(ped) else SetPedRelationshipGroupHash(ped, hostileGroup()) end
            end
        end
    end
    local driver = GetPedInVehicleSeat(wagon, -1)
    if driver and driver ~= 0 then TaskVehicleDriveWander(driver, wagon, 10.0, 786603) end
    return wagon
end

local function spawnAll()
    local networked = not W.soloOnly
    local own = { all = {}, peds = {}, extra = {} }
    job.own = own
    local c = job.coords
    local wagon = spawnWagon(c, job.heading, networked, own)
    if not wagon then deleteOwn() return false end
    own.wagon = wagon
    local rad = math.rad(job.heading)
    for _, back in ipairs(job.followers or {}) do
        local at = vector3(c.x + math.sin(rad) * back, c.y - math.cos(rad) * back, c.z)
        local extra = spawnWagon(at, job.heading, networked, own)
        if extra then own.extra[#own.extra + 1] = extra end
    end
    if not networked then
        HX.send('jobSpawned', job.id, { wagon = 0, peds = {}, extra = {} })
        return true
    end
    local ids = { wagon = NetworkGetNetworkIdFromEntity(wagon), peds = {}, extra = {} }
    for _, p in ipairs(own.peds) do ids.peds[#ids.peds + 1] = NetworkGetNetworkIdFromEntity(p) end
    for _, e in ipairs(own.extra) do ids.extra[#ids.extra + 1] = NetworkGetNetworkIdFromEntity(e) end
    HX.send('jobSpawned', job.id, ids)
    return true
end

----------------------------------------------------------------------------------------------------
-- server events
----------------------------------------------------------------------------------------------------
RegisterNetEvent('pup_hideouts:jobStart', function(data)
    if type(data) ~= 'table' then return end
    if job then clearMarks(); deleteOwn() end
    job = {
        id = tonumber(data.id), level = tonumber(data.level), coords = U.vec(data.coords), heading = tonumber(data.heading) or 0.0,
        escorts = data.escorts or {}, weapons = data.weapons or {}, followers = data.followers or {},
        state = data.state or 'pending', net = data.netIds, blips = {}, told = false,
    }
    if not job.coords or #job.escorts == 0 or #job.weapons == 0 then job = nil return end
    markRoute()
end)

RegisterNetEvent('pup_hideouts:jobEntities', function(id, netIds, spawner)
    if not job or job.id ~= tonumber(id) then return end
    job.net = netIds
    job.state = 'spawned'
    if tonumber(spawner) ~= GetPlayerServerId(PlayerId()) then
        CreateThread(function()
            local t = GetGameTimer() + 15000
            local w = wagonEntity()
            while not w and GetGameTimer() < t and job do Wait(500); w = wagonEntity() end
            if w and job then
                local b = addBlip(W.wagonBlipStyle, 0, 0, 0, w)
                if b then job.blips[#job.blips + 1] = b end
            end
        end)
    elseif job.own and job.own.wagon then
        local b = addBlip(W.wagonBlipStyle, 0, 0, 0, job.own.wagon)
        if b then job.blips[#job.blips + 1] = b end
    end
end)

RegisterNetEvent('pup_hideouts:jobState', function(id, state)
    if job and job.id == tonumber(id) then job.state = state end
end)

RegisterNetEvent('pup_hideouts:jobEnd', function(id)
    if not job or job.id ~= tonumber(id) then return end
    clearMarks()
    deleteOwn()
    job = nil
    acting = false
    setBusy(false)
end)

----------------------------------------------------------------------------------------------------
-- the charge
----------------------------------------------------------------------------------------------------
local function crouch(propModel)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    local anim = W.crouchAnims[math.random(#W.crouchAnims)]
    if HX.loadDict(W.crouchDict) then TaskPlayAnim(ped, W.crouchDict, anim, 8.0, -8.0, -1, 1, 0, false, false, false) end
    local prop
    local hash = HX.loadModel(propModel)
    if hash then
        local c = GetEntityCoords(ped)
        prop = CreateObject(hash, c.x, c.y, c.z, true, true, false, false, false)
        AttachEntityToEntity(prop, ped, GetEntityBoneIndexByName(ped, 'SKEL_R_HAND'), 0.08, 0.02, -0.02, 0.0, 0.0, 0.0,
            true, true, false, true, 1, true, false, false)
        SetModelAsNoLongerNeeded(hash)
    end
    setBusy(true)
    return prop
end

local function standUp(prop)
    local ped = PlayerPedId()
    if prop and DoesEntityExist(prop) then DeleteObject(prop) end
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    setBusy(false)
end

local function chargeGame()
    local c = W.charge
    local rounds = math.random(c.roundsMin, c.roundsMax)
    local misses = 0
    for i = 1, rounds do
        local zone = math.max(c.minZone, c.zone - c.zoneStep * (i - 1))
        local speed = math.min(c.maxSpeed, c.speed + c.speedStep * (i - 1))
        local ok = HX.skillBar({
            style = 'default', icon = c.icon, orientation = 1, area_size = zone, perfect_area_size = c.perfect,
            speed = speed, moving_icon = true, icon_speed = c.iconSpeed, hint = L('charge_hint'),
        })
        if not ok then
            misses = misses + 1
            if misses > c.misses then return false end
            HX.tip(L('charge_slipped'))
        end
    end
    return true
end

local function plant()
    local wagon = wagonEntity()
    if not wagon then return end
    if GetEntitySpeed(wagon) > 0.5 then return HX.tip(L('wagon_not_stopped')) end
    for _, seat in ipairs({ -1, 0 }) do
        local p = GetPedInVehicleSeat(wagon, seat)
        if p and p ~= 0 and not IsEntityDead(p) then return HX.tip(L('wagon_not_empty')) end
    end
    local id = job.id
    local ok, paid = HX.call('jobPayCharge', 5000, id)
    if not ok then return HX.tip(L('no_answer')) end
    if not paid then return end
    local answered, allowed = HX.call('jobChargeStart', 5000, id)
    if not answered then return HX.tip(L('no_answer')) end
    if not allowed then return end
    local prop = crouch(W.dynamiteProp)
    local won = chargeGame()
    standUp(prop)
    HX.send('jobChargeResult', id, won)
    if not won then return end
    HX.tip(L('charge_set', W.fuseSeconds))
    HX.progress(L('dynamite_timer'), W.fuseSeconds * 1000)
    Wait(W.fuseSeconds * 1000)
    wagon = wagonEntity()
    if wagon then
        for door = 0, 3 do SetVehicleDoorBroken(wagon, door, true) end
        local c = GetEntityCoords(wagon)
        AddExplosion(c.x, c.y, c.z, W.explosionType, 1.0, true, false, 1.0)
    end
    HX.send('jobBlown', id)
end

----------------------------------------------------------------------------------------------------
-- stripping the wagon
----------------------------------------------------------------------------------------------------
local function stripSeconds()
    local base = W.stripSeconds
    if GetResourceState('pup-perks') ~= 'started' then return base end
    local ok, timed = pcall(function() return exports['pup-perks']:Timed(base * 1000, 'underground_speed') end)
    local secs = ok and tonumber(timed) and timed / 1000 or base
    -- never shorter than the server will accept
    local ok2, mu = pcall(function() return exports['pup-perks']:Mult('underground_speed') end)
    local ok3, md = pcall(function() return exports['pup-perks']:Mult('dig_speed') end)
    local floor = 0.95 * base * (ok2 and tonumber(mu) or 1.0) * (ok3 and tonumber(md) or 1.0)
    return math.max(secs, floor)
end

local function rob()
    local id = job.id
    local ok, claimed = HX.call('jobRobClaim', 5000, id)
    if not ok then return HX.tip(L('no_answer')) end
    if not claimed then return end
    local secs = stripSeconds()
    local prop = crouch(W.bagProp)
    HX.progress(L('taking_items'), math.floor(secs * 1000))
    HX.bottom(L('backspace_stops'), math.floor(secs * 1000))
    local untilMs = GetGameTimer() + math.floor(secs * 1000)
    local gaveUp = false
    while GetGameTimer() < untilMs do
        Wait(0)
        if IsControlJustPressed(0, Config.Keys.cancel) or IsDisabledControlJustPressed(0, Config.Keys.cancel)
            or HX.dead() or not job or job.id ~= id then
            gaveUp = true
            break
        end
    end
    standUp(prop)
    if gaveUp then
        HX.progressCancel()
        if job and job.id == id then
            HX.send('jobRobAbort', id)
        end
        return
    end
    Wait(1000)
    HX.call('jobRobDone', 8000, id)
end

----------------------------------------------------------------------------------------------------
-- the job loop: idle checks once a second, prompts every frame only near the wagon
----------------------------------------------------------------------------------------------------
local spawnTryAt = 0

CreateThread(function()
    while true do
        local sleep = 1000
        if job and not HX.insideId then
            if not job.told then
                job.told = true
                HX.bottom(L('wagon_to_hit'), 8000)
            end
            local pos = HX.pos()
            -- spawning
            if job.state == 'pending' and not job.own and GetGameTimer() >= spawnTryAt
                and U.dist(pos, job.coords) <= W.spawnDistance then
                spawnTryAt = GetGameTimer() + W.spawnRetrySeconds * 1000
                local id = job.id
                CreateThread(function()
                    local ok, mine = HX.call('jobSpawnClaim', 4000, id)
                    if ok and mine and job and job.id == id and not job.own then
                        if not spawnAll() then HX.send('jobSpawnFailed', id) end
                    end
                end)
            end
            -- solo wagons are not networked: report where it is
            if W.soloOnly and job.own and job.own.wagon and DoesEntityExist(job.own.wagon) then
                local w = GetEntityCoords(job.own.wagon)
                if GetGameTimer() >= (job.posAt or 0) then
                    job.posAt = GetGameTimer() + 1000
                    HX.send('jobWagonPos', job.id, { x = w.x, y = w.y, z = w.z })
                end
            end
            local wagon = (job.state == 'spawned' or job.state == 'blown') and wagonEntity()
            if wagon and not acting and not HX.menuOpen and U.dist(pos, GetEntityCoords(wagon)) <= W.promptDistance then
                sleep = 0
                if job.state == 'spawned' then
                    if HX.prompt(L('title_wagon'), L('plant_explosive')) then
                        acting = true
                        CreateThread(function() plant(); acting = false end)
                    end
                elseif HX.prompt(L('title_wagon'), L('rob_cart')) then
                    acting = true
                    CreateThread(function() rob(); acting = false end)
                end
            end
        end
        Wait(sleep)
    end
end)

-- vorp_admin world cleanup swept the networked mission wagon: forget it (the server puts
-- the job back to pending) so a fresh one is spawned when the crew is near again
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    if not job or W.soloOnly then return end
    Wait(1500) -- the server's jobState 'pending' comes first when it reset the job
    if not job or job.state ~= 'pending' or wagonEntity() then return end
    if not job.own and not job.net then return end
    deleteOwn()
    job.net = nil
    clearMarks()
    markRoute()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if job then clearMarks(); deleteOwn() end
    setBusy(false)
end)
