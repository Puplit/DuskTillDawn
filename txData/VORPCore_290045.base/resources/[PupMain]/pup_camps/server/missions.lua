-- pup_camps | supply and delivery missions

MissionCooldowns = {}  -- [campId] = { supply = untilTs, delivery = untilTs }

local Pools    = { supply = {}, delivery = {} }   -- [kind][region][index] = mission (nil while in use)
local InUse    = {}                               -- ["kind:region:index"] = since (os.time)
local Runs     = {}                               -- [src] = run
local Supplies = {}                               -- [netId] = { supplies, items, created }
local Deliveries = {}                             -- [netId] = run (delivery)

local MCFG = Config.Missions

------------------------------------------------------------------------------ pools

local function buildPools()
    for region, list in pairs(CampSupplyMissions or {}) do
        Pools.supply[region] = {}
        for i, m in ipairs(list) do
            -- the reward is rolled once per resource start, not per run
            local lo, hi = m.supplies[1], m.supplies[2] or m.supplies[1]
            Pools.supply[region][i] = {
                region = region, index = i, spot = m.spot, enemies = m.enemies, items = m.items or {},
                supplies = math.random(math.min(lo, hi), math.max(lo, hi)),
            }
        end
    end
    for region, list in pairs(CampDeliveryMissions or {}) do
        Pools.delivery[region] = {}
        for i, m in ipairs(list) do
            Pools.delivery[region][i] = { region = region, index = i, spot = m.spot, enemies = m.enemies }
        end
    end
end

local free = {}  -- [kind][region][index] = true when free
local function initFree()
    for kind, regions in pairs(Pools) do
        free[kind] = {}
        for region, list in pairs(regions) do
            free[kind][region] = {}
            for i in pairs(list) do free[kind][region][i] = true end
        end
    end
end

local function freeList(kind, region)
    local out = {}
    for i in pairs(free[kind][region] or {}) do out[#out + 1] = i end
    table.sort(out)
    return out
end

local function takeMission(kind, region, index)
    free[kind][region][index] = nil
    InUse[('%s:%s:%d'):format(kind, region, index)] = os.time()
    return Pools[kind][region][index]
end

local function giveBack(kind, region, index)
    if not (kind and region and index) then return end
    local key = ('%s:%s:%d'):format(kind, region, index)
    if InUse[key] then
        InUse[key] = nil
        free[kind][region][index] = true
    end
end

------------------------------------------------------------------------------ helpers

local function nearestRegion(pos)
    local best, bestD
    for key, anchor in pairs(CampMissionRegions) do
        local d = U.dist3(pos, anchor)
        if not bestD or d < bestD then best, bestD = key, d end
    end
    return best
end

local function cooldown(campId, kind)
    local cd = MissionCooldowns[campId]
    return cd and (cd[kind] or 0) > os.time()
end

local function setCooldown(campId, kind, minutes)
    MissionCooldowns[campId] = MissionCooldowns[campId] or {}
    MissionCooldowns[campId][kind] = os.time() + minutes * 60
end

local function permitModels(src, mission)
    pcall(Integrations.allowSpawn, src, MCFG.wagonModel, 120000)
    for _, e in ipairs(mission.enemies or {}) do
        pcall(Integrations.allowSpawn, src, e[5], 120000)
        if e[6] and e[6] ~= 0 then pcall(Integrations.allowSpawn, src, e[6], 120000) end
    end
end

local function pushWagons(target)
    local supply, delivery = {}, {}
    for net in pairs(Supplies) do supply[#supply + 1] = net end
    for net, run in pairs(Deliveries) do
        delivery[#delivery + 1] = { net = net, dest = run.spot, arrived = run.arrived == true }
    end
    TriggerClientEvent('pup_camps:cl:wagons', target or -1, supply, delivery)
end
PushWagons = pushWagons

local function entityOf(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

local function isWagonModel(ent)
    return U.h32(GetEntityModel(ent)) == U.h32(MCFG.wagonModel)
end

local function posseOthers(src)
    if not Integrations.running('pup-ui') then return {} end
    local ok, list = pcall(function() return exports['pup-ui']:GetPosseMembers(src) end)
    if not ok or type(list) ~= 'table' then return {} end
    local out = {}
    for _, s in ipairs(list) do if s ~= src then out[#out + 1] = s end end
    return out
end

local function endDelivery(run, reason)
    if not run then return end
    if run.wagon then Deliveries[run.wagon] = nil end
    if not run.arrived then giveBack('delivery', run.region, run.index) end
    for _, s in ipairs(run.posse or {}) do
        if GetPlayerName(s) then TriggerClientEvent('pup_camps:cl:deliveryOver', s, run.wagon) end
    end
    if run.owner and Runs[run.owner] == run then Runs[run.owner] = nil end
    if run.owner and GetPlayerName(run.owner) then TriggerClientEvent('pup_camps:cl:runOver', run.owner, reason) end
    pushWagons()
end

local function endRun(src, reason)
    local run = Runs[src]
    if not run then return end
    if run.kind == 'delivery' then
        endDelivery(run, reason)
    else
        giveBack('supply', run.region, run.index)
        Runs[src] = nil
        if GetPlayerName(src) then TriggerClientEvent('pup_camps:cl:runOver', src, reason) end
    end
end
EndRunOf = endRun

------------------------------------------------------------------------------ supply runs

Handle('supplyStart', function(ctx, campId)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return nil, why end
    if Runs[ctx.src] then return nil, L('on_mission') end
    if cooldown(camp.id, 'supply') then return nil, L('on_cooldown') end
    local region = nearestRegion(camp.coords)
    local list = region and freeList('supply', region) or {}
    if #list == 0 then return nil, L('no_missions') end
    local index = list[math.random(1, #list)]
    local m = takeMission('supply', region, index)
    Runs[ctx.src] = { kind = 'supply', region = region, index = index, campId = camp.id, started = os.time(), owner = ctx.src, spot = m.spot }
    setCooldown(camp.id, 'supply', MCFG.supplyCooldownMin)
    permitModels(ctx.src, m)
    CampLog(camp, 'missions', 'Supply Run Started', LogColour.blue, {
        { 'Who', Who(ctx.src, camp) }, { 'Next run in', ('%d min'):format(MCFG.supplyCooldownMin), true },
    }, { actor = ctx.src })
    return { spot = m.spot, enemies = m.enemies }
end, { gapMs = 2000 })

-- the spawn guard permit lasts 30 s at most, so it is renewed on arrival and before the wagon spawns
Handle('supplyPermit', function(ctx)
    local run = Runs[ctx.src]
    if not run or run.kind ~= 'supply' or run.wagon then return false end
    if not NearPoint(ctx.src, run.spot, MCFG.leaveDistance) then return false end
    permitModels(ctx.src, Pools.supply[run.region][run.index])
    return true
end, { gapMs = 1000 })

-- the player cleared the enemies and their client spawned the supply wagon
Handle('supplyWagon', function(ctx, netId)
    local run = Runs[ctx.src]
    if not run or run.kind ~= 'supply' or run.wagon then return false end
    if os.time() - run.started > MCFG.maxRunHours * 3600 then return false end
    if not NearPoint(ctx.src, run.spot, MCFG.acceptRadius) then return false end
    local ent = entityOf(netId)
    if not ent or not isWagonModel(ent) then return false end
    local m = Pools.supply[run.region][run.index]
    netId = tonumber(netId)
    Supplies[netId] = { supplies = m.supplies, items = m.items, created = os.time() }
    run.wagon = netId
    giveBack('supply', run.region, run.index)
    Runs[ctx.src] = nil
    pushWagons()
    return true
end, { gapMs = 1000 })

local function trapperNear(camp, pos, dist)
    for _, p in pairs(camp.furni) do
        if p.active and p.functional == 'hunting' and U.dist3(p.coords, pos) <= dist then return true end
    end
    return false
end

Handle('handIn', function(ctx, campId, netId)
    netId = tonumber(netId)
    local w = netId and Supplies[netId]
    if not w then return false end
    local camp, why = Can(ctx, campId, nil)
    if not camp then return false, why end
    local veh = entityOf(netId)
    if not veh then Supplies[netId] = nil pushWagons() return false end
    if GetPedInVehicleSeat(veh, -1) ~= GetPlayerPed(ctx.src) then return false end
    local c = GetEntityCoords(veh)
    if not trapperNear(camp, { x = c.x, y = c.y, z = c.z }, MCFG.handInDistance + 5.0) then return false end

    -- read the perk BEFORE the wagon is consumed, and never let a perk error eat the wagon
    local okM, mult = pcall(Integrations.perkMult, ctx.src, Config.Economy.perkSupply)
    mult = okM and tonumber(mult) or 1.0
    if not mult or mult ~= mult or mult < 0.1 or mult > 10 then mult = 1.0 end
    Supplies[netId] = nil
    DeleteEntity(veh)
    local base = w.supplies
    local gained = math.floor(base * mult + 0.5)
    camp.supply = camp.supply + gained
    Save(camp)
    if gained > base then Notify(ctx.src, L('wagon_boss', gained - base)) end
    for _, it in ipairs(w.items or {}) do
        if exports.vorp_inventory:canCarryItem(ctx.src, it.name, it.count) then
            exports.vorp_inventory:addItem(ctx.src, it.name, it.count)
        end
    end
    pcall(Integrations.perkAward, ctx.src, Config.Economy.xpSupply)
    Notify(ctx.src, L('supplies_delivered', gained, camp.supply))
    CampLog(camp, 'missions', 'Supply Wagon Collected', LogColour.green, {
        { 'Who', Who(ctx.src, camp) },
        { 'Supplies gained', tostring(gained) .. (gained > base and (' (Wagon Boss +' .. (gained - base) .. ')') or ''), true },
        { 'Camp supplies', tostring(camp.supply), true },
    }, { actor = ctx.src })
    pushWagons()
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ delivery runs

-- may this player spawn a wagon right now? (spawn guard permit + early refusal)
Handle('wagonPermit', function(ctx, campId, kind, size)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return false, why end
    if kind == 'delivery' then
        if Runs[ctx.src] then return false, L('on_mission') end
        if cooldown(camp.id, 'delivery') then return false, L('on_cooldown') end
        local need = MCFG.sizes[size]
        if not need then return false end
        if camp.stock < need then return false, L('needs_stock', need, math.floor(camp.stock)) end
        pcall(Integrations.allowSpawn, ctx.src, MCFG.wagonModel, 15000)
        return true
    elseif kind == 'hunting' then
        if not Config.HuntingWagon.enabled or camp.hwagon ~= 1 then return false end
        pcall(Integrations.allowSpawn, ctx.src, Config.HuntingWagon.model, 15000)
        return true
    end
    return false
end, { gapMs = 1000 })

local function rankedRegions(pos)
    local list = {}
    for key, anchor in pairs(CampMissionRegions) do
        if #freeList('delivery', key) > 0 then list[#list + 1] = { key = key, d = U.dist3(pos, anchor) } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

Handle('deliveryStart', function(ctx, campId, size, netId)
    local camp, why = Can(ctx, campId, nil)
    if not camp then return nil, why end
    if Runs[ctx.src] then return nil, L('on_mission') end
    if cooldown(camp.id, 'delivery') then return nil, L('on_cooldown') end
    local need = MCFG.sizes[size]
    if not need then return nil end
    if camp.stock < need then return nil, L('needs_stock', need, math.floor(camp.stock)) end
    local ent = entityOf(netId)
    if not ent or not isWagonModel(ent) then return nil, L('delivery_failed') end
    if not NearPoint(ctx.src, (function() local c = GetEntityCoords(ent) return { x = c.x, y = c.y, z = c.z } end)(), 15.0) then
        return nil, L('delivery_failed')
    end
    local ranks = rankedRegions(camp.coords)
    if #ranks == 0 then return nil, L('no_missions') end
    local want = size == 'small' and 1 or (size == 'medium' and 2 or 3)
    local pick = ranks[math.min(want, #ranks)]
    local list = freeList('delivery', pick.key)
    local index = list[math.random(1, #list)]
    local m = takeMission('delivery', pick.key, index)
    local largest = 0
    for _, v in pairs(MCFG.sizes) do if v > largest then largest = v end end
    netId = tonumber(netId)
    local run = {
        kind = 'delivery', region = pick.key, index = index, campId = camp.id, started = os.time(),
        owner = ctx.src, spot = m.spot, enemies = m.enemies, wagon = netId,
        stock = math.min(need, largest, camp.stock), arrived = false,
    }
    Runs[ctx.src] = run
    Deliveries[netId] = run
    setCooldown(camp.id, 'delivery', MCFG.deliveryCooldownMin)
    permitModels(ctx.src, m)
    run.posse = posseOthers(ctx.src)
    for _, s in ipairs(run.posse) do
        TriggerClientEvent('pup_camps:cl:posseDelivery', s, netId, m.spot)
        Notify(s, L('posse_delivery'))
    end
    CampLog(camp, 'missions', 'Delivery Run Started', LogColour.blue, {
        { 'Who', Who(ctx.src, camp) }, { 'Next run in', ('%d min'):format(MCFG.deliveryCooldownMin), true },
        { 'Stock carried', tostring(run.stock), true },
    }, { actor = ctx.src })
    pushWagons()
    return { spot = m.spot }
end, { gapMs = 2000 })

Handle('deliveryArrived', function(ctx, netId)
    local run = Deliveries[tonumber(netId) or -1]
    if not run then return nil end
    if not NearPoint(ctx.src, run.spot, MCFG.acceptRadius) then return nil end
    if not run.arrived then
        run.arrived = true
        giveBack('delivery', run.region, run.index)
        pushWagons()
    end
    for _, e in ipairs(run.enemies or {}) do
        pcall(Integrations.allowSpawn, ctx.src, e[5], 120000)
        if e[6] and e[6] ~= 0 then pcall(Integrations.allowSpawn, ctx.src, e[6], 120000) end
    end
    return { enemies = run.enemies }
end, { gapMs = 1000 })

Handle('deliverySell', function(ctx, campId, netId)
    local camp, why = Can(ctx, campId, nil, { noDistance = true })
    if not camp then return false, why end
    local pos = PlayerPos(ctx.src)
    -- only this camp's delivery, sold by the one who drove it out or their posse
    local function mine(r)
        if r.campId ~= camp.id then return false end
        if r.owner == ctx.src then return true end
        for _, s in ipairs(r.posse or {}) do if s == ctx.src then return true end end
        return false
    end
    local run = Deliveries[tonumber(netId) or -1]
    if not run or not run.arrived or not mine(run) then
        run = nil
        for _, r in pairs(Deliveries) do
            if r.arrived and mine(r) and (not pos or U.dist3(pos, r.spot) <= MCFG.acceptRadius) then run = r break end
        end
    end
    if not run or not run.arrived then return false end
    if pos and U.dist3(pos, run.spot) > MCFG.acceptRadius then return false end

    local pieces = math.floor(math.min(run.stock, camp.stock))
    local each = Config.Economy.randomPrice and math.random(Config.Economy.priceMin, Config.Economy.priceMax) or Config.Economy.fixedPrice
    local okM, mult = pcall(Integrations.perkMult, ctx.src, Config.Economy.perkSale)
    mult = okM and tonumber(mult) or 1.0
    if not mult or mult ~= mult or mult < 0.1 or mult > 10 then mult = 1.0 end
    local money = math.floor(each * pieces * mult + 0.5)
    camp.stock = math.max(0, camp.stock - pieces)
    camp.cash = U.round(camp.cash + money, 2)
    Save(camp)
    local veh = run.wagon and entityOf(run.wagon)
    if veh then DeleteEntity(veh) end
    pcall(Integrations.perkAward, ctx.src, Config.Economy.xpDelivery)
    Notify(ctx.src, L('delivery_sold', pieces, U.money(money), U.money(camp.cash)), 8000)
    CampLog(camp, 'supplies', 'Stock Sold', LogColour.green, {
        { 'Who', Who(ctx.src, camp) }, { 'Pieces', tostring(pieces), true },
        { 'Paid', U.money(money), true }, { 'Safe', U.money(camp.cash), true },
    }, { actor = ctx.src })
    endDelivery(run, 'sold')
    PushCamp(camp)
    return true
end, { gapMs = 2000 })

-- died, drove off or otherwise lost the buyer
Handle('missionAbandon', function(ctx, netId)
    netId = tonumber(netId)
    local run = Runs[ctx.src]
    if run and (not netId or run.kind == 'supply' or run.wagon == netId) then
        endRun(ctx.src, 'lost')
        return true
    end
    local d = netId and Deliveries[netId]
    if d then
        local veh = entityOf(netId)
        if veh and GetPedInVehicleSeat(veh, -1) == GetPlayerPed(ctx.src) then
            endDelivery(d, 'lost')
            return true
        end
    end
    return false
end, { gapMs = 1000 })

Handle('wagonList', function(ctx)
    pushWagons(ctx.src)
    return true
end, { gapMs = 2000 })

------------------------------------------------------------------------------ housekeeping

CreateThread(function()
    buildPools()
    initFree()
    while true do
        Wait(30000)
        local now = os.time()
        -- missions in use return after the return time at the latest
        for key, since in pairs(InUse) do
            if now - since >= MCFG.returnMin * 60 then
                local kind, region, idx = key:match('^(%w+):(%w+):(%d+)$')
                if kind then giveBack(kind, region, tonumber(idx)) end
            end
        end
        for src, run in pairs(Runs) do
            if now - run.started > MCFG.maxRunHours * 3600 then endRun(src, 'expired') end
        end
        local changed = false
        for net, w in pairs(Supplies) do
            if now - w.created > MCFG.maxRunHours * 3600 or not entityOf(net) then
                Supplies[net] = nil
                changed = true
            end
        end
        for net, run in pairs(Deliveries) do
            if not entityOf(net) then endDelivery(run, 'lost') end
        end
        if changed then pushWagons() end
    end
end)

-- vorp_admin world cleanup deleted the bandits and the wagons. A supply run cannot be
-- finished any more, so it ends and its cooldown is handed back; a delivery whose wagon
-- was kept (someone was driving it) carries on. Wagons that are gone are forgotten now
-- rather than on the next 30 s sweep.
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for src, run in pairs(Runs) do
        if not (run.kind == 'delivery' and run.wagon and entityOf(run.wagon)) then
            local cd = MissionCooldowns[run.campId]
            if cd then cd[run.kind] = nil end
            endRun(src, 'lost')
        end
    end
    for net in pairs(Supplies) do
        if not entityOf(net) then Supplies[net] = nil end
    end
    for net, run in pairs(Deliveries) do
        if not entityOf(net) then endDelivery(run, 'lost') end
    end
    pushWagons()
end)

function MissionsForget(src)
    endRun(src, 'left')
end

function MissionsCampGone(campId)
    MissionCooldowns[campId] = nil
    for src, run in pairs(Runs) do
        if run.campId == campId then endRun(src, 'camp') end
    end
end

function MissionsMemberLost(charid, campId)
    local src = SrcOfChar(charid)
    local run = src and Runs[src]
    if run and run.campId == campId then endRun(src, 'camp') end
end
