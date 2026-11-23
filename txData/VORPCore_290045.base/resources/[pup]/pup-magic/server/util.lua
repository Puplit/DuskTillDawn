-- pup-magic | small server helpers shared by every server file

Core = exports.vorp_core:GetCore()

local RES <const> = GetCurrentResourceName()
local warned = {}

function WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RES, msg))
end

-- a connected player id, as an integer, or nil
function PlayerIdOf(v)
    local n = math.tointeger(tonumber(v))
    if not n or n <= 0 then return nil end
    local name = GetPlayerName(n)
    if not name or name == '' then return nil end
    return n
end

function Online(src)
    return PlayerIdOf(src) ~= nil
end

-- the live character: { id = charidentifier, first, last } or nil
function CharOf(src)
    if not Online(src) then return nil end
    local ok, user = pcall(Core.getUser, src)
    if not ok or type(user) ~= 'table' then return nil end
    local c = user.getUsedCharacter
    if type(c) ~= 'table' then return nil end
    local id = math.tointeger(tonumber(c.charIdentifier))
    if not id or id <= 0 then return nil end
    return { id = id, first = c.firstname, last = c.lastname }
end

function PosOf(src)
    if not Online(src) then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetEntityCoords(ped)
end

function AtOrigin(p)
    return math.abs(p.x) < 1.0 and math.abs(p.y) < 1.0 and math.abs(p.z) < 1.0
end

-- true when both players have peds and stand within `max` metres
function PlayersWithin(a, b, max)
    local pa, pb = PosOf(a), PosOf(b)
    if not pa or not pb then return false end
    return #(pa - pb) <= (tonumber(max) or 0)
end

-- x, y, z from a plain table (or a vector) the client sent; nil when any is missing or not finite
function PointOf(t)
    local kind = type(t)
    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z then return nil end
    for _, v in ipairs({ x, y, z }) do
        if v ~= v or v == math.huge or v == -math.huge or math.abs(v) > 100000 then return nil end
    end
    return vector3(x, y, z)
end

function TipRight(src, text, ms)
    if type(text) ~= 'string' or text == '' or not Online(src) then return end
    TriggerClientEvent('vorp:TipRight', src, text, ms or 3000)
end

function TipBottom(src, text, ms)
    if type(text) ~= 'string' or text == '' or not Online(src) then return end
    TriggerClientEvent('vorp:TipBottom', src, text, ms or 4000)
end

-- true (and stamps the time) when the last stamp in `bucket` for `src` is at least `ms` old
function Throttle(bucket, src, ms)
    local now = GetGameTimer()
    local last = bucket[src]
    if last and now - last < ms then return false end
    bucket[src] = now
    return true
end

function Trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- for text the inventory shows as HTML
function EscapeHtml(s)
    return (tostring(s):gsub('[&<>"\']', {
        ['&'] = '&amp;', ['<'] = '&lt;', ['>'] = '&gt;', ['"'] = '&quot;', ["'"] = '&#39;',
    }))
end

function ConnectedPlayers()
    local out = {}
    for _, p in ipairs(GetPlayers()) do
        local id = math.tointeger(tonumber(p))
        if id then out[#out + 1] = id end
    end
    return out
end

-- vorp_inventory, each call guarded: a missing export or a throw counts as "no"
Inv = {}

function Inv.canCarry(src, item, count)
    local ok, res = pcall(function() return exports.vorp_inventory:canCarryItem(src, item, count) end)
    if not ok then WarnOnce('inv.canCarry', 'vorp_inventory canCarryItem failed: ' .. tostring(res)) return false end
    return res == true
end

function Inv.add(src, item, count, metadata)
    local ok, res = pcall(function() return exports.vorp_inventory:addItem(src, item, count, metadata) end)
    if not ok then WarnOnce('inv.add', 'vorp_inventory addItem failed: ' .. tostring(res)) return false end
    return res == true
end

function Inv.count(src, item)
    local ok, res = pcall(function() return exports.vorp_inventory:getItemCount(src, nil, item) end)
    if not ok then WarnOnce('inv.count', 'vorp_inventory getItemCount failed: ' .. tostring(res)) return 0 end
    return tonumber(res) or 0
end

function Inv.items(src)
    local ok, res = pcall(function() return exports.vorp_inventory:getUserInventoryItems(src) end)
    if not ok then WarnOnce('inv.items', 'vorp_inventory getUserInventoryItems failed: ' .. tostring(res)) return {} end
    return type(res) == 'table' and res or {}
end

function Inv.removeById(src, id)
    local ok, res = pcall(function() return exports.vorp_inventory:subItemID(src, id) end)
    if not ok then WarnOnce('inv.sub', 'vorp_inventory subItemID failed: ' .. tostring(res)) return false end
    return res == true
end

function Inv.close(src)
    local ok, res = pcall(function() return exports.vorp_inventory:closeInventory(src) end)
    if not ok then WarnOnce('inv.close', 'vorp_inventory closeInventory failed: ' .. tostring(res)) end
end
