-- Every placed prop is known, but only the ones near the player exist as objects.

local known   = {}  -- [id] = row, everything the server has
local spawned = {}  -- [id] = entity, only what is near us
local buckets = {}  -- ["bx:by"] = { id, id, ... }
local missing = {}  -- models that do not exist on this client, reported once
local pending = {}  -- model -> passes spent waiting for it to stream in

local function bucketKey(x, y)
    local s <const> = Config.Streaming.bucketSize
    return ('%d:%d'):format(math.floor(x / s), math.floor(y / s))
end

local function indexProp(p)
    local k <const> = bucketKey(p.x, p.y)
    buckets[k] = buckets[k] or {}
    buckets[k][p.id] = true
end

local function unindexProp(p)
    local k <const> = bucketKey(p.x, p.y)
    if buckets[k] then buckets[k][p.id] = nil end
end

local function despawn(id)
    local e = spawned[id]
    if e and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteObject(e)
    end
    spawned[id] = nil
end

local function spawn(p)
    if spawned[p.id] then return end
    if missing[p.model] then return end

    local model <const> = GetHashKey(p.model)
    if not IsModelValid(model) then
        missing[p.model] = true
        if Config.General.warnMissingModels then
            print(('^1[pup-props]^7 model does not exist on this client: %s (prop #%d)')
                :format(tostring(p.model), p.id))
        end
        return
    end

    -- request without blocking; a later pass spawns it once loaded
    if not HasModelLoaded(model) then
        RequestModel(model)
        local n <const> = (pending[p.model] or 0) + 1
        pending[p.model] = n
        if n == 60 and Config.General.warnMissingModels then
            print(('^3[pup-props]^7 still waiting on %s (prop #%d) - streamed asset not loading')
                :format(tostring(p.model), p.id))
        end
        return
    end
    pending[p.model] = nil

    -- not networked: every client builds its own copy from the same row
    local obj = CreateObject(model, p.x, p.y, p.z, false, false, false)
    if not DoesEntityExist(obj) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    SetEntityRotation(obj, p.rx or 0.0, p.ry or 0.0, p.rz or 0.0, 2, true)
    SetEntityCollision(obj, p.collision ~= false, true)
    if p.frozen ~= false then FreezeEntityPosition(obj, true) end
    SetEntityCanBeDamaged(obj, false)
    SetModelAsNoLongerNeeded(model)

    spawned[p.id] = obj
end

-- SERVER PUSHES

RegisterNetEvent('pup-props:all', function(all)
    for id in pairs(known) do despawn(id) end
    known, buckets = {}, {}
    for _, p in pairs(all or {}) do
        known[p.id] = p
        indexProp(p)
    end
end)

RegisterNetEvent('pup-props:added', function(p)
    if type(p) ~= 'table' or not p.id then return end
    known[p.id] = p
    indexProp(p)
end)

RegisterNetEvent('pup-props:removed', function(id)
    id = tonumber(id)
    local p = id and known[id]
    if not p then return end
    despawn(id)
    unindexProp(p)
    known[id] = nil
end)

-- PROXIMITY PASS (only the buckets touching the radius are walked)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('pup-props:hello')

    while true do
        Wait(Config.Streaming.scanIntervalMs)

        local here <const> = GetEntityCoords(PlayerPedId())
        local r <const> = Config.Streaming.radius
        local s <const> = Config.Streaming.bucketSize
        local want = {}

        local bx0, bx1 = math.floor((here.x - r) / s), math.floor((here.x + r) / s)
        local by0, by1 = math.floor((here.y - r) / s), math.floor((here.y + r) / s)

        for bx = bx0, bx1 do
            for by = by0, by1 do
                local b = buckets[('%d:%d'):format(bx, by)]
                if b then
                    for id in pairs(b) do
                        local p = known[id]
                        if p and #(here - vector3(p.x, p.y, p.z)) <= r then
                            want[id] = true
                        end
                    end
                end
            end
        end

        for id in pairs(want) do
            if not spawned[id] then spawn(known[id]) end
        end
        for id in pairs(spawned) do
            if not want[id] then despawn(id) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
end)

exports('NearestProp', function(maxDist)
    local here <const> = GetEntityCoords(PlayerPedId())
    local best, bestd
    for id, p in pairs(known) do
        local d = #(here - vector3(p.x, p.y, p.z))
        if not bestd or d < bestd then best, bestd = p, d end
    end
    if best and bestd <= (tonumber(maxDist) or 10.0) then return best, bestd end
    return nil
end)

exports('PlacedCount', function()
    local n = 0
    for _ in pairs(known) do n = n + 1 end
    return n
end)
