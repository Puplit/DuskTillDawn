-- pup-mdt | physical evidence lockers (one shared vorp_inventory stash per station)

Lockers = { busy = {}, refreshQueued = false, registered = false }

local E = Config.Evidence
local PREFIX = 'evidence_'

local function stationById(id)
    for _, s in ipairs(E.stations) do if s.id == id then return s end end
end

local function nearestStation(coords, maxDist)
    if not coords then return nil end
    local best, bestD
    for _, s in ipairs(E.stations) do
        local d = MDT.dist(coords, s.coords)
        if (not maxDist or d <= maxDist) and (not bestD or d < bestD) then best, bestD = s, d end
    end
    return best
end

-- job on the locker list and (when required) on duty
local function mayUse(src)
    if not E.enabled then return false end
    local a = MDT.player(src)
    if not a or not MDT.inList(E.jobs, a.job) then return false end
    if E.requireDuty and not Duty.isOn(src) then return false end
    return true, a
end

function Lockers.stationNear(src)
    local s = nearestStation(MDT.coords(src), E.stationRadius)
    return s and s.id or nil
end

---------------------------------------------------------------------------
-- Stashes
---------------------------------------------------------------------------
local function registerAll()
    if not E.enabled or GetResourceState('vorp_inventory') ~= 'started' then return end
    for _, s in ipairs(E.stations) do
        exports.vorp_inventory:registerInventory({
            id = PREFIX .. s.id, name = 'Evidence Locker - ' .. s.label, limit = 100000,
            acceptWeapons = true, shared = true, ignoreItemStackLimit = true,
        })
    end
    Lockers.registered = true
end

-- old split ids become one stash per station
local function migrateIds()
    DB.upd("UPDATE character_inventories SET inventory_type = CONCAT('evidence_', SUBSTRING(inventory_type, 16)) WHERE inventory_type LIKE 'evidence\\_items\\_%'")
    DB.upd("UPDATE character_inventories SET inventory_type = CONCAT('evidence_', SUBSTRING(inventory_type, 18)) WHERE inventory_type LIKE 'evidence\\_weapons\\_%'")
    DB.upd("UPDATE loadout SET curr_inv = CONCAT('evidence_', SUBSTRING(curr_inv, 16)) WHERE curr_inv LIKE 'evidence\\_items\\_%'")
    DB.upd("UPDATE loadout SET curr_inv = CONCAT('evidence_', SUBSTRING(curr_inv, 18)) WHERE curr_inv LIKE 'evidence\\_weapons\\_%'")
end

---------------------------------------------------------------------------
-- Mirror table
---------------------------------------------------------------------------
function Lockers.rebuild()
    local items = DB.q([[SELECT ci.inventory_type, ci.amount, ci.character_id, ic.item_name, ic.metadata, i.label,
            c.firstname, c.lastname
        FROM character_inventories ci
        JOIN items_crafted ic ON ic.id = ci.item_crafted_id
        LEFT JOIN items i ON i.item = ic.item_name
        LEFT JOIN characters c ON c.charidentifier = ci.character_id
        WHERE ci.inventory_type LIKE 'evidence\_%']])
    local weapons = DB.q([[SELECT l.id, l.name, l.label, l.custom_label, l.serial_number, l.curr_inv, c.firstname, c.lastname
        FROM loadout l LEFT JOIN characters c ON c.charidentifier = l.charidentifier
        WHERE l.curr_inv LIKE 'evidence\_%' AND l.dropped = 0]])
    local by = {}
    for _, s in ipairs(E.stations) do by[PREFIX .. s.id] = { items = {}, weapons = {} } end
    for _, r in ipairs(items) do
        local b = by[r.inventory_type]
        if b then
            b.items[#b.items + 1] = { name = r.item_name, label = r.label or r.item_name, count = tonumber(r.amount) or 0,
                from = r.firstname and (r.firstname .. ' ' .. (r.lastname or '')) or nil, metadata = MDT.jdec(r.metadata, {}) }
        end
    end
    for _, r in ipairs(weapons) do
        local b = by[r.curr_inv]
        if b then
            b.weapons[#b.weapons + 1] = { id = r.id, name = r.name, label = r.custom_label or r.label or r.name, serial = r.serial_number,
                from = r.firstname and (r.firstname .. ' ' .. (r.lastname or '')) or nil }
        end
    end
    for _, s in ipairs(E.stations) do
        local b = by[PREFIX .. s.id]
        DB.q([[INSERT INTO evidence_lockers (station, label, items, weapons, updated) VALUES (?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE label = VALUES(label), items = VALUES(items), weapons = VALUES(weapons), updated = VALUES(updated)]],
            { s.id, s.label, MDT.jenc(b.items), MDT.jenc(b.weapons), os.time() })
    end
end

function Lockers.queueRebuild()
    if Lockers.refreshQueued then return end
    Lockers.refreshQueued = true
    SetTimeout(500, function()
        Lockers.refreshQueued = false
        local ok, err = pcall(Lockers.rebuild)
        if not ok then print('^1[pup-mdt]^7 evidence mirror: ' .. tostring(err)) end
    end)
end

local function isEvidence(invId) return type(invId) == 'string' and invId:sub(1, #PREFIX) == PREFIX end

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', function(_, invId)
    if isEvidence(invId) then Lockers.queueRebuild() end
end)

AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', function(item, invId, src)
    if not isEvidence(invId) then return end
    local station = invId:sub(#PREFIX + 1)
    local who = MDT.player(src)
    -- the original owner from the mirror, before it is rebuilt
    local from = '-'
    local row = DB.one('SELECT items, weapons FROM evidence_lockers WHERE station = ?', { station })
    if row and type(item) == 'table' then
        for _, x in ipairs(MDT.jdec(item.type == 'item_weapon' and row.weapons or row.items, {})) do
            if (item.type == 'item_weapon' and tonumber(x.id) == tonumber(item.id)) or (item.type ~= 'item_weapon' and x.name == item.name) then
                from = x.from or '-'
                break
            end
        end
    end
    MDT.log('evidence_locker', 'Removed from evidence', ('%s took %sx %s%s from the %s locker (originally from %s)'):format(
        who and who.name or tostring(src), tostring(item and item.amount or 1), tostring(item and (item.label or item.name) or '?'),
        item and item.serial and (' [' .. item.serial .. ']') or '', station, from), 'orange')
    Lockers.queueRebuild()
end)

---------------------------------------------------------------------------
-- Opening and seizing
---------------------------------------------------------------------------
Core.Callback.Register('pup-mdt:evidence:canSeize', function(source, cb)
    if not mayUse(source) then return cb(false) end
    cb(Lockers.stationNear(source) or false)
end)

RegisterNetEvent('pup-mdt:server:lockerOpen', function(stationId)
    local src = source
    if not mayUse(src) then return MDT.notify(src, L('ev_locker_denied'), 4000) end
    local s = stationById(stationId)
    if not s or not MDT.near(src, s.coords, E.promptDistance + 1.0) then return end
    if not Lockers.registered then registerAll() end
    exports.vorp_inventory:openInventory(src, PREFIX .. s.id)
end)

local function seizeOne(src, item)
    local ok, officer = mayUse(src)
    if not ok then return MDT.notify(src, L('ev_locker_denied'), 4000) end
    if type(item) ~= 'table' then return end
    local okT, target = pcall(function() return exports['pup-misc']:GetSearchTarget(src) end)
    target = okT and tonumber(target) or nil
    if not target or not MDT.online(target) then return MDT.notify(src, L('ev_not_searching'), 4000) end
    local stationId = Lockers.stationNear(src)
    if not stationId then return MDT.notify(src, L('ev_no_station'), 4000) end
    if MDT.dist(MDT.coords(src), MDT.coords(target)) > E.targetDistance then return MDT.notify(src, L('ev_target_far'), 4000) end
    local tChar = MDT.char(target)
    if not tChar then return end
    local invId = PREFIX .. stationId
    if not Lockers.registered then registerAll() end
    local isWeapon = item.type == 'item_weapon'
    local id = tonumber(item.id)
    if not id then return end
    local name, label, amount, serial
    if isWeapon then
        -- seizeWeaponToCustomInventory only exists in the patched vorp_inventory (docs/vorp_inventory)
        local okCall, okW, err = pcall(function() return exports.vorp_inventory:seizeWeaponToCustomInventory(target, id, invId) end)
        if not okCall then okW, err = false, 'vorp_inventory has no seizeWeaponToCustomInventory export' end
        if not okW then return MDT.notify(src, L('ev_seize_failed', tostring(err or '')), 5000) end
        name, label, amount, serial = MDT.str(item.name, 60), MDT.str(item.label, 60), 1, MDT.str(item.serial, 60)
    else
        local row = exports.vorp_inventory:getItemByMainId(target, id)
        if not row then return MDT.notify(src, L('ev_seize_failed', 'item'), 5000) end
        name, label, amount = row.name, row.label, tonumber(row.count) or 1
        if not exports.vorp_inventory:subItemID(target, id, nil, false, amount) then
            return MDT.notify(src, L('ev_seize_failed', 'remove'), 5000)
        end
        local added = exports.vorp_inventory:addItemsToCustomInventory(invId, { { name = name, amount = amount, metadata = row.metadata or {} } }, tonumber(tChar.charIdentifier))
        if not added then
            -- put it back; if even that fails, say so loudly so staff can return it by hand
            local back = MDT.online(target) and exports.vorp_inventory:addItem(target, name, amount, row.metadata)
            if not back then
                print(('^1[pup-mdt]^7 seizure rollback failed: %dx %s for character %s'):format(amount, tostring(name), tostring(tChar.charIdentifier)))
                MDT.log('evidence_locker', 'Seizure rollback FAILED', ('%dx %s could not be returned to %s (character %s)'):format(
                    amount, tostring(name), MDT.str((tChar.firstname or '') .. ' ' .. (tChar.lastname or ''), 100), tostring(tChar.charIdentifier)), 'red')
            end
            return MDT.notify(src, L('ev_seize_failed', 'locker'), 5000)
        end
    end
    Lockers.queueRebuild()
    local st = stationById(stationId)
    local tName = MDT.str((tChar.firstname or '') .. ' ' .. (tChar.lastname or ''), 100)
    MDT.notify(src, L('ev_seized', amount, label or name, st.label), 5000)
    MDT.notify(target, L('ev_seized_from_you', amount, label or name), 5000)
    MDT.log('evidence_locker', 'Booked into evidence', ('%s booked %sx %s%s from %s into %s'):format(
        officer.name, amount, label or name, serial and serial ~= '' and (' [' .. serial .. ']') or '', tName, st.label), 'blue')
    TriggerEvent('pup-mdt:evidence:seized', src, target, stationId, name, label, isWeapon)
    pcall(function() exports['pup-misc']:RefreshSearchView(src, target) end)
end

RegisterNetEvent('pup-mdt:evidence:seize', function(item)
    local src = source
    if Lockers.busy[src] then return end
    Lockers.busy[src] = true
    local ok, err = pcall(seizeOne, src, item)
    Lockers.busy[src] = nil
    if not ok then print('^1[pup-mdt]^7 seize failed: ' .. tostring(err)) end
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
exports('GetEvidenceStationNear', function(src) return Lockers.stationNear(src) end)

exports('GetContrabandItems', function()
    local out = {}
    for _, g in ipairs(Config.Confiscation.contraband) do
        for _, it in ipairs(g.items) do out[it.name] = it.label end
    end
    return out
end)

exports('GetLawJobs', function()
    local out = {}
    for _, j in ipairs(Config.LawJobs) do out[#out + 1] = j end
    return out
end)

exports('SeizeItemToEvidence', function(officerSrc, item, ctx)
    if not E.enabled then return false, 'evidence lockers are off' end
    if not mayUse(officerSrc) then return false, 'not law on duty' end
    if type(item) ~= 'table' or type(item.name) ~= 'string' or item.name == '' then return false, 'bad item' end
    local amount = MDT.int(item.amount, 1, 1000000, nil)
    if not amount then return false, 'bad amount' end
    ctx = type(ctx) == 'table' and ctx or {}
    local at = ctx.at and vector3(tonumber(ctx.at.x) or 0, tonumber(ctx.at.y) or 0, tonumber(ctx.at.z) or 0) or MDT.coords(officerSrc)
    local st = nearestStation(at, nil)
    if not st then return false, 'no station' end
    local ch = MDT.char(officerSrc)
    local charid = tonumber(ctx.fromCharid) or (ch and tonumber(ch.charIdentifier))
    if not charid then return false, 'no character' end
    if not Lockers.registered then registerAll() end
    local ok = exports.vorp_inventory:addItemsToCustomInventory(PREFIX .. st.id, { { name = item.name, amount = amount, metadata = item.metadata or {} } }, charid)
    if not ok then return false, 'the locker would not take it' end
    local officer = MDT.player(officerSrc)
    MDT.log('evidence_locker', 'Booked into evidence', ('%s booked %dx %s from %s into %s'):format(
        officer and officer.name or tostring(officerSrc), amount, item.label or item.name, MDT.str(ctx.fromName, 100), st.label), 'blue')
    Lockers.queueRebuild()
    return true, st.id, st.label
end)

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------
AddEventHandler('onResourceStart', function(res)
    if res == 'vorp_inventory' then
        SetTimeout(2000, registerAll)
        SetTimeout(6000, function() pcall(Lockers.rebuild) end)
    end
end)

function Lockers.init()
    if not E.enabled then return end
    pcall(migrateIds)
    registerAll()
    SetTimeout(6000, function() pcall(Lockers.rebuild) end)
end
