-- Licences and the private market storage containers that come with them.

Storage = {}

local registered = {} -- [containerId string] = true once vorp_inventory knows it

function Storage.Licence(charid, market)
    local rows = MySQL.query.await(
        'SELECT inv_id, slots FROM tradepost_licences WHERE charid = ? AND market = ?', { charid, market })
    local row = rows and rows[1]
    if not row then return nil end
    return { invId = math.floor(tonumber(row.inv_id)), slots = math.floor(tonumber(row.slots) or Config.Licence.startSlots) }
end

-- registers the container (first time) and keeps its slot limit in step
function Storage.Register(invId, slots)
    local id = tostring(invId)
    local limit = math.max(1, math.floor(tonumber(slots) or 1))
    -- ask vorp_inventory every time: a restart of vorp_inventory forgets every
    -- container, and a cached "yes" here would then never register it again
    local known
    local okAsk, yes = pcall(function() return exports.vorp_inventory:isCustomInventoryRegistered(id) end)
    if okAsk then known = yes == true else known = registered[id] == true end
    if not known then
        local ok, err = pcall(function()
            exports.vorp_inventory:registerInventory({
                id = id,
                name = Config.Licence.containerName,
                limit = limit,
                acceptWeapons = false,
                shared = false,
                ignoreItemStackLimit = true,
                whitelistItems = false,
                UsePermissions = false,
                UseBlackList = true,
                whitelistWeapons = false,
            })
            -- exact names and every catalogue name caught by a blacklisted prefix
            for name in pairs(Items.storageBlock) do
                exports.vorp_inventory:BlackListCustomAny(id, name)
            end
        end)
        if not ok then
            print(('[pup_tradepost] could not register storage %s: %s'):format(id, tostring(err)))
            return false
        end
    end
    registered[id] = true
    pcall(function() exports.vorp_inventory:updateCustomInventorySlots(id, limit) end)
    return true
end

-- puts goods into a character's container at a market; works while they are offline
function Storage.Deliver(charid, market, item, qty)
    local lic = Storage.Licence(charid, market)
    if not lic then return false end
    if not Storage.Register(lic.invId, lic.slots) then return false end
    local p = promise.new()
    local settled = false
    local function settle(v)
        if settled then return end
        settled = true
        p:resolve(v)
    end
    local ok, err = pcall(function()
        local result = exports.vorp_inventory:addItemsToCustomInventory(
            tostring(lic.invId), { { name = item, amount = qty } }, charid, function(done)
                settle(done == true)
            end)
        -- the export also answers through its return value
        if result ~= nil then settle(result == true) end
    end)
    if not ok then
        print('[pup_tradepost] storage delivery failed: ' .. tostring(err))
        settle(false)
    end
    return Citizen.Await(p)
end

function Storage.RegisterAll()
    local rows = MySQL.query.await('SELECT inv_id, slots FROM tradepost_licences') or {}
    for _, row in ipairs(rows) do
        Storage.Register(row.inv_id, row.slots)
    end
    print(('[pup_tradepost] %d market storages registered'):format(#rows))
end

---------------------------------------------------------------------------
-- buying a licence
---------------------------------------------------------------------------
local allocating = false

-- New id and row in one statement, under one in-process lock, so two buyers
-- can never pick the same id. The row is written before any money moves and
-- removed again if the charge fails, so nobody pays without a licence.
function Storage.BuyLicence(src, charid, market)
    if Storage.Licence(charid, market) then return false, Lang.haveLicence end

    local waited = 0
    while allocating and waited < 5000 do Wait(50); waited = waited + 50 end
    if allocating then return false, Lang.busy end
    allocating = true

    local okIns, res = pcall(function()
        return MySQL.update.await(
            'INSERT IGNORE INTO tradepost_licences (charid, market, inv_id, slots, created_at) '
            .. 'SELECT ?, ?, GREATEST(?, COALESCE(MAX(inv_id), 0) + 1), ?, ? FROM tradepost_licences',
            { charid, market, Config.Licence.firstContainerId, Config.Licence.startSlots, os.time() })
    end)
    allocating = false
    if not okIns then error(res) end
    if DB.Affected(res) < 1 then return false, Lang.haveLicence end

    local lic = Storage.Licence(charid, market)
    if not lic then return false, Lang.failed end

    -- an error inside the charge must not leave an unpaid licence behind
    local okCharge, paid, why = pcall(Money.Charge, src, charid, TP.ToCents(Config.Licence.price), 'trading post licence')
    if not okCharge then paid, why = false, Lang.failed end
    if not paid then
        MySQL.update.await('DELETE FROM tradepost_licences WHERE charid = ? AND market = ? AND inv_id = ?',
            { charid, market, lic.invId })
        return false, why
    end

    Storage.Register(lic.invId, lic.slots)
    return true, Lang.licenceBought:format(lic.slots)
end

---------------------------------------------------------------------------
-- buying slots: reserved atomically, paid, then handed to vorp_inventory
---------------------------------------------------------------------------
function Storage.BuySlots(src, charid, market, count)
    local lic = Storage.Licence(charid, market)
    if not lic then return false, Lang.needLicenceHere end
    if not TP.IsWhole(count) or count < 1 or count > Config.Licence.maxSlotsPerBuy then
        return false, Lang.badAmount
    end
    local max = Config.Licence.maxSlots
    if lic.slots + count > max then return false, Lang.maxSlots:format(max) end

    local res = MySQL.update.await(
        'UPDATE tradepost_licences SET slots = slots + ? WHERE charid = ? AND market = ? AND slots + ? <= ?',
        { count, charid, market, count, max })
    if DB.Affected(res) < 1 then return false, Lang.maxSlots:format(max) end

    local okCharge, paid, why = pcall(Money.Charge, src, charid, count * TP.ToCents(Config.Licence.slotPrice), 'trading post storage')
    if not okCharge then paid, why = false, Lang.failed end
    if not paid then
        MySQL.update.await('UPDATE tradepost_licences SET slots = slots - ? WHERE charid = ? AND market = ?',
            { count, charid, market })
        return false, why
    end

    local now = Storage.Licence(charid, market)
    local slots = now and now.slots or (lic.slots + count)
    Storage.Register(lic.invId, slots)
    return true, Lang.slotsNow:format(slots)
end

function Storage.Open(src, charid, market)
    local lic = Storage.Licence(charid, market)
    if not lic then return false, Lang.needLicenceHere end
    Storage.Register(lic.invId, lic.slots)
    if not TP.SameChar(src, charid) then return false, Lang.notOpen end
    local ok = pcall(function() exports.vorp_inventory:openInventory(src, tostring(lic.invId), true) end)
    if not ok then return false, Lang.failed end
    return true, nil
end
