-- instanced-player check, server half: reports what the server sees of the player's ped

local function nativeStatus(fn, ...)
    local ok, value = pcall(fn, ...)
    if not ok then return nil, 'error' end
    return value, 'ok'
end

RegisterNetEvent('pup-debugs:syncProbe', function(generation, sequence, charId)
    local src <const> = source
    if Config.SyncCheck.enabled == false then return end

    local sample = {
        version      = 1,
        pedExists    = false,
        pedStatus    = 'missing',
        coordsStatus = 'not_checked',
        coords       = nil,
        model        = nil,
    }
    local netId = 0

    local ped, pedRead = nativeStatus(GetPlayerPed, src)
    if pedRead ~= 'ok' then
        sample.pedStatus = 'error'
    elseif not ped or ped == 0 or not DoesEntityExist(ped) then
        -- THE SIGNATURE WORTH CATCHING: the client has a ped, the server has none
        sample.pedStatus = 'missing'
    else
        sample.pedExists = true
        sample.pedStatus = 'ok'

        local coords, coordsRead = nativeStatus(GetEntityCoords, ped)
        if coordsRead ~= 'ok' or not coords then
            sample.coordsStatus = 'error'
        else
            sample.coordsStatus = 'ok'
            sample.coords = { x = coords.x, y = coords.y, z = coords.z }
        end

        sample.model = select(1, nativeStatus(GetEntityModel, ped))

        local id = select(1, nativeStatus(NetworkGetNetworkIdFromEntity, ped))
        netId = (type(id) == 'number' and id > 0) and id or 0
    end

    -- generation and sequence come back so the client can drop stale answers
    TriggerClientEvent('pup-debugs:syncReply', src, generation, sequence, charId, netId, sample)
end)
