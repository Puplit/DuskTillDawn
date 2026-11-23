-- pup_robbery | hostile guards, spawned on one client (the walk-up controller or the heist leader)

Guards = {}

local owned = {}  -- [ped] = { blip, tag }
local remoteBlips = {} -- [netId] = blip, guards spawned by someone else on the crew

local function profileFor(def)
    local kind = def.type
    if not kind and Config.Walkup.lawModelsUsePoliceProfile and Config.LawModels[def.model] then kind = 'police' end
    return Config.GuardProfiles[kind or 'outlaw'] or Config.GuardProfiles.outlaw
end

-- one networked hostile ped; returns the ped or nil
function Guards.spawn(def, tag)
    local hash = C.loadModel(def.model, Config.GuardModelTimeoutMs)
    if not hash then
        print(('[pup_robbery] guard model %s would not load - skipped'):format(tostring(def.model)))
        return nil
    end
    local pos = def.pos
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, def.heading or 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- random outfit
    local wait = GetGameTimer() + 2000
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < wait do Wait(10) end
    PlaceEntityOnGroundProperly(ped, true)
    SetPedCanRagdoll(ped, false)
    for _, f in ipairs(Config.GuardConfigFlags or {}) do SetPedConfigFlag(ped, f[1], f[2]) end
    local prof = profileFor(def)
    SetEntityMaxHealth(ped, prof.health)
    SetEntityHealth(ped, prof.health, 0)
    SetPedAccuracy(ped, prof.accuracy)
    GiveWeaponToPed(ped, GetHashKey(def.weapon), Config.GuardAmmo, true, true, 0, false, 0.5, 1.0, 0, false, 0.0, false)
    SetPedCombatAttributes(ped, 46, true) -- always fight
    SetPedCombatAttributes(ped, 5, true)
    SetPedFleeAttributes(ped, 0, false)
    if prof.cover then SetPedCombatAttributes(ped, 0, true) end
    local blip = nil
    if Config.Walkup.guardBlips then blip = C.blipEntity(ped) end
    owned[ped] = { blip = blip, tag = tag }
    TaskCombatPed(ped, PlayerPedId(), 0, 16)
    return ped
end

function Guards.netIds(tag)
    local out = {}
    for ped, g in pairs(owned) do
        if g.tag == tag and DoesEntityExist(ped) and NetworkGetEntityIsNetworked(ped) then
            out[#out + 1] = NetworkGetNetworkIdFromEntity(ped)
        end
    end
    return out
end

function Guards.alive(tag)
    local n = 0
    for ped, g in pairs(owned) do
        if g.tag == tag and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then n = n + 1 end
    end
    return n
end

function Guards.clear(tag)
    for ped, g in pairs(owned) do
        if not tag or g.tag == tag then
            C.removeBlip(g.blip)
            if DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeletePed(ped)
            end
            owned[ped] = nil
        end
    end
end

-- blips on guards someone else on the crew spawned
function Guards.markRemote(ids)
    Guards.clearRemote()
    if not Config.Walkup.guardBlips then return end
    for _, id in ipairs(ids or {}) do
        if NetworkDoesNetworkIdExist(id) then
            local ent = NetworkGetEntityFromNetworkId(id)
            if ent and ent ~= 0 and DoesEntityExist(ent) and not owned[ent] then
                remoteBlips[id] = C.blipEntity(ent)
            end
        end
    end
end

function Guards.anyAliveRemote(ids)
    for _, id in ipairs(ids or {}) do
        if NetworkDoesNetworkIdExist(id) then
            local ent = NetworkGetEntityFromNetworkId(id)
            if ent and ent ~= 0 and DoesEntityExist(ent) and not IsPedDeadOrDying(ent, true) then return true end
        end
    end
    return false
end

function Guards.clearRemote()
    for id, b in pairs(remoteBlips) do
        C.removeBlip(b)
        remoteBlips[id] = nil
    end
end

-- vorp_admin world cleanup. Guards.wiped tells a wave that its guards were deleted by staff,
-- not killed, so walkup.lua sends that wave again instead of counting it as cleared.
Guards.wiped = false
RegisterNetEvent('vorp_admin:worldCleanup', function()
    if next(owned) then Guards.wiped = true end
end)
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    for ped, g in pairs(owned) do
        if not DoesEntityExist(ped) then
            C.removeBlip(g.blip)
            owned[ped] = nil
        end
    end
    for id, b in pairs(remoteBlips) do
        if not NetworkDoesNetworkIdExist(id) then
            C.removeBlip(b)
            remoteBlips[id] = nil
        end
    end
end)
