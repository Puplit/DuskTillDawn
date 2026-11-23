-- pup_business | the business stash (a vorp_inventory container)

local function invRunning() return GetResourceState('vorp_inventory') == 'started' end

function BoughtSlots(job)
    local b = Biz[job]
    if not b or not b.containerid then return 0 end
    return PB.int(MySQL.scalar.await('SELECT invslots FROM container WHERE id = ? LIMIT 1', { b.containerid })) or 0
end

-- makes sure the container row exists (name = job code, empty items)
function EnsureContainerRow(job)
    local b = Biz[job]
    if not b or not b.containerid then return false end
    MySQL.insert.await("INSERT IGNORE INTO container (id, name, items, invslots) VALUES (?, ?, '[]', 0)", { b.containerid, job })
    return true
end

-- registers (or refreshes) the live container with its current size
function RegisterStash(job, bought)
    local b = Biz[job]
    if not b or not b.containerid or not invRunning() then return false end
    bought = bought or BoughtSlots(job)
    local id = tostring(b.containerid)
    local limit = Config.BaseSlots + math.max(0, bought)
    local useBlacklist = #Config.StashBlacklist > 0
    local inv = exports.vorp_inventory
    local ok, err = pcall(function()
        local registered = inv:isCustomInventoryRegistered(id)
        if not registered then
            inv:registerInventory({
                id = id,
                name = b.containername,
                limit = limit,
                acceptWeapons = true,
                shared = true,
                ignoreItemStackLimit = true,
                whitelistItems = false,
                whitelistWeapons = false,
                UsePermissions = false,
                UseBlackList = useBlacklist,
            })
            if useBlacklist then
                for _, name in ipairs(Config.StashBlacklist) do inv:BlackListCustomAny(id, name) end
            end
        else
            inv:updateCustomInventoryData(id, { name = b.containername })
        end
        inv:updateCustomInventorySlots(id, limit)
    end)
    if not ok then print(('^1[%s]^7 registering stash %s failed: %s'):format(RES, id, tostring(err))) end
    return ok
end

-- boss, the stash permission, or a grade at or above the access grade
function CanOpenStash(job, grade)
    return HasRankPerm(job, grade, 'stash') or (tonumber(grade) or 0) >= StashAccessGrade(job)
end

-- access grade and buying slots: VORP admin group, grade >= the fixed manage
-- grade, or the Manage Storage permission (the boss holds every permission)
local function canManageStash(src, ch)
    if IsGroupAdmin(src) then return true end
    if not Biz[ch.job] then return false end
    local g = CharGrade(ch)
    return g >= Config.StashManageGrade or HasRankPerm(ch.job, g, 'store')
end

Handle('openStash', 1500, function(src, ch)
    local job, grade = ch.job, CharGrade(ch)
    local b = Biz[job]
    if not b then Notify(src, L('not_in_business')) return false end
    if not CanOpenStash(job, grade) then Notify(src, L('stash_denied')) return false end
    if not invRunning() then Notify(src, L('action_failed')) return false end
    EnsureContainerRow(job)
    RegisterStash(job)
    -- the rank may have changed while the database answered
    local again = GetCharIf(src, CharId(ch))
    if not again or again.job ~= job or not CanOpenStash(job, CharGrade(again)) then return false end
    local id = tostring(b.containerid)
    StashOpenBy[src] = id
    if StaffStash then StaffStash[src] = nil end -- an ordinary open, not a staff one
    exports.vorp_inventory:openInventory(src, id, IsBossGrade(job, grade))
    return true
end)

Handle('setAccess', 750, function(src, ch, grade)
    grade = PB.int(grade)
    local job = ch.job
    local b = Biz[job]
    if not b then Notify(src, L('not_in_business')) return false end
    if not canManageStash(src, ch) then Notify(src, L('no_permission')) return false end
    if not grade or grade < 0 or grade > b.bossrank then Notify(src, L('invalid_grade')) return false end
    LedgerEnsure(job)
    MySQL.update.await('UPDATE society_ledger SET invaccess = ? WHERE job = ? LIMIT 1', { grade, job })
    LedgerInfo[job] = LedgerInfo[job] or { webhook = '', invaccess = 0 }
    LedgerInfo[job].invaccess = grade
    PushBusinesses(-1)
    Notify(src, L('access_set', grade))
    return true
end)

Handle('buySlots', 1500, function(src, ch, count)
    count = tonumber(count)
    if not count or count ~= math.floor(count) or count < 1 or count > Config.MaxSlotPurchase then
        Notify(src, L('invalid_amount')) return false
    end
    local job = ch.job
    local b = Biz[job]
    if not b then Notify(src, L('not_in_business')) return false end
    if not canManageStash(src, ch) then Notify(src, L('no_permission')) return false end
    if not b.containerid then Notify(src, L('container_missing')) return false end
    EnsureContainerRow(job)
    local before = LedgerGet(job)
    if before == nil then Notify(src, L('ledger_not_found')) return false end

    local cost = count * Config.SlotPrice
    if not LedgerTake(job, cost) then Notify(src, L('ledger_need', PB.money(cost))) return false end
    local okQ, n = pcall(MySQL.update.await, 'UPDATE container SET invslots = invslots + ? WHERE id = ?', { count, b.containerid })
    if not okQ or (tonumber(n) or 0) == 0 then
        LedgerAdd(job, cost)
        Notify(src, L('slots_update_failed'))
        return false
    end
    local bought = BoughtSlots(job)
    RegisterStash(job, bought)
    Notify(src, L('slots_bought', count, PB.money(cost)))
    Activity(job, 'SLOTS', ('Bought %d storage slots for %s'):format(count, PB.money(cost)), FullName(ch))
    TriggerClientEvent('pup_business:findnewhired', src)
    CreateThread(function()
        local after = LedgerGet(job) or 0
        SendLog(job, 'Storage slots bought', COLOUR.blue, table.pack(
            F('Who', WhoText(src)), F('Slots added', count, true), F('Cost', PB.money(cost), true),
            F('Ledger', LedgerText(before, -cost, after)), F('Container', b.containerid, true), F('Business', job, true)))
    end)
    return true
end)

---------------------------------------------------------------------------
-- audit mirror: a readable copy of the stash on the container row
---------------------------------------------------------------------------

function BuildSnapshot(containerid)
    local id = tostring(containerid)
    local out = {}
    local items = MySQL.query.await([[
        SELECT ci.amount AS amount, ic.metadata AS metadata, i.item AS item
        FROM character_inventories ci
        LEFT JOIN items_crafted ic ON ic.id = ci.item_crafted_id
        LEFT JOIN items i ON i.id = ic.item_id
        WHERE ci.inventory_type = ?
    ]], { id }) or {}
    for _, r in ipairs(items) do
        if r.item then
            local entry = { name = r.item, count = tonumber(r.amount) or 0 }
            if type(r.metadata) == 'string' and r.metadata ~= '' then
                local ok, md = pcall(json.decode, r.metadata)
                if ok and type(md) == 'table' and next(md) ~= nil then entry.metadata = md end
            end
            out[#out + 1] = entry
        end
    end
    local weapons = MySQL.query.await(
        'SELECT name, label, serial_number, tier FROM loadout WHERE curr_inv = ? AND (dropped = 0 OR dropped IS NULL)', { id }) or {}
    for _, w in ipairs(weapons) do
        out[#out + 1] = {
            name = w.name, count = 1, weapon = true,
            label = w.label or w.name, serial = w.serial_number or '', tier = tonumber(w.tier) or 0,
        }
    end
    MySQL.update.await('UPDATE container SET items = ? WHERE id = ?', { json.encode(out), containerid })
end

local pendingSnap = {}

-- several moves in a row produce one rebuild
local function queueSnapshot(containerid)
    if pendingSnap[containerid] then return end
    pendingSnap[containerid] = true
    SetTimeout(1000, function()
        pendingSnap[containerid] = nil
        BuildSnapshot(containerid)
    end)
end

local function itemLabel(item)
    if item.label and item.label ~= '' then return item.label end
    local ok, def = pcall(function() return exports.vorp_inventory:getItemDB(item.name) end)
    if ok and type(def) == 'table' and def.label then return def.label end
    return tostring(item.name or '?')
end

-- [src] = container id text that vorp_admin opened for a staff member (adminOpenStash)
StaffStash = {}

RegisterNetEvent('vorp_inventory:Server:CloseCustomInventory', function()
    StaffStash[source] = nil
end)

AddEventHandler('playerDropped', function()
    StaffStash[source] = nil
end)

local function onStashMove(item, invId, src, taken)
    local job = BusinessOfContainer(invId)
    if not job or type(item) ~= 'table' then return end
    queueSnapshot(Biz[job].containerid)
    local weapon = item.type == 'item_weapon'
    local staff = src ~= nil and StaffStash[tonumber(src)] == tostring(invId)
    local title = (taken and 'Storage withdrawal' or 'Storage deposit') .. (weapon and ' (weapon)' or '')
        .. (staff and ' (admin)' or '')
    SendLog(job, title, taken and COLOUR.orange or COLOUR.green, table.pack(
        F('Who', src and WhoText(src) or nil),
        F(weapon and 'Weapon' or 'Item', itemLabel(item), true),
        weapon and F('Serial', item.serial, true) or F('Quantity', item.amount, true)))
end

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(item, invId, src)
    onStashMove(item, invId, src, false)
end)

AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', function(item, invId, src)
    onStashMove(item, invId, src, true)
end)

-- pup_railroad expects this name to belong here: refresh one business stash
RegisterNetEvent('pup-Container:reloadContainerInventory', function(containerId)
    local src = source
    if not Throttle(src, 'reloadContainer', 3000) then return end
    local ch = GetChar(src)
    if not ch then return end
    local job = BusinessOfContainer(containerId)
    if not job then return end
    if ch.job ~= job and not IsPanelAdmin(src) then return end
    EnsureContainerRow(job)
    RegisterStash(job)
    BuildSnapshot(Biz[job].containerid)
end)

---------------------------------------------------------------------------
-- start-up: rows, registration, snapshots
---------------------------------------------------------------------------

local booting = false

function BootStashes()
    if booting or not invRunning() then return end
    booting = true
    CreateThread(function()
        Wait(1500)
        WaitLoaded(10000)
        for job in pairs(Biz) do
            EnsureContainerRow(job)
            RegisterStash(job)
        end
        Wait(1000)
        for _, b in pairs(Biz) do
            if b.containerid then
                BuildSnapshot(b.containerid)
                Wait(50)
            end
        end
        booting = false
    end)
end

AddEventHandler('onResourceStart', function(name)
    if name == 'vorp_inventory' then BootStashes() end
end)

---------------------------------------------------------------------------
-- admin: empty a stash
---------------------------------------------------------------------------

function ClearStash(job)
    local b = Biz[job]
    if not b or not b.containerid then return nil end
    local id = tostring(b.containerid)
    local stacks = 0
    if invRunning() then
        RegisterStash(job)
        local inv = exports.vorp_inventory
        -- one call per stored row: getCustomInventoryItems merges stacks and keeps only the first crafted id
        local rows = MySQL.query.await(
            'SELECT item_name, amount, item_crafted_id FROM character_inventories WHERE inventory_type = ?', { id }) or {}
        for _, r in ipairs(rows) do
            local amt = tonumber(r.amount) or 0
            if r.item_name and amt > 0 then
                pcall(function() inv:removeItemFromCustomInventory(id, r.item_name, amt, r.item_crafted_id) end)
            end
            stacks = stacks + 1
        end
        local okW, weapons = pcall(function() return inv:getCustomInventoryWeapons(id) end)
        if okW and type(weapons) == 'table' then
            for _, w in ipairs(weapons) do
                pcall(function() inv:removeCustomInventoryWeaponById(id, w.id) end)
                stacks = stacks + 1
            end
        end
    end
    local n = MySQL.update.await('DELETE FROM character_inventories WHERE inventory_type = ?', { id })
    stacks = math.max(stacks, tonumber(n) or 0)
    MySQL.update.await("UPDATE container SET items = '[]' WHERE id = ?", { b.containerid })
    return stacks
end
