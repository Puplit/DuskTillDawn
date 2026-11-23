-- pup_mercantile | server plumbing: VORP core, characters, money, notices

local RES <const> = GetCurrentResourceName()
Inv = exports.vorp_inventory

local Core
CreateThread(function()
    for _ = 1, 40 do
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        if ok and c then Core = c return end
        Wait(250)
    end
    print('^1[pup_mercantile]^7 vorp_core did not answer - stores cannot work.')
end)

function Dbg(...)
    if Config.Debug then print('^5[pup_mercantile]^7', ...) end
end

function GetCoreObj() return Core end

-- the player's VORP user and active character, or nil
function GetChar(src)
    src = tonumber(src)
    if not Core or not src or src <= 0 then return nil end
    local user = Core.getUser(src)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char or not char.charIdentifier then return nil end
    return char, user
end

function CharId(src)
    local c = GetChar(src)
    return c and tonumber(c.charIdentifier) or nil
end

function IsAdmin(src)
    if tonumber(src) == 0 then return true end
    if not Core then return false end
    local user = Core.getUser(src)
    return user ~= nil and user.getGroup == 'admin'
end

function Cash(src)
    local c = GetChar(src)
    return c and Util.round2(c.money or 0) or 0
end

-- takes cash only when the live character really holds it
function TakeCash(src, amount)
    amount = Util.round2(amount)
    if amount <= 0 then return true end
    local c = GetChar(src)
    if not c or Util.round2(c.money or 0) < amount then return false end
    c.removeCurrency(0, amount)
    return true
end

function GiveCash(src, amount)
    amount = Util.round2(amount)
    if amount <= 0 then return true end
    local c = GetChar(src)
    if not c then return false end
    c.addCurrency(0, amount)
    return true
end

function Notify(src, text, ms)
    if not src or src <= 0 then
        print('[pup_mercantile] ' .. tostring(text))
        return
    end
    TriggerClientEvent('vorp:TipBottom', src, tostring(text), ms or 4000)
end

function PlayerPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0.0 and c.y == 0.0 and c.z == 0.0) then return nil end
    return { x = c.x, y = c.y, z = c.z }
end

function FullName(char)
    if not char then return '?' end
    return ((char.firstname or '') .. ' ' .. (char.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

function DiscordId(src)
    local id = GetPlayerIdentifierByType(tostring(src), 'discord')
    if not id then return nil end
    id = id:gsub('^discord:', '')
    if id == '' or id == '0' then return nil end
    return id
end

function OnlineByCharId(charid)
    charid = tonumber(charid)
    if not charid or not Core then return nil end
    for _, pid in ipairs(GetPlayers()) do
        local c = GetChar(tonumber(pid))
        if c and tonumber(c.charIdentifier) == charid then return tonumber(pid) end
    end
    return nil
end

-- calls a function that may hang (another resource), giving up after ms
function WithTimeout(ms, fn, ...)
    local args = table.pack(...)
    local p = promise.new()
    local done = false
    CreateThread(function()
        local res = table.pack(pcall(fn, table.unpack(args, 1, args.n)))
        if not done then done = true p:resolve(res) end
    end)
    SetTimeout(ms, function()
        if not done then done = true p:resolve({ false, 'timeout', n = 2 }) end
    end)
    local res = Citizen.Await(p)
    return table.unpack(res, 1, res.n)
end

function ResourceUp(name)
    return name and GetResourceState(name) == 'started'
end

function ResName() return RES end
