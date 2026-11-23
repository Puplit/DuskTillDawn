-- pup_business | helpers shared by client and server

PB = PB or {}

-- the eight rank permissions, in display order
PB.PERM_KEYS = { 'hire', 'fire', 'setranks', 'managepay', 'stash', 'store', 'billing', 'mail' }

PB.PERM_SET = {}
for _, k in ipairs(PB.PERM_KEYS) do PB.PERM_SET[k] = true end

-- tax period lengths in seconds; monthly is a flat 30 days
PB.PERIODS = { daily = 86400, weekly = 604800, monthly = 2592000 }

function PB.period(p)
    p = type(p) == 'string' and p:lower() or ''
    if PB.PERIODS[p] then return p end
    return 'weekly'
end

-- the driver hands booleans back as true/false or 1/0 (sometimes as text)
function PB.bool(v)
    return v == true or v == 1 or v == '1' or v == 'true'
end

function PB.int(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.floor(v)
end

-- "$1,234.00"
function PB.money(n)
    n = tonumber(n) or 0
    local neg = n < 0
    local s = ('%.2f'):format(math.abs(n))
    local whole, frac = s:match('^(%d+)%.(%d+)$')
    whole = whole or s
    local out = whole:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if out:sub(1, 1) == ',' then out = out:sub(2) end
    return (neg and '-$' or '$') .. out .. '.' .. (frac or '00')
end

-- keeps only {x,y,z} entries that are all numbers
function PB.points(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, p in ipairs(list) do
        if type(p) == 'table' then
            local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
            if x and y and z and x == x and y == y and z == z then
                out[#out + 1] = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
            end
        end
    end
    return out
end

-- player-typed text: control characters and < > @ ` removed, trimmed, capped
function PB.cleanText(s, max)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('[%c<>@`]', '')
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if max and #s > max then s = s:sub(1, max) end
    return s
end

-- lower-case job code with a-z 0-9 _ only (empty when nothing is left)
function PB.jobCode(s)
    if type(s) ~= 'string' then return '' end
    s = s:lower():gsub('[^a-z0-9_]', '')
    if #s > 50 then s = s:sub(1, 50) end
    return s
end

-- "just now", "5m ago", "3h ago", "2d ago", "never"
function PB.ago(ts, now)
    ts = tonumber(ts) or 0
    if ts <= 0 then return 'never' end
    local d = (tonumber(now) or ts) - ts
    if d < 60 then return 'just now' end
    if d < 3600 then return ('%dm ago'):format(d // 60) end
    if d < 86400 then return ('%dh ago'):format(d // 3600) end
    return ('%dd ago'):format(d // 86400)
end
