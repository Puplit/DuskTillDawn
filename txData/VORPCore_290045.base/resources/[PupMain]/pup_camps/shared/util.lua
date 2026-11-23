-- pup_camps | helpers shared by server and client

U = {}

local TWO32 <const> = 4294967296

-- Model / outfit / quality values as unsigned 32-bit numbers. A value outside the 32-bit
-- range (bad data) gives nil so it never matches anything.
function U.h32(v)
    if v == nil or v == false then return nil end
    if type(v) == 'string' then
        if v == 'any' or v == '' then return nil end
        v = GetHashKey(v)
    end
    v = tonumber(v)
    if not v or v ~= math.floor(v) then return nil end
    if v < -2147483648 or v >= TWO32 then return nil end
    if v < 0 then v = v + TWO32 end
    return math.tointeger(v) or v
end

-- a game hash in the signed form natives expect
function U.signed(v)
    local u = U.h32(v)
    if not u then return 0 end
    if u >= 2147483648 then return u - TWO32 end
    return u
end

function U.round(n, places)
    local m = 10 ^ (places or 0)
    return math.floor((tonumber(n) or 0) * m + 0.5) / m
end

function U.money(n)
    n = U.round(tonumber(n) or 0, 2)
    local neg = n < 0
    if neg then n = -n end
    local whole = math.floor(n)
    local cents = math.floor((n - whole) * 100 + 0.5)
    if cents >= 100 then whole, cents = whole + 1, cents - 100 end
    local s = tostring(math.tointeger(whole) or whole)
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if out:sub(1, 1) == ',' then out = out:sub(2) end
    return ('%s$%s.%02d'):format(neg and '-' or '', out, cents)
end

function U.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function U.dist3(a, b)
    local dx, dy, dz = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0), (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function U.dist2(a, b)
    local dx, dy = (a.x or 0) - (b.x or 0), (a.y or 0) - (b.y or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function U.vec(t)
    return { x = tonumber(t and t.x) or 0.0, y = tonumber(t and t.y) or 0.0, z = tonumber(t and t.z) or 0.0 }
end

-- ranks ------------------------------------------------------------------------------
local rankPos = {}
for i, r in ipairs(Config.Ranks) do rankPos[r.id] = i end

function U.rankIndex(id)
    return rankPos[id] or 1
end

function U.rankLabel(id)
    if id == 'leader' then return 'Leader' end
    local r = Config.Ranks[rankPos[id] or 1]
    return r and r.label or 'Member'
end

function U.validRank(id)
    return rankPos[id] ~= nil
end

-- isLeader passes everything; otherwise compare positions
function U.meets(rankId, isLeader, required)
    if isLeader then return true end
    if required == 'leader' then return false end
    return U.rankIndex(rankId) >= U.rankIndex(required)
end

function U.permLabel(action)
    local need = Config.Permissions[action] or 'leader'
    return U.rankLabel(need)
end

-- furniture --------------------------------------------------------------------------
-- legacy purpose names stored in the camp row, mapped from the catalogue's "use"
U.UseToStored = {
    none = 'none', storage = 'inv', wardrobe = 'changing', stable = 'stable',
    stew = 'stew', trapper = 'hunting', beerbox = 'beerbox', waterbarrel = 'waterbarrel',
}

-- every piece of a camp as a list sorted by id
function U.pieces(furni)
    local out = {}
    for k, p in pairs(furni or {}) do
        if type(p) == 'table' then
            p.id = tonumber(p.id) or tonumber(k)
            if p.id then out[#out + 1] = p end
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function U.placedCount(furni)
    local n = 0
    for _, p in pairs(furni or {}) do
        if type(p) == 'table' and p.item ~= Config.Camp.flagItem then n = n + 1 end
    end
    return n
end

-- animals ----------------------------------------------------------------------------
local byModel = nil
local function indexAnimals()
    byModel = {}
    for _, row in ipairs(CampAnimals or {}) do
        local m = U.h32(row.model)
        if m then
            byModel[m] = byModel[m] or {}
            local list = byModel[m]
            list[#list + 1] = row
        end
    end
end

-- same model + same outfit wins; else the first row with that model and outfit 'any'
function U.animalRow(model, outfit)
    if not byModel then indexAnimals() end
    local m = U.h32(model)
    if not m then return nil end
    local list = byModel[m]
    if not list then return nil end
    local o = U.h32(outfit)
    if o then
        for _, row in ipairs(list) do
            if row.outfit ~= 'any' and U.h32(row.outfit) == o then return row end
        end
    end
    for _, row in ipairs(list) do
        if row.outfit == 'any' then return row end
    end
    return nil
end

function U.peltPrice(row, quality)
    local q = U.h32(quality)
    local qs = row.quality
    if q and qs then
        if qs[3] and U.h32(qs[3]) == q then return row.price[3] end
        if qs[2] and U.h32(qs[2]) == q then return row.price[2] end
        if qs[1] and U.h32(qs[1]) == q then return row.price[1] end
    end
    return row.price[1]
end

function U.rowMax(row)
    return math.max(row.price[1] or 0, row.price[2] or 0, row.price[3] or 0)
end

local bestSmall = nil
function U.horsePeltCap()
    if not bestSmall then
        bestSmall = 0
        for _, row in ipairs(CampAnimals or {}) do
            if not row.big and (row.price[3] or 0) > bestSmall then bestSmall = row.price[3] end
        end
    end
    return (Config.Butchers.maxHorsePelts or 6) * bestSmall
end

function U.isWebhook(url)
    if type(url) ~= 'string' or url == '' then return false end
    local low = url:lower()
    for _, p in ipairs(Config.Camp.webhookPrefixes) do
        if low:sub(1, #p) == p then return #url > #p end
    end
    return false
end

function U.debug(...)
    if not Config.Debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print('^5[pup_camps]^7 ' .. table.concat(parts, ' '))
end
