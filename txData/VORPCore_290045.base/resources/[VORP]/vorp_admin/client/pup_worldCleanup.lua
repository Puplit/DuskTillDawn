-- Client half of the world cleanup (server/pup_worldCleanup.lua).
-- 1. Just before the sweep the server asks what this player is sitting in or on, so it
--    is never deleted from under them: the mount, the vehicle, and the horses in its harness.
-- 2. The web panel's button posts here.

local Core = exports.vorp_core:GetCore()

local MAX_HARNESS <const> = 6 -- eDraftHarness: LR, RR, LM, RM, LF, RF

local function addNet(list, entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not NetworkGetEntityIsNetworked(entity) then return end
    list[#list + 1] = NetworkGetNetworkIdFromEntity(entity)
end

RegisterNetEvent('vorp_admin:worldCleanup:collect', function(id)
    local ped = PlayerPedId()
    local list = {}

    if IsPedOnMount(ped) then addNet(list, GetMount(ped)) end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        addNet(list, veh)
        -- _GET_PED_IN_DRAFT_HARNESS: the horses pulling the wagon
        for i = 0, MAX_HARNESS - 1 do
            addNet(list, Citizen.InvokeNative(0xA8BA0BAE0173457B, veh, i, Citizen.ResultAsInteger()))
        end
    end

    TriggerServerEvent('vorp_admin:worldCleanup:report', id, list)
end)

-- web panel: Anti-Cheat page button (the server checks the permission again)
RegisterNUICallback('panelWorldCleanup', function(_, cb)
    cb('ok')
    TriggerServerEvent('vorp_admin:worldCleanup:start')
    CreateThread(function()
        Wait(600)
        SendNUIMessage({ app = 'panel', action = 'security',
            data = Core.Callback.TriggerAwait('vorp_admin:Callback:getFlags') })
    end)
end)
