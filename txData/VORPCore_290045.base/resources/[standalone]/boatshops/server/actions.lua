-- boatshops | buying, selling, giving, upgrades and storage (server)
-- Every price, job, distance and ownership rule is checked here; the client only asks.

local S = BoatServer
local F = BoatFleet
local CFG <const> = BoatConfig
local T <const> = CFG.Timings
local L <const> = BoatLocale
local INV <const> = exports.vorp_inventory

local function money(ch)
    return tonumber(ch and ch.money) or 0
end

local function call(fn)
    local ok, r = pcall(fn)
    if not ok then
        print(('^1[boatshops]^7 %s'):format(tostring(r)))
        return nil
    end
    return r
end

-- ------------------------------------------------------------------ lists

RegisterNetEvent('boatshops:getBoats', function()
    local src = source
    if S.limited(src, 'list', 200) then return end
    local ch = S.char(src)
    if not ch then return end
    S.sendBoats(src)
    F.sendState(src, ch.charIdentifier)
end)

-- the shop's job lock, answered before a job-restricted shop opens
RegisterNetEvent('boatshops:access', function(shopId)
    local src = source
    if S.limited(src, 'access') then return end
    local ch = S.char(src)
    local shop = type(shopId) == 'string' and Boat.shops[shopId] or nil
    if not ch or not shop then return end
    TriggerClientEvent('boatshops:access', src, shopId, S.nearShop(src, shop) and S.jobOk(ch, shop))
end)

-- ------------------------------------------------------------------ buying

local function cleanName(name)
    if type(name) ~= 'string' then return nil, L.badName end
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    local len = utf8.len(name) or #name
    if len < CFG.Name.min or len > CFG.Name.max then return nil, L.badName end
    if name:find('[%c<>"\\`{}]') then return nil, L.badNameChars end
    return name
end

local function buy(src, ch, shopId, key, rawName)
    local name, why = cleanName(rawName)
    if not name then return S.tip(src, why) end
    local shop, entry = S.shopFor(src, ch, shopId, key)
    if not shop then
        -- a known shop the player is at but not allowed to use
        local s = type(shopId) == 'string' and Boat.shops[shopId]
        if s and S.nearShop(src, s) and not S.jobOk(ch, s) then S.tip(src, L.notPermitted) end
        return
    end
    if S.closed(shop) then return S.tip(src, L.storeClosed) end
    if not entry then return S.tip(src, L.notForSale) end
    if type(entry.jobs) == 'table' and #entry.jobs > 0 and not Boat.inList(entry.jobs, ch.job) then
        return S.tip(src, L.notPermitted)
    end
    local price = entry.buy
    if money(ch) < price then return S.tip(src, L.cannotAfford) end

    -- the row first, then the money: a failed save never costs anything
    local id = MySQL.insert.await(
        'INSERT INTO boats (identifier, charidentifier, name, boat, components) VALUES (?, ?, ?, ?, ?)',
        { ch.identifier, ch.charIdentifier, name, entry.key, '{}' })
    if not id or id == 0 then return S.tip(src, L.saveFailed) end

    local now = S.char(src)
    if not now or money(now) < price then
        MySQL.update.await('DELETE FROM boats WHERE id = ? AND charidentifier = ?', { id, ch.charIdentifier })
        return S.tip(src, L.cannotAfford)
    end
    local before = money(now)
    if price > 0 then now.removeCurrency(0, price) end

    S.tip(src, L.bought:format(Boat.money(price)))
    S.sendBoats(src)
    local row = { id = id, name = name, boat = entry.key }
    BoatLog.send('buy', src, '%s bought a boat.', {
        { 'Buyer', BoatLog.player(src, now) },
        { 'Boat', BoatLog.boat(row, {}) },
        { 'Price', '$' .. Boat.money(price), true },
        { 'Their cash', ('$%s -> $%s'):format(Boat.money(before), Boat.money(before - price)), true },
    })
end

RegisterNetEvent('boatshops:buy', function(shopId, key, name)
    local src = source
    if S.limited(src, 'buy') then return end
    local ch = S.char(src)
    if not ch or type(key) ~= 'string' then return end
    S.locked(ch.charIdentifier, buy, src, ch, shopId, key, name)
end)

-- ------------------------------------------------------------------ storage

local function storageId(id)
    return 'boat_' .. tostring(id)
end

-- registers the boat's storage once per server run; true when it was new.
-- vorp_inventory is asked every time, so a restart of it is picked up.
local function ensureStorage(row)
    local invId = storageId(row.id)
    if call(function() return INV:isCustomInventoryRegistered(invId) end) == true then
        return false
    end
    local base = Boat.catalogue(row.boat) or {}
    call(function()
        INV:registerInventory({
            id = invId,
            name = CFG.Storage.title,
            limit = Boat.storageSlots(row.boat),
            acceptWeapons = base.weapons == true,
            shared = CFG.Storage.shared == true,
            ignoreItemStackLimit = base.ignoreStack ~= false,
            whitelistItems = false,
            UsePermissions = false,
            UseBlackList = false,
            whitelistWeapons = false,
        })
    end)
    return true
end

local function aboard(src, e)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(e.ent) then return false end
    if type(GetVehiclePedIsIn) == 'function' then
        return GetVehiclePedIsIn(ped, false) == e.ent
    end
    local p, b = GetEntityCoords(ped), GetEntityCoords(e.ent)
    return S.dist(p, b.x, b.y, b.z) <= CFG.Storage.nearBoatMeters
end

RegisterNetEvent('boatshops:storage', function(rowId)
    local src = source
    if S.limited(src, 'storage') then return end
    local ch = S.char(src)
    if not ch then return end
    local row = S.loadOwned(rowId, ch.charIdentifier)
    if not row then return end
    if CFG.Storage.requireAboard then
        local e = F.get(row.id)
        if not e or e.charId ~= ch.charIdentifier or not aboard(src, e) then return S.tip(src, L.notAboard) end
    end
    if ensureStorage(row) then Wait(CFG.Storage.registerWaitMs) end
    call(function() INV:openInventory(src, storageId(row.id)) end)
end)

-- moves what is in the boat's storage into the seller's satchel; false stops the sale
local function emptyStorage(src, ch, row)
    local invId = storageId(row.id)
    ensureStorage(row)
    -- only the owner can have it open; closing a container they are not in
    -- would clear their lock on whatever else they have open
    if call(function() return INV:getOpenCustomInventory(src) end) == invId then
        call(function() INV:closeInventory(src, invId) end)
    end

    local weapons = call(function() return INV:getCustomInventoryWeapons(invId) end)
    if type(weapons) == 'table' and #weapons > 0 then
        S.tip(src, L.storageWeapons, T.tipMs)
        return false
    end
    local items = call(function() return INV:getCustomInventoryItems(invId) end)
    if type(items) ~= 'table' or #items == 0 then return true end

    -- removing by name takes from any row of that name, metadata rows too, so
    -- the items with metadata (removed by their crafted id) go first
    local ordered = {}
    for _, it in ipairs(items) do
        if type(it.metadata) == 'table' and next(it.metadata) ~= nil then ordered[#ordered + 1] = it end
    end
    for _, it in ipairs(items) do
        if not (type(it.metadata) == 'table' and next(it.metadata) ~= nil) then ordered[#ordered + 1] = it end
    end

    for _, it in ipairs(ordered) do
        local amount = math.floor(tonumber(it.amount) or 0)
        if amount > 0 then
            -- canCarryAmount is only in the patched vorp_inventory; stock falls back to canCarryItem
            local okA, fits = pcall(function() return INV:canCarryAmount(src, it.name, amount) end)
            if not okA then
                fits = call(function() return INV:canCarryItem(src, it.name, amount) end) == true and amount or 0
            end
            if (tonumber(fits) or 0) < amount then
                S.tip(src, L.storageFull, T.tipMs)
                return false
            end
            -- items without metadata are grouped by name, so they go by name
            local meta = type(it.metadata) == 'table' and next(it.metadata) ~= nil and it.metadata or nil
            local removed = call(function()
                return INV:removeItemFromCustomInventory(invId, it.name, amount, meta and it.crafted_id or nil)
            end)
            if removed ~= true then
                S.tip(src, L.storageFull, T.tipMs)
                return false
            end
            local added = call(function() return INV:addItem(src, it.name, amount, meta) end)
            if added ~= true then
                local back = call(function()
                    return INV:addItemsToCustomInventory(invId, { { name = it.name, amount = amount, metadata = meta } }, ch.charIdentifier)
                end)
                if back ~= true then
                    print(('^1[boatshops]^7 could not return %dx %s to %s after a failed hand-over'):format(amount, tostring(it.name), invId))
                end
                S.tip(src, L.storageFull, T.tipMs)
                return false
            end
        end
    end
    S.tip(src, L.storageReturned, T.tipMs)
    return true
end

-- ------------------------------------------------------------------ selling

local function sell(src, ch, shopId, rowId)
    local row = S.loadOwned(rowId, ch.charIdentifier)
    if not row then return end
    local shop, entry = S.shopFor(src, ch, shopId, row.boat)
    if not shop or not entry then return end
    if S.closed(shop) then return S.tip(src, L.storeClosed) end
    if F.isOut(row.id) then return S.tip(src, L.parkItFirst) end
    if CFG.Sell.returnStorage and not emptyStorage(src, ch, row) then return end

    local price = entry.sell
    local affected = MySQL.update.await('DELETE FROM boats WHERE id = ? AND charidentifier = ?', { row.id, ch.charIdentifier })
    if (tonumber(affected) or 0) < 1 then return end
    call(function() INV:removeInventory(storageId(row.id)) end)

    local now = S.char(src) or ch
    local before = money(now)
    if price > 0 then now.addCurrency(0, price) end

    S.tip(src, L.sold:format(Boat.money(price)))
    S.sendBoats(src)
    BoatLog.send('sell', src, '%s sold a boat to the store.', {
        { 'Seller', BoatLog.player(src, now) },
        { 'Boat', BoatLog.boat(row, Boat.decode(row.components)) },
        { 'Paid out', '$' .. Boat.money(price), true },
        { 'Their cash', ('$%s -> $%s'):format(Boat.money(before), Boat.money(before + price)), true },
    })
end

RegisterNetEvent('boatshops:sell', function(shopId, rowId)
    local src = source
    if S.limited(src, 'sell') then return end
    local ch = S.char(src)
    if not ch then return end
    S.locked(ch.charIdentifier, sell, src, ch, shopId, tonumber(rowId))
end)

-- ------------------------------------------------------------------ giving

local function give(src, ch, shopId, rowId, target)
    local row = S.loadOwned(rowId, ch.charIdentifier)
    if not row then return end
    local shop, entry = S.shopFor(src, ch, shopId, row.boat)
    if not shop or not entry then return end
    local tCh = S.online(target) and S.char(target) or nil
    if not tCh then return S.tip(src, L.notOnline) end
    local a, b = S.pos(src), S.pos(target)
    if not a or not b or S.dist(a, b.x, b.y, b.z) > CFG.Give.maxDistance then return S.tip(src, L.tooFar) end
    if F.isOut(row.id) then return S.tip(src, L.parkItFirst) end

    local affected = MySQL.update.await(
        'UPDATE boats SET identifier = ?, charidentifier = ? WHERE id = ? AND charidentifier = ?',
        { tCh.identifier, tCh.charIdentifier, row.id, ch.charIdentifier })
    if (tonumber(affected) or 0) < 1 then return end

    S.tip(src, L.handedOver:format(row.name))
    S.tip(target, L.givenBoat:format(row.name))
    S.sendBoats(src)
    S.sendBoats(target)
    BoatLog.send('give', src, '%s handed a boat to another player.', {
        { 'From', BoatLog.player(src, ch) },
        { 'To', BoatLog.player(target, tCh) },
        { 'Boat', BoatLog.boat(row, Boat.decode(row.components)) },
        { 'Payment', 'none - transferred free' },
    })
end

RegisterNetEvent('boatshops:give', function(shopId, rowId, target)
    local src = source
    if S.limited(src, 'give') then return end
    target = tonumber(target)
    if not target or target ~= math.floor(target) or target <= 0 or target == src then return end
    local ch = S.char(src)
    if not ch then return end
    S.locked(ch.charIdentifier, give, src, ch, shopId, tonumber(rowId), target)
end)

-- ------------------------------------------------------------------ upgrades

local function fit(src, ch, shopId, rowId, category, value)
    if not Boat.validCategory(category) then return end
    local row = S.loadOwned(rowId, ch.charIdentifier)
    if not row then return end
    local shop, entry = S.shopFor(src, ch, shopId, row.boat)
    if not shop or not entry then return end
    if S.closed(shop) then return S.tip(src, L.storeClosed) end
    local opt = Boat.findOption(category, row.boat, value)
    if not opt then return end
    if F.isOut(row.id) then return S.tip(src, L.parkItFirst) end

    local price = math.floor(tonumber(opt.price) or 0)
    if price > 0 and money(ch) < price then return S.tip(src, L.cannotAfford) end

    local comps = Boat.decode(row.components)
    comps[category] = opt.value
    local affected = MySQL.update.await('UPDATE boats SET components = ? WHERE id = ? AND charidentifier = ?',
        { json.encode(comps), row.id, ch.charIdentifier })
    if (tonumber(affected) or 0) < 1 then return end

    -- the money only after the save; put the old look back if it is gone meanwhile
    local now = S.char(src)
    if price > 0 and (not now or money(now) < price) then
        MySQL.update.await('UPDATE boats SET components = ? WHERE id = ? AND charidentifier = ?',
            { row.components, row.id, ch.charIdentifier })
        return S.tip(src, L.cannotAfford)
    end
    local before = money(now)
    if price > 0 then now.removeCurrency(0, price) end

    S.tip(src, L.fitted)
    S.sendBoats(src)
    BoatLog.send('upgrade', src, '%s fitted a modification.', {
        { 'Owner', BoatLog.player(src, now) },
        { 'Boat (after)', BoatLog.boat(row, comps) },
        { 'Fitted', ('%s -> %s'):format(category, tostring(opt.value)), true },
        { 'Price', '$' .. Boat.money(price), true },
        { 'Their cash', ('$%s -> $%s'):format(Boat.money(before), Boat.money(before - price)), true },
    })
end

RegisterNetEvent('boatshops:fit', function(shopId, rowId, category, value)
    local src = source
    if S.limited(src, 'fit') then return end
    if type(category) ~= 'string' or (type(value) ~= 'string' and type(value) ~= 'number') then return end
    local ch = S.char(src)
    if not ch then return end
    S.locked(ch.charIdentifier, fit, src, ch, shopId, tonumber(rowId), category, value)
end)
