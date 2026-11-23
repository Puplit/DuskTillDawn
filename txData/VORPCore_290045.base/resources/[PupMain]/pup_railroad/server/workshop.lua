-- pup_railroad | server: repairs, upgrades, the lockbox and its stored copy

local Out <const> = Srv.Out

local Working = {} -- [trainId] = true while a repair or upgrade is being processed
local OpenBox = {} -- [src] = lockbox id (string) the player has open

Srv.OpenBox = OpenBox

-- [lockbox id] = GetGameTimer() while a delivery is unloading it; nobody may open it meanwhile.
-- An entry older than 30 s is treated as stale (a failed handler can never lock a box for good).
Srv.BoxBusy = {}

function Srv.boxBusy(boxId)
    local since = Srv.BoxBusy[boxId]
    if not since then return false end
    if GetGameTimer() - since > 30000 then
        Srv.BoxBusy[boxId] = nil
        return false
    end
    return true
end

--------------------------------------------------------------------------------
-- materials, all or nothing
--------------------------------------------------------------------------------
local function giveBack(src, list)
    for i = 1, #list do
        local m = list[i]
        pcall(function() exports.vorp_inventory:addItem(src, m.item, m.count) end)
    end
end

local function takeMaterials(src, list)
    for i = 1, #list do
        local m = list[i]
        local ok, have = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, m.item) end)
        if not ok or (tonumber(have) or 0) < m.count then return false end
    end
    local taken = {}
    for i = 1, #list do
        local m = list[i]
        local ok, removed = pcall(function() return exports.vorp_inventory:subItem(src, m.item, m.count) end)
        if not ok or not removed then
            giveBack(src, taken)
            return false
        end
        taken[#taken + 1] = m
    end
    return true
end

--------------------------------------------------------------------------------
-- repairs
--------------------------------------------------------------------------------
Srv.on('repair', { gap = 1000 }, function(src, char, trainId)
    if not Rail.inList(Config.Maintenance.jobs, char.job) then return Srv.fail(src, 'invalid') end
    local id = Rail.int(trainId)
    local t = id and Out[id]
    if not t or not Srv.nearTrain(src, t, Config.Reach.train) then return Srv.fail(src, 'invalid') end
    if Working[id] then return nil end -- a second request at the same moment is ignored
    if not Config.Maintenance.enabled then return Srv.fail(src, 'invalid') end
    if t.maint > Config.Maintenance.repairAtOrBelow then return Srv.fail(src, 'not_needed') end

    local set = Rail.nearestMaterialSet(t.maint)
    if not set then return Srv.fail(src, 'invalid') end

    Working[id] = true
    local ok = takeMaterials(src, set)
    if not ok then
        Working[id] = nil
        return Srv.fail(src, 'not_enough_fix')
    end
    if Out[id] ~= t then
        Working[id] = nil
        giveBack(src, set)
        return Srv.fail(src, 'invalid')
    end
    t.maint = 100
    Srv.saveTrain(t)
    Srv.pushTrain(t)
    Working[id] = nil
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- upgrades
--------------------------------------------------------------------------------
Srv.on('upgrade', { gap = 1000 }, function(src, char, trainId, kind, tier)
    if not Rail.inList(Config.Upgrades.jobs, char.job) then return Srv.fail(src, 'invalid') end
    local id = Rail.int(trainId)
    local t = id and Out[id]
    if not t or not Srv.nearTrain(src, t, Config.Reach.train) then return Srv.fail(src, 'invalid') end
    if kind ~= 'speed' and kind ~= 'engine' then return Srv.fail(src, 'invalid') end
    if Working[id] then return nil end

    tier = Rail.int(tier)
    local level = kind == 'speed' and t.speedup or t.coalup
    local def = tier and Config.Upgrades[kind][tier]
    if not def or tier ~= level + 1 then return Srv.fail(src, 'invalid') end
    if kind == 'speed' and t.speed >= Config.Upgrades.speedCap then return Srv.fail(src, 'invalid') end
    -- a train that burns no coal has no engine to tune (it would start burning coal)
    if kind == 'engine' and t.coalcon <= 0 then return Srv.fail(src, 'invalid') end

    Working[id] = true
    if not takeMaterials(src, def.materials) then
        Working[id] = nil
        return Srv.fail(src, 'not_enough_upgrade')
    end
    if Out[id] ~= t then
        Working[id] = nil
        giveBack(src, def.materials)
        return Srv.fail(src, 'invalid')
    end

    if kind == 'speed' then
        t.speed = math.min(Config.Upgrades.speedCap, t.speed + def.amount)
        t.speedup = tier
        Srv.db.updateAsync('UPDATE player_trains SET speed = ?, speedup = ? WHERE id = ?', { t.speed, t.speedup, id })
    else
        t.coalcon = t.coalcon + def.amount
        t.coalup = tier
        Srv.db.updateAsync('UPDATE player_trains SET coalcon = ?, coalup = ? WHERE id = ?', { t.coalcon, t.coalup, id })
    end
    Srv.pushTrain(t)
    Working[id] = nil
    return { ok = true }
end)

--------------------------------------------------------------------------------
-- stored copy of a lockbox (player_trains.items), debounced per lockbox
--------------------------------------------------------------------------------
local refreshQueued = {}

local function writeCopy(contid)
    local rows = Srv.db.query([[
        SELECT i.item AS name, ci.amount AS amount, ic.metadata AS metadata
        FROM character_inventories ci
        LEFT JOIN items_crafted ic ON ic.id = ci.item_crafted_id
        LEFT JOIN items i ON i.id = ic.item_id
        WHERE ci.inventory_type = ?]], { tostring(contid) })
    if not rows then return end
    local list = {}
    for i = 1, #rows do
        local r = rows[i]
        if r.name then
            local entry = { name = r.name, count = tonumber(r.amount) or 0 }
            if type(r.metadata) == 'string' and r.metadata ~= '' then
                local ok, meta = pcall(json.decode, r.metadata)
                if ok and type(meta) == 'table' and next(meta) then entry.metadata = meta end
            end
            list[#list + 1] = entry
        end
    end
    local encoded = #list == 0 and '[]' or json.encode(list)
    Srv.db.updateAsync('UPDATE player_trains SET items = ? WHERE contid = ?', { encoded, Rail.int(contid) })
end

function Srv.refreshCopy(contid)
    local key = tostring(contid)
    if refreshQueued[key] then return end
    refreshQueued[key] = true
    SetTimeout(1000, function()
        refreshQueued[key] = nil
        writeCopy(key)
    end)
end

local function onBoxChanged(_, inventoryId)
    local key = tostring(inventoryId)
    if Srv.KnownBoxes[key] then Srv.refreshCopy(key) end
end

AddEventHandler('vorp_inventory:Server:OnItemMovedToCustomInventory', onBoxChanged)
AddEventHandler('vorp_inventory:Server:OnItemTakenFromCustomInventory', onBoxChanged)

--------------------------------------------------------------------------------
-- the lockbox
--------------------------------------------------------------------------------
Srv.on('openLockbox', { gap = 1000 }, function(src, char, trainId)
    local id = Rail.int(trainId)
    local t = id and Out[id]
    if not t or not t.contid then return Srv.fail(src, 'invalid') end
    -- only the company that owns the train (or staff) opens its lockbox
    if t.company ~= char.job and not Srv.isStaff(src) then return Srv.fail(src, 'invalid') end
    if not Srv.hasKey(src) or not Srv.nearTrain(src, t, Config.Reach.train) then return Srv.fail(src, 'invalid') end

    local contid = t.contid
    local exists = Srv.db.single('SELECT id FROM container WHERE id = ?', { contid })
    if not exists then
        Srv.db.insert('INSERT INTO container (id, name, items) VALUES (?, ?, ?)', { contid, 'Train', '{}' })
        print(('[pup_railroad] container row %d for train %d was missing and has been recreated empty'):format(contid, id))
    end
    -- re-check after the database wait (a delivery may have started unloading this lockbox meanwhile)
    if Out[id] ~= t or not Srv.char(src) or not Srv.nearTrain(src, t, Config.Reach.train) then return Srv.fail(src, 'invalid') end
    local boxId = tostring(contid)
    if Srv.boxBusy(boxId) then return Srv.fail(src, 'invalid') end

    Srv.registerBox(contid)
    local ok = pcall(function() exports.vorp_inventory:openInventory(src, boxId) end)
    if ok then OpenBox[src] = boxId end
    return { ok = ok }
end)

-- which custom inventory a player has open right now (vorp_inventory export); nil when unknown
local function openInventoryOf(s)
    local ok, open = pcall(function() return exports.vorp_inventory:getOpenCustomInventory(s) end)
    if not ok then return false, nil end
    return true, open
end

--- close a lockbox for everyone who has it open
function Srv.closeBoxForAll(boxId)
    local known = false
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local ok, open = openInventoryOf(s)
        if ok then
            known = true
            if open ~= nil and tostring(open) == boxId then
                pcall(function() exports.vorp_inventory:closeInventory(s, boxId) end)
            end
            if OpenBox[s] == boxId then OpenBox[s] = nil end
        end
    end
    if known then return end
    -- the export is missing: fall back to the players this resource opened it for
    for s, open in pairs(OpenBox) do
        if open == boxId then
            pcall(function() exports.vorp_inventory:closeInventory(s, boxId) end)
            OpenBox[s] = nil
        end
    end
end

AddEventHandler('playerDropped', function()
    OpenBox[source] = nil
end)

function Srv.boxesOnCharacterSwitch(src)
    OpenBox[src] = nil
end

--------------------------------------------------------------------------------
-- container reload (only when pup_business does not own the event)
--------------------------------------------------------------------------------
if not Config.BusinessIntegration then
    local lastReload = {}
    RegisterNetEvent('pup-Container:reloadContainerInventory', function(containerId)
        local src = source
        if not Srv.char(src) then return end
        local now = GetGameTimer()
        if lastReload[src] and now - lastReload[src] < 1000 then return end
        lastReload[src] = now
        local contid = Rail.int(containerId)
        if not contid then return end
        local row = Srv.db.single('SELECT id FROM player_trains WHERE contid = ?', { contid })
        if row then Srv.registerBox(contid, true) end
    end)
    AddEventHandler('playerDropped', function() lastReload[source] = nil end)
end

--------------------------------------------------------------------------------
-- start-up: items column, every lockbox registered and its copy refreshed
--------------------------------------------------------------------------------
CreateThread(function()
    Wait(2000)
    local col = Srv.db.query("SHOW COLUMNS FROM player_trains LIKE 'items'")
    if col and #col == 0 then
        Srv.db.query('ALTER TABLE player_trains ADD COLUMN items LONGTEXT DEFAULT NULL')
    end
    local rows = Srv.db.query('SELECT contid FROM player_trains WHERE contid IS NOT NULL') or {}
    for i = 1, #rows do
        Srv.registerBox(rows[i].contid)
        writeCopy(rows[i].contid)
    end
end)
