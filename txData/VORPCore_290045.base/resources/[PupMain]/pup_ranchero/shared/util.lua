-- pup_ranchero | helpers shared by client and server

U = {}

-- lenient number: accepts numbers and numeric strings, anything else is the fallback
function U.num(v, fallback)
    local n = tonumber(v)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return fallback end
    return n
end

function U.round(n)
    return math.floor((tonumber(n) or 0) + 0.5)
end

function U.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function U.cents(n)
    return math.floor((tonumber(n) or 0) * 100 + 1e-6) / 100
end

function U.money(n)
    n = U.cents(n)
    if n == math.floor(n) then return tostring(math.floor(n)) end
    return ('%.2f'):format(n)
end

-- a coordinate table {x,y,z} with real finite numbers, or nil
function U.coords(t)
    if type(t) ~= 'table' and type(t) ~= 'vector3' and type(t) ~= 'userdata' then return nil end
    local ok, x, y, z = pcall(function() return t.x, t.y, t.z end)
    if not ok then return nil end
    x, y, z = U.num(x), U.num(y), U.num(z)
    if not (x and y and z) then return nil end
    if math.abs(x) > 20000 or math.abs(y) > 20000 or math.abs(z) > 5000 then return nil end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

function U.dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

-- json text from the database: tolerates NULL, '' and broken values
function U.decode(text)
    if type(text) == 'table' then return text end
    if type(text) ~= 'string' or text == '' then return {} end
    local ok, v = pcall(json.decode, text)
    if ok and type(v) == 'table' then return v end
    return {}
end

-- seconds as "45s" under a minute, otherwise whole minutes rounded up
function U.shortTime(sec)
    sec = math.max(0, math.ceil(tonumber(sec) or 0))
    if sec < 60 then return sec .. 's' end
    return math.ceil(sec / 60) .. 'm'
end

-- cut a string to at most n characters without splitting a UTF-8 sequence
function U.cut(s, n)
    s = tostring(s or '')
    local okLen, len = pcall(utf8.len, s)
    if not okLen or not len then
        s = s:gsub('[\128-\255]', '?')
        return s:sub(1, n)
    end
    if len <= n then return s end
    local stop = utf8.offset(s, n + 1)
    return s:sub(1, stop - 1)
end

function U.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- trail points 1..4 from the stored shape [ {loc1,loc2,loc3,loc4} ], or nil
function U.trailPoints(trail)
    if type(trail) ~= 'table' then return nil end
    local t = trail[1] or trail
    if type(t) ~= 'table' then return nil end
    local pts = {}
    for i = 1, 4 do
        local p = U.coords(t['loc' .. i])
        if not p then return nil end
        pts[i] = p
    end
    return pts
end

-- the herding route: trail points 1,2,3,4,3,2,1
U.ROUTE = { 1, 2, 3, 4, 3, 2, 1 }

function U.sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a):lower() < tostring(b):lower() end)
    return keys
end

-- herd quality after a successful drive, shared so client and server use one formula
function U.herdQuality(startQuality, arrived, trailFactor, environment)
    local lv = Config.Livestock
    local x
    if startQuality >= lv.maxQuality then
        x = startQuality
    else
        x = (startQuality + arrived) * trailFactor
    end
    local env = environment
    if not env or env <= 0 then env = 1 end
    local q = x * env / 100
    if lv.boostOn then q = q * lv.boostMult end
    return math.min(q, lv.maxQuality)
end

function U.choreLabel(name)
    return Locale['chore_' .. tostring(name)] or tostring(name)
end

function U.envMax()
    local m = tonumber(Config.Environment.max) or 0
    return m > 0 and m or 300
end

function U.yieldFor(score, environment)
    local maxScore = Config.Chores.maxScore
    score = U.clamp(tonumber(score) or 0, 0, maxScore)
    local scale = U.envMax()
    local env = tonumber(environment) or 0
    if env <= 0 then env = 1 end
    env = math.min(env, scale)
    return U.round((score / maxScore) * (env / scale) * Config.Produce.maxYield)
end
