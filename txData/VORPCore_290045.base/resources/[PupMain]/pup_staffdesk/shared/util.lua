-- pup_staffdesk | helpers used on both sides
Desk = Desk or {}

-- 1234.5 -> "1,234.50"
function Desk.money(n)
    local s = ('%.2f'):format(tonumber(n) or 0)
    local sign, int, dec = s:match('^(-?)(%d+)%.(%d+)$')
    int = int:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return sign .. int .. '.' .. dec
end

-- seconds -> "3 days" / "5 hours" / "12 min"
function Desk.wait(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    if d >= 1 then return d .. (d == 1 and ' day' or ' days') end
    local h = math.floor(seconds / 3600)
    if h >= 1 then return h .. (h == 1 and ' hour' or ' hours') end
    return math.max(1, math.floor(seconds / 60)) .. ' min'
end

-- 12.75 hours -> "12 h 45 min"
function Desk.hours(h)
    h = tonumber(h) or 0
    if h <= 0 then return '0 min' end
    local whole = math.floor(h)
    local mins = math.floor((h - whole) * 60 + 0.5)
    if mins == 60 then whole, mins = whole + 1, 0 end
    if whole == 0 then return mins .. ' min' end
    if mins == 0 then return whole .. ' h' end
    return ('%d h %d min'):format(whole, mins)
end

function Desk.trim(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- cash parcels are kept to the cent
function Desk.cents(n)
    n = tonumber(n)
    if not n then return nil end
    return math.floor(n * 100 + 0.5) / 100
end
