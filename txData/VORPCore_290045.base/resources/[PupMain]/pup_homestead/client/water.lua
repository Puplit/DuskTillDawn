-- pup_homestead | client: the watering can in your hand, and filling it in a river
local H = Homestead
local canProp = nil

function H.holdCan(on)
    local ped = PlayerPedId()
    if canProp then
        if DoesEntityExist(canProp) then DeleteObject(canProp) end
        canProp = nil
    end
    H.holding = on
    if not on then
        ClearPedTasks(ped)
        return
    end
    ClearPedTasks(ped)
    RequestAnimDict('amb_camp@world_camp_jack_es@bucket_pickup@empty@male_a@base')
    local t = GetGameTimer()
    while not HasAnimDictLoaded('amb_camp@world_camp_jack_es@bucket_pickup@empty@male_a@base') and GetGameTimer() - t < 3000 do Wait(50) end
    TaskPlayAnim(ped, 'amb_camp@world_camp_jack_es@bucket_pickup@empty@male_a@base', 'base', 1.0, 1.0, -1, 25, 0, false, false, false)
    local hash = GetHashKey('p_bucketcampmil01x')
    RequestModel(hash)
    t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 3000 do Wait(50) end
    local c = GetEntityCoords(ped)
    canProp = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    AttachEntityToEntity(canProp, ped, GetEntityBoneIndexByName(ped, 'PH_R_Hand'), -0.03, 0.02, -0.02, 0.0, 0.0, -94.0, false, false, true, false, 0, true, false, false)
    SetModelAsNoLongerNeeded(hash)
end

RegisterNetEvent('pup_homestead:holdCan', function(on) H.holdCan(on) end)

RegisterCommand(Config.General.dropCanCommand, function()
    if not H.holding then return end
    H.holdCan(false)
    TriggerServerEvent('pup_homestead:dropCan')
end, false)

-- an empty can was used: fill it if they are standing in water
RegisterNetEvent('pup_homestead:tryRiver', function()
    local ped = PlayerPedId()
    if not IsEntityInWater(ped) then return H.tip(Locale.notInWater) end
    if H.busy then return end
    H.busy = true
    FreezeEntityPosition(ped, true)
    RequestAnimDict('amb_work@world_human_bucket_fill@female_a@stand_exit_withprop')
    local t = GetGameTimer()
    while not HasAnimDictLoaded('amb_work@world_human_bucket_fill@female_a@stand_exit_withprop') and GetGameTimer() - t < 3000 do Wait(50) end
    TaskPlayAnim(ped, 'amb_work@world_human_bucket_fill@female_a@stand_exit_withprop', 'exit_front', 1.0, 1.0, -1, 1, 0, false, false, false)
    Wait(1400)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    local res = H.ask({ op = 'river' })
    H.tip(res and res.msg)
    H.busy = false
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and canProp and DoesEntityExist(canProp) then DeleteObject(canProp) end
end)
