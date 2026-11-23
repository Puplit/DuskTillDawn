-- pup_realestate | the world: door locks, locked signs and labels, blips, furniture

-- door system natives, through their declared names so the results come back typed (a raw
-- InvokeNative with no result type can hand back 0 for "not registered", which Lua treats as true)
local function isRegistered(hash)
    local r = IsDoorRegisteredWithSystem(hash)
    return r == true or r == 1
end

local function doorsOf(h)
    local list = {}
    if type(h.doors) == 'table' and type(h.doors[1]) == 'table' then list[#list + 1] = h.doors[1] end
    if h.kind == KIND_REAL then
        for _, d in ipairs(h.other or {}) do
            if type(d) == 'table' then list[#list + 1] = d end
        end
    end
    return list
end

-- door enforcement: near real-door houses keep the stored lock state ------------------------------

local lastRegister = {}

local function enforce(d)
    local hash = U.int(d.objc)
    if not hash or hash == 0 then return end
    local want = d.locked == true and 1 or 0
    local registered = isRegistered(hash)
    local state = registered and DoorSystemGetDoorState(hash) or -1
    if state == want then return end
    local now = GetGameTimer()
    if not registered and now - (lastRegister[hash] or -10000) >= 5000 then
        lastRegister[hash] = now
        AddDoorToSystemNew(hash, true, true, false, 0, 0, false)
        registered = isRegistered(hash)
    end
    if not registered then return end
    if want == 1 then
        DoorSystemSetOpenRatio(hash, 0.0, true)
        local model = U.int(d.doorhash)
        if model and model ~= 0 and d.x then
            local ent = GetClosestObjectOfType(d.x + 0.0, d.y + 0.0, d.z + 0.0, 1.5, model, false, false, false)
            if ent and ent ~= 0 then
                SetEntityRotation(ent, (tonumber(d.objYaw1) or 0.0) + 0.0, (tonumber(d.objYaw2) or 0.0) + 0.0,
                    (tonumber(d.objYaw3) or 0.0) + 0.0, 2, true)
            end
        end
    end
    DoorSystemSetDoorState(hash, want)
end

CreateThread(function()
    while true do
        local any = false
        if not Config.Doorlocks.enabled then
            for id in pairs(C.near) do
                local h = C.houses[id]
                if h and h.kind == KIND_REAL then
                    any = true
                    for _, d in ipairs(doorsOf(h)) do enforce(d) end
                end
            end
        end
        Wait(any and 250 or 1000)
    end
end)

-- locked signs, floating door labels and motel labels ----------------------------------------------

local labelIds = {}

local function clearLabels()
    for _, id in ipairs(labelIds) do UI:Remove3DInteraction(id) end
    labelIds = {}
end

local function addLabel(data)
    local id = 'pup_realestate:lbl:' .. (#labelIds + 1)
    if UI:Add3DInteraction(id, data) then labelIds[#labelIds + 1] = id end
end

local function labelSpot(d)
    if tonumber(d.o) and tonumber(d.p) and tonumber(d.q) then
        return vector3(d.o + 0.0, d.p + 0.0, d.q + 0.0)
    end
    local v = U.vec(d)
    return v and vector3(v.x, v.y, v.z + 1.1) or nil
end

local function rebuildLabels()
    clearLabels()
    local L = Config.Labels
    if L.floatingDoorLabels then
        for _, h in pairs(C.houses) do
            for i, d in ipairs(doorsOf(h)) do
                local spot = labelSpot(d)
                if spot then
                    local text, icon
                    if not h.owned then
                        text, icon = T('for_sale_price', U.money(h.price)), 'money'
                    elseif h.kind == KIND_REAL and d.locked == true and not Config.Doorlocks.enabled then
                        text, icon = T('house_title', h.id) .. ' - ' .. Locale.locked, 'lock'
                    else
                        text, icon = T('house_title', h.id), C.hasAccess(h) and 'key' or 'info'
                    end
                    if i == 1 or h.kind == KIND_REAL then addLabel({ coords = spot, text = text, icon = icon, distance = 8.0 }) end
                end
            end
        end
    elseif L.lockedSign and not Config.Doorlocks.enabled then
        local locked = {}
        for _, h in pairs(C.houses) do
            if h.kind == KIND_REAL then
                for _, d in ipairs(doorsOf(h)) do
                    local v = d.locked == true and U.vec(d)
                    if v then locked[#locked + 1] = v end
                end
            end
        end
        local used = {}
        for i, a in ipairs(locked) do
            if not used[i] then
                used[i] = true
                local spot = a
                for j = i + 1, #locked do
                    if not used[j] and #(a - locked[j]) <= L.lockedSignPairGap then
                        used[j] = true
                        spot = (a + locked[j]) / 2
                        break
                    end
                end
                addLabel({
                    coords = vector3(spot.x, spot.y, spot.z + L.lockedSignHeight),
                    text = Locale.locked, icon = 'padlock', style = 'lock', distance = L.lockedSignDistance,
                })
            end
        end
    end
    if Config.Motels.enabled and Config.Motels.labels then
        for key in pairs(Config.Motels.list) do
            local m = U.motel(key)
            local mine = C.roomAt(key)
            addLabel({
                coords = vector3(m.entrance.x, m.entrance.y, m.entrance.z + 1.0),
                text = mine and m.name or (m.name .. ' - $' .. U.money(m.price)),
                icon = mine and 'key' or 'money', distance = 8.0,
            })
        end
    end
end

-- blips --------------------------------------------------------------------------------------------

local blips = {}

local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function addBlip(pos, sprite, name)
    local b = BlipAddForCoords(1664425300, pos.x + 0.0, pos.y + 0.0, pos.z + 0.0) -- standard blip at coords
    if not b or b == 0 then return end
    SetBlipSprite(b, sprite, true)
    Citizen.InvokeNative(0xD38744167B2FA257, b, Config.Blips.scale) -- scale
    Citizen.InvokeNative(0x9CB1A1623062F402, b, CreateVarString(10, 'LITERAL_STRING', name)) -- name
    blips[#blips + 1] = b
end

local function rebuildBlips()
    clearBlips()
    if not C.charid then return end
    local realtor = Config.Blips.realtorSeesAll and C.job and C.job.job == Config.Jobs.realtor
    for id, h in pairs(C.houses) do
        local door = U.frontDoor(h)
        if door then
            if not h.owned then
                if Config.Blips.forSaleShown then addBlip(door, Config.Blips.forSale, Locale.blip_for_sale) end
            elseif C.hasAccess(h) or realtor then
                addBlip(door, Config.Blips.owned, T('blip_my_home', id))
            end
        end
    end
    for _, p in ipairs(Config.LedgerPoints) do addBlip(p.coords, p.blip, p.name) end
    if Config.Motels.enabled then
        for key in pairs(Config.Motels.list) do
            local m = U.motel(key)
            addBlip(m.entrance, m.blip, m.name)
        end
    end
end

-- one rebuild a second after the last change
local rebuildAt = nil

function C.queueWorldRebuild()
    local first = rebuildAt == nil
    rebuildAt = GetGameTimer() + Config.Timers.blipDelay
    if not first then return end
    CreateThread(function()
        while GetGameTimer() < rebuildAt do Wait(200) end
        rebuildAt = nil
        rebuildBlips()
        rebuildLabels()
    end)
end

C.onChange(function() C.queueWorldRebuild() end)
RegisterNetEvent('pup_realestate:cl_rooms', function() C.queueWorldRebuild() end)

-- furniture ----------------------------------------------------------------------------------------

local spawned = {}   -- house id -> { entities }
local spawnGen = {}  -- house id -> generation (a newer spawn or a despawn cancels an older one)

local function loadModel(model)
    model = U.int(model)
    if not model or not IsModelValid(model) then return nil end
    if HasModelLoaded(model) then return model end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 2000 do
        Wait(50)
        t = t + 50
    end
    return HasModelLoaded(model) and model or nil
end

local function despawn(id)
    spawnGen[id] = (spawnGen[id] or 0) + 1
    for _, e in ipairs(spawned[id] or {}) do
        if DoesEntityExist(e) then DeleteObject(e) end
    end
    spawned[id] = nil
end

local function spawn(id)
    despawn(id)
    local gen = spawnGen[id]
    local h = C.houses[id]
    if not h or type(h.furniture) ~= 'table' then return end
    CreateThread(function()
        local list = {}
        spawned[id] = list
        for _, p in ipairs(h.furniture) do
            if spawnGen[id] ~= gen then return end
            local model = loadModel(p.furnitem)
            if spawnGen[id] ~= gen then return end
            local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
            if model and x and y and z then
                local obj = CreateObject(model, x + 0.0, y + 0.0, z + 0.0, false, false, false)
                if obj and obj ~= 0 then
                    SetEntityHeading(obj, (tonumber(p.h) or 0.0) + 0.0)
                    FreezeEntityPosition(obj, true)
                    SetEntityAsMissionEntity(obj, true, true)
                    list[#list + 1] = obj
                end
                SetModelAsNoLongerNeeded(model)
            end
        end
    end)
end

function C.onNearChanged(old, new)
    for id in pairs(old or {}) do
        if not new[id] then despawn(id) end
    end
    for id in pairs(new or {}) do
        if not (old or {})[id] then spawn(id) end
    end
end

C.onChange(function(id, refresh)
    if id == nil then
        for hid in pairs(spawned) do
            if not C.near[hid] or not C.houses[hid] then despawn(hid) end
        end
        if refresh then
            for hid in pairs(C.near) do spawn(hid) end
        end
        return
    end
    if not C.houses[id] then return despawn(id) end
    if refresh and C.near[id] then spawn(id) end
end)

-- placing a piece: vorp_lib's gizmo when it is running, else pup-ui's placement tool
local PLACE_OWNER = 'pup_realestate:place'
local placeWait = nil

AddEventHandler('pup-ui:client:placeConfirm', function(owner, spot)
    if owner ~= PLACE_OWNER or not placeWait then return end
    placeWait:resolve(type(spot) == 'table' and spot or false)
end)

AddEventHandler('pup-ui:client:placeCancel', function(owner)
    if owner ~= PLACE_OWNER or not placeWait then return end
    placeWait:resolve(false)
end)

function C.cancelPlacement()
    if not C.placing then return end
    pcall(function() UI:CancelPlacement() end)
    if placeWait then placeWait:resolve(false) end
end

local function viaGizmo(model)
    local ped = C.ped()
    local at = GetOffsetFromEntityInWorldCoords(ped, 0.0, 1.5, 0.0)
    local obj = CreateObject(model, at.x, at.y, at.z, false, false, false)
    if not obj or obj == 0 then return nil, false end
    SetEntityCollision(obj, false, false)
    PlaceObjectOnGroundProperly(obj)
    local ok, res = pcall(function() return exports.vorp_lib:StartGizmo(obj, 200, false, false, true) end)
    if DoesEntityExist(obj) then DeleteObject(obj) end
    -- vorp_lib StartGizmo(handle, alpha, placeOnGround, deleteOnStop, createCam) returns
    -- { handle, position = vector3, rotation = vector3 } on apply, nil on cancel
    if not ok then
        print(('^3[pup_realestate]^7 vorp_lib StartGizmo failed, using pup-ui placement: %s'):format(tostring(res)))
        return nil, false
    end
    if type(res) ~= 'table' then return nil, true end
    local p = res.position or res.coords
    local r = res.rotation or {}
    if type(p) ~= 'table' and type(p) ~= 'vector3' then return nil, true end
    return { x = p.x, y = p.y, z = p.z, heading = (tonumber(r.z) or 0.0) % 360.0 }, true
end

local function viaPlacement(h, entry, model, insideThis)
    local door = U.frontDoor(h)
    local bounds
    if not insideThis and door then bounds = { x = door.x, y = door.y, z = door.z, radius = (tonumber(h.range) or 0) + 0.0 } end
    placeWait = promise.new()
    local started = UI:StartPlacement({ owner = PLACE_OWNER, model = model, grounded = true, title = entry.name, bounds = bounds })
    if not started then
        placeWait = nil
        return nil, false
    end
    local spot = Citizen.Await(placeWait)
    placeWait = nil
    return spot or nil, true
end

function C.placeFurniture(id, entry)
    if C.placing or C.busy then return end
    local h = C.houses[id]
    if not h or not C.hasAccess(h) then return end
    C.placing = true
    local insideThis = C.insideHouse(id)
    local model = loadModel(entry.model)
    local spot, started
    if model then
        if Config.Furniture.useGizmo and GetResourceState('vorp_lib') == 'started' then
            spot, started = viaGizmo(model)
        end
        if not started then spot, started = viaPlacement(h, entry, model, insideThis) end
        SetModelAsNoLongerNeeded(model)
    end
    C.placing = false
    -- a piece that will not load says so, instead of the range message
    if not model or not started then return C.tip(Locale.piece_failed) end
    if not spot then return end
    h = C.houses[id]
    if not h or not C.hasAccess(h) then return end
    local door = U.frontDoor(h)
    local pos = vector3(spot.x + 0.0, spot.y + 0.0, spot.z + 0.0)
    if not C.insideHouse(id) and (not door or #(pos - door) > (tonumber(h.range) or 0)) then
        return C.tip(Locale.out_of_range)
    end
    Menu.open(function()
        return {
            title = entry.name, subtitle = Locale.place_furniture,
            options = {
                { label = Locale.yes, select = function()
                    Send('sv_furnPlace', id, entry.key, { x = pos.x, y = pos.y, z = pos.z }, tonumber(spot.heading) or 0.0)
                    Menu.close()
                end },
                { label = Locale.no, select = function() Menu.close() end },
            },
        }
    end)
end

-- cleanup ------------------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    clearLabels()
    for id in pairs(spawned) do despawn(id) end
    if C.placing then pcall(function() UI:CancelPlacement() end) end
end)
