-- pup-medical | purge overrides of the respawn rules (client side)

RegisterNetEvent('pup-events:state', function(key, on)
    if not Config.Purge or key ~= Config.Purge.eventKey then return end
    SetPurgeApplied(on == true)
end)

exports('PurgeDeathStatus', function()
    return PurgeStatus()
end)
