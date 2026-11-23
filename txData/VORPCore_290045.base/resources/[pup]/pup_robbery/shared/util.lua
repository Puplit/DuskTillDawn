-- pup_robbery | helpers shared by client and server

U = {}

function U.vec(p)
    if type(p) == 'vector3' or type(p) == 'vector4' then return vector3(p.x, p.y, p.z) end
    if type(p) == 'table' then
        local x, y, z = tonumber(p.x or p[1]), tonumber(p.y or p[2]), tonumber(p.z or p[3])
        if x and y and z then return vector3(x + 0.0, y + 0.0, z + 0.0) end
    end
    return nil
end

function U.dist(a, b)
    a, b = U.vec(a), U.vec(b)
    if not a or not b then return math.huge end
    return #(a - b)
end

function U.clamp(n, lo, hi)
    n = tonumber(n) or lo
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function U.round(n)
    n = tonumber(n) or 0
    return math.floor(n + 0.5)
end

function U.contains(list, value)
    if type(list) ~= 'table' then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

function U.shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function U.count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- "1h 05m" from seconds
function U.hm(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    return ('%dh %02dm'):format(h, m)
end

function U.minutesUp(seconds)
    return math.max(1, math.ceil((tonumber(seconds) or 0) / 60))
end

-- the place settings with category defaults filled in
function U.placeSettings(place)
    local cat = Config.Categories[place.category or 'other'] or Config.Categories.other or {}
    local s = {}
    s.lawmen = place.lawmen or cat.lawmen or 0
    s.riders = place.riders or cat.riders or Config.Walkup.defaultRiders or 1
    s.jobLimit = place.jobLimit or cat.jobLimit
    return s
end

-- the distinct guard posts a wave uses, in order (duplicates merged, cycled when short)
function U.wavePosts(place)
    local seen, distinct = {}, {}
    for _, p in ipairs(place.posts or {}) do
        local key = ('%.2f:%.2f:%.2f'):format(p.pos.x, p.pos.y, p.pos.z)
        if not seen[key] then
            seen[key] = true
            distinct[#distinct + 1] = p
        end
    end
    local size = place.waves and place.waves.size or 0
    local out = {}
    if #distinct == 0 then return out end
    for i = 1, size do
        out[i] = distinct[((i - 1) % #distinct) + 1]
    end
    return out
end

-- route limits for heist stages, alternatives, doors and loot spots
function U.routeAllows(x, entryKey, quiet)
    if type(x) ~= 'table' then return false end
    if x.onlyVia and not U.contains(x.onlyVia, entryKey) then return false end
    if x.neverVia and U.contains(x.neverVia, entryKey) then return false end
    if x.quietOnly and not quiet then return false end
    if x.loudOnly and quiet then return false end
    return true
end

-- every door hash a bank controls
function U.bankDoors(bank)
    local out, seen = {}, {}
    local function add(h)
        h = tonumber(h)
        if h and not seen[h] then
            seen[h] = true
            out[#out + 1] = h
        end
    end
    add(bank.vaultDoor)
    for _, e in pairs(bank.entries or {}) do
        for _, h in ipairs(e.doors or {}) do add(h) end
    end
    for _, s in ipairs(bank.stages or {}) do
        for _, h in ipairs(s.doors or {}) do add(h) end
    end
    for _, d in ipairs(bank.extraDoors or {}) do
        for _, h in ipairs(d.doors or {}) do add(h) end
    end
    for _, h in ipairs(bank.lockedDoors or {}) do add(h) end
    return out
end

function U.fill(template, values)
    return (tostring(template):gsub('{(%w+)}', function(k)
        local v = values[k]
        return v ~= nil and tostring(v) or ('{' .. k .. '}')
    end))
end
