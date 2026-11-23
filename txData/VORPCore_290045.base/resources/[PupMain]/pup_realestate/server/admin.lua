-- pup_realestate | exports for vorp_admin's Housing page and pup-gangs
-- vorp_admin checks manage_housing / delete_housing before calling these.

local function fail(err) return { ok = false, err = err } end

local function after(text)
    AdminLog('[admin panel] ' .. text)
    S.sendFull()
end

local function cachedOrFail(id)
    id = U.int(id)
    local h = id and S.houses[id]
    if not h then return nil, fail('unknown house (motel rooms are not editable here)') end
    return h
end

exports('adminHousingList', function()
    local ok, rows = pcall(MySQL.query.await,
        'SELECT id, `type`, motel, price, tax, ledger, taxledger, owned, repoed, buyercharidentifier, keyholders, `range`, invspace FROM playerhousing')
    if not ok then return {} end
    local list = {}
    for _, r in ipairs(rows or {}) do
        local id = U.int(r.id)
        local motelKey = tostring(r.motel or '0')
        local h = id and S.houses[id]
        local e = {
            id = id, type = U.int(r.type) or 0, motel = motelKey ~= '0' and motelKey ~= '',
            price = tonumber(r.price) or 0, tax = tonumber(r.tax) or 0,
            ledger = tonumber(r.ledger) or 0, taxledger = tonumber(r.taxledger) or 0,
            owned = tonumber(r.owned) == 1, repo = tonumber(r.repoed) == 1,
            ownerCharid = tonumber(r.buyercharidentifier) or 0,
            keyholders = S.decode(r.keyholders, {}),
            range = tonumber(r.range) or 0, slots = U.slotCap(r.invspace),
        }
        if h then -- the live copy wins over a row that may still be catching up
            e.type, e.price, e.tax, e.ledger, e.taxledger = h.kind, h.price, h.tax, h.ledger, h.taxledger
            e.owned, e.repo, e.ownerCharid, e.keyholders = h.owned, h.repo, h.owned and h.buyerChar or 0, h.keys
            e.range, e.slots = h.range, U.slotCap(h.slots)
        end
        list[#list + 1] = e
    end
    return list
end)

exports('adminSetHousePrice', function(id, price)
    price = tonumber(price)
    if not price or price ~= price or price < 0 then return fail('bad values') end
    price = math.floor(price)
    id = U.int(id)
    -- an unowned house at $0 would vanish after a restart; refuse it, and relist a delisted one
    if id and not S.houses[id] and S.delisted[id] then
        if price <= 0 then return fail('price must be above $0 to list this house') end
        local h = S.relist(id, price)
        if not h then return fail('could not relist the house') end
        after(('house %s relisted at $%s'):format(id, price))
        return { ok = true }
    end
    local h, err = cachedOrFail(id)
    if not h then return err end
    if price <= 0 and not h.owned then return fail('an unowned house needs a price above $0') end
    h.price = price
    S.save(h, 'price')
    after(('price of house %s set to $%s'):format(h.id, price))
    return { ok = true }
end)

exports('adminSetHouseTax', function(id, tax)
    tax = tonumber(tax)
    if not tax or tax ~= tax or tax < 0 then return fail('bad values') end
    local h, err = cachedOrFail(id)
    if not h then return err end
    h.tax = math.floor(tax)
    S.save(h, 'tax')
    after(('tax of house %s set to $%s'):format(h.id, h.tax))
    return { ok = true }
end)

exports('adminSetHouseRange', function(id, range)
    range = tonumber(range)
    if not range or range ~= range or range < 0 then return fail('bad values') end
    local h, err = cachedOrFail(id)
    if not h then return err end
    range = math.floor(range)
    local cap = math.floor(tonumber(Config.MaxRange) or 0)
    if cap > 0 and range > cap then range = cap end
    h.range = range
    S.save(h, 'range')
    after(('furniture range of house %s set to %s'):format(h.id, range))
    return { ok = true, value = range }
end)

exports('adminSetHouseSlots', function(id, slots)
    slots = tonumber(slots)
    if not slots or slots ~= slots or slots < 0 then return fail('bad values') end
    local h, err = cachedOrFail(id)
    if not h then return err end
    h.slots = U.slotCap(slots)
    S.save(h, 'slots')
    S.updateSlots(h.id)
    after(('storage slots of house %s set to %s'):format(h.id, h.slots))
    return { ok = true, value = h.slots }
end)

exports('adminSetHouseRepo', function(id, state)
    local h, err = cachedOrFail(id)
    if not h then return err end
    h.repo = state == true
    S.save(h, 'repo')
    after(('repossessed flag of house %s set to %s'):format(h.id, tostring(h.repo)))
    return { ok = true }
end)

exports('adminSeizeHouse', function(id)
    local h, err = cachedOrFail(id)
    if not h then return err end
    if not h.owned then return fail('house is not owned') end
    local prev = h.buyerChar
    -- a seizure is a repossession: the next sale pays no seller or business share
    S.clearOwner(h, { repo = true })
    after(('house %s seized from char %s'):format(h.id, prev))
    return { ok = true }
end)

exports('adminDeleteHouse', function(id)
    -- a house delisted at boot for its $0 price is not in the game, but the panel still lists it
    local did = U.int(id)
    if did and not S.houses[did] and S.delisted[did] then
        local okDel, affected = pcall(MySQL.update.await, 'DELETE FROM playerhousing WHERE id = ? AND owned <> 1', { did })
        if not okDel or tonumber(affected) ~= 1 then
            return fail('could not delete the house row (it may have been bought or already removed)')
        end
        S.delisted[did] = nil
        -- its container was never registered at boot: register-and-delete so house_<id> is emptied
        S.purgeUnregisteredContainer(did)
        S.forgetHook(did)
        after(('house %s deleted (it was delisted for a $0 price)'):format(did))
        return { ok = true }
    end
    local h, err = cachedOrFail(id)
    if not h then return err end
    if h.owned then return fail('house is owned - seize it first') end
    local ok = S.deleteHouse(h, 'House removed by an administrator')
    if not ok then return fail('house is owned - seize it first') end
    AdminLog(('[admin panel] house %s deleted'):format(h.id))
    return { ok = true }
end)

exports('adminTransferHouse', function(id, charid)
    charid = U.int(charid)
    if not charid or charid <= 0 then return fail('bad charid') end
    local h, err = cachedOrFail(id)
    if not h then return err end
    local ok, rows = pcall(MySQL.query.await, 'SELECT identifier FROM characters WHERE charidentifier = ? LIMIT 1', { charid })
    if not ok or not rows or not rows[1] then return fail(('no character with charid %s'):format(charid)) end
    h = S.houses[h.id]
    if not h then return fail('unknown house (motel rooms are not editable here)') end
    local before = S.accessSet(h)
    h.owned = true
    h.buyerChar = charid
    h.buyerIdent = tostring(rows[1].identifier or '0')
    h.keys = {}
    h.repo = false
    S.viewing[h.id] = nil
    S.save(h, 'owned', 'buyerChar', 'buyer', 'keys', 'repo')
    S.bridgeSync(h)
    S.afterAccessChange(h, before, true)
    after(('house %s transferred to char %s'):format(h.id, charid))
    return { ok = true }
end)

exports('adminRemoveKeyholder', function(id, charid)
    if type(charid) == 'table' then charid = charid.charid or charid.charidentifier end
    charid = U.int(charid)
    local h, err = cachedOrFail(id)
    if not h then return err end
    if not charid or not S.removeKey(h, charid) then return fail(('charid %s is not a keyholder'):format(tostring(charid))) end
    after(('keyholder char %s removed from house %s'):format(charid, h.id))
    return { ok = true }
end)

-- vorp_admin "Open storage": the house's real storage container for a staff member, from
-- anywhere, with the owner's controls. manage_housing is checked again here.
-- Returns true, or false and a reason.
exports('adminOpenStorage', function(src, id)
    src = U.int(src)
    if not src or src <= 0 or not S.online(src) then return false, 'player is not online' end
    if not S.ready then return false, 'pup_realestate is still loading' end
    if GetResourceState('vorp_admin') ~= 'started' then return false, 'vorp_admin is not running' end
    local okA, allowed = pcall(function() return exports.vorp_admin:allowedToExecuteAction(src, 'manage_housing') end)
    if not okA or allowed ~= true then return false, 'not allowed (manage_housing)' end
    local ch = S.char(src)
    if not ch then return false, 'no character loaded' end
    local rowId = U.int(id)
    if not rowId then return false, 'unknown house' end

    local ok, res = S.openStashAsStaff(src, ch, rowId)
    if not ok then return false, res end
    AdminLog(('[admin panel] %s (char %s, %s) opened the storage of %s %s'):format(
        tostring(ch.name), tostring(ch.charid), tostring(GetPlayerName(tostring(src)) or src),
        res and 'motel room' or 'house', rowId))
    return true
end)

-- pup-gangs
exports('hasHouseAccess', function(charid, houseId)
    local h = S.house(houseId)
    charid = U.int(charid)
    return (h and charid and S.hasAccess(h, charid)) and true or false
end)

exports('getHouseInfo', function(houseId)
    houseId = U.int(houseId)
    if not houseId then return nil end
    local ok, rows = pcall(MySQL.query.await, 'SELECT id, owned, buyercharidentifier, keyholders FROM playerhousing WHERE id = ? LIMIT 1', { houseId })
    local r = ok and rows and rows[1]
    if not r then return nil end
    local keys = {}
    for _, k in ipairs(S.decode(r.keyholders, {})) do
        if type(k) == 'table' then
            keys[#keys + 1] = { identifier = k.identifier, charidentifier = tonumber(k.charidentifier or k.charid), name = k.name }
        end
    end
    return { id = U.int(r.id), owned = tonumber(r.owned) == 1, ownerCharid = tonumber(r.buyercharidentifier) or 0, keyholders = keys }
end)
