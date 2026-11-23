-- Helpers used on both sides.

TP = TP or {}

TP.Res = GetCurrentResourceName()

-- markets by key (keys are case-sensitive and stored in the database)
TP.MarketByKey = {}
for i, m in ipairs(Config.Markets) do
    m.index = i
    TP.MarketByKey[m.key] = m
end

function TP.MarketName(key)
    local m = TP.MarketByKey[key]
    if m then return m.name end
    return tostring(key or '')
end

-- whole cents from a dollar value (nil when not a finite number)
function TP.ToCents(value)
    local n = tonumber(value)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.floor(n * 100 + 0.5)
end

function TP.FromCents(cents)
    return (tonumber(cents) or 0) / 100
end

-- "1,234.50"
function TP.Money(value)
    local cents = TP.ToCents(value) or 0
    local neg = cents < 0
    if neg then cents = -cents end
    local whole = tostring(cents // 100)
    local frac = string.format('%02d', cents % 100)
    local grouped = whole:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    if grouped:sub(1, 1) == ',' then grouped = grouped:sub(2) end
    return (neg and '-' or '') .. grouped .. '.' .. frac
end

-- true for an integer-valued finite number
function TP.IsWhole(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge and math.floor(n) == n
end

function TP.ItemImage(name)
    return string.format(Config.ItemImage, tostring(name or ''))
end

function TP.Debug(...)
    if not Config.Debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print('[pup_tradepost] ' .. table.concat(parts, ' '))
end
