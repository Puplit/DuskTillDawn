-- pup-misc / cannon Places RDR2's mounted weapons for senior law and lets the placer turn them

local placed = {}   -- { {entity=, label=, at=} } - this client's own pieces

local function loadModel(hash)
    RequestModel(hash)
    local tries = 0
    while not HasModelLoaded(hash) and tries < 200 do
        tries = tries + 1
        Citizen.Wait(10)
    end
    return HasModelLoaded(hash)
end

local function deleteEntry(i)
    local entry = placed[i]
    if not entry then return end
    if entry.entity and DoesEntityExist(entry.entity) then
        SetEntityAsMissionEntity(entry.entity, true, true)
        DeleteEntity(entry.entity)
    end
    if entry.net then TriggerServerEvent('pup-misc:cannon:gone', entry.net) end
    table.remove(placed, i)
end

local function clearAll()
    for i = #placed, 1, -1 do deleteEntry(i) end
end

-- nearest piece THIS player placed, within `dist`
local function nearestOwn(dist)
    local c = GetEntityCoords(PlayerPedId())
    local best, bestI, bestD = nil, nil, dist or 4.0
    for i, entry in ipairs(placed) do
        if entry.entity and DoesEntityExist(entry.entity) then
            local d = #(c - GetEntityCoords(entry.entity))
            if d <= bestD then best, bestI, bestD = entry, i, d end
        end
    end
    return best, bestI
end

RegisterNetEvent('pup-misc:cannon:spawn', function(model, label)
    if #placed >= (CannonConfig.Placement.maxPerPlayer or 2) then
        exports['pup-ui']:Toast((CannonLocale.tooMany)
            :format(#placed, CannonConfig.General.removeCommand or 'gatremove'), 6000)
        return
    end

    local hash = GetHashKey(model)
    if not loadModel(hash) then
        print(('^3[pup-misc/cannon]^7 model failed to load: %s'):format(tostring(model)))
        return
    end

    local ped = PlayerPedId()
    local fwd = GetEntityForwardVector(ped)
    local c   = GetEntityCoords(ped)
    local dist = CannonConfig.Placement.spawnForward or 2.5
    local x, y, z = c.x + fwd.x * dist, c.y + fwd.y * dist, c.z

    -- these are vehicle-class models in RDR2, which is what makes them mannable once they are down
    local ent = CreateVehicle(hash, x, y, z, GetEntityHeading(ped), true, false)
    local tries = 0
    while not DoesEntityExist(ent) and tries < 20 do tries = tries + 1 Citizen.Wait(50) end
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ent) then return end

    SetEntityAsMissionEntity(ent, true, true)
    PlaceObjectOnGroundProperly(ent)

    -- the server removes what this client leaves behind if it disconnects
    local waited = 0
    while not NetworkGetEntityIsNetworked(ent) and waited < 20 do waited = waited + 1 Citizen.Wait(50) end
    local net = NetworkGetEntityIsNetworked(ent) and NetworkGetNetworkIdFromEntity(ent) or 0
    if net ~= 0 then TriggerServerEvent('pup-misc:cannon:placed', net) end

    placed[#placed + 1] = { entity = ent, net = net ~= 0 and net or nil, label = label or CannonLocale.defaultLabel, at = GetGameTimer() }
    exports['pup-ui']:Toast((CannonLocale.placed)
        :format(label or CannonLocale.defaultLabel, CannonConfig.General.removeCommand or 'gatremove'), 7000)
end)

RegisterNetEvent('pup-misc:cannon:remove', function()
    local entry, i = nearestOwn(8.0)
    if not entry then
        -- not stood next to one: take the oldest so nothing is ever stranded
        if #placed == 0 then
            return exports['pup-ui']:Toast(CannonLocale.nothingPlaced, 4000)
        end
        i = 1
        entry = placed[1]
    end
    local label = entry.label or CannonLocale.defaultLabel
    deleteEntry(i)
    exports['pup-ui']:Toast((CannonLocale.removed):format(label), 4000)
end)

-- turning: only while stood beside your own piece, and only on foot
CreateThread(function()
    while true do
        local sleep = 500
        if #placed > 0 then
            local ped = PlayerPedId()
            if not IsPedDeadOrDying(ped, true) and not IsPedInAnyVehicle(ped, false) then
                local entry = nearestOwn(CannonConfig.Placement.rotateDistance or 4.0)
                if entry and entry.entity and DoesEntityExist(entry.entity) then
                    sleep = 0
                    local step = CannonConfig.Placement.rotateStepDegrees or 1.5
                    local h = GetEntityHeading(entry.entity)
                    if IsControlPressed(0, CannonConfig.Keys.rotateLeft) then
                        SetEntityHeading(entry.entity, (h + step) % 360)
                    elseif IsControlPressed(0, CannonConfig.Keys.rotateRight) then
                        SetEntityHeading(entry.entity, (h - step) % 360)
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- despawn timer: artillery left lying around eventually goes away on its own
CreateThread(function()
    while true do
        Citizen.Wait(30000)
        local mins = tonumber(CannonConfig.Placement.despawnMinutes) or 0
        if mins > 0 then
            local cutoff = mins * 60 * 1000
            local now = GetGameTimer()
            for i = #placed, 1, -1 do
                local entry = placed[i]
                if not entry.entity or not DoesEntityExist(entry.entity) then
                    deleteEntry(i)
                elseif (now - (entry.at or now)) >= cutoff then
                    deleteEntry(i)
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearAll()
end)

-- vorp_admin world cleanup: a piece staff deleted counts as removed (the server is told too),
-- so it no longer fills one of the placer's slots. A manned piece is kept by the sweep.
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    for i = #placed, 1, -1 do
        local e = placed[i].entity
        if not e or not DoesEntityExist(e) then deleteEntry(i) end
    end
end)
