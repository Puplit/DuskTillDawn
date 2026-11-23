-- storagebox | server core: state and helpers shared by server/storagebox/*.lua
--
-- Everything this module keeps between its own server files lives in the one PupSBX
-- table. The only other globals it defines are the PupStorageBoxNoteTransfer hook
-- (called by the search module) and the config/locale tables.

PupSBX = {}
local S = PupSBX
local C = StorageBoxConfig
local L = StorageBoxLocale

S.RES  = GetCurrentResourceName()
S.Core = exports.vorp_core:GetCore()
local Inv = exports.vorp_inventory

------------------------------------------------------------------------------ console
local warned = {}
function S.warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s:storagebox]^7 %s'):format(S.RES, msg))
end

function S.debug(msg)
    if C.Debug then print(('^5[%s:storagebox]^7 %s'):format(S.RES, msg)) end
end

------------------------------------------------------------------------------ item definitions
S.Defs      = {}  -- name -> definition (boxes and packs), with kind = 'box' | 'pack'
S.BoxNames  = {}  -- every container item name (boxes and packs), sorted
S.PackNames = {}  -- just the packs, sorted

for name, d in pairs(C.Boxes or {}) do
    S.Defs[name] = {
        name = name, kind = 'box', label = d.label, desc = d.desc,
        capacity = tonumber(d.capacity) or C.InventoryDefaults.capacity,
        moveRate = tonumber(d.moveRate) or C.Carry.defaultMoveRate,
        model = d.model or C.Carry.defaultModel,
        limit = tonumber(d.limit) or C.ItemDefaults.limit,
        rarity = tonumber(d.rarity) or C.ItemDefaults.rarity,
    }
end
for name, d in pairs(C.Packs or {}) do
    local set = {}
    for _, m in ipairs(d.materials or {}) do set[m] = true end
    S.Defs[name] = {
        name = name, kind = 'pack', label = d.label, desc = d.desc,
        capacity = tonumber(d.capacity) or C.InventoryDefaults.capacity,
        limit = tonumber(d.limit) or C.ItemDefaults.limit,
        rarity = tonumber(d.rarity) or C.ItemDefaults.rarity,
        gather = d.gather, jobs = d.jobs or {}, materials = d.materials or {}, materialSet = set,
    }
end
for name, d in pairs(S.Defs) do
    S.BoxNames[#S.BoxNames + 1] = name
    if d.kind == 'pack' then S.PackNames[#S.PackNames + 1] = name end
end
table.sort(S.BoxNames)
table.sort(S.PackNames)

function S.def(name) return type(name) == 'string' and S.Defs[name] or nil end
function S.isPack(name) local d = S.def(name) return d ~= nil and d.kind == 'pack' end

------------------------------------------------------------------------------ small validators
function S.posInt(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = math.floor(v)
    if v < 1 then return nil end
    return v
end

function S.finite(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function S.str(v, max)
    if type(v) ~= 'string' or v == '' or #v > (max or 64) then return nil end
    return v
end

function S.isBoxId(v)
    return type(v) == 'string' and v:match('^pupbox_%l%l%l%l%l%l%l%l$') ~= nil
end

function S.decodeMeta(meta)
    if type(meta) == 'string' then
        local ok, t = pcall(json.decode, meta)
        meta = ok and t or nil
    end
    return type(meta) == 'table' and meta or {}
end

function S.metaBoxId(meta)
    local id = S.decodeMeta(meta).boxId
    return S.isBoxId(id) and id or nil
end

function S.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = S.copy(v) end
    return out
end

function S.isWeaponName(name)
    return type(name) == 'string' and name:lower():sub(1, 7) == 'weapon_'
end

------------------------------------------------------------------------------ vorp_inventory calls
-- Every call goes through here: a missing or failing export is reported once and
-- answers nil, so the caller fails closed instead of erroring half-way.
function S.inv(fn, ...)
    local n = select('#', ...)
    local args = { ... }
    local ok, a, b = pcall(function() return Inv[fn](Inv, table.unpack(args, 1, n)) end)
    if not ok then
        S.warnOnce('inv:' .. fn, ('vorp_inventory export %s failed: %s'):format(fn, tostring(a)))
        return nil
    end
    return a, b
end

function S.resStarted(name) return GetResourceState(name) == 'started' end

------------------------------------------------------------------------------ players
function S.char(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ok, user = pcall(S.Core.getUser, src)
    if not ok or type(user) ~= 'table' then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' or not ch.charIdentifier then return nil end
    return ch
end

function S.charId(src)
    local ch = S.char(src)
    return ch and tonumber(ch.charIdentifier) or nil
end

function S.charName(ch)
    if not ch then return '?' end
    return ('%s %s'):format(tostring(ch.firstname or ''), tostring(ch.lastname or ''))
end

function S.tip(src, msg, ms)
    if not msg then return end
    pcall(S.Core.NotifyRightTip, src, msg, ms or 4000)
end

function S.pedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function S.dist(a, x, y, z)
    local dx, dy, dz = a.x - x, a.y - y, a.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local throttles = {}
function S.throttle(src, key, ms)
    local k = tostring(src) .. ':' .. key
    local now = GetGameTimer()
    if throttles[k] and now < throttles[k] then return false end
    throttles[k] = now + ms
    return true
end

function S.forgetPlayer(src)
    local prefix = tostring(src) .. ':'
    for k in pairs(throttles) do
        if k:sub(1, #prefix) == prefix then throttles[k] = nil end
    end
end

-- a net-event entry point: valid source with a selected character, rate-limited
function S.netGate(src, key, ms)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local ch = S.char(src)
    if not ch then return nil end
    if not S.throttle(src, key, ms or 250) then return nil end
    return ch
end

------------------------------------------------------------------------------ timed flags and locks
local function newFlagSet() return {} end
S.depositing = newFlagSet()
S.placing    = newFlagSet()
S.fallback   = newFlagSet()  -- box ids the "moved to custom inventory" fallback is handling
S.locks      = newFlagSet()

function S.flag(set, key, ms) set[key] = GetGameTimer() + ms end
function S.unflag(set, key) set[key] = nil end
function S.flagged(set, key)
    local t = set[key]
    if not t then return false end
    if GetGameTimer() >= t then set[key] = nil return false end
    return true
end

-- true when the lock was taken
function S.lock(key, ms)
    if S.flagged(S.locks, key) then return false end
    S.flag(S.locks, key, ms or 30000)
    return true
end
function S.unlock(key) S.locks[key] = nil end

------------------------------------------------------------------------------ database (oxmysql, parameterised)
local function dbCall(kind, sql, params)
    local ok, res = pcall(MySQL[kind].await, sql, params or {})
    if not ok then
        print(('^1[%s:storagebox]^7 SQL failed: %s'):format(S.RES, tostring(res)))
        return nil, false
    end
    return res, true
end
function S.query(sql, p) local r = dbCall('query', sql, p) return type(r) == 'table' and r or {} end
function S.scalar(sql, p) return (dbCall('scalar', sql, p)) end
function S.update(sql, p) local r, ok = dbCall('update', sql, p) return tonumber(r) or 0, ok end
function S.insert(sql, p) local r, ok = dbCall('insert', sql, p) return r, ok end

-- vorp_inventory merges some stacks with an async UPDATE: poll until `test` passes
function S.waitFor(test)
    local deadline = GetGameTimer() + C.WriteConfirmTimeoutMs
    local v = test()
    while not v and GetGameTimer() < deadline do
        Wait(C.WriteConfirmStepMs)
        v = test()
    end
    return v
end

------------------------------------------------------------------------------ labels
local labelCache = {}
function S.label(name)
    if type(name) ~= 'string' then return '?' end
    if labelCache[name] then return labelCache[name] end
    local d = S.Defs[name]
    if d and d.label then labelCache[name] = d.label return d.label end
    local row = S.inv('getItemDB', name)
    local label = type(row) == 'table' and row.label or name
    labelCache[name] = label
    return label
end

------------------------------------------------------------------------------ box rows and inventories
function S.getRow(boxId)
    local r = S.query('SELECT box_id, capacity, placed, pos_x, pos_y, pos_z, pos_h, item_name FROM storage_boxes WHERE box_id = ? LIMIT 1', { boxId })
    return r[1]
end

function S.capacityFor(boxId, itemName)
    local row = boxId and S.getRow(boxId)
    if row and tonumber(row.capacity) then return tonumber(row.capacity) end
    local d = S.def(itemName)
    return d and d.capacity or C.InventoryDefaults.capacity
end

function S.registered(id) return S.inv('isCustomInventoryRegistered', id) == true end

-- registers the custom inventory behind a box id (blacklist of every container item;
-- packs whitelist their own materials with no per-item cap)
function S.register(boxId, itemName, capacity)
    if S.registered(boxId) then return true end
    local d = S.def(itemName)
    local cap = tonumber(capacity) or (d and d.capacity) or C.InventoryDefaults.capacity
    local isPack = d ~= nil and d.kind == 'pack'
    S.inv('registerInventory', {
        id = boxId,
        name = d and d.label or L.promptGroup,
        limit = cap,
        acceptWeapons = C.InventoryDefaults.acceptWeapons,
        shared = C.InventoryDefaults.shared,
        ignoreItemStackLimit = C.InventoryDefaults.ignoreItemStackLimit,
        whitelistItems = isPack,
        whitelistWeapons = false,
        UsePermissions = false,
        UseBlackList = true,
    })
    if not S.registered(boxId) then return false end
    for _, n in ipairs(S.BoxNames) do S.inv('BlackListCustomAny', boxId, n) end
    if isPack then
        for _, m in ipairs(d.materials) do S.inv('setCustomInventoryItemLimit', boxId, m, 0) end
    end
    return true
end

-- registered already, or registered now from its row; false when the row is gone
function S.ensure(boxId, itemNameHint)
    if not S.isBoxId(boxId) then return false end
    if S.registered(boxId) then return true end
    local row = S.getRow(boxId)
    if not row then return false end
    return S.register(boxId, row.item_name or itemNameHint, row.capacity)
end

function S.newBoxId()
    for _ = 1, 25 do
        local t = {}
        for i = 1, 8 do t[i] = string.char(math.random(97, 122)) end
        local id = 'pupbox_' .. table.concat(t)
        if not S.scalar('SELECT 1 FROM storage_boxes WHERE box_id = ? LIMIT 1', { id }) and not S.registered(id) then
            return id
        end
    end
    return nil
end

-- row + inventory for a fresh box id
function S.createBox(itemName)
    local d = S.def(itemName)
    if not d then return nil end
    local id = S.newBoxId()
    if not id then return nil end
    local _, ok = S.insert('INSERT INTO storage_boxes (box_id, capacity, item_name) VALUES (?, ?, ?)', { id, d.capacity, itemName })
    if not ok then return nil end
    if not S.register(id, itemName, d.capacity) then
        S.update('DELETE FROM storage_boxes WHERE box_id = ?', { id })
        return nil
    end
    return id
end

-- a box id that was created but never stamped (or whose stamp failed)
function S.dropFresh(boxId)
    if S.registered(boxId) then S.inv('removeInventory', boxId) end
    S.update('DELETE FROM storage_boxes WHERE box_id = ?', { boxId })
end

-- retire: contents, inventory and row are all removed
function S.retire(boxId)
    if not S.isBoxId(boxId) then return end
    if S.registered(boxId) then
        S.inv('deleteCustomInventory', boxId)
        if S.registered(boxId) then S.inv('removeInventory', boxId) end
    end
    S.update('DELETE ic FROM items_crafted ic INNER JOIN character_inventories ci ON ci.item_crafted_id = ic.id WHERE ci.inventory_type = ?', { boxId })
    S.update('DELETE FROM character_inventories WHERE inventory_type = ?', { boxId })
    S.update('DELETE FROM storage_boxes WHERE box_id = ?', { boxId })
    if S.Placed and S.Placed[boxId] then S.Placed[boxId] = nil end
end

------------------------------------------------------------------------------ contents
function S.units(invId)
    return tonumber(S.scalar('SELECT COALESCE(SUM(amount), 0) FROM character_inventories WHERE inventory_type = ?', { invId })) or 0
end

function S.weaponCount(invId)
    return tonumber(S.scalar('SELECT COUNT(*) FROM loadout WHERE curr_inv = ?', { invId })) or 0
end

function S.countByName(invId, name)
    return tonumber(S.scalar('SELECT COALESCE(SUM(amount), 0) FROM character_inventories WHERE inventory_type = ? AND item_name = ?', { invId, name })) or 0
end

-- one entry per stored row: { craftedId, name, amount, percentage, metadata }.
-- charId limits it to one character's rows (a non-shared custom inventory).
function S.contents(invId, charId)
    local sql = [[
        SELECT ci.item_crafted_id AS crafted, ci.item_name AS name, ci.amount AS amount, ci.percentage AS percentage, ic.metadata AS metadata
        FROM character_inventories ci
        LEFT JOIN items_crafted ic ON ic.id = ci.item_crafted_id
        WHERE ci.inventory_type = ?]]
    local params = { invId }
    if charId then
        sql = sql .. ' AND ci.character_id = ?'
        params[2] = charId
    end
    local rows = S.query(sql .. ' ORDER BY ci.item_crafted_id', params)
    local out = {}
    for _, r in ipairs(rows) do
        local amount = tonumber(r.amount) or 0
        if r.name and amount > 0 then
            out[#out + 1] = {
                craftedId = tonumber(r.crafted), name = r.name, amount = amount,
                percentage = tonumber(r.percentage), metadata = S.decodeMeta(r.metadata),
            }
        end
    end
    return out
end

function S.rowByCrafted(invId, craftedId)
    local r = S.query('SELECT item_name, amount FROM character_inventories WHERE inventory_type = ? AND item_crafted_id = ? LIMIT 1', { invId, craftedId })
    return r[1]
end

------------------------------------------------------------------------------ the satchel
function S.satchel(src)
    local list = S.inv('getUserInventoryItems', src)
    return type(list) == 'table' and list or {}
end

function S.itemById(src, id)
    id = tonumber(id)
    if not id then return nil end
    local it = S.inv('getItemById', src, id)
    return type(it) == 'table' and it or nil
end

-- every container item in the satchel: { item, def, boxId (nil when unstamped) }
function S.containers(src)
    local out = {}
    for _, it in ipairs(S.satchel(src)) do
        local d = S.def(it.name)
        if d then out[#out + 1] = { item = it, def = d, boxId = S.metaBoxId(it.metadata) } end
    end
    return out
end

function S.findStamped(src, boxId)
    if not S.isBoxId(boxId) then return nil end
    for _, c in ipairs(S.containers(src)) do
        if c.boxId == boxId then return c end
    end
    return nil
end

function S.stampedCount(src)
    local n = 0
    for _, c in ipairs(S.containers(src)) do if c.boxId then n = n + 1 end end
    return n
end

-- "already using one of this type": only a box that still HOLDS something counts. An emptied
-- box keeps its box id until it is stored or dropped, but it must not block another one
function S.hasStampedOfName(src, name)
    if not C.Switches.OneUsedBoxPerType then return false end
    for _, c in ipairs(S.containers(src)) do
        if c.boxId and c.item.name == name and (S.units(c.boxId) > 0 or S.weaponCount(c.boxId) > 0) then
            return true
        end
    end
    return false
end

-- an item by its satchel id that is a container; `stamped` = true / false / nil (either)
function S.containerById(src, itemId, stamped)
    local it = S.itemById(src, itemId)
    if not it then return nil end
    local d = S.def(it.name)
    if not d then return nil end
    local boxId = S.metaBoxId(it.metadata)
    if stamped == true and not boxId then return nil end
    if stamped == false and boxId then return nil end
    return { item = it, def = d, boxId = boxId }
end

function S.jobAllowed(ch, d)
    if not d or d.kind ~= 'pack' or #d.jobs == 0 then return true end
    for _, j in ipairs(d.jobs) do
        if ch and ch.job == j then return true end
    end
    return false
end

-- writes the box id into an item; returns the stamped item's satchel id or nil.
-- A stack of several unopened boxes is split by vorp, so the stamped copy is looked up again.
function S.stamp(src, itemId, boxId, extra)
    local meta = { boxId = boxId }
    for k, v in pairs(extra or {}) do meta[k] = v end
    local ok = S.inv('setItemMetadata', src, tonumber(itemId), meta, 1)
    if not ok then return nil end
    local found = S.waitFor(function() return S.findStamped(src, boxId) end)
    return found and found.item.id or nil
end

------------------------------------------------------------------------------ open-panel helpers (pup exports in vorp_inventory)
function S.openInv(src)
    local id = S.inv('getOpenCustomInventory', src)
    return type(id) == 'string' and id or (id ~= nil and tostring(id) or nil)
end

function S.reloadInv(src, invId)
    if invId then S.inv('reloadCustomInventory', src, invId) end
end

-- closes this player's box panel (server lock and client panel) when it shows this box
function S.closeBoxFor(src, boxId)
    local open = S.openInv(src)
    local session = S.sessions and S.sessions[src] == boxId
    if session then S.sessions[src] = nil end
    if open == boxId then S.inv('closeInventory', src, boxId) end
    if open == boxId or session then TriggerClientEvent('pup_storagebox:closeBoxPanel', src) end
end

-- closes the panel of everyone (but `except`) who has this custom inventory open
function S.closeViewers(invId, except)
    for _, p in ipairs(GetPlayers()) do
        local id = tonumber(p)
        if id and id ~= except and S.openInv(id) == invId then
            S.inv('closeInventory', id, invId)
            TriggerClientEvent('pup_storagebox:closeBoxPanel', id)
            if S.sessions and S.sessions[id] == invId then S.sessions[id] = nil end
        end
    end
end

------------------------------------------------------------------------------ a custom inventory's own rules
-- vorp's server-side add/remove exports skip the permission, blacklist and whitelist checks its
-- own panel makes, so the module makes them itself. nil when the inventory is not registered.
function S.invRules(invId)
    local d = S.inv('getCustomInventoryData', invId)
    return type(d) == 'table' and d or nil
end

local function permitted(ch, jobs, chars)
    jobs, chars = type(jobs) == 'table' and jobs or {}, type(chars) == 'table' and chars or {}
    if not next(jobs) and not next(chars) then return true end
    local need = ch and jobs[ch.job]
    if need ~= nil and (tonumber(ch.jobGrade) or 0) >= (tonumber(need) or 0) then return true end
    local cid = ch and ch.charIdentifier
    if cid ~= nil and (chars[cid] or chars[tostring(cid)] or chars[tonumber(cid) or -1]) then return true end
    return false
end

-- may this character take goods out of the inventory (vorp's take-from permission)?
function S.mayTake(ch, rules)
    if type(rules) ~= 'table' then return false end
    if not rules.UsePermissions then return true end
    return permitted(ch, rules.PermissionTakeFrom, rules.CharIdPermissionTakeFrom)
end

-- may this character put these item names into the inventory (move-to permission, blacklist, whitelist)?
function S.mayPut(ch, rules, names)
    if type(rules) ~= 'table' then return false end
    if rules.UsePermissions and not permitted(ch, rules.PermissionMoveTo, rules.CharIdPermissionMoveTo) then return false end
    local black = type(rules.BlackListItems) == 'table' and rules.BlackListItems or {}
    local white = type(rules.limitedItems) == 'table' and rules.limitedItems or {}
    for _, n in ipairs(names or {}) do
        local low = tostring(n):lower()
        if rules.UseBlackList and (black[n] ~= nil or black[low] ~= nil) then return false end
        if rules.whitelistItems and white[low] == nil then return false end
    end
    return true
end

------------------------------------------------------------------------------ carry refresh (S.sendCarry lives in boxes.lua)
local carryPending = {}
function S.refreshCarry(src, delay)
    src = tonumber(src)
    if not src or carryPending[src] then return end
    carryPending[src] = true
    SetTimeout(delay or 0, function()
        carryPending[src] = nil
        if S.sendCarry and GetPlayerName(src) then S.sendCarry(src) end
    end)
end
