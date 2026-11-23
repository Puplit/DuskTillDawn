-- pup-gangs | server/drugs.lua: the gang drug
-- NOTHING here trusts the client. Gang, turf, prices, points and effects are
-- all resolved server-side from the character's own record and ped position.
-- Loads AFTER server/main.lua (the Gang* bridge), server/features.lua (GangHasPerk)
-- and server/blood.lua (GangBloodMove) - see fxmanifest.lua.

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end
local VorpInv <const> = exports.vorp_inventory

local CFG = Config.GangDrug or {}

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs drug]^7 " .. table.concat(parts, " "))
end

local function Char(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end
local function notify(src, msg, dur) VorpCore.NotifyRightTip(src, msg, dur or 4000) end
local function now() return os.time() end

-- ---------------------------------------------------------------- SCHEMA
-- Extra columns on the gang row, not a second gang database.
CreateThread(function()
    if not CFG.enabled then return end
    Wait(4500)
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_name VARCHAR(48) NULL")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_icon VARCHAR(32) NULL")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_points INT(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_earned INT(11) NOT NULL DEFAULT 0")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_nodes TEXT NULL")
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_created INT(11) NOT NULL DEFAULT 0")
    -- seed paid for but not yet picked up from the fence
    MySQL.query.await("ALTER TABLE gangs ADD COLUMN IF NOT EXISTS drug_seed_pending INT(11) NOT NULL DEFAULT 0")
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS gang_drug_log (
        id     INT(11) NOT NULL AUTO_INCREMENT,
        gangid INT(11) NOT NULL,
        charid INT(11) NULL,
        name   VARCHAR(64) NOT NULL DEFAULT '',
        kind   VARCHAR(24) NOT NULL DEFAULT '',
        amount INT(11) NOT NULL DEFAULT 0,
        detail VARCHAR(160) NOT NULL DEFAULT '',
        ts     INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        KEY idx_drug_gang (gangid, ts)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    -- both items must exist or seeds vanish and harvests never land
    for _, item in ipairs({ CFG.seedItem, CFG.drugItem }) do
        local row = MySQL.query.await('SELECT item FROM items WHERE item = ?', { item })
        if not row or not row[1] then
            print(('^1[pup-gangs]^7 gang drug item "%s" is NOT in the items table - import gang_drug.sql and restart the server')
                :format(tostring(item)))
        end
    end

    -- the crop has to be wired into pup_homestead or nothing can ever be planted
    if GetResourceState('pup_homestead') ~= 'started' then
        print('^3[pup-gangs]^7 pup_homestead is not running - the gang crop cannot be planted')
    end
    dbg('ready')
end)

local function drugLog(gangid, charid, name, kind, amount, detail)
    MySQL.insert('INSERT INTO gang_drug_log (gangid, charid, name, kind, amount, detail, ts) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { gangid, charid, name or '', kind or '', amount or 0, detail or '', now() })
end

-- ---------------------------------------------------------------- HELPERS
-- STRICT: an unknown key is nil, never silently the first icon, so a spoofed
-- key is refused instead of quietly picking something.
local function iconByKey(key)
    for _, ic in ipairs(CFG.icons or {}) do
        if ic.key == key then return ic end
    end
    return nil
end
-- for DISPLAY only, where a gang somehow holds a key that was later removed
local function iconOrDefault(key)
    return iconByKey(key) or (CFG.icons or {})[1]
end

-- the unlocked-node set, cached on the gang row like server/blood.lua does for perks
local function nodeSet(gang)
    if not gang then return {} end
    if gang._drugNodes then return gang._drugNodes end
    local set = {}
    local raw = gang.drug_nodes
    if type(raw) == 'string' and raw ~= '' then
        local ok, list = pcall(json.decode, raw)
        if ok and type(list) == 'table' then
            for _, id in ipairs(list) do set[id] = true end
        end
    end
    gang._drugNodes = set
    return set
end

local function saveNodes(gang)
    local list = {}
    for id in pairs(nodeSet(gang)) do list[#list + 1] = id end
    table.sort(list)
    gang.drug_nodes = json.encode(list)
    MySQL.update('UPDATE gangs SET drug_nodes = ? WHERE id = ?', { gang.drug_nodes, gang.id })
end

local function nodeById(id)
    for _, n in ipairs(CFG.tree or {}) do
        if n.id == id then return n end
    end
    return nil
end

-- does this gang actually have a drug set up?
local function hasDrug(gang)
    return gang ~= nil and type(gang.drug_name) == 'string' and gang.drug_name ~= ''
end

local function drugLevel(gang)
    local earned = tonumber(gang and gang.drug_earned) or 0
    local tier = (CFG.levels or {})[1]
    for _, l in ipairs(CFG.levels or {}) do
        if earned >= (tonumber(l.points) or 0) then tier = l end
    end
    return tier or { level = 1, label = '?' }
end

-- KEYS THE TREE MAY TOUCH. A node naming anything else is ignored, never crashes.
local EFFECT_KEYS <const> = {
    health = true, stamina = true, deadeye = true,
    healthGold = true, staminaGold = true, deadeyeGold = true,
    hunger = true, thirst = true, metabolism = true,
}
local MOD_KEYS <const> = {
    yield = true, saleValue = true, progression = true, seedDiscount = true,
}

-- base effect + every unlocked node, resolved server-side. Never sent for editing.
local function resolveEffects(gang)
    local e = {}
    for k, v in pairs(CFG.effect or {}) do e[k] = v end
    local mods = { yield = 0, saleValue = 0, progression = 0, seedDiscount = 0 }

    local set = nodeSet(gang)
    for _, n in ipairs(CFG.tree or {}) do
        if set[n.id] then
            local key = tostring(n.effect or '')
            local val = tonumber(n.effectValue) or 0
            if key == 'duration' then
                e.durationMs = (tonumber(e.durationMs) or 0) + val
            elseif EFFECT_KEYS[key] then
                e[key] = (tonumber(e[key]) or 0) + val
            elseif MOD_KEYS[key] then
                mods[key] = mods[key] + val
            end
        end
    end

    -- cores are 0-100, gold cores 0.0-1.0; clamp so a fat tree cannot overflow them
    for _, k in ipairs({ 'health', 'stamina', 'deadeye' }) do
        e[k] = math.max(0, math.min(100, math.floor(tonumber(e[k]) or 0)))
    end
    for _, k in ipairs({ 'healthGold', 'staminaGold', 'deadeyeGold' }) do
        e[k] = math.max(0.0, math.min(1.0, (tonumber(e[k]) or 0) + 0.0))
    end
    e.durationMs = math.max(0, math.floor(tonumber(e.durationMs) or 0))
    mods.seedDiscount = math.max(0, math.min(0.9, mods.seedDiscount))
    return e, mods
end

-- the metadata that travels on the item. The SERVER builds this, always.
local function metaFor(gang, isSeed)
    if not hasDrug(gang) then return nil end
    local ic = iconOrDefault(gang.drug_icon)
    return {
        gangid = tonumber(gang.id),
        label = isSeed and (gang.drug_name .. ' Seed') or gang.drug_name,
        description = isSeed
            and ('Seed stock. Only ' .. (gang.name or 'the gang') .. ' can work it.')
            or ((gang.name or 'The gang') .. "'s own product."),
        image = ic and ic.image or nil,
    }
end

-- The gang a source belongs to, from the CHARACTER RECORD - never from the client.
local function gangOf(src)
    local ch = Char(src)
    if not ch then return nil, nil end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return nil, ch end
    return GangById(m.gangid), ch, m
end

-- ------------------------------------------------------------- TURF CHECK
-- Server-authoritative: the ped's own position, resolved against the same
-- territory table and influence radius the map draws. A client cannot pass a
-- gang id, a territory id, or a coordinate into this.
function DrugTurfOwnerAt(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c then return nil end
    local here <const> = vector3(c.x, c.y, c.z)

    local best, bestD = nil, nil
    local function consider(gangid, x, y, z)
        local g = GangById(gangid)
        if not g then return end
        local r <const> = tonumber(GangRadius(g.points)) or 0
        if r <= 0 then return end
        local d <const> = #(here - vector3((tonumber(x) or 0) + 0.0, (tonumber(y) or 0) + 0.0, (tonumber(z) or 0) + 0.0))
        if d <= r and (bestD == nil or d < bestD) then best, bestD = g.id, d end
    end

    for _, t in pairs(GangAllTerritories() or {}) do
        if t.gangid then consider(t.gangid, t.x, t.y, t.z) end
    end
    -- a gang's HQ table projects the same circle the map shows
    for gid, t in pairs(GANG_TABLES or {}) do
        consider(gid, t.x, t.y, t.z)
    end
    return best
end

-- ------------------------------------------------------------- AT THE FENCE
-- Seed is paid for at the table and handed over in person. Standing at the
-- fence is checked HERE, from the ped's own position against the spot
-- pup_robbery is actually running - the client never says where it is.
local function atFence(src)
    if not (CFG.seed and CFG.seed.collectAtFence) then return true end
    if GetResourceState('pup_robbery') ~= 'started' then return false end

    local spot = nil
    pcall(function() spot = exports['pup_robbery']:FenceSpot() end)
    if type(spot) ~= 'table' or type(spot.coords) ~= 'table' then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    if not c then return false end
    local here <const> = vector3(c.x, c.y, c.z)
    local max <const> = tonumber(CFG.seed.fenceDistance) or 4.0

    -- he stands on `coords` but you talk to him from `promptcoords`; either counts
    for _, t in ipairs({ spot.coords, spot.promptcoords }) do
        if type(t) == 'table' then
            local d = #(here - vector3((tonumber(t.x) or 0) + 0.0,
                                       (tonumber(t.y) or 0) + 0.0,
                                       (tonumber(t.z) or 0) + 0.0))
            if d <= max then return true end
        end
    end
    return false
end

-- -------------------------------------------------------------- PROGRESSION
local function addPoints(gang, n, charid, who, detail)
    n = math.floor(tonumber(n) or 0)
    if not gang or n <= 0 then return 0 end
    gang.drug_points = (tonumber(gang.drug_points) or 0) + n
    gang.drug_earned = (tonumber(gang.drug_earned) or 0) + n
    MySQL.update('UPDATE gangs SET drug_points = ?, drug_earned = ? WHERE id = ?',
        { gang.drug_points, gang.drug_earned, gang.id })
    drugLog(gang.id, charid, who, 'points', n, detail or '')
    return n
end

-- ------------------------------------------------------- PERMISSION GATES
local function canManage(charid)
    local key = CFG.managePerm
    if not key or key == '' then return true end
    return GangCan(charid, key) == true
end

local function canBuy(charid)
    local key = CFG.buyPerm
    if not key or key == '' then return true end
    return GangCan(charid, key) == true
end

-- the one gate everything else sits behind
local function drugGang(src, needManage)
    if not CFG.enabled then return nil end
    local gang, ch, m = gangOf(src)
    if not ch then return nil end
    if not gang then
        notify(src, Locale.noGang)
        return nil
    end
    if CFG.perk and CFG.perk ~= '' and not GangHasPerk(gang, CFG.perk) then
        notify(src, Locale.lockedPerk or 'Your gang has not unlocked that.', 6000)
        return nil
    end
    if needManage and not canManage(ch.charIdentifier) then
        notify(src, Locale.notAllowed)
        return nil
    end
    return gang, ch, m
end

-- ---------------------------------------------------------------- CREATION
RegisterNetEvent('pup-gangs:drugCreate', function(name, iconKey)
    local _source = source
    local gang, ch = drugGang(_source, true)
    if not gang then return end
    if hasDrug(gang) then return notify(_source, Locale.drugHave, 5000) end

    name = tostring(name or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    -- letters, digits, spaces and apostrophes only: the name lands in an item label
    if name:find("[^%w '%-]") then return notify(_source, Locale.drugBadName, 6000) end
    if #name < (tonumber(CFG.nameMin) or 3) or #name > (tonumber(CFG.nameMax) or 24) then
        return notify(_source, (Locale.drugNameLen):format(CFG.nameMin or 3, CFG.nameMax or 24), 6000)
    end

    local ic = iconByKey(tostring(iconKey or ''))
    if not ic then return notify(_source, Locale.drugBadIcon, 5000) end

    gang.drug_name = name
    gang.drug_icon = ic.key
    gang.drug_created = now()
    MySQL.update('UPDATE gangs SET drug_name = ?, drug_icon = ?, drug_created = ? WHERE id = ?',
        { gang.drug_name, gang.drug_icon, gang.drug_created, gang.id })

    local who <const> = ch.firstname .. ' ' .. ch.lastname
    drugLog(gang.id, ch.charIdentifier, who, 'create', 0, name .. ' / ' .. ic.key)
    GangLog(gang.id, 'drug', ('started running %s'):format(name), who)
    notify(_source, (Locale.drugStarted):format(name), 8000)
    GangRefreshCrew(gang.id)
end)

RegisterNetEvent('pup-gangs:drugRename', function(name)
    local _source = source
    local gang, ch = drugGang(_source, true)
    if not gang then return end
    if not hasDrug(gang) then return notify(_source, Locale.drugNone, 5000) end

    name = tostring(name or ''):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if name:find("[^%w '%-]") then return notify(_source, Locale.drugBadName, 6000) end
    if #name < (tonumber(CFG.nameMin) or 3) or #name > (tonumber(CFG.nameMax) or 24) then
        return notify(_source, (Locale.drugNameLen):format(CFG.nameMin or 3, CFG.nameMax or 24), 6000)
    end
    if name == gang.drug_name then return end

    local cost <const> = math.max(0, math.floor(tonumber(CFG.renameCost) or 0))
    local who <const> = ch.firstname .. ' ' .. ch.lastname
    if cost > 0 then
        local bal = GangBloodMove(gang, -cost, ch.charIdentifier, who, 'drug rename')
        if not bal then
            return notify(_source, (Locale.bloodShort):format(cost, tonumber(gang.bloodmoney) or 0), 6000)
        end
    end

    local old <const> = gang.drug_name
    gang.drug_name = name
    MySQL.update('UPDATE gangs SET drug_name = ? WHERE id = ?', { name, gang.id })
    drugLog(gang.id, ch.charIdentifier, who, 'rename', cost, old .. ' -> ' .. name)
    GangLog(gang.id, 'drug', ('renamed the product to %s'):format(name), who)
    -- product already in satchels keeps the name it was made under; that is the point
    notify(_source, (Locale.drugRenamed):format(name), 7000)
    GangRefreshCrew(gang.id)
end)

RegisterNetEvent('pup-gangs:drugIcon', function(iconKey)
    local _source = source
    local gang, ch = drugGang(_source, true)
    if not gang then return end
    if not hasDrug(gang) then return end
    local ic = iconByKey(tostring(iconKey or ''))
    if not ic or ic.key == gang.drug_icon then return end
    if not GangEditAllowed(_source) then return end

    gang.drug_icon = ic.key
    MySQL.update('UPDATE gangs SET drug_icon = ? WHERE id = ?', { ic.key, gang.id })
    drugLog(gang.id, ch.charIdentifier, ch.firstname .. ' ' .. ch.lastname, 'icon', 0, ic.key)
    notify(_source, (Locale.drugRelabelled):format(ic.label), 6000)
    GangRefreshCrew(gang.id)
end)

-- ------------------------------------------------------------------ SEEDS
RegisterNetEvent('pup-gangs:drugBuySeeds', function(batches)
    local _source = source
    local gang, ch = drugGang(_source, false)
    if not gang then return end
    if not hasDrug(gang) then return notify(_source, Locale.drugNone, 5000) end
    if not canBuy(ch.charIdentifier) then return notify(_source, Locale.notAllowed) end

    local n = math.floor(tonumber(batches) or 1)
    if n ~= n or n < 1 then n = 1 end
    if n > 10 then n = 10 end

    local _, mods = resolveEffects(gang)
    local unit <const> = math.max(0, math.floor((tonumber(CFG.seed.price) or 0) * (1 - mods.seedDiscount) + 0.5))
    local cost <const> = unit * n
    local seeds <const> = math.max(1, math.floor(tonumber(CFG.seed.perBuy) or 1)) * n

    local collect <const> = (CFG.seed.collectAtFence == true)
    local who <const> = ch.firstname .. ' ' .. ch.lastname

    if collect then
        -- ORDER. The ledger pays now; the seed waits with the fence.
        local pending <const> = tonumber(gang.drug_seed_pending) or 0
        local maxP <const> = tonumber(CFG.seed.maxPending) or 0
        if maxP > 0 and (pending + seeds) > maxP then
            return notify(_source, (Locale.drugSeedOrderCap):format(maxP, pending), 7000)
        end

        local bal = GangBloodMove(gang, -cost, ch.charIdentifier, who, 'drug seed order')
        if not bal then
            return notify(_source, (Locale.bloodShort):format(cost, tonumber(gang.bloodmoney) or 0), 6000)
        end

        gang.drug_seed_pending = pending + seeds
        MySQL.update('UPDATE gangs SET drug_seed_pending = ? WHERE id = ?',
            { gang.drug_seed_pending, gang.id })
        drugLog(gang.id, ch.charIdentifier, who, 'seedorder', cost, ('%d seed ordered'):format(seeds))
        GangLog(gang.id, 'drug', ('ordered %d seed for %d'):format(seeds, cost), who)
        notify(_source, (Locale.drugSeedOrdered):format(seeds, bal), 8000)
        GangRefreshCrew(gang.id)
        return
    end

    -- STRAIGHT TO THE SATCHEL (collectAtFence = false).
    -- Carry check BEFORE the ledger is touched, so a refusal never costs anything.
    -- getItemCount takes its callback SECOND - nil here, same as server/blood.lua
    local held <const> = tonumber(VorpInv:getItemCount(_source, nil, CFG.seedItem)) or 0
    local cap <const> = tonumber(CFG.seed.maxHeld) or 0
    if cap > 0 and (held + seeds) > cap then
        return notify(_source, (Locale.drugSeedCap):format(cap), 6000)
    end
    if not VorpInv:canCarryItem(_source, CFG.seedItem, seeds) then
        return notify(_source, Locale.drugSeedCarry, 5000)
    end

    local bal = GangBloodMove(gang, -cost, ch.charIdentifier, who, 'drug seed')
    if not bal then
        return notify(_source, (Locale.bloodShort):format(cost, tonumber(gang.bloodmoney) or 0), 6000)
    end

    -- the ledger is already debited: if the hand-over fails, put it back
    local ok = pcall(function() VorpInv:addItem(_source, CFG.seedItem, seeds, metaFor(gang, true)) end)
    if not ok then
        GangBloodMove(gang, cost, ch.charIdentifier, who, 'drug seed refund')
        return notify(_source, Locale.drugSeedFailed, 6000)
    end

    drugLog(gang.id, ch.charIdentifier, who, 'seed', cost, ('%d seed'):format(seeds))
    GangLog(gang.id, 'drug', ('bought %d seed for %d'):format(seeds, cost), who)
    notify(_source, (Locale.drugSeedBought):format(seeds, bal), 7000)
end)

-- COLLECTING THE ORDER. Any member may run the errand - ordering was the
-- leadership act, fetching it is not. Fired from the fence menu in pup_robbery.
-- one pickup per gang at a time: the inventory calls below wait, and a second
-- pickup running alongside would read the same order
local seedPickupBusy = {}

local function collectSeed(_source, gang, ch)
    local pending <const> = tonumber(gang.drug_seed_pending) or 0
    if pending < 1 then return notify(_source, Locale.drugSeedNoOrder, 5000) end
    if not atFence(_source) then return notify(_source, Locale.drugSeedNotAtFence, 6000) end

    -- take what fits and leave the rest on the order, so a full satchel never
    -- destroys seed the gang has already paid for
    local held <const> = tonumber(VorpInv:getItemCount(_source, nil, CFG.seedItem)) or 0
    local cap <const> = tonumber(CFG.seed.maxHeld) or 0
    local take = pending
    if cap > 0 then take = math.min(take, math.max(0, cap - held)) end
    while take > 0 and not VorpInv:canCarryItem(_source, CFG.seedItem, take) do
        take = math.floor(take / 2)
    end
    if take < 1 then return notify(_source, Locale.drugSeedCarry, 6000) end

    -- take it off the order before handing it over; put it back if the hand-over fails
    gang.drug_seed_pending = (tonumber(gang.drug_seed_pending) or 0) - take
    MySQL.update('UPDATE gangs SET drug_seed_pending = ? WHERE id = ?',
        { gang.drug_seed_pending, gang.id })

    local ok, res = pcall(function() return VorpInv:addItem(_source, CFG.seedItem, take, metaFor(gang, true)) end)
    if not ok or res == false then
        gang.drug_seed_pending = (tonumber(gang.drug_seed_pending) or 0) + take
        MySQL.update('UPDATE gangs SET drug_seed_pending = ? WHERE id = ?',
            { gang.drug_seed_pending, gang.id })
        return notify(_source, Locale.drugSeedFailed, 6000)
    end

    local who <const> = ch.firstname .. ' ' .. ch.lastname
    drugLog(gang.id, ch.charIdentifier, who, 'seedpickup', take, ('%d collected'):format(take))
    GangLog(gang.id, 'drug', ('collected %d seed from the fence'):format(take), who)
    notify(_source, gang.drug_seed_pending > 0
        and (Locale.drugSeedPartly):format(take, gang.drug_seed_pending)
        or (Locale.drugSeedGot):format(take), 7000)
    GangRefreshCrew(gang.id)
end

RegisterNetEvent('pup-gangs:drugCollectSeed', function()
    local _source = source
    local gang, ch = drugGang(_source, false)   -- no manage permission needed
    if not gang then return end
    if not hasDrug(gang) then return notify(_source, Locale.drugNone, 5000) end

    if seedPickupBusy[gang.id] then return end
    seedPickupBusy[gang.id] = true
    local ok, err = pcall(collectSeed, _source, gang, ch)
    seedPickupBusy[gang.id] = nil
    if not ok then print(('^1[pup-gangs]^7 seed pickup error: %s'):format(tostring(err))) end
end)

-- What the fence menu in pup_robbery asks before drawing its option
VorpCore.Callback.Register('pup-gangs:getSeedOrder', function(source, cb)
    local none <const> = { count = 0 }
    if not CFG.enabled or not (CFG.seed and CFG.seed.collectAtFence) then return cb(none) end
    local gang = gangOf(source)
    if not gang or not hasDrug(gang) then return cb(none) end
    if CFG.perk and CFG.perk ~= '' and not GangHasPerk(gang, CFG.perk) then return cb(none) end
    cb({ count = tonumber(gang.drug_seed_pending) or 0, label = gang.drug_name })
end)

-- the same answer as an export, for anything that is not the fence menu
exports('DrugSeedOrder', function(src)
    local none <const> = { count = 0 }
    if not CFG.enabled or not (CFG.seed and CFG.seed.collectAtFence) then return none end
    local gang = gangOf(src)
    if not gang or not hasDrug(gang) then return none end
    if CFG.perk and CFG.perk ~= '' and not GangHasPerk(gang, CFG.perk) then return none end
    return { count = tonumber(gang.drug_seed_pending) or 0, label = gang.drug_name }
end)

-- ------------------------------------------------------------ TREE UNLOCKS
RegisterNetEvent('pup-gangs:drugUnlock', function(nodeId)
    local _source = source
    local gang, ch = drugGang(_source, true)
    if not gang then return end
    if not hasDrug(gang) then return end

    local node = nodeById(tostring(nodeId or ''))
    if not node then return end

    local set = nodeSet(gang)
    if set[node.id] then return notify(_source, Locale.drugNodeHave, 4000) end
    for _, req in ipairs(node.prerequisites or {}) do
        if not set[req] then
            local r = nodeById(req)
            return notify(_source, (Locale.drugNodeNeeds):format(r and r.name or req), 6000)
        end
    end

    local cost <const> = math.max(0, math.floor(tonumber(node.requiredPoints) or 0))
    local have <const> = tonumber(gang.drug_points) or 0
    if have < cost then
        return notify(_source, (Locale.drugNodeShort):format(cost, have), 6000)
    end

    -- spend and record in one go; the balance is the server's number throughout
    gang.drug_points = have - cost
    set[node.id] = true
    saveNodes(gang)
    MySQL.update('UPDATE gangs SET drug_points = ? WHERE id = ?', { gang.drug_points, gang.id })

    local who <const> = ch.firstname .. ' ' .. ch.lastname
    drugLog(gang.id, ch.charIdentifier, who, 'unlock', -cost, node.id)
    GangLog(gang.id, 'drug', ('learned %s'):format(node.name or node.id), who)
    notify(_source, (Locale.drugNodeBought):format(node.name or node.id, gang.drug_points), 7000)
    GangRefreshCrew(gang.id)
end)

-- ------------------------------------------------------------ CONSUMPTION
-- fred_metabolism owns the effect. We hand it a resolved item table and it runs
-- exactly the code every other consumable runs.
if CFG.enabled and CFG.drugItem and CFG.drugItem ~= '' then
    VorpInv:registerUsableItem(CFG.drugItem, function(data)
        local _source <const> = data.source
        -- the EXACT stored metadata of the stack that was clicked, handed to us
        -- by vorp_inventory. The client never names it.
        local meta <const> = (data.item and data.item.metadata) or {}
        local owner <const> = tonumber(meta.gangid)

        local gang, ch = gangOf(_source)
        if not ch then return end

        if not owner then
            return notify(_source, Locale.drugUnmarked, 5000)
        end
        if not gang or gang.id ~= owner then
            -- another gang's product. It is theirs, and it is not for you.
            return notify(_source, Locale.drugNotYours, 6000)
        end
        if not hasDrug(gang) then return end

        local e <const> = resolveEffects(gang)
        -- claim the unit FIRST: no effect is applied until the item is gone
        local subbed = false
        pcall(function()
            subbed = VorpInv:subItem(_source, CFG.drugItem, 1, meta) ~= false
        end)
        if not subbed then return end

        TriggerClientEvent('fred_meta:applyEffect', _source, {
            Name = CFG.drugItem,
            DisplayName = gang.drug_name,
            Hunger = e.hunger, Thirst = e.thirst, Metabolism = e.metabolism,
            InnerCoreHealth = e.health,
            InnerCoreStamina = e.stamina,
            InnerCoreDeadeye = e.deadeye,
            InnerCoreHealthGold = e.healthGold,
            InnerCoreStaminaGold = e.staminaGold,
            InnerCoreDeadeyeGold = e.deadeyeGold,
            OuterCoreHealthGold = 0.0, OuterCoreStaminaGold = 0.0, OuterCoreDeadeyeGold = 0.0,
            Animation = CFG.effect.animation or '',
            PropName = CFG.effect.prop or '',
            Effect = CFG.effect.screen or '',
            EffectDuration = e.durationMs,
            DurationMs = e.durationMs,
            Diff = 0,
        })
        notify(_source, gang.drug_name, 4000)
        dbg('consumed', gang.drug_name, 'by', _source)
    end)
end

-- ------------------------------------------------------- pup_homestead BRIDGE
-- Called from pup_homestead's planttypecheck for the gang crop only.
exports('DrugCanPlant', function(src)
    if not CFG.enabled then return false end
    local gang, ch = gangOf(src)
    if not ch then return false end
    if not gang then
        notify(src, Locale.noGang)
        return false
    end
    if CFG.perk and CFG.perk ~= '' and not GangHasPerk(gang, CFG.perk) then
        notify(src, Locale.lockedPerk or 'Your gang has not unlocked that.', 6000)
        return false
    end
    if not hasDrug(gang) then
        notify(src, Locale.drugNone, 6000)
        return false
    end
    -- the seed in hand must be YOUR gang's seed
    local item = nil
    pcall(function() item = VorpInv:getItemContainingMetadata(src, CFG.seedItem, { gangid = gang.id }) end)
    if not item then
        notify(src, Locale.drugSeedTheirs, 6000)
        return false
    end
    return true
end)

-- Called from pup_homestead's harvest path. `dryRun` is the capacity pre-check
-- that runs before ANY reward is handed out; the real call then grants.
-- Returns a TABLE { count, label } - cross-resource exports do not carry
-- multiple return values reliably, so nothing here depends on them.
exports('DrugHarvest', function(src, baseCount, dryRun)
    local none <const> = { count = 0 }
    if not CFG.enabled then return none end
    local gang = gangOf(src)
    if not gang or not hasDrug(gang) then return none end
    if CFG.perk and CFG.perk ~= '' and not GangHasPerk(gang, CFG.perk) then return none end

    local _, mods = resolveEffects(gang)
    local n = math.max(1, math.floor((tonumber(baseCount) or 1) + (tonumber(mods.yield) or 0)))
    if not VorpInv:canCarryItem(src, CFG.drugItem, n) then return none end
    if dryRun then return { count = n, label = gang.drug_name } end

    local ok = pcall(function() VorpInv:addItem(src, CFG.drugItem, n, metaFor(gang, false)) end)
    if not ok then return none end
    dbg('harvest', n, gang.drug_name, 'to', src)
    return { count = n, label = gang.drug_name }
end)

-- Take the planting cost off the player's OWN gang's seed stack.
-- pup_homestead's plain subItem would take it off whatever gang_seed stack it
-- found first, so a looted rival seed could pay for your own planting.
exports('DrugTakeSeed', function(src, amount)
    if not CFG.enabled then return false end
    local n = math.max(1, math.floor(tonumber(amount) or 1))
    local gang = gangOf(src)
    if not gang then return false end
    local item = nil
    pcall(function() item = VorpInv:getItemContainingMetadata(src, CFG.seedItem, { gangid = gang.id }) end)
    if not item or (tonumber(item.count) or 0) < n then return false end
    local ok, res = pcall(function() return VorpInv:subItem(src, CFG.seedItem, n, item.metadata) end)
    return ok and res ~= false
end)

-- --------------------------------------------------- pup_hideouts BRIDGE
-- What this player has to sell, if anything. pup_hideouts treats the return
-- value as one more entry in its own recipe scan.
exports('DrugSellOffer', function(src)
    if not CFG.enabled then return nil end
    local gang = gangOf(src)
    if not gang then return nil end

    local item = nil
    pcall(function() item = VorpInv:getItemContainingMetadata(src, CFG.drugItem, { gangid = gang.id }) end)
    if not item then return nil end
    local held = tonumber(item.count) or 0
    if held < 1 then return nil end

    -- the locals may refuse it anywhere but rival ground
    if CFG.sale.foreignOnly then
        local owner = DrugTurfOwnerAt(src)
        if not owner or owner == gang.id then return nil end
    else
        local owner = DrugTurfOwnerAt(src)
        if owner == gang.id and CFG.sale.ownTurfSells == false then return nil end
        if owner == nil and CFG.sale.neutralSells == false then return nil end
    end

    local _, mods = resolveEffects(gang)
    local price = math.max(1, math.floor((tonumber(CFG.sale.price) or 0) * (1 + (tonumber(mods.saleValue) or 0)) + 0.5))
    return {
        resultitem = CFG.drugItem,
        label = (item.metadata and item.metadata.label) or gang.drug_name,
        sellprice = price,
        held = held,
    }
end)

-- TAKE the goods for a sale. pup-gangs does the removal itself so the stack's
-- metadata never leaves this resource: vorp_inventory matches a metadata sub on
-- exact table equality, and a round trip through an export re-encodes it.
-- Also the only place that guarantees the units come off the SELLER'S OWN gang
-- stack - getItemCount sums every gang's and would let one crew sell another's.
-- Returns how many were actually taken, which may be fewer than asked.
exports('DrugTakeForSale', function(src, want)
    local none <const> = { count = 0 }
    if not CFG.enabled then return none end
    local n = math.max(1, math.floor(tonumber(want) or 1))
    local gang = gangOf(src)
    if not gang then return none end

    local item = nil
    pcall(function() item = VorpInv:getItemContainingMetadata(src, CFG.drugItem, { gangid = gang.id }) end)
    if not item then return none end
    local have <const> = tonumber(item.count) or 0
    if have < 1 then return none end
    if n > have then n = have end

    local ok, res = pcall(function() return VorpInv:subItem(src, CFG.drugItem, n, item.metadata) end)
    if not ok or res == false then return none end
    return { count = n, label = (item.metadata and item.metadata.label) or gang.drug_name }
end)

-- Called once, after pup_hideouts has taken the goods and paid for them.
-- This is where turf decides whether the crew learns anything.
exports('DrugSaleDone', function(src, sold, pay)
    if not CFG.enabled then return nil end
    sold = math.max(0, math.floor(tonumber(sold) or 0))
    if sold < 1 then return nil end

    local gang, ch = gangOf(src)
    if not gang or not ch or not hasDrug(gang) then return nil end

    local owner <const> = DrugTurfOwnerAt(src)
    local qualified <const> = owner ~= nil and owner ~= gang.id
    if not qualified then
        dbg('sale on', owner and 'own ground' or 'neutral ground', '- no progress')
        return { qualified = false, points = 0 }
    end

    local _, mods = resolveEffects(gang)
    local per <const> = math.max(0, math.floor(tonumber(CFG.sale.pointsPerUnit) or 0))
    local cap <const> = math.max(0, math.floor(tonumber(CFG.sale.pointsPerSaleCap) or 0))
    local gained = math.floor(per * sold * (1 + (tonumber(mods.progression) or 0)) + 0.5)
    if cap > 0 and gained > cap then gained = cap end

    local rival = GangById(owner)
    local who <const> = ch.firstname .. ' ' .. ch.lastname
    addPoints(gang, gained, ch.charIdentifier, who,
        ('%d sold on %s ground for %d'):format(sold, rival and rival.name or ('gang ' .. tostring(owner)), tonumber(pay) or 0))
    notify(src, (Locale.drugSaleWord):format(gained), 6000)
    return { qualified = true, points = gained, rival = rival and rival.name or nil }
end)

-- The money multiplier for a QUALIFYING sale. pup_hideouts asks before paying.
exports('DrugSaleMult', function(src)
    if not CFG.enabled then return 1.0 end
    local gang = gangOf(src)
    if not gang then return 1.0 end
    local owner = DrugTurfOwnerAt(src)
    if owner == nil or owner == gang.id then return 1.0 end
    return math.max(1.0, (tonumber(CFG.sale.bonusMult) or 1.0) + 0.0)
end)

-- ------------------------------------------------------------- PANEL FEED
VorpCore.Callback.Register('pup-gangs:getDrug', function(source, cb)
    local _source = source
    if not CFG.enabled then return cb(false) end
    local gang, ch = gangOf(_source)
    if not gang or not ch then return cb(false) end

    local unlocked <const> = CFG.perk == '' or CFG.perk == nil or GangHasPerk(gang, CFG.perk) == true
    local manage <const> = canManage(ch.charIdentifier)
    local set <const> = nodeSet(gang)
    local e, mods = resolveEffects(gang)

    local tree = {}
    for _, n in ipairs(CFG.tree or {}) do
        local ready = true
        for _, req in ipairs(n.prerequisites or {}) do
            if not set[req] then ready = false break end
        end
        tree[#tree + 1] = {
            id = n.id, name = n.name, description = n.description, icon = n.icon,
            tier = n.tier, cost = n.requiredPoints, prerequisites = n.prerequisites or {},
            effect = n.effect, effectValue = n.effectValue,
            owned = set[n.id] == true,
            ready = ready,
        }
    end

    local icons = {}
    for _, ic in ipairs(CFG.icons or {}) do
        icons[#icons + 1] = { key = ic.key, label = ic.label, image = ic.image }
    end

    local lvl <const> = drugLevel(gang)
    local seedCost <const> = math.max(0, math.floor((tonumber(CFG.seed.price) or 0) * (1 - mods.seedDiscount) + 0.5))

    cb({
        unlocked = unlocked,
        perk = CFG.perk,
        perkLabel = (Config.Perks.labels or {})[CFG.perk] or CFG.perk,
        created = hasDrug(gang),
        name = gang.drug_name or '',
        icon = gang.drug_icon or '',
        icons = icons,
        points = tonumber(gang.drug_points) or 0,
        earned = tonumber(gang.drug_earned) or 0,
        level = lvl.level, levelLabel = lvl.label,
        tree = tree,
        canManage = manage,
        canBuy = canBuy(ch.charIdentifier),
        ledger = tonumber(gang.bloodmoney) or 0,
        seedCost = seedCost,
        seedPer = math.max(1, math.floor(tonumber(CFG.seed.perBuy) or 1)),
        seedItem = CFG.seedItem,
        -- the order waiting with the fence, and roughly where he is working.
        -- The REGION only - naming the exact stop is what the rumour perks buy,
        -- where he travels is meant to be learned in the world.
        seedAtFence = (CFG.seed.collectAtFence == true),
        seedPending = tonumber(gang.drug_seed_pending) or 0,
        plantType = Config.Integrations.homestead.cropType or '',
        renameCost = math.max(0, math.floor(tonumber(CFG.renameCost) or 0)),
        nameMin = CFG.nameMin, nameMax = CFG.nameMax,
        -- the resolved effect, for display only
        effect = {
            health = e.health, stamina = e.stamina, deadeye = e.deadeye,
            healthGold = e.healthGold, staminaGold = e.staminaGold,
            seconds = math.floor((e.durationMs or 0) / 1000),
        },
        mods = {
            yield = mods.yield, saleValue = mods.saleValue,
            progression = mods.progression, seedDiscount = mods.seedDiscount,
        },
        sale = {
            pointsPerUnit = CFG.sale.pointsPerUnit,
            bonusMult = CFG.sale.bonusMult,
            foreignOnly = CFG.sale.foreignOnly == true,
        },
    })
end)

-- admin / dev
RegisterCommand('gangdrug', function(src, args)
    if src ~= 0 then
        local u = VorpCore.getUser(src)
        if not u or u.getGroup ~= 'admin' then return end
    end
    local gangid, amount = tonumber(args[1]), tonumber(args[2])
    local g = gangid and GangById(gangid)
    if not g or not amount then return print('usage: gangdrug <gangid> <points>') end
    addPoints(g, amount, nil, 'admin', 'admin grant')
    print(('^2[pup-gangs]^7 %s drug progress -> %d'):format(g.name, g.drug_points or 0))
end, false)
