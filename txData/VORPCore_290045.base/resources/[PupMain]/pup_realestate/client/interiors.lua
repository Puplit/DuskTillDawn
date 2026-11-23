-- pup_realestate | interiors: teleporter houses and motel rooms, the leash, knocking, relog placement,
-- forced exits and the character-switch reset

local EXIT_LABEL = 'pup_realestate:exit'

local function fadeOut()
    DoScreenFadeOut(500)
    local t = 0
    while not IsScreenFadedOut() and t < 3000 do
        Wait(50)
        t = t + 50
    end
end

local function fadeIn()
    DoScreenFadeIn(500)
end

-- teleport and hold the player until the ground is there and they stop falling
-- (one try a second, up to maxSeconds)
local function teleport(pos, maxSeconds)
    if not pos then return end
    local ped = C.ped()
    FreezeEntityPosition(ped, true)
    for _ = 1, math.max(1, maxSeconds or 10) do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
        Wait(1000)
        ped = C.ped()
        if HasCollisionLoadedAroundEntity(ped) and not IsPedFalling(ped) then break end
    end
    FreezeEntityPosition(C.ped(), false)
end

local function setBucket(rowId)
    return Rpc('sv_bucket', nil, rowId or 0) == true
end

local function loadImaps(list)
    for _, name in ipairs(list or {}) do RequestImap(GetHashKey(name)) end
end

local function unloadImaps(list)
    for _, name in ipairs(list or {}) do RemoveImap(GetHashKey(name)) end
end

local function weather(inside)
    if not Config.Rules.forceInteriorWeather or GetResourceState('weathersync') ~= 'started' then return end
    -- weathersync client exports: setSyncEnabled(bool), setMyWeather(name, transition, permanentSnow),
    -- setMyTime(h, m, s, transitionMs); the last two also switch sync off themselves
    local ok, err = pcall(function()
        if inside then
            exports.weathersync:setSyncEnabled(false)
            exports.weathersync:setMyWeather('SUNNY', 0.0, false)
            exports.weathersync:setMyTime(0, 0, 0, 0)
        else
            exports.weathersync:setSyncEnabled(true)
        end
    end)
    if not ok then print(('^3[pup_realestate]^7 weathersync call failed: %s'):format(tostring(err))) end
end

local function showExitLabel(text, pos)
    UI:Add3DInteraction(EXIT_LABEL, {
        coords = vector3(pos.x, pos.y, pos.z + 1.1), text = text, icon = 'home', distance = 8.0,
    })
end

local function rememberOutside()
    if not Config.Underground or not C.charid then return end
    local p = C.pos()
    TriggerServerEvent('pup_hideouts:sendlastcoords', C.charid, { x = p.x, y = p.y, z = p.z })
end

-- teleporter house -------------------------------------------------------------------------------

local function enterHouseQuiet(id, int)
    local imaps = int.imaps or {}
    loadImaps(imaps)
    if not setBucket(id) then
        unloadImaps(imaps)
        return false
    end
    C.inside = { row = id, kind = 'house', imaps = imaps, entry = int.entry, range = tonumber(int.range) or 50.0 }
    C.refreshNear()
    showExitLabel(T('house_exit', id), int.entry)
    weather(true)
    return true
end

-- owners and keyholders from the door menu, guests once the server lets them in
function C.enterHouse(id)
    if C.busy or C.inside then return end
    local h = C.houses[id]
    local int = U.interior(h)
    if not int then return end
    C.busy = true
    UI:DoorSound('unlock')
    TriggerEvent('pup-scene:stopscene', false)
    rememberOutside()
    Send('sv_enter', id)
    fadeOut()
    -- lets a stable resource put away the player's horse
    TriggerEvent('pup-stable:deletehorse')
    if enterHouseQuiet(id, int) then
        teleport(int.entry, 10)
    else
        Send('sv_left')
    end
    fadeIn()
    C.busy = false
end

function C.leaveHouse()
    local ins = C.inside
    if not ins or ins.kind ~= 'house' or C.leaving then return end
    C.leaving = true
    C.busy = true
    local id = ins.row
    C.inside = nil
    C.knocks = {}
    C.refreshNear()
    UI:Remove3DInteraction(EXIT_LABEL)
    weather(false)
    TriggerEvent('pup-scene:stopscene', true)
    fadeOut()
    unloadImaps(ins.imaps)
    setBucket(0)
    local h = C.houses[id]
    local dest = (h and U.frontDoor(h)) or U.nearestFallback(C.pos())
    teleport(dest, 10)
    fadeIn()
    Send('sv_left')
    C.busy = false
    C.leaving = false
end

-- knocking at someone else's teleporter house
function C.knock(id)
    if C.busy then return end
    C.busy = true
    Send('sv_knock', id)
    local a = Config.Anims.knock
    RequestAnimDict(a.dict)
    local t = 0
    while not HasAnimDictLoaded(a.dict) and t < 2000 do
        Wait(50)
        t = t + 50
    end
    if HasAnimDictLoaded(a.dict) then
        TaskPlayAnim(C.ped(), a.dict, a.name, 8.0, -8.0, a.ms or 3000, 1, 0, false, false, false)
    end
    Wait(a.ms or 3000)
    ClearPedTasks(C.ped())
    C.busy = false
end

-- the server let us in (a knock was answered, or a viewing of a teleporter house for sale)
RegisterNetEvent('pup_realestate:cl_letIn', function(id)
    id = U.int(id)
    if not id or C.inside then return end
    local t = 0
    while C.busy and t < 5000 do -- still knocking
        Wait(100)
        t = t + 100
    end
    local h = C.houses[id]
    local door = h and U.frontDoor(h)
    if not door or #(C.pos() - door) > 10.0 then return end
    C.enterHouse(id)
end)

-- motel rooms --------------------------------------------------------------------------------------

local function enterMotelQuiet(rowId, key)
    if not setBucket(rowId) then return false end
    local m = U.motel(key)
    C.inside = { row = rowId, kind = 'motel', motel = key, entry = Config.MotelRoom.exit, range = m and m.leash or Config.Motels.defaults.leash }
    if Config.Motels.labels then showExitLabel(Locale.hotel_exit, Config.MotelRoom.exit) end
    TriggerEvent('fred_meta:switch', false)
    return true
end

function C.enterMotel(rowId, key)
    if C.busy or C.inside then return end
    C.busy = true
    UI:DoorSound('unlock')
    TriggerEvent('pup-scene:stopscene', false)
    rememberOutside()
    Send('sv_enter', rowId)
    fadeOut()
    TriggerEvent('pup-stable:deletehorse')
    if enterMotelQuiet(rowId, key) then
        teleport(Config.MotelRoom.exit, 10)
    else
        Send('sv_left')
    end
    fadeIn()
    C.busy = false
end

function C.leaveMotel()
    local ins = C.inside
    if not ins or ins.kind ~= 'motel' or C.leaving then return end
    C.leaving = true
    C.busy = true
    C.inside = nil
    UI:Remove3DInteraction(EXIT_LABEL)
    TriggerEvent('fred_meta:switch', true)
    UI:DoorSound('unlock')
    TriggerEvent('pup-scene:stopscene', true)
    fadeOut()
    setBucket(0)
    local m = U.motel(ins.motel)
    teleport((m and m.entrance) or U.nearestFallback(C.pos()), 10)
    fadeIn()
    Send('sv_left')
    C.busy = false
    C.leaving = false
end

-- the server sends occupants out (house sold, repossessed, seized, keys taken, viewing over)
RegisterNetEvent('pup_realestate:cl_forceLeave', function(rowId)
    local ins = C.inside
    if not ins or ins.row ~= U.int(rowId) then return end
    if Menu then Menu.close() end
    CreateThread(function()
        while C.busy and not C.leaving do Wait(100) end
        if ins.kind == 'house' then C.leaveHouse() else C.leaveMotel() end
    end)
end)

-- the leash: inside an interior, wandering past its range puts you back at the entry
CreateThread(function()
    while true do
        local ins = C.inside
        if ins and ins.entry and not C.busy then
            Wait(250)
            local pos = C.pos()
            if #(pos - ins.entry) > (ins.range or 50.0) then
                SetEntityCoords(C.ped(), ins.entry.x, ins.entry.y, ins.entry.z, false, false, false, false)
            end
        else
            Wait(1000)
        end
    end
end)

-- relog -----------------------------------------------------------------------------------------

local shine = nil

-- pup_hideouts always answers: the stored spot, else its own first fallback spot, else the origin
-- (it never sends nil). The origin means "nothing stored", so it falls through to our nearest fallback.
RegisterNetEvent('pup_realestate:reclastshinecoords', function(coords)
    local p = shine
    if not p then return end
    shine = nil
    local v = U.vec(coords)
    if v and math.abs(v.x) < 1.0 and math.abs(v.y) < 1.0 and math.abs(v.z) < 1.0 then v = nil end
    p:resolve(v or false)
end)

local function lastOutdoor()
    if not Config.Underground or GetResourceState('pup_hideouts') ~= 'started' then return nil end
    local p = promise.new()
    shine = p
    TriggerServerEvent('pup_hideouts:getlastshinecoords', C.charid)
    SetTimeout(10000, function() if shine == p then p:resolve(false) end end)
    local v = Citizen.Await(p)
    shine = nil
    return v or nil
end

-- put the player outside: the given spot, else pup_hideouts' last outdoor spot, else the nearest fallback
local function placeOutside(dest)
    C.busy = true
    fadeOut()
    setBucket(0)
    if not dest then dest = lastOutdoor() end
    if not dest then dest = U.nearestFallback(C.pos()) end
    teleport(dest, dest and 60 or 10)
    FreezeEntityPosition(C.ped(), false)
    fadeIn()
    Send('sv_left')
    C.busy = false
end

local function doorOfRecord(record)
    if record.kind == 'house' then
        local h = C.houses[record.id]
        return h and U.frontDoor(h) or nil
    end
    local m = U.motel(record.motel)
    return m and m.entrance or nil
end

function C.handleRelog(record)
    if type(record) ~= 'table' or record.kind == 'gone' then
        -- no record: someone standing in an interior spot is moved out (and back to the world bucket)
        Wait(1000)
        local pos = C.pos()
        local stuck = #(pos - Config.MotelRoom.exit) <= 5.0
        for _, int in pairs(Config.Interiors) do
            if #(pos - int.entry) <= 10.0 then stuck = true end
        end
        if stuck then placeOutside(U.nearestFallback(pos)) end
        return
    end
    if record.outside then
        -- a guest or former owner logs back in at the door, not at a random fallback
        return placeOutside(doorOfRecord(record))
    end
    if Config.SafeExitOnRelog then
        return placeOutside(doorOfRecord(record))
    end
    -- re-enter silently
    if record.kind == 'house' then
        local h = C.houses[record.id]
        local int = U.interior(h)
        if not int then return placeOutside(nil) end
        TriggerEvent('pup-scene:stopscene', false)
        if not enterHouseQuiet(record.id, int) then placeOutside(U.frontDoor(h)) end
    else
        if not enterMotelQuiet(record.id, record.motel) then placeOutside(doorOfRecord(record)) end
    end
end

-- character switch: forget the old character's interior and go back to the world first
function C.resetForSwitch()
    local ins = C.inside
    C.inside = nil
    C.knocks = {}
    UI:Remove3DInteraction(EXIT_LABEL)
    if ins then
        if ins.kind == 'house' then
            unloadImaps(ins.imaps)
            weather(false)
        else
            TriggerEvent('fred_meta:switch', true)
        end
    end
    FreezeEntityPosition(C.ped(), false)
    C.busy = false
    C.leaving = false
    if C.cancelCreator then C.cancelCreator(true) end
    if C.cancelPlacement then C.cancelPlacement() end
    C.refreshNear()
    if ins then CreateThread(function() setBucket(0) end) end
end

-- resource stop: unfreeze, labels off, weather back
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    UI:Remove3DInteraction(EXIT_LABEL)
    if C.inside then
        FreezeEntityPosition(C.ped(), false)
        if C.inside.kind == 'house' then weather(false) else TriggerEvent('fred_meta:switch', true) end
    end
    if C.busy then DoScreenFadeIn(0) end
end)
