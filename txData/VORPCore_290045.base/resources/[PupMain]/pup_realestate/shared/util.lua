-- pup_realestate | helpers shared by both sides

KIND_REAL, KIND_MOTEL, KIND_MARKER, KIND_TELE = 0, 1, 3, 4

U = {}

function U.int(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.floor(v)
end

function U.vec(t)
    if type(t) == 'vector3' or type(t) == 'vector4' then return vector3(t.x, t.y, t.z) end
    if type(t) ~= 'table' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not (x and y and z) then return nil end
    if x ~= x or y ~= y or z ~= z then return nil end
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

function U.dist(a, b)
    if not a or not b then return math.huge end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

-- the interior name of a teleporter house (stored as the one string in otherdoors)
function U.interiorName(h)
    if not h or h.kind ~= KIND_TELE then return nil end
    local name = type(h.other) == 'table' and h.other[1]
    if type(name) == 'string' then return name end
    return nil
end

function U.interior(h)
    local name = U.interiorName(h)
    return name and Config.Interiors[name] or nil, name
end

-- "Penthouse #12" or "House #12"
function U.title(h)
    if not h then return 'House' end
    return ('%s #%s'):format(U.interiorName(h) or Locale.house, tostring(h.id))
end

-- front door position of a house (any kind)
function U.frontDoor(h)
    local d = h and type(h.doors) == 'table' and h.doors[1]
    return U.vec(d)
end

function U.money(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if out:sub(1, 1) == ',' then out = out:sub(2) end
    return (n < 0 and '-' or '') .. out
end

function U.nearestFallback(pos)
    local best, bestD
    for _, f in ipairs(Config.Fallbacks) do
        local d = pos and #(pos - f.coords) or 0
        if not best or d < bestD then best, bestD = f.coords, d end
    end
    return best
end

function U.motel(key)
    if type(key) ~= 'string' then return nil end
    local m = Config.Motels.list[key]
    if not m then return nil end
    return {
        key = key,
        name = m.name,
        entrance = m.entrance,
        price = math.floor(tonumber(m.price) or Config.Motels.defaults.price),
        slots = math.floor(tonumber(m.slots) or Config.Motels.defaults.slots),
        leash = tonumber(m.leash) or Config.Motels.defaults.leash,
        blip = m.blip or Config.Motels.blip,
    }
end

function U.slotCap(n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    local cap = Config.MaxSlots
    if cap == nil then cap = 200 end
    cap = math.floor(tonumber(cap) or 200)
    if cap > 0 and n > cap then n = cap end
    return n
end

function U.inList(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then return true end
    end
    return false
end
