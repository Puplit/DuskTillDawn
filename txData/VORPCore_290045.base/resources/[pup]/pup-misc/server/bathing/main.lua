-- bathing | server: one bather per bathhouse, the bath and deluxe payments,
-- and freeing a bathhouse. The client only asks.
-- Reads BathhouseConfig / BathhouseLocale (shared).

local CFG <const> = BathhouseConfig
local L <const> = BathhouseLocale
local T <const> = CFG.Timings

local EV_REQUEST <const> = 'pup-misc:bath:request'
local EV_BEGIN <const> = 'pup-misc:bath:begin'
local EV_REFUSED <const> = 'pup-misc:bath:refused'
local EV_DELUXE <const> = 'pup-misc:bath:deluxe'
local EV_DELUXE_OK <const> = 'pup-misc:bath:deluxeOk'
local EV_DELUXE_NO <const> = 'pup-misc:bath:deluxeNo'
local EV_FINISHED <const> = 'pup-misc:bath:finished'
local EV_RELEASED <const> = 'pup-misc:bath:released'
local EV_STARTED <const> = 'pup-misc:bath:started'
local EV_REFUND <const> = 'pup-misc:bath:refund'

local Core = nil
local function core()
    if Core then return Core end
    local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
    if ok and c then
        Core = c
    else
        TriggerEvent('getCore', function(c2) Core = c2 end)
    end
    return Core
end

local function charOf(src)
    local c = core()
    if not c then return nil end
    local ok, user = pcall(c.getUser, src)
    if not ok or not user then return nil end
    return user.getUsedCharacter
end

local function tip(src, text)
    TriggerClientEvent('vorp:TipRight', src, text, T.tipMs)
end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- ------------------------------------------------------------------ occupancy

local holds = {} -- [house key] = { src = server id, deluxe = bought this bath }

-- what this player paid that has not started yet, so a failed cutscene can be
-- refunded once: [src] = { key = house key, regular = amount, deluxe = amount }
local charged = {}

local function heldBy(src)
    for key, h in pairs(holds) do
        if h.src == src then return key end
    end
    return nil
end

local function freeAll(src)
    for key, h in pairs(holds) do
        if h.src == src then holds[key] = nil end
    end
    charged[src] = nil
end

-- ------------------------------------------------------------------ request gap

local lastAsk = {}
local function tooSoon(src)
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < T.requestGapMs then return true end
    lastAsk[src] = now
    return false
end

-- ------------------------------------------------------------------ starting a bath

local function decideStart(src, key)
    if type(key) ~= 'string' or key == '' then return false end
    local house = CFG.Houses[key]
    if not house or not house.consumer then return false end

    local char = charOf(src)
    if not char then return false end

    local pos = pedPos(src)
    if not pos or #(pos - house.consumer) > CFG.Distances.serverStart then return false end

    if heldBy(src) then return false end
    if holds[key] then return false, L.occupied end

    local price = CFG.Prices.regular
    if (tonumber(char.money) or 0) < price then return false, L.noCashBath:format(price) end

    char.removeCurrency(0, price)
    holds[key] = { src = src, deluxe = false }
    charged[src] = { key = key, regular = price, regularAt = GetGameTimer() }
    return true
end

RegisterNetEvent(EV_REQUEST, function(key)
    local src = source
    if tooSoon(src) then
        TriggerClientEvent(EV_REFUSED, src)
        return
    end
    local ok, allowed, msg = pcall(decideStart, src, key)
    if not ok then
        print(('^1[pup-misc/bathing]^7 start failed: %s'):format(tostring(allowed)))
        allowed, msg = false, nil
    end
    if not allowed then
        if msg then tip(src, msg) end
        TriggerClientEvent(EV_REFUSED, src)
        return
    end
    TriggerClientEvent(EV_BEGIN, src, key)
end)

-- ------------------------------------------------------------------ deluxe

local function decideDeluxe(src, key)
    if type(key) ~= 'string' then return false end
    local h = holds[key]
    if not h or h.src ~= src then return false end
    if h.deluxe then return false end

    local char = charOf(src)
    if not char then return false end

    local price = CFG.Prices.deluxe
    if (tonumber(char.money) or 0) < price then return false, L.noCashDeluxe:format(price) end

    char.removeCurrency(0, price)
    h.deluxe = true
    local c = charged[src]
    if c and c.key == key then
        c.deluxe, c.deluxeAt = price, GetGameTimer()
    else
        charged[src] = { key = key, deluxe = price, deluxeAt = GetGameTimer() }
    end
    return true
end

RegisterNetEvent(EV_DELUXE, function(key)
    local src = source
    if tooSoon(src) then
        TriggerClientEvent(EV_DELUXE_NO, src)
        return
    end
    local ok, allowed, msg = pcall(decideDeluxe, src, key)
    if not ok then
        print(('^1[pup-misc/bathing]^7 deluxe failed: %s'):format(tostring(allowed)))
        allowed, msg = false, nil
    end
    if not allowed then
        if msg then tip(src, msg) end
        TriggerClientEvent(EV_DELUXE_NO, src)
        return
    end
    TriggerClientEvent(EV_DELUXE_OK, src, key)
end)

-- ------------------------------------------------------------------ started / refund

local KINDS <const> = { regular = true, deluxe = true }
-- a cutscene that fails does so within moments of paying; a later refund claim is a bath that ran
local REFUND_WINDOW_MS <const> = 15000
-- and one refund per player per 10 minutes, so a refund can't be claimed bath after bath
local REFUND_GAP_MS <const> = 600000
local lastRefund = {}

-- the cutscene for this charge is playing: it can no longer be refunded
RegisterNetEvent(EV_STARTED, function(kind)
    local c = charged[source]
    if KINDS[kind] and c then c[kind] = nil end
end)

-- the cutscene for this charge never started: pay back what was taken, once
RegisterNetEvent(EV_REFUND, function(kind)
    local src = source
    if not KINDS[kind] then return end
    local c = charged[src]
    if not c or not c[kind] then return end
    local amount = c[kind]
    c[kind] = nil
    local now = GetGameTimer()
    if now - (c[kind .. 'At'] or 0) > REFUND_WINDOW_MS then return end
    if lastRefund[src] and now - lastRefund[src] < REFUND_GAP_MS then return end
    lastRefund[src] = now
    local h = holds[c.key]
    if not h or h.src ~= src then
        charged[src] = nil
        return
    end
    local char = charOf(src)
    if not char then return end
    local ok, err = pcall(char.addCurrency, 0, amount)
    if not ok then
        print(('^1[pup-misc/bathing]^7 refund failed: %s'):format(tostring(err)))
        return
    end
    if kind == 'deluxe' then
        h.deluxe = false
    else
        freeAll(src) -- the bath never began: the bathhouse goes too
    end
end)

-- ------------------------------------------------------------------ freeing

-- carries nothing: a player can only free their own holds
RegisterNetEvent(EV_FINISHED, function()
    freeAll(source)
end)

AddEventHandler('playerDropped', function()
    local src = source
    freeAll(src)
    lastAsk[src] = nil
    lastRefund[src] = nil
end)

AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then freeAll(src) end
end)

-- a holder who is gone or has walked away from the bathhouse loses it
CreateThread(function()
    while true do
        Wait(T.sweepMs)
        for key, h in pairs(holds) do
            if not GetPlayerName(h.src) then
                holds[key] = nil
                charged[h.src] = nil
            else
                local pos = pedPos(h.src)
                local house = CFG.Houses[key]
                local known = pos and not (pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0)
                if known and house and #(pos - house.consumer) > CFG.Distances.serverLeave then
                    holds[key] = nil
                    charged[h.src] = nil
                    TriggerClientEvent(EV_RELEASED, h.src, key)
                end
            end
        end
    end
end)
