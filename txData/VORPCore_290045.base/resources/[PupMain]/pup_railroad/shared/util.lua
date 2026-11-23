-- pup_railroad | helpers shared by client and server

Rail = Rail or {}

function Rail.L(key, ...)
    local text = Locale[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, text, ...)
        if ok then return out end
    end
    return text
end

function Rail.debug(...)
    if Config.Debug then print('[pup_railroad]', ...) end
end

function Rail.round(n)
    n = tonumber(n) or 0
    return math.floor(n + 0.5)
end

-- whole number or nil
function Rail.int(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.tointeger(v) -- nil for fractions
end

-- 32-bit views of a hash, whatever form it was written in
function Rail.u32(h)
    local n = Rail.int(h)
    if not n then return nil end
    return n & 0xFFFFFFFF
end

function Rail.s32(h)
    local u = Rail.u32(h)
    if not u then return nil end
    if u >= 0x80000000 then return u - 0x100000000 end
    return u
end

-- the form stored in player_trains.hash: hex config values give their unsigned decimal,
-- negative decimal ones stay as written
function Rail.hashString(h)
    return tostring(Rail.int(h))
end

function Rail.shopEntryByHash(h)
    local want = Rail.u32(h)
    if not want then return nil end
    for i = 1, #Config.Trains do
        local t = Config.Trains[i]
        if not t.disabled and Rail.u32(t.hash) == want then return t, i end
    end
    return nil
end

function Rail.stationByKey(key)
    if type(key) ~= 'string' then return nil end
    for i = 1, #Config.Stations do
        if Config.Stations[i].key == key then return Config.Stations[i] end
    end
    return nil
end

function Rail.jobHasStation(job)
    if type(job) ~= 'string' then return false end
    for i = 1, #Config.Stations do
        if Config.Stations[i].job == job then return true end
    end
    return false
end

function Rail.findRoute(name)
    if type(name) ~= 'string' then return nil end
    for _, routes in pairs(Config.Circuits) do
        for i = 1, #routes do
            if routes[i].name == name then return routes[i] end
        end
    end
    return nil
end

function Rail.inList(list, value)
    for i = 1, #list do
        if list[i] == value then return true end
    end
    return false
end

-- a heading h matches when h, or h + 360, lies in the range
function Rail.headingMatches(h, range)
    local lo, hi = range[1], range[2]
    return (h >= lo and h <= hi) or (h + 360 >= lo and h + 360 <= hi)
end

-- material set whose wear key is nearest the given wear
function Rail.nearestMaterialSet(wear)
    local bestKey, bestDiff
    for key in pairs(Config.Maintenance.materialSets) do
        local d = math.abs(key - wear)
        if not bestDiff or d < bestDiff or (d == bestDiff and key < bestKey) then
            bestKey, bestDiff = key, d
        end
    end
    return bestKey and Config.Maintenance.materialSets[bestKey] or nil
end

function Rail.cargoText(cargo)
    local parts = {}
    for i = 1, #cargo do
        parts[i] = ('%d %s'):format(cargo[i].count, cargo[i].label)
    end
    return table.concat(parts, ', ')
end
