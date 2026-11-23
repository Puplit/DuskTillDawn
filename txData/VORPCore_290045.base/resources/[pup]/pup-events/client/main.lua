-- pup-events | client state and shared helpers.

EVC = {}
EVC.live = {}

function EVC.isLive(key) return EVC.live[key] == true end

RegisterNetEvent('pup-events:state', function(key, on)
    EVC.live[key] = on and true or nil
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(2000)
    TriggerServerEvent('pup-events:sync')
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    Wait(2000)
    TriggerServerEvent('pup-events:sync')
end)

-- ===========================================================================
-- HELPERS
-- ===========================================================================

function EVC.loadModel(name, timeoutMs)
    local hash <const> = type(name) == 'number' and name or GetHashKey(name)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) do
        Wait(50)
        waited = waited + 50
        if waited > (timeoutMs or 8000) then return nil end
    end
    return hash
end

-- ground under a point, or nil. Never trust the z that came out of a config.
function EVC.groundAt(x, y, z)
    local height = (z or 0.0) + 25.0
    for _ = 1, 8 do
        local found, gz = GetGroundZAndNormalFor_3dCoord(x, y, height)
        if found then return gz end
        height = height + 20.0
        Wait(0)
    end
    return nil
end

function EVC.randomInCircle(centre, radius)
    local ang <const> = math.random() * math.pi * 2
    local r <const> = math.sqrt(math.random()) * radius
    return centre.x + math.cos(ang) * r, centre.y + math.sin(ang) * r
end

-- APPLY_PED_DAMAGE_PACK
function EVC.gore(ped, pack, amount, mult)
    if not pack then return end
    Citizen.InvokeNative(0x46DF918788CB093F, ped, pack, amount or 100.0, mult or 1.0)
end

function EVC.setScale(ped, scale)
    if not scale or scale == 1.0 then return end
    SetPedScale(ped, scale + 0.0)
end

-- the hostile relationship group the trick-or-treat door mob uses
CreateThread(function()
    local _, g = AddRelationshipGroup('PUP_DEADOFNIGHT')
    EVC.relGroup = g or GetHashKey('PUP_DEADOFNIGHT')
    SetRelationshipBetweenGroups(5, EVC.relGroup, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), EVC.relGroup)
    SetRelationshipBetweenGroups(0, EVC.relGroup, EVC.relGroup)
end)

-- SET_RANDOM_OUTFIT_VARIATION: without it a ped spawns with no components and renders as nothing
function EVC.dress(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
end

function EVC.deleteEntity(e)
    if not e or e == 0 then return end
    if not DoesEntityExist(e) then return end
    SetEntityAsMissionEntity(e, true, true)
    DeleteEntity(e)
end
