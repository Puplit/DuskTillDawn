-- pup-misc / bandana /bandana - mask up, mask down

local up   = false   -- is the bandana currently over the face?
local busy = false

local function categories()
    local c = BandanaConfig.Garment.categories
    if type(c) == 'table' and #c > 0 then return c end
    return { 'neckwear' }
end

-- The worn components, straight from the character record on the server
local comps = nil          -- last set the server sent
local waitingComps = false

RegisterNetEvent('pup-misc:bandana:comps', function(raw)
    waitingComps = false
    comps = nil
    if type(raw) ~= 'string' or raw == '' then return end
    local ok, t = pcall(json.decode, raw)
    if ok and type(t) == 'table' then comps = t end
end)

-- ask, then wait briefly for the answer
local function fetchComps()
    waitingComps = true
    TriggerServerEvent('pup-misc:bandana:getComps')
    local waited = 0
    while waitingComps and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end
    return comps
end

local function storedHash()
    local t = fetchComps()
    if type(t) ~= 'table' then return nil end
    for _, key in ipairs(BandanaConfig.Garment.storedKeys or { 'NeckWear', 'Mask' }) do
        local v = t[key]
        -- a slot is either the hash itself or { comp = hash, tint... }
        if type(v) == 'table' then v = v.comp or v.hash or v[1] end
        v = tonumber(v)
        if v and v ~= 0 and v ~= -1 then return v, key end
    end
    return nil
end

local function stateHash(v)
    if type(v) == 'string' then return GetHashKey(v) end
    return v
end

local function setState(newUp)
    up = newUp and true or false
    -- tell every other resource on this client (pup_robbery listens)
    TriggerEvent('pup-misc:bandanaState', up)
end

exports('IsBandanaUp', function() return up end)

-- the server can force the state (pup_robbery syncs it on spawn/job change)
RegisterNetEvent('pup-misc:setBandana', function(state)
    setState(state)
end)

RegisterCommand(BandanaConfig.General.command or 'bandana', function()
    if busy then return end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end

    -- ONLY the character's real NeckWear slot
    local neck, from = storedHash()
    if not neck then
        if BandanaConfig.General.debug then
            print("^1[bandana]^7 no usable garment hash from vorp_character or the ped")
        end
        return TriggerEvent('vorp:TipRight', BandanaLocale.noNeckwear, 3000)
    end
    if BandanaConfig.General.debug then
        print(("^3[bandana]^7 using hash %s from %s"):format(tostring(neck), tostring(from)))
    end

    busy = true
    if up then
        if BandanaConfig.Animation.enabled then
            Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, neck,
                GetHashKey('BANDANA_OFF_RIGHT_HAND'), 1, 0, -1082130432)
            Wait(BandanaConfig.Animation.waitMs or 700)
        end
        Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, neck, stateHash(BandanaConfig.Garment.stateDown), 0, true, 1)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
        setState(false)
    else
        if BandanaConfig.Animation.enabled then
            Citizen.InvokeNative(0xAE72E7DF013AAA61, ped, neck,
                GetHashKey('BANDANA_ON_RIGHT_HAND'), 1, 0, -1082130432)
            Wait(BandanaConfig.Animation.waitMs or 700)
        end
        Citizen.InvokeNative(0x66B957AAC2EAAEAB, ped, neck, stateHash(BandanaConfig.Garment.stateUp), 0, true, 1)
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, 1, 1, 1, false)
        setState(true)
    end
    -- the flip redraws the neckwear at stock tint; vorp_character puts the dye back
    TriggerEvent('vorp_character:client:reapplyColors')
    busy = false
end, false)

-- a ped rebuild (/rc, outfit change) comes back with the neckwear down
AddEventHandler('vorp_character:client:reloadedComponents', function()
    if up then setState(false) end
end)
