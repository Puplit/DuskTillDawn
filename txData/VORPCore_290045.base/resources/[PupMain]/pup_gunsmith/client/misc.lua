-- pup_gunsmith | character select, ammo wipe, and clean-up on stop

local function endEverything(instant)
    ShopCl.stop()
    CraftCl.stop()
    BenchCl.close(false, instant)
    Preview.clearAll()
    local ped = PlayerPedId()
    if Cl.busy then
        Cl.busy = nil
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end
end

-- a new character: nothing from the old one may stay open
RegisterNetEvent('vorp:SelectedCharacter', function()
    endEverything(true)
    TriggerServerEvent('pup_gunsmith:clearSecondSlot')
    SetTimeout(1000, function()
        RemoveAllPedWeapons(PlayerPedId(), true, true)
    end)
end)

-- sent by vorp_inventory and vorp_admin on a weapon/ammo wipe
RegisterNetEvent('pup_gunsmith:removeallammo', function()
    TriggerServerEvent('pup_gunsmith:clearStoredAmmo')
    local ped = PlayerPedId()
    pcall(Citizen.InvokeNative, 0x1B83C0DEEBCBB214, ped) -- REMOVE_ALL_PED_AMMO
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GS.RES then return end
    endEverything(true)
    SetNuiFocus(false, false)
end)
