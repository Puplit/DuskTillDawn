-- storagebox | server: job packs. Unload, the tick-list filter, and the gathering exports.

local S = PupSBX
local C = StorageBoxConfig
local L = StorageBoxLocale

local NOT_CUSTOM = { clan = true, hideout = true } -- camps and hideouts are not custom inventories

-- how many of an item fit in the pockets: vorp's direct answer, else a halving search on its carry check
local function carryable(src, name, want)
    local n = S.inv('canCarryAmount', src, name, want)
    if type(n) == 'number' then return math.max(0, math.min(want, math.floor(n))) end
    local lo, hi = 0, want
    while lo < hi do
        local mid = math.ceil((lo + hi) / 2)
        if S.inv('canCarryItem', src, name, mid) == true then lo = mid else hi = mid - 1 end
    end
    return lo
end

local function slotsLeft(invId)
    local cap = tonumber(S.inv('getCustomInventorySlots', invId)) or 0
    if cap <= 0 then return math.huge end
    return math.max(0, cap - S.units(invId) - S.weaponCount(invId))
end

local function plainMeta(meta)
    return (type(meta) == 'table' and next(meta)) and meta or nil
end

-- where an unload goes: a custom inventory id, or nil for the pockets
local function destination(src, boxId, targetType, targetId)
    if C.PocketPanelTypes[targetType] or NOT_CUSTOM[targetType] then return nil end
    local open = S.openInv(src)
    if not open or open == boxId then return nil end
    if open == targetId or open == 'house_' .. targetId then return open end
    return nil
end

local function storeEmptyPack(src, ch, c, dest)
    if S.isBoxId(dest) then return S.tip(src, L.boxInBox) end
    if not S.mayPut(ch, S.invRules(dest), { c.item.name }) then return S.tip(src, L.noRoom) end
    if slotsLeft(dest) < 1 then return S.tip(src, L.noRoom) end
    if S.inv('subItemById', src, c.item.id, nil, true, 1) ~= true then return S.tip(src, L.noRoom) end
    -- a plain, unstamped pack: its box id is retired below
    if S.inv('addItemsToCustomInventory', dest, { { name = c.item.name, amount = 1, metadata = {} } }, ch.charIdentifier) ~= true then
        S.inv('addItem', src, c.item.name, 1, S.decodeMeta(c.item.metadata))
        return S.tip(src, L.noRoom)
    end
    S.retire(c.boxId)
    S.reloadInv(src, dest)
    S.tip(src, L.emptyPackStored)
    S.log('Empty Pack Stored', S.Colour.packStored, src, {
        { 'Pack', ('%s (%s)'):format(c.def.label, c.boxId) }, { 'Into', dest },
    })
end

local function unload(src, ch, c, dest, dropped)
    local stacks = S.contents(c.boxId)
    if #stacks == 0 then
        if dropped and dest then return storeEmptyPack(src, ch, c, dest) end
        return S.tip(src, L.packEmpty)
    end
    local moved, left, lines = 0, 0, {}
    if dest then
        local room = slotsLeft(dest)
        local rules = S.invRules(dest)
        for _, e in ipairs(stacks) do
            -- the container's own permission / blacklist / whitelist (vorp's add export skips them)
            local n = S.mayPut(ch, rules, { e.name }) and math.min(e.amount, room) or 0
            local arrived = 0
            if n > 0 then
                local before = S.countByName(dest, e.name)
                if S.inv('addItemsToCustomInventory', dest, { { name = e.name, amount = n, metadata = e.metadata } }, ch.charIdentifier) == true then
                    S.waitFor(function() return S.countByName(dest, e.name) - before >= n end)
                    arrived = math.max(0, math.min(n, S.countByName(dest, e.name) - before))
                end
                -- only what really arrived leaves the pack
                if arrived > 0 and S.inv('removeItemFromCustomInventory', c.boxId, e.name, arrived, e.craftedId) ~= true then
                    S.log('Pack Unload Mismatch', S.Colour.deleted, src, {
                        { 'Pack', c.boxId }, { 'Item', ('%s x%d reached %s but could not be taken out of the pack'):format(e.name, arrived, dest) },
                    })
                end
            end
            room = room - arrived
            moved = moved + arrived
            left = left + (e.amount - arrived)
            if arrived > 0 then lines[#lines + 1] = ('%s x%d'):format(S.label(e.name), arrived) end
        end
        S.reloadInv(src, dest)
        if left > 0 and moved > 0 then S.tip(src, L.leftInPack:format(left), 5000) end
    else
        for _, e in ipairs(stacks) do
            local n = carryable(src, e.name, e.amount)
            if n > 0 and S.inv('removeItemFromCustomInventory', c.boxId, e.name, n, e.craftedId) == true then
                if S.inv('addItem', src, e.name, n, plainMeta(e.metadata)) == true then
                    moved = moved + n
                    lines[#lines + 1] = ('%s x%d'):format(S.label(e.name), n)
                else
                    S.inv('addItemsToCustomInventory', c.boxId, { { name = e.name, amount = n, metadata = e.metadata } }, ch.charIdentifier)
                    n = 0
                end
            else
                n = 0
            end
            left = left + (e.amount - n)
        end
    end
    if moved > 0 then
        S.tip(src, L.unloaded:format(moved))
        S.log('Pack Unloaded', S.Colour.packUnloaded, src, {
            { 'Pack', ('%s (%s)'):format(c.def.label, c.boxId) },
            { 'Into', dest or 'pockets' },
            { 'Items', table.concat(lines, '\n') },
            { 'Left in pack', tostring(left) },
        })
    else
        S.tip(src, L.nothingFits)
    end
end

function S.unloadPack(src, itemId, boxId, targetType, targetId, dropped)
    local ch = S.char(src)
    if not ch then return end
    local c = S.containerById(src, itemId, true)
    if not c or c.boxId ~= boxId or c.def.kind ~= 'pack' then return end
    targetType = type(targetType) == 'string' and targetType or ''
    targetId = targetId ~= nil and tostring(targetId) or ''
    if C.ShopPanelTypes[targetType] then return S.tip(src, L.packAtShop) end
    if not S.ensure(boxId, c.item.name) then return S.tip(src, L.notFound) end
    local key = 'pack:' .. boxId
    if not S.lock(key, 60000) then return end
    local dest = destination(src, boxId, targetType, targetId)
    -- nobody may drag goods out of the pack while it is being unloaded
    S.closeViewers(boxId)
    local ok, err = pcall(unload, src, ch, c, dest, dropped == true)
    S.unlock(key)
    if not ok then print(('^1[%s:storagebox]^7 pack unload failed: %s'):format(S.RES, tostring(err))) end
end

RegisterNetEvent('pup_storagebox:packUnload', function(itemId, boxId, targetType, targetId, dropped)
    local src = source
    if not S.netGate(src, 'packUnload', 750) or not S.isBoxId(boxId) then return end
    if targetId ~= nil and #tostring(targetId) > 64 then return end
    S.unloadPack(src, itemId, boxId, targetType, targetId, dropped)
end)

------------------------------------------------------------------------------ the filter
local function ownPack(src, itemId, boxId)
    if not S.isBoxId(boxId) then return nil end
    local c = S.containerById(src, itemId, true)
    if not c or c.boxId ~= boxId or c.def.kind ~= 'pack' then return nil end
    return c
end

RegisterNetEvent('pup_storagebox:packFilter', function(itemId, boxId)
    local src = source
    if not S.netGate(src, 'packFilter', 750) then return end
    local c = ownPack(src, itemId, boxId)
    if not c then return end
    local filter = S.decodeMeta(c.item.metadata).filter
    local materials, picked = {}, {}
    for _, m in ipairs(c.def.materials) do
        materials[#materials + 1] = { name = m, label = S.label(m) }
        picked[m] = type(filter) ~= 'table' or filter[m] == true
    end
    TriggerClientEvent('pup-misc:storagebox:filterData', src, {
        itemId = c.item.id, boxId = boxId, label = c.def.label,
        materials = materials, picked = picked,
        text = { title = L.filterSubtitle, all = L.filterAll, save = L.filterSave, saveDesc = L.filterNote },
    })
end)

RegisterNetEvent('pup_storagebox:packFilterSet', function(itemId, boxId, filter, all)
    local src = source
    if not S.netGate(src, 'packFilterSet', 750) then return end
    local c = ownPack(src, itemId, boxId)
    if not c then return end
    local value = false -- false = everything
    if all ~= true then
        local picked, n = {}, 0
        if type(filter) == 'table' then
            for _, m in ipairs(c.def.materials) do
                if filter[m] == true then picked[m] = true n = n + 1 end
            end
        end
        if n < #c.def.materials then value = picked end
    end
    -- vorp merges metadata, so "everything" has to be written explicitly as false
    if S.inv('setItemMetadata', src, c.item.id, { boxId = boxId, filter = value }, 1) then
        S.tip(src, L.filterSaved)
    end
end)

------------------------------------------------------------------------------ gathering exports
local function packFor(src, gatherType, itemName)
    for _, c in ipairs(S.containers(src)) do
        local d = c.def
        if c.boxId and d.kind == 'pack' and d.gather == gatherType and d.materialSet[itemName] then
            local f = S.decodeMeta(c.item.metadata).filter
            if type(f) ~= 'table' or f[itemName] == true then return c end
        end
    end
    return nil
end

local function gatherArgs(src, gatherType, itemName, amount)
    src = tonumber(src)
    local n = S.posInt(amount)
    if not src or not n or type(gatherType) ~= 'string' or type(itemName) ~= 'string' then return nil end
    local ch = S.char(src)
    if not ch then return nil end
    return src, ch, n
end

exports('PackStore', function(src, gatherType, itemName, amount)
    local s, ch, n = gatherArgs(src, gatherType, itemName, amount)
    if not s then return false end
    local c = packFor(s, gatherType, itemName)
    if not c or not S.ensure(c.boxId, c.item.name) then return false end
    if S.inv('addItemsToCustomInventory', c.boxId, { { name = itemName, amount = n, metadata = {} } }, ch.charIdentifier) ~= true then
        return false
    end
    return true, c.def.label
end)

exports('PackCanStore', function(src, gatherType, itemName, amount)
    local s, _, n = gatherArgs(src, gatherType, itemName, amount)
    if not s then return false end
    local c = packFor(s, gatherType, itemName)
    if not c then return false end
    local cap = S.capacityFor(c.boxId, c.item.name)
    if cap <= 0 then return true end
    return S.units(c.boxId) + n <= cap
end)
