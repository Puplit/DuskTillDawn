-- pup_realestate | storage: vorp_inventory containers, the contents report, legacy migration, stash access

local INV = exports.vorp_inventory

S.legacy = {}       -- row id -> legacy contents list waiting to be migrated
S.stashActor = {}   -- src -> actor of the stash they have open (named in the report after a disconnect)
local snapshots = {} -- row id -> { [key] = count }
local labelOf = {}   -- snapshot key -> label (so removed things keep a name)
local lastJson = {}  -- row id -> last report written
local migrating = {}

function S.containerId(rowId) return 'house_' .. tostring(rowId) end

-- house or motel room behind a row id
function S.row(rowId)
    rowId = U.int(rowId)
    if not rowId then return nil end
    if S.houses[rowId] then return S.houses[rowId], false end
    if S.motels[rowId] then return S.motels[rowId], true end
    return nil
end

function S.rowSlots(rowId)
    local r, isMotel = S.row(rowId)
    if not r then return 0 end
    return U.slotCap(isMotel and r.slots or r.slots)
end

function S.ensureContainer(rowId)
    local r, isMotel = S.row(rowId)
    if not r then return false end
    local cid = S.containerId(rowId)
    local slots = S.rowSlots(rowId)
    local ok, registered = pcall(function() return INV:isCustomInventoryRegistered(cid) end)
    if not ok then return false end
    if not registered then
        local blacklist = Config.Storage.blacklist or {}
        pcall(function()
            INV:registerInventory({
                id = cid,
                name = isMotel and Locale.inventory or T('storage_title', rowId),
                limit = slots,
                acceptWeapons = true,
                shared = true,
                ignoreItemStackLimit = true,
                whitelistItems = false,
                UsePermissions = false,
                UseBlackList = #blacklist > 0,
                whitelistWeapons = false,
            })
        end)
        -- the registration payload's blacklist is dropped by vorp_inventory, so add each item
        for _, item in ipairs(blacklist) do
            pcall(function() INV:BlackListCustomAny(cid, tostring(item):lower()) end)
        end
    end
    pcall(function() INV:updateCustomInventorySlots(cid, slots) end)
    return true
end

function S.updateSlots(rowId)
    pcall(function() INV:updateCustomInventorySlots(S.containerId(rowId), S.rowSlots(rowId)) end)
end

-- vorp_inventory's deleteCustomInventory empties a registered container, but it stops early
-- (leaving the weapons in loadout) when the container holds no item rows, so whatever is left
-- under exactly this container id is cleared directly afterwards
local function clearLeftovers(rowId, cid)
    local steps = {
        { 'DELETE ic FROM items_crafted ic JOIN character_inventories ci ON ci.item_crafted_id = ic.id WHERE ci.inventory_type = ?', { cid } },
        { 'DELETE FROM character_inventories WHERE inventory_type = ?', { cid } },
        { 'DELETE FROM loadout WHERE curr_inv = ?', { cid } },
    }
    for _, s in ipairs(steps) do
        local ok, err = pcall(MySQL.update.await, s[1], s[2])
        if not ok then Warn('row %s: container cleanup step failed: %s', rowId, tostring(err)) end
    end
end

function S.deleteContainer(rowId)
    local cid = S.containerId(rowId)
    pcall(function() INV:deleteCustomInventory(cid) end)
    pcall(function() INV:removeInventory(cid) end)
    clearLeftovers(rowId, cid)
    snapshots[rowId], lastJson[rowId], S.legacy[rowId] = nil, nil, nil
end

-- empty the container of a row that is being deleted although it was never registered (a house
-- delisted at boot for a $0 price). vorp_inventory's deleteCustomInventory only acts on a
-- registered container, so it is registered first and then deleted like any other.
function S.purgeUnregisteredContainer(rowId)
    rowId = U.int(rowId)
    if not rowId or rowId <= 0 or S.houses[rowId] or S.motels[rowId] then return end
    local cid = S.containerId(rowId)
    local okR, registered = pcall(function() return INV:isCustomInventoryRegistered(cid) end)
    if okR and not registered then
        local okReg, err = pcall(function()
            INV:registerInventory({
                id = cid, name = T('storage_title', rowId), limit = 1,
                acceptWeapons = true, shared = true, ignoreItemStackLimit = true,
                whitelistItems = false, UsePermissions = false, UseBlackList = false, whitelistWeapons = false,
            })
        end)
        if not okReg then Warn('row %s: could not register its container for deletion: %s', rowId, tostring(err)) end
    end
    S.deleteContainer(rowId)
end

-- the items column: a report list (every entry mirror = true), a legacy list, or empty
function S.readItemsColumn(rowId, raw)
    local list = S.decode(raw, {})
    if type(list) ~= 'table' or #list == 0 then return end
    local allReport = true
    for _, e in ipairs(list) do
        if type(e) ~= 'table' or e.mirror ~= true then allReport = false end
        if type(e) == 'table' and e.limit ~= nil then e.limit = -1 end
    end
    if allReport then
        lastJson[rowId] = raw
        return
    end
    S.legacy[rowId] = list
    Warn('row %s still holds legacy storage contents; they move into the container on first open', rowId)
end

-- legacy contents into the container (once per row, owner charid needed)
function S.migrate(rowId)
    local list = S.legacy[rowId]
    if not list or migrating[rowId] then return false end
    local r, isMotel = S.row(rowId)
    if not r then return false end
    local owner = isMotel and r.owner or (r.owned and r.buyerChar or 0)
    if not owner or owner <= 0 then return false end
    migrating[rowId] = true
    local items = {}
    for _, e in ipairs(list) do
        if type(e) == 'table' and type(e.name) == 'string' then
            local ok, def = pcall(function() return INV:getItemDB(e.name) end)
            if not ok or not def then
                Warn('row %s: legacy item "%s" is unknown to vorp_inventory - nothing was moved', rowId, e.name)
                migrating[rowId] = nil
                return false
            end
            local amount = math.floor(tonumber(e.count) or 0)
            if amount > 0 then
                items[#items + 1] = { name = e.name, amount = amount, metadata = type(e.metadata) == 'table' and e.metadata or {} }
            end
        end
    end
    local moved = true
    if #items > 0 then
        local ok, res = pcall(function() return INV:addItemsToCustomInventory(S.containerId(rowId), items, owner) end)
        moved = ok and res == true
    end
    if moved then
        S.legacy[rowId] = nil
        pcall(MySQL.update.await, 'UPDATE playerhousing SET items = ? WHERE id = ?', { '[]', rowId })
        lastJson[rowId] = '[]'
        Dbg('row %s: legacy storage moved into its container', rowId)
    end
    migrating[rowId] = nil
    return moved
end

-- contents report
local function placeholders(n)
    local t = {}
    for i = 1, n do t[i] = '?' end
    return table.concat(t, ',')
end

local function describe(changes)
    local parts = {}
    for _, c in ipairs(changes) do parts[#parts + 1] = ('%s x%d'):format(c.label, c.n) end
    return table.concat(parts, ', ')
end

local function logDiff(rowId, before, after, actor)
    local stored, took = {}, {}
    for key, n in pairs(after) do
        local was = before[key] or 0
        if n > was then stored[#stored + 1] = { label = labelOf[key] or key, n = n - was } end
    end
    for key, was in pairs(before) do
        local n = after[key] or 0
        if was > n then took[#took + 1] = { label = labelOf[key] or key, n = was - n } end
    end
    if #stored == 0 and #took == 0 then return end
    table.sort(stored, function(a, b) return a.label < b.label end)
    table.sort(took, function(a, b) return a.label < b.label end)
    local parts = {}
    if #stored > 0 then parts[#parts + 1] = 'stored ' .. describe(stored) end
    if #took > 0 then parts[#parts + 1] = 'took ' .. describe(took) end
    Activity(rowId, 'STORAGE', table.concat(parts, '; '), actor)
end

-- batched rewrite state (see S.markReport below); declared here so a full rewrite can name actors
local pendingRows, pendingActors, flushQueued = {}, {}, false

-- rewrite the report of some rows (set of ids) or of every row (nil); actors: row id -> actor
local function rewriteNow(rowSet, actors)
    local ids = {}
    if rowSet then
        for id in pairs(rowSet) do
            if S.row(id) and not S.legacy[id] then ids[#ids + 1] = id end
        end
    else
        for id in pairs(S.houses) do if not S.legacy[id] then ids[#ids + 1] = id end end
        for id in pairs(S.motels) do if not S.legacy[id] then ids[#ids + 1] = id end end
    end
    if #ids == 0 then return end

    for start = 1, #ids, 200 do
        local chunk, cids, byCid = {}, {}, {}
        for i = start, math.min(#ids, start + 199) do
            chunk[#chunk + 1] = ids[i]
            local cid = S.containerId(ids[i])
            cids[#cids + 1] = cid
            byCid[cid] = ids[i]
        end
        local okI, itemRows = pcall(MySQL.query.await, ([[
            SELECT ci.inventory_type, ci.item_name, ci.amount, ci.item_crafted_id, ci.percentage,
                   ic.metadata, i.label, i.type
            FROM character_inventories ci
            LEFT JOIN items_crafted ic ON ic.id = ci.item_crafted_id
            LEFT JOIN items i ON i.item = ci.item_name
            WHERE ci.inventory_type IN (%s)]]):format(placeholders(#cids)), cids)
        local okW, weaponRows = pcall(MySQL.query.await,
            ('SELECT * FROM loadout WHERE curr_inv IN (%s)'):format(placeholders(#cids)), cids)
        if okI and okW then
            local reports, counts = {}, {}
            for _, id in ipairs(chunk) do reports[id], counts[id] = {}, {} end
            for _, r in ipairs(itemRows or {}) do
                local id = byCid[r.inventory_type]
                if id then
                    local amount = math.floor(tonumber(r.amount) or 0)
                    local label = r.label or r.item_name
                    reports[id][#reports[id] + 1] = {
                        mirror = true, name = r.item_name, label = label, count = amount,
                        type = r.type or 'item_standard', metadata = S.decode(r.metadata, {}),
                        percentage = r.percentage, crafted_id = r.item_crafted_id,
                    }
                    local key = 'i:' .. tostring(r.item_name)
                    labelOf[key] = label
                    counts[id][key] = (counts[id][key] or 0) + amount
                end
            end
            for _, w in ipairs(weaponRows or {}) do
                local id = byCid[w.curr_inv]
                if id then
                    local label = (w.custom_label ~= nil and w.custom_label ~= '' and w.custom_label) or w.label or w.name
                    reports[id][#reports[id] + 1] = {
                        mirror = true, name = w.name, label = label, count = 1, type = 'item_weapon',
                        serial_number = w.serial_number, loadout_id = w.id, degradation = w.degradation,
                    }
                    local serial = w.serial_number and tostring(w.serial_number) or ''
                    local key = 'w:' .. tostring(w.name) .. '|' .. serial
                    labelOf[key] = (serial ~= '' and serial ~= '0') and ('%s (SN %s)'):format(label, serial) or label
                    counts[id][key] = (counts[id][key] or 0) + 1
                end
            end
            for _, id in ipairs(chunk) do
                if S.row(id) and not S.legacy[id] then
                    local encoded = #reports[id] > 0 and json.encode(reports[id]) or '[]'
                    if lastJson[id] ~= encoded then
                        lastJson[id] = encoded
                        pcall(MySQL.update.await, 'UPDATE playerhousing SET items = ? WHERE id = ?', { encoded, id })
                    end
                    local before = snapshots[id]
                    snapshots[id] = counts[id]
                    if before then logDiff(id, before, counts[id], actors and actors[id] or nil) end
                end
            end
        else
            Warn('storage report query failed')
        end
    end
end

-- One rewrite at a time: a second one waits, then diffs against the snapshot the first one left,
-- so the same change is never logged twice.
local rewriting = false
function S.rewriteReports(rowSet, actors)
    while rewriting do Wait(50) end
    rewriting = true
    -- a full rewrite that picks up a change still waiting in the batch names that batch's actor
    if not actors and not rowSet then actors = pendingActors end
    local ok, err = pcall(rewriteNow, rowSet, actors)
    rewriting = false
    if not ok then Warn('storage report rewrite failed: %s', tostring(err)) end
end

-- batched rewrite 1.5 s after a change, naming whoever caused it

-- fallbackActor: used when the player can no longer be read (a disconnect with the stash open)
function S.markReport(rowId, src, fallbackActor)
    rowId = U.int(rowId)
    if not rowId or not S.row(rowId) then return end
    pendingRows[rowId] = true
    local ch = src and S.char(src)
    if ch then
        pendingActors[rowId] = S.actor(ch)
    elseif fallbackActor then
        pendingActors[rowId] = fallbackActor
    end
    if flushQueued then return end
    flushQueued = true
    SetTimeout(Config.Timers.reportBatch, function()
        local rows, actors = pendingRows, pendingActors
        pendingRows, pendingActors, flushQueued = {}, {}, false
        S.rewriteReports(rows, actors)
    end)
end

local function rowFromContainer(cid)
    if type(cid) ~= 'string' then return nil end
    return U.int(cid:match('^house_(%d+)$'))
end

local function openContainerOf(src)
    local ok, cid = pcall(function() return INV:getOpenCustomInventory(src) end)
    if ok and cid then return rowFromContainer(cid) end
    return S.openStash[src]
end

RegisterNetEvent('vorp_inventory:MoveToCustom', function()
    local src = tonumber(source)
    if src then S.markReport(openContainerOf(src), src) end
end)

RegisterNetEvent('vorp_inventory:TakeFromCustom', function()
    local src = tonumber(source)
    if src then S.markReport(openContainerOf(src), src) end
end)

AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', function(_, invId, src)
    S.markReport(rowFromContainer(invId), tonumber(src))
end)

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(_, invId, src)
    S.markReport(rowFromContainer(invId), tonumber(src))
end)

RegisterNetEvent('vorp_inventory:Server:CloseCustomInventory', function()
    local src = tonumber(source)
    if not src then return end
    local rowId = S.openStash[src]
    if rowId then
        S.openStash[src] = nil
        S.markReport(rowId, src, S.stashActor[src])
        S.stashActor[src] = nil
        if S.lockHolder(rowId) == src then S.locks[rowId] = nil end
    end
end)

-- vorp_inventory still fires these legacy house events; accept and ignore them
RegisterNetEvent('vorp_housing:MoveToHouse', function() end)
RegisterNetEvent('vorp_housing:TakeFromHouse', function() end)

-- open a stash (house or motel room)
local function refuse(src, rowId, msg)
    if rowId and S.lockHolder(rowId) == src then S.locks[rowId] = nil end
    if msg then Tip(src, msg) end
    TriggerClientEvent('pup_realestate:cl_stashDone', src)
end

function S.openStashFor(src, ch, rowId)
    local r, isMotel = S.row(rowId)
    if not r then return refuse(src, nil) end
    rowId = r.id
    local spot, manage
    if isMotel then
        if r.owner ~= ch.charid or not S.insideRow(src, rowId) then return refuse(src, rowId) end
        spot = Config.MotelRoom.stash
        manage = true
    else
        if not S.hasAccess(r, ch.charid) then return refuse(src, rowId) end
        spot = U.vec(r.stash)
        manage = S.isOwner(r, ch.charid) or Config.Rules.keyholderArrangeStash == true
    end
    if not spot then return refuse(src, rowId) end
    local pos = S.pedPos(src)
    if not pos or #(pos - spot) > Config.Reach.serverStash then return refuse(src, rowId) end
    local okOpen, already = pcall(function() return INV:getOpenCustomInventory(src) end)
    if okOpen and already then return refuse(src, rowId, Locale.menu_in_use) end
    if not isMotel then
        local holder = S.lockHolder(rowId)
        if holder and holder ~= src then return refuse(src, nil, Locale.menu_in_use) end
        S.locks[rowId] = { src = src, at = Now() }
    end

    S.ensureContainer(rowId)
    local migrated = S.migrate(rowId)

    -- the waits above: check again that nothing changed
    local again = S.char(src)
    if not again or again.charid ~= ch.charid then return refuse(src, rowId) end
    r = S.row(rowId)
    if not r then return refuse(src, rowId) end
    if isMotel then
        if r.owner ~= ch.charid then return refuse(src, rowId) end
    elseif not S.hasAccess(r, ch.charid) then
        return refuse(src, rowId)
    end

    if migrated then
        SetTimeout(750, function() S.rewriteReports({ [rowId] = true }, { [rowId] = S.actor(again) }) end)
    end
    S.openStash[src] = rowId
    S.stashActor[src] = S.actor(again)
    INV:openInventory(src, S.containerId(rowId), manage == true)
end

Net('sv_stash', 1000, function(src, ch, rowId)
    S.openStashFor(src, ch, rowId)
end)

-- pup-misc's storage box re-opens a house stash after a transfer (capacity is ignored)
Net('ReloadHouseInventory', 1000, function(src, ch, rowId)
    S.openStashFor(src, ch, rowId)
end)

-- vorp_admin "Open storage": staff open the real container from anywhere with the owner's
-- controls. No ownership, key, inside or distance check, and nothing about the house changes.
-- The house lock is still honoured, so staff and the owner are never both in it.
-- Returns true, isMotel or false, reason. The caller checks manage_housing.
function S.openStashAsStaff(src, ch, rowId)
    local r, isMotel = S.row(rowId)
    if not r then return false, 'unknown house' end
    rowId = r.id
    local okOpen, already = pcall(function() return INV:getOpenCustomInventory(src) end)
    if okOpen and already then return false, 'you already have a storage open - close it first' end
    local function unlock()
        if not isMotel and S.lockHolder(rowId) == src then S.locks[rowId] = nil end
    end
    if not isMotel then
        local holder = S.lockHolder(rowId)
        if holder and holder ~= src then return false, 'someone is using this house menu or storage right now' end
        S.locks[rowId] = { src = src, at = Now() }
    end

    if not S.ensureContainer(rowId) then
        unlock()
        return false, 'could not register the storage container'
    end
    local migrated = S.migrate(rowId)

    -- the waits above: check again that nothing changed
    local again = S.char(src)
    if not again or again.charid ~= ch.charid or not S.row(rowId) then
        unlock()
        return false, 'the house or your character changed while opening'
    end
    if migrated then
        SetTimeout(750, function() S.rewriteReports({ [rowId] = true }, { [rowId] = S.actor(again) }) end)
    end

    local cid = S.containerId(rowId)
    S.openStash[src] = rowId
    S.stashActor[src] = S.actor(again)
    INV:openInventory(src, cid, true)
    local okNow, nowOpen = pcall(function() return INV:getOpenCustomInventory(src) end)
    -- getOpenCustomInventory is only in the patched vorp_inventory; without it trust openInventory
    if okNow and nowOpen ~= cid then
        S.openStash[src] = nil
        S.stashActor[src] = nil
        unlock()
        return false, 'vorp_inventory did not open the container'
    end
    return true, isMotel
end

-- an owner or keyholder losing access closes the stash they have open
function S.closeStashOf(src, rowId)
    if S.openStash[src] == rowId then
        pcall(function() INV:closeInventory(src, S.containerId(rowId)) end)
        S.openStash[src] = nil
        S.markReport(rowId, src, S.stashActor[src])
        S.stashActor[src] = nil
    end
end
