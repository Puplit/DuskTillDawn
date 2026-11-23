-- boatshops | server helpers: characters, reach, jobs, locks, the boats table

BoatServer = {}
local S = BoatServer
local CFG <const> = BoatConfig

local Core = nil
local function core()
    if Core then return Core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and c then Core = c end
    return Core
end

function S.char(src)
    local c = core()
    if not c or not src then return nil end
    local ok, user = pcall(c.getUser, src)
    if not ok or not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' or not ch.charIdentifier then return nil end
    return ch
end

function S.tip(src, text, ms)
    if not text then return end
    local c = core()
    if c and c.NotifyRightTip then
        c.NotifyRightTip(src, text, ms or CFG.Timings.tipMs)
    else
        TriggerClientEvent('vorp:TipRight', src, text, ms or CFG.Timings.tipMs)
    end
end

function S.online(src)
    return src ~= nil and GetPlayerName(src) ~= nil
end

function S.pos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function dist(a, x, y, z)
    local dx, dy, dz = a.x - x, a.y - y, a.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
S.dist = dist

-- within the shop's open radius plus the extra reach of its counter
function S.nearShop(src, shop)
    local p = S.pos(src)
    if not p or not shop then return false end
    local c = shop.counter
    return dist(p, c.x, c.y, c.z) <= (tonumber(shop.openRadius) or 3.0) + (tonumber(CFG.Reach.extraMeters) or 10.0)
end

-- the shop's job lock and minimum grade
function S.jobOk(ch, shop)
    local jobs = shop and shop.jobs
    if type(jobs) ~= 'table' or #jobs == 0 then return true end
    if not Boat.inList(jobs, ch.job) then return false end
    local min = tonumber(shop.minGrade)
    if min and (tonumber(ch.jobGrade) or 0) < min then return false end
    return true
end

-- the game hour, from weathersync (the server has no clock of its own); nil when unknown
function S.gameHour()
    if GetResourceState('weathersync') ~= 'started' then return nil end
    local ok, t = pcall(function() return exports.weathersync:getTime() end)
    if not ok or type(t) ~= 'table' then return nil end
    return tonumber(t.hour)
end

-- the shop's hours, as the client checks them; with no known hour it stays open
function S.closed(shop)
    local h = shop and shop.hours
    if not h or not h.enabled then return false end
    local hour = S.gameHour()
    if not hour then
        Boat.debug('shop hours are on but the server has no game hour (weathersync not started)')
        return false
    end
    return Boat.isClosed(shop, hour)
end

-- a real shop, the player at it, allowed in, and it sells this model
function S.shopFor(src, ch, shopId, key)
    local shop = type(shopId) == 'string' and Boat.shops[shopId] or nil
    if not shop then return nil end
    if not S.nearShop(src, shop) then
        Boat.debug(('%s is too far from shop %s'):format(src, shopId))
        return nil
    end
    if not S.jobOk(ch, shop) then return nil end
    local entry = Boat.entry(shop, key)
    if not entry then return shop, nil end
    return shop, entry
end

-- one action per player per window
local lastHit = {}
function S.limited(src, key, gapMs)
    local per = lastHit[src]
    if not per then
        per = {}
        lastHit[src] = per
    end
    local now = GetGameTimer()
    if per[key] and now - per[key] < (gapMs or CFG.Timings.rateLimitMs) then return true end
    per[key] = now
    return false
end

-- one money or ownership change at a time per character
local busy = {}
function S.lock(charId)
    if busy[charId] then return false end
    busy[charId] = true
    return true
end

function S.unlock(charId)
    busy[charId] = nil
end

-- runs fn while holding the character's lock; errors are printed, never left locked
function S.locked(charId, fn, ...)
    if not S.lock(charId) then return end
    local ok, err = pcall(fn, ...)
    S.unlock(charId)
    if not ok then print(('^1[boatshops]^7 %s'):format(tostring(err))) end
end

-- ------------------------------------------------------------------ database

function S.loadOwned(id, charId)
    id = tonumber(id)
    if not id or not charId then return nil end
    return MySQL.single.await(
        'SELECT id, identifier, charidentifier, name, boat, components FROM boats WHERE id = ? AND charidentifier = ?',
        { id, charId })
end

function S.listBoats(charId)
    return MySQL.query.await(
        'SELECT id, name, boat, components FROM boats WHERE charidentifier = ? ORDER BY id', { charId }) or {}
end

function S.sendBoats(src)
    local ch = S.char(src)
    if not ch then return end
    local rows = S.listBoats(ch.charIdentifier)
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = {
            id = r.id,
            name = r.name,
            boat = r.boat,
            components = r.components,
            out = BoatFleet.isOut(r.id),
        }
    end
    TriggerClientEvent('boatshops:boats', src, out)
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `boats` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(100) NOT NULL DEFAULT '',
            `charidentifier` int(11) NOT NULL,
            `name` varchar(64) NOT NULL DEFAULT 'Boat',
            `boat` varchar(64) NOT NULL DEFAULT '',
            `components` longtext NULL DEFAULT NULL,
            PRIMARY KEY (`id`),
            KEY `charidentifier` (`charidentifier`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    ]])
    print('^2[boatshops]^7 ready')
end)

AddEventHandler('playerDropped', function()
    lastHit[source] = nil
end)
