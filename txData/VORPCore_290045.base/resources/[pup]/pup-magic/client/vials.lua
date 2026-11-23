-- pup-magic | drinking a vial (the short freeze) and the smoke puff seen around it

local B <const> = Config.Blood

local drinking = false

RegisterNetEvent('pup-magic:drink', function()
    if drinking then return end
    drinking = true
    local ms = math.max(0, tonumber(B.drinkMs) or 0)
    TipBottom(Locale.drinkDown, ms)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, true)
    SetTimeout(ms, function()
        if not drinking then return end
        FreezeEntityPosition(PlayerPedId(), false)
        drinking = false
    end)
end)

RegisterNetEvent('pup-magic:vialSmoke', function(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    local s = B.smoke
    if type(s) ~= 'table' then return end
    local here = GetEntityCoords(PlayerPedId())
    if #(here - vector3(x, y, z)) > (tonumber(s.viewRange) or 0) then return end

    CreateThread(function()
        if not LoadPtfx(s.asset, 5000) then return end
        UseParticleFxAsset(s.asset)
        local handle = StartParticleFxLoopedAtCoord(s.name, x, y, z + (tonumber(s.zOffset) or 0.0),
            0.0, 0.0, 0.0, (tonumber(s.scale) or 1.0) + 0.0, false, false, false, false)
        if not handle or handle == 0 then return end
        -- drawn as far as it is sent (viewRange), not a fixed few metres
        pcall(SetParticleFxLoopedFarClipDist, handle, (tonumber(s.viewRange) or 60.0) + 0.0)
        pcall(SetParticleFxLoopedAlpha, handle, 1.0)
        Wait(tonumber(s.durationMs) or 4000)
        StopLoop(handle)
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if drinking then
        drinking = false
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
