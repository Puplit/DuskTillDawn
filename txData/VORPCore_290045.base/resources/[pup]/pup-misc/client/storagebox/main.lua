-- storagebox | client: carrying a loaded box, putting it down, the placed boxes in the world, and the
-- events the vorp_inventory bridge listens to. The server decides everything; this file only draws.

local C = StorageBoxConfig
local L = StorageBoxLocale

local okCore, Core = pcall(function() return exports.vorp_core:GetCore() end)
if not okCore then Core = nil end

local carry       = nil   -- { rate, model, count } while the server has us carrying
local crate       = nil   -- the networked crate in our hands
local inHideout   = false
local puttingDown = false
local busy        = false -- a put-down, pick-up or open is running
local nearPlaced  = false -- the placed-box prompt owns the prompt bar this frame
local yieldUntil  = 0
local placed      = {}    -- boxId -> { boxId, x, y, z, h, label, model, obj }

local STREAM_IN, STREAM_OUT = 100.0, 120.0 -- placed-box objects exist only near the player
local UNARMED = GetHashKey('WEAPON_UNARMED')

local function tip(msg, ms)
    if Core and Core.NotifyRightTip then pcall(Core.NotifyRightTip, msg, ms or 4000) end
end

------------------------------------------------------------------------------ loaders
local function modelHash(m)
    if type(m) == 'number' then return m end
    return GetHashKey(tostring(m or C.Carry.defaultModel))
end

local function loadModel(hash)
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    return HasModelLoaded(hash)
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function playOnce(anim)
    if not loadDict(anim.dict) then return end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, 8.0, -8.0, anim.ms or -1, 0, 0, false, false, false)
end

------------------------------------------------------------------------------ prompts
local carryGroup  = GetRandomIntInRange(0, 0xffffff)
local placedGroup = GetRandomIntInRange(0, 0xffffff)
local putPrompt, openPrompt, pickPrompt

local function makePrompt(key, text, group)
    local p = PromptRegisterBegin()
    PromptSetControlAction(p, key)
    PromptSetText(p, CreateVarString(10, 'LITERAL_STRING', text))
    PromptSetEnabled(p, true)
    PromptSetVisible(p, true)
    PromptSetStandardMode(p, true)
    PromptSetGroup(p, group, 0)
    PromptRegisterEnd(p)
    return p
end

CreateThread(function()
    putPrompt  = makePrompt(C.Keys.putDown, L.promptPutDown, carryGroup)
    openPrompt = makePrompt(C.Keys.open, L.promptOpen, placedGroup)
    pickPrompt = makePrompt(C.Keys.pickUp, L.promptPickUp, placedGroup)
end)

-- another resource owns the prompt bar for a while (RedM draws one active group per frame)
AddEventHandler('pup:promptYield', function(ms)
    yieldUntil = GetGameTimer() + (tonumber(ms) or 250)
end)

------------------------------------------------------------------------------ the crate in our hands
local function setHandFlags(enabled)
    for _, f in ipairs(C.Carry.handFlags or {}) do
        Citizen.InvokeNative(C.Carry.handFlagNative, PlayerPedId(), f, enabled)
    end
end

local function deleteCrate()
    if crate and DoesEntityExist(crate) then
        DetachEntity(crate, true, true)
        SetEntityAsMissionEntity(crate, true, true)
        DeleteObject(crate)
    end
    crate = nil
end

local function attachCrate(model)
    local hash = modelHash(model)
    if not loadModel(hash) then return end
    -- carrying may have stopped while the model loaded
    if not carry or (crate and DoesEntityExist(crate)) then return end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local obj = CreateObject(hash, pos.x, pos.y, pos.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end
    SetEntityCollision(obj, false, false)
    local o, r = C.Carry.offset, C.Carry.rotation
    -- the full 15-argument attach; the shorter wrapper turns the crate sideways. The offset and
    -- rotation in the config were measured against exactly these trailing flags (rotation order 1,
    -- fixed rotation on): other flags tip the crate over in the hand
    Citizen.InvokeNative(0x6B9BBD38AB0796DF, obj, ped, GetEntityBoneIndexByName(ped, C.Carry.bone),
        o[1], o[2], o[3], r[1], r[2], r[3], true, true, false, true, 1, true)
    crate = obj
end

local function playCarryAnim()
    local a = C.Carry.anim
    if not loadDict(a.dict) then return end
    TaskPlayAnim(PlayerPedId(), a.dict, a.clip, a.blendIn, a.blendOut, -1, a.flag, 0, false, false, false)
end

------------------------------------------------------------------------------ putting the box down
local function putDown()
    if busy or not carry then return end
    local ped = PlayerPedId()
    if IsPedOnMount(ped) or IsPedInAnyVehicle(ped, false) then return end
    busy = true
    local P = C.PutDown
    local pos = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local footZ = pos.z - 1.0
    local rayZ = footZ + P.rayHeight
    local ray = StartShapeTestRay(pos.x, pos.y, rayZ, pos.x + fwd.x * P.rayLength, pos.y + fwd.y * P.rayLength, rayZ, 1, ped, 7)
    local status, hit, endPos = 1, false, nil
    local deadline = GetGameTimer() + 500
    repeat
        status, hit, endPos = GetShapeTestResult(ray)
        if status == 1 then Wait(0) end
    until status ~= 1 or GetGameTimer() > deadline

    local dist = P.maxDistance
    if (hit == true or hit == 1) and endPos then
        local d = #(vector3(endPos.x, endPos.y, rayZ) - vector3(pos.x, pos.y, rayZ))
        dist = math.max(P.minDistance, math.min(P.maxDistance, d - P.wallMargin))
        tip(L.wall, 3000)
    end
    local x, y, h = pos.x + fwd.x * dist, pos.y + fwd.y * dist, GetEntityHeading(ped)

    puttingDown = true
    playOnce(C.Anims.putDown)
    Wait(C.Anims.putDown.ms)
    puttingDown = false
    TriggerServerEvent('pup-misc:storagebox:place', x, y, footZ, h)
    busy = false
end

------------------------------------------------------------------------------ the carry loop (runs only while carrying)
local wagonUntil = 0

local function carryFrame(ped)
    SetPedMaxMoveBlendRatio(ped, carry.rate)
    local _, current = GetCurrentPedWeapon(ped, true, 0, false)
    if current ~= UNARMED then SetCurrentPedWeapon(ped, UNARMED, true, 0, false, false) end
    Citizen.InvokeNative(0xC1E8A365BF3B29F2, ped, C.Carry.resetFlag, true)
    for _, ctl in ipairs(C.Carry.blockedControls) do DisableControlAction(0, ctl, true) end

    local a = C.Carry.anim
    if not puttingDown and not busy and not IsEntityPlayingAnim(ped, a.dict, a.clip, 3) then playCarryAnim() end

    -- streaming can delete the crate inside a hideout interior: put it back
    if inHideout and (not crate or not DoesEntityExist(crate)) then attachCrate(carry.model) end

    if GetGameTimer() > wagonUntil and (IsPedGettingIntoAVehicle(ped) or (Citizen.InvokeNative(0xF92691AED837A5FC, ped, Citizen.ResultAsInteger()) or 0) ~= 0) then -- GET_VEHICLE_PED_IS_ENTERING
        wagonUntil = GetGameTimer() + C.Carry.wagonDebounceMs
        tip(L.noWagon, 3000)
        SetTimeout(C.Carry.wagonEjectMs, function()
            local p = PlayerPedId()
            ClearPedTasksImmediately(p)
            SetPedToRagdoll(p, C.Carry.ragdollMinMs, C.Carry.ragdollMaxMs, 0, false, false, false)
        end)
    end

    if not inHideout and not busy and not nearPlaced and putPrompt and GetGameTimer() >= yieldUntil then
        PromptSetActiveGroupThisFrame(carryGroup, CreateVarString(10, 'LITERAL_STRING', L.promptGroup))
        if PromptHasStandardModeCompleted(putPrompt) then CreateThread(putDown) end
    end
end

local function carryLoop()
    while carry do
        carryFrame(PlayerPedId())
        Wait(0)
    end
end

local function stopCarry()
    local was = carry ~= nil
    carry = nil
    deleteCrate()
    if not was then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    SetPedMaxMoveBlendRatio(ped, C.Carry.restoreMoveRate)
    setHandFlags(true)
end

local function startCarry(state)
    local was = carry ~= nil
    local oldModel = carry and carry.model
    carry = { rate = tonumber(state.rate) or C.Carry.defaultMoveRate, model = state.model, count = tonumber(state.count) or 1 }
    inHideout = state.hideout == true
    if not was then setHandFlags(false) end
    if not crate or not DoesEntityExist(crate) or oldModel ~= carry.model then
        deleteCrate()
        attachCrate(carry.model)
    end
    playCarryAnim()
    if not was then CreateThread(carryLoop) end
end

exports('IsCarrying', function() return carry ~= nil end)

------------------------------------------------------------------------------ placed boxes
local function spawnPlaced(e)
    if e.obj and DoesEntityExist(e.obj) then return end
    local hash = modelHash(e.model)
    if not loadModel(hash) then return end
    local obj = CreateObject(hash, e.x, e.y, e.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end
    SetEntityHeading(obj, (tonumber(e.h) or 0.0) + 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    e.obj = obj
end

local function despawnPlaced(e)
    if e.obj and DoesEntityExist(e.obj) then
        SetEntityAsMissionEntity(e.obj, true, true)
        DeleteObject(e.obj)
    end
    e.obj = nil
end

local function clearPlaced()
    for _, e in pairs(placed) do despawnPlaced(e) end
    placed = {}
end

local function addPlaced(e)
    if type(e) ~= 'table' or type(e.boxId) ~= 'string' then return end
    if placed[e.boxId] then despawnPlaced(placed[e.boxId]) end
    placed[e.boxId] = {
        boxId = e.boxId, x = tonumber(e.x) or 0.0, y = tonumber(e.y) or 0.0, z = tonumber(e.z) or 0.0,
        h = tonumber(e.h) or 0.0, label = tostring(e.label or L.promptGroup), model = e.model,
    }
end

local function openPlaced(e)
    if busy then return end
    busy = true
    local ped = PlayerPedId()
    local a = C.Anims.inspect
    if loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.clip, 8.0, -8.0, -1, a.flag, 0, false, false, false) end
    FreezeEntityPosition(ped, true)
    TriggerServerEvent('pup-misc:storagebox:openPlaced', e.boxId)
    Wait(C.InspectFocusWaitMs)
    -- crouch until the panel closes (or never opened)
    local started, seen = GetGameTimer(), false
    while true do
        local focused = IsNuiFocused()
        if focused then seen = true end
        if (seen and not focused) or (not seen and GetGameTimer() - started > C.InspectFocusGraceMs) then break end
        Wait(C.InspectFocusPollMs)
    end
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
    busy = false
end

local function pickUpPlaced(e)
    if busy then return end
    busy = true
    playOnce(C.Anims.pickUp)
    Wait(C.Anims.pickUp.ms)
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('pup-misc:storagebox:pickup', e.boxId)
    busy = false
end

CreateThread(function()
    while true do
        local nearest, nd = nil, math.huge
        if next(placed) then
            local pos = GetEntityCoords(PlayerPedId())
            for _, e in pairs(placed) do
                local d = #(pos - vector3(e.x, e.y, e.z))
                if d < STREAM_IN then spawnPlaced(e) elseif d > STREAM_OUT then despawnPlaced(e) end
                if d < nd then nearest, nd = e, d end
            end
        end
        if nearest and nd <= C.PromptRadius and openPrompt then
            -- in range: draw the prompt every frame for a short slice, then re-measure
            local slice = GetGameTimer() + 500
            nearPlaced = true
            while GetGameTimer() < slice and placed[nearest.boxId] do
                if not busy then
                    PromptSetActiveGroupThisFrame(placedGroup, CreateVarString(10, 'LITERAL_STRING', nearest.label))
                    if PromptHasStandardModeCompleted(openPrompt) then
                        local target = nearest
                        CreateThread(function() openPlaced(target) end)
                    elseif PromptHasStandardModeCompleted(pickPrompt) then
                        local target = nearest
                        CreateThread(function() pickUpPlaced(target) end)
                    end
                end
                Wait(0)
            end
            nearPlaced = false
        elseif nearest and nd < 20.0 then
            Wait(250)
        else
            Wait(1000)
        end
    end
end)

------------------------------------------------------------------------------ the vorp_inventory bridge: name lists
local function sendNames()
    local boxes, packs = {}, {}
    for name in pairs(C.Boxes or {}) do boxes[#boxes + 1] = name end
    for name in pairs(C.Packs or {}) do
        boxes[#boxes + 1] = name
        packs[#packs + 1] = name
    end
    table.sort(boxes)
    table.sort(packs)
    TriggerEvent('pup_storagebox:boxNamesToNUI', boxes, L.usedBoxAtShop, packs)
end

AddEventHandler('pup_storagebox:requestBoxNames', sendNames)

AddEventHandler('onClientResourceStart', function(res)
    if res == 'vorp_inventory' then SetTimeout(1000, sendNames) end
end)

------------------------------------------------------------------------------ server events
RegisterNetEvent('pup-misc:storagebox:carry', function(state)
    if type(state) == 'table' then startCarry(state) else stopCarry() end
end)

RegisterNetEvent('pup-misc:storagebox:hideout', function(inside)
    inside = inside == true
    local was = inHideout
    inHideout = inside
    if was and not inside and carry then
        -- leaving a hideout: drop the crate now, ask for the carry state again shortly
        deleteCrate()
        SetTimeout(4000, function() TriggerServerEvent('pup-misc:storagebox:requestState') end)
    end
end)

RegisterNetEvent('pup-misc:storagebox:placedList', function(list)
    clearPlaced()
    for _, e in ipairs(type(list) == 'table' and list or {}) do addPlaced(e) end
end)

RegisterNetEvent('pup-misc:storagebox:placedAdd', addPlaced)

RegisterNetEvent('pup-misc:storagebox:placedRemove', function(boxId)
    local e = placed[boxId]
    if not e then return end
    despawnPlaced(e)
    placed[boxId] = nil
end)

-- the server asks before it opens a box: close the inventory first, then answer
RegisterNetEvent('pup-misc:storagebox:confirmOpen', function(token)
    pcall(function() exports.vorp_inventory:closeInventory() end)
    TriggerServerEvent('pup-misc:storagebox:openConfirmed', token)
end)

RegisterNetEvent('pup-misc:storagebox:filterData', function(data)
    if type(data) ~= 'table' then return end
    TriggerEvent('pup_storagebox:packFilterNUI', data)
end)

RegisterNetEvent('pup-misc:storagebox:stop', stopCarry)

------------------------------------------------------------------------------ start and stop
CreateThread(function()
    Wait(C.StateResendMs)
    TriggerServerEvent('pup-misc:storagebox:requestState')
    sendNames()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopCarry()
    clearPlaced()
    for _, p in ipairs({ putPrompt, openPrompt, pickPrompt }) do
        if p then PromptDelete(p) end
    end
end)
