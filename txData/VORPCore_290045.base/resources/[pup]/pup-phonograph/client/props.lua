-- The list of phonographs and the local, non-networked props near the player.

PC = PC or {}
PC.Phonos = {}   -- [id] = public view from the server
PC.Spawned = {}  -- [id] = entity

local modelHash = joaat(Config.Model)

local function loadModel()
    if HasModelLoaded(modelHash) then return true end
    if not IsModelInCdimage(modelHash) then
        PC.WarnOnce('model', ('model %s is not in the game files'):format(Config.Model))
        return false
    end
    RequestModel(modelHash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < deadline do Wait(50) end
    return HasModelLoaded(modelHash)
end
PC.LoadModel = loadModel
PC.ModelHash = modelHash

local function despawn(id)
    local ent = PC.Spawned[id]
    PC.Spawned[id] = nil
    if ent and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteObject(ent)
    end
end

local function spawn(p)
    if not loadModel() then return end
    -- the list may have changed while the model loaded
    if PC.Phonos[p.id] ~= p or PC.Spawned[p.id] then return end
    local ent = CreateObject(modelHash, p.x, p.y, p.z, false, false, false)
    if not ent or ent == 0 then return end
    SetEntityCoordsNoOffset(ent, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(ent, (p.rotation and p.rotation.z or 0.0) + 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    PC.Spawned[p.id] = ent
end

local function clean(p)
    if type(p) ~= 'table' then return nil end
    local id = tonumber(p.id)
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not id or not x or not y or not z then return nil end
    local rot = type(p.rotation) == 'table' and p.rotation or {}
    return {
        id = id, x = x, y = y, z = z,
        rotation = { x = 0.0, y = 0.0, z = tonumber(rot.z) or 0.0 },
        job = type(p.job) == 'string' and p.job or '',
        rank = tonumber(p.rank) or 0,
        record = p.record,
        radius = tonumber(p.radius) or Config.Radius.default,
    }
end

RegisterNetEvent('pup-phonograph:client:list', function(list)
    if type(list) ~= 'table' then return end
    local fresh = {}
    for _, raw in ipairs(list) do
        local p = clean(raw)
        if p then fresh[p.id] = p end
    end
    for id in pairs(PC.Spawned) do
        local old, new = PC.Phonos[id], fresh[id]
        if not new or not old or old.x ~= new.x or old.y ~= new.y or old.z ~= new.z
            or old.rotation.z ~= new.rotation.z then
            despawn(id)
        end
    end
    PC.Phonos = fresh
end)

RegisterNetEvent('pup-phonograph:client:upsert', function(raw)
    local p = clean(raw)
    if not p then return end
    local old = PC.Phonos[p.id]
    if old and (old.x ~= p.x or old.y ~= p.y or old.z ~= p.z or old.rotation.z ~= p.rotation.z) then
        despawn(p.id)
    end
    PC.Phonos[p.id] = p
end)

RegisterNetEvent('pup-phonograph:client:remove', function(id)
    id = tonumber(id)
    if not id then return end
    despawn(id)
    PC.Phonos[id] = nil
end)

-- spawn and despawn about once a second
CreateThread(function()
    while true do
        Wait(1000)
        local pos = GetEntityCoords(PlayerPedId())
        local range = Config.Ranges.spawn
        -- snapshot first: spawn() can wait on the model load, and a list/upsert
        -- event that adds a new key during a pairs() walk is undefined in Lua
        local list = {}
        for _, p in pairs(PC.Phonos) do list[#list + 1] = p end
        for _, p in ipairs(list) do
            local id = p.id
            local d = #(pos - vector3(p.x, p.y, p.z))
            if d <= range then
                if not PC.Spawned[id] then spawn(p) end
            elseif PC.Spawned[id] then
                despawn(id)
            end
        end
        local gone = {}
        for id in pairs(PC.Spawned) do
            if not PC.Phonos[id] then gone[#gone + 1] = id end
        end
        for _, id in ipairs(gone) do despawn(id) end
    end
end)

function PC.DespawnAll()
    for id in pairs(PC.Spawned) do despawn(id) end
end
