-- pup_postoffice | server helpers shared by every server file

PO = PO or {} -- server/config.lua loads first and has already put PO.secrets here

local Core = exports.vorp_core:GetCore()
PO.Core = Core

-- per-player state: { charid, box (number | false when known to have none), bucket = {}, lastSend, sending,
-- registering, lastPost, lastMailboxReq }
PO.players = {}

function PO.player(src)
    local p = PO.players[src]
    if not p then
        p = { bucket = {} }
        PO.players[src] = p
    end
    return p
end

function PO.forget(src)
    PO.players[src] = nil
end

--------------------------------------------------------------------------------
-- text

function PO.trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:match('^%s*(.-)%s*$'))
end

--- Cut a string to at most `max` bytes without leaving half a UTF-8 character at the end.
function PO.cutBytes(s, max)
    if type(s) ~= 'string' then s = (s ~= nil) and tostring(s) or '' end
    if #s <= max then return s end
    local cut = max
    while cut > 0 do
        local nextByte = s:byte(cut + 1)
        if not nextByte or nextByte < 0x80 or nextByte >= 0xC0 then break end
        cut = cut - 1
    end
    return s:sub(1, cut)
end

function PO.isoNow()
    return os.date('!%Y-%m-%dT%H:%M:%S') .. '.000Z'
end

function PO.toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    n = math.floor(n)
    return n
end

--- A list of whole numbers from a client list, at most `cap` long, duplicates removed.
function PO.idList(list, cap)
    local out, seen = {}, {}
    if type(list) ~= 'table' then return out end
    for _, v in ipairs(list) do
        if #out >= cap then break end
        local n = PO.toInt(v)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
        end
    end
    return out
end

function PO.placeholders(n)
    return ('?,'):rep(n):sub(1, -2)
end

function PO.truthy(v)
    return v == true or v == 1 or v == '1'
end

function PO.decodeList(raw)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, value = pcall(json.decode, raw)
    if not ok or type(value) ~= 'table' then return {} end
    local out = {}
    for _, v in ipairs(value) do out[#out + 1] = tostring(v) end
    return out
end

--------------------------------------------------------------------------------
-- players

function PO.tip(src, msg, ms)
    TriggerClientEvent('vorp:TipRight', src, msg, ms or 4000)
end

function PO.tipBottom(src, msg, ms)
    TriggerClientEvent('vorp:TipBottom', src, msg, ms or 4000)
end

function PO.getChar(src)
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' then return nil end
    local cid = PO.toInt(char.charIdentifier)
    if not cid or cid <= 0 then return nil end
    return char, cid
end

function PO.charName(char)
    if not char then return '' end
    local name = PO.trim(('%s %s'):format(char.firstname or '', char.lastname or ''))
    return name
end

--- Valid net event source with a loaded character. Returns src, char, charid.
function PO.caller(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    if not GetPlayerName(src) then return nil end
    local char, cid = PO.getChar(src)
    if not char then return nil end
    return src, char, cid
end

--- Simple bucket limiter: at most `max` calls per `windowMs` for one player and key.
function PO.allow(src, key, max, windowMs)
    local p = PO.player(src)
    local now = GetGameTimer()
    local b = p.bucket[key]
    if not b or now - b.start >= windowMs then
        p.bucket[key] = { start = now, n = 1 }
        return true
    end
    if b.n >= max then return false end
    b.n = b.n + 1
    return true
end

--------------------------------------------------------------------------------
-- secrets (set in server/config.lua)

PO.secrets = PO.secrets or {}

function PO.secret(group, key)
    local g = PO.secrets[group]
    if type(g) ~= 'table' then return nil end
    local v = g[key]
    if type(v) ~= 'string' or v == '' then return nil end
    return v
end

--------------------------------------------------------------------------------
-- database: thin guards so one bad query never kills a handler

function PO.query(sql, params)
    local ok, res = pcall(MySQL.query.await, sql, params or {})
    if not ok then
        print(('[pup_postoffice] query failed: %s'):format(tostring(res)))
        return nil
    end
    return res
end

function PO.single(sql, params)
    local ok, res = pcall(MySQL.single.await, sql, params or {})
    if not ok then
        print(('[pup_postoffice] query failed: %s'):format(tostring(res)))
        return nil
    end
    return res
end

function PO.scalar(sql, params)
    local ok, res = pcall(MySQL.scalar.await, sql, params or {})
    if not ok then
        print(('[pup_postoffice] query failed: %s'):format(tostring(res)))
        return nil
    end
    return res
end

function PO.insert(sql, params)
    local ok, res = pcall(MySQL.insert.await, sql, params or {})
    if not ok then
        print(('[pup_postoffice] insert failed: %s'):format(tostring(res)))
        return nil
    end
    return res
end

--- Insert one row from an ordered list of { column, value }. A nil value is written as a literal NULL,
--- because a nil inside a Lua parameter array would cut the array short on its way to oxmysql.
function PO.insertRow(tbl, cols)
    local names, marks, params = {}, {}, {}
    for _, c in ipairs(cols) do
        names[#names + 1] = '`' .. c[1] .. '`'
        if c[2] == nil then
            marks[#marks + 1] = 'NULL'
        else
            marks[#marks + 1] = '?'
            params[#params + 1] = c[2]
        end
    end
    return PO.insert(('INSERT INTO `%s` (%s) VALUES (%s)'):format(tbl, table.concat(names, ', '), table.concat(marks, ', ')), params)
end

--- Returns affected rows, or nil on error.
function PO.update(sql, params)
    local ok, res = pcall(MySQL.update.await, sql, params or {})
    if not ok then
        print(('[pup_postoffice] update failed: %s'):format(tostring(res)))
        return nil
    end
    return tonumber(res) or 0
end

--------------------------------------------------------------------------------
-- offices

function PO.nearOffice(src)
    -- props can stand anywhere and the server cannot see them
    if Config.MailboxProps.enabled then return true end
    -- without OneSync (or before the ped streams in) the position is unknown; Config decides what that means
    local unknown = Config.PassWhenNoPosition ~= false
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return unknown end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then return unknown end
    local reach = Config.ServerReach
    for _, office in ipairs(Config.Offices) do
        if #(c - office.coords) <= reach then return true end
    end
    return false
end
