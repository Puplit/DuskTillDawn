-- boatshops | the boat in the water: boarding it, the aboard menu, parking

local CFG <const> = BoatConfig
local L <const> = BoatLocale
local T <const> = CFG.Timings

local boatBlip = nil
local anchored = false

local function removeBoatBlip()
    BN.removeBlip(boatBlip)
    boatBlip = nil
end

BC.onBoatGone = function()
    removeBoatBlip()
    anchored = false
end

local function waitFor(test, ms)
    local deadline = GetGameTimer() + ms
    while not test() do
        if GetGameTimer() > deadline then return false end
        Wait(50)
    end
    return true
end

-- ------------------------------------------------------------------ boarding

-- the server created the boat; find it, dress it and seat the owner at the helm
RegisterNetEvent('boatshops:spawned', function(state)
    if type(state) ~= 'table' or not state.netId then return end
    BC.active = state
    CreateThread(function()
        local veh = nil
        local found = waitFor(function()
            if not NetworkDoesNetworkIdExist(state.netId) then return false end
            veh = NetworkGetEntityFromNetworkId(state.netId)
            return veh ~= nil and veh ~= 0 and DoesEntityExist(veh)
        end, T.netWaitMs)
        if not found then
            TriggerServerEvent('boatshops:spawnFailed', state.id)
            return
        end

        NetworkRequestControlOfEntity(veh)
        waitFor(function() return NetworkHasControlOfEntity(veh) end, 2000)

        BN.noSink(veh)
        BC.applyComponents(veh, Boat.decode(state.components))
        anchored = false

        removeBoatBlip()
        boatBlip = BN.entityBlip(CFG.Blips.boatStyle, veh)
        BN.blipSprite(boatBlip, CFG.Blips.boatSprite)
        BN.blipModifier(boatBlip, CFG.Blips.boatModifier)
        BN.blipName(boatBlip, state.name or '')

        DoScreenFadeOut(T.spawnFadeMs)
        waitFor(IsScreenFadedOut, T.spawnFadeMs + 500)
        SetPedIntoVehicle(PlayerPedId(), veh, -1)
        DoScreenFadeIn(T.spawnFadeMs)
    end)
end)

-- ------------------------------------------------------------------ parking

local function myBoatUnderMe()
    local ped = PlayerPedId()
    if not IsPedInAnyBoat(ped) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    local mine = BC.activeEntity()
    if not mine or veh ~= mine then return nil end
    return veh
end

local function leaveBoat(veh)
    local ped = PlayerPedId()
    BN.anchor(veh, true)
    TaskLeaveVehicle(ped, veh, 16)
    waitFor(function() return not IsPedInVehicle(ped, veh, false) end, 3000)
    FreezeEntityPosition(veh, true)
end

local function parkAt(shop)
    BC.fetchBoats()
    local veh = myBoatUnderMe()
    if not veh then return end
    local id = BC.active.id
    leaveBoat(veh)
    DoScreenFadeOut(T.parkFadeMs)
    Wait(T.parkFadeMs)
    local e = shop.exit
    local ped = PlayerPedId()
    SetEntityCoords(ped, e.x + 0.0, e.y + 0.0, e.z + 0.0, false, false, false, false)
    if e.h then SetEntityHeading(ped, e.h + 0.0) end
    Wait(T.parkHoldMs)
    DoScreenFadeIn(T.parkFadeMs)
    BC.tip(L.parked, T.parkedTipMs)
    TriggerServerEvent('boatshops:park', id)
end

function BC.parkAt(shop)
    local ok, err = pcall(parkAt, shop)
    if not ok then
        print(('^1[boatshops]^7 %s'):format(tostring(err)))
        DoScreenFadeIn(500)
    end
    BC.busy = false
end

-- pup_railroad's /dv fires this when the player is in a boat: park where it is
AddEventHandler('wsrp:parkboat', function()
    CreateThread(function()
        local veh = myBoatUnderMe()
        if not veh then return end
        local id = BC.active.id
        leaveBoat(veh)
        BC.tip(L.parked, T.parkedTipMs)
        TriggerServerEvent('boatshops:park', id)
    end)
end)

-- ------------------------------------------------------------------ aboard menu

local function toggleAnchor(veh)
    if not DoesEntityExist(veh) then return end
    if CFG.NoAnchor[GetEntityModel(veh)] then return BC.tip(L.noAnchor) end
    anchored = not anchored
    BN.anchor(veh, anchored)
    BC.tip(anchored and L.anchorDown or L.anchorUp)
end

local function openAboard()
    local veh = myBoatUnderMe()
    if not veh then return end
    local id = BC.active.id
    BoatMenu.open({
        title = L.aboardTitle,
        subtitle = BC.active.name,
        options = {
            {
                label = L.anchor, description = L.anchorDesc,
                onSelect = function()
                    BoatMenu.close()
                    toggleAnchor(veh)
                end,
            },
            {
                label = L.openStorage, description = L.openStorageDesc,
                onSelect = function()
                    BoatMenu.close()
                    TriggerServerEvent('boatshops:storage', id)
                end,
            },
        },
    })
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if BC.active and IsPedInAnyBoat(ped) then
            Wait(0)
            if not BoatMenu.isOpen() and not BC.busy
                and BN.yes(Citizen.InvokeNative(0x580417101DDB492F, 0, CFG.Keys.boatMenu, Citizen.ResultAsInteger())) then
                openAboard()
            end
        else
            Wait(500)
        end
    end
end)

-- ------------------------------------------------------------------ stop

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearPedTasks(PlayerPedId())
    if BoatMenu.isOpen() then exports['pup-ui']:HideInkMenu() end
    BC.cleanupShop()
    BC.cleanupWorld()
    removeBoatBlip()
    BC.active, BC.boats = false, {}
    TriggerEvent('vorp_inventory:CloseInv')
    DoScreenFadeIn(0)
end)
