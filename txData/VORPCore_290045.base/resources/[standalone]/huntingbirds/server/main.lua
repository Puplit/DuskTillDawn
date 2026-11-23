-- huntingbirds | server core: characters, sessions, database, owned list, calling a bird out

Srv = {}

local RES <const> = GetCurrentResourceName()
local Core = exports.vorp_core:GetCore()

-- [src] = { key, activeBird, activeModel, trip, sellPoint }
Srv.sessions = {}
-- [identifier:charid] = GetGameTimer() of the last trip start; kept across reconnects until restart
Srv.cooldowns = {}
-- [birdId] = sell point (server/trade.lua)
Srv.points = {}

function Srv.dbg(fmt, ...)
    if not Config.Debug then return end
    print(('^5[%s]^7 ' .. fmt):format(RES, ...))
end

function Srv.char(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

function Srv.key(char)
    return ('%s:%s'):format(tostring(char.identifier), tostring(char.charIdentifier))
end

-- the session for this character; a different character on the same source starts fresh
function Srv.session(src, char)
    local key = Srv.key(char)
    local s = Srv.sessions[src]
    if not s or s.key ~= key then
        if s then Srv.endSession(src) end
        s = { key = key }
        Srv.sessions[src] = s
    end
    return s
end

-- [src] = { [action] = time }; kept apart from the session so the first request is counted too
Srv.stamps = {}

-- true when the action is allowed now (and records it); false when called again within ms
function Srv.throttle(src, name, ms)
    local stamps = Srv.stamps[src]
    if not stamps then
        stamps = {}
        Srv.stamps[src] = stamps
    end
    local now = GetGameTimer()
    if stamps[name] and now - stamps[name] < ms then return false end
    stamps[name] = now
    return true
end

function Srv.notify(src, text, tone)
    TriggerClientEvent('pup-ui:toast', src, { title = Locale.title, subtitle = text, tone = tone or 'gold', duration = 5000 })
end

function Srv.pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function Srv.near(src, point, maxDist)
    local c = Srv.pedCoords(src)
    if not c then return false end
    return #(c - point) <= maxDist
end

function Srv.hasJob(char, jobs)
    return type(jobs) == 'table' and Util.listHas(jobs, char.job)
end

function Srv.perkMult(src)
    if GetResourceState('pup-perks') ~= 'started' then return 1.0 end
    local ok, m = pcall(function() return exports['pup-perks']:Mult(src, 'bird_xp') end)
    m = ok and tonumber(m) or nil
    if not m or m ~= m or m <= 0 or m == math.huge then return 1.0 end
    return m
end

-------------------------------------------------------------------------------- database
function Srv.ownedRows(identifier, charid)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT `id`, `model`, `name`, `preset`, `xp`, `price` FROM `birds` WHERE `identifier` = ? AND `charid` = ?',
        { identifier, charid })
    if not ok then
        print(('^1[%s]^7 reading birds failed: %s'):format(RES, tostring(rows)))
        return false
    end
    return rows or {}
end

function Srv.ownedRow(char, birdId)
    local ok, rows = pcall(MySQL.query.await,
        'SELECT `id`, `model`, `name`, `preset`, `xp`, `price` FROM `birds` WHERE `id` = ? AND `identifier` = ? AND `charid` = ? LIMIT 1',
        { birdId, char.identifier, char.charIdentifier })
    if not ok or type(rows) ~= 'table' then return nil end
    return rows[1]
end

-- server-local event for other server scripts; never a network event
AddEventHandler('huntingbirds:getOwnedDB', function(identifier, charid, cb)
    if type(cb) ~= 'function' then return end
    cb(Srv.ownedRows(identifier, charid))
end)

function Srv.sellValue(price)
    local divisor = tonumber(Config.SellBack.divisor) or 3
    if divisor <= 0 then divisor = 3 end
    return Util.round2((tonumber(price) or 0) / divisor)
end

-------------------------------------------------------------------------------- session end
-- forget the bird, the trip and any sell point of this source
function Srv.endSession(src)
    local s = Srv.sessions[src]
    if s and s.sellPoint and Srv.removePoint then
        Srv.removePoint(s.sellPoint, true)
    end
    Srv.sessions[src] = nil
end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src then
        Srv.endSession(src)
        Srv.stamps[src] = nil
    end
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then Srv.endSession(src) end
end)

-------------------------------------------------------------------------------- owned list
RegisterNetEvent('huntingbirds:getOwnedBirds', function()
    local src = source
    local char = Srv.char(src)
    if not char then return end
    if not Srv.throttle(src, 'list', 500) then return end
    Srv.session(src, char)
    local rows = Srv.ownedRows(char.identifier, char.charIdentifier)
    local list = {}
    for _, r in ipairs(rows or {}) do
        list[#list + 1] = {
            id = r.id, name = r.name, model = Util.u32(r.model), preset = r.preset or 0,
            xp = r.xp or 0, sellValue = Srv.sellValue(r.price),
        }
    end
    TriggerClientEvent('huntingbirds:ownedbirds', src, list)
end)

-------------------------------------------------------------------------------- call out / home
RegisterNetEvent('huntingbirds:callbird', function(birdId)
    local src = source
    birdId = Util.int(birdId, 1)
    local char = Srv.char(src)
    if not birdId or not char then return end
    if not Srv.throttle(src, 'call', 1000) then return end
    local s = Srv.session(src, char)
    if s.activeBird or Srv.points[birdId] then
        Srv.notify(src, Locale.sendHomeFirst, 'red')
        return
    end
    local row = Srv.ownedRow(char, birdId)
    if not row then
        Srv.dbg('src=%d asked to call bird %d it does not own', src, birdId)
        return
    end
    s.activeBird, s.activeModel, s.trip = row.id, Util.u32(row.model), nil
    TriggerClientEvent('huntingbirds:spawnbird', src, {
        id = row.id, model = Util.u32(row.model), preset = row.preset or 0, name = row.name, xp = row.xp or 0,
    })
end)

RegisterNetEvent('huntingbirds:birdhome', function()
    local src = source
    local s = Srv.sessions[src]
    if not s then return end
    if s.sellPoint then Srv.removePoint(s.sellPoint, false) end
    s.activeBird, s.activeModel, s.trip = nil, nil, nil
end)

-------------------------------------------------------------------------------- command and item
if type(Config.General.callCommand) == 'string' and Config.General.callCommand ~= '' then
    RegisterCommand(Config.General.callCommand, function(src)
        if src and src > 0 then TriggerClientEvent('huntingbirds:callowneds', src) end
    end, false)
end

CreateThread(function()
    local item = Config.General.callItem
    if type(item) ~= 'string' or item == '' then return end
    local ok, err = pcall(function()
        exports.vorp_inventory:registerUsableItem(item, function(data)
            local src = data and data.source
            if not src then return end
            pcall(function() exports.vorp_inventory:closeInventory(src) end)
            TriggerClientEvent('huntingbirds:callowneds', src)
        end, RES)
    end)
    if not ok then print(('^1[%s]^7 could not register the %s item: %s'):format(RES, item, tostring(err))) end
end)

-------------------------------------------------------------------------------- config check
CreateThread(function()
    local function warn(msg) print(('^3[%s]^7 config: %s'):format(RES, msg)) end
    local maxXp = tonumber(Config.Progression.maxXp) or 0
    for ci, cat in ipairs(Config.BirdCatalog) do
        for vi, v in ipairs(cat.variants) do
            if not Config.BirdRoles[v.model] then
                warn(('catalog %d.%d (%s) model %s has no role: it brings nothing back'):format(ci, vi, v.name, v.modelName))
            end
            if not Config.ShoulderOffsets[v.model] then
                warn(('catalog %d.%d (%s) model %s has no shoulder offset: the hawk one is used'):format(ci, vi, v.name, v.modelName))
            end
            if v.startXp > maxXp then warn(('catalog %d.%d (%s) starts above maxXp'):format(ci, vi, v.name)) end
        end
    end
    for _, lvl in ipairs(Config.HuntZones.levels) do
        for _, z in pairs(lvl.byHash) do
            if z.prey and not Config.PreyLists[z.prey] then
                warn(('zone %s points at unknown prey list %s'):format(z.label, z.prey))
            end
        end
    end
    if not Config.HuntZones.fallback then warn('HuntZones.fallbackHash is not one of the districts') end
    for name, list in pairs(Config.PreyLists) do
        for i, e in ipairs(list) do
            if e.xpRequired > maxXp then warn(('prey list %s entry %d needs %d XP, above maxXp'):format(name, i, e.xpRequired)) end
        end
    end
    for i, e in ipairs(Config.ScavengeItems) do
        if e.xpRequired > maxXp then warn(('scavenge item %d (%s) needs %d XP, above maxXp: it never drops'):format(i, e.item, e.xpRequired)) end
    end
    for i, e in ipairs(Config.FishCatches) do
        if e.xpRequired > maxXp then warn(('fish %d (%s) needs %d XP, above maxXp'):format(i, e.modelName, e.xpRequired)) end
    end
end)
