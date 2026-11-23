-- pup_armory | server
-- Owns what each player is carrying. The 'pup_armory' state bag on the player is
-- the one source every client draws from: { hand = item, shield = item, pos = {...} }.

local Core = exports.vorp_core:GetCore()
local carrying = {}   -- [src] = { charid, hand, shield, pos = { [item] = { [slot] = {6} } } }
local isStaff         -- defined with the server defaults below

local function dbg(...) if Config.General.debug then print('^5[pup_armory]^7', ...) end end
local function tip(src, msg) Core.NotifyRightTip(src, msg, 4000) end

local function character(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

-- publish what this player carries, with their own saved positions for those items
local function publish(src)
    local c = carrying[src]
    if not c or (not c.hand and not c.shield) then
        Player(src).state:set('pup_armory', nil, true)
        return
    end
    local pos = {}
    for _, item in ipairs({ c.hand, c.shield }) do
        if item and c.pos[item] then pos[item] = c.pos[item] end
    end
    Player(src).state:set('pup_armory', { hand = c.hand, shield = c.shield, pos = pos }, true)
end

local function loadPositions(charid, item, cb)
    MySQL.query('SELECT slot, x, y, z, rx, ry, rz FROM armory_offsets WHERE charid = ? AND item = ?',
        { charid, item }, function(rows)
            local out = {}
            for _, r in ipairs(rows or {}) do out[r.slot] = { r.x, r.y, r.z, r.rx, r.ry, r.rz } end
            cb(out)
        end)
end

-- put the hand weapon / shield away; `silent` skips the tip (item lost, character switch)
local function stow(src, which, silent)
    local c = carrying[src]
    if not c or not c[which] then return end
    local def = Armory.get(c[which])
    c[which] = nil
    if which == 'hand' then TriggerClientEvent('pup_armory:arm', src, false) end
    publish(src)
    if not silent and def then
        tip(src, (def.kind == 'shield' and Locale.shieldOff or Locale.putAway):format(def.label))
    end
end

local function jobAllowed(def, char)
    if not def.jobs then return true end
    for _, j in ipairs(def.jobs) do if j == char.job then return true end end
    return false
end

local function use(src, def)
    local char = character(src)
    if not char then return end
    if not jobAllowed(def, char) then return tip(src, Locale.notYourTrade) end

    local c = carrying[src]
    if not c or c.charid ~= char.charIdentifier then
        c = { charid = char.charIdentifier, pos = {} }
        carrying[src] = c
    end

    local which = def.kind == 'shield' and 'shield' or 'hand'
    if c[which] == def.item then return stow(src, which) end   -- same item again = put it away

    loadPositions(c.charid, def.item, function(pos)
        if carrying[src] ~= c then return end                  -- left or switched while the query ran
        -- a player's own in-hand position is ignored while that slot is staff-only
        if pos.hand and Armory.handLocked('hand') and not isStaff(src) then pos.hand = nil end
        c.pos[def.item] = next(pos) and pos or nil
        c[which] = def.item                                     -- one hand weapon and one shield at a time
        if which == 'hand' then TriggerClientEvent('pup_armory:arm', src, def.item) end
        publish(src)
        tip(src, (which == 'shield' and Locale.shieldOn or Locale.takenOut):format(def.label))
        dbg(('%s carries %s (%s)'):format(src, def.item, which))
    end)
end

-- every weapon is a usable item
CreateThread(function()
    for _, def in ipairs(Armory.list) do
        exports.vorp_inventory:registerUsableItem(def.item, function(data)
            local src = data.source
            exports.vorp_inventory:closeInventory(src)
            use(src, def)
        end, GetCurrentResourceName())
    end
    dbg(('%d weapon items registered'):format(#Armory.list))
end)

-- the item left the inventory (dropped, given, sold, stashed): put it away if none remain
AddEventHandler('vorp_inventory:Server:OnItemRemoved', function(data, src)
    local c = src and carrying[src]
    if not c or type(data) ~= 'table' then return end
    local which = (c.hand == data.name and 'hand') or (c.shield == data.name and 'shield') or nil
    if not which then return end
    SetTimeout(300, function()
        exports.vorp_inventory:getItemCount(src, function(n)
            if (tonumber(n) or 0) <= 0 and carrying[src] and carrying[src][which] == data.name then
                local def = Armory.get(data.name)
                stow(src, which, true)
                if def then tip(src, Locale.lostItem:format(def.label)) end
            end
        end, data.name)
    end)
end)

-- each editor write at most once per WRITE_GAP ms per player
local WRITE_GAP <const> = 500
local lastWrite = {}   -- [src] = { [key] = GetGameTimer() }
local function writeAllowed(src, key)
    local now = GetGameTimer()
    local t = lastWrite[src]
    if not t then t = {}; lastWrite[src] = t end
    if t[key] and now - t[key] < WRITE_GAP then return false end
    t[key] = now
    return true
end

-- the editor saving one position
RegisterNetEvent('pup_armory:saveSpot', function(item, slot, off)
    local src = source
    if not writeAllowed(src, 'save') then return end
    local c = carrying[src]
    local def = Armory.get(item)
    if not c or not def or (c.hand ~= item and c.shield ~= item) then return end
    local okSlot = false
    for _, s in ipairs(def.slots) do if s == slot then okSlot = true end end
    if not okSlot then return end
    if Armory.handLocked(slot) and not isStaff(src) then return end
    if not Armory.validOffset(off) then return tip(src, Locale.tooFar) end

    local v = {}
    for i = 1, 6 do v[i] = math.floor(tonumber(off[i]) * 1000 + 0.5) / 1000 end
    MySQL.update([[INSERT INTO armory_offsets (charid, item, slot, x, y, z, rx, ry, rz) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                   ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), rx = VALUES(rx), ry = VALUES(ry), rz = VALUES(rz)]],
        { c.charid, item, slot, v[1], v[2], v[3], v[4], v[5], v[6] })
    c.pos[item] = c.pos[item] or {}
    c.pos[item][slot] = v
    publish(src)
    tip(src, Locale.saved)
end)

RegisterNetEvent('pup_armory:resetItem', function(item)
    local src = source
    if not writeAllowed(src, 'reset') then return end
    local c = carrying[src]
    local def = Armory.get(item)
    if not c or not def then return end
    MySQL.update('DELETE FROM armory_offsets WHERE charid = ? AND item = ?', { c.charid, item })
    c.pos[item] = nil
    publish(src)
    tip(src, Locale.resetDone:format(def.label))
end)

-- SERVER DEFAULTS (shared with every client through GlobalState) ----------------
local function holdsAdminPermission(src)
    if GetResourceState('vorp_admin') ~= 'started' then return false end
    local ok, allowed = pcall(function() return exports.vorp_admin:hasPermission(src, Config.Staff.permission) end)
    return ok and allowed == true
end

function isStaff(src) -- the local declared at the top
    if holdsAdminPermission(src) then return true end
    local user = Core.getUser(src)
    local group = user and user.getGroup
    for _, g in ipairs(Config.Staff.groups or {}) do if g == group then return true end end
    return false
end

local defaults = {}
local function shareDefaults()
    GlobalState.pup_armory_defaults = defaults
    GlobalState.pup_armory_defaults_v = (GlobalState.pup_armory_defaults_v or 0) + 1
end

RegisterNetEvent('pup_armory:hello', function()
    local src = source
    Player(src).state:set('pup_armory_staff', isStaff(src), true)
end)

RegisterNetEvent('pup_armory:saveDefault', function(item, slot, off)
    local src = source
    if not isStaff(src) then return end
    local def = Armory.get(item)
    if not def then return end
    local okSlot = false
    for _, s in ipairs(def.slots) do if s == slot then okSlot = true end end
    if not okSlot then return end
    if not Armory.validOffset(off) then return tip(src, Locale.tooFar) end

    local v = {}
    for i = 1, 6 do v[i] = math.floor(tonumber(off[i]) * 1000 + 0.5) / 1000 end
    MySQL.update([[INSERT INTO armory_defaults (item, slot, x, y, z, rx, ry, rz) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                   ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z), rx = VALUES(rx), ry = VALUES(ry), rz = VALUES(rz)]],
        { item, slot, v[1], v[2], v[3], v[4], v[5], v[6] })
    defaults[item] = defaults[item] or {}
    defaults[item][slot] = v
    shareDefaults()
    tip(src, Locale.defaultSaved:format(def.label))
    print(('[pup_armory] %s set the server default for %s (%s)'):format(GetPlayerName(src) or src, item, slot))
end)

RegisterNetEvent('pup_armory:resetDefault', function(item)
    local src = source
    if not isStaff(src) then return end
    local def = Armory.get(item)
    if not def then return end
    MySQL.update('DELETE FROM armory_defaults WHERE item = ?', { item })
    defaults[item] = nil
    shareDefaults()
    tip(src, Locale.defaultReset:format(def.label))
end)

-- character switch or the client asking for a clean slate
local function forget(src)
    if carrying[src] then
        stow(src, 'hand', true)
        stow(src, 'shield', true)
    end
    carrying[src] = nil
    Player(src).state:set('pup_armory', nil, true)
end
RegisterNetEvent('pup_armory:clear', function() forget(source) end)
AddEventHandler('playerDropped', function() carrying[source] = nil; lastWrite[source] = nil end)

-- tables
CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS armory_offsets (
        charid INT NOT NULL, item VARCHAR(50) NOT NULL, slot VARCHAR(10) NOT NULL,
        x DOUBLE NOT NULL DEFAULT 0, y DOUBLE NOT NULL DEFAULT 0, z DOUBLE NOT NULL DEFAULT 0,
        rx DOUBLE NOT NULL DEFAULT 0, ry DOUBLE NOT NULL DEFAULT 0, rz DOUBLE NOT NULL DEFAULT 0,
        PRIMARY KEY (charid, item, slot)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS armory_defaults (
        item VARCHAR(50) NOT NULL, slot VARCHAR(10) NOT NULL,
        x DOUBLE NOT NULL DEFAULT 0, y DOUBLE NOT NULL DEFAULT 0, z DOUBLE NOT NULL DEFAULT 0,
        rx DOUBLE NOT NULL DEFAULT 0, ry DOUBLE NOT NULL DEFAULT 0, rz DOUBLE NOT NULL DEFAULT 0,
        PRIMARY KEY (item, slot)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    for _, r in ipairs(MySQL.query.await('SELECT item, slot, x, y, z, rx, ry, rz FROM armory_defaults') or {}) do
        if Armory.get(r.item) then
            defaults[r.item] = defaults[r.item] or {}
            defaults[r.item][r.slot] = { r.x, r.y, r.z, r.rx, r.ry, r.rz }
        end
    end
    shareDefaults()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(carrying) do Player(src).state:set('pup_armory', nil, true) end
end)
