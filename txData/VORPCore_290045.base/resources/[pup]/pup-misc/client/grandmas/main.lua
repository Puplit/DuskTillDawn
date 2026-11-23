-- pup-misc / grandmas - NPC doctors that revive a dead player for a fee (/rev next to one)

local jobpeds   = {}
local blips     = {}
local oncooldown
local inmenu    = false

RegisterNetEvent('pup-grandma:reccooldown')
AddEventHandler('pup-grandma:reccooldown', function(x)
    oncooldown = x
end)

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoord())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)
    local str = CreateVarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
    if onScreen then
        SetTextScale(0.30, 0.30)
        SetTextFontForCurrentCommand(1)
        SetTextColor(255, 255, 255, 215)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
        local factor = (string.len(text)) / 225
        DrawSprite("feeds", "hud_menu_4a", _x, _y + 0.0125, 0.015 + factor, 0.03, 0.1, 35, 35, 35, 190, 0)
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    for k, v in pairs(GrandmasConfig.Doctors) do
        if v.blip.show then
            local blip = N_0x554d9d53f696d002(1664425300, v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, v.blip.sprite, 1)
            SetBlipScale(blip, 0.2)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, v.blip.name)
            table.insert(blips, blip)
        end
        -----
        local hashModel = GetHashKey(v.model)
        if IsModelValid(hashModel) then
            RequestModel(hashModel)
            while not HasModelLoaded(hashModel) do
                Wait(100)
            end
        end
        local npc = CreatePed(hashModel, v.coords.x, v.coords.y, v.coords.z - 1.0, v.coords.h, false, true, true, true)
        Citizen.InvokeNative(0x283978A15512B2FE, npc, true) -- SetRandomOutfitVariation
        SetEntityNoCollisionEntity(PlayerPedId(), npc, false)
        SetEntityCanBeDamaged(npc, false)
        SetEntityInvincible(npc, true)
        Wait(1000)
        FreezeEntityPosition(npc, true)             -- NPC can't escape
        SetBlockingOfNonTemporaryEvents(npc, true)  -- NPC can't be scared
        table.insert(jobpeds, npc)
    end
end)

-- the treatment takes time and can be interrupted
local reviving = false

local function RevivalTreatment(doctor)
    if reviving then return end
    reviving = true

    local duration = math.floor(tonumber(GrandmasConfig.Treatment.durationMs) or 8000)
    local leash    = tonumber(GrandmasConfig.Treatment.leashDistance) or 3.0
    local origin   = vector3(doctor.coords.x + 0.0, doctor.coords.y + 0.0, doctor.coords.z + 0.0)

    exports['pup-ui']:Progress({
        label = GrandmasLocale.treating or 'BEING TREATED...',
        duration = duration,
    })

    local deadline = GetGameTimer() + duration
    local cancelled = false
    while GetGameTimer() < deadline do
        Citizen.Wait(100)
        local ped = PlayerPedId()
        -- moved out of the doctor's reach, or somehow revived by someone else
        if #(GetEntityCoords(ped) - origin) > leash or not IsEntityDead(ped) then
            cancelled = true
            break
        end
    end

    if cancelled then
        exports['pup-ui']:ProgressCancel()
        TriggerEvent("vorp:TipBottom", GrandmasLocale.treatcancelled or "The treatment was interrupted", 4000)
        reviving = false
        return
    end

    -- server re-validates distance, price and cooldown before charging
    TriggerServerEvent("pup-grandma:revive", doctor.price, doctor.gold)
    reviving = false
end

RegisterCommand(GrandmasConfig.General.command, function()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    local isDead = IsEntityDead(player)

    if oncooldown then
        TriggerEvent("vorp:TipBottom", GrandmasLocale.cooldown, 4000)
        return
    end
    if reviving then return end

    for k, v in pairs(GrandmasConfig.Doctors) do
        if GetDistanceBetweenCoords(coords, v.coords.x, v.coords.y, v.coords.z, true) < 2 then
            if isDead then
                Citizen.CreateThread(function() RevivalTreatment(v) end)
            else
                TriggerEvent("vorp:TipBottom", GrandmasLocale.notdead, 4000)
            end
            return -- only ever treat at ONE doctor, even if two are close
        end
    end
end)

-- physical cleanup after the revive - the death task
RegisterNetEvent("pup-grandma:revived")
AddEventHandler("pup-grandma:revived", function()
    Citizen.CreateThread(function()
        Citizen.Wait(500) -- let the core revive settle first
        local ped = PlayerPedId()
        ClearPedTasksImmediately(ped)
        SetPedToRagdoll(ped, 0, 0, 0, false, false, false) -- ends any active ragdoll
        Citizen.InvokeNative(0x675680D089BFA21F, PlayerId(), 100.0) -- RestorePlayerStamina
        SetPlayerInvincible(PlayerId(), false)
        SetPedCanRagdoll(ped, true)
    end)
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10)
        local player = PlayerPedId()
        local coords = GetEntityCoords(player)
        local sleep = true
        for k, v in pairs(GrandmasConfig.Doctors) do
            if GetDistanceBetweenCoords(coords, v.coords.x, v.coords.y, v.coords.z, true) < 1.5 and not inmenu then
                sleep = false
                DrawText3D(v.coords.x, v.coords.y, v.coords.z, GrandmasLocale.type)
            end
        end
        if sleep then
            Citizen.Wait(500)
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(100)
        if oncooldown then
            Citizen.Wait((GrandmasConfig.Treatment.cooldownMinutes * 60000) - 100)
            oncooldown = false
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for k, v in pairs(blips) do
            RemoveBlip(v)
        end
        for k, v in pairs(jobpeds) do
            DeletePed(v)
        end
    end
end)
