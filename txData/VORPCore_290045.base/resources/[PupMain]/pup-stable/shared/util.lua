-- pup-stable | small helpers shared by client and server

U = {}

function U.num(v, def)
    local n = tonumber(v)
    if n == nil or n ~= n or n == math.huge or n == -math.huge then return def end
    return n
end

function U.int(v, def)
    local n = U.num(v)
    if not n then return def end
    return math.floor(n)
end

function U.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function U.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- cut to at most n characters, never splitting a UTF-8 sequence; bad bytes are dropped
function U.cut(s, n)
    if type(s) ~= 'string' then return '' end
    local out, count = {}, 0
    for ch in s:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if count >= n then break end
        if ch:byte() >= 32 or #ch > 1 then
            out[#out + 1] = ch
            count = count + 1
        end
    end
    return table.concat(out)
end

-- trimmed, control characters stripped, at most max characters; nil when empty
function U.cleanName(s, max)
    if type(s) ~= 'string' then return nil end
    s = U.trim(U.cut(U.trim(s), max or 50))
    if s == '' then return nil end
    return s
end

function U.dist2(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function U.dist3(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- point in polygon (x/y only); poly = { { x, y }, ... }
function U.inPoly(poly, x, y)
    local inside, j = false, #poly
    for i = 1, #poly do
        local xi, yi, xj, yj = poly[i][1], poly[i][2], poly[j][1], poly[j][2]
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) ~= 0 and (yj - yi) or 1e-9) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

-- unsigned 32-bit view of a hash (catalogue compares)
function U.u32(h)
    h = U.int(h, 0)
    if h < 0 then h = h + 4294967296 end
    return h % 4294967296
end

-- signed 32-bit (database form)
function U.s32(h)
    h = U.u32(h)
    if h >= 2147483648 then h = h - 4294967296 end
    return h
end

-- horse level from lifetime XP
function U.level(xp)
    local lv = 1
    for i, need in ipairs(Config.Training.levels) do
        if xp >= need then lv = i end
    end
    return lv
end

-- game rank (0..10) from points (0..5000 scale of the native attribute)
function U.rankFromPoints(points, ceiling)
    ceiling = ceiling or Config.Stats.pointCeiling
    return U.clamp(math.floor((points or 0) / ceiling * 10 + 0.0001), 0, 10)
end

-- bond level 1..4 from points
function U.bondLevel(points)
    local max = Config.Stats.bondCeiling
    if points >= max then return 4 end
    if points >= max * 2 / 3 then return 3 end
    if points >= max / 3 then return 2 end
    return 1
end

function U.money(n)
    n = U.num(n, 0)
    if n == math.floor(n) then return ('%d'):format(n) end
    return ('%.2f'):format(n)
end

function U.copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = U.copy(v) end
    return o
end

-- handling level 1..4 -> game rank
U.HANDLING_RANK = { 1, 3, 5, 9 }

-- catalogue index of a component hash in a category (1-based) or nil
function U.catalogueIndex(category, hash)
    local list = HorseComponents and HorseComponents[category]
    if not list then return nil end
    local want = U.u32(hash)
    for i, entry in ipairs(list) do
        for _, h in ipairs(entry.variations or {}) do
            if U.u32(h) == want then return i end
        end
    end
    return nil
end

-- position of a wagon customisation value in that model's option list (0 = the "No ..." row), or nil
-- when the model does not offer it (the server refuses those). Extras are numbered extra id + 1:
-- which extras exist is only known to the game.
function U.wagonOptionIndex(model, col, value)
    model = tostring(model or ''):lower()
    local D = WagonsData or {}
    if col == 'vehicle_tints' then
        local v = U.int(value)
        if v == nil then return nil end
        if v == -2 then return 0 end
        local n = (D.vehicle_tints or {})[model] or 0
        if v >= 0 and v < n then return v + 1 end
    elseif col == 'vehicle_propsets' or col == 'vehicle_lantern_propsets' then
        local v = tostring(value or '')
        if v == '-1' then return 0 end
        for i, p in ipairs((D[col] or {})[model] or {}) do if p == v then return i end end
    elseif col == 'vehicle_liveries' then
        local v = U.int(value)
        if v == nil then return nil end
        if v == 254 or v == -1 then return 0 end
        local i = 0
        for _, g in ipairs((D.vehicle_liveries or {})[model] or {}) do
            for _, id in ipairs(g.ids or {}) do
                i = i + 1
                if id == v then return i end
            end
        end
    elseif col == 'vehicle_extras' then
        local v = U.int(value)
        if v == nil then return nil end
        if v == -1 then return 0 end
        if v >= 0 and v <= 15 then return v + 1 end
    end
    return nil
end

-- categories that are part of the horse's own look (one per horse)
U.UNIQUE = { horse_heads = true, horse_bodies = true, horse_manes = true, horse_tails = true, horse_mustache = true, horse_shoes = true, palettesForHorseCoat = true }
U.TACK = { 'horse_saddles', 'horse_saddlebags', 'saddle_stirrups', 'saddle_horns', 'saddle_lanterns', 'horse_blankets', 'horse_bedrolls', 'horse_bridles', 'horse_accessories', 'horse_outfits' }
U.TACK_SET = {}
for _, c in ipairs(U.TACK) do U.TACK_SET[c] = true end
U.FOCUS = { speed = true, acceleration = true, handling = true, health = true, stamina = true, bonding = true }
