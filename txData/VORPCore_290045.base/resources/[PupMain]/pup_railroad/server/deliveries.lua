-- pup_railroad | server: delivery routes

local Out <const> = Srv.Out

local Routes = {} -- [src] = { charId, identity, route, stop, trainId, busy, paid }

local function trainName(trainId)
    local row = Srv.db.single('SELECT name FROM player_trains WHERE id = ?', { trainId })
    return row and row.name or 'Unknown Train'
end

local function logRoute(r, title, colour, withReward)
    CreateThread(function()
        local extras = {
            { 'Mission', r.route.name },
            { 'Train', trainName(r.trainId) },
        }
        if withReward then extras[#extras + 1] = { 'Reward', '$' .. tostring(r.route.total) } end
        Srv.log(r.identity, title, colour, extras)
    end)
end

function Srv.routeOnTrain(trainId)
    for _, r in pairs(Routes) do
        if r.trainId == trainId then return true end
    end
    return false
end

function Srv.forgetRoutesOn(trainId)
    for src, r in pairs(Routes) do
        if r.trainId == trainId then Routes[src] = nil end
    end
end

--- end a running route with a cancel log and tell the client why
local function endRoute(src, reasonKey)
    local r = Routes[src]
    if not r then return end
    Routes[src] = nil
    logRoute(r, 'Delivery Cancelled', 15158332, false)
    if reasonKey then TriggerClientEvent('pup_railroad:routeEnded', src, reasonKey) end
end

--------------------------------------------------------------------------------
-- start / cancel
--------------------------------------------------------------------------------
Srv.on('startRoute', { gap = 1000 }, function(src, char, routeName, trainId)
    -- a route mid-delivery is refused; an idle one is ended with a cancel log once the new route passes its checks
    local old = Routes[src]
    if old and old.busy then return Srv.fail(src, 'finish_first') end
    local route = Rail.findRoute(routeName)
    local id = Rail.int(trainId)
    local t = id and Out[id]
    if not route or not t or t.company ~= char.job then return Srv.fail(src, 'invalid') end
    if not Srv.nearOwnStation(src, char.job) then return Srv.fail(src, 'invalid') end

    local first = route.stops[1]
    local pos = Srv.playerPos(src)
    if pos and #(pos - first.coords) < Config.MinRouteDistance then return Srv.fail(src, 'invalid') end

    if Routes[src] then endRoute(src, nil) end

    local r = {
        charId = char.charIdentifier, identity = Srv.identity(char),
        route = route, stop = 1, trainId = id, busy = false, paid = 0,
    }
    Routes[src] = r
    logRoute(r, 'Delivery Started', 15844367, true)
    return { ok = true, name = route.name, first = first.name }
end)

Srv.on('cancelRoute', { gap = 500 }, function(src)
    local r = Routes[src]
    if not r or r.busy then return { ok = false } end
    endRoute(src, nil)
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- deliver a stop (only the stop number comes from the client)
--------------------------------------------------------------------------------
local function putBack(boxId, lines, charId)
    if #lines == 0 then return end
    local items = {}
    for i = 1, #lines do items[i] = { name = lines[i].item, amount = lines[i].count } end
    local ok, done = pcall(function()
        return exports.vorp_inventory:addItemsToCustomInventory(boxId, items, charId)
    end)
    if not ok or not done then
        print(('[pup_railroad] could not put cargo back into lockbox %s'):format(boxId))
    end
end

Srv.on('deliver', { gap = 1000 }, function(src, char, stopNo)
    local r = Routes[src]
    stopNo = Rail.int(stopNo)
    if not r or r.busy or r.charId ~= char.charIdentifier or stopNo ~= r.stop then return Srv.fail(src, 'invalid') end
    local t = Out[r.trainId]
    if not t or not t.contid then return Srv.fail(src, 'invalid') end

    local stop = r.route.stops[r.stop]
    local trainEnt = Srv.trainEntity(t)
    if not trainEnt or not Srv.within(Srv.playerPos(src), stop.coords, Config.Reach.stopPlayer, true)
        or not Srv.within(Srv.entityPos(trainEnt), stop.coords, Config.Reach.stopTrain, true) then
        return Srv.fail(src, 'train_at_stop')
    end

    local boxId = tostring(t.contid)
    if Srv.boxBusy(boxId) then return Srv.fail(src, 'invalid') end -- another delivery is unloading this lockbox
    r.busy = true
    Srv.BoxBusy[boxId] = GetGameTimer()
    local function release()
        r.busy = false
        Srv.BoxBusy[boxId] = nil
    end
    Srv.registerBox(t.contid)
    Srv.closeBoxForAll(boxId) -- delivered cargo cannot also be taken out

    for i = 1, #stop.cargo do
        local c = stop.cargo[i]
        local ok, have = pcall(function() return exports.vorp_inventory:getCustomInventoryItemCount(boxId, c.item) end)
        if not ok or (tonumber(have) or 0) < c.count then
            release()
            return Srv.fail(src, 'not_enough_cargo')
        end
    end

    local removed = {}
    for i = 1, #stop.cargo do
        local c = stop.cargo[i]
        local ok, done = pcall(function() return exports.vorp_inventory:removeItemFromCustomInventory(boxId, c.item, c.count) end)
        if not ok or not done then
            putBack(boxId, removed, r.charId)
            release()
            return Srv.fail(src, 'invalid')
        end
        removed[#removed + 1] = c
    end

    -- re-check after the inventory work: same route, same character, still online
    char = Srv.sameChar(src, r.charId)
    if Routes[src] ~= r or not char then
        putBack(boxId, removed, r.charId)
        release()
        return { ok = false }
    end
    Srv.BoxBusy[boxId] = nil

    local pay = math.max(0, math.floor(tonumber(stop.pay) or 0))
    if pay > 0 then char.addCurrency(0, pay) end
    r.paid = r.paid + pay
    Srv.refreshCopy(t.contid)

    local delivered = r.stop
    local last = delivered >= #r.route.stops
    if last then
        Routes[src] = nil
        logRoute(r, 'Delivery Completed', 3066993, true)
    else
        r.stop = r.stop + 1
        r.busy = false
    end
    return { ok = true, stop = delivered, pay = pay, last = last, paid = r.paid }
end)

--------------------------------------------------------------------------------
-- losing the job that owns the train ends the route (checked with the sweep)
--------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Timings.sweep * 1000)
        for src, r in pairs(Routes) do
            local char = Srv.char(src)
            local t = Out[r.trainId]
            if char and char.charIdentifier == r.charId and t and t.company ~= char.job and not r.busy then
                endRoute(src, 'route_ended_job')
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- disconnect and character switch
--------------------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    Routes[source] = nil
end)

-- switching character ends the delivery (with a cancel log), releases driven trains and drops per-character state
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    if Routes[src] then
        local r = Routes[src]
        Routes[src] = nil
        logRoute(r, 'Delivery Cancelled', 15158332, false)
    end
    Srv.trainsOnCharacterSwitch(src)
    Srv.boxesOnCharacterSwitch(src)
end)
