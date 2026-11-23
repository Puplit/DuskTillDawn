-- pup-stable | small server pieces: waypoint relay between riders of one horse, the reload-tack command

RegisterNetEvent('pup-stable:waypoint', function(targets, x, y)
    local src = source
    if not Config.Horse.shareWaypoint or not Throttle(src, 'waypoint', 1000) or not Ctx(src) then return end
    x, y = U.num(x), U.num(y)
    if not x or not y or type(targets) ~= 'table' then return end
    local myPos = PedPos(src)
    for i, t in ipairs(targets) do
        if i > 4 then break end
        t = U.int(t)
        -- only someone sitting right with the sender (same horse: within a couple of metres)
        local p = t and t ~= src and PedPos(t)
        if p and myPos and #(p - myPos) <= 3.0 then TriggerClientEvent('pup-stable:waypoint', t, x, y) end
    end
end)

-- re-apply tack on the nearest spawned stable horse within 10 m
if Config.Commands.reloadHorse then
    RegisterCommand(Config.Commands.reloadHorse, function(src)
        if src == 0 or not Ctx(src) then return end
        if not Throttle(src, 'reload', 3000) then return end
        local p = PedPos(src)
        if not p then return end
        local best, bestD = nil, 10.0
        for id, ent in pairs(HorseEnt) do
            if DoesEntityExist(ent) then
                local d = #(GetEntityCoords(ent) - p)
                if d <= bestD then best, bestD = id, d end
            end
        end
        local h = best and Horses[best]
        local owner = best and SpawnedBy[best]
        if h and owner then
            TriggerClientEvent('pup-stable:redress', owner, NetworkGetNetworkIdFromEntity(HorseEnt[best]), HorsePayload(h))
        end
    end, false)
end
