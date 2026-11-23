-- pup_mercantile | small helpers shared by client and server

Util = {}

local MAX_AMOUNT <const> = 999999999

function Util.round2(n)
    n = tonumber(n) or 0
    if n >= 0 then return math.floor(n * 100 + 0.5) / 100 end
    return -math.floor(-n * 100 + 0.5) / 100
end

-- a money amount: a number above 0 and at most 999,999,999, rounded to cents
function Util.money(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = Util.round2(n)
    if n <= 0 or n > MAX_AMOUNT then return nil end
    return n
end

-- a whole count between lo and hi
function Util.whole(v, lo, hi)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    if math.floor(n) ~= n then return nil end
    n = math.floor(n)
    if lo and n < lo then return nil end
    if hi and n > hi then return nil end
    return n
end

function Util.fmt(n)
    return ('%.2f'):format(Util.round2(n))
end

-- 10000000 -> "10,000,000.00"
function Util.fmtThousands(n)
    local s = Util.fmt(n)
    local int, dec = s:match('^(-?%d+)%.(%d+)$')
    if not int then return s end
    local neg = int:sub(1, 1) == '-'
    if neg then int = int:sub(2) end
    int = int:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (neg and '-' or '') .. int .. '.' .. dec
end

function Util.trim(s)
    if type(s) ~= 'string' then return nil end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- shop names: trimmed, 1 to 50 characters, no markup characters
function Util.cleanName(s)
    s = Util.trim(s)
    if not s or #s < 1 or #s > 50 then return nil end
    if s:find('[<>\r\n\t]') then return nil end
    return s
end

function Util.copy(v)
    if type(v) ~= 'table' then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Util.copy(x) end
    return t
end

local COSMETIC <const> = { description = true, orgdescription = true }

local function deepEqual(a, b)
    if type(a) ~= type(b) then
        -- numbers that went through JSON may come back as strings of the same value
        if (type(a) == 'number' or type(a) == 'string') and (type(b) == 'number' or type(b) == 'string') then
            return tostring(a) == tostring(b)
        end
        return false
    end
    if type(a) ~= 'table' then return a == b end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
        if a[k] == nil and v ~= nil then return false end
    end
    return true
end

-- the identity part of item metadata: everything but the cosmetic top-level keys
function Util.identity(meta)
    local out = {}
    if type(meta) ~= 'table' then return out end
    for k, v in pairs(meta) do
        if not COSMETIC[k] then out[k] = v end
    end
    return out
end

function Util.sameIdentity(a, b)
    return deepEqual(Util.identity(a), Util.identity(b))
end

function Util.dist(a, b)
    if not a or not b then return math.huge end
    local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
    local dy = (tonumber(a.y) or 0) - (tonumber(b.y) or 0)
    local dz = (tonumber(a.z) or 0) - (tonumber(b.z) or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Util.validCoords(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not x or not y or not z then return nil end
    for _, n in ipairs({ x, y, z }) do
        if n ~= n or n == math.huge or n == -math.huge or math.abs(n) > 100000 then return nil end
    end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end

local blacklist
function Util.blacklisted(name)
    if not blacklist then
        blacklist = {}
        for _, n in ipairs(Config.Blacklist or {}) do blacklist[n] = true end
    end
    return blacklist[name] == true
end

-- "Item 2" sorts before "Item 10"
function Util.naturalLess(a, b)
    a, b = tostring(a or ''):lower(), tostring(b or ''):lower()
    local pa, na = a:match('^(.-)(%d+)$')
    local pb, nb = b:match('^(.-)(%d+)$')
    if pa and pb and pa == pb then return tonumber(na) < tonumber(nb) end
    return a < b
end

-- Discord webhook on one of the four official hosts, at most 200 characters
function Util.validWebhook(url)
    if type(url) ~= 'string' or #url > 200 then return false end
    local host, id, token = url:match('^https://([%w%.]+)/api/webhooks/(%d+)/([%w%-_]+)$')
    if not host or not id or not token then return false end
    local hosts = { ['discord.com'] = true, ['discordapp.com'] = true, ['ptb.discord.com'] = true, ['canary.discord.com'] = true }
    return hosts[host] == true
end

function Util.escape(s)
    s = tostring(s or '')
    return (s:gsub('[&<>"\']', { ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;', ["'"] = '&#39;' }))
end

function Util.L(key, ...)
    local s = Locale and Locale[key] or key
    if select('#', ...) > 0 then
        local ok, out = pcall(string.format, s, ...)
        if ok then return out end
    end
    return s
end
