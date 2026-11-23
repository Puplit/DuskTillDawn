-- pup_gunsmith | a weapon object laid on a bench: spawning, parts, turning about its centre
-- Shared by the bench user (client/bench.lua) and the players watching (client/preview.lua).

GunObj = {}

-- natives called by hash so the build does not depend on a particular name table
local N <const> = {
    CREATE_WEAPON_OBJECT                    = 0x9888652B8BA77F73,
    REQUEST_WEAPON_ASSET                    = 0x72D4CB5DB927009C,
    HAS_WEAPON_ASSET_LOADED                 = 0xFF07CF465F48B830,
    GIVE_WEAPON_COMPONENT_TO_ENTITY         = 0x74C9090FDD1BB48E,
    REMOVE_WEAPON_COMPONENT_FROM_OBJECT     = 0xF7D82B0D66777611,
    GET_WEAPON_COMPONENT_TYPE_MODEL         = 0x59DE03442B6C9598,
}
GunObj.N = N

local PIVOT_LIFT <const> = 0.06 -- a flipped gun must not sink into the bench

--- loads a component's model (if it has one); returns the model to release later, or nil
function GunObj.loadComponentModel(compHash)
    local model = Citizen.InvokeNative(N.GET_WEAPON_COMPONENT_TYPE_MODEL, compHash, Citizen.ResultAsInteger())
    if not model or model == 0 then return nil end
    if not IsModelValid(model) then return nil end
    RequestModel(model, false)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(25) end
    return HasModelLoaded(model) and model or nil
end

--- spawns the weapon model at `pos`, frozen, no collision. Returns a gun table or nil.
--- gun = { obj, hash, pivot, size, centre (local offset of the bbox centre) }
function GunObj.spawn(weaponHash, pos)
    Citizen.InvokeNative(N.REQUEST_WEAPON_ASSET, weaponHash, 31, 0)
    local deadline = GetGameTimer() + 5000
    while Citizen.InvokeNative(N.HAS_WEAPON_ASSET_LOADED, weaponHash, Citizen.ResultAsInteger()) ~= 1
        and GetGameTimer() < deadline do
        Wait(25)
    end
    local obj = Citizen.InvokeNative(N.CREATE_WEAPON_OBJECT, weaponHash, 0, pos.x, pos.y, pos.z, true, 1.0,
        Citizen.ResultAsInteger())
    if not obj or obj == 0 or not DoesEntityExist(obj) then return nil end
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    SetEntityCoordsNoOffset(obj, pos.x, pos.y, pos.z, false, false, false)
    SetEntityRotation(obj, 0.0, 0.0, 0.0, 2, true)

    local size, centre = 0.8, vector3(0.0, 0.0, 0.0)
    local ok, mn, mx = pcall(GetModelDimensions, GetEntityModel(obj))
    if ok and mn and mx then
        centre = vector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
        local diag = #(mx - mn)
        if diag > 0.0 then size = math.max(0.25, diag) end
    end
    local world = GetOffsetFromEntityInWorldCoords(obj, centre.x, centre.y, centre.z)
    local gun = {
        obj = obj,
        hash = weaponHash,
        pivot = vector3(world.x, world.y, world.z + PIVOT_LIFT),
        size = size,
        centre = centre,
        rot = vector3(0.0, 0.0, 0.0),
        models = {},
    }
    GunObj.rotate(gun, 0.0, 0.0, 0.0)
    return gun
end

--- sets the rotation, then moves the object so its centre stays on the pivot
function GunObj.rotate(gun, rx, ry, rz)
    if not gun or not DoesEntityExist(gun.obj) then return end
    gun.rot = vector3(rx, ry, rz)
    SetEntityRotation(gun.obj, rx, ry, rz, 2, true)
    local now = GetOffsetFromEntityInWorldCoords(gun.obj, gun.centre.x, gun.centre.y, gun.centre.z)
    local cur = GetEntityCoords(gun.obj)
    local fix = gun.pivot - now
    SetEntityCoordsNoOffset(gun.obj, cur.x + fix.x, cur.y + fix.y, cur.z + fix.z, false, false, false)
end

function GunObj.remove(gun, comp)
    if not gun or type(comp) ~= 'string' or not DoesEntityExist(gun.obj) then return end
    Citizen.InvokeNative(N.REMOVE_WEAPON_COMPONENT_FROM_OBJECT, gun.obj, joaat(comp))
end

function GunObj.fit(gun, comp)
    if not gun or type(comp) ~= 'string' or not DoesEntityExist(gun.obj) then return end
    local h = joaat(comp)
    local model = GunObj.loadComponentModel(h)
    if model then gun.models[model] = true end
    Citizen.InvokeNative(N.GIVE_WEAPON_COMPONENT_TO_ENTITY, gun.obj, h, gun.hash, true)
end

--- takes every listed variant off, then fits `comp` (nil = leave the slot empty)
function GunObj.swap(gun, variants, comp)
    for _, v in ipairs(variants or {}) do GunObj.remove(gun, v) end
    if comp then GunObj.fit(gun, comp) end
end

--- the variants of one catalogue category, plus an extra part (e.g. the fitted one)
function GunObj.variants(catalogue, cat, extra)
    local out, seen = {}, {}
    for _, v in ipairs((catalogue and catalogue[cat]) or {}) do
        if not seen[v.item] then out[#out + 1] = v.item; seen[v.item] = true end
    end
    if type(extra) == 'string' and not seen[extra] then out[#out + 1] = extra end
    return out
end

--- clears every category and fits a whole set: non-tints first, tints last
function GunObj.fitAll(gun, catalogue, set, previous)
    for cat in pairs(catalogue or {}) do
        GunObj.swap(gun, GunObj.variants(catalogue, cat, previous and previous[cat]), nil)
    end
    local tints = {}
    for cat, comp in pairs(set or {}) do
        if Catalogue.isTint(cat) then tints[cat] = comp else GunObj.fit(gun, comp) end
    end
    for _, comp in pairs(tints) do GunObj.fit(gun, comp) end
end

function GunObj.delete(gun)
    if not gun then return end
    if gun.obj and DoesEntityExist(gun.obj) then
        SetEntityAsMissionEntity(gun.obj, true, true)
        DeleteEntity(gun.obj)
    end
    for model in pairs(gun.models or {}) do SetModelAsNoLongerNeeded(model) end
    gun.obj = nil
end
