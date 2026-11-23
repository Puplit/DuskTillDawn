-- pup_hideouts | the stash (vorp_inventory hideout panel + pup-misc storage boxes)

local S <const> = Config.Storage

-- staff who opened a stash from the vorp_admin panel (AdminOpenStash): [src] = hideout id.
-- They take no stash lock and need no membership; manage_hideouts is checked on every action.
local StaffView = {}
local STAFF_ACTION <const> = 'manage_hideouts'

local function adminAllowed(src)
    if GetResourceState('vorp_admin') ~= 'started' then return false end
    local ok, yes = pcall(Config.Integrations.adminAllowed, src, STAFF_ACTION)
    if not ok then U.warnIntegration('adminAllowed', yes) return false end
    return yes == true
end

-- a staff viewer of this hideout's stash while the hideout exists and vorp_admin still allows it
local function staffViewing(src, id)
    local v = StaffView[src]
    if not v or v ~= tonumber(id) then return false end
    if HX.hideouts[v] and GetPlayerName(src) and adminAllowed(src) then return true end
    StaffView[src] = nil
    return false
end

-- keep every staff viewer's open grid in step (skip: sources already reloaded)
local function reloadStaff(h, skipA, skipB)
    for s, id in pairs(StaffView) do
        if id == h.id and s ~= skipA and s ~= skipB then
            if GetPlayerName(s) then HX.reloadStashFor(s, h) else StaffView[s] = nil end
        end
    end
end

local function total(h)
    local n = 0
    for _, it in ipairs(h.items) do n = n + it.count end
    return n
end
HX.stashTotal = total

local function nextId(h)
    local m = 0
    for _, it in ipairs(h.items) do if it.id > m then m = it.id end end
    return m + 1
end

local function isWeapon(name, itype)
    return itype == 'item_weapon' or (type(name) == 'string' and name:upper():sub(1, 7) == 'WEAPON_')
end

local function refused(name, itype)
    return isWeapon(name, itype) or S.blacklist[name] == true
end

-- who may use the stash: members or the loot crew; inside, or (members via boxes) near the door
local function access(src, h)
    if not h or h.invlevel == 0 then return false, 'owner_only' end
    local cid = HX.charId(src)
    if not (HX.isMember(h, cid) or HX.isCrew(h, cid)) then return false, 'owner_only' end
    if HX.isInside(src, h) then return true end
    if HX.bucket(src) == 0 and U.dist(HX.pos(src), h.coords) <= S.doorReach then return true end
    return false, 'too_far'
end
HX.stashAccess = access

local function payloadItems(h)
    local list = {}
    for _, it in ipairs(h.items) do
        list[#list + 1] = {
            id = it.id, name = it.name, label = it.label, count = it.count, limit = it.limit,
            type = it.type, metadata = it.metadata, canUse = false, canRemove = true,
        }
    end
    return list
end

function HX.reloadStashFor(src, h)
    if not GetPlayerName(src) then return end
    TriggerClientEvent('vorp_inventory:ReloadHideoutInventory', src, json.encode({
        action = 'setSecondInventoryItems',
        itemList = payloadItems(h),
        info = { id = tostring(h.id), type = 'hideout' },
    }))
end

function HX.reloadStashInside(h)
    local done = {}
    for _, s in ipairs(HX.insideSources(h)) do
        HX.reloadStashFor(s, h)
        done[s] = true
    end
    for s, id in pairs(StaffView) do
        if id == h.id and not done[s] then
            if GetPlayerName(s) then HX.reloadStashFor(s, h) else StaffView[s] = nil end
        end
    end
end

local function commit(h, src)
    HX.save(h, { 'items' })
    if src then HX.reloadStashFor(src, h) end
    local holder = HX.stashLock[h.id]
    if holder and holder ~= src then HX.reloadStashFor(holder, h) end
    reloadStaff(h, src, holder)
end

-- add count of name/metadata into the stash rows (no capacity check here)
local function putIn(h, name, label, count, metadata, itype, limit)
    if U.isEmpty(metadata) then
        for _, it in ipairs(h.items) do
            if it.name == name and U.isEmpty(it.metadata) then
                it.count = it.count + count
                return it
            end
        end
    end
    -- labels reach every member's stash panel; keep markup out of them
    label = (tostring(label or name):gsub('[<>]', ''))
    local row = {
        id = nextId(h), name = name, label = label, count = count, limit = tonumber(limit) or 100,
        type = itype or 'item_standard', metadata = U.isEmpty(metadata) and {} or metadata,
    }
    h.items[#h.items + 1] = row
    return row
end
HX.stashPutIn = putIn

local function rowById(h, id)
    id = tonumber(id)
    for i, it in ipairs(h.items) do if it.id == id then return it, i end end
    return nil
end

local function takeRow(h, row, count)
    row.count = row.count - count
    if row.count <= 0 then
        for i, it in ipairs(h.items) do
            if it == row then table.remove(h.items, i) break end
        end
    end
end
HX.stashTakeRow = takeRow

-- remove an amount of an item by name from the stash rows (for recipes); false when short
function HX.stashRemove(h, name, amount)
    local have = 0
    for _, it in ipairs(h.items) do if it.name == name then have = have + it.count end end
    if have < amount then return false end
    local left = amount
    for i = #h.items, 1, -1 do
        local it = h.items[i]
        if left <= 0 then break end
        if it.name == name then
            local n = math.min(it.count, left)
            it.count = it.count - n
            left = left - n
            if it.count <= 0 then table.remove(h.items, i) end
        end
    end
    return true
end

function HX.stashCount(h, name)
    local have = 0
    for _, it in ipairs(h.items) do if it.name == name then have = have + it.count end end
    return have
end

----------------------------------------------------------------------------------------------------
-- opening
----------------------------------------------------------------------------------------------------
HX.rpc('stashBusy', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h then return true end
    local holder = HX.stashLock[h.id]
    return holder ~= nil and holder ~= src and GetPlayerName(holder) ~= nil and HX.isInside(holder, h)
end, 300)

HX.rpc('stashOpen', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    local ok, why = access(src, h)
    if not ok then HX.tip(src, L(why)) return false end
    local holder = HX.stashLock[h.id]
    if holder and holder ~= src and GetPlayerName(holder) and HX.isInside(holder, h) then
        HX.tip(src, L('menu_in_use'))
        return false
    end
    HX.stashLock[h.id] = src
    SetTimeout(300, function() HX.reloadStashFor(src, h) end)
    return true, h.invslots
end, 800)

HX.on('stashClosed', function(src)
    for id, holder in pairs(HX.stashLock) do
        if holder == src then HX.stashLock[id] = nil end
    end
    StaffView[src] = nil
end, 100)

-- vorp_admin "Open storage": the hideout's real stash panel for a staff member, from anywhere,
-- with the owner's controls (take out, put in, sort). No membership is given and no stash lock
-- is taken, so members inside can still use it; every open grid is kept in step.
-- vorp_admin checks manage_hideouts before calling; it is checked again here and on every
-- take, deposit, sort and reorder. Returns true, or false and a reason.
exports('AdminOpenStash', function(src, hideoutId)
    src = tonumber(src)
    if not HX.ready then return false, 'pup_hideouts is still loading.' end
    if not src or not GetPlayerName(src) or not HX.char(src) then return false, 'No character loaded.' end
    if not adminAllowed(src) then return false, 'Not allowed (' .. STAFF_ACTION .. ').' end
    local h = HX.hideouts[tonumber(hideoutId)]
    if not h then return false, 'No hideout with that id.' end

    -- let go of any stash this player was holding first
    for id, holder in pairs(HX.stashLock) do
        if holder == src then HX.stashLock[id] = nil end
    end
    local id, slots = h.id, h.invslots
    StaffView[src] = id
    -- the client reports the close back (stashClosed) only for a panel it knows about
    TriggerClientEvent('pup_hideouts:staffStash', src, id)
    TriggerClientEvent('vorp_inventory:OpenHideoutInventory', src, L('stash_limit', slots), id, slots)
    SetTimeout(300, function()
        local fresh = HX.hideouts[id]
        if fresh and StaffView[src] == id then HX.reloadStashFor(src, fresh) end
    end)
    Logs.send('Inventory', 'Admin Opened Stash', 'Opened from the vorp_admin panel with the owner\'s controls.',
        'default', src, { { 'Used', ('%d / %d'):format(total(h), slots), true } }, h)
    return true
end)

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then StaffView[src] = nil end
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then StaffView[src] = nil end
end)

----------------------------------------------------------------------------------------------------
-- vorp_inventory panel events
----------------------------------------------------------------------------------------------------
local function decodePayload(raw)
    local d = U.decode(raw, nil)
    if type(d) ~= 'table' then return nil end
    return d
end

-- vorp_inventory keeps the panel "pending" until a reload arrives, so every path through these
-- events ends in one (also a rate-limited or refused request).
local function panelEvent(name, rateMs, handler)
    RegisterNetEvent('pup_hideouts:' .. name, function(raw)
        local src = tonumber(source)
        if not src or not GetPlayerName(src) or not HX.ready or not HX.char(src) then return end
        local d = decodePayload(raw)
        local h = d and HX.hideouts[tonumber(d.hideout)]
        if not h then return end
        if not HX.rateOk(src, 'panel:' .. name, rateMs) then return HX.reloadStashFor(src, h) end
        -- a vorp_admin staff viewer of this stash (manage_hideouts re-checked here), else the usual rules
        local staff = staffViewing(src, h.id)
        if not staff then
            local ok, why = access(src, h)
            if not ok then
                HX.tip(src, L(why))
                return HX.reloadStashFor(src, h)
            end
        end
        handler(src, d, h, staff)
    end)
end

panelEvent('MoveToHideout', 400, function(src, d, h, staff)
    if type(d.item) ~= 'table' then return HX.reloadStashFor(src, h) end
    local amount = U.posInt(d.number)
    local itemId = tonumber(d.item.id)
    if not amount or not itemId then return HX.reloadStashFor(src, h) end

    -- the real stack, by its id, read from the player's own inventory
    local okGet, real = pcall(function() return Inv:getItemByMainId(src, itemId) end)
    if not okGet or type(real) ~= 'table' or not real.name then return HX.reloadStashFor(src, h) end
    if refused(real.name, real.type) or isWeapon(d.item.name, d.type) then
        HX.tip(src, L('item_not_allowed'))
        return HX.reloadStashFor(src, h)
    end
    if (tonumber(real.count) or 0) < amount then return HX.reloadStashFor(src, h) end
    if total(h) + amount > h.invslots then
        HX.tip(src, L('stash_full', h.invslots))
        return HX.reloadStashFor(src, h)
    end
    local okSub, removed = pcall(function() return Inv:subItemById(src, itemId, nil, nil, amount) end)
    if not okSub or removed ~= true then return HX.reloadStashFor(src, h) end
    -- the await-free path above means h is still the same row; re-check it was not deleted
    h = HX.hideouts[h.id]
    if not h then
        HX.addItem(src, real.name, amount, not U.isEmpty(real.metadata) and real.metadata or nil)
        return
    end
    local label = (real.metadata and real.metadata.label) or real.label or HX.itemLabel(real.name)
    putIn(h, real.name, label, amount, real.metadata, real.type, real.limit)
    commit(h, src)
    Logs.send('Inventory', staff and 'Item Deposited (Admin)' or 'Item Deposited', ('%s x%d'):format(label, amount), 'itemDeposited', src,
        { { 'Item', ('%s (%s)'):format(label, real.name), true }, { 'Quantity', tostring(amount), true }, { 'Action', staff and 'Deposit (Admin)' or 'Deposit', true } }, h)
end)

panelEvent('TakeFromHideout', 400, function(src, d, h, staff)
    if type(d.item) ~= 'table' then return HX.reloadStashFor(src, h) end
    local row = rowById(h, d.item.id)
    local amount = U.posInt(d.number)
    if not row or not amount then return HX.reloadStashFor(src, h) end
    amount = math.min(amount, row.count)
    if not HX.canCarry(src, row.name, amount) then
        HX.tip(src, L('cant_carry'))
        return HX.reloadStashFor(src, h)
    end
    local name, label, meta, rtype, rlimit = row.name, row.label, row.metadata, row.type, row.limit
    takeRow(h, row, amount)
    local given = HX.addItem(src, name, amount, not U.isEmpty(meta) and meta or nil)
    h = HX.hideouts[h.id]
    if not h then return end
    if not given then
        putIn(h, name, label, amount, meta, rtype, rlimit)
        commit(h, src)
        HX.tip(src, L('cant_carry'))
        return
    end
    commit(h, src)
    Logs.send('Inventory', staff and 'Item Withdrawn (Admin)' or 'Item Withdrawn', ('%s x%d'):format(label, amount), 'itemWithdrawn', src,
        { { 'Item', ('%s (%s)'):format(label, name), true }, { 'Quantity', tostring(amount), true }, { 'Action', staff and 'Withdraw (Admin)' or 'Withdraw', true } }, h)
end)

panelEvent('SortHideoutInventory', 1000, function(src, _, h)
    table.sort(h.items, function(a, b)
        local wa, wb = isWeapon(a.name, a.type), isWeapon(b.name, b.type)
        if wa ~= wb then return not wa end
        local la, lb = tostring(a.label):lower(), tostring(b.label):lower()
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
    commit(h, src)
end)

panelEvent('ChangeOrderHideout', 1000, function(src, d, h)
    if type(d.inventoryItems) ~= 'table' then return HX.reloadStashFor(src, h) end
    local byId, seen, ordered = {}, {}, {}
    for _, it in ipairs(h.items) do byId[it.id] = it end
    for _, e in ipairs(d.inventoryItems) do
        local id = tonumber(type(e) == 'table' and e.id or e)
        local it = id and byId[id]
        if not it or seen[id] then return HX.reloadStashFor(src, h) end
        seen[id] = true
        ordered[#ordered + 1] = it
    end
    for _, it in ipairs(h.items) do
        if not seen[it.id] then ordered[#ordered + 1] = it end
    end
    h.items = ordered
    commit(h, src)
end)

-- pup-misc logs storage-box withdrawals through us
AddEventHandler('pup_hideouts:stashtaken_log', function(actor, hideoutId, item, qty)
    local h = HX.hideouts[tonumber(hideoutId)]
    if not h or type(item) ~= 'table' then return end
    local label = tostring(item.label or item.name or '?')
    Logs.send('Inventory', 'Item Withdrawn', ('%s x%s'):format(label, tostring(qty)), 'itemWithdrawn', tonumber(actor),
        { { 'Item', ('%s (%s)'):format(label, tostring(item.name)), true }, { 'Quantity', tostring(qty), true }, { 'Action', 'Withdraw (storage box)', true } }, h)
end)

----------------------------------------------------------------------------------------------------
-- storage-box bridge (pup-misc)
----------------------------------------------------------------------------------------------------
local function rowsCopy(h)
    local out = {}
    for _, it in ipairs(h.items) do
        out[#out + 1] = { id = it.id, name = it.name, label = it.label, count = it.count, limit = it.limit, type = it.type, metadata = U.copy(it.metadata) }
    end
    return out
end

exports('BoxStashItems', function(src, hideoutId)
    src = tonumber(src)
    local h = HX.hideouts[tonumber(hideoutId)]
    if not src or not access(src, h) then return nil end
    return rowsCopy(h)
end)

exports('BoxStashTake', function(src, hideoutId, entryId, name, metadata, amount)
    src = tonumber(src)
    local h = HX.hideouts[tonumber(hideoutId)]
    amount = U.posInt(amount)
    if not src or not amount or not access(src, h) then return false end
    local row
    if entryId ~= nil then
        row = rowById(h, entryId)
        if row and row.name ~= name then row = nil end
    else
        for _, it in ipairs(h.items) do
            if it.name == name and U.sameMeta(it.metadata, metadata) then row = it break end
        end
    end
    if not row then return false end
    amount = math.min(amount, row.count)
    takeRow(h, row, amount)
    commit(h, nil)
    HX.reloadStashInside(h)
    return true, rowsCopy(h)
end)

-- items a box could not hold come back; no access check and nothing new enters
exports('BoxStashReturn', function(hideoutId, name, metadata, amount, label)
    local h = HX.hideouts[tonumber(hideoutId)]
    amount = U.posInt(amount)
    if not h or not amount or type(name) ~= 'string' then return false end
    putIn(h, name, label or name, amount, metadata)
    commit(h, nil)
    HX.reloadStashInside(h)
    return true
end)

exports('BoxStashPut', function(src, hideoutId, items)
    src = tonumber(src)
    local h = HX.hideouts[tonumber(hideoutId)]
    if not src or type(items) ~= 'table' or not access(src, h) then return false end
    local sum = 0
    for _, it in ipairs(items) do
        local c = U.posInt(it.count)
        if type(it.name) ~= 'string' or not c or refused(it.name, it.type) then return false end
        sum = sum + c
    end
    if total(h) + sum > h.invslots then return false end
    for _, it in ipairs(items) do
        putIn(h, it.name, it.label or it.name, U.posInt(it.count), it.metadata)
    end
    commit(h, nil)
    HX.reloadStashInside(h)
    return true
end)
