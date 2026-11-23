-- pup-misc / outfitter - server half.
-- Owns the money, the limit and the world list. A placement is stored once and
-- broadcast to everyone, because a propset is not a networked entity: each
-- client builds its own copy from this list.

local Core = exports.vorp_core:GetCore()

-- [id] = { id, sku, owner, x, y, z, h }  everything standing in the world
local placed = {}

local function dbQuery(query, params)
    local p = promise.new()
    exports.oxmysql:execute(query, params or {}, function(result) p:resolve(result or {}) end)
    return Citizen.Await(p)
end

local function dbInsert(query, params)
    local p = promise.new()
    exports.oxmysql:insert(query, params or {}, function(id) p:resolve(id) end)
    return Citizen.Await(p)
end

local dbRun = dbQuery

-- oxmysql hands tinyint(1) back as a number on some builds and a boolean on
-- others, and tonumber(false) is nil, so neither form alone is safe to test
local function truthy(value)
    if type(value) == "boolean" then return value end
    local n = tonumber(value)
    if n ~= nil then return n ~= 0 end
    return value ~= nil
end

local function notify(src, message)
    Core.NotifyRightTip(src, message, 4000)
end

local function charOf(src)
    local user = Core.getUser(src)
    return user and user.getUsedCharacter or nil
end

local function dbg(fmt, ...)
    if not OutfitterConfig.General.debug then return end
    print(('^5[pup-misc/outfitter]^7 ' .. fmt):format(...))
end

CreateThread(function()
    Wait(1500)
    pcall(function()
        dbQuery([[CREATE TABLE IF NOT EXISTS `outfitter` (
                    `id` int(11) NOT NULL AUTO_INCREMENT,
                    `charidentifier` int(11) NOT NULL,
                    `sku` varchar(64) NOT NULL,
                    `placed` tinyint(1) NOT NULL DEFAULT 0,
                    `x` float DEFAULT NULL,
                    `y` float DEFAULT NULL,
                    `z` float DEFAULT NULL,
                    `h` float DEFAULT NULL,
                    PRIMARY KEY (`id`),
                    KEY `owner` (`charidentifier`),
                    KEY `standing` (`placed`)
                  )]], {})
    end)

    -- everything already pitched, so a restart puts the world back
    for _, r in ipairs(dbQuery("SELECT `id`, `charidentifier`, `sku`, `x`, `y`, `z`, `h` FROM `outfitter` WHERE `placed` = 1", {})) do
        if OutfitterIndex[r.sku] then
            placed[tonumber(r.id)] = {
                id = tonumber(r.id), sku = r.sku, owner = tonumber(r.charidentifier),
                x = tonumber(r.x) or 0.0, y = tonumber(r.y) or 0.0,
                z = tonumber(r.z) or 0.0, h = tonumber(r.h) or 0.0,
            }
        end
    end
    local n = 0
    for _ in pairs(placed) do n = n + 1 end
    dbg('%d pieces standing', n)
end)

-- keyed by id, so it is a map and not an array: # would read 0
-- what clients are told about a piece. The owner isn't part of it: it would locate one player's camps anywhere on the map.
local function forClients(v)
    return { id = v.id, sku = v.sku, x = v.x, y = v.y, z = v.z, h = v.h }
end

local function worldList()
    local out = {}
    for _, v in pairs(placed) do out[#out + 1] = forClients(v) end
    return out
end

-- what this character owns, placed or still in the wagon
local function ownedFor(charid)
    local rows = dbQuery("SELECT `id`, `sku`, `placed`, `x`, `y`, `z`, `h` FROM `outfitter` WHERE `charidentifier` = ?", { charid })
    local out = {}
    for _, r in ipairs(rows) do
        local def = OutfitterIndex[r.sku]
        if def then
            out[#out + 1] = {
                id = tonumber(r.id), sku = r.sku, label = def.label, kind = def.kind,
                placed = truthy(r.placed),
                x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), h = tonumber(r.h),
            }
        end
    end
    return out
end

local function pushOwned(src, charid)
    TriggerClientEvent('pup-misc:outfitter:owned', src, ownedFor(charid))
end

-- SELLING happens at a stable and nowhere else, so the buy event is checked
-- against the counters rather than taken on the client's word. Pitching is not
-- gated here: you open the kit at your wagon and then ride out to find a spot.
local stableSpots = nil

local function loadStableSpots()
    if stableSpots and #stableSpots > 0 then return stableSpots end
    stableSpots = {}
    local ok, cfg = pcall(function() return exports['pup-stable']:getConfig() end)
    if ok and type(cfg) == 'table' and type(cfg.Stables) == 'table' then
        for _, s in pairs(cfg.Stables) do
            local p = s.location
            -- read the components rather than the vector: a vector4 crossing a
            -- resource boundary can arrive as a plain table
            if p and p.x and p.y and p.z then
                stableSpots[#stableSpots + 1] = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
            end
        end
    end
    dbg('%d stable counters known', #stableSpots)
    return stableSpots
end

local function atAStable(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    local spots = loadStableSpots()
    -- pup-stable missing or its config unreadable: refuse rather than sell blind
    if #spots == 0 then
        dbg('no stable counters resolved, refusing the sale')
        return false
    end

    local coords = GetEntityCoords(ped)
    for _, p in ipairs(spots) do
        if #(coords - p) <= OutfitterConfig.Shop.stableDistance then return true end
    end
    return false
end

local lastRequest, placing = {}, {}
AddEventHandler('playerDropped', function() lastRequest[source] = nil end)

RegisterNetEvent('pup-misc:outfitter:request', function()
    local src = source
    local char = charOf(src)
    if not char then return end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 1000 then return end
    lastRequest[src] = now
    TriggerClientEvent('pup-misc:outfitter:world', src, worldList())
    pushOwned(src, char.charIdentifier)
end)

RegisterNetEvent('pup-misc:outfitter:buy', function(sku)
    local src = source
    if not OutfitterConfig.General.enabled then return end
    local char = charOf(src)
    if not char then return end

    local def = OutfitterIndex[tostring(sku or '')]
    if not def then return end

    if not atAStable(src) then
        return notify(src, OutfitterLocale.notAtCounter)
    end

    local price = tonumber(def.price) or 0
    local have = (OutfitterConfig.Shop.moneyType == 1) and char.gold or char.money
    if have < price then
        return notify(src, (OutfitterLocale.tooPoor):format(price))
    end
    char.removeCurrency(OutfitterConfig.Shop.moneyType or 0, price)

    local newId = dbInsert("INSERT INTO `outfitter` (`charidentifier`, `sku`, `placed`) VALUES (?, ?, 0)",
        { char.charIdentifier, def.sku })
    if not newId then
        char.addCurrency(OutfitterConfig.Shop.moneyType or 0, price)
        return
    end

    notify(src, (OutfitterLocale.bought):format(def.label))
    pushOwned(src, char.charIdentifier)
end)

local placePiece

RegisterNetEvent('pup-misc:outfitter:place', function(id, x, y, z, h)
    local src = source
    local char = charOf(src)
    if not char then return end
    id = tonumber(id)
    x, y, z, h = tonumber(x), tonumber(y), tonumber(z), tonumber(h)
    if not id or not x or not y or not z then return end
    if x ~= x or y ~= y or z ~= z or math.abs(x) == math.huge or math.abs(y) == math.huge or math.abs(z) == math.huge then return end
    h = (h and h == h and math.abs(h) ~= math.huge) and (h % 360.0) or 0.0
    if placing[id] then return end
    placing[id] = true
    local function done(...) placing[id] = nil return ... end
    return done(placePiece(src, char, id, x, y, z, h))
end)

placePiece = function(src, char, id, x, y, z, h)

    local rows = dbQuery("SELECT `sku`, `placed` FROM `outfitter` WHERE `id` = ? AND `charidentifier` = ?",
        { id, char.charIdentifier })
    local row = rows[1]
    if not row or truthy(row.placed) then return end
    if not OutfitterIndex[row.sku] then return end

    -- the client may only pitch near itself, whatever it claims
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    if #(GetEntityCoords(ped) - vector3(x, y, z)) > (OutfitterConfig.Placement.maxDistance + 6.0) then
        return notify(src, OutfitterLocale.tooFar)
    end
    -- not on a stable's counter. Same rule as the client.
    for _, p in ipairs(loadStableSpots()) do
        if #(vector3(x, y, z) - p) < 5.0 then return notify(src, OutfitterLocale.tooFar) end
    end

    local standing = 0
    for _, v in pairs(placed) do
        if v.owner == char.charIdentifier then standing = standing + 1 end
    end
    if standing >= (tonumber(OutfitterConfig.World.spawnLimit) or 10) then
        return notify(src, (OutfitterLocale.limit):format(standing))
    end

    -- counted before the database wait, so a burst can't all read the same number
    local entry = { id = id, sku = row.sku, owner = char.charIdentifier, x = x, y = y, z = z, h = h or 0.0 }
    placed[id] = entry
    dbRun("UPDATE `outfitter` SET `placed` = 1, `x` = ?, `y` = ?, `z` = ?, `h` = ? WHERE `id` = ?",
        { x, y, z, h or 0.0, id })
    TriggerClientEvent('pup-misc:outfitter:added', -1, forClients(entry))

    pushOwned(src, char.charIdentifier)
end

RegisterNetEvent('pup-misc:outfitter:pack', function(id)
    local src = source
    local char = charOf(src)
    if not char then return end
    id = tonumber(id)
    if not id then return end

    local entry = placed[id]
    if not entry or entry.owner ~= char.charIdentifier then return end

    dbRun("UPDATE `outfitter` SET `placed` = 0, `x` = NULL, `y` = NULL, `z` = NULL, `h` = NULL WHERE `id` = ? AND `charidentifier` = ?",
        { id, char.charIdentifier })

    placed[id] = nil
    TriggerClientEvent('pup-misc:outfitter:removed', -1, id)
    notify(src, OutfitterLocale.packed)
    pushOwned(src, char.charIdentifier)
end)

-- selling it back is the only way to be rid of a piece for good
RegisterNetEvent('pup-misc:outfitter:scrap', function(id)
    local src = source
    local char = charOf(src)
    if not char then return end
    id = tonumber(id)
    if not id then return end

    local rows = dbQuery("SELECT `sku`, `placed` FROM `outfitter` WHERE `id` = ? AND `charidentifier` = ?",
        { id, char.charIdentifier })
    local row = rows[1]
    if not row then return end
    if truthy(row.placed) then
        return notify(src, OutfitterLocale.packFirst)
    end

    dbRun("DELETE FROM `outfitter` WHERE `id` = ? AND `charidentifier` = ?", { id, char.charIdentifier })
    notify(src, OutfitterLocale.scrapped)
    pushOwned(src, char.charIdentifier)
end)
