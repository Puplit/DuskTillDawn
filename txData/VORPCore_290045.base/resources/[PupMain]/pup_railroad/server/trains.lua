-- pup_railroad | server: purchases, trains out in the world, coal, removal and the sweep

local L <const> = Rail.L

local Out     = {} -- [trainId] = live train entry
local Permits = {} -- [trainId] = { src, charId, at } spawn permission
local Buying  = {} -- [src] = true while a train purchase is in flight

Srv.Out = Out
Srv.KnownBoxes = {} -- [contid string] = true for every train lockbox

--------------------------------------------------------------------------------
-- lockbox registration with vorp_inventory
--------------------------------------------------------------------------------
function Srv.registerBox(contid, force)
    contid = Rail.int(contid)
    if not contid then return end
    local id = tostring(contid)
    Srv.KnownBoxes[id] = true
    local ok, err = pcall(function()
        local inv = exports.vorp_inventory
        if inv:isCustomInventoryRegistered(id) then
            if not force then return end
            inv:removeInventory(id)
        end
        inv:registerInventory({
            id = id,
            name = L('lockbox_name'),
            limit = 0, -- no slot limit
            acceptWeapons = true,
            shared = true,
            ignoreItemStackLimit = true,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = true,
            whitelistWeapons = false,
        })
        for i = 1, #Config.LockboxBlacklist do
            inv:BlackListCustomAny(id, Config.LockboxBlacklist[i])
        end
    end)
    if not ok then
        print(('[pup_railroad] lockbox %s could not be registered: %s'):format(id, tostring(err)))
    end
end

--------------------------------------------------------------------------------
-- the list of trains out
--------------------------------------------------------------------------------
local function public(t)
    return {
        netId = t.netId, id = t.id, name = t.name, contid = t.contid,
        coalup = t.coalup, speedup = t.speedup, speed = t.speed,
        coal = t.coal, coalcap = t.coalcap, coalcon = t.coalcon, maint = t.maint,
    }
end

function Srv.publicList()
    local list = {}
    for _, t in pairs(Out) do list[#list + 1] = public(t) end
    return list
end

function Srv.broadcastList()
    TriggerClientEvent('pup_railroad:outList', -1, Srv.publicList())
end

function Srv.pushTrain(t)
    TriggerClientEvent('pup_railroad:trainChanged', -1, public(t))
end

function Srv.trainEntity(t)
    if not t or not t.netId then return nil end
    local ent = NetworkGetEntityFromNetworkId(t.netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

function Srv.nearTrain(src, t, dist)
    local ent = Srv.trainEntity(t)
    if not ent then return false end
    return Srv.within(Srv.playerPos(src), Srv.entityPos(ent), dist, true)
end

function Srv.trainByNet(netId)
    netId = Rail.int(netId)
    if not netId then return nil end
    for _, t in pairs(Out) do
        if t.netId == netId then return t end
    end
    return nil
end

function Srv.saveTrain(t)
    if t.coal == t.savedCoal and t.maint == t.savedMaint then return end
    t.savedCoal, t.savedMaint = t.coal, t.maint
    Srv.db.updateAsync('UPDATE player_trains SET coal = ?, maint = ? WHERE id = ?', { t.coal, t.maint, t.id })
end

--- save, take off the list, forget routes on it, broadcast
function Srv.dropTrain(id, quiet)
    local t = Out[id]
    if not t then return end
    Srv.saveTrain(t)
    Out[id] = nil
    if Srv.forgetRoutesOn then Srv.forgetRoutesOn(id) end
    if not quiet then Srv.broadcastList() end
end

--------------------------------------------------------------------------------
-- small helpers
--------------------------------------------------------------------------------
local function cleanName(raw, fallback)
    local s = type(raw) == 'string' and raw or ''
    s = s:gsub('%c', ''):gsub('[<>]', '')
    s = s:match('^%s*(.-)%s*$') or ''
    if #s > 50 then
        local cut = 50
        -- step back over UTF-8 continuation bytes so a character is never split
        while cut > 0 do
            local b = s:byte(cut + 1)
            if not b or b < 0x80 or b >= 0xC0 then break end
            cut = cut - 1
        end
        s = s:sub(1, cut):match('^(.-)%s*$')
    end
    if s == '' then s = fallback end
    return s
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

--------------------------------------------------------------------------------
-- station requests
--------------------------------------------------------------------------------
Srv.on('whoami', { gap = 500 }, function(_, char)
    return { ok = true, job = char.job, cash = char.money }
end)

Srv.on('companyTrains', { gap = 500 }, function(_, char)
    local rows = Srv.db.query(
        'SELECT id, name, contid, maint, coal, coalcap, speed, coalcon, coalup, speedup FROM player_trains WHERE company = ?',
        { char.job }) or {}
    local trains = {}
    for i = 1, #rows do
        local r = rows[i]
        if r.contid then Srv.registerBox(r.contid) end
        trains[#trains + 1] = {
            id = r.id, name = r.name, coal = tonumber(r.coal) or 0, coalcap = tonumber(r.coalcap) or 0,
            speed = tonumber(r.speed) or 0, maint = tonumber(r.maint) or 0, coalcon = tonumber(r.coalcon) or 0,
            coalup = tonumber(r.coalup) or 0, speedup = tonumber(r.speedup) or 0,
        }
    end
    return { ok = true, trains = trains }
end)

Srv.on('buyKey', { gap = 1000 }, function(src, char)
    if not Srv.nearOwnStation(src, char.job) then return Srv.fail(src, 'invalid') end
    local price = Config.KeyPrice
    if (tonumber(char.money) or 0) < price then return Srv.fail(src, 'no_money') end
    local okCarry, canCarry = pcall(function() return exports.vorp_inventory:canCarryItem(src, Config.KeyItem, 1) end)
    if not okCarry or not canCarry then return Srv.fail(src, 'cant_carry') end

    char.removeCurrency(0, price)
    local okAdd, added = pcall(function() return exports.vorp_inventory:addItem(src, Config.KeyItem, 1) end)
    if not okAdd or not added then
        char.addCurrency(0, price)
        return Srv.fail(src, 'cant_carry')
    end
    return { ok = true, price = price }
end)

Srv.on('buyTrain', { gap = 500 }, function(src, char, hash, rawName)
    if Buying[src] then return Srv.fail(src, 'purchase_pending') end
    if not Srv.nearOwnStation(src, char.job) then return Srv.fail(src, 'invalid') end
    local entry = Rail.shopEntryByHash(hash)
    if not entry then return Srv.fail(src, 'invalid') end
    local price = entry.price
    if (tonumber(char.money) or 0) < price then return Srv.fail(src, 'no_money') end

    local name = cleanName(rawName, entry.name)
    Buying[src] = true
    char.removeCurrency(0, price)

    local contid, trainId
    local okDb, dbErr = pcall(function()
        contid = Srv.db.insert('INSERT INTO container (name, items) VALUES (?, ?)', { name, '{}' })
        if contid then
            trainId = Srv.db.insert(
                'INSERT INTO player_trains (name, contid, maint, coal, coalcap, speed, hash, company, coalcon, img, coalup, speedup) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                { name, contid, 100, 0, entry.cap, entry.speed, Rail.hashString(entry.hash), char.job, entry.burn, entry.picture, 0, 0 })
        end
    end)
    if not okDb then
        print(('[pup_railroad] train purchase failed: %s'):format(tostring(dbErr)))
        trainId = nil
    end

    Buying[src] = nil
    if not contid or not trainId then
        char.addCurrency(0, price) -- the same character object the cash came from
        if contid then Srv.db.update('DELETE FROM container WHERE id = ?', { contid }) end
        return Srv.fail(src, 'invalid')
    end

    Srv.registerBox(contid)
    return { ok = true, price = price, id = trainId }
end)

--------------------------------------------------------------------------------
-- bringing a train out
--------------------------------------------------------------------------------
Srv.on('requestSpawn', { gap = 1000 }, function(src, char, trainId)
    trainId = Rail.int(trainId)
    if not trainId then return Srv.fail(src, 'invalid') end
    local charId = char.charIdentifier

    local row = Srv.db.single('SELECT id, company, hash, speed FROM player_trains WHERE id = ?', { trainId })
    char = Srv.sameChar(src, charId)
    if not char or not row or row.company ~= char.job then return Srv.fail(src, 'invalid') end
    if not Srv.nearOwnStation(src, char.job) then return Srv.fail(src, 'invalid') end

    local t = Out[trainId]
    if t then
        if Srv.trainEntity(t) then return Srv.fail(src, 'already_out') end
        Srv.dropTrain(trainId) -- stale entry: saved first, then the request continues
    end

    local now = os.time()
    local p = Permits[trainId]
    if p and p.src ~= src and now - p.at < Config.Timings.spawnPermit then
        return Srv.fail(src, 'already_out')
    end
    Permits[trainId] = { src = src, charId = charId, at = now }
    return { ok = true, hash = tostring(row.hash), speed = tonumber(row.speed) or 0 }
end)

Srv.on('spawnFailed', { gap = 250 }, function(src, _, trainId)
    trainId = Rail.int(trainId)
    local p = trainId and Permits[trainId]
    if p and p.src == src then Permits[trainId] = nil end
end)

Srv.on('spawned', { gap = 1000 }, function(src, char, trainId, netId)
    trainId, netId = Rail.int(trainId), Rail.int(netId)
    if not trainId or not netId then return Srv.fail(src, 'spawn_failed') end

    local function permitValid()
        local p = Permits[trainId]
        return p and p.src == src and p.charId == char.charIdentifier
            and os.time() - p.at <= Config.Timings.spawnPermit
    end
    if not permitValid() or Out[trainId] or Srv.trainByNet(netId) then return Srv.fail(src, 'spawn_failed') end

    -- the network id must point at a real vehicle next to this player (give it a moment to reach the server)
    local ent
    for _ = 1, 20 do
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        ent = nil
        Wait(150)
    end
    if not ent or GetEntityType(ent) ~= 2
        or not Srv.within(Srv.playerPos(src), Srv.entityPos(ent), Config.Reach.train, true) then
        return Srv.fail(src, 'spawn_failed')
    end

    local row = Srv.db.single('SELECT * FROM player_trains WHERE id = ?', { trainId })
    -- re-check everything after the wait
    if not row or not Srv.sameChar(src, char.charIdentifier) or not permitValid()
        or Out[trainId] or Srv.trainByNet(netId) then
        return Srv.fail(src, 'spawn_failed')
    end
    Permits[trainId] = nil

    local cap = math.max(0, Rail.int(row.coalcap) or 0)
    local coal = clamp(math.floor(tonumber(row.coal) or 0), 0, cap)
    local maint = clamp(tonumber(row.maint) or 100, 0, 100)
    local t = {
        id = trainId, netId = netId, name = row.name, contid = Rail.int(row.contid),
        coalup = Rail.int(row.coalup) or 0, speedup = Rail.int(row.speedup) or 0,
        speed = tonumber(row.speed) or 0, coal = coal, coalcap = cap,
        coalcon = math.max(0, Rail.int(row.coalcon) or 0), maint = maint,
        company = row.company, driver = src, lastBurn = nil, burns = 0,
        savedCoal = tonumber(row.coal), savedMaint = tonumber(row.maint),
        seen = false, missingSince = nil, abandonedSince = nil,
    }
    Out[trainId] = t
    if t.contid then Srv.registerBox(t.contid) end
    Srv.saveTrain(t) -- writes back clamped values only when they changed
    Srv.broadcastList()
    Srv.log(Srv.identity(char), 'Train Pulled Out', 5814783, { { 'Train', t.name } })
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- driving: key check, driver report, coal burn, adding coal
--------------------------------------------------------------------------------
Srv.on('hasKey', { gap = 1000 }, function(src)
    return { ok = true, has = Srv.hasKey(src) }
end)

Srv.on('driving', { gap = 1000 }, function(src, _, trainId)
    local t = Out[Rail.int(trainId) or -1]
    if not t or not Srv.hasKey(src) or not Srv.nearTrain(src, t, Config.Reach.train) then return end
    t.driver = src
    t.abandonedSince = nil
end)

Srv.on('burn', { gap = 500 }, function(src, _, trainId)
    local t = Out[Rail.int(trainId) or -1]
    if not t or t.coalcon <= 0 or t.coal <= 0 then return end
    local maintOn = Config.Maintenance.enabled
    if maintOn and t.maint <= 0 then return end
    if not Srv.hasKey(src) or not Srv.nearTrain(src, t, Config.Reach.train) then return end

    local now = GetGameTimer()
    if t.lastBurn and now - t.lastBurn < (t.coalcon - Config.Timings.burnSlack) * 1000 then return end
    t.lastBurn = now
    t.coal = math.max(0, t.coal - 1)
    if maintOn then t.maint = math.max(0, t.maint - Config.Maintenance.wearPerCoal) end
    t.burns = t.burns + 1
    Srv.pushTrain(t)
    if t.burns % 2 == 0 or t.coal == 0 or (maintOn and t.maint == 0) then Srv.saveTrain(t) end
end)

Srv.on('addCoal', { gap = 1000 }, function(src, _, trainId, amount)
    local id = Rail.int(trainId)
    local t = id and Out[id]
    amount = Rail.int(amount)
    if not t or not amount or amount <= 0 then return Srv.fail(src, 'invalid') end
    if not Srv.hasKey(src) or not Srv.nearTrain(src, t, Config.Reach.train) then return Srv.fail(src, 'invalid') end
    if t.coal + amount > t.coalcap then return Srv.fail(src, 'coal_too_much') end

    local okCount, have = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, Config.CoalItem) end)
    if not okCount or (tonumber(have) or 0) < amount then return Srv.fail(src, 'invalid') end
    local okSub, removed = pcall(function() return exports.vorp_inventory:subItem(src, Config.CoalItem, amount) end)
    if not okSub or not removed then return Srv.fail(src, 'invalid') end

    -- the train may have gone, or been filled by someone else, meanwhile
    if Out[id] ~= t or t.coal + amount > t.coalcap then
        pcall(function() exports.vorp_inventory:addItem(src, Config.CoalItem, amount) end)
        return Srv.fail(src, 'coal_too_much')
    end
    t.coal = t.coal + amount
    Srv.saveTrain(t)
    Srv.pushTrain(t)
    return { ok = true, amount = amount }
end)

--------------------------------------------------------------------------------
-- putting a train away (the dv command)
--------------------------------------------------------------------------------
Srv.on('putAway', { gap = 1000 }, function(src, char, netId)
    netId = Rail.int(netId)
    if not netId then return Srv.fail(src, 'not_yours') end
    local t = Srv.trainByNet(netId)
    local staff = Srv.isStaff(src)

    if not t then
        if staff or Rail.jobHasStation(char.job) then return { ok = true } end
        return Srv.fail(src, 'not_yours')
    end

    if Srv.trainEntity(t) then
        if (t.company == char.job or staff) and Srv.nearTrain(src, t, Config.Reach.train) then
            Srv.dropTrain(t.id)
            return { ok = true }
        end
        return Srv.fail(src, 'not_yours')
    end

    Srv.dropTrain(t.id) -- the entity has gone: anyone may clear it
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- sweep every 30 s: seen/missing trains and abandoned trains
--------------------------------------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Timings.sweep * 1000)
        local now = os.time()
        local changed = false
        for id, t in pairs(Out) do
            if not t.netId or not t.id then
                Out[id] = nil
                if Srv.forgetRoutesOn then Srv.forgetRoutesOn(id) end
                changed = true
            else
                local ent = Srv.trainEntity(t)
                if ent then
                    t.seen = true
                    t.missingSince = nil
                    if t.abandonedSince then
                        local driver = GetPedInVehicleSeat(ent, -1)
                        if driver and driver ~= 0 then
                            t.abandonedSince = nil
                        elseif Srv.routeOnTrain and Srv.routeOnTrain(id) then
                            t.abandonedSince = now
                        elseif now - t.abandonedSince >= Config.AbandonedSeconds then
                            DeleteEntity(ent)
                            Srv.dropTrain(id, true)
                            changed = true
                        end
                    end
                elseif t.seen then
                    t.missingSince = t.missingSince or now
                    if now - t.missingSince >= Config.Timings.missingDrop then
                        Srv.dropTrain(id, true)
                        changed = true
                    end
                end
            end
        end
        -- old spawn permissions
        for id, p in pairs(Permits) do
            if now - p.at > Config.Timings.spawnPermit then Permits[id] = nil end
        end
        if changed then Srv.broadcastList() end
    end
end)

--------------------------------------------------------------------------------
-- disconnect, character switch, resource stop
--------------------------------------------------------------------------------
local function releaseDriver(src)
    local now = os.time()
    for _, t in pairs(Out) do
        if t.driver == src then
            t.driver = nil
            t.abandonedSince = now
        end
    end
end

local function forgetPlayer(src)
    Buying[src] = nil
    for id, p in pairs(Permits) do
        if p.src == src then Permits[id] = nil end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    forgetPlayer(src)
    releaseDriver(src)
end)

-- a character switch releases the trains that character was driving
function Srv.trainsOnCharacterSwitch(src)
    forgetPlayer(src)
    releaseDriver(src)
end

--------------------------------------------------------------------------------
-- vorp_admin world cleanup: a train someone is driving or seated on stays, every
-- carriage of it; any other train is swept and taken off the list, so it can be
-- brought out again
--------------------------------------------------------------------------------
local cleanupKept = {}

local function engineOf(veh)
    local ok, eng = pcall(GetTrainCarriageEngine, veh)
    if ok and eng and eng ~= 0 then return eng end
    return veh
end

AddEventHandler('vorp_admin:worldCleanup', function()
    local occupied = {}
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        local veh = (ped and ped ~= 0) and GetVehiclePedIsIn(ped, false) or 0
        if veh and veh ~= 0 then occupied[engineOf(veh)] = true end
    end
    local keep = {}
    for _, t in pairs(Out) do
        local ent = Srv.trainEntity(t)
        if ent and (occupied[ent] or t.driver) then keep[ent] = true end
    end
    if next(keep) == nil then return end
    for _, v in pairs(GetAllVehicles()) do
        if keep[v] or keep[engineOf(v)] then
            Entity(v).state:set('worldCleanupKeep', true, true)
            cleanupKept[#cleanupKept + 1] = v
        end
    end
end)

AddEventHandler('vorp_admin:worldCleanupDone', function()
    for _, v in ipairs(cleanupKept) do
        if DoesEntityExist(v) then Entity(v).state:set('worldCleanupKeep', nil, true) end
    end
    cleanupKept = {}
    local changed = false
    for id, t in pairs(Out) do
        if not Srv.trainEntity(t) then
            Srv.dropTrain(id, true)
            changed = true
        end
    end
    if changed then Srv.broadcastList() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, t in pairs(Out) do
        Srv.saveTrain(t)
        local ent = Srv.trainEntity(t)
        if ent then DeleteEntity(ent) end
    end
end)
