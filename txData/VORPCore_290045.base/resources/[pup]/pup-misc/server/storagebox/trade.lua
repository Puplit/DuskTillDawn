-- storagebox | server: the trading bridge pup_mercantile uses, and an owner tipping a box onto their shelves.
-- Every export takes the satchel item id of the box (never a box id) and proves the player holds it.

local S = PupSBX
local L = StorageBoxLocale

local MAX_INT = 2147483647

local function holder(src, itemId, stamped)
    src = tonumber(src)
    if not src or not S.char(src) then return nil end
    return S.containerById(src, itemId, stamped), src
end

exports('BoxItemNames', function()
    local out = {}
    for _, name in ipairs(S.BoxNames) do out[name] = S.Defs[name].kind end
    return out
end)

exports('BoxInfo', function(src, itemId)
    local c = holder(src, itemId, true)
    if not c then return nil end
    return {
        boxId = c.boxId, name = c.item.name, label = c.def.label,
        capacity = S.capacityFor(c.boxId, c.item.name), used = S.units(c.boxId),
    }
end)

exports('BoxContents', function(src, itemId)
    local c = holder(src, itemId, true)
    if not c then return nil end
    local out = {}
    for _, e in ipairs(S.contents(c.boxId)) do
        if not S.isWeaponName(e.name) then
            out[#out + 1] = {
                craftedId = e.craftedId, name = e.name, label = S.label(e.name),
                amount = e.amount, percentage = e.percentage, metadata = e.metadata,
            }
        end
    end
    return out, c.boxId
end)

exports('BoxesOnPlayer', function(src)
    src = tonumber(src)
    if not src or not S.char(src) then return {} end
    local out = {}
    for _, c in ipairs(S.containers(src)) do
        if c.boxId then
            out[#out + 1] = {
                itemId = c.item.id, name = c.item.name, label = c.def.label,
                capacity = S.capacityFor(c.boxId, c.item.name), used = S.units(c.boxId),
                stacks = #S.contents(c.boxId), pack = c.def.kind == 'pack',
            }
        end
    end
    return out
end)

exports('BoxSpace', function(src, itemId)
    local c = holder(src, itemId, nil)
    if not c then return 0 end
    if not c.boxId then return c.def.capacity > 0 and c.def.capacity or MAX_INT end
    local cap = S.capacityFor(c.boxId, c.item.name)
    if cap <= 0 then return MAX_INT end
    return math.max(0, cap - S.units(c.boxId))
end)

exports('BoxTake', function(src, itemId, craftedId, amount)
    local c, s = holder(src, itemId, true)
    local n = S.posInt(amount)
    craftedId = tonumber(craftedId)
    if not c or not n or not craftedId or not S.ensure(c.boxId, c.item.name) then return false end
    local row = S.rowByCrafted(c.boxId, craftedId)
    local had = row and tonumber(row.amount) or 0
    if had < n then return false end
    if S.inv('removeItemFromCustomInventory', c.boxId, row.item_name, n, craftedId) ~= true then return false end
    -- confirm the stack really fell before telling the shop it may pay
    local fell = S.waitFor(function()
        local now = S.rowByCrafted(c.boxId, craftedId)
        return (now and tonumber(now.amount) or 0) <= had - n
    end)
    if not fell then return false end
    S.refreshCarry(s, 0)
    S.log('Taken OUT of a Container (shop sale)', S.Colour.shopTake, s, {
        { 'Box', ('%s (%s)'):format(c.def.label, c.boxId) },
        { 'Item', S.changeText(S.label(row.item_name), had, had - n) },
    })
    return true
end)

exports('BoxPut', function(src, itemId, name, amount, metadata)
    local c, s = holder(src, itemId, nil)
    local n = S.posInt(amount)
    if not c or not n or type(name) ~= 'string' then return 0 end
    local ch = S.char(s)
    if S.def(name) then return 0 end -- no box inside a box
    if S.isWeaponName(name) then return 0 end
    if c.def.kind == 'pack' and not c.def.materialSet[name] then return 0 end
    local boxId = c.boxId
    if not boxId then
        if S.hasStampedOfName(s, c.item.name) or not S.jobAllowed(ch, c.def) then return 0 end
        boxId = S.createBox(c.item.name)
        if not boxId then return 0 end
        if not S.stamp(s, c.item.id, boxId) then
            S.dropFresh(boxId)
            return 0
        end
        S.log('Box Created', S.Colour.created, s, { { 'Box', ('%s (%s)'):format(c.def.label, boxId) } })
    elseif not S.ensure(boxId, c.item.name) then
        return 0
    end
    local cap = S.capacityFor(boxId, c.item.name)
    if cap > 0 then n = math.min(n, math.max(0, cap - S.units(boxId))) end
    if n <= 0 then return 0 end
    local meta = type(metadata) == 'table' and metadata or {}
    local before = S.countByName(boxId, name)
    if S.inv('addItemsToCustomInventory', boxId, { { name = name, amount = n, metadata = meta } }, ch.charIdentifier) ~= true then
        return 0
    end
    S.waitFor(function() return S.countByName(boxId, name) - before >= n end)
    local landed = math.max(0, math.min(n, S.countByName(boxId, name) - before))
    if landed > 0 then
        S.refreshCarry(s, 0)
        S.log('Bought INTO a Container', S.Colour.shopBuy, s, {
            { 'Box', ('%s (%s)'):format(c.def.label, boxId) },
            { 'Item', S.changeText(S.label(name), before, before + landed) },
        })
    end
    return landed
end)

exports('BoxConsumeIfEmpty', function(src, itemId)
    local c, s = holder(src, itemId, true)
    if not c or c.def.kind == 'pack' then return false end
    if S.units(c.boxId) > 0 then return false end
    S.flag(S.depositing, c.boxId, 3000)
    if S.inv('subItemById', s, c.item.id, nil, true, 1) ~= true then return false end
    S.retire(c.boxId)
    S.refreshCarry(s, 0)
    S.log('Container Sold With Its Goods', S.Colour.shopConsumed, s, {
        { 'Box', ('%s (%s)'):format(c.def.label, c.boxId) },
    })
    return true
end)

------------------------------------------------------------------------------ owner tips a box onto their own shelves
RegisterNetEvent('pup_storagebox:dumpToStore', function(itemId, boxId)
    local src = source
    if not S.netGate(src, 'dumpToStore', 1500) then return end
    if not S.isBoxId(boxId) or not S.resStarted('pup_mercantile') then return end
    local c = S.containerById(src, itemId, true)
    if not c or c.boxId ~= boxId then return end
    local key = 'deposit:' .. boxId
    if not S.lock(key, 30000) then return end
    local ok, err = pcall(function()
        -- nobody may drag goods out while they are being shelved (see deposit in transfer.lua)
        S.closeBoxFor(src, boxId)
        S.closeViewers(boxId)
        local stacks = S.contents(boxId)
        if #stacks == 0 then return S.tip(src, L.boxEmptyHere) end
        local rows = {}
        for _, e in ipairs(stacks) do
            rows[#rows + 1] = { name = e.name, amount = e.amount, metadata = e.metadata, label = S.label(e.name), type = 'item_standard' }
        end
        local okCall, res = pcall(function() return exports.pup_mercantile:StockFromContainer(src, rows) end)
        if not okCall then
            S.warnOnce('mercantile:StockFromContainer', ('pup_mercantile export StockFromContainer failed: %s'):format(tostring(res)))
            return
        end
        if type(res) ~= 'table' or res.ok ~= true then return end
        -- the shop has the goods now: empty the box and use it up (packs included)
        local again = S.findStamped(src, boxId)
        local missing = {}
        for _, e in ipairs(stacks) do
            if S.inv('removeItemFromCustomInventory', boxId, e.name, e.amount, e.craftedId) ~= true then
                missing[#missing + 1] = ('%s x%d'):format(e.name, e.amount)
            end
        end
        if #missing > 0 then
            S.log('Shop Stocking Mismatch', S.Colour.deleted, src, {
                { 'Box', boxId }, { 'Shelved but not taken out of the box', table.concat(missing, ', ') },
            })
        end
        S.flag(S.depositing, boxId, 3000)
        if again then S.inv('subItemById', src, again.item.id, nil, true, 1) end
        S.retire(boxId)
        S.refreshCarry(src, 0)
        S.log('Container Stocked into a Shop', S.Colour.shopStocked, src, {
            { 'Box', ('%s (%s)'):format(c.def.label, boxId) },
            { 'Stacks', tostring(#stacks) },
            { 'Moved', tostring(res.moved or '?') }, { 'Merged', tostring(res.merged or '?') }, { 'Shelved', tostring(res.shelved or '?') },
            { 'Contents', S.contentsText(stacks) },
        })
    end)
    S.unlock(key)
    if not ok then print(('^1[%s:storagebox]^7 shop stocking failed: %s'):format(S.RES, tostring(err))) end
end)
