-- Shared server helpers: core access, staff check, validation, throttles.

PH = PH or {}
PH.Res = GetCurrentResourceName()

local Core = exports.vorp_core:GetCore()
PH.Core = Core

local warned = {}
function PH.WarnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(PH.Res, msg))
end

-- the vorp_core user and selected character, or nil when there is no character
function PH.GetChar(src)
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if type(char) ~= 'table' or char.charIdentifier == nil then return nil end
    local charId = tonumber(char.charIdentifier)
    if not charId or charId <= 0 then return nil end
    return char, user
end

function PH.IsStaff(src)
    local user = Core.getUser(src)
    if not user then return false end
    return Config.StaffGroups[user.getGroup] == true
end

function PH.Tip(src, text, ms)
    TriggerClientEvent('vorp:TipRight', src, text, ms or 3000)
end

function PH.IsFinite(n)
    return type(n) == 'number' and n == n and n ~= math.huge and n ~= -math.huge
end

local function readVec(v)
    local t = type(v)
    if t ~= 'table' and t ~= 'vector3' then return nil end
    local x, y, z = tonumber(v.x), tonumber(v.y), tonumber(v.z)
    for _, n in ipairs({ x, y, z }) do
        if not PH.IsFinite(n) or math.abs(n) >= 100000 then return nil end
    end
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0 }
end
PH.ReadVec = readVec

function PH.Clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function PH.CleanVolume(v)
    v = tonumber(v)
    if not PH.IsFinite(v) then return Config.DefaultVolume end
    return PH.Clamp(v, 0.0, 1.0)
end

function PH.CleanRadius(r)
    r = tonumber(r)
    if not PH.IsFinite(r) then return Config.Radius.default end
    return PH.Clamp(r, Config.Radius.min, Config.Radius.max)
end

-- a positive integer id, or nil
function PH.ReadId(v)
    v = tonumber(v)
    if not PH.IsFinite(v) or v < 1 or v ~= math.floor(v) or v > 4294967295 then return nil end
    return math.floor(v)
end

function PH.PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function PH.DistTo(src, pos)
    local p = PH.PlayerPos(src)
    if not p then return math.huge end
    local dx, dy, dz = p.x - pos.x, p.y - pos.y, p.z - pos.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- per-player, per-key timers (milliseconds)
local stamps = {}

-- true and stamp when the key is free; false while it is cooling down
function PH.Throttle(src, key, ms)
    local now = GetGameTimer()
    local t = stamps[src]
    if not t then t = {}; stamps[src] = t end
    local last = t[key]
    if last and now - last < ms then return false end
    t[key] = now
    return true
end

-- the same check without stamping (stamp later with PH.Stamp)
function PH.Cooling(src, key, ms)
    local t = stamps[src]
    local last = t and t[key]
    return last ~= nil and GetGameTimer() - last < ms
end

function PH.Stamp(src, key)
    local t = stamps[src]
    if not t then t = {}; stamps[src] = t end
    t[key] = GetGameTimer()
end

function PH.Unstamp(src, key)
    local t = stamps[src]
    if t then t[key] = nil end
end

function PH.ForgetPlayer(src)
    stamps[src] = nil
end

-- link checks ---------------------------------------------------------------

-- the lower-case host of an http(s) link with a clean host, or nil
local function linkHost(url)
    if type(url) ~= 'string' or url == '' or #url > Config.MaxLinkLength then return nil end
    if url:find('[%c%s]') then return nil end
    local lower = url:lower()
    local rest
    if lower:sub(1, 7) == 'http://' then
        rest = lower:sub(8)
    elseif lower:sub(1, 8) == 'https://' then
        rest = lower:sub(9)
    else
        return nil
    end
    local host = rest:match('^([^/:%?#]*)') or ''
    if host == '' or host:find('[^%w%.%-]') then return nil end
    return host
end

function PH.IsWebLink(url)
    return linkHost(url) ~= nil
end

function PH.SiteApproved(url)
    local host = linkHost(url)
    if not host then return false end
    for _, site in ipairs(Config.ApprovedSites) do
        site = tostring(site):lower()
        if host == site then return true end
        local tail = '.' .. site
        if #host > #tail and host:sub(-#tail) == tail then return true end
    end
    return false
end

-- vorp_inventory wrappers (direct exports, guarded) --------------------------

local function inv(fn, ...)
    local ok, r = pcall(function(...)
        local res = exports.vorp_inventory
        return res[fn](res, ...)
    end, ...)
    if not ok then
        PH.WarnOnce('inv:' .. fn, ('vorp_inventory export %s failed: %s'):format(fn, tostring(r)))
        return nil
    end
    return r
end

function PH.ItemCount(src, item)
    return tonumber(inv('getItemCount', src, nil, item)) or 0
end

function PH.CanCarry(src, item, n)
    return inv('canCarryItem', src, item, n) == true
end

function PH.TakeItem(src, item, n)
    return inv('subItem', src, item, n) == true
end

function PH.GiveItem(src, item, n)
    return inv('addItem', src, item, n) == true
end

function PH.CloseInventory(src)
    inv('closeInventory', src)
end
