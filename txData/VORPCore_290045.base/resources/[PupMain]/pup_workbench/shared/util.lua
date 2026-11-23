-- Small helpers used on both sides.
WB = WB or {}

--- Remove every whitespace character.
function WB.nospace(s)
    if type(s) ~= 'string' and type(s) ~= 'number' then return '' end
    return (tostring(s):gsub('%s', ''))
end

function WB.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Cut to at most n bytes without splitting a UTF-8 character.
function WB.cut(s, n)
    s = tostring(s or '')
    if #s <= n then return s end
    local i = n
    while i > 0 and ((s:byte(i + 1) or 0) & 0xC0) == 0x80 do i = i - 1 end
    return s:sub(1, i)
end

--- Whole number, or nil when the value is not a finite number.
function WB.int(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.floor(n)
end

--- A database flag as a boolean. oxmysql returns tinyint(1) columns as true/false
--- and wider tinyint columns as numbers, so both must be read.
function WB.flag(v)
    if type(v) == 'boolean' then return v end
    local n = tonumber(v)
    return n ~= nil and n ~= 0
end

--- "Ns" under a minute, "Nm Ns" under an hour, otherwise "Nh Nm".
function WB.fmtTime(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    if sec < 60 then return ('%ds'):format(sec) end
    if sec < 3600 then return ('%dm %ds'):format(sec // 60, sec % 60) end
    return ('%dh %dm'):format(sec // 3600, (sec % 3600) // 60)
end

--- Does the text contain a banned word? Case-insensitive plain match.
function WB.hasBannedWord(text)
    if type(text) ~= 'string' or text == '' then return false end
    local low = text:lower()
    for _, w in ipairs(Config.Descriptions.bannedWords or {}) do
        local word = tostring(w):lower()
        if word ~= '' then
            if Config.Descriptions.wholeWordsOnly then
                local pat = '%f[%w]' .. word:gsub('%W', '%%%0') .. '%f[%W]'
                if low:find(pat) then return true end
            elseif low:find(word, 1, true) then
                return true
            end
        end
    end
    return false
end

--- Accept a list, a single value, 0, "0" or empty; return a list of strings or nil.
function WB.nameList(v)
    if v == nil or v == 0 or v == '0' or v == '' or v == false then return nil end
    local out = {}
    if type(v) == 'table' then
        for _, x in pairs(v) do
            if type(x) == 'string' or type(x) == 'number' then
                local s = WB.nospace(x)
                if s ~= '' and s ~= '0' then out[#out + 1] = s end
            end
        end
    elseif type(v) == 'string' then
        for part in v:gmatch('[^,]+') do
            local s = WB.nospace(part)
            if s ~= '' and s ~= '0' then out[#out + 1] = s end
        end
    else
        return nil
    end
    if #out == 0 then return nil end
    return out
end

function WB.listHas(list, value)
    if not list then return false end
    for _, x in ipairs(list) do
        if x == value then return true end
    end
    return false
end

--- Item picture from vorp_inventory's item image folder.
function WB.itemImage(name)
    return ('nui://vorp_inventory/html/img/items/%s.png'):format(tostring(name or ''))
end

function WB.categoryByKey(key)
    for i, c in ipairs(Config.Categories) do
        if c.key == key then return c, i end
    end
    return nil
end

function WB.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
