-- pup_railroad | client: the delete-vehicle command

local L <const> = Rail.L

local function takeControl(ent, ms)
    local deadline = GetGameTimer() + ms
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) do
        if GetGameTimer() > deadline then return false end
        NetworkRequestControlOfEntity(ent)
        Wait(50)
    end
    return true
end

local function deleteVehicle(veh)
    SetEntityAsMissionEntity(veh, true, true)
    if Cl.isTrain(veh) then Cl.train.delete(veh) end
    if DoesEntityExist(veh) then DeleteVehicle(veh) end
    if DoesEntityExist(veh) then DeleteEntity(veh) end
end

local busy = false

RegisterCommand(Config.DeleteCommand, function()
    if busy then return end
    local ped = PlayerPedId()

    if IsPedInAnyBoat(ped) then
        TriggerEvent('wsrp:parkboat')
        return
    end

    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetVehiclePedIsIn(ped, true) end
    if veh == 0 or not DoesEntityExist(veh) then return end

    busy = true
    CreateThread(function()
        if Cl.isTrain(veh) then
            local entry = Cl.entryForVehicle(veh)
            if entry and Cl.route and Cl.route.trainId == entry.id then
                busy = false
                return Cl.notify(L('dv_cancel_first'))
            end
            if not takeControl(veh, 3000) then
                busy = false
                return Cl.notify(L('cant_reach'))
            end
            local netId = NetworkGetEntityIsNetworked(veh) and NetworkGetNetworkIdFromEntity(veh) or 0
            local r = Cl.call('putAway', 6000, netId)
            if not r then
                busy = false
                return Cl.officeSilent()
            end
            if r.ok and DoesEntityExist(veh) then deleteVehicle(veh) end
        else
            if takeControl(veh, 3000) then deleteVehicle(veh) end
        end
        busy = false
    end)
end, false)
