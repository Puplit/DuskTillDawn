-- Placeables: set a campfire down, pick it back up with /dc.
local placedObj = nil
local lastPickup = 0
local placing = false

local function inBannedTown()
    local c = GetEntityCoords(PlayerPedId())
    local zone = Citizen.InvokeNative(0x43AD8FC02B429D33, c.x, c.y, c.z, 1) -- GetMapZoneAtCoords, town level
    if not zone or zone == 0 then return false end
    for _, name in ipairs(Config.BannedTowns) do
        if zone == joaat(name) then return true end
    end
    return false
end

local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local waited = 0
    while not HasModelLoaded(hash) and waited < 5000 do
        Wait(50)
        waited = waited + 50
    end
    return HasModelLoaded(hash)
end

local function spawn(model)
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.0, 0.0)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false)
    SetEntityHeading(obj, GetEntityHeading(ped))
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    placedObj = obj
end

local function removeObj()
    if placedObj and DoesEntityExist(placedObj) then
        SetEntityAsMissionEntity(placedObj, true, true)
        DeleteObject(placedObj)
    end
    placedObj = nil
end

RegisterNetEvent('pup_workbench:place:begin', function(item)
    local def = type(item) == 'string' and Config.Placeables.items[item]
    if not def or placing then return end
    if placedObj and DoesEntityExist(placedObj) then
        return Notify(L('already_placed', Config.Placeables.pickupCommand))
    end
    if def.townLock and inBannedTown() then return Notify(L('no_town')) end

    placing = true
    local ped = PlayerPedId()
    TaskStartScenarioInPlace(ped, joaat('WORLD_HUMAN_CROUCH_INSPECT'), Config.Placeables.placeMs, true, false, false, false)
    local p = promise.new()
    local done = false
    local function finish()
        if done then return end
        done = true
        p:resolve(true)
    end
    local shown = pcall(function()
        exports['pup-ui']:Progress({ label = L('placing'), duration = Config.Placeables.placeMs }, finish)
    end)
    SetTimeout(Config.Placeables.placeMs + (shown and 1500 or 0), finish)
    Citizen.Await(p)
    ClearPedTasks(PlayerPedId())

    if IsEntityDead(PlayerPedId()) then
        placing = false
        return
    end
    local res = Req('place', { item = item })
    if type(res) == 'table' and res.ok and type(res.model) == 'string' then
        spawn(res.model)
    else
        Notify(type(res) == 'table' and res.msg or L('place_failed'))
    end
    placing = false
end)

RegisterCommand(Config.Placeables.pickupCommand, function()
    local now = GetGameTimer()
    if now - lastPickup < Config.Placeables.pickupCooldownMs then return end
    lastPickup = now
    CreateThread(function()
        local res = Req('pickup')
        if type(res) == 'table' and res.ok then removeObj() end
        if type(res) == 'table' and res.msg then Notify(res.msg) end
    end)
end, false)

-- character switch: the prop belonged to the previous character (the server keeps
-- that character's record, so switching back still lets /dc return the item)
RegisterNetEvent('vorp:SelectedCharacter', function(charid)
    removeObj()
    Prefs.charid = tonumber(charid)
    Prefs.load()
    if Bench.open then Bench.close() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeObj()
end)

-- vorp_admin world cleanup: the server has forgotten the campfire and returned the item
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    removeObj()
end)

-- after a resource restart while already in game: learn the character and stations
CreateThread(function()
    Wait(2000)
    for _ = 1, 20 do
        local res = Req('hello')
        if type(res) == 'table' then
            if res.charid and not Prefs.charid then
                Prefs.charid = tonumber(res.charid)
                Prefs.load()
            end
            if type(res.stations) == 'table' then TriggerEvent('pup_workbench:stations', res.stations) end
            return
        end
        Wait(5000)
    end
end)
