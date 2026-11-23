-- pup_tailor | small helpers shared by client and server. Pure Lua, no natives.
Tailor = Tailor or {}
local U = {}
Tailor.U = U

local TWO32 <const> = 4294967296

-- whole number or nil (accepts 3.0, refuses 3.5 / nan / inf / strings)
function U.int(v)
    if type(v) ~= 'number' then return nil end
    if v ~= v or v == math.huge or v == -math.huge then return nil end
    return math.tointeger(v)
end

-- a 32-bit hash in its unsigned form (0..2^32-1), or nil
function U.unsigned(v)
    local n = U.int(v)
    if not n then return nil end
    if n < 0 then n = n + TWO32 end
    if n < 0 or n >= TWO32 then return nil end
    return n
end

-- a 32-bit hash in its signed form (-2^31..2^31-1), or nil
function U.signed(v)
    local n = U.unsigned(v)
    if not n then return nil end
    if n >= 2147483648 then n = n - TWO32 end
    return n
end

-- a garment value that means "something is worn here"
function U.isReal(v)
    local n = U.int(v)
    return n ~= nil and n ~= -1 and n ~= 0
end

function U.isMap(t)
    return type(t) == 'table' and next(t) ~= nil and t[1] == nil
end

function U.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

function U.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = U.copy(v) end
    return out
end

-- cut a string to at most maxBytes without leaving half a UTF-8 character at the end
function U.cutUtf8(s, maxBytes)
    if #s <= maxBytes then return s end
    local cut = maxBytes
    -- step back over continuation bytes (10xxxxxx) to the lead byte
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return s:sub(1, cut)
end

-- player text: no control characters, optionally no < >, trimmed, cut UTF-8 safely
function U.cleanText(s, maxBytes, stripAngles)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('%c', '')
    if stripAngles then s = s:gsub('[<>]', '') end
    s = s:match('^%s*(.-)%s*$') or ''
    s = U.cutUtf8(s, maxBytes)
    -- the cut can expose trailing spaces
    s = s:match('^(.-)%s*$') or ''
    return s
end

function U.trim(s)
    if type(s) ~= 'string' then return '' end
    return s:match('^%s*(.-)%s*$') or ''
end

-- decode a JSON string that must hold an object; returns the table or nil
function U.decodeMap(s)
    if type(s) == 'table' then return s end
    if type(s) ~= 'string' or s == '' then return nil end
    local ok, t = pcall(json.decode, s)
    if not ok or type(t) ~= 'table' then return nil end
    if t[1] ~= nil then return nil end
    return t
end

-- "%d" of a whole number, used for hash keys in JSON maps
function U.hashKey(v)
    local n = U.int(v)
    if not n then return tostring(v) end
    return string.format('%d', n)
end
