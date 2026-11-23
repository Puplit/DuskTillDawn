-- pup_camps | supply and delivery runs on the client: blips, routes, enemies, wagons

Missions = {}

local MC = Config.Missions
local supplyNets = {}        -- [netId] = true: listed supply wagons
local deliveryNets = {}      -- [netId] = { dest, arrived }
local run = nil              -- this player's run: { kind, campId, spot, blip, enemies = {}, wagonNet, phase }
local posseRuns = {}         -- [netId] = { destBlip, wagonBlip, expires }
local wagonBlips = {}        -- [blip] = true: supply wagon blips still on the map
local GROUP <const> = GetHashKey('PUP_CAMPS_BANDITS')

------------------------------------------------------------------------------ enemies

local function spawnEnemies(list)
    AddRelationshipGroup('PUP_CAMPS_BANDITS')
    SetRelationshipBetweenGroups(5, GROUP, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), GROUP)
    local out = {}
    for _, e in ipairs(list or {}) do
        local model = LoadModel(e[5])
        if model then
            local ped = CreatePed(model, e[1] + 0.0, e[2] + 0.0, e[3] + 0.0, 0.0, true, true, false, false)
            SetModelAsNoLongerNeeded(model)
            if ped and ped ~= 0 then
                N(0x283978A15512B2FE, ped, true)
                SetPedRelationshipGroupHash(ped, GROUP)
                N(0x5E3BDDBCB83F3D84, ped, GetHashKey(e[4]), 500, true, false, 0, false, 0.5, 1.0, 752097756, false, 0.0, false)
                if e[6] and e[6] ~= 0 then
                    local hm = LoadModel(e[6])
                    if hm then
                        local horse = CreatePed(hm, e[1] + 1.5, e[2] + 0.0, e[3] + 0.0, 0.0, true, true, false, false)
                        SetModelAsNoLongerNeeded(hm)
                        if horse and horse ~= 0 then
                            N(0x283978A15512B2FE, horse, true)
                            N(0x028F76B6E78246EB, ped, horse, -1, true)
                            out[#out + 1] = { ped = horse, horse = true }
                        end
                    end
                end
                TaskCombatPed(ped, PlayerPedId(), 0, 16)
                local blip = MC.enemyBlips and BlipEntity(ped) or nil
                out[#out + 1] = { ped = ped, blip = blip }
            end
        end
    end
    return out
end

local function enemiesLeft(list)
    local n = 0
    for _, e in ipairs(list) do
        if not e.horse and DoesEntityExist(e.ped) and not IsPedDeadOrDying(e.ped, true) then
            n = n + 1
        elseif e.blip then
            DropBlip(e.blip)
            e.blip = nil
        end
    end
    return n
end

local function clearEnemies(list)
    for _, e in ipairs(list or {}) do
        DropBlip(e.blip)
        if DoesEntityExist(e.ped) then SetEntityAsNoLongerNeeded(e.ped) end
    end
end

------------------------------------------------------------------------------ run state

local function endRun(msg)
    local r = run
    if not r then return end
    run = nil
    DropBlip(r.blip)
    DropBlip(r.wagonBlip)
    ClearRoute()
    clearEnemies(r.enemies)
    if msg then Notify(msg) end
end

local function abandon()
    local r = run
    if not r then return end
    endRun(L('mission_lost'))
    CreateThread(function() Request('missionAbandon', r.wagonNet) end)
end

local function inSeat(net)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return false end
    if net and NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) ~= net then return false end
    return GetPedInVehicleSeat(veh, -1) == ped, veh
end

------------------------------------------------------------------------------ supply runs

local function supplyLoop(r)
    CreateThread(function()
        local spot = r.spot
        while run == r do
            local wait = 1000
            local pos = PedPos()
            local d = U.dist3(pos, spot)
            if r.phase == 'travel' then
                if IsDeadOrDying() then abandon() break end
                if d <= MC.arriveDistance then
                    r.phase = 'fight'
                    Request('supplyPermit')
                    if run ~= r then break end
                    r.enemies = spawnEnemies(r.enemyList)
                end
            elseif r.phase == 'fight' then
                wait = 500
                if IsDeadOrDying() or d > MC.leaveDistance then abandon() break end
                if enemiesLeft(r.enemies) == 0 then
                    r.phase = 'wagon'
                    DropBlip(r.blip)
                    ClearRoute()
                    Request('supplyPermit')
                    local model = LoadModel(MC.wagonModel)
                    local veh = model and CreateVehicle(model, spot.x + 0.0, spot.y + 0.0, spot.z + 0.0, 0.0, true, false, false, false) or 0
                    if model then SetModelAsNoLongerNeeded(model) end
                    local net = NetOf(veh, 3000)
                    if net == 0 or not Request('supplyWagon', net) then
                        DeleteEnt(veh)
                        endRun(L('delivery_failed'))
                        break
                    end
                    SetVehicleOnGroundProperly(veh)
                    r.wagonBlip = BlipEntity(veh, L('supply_wagon_blip'))
                    Notify(L('supply_wagon_go'), 10000)
                    -- the server now owns the wagon's fate; the run on this side is done
                    run = nil
                    clearEnemies(r.enemies)
                    local blip = r.wagonBlip
                    if blip then
                        wagonBlips[blip] = true
                        CreateThread(function()
                            while DoesEntityExist(veh) and supplyNets[net] and wagonBlips[blip] do Wait(2000) end
                            wagonBlips[blip] = nil
                            DropBlip(blip)
                        end)
                    end
                    break
                end
            end
            Wait(wait)
        end
    end)
end

local function startSupply(campId)
    if run then return Notify(L('on_mission')) end
    local res = Ask('supplyStart', campId)
    if type(res) ~= 'table' then return end
    local spot = res.spot
    run = { kind = 'supply', campId = campId, spot = spot, enemyList = res.enemies, enemies = {}, phase = 'travel' }
    run.blip = BlipCoords(MC.blipSprite, spot, L('mission_blip'))
    Route(spot)
    Notify(L('go_to_marker'))
    supplyLoop(run)
end

------------------------------------------------------------------------------ delivery runs

local function deliveryLoop(r)
    CreateThread(function()
        while run == r do
            local wait = 1000
            local pos = PedPos()
            local d = U.dist3(pos, r.spot)
            local veh = NetworkDoesNetworkIdExist(r.wagonNet) and NetworkGetEntityFromNetworkId(r.wagonNet) or 0
            if veh == 0 or not DoesEntityExist(veh) then endRun(L('mission_lost')) break end
            if r.phase == 'travel' then
                if IsDeadOrDying() then abandon() break end
                local seated = inSeat(r.wagonNet)
                if seated and d <= MC.arriveDistance then
                    local res = Request('deliveryArrived', r.wagonNet)
                    if type(res) == 'table' then
                        r.phase = 'fight'
                        DropBlip(r.blip)
                        ClearRoute()
                        r.enemies = spawnEnemies(res.enemies)
                    end
                end
            elseif r.phase == 'fight' or r.phase == 'sell' then
                wait = r.phase == 'sell' and 0 or 500
                if IsDeadOrDying() or d > MC.leaveDistance then abandon() break end
                if r.phase == 'fight' and enemiesLeft(r.enemies) == 0 then r.phase = 'sell' end
                if r.phase == 'sell' and inSeat(r.wagonNet) then
                    DrawHint(L('press_sell'), 0.88)
                    if IsControlJustReleased(0, Config.Keys.handIn) then
                        local campId = State.myCamp
                        local net = r.wagonNet
                        FadeOut(500)
                        DeleteEnt(veh)
                        local ok = Ask('deliverySell', campId, net)
                        FadeIn(500)
                        endRun(nil)
                        if not ok then Notify(L('mission_lost')) end
                        break
                    end
                end
            end
            Wait(wait)
        end
    end)
end

local function beginDelivery(campId, wagonNet, spot, owned)
    run = { kind = 'delivery', campId = campId, spot = spot, wagonNet = wagonNet, enemies = {}, phase = 'travel', owned = owned }
    run.blip = BlipCoords(MC.blipSprite, spot, L('delivery_blip'))
    Route(spot)
    Notify(L('delivery_go'), 10000)
    deliveryLoop(run)
end

local function callDelivery(campId, size, pos, heading)
    if run then return Notify(L('on_mission')) end
    if not Ask('wagonPermit', campId, 'delivery', size) then return end
    local model = LoadModel(MC.wagonModel)
    if not model then return Notify(L('delivery_failed')) end
    local veh = CreateVehicle(model, pos.x, pos.y, pos.z, heading, true, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not veh or veh == 0 then return Notify(L('delivery_failed')) end
    SetVehicleOnGroundProperly(veh)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    local net = NetOf(veh, MC.wagonListSeconds * 1000)
    local res = net ~= 0 and Request('deliveryStart', campId, size, net) or nil
    if type(res) ~= 'table' then
        DeleteEnt(veh)
        return Notify(L('delivery_failed'))
    end
    beginDelivery(campId, net, res.spot, true)
end

------------------------------------------------------------------------------ trapper rows

function Missions.rows(campId, info)
    local v = State.camps[campId]
    local rows = {}
    if not v or v.repo then return rows end
    local supplyCd = (tonumber(info.supplyLeft) or 0) > 0
    rows[#rows + 1] = {
        label = L('supply_start'), description = supplyCd and L('on_cooldown') or L('supply_start_desc'), disabled = supplyCd,
        onSelect = function()
            Menu.closeAll()
            startSupply(campId)
        end,
    }
    local deliveryCd = (tonumber(info.deliveryLeft) or 0) > 0
    local stock = math.floor(tonumber(info.stock) or 0)
    for _, size in ipairs({ 'small', 'medium', 'large' }) do
        local need = MC.sizes[size]
        local short = stock < need
        rows[#rows + 1] = {
            label = L('delivery_' .. size),
            description = deliveryCd and L('on_cooldown') or (short and L('needs_stock', need, stock) or L('delivery_desc', need)),
            disabled = deliveryCd or short,
            onSelect = function()
                Menu.closeAll()
                Calling.start(campId, function(pos, heading) callDelivery(campId, size, pos, heading) end)
            end,
        }
    end
    return rows
end

------------------------------------------------------------------------------ listed wagons

RegisterNetEvent('pup_camps:cl:wagons', function(supply, delivery)
    supplyNets = {}
    for _, n in ipairs(supply or {}) do supplyNets[n] = true end
    deliveryNets = {}
    for _, d in ipairs(delivery or {}) do deliveryNets[d.net] = { dest = d.dest, arrived = d.arrived } end
end)

RegisterNetEvent('pup_camps:cl:runOver', function(reason)
    if run and reason ~= 'sold' then
        endRun(reason == 'lost' and L('mission_lost') or nil)
    end
end)

-- hand-in of a supply wagon at a trapper, and taking over a delivery wagon
Interact.add(function(pos, ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped or not NetworkGetEntityIsNetworked(veh) then return nil end
    local net = NetworkGetNetworkIdFromEntity(veh)
    if supplyNets[net] then
        local v = MyCamp()
        if not v or not World.isRendered(v.id) then return nil end
        for _, p in ipairs(v.furni or {}) do
            if p.active and p.functional == 'hunting' and p.coords and U.dist3(pos, p.coords) <= MC.handInDistance then
                return { dist = 0.1, title = L('supply_wagon_blip'), keys = { { control = Config.Keys.handIn, label = L('press_deliver'), fn = function()
                    FadeOut(500)
                    Ask('handIn', v.id, net)
                    FadeIn(500)
                end } } }
            end
        end
    end
    return nil
end)

-- anyone who climbs onto a listed delivery wagon that has not arrived takes the run on their side
CreateThread(function()
    while true do
        Wait(1500)
        if State.started and not run then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and NetworkGetEntityIsNetworked(veh) then
                local net = NetworkGetNetworkIdFromEntity(veh)
                local d = deliveryNets[net]
                if d and not d.arrived and d.dest then beginDelivery(State.myCamp, net, d.dest, false) end
            end
        end
    end
end)

------------------------------------------------------------------------------ posse deliveries

local function clearPosse(net)
    local p = posseRuns[net]
    if not p then return end
    posseRuns[net] = nil
    DropBlip(p.destBlip)
    DropBlip(p.wagonBlip)
end

RegisterNetEvent('pup_camps:cl:posseDelivery', function(net, spot)
    if type(spot) ~= 'table' then return end
    clearPosse(net)
    local p = { expires = GetGameTimer() + MC.posseBlipMin * 60000 }
    p.destBlip = BlipCoords(MC.blipSprite, spot, L('delivery_blip'))
    posseRuns[net] = p
    CreateThread(function()
        while posseRuns[net] == p do
            local veh = NetworkDoesNetworkIdExist(net) and NetworkGetEntityFromNetworkId(net) or 0
            if veh ~= 0 and DoesEntityExist(veh) then
                if not p.wagonBlip then p.wagonBlip = BlipEntity(veh, L('delivery_wagon_blip')) end
            elseif p.wagonBlip then
                clearPosse(net)
                break
            end
            if GetGameTimer() > p.expires then clearPosse(net) break end
            Wait(2000)
        end
    end)
end)

RegisterNetEvent('pup_camps:cl:deliveryOver', function(net)
    clearPosse(net)
end)

------------------------------------------------------------------------------ cleanup

OnState('stop', function()
    if run then
        DropBlip(run.blip)
        DropBlip(run.wagonBlip)
        ClearRoute()
        for _, e in ipairs(run.enemies or {}) do
            DropBlip(e.blip)
            if DoesEntityExist(e.ped) then DeleteEntity(e.ped) end
        end
        run = nil
    end
    for net in pairs(posseRuns) do clearPosse(net) end
    for blip in pairs(wagonBlips) do DropBlip(blip) end
    wagonBlips = {}
end)

-- vorp_admin world cleanup is about to delete the bandits: a supply run must not read
-- that as the fight being won (the server ends the run and returns its cooldown)
RegisterNetEvent('vorp_admin:worldCleanup', function()
    if run and run.kind == 'supply' then endRun(L('mission_lost')) end
end)

OnState('mycamp', function()
    if run and run.owned then abandon() end
end)
