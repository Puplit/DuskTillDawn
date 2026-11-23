-- legendaryhunt | rules shared by client and server
-- Lookups built once from the config, so neither side walks the lists per request.

Rules = {}

-- apply Config.LocaleOverrides on top of the Locale table
Locale = Locale or {}
for key, text in pairs(Config.LocaleOverrides or {}) do
    if type(text) == 'string' and text ~= '' then Locale[key] = text end
end

function Rules.text(key)
    local t = Locale[key]
    if type(t) == 'string' then return t end
    return key
end

local function signed32(n)
    n = math.floor(tonumber(n) or 0) & 0xFFFFFFFF
    if n >= 0x80000000 then n = n - 0x100000000 end
    return n
end
Rules.signed32 = signed32

-- lure item name -> label
Rules.lureLabel = {}
for _, l in ipairs(Config.Lures or {}) do
    Rules.lureLabel[l.item] = l.label
end

-- legendary id -> entry (Config.Animals keys need not be continuous: always look up by id)
function Rules.animal(id)
    id = tonumber(id)
    if not id or id ~= math.floor(id) then return nil end
    local a = Config.Animals and Config.Animals[id]
    if type(a) ~= 'table' then return nil end
    return a
end

-- from <= hour < to; a window whose start is after its end runs past midnight
function Rules.hourFits(animal, hour)
    local h = animal and animal.hours
    if type(h) ~= 'table' then return false end
    local from, to = tonumber(h[1]) or 0, tonumber(h[2]) or 24
    if from <= to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

-- hunting grounds: signed zone hash -> ground index (the client compares the same way)
Rules.groundByZone = {}
for i, g in ipairs(Config.Grounds or {}) do
    if type(g.zone) == 'string' and g.zone ~= '' then
        Rules.groundByZone[signed32(GetHashKey(g.zone))] = i
    end
end

function Rules.ground(index)
    index = tonumber(index)
    return index and Config.Grounds and Config.Grounds[index] or nil
end

-- the beast on this ground that this lure calls, ignoring the hour (first in the list wins)
function Rules.beastForLure(ground, lure)
    if type(ground) ~= 'table' or not lure then return nil end
    for _, id in ipairs(ground.beasts or {}) do
        local a = Rules.animal(id)
        if a and a.lure == lure then return id, a end
    end
    return nil
end

-- the beast on this ground that this lure calls at this hour
function Rules.beastNow(ground, lure, hour)
    if type(ground) ~= 'table' or not lure then return nil end
    for _, id in ipairs(ground.beasts or {}) do
        local a = Rules.animal(id)
        if a and a.lure == lure and Rules.hourFits(a, hour) then return id, a end
    end
    return nil
end

-- ped types that get the fight flags, as signed 32-bit hashes
Rules.fighter = {}
for _, name in ipairs(Config.Hunt.fighters or {}) do
    Rules.fighter[signed32(GetHashKey(name))] = true
end

-- shop lookups. Buy and sell: item -> { label, price }; a sell item listed twice keeps its first price
Rules.buy, Rules.sell = {}, {}
do
    local shop = Config.Shop or {}
    local function add(map, row)
        local price = type(row) == 'table' and tonumber(row[3]) or nil
        if type(row[1]) == 'string' and price and price >= 0 and not map[row[1]] then
            map[row[1]] = { label = tostring(row[2] or row[1]), price = price }
        end
    end
    for _, row in ipairs(shop.buy and shop.buy.rows or {}) do add(Rules.buy, row) end
    for _, group in ipairs(shop.sell and shop.sell.groups or {}) do
        for _, row in ipairs(group.rows or {}) do add(Rules.sell, row) end
    end
end

function Rules.minutesLeft(ms)
    return math.max(1, math.ceil((tonumber(ms) or 0) / 60000))
end
