-- boatshops | client state: the player's boats, the boat in the water, server replies

BC = {
    boats = {},      -- rows from the server: { id, name, boat, components, out }
    active = false,  -- the boat this character has in the water: { id, netId, key, hash, name }
    shop = nil,      -- the shop whose menu is open
}

local CFG <const> = BoatConfig

function BC.tip(text, ms)
    if not text then return end
    TriggerEvent('vorp:TipRight', text, ms or CFG.Timings.tipMs)
end

-- ------------------------------------------------------------------ server replies

local boatsWaiter = nil
local accessWaiter = nil

RegisterNetEvent('boatshops:boats', function(rows)
    BC.boats = type(rows) == 'table' and rows or {}
    if boatsWaiter then
        local p = boatsWaiter
        boatsWaiter = nil
        p:resolve(true)
    end
end)

RegisterNetEvent('boatshops:active', function(state)
    BC.active = type(state) == 'table' and state or false
    if not BC.active and BC.onBoatGone then BC.onBoatGone() end
end)

RegisterNetEvent('boatshops:access', function(shopId, ok)
    if accessWaiter and accessWaiter.shopId == shopId then
        local w = accessWaiter
        accessWaiter = nil
        w.p:resolve(ok == true)
    end
end)

local function await(p)
    SetTimeout(CFG.Timings.replyWaitMs, function() p:resolve(nil) end)
    return Citizen.Await(p)
end

-- asks for a fresh list and waits for it; false when the server did not answer
function BC.fetchBoats()
    local p = promise.new()
    boatsWaiter = p
    TriggerServerEvent('boatshops:getBoats')
    return await(p) == true
end

function BC.askAccess(shopId)
    local p = promise.new()
    accessWaiter = { shopId = shopId, p = p }
    TriggerServerEvent('boatshops:access', shopId)
    return await(p) == true
end

function BC.boatById(id)
    for _, b in ipairs(BC.boats) do
        if b.id == id then return b end
    end
    return nil
end

function BC.isOut(id)
    if BC.active and BC.active.id == id then return true end
    local b = BC.boatById(id)
    return b ~= nil and b.out == true
end

-- the entity of the boat in the water, if this client can see it
function BC.activeEntity()
    local a = BC.active
    if not a or not a.netId then return nil end
    if not NetworkDoesNetworkIdExist(a.netId) then return nil end
    local ent = NetworkGetEntityFromNetworkId(a.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    return ent
end

function BC.gameHour()
    return GetClockHours()
end

-- ------------------------------------------------------------------ start

local function refresh()
    TriggerServerEvent('boatshops:getBoats')
end

RegisterNetEvent('vorp:SelectedCharacter', function()
    BC.boats, BC.active = {}, false
    SetTimeout(2000, refresh)
end)

CreateThread(function()
    Wait(2000)
    refresh()
end)
