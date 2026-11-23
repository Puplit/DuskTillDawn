-- goldpan | pay streaks: hidden rich cells per water, server memory only

Streaks = {}

local S <const> = Config.Panning.Streaks
local CELL <const> = math.max(1, tonumber(S.cell) or 60)
local RADIUS <const> = math.max(0, tonumber(S.radius) or 55)
local FALLOFF <const> = math.max(tonumber(S.falloff) or 220, RADIUS + 1)
local SPREAD <const> = math.max(0, math.floor(tonumber(S.spread) or 3))
local PER_WATER <const> = math.max(0, math.floor(tonumber(S.perWater) or 2))
local PANS <const> = math.max(1, math.floor(tonumber(S.pansToDrain) or 14))
local LIFE_MS <const> = math.max(0, tonumber(S.lifetimeMin) or 45) * 60000
local MEMORY <const> = math.max(1, math.floor(tonumber(S.memory) or 64))

if SPREAD * CELL >= FALLOFF then
    print(('^3[%s]^7 Streaks.spread * Streaks.cell (%d m) reaches past Streaks.falloff (%d m); new streaks can start out of hint range')
        :format(GetCurrentResourceName(), SPREAD * CELL, FALLOFF))
end

-- [water] = { live = { [key] = { cx, cy, left, expires } }, panned = { key, ... }, pannedSet = { [key] = true }, worked = { [key] = until } }
local waters = {}

local function key(cx, cy) return cx .. ':' .. cy end

local function cellOf(x, y)
    return math.floor(x / CELL), math.floor(y / CELL)
end

local function centre(cx, cy)
    return (cx + 0.5) * CELL, (cy + 0.5) * CELL
end

local function waterData(hash)
    local w = waters[hash]
    if not w then
        w = { live = {}, panned = {}, pannedSet = {}, worked = {} }
        waters[hash] = w
    end
    return w
end

local function purge(w, now)
    for k, s in pairs(w.live) do
        if s.left <= 0 or (s.expires and now >= s.expires) then w.live[k] = nil end
    end
    for k, untilMs in pairs(w.worked) do
        if now >= untilMs then w.worked[k] = nil end
    end
end

local function liveCount(w)
    local n = 0
    for _ in pairs(w.live) do n = n + 1 end
    return n
end

-- one new streak near (pcx, pcy): prefer cells someone has panned, else a random cell
local function seed(w, pcx, pcy, now)
    local own = key(pcx, pcy)
    local candidates = {}
    for _, k in ipairs(w.panned) do
        if k ~= own and not w.live[k] and not w.worked[k] then
            local cx, cy = k:match('^(-?%d+):(-?%d+)$')
            cx, cy = tonumber(cx), tonumber(cy)
            if cx and math.abs(cx - pcx) <= SPREAD and math.abs(cy - pcy) <= SPREAD then
                candidates[#candidates + 1] = { cx, cy }
            end
        end
    end

    local cx, cy
    if #candidates > 0 then
        local pick = candidates[math.random(1, #candidates)]
        cx, cy = pick[1], pick[2]
    else
        for _ = 1, 12 do
            local tx, ty = pcx + math.random(-SPREAD, SPREAD), pcy + math.random(-SPREAD, SPREAD)
            if not w.live[key(tx, ty)] then cx, cy = tx, ty break end
        end
    end
    if not cx then return end
    w.live[key(cx, cy)] = { cx = cx, cy = cy, left = PANS, expires = LIFE_MS > 0 and (now + LIFE_MS) or nil }
end

-- tops up the water's streaks and returns proximity p (0..1) and the nearest streak key
function Streaks.check(hash, x, y)
    local now = GetGameTimer()
    local w = waterData(hash)
    purge(w, now)
    local pcx, pcy = cellOf(x, y)
    if liveCount(w) < PER_WATER then seed(w, pcx, pcy, now) end

    local best, bestKey = 0.0, nil
    for k, s in pairs(w.live) do
        if s.left > 0 then
            local mx, my = centre(s.cx, s.cy)
            local d = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
            local f
            if d <= RADIUS then f = 1.0
            elseif d >= FALLOFF then f = 0.0
            else f = 1.0 - (d - RADIUS) / (FALLOFF - RADIUS) end
            if f > best then best, bestKey = f, k end
        end
    end
    return best, bestKey
end

-- remember a paid pan's cell (newest last, oldest dropped)
function Streaks.recordPan(hash, x, y)
    local w = waterData(hash)
    local k = key(cellOf(x, y))
    if w.pannedSet[k] then
        for i, v in ipairs(w.panned) do
            if v == k then table.remove(w.panned, i) break end
        end
    end
    w.panned[#w.panned + 1] = k
    w.pannedSet[k] = true
    while #w.panned > MEMORY do
        w.pannedSet[table.remove(w.panned, 1)] = nil
    end
end

-- one pan off a streak; true when that emptied it
function Streaks.drain(hash, k)
    local w = waters[hash]
    local s = w and w.live[k]
    if not s then return false end
    s.left = s.left - 1
    if s.left > 0 then return false end
    w.live[k] = nil
    -- a worked-out cell does not reseed straight away
    w.worked[k] = GetGameTimer() + (LIFE_MS > 0 and LIFE_MS or 2700000)
    return true
end
