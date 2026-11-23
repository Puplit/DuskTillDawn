-- pup-stable | stables in the world: blips, the stablehand, prompts, opening the menu, previews, camera

Stable = {
    id = nil, zone = nil, hand = nil, handStable = nil, handOwned = false,
    preview = nil, previewKind = nil, previewKey = nil, seq = 0,
    cam = nil, camAngle = 0.0, camTarget = nil, instanced = false, statsCache = {},
}

local blips = {}
local K = Config.Keys

------------------------------------------------------------------------------
-- blips
------------------------------------------------------------------------------
CreateThread(function()
    for id, s in pairs(Config.Stables) do
        if s.blip then
            local b = N.blipCoords(1664425300, s.location.x, s.location.y, s.location.z)
            if b and b ~= 0 then
                N.blipSprite(b, s.blip)
                N.blipName(b, L('blipStable'))
                blips[id] = b
            end
        end
    end
end)

------------------------------------------------------------------------------
-- the stablehand
------------------------------------------------------------------------------
local function dropHand()
    if Stable.hand and Stable.handOwned and DoesEntityExist(Stable.hand) then DeleteEntity(Stable.hand) end
    Stable.hand, Stable.handStable, Stable.handOwned = nil, nil, false
end

local function ensureHand(id, s)
    if Stable.hand and Stable.handStable == id and DoesEntityExist(Stable.hand) then return end
    dropHand()
    local model = joaat(s.stablehand)
    local loc = vector3(s.location.x, s.location.y, s.location.z)
    for _, ped in ipairs(GetGamePool('CPed')) do
        if GetEntityModel(ped) == model and not IsPedAPlayer(ped) and #(GetEntityCoords(ped) - loc) <= 5.0 then
            Stable.hand, Stable.handStable, Stable.handOwned = ped, id, false
            return
        end
    end
    local hash = LoadModel(model)
    if not hash then return end
    local ped = CreatePed(hash, s.location.x, s.location.y, s.location.z - 1.0, s.location.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetPedCanBeTargetted(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    Stable.hand, Stable.handStable, Stable.handOwned = ped, id, true
    SetTimeout(1000, function() if DoesEntityExist(ped) then FreezeEntityPosition(ped, true) end end)
end

------------------------------------------------------------------------------
-- prompts at the stable
------------------------------------------------------------------------------
local group = N.newGroup()
local pStableHorse = N.prompt(K.stableIt, L('stableHorse'), 1000, group)
local pStopLead = N.prompt(K.stopLead, L('stopLeading'), nil, group)
local pStableWagon = N.prompt(K.stableIt, L('stableWagon'), 1000, group)
local pEnter = N.prompt(K.enter, L('enter'), nil, group)
SkipPrompt = N.prompt(K.skip, L('skip'), 1000, nil)

local function hideWorldPrompts()
    for _, p in ipairs({ pStableHorse, pStopLead, pStableWagon, pEnter }) do N.promptShow(p, false) end
end

-- the stable the player stands in
local function zoneOf(pos)
    for id, s in pairs(Config.Stables) do
        if U.inPoly(s.polygon, pos.x, pos.y) and math.abs(pos.z - s.location.z) <= 3.0 then return id, s end
    end
    return nil
end

CreateThread(function()
    while true do
        local wait = 1000
        local me = PlayerPedId()
        local pos = GetEntityCoords(me)
        local nearId, nearS, nearD = nil, nil, math.huge
        for id, s in pairs(Config.Stables) do
            local d = #(pos - vector3(s.location.x, s.location.y, s.location.z))
            if d < nearD then nearId, nearS, nearD = id, s, d end
        end
        if nearS and nearD <= Config.General.stablehandSpawn then
            ensureHand(nearId, nearS)
            wait = 500
        elseif Stable.hand then
            dropHand()
        end

        local zid, zs = zoneOf(pos)
        if zid ~= Stable.zone then
            local old = Stable.zone
            Stable.zone = zid
            if old then TriggerEvent('pup-stable:zoneLeft', old) end
            if zid then TriggerEvent('pup-stable:zoneEntered', zid) end
        end

        if zid and not Ui.open and not Stable.busy and not IsEntityDead(me) then
            wait = 0
            local mount = GetMount(me)
            local leading = N.leading(me)
            local veh = GetVehiclePedIsIn(me, false)
            local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == me
            local nearHand = Stable.hand and DoesEntityExist(Stable.hand) and #(GetEntityCoords(Stable.hand) - pos) <= Config.General.promptDistance
            N.promptShow(pStableHorse, (leading and zs.horseMenu) or (mount ~= 0 and zs.horseMenu))
            N.promptShow(pStopLead, leading)
            N.promptShow(pStableWagon, driving and zs.wagonMenu)
            N.promptShow(pEnter, nearHand and mount == 0 and not leading and veh == 0)
            N.groupActive(group, L('stable'))
            if N.promptDone(pEnter) then
                CreateThread(function() Stable.open(zid) end)
            elseif N.promptDone(pStableHorse) then
                local horse = mount ~= 0 and mount or N.ledHorse(me)
                CreateThread(function() Stable.stableHorse(zid, horse, mount ~= 0) end)
            elseif N.promptDone(pStableWagon) then
                CreateThread(function() Wagon.stableIt(zid, veh) end)
            elseif N.promptDone(pStopLead) then
                ClearPedTasks(me)
                local led = N.ledHorse(me)
                if led ~= 0 then ClearPedTasks(led) end
            end
        else
            hideWorldPrompts()
        end
        Wait(wait)
    end
end)

------------------------------------------------------------------------------
-- stabling the horse you ride or lead
------------------------------------------------------------------------------
function Stable.stableHorse(stableId, horse, mounted)
    if not horse or horse == 0 or not DoesEntityExist(horse) then return end
    if Stable.busy then return end
    Stable.busy = true
    local me = PlayerPedId()
    local s = Config.Stables[stableId]
    local id = U.int(Entity(horse).state.pup_stable_horseID)
    local net = NetIdOf(horse)
    if not net then Stable.busy = false return end
    if mounted then
        -- get off on the side away from the stablehand
        -- RedM has no GetEntityRightVector: turn the forward vector a quarter to the right
        local fwd = GetEntityForwardVector(horse)
        local right = vector3(fwd.y, -fwd.x, 0.0)
        local toHand = Stable.hand and (GetEntityCoords(Stable.hand) - GetEntityCoords(horse)) or right
        local side = (right.x * toHand.x + right.y * toHand.y) > 0 and 1 or 0
        TaskDismountAnimal(me, side, 0, 0, 0, 0)
        local deadline = GetGameTimer() + 4000
        while IsPedOnMount(me) and GetGameTimer() < deadline do Wait(100) end
    end
    if id and Horse.peds[id] then Cores.save(id, horse, true) end
    local ok, why = Call('stableHorse', net, stableId)
    if not ok then
        Stable.busy = false
        if why == 'wild' then return Wild.handIn(stableId, horse) end
        return Tip(why or L('cantStable'))
    end
    if Config.Horse.stablingCutscene and s then
        Stable.saddleScene(s, horse)
    end
    if id then
        local rec = Horse.peds[id]
        if rec then Look.stripTack(rec.ped, rec.row and rec.row.comps) end
        Horse.forget(id, true)
        if Me.horses[id] then Me.horses[id].isOut, Me.horses[id].stable = false, stableId end
    end
    Stable.busy = false
end

-- the player lifts the saddle off and carries it to the saddle store; skippable
function Stable.saddleScene(s, horse)
    local me = PlayerPedId()
    local skip = SkipPrompt
    N.promptShow(skip, true)
    local done = false
    CreateThread(function()
        while not done do
            Wait(0)
            if N.promptDone(skip) then done = true end
        end
    end)
    TaskTurnPedToFaceEntity(me, horse, 1000)
    Wait(1000)
    if not done and LoadDict('mech_inventory@saddle@putaway') then
        TaskPlayAnim(me, 'mech_inventory@saddle@putaway', 'putaway', 4.0, -4.0, 2500, 0, 0.0, false, false, false)
        local t0 = GetGameTimer()
        while not done and GetGameTimer() - t0 < 2500 do Wait(50) end
    end
    if not done and s.saddleStore then
        TaskGoStraightToCoord(me, s.saddleStore.x, s.saddleStore.y, s.saddleStore.z, 1.0, 6000, s.saddleStore.w or 0.0, 0.5)
        local t0 = GetGameTimer()
        while not done and GetGameTimer() - t0 < 6000 and #(GetEntityCoords(me) - vector3(s.saddleStore.x, s.saddleStore.y, s.saddleStore.z)) > 1.2 do Wait(100) end
    end
    done = true
    ClearPedTasks(me)
    N.promptShow(skip, false)
end

------------------------------------------------------------------------------
-- previews
------------------------------------------------------------------------------
function Stable.clearPreview()
    Stable.seq = Stable.seq + 1
    if Stable.preview and DoesEntityExist(Stable.preview) then DeleteEntity(Stable.preview) end
    Stable.preview, Stable.previewKind, Stable.previewKey = nil, nil, nil
end

local function previewSpot(kind)
    local s = Config.Stables[Stable.id]
    if not s then return nil end
    if kind == 'wagon' then return s.wagonPreview end
    if kind == 'own' then return s.ownPreview or s.horsePreview end
    return s.horsePreview
end

-- key = anything identifying what is shown; the same key keeps the current preview
function Stable.showHorse(key, model, kind, after)
    if Stable.previewKey == key and Stable.preview and DoesEntityExist(Stable.preview) then
        if after then after(Stable.preview, false) end
        return Stable.preview
    end
    Stable.clearPreview()
    local mySeq = Stable.seq
    local spot = previewSpot(kind or 'shop')
    if not spot then return nil end
    local hash = LoadModel(model)
    if not hash or mySeq ~= Stable.seq or not Ui.open then return nil end
    local ped = CreatePed(hash, spot.x, spot.y, spot.z, spot.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if mySeq ~= Stable.seq or not Ui.open then if ped ~= 0 then DeleteEntity(ped) end return nil end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    PlaceEntityOnGroundProperly(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    N.cleanDirt(ped)
    Stable.preview, Stable.previewKind, Stable.previewKey = ped, 'horse', key
    Stable.aimCamera(ped)
    if after then after(ped, true) end
    return ped
end

function Stable.showWagon(key, model, after)
    if Stable.previewKey == key and Stable.preview and DoesEntityExist(Stable.preview) then
        if after then after(Stable.preview, false) end
        return Stable.preview
    end
    Stable.clearPreview()
    local mySeq = Stable.seq
    local spot = previewSpot('wagon')
    if not spot then return nil end
    local hash = LoadModel(model)
    if not hash or mySeq ~= Stable.seq or not Ui.open then return nil end
    local veh = CreateVehicle(hash, spot.x, spot.y, spot.z, spot.w, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if mySeq ~= Stable.seq or not Ui.open then if veh ~= 0 then DeleteEntity(veh) end return nil end
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    Stable.preview, Stable.previewKind, Stable.previewKey = veh, 'wagon', key
    Stable.aimCamera(veh, 7.5)
    if after then after(veh, true) end
    return veh
end

------------------------------------------------------------------------------
-- camera and light
------------------------------------------------------------------------------
local camDist = 4.2

function Stable.aimCamera(ent, dist)
    camDist = dist or 4.2
    Stable.camTarget = ent
    Stable.camAngle = 0.0
    Stable.placeCamera()
end

function Stable.placeCamera()
    local ent = Stable.camTarget
    if not ent or not DoesEntityExist(ent) then return end
    local c = GetEntityCoords(ent)
    local h = math.rad(GetEntityHeading(ent) + 90.0 + Stable.camAngle)
    local pos = vector3(c.x + math.cos(h) * camDist, c.y + math.sin(h) * camDist, c.z + 0.9)
    if not Stable.cam then
        Stable.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 50.0, false, 0)
        SetCamActive(Stable.cam, true)
        RenderScriptCams(true, true, 600, true, true, 0)
    else
        SetCamCoord(Stable.cam, pos.x, pos.y, pos.z)
    end
    PointCamAtCoord(Stable.cam, c.x, c.y, c.z + 0.4)
end

function Stable.rotate(dir)
    Stable.camAngle = U.clamp(Stable.camAngle + dir * 10.0, -45.0, 45.0)
    Stable.placeCamera()
end

function Stable.dropCamera()
    if Stable.cam then
        RenderScriptCams(false, true, 500, true, true, 0)
        DestroyCam(Stable.cam, false)
        Stable.cam = nil
    end
    Stable.camTarget = nil
end

CreateThread(function()
    local fade = 0.0
    while true do
        if Stable.cam and Ui.open then
            fade = math.min(1.0, fade + 0.05)
            local p = GetCamCoord(Stable.cam)
            N.light(p.x, p.y, p.z, 12.0, Config.General.previewLight * fade)
            Wait(0)
        else
            fade = 0.0
            Wait(500)
        end
    end
end)

------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------
function Stable.open(stableId)
    local s = Config.Stables[stableId]
    if not s or Ui.open or Stable.busy then return end
    Stable.busy = true
    Stable.id = stableId
    RefreshHorses()
    RefreshWagons()
    local okP, can = Call('colorPermission')
    if okP then Me.canColor = can == true end
    if s.needsInstance then
        local me = PlayerPedId()
        local mount = GetMount(me)
        local veh = GetVehiclePedIsIn(me, false)
        Stable.instanced = Call('instance', true, stableId, mount ~= 0 and NetIdOf(mount) or nil, veh ~= 0 and NetIdOf(veh) or nil) == true
    end
    if Stable.hand and DoesEntityExist(Stable.hand) then
        TaskTurnPedToFaceEntity(Stable.hand, PlayerPedId(), 1500)
        TaskStartScenarioInPlace(Stable.hand, joaat('WORLD_HUMAN_CLIPBOARD'), -1, true, false, false, false)
    end
    Stable.busy = false
    Menus.openHome(stableId)
end

function Stable.onClosed()
    Stable.clearPreview()
    Stable.dropCamera()
    if Stable.instanced then
        Stable.instanced = false
        CreateThread(function() Call('instance', false) end)
    end
    local hand = Stable.hand
    SetTimeout(3400, function() if hand and DoesEntityExist(hand) then ClearPedTasks(hand) end end)
    Stable.id = nil
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    Stable.clearPreview()
    Stable.dropCamera()
    dropHand()
    for _, b in pairs(blips) do N.blipRemove(b) end
end)
