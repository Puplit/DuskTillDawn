-- goldpan | server core: integrations, the usable item, pan sessions
-- the client only asks; the server checks the pan, the water, the timing and the position

Srv = {}

local RES <const> = GetCurrentResourceName()

local warned = {}
function Srv.warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[%s]^7 %s'):format(RES, msg))
end

math.randomseed(os.time() + GetGameTimer())

------------------------------------------------------------------------------- vorp_core
local core
local function getCore()
    if core then return core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and type(c) == 'table' then core = c
    else Srv.warnOnce('core', 'vorp_core GetCore failed: ' .. tostring(c)) end
    return core
end

-- the selected character, or nil
function Srv.character(src)
    local c = getCore()
    if not c or type(src) ~= 'number' or src <= 0 then return nil end
    local ok, char = pcall(function()
        local user = c.getUser(src)
        return user and user.getUsedCharacter
    end)
    if not ok or type(char) ~= 'table' or char.charIdentifier == nil then return nil end
    return char
end

------------------------------------------------------------------------------- vorp_inventory
local function inv(name, ...)
    local args = table.pack(...)
    local ok, result = pcall(function()
        local api = exports.vorp_inventory
        return api[name](api, table.unpack(args, 1, args.n))
    end)
    if not ok then
        Srv.warnOnce('inv_' .. name, ('vorp_inventory %s failed: %s'):format(name, tostring(result)))
        return nil
    end
    return result
end

function Srv.hasPan(src)
    return (tonumber(inv('getItemCount', src, nil, Config.PanItem)) or 0) >= 1
end

-- carry checks, then add; true when the item was given
function Srv.give(src, item, amount)
    if inv('canCarryItems', src, amount) == false then return false end
    if inv('canCarryItem', src, item, amount) ~= true then return false end
    return inv('addItem', src, item, amount) == true
end

------------------------------------------------------------------------------- pup-perks (optional)
local function perks(name, ...)
    if GetResourceState('pup-perks') ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        local api = exports['pup-perks']
        return api[name](api, table.unpack(args, 1, args.n))
    end)
    if not ok then
        Srv.warnOnce('perks_' .. name, ('pup-perks %s failed: %s'):format(name, tostring(result)))
        return nil
    end
    return result
end

function Srv.panLuck(src)
    local v = tonumber(perks('Bonus', src, 'pan_luck')) or 0
    if v ~= v then return 0 end
    return v
end

function Srv.award(src)
    perks('Award', src, 'pan')
end

------------------------------------------------------------------------------- messages
function Srv.toast(src, title, subtitle, tone, ms)
    if GetResourceState('pup-ui') == 'started' then
        TriggerClientEvent('pup-ui:toast', src, { title = title, subtitle = subtitle, tone = tone, duration = ms })
    else
        TriggerClientEvent('vorp:TipRight', src, subtitle and (title .. ' ' .. subtitle) or title, ms)
    end
end

function Srv.say(src, key)
    Srv.toast(src, GP.msg(key), nil, GP.toneOf(key), GP.msOf(key))
end

------------------------------------------------------------------------------- sessions
Srv.Sessions = {} -- [src] = { token, water, at, pos, charId }
Srv.LastPaid = {} -- [src] = game timer of the last paid pan
local lastBegin = {}

local function newToken()
    return ('%08x%08x%08x'):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff), GetGameTimer() & 0x7fffffff)
end

function Srv.cooledDown(src)
    local last = Srv.LastPaid[src]
    return not last or GetGameTimer() - last >= (tonumber(Config.Panning.Cooldown) or 0) * 1000
end

function Srv.pedAlive(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    if (GetEntityHealth(ped) or 0) <= 0 then return nil end
    return ped
end

RegisterNetEvent('pup_goldpan:begin', function(waterHash)
    local src = source
    local now = GetGameTimer()
    -- flood guard
    if lastBegin[src] and now - lastBegin[src] < 500 then return end
    lastBegin[src] = now

    local function refuse(reason)
        TriggerClientEvent('pup_goldpan:begun', src, false, reason)
    end

    local char = Srv.character(src)
    if not char then return refuse('NoPan') end
    if not Srv.hasPan(src) then return refuse('NoItem') end

    local water, hash = GP.water(waterHash)
    if not water then return refuse('WrongArea') end

    local open = Srv.Sessions[src]
    if open then
        -- a session the client never closed (crash, lost event) runs out after MaxSessionMs
        if now - open.at <= (Config.Panning.MaxSessionMs or 60000) then return refuse('Working') end
        Srv.Sessions[src] = nil
    end

    if not Srv.cooledDown(src) then return refuse('TooSoon') end

    local ped = Srv.pedAlive(src)
    if not ped then return refuse('NoPan') end

    -- re-check after the inventory call: the character or a racing begin may have changed
    if Srv.Sessions[src] then return refuse('Working') end
    local token = newToken()
    Srv.Sessions[src] = {
        token  = token,
        water  = hash,
        at     = GetGameTimer(),
        pos    = GetEntityCoords(ped),
        charId = char.charIdentifier,
    }
    TriggerClientEvent('pup_goldpan:begun', src, token, nil)
end)

RegisterNetEvent('pup_goldpan:cancel', function(token)
    local src = source
    local s = Srv.Sessions[src]
    if s and type(token) == 'string' and s.token == token then
        Srv.Sessions[src] = nil
    end
end)

------------------------------------------------------------------------------- the usable item
local function registerItem()
    local ok, err = pcall(function()
        exports.vorp_inventory:registerUsableItem(Config.PanItem, function(data)
            local src = data and tonumber(data.source)
            if not src or not Srv.character(src) then return end
            TriggerClientEvent('pup_goldpan:add', src)
        end, RES)
    end)
    if not ok then print(('^1[%s]^7 registerUsableItem failed: %s'):format(RES, tostring(err))) end
end

CreateThread(function()
    registerItem()
end)

AddEventHandler('playerDropped', function()
    local src = source
    Srv.Sessions[src], Srv.LastPaid[src], lastBegin[src] = nil, nil, nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    pcall(function() exports.vorp_inventory:unRegisterUsableItem(Config.PanItem) end)
end)
