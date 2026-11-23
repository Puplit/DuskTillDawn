-- pup-events | The Spring Hunt, client.
-- the server sends x/y only; the ground is found here and eggs in water or off-mesh are skipped

local Core = exports.vorp_core:GetCore()

local patches  = {}    -- [i] = { name, centre, eggs }
local spawned  = {}    -- "patch:egg" -> object
local blips    = {}
local rabbits  = {}
local busy     = false
local handProp = nil
local prompt, promptGroup

local function key(p, e) return tostring(p) .. ':' .. tostring(e) end

local function notify(msg, ms) Core.NotifyRightTip(msg, ms or 4000) end

-- the egg models are custom and not shipped; warn once if no stream resource provides them
local modelsChecked = false
local function checkModels()
    if modelsChecked then return end
    modelsChecked = true
    local ok = 0
    for _, m in ipairs(Config.Easter.eggModels) do
        if IsModelValid(joaat(m)) then ok = ok + 1 end
    end
    if ok == 0 then
        print('^1[spring hunt]^7 NONE of Config.Easter.eggModels are valid on this client. ' ..
              'The egg models are not streamed by any resource, so no eggs will appear. ' ..
              'Add them to a stream resource, or point Config.Easter.eggModels at props that exist.')
    elseif ok < #Config.Easter.eggModels then
        print(('^3[spring hunt]^7 only %d of %d egg models are valid; the rest are skipped.')
            :format(ok, #Config.Easter.eggModels))
    end
end

-- ===========================================================================
-- GROUND
-- ===========================================================================
local function groundAt(x, y)
    local height = 1200.0
    for _ = 1, 10 do
        local found, z = GetGroundZAndNormalFor_3dCoord(x, y, height)
        if found then return z end
        height = height - 120.0
        if height < -150.0 then break end
        Wait(0)
    end
    return nil
end

-- GET_WATER_HEIGHT: an egg floating on a lake gives the whole thing away
local function inWater(x, y, z)
    local ok, h = Citizen.InvokeNative(0xFCA8B23F28813F69, x + 0.0, y + 0.0, z + 0.0,
        Citizen.ResultAsFloat())
    if ok == nil then return false end
    local wh = tonumber(h) or tonumber(ok)
    return wh ~= nil and wh > z
end

-- ===========================================================================
-- EGGS
-- ===========================================================================
local function dropEgg(p, e)
    local k <const> = key(p, e.id)
    if spawned[k] then return end

    local z = groundAt(e.x, e.y)
    if not z then return end
    if inWater(e.x, e.y, z) then return end

    local hash <const> = EVC.loadModel(e.model, 6000)
    if not hash then return end

    local obj = CreateObject(hash, e.x, e.y, z + 0.35, false, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return end

    SetEntityHeading(obj, e.heading or 0.0)
    Citizen.InvokeNative(0x58A850EAEE20FAA3, obj, false) -- PlaceObjectOnGroundProperly
    FreezeEntityPosition(obj, true)
    SetEntityCanBeDamaged(obj, false)
    spawned[k] = obj
end

local function clearEgg(p, eid)
    local k <const> = key(p, eid)
    local o = spawned[k]
    if o then
        if DoesEntityExist(o) then
            SetEntityAsMissionEntity(o, true, true)
            DeleteEntity(o)
        end
        spawned[k] = nil
    end
end

local function clearAllEggs()
    for k, o in pairs(spawned) do
        if DoesEntityExist(o) then
            SetEntityAsMissionEntity(o, true, true)
            DeleteEntity(o)
        end
        spawned[k] = nil
    end
end

-- ===========================================================================
-- RABBITS
-- ===========================================================================
local function clearRabbits(p)
    for _, ped in ipairs(rabbits[p] or {}) do
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
    rabbits[p] = nil
end

local function spawnRabbits(p, centre)
    if not (Config.Easter.rabbits and Config.Easter.rabbits.enabled) or rabbits[p] then return end
    rabbits[p] = {}
    local hash <const> = EVC.loadModel(Config.Easter.rabbits.model, 6000)
    if not hash then return end
    for _ = 1, math.random(Config.Easter.rabbits.count[1], Config.Easter.rabbits.count[2]) do
        local a, d = math.random() * math.pi * 2.0, math.sqrt(math.random()) * Config.Easter.rabbits.spawnRadius
        local x, y = centre.x + math.cos(a) * d, centre.y + math.sin(a) * d
        local z = groundAt(x, y)
        if z and not inWater(x, y, z) then
            local ped = CreatePed(hash, x, y, z, math.random(0, 359) + 0.0, false, false, false, false)
            if ped and ped ~= 0 then
                SetEntityAsMissionEntity(ped, true, true)
                EVC.dress(ped)
                if Config.Easter.rabbits.scale and Config.Easter.rabbits.scale ~= 1.0 then
                    SetPedScale(ped, Config.Easter.rabbits.scale + 0.0)
                end
                TaskWanderStandard(ped, 10.0, 10)
                rabbits[p][#rabbits[p] + 1] = ped
            end
        end
        Wait(0)
    end
    SetModelAsNoLongerNeeded(hash)
end

-- ===========================================================================
-- BLIPS
-- ===========================================================================
local function clearBlips()
    for _, b in ipairs(blips) do RemoveBlip(b) end
    blips = {}
end

local function drawBlips()
    clearBlips()
    if not (Config.Easter.blips and Config.Easter.blips.enabled) then return end
    for _, p in ipairs(patches) do
        local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, p.centre.x, p.centre.y, p.centre.z or 0.0)
        SetBlipSprite(b, joaat(Config.Easter.blips.sprite), true)
        Citizen.InvokeNative(0x9CB1A1623062F402, b, Config.Easter.blips.label or 'Egg Hunt')
        blips[#blips + 1] = b
    end
end

-- ===========================================================================
-- SERVER SYNC
-- ===========================================================================
RegisterNetEvent('pup-events:easter:patches', function(list, gen)
    if list and #list > 0 then checkModels() end
    clearAllEggs()
    for p in pairs(rabbits) do clearRabbits(p) end
    patches = list or {}
    drawBlips()
end)

RegisterNetEvent('pup-events:easter:removeEgg', function(p, eid)
    clearEgg(p, eid)
    local patch = patches[p]
    if patch and patch.eggs then patch.eggs[eid] = nil end
end)

RegisterNetEvent('pup-events:easter:failed', function(msg)
    busy = false
    if msg then notify(msg) end
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    Wait(3000)
    TriggerServerEvent('pup-events:easter:sync')
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    Wait(3000)
    TriggerServerEvent('pup-events:easter:sync')
end)

-- stream patches in and out
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 2000
        if EVC.isLive('easter') and #patches > 0 then
            local me <const> = GetEntityCoords(PlayerPedId())
            local range <const> = Config.Easter.patches.detectRadius or 180.0
            for i, p in ipairs(patches) do
                local d <const> = #(vector2(me.x, me.y) - vector2(p.centre.x, p.centre.y))
                if d <= range then
                    for _, e in pairs(p.eggs or {}) do
                        dropEgg(i, e)
                        Wait(0)
                    end
                    spawnRabbits(i, p.centre)
                elseif d > range * 1.3 then
                    for eid in pairs(p.eggs or {}) do clearEgg(i, eid) end
                    if rabbits[i] then clearRabbits(i) end
                end
            end
        elseif next(spawned) then
            clearAllEggs()
            for p in pairs(rabbits) do clearRabbits(p) end
            clearBlips()
        end
        Wait(wait)
    end
end)

-- ===========================================================================
-- PICKUP
-- ===========================================================================
local function ensurePrompt()
    if prompt then return end
    promptGroup = GetRandomIntInRange(0, 0x7FFFFFFF)
    prompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(prompt, Config.Keys.easterPickup)
    UiPromptSetText(prompt, VarString(10, 'LITERAL_STRING', Locale.easter.promptLabel))
    UiPromptSetEnabled(prompt, true)
    UiPromptSetVisible(prompt, true)
    UiPromptSetHoldMode(prompt, Config.Easter.pickup.promptHoldMs or 800)
    UiPromptSetGroup(prompt, promptGroup, 0)
    UiPromptRegisterEnd(prompt)
end

local function dropHandProp()
    if handProp and DoesEntityExist(handProp) then
        SetEntityAsMissionEntity(handProp, true, true)
        DeleteEntity(handProp)
    end
    handProp = nil
end

local function pickupSequence(p, e)
    local A <const> = Config.Easter.pickup.anim
    RequestAnimDict(A.dict)
    local waited = 0
    while not HasAnimDictLoaded(A.dict) and waited < 5000 do Wait(100) waited = waited + 100 end
    if not HasAnimDictLoaded(A.dict) then
        notify(Locale.easter.animFailed)
        return false
    end

    local me <const> = PlayerPedId()
    TaskPlayAnim(me, A.dict, A.name, 1.0, 1.0, -1, A.flag or 0, 0.0, false, false, false)
    Wait(A.handoffMs or 3500)

    clearEgg(p, e.id)

    local hash = EVC.loadModel(e.model, 4000)
    if hash then
        handProp = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if handProp and handProp ~= 0 then
            local bone <const> = GetPedBoneIndex(me, joaat(A.handBone))
            AttachEntityToEntity(handProp, me, bone,
                A.attachOffset.x, A.attachOffset.y, A.attachOffset.z,
                A.attachRotation.x, A.attachRotation.y, A.attachRotation.z,
                false, false, false, false, 2, true, false, false)
        end
    end

    Wait(A.propRemoveMs or 2300)
    dropHandProp()
    ClearPedTasks(me)
    return true
end

RegisterNetEvent('pup-events:easter:approved', function(p, eid)
    local patch = patches[p]
    local e = patch and patch.eggs and patch.eggs[eid]
    if not e then busy = false return end

    if pickupSequence(p, e) then
        TriggerServerEvent('pup-events:easter:finish', p, eid)
    else
        TriggerServerEvent('pup-events:easter:cancel', p, eid)
    end
    busy = false
end)

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 500
        if EVC.isLive('easter') and not busy and #patches > 0 then
            local me <const> = GetEntityCoords(PlayerPedId())
            local best, bestP, bestD

            for i, p in ipairs(patches) do
                if #(vector2(me.x, me.y) - vector2(p.centre.x, p.centre.y)) <= (Config.Easter.patches.detectRadius or 180.0) then
                    for _, e in pairs(p.eggs or {}) do
                        if spawned[key(i, e.id)] then
                            local d = #(vector2(me.x, me.y) - vector2(e.x, e.y))
                            if d <= (Config.Easter.pickup.distance or 1.6) and (not bestD or d < bestD) then
                                best, bestP, bestD = e, i, d
                            end
                        end
                    end
                end
            end

            if best then
                wait = 0
                ensurePrompt()
                UiPromptSetActiveGroupThisFrame(promptGroup,
                    VarString(10, 'LITERAL_STRING', Locale.easter.promptGroup), 0, 0, 0, 0)
                if UiPromptHasHoldModeCompleted(prompt) then
                    busy = true
                    TriggerServerEvent('pup-events:easter:begin', bestP, best.id,
                        { x = me.x, y = me.y, z = me.z })
                end
            end
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearAllEggs()
    for p in pairs(rabbits) do clearRabbits(p) end
    clearBlips()
    dropHandProp()
end)
