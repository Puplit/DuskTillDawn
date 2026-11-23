-- pup-gangs | server/features.lua: gang tables, levels/perks, stashes, dens and missions.
-- Loads after server/main.lua and reuses its state through the bridge at the bottom of that file.

local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)
if not VorpCore or not VorpCore.getUser then
    VorpCore = exports.vorp_core:GetCore()
end
local VorpInv = exports.vorp_inventory

local function dbg(...)
    if not Config.General.debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print("^5[pup-gangs]^7 " .. table.concat(parts, " "))
end

local function DBQuery(query, params)
    if _G.MySQL and _G.MySQL.query and _G.MySQL.query.await then
        return _G.MySQL.query.await(query, params or {})
    end
    return exports.oxmysql:query_async(query, params or {})
end
local function DBExec(query, params)
    if _G.MySQL and _G.MySQL.update then return _G.MySQL.update(query, params or {}) end
    return exports.oxmysql:update(query, params or {})
end
local function DBInsert(query, params)
    if _G.MySQL and _G.MySQL.insert and _G.MySQL.insert.await then
        return _G.MySQL.insert.await(query, params or {})
    end
    return exports.oxmysql:insert_async(query, params or {})
end

local function Char(src)
    local user = VorpCore.getUser(src)
    return user and user.getUsedCharacter or nil
end
local function notify(src, msg, dur) VorpCore.NotifyRightTip(src, msg, dur or 4000) end
local function now() return os.time() end

-- connected source for a character id (nil when they are offline)
local function charSource(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local ch = src and Char(src)
        if ch and tonumber(ch.charIdentifier) == charid then return src end
    end
    return nil
end

-- where a player's ped stands, as a vector3. nil when they have no ped.
local function pedPos(src)
    local ped = GetPlayerPed(src)
    local c = ped and ped > 0 and GetEntityCoords(ped) or nil
    return c and vector3(c.x, c.y, c.z) or nil
end

-- is `here` within r of a row or config spot that has x, y, z?
local function within(here, spot, r)
    return #(here - vector3((tonumber(spot.x) or 0) + 0.0, (tonumber(spot.y) or 0) + 0.0, (tonumber(spot.z) or 0) + 0.0)) <= r
end

-- state owned by this file
GANG_TABLES = GANG_TABLES or {}   -- [gangid] = row
local plants = {}                 -- [plantid] = row

-- Den state lives HERE, above everything that touches it: the drug run starts at a den
local dens      = {}   -- [id] = row
local denRaids  = {}   -- [denId] = { src, attacker, defender, endts }
local denFound  = {}   -- [gangid][denId] = true  (which gangs have FOUND a fixed den)
local denSeizes = {}   -- [denId] = { gangid, endts, empty }  (seize in progress)

-- Forward declarations: the raid tick and the den payload (both written above the FIXED DENS section) call these
local denLabel, hasFound, markFound, giveDen

-- IN-FLIGHT DRUG RUNS: [charid] = { gangid, target, denId, denX/Y/Z, takenAt,
-- plantId, collectBy }. One run per carrier; cleared when it pays out or dies.
local activeRuns = {}

-- LEVELS AND PERKS
function GangLevel(points)
    points = tonumber(points) or 0
    local current = Config.Perks.levels[1]
    for _, tier in ipairs(Config.Perks.levels) do
        if points >= tier.points then current = tier end
    end
    return current
end

function GangNextLevel(points)
    points = tonumber(points) or 0
    for _, tier in ipairs(Config.Perks.levels) do
        if points < tier.points then return tier end
    end
    return nil -- maxed
end

-- merged perks for a gang at its current level
function GangPerks(points)
    local tier = GangLevel(points)
    return tier and tier.perks or Config.Perks.levels[1].perks
end

-- Is this perk OFFERED at the gang's level?
function GangPerkAvailable(gangOrPoints, flag)
    local points = (type(gangOrPoints) == 'table')
        and (tonumber(gangOrPoints.points) or 0)
        or (tonumber(gangOrPoints) or 0)
    for _, u in ipairs(GangPerks(points).unlocks or {}) do
        if u == flag then return true end
    end
    return false
end

-- Does a gang actually HAVE a perk? With Config.Blood.perksNeedBuying a level only offers it
function GangHasPerk(gangOrPoints, flag)
    if type(gangOrPoints) ~= 'table' then
        return GangPerkAvailable(gangOrPoints, flag)
    end
    local gang = gangOrPoints

    if not (Config.Blood and Config.Blood.enabled and Config.Blood.perksNeedBuying) then
        -- perksNeedBuying off: the level hands it over
        if GangPerkAvailable(gang, flag) then return true end
    end

    -- bought with blood money (server/blood.lua, loaded after this file - so this is a runtime lookup, never a load-time one)
    if GangBoughtPerk then return GangBoughtPerk(gang, flag) end
    return false
end

exports('GetGangLevel', function(gangid)
    local g = GangById(gangid)
    if not g then return nil end
    local tier = GangLevel(g.points)
    return { level = tier.level, label = tier.label, points = g.points, perks = tier.perks }
end)

exports('HasPerk', function(gangid, flag)
    local g = GangById(gangid)
    return g ~= nil and GangHasPerk(g, flag)
end)

-- GANG TABLE - the founding gate: a table may only be placed INSIDE a house the placer owns or holds keys to
local UNFOUNDED = {}

local function loadTables()
    GANG_TABLES = {}
    UNFOUNDED = {}
    -- founding tables have no gang yet: gangid must accept NULL (a unique key allows any number of NULLs)
    DBExec('ALTER TABLE gang_tables MODIFY COLUMN gangid INT(11) NULL')
    for _, row in ipairs(DBQuery('SELECT * FROM gang_tables') or {}) do
        row.id = tonumber(row.id)
        row.gangid = tonumber(row.gangid) -- nil for a founding table
        row.houseid = tonumber(row.houseid)
        row.placed_by = tonumber(row.placed_by)
        if row.gangid then
            GANG_TABLES[row.gangid] = row
        elseif row.placed_by then
            UNFOUNDED[row.placed_by] = row
        end
    end
    local n, u = 0, 0
    for _ in pairs(GANG_TABLES) do n = n + 1 end
    for _ in pairs(UNFOUNDED) do u = u + 1 end
    dbg('loaded', n, 'gang table(s),', u, 'founding table(s)')
end

-- the gang_table item places itself (with the panel locked to the table, the item is the way in)
local function registerTableUsable()
    local ok, err = pcall(function()
        exports.vorp_inventory:registerUsableItem(Config.Table.item, function(data)
            local src = data.source
            dbg('gang_table used by src', src)
            exports.vorp_inventory:closeInventory(src)
            TriggerClientEvent('pup-gangs:useTableItem', src)
        end)
    end)
    if ok then
        print(('^2[pup-gangs]^7 usable item "%s" registered'):format(Config.Table.item))
    else
        print(('^1[pup-gangs]^7 could NOT register usable item "%s": %s'):format(Config.Table.item, tostring(err)))
    end
end

CreateThread(function()
    while GetResourceState('vorp_inventory') ~= 'started' do Wait(250) end
    Wait(1500)
    registerTableUsable()
end)

-- bridge for server/main.lua's create flow
function GangUnfoundedTable(charid)
    return UNFOUNDED[tonumber(charid) or -1]
end

function GangBindTable(charid, gangid)
    charid, gangid = tonumber(charid), tonumber(gangid)
    local t = charid and UNFOUNDED[charid]
    if not t or not gangid then return false end
    UNFOUNDED[charid] = nil
    t.gangid = gangid
    GANG_TABLES[gangid] = t
    DBExec('UPDATE gang_tables SET gangid = ? WHERE id = ?', { gangid, t.id })
    TriggerClientEvent('pup-gangs:tablesDirty', -1)
    return true
end

local function houseAllowsTable(houseid)
    local ok, info = pcall(function() return exports['pup_realestate']:getHouseInfo(houseid) end)
    if not ok or type(info) ~= 'table' then return false, 'housing unavailable' end
    if not info.owned then return false, 'that house is not owned' end
    return true
end

local function playerHasHouse(charid, houseid)
    local ok, allowed = pcall(function()
        return exports['pup_realestate']:hasHouseAccess(charid, houseid)
    end)
    return ok and allowed == true
end

RegisterNetEvent('pup-gangs:placeTable', function(houseid, x, y, z, h)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    dbg('placeTable: src', _source, 'charid', charid, 'house', tostring(houseid), 'member', m ~= nil)

    if m then
        -- MEMBER path: siting (or re-siting) an existing gang's table
        local gang = GangById(m.gangid)
        if not gang then return end
        -- rank gate: only ranks that may manage territory may site the table
        if not GangCan(charid, 'territory') then dbg('placeTable: DENIED rank') return notify(_source, Locale.notAllowed) end
        if GANG_TABLES[gang.id] then dbg('placeTable: DENIED gang already has a table') return notify(_source, Locale.tableExists) end
    else
        -- founding path: an unaffiliated player places the table first, then founds the gang at it
        if UNFOUNDED[charid] then dbg('placeTable: DENIED founding table already placed') return notify(_source, Locale.alreadyPlacedTable) end
    end

    houseid = tonumber(houseid)
    if not houseid then dbg('placeTable: DENIED no house id') return notify(_source, Locale.needHouse) end

    -- the table goes where the player is working: the gizmo starts at their feet. The coords reach
    -- the database, the map and the crew, and "not <=" also refuses NaN.
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    local here = pedPos(_source)
    if not here or not x or not y or not z or not (#(here - vector3(x + 0.0, y + 0.0, z + 0.0)) <= 100.0) then
        dbg('placeTable: DENIED coords')
        return notify(_source, Locale.needHouse)
    end
    if h and h ~= h then h = nil end

    -- BOTH checks matter: the house must be owned by someone, and THIS player must have access to it
    local allowed, why = houseAllowsTable(houseid)
    if not allowed then dbg('placeTable: DENIED houseAllowsTable:', tostring(why)) return notify(_source, why or Locale.needHouse) end
    if not playerHasHouse(charid, houseid) then dbg('placeTable: DENIED hasHouseAccess') return notify(_source, Locale.needHouse) end

    -- getItemCount is (source, CALLBACK, itemName) - nil callback = sync return
    local count = tonumber(VorpInv:getItemCount(_source, nil, Config.Table.item)) or 0
    if count < 1 then dbg('placeTable: DENIED no table item') return notify(_source, 'You need a ' .. Config.Table.item .. '.') end
    VorpInv:subItem(_source, Config.Table.item, 1)
    dbg('placeTable: all gates passed - inserting')

    local gangid = m and GangById(m.gangid) and m.gangid or nil
    local id = DBInsert(
        'INSERT INTO gang_tables (gangid, houseid, x, y, z, h, placed_by, placed_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { gangid, houseid, x, y, z, h or 0.0, charid, now() })
    if not id then return end

    local row = { id = id, gangid = gangid, houseid = houseid, x = x, y = y, z = z, h = h or 0.0, placed_by = charid }
    if gangid then
        GANG_TABLES[gangid] = row
        GangLog(gangid, 'table', ('table placed in house %d'):format(houseid), ch.firstname .. ' ' .. ch.lastname)
        notify(_source, Locale.tablePlaced)
    else
        UNFOUNDED[charid] = row
        notify(_source, Locale.createAtTable, 8000)
    end
    TriggerClientEvent('pup-gangs:tablesDirty', -1)
    TriggerClientEvent('pup-gangs:territoriesDirty', -1) -- the HQ influence circle moved
end)

RegisterNetEvent('pup-gangs:pickupTable', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)

    local t
    if m then
        if not GangCan(charid, 'territory') then return notify(_source, Locale.notAllowed) end
        t = GANG_TABLES[m.gangid]
        if not t then return notify(_source, Locale.noTable) end
        GANG_TABLES[m.gangid] = nil
        GangLog(m.gangid, 'table', 'table picked up', ch.firstname .. ' ' .. ch.lastname)
    else
        -- founding table: its placer can always take it back
        t = UNFOUNDED[charid]
        if not t then return notify(_source, Locale.noTable) end
        UNFOUNDED[charid] = nil
    end

    DBExec('DELETE FROM gang_tables WHERE id = ?', { t.id })
    VorpInv:addItem(_source, Config.Table.item, 1)
    notify(_source, Locale.tableRemoved)
    TriggerClientEvent('pup-gangs:tablesDirty', -1)
    TriggerClientEvent('pup-gangs:territoriesDirty', -1) -- HQ circle gone
end)

-- tables visible to this player: their OWN gang's - or, with no gang yet, the founding table they placed
VorpCore.Callback.Register('pup-gangs:getTables', function(source, cb)
    local ch = Char(source)
    if not ch then return cb({}) end
    local m = GangMemberOf(ch.charIdentifier)
    local t = m and GANG_TABLES[m.gangid] or UNFOUNDED[ch.charIdentifier]
    if not t then return cb({}) end
    cb({ {
        gangid = t.gangid, houseid = t.houseid,
        x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h),
    } })
end)

-- STASHES
local function stashInvId(gangid, index)
    return Config.Stashes.invOffset + (tonumber(gangid) * 10) + tonumber(index)
end

local function registerStash(gang, stash, index)
    local cid = stashInvId(gang.id, index)
    local perks = GangPerks(gang.points)
    local slots = (tonumber(stash.slots) or 10) + (tonumber(perks.stashSlots) or 0)

    local ok, err = pcall(function()
        exports.vorp_inventory:registerInventory({
            -- STRING id: vorp_inventory's MOVE_TO / TAKE_FROM look up CUSTOM_INVENTORIES[tostring(id)]
            id                   = tostring(cid),
            -- `bare` stashes show the label alone
            name                 = stash.bare and stash.label
                                    or ('%s - %s'):format(gang.name, stash.label),
            limit                = slots,
            -- the Gang Armory (Empire perk) is the ONLY gang storage that takes weapons
            acceptWeapons        = stash.weapons == true,
            shared               = true,
            ignoreItemStackLimit = true,
            whitelistItems       = (stash.whitelist and #stash.whitelist > 0) or false,
            UsePermissions       = false,
            UseBlackList         = false,
            whitelistWeapons     = false,
        })
        -- whitelistItems above is IGNORED by customInventory's constructor
        for _, item in ipairs(stash.whitelist or {}) do
            exports.vorp_inventory:setCustomInventoryItemLimit(tostring(cid), item, -1)
        end
    end)
    if not ok then
        print(('^1[pup-gangs]^7 could not register stash %s: %s'):format(tostring(cid), tostring(err)))
        return nil
    end
    return cid
end

-- ONE-TIME stash id migration (offset 9000000 -> 13000000)
CreateThread(function()
    Wait(3000) -- let the DB layer come up
    local OLD_OFFSET <const> = 9000000
    if (tonumber(Config.Stashes.invOffset) or 0) == OLD_OFFSET then return end

    DBExec('CREATE TABLE IF NOT EXISTS gang_meta (k VARCHAR(50) PRIMARY KEY, v VARCHAR(50) NOT NULL)')
    Wait(500)
    local done = DBQuery("SELECT v FROM gang_meta WHERE k = 'stash_offset_13m'")
    if done and done[1] then return end

    local moved = 0
    for _, g in ipairs(DBQuery('SELECT id FROM gangs') or {}) do
        local gid = tonumber(g.id)
        if gid then
            for index = 1, #Config.Stashes.list do
                local oldId = OLD_OFFSET + (gid * 10) + index
                local newId = (tonumber(Config.Stashes.invOffset)) + (gid * 10) + index
                local rows = DBQuery('SELECT COUNT(*) AS n FROM character_inventories WHERE inventory_type = ?', { tostring(oldId) })
                local n = rows and rows[1] and tonumber(rows[1].n) or 0
                if n > 0 then
                    DBExec('UPDATE character_inventories SET inventory_type = ? WHERE inventory_type = ?',
                        { tostring(newId), tostring(oldId) })
                    moved = moved + n
                end
            end
        end
    end
    DBInsert("INSERT INTO gang_meta (k, v) VALUES ('stash_offset_13m', 'done')", {})
    print(('^2[pup-gangs]^7 stash id migration complete - %d stored item rows moved to the 13000000 range'):format(moved))
end)

-- is this position at one of the gang's dens: its door, or the spots inside its shack?
local function atOwnDen(gang, here, r)
    for _, t in pairs(dens) do
        if t.gangid == gang.id then
            if within(here, t, r) then return true end
            local site = (Config.Dens.sites or {})[denSite(t) or '']
            if site then
                for _, k in ipairs({ 'stash', 'bench', 'menu', 'inside' }) do
                    if site[k] and within(here, site[k], r) then return true end
                end
            end
        end
    end
    return false
end

RegisterNetEvent('pup-gangs:openStash', function(stashKey)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    local stash, index
    for i, s in ipairs(Config.Stashes.list) do
        if s.key == stashKey then stash, index = s, i break end
    end
    if not stash then return end

    -- WHERE THE STASH LIVES
    if stash.den then
        -- at the den, not merely holding one
        local ped = GetPlayerPed(_source)
        local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
        if not pc then return end
        local here = vector3(pc.x, pc.y, pc.z)

        local atDen = false
        for _, t in pairs(dens) do
            if t.gangid == gang.id then
                local spots = { { x = t.x, y = t.y, z = t.z } }
                local site = (Config.Dens.sites or {})[denSite(t) or '']
                if site then
                    for _, k in ipairs({ 'stash', 'bench', 'menu', 'inside' }) do
                        if site[k] then spots[#spots + 1] = site[k] end
                    end
                end
                for _, s in ipairs(spots) do
                    if #(here - vector3(tonumber(s.x) + 0.0, tonumber(s.y) + 0.0, tonumber(s.z) + 0.0)) <= 8.0 then
                        atDen = true break
                    end
                end
            end
            if atDen then break end
        end
        if not atDen then return notify(_source, Locale.denNotHere) end
    elseif not GANG_TABLES[gang.id] then
        return notify(_source, Locale.noTable)
    elseif not Config.General.menuAnywhere then
        -- these buttons are on the panel, and the panel opens at the gang table or at a den
        local here = pedPos(_source)
        if not here then return end
        if not within(here, GANG_TABLES[gang.id], 25.0) and not atOwnDen(gang, here, 25.0) then
            return notify(_source, 'You need to be at your gang table.')
        end
    end

    if stash.unlock and not GangHasPerk(gang, stash.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if (m.rank or 1) < (tonumber(stash.minRank) or 1) then
        return notify(_source, Locale.lockedRank)
    end

    local cid = registerStash(gang, stash, index)
    if not cid then return end
    -- the perk and minRank gates above decided access, and access is also the
    -- right to arrange: a stash belongs to everyone who can reach it
    exports.vorp_inventory:openInventory(_source, tostring(cid), true)
end)

-- DRUG PLANT MISSIONS - pick up a package at your own table, carry it into a RIVAL territory, plant it
local function busiestRivalGang(myGangId)
    local counts = {}
    for _, sid in ipairs(GetPlayers()) do
        local ch = Char(tonumber(sid))
        local m = ch and GangMemberOf(ch.charIdentifier)
        if m and m.gangid ~= myGangId then
            counts[m.gangid] = (counts[m.gangid] or 0) + 1
        end
    end
    local best, bestN = nil, 0
    for gid, n in pairs(counts) do
        local g = GangById(gid)
        -- a target needs ground to plant on: their HQ table or a held fort
        local hasGround = g and (GANG_TABLES[gid] ~= nil)
        if not hasGround and g then
            for _, t in pairs(GangAllTerritories()) do
                if t.gangid == gid then hasGround = true break end
            end
        end
        if g and hasGround then
            if n > bestN or (n == bestN and best and (g.points or 0) > (best.points or 0)) then
                best, bestN = g, n
            end
        end
    end
    return best, bestN
end

RegisterNetEvent('pup-gangs:takePackage', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Missions.enabled then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    -- the run starts at the den, and you must be standing at one of your own
    local den = nil
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if pc then
        local here = vector3(pc.x, pc.y, pc.z)
        for _, th in pairs(dens) do
            if th.gangid == gang.id then
                local spots = { { x = th.x, y = th.y, z = th.z } }
                local site = (Config.Dens.sites or {})[denSite(th) or '']
                if site then
                    for _, k in ipairs({ 'inside', 'menu', 'bench' }) do
                        if site[k] then spots[#spots + 1] = site[k] end
                    end
                end
                for _, s in ipairs(spots) do
                    if #(here - vector3(tonumber(s.x) + 0.0, tonumber(s.y) + 0.0, tonumber(s.z) + 0.0)) <= 8.0 then
                        den = th break
                    end
                end
                if den then break end
            end
        end
    end
    if not den then return notify(_source, Locale.runNeedDen, 6000) end

    if Config.Missions.unlock and not GangHasPerk(gang, Config.Missions.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if (m.rank or 1) < (tonumber(Config.Missions.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end

    -- you do not run this alone
    local need <const> = tonumber(Config.Missions.minPosse) or 1
    if need > 1 then
        local okP, riders = pcall(function() return exports['pup-ui']:GetPosseMembers(_source) end)
        local crew = (okP and type(riders) == 'table') and #riders or 0
        if crew < need then
            dbg('takePackage: POSSE', crew, '<', need)
            return notify(_source, (Locale.runNeedPosse):format(need, crew), 7000)
        end
    end

    -- Supply Lines (Empire perk): the delivery cooldown is halved
    local cdMult = GangHasPerk(gang, 'supply_lines') and 0.5 or 1.0
    local cd = (tonumber(gang.last_mission) or 0) + math.floor(Config.Missions.cooldownMinutes * 60 * cdMult)
    if cd > now() then return notify(_source, Locale.missionCooldown) end

    local target, headcount = busiestRivalGang(gang.id)
    if not target then return notify(_source, Locale.runNoTarget, 6000) end

    if not VorpInv:canCarryItem(_source, Config.Missions.packageItem, 1) then
        return notify(_source, 'You cannot carry that.')
    end
    VorpInv:addItem(_source, Config.Missions.packageItem, 1)

    -- remember the run so the plant can check it landed on the RIGHT crew and the payday knows which den to come home to
    activeRuns[charid] = {
        gangid = gang.id, target = target.id, denId = den.id,
        denX = tonumber(den.x), denY = tonumber(den.y), denZ = tonumber(den.z),
        takenAt = now(),
    }

    local tag = (target.shortname ~= '' and target.shortname or target.name)
    notify(_source, Locale.runTarget .. tag .. ' (' .. headcount .. ' out)', 8000)
    TriggerClientEvent('pup-gangs:runTargeted', _source, {
        target = target.id, tag = tag,
        denX = tonumber(den.x), denY = tonumber(den.y), denZ = tonumber(den.z),
    })
    dbg('run started by gang', gang.id, '-> target', target.id, '(' .. headcount .. ' online)')
end)

RegisterNetEvent('pup-gangs:plantPackage', function(territoryId, x, y, z)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Missions.enabled then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return end
    local gang = GangById(m.gangid)
    if not gang then return end

    local run = activeRuns[charid]
    if not run then return notify(_source, Locale.runNeedDen, 6000) end
    if run.plantId then return end -- one plant per run

    -- the ground must belong to the crew this run was ASSIGNED to
    local ownerGang, groundName
    local hqId = tostring(territoryId):match('^hq(%d+)$')
    if hqId then
        ownerGang = tonumber(hqId)
        local og = GangById(ownerGang)
        groundName = (og and (og.shortname ~= '' and og.shortname or og.name) or '?') .. ' HQ'
    else
        local t = GangTerritory(territoryId)
        if not t or not t.gangid then return notify(_source, Locale.plantNeedRival) end
        ownerGang, groundName = t.gangid, t.name
    end
    if not ownerGang or ownerGang == gang.id then return notify(_source, Locale.plantNeedRival) end
    if ownerGang ~= run.target then
        local tg = GangById(run.target)
        return notify(_source, Locale.runTarget ..
            (tg and (tg.shortname ~= '' and tg.shortname or tg.name) or 'the target crew'), 6000)
    end

    -- standing on that ground, going by the ped: same circle the client tests, plus room for lag.
    -- The plant goes where they stand, because its coords are sent to every player.
    local here = pedPos(_source)
    local ground = GANG_TABLES[ownerGang]
    if not hqId then ground = GangTerritory(territoryId) end
    local holder = GangById(ownerGang)
    if not here or not ground or not holder or not within(here, ground, GangRadius(holder.points) + 30.0) then
        return notify(_source, Locale.plantNeedRival)
    end
    x, y, z = here.x, here.y, here.z

    local count = tonumber(VorpInv:getItemCount(_source, nil, Config.Missions.packageItem)) or 0
    if count < 1 then return end
    VorpInv:subItem(_source, Config.Missions.packageItem, 1)

    local endts = now() + Config.Missions.defendSeconds
    local id = DBInsert(
        'INSERT INTO gang_plants (attacker, defender, territoryid, x, y, z, startts, endts, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { gang.id, ownerGang, tonumber(hqId) and 0 or tonumber(territoryId) or 0, x, y, z, now(), endts, 'active' })
    if not id then return end
    plants[id] = { id = id, attacker = gang.id, defender = ownerGang, territoryid = tonumber(territoryId) or 0,
                   x = x, y = y, z = z, startts = now(), endts = endts, status = 'active',
                   carrier = charid }
    run.plantId = id
    local t = { name = groundName, gangid = ownerGang }

    gang.last_mission = now()
    DBExec('UPDATE gangs SET last_mission = ? WHERE id = ?', { gang.last_mission, gang.id })

    GangLog(gang.id, 'plant', ('planted in %s'):format(t.name), ch.firstname .. ' ' .. ch.lastname)
    GangLog(t.gangid, 'plant', ('contraband planted in %s'):format(t.name), '')
    notify(_source, Locale.plantDone)

    -- everyone sees the contested ground; the DEFENDING gang also gets told
    TriggerClientEvent('pup-gangs:plantStarted', -1, {
        id = id, x = x, y = y, z = z, endts = endts,
        defender = t.gangid, attacker = gang.id, territory = t.name,
    })
    dbg('plant', id, 'attacker', gang.id, 'defender', t.gangid, 'in', t.name)
end)

RegisterNetEvent('pup-gangs:destroyPlant', function(plantId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return end
    local p = plants[tonumber(plantId) or -1]
    if not p or p.status ~= 'active' then return end
    -- only the DEFENDING gang can destroy it
    if p.defender ~= m.gangid then return end
    -- and they have to find it: the client's prompt is at Config.Missions.destroyDistance
    local here = pedPos(_source)
    if not here or not within(here, p, (tonumber(Config.Missions.destroyDistance) or 2.0) + 8.0) then return end

    p.status = 'destroyed'
    DBExec("UPDATE gang_plants SET status = 'destroyed' WHERE id = ?", { p.id })
    plants[p.id] = nil
    -- the run dies with the plant: nothing to carry home
    if p.carrier then activeRuns[p.carrier] = nil end

    GangPayReward(_source, 'defend', 'defended a plant')
    GangLog(p.attacker, 'plant', 'plant was destroyed', '')
    TriggerClientEvent('pup-gangs:plantEnded', -1, { id = p.id, destroyed = true })
    dbg('plant destroyed', p.id, 'by gang', m.gangid)
end)

-- resolve plants whose defend window ran out
CreateThread(function()
    while true do
        Wait(5000)
        local t = now()
        for id, p in pairs(plants) do
            if p.status == 'active' and (tonumber(p.endts) or 0) <= t then
                p.status = 'survived'
                DBExec("UPDATE gang_plants SET status = 'survived' WHERE id = ?", { id })
                plants[id] = nil
                GangLog(p.defender, 'plant', 'failed to find a plant', '')
                TriggerClientEvent('pup-gangs:plantEnded', -1, { id = id, destroyed = false })

                local run = p.carrier and activeRuns[p.carrier]
                if run then
                    run.collectBy = t + (Config.Missions.collectMinutes * 60)
                    local src = charSource(p.carrier)
                    if src then
                        notify(src, Locale.runCollect, 8000)
                        TriggerClientEvent('pup-gangs:runCollect', src, {
                            x = run.denX, y = run.denY, z = run.denZ, collectBy = run.collectBy,
                            secondsLeft = Config.Missions.collectMinutes * 60,
                        })
                    end
                end
                dbg('plant survived', id, '- carrier must now get home')
            end
        end

        -- runs whose window to get home expired
        for cid, run in pairs(activeRuns) do
            if run.collectBy and run.collectBy <= t then
                activeRuns[cid] = nil
                local src = charSource(cid)
                if src then notify(src, Locale.runTooSlow, 6000) end
                TriggerClientEvent('pup-gangs:runEnded', src or -1)
                dbg('run expired for charid', cid)
            end
        end
    end
end)

-- COLLECT: the carrier is back at their own den, alive, in time.
RegisterNetEvent('pup-gangs:collectRun', function()
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local run = activeRuns[charid]
    if not run or not run.collectBy then return end
    if ch.isdead then return notify(_source, Locale.runLostCarrier, 6000) end

    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc then return end
    if #(vector3(pc.x, pc.y, pc.z) - vector3((run.denX or 0) + 0.0, (run.denY or 0) + 0.0, (run.denZ or 0) + 0.0)) > 5.0 then
        return notify(_source, Locale.runNeedDen, 6000)
    end

    activeRuns[charid] = nil

    -- RISK PREMIUM: the busier the crew you hit, the bigger the payday
    local headcount = 0
    for _, sid in ipairs(GetPlayers()) do
        local c2 = Char(tonumber(sid))
        local m2 = c2 and GangMemberOf(c2.charIdentifier)
        if m2 and m2.gangid == run.target then headcount = headcount + 1 end
    end
    local bonus = headcount * (tonumber((Config.Rewards.run or {}).perTargetMember) or 0)
    GangPayReward(_source, 'run', 'delivery run', bonus)
    notify(_source, Locale.runPaid, 6000)
    TriggerClientEvent('pup-gangs:runEnded', _source)
    dbg('run paid to charid', charid)
end)

-- the carrier dying loses the run outright
AddEventHandler('vorp_core:Server:OnPlayerDeath', function()
    local _source = source
    local ch = Char(_source)
    local run = ch and activeRuns[ch.charIdentifier]
    if not run then return end
    activeRuns[ch.charIdentifier] = nil
    notify(_source, Locale.runLostCarrier, 6000)
    TriggerClientEvent('pup-gangs:runEnded', _source)
    if run.gangid then GangLog(run.gangid, 'plant', 'the carrier went down before getting home', '') end
    dbg('run lost - carrier died', ch.charIdentifier)
end)

VorpCore.Callback.Register('pup-gangs:getPlants', function(source, cb)
    local ch = Char(source)
    if not ch then return cb({}) end
    local out = {}
    for _, p in pairs(plants) do
        if p.status == 'active' then
            out[#out + 1] = { id = p.id, x = p.x, y = p.y, z = p.z, endts = p.endts,
                              attacker = p.attacker, defender = p.defender }
        end
    end
    cb(out)
end)

-- Boot
CreateThread(function()
    Wait(4000) -- after server/main.lua's own cache load
    loadTables()
    for _, row in ipairs(DBQuery("SELECT * FROM gang_plants WHERE status = 'active'") or {}) do
        row.id = tonumber(row.id)
        plants[row.id] = row
    end
end)

-- re-register stashes after vorp_inventory restarts (a restart wipes its registry)
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'vorp_inventory' then return end
    dbg('vorp_inventory restarted - gang stashes will re-register on next open')
end)

-- DENS (level 3+ perk) - the drug-ops hub
CreateThread(function()
    Wait(4500)

    -- traphouse -> den rename
    local function tableExists(name)
        local r = DBQuery([[SELECT COUNT(*) AS c FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name = ?]], { name })
        return r and r[1] and (tonumber(r[1].c) or 0) > 0
    end
    local function columnExists(tbl, col)
        local r = DBQuery([[SELECT COUNT(*) AS c FROM information_schema.columns
            WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?]], { tbl, col })
        return r and r[1] and (tonumber(r[1].c) or 0) > 0
    end
    if tableExists('gang_traphouses') and not tableExists('gang_dens') then
        DBExec('RENAME TABLE gang_traphouses TO gang_dens')
        Wait(200)
        dbg('migrated gang_traphouses -> gang_dens')
    end
    if tableExists('gang_trap_found') and not tableExists('gang_den_found') then
        DBExec('RENAME TABLE gang_trap_found TO gang_den_found')
        Wait(200)
        dbg('migrated gang_trap_found -> gang_den_found')
    end
    if columnExists('gang_den_found', 'trapid') and not columnExists('gang_den_found', 'denid') then
        DBExec('ALTER TABLE gang_den_found CHANGE COLUMN trapid denid INT(11) NOT NULL')
        Wait(200)
        dbg('migrated gang_den_found.trapid -> denid')
    end

    DBExec([[CREATE TABLE IF NOT EXISTS gang_dens (
        id INT(11) NOT NULL AUTO_INCREMENT,
        gangid INT(11) NOT NULL,
        houseid INT(11) NOT NULL,
        x DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
        y DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
        z DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
        h DECIMAL(10,4) NOT NULL DEFAULT 0.0000,
        stored INT(11) NOT NULL DEFAULT 0,
        last_brew INT(11) NOT NULL DEFAULT 0,
        last_raided INT(11) NOT NULL DEFAULT 0,
        created_at INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (id),
        UNIQUE KEY uk_pup_gang_dens_house (houseid),
        KEY idx_pup_gang_dens_gang (gangid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    Wait(300)
    -- FIXED DENS need a few more columns than a player-made one: they have no house, they carry a name
    DBExec("ALTER TABLE gang_dens MODIFY COLUMN gangid INT(11) NULL")
    DBExec("ALTER TABLE gang_dens MODIFY COLUMN houseid INT(11) NULL")
    DBExec("ALTER TABLE gang_dens ADD COLUMN IF NOT EXISTS admin TINYINT NOT NULL DEFAULT 0")
    DBExec("ALTER TABLE gang_dens ADD COLUMN IF NOT EXISTS label VARCHAR(64) NOT NULL DEFAULT ''")
    DBExec("ALTER TABLE gang_dens ADD COLUMN IF NOT EXISTS cook_until INT(11) NOT NULL DEFAULT 0")
    DBExec("ALTER TABLE gang_dens ADD COLUMN IF NOT EXISTS last_cook INT(11) NOT NULL DEFAULT 0")
    DBExec("ALTER TABLE gang_dens ADD COLUMN IF NOT EXISTS last_seized INT(11) NOT NULL DEFAULT 0")
    -- which gangs have FOUND which fixed den (discovery is per gang)
    DBExec([[CREATE TABLE IF NOT EXISTS gang_den_found (
        denid  INT(11) NOT NULL,
        gangid INT(11) NOT NULL,
        ts     INT(11) NOT NULL DEFAULT 0,
        PRIMARY KEY (denid, gangid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    Wait(400)

    -- seed the config's fixed dens (idempotent - matched on label)
    for _, loc in ipairs(Config.Dens.locations or {}) do
        local label = tostring(loc.label or '')
        if label ~= '' then
            local exists = DBQuery('SELECT id FROM gang_dens WHERE admin = 1 AND label = ?', { label })
            if not exists or not exists[1] then
                DBInsert([[INSERT INTO gang_dens
                    (gangid, houseid, x, y, z, h, stored, last_brew, last_raided, created_at, admin, label)
                    VALUES (NULL, NULL, ?, ?, ?, ?, 0, ?, 0, ?, 1, ?)]],
                    { loc.x, loc.y, loc.z, loc.h or 0.0, now(), now(), label })
                dbg('seeded fixed den', label)
            end
        end
    end
    Wait(200)

    -- a den is a lease on the session
    if Config.Dens.resetOnRestart ~= false then
        DBExec([[UPDATE gang_dens
                 SET gangid = NULL, stored = 0, cook_until = 0, last_cook = 0,
                     last_seized = 0, last_raided = 0
                 WHERE admin = 1]])
        DBExec('DELETE FROM gang_den_found')
        dbg('dens reset for the new session - all unowned, all unfound')
    end
    Wait(200)

    for _, row in ipairs(DBQuery('SELECT * FROM gang_dens') or {}) do
        row.id = tonumber(row.id)
        row.gangid = tonumber(row.gangid) -- nil = unowned fixed den
        row.stored = tonumber(row.stored) or 0
        row.admin = (tonumber(row.admin) or 0) == 1
        row.cook_until = tonumber(row.cook_until) or 0
        dens[row.id] = row
    end
    for _, row in ipairs(DBQuery('SELECT denid, gangid FROM gang_den_found') or {}) do
        local tid, gid = tonumber(row.denid), tonumber(row.gangid)
        if tid and gid then
            denFound[gid] = denFound[gid] or {}
            denFound[gid][tid] = true
        end
    end
    local n, a = 0, 0
    for _, t in pairs(dens) do n = n + 1 if t.admin then a = a + 1 end end
    dbg('loaded', n, 'den(s),', a, 'fixed')
end)

-- Which Config.Dens.sites key a fixed den belongs to, matched on the label it was seeded with
function denSite(t)
    if not t or not t.admin then return nil end
    local label = tostring(t.label or '')
    if label == '' then return nil end
    for _, loc in ipairs(Config.Dens.locations or {}) do
        if tostring(loc.label or '') == label then return loc.site end
    end
    return nil
end

local function denCount(gangid)
    local n = 0
    for _, t in pairs(dens) do if t.gangid == gangid then n = n + 1 end end
    return n
end

local function denLimitFor(gang)
    local tier = GangLevel(gang.points)
    return tonumber((Config.Dens.maxByLevel or {})[tier.level]) or 0
end

local function broadcastDens()
    TriggerClientEvent('pup-gangs:densDirty', -1)
end

RegisterNetEvent('pup-gangs:designateDen', function(houseid, x, y, z, h)
    local _source = source
    if not Config.Dens.enabled then return end
    -- dens are found, not built
    if not Config.Dens.playerDens then return notify(_source, Locale.denNoBuild) end
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    if not GangCan(charid, 'territory') then return notify(_source, Locale.notAllowed) end
    if not GangHasPerk(gang, Config.Dens.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if denCount(gang.id) >= denLimitFor(gang) then
        return notify(_source, Locale.denLimit)
    end

    houseid = tonumber(houseid)
    if not houseid then return notify(_source, Locale.denNeedHouse) end
    -- HQ and operation stay separate addresses
    local tbl = GANG_TABLES[gang.id]
    if tbl and tonumber(tbl.houseid) == houseid then
        return notify(_source, Locale.denSameAsTable)
    end
    -- one den per property, whoever's it is
    for _, t in pairs(dens) do
        if tonumber(t.houseid) == houseid then return notify(_source, Locale.denHouseTaken) end
    end
    -- same double gate as the gang table: owned, and by THIS player
    local allowed, why = houseAllowsTable(houseid)
    if not allowed then return notify(_source, why or Locale.denNeedHouse) end
    if not playerHasHouse(charid, houseid) then return notify(_source, Locale.denNeedHouse) end

    local id = DBInsert(
        'INSERT INTO gang_dens (gangid, houseid, x, y, z, h, stored, last_brew, last_raided, created_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, 0, ?)',
        { gang.id, houseid, x, y, z, h or 0.0, now(), now() })
    if not id then return end
    dens[id] = { id = id, gangid = gang.id, houseid = houseid, x = x, y = y, z = z, h = h or 0.0,
                       stored = 0, last_brew = now(), last_raided = 0 }
    GangLog(gang.id, 'dens', ('den established in house %d'):format(houseid), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, Locale.denDesignated)
    broadcastDens()
end)

RegisterNetEvent('pup-gangs:shutdownDen', function(denId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return end
    if not GangCan(charid, 'territory') then return notify(_source, Locale.notAllowed) end
    local t = dens[tonumber(denId) or -1]
    if not t or t.gangid ~= m.gangid then return end
    if t.admin then return end -- a fixed den belongs to the map; this would delete it for everyone
    if denRaids[t.id] then return end -- not while it is being hit

    DBExec('DELETE FROM gang_dens WHERE id = ?', { t.id })
    dens[t.id] = nil
    GangLog(m.gangid, 'dens', 'den shut down', ch.firstname .. ' ' .. ch.lastname)
    notify(_source, Locale.denShutdown)
    broadcastDens()
end)

-- collect the brewed packages (members, on site)
RegisterNetEvent('pup-gangs:collectDen', function(denId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return end
    local t = dens[tonumber(denId) or -1]
    if not t or t.gangid ~= m.gangid then return end
    if (m.rank or 1) < (tonumber(Config.Dens.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end
    if denRaids[t.id] then return end -- shelf is frozen during a raid

    -- server-side distance check - the prompt is a convenience, not authority
    local ped = GetPlayerPed(_source)
    local c = ped and GetEntityCoords(ped)
    if not c or #(vector3(c.x, c.y, c.z) - vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)) > 5.0 then return end

    local stored = tonumber(t.stored) or 0
    if stored <= 0 then return notify(_source, Locale.denEmpty) end

    local item = Config.Missions.packageItem
    local given = 0
    for _ = 1, stored do
        local okc, can = pcall(function() return VorpInv:canCarryItem(_source, item, 1) end)
        if okc and can then
            VorpInv:addItem(_source, item, 1)
            given = given + 1
        else
            break
        end
    end
    if given <= 0 then return notify(_source, 'You cannot carry that.') end

    t.stored = stored - given
    DBExec('UPDATE gang_dens SET stored = ? WHERE id = ?', { t.stored, t.id })
    GangLog(t.gangid, 'dens', ('collected %d package(s)'):format(given), m.name)
    notify(_source, Locale.denCollected)
    broadcastDens()
end)

-- RAID: a rival holds the spot for raidHoldSeconds; the owners are alerted the second it starts
RegisterNetEvent('pup-gangs:startRaid', function(denId)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return end
    local t = dens[tonumber(denId) or -1]
    -- an unowned fixed den has no defender: the way in is its key
    if not t or not t.gangid or t.gangid == m.gangid then return end
    if denRaids[t.id] then return end
    if (m.rank or 1) < (tonumber(Config.Dens.raidMinRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end
    if (tonumber(t.stored) or 0) <= 0 then return notify(_source, Locale.denEmpty) end
    local cdUntil = (tonumber(t.last_raided) or 0) + (Config.Dens.raidCooldownMinutes * 60)
    if cdUntil > now() then return notify(_source, Locale.denRaidCooldown) end

    local ped = GetPlayerPed(_source)
    local c = ped and GetEntityCoords(ped)
    if not c or #(vector3(c.x, c.y, c.z) - vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0)) > 8.0 then return end

    local endts = now() + Config.Dens.raidHoldSeconds
    denRaids[t.id] = { src = _source, attacker = m.gangid, defender = t.gangid, endts = endts }
    GangLog(m.gangid, 'raid', 'raiding a rival den', m.name)
    GangLog(t.gangid, 'raid', 'den under raid!', '')
    TriggerClientEvent('pup-gangs:raidStarted', -1, {
        id = t.id, x = t.x, y = t.y, z = t.z, endts = endts,
        attacker = m.gangid, defender = t.gangid,
    })
    dbg('raid started', t.id, 'attacker', m.gangid, 'defender', t.gangid)
end)

-- brew tick: one package per brewMinutes, up to the shelf cap
CreateThread(function()
    while true do
        Wait(60000)
        if Config.Dens.enabled then
            local dirty = false
            for _, t in pairs(dens) do
                if not denRaids[t.id] and (tonumber(t.stored) or 0) < Config.Dens.maxStored then
                    if (now() - (tonumber(t.last_brew) or 0)) >= Config.Dens.brewMinutes * 60 then
                        t.stored = (tonumber(t.stored) or 0) + 1
                        t.last_brew = now()
                        DBExec('UPDATE gang_dens SET stored = ?, last_brew = ? WHERE id = ?',
                            { t.stored, t.last_brew, t.id })
                        dirty = true
                    end
                end
            end
            if dirty then broadcastDens() end
        end
    end
end)

-- raid tick: at the deadline the raider must still be holding the spot
CreateThread(function()
    while true do
        Wait(5000)
        local t0 = now()
        for thid, raid in pairs(denRaids) do
            if raid.endts <= t0 then
                denRaids[thid] = nil
                local t = dens[thid]
                if t then
                    local held = false
                    local ped = GetPlayerPed(raid.src)
                    if ped and ped > 0 then
                        local c = GetEntityCoords(ped)
                        held = #(vector3(c.x, c.y, c.z) - vector3(t.x + 0.0, t.y + 0.0, t.z + 0.0))
                            <= (Config.Dens.raidHoldRadius + 0.0)
                    end
                    t.last_raided = t0
                    if held then
                        -- stolen: shelf empties into the raider's satchel (what does not fit is lost in the scuffle)
                        local stolen = tonumber(t.stored) or 0
                        local item = Config.Missions.packageItem
                        for _ = 1, stolen do
                            local okc, can = pcall(function() return VorpInv:canCarryItem(raid.src, item, 1) end)
                            if okc and can then VorpInv:addItem(raid.src, item, 1) end
                        end
                        t.stored = 0
                        DBExec('UPDATE gang_dens SET stored = 0, last_raided = ? WHERE id = ?', { t0, thid })
                        GangAward(raid.src, 'war', Config.Dens.raidAttackerPoints, 'raided a den')
                        -- a FIXED den changes hands when it is taken; a player den stays theirs (it is inside their own house)
                        if t.admin then
                            t.cook_until = 0
                            DBExec('UPDATE gang_dens SET cook_until = 0 WHERE id = ?', { thid })
                            giveDen(t, raid.attacker, 'took the den')
                        end
                        GangLog(raid.defender, 'raid', ('den raided - %d package(s) stolen'):format(stolen), '')
                        TriggerClientEvent('pup-gangs:raidEnded', -1, { id = thid, success = true, defender = raid.defender, attacker = raid.attacker })
                    else
                        DBExec('UPDATE gang_dens SET last_raided = ? WHERE id = ?', { t0, thid })
                        GangAwardGang(raid.defender, Config.Dens.raidDefenderPoints, 'beat off a den raid')
                        GangLog(raid.attacker, 'raid', 'den raid failed', '')
                        TriggerClientEvent('pup-gangs:raidEnded', -1, { id = thid, success = false, defender = raid.defender, attacker = raid.attacker })
                    end
                    broadcastDens()
                end
            end
        end
    end
end)

-- what each player may SEE: own gang = every den in full
VorpCore.Callback.Register('pup-gangs:getDens', function(source, cb)
    local ch = Char(source)
    if not ch then return cb(false) end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return cb(false) end

    local mine, rivals, fixed = {}, {}, {}
    for _, t in pairs(dens) do
        local cooking = (tonumber(t.cook_until) or 0) > now()
        if t.gangid == m.gangid then
            mine[#mine + 1] = {
                id = t.id, x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h) or 0.0,
                houseid = t.houseid, stored = tonumber(t.stored) or 0,
                raided = denRaids[t.id] ~= nil,
                admin = t.admin == true, label = denLabel(t),
                cooking = cooking, cookLeft = cooking and (t.cook_until - now()) or 0,
                canCook = Config.Dens.cook.enabled,
                -- which shack interior this den's door opens into (nil = crate only)
                site = denSite(t),
            }
        elseif t.admin then
            -- FIXED dens are invisible until this gang has FOUND them
            if hasFound(m.gangid, t.id) then
                local g = t.gangid and GangById(t.gangid) or nil
                fixed[#fixed + 1] = {
                    id = t.id, x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h) or 0.0,
                    label = denLabel(t),
                    holder = g and (g.shortname ~= '' and g.shortname or g.name) or nil,
                    unowned = t.gangid == nil,
                    contested = denSeizes[t.id] ~= nil,
                    cooking = cooking,
                    site = denSite(t),
                }
            end
        elseif (tonumber(t.stored) or 0) > 0 or cooking then
            -- a PLAYER den gives itself away while it is stocked or hot
            local g = GangById(t.gangid)
            rivals[#rivals + 1] = {
                id = t.id, x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h) or 0.0,
                gang = g and g.name or '?', short = g and g.shortname or '',
                raided = denRaids[t.id] ~= nil, cooking = cooking,
            }
        end
    end
    -- EVERY fixed den's crate is a real object in the world - that is how a gang stumbles on one in the first place
    local props = {}
    for _, t in pairs(dens) do
        if t.admin then
            props[#props + 1] = { id = t.id, x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z), h = tonumber(t.h) or 0.0,
                -- a den with a SHACK does not get a crate: the building is the landmark, and a crate sat in the doorway is just clutter
                site = denSite(t) }
        end
    end
    cb({ mine = mine, rivals = rivals, dens = fixed, props = props })
end)

-- FIXED DENS: finding them, taking them, and cooking in them
denLabel = function(t)
    if t.label and t.label ~= '' then return t.label end
    return t.admin and ('Den #' .. tostring(t.id)) or ('House #' .. tostring(t.houseid or 0))
end

hasFound = function(gangid, tid)
    return denFound[gangid] ~= nil and denFound[gangid][tid] == true
end

markFound = function(gangid, tid)
    denFound[gangid] = denFound[gangid] or {}
    if denFound[gangid][tid] then return false end
    denFound[gangid][tid] = true
    if Config.Dens.discovery.keepFound ~= false then
        DBInsert('INSERT IGNORE INTO gang_den_found (denid, gangid, ts) VALUES (?, ?, ?)',
            { tid, gangid, now() })
    end
    return true
end

-- the client reports proximity; the server decides whether that counts as a find
RegisterNetEvent('pup-gangs:denNearby', function(tid)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return end
    local t = dens[tonumber(tid) or -1]
    if not t or not t.admin then return end
    if hasFound(m.gangid, t.id) then return end

    -- re-check the distance here: the client only ever asks
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc then return end
    if #(vector3(pc.x, pc.y, pc.z) - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0))
        > (Config.Dens.discovery.discoverDistance + 5.0) then return end

    if markFound(m.gangid, t.id) then
        GangLog(m.gangid, 'den', ('found %s'):format(denLabel(t)), ch.firstname .. ' ' .. ch.lastname)
        notify(_source, ('You found a den - %s'):format(denLabel(t)), 7000)
        if Config.Dens.discovery.announceToGang then
            for _, sid in ipairs(GetPlayers()) do
                local s = tonumber(sid)
                local c2 = s and Char(s)
                local m2 = c2 and GangMemberOf(c2.charIdentifier)
                if m2 and m2.gangid == m.gangid and s ~= _source then
                    notify(s, ('Your crew found a den - %s'):format(denLabel(t)), 6000)
                end
            end
        end
        TriggerClientEvent('pup-gangs:densDirty', -1)
    end
end)

-- TURN THE KEY - the way a gang takes a den
RegisterNetEvent('pup-gangs:denUseKey', function(tid)
    local _source = source
    if not Config.Dens.enabled then return end
    local ch = Char(_source)
    if not ch then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end

    local t = dens[tonumber(tid) or -1]
    if not t or not t.admin then return dbg('denUseKey: no such fixed den', tid) end
    if t.gangid then
        dbg('denUseKey: already held by gang', t.gangid)
        return notify(_source, t.gangid == gang.id and Locale.denAlreadyYours or Locale.denHeld)
    end
    -- you cannot key a den your crew has not found: no discovery, no door
    if not hasFound(gang.id, t.id) then return dbg('denUseKey: gang', gang.id, 'has not found den', t.id) end

    -- every refusal below traces as well as notifies: the notify is for the player
    if (m.rank or 1) < (tonumber(Config.Dens.key.minRank) or 1) then
        dbg('denUseKey: RANK', m.rank or 1, '< required', Config.Dens.key.minRank)
        return notify(_source, Locale.notAllowed)
    end
    if Config.Dens.unlock and not GangHasPerk(gang, Config.Dens.unlock) then
        dbg('denUseKey: PERK missing -', Config.Dens.unlock, '- gang has', gang.points, 'points')
        return notify(_source, Locale.lockedPerk)
    end
    if denCount(gang.id) >= denLimitFor(gang) then
        dbg('denUseKey: LIMIT', denCount(gang.id), '>=', denLimitFor(gang))
        return notify(_source, Locale.denLimit)
    end

    -- distance re-check: the client only ever asks
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc then return end
    local away = #(vector3(pc.x, pc.y, pc.z) - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0))
    if away > (Config.Dens.doorDistance + 4.0) then
        dbg('denUseKey: TOO FAR', ('%.1fm'):format(away), '>', Config.Dens.doorDistance + 4.0)
        return
    end

    -- getItemCount is (source, CALLBACK, itemName) - nil callback = sync return
    local have = tonumber(VorpInv:getItemCount(_source, nil, Config.Dens.keyItem)) or 0
    if have < 1 then
        dbg('denUseKey: NO KEY - item', Config.Dens.keyItem, 'count', have)
        return notify(_source, Locale.denNoKey)
    end

    if Config.Dens.key.consume ~= false then
        VorpInv:subItem(_source, Config.Dens.keyItem, 1)
    end

    t.gangid = gang.id
    t.last_seized = now()
    DBExec('UPDATE gang_dens SET gangid = ?, last_seized = ? WHERE id = ?', { gang.id, t.last_seized, t.id })
    local pts <const> = tonumber(Config.Dens.key.points) or 0
    GangLog(gang.id, 'den', ('opened %s with a key'):format(denLabel(t)),
        ch.firstname .. ' ' .. ch.lastname, pts)
    if pts > 0 then GangAwardGang(gang.id, pts, 'den opened - ' .. denLabel(t)) end
    notify(_source, Locale.denOpened, 7000)

    if Config.Dens.key.announce then
        for _, sid in ipairs(GetPlayers()) do
            local s = tonumber(sid)
            local c2 = s and Char(s)
            local m2 = c2 and GangMemberOf(c2.charIdentifier)
            if m2 and m2.gangid == gang.id and s ~= _source then
                notify(s, ('Your crew has taken %s'):format(denLabel(t)), 6000)
            end
        end
    end
    broadcastDens()
end)

-- SEIZE an unowned fixed den: hold the ground, same shape as a territory claim
RegisterNetEvent('pup-gangs:seizeDen', function(tid)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Dens.seize.enabled then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return notify(_source, Locale.noGang) end
    local gang = GangById(m.gangid)
    if not gang then return end
    local t = dens[tonumber(tid) or -1]
    if not t or not t.admin then return end
    if t.gangid then return notify(_source, Locale.denHeld) end
    if denSeizes[t.id] then return notify(_source, Locale.denBusy) end
    if (m.rank or 1) < (tonumber(Config.Dens.seize.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end
    if Config.Dens.unlock and not GangHasPerk(gang, Config.Dens.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if denCount(gang.id) >= denLimitFor(gang) then return notify(_source, Locale.denLimit) end
    local cd = (tonumber(t.last_seized) or 0) + (Config.Dens.seize.cooldownMinutes * 60)
    if cd > now() then return notify(_source, Locale.denCooldown) end

    local endts = now() + Config.Dens.seize.holdSeconds
    denSeizes[t.id] = { gangid = gang.id, endts = endts, empty = 0 }
    GangLog(gang.id, 'den', ('moving on %s'):format(denLabel(t)), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, Locale.denSeizing, 8000)

    -- every gang that KNOWS this den is told it is being taken
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        local c2 = s and Char(s)
        local m2 = c2 and GangMemberOf(c2.charIdentifier)
        if m2 and (m2.gangid == gang.id or (Config.Dens.seize.alertRivals and hasFound(m2.gangid, t.id))) then
            TriggerClientEvent('pup-gangs:denSeizeStarted', s, {
                id = t.id, name = denLabel(t), x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z),
                gangid = gang.id, mine = m2.gangid == gang.id,
                secondsLeft = Config.Dens.seize.holdSeconds,
                radius = Config.Dens.seize.holdRadius,
            })
        end
    end
end)

-- living members of `gangid` standing on this den
local function seizersPresent(gangid, t, radius)
    local n = 0
    for _, sid in ipairs(GetPlayers()) do
        local src = tonumber(sid)
        local c2 = src and Char(src)
        local m2 = c2 and GangMemberOf(c2.charIdentifier)
        if m2 and m2.gangid == gangid and not c2.isdead then
            local ped = GetPlayerPed(src)
            if ped and ped > 0 then
                local pc = GetEntityCoords(ped)
                if #(vector3(pc.x, pc.y, pc.z) - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0)) <= radius then
                    n = n + 1
                end
            end
        end
    end
    return n
end

giveDen = function(t, gangid, reason)
    t.gangid = gangid
    t.last_seized = now()
    DBExec('UPDATE gang_dens SET gangid = ?, last_seized = ? WHERE id = ?', { gangid, t.last_seized, t.id })
    markFound(gangid, t.id)
    GangLog(gangid, 'den', ('%s - %s'):format(reason, denLabel(t)), '', Config.Dens.seize.points)
    GangAwardGang(gangid, Config.Dens.seize.points, reason .. ' ' .. denLabel(t))
    TriggerClientEvent('pup-gangs:densDirty', -1)
end

-- seize + cook tick
CreateThread(function()
    while true do
        Wait((Config.Dens.seize.tickSeconds or 10) * 1000)
        local t0 = now()

        for tid, s in pairs(denSeizes) do
            local t = dens[tid]
            if not t then
                denSeizes[tid] = nil
            else
                local radius = Config.Dens.seize.holdRadius
                if seizersPresent(s.gangid, t, radius) > 0 then
                    s.empty = 0
                else
                    s.empty = (s.empty or 0) + 1
                    if s.empty >= (Config.Dens.seize.presenceTicks or 3) then
                        denSeizes[tid] = nil
                        t.last_seized = t0
                        DBExec('UPDATE gang_dens SET last_seized = ? WHERE id = ?', { t0, tid })
                        GangLog(s.gangid, 'den', ('lost the seize on %s'):format(denLabel(t)), '', 0)
                        TriggerClientEvent('pup-gangs:denSeizeEnded', -1, { id = tid, won = false })
                    end
                end
                if denSeizes[tid] and s.endts <= t0 then
                    denSeizes[tid] = nil
                    giveDen(t, s.gangid, 'seized')
                    TriggerClientEvent('pup-gangs:denSeizeEnded', -1, { id = tid, won = true, gangid = s.gangid })
                end
            end
        end

        -- COOK: a batch that has run its time pays out
        for tid, t in pairs(dens) do
            if (tonumber(t.cook_until) or 0) > 0 and t.cook_until <= t0 and t.gangid then
                t.cook_until = 0
                t.last_cook = t0
                local pr = Config.Dens.cook.product
                local yield = tonumber(pr.count) or 1
                -- Bulk Cooking (Syndicate perk): every batch comes out bigger
                local og = GangById(t.gangid)
                if og and GangHasPerk(og, 'bulk_cook') then
                    yield = yield + (tonumber(Config.Dens.cook.bulkPerkBonus) or 1)
                end
                t.stored = math.min(Config.Dens.maxStored, (tonumber(t.stored) or 0) + yield)
                DBExec('UPDATE gang_dens SET cook_until = 0, last_cook = ?, stored = ? WHERE id = ?',
                    { t0, t.stored, tid })
                GangAwardGang(t.gangid, Config.Dens.cook.points, 'finished a batch')
                GangLog(t.gangid, 'den', ('a batch finished at %s'):format(denLabel(t)), '', Config.Dens.cook.points)
                TriggerClientEvent('pup-gangs:denCookEnded', -1, { id = tid, gangid = t.gangid })
                TriggerClientEvent('pup-gangs:densDirty', -1)
            end
        end
    end
end)

-- START A COOK at your own den
RegisterNetEvent('pup-gangs:startCook', function(tid)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Dens.cook.enabled then return end
    local charid = ch.charIdentifier
    local m = GangMemberOf(charid)
    if not m then return end
    local t = dens[tonumber(tid) or -1]
    if not t or t.gangid ~= m.gangid then return end
    if (m.rank or 1) < (tonumber(Config.Dens.cook.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end
    if (tonumber(t.cook_until) or 0) > now() then return notify(_source, Locale.cookBusy) end
    local cd = (tonumber(t.last_cook) or 0) + (Config.Dens.cook.cooldownMinutes * 60)
    if cd > now() then return notify(_source, Locale.cookCooldown) end

    -- ingredients come out of the cook's own satchel
    for _, ing in ipairs(Config.Dens.cook.ingredients or {}) do
        local have = tonumber(VorpInv:getItemCount(_source, nil, ing.item)) or 0
        if have < (tonumber(ing.count) or 1) then
            return notify(_source, ('You need %dx %s.'):format(ing.count or 1, ing.item), 6000)
        end
    end
    for _, ing in ipairs(Config.Dens.cook.ingredients or {}) do
        VorpInv:subItem(_source, ing.item, tonumber(ing.count) or 1)
    end

    t.cook_until = now() + (Config.Dens.cook.cookMinutes * 60)
    DBExec('UPDATE gang_dens SET cook_until = ? WHERE id = ?', { t.cook_until, t.id })
    GangLog(m.gangid, 'den', ('started a cook at %s'):format(denLabel(t)), ch.firstname .. ' ' .. ch.lastname)
    notify(_source, Locale.cookStarted, 8000)

    if Config.Dens.cook.goesHot then
        -- HOT: the den is revealed while it runs - that is the price of cooking
        TriggerClientEvent('pup-gangs:denCookStarted', -1, {
            id = t.id, name = denLabel(t),
            x = tonumber(t.x), y = tonumber(t.y), z = tonumber(t.z),
            gangid = t.gangid, radius = Config.Dens.cook.hotRadius,
            secondsLeft = Config.Dens.cook.cookMinutes * 60,
        })
    end
    TriggerClientEvent('pup-gangs:densDirty', -1)
end)

-- THE POWDER BENCH - gang-only explosives, hidden inside a den
local benchItemOk = {}     -- [itemName] = true/false

local function auditBenchItems()
    local want = {}
    for _, r in ipairs((Config.Dens.bench or {}).recipes or {}) do
        if r.give and r.give.item then want[r.give.item] = true end
        for _, c in ipairs(r.costs or {}) do if c.item then want[c.item] = true end end
    end
    if Config.Missions and Config.Missions.packageItem then want[Config.Missions.packageItem] = true end
    -- the fort raid's strongbox too: a loot entry naming a nonexistent item fails silently at the worst possible moment
    for _, e in ipairs(((Config.FortRaid or {}).loot or {}).table or {}) do
        if e.item then want[e.item] = true end
    end
    for _, rw in pairs(Config.Rewards or {}) do
        for _, e in ipairs(rw.items or {}) do if e.item then want[e.item] = true end end
    end

    local missing = {}
    for item in pairs(want) do
        local row = DBQuery('SELECT item FROM items WHERE item = ?', { item })
        benchItemOk[item] = (row and row[1]) and true or false
        if not benchItemOk[item] then missing[#missing + 1] = item end
    end
    if #missing > 0 then
        table.sort(missing)
        print(('^3[pup-gangs]^7 bench recipes name %d item(s) that are NOT in the items table: ^1%s^7')
            :format(#missing, table.concat(missing, ', ')))
        print('^3[pup-gangs]^7 those recipes cannot be crafted until the rows exist - see bench_items.sql')
    end
end

--- Count an item, without asking about ones we know are not there.
local function benchCount(src, item)
    if benchItemOk[item] == false then return 0 end
    return tonumber(VorpInv:getItemCount(src, nil, item)) or 0
end

-- run the audit here, below the `local function`s it calls
CreateThread(function()
    Wait(6000)
    auditBenchItems()
end)

-- DEN BRIDGE for server/fortraid.lua (loaded after this file, so these are visible to it)

--- Every den a gang holds. Empty table when they hold none.
function GangDensOf(gangid)
    local out = {}
    for _, t in pairs(dens) do
        if t.gangid == gangid then out[#out + 1] = t end
    end
    return out
end

-- The container id of a gang's Den Inventory, registering it if needed; nil when it is not available
function GangDenStashId(gang)
    if not gang then return nil end
    for i, s in ipairs(Config.Stashes.list or {}) do
        if s.key == 'den' then return registerStash(gang, s, i) end
    end
    return nil
end

local benchCooldown = {}   -- [denId] = ts
-- [denId] = { gangid, index, name, item, count, endts, charid }
-- A batch in progress. One per den; epoch-timed so a restart cannot lose it.
local benchJobs = {}

VorpCore.Callback.Register('pup-gangs:getBench', function(source, cb)
    local ch = Char(source)
    if not ch then return cb(false) end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return cb(false) end
    local gang = GangById(m.gangid)
    if not gang or not Config.Dens.bench.enabled then return cb(false) end
    if not GangHasPerk(gang, Config.Dens.bench.unlock) then return cb(false) end

    -- what they can make, and whether they are holding the makings right now
    local out = {}
    for i, r in ipairs(Config.Dens.bench.recipes or {}) do
        local costs, canMake = {}, true
        for _, c in ipairs(r.costs or {}) do
            local have = tonumber(VorpInv:getItemCount(source, nil, c.item)) or 0
            costs[#costs + 1] = { item = c.item, count = c.count, have = have }
            if have < (tonumber(c.count) or 1) then canMake = false end
        end
        out[#out + 1] = {
            index = i, name = r.name,
            gives = r.give, costs = costs, canMake = canMake,
        }
    end
    cb({ recipes = out, rank = m.rank, minRank = Config.Dens.bench.minRank })
end)

-- THE DEN PANEL - everything the shack's own interface needs, in one call
VorpCore.Callback.Register('pup-gangs:getDenPanel', function(source, cb, denId)
    local ch = Char(source)
    if not ch then return cb(false) end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return cb(false) end
    local gang = GangById(m.gangid)
    if not gang then return cb(false) end

    local t = dens[tonumber(denId) or -1]
    if not t or t.gangid ~= gang.id then return cb(false) end

    local t0 <const> = now()
    local cooking <const> = (tonumber(t.cook_until) or 0) > t0
    local cookCd <const> = math.max(0, ((tonumber(t.last_cook) or 0) + (Config.Dens.cook.cooldownMinutes * 60)) - t0)

    -- BENCH. cb(false) from getBench means "no perk"; here it is a flag instead
    local benchOn <const> = Config.Dens.bench.enabled
        and GangHasPerk(gang, Config.Dens.bench.unlock)
    local recipes = {}
    if benchOn then
        for i, r in ipairs(Config.Dens.bench.recipes or {}) do
            local costs, broken = {}, nil
            -- a recipe naming an item that does not exist is BROKEN, not "short": no amount of playing will ever satisfy it
            if benchItemOk[r.give and r.give.item] == false then broken = r.give.item end
            for _, c in ipairs(r.costs or {}) do
                if benchItemOk[c.item] == false then broken = broken or c.item end
                costs[#costs + 1] = {
                    item = c.item, count = c.count,
                    have = benchCount(source, c.item),
                }
            end
            local ok = not broken
            for _, c in ipairs(costs) do if c.have < (tonumber(c.count) or 1) then ok = false end end
            recipes[#recipes + 1] = {
                index = i, name = r.name,
                give = { item = r.give.item, count = r.give.count or 1 },
                costs = costs, canMake = ok, broken = broken,
                minutes = tonumber(r.minutes) or tonumber(Config.Dens.bench.craftMinutes) or 8,
            }
        end
    end

    -- RAID TARGETS: rival dens that have given themselves away by being stocked or hot
    local targets = {}
    for _, o in pairs(dens) do
        if o.gangid and o.gangid ~= gang.id then
            local hot = (tonumber(o.cook_until) or 0) > t0
            if (tonumber(o.stored) or 0) > 0 or hot then
                local g = GangById(o.gangid)
                targets[#targets + 1] = {
                    id = o.id,
                    gang = g and (g.shortname ~= '' and g.shortname or g.name) or '?',
                    hot = hot,
                    beingRaided = denRaids[o.id] ~= nil,
                    x = tonumber(o.x), y = tonumber(o.y), z = tonumber(o.z),
                }
            end
        end
    end

    cb({
        id       = t.id,
        label    = denLabel(t),
        site     = denSite(t),
        rank     = m.rank or 1,
        gangTag  = gang.shortname ~= '' and gang.shortname or gang.name,
        shelf    = tonumber(t.stored) or 0,
        maxStored = tonumber(Config.Dens.maxStored) or 3,
        collectRank = tonumber(Config.Dens.minRank) or 1,
        cook = {
            enabled   = Config.Dens.cook.enabled,
            minRank   = tonumber(Config.Dens.cook.minRank) or 1,
            cooking   = cooking,
            leftSecs  = cooking and (t.cook_until - t0) or 0,
            cooldown  = cookCd,
            minutes   = Config.Dens.cook.cookMinutes,
            ingredients = Config.Dens.cook.ingredients,
            product   = Config.Dens.cook.product,
            bulk      = GangHasPerk(gang, 'bulk_cook'),
        },
        bench = {
            enabled = Config.Dens.bench.enabled,
            unlocked = benchOn,
            unlockLabel = (Config.Perks.labels or {})[Config.Dens.bench.unlock] or Config.Dens.bench.unlock,
            minRank = tonumber(Config.Dens.bench.minRank) or 1,
            recipes = recipes,
            -- what is ON the bench right now, if anything
            job = benchJobs[t.id] and {
                index    = benchJobs[t.id].index,
                name     = benchJobs[t.id].name,
                count    = benchJobs[t.id].count,
                item     = benchJobs[t.id].item,
                leftSecs = math.max(0, (benchJobs[t.id].endts or 0) - t0),
            } or nil,
        },
        raid = {
            minRank = tonumber(Config.Dens.raidMinRank) or 1,
            targets = targets,
        },
        -- the plant run: what it needs and whether this player has it
        run = {
            enabled  = Config.Missions.enabled,
            minRank  = tonumber(Config.Missions.minRank) or 1,
            minPosse = tonumber(Config.Missions.minPosse) or 1,
            posse    = (function()
                local ok, riders = pcall(function() return exports['pup-ui']:GetPosseMembers(source) end)
                return (ok and type(riders) == 'table') and #riders or 0
            end)(),
            have     = tonumber(VorpInv:getItemCount(source, nil, Config.Missions.packageItem)) or 0,
            item     = Config.Missions.packageItem,
            defendSeconds = tonumber(Config.Missions.defendSeconds) or 900,
        },
        beingRaided = denRaids[t.id] ~= nil,
    })
end)

RegisterNetEvent('pup-gangs:benchCraft', function(tid, index)
    local _source = source
    local ch = Char(_source)
    if not ch then return end
    if not Config.Dens.bench.enabled then return end
    local m = GangMemberOf(ch.charIdentifier)
    if not m then return end
    local gang = GangById(m.gangid)
    if not gang then return end
    local t = dens[tonumber(tid) or -1]
    if not t or t.gangid ~= m.gangid then return end
    if not GangHasPerk(gang, Config.Dens.bench.unlock) then
        return notify(_source, Locale.lockedPerk)
    end
    if (m.rank or 1) < (tonumber(Config.Dens.bench.minRank) or 1) then
        return notify(_source, Locale.notAllowed)
    end
    local cd = (benchCooldown[t.id] or 0) + (Config.Dens.bench.cooldownSeconds or 30)
    if cd > now() then return notify(_source, Locale.benchBusy) end

    local r = (Config.Dens.bench.recipes or {})[tonumber(index) or -1]
    if not r then return end

    -- ONE JOB PER DEN. The bench is a thing in a room, not a queue.
    if benchJobs[t.id] then return notify(_source, Locale.benchWorking) end

    -- on-site check
    local ped = GetPlayerPed(_source)
    local pc = ped and ped > 0 and GetEntityCoords(ped) or nil
    if not pc then return end
    local here = vector3(pc.x, pc.y, pc.z)
    local near = #(here - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0)) <= 5.0
    if not near then
        local site = (Config.Dens.sites or {})[denSite(t) or '']
        for _, k in ipairs({ 'bench', 'menu', 'inside' }) do
            local s = site and site[k]
            if s and #(here - vector3(tonumber(s.x) + 0.0, tonumber(s.y) + 0.0, tonumber(s.z) + 0.0)) <= 8.0 then
                near = true break
            end
        end
    end
    if not near then return end

    -- refuse a recipe whose items were never added, and NAME the item: this is a config fault
    if benchItemOk[r.give and r.give.item] == false then
        return notify(_source, (Locale.benchBadItem):format(r.give.item), 8000)
    end
    for _, c in ipairs(r.costs or {}) do
        if benchItemOk[c.item] == false then
            return notify(_source, (Locale.benchBadItem):format(c.item), 8000)
        end
        local have = benchCount(_source, c.item)
        if have < (tonumber(c.count) or 1) then
            return notify(_source, ('You need %dx %s.'):format(c.count or 1, c.item), 6000)
        end
    end

    -- no canCarryItem check: the goods go to the den, not the satchel
    for _, c in ipairs(r.costs or {}) do VorpInv:subItem(_source, c.item, tonumber(c.count) or 1) end

    local mins <const> = tonumber(r.minutes) or tonumber(Config.Dens.bench.craftMinutes) or 8
    benchJobs[t.id] = {
        gangid = m.gangid,
        index  = tonumber(index),
        name   = r.name,
        item   = r.give.item,
        count  = tonumber(r.give.count) or 1,
        endts  = now() + math.floor(mins * 60),
        charid = ch.charIdentifier,
    }
    GangLog(m.gangid, 'bench', ('put %dx %s on the bench'):format(r.give.count or 1, r.name),
        ch.firstname .. ' ' .. ch.lastname)
    notify(_source, (Locale.benchStarted):format(r.name, mins), 7000)
    dbg('bench job started at den', t.id, r.name, mins .. 'm')
end)

-- THE BENCH TICK - finish whatever is on it
CreateThread(function()
    while true do
        Wait(10000)
        if Config.Dens.bench.enabled then
            local t0 = now()
            for denId, job in pairs(benchJobs) do
                if t0 >= (job.endts or 0) then
                    benchJobs[denId] = nil
                    benchCooldown[denId] = t0

                    local gang = GangById(job.gangid)
                    local stash, index
                    for i, s in ipairs(Config.Stashes.list) do
                        if s.key == 'den' then stash, index = s, i break end
                    end

                    local delivered = false
                    if gang and stash then
                        local cid = registerStash(gang, stash, index)
                        if cid then
                            local ok = pcall(function()
                                exports.vorp_inventory:addItemsToCustomInventory(
                                    tostring(cid),
                                    { { name = job.item, amount = job.count } },
                                    job.charid)
                            end)
                            delivered = ok == true
                        end
                    end

                    if delivered then
                        GangLog(job.gangid, 'bench',
                            ('%dx %s came off the bench'):format(job.count, job.name), '')
                        for _, sid in ipairs(GetPlayers()) do
                            local s = tonumber(sid)
                            local c2 = s and Char(s)
                            local m2 = c2 and GangMemberOf(c2.charIdentifier)
                            if m2 and m2.gangid == job.gangid then
                                notify(s, (Locale.benchDone):format(job.count, job.name), 6000)
                            end
                        end
                        dbg('bench job done at den', denId, job.name)
                    else
                        -- the inventory refused it (full, or not registered)
                        print(('^1[pup-gangs]^7 bench job at den %s could not deliver %dx %s')
                            :format(tostring(denId), job.count, tostring(job.item)))
                        local src = charSource(job.charid)
                        if src then notify(src, Locale.benchNoRoom, 8000) end
                    end
                end
            end
        end
    end
end)

-- ADMIN: place and remove fixed dens in the world
RegisterCommand('gangden', function(src, args)
    if src ~= 0 then
        local u = VorpCore.getUser(src)
        if not u or u.getGroup ~= 'admin' then return end
    end
    local sub = tostring(args[1] or ''):lower()

    if sub == 'add' and src ~= 0 then
        local label = table.concat(args, ' ', 2)
        if label == '' then label = 'Den' end
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        local id = DBInsert([[INSERT INTO gang_dens
            (gangid, houseid, x, y, z, h, stored, last_brew, last_raided, created_at, admin, label)
            VALUES (NULL, NULL, ?, ?, ?, ?, 0, ?, 0, ?, 1, ?)]],
            { c.x, c.y, c.z - 0.95, GetEntityHeading(ped), now(), now(), label })
        if not id then return end
        dens[id] = { id = id, gangid = nil, houseid = nil, x = c.x, y = c.y, z = c.z - 0.95,
                           h = GetEntityHeading(ped), stored = 0, admin = true, label = label, cook_until = 0 }
        notify(src, ('Den "%s" placed. Gangs must find it.'):format(label), 6000)
        print(('^2[pup-gangs]^7 den "%s" added at %.2f, %.2f, %.2f'):format(label, c.x, c.y, c.z - 0.95))
        TriggerClientEvent('pup-gangs:densDirty', -1)

    elseif sub == 'remove' and src ~= 0 then
        local ped = GetPlayerPed(src)
        local c = GetEntityCoords(ped)
        local best, bestD
        for id, t in pairs(dens) do
            if t.admin then
                local d = #(vector3(c.x, c.y, c.z) - vector3(tonumber(t.x) + 0.0, tonumber(t.y) + 0.0, tonumber(t.z) + 0.0))
                if not bestD or d < bestD then best, bestD = id, d end
            end
        end
        if not best or bestD > 25.0 then return notify(src, 'No fixed den within 25m.') end
        local label = denLabel(dens[best])
        DBExec('DELETE FROM gang_dens WHERE id = ?', { best })
        DBExec('DELETE FROM gang_den_found WHERE denid = ?', { best })
        dens[best] = nil
        denSeizes[best] = nil
        for _, g in pairs(denFound) do g[best] = nil end
        notify(src, ('Den "%s" removed.'):format(label), 6000)
        TriggerClientEvent('pup-gangs:densDirty', -1)

    else
        print('^3[pup-gangs]^7 fixed dens:')
        for id, t in pairs(dens) do
            if t.admin then
                local holder = t.gangid and GangById(t.gangid)
                print(('  #%d  %-24s %.2f, %.2f, %.2f   %s'):format(
                    id, denLabel(t), tonumber(t.x), tonumber(t.y), tonumber(t.z),
                    holder and ('held by ' .. holder.name) or 'unowned'))
            end
        end
        print('  usage: /gangden add <label> | /gangden remove | /gangden list')
    end
end, false)

-- VORP_ADMIN PANEL BRIDGE (Gangs page)
exports('adminGangList', function()
    local list = {}
    local weekly = GangWeeklyEarned and GangWeeklyEarned() or {}
    for _, g in pairs(GangAll()) do
        local tier = GangLevel(g.points)
        local faction = Config.Factions.list[g.faction]

        local roster = {}
        for _, row in ipairs(DBQuery('SELECT charid, name, rank, points FROM gang_members WHERE gangid = ? ORDER BY rank DESC', { g.id }) or {}) do
            local r = Config.Ranks.list[math.min(#Config.Ranks.list, math.max(1, tonumber(row.rank) or 1))]
            roster[#roster + 1] = {
                charid = tonumber(row.charid), name = row.name,
                rank = tonumber(row.rank) or 1, rankLabel = r and r.label or '?',
                points = tonumber(row.points) or 0,
                isLeader = tonumber(row.charid) == tonumber(g.leader),
            }
        end

        local terr = {}
        for _, t in pairs(GangAllTerritories()) do
            if t.gangid == g.id then terr[#terr + 1] = { id = t.id, name = t.name } end
        end

        -- wars this gang is in, with the scoreline from ITS side
        local gwars = {}
        for _, w in pairs(GangAllWars()) do
            if w.gang_a == g.id or w.gang_b == g.id then
                local otherId = (w.gang_a == g.id) and w.gang_b or w.gang_a
                local other = GangById(otherId)
                gwars[#gwars + 1] = {
                    id = w.id,
                    enemy = other and other.name or ('gang ' .. tostring(otherId)),
                    mine = (w.gang_a == g.id) and w.score_a or w.score_b,
                    theirs = (w.gang_a == g.id) and w.score_b or w.score_a,
                    endsIn = math.max(0, (tonumber(w.endts) or 0) - now()),
                }
            end
        end

        -- live plants, either direction
        local gplants = {}
        for _, p in pairs(plants) do
            if p.status == 'active' and (p.attacker == g.id or p.defender == g.id) then
                gplants[#gplants + 1] = {
                    id = p.id,
                    attacking = (p.attacker == g.id),
                    other = GangById(p.attacker == g.id and p.defender or p.attacker),
                    endsIn = math.max(0, (tonumber(p.endts) or 0) - now()),
                }
            end
        end

        -- level progress, so the panel can show 750/1500 rather than a bare number
        local nextTier = GangNextLevel(g.points)
        local prevAt = tier.points or 0
        local nextAt = nextTier and nextTier.points or nil

        local t = GANG_TABLES[g.id]

        local denRows = {}
        for _, th in pairs(dens) do
            if th.gangid == g.id then
                denRows[#denRows + 1] = {
                    id = th.id, houseid = th.houseid,
                    stored = tonumber(th.stored) or 0,
                    underRaid = denRaids[th.id] ~= nil,
                }
            end
        end

        local weekEarned = weekly[g.id] or 0
        list[#list + 1] = {
            id = g.id, name = g.name, motd = g.motd or '',
            shortname = g.shortname or '',
            faction = g.faction, factionLabel = faction and faction.label or g.faction,
            factionColor = faction and faction.colorModifier or nil,
            points = g.points, level = tier.level, levelLabel = tier.label,
            levelFrom = prevAt, levelNextAt = nextAt,
            levelNextLabel = nextTier and nextTier.label or nil,
            perks = tier.perks,
            radius = GangRadius(g.points),
            money = tonumber(g.money) or 0,
            createdAt = tonumber(g.created_at) or 0,
            lastActivity = tonumber(g.last_activity) or 0,
            earnedWeek = weekEarned,
            activityScore = GangActivityLabel and GangActivityLabel(weekEarned) or '?',
            stats = GangStatsOf and GangStatsOf(g) or {},
            hasTable = t ~= nil,
            tableHouse = t and t.houseid or nil,
            dens = denRows,
            members = roster, territories = terr,
            wars = gwars, plants = gplants,
            activity = DBQuery('SELECT ts, type, detail, actor, pts FROM gang_activity WHERE gangid = ? ORDER BY id DESC LIMIT 15', { g.id }) or {},
        }
    end
    table.sort(list, function(a, b) return (a.points or 0) > (b.points or 0) end)

    local activeWars, activePlants = 0, 0
    for _ in pairs(GangAllWars()) do activeWars = activeWars + 1 end
    for _, p in pairs(plants) do if p.status == 'active' then activePlants = activePlants + 1 end end

    return {
        list = list, wars = activeWars, plants = activePlants,
        factions = GangFactionStandings(), -- the three-way leaderboard
        now = now(),
    }
end)

exports('adminAdjustPoints', function(gangid, delta)
    local g = GangById(gangid)
    local d = tonumber(delta)
    if not g or not d or d == 0 then return { ok = false, err = 'bad values' } end
    g.points = math.max(0, (g.points or 0) + d)
    g.last_activity = now()
    DBExec('UPDATE gangs SET points = ?, last_activity = ? WHERE id = ?', { g.points, g.last_activity, g.id })
    GangLog(g.id, 'admin', ('points adjusted by %+d -> %d'):format(d, g.points), 'admin', d)
    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    return { ok = true, points = g.points }
end)

-- SEASON RESET - 'gangs', 'members', 'factions' or 'all'
exports('adminResetPoints', function(what)
    local scope = tostring(what or 'all')
    if scope ~= 'gangs' and scope ~= 'members' and scope ~= 'factions' and scope ~= 'all' then
        return { ok = false, err = 'bad scope' }
    end
    local res = GangResetPoints(scope)
    if type(res) ~= 'table' then return { ok = false, err = 'reset failed' } end
    res.ok = true
    res.scope = scope
    return res
end)

exports('adminDisbandGang', function(gangid)
    local g = GangById(gangid)
    if not g then return { ok = false, err = 'unknown gang' } end

    -- release everything the gang held, so nothing is orphaned: members, its table, its ground, and any running wars/plants
    DBExec('DELETE FROM gang_members WHERE gangid = ?', { g.id })
    DBExec('DELETE FROM gang_tables WHERE gangid = ?', { g.id })
    DBExec('DELETE FROM gang_dens WHERE gangid = ?', { g.id })
    DBExec('UPDATE gang_territories SET gangid = NULL WHERE gangid = ?', { g.id })
    DBExec("UPDATE gang_wars SET status = 'finished' WHERE (gang_a = ? OR gang_b = ?) AND status = 'active'", { g.id, g.id })
    DBExec("UPDATE gang_plants SET status = 'destroyed' WHERE (attacker = ? OR defender = ?) AND status = 'active'", { g.id, g.id })
    DBExec('DELETE FROM gangs WHERE id = ?', { g.id })

    GANG_TABLES[g.id] = nil
    for thid, th in pairs(dens) do
        if th.gangid == g.id then
            dens[thid] = nil
            denRaids[thid] = nil
            TriggerClientEvent('pup-gangs:raidEnded', -1, { id = thid, success = false })
        end
    end
    TriggerClientEvent('pup-gangs:densDirty', -1)
    for id, p in pairs(plants) do
        if p.attacker == g.id or p.defender == g.id then
            plants[id] = nil
            TriggerClientEvent('pup-gangs:plantEnded', -1, { id = id, destroyed = true })
        end
    end
    GangForget(g.id)

    TriggerClientEvent('pup-gangs:territoriesDirty', -1)
    TriggerClientEvent('pup-gangs:tablesDirty', -1)
    TriggerClientEvent('pup-gangs:refresh', -1)
    return { ok = true }
end)
