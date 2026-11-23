-- pup_gunsmith | small shared helpers (client and server)

GS = GS or {}
GS.RES = GetCurrentResourceName()

function GS.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- every whitespace character removed
function GS.noSpace(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('%s', ''))
end

function GS.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- a whole number from anything; nil when it isn't a finite number
function GS.int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.floor(n)
end

function GS.inList(list, value)
    if type(list) ~= 'table' or value == nil then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

-- "a, b ,c" or { 'a', 'b' } -> { 'a', 'b', 'c' } (whitespace removed, empties dropped)
function GS.splitJobs(v)
    local out = {}
    if type(v) == 'table' then
        for _, j in ipairs(v) do
            local s = GS.noSpace(tostring(j))
            if s ~= '' then out[#out + 1] = s end
        end
        return out
    end
    if type(v) ~= 'string' then return out end
    for part in GS.noSpace(v):gmatch('[^,]+') do
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

function GS.count(t)
    local n = 0
    if type(t) == 'table' then for _ in pairs(t) do n = n + 1 end end
    return n
end

function GS.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = GS.copy(v) end
    return out
end

-- "$12.50" / "$12" (".00" dropped)
function GS.dollars(n)
    n = tonumber(n) or 0
    local s = ('%.2f'):format(n)
    s = s:gsub('%.00$', '')
    return '$' .. s
end

-- 12345 -> "12,345"
function GS.thousands(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local sign, digits = s:match('^(-?)(%d+)$')
    if not digits then return s end
    local out = digits:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    out = out:gsub('^,', '')
    return sign .. out
end

-- strips control characters and < > " ` \ (and optionally '), then trims
function GS.cleanText(s, alsoQuote)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('%c', '')
    s = s:gsub('[<>"`\\]', '')
    if alsoQuote then s = s:gsub("'", '') end
    return GS.trim(s)
end

-- UTF-8 aware cut to at most n characters
function GS.cut(s, n)
    if type(s) ~= 'string' then return '' end
    local ok, len = pcall(utf8.len, s)
    if not ok or not len then return s:sub(1, n) end
    if len <= n then return s end
    local stop = utf8.offset(s, n + 1)
    return stop and s:sub(1, stop - 1) or s
end

-- a parts set ({ CATEGORY = 'COMPONENT_NAME' }) with junk removed and at most `max` entries.
-- Old rows hold things like { nothing = 0 } or array entries; those are skipped.
function GS.cleanParts(t, max)
    local out, n = {}, 0
    if type(t) ~= 'table' then return out end
    local keys = {}
    for k in pairs(t) do
        if type(k) == 'string' then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local v = t[k]
        if type(v) == 'string' and v ~= '' and v:lower() ~= 'nothing' and k:match('^[%w_]+$') and v:match('^[%w_]+$') then
            n = n + 1
            if max and n > max then break end
            out[k:upper()] = v:upper()
        end
    end
    return out
end

function GS.sameParts(a, b)
    a, b = a or {}, b or {}
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

function GS.itemImage(name)
    return Config.ItemImage:format(tostring(name or ''))
end
