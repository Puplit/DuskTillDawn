-- storagebox | server: goods from a container into a box ("Transfer to box"), and a whole box tipped
-- into a container (deposit). The net event names are the ones the vorp_inventory bridge fires.

local S = PupSBX
local C = StorageBoxConfig
local L = StorageBoxLocale

------------------------------------------------------------------------------ camp and hideout stashes
local STASH_RES = { clan = 'pup_camps', hideout = 'pup_hideouts' }

function S.stashCall(invType, fn, ...)
    local res = STASH_RES[invType]
    if not res then return nil end
    if not S.resStarted(res) then
        S.warnOnce('stash:' .. res, ('%s is not running: storage boxes cannot reach its stashes'):format(res))
        return nil
    end
    local n = select('#', ...)
    local args = { ... }
    local ok, a, b = pcall(function() return exports[res][fn](exports[res], table.unpack(args, 1, n)) end)
    if not ok then
        S.warnOnce('stash:' .. res .. ':' .. fn, ('%s export %s failed: %s'):format(res, fn, tostring(a)))
        return nil
    end
    return a, b
end

local function isStash(invType) return STASH_RES[invType] ~= nil end

------------------------------------------------------------------------------ metadata comparison
local function canon(v)
    if type(v) ~= 'table' then return tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local val = v[k]
        if val == nil then val = v[tonumber(k)] end
        parts[#parts + 1] = k .. '=' .. canon(val)
    end
    return '{' .. table.concat(parts, ',') .. '}'
end

function S.metaEqual(a, b)
    return canon(S.decodeMeta(a)) == canon(S.decodeMeta(b))
end

------------------------------------------------------------------------------ finding the source stack
-- list entries: { id, name, amount, metadata, label, type }.
-- charId: only that character's rows (a non-shared custom inventory)
local function sourceList(src, invType, invId, charId)
    if isStash(invType) then
        local rows = S.stashCall(invType, 'BoxStashItems', src, invId)
        if type(rows) ~= 'table' then return nil end
        local out = {}
        for _, r in ipairs(rows) do
            if type(r) == 'table' and type(r.name) == 'string' then
                out[#out + 1] = {
                    id = r.id, name = r.name, amount = tonumber(r.count or r.amount) or 0,
                    metadata = S.decodeMeta(r.metadata), label = r.label, type = r.type,
                }
            end
        end
        return out
    end
    local out = {}
    for _, e in ipairs(S.contents(invId, charId)) do
        out[#out + 1] = { id = e.craftedId, name = e.name, amount = e.amount, metadata = e.metadata }
    end
    return out
end

-- by entry id first; a list with ids and no matching id finds nothing.
-- Without an id: name and identical metadata, then name alone.
local function matchEntry(list, itemId, name, meta)
    local wantId = tonumber(itemId)
    if wantId then
        local hasIds = false
        for _, e in ipairs(list) do
            if e.id ~= nil then
                hasIds = true
                if tonumber(e.id) == wantId then return e.name == name and e or nil end
            end
        end
        if hasIds then return nil end
    end
    for _, e in ipairs(list) do
        if e.name == name and S.metaEqual(e.metadata, meta) then return e end
    end
    for _, e in ipairs(list) do
        if e.name == name then return e end
    end
    return nil
end

local function takeFromSource(src, a, e, n)
    if isStash(a.invType) then
        -- pup_hideouts' BoxStashTake clamps a short stack instead of refusing it, and the stash
        -- may have changed while the box was checked: read the entry again right before the
        -- take (no wait in between), so the box never gets more than really left the stash
        local now = sourceList(src, a.invType, a.sourceInvId)
        local cur = now and matchEntry(now, e.id, e.name, e.metadata)
        if not cur or cur.amount < n then return false end
        return S.stashCall(a.invType, 'BoxStashTake', src, a.sourceInvId, e.id, e.name, e.metadata, n) == true
    end
    return S.inv('removeItemFromCustomInventory', a.sourceInvId, e.name, n, tonumber(e.id)) == true
end

local function giveBackToSource(src, ch, a, e, n)
    local ok
    if isStash(a.invType) then
        ok = S.stashCall(a.invType, 'BoxStashReturn', a.sourceInvId, e.name, e.metadata, n, e.label or S.label(e.name)) == true
    else
        ok = S.inv('addItemsToCustomInventory', a.sourceInvId, { { name = e.name, amount = n, metadata = e.metadata } }, ch.charIdentifier) == true
    end
    if not ok then
        -- the source would not take it back: the player keeps it rather than it vanishing
        S.inv('addItem', src, e.name, n, e.metadata)
        S.log('Item Returned to Player (source refused it back)', S.Colour.takenOut, src, {
            { 'Item', ('%s x%d'):format(e.name, n) }, { 'Source', ('%s %s'):format(a.invType, a.sourceInvId) },
        })
    end
end

------------------------------------------------------------------------------ after a successful transfer
local function afterTransfer(src, a, e, n, boxId, d, before)
    local label = e.label or S.label(e.name)
    S.tip(src, L.transferred:format(n, label))
    S.refreshCarry(src, 0)

    -- tell the ledgers about a withdrawal they would otherwise miss
    if a.invType == 'hideout' then
        TriggerEvent('pup_hideouts:stashtaken_log', src, a.sourceInvId, { name = e.name, label = label }, n)
    elseif a.invType == 'clan' then
        TriggerEvent('pup_camps:stashtaken_log', src, a.sourceInvId, e.name, label, n)
    elseif not S.isBoxId(a.sourceInvId) and a.sourceInvId:sub(1, 6) ~= 'house_' then
        TriggerEvent('vorp_inventory:Server:OnItemTakenFromCustomInventory',
            { id = tonumber(e.id), name = e.name, amount = n, metadata = e.metadata }, a.sourceInvId, src)
    end

    local fields = {
        { 'Box', ('%s (%s)'):format(d.label, boxId) },
        { 'From', ('%s %s'):format(a.invType, a.sourceInvId) },
        { 'Item', S.changeText(label, before, before + n) },
    }
    S.log(a.newBox and 'Item Transferred to New Box' or 'Item Transferred to Box', S.Colour.transferred, src, fields)
    if S.isBoxId(a.sourceInvId) then
        S.log('Item Removed from Box', S.Colour.takenOut, src, {
            { 'Box', a.sourceInvId }, { 'Into', boxId }, { 'Item', ('%s x%d'):format(label, n) },
        })
    end
    if a.invType == 'Container' then
        S.societyLog(src, a.sourceInvId, true, { { amount = n, label = label } }, boxId)
    elseif not S.isBoxId(a.sourceInvId) then
        S.typeLog(src, S.kindOf(a.invType, a.sourceInvId), a.sourceInvId, 'Withdrew from:', label, n)
    end

    -- camp and hideout stashes reload their own viewers when BoxStashTake changes them
    if not isStash(a.invType) then S.reloadInv(src, a.sourceInvId) end
end

------------------------------------------------------------------------------ the transfer itself
-- a = { sourceInvId, itemId, itemName, amount, metadata, invType, newBox, targetBoxId | targetItemId + targetItemName }
local function transfer(src, ch, a)
    -- the panel must be the one really open (camps and hideouts check access in their own exports)
    if not isStash(a.invType) and S.openInv(src) ~= a.sourceInvId then return end

    local c, boxId
    if a.newBox then
        c = S.containerById(src, a.targetItemId, false)
        if not c or c.item.name ~= a.targetItemName then return S.tip(src, L.notFound) end
        if not S.jobAllowed(ch, c.def) then return S.tip(src, L.wrongJob) end
        if S.hasStampedOfName(src, c.item.name) then return S.tip(src, L.alreadyHave:format(c.def.label)) end
    else
        boxId = a.targetBoxId
        c = S.findStamped(src, boxId)
        if not c or boxId == a.sourceInvId or not S.ensure(boxId, c.item.name) then return S.tip(src, L.notFound) end
    end
    local d = c.def

    -- a custom inventory's own take-from permission, and only this character's rows when it is not shared
    local ownRows
    if not isStash(a.invType) then
        local rules = S.invRules(a.sourceInvId)
        if not S.mayTake(ch, rules) then return S.tip(src, L.sourceGone) end
        if not rules.shared then ownRows = ch.charIdentifier end
    end

    local list = sourceList(src, a.invType, a.sourceInvId, ownRows)
    local e = list and matchEntry(list, a.itemId, a.itemName, a.metadata)
    if not e or e.amount < 1 then return S.tip(src, L.sourceGone) end
    if e.type == 'item_weapon' or S.isWeaponName(e.name) then return S.tip(src, L.sourceGone) end
    if S.def(e.name) then return S.tip(src, L.boxInBox) end
    if d.kind == 'pack' and not d.materialSet[e.name] then return S.tip(src, L.notForPack) end

    local n = S.posInt(a.amount)
    if not n then return end
    n = math.min(n, e.amount)

    -- room is checked before anything moves
    local cap = boxId and S.capacityFor(boxId, c.item.name) or d.capacity
    local held = boxId and S.units(boxId) or 0
    if cap > 0 and held + n > cap then
        return S.tip(src, held >= cap and L.boxFull or L.boxShort)
    end

    if not takeFromSource(src, a, e, n) then return S.tip(src, L.sourceGone) end

    if a.newBox then
        -- the satchel may have changed while the source answered
        local again = S.containerById(src, a.targetItemId, false)
        boxId = again and again.item.name == a.targetItemName and S.createBox(again.item.name) or nil
        if boxId and not S.stamp(src, again.item.id, boxId) then
            S.dropFresh(boxId)
            boxId = nil
        end
        if not boxId then
            giveBackToSource(src, ch, a, e, n)
            return S.tip(src, L.initFailed)
        end
        S.log('Box Created', S.Colour.created, src, { { 'Box', ('%s (%s)'):format(d.label, boxId) } })
    elseif not S.findStamped(src, boxId) then
        giveBackToSource(src, ch, a, e, n)
        return S.tip(src, L.notFound)
    end

    local before = S.countByName(boxId, e.name)
    local added = S.inv('addItemsToCustomInventory', boxId, { { name = e.name, amount = n, metadata = e.metadata } }, ch.charIdentifier) == true
    if not added then
        giveBackToSource(src, ch, a, e, n)
        local capNow = S.capacityFor(boxId, c.item.name)
        return S.tip(src, (capNow > 0 and S.units(boxId) >= capNow) and L.boxFull or L.boxShort)
    end
    afterTransfer(src, a, e, n, boxId, d, before)
end

local function runTransfer(src, ch, a, lockKey, lockMs, holdLock)
    if not S.lock(lockKey, lockMs) then return end
    local ok, err = pcall(transfer, src, ch, a)
    if not ok then print(('^1[%s:storagebox]^7 transfer failed: %s'):format(S.RES, tostring(err))) end
    if not holdLock then S.unlock(lockKey) end
end

local function sourceArgs(src, sourceInvId, invType)
    if sourceInvId == nil or type(invType) ~= 'string' then return nil end
    sourceInvId = tostring(sourceInvId)
    if sourceInvId == '' or #sourceInvId > 64 then return nil end
    if not C.TransferSourceTypes[invType] then
        S.tip(src, L.typeNotAllowed)
        return nil
    end
    return sourceInvId
end

RegisterNetEvent('pup_inventory:sendToBox', function(sourceInvId, itemId, itemName, amount, metadata, targetBoxId, invType)
    local src = source
    local ch = S.netGate(src, 'sendToBox', 300)
    if not ch or type(itemName) ~= 'string' then return end
    sourceInvId = sourceArgs(src, sourceInvId, invType)
    if not sourceInvId then return end
    if not S.isBoxId(targetBoxId) then return S.tip(src, L.notFound) end
    -- one transfer out of a source inventory at a time; a second request is dropped
    runTransfer(src, ch, {
        sourceInvId = sourceInvId, itemId = itemId, itemName = itemName, amount = amount,
        metadata = S.decodeMeta(metadata), invType = invType, targetBoxId = targetBoxId,
    }, 'source:' .. invType .. ':' .. sourceInvId, 60000, false)
end)

RegisterNetEvent('pup_inventory:sendToNewBox', function(sourceInvId, itemId, itemName, amount, metadata, targetItemId, targetItemName, invType)
    local src = source
    local ch = S.netGate(src, 'sendToNewBox', 300)
    -- arguments first, then the lock
    if not ch or type(itemName) ~= 'string' or not S.posInt(targetItemId) or not S.def(targetItemName) then return end
    sourceInvId = sourceArgs(src, sourceInvId, invType)
    if not sourceInvId then return end
    -- shares the per-player lock with using an item, so one unopened item is never stamped twice
    if not S.lock('use:' .. src, 15000) then return end
    -- a short lock per source inventory that is left to expire on its own
    runTransfer(src, ch, {
        sourceInvId = sourceInvId, itemId = itemId, itemName = itemName, amount = amount,
        metadata = S.decodeMeta(metadata), invType = invType, newBox = true,
        targetItemId = S.posInt(targetItemId), targetItemName = targetItemName,
    }, 'newsource:' .. invType .. ':' .. sourceInvId, C.NewBoxLockMs, true)
    S.unlock('use:' .. src)
end)

------------------------------------------------------------------------------ deposits
local function directInsert(charId, name, meta, invId)
    local itemId = S.scalar('SELECT id FROM items WHERE item = ? LIMIT 1', { name })
    if not itemId then return false end
    local crafted, ok = S.insert('INSERT INTO items_crafted (character_id, item_id, metadata, item_name) VALUES (?, ?, ?, ?)',
        { charId, itemId, json.encode(meta), name })
    if not ok or not crafted then return false end
    local _, ok2 = S.insert('INSERT INTO character_inventories (character_id, item_crafted_id, amount, inventory_type, item_name, degradation) VALUES (?, ?, 1, ?, ?, 100)',
        { charId, crafted, invId, name })
    if not ok2 then
        S.update('DELETE FROM items_crafted WHERE id = ?', { crafted })
        return false
    end
    return true
end

-- adds to a custom inventory and, when switched on, reads it back until everything is there
local function addAndVerify(ch, invId, items, always)
    local verify = always or C.Switches.VerifyDepositArrival
    local want, before = {}, {}
    for _, it in ipairs(items) do want[it.name] = (want[it.name] or 0) + it.amount end
    if verify then
        for n in pairs(want) do before[n] = S.countByName(invId, n) end
    end
    if S.inv('addItemsToCustomInventory', invId, items, ch.charIdentifier) ~= true then return false end
    if not verify then return true end
    return S.waitFor(function()
        for n, w in pairs(want) do
            if S.countByName(invId, n) - before[n] < w then return false end
        end
        return true
    end) == true
end

local function depositContainer(src, ch, invId, items, total)
    local key = 'container:' .. invId
    if not S.lock(key, 30000) then return false end
    local ok, res = pcall(function()
        -- current contents always come from vorp's rows, never from the container.items mirror
        local cap = tonumber(S.inv('getCustomInventorySlots', invId)) or 0
        local held = S.units(invId) + S.weaponCount(invId)
        if cap > 0 and held + total > cap then return false end
        if not addAndVerify(ch, invId, items, true) then return false end
        for _, it in ipairs(items) do
            TriggerEvent('vorp_inventory:Server:OnItemMovedToCustomInventory',
                { name = it.name, amount = it.amount, metadata = it.metadata }, invId, src)
        end
        return true
    end)
    S.unlock(key)
    return ok and res == true
end

local function depositEmpty(src, ch, c, targetType, targetId)
    local name, boxId = c.item.name, c.boxId
    -- stored as a plain item: the box id is retired below, so it must not travel with it
    local meta = S.copy(S.decodeMeta(c.item.metadata))
    meta.boxId = nil
    meta.filter = nil
    S.flag(S.depositing, boxId, C.DepositingFlagMs)
    -- satchel first, so a refused store is undone without leaving a copy in the container
    if S.inv('subItemById', src, c.item.id, nil, true, 1) ~= true then
        S.tip(src, L.noRoom)
        return false
    end
    local stored = false
    if isStash(targetType) then
        stored = S.stashCall(targetType, 'BoxStashPut', src, targetId, { { name = name, count = 1, metadata = meta, label = c.def.label } }) == true
    elseif S.registered(targetId) then
        stored = S.inv('addItemsToCustomInventory', targetId, { { name = name, amount = 1, metadata = meta } }, ch.charIdentifier) == true
    elseif C.Switches.EmptyBoxDirectInsert then
        stored = directInsert(ch.charIdentifier, name, meta, targetId)
    end
    if not stored then
        S.inv('addItem', src, name, 1, S.decodeMeta(c.item.metadata))
        S.tip(src, L.noRoom)
        return false
    end
    S.retire(boxId)
    S.log('Empty Box Stored to Inventory', S.Colour.emptyStored, src, {
        { 'Box', ('%s (%s)'):format(c.def.label, boxId) }, { 'Into', ('%s %s'):format(targetType, targetId) },
    })
    if not isStash(targetType) then S.reloadInv(src, targetId) end
    S.refreshCarry(src, 0)
    return true
end

-- returns true when the deposit guard should stay up (it went through)
local function deposit(src, ch, c, targetType, targetId)
    local boxId, name = c.boxId, c.item.name
    if S.isBoxId(targetId) then S.tip(src, L.boxInBox) return false end
    if not C.DepositTypes[targetType] then S.tip(src, L.typeNotAllowed) return false end
    if not isStash(targetType) and S.openInv(src) ~= targetId then S.tip(src, L.noRoom) return false end
    if not S.ensure(boxId, name) then S.tip(src, L.notFound) return false end

    -- close every panel showing this box (vorp's server forgets it too) BEFORE reading the contents,
    -- or goods dragged out during the writes below would land both in a satchel and in the target
    S.closeBoxFor(src, boxId)
    S.closeViewers(boxId)

    local stacks = S.contents(boxId)
    -- vorp's add export skips the target's permission / blacklist / whitelist: check them here
    if not isStash(targetType) then
        local names = { name }
        for _, e in ipairs(stacks) do names[#names + 1] = e.name end
        if #stacks > 0 then table.remove(names, 1) end
        if not S.mayPut(ch, S.invRules(targetId), names) then S.tip(src, L.noRoom) return false end
    end
    if #stacks == 0 then return depositEmpty(src, ch, c, targetType, targetId) end

    local items, stashRows, total, labels = {}, {}, 0, {}
    for _, e in ipairs(stacks) do
        local label = S.label(e.name)
        items[#items + 1] = { name = e.name, amount = e.amount, metadata = e.metadata }
        stashRows[#stashRows + 1] = { name = e.name, count = e.amount, metadata = e.metadata, label = label }
        total = total + e.amount
        labels[#labels + 1] = { amount = e.amount, label = label }
    end

    -- the box item leaves the satchel first; its contents stay in the box until the target confirms
    S.flag(S.depositing, boxId, C.DepositingFlagMs + C.WriteConfirmTimeoutMs)
    if S.inv('subItemById', src, c.item.id, nil, true, 1) ~= true then
        S.tip(src, L.noRoom)
        return false
    end
    local stored
    if isStash(targetType) then
        stored = S.stashCall(targetType, 'BoxStashPut', src, targetId, stashRows) == true
    elseif targetType == 'Container' then
        stored = depositContainer(src, ch, targetId, items, total)
    else
        stored = addAndVerify(ch, targetId, items)
    end
    if not stored then
        S.inv('addItem', src, name, 1, S.decodeMeta(c.item.metadata))
        S.tip(src, L.noRoom)
        S.refreshCarry(src, 0)
        return false
    end

    S.flag(S.depositing, boxId, C.DepositingFlagMs)
    if S.sessions[src] == boxId then S.sessions[src] = nil end
    S.retire(boxId)
    S.tip(src, L.deposited)
    S.refreshCarry(src, 0)
    S.log('Box Deposited to Inventory', S.Colour.deposited, src, {
        { 'Box', ('%s (%s)'):format(c.def.label, boxId) },
        { 'Into', ('%s %s'):format(targetType, targetId) },
        { 'Contents', S.contentsText(stacks) },
    })
    if targetType == 'Container' then
        S.societyLog(src, targetId, false, labels, boxId)
    else
        local parts = {}
        for i, l in ipairs(labels) do
            if i > 10 then parts[#parts + 1] = '...' break end
            parts[#parts + 1] = ('%s x%d'):format(l.label, l.amount)
        end
        S.typeLog(src, S.kindOf(targetType, targetId), targetId, 'Deposited to:', table.concat(parts, ', '), total)
    end
    if not isStash(targetType) then S.reloadInv(src, targetId) end
    return true
end

RegisterNetEvent('pup_storagebox:depositBoxToInv', function(itemId, itemName, _, targetType, targetId)
    local src = source
    local ch = S.netGate(src, 'deposit', 500)
    if not ch or type(targetType) ~= 'string' or targetId == nil then return end
    targetId = tostring(targetId)
    if targetId == '' or #targetId > 64 then return end
    -- the client's metadata is ignored: only the server's stamp counts
    local c = S.containerById(src, itemId, true)
    if not c or (type(itemName) == 'string' and itemName ~= c.item.name) then return end
    if c.def.kind == 'pack' then
        return S.unloadPack(src, c.item.id, c.boxId, targetType, targetId, true)
    end
    local key = 'deposit:' .. c.boxId
    if not S.lock(key, C.DepositGuardMs) then return end
    local ok, keep = pcall(deposit, src, ch, c, targetType, targetId)
    if not ok then print(('^1[%s:storagebox]^7 deposit failed: %s'):format(S.RES, tostring(keep))) end
    if not ok or not keep then S.unlock(key) end
end)

------------------------------------------------------------------------------ goods dragged in or out of a box through vorp's own panel
AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(moved, invId, src)
    if type(moved) ~= 'table' or not S.isBoxId(invId) then return end
    src = tonumber(src)
    if not src then return end
    S.refreshCarry(src, 0)
    S.log('Item Added to Box (dragged in)', S.Colour.addedIn, src, {
        { 'Box', invId }, { 'Item', ('%s x%s'):format(S.label(moved.name), tostring(moved.amount)) },
    })
end)

AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', function(taken, invId, src)
    if type(taken) ~= 'table' or not S.isBoxId(invId) then return end
    src = tonumber(src)
    if not src then return end
    S.refreshCarry(src, 0)
    S.log('Item Taken from Box (dragged out)', S.Colour.takenOut, src, {
        { 'Box', invId }, { 'Item', ('%s x%s'):format(S.label(taken.name), tostring(taken.amount)) },
    })
end)
