-- pup_clothing | small helpers shared by both sides. No natives here.

PC = PC or {}
local U = {}
PC.U = U

local TWO32 <const> = 4294967296

-- any hash (signed, unsigned, float, numeric string) -> unsigned 32-bit integer, or nil
function U.u32(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    v = math.tointeger(v) or math.floor(v)
    return math.tointeger(v % TWO32)
end

-- unsigned -> signed 32-bit
function U.s32(v)
    v = U.u32(v)
    if not v then return nil end
    if v >= 2147483648 then return v - TWO32 end
    return v
end

function U.int(v)
    v = tonumber(v)
    if not v or v ~= v then return nil end
    return math.tointeger(v) or math.floor(v)
end

function U.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- decode a JSON string into a table; nil when it is not a string, too long, or not an object
function U.decodeObject(str, maxBytes)
    if type(str) ~= 'string' then return nil end
    if maxBytes and #str > maxBytes then return nil end
    local ok, t = pcall(json.decode, str)
    if not ok or type(t) ~= 'table' then return nil end
    return t
end

function U.count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function U.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- cut a UTF-8 string to at most n characters without splitting a character
function U.utf8Cut(s, n)
    s = tostring(s or '')
    local ok, len = pcall(utf8.len, s)
    if not ok or not len then
        -- invalid UTF-8: keep only printable ASCII
        s = s:gsub('[^\32-\126]', '')
        return s:sub(1, n)
    end
    if len <= n then return s end
    return s:sub(1, utf8.offset(s, n + 1) - 1)
end

-- a category key as stored in the extras: lower-case letters, digits and underscores
function U.validCatKey(k, maxLen)
    return type(k) == 'string' and #k > 0 and #k <= (maxLen or 64) and k:match('^[%w_]+$') ~= nil
end

local function chan(v, max)
    v = U.int(v) or 0
    return U.clamp(v, 0, max)
end

-- one clean extras entry: { h = number|false, p = 0..palettes, c = {c1,c2,c3} } or nil when invalid
function U.cleanExtrasEntry(e, paletteCount, chanMax)
    if type(e) ~= 'table' then return nil end
    local h = e.h
    if type(h) == 'number' then
        h = U.int(h)
        if not h or h == 0 then h = false end
    else
        h = false
    end
    local p = U.int(e.p) or 0
    if p < 0 or p > paletteCount then p = 0 end
    local c = type(e.c) == 'table' and e.c or {}
    return { h = h, p = p, c = { chan(c[1], chanMax), chan(c[2], chanMax), chan(c[3], chanMax) } }
end

-- clean a whole extras map; drops entries that carry neither a garment nor a colour
function U.cleanExtras(t, opts)
    local out, n = {}, 0
    if type(t) ~= 'table' then return out, 0 end
    for k, e in pairs(t) do
        if U.validCatKey(k, opts.keyMax) then
            local ce = U.cleanExtrasEntry(e, opts.paletteCount, opts.chanMax)
            if ce and (ce.h ~= false or ce.p > 0) then
                n = n + 1
                if n > opts.maxSlots then return nil, n end
                out[k] = ce
            end
        end
    end
    return out, n
end

-- json.encode turns an empty table into [] in some builds; extras are always an object
function U.encodeObject(t)
    if type(t) ~= 'table' or next(t) == nil then return '{}' end
    return json.encode(t)
end

-- "pants_accessories" -> "Pants Accessories"; "word_0xABCD" -> "Special ABCD"
function U.prettyKey(key, specialFmt)
    local hex = tostring(key):match('^%a+_0[xX](%x+)$')
    if hex then return (specialFmt or 'Special %s'):format(hex:upper()) end
    local s = tostring(key):gsub('_', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end
