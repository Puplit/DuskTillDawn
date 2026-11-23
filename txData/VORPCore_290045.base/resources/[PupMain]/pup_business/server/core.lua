-- pup_business | server basics: core object, characters, admin checks, throttles

Core = exports.vorp_core:GetCore()
RES = GetCurrentResourceName()

function Dbg(...)
    if not Config.Debug then return end
    local parts = {}
    for i = 1, select('#', ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print(('[%s] %s'):format(RES, table.concat(parts, ' ')))
end

---------------------------------------------------------------------------
-- characters
---------------------------------------------------------------------------

-- the selected character of a player (a fresh snapshot every call), or nil
function GetChar(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local ch = user.getUsedCharacter
    if type(ch) ~= 'table' or not ch.charIdentifier then return nil end
    return ch, user
end

-- the same, but only while the player still plays the given character
function GetCharIf(src, charid)
    local ch, user = GetChar(src)
    if not ch or tonumber(ch.charIdentifier) ~= tonumber(charid) then return nil end
    return ch, user
end

function CharId(ch) return tonumber(ch and ch.charIdentifier) end
function CharGrade(ch) return tonumber(ch and ch.jobGrade) or 0 end

function FullName(ch)
    if not ch then return '' end
    local n = ((ch.firstname or '') .. ' ' .. (ch.lastname or ''))
    n = n:gsub('^%s+', ''):gsub('%s+$', '')
    return n
end

-- server id of the player currently on a character, or nil
function SourceOfChar(charid)
    charid = tonumber(charid)
    if not charid then return nil end
    for _, s in ipairs(GetPlayers()) do
        local ch = GetChar(s)
        if ch and CharId(ch) == charid then return tonumber(s) end
    end
    return nil
end

function Notify(src, text, ms)
    src = tonumber(src)
    if not src or src <= 0 then return end
    TriggerClientEvent('vorp:TipRight', src, tostring(text), ms or 4000)
end

---------------------------------------------------------------------------
-- admin checks
---------------------------------------------------------------------------

function GroupOf(src)
    local user = Core.getUser(tonumber(src))
    return user and user.getGroup or 'user'
end

-- the plain VORP admin group, accepted directly by several actions
function IsGroupAdmin(src)
    return Config.GroupAdminShortcuts and GroupOf(src) == 'admin'
end

function VorpAdminAllows(src, action)
    if GetResourceState('vorp_admin') ~= 'started' then return false end
    local ok, res = pcall(function() return exports.vorp_admin:allowedToExecuteAction(src, action) end)
    return ok and res == true
end

-- business-management rules
function IsSocietyAdmin(src)
    if VorpAdminAllows(src, 'manage_society') then return true end
    return Config.AdminBypass == true and GroupOf(src) == 'admin'
end

-- the VORP admin groups and anyone vorp_admin allows 'manage_society'
function IsServerPanelAdmin(src)
    local g = GroupOf(src)
    if g == 'admin' or g == 'superadmin' then return true end
    return VorpAdminAllows(src, 'manage_society')
end

-- a character in Config.PanelAdminJobs at Config.PanelAdminMinGrade or higher
function IsJobPanelAdmin(src)
    local ch = GetChar(src)
    if not ch or Config.PanelAdminJobs[ch.job] ~= true then return false end
    local min = Config.PanelAdminMinGrade
    if min == 'boss' then return IsBossGrade(ch.job, CharGrade(ch)) end
    min = tonumber(min)
    return min ~= nil and CharGrade(ch) >= min
end

-- the admin tool and the vorp_admin bridge
function IsPanelAdmin(src)
    return IsServerPanelAdmin(src) or IsJobPanelAdmin(src)
end

function IsManagement(src)
    return VorpAdminAllows(src, 'delete_society')
end

---------------------------------------------------------------------------
-- throttles and locks
---------------------------------------------------------------------------

local stamps = {}

-- true when the player may do `key` now; false while still inside `ms`
function Throttle(src, key, ms)
    local now = GetGameTimer()
    local t = stamps[src]
    if not t then t = {}; stamps[src] = t end
    local last = t[key]
    if last and now - last < ms then return false end
    t[key] = now
    return true
end

local locks = {}

function Lock(key)
    if locks[key] then return false end
    locks[key] = true
    return true
end

function Unlock(key) locks[key] = nil end

AddEventHandler('playerDropped', function()
    stamps[source] = nil
end)

---------------------------------------------------------------------------
-- positions (OneSync); nil when the server cannot see the ped
---------------------------------------------------------------------------

function PedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then return nil end
    return c
end

-- distance check that passes when positions are unknown
function WithinOrUnknown(a, b, dist)
    local pa, pb = PedCoords(a), PedCoords(b)
    if not pa or not pb then return true end
    return #(pa - pb) <= dist
end

function Now() return os.time() end

function FormatDate(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return '-' end
    return os.date('%Y-%m-%d %H:%M', ts)
end
