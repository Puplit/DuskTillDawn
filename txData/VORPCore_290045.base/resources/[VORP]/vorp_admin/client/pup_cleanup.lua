-- Modified by Puppet (Dusk Till Dawn), 2026
-- Client half of the cleanup sweep. Some entities cannot be removed from the server,
-- so the owning client is asked to take control of one and delete it here.

local CONTROL_TIMEOUT_MS <const> = 1500

local function takeControl(entity)
    if not NetworkGetEntityIsNetworked(entity) then return true end

    NetworkRequestControlOfEntity(entity)
    local deadline <const> = GetGameTimer() + CONTROL_TIMEOUT_MS
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

RegisterNetEvent('vorp_admin:cleanup:deleteNetId')
AddEventHandler('vorp_admin:cleanup:deleteNetId', function(netId, isVehicle)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    -- never our own ped, whatever the server asked for
    if entity == PlayerPedId() then return end
    if not takeControl(entity) then return end

    SetEntityAsMissionEntity(entity, true, true)
    if isVehicle and type(DeleteVehicle) == 'function' then
        DeleteVehicle(entity)
    end
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)
