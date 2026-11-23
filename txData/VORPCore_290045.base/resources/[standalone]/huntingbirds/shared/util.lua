-- huntingbirds | helpers used on both sides

Util = {}

-- unsigned 32-bit form of a model or zone hash, so signed and unsigned values compare equal
function Util.u32(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.tointeger(math.floor(n))
    if not n then return nil end
    return n & 0xFFFFFFFF
end

-- signed 32-bit form, as the birds.model column stores it
function Util.s32(v)
    local n = Util.u32(v)
    if not n then return nil end
    if n >= 0x80000000 then n = n - 0x100000000 end
    return n
end

function Util.hash(name)
    if type(name) == 'number' then return Util.u32(name) end
    return Util.u32(GetHashKey(tostring(name)))
end

function Util.round2(n)
    return math.floor((tonumber(n) or 0) * 100 + 0.5) / 100
end

-- a finite whole number inside [lo, hi], else nil
function Util.int(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.tointeger(n)
    if not n then return nil end
    if lo and n < lo then return nil end
    if hi and n > hi then return nil end
    return n
end

-- shop price of a catalog variant: base plus the shop's tax, two decimals
function Util.finalPrice(shop, variant)
    local base = tonumber(variant.price) or 0
    local tax = tonumber(shop.taxPercent) or 0
    return Util.round2(base + base * tax / 100)
end

function Util.variant(categoryIndex, variantIndex)
    local cat = Config.BirdCatalog[categoryIndex]
    if not cat then return nil, nil end
    return cat, cat.variants[variantIndex]
end

function Util.roleOf(model)
    return Config.BirdRoles[Util.u32(model) or -1]
end

function Util.listHas(list, value)
    if type(list) ~= 'table' or value == nil then return false end
    for _, v in pairs(list) do
        if v == value then return true end
    end
    return false
end

-- money text: whole dollars without decimals, otherwise two
function Util.money(n)
    n = Util.round2(n)
    if n == math.floor(n) then return ('%d'):format(math.floor(n)) end
    return ('%.2f'):format(n)
end
