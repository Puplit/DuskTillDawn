-- bathing | client: blips, doors, prompts, the cutscenes, the scrub minigame,
-- the deluxe attendant and the ways out. Everything here is local to this
-- player; the server owns money and occupancy.
-- Reads BathhouseConfig / BathhouseLocale (shared) and BathhouseMoveNet (movenet.lua).

local CFG <const> = BathhouseConfig
local L <const> = BathhouseLocale
local T <const> = CFG.Timings
local A <const> = CFG.Assets
local MoveNet <const> = BathhouseMoveNet

local EV_REQUEST <const> = 'pup-misc:bath:request'
local EV_BEGIN <const> = 'pup-misc:bath:begin'
local EV_REFUSED <const> = 'pup-misc:bath:refused'
local EV_DELUXE <const> = 'pup-misc:bath:deluxe'
local EV_DELUXE_OK <const> = 'pup-misc:bath:deluxeOk'
local EV_DELUXE_NO <const> = 'pup-misc:bath:deluxeNo'
local EV_FINISHED <const> = 'pup-misc:bath:finished'
local EV_RELEASED <const> = 'pup-misc:bath:released'
local EV_STARTED <const> = 'pup-misc:bath:started'
local EV_REFUND <const> = 'pup-misc:bath:refund'

-- ------------------------------------------------------------------ natives

local N_CLEAR_ENV_DIRT <const> = 0x6585D955A68452A5
local N_CLEAR_BLOOD <const> = 0x8FE22675A5A45817
local N_CLEAR_DECALS_ZONE <const> = 0x523C79AEEFCC4A2A
local N_DIRT_CLEANED <const> = 0xE3144B932DFDFF65
local N_CLEAN_FLAG <const> = 0x7F5D88333EE8A86F
local N_CLEAR_WETNESS <const> = 0x9C720776DAA43E7E
local N_LETTERBOX <const> = 0x69D65E89FFD72313
local N_REFRESH_PED <const> = 0x704C908E9C405136
local N_RANDOM_OUTFIT <const> = 0x283978A15512B2FE
local N_AFTER_NETWORK <const> = 0x55546004A244302A
local N_ADD_DOOR <const> = 0xD99229FE93B46286
local N_DOOR_ENTITY <const> = 0xF7424890E4A094C0
local N_BLIP_FOR_COORDS <const> = 0x554D9D53F696D002
local N_BLIP_NAME <const> = 0x9CB1A1623062F402
local N_SCENE_LOADED <const> = 0x477122B8D05E7968
local N_SCENE_PROGRESS <const> = 0x3FBC3F51BF12DFBF
local N_SCENE_FINISHED <const> = 0xD8254CB2C586412B
local N_SCENE_EXISTS <const> = 0x25557E324489393C
local N_SCENE_DELETE <const> = 0x84EEDB2C6E650000
local N_NET_DEF_REQUEST <const> = 0x2B6529C54D29037A
local N_NET_DEF_RELEASE <const> = 0x57A197AD83F66BBF
local N_MUSIC_EVENT <const> = 0x706D57B0F50DA710
local N_LEG_IK <const> = 0xC396F5B86FF9FEBD
local N_NET_READY <const> = 0x30ED88D5E0C56A37
local N_NET_TRANSITION <const> = 0xD01015C7316AE176
local N_NET_STATE <const> = 0x717E4D1F2048376D
local N_NET_SIGNAL_FLOAT <const> = 0xD5BB4025AE449A4E
local N_SOUND_FRONTEND <const> = 0x67C540AA08E4A6F5

local CLEANLINESS <const> = {
    'Cleanliness_Right_Arm', 'Cleanliness_Left_Arm', 'Cleanliness_Left_Leg',
    'Cleanliness_Right_Leg', 'Cleanliness_Head',
}

local function truthy(v)
    return v == true or v == 1
end

-- natives that may answer 0/1: read them as booleans (a bare 0 is true in Lua)
local function asBool(fn)
    return function(...) return truthy(fn(...)) end
end
local IsEntityDead <const> = asBool(IsEntityDead)
local IsPedMale <const> = asBool(IsPedMale)
local IsModelValid <const> = asBool(IsModelValid)
local HasModelLoaded <const> = asBool(HasModelLoaded)
local DoesEntityExist <const> = asBool(DoesEntityExist)
local DoesCamExist <const> = asBool(DoesCamExist)
local IsControlPressed <const> = asBool(IsControlPressed)
local IsControlJustReleased <const> = asBool(IsControlJustReleased)

-- calls the named native when the runtime has it, else the hash
local function callNative(name, hash, ...)
    local fn = _G[name]
    if type(fn) == 'function' then return fn(...) end
    return Citizen.InvokeNative(hash, ...)
end

local function controlHash(c)
    if type(c) == 'string' then return GetHashKey(c) end
    return c
end

local function setLegIk(ped, mode)
    pcall(callNative, 'SetPedLegIkMode', N_LEG_IK, ped, mode)
end

local function music(name)
    pcall(callNative, 'TriggerMusicEvent', N_MUSIC_EVENT, name)
end

local function letterbox(on)
    Citizen.InvokeNative(N_LETTERBOX, on, on)
end

local function refreshPed()
    Citizen.InvokeNative(N_REFRESH_PED, PlayerPedId())
end

-- move network
local function netReady(ent)
    return truthy(callNative('IsTaskMoveNetworkReadyForTransition', N_NET_READY, ent))
end

local function netState(ent)
    if type(GetTaskMoveNetworkState) == 'function' then return GetTaskMoveNetworkState(ent) end
    return Citizen.InvokeNative(N_NET_STATE, ent, Citizen.ResultAsString())
end

local function netTransition(ent, state)
    callNative('RequestTaskMoveNetworkStateTransition', N_NET_TRANSITION, ent, state)
end

local function netSignal(ent, name, value)
    callNative('SetTaskMoveNetworkSignalFloat', N_NET_SIGNAL_FLOAT, ent, name, value + 0.0)
end

-- anim scenes
local function sceneExists(scene)
    return scene and scene ~= 0 and truthy(Citizen.InvokeNative(N_SCENE_EXISTS, scene))
end

local function sceneProgress(scene)
    return Citizen.InvokeNative(N_SCENE_PROGRESS, scene, Citizen.ResultAsFloat()) or 0.0
end

local function sceneFinished(scene)
    return truthy(Citizen.InvokeNative(N_SCENE_FINISHED, scene, true))
end

local function doorEntity(doorHash)
    local ent = Citizen.InvokeNative(N_DOOR_ENTITY, doorHash, 0)
    if ent and ent ~= 0 then return ent end
    return nil
end

local function deleteEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
end

local function loadModel(model, timeoutMs)
    local hash = GetHashKey(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local until_ = GetGameTimer() + timeoutMs
    while not HasModelLoaded(hash) do
        if GetGameTimer() > until_ then return nil end
        Wait(10)
    end
    return hash
end

-- ------------------------------------------------------------------ cleaning

local function cleanZone(ped, zone)
    Citizen.InvokeNative(N_CLEAR_DECALS_ZONE, ped, zone, 'ALL')
end

local function cleanAll(ped)
    Citizen.InvokeNative(N_CLEAR_ENV_DIRT, ped)
    Citizen.InvokeNative(N_CLEAR_BLOOD, ped)
    Citizen.InvokeNative(N_DIRT_CLEANED, ped, 0.0, -1, 1, 1)
    cleanZone(ped, CFG.AllZones)
    Citizen.InvokeNative(N_CLEAN_FLAG, ped, 1)
    Citizen.InvokeNative(N_CLEAR_WETNESS, ped)
end

-- ------------------------------------------------------------------ prompts

local prompts = {} -- [id] = { handle, shown, control }

local function priceText(v)
    v = tonumber(v) or 0
    if v == math.floor(v) then return ('%d'):format(v) end
    return tostring(v)
end

local function registerPrompts()
    local def = CFG.PromptDefaults
    for _, p in ipairs(CFG.Prompts) do
        local control = controlHash(p.control or def.control)
        local text = L.prompts[p.id] or p.id
        if p.price then text = text:format(priceText(CFG.Prices[p.price])) end
        local h = PromptRegisterBegin()
        PromptSetControlAction(h, control)
        PromptSetText(h, CreateVarString(10, 'LITERAL_STRING', text))
        PromptSetEnabled(h, false)
        PromptSetVisible(h, false)
        PromptSetHoldMode(h, p.hold or def.hold)
        PromptRegisterEnd(h)
        prompts[p.id] = { handle = h, shown = false, control = control }
    end
end

local function setPrompt(id, on)
    local p = prompts[id]
    if not p or p.shown == on then return end
    PromptSetEnabled(p.handle, on)
    PromptSetVisible(p.handle, on)
    p.shown = on
end

local function promptShown(id)
    local p = prompts[id]
    return p ~= nil and p.shown
end

local function promptDone(id)
    local p = prompts[id]
    return p ~= nil and p.shown and truthy(PromptHasHoldModeCompleted(p.handle))
end

local function hideAll()
    for id in pairs(prompts) do setPrompt(id, false) end
end

-- ------------------------------------------------------------------ session

-- the bath in progress, or nil. One table per bath: threads hold their own
-- reference and stop as soon as it is no longer the current one.
local bath = nil
local pendingSince = nil -- GetGameTimer() of an unanswered start request

local function alive(sess)
    return bath == sess and not sess.over
end

local function waitFor(sess, cond, timeoutMs, stepMs)
    local limit = GetGameTimer() + timeoutMs
    while not cond() do
        if not alive(sess) or GetGameTimer() > limit then return false end
        if IsEntityDead(PlayerPedId()) then return false end -- dying in a cutscene ends the wait
        Wait(stepMs or 10)
    end
    return alive(sess)
end

local function requestAssets()
    for _, d in ipairs(A.dicts) do RequestAnimDict(d) end
    for _, c in pairs(A.clipsets) do RequestClipSet(c) end
    for _, n in pairs(A.networks) do Citizen.InvokeNative(N_NET_DEF_REQUEST, n) end
end

local function assetsLoaded()
    for _, d in ipairs(A.dicts) do
        if not truthy(HasAnimDictLoaded(d)) then return false end
    end
    for _, c in pairs(A.clipsets) do
        if not truthy(HasClipSetLoaded(c)) then return false end
    end
    return true
end

local function releaseAssets()
    for _, d in ipairs(A.dicts) do RemoveAnimDict(d) end
    for _, c in pairs(A.clipsets) do RemoveClipSet(c) end
    for _, n in pairs(A.networks) do Citizen.InvokeNative(N_NET_DEF_RELEASE, n) end
end

local function deleteScene(sess, scene)
    if not scene then return end
    if sceneExists(scene) then Citizen.InvokeNative(N_SCENE_DELETE, scene) end
    sess.scenes[scene] = nil
end

-- creates, binds and loads a scene; nil if it does not load in time
local function newScene(sess, list, roles)
    local scene = CreateAnimScene(sess.house.dict, 0, list, false, true)
    if not scene or scene == 0 then return nil end
    sess.scenes[scene] = true
    for role, ent in pairs(roles) do
        if ent and ent ~= 0 then SetAnimSceneEntity(scene, role, ent, 0) end
    end
    LoadAnimScene(scene)
    local loaded = waitFor(sess, function()
        return truthy(Citizen.InvokeNative(N_SCENE_LOADED, scene, 1, 0))
    end, T.sceneLoadTimeoutMs, 10)
    if not loaded then
        deleteScene(sess, scene)
        return nil
    end
    return scene
end

local function playerRoles(sess, extra)
    local roles = {
        [A.roles.player] = PlayerPedId(),
        [A.roles.door] = doorEntity(sess.house.door),
    }
    if extra then roles[A.roles.attendant] = extra end
    return roles
end

local function waitSceneEnd(sess, scene)
    return waitFor(sess, function() return sceneFinished(scene) end, T.sceneMaxMs, 10)
end

-- scripted camera
local function camOn(sess)
    if sess.cam and DoesCamExist(sess.cam) then RenderScriptCams(true, true, T.camEaseMs, true, true, 0) end
end

local function camOff()
    RenderScriptCams(false, false, 0, true, true, 0)
end

local function destroyCam(sess)
    camOff()
    if sess.cam and DoesCamExist(sess.cam) then DestroyCam(sess.cam, false) end
    sess.cam = nil
end

local function dress(sess)
    if sess then sess.dressed = true end
    ExecuteCommand(CFG.Commands.dress)
end

-- the move network partner: the attendant when she is there, else the rag
local function partner(sess)
    if sess.maid and DoesEntityExist(sess.maid) then return sess.maid end
    return sess.rag
end

local function toState(sess, state)
    netTransition(PlayerPedId(), state)
    local other = partner(sess)
    if other and DoesEntityExist(other) then netTransition(other, state) end
end

local function signalBoth(sess, name, value)
    netSignal(PlayerPedId(), name, value)
    local other = partner(sess)
    if other and DoesEntityExist(other) then netSignal(other, name, value) end
end

-- cleanliness goes to the player and the rag, plus the attendant
local function setCleanliness(sess, value)
    local targets = { PlayerPedId(), sess.rag, sess.maid }
    for i = 1, 3 do
        local ent = targets[i]
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            for _, sig in ipairs(CLEANLINESS) do netSignal(ent, sig, value) end
        end
    end
end

local function startRegularNetwork(ped)
    MoveNet.start(ped, A.networks.regular, A.clipsets.regularPlayer, A.clipsetVariable, A.startState)
end

local function restoreTubPrompts(sess)
    setPrompt('exit', true)
    setPrompt('scrub', not sess.allDone)
    setPrompt('deluxe', not sess.scrubStarted and not sess.deluxeBought)
end

-- ------------------------------------------------------------------ ending a bath

-- one way out for every ending. opts: teleport, dress, noDress, stopAnim, clearTasks, dead
local function endBath(sess, opts)
    if bath ~= sess or sess.over then return end
    sess.over = true
    bath = nil
    opts = opts or {}
    if IsEntityDead(PlayerPedId()) then opts.dead = true end

    hideAll()
    destroyCam(sess)
    for scene in pairs(sess.scenes) do deleteScene(sess, scene) end
    deleteEntity(sess.maid)
    deleteEntity(sess.rag)
    MoveNet.forget()

    local ped = PlayerPedId()
    if opts.clearTasks then ClearPedTasksImmediately(ped) end
    if opts.teleport and sess.house.landing then
        local p = sess.house.landing
        SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    end

    if opts.dead then
        -- the reload command refuses a dead ped; dress once they are back up
        CreateThread(function()
            local limit = GetGameTimer() + T.reviveWaitMs
            while IsEntityDead(PlayerPedId()) and GetGameTimer() < limit do Wait(1000) end
            if not IsEntityDead(PlayerPedId()) then
                Wait(T.afterDressMs)
                if not bath then ExecuteCommand(CFG.Commands.dress) end
            end
        end)
    elseif opts.noDress then
        -- a character switch: vorp_character dresses the new character itself
    elseif not sess.dressed or opts.dress then
        dress(sess)
        Wait(T.afterDressMs)
    end
    if opts.stopAnim then ExecuteCommand(CFG.Commands.stopAnim) end

    releaseAssets()
    letterbox(false)
    music(A.music.stop)
    refreshPed()
    setLegIk(PlayerPedId(), 2)
    TriggerServerEvent(EV_FINISHED)
end

-- /exitbath, the exit spots and every failure: straight out at this bathhouse
local function emergencyExit(sess)
    endBath(sess, { teleport = true, dress = true, stopAnim = true, clearTasks = true })
end

-- ------------------------------------------------------------------ deluxe

local function deluxeOutro(sess, exiting)
    sess.busy = true
    setPrompt('exit', false)
    setPrompt('scrub', false)
    local scene = newScene(sess, A.scenes.deluxeOutro, playerRoles(sess, sess.maid))
    if not alive(sess) then return false end
    if scene then
        StartAnimScene(scene)
        camOff()
        waitSceneEnd(sess, scene)
        if not alive(sess) then return false end
        deleteScene(sess, scene)
    end
    deleteEntity(sess.maid)
    MoveNet.forget(sess.maid)
    sess.maid = nil
    startRegularNetwork(PlayerPedId())
    if not exiting then
        restoreTubPrompts(sess)
        camOn(sess)
    end
    sess.busy = false
    return true
end

-- the service never started: the server pays it back and the prompt returns
local function deluxeFailed(sess)
    TriggerServerEvent(EV_REFUND, 'deluxe')
    restoreTubPrompts(sess)
    sess.busy = false
end

local function deluxeIntro(sess)
    sess.busy = true
    hideAll()
    if sess.intro then
        deleteScene(sess, sess.intro)
        sess.intro = nil
    end

    local ped = PlayerPedId()
    local att = CFG.Attendants
    local model = loadModel(IsPedMale(ped) and att.forMale or att.forFemale, T.assetTimeoutMs)
    if not alive(sess) then return end
    if not model then return deluxeFailed(sess) end
    local pos = GetEntityCoords(ped)
    local maid = CreatePed(model, pos.x, pos.y, pos.z + att.heightAbove, 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not maid or maid == 0 then return deluxeFailed(sess) end
    Citizen.InvokeNative(N_RANDOM_OUTFIT, maid, true)
    sess.maid = maid

    local scene = newScene(sess, A.scenes.deluxeIntro, playerRoles(sess, maid))
    if not alive(sess) then return end
    if not scene then
        deleteEntity(maid)
        sess.maid = nil
        return deluxeFailed(sess)
    end

    pcall(callNative, 'PlaySoundFrontend', N_SOUND_FRONTEND, A.knock.name, A.knock.set or 0, true, 0)
    Wait(T.knockLeadMs)
    if not alive(sess) then return end
    sess.deluxeBought = true
    TriggerServerEvent(EV_STARTED, 'deluxe')
    StartAnimScene(scene)
    camOff()
    waitSceneEnd(sess, scene)
    if not alive(sess) then return end
    deleteScene(sess, scene)

    MoveNet.start(PlayerPedId(), A.networks.deluxe, A.clipsets.deluxePlayer, A.clipsetVariable, A.startState)
    MoveNet.start(maid, A.networks.deluxe, A.clipsets.deluxeMaid, A.clipsetVariable, A.startState)
    setPrompt('exit', true)
    setPrompt('scrub', not sess.allDone)
    camOn(sess)
    sess.busy = false
end

local function orderDeluxe(sess)
    hideAll()
    sess.busy = true
    sess.deluxePending = GetGameTimer()
    TriggerServerEvent(EV_DELUXE, sess.key)
    local asked = sess.deluxePending
    SetTimeout(T.replyTimeoutMs, function()
        if alive(sess) and sess.deluxePending == asked then
            sess.deluxePending = nil
            restoreTubPrompts(sess)
            sess.busy = false
        end
    end)
end

RegisterNetEvent(EV_DELUXE_OK, function(key)
    local sess = bath
    if not sess or sess.key ~= key or sess.deluxeBought then return end
    if not sess.deluxePending then
        -- a late answer (after the reply timeout): the server has charged, so
        -- run the service if the tub is idle (not scrubbing, no cutscene), else pay it back
        if sess.busy or sess.scrubbing or sess.ending then
            TriggerServerEvent(EV_REFUND, 'deluxe')
            return
        end
    end
    sess.deluxePending = nil
    deluxeIntro(sess)
end)

RegisterNetEvent(EV_DELUXE_NO, function()
    local sess = bath
    if not sess or not sess.deluxePending then return end
    sess.deluxePending = nil
    restoreTubPrompts(sess)
    sess.busy = false
end)

-- ------------------------------------------------------------------ scrubbing

local function reachScrubIdle(sess)
    local ped = PlayerPedId()
    local limit = GetGameTimer() + T.transitionTimeoutMs
    while alive(sess) and netState(ped) ~= 'Scrub_Idle' and GetGameTimer() < limit do
        toState(sess, 'Scrub_Idle')
        Wait(T.transitionRetryMs)
    end
end

local function allPartsDone(sess)
    hideAll()
    setPrompt('exit', true)
    cleanAll(PlayerPedId())
    sess.allDone = true
end

-- the finished part comes clean; the last one cleans everything
local function nextPart(sess, finished)
    if finished then cleanZone(PlayerPedId(), CFG.BodyParts[sess.part].zone) end
    sess.progress = 0.0
    sess.part = sess.part + 1
    if sess.part > #CFG.BodyParts then
        allPartsDone(sess)
        return true
    end
    return false
end

local function scrubHold(sess, key)
    sess.scrubStarted = true
    setPrompt('deluxe', false)
    reachScrubIdle(sess)

    while alive(sess) and IsControlPressed(0, key) and not sess.allDone do
        if promptDone('scrub') then
            local part = CFG.BodyParts[sess.part]
            if sess.maid and not part.deluxe then
                if nextPart(sess, false) then break end
                part = CFG.BodyParts[sess.part]
            end
            sess.progress = sess.progress + (part.step or CFG.DefaultStep)
            local ped = PlayerPedId()
            if netState(ped) ~= part.state then
                setCleanliness(sess, 0.0)
                toState(sess, part.state)
            end
            signalBoth(sess, 'scrub_freq', part.speed)
            setCleanliness(sess, sess.progress)
            if sess.progress >= 1.0 and nextPart(sess, true) then break end
        end
        Wait(T.scrubTickMs)
    end
    if not alive(sess) then return end

    if sess.allDone and sess.maid then
        Wait(T.deluxeFinishPauseMs)
        if alive(sess) then deluxeOutro(sess, false) end
        setPrompt('scrub', false)
        return
    end

    local ped = PlayerPedId()
    waitFor(sess, function() return netReady(ped) end, T.transitionTimeoutMs, T.readyPollMs)
    local rest = (sess.allDone or sess.maid) and 'Bathing' or 'Scrub_Idle'
    local limit = GetGameTimer() + T.restTimeoutMs
    while alive(sess) and netState(ped) ~= rest and GetGameTimer() < limit do
        setCleanliness(sess, 1.0)
        reachScrubIdle(sess)
        if rest == 'Bathing' then
            if sess.maid and IsControlPressed(0, key) then break end
            toState(sess, 'Bathing')
        end
        Wait(T.restRetryMs)
    end
end

-- ------------------------------------------------------------------ the regular outro

local function regularOutro(sess)
    if sess.maid then
        if not deluxeOutro(sess, true) then return end
    end
    sess.ending = true
    sess.busy = true
    hideAll()
    if sess.intro then
        deleteScene(sess, sess.intro)
        sess.intro = nil
    end

    local scene = newScene(sess, A.scenes.regularOutro, playerRoles(sess))
    if not alive(sess) then return end
    if not scene then return emergencyExit(sess) end
    StartAnimScene(scene)
    destroyCam(sess)

    local dressed = waitFor(sess, function() return sceneProgress(scene) > T.dressAt end, T.sceneMaxMs, 10)
    if not alive(sess) then return end
    if dressed then dress(sess) end
    waitSceneEnd(sess, scene)
    if not alive(sess) then return end
    deleteScene(sess, scene)
    endBath(sess, {})
end

-- ------------------------------------------------------------------ the tub

local function tubLoop(sess)
    local scrubKey = prompts.scrub and prompts.scrub.control
    while alive(sess) and sess.cam and DoesCamExist(sess.cam) do
        Wait(T.tubTickMs)
        if not alive(sess) then return end
        local ped = PlayerPedId()

        if IsEntityDead(ped) then
            return endBath(sess, { dead = true })
        end
        if #(GetEntityCoords(ped) - sess.house.consumer) > CFG.Distances.clientLeave then
            return endBath(sess, { dress = true })
        end

        if not sess.busy then
            if sess.allDone then setPrompt('scrub', false) end
            if promptDone('exit') then
                regularOutro(sess)
                return
            elseif promptDone('deluxe') then
                orderDeluxe(sess)
            elseif promptShown('scrub') and IsControlPressed(0, scrubKey) and netReady(ped) then
                sess.scrubbing = true
                scrubHold(sess, scrubKey)
                sess.scrubbing = false
            end
        end
    end
end

-- ------------------------------------------------------------------ the intro

local function runIntro(sess)
    local ped = PlayerPedId()
    SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true, 0, false, false)

    requestAssets()
    if not waitFor(sess, assetsLoaded, T.assetTimeoutMs, 10) then return false end

    local ragModel = loadModel(CFG.Rag, T.assetTimeoutMs)
    if not ragModel or not alive(sess) then return false end
    local pos = GetEntityCoords(ped)
    sess.rag = CreateObject(ragModel, pos.x, pos.y, pos.z, false, false, false, false, false)
    SetModelAsNoLongerNeeded(ragModel)

    setLegIk(ped, 0)
    ClearPedTasksImmediately(ped)

    local scene = newScene(sess, A.scenes.regularIntro, playerRoles(sess))
    if not scene then return false end
    sess.intro = scene
    music(A.music.start)
    StartAnimScene(scene)

    if not waitFor(sess, function() return sceneProgress(scene) > T.undressAt end, T.sceneMaxMs, 10) then return false end
    TriggerEvent('vorp_character:client:undress')
    if not waitSceneEnd(sess, scene) then return false end

    -- a scripted camera exactly where the view is now
    local at, rot, fov = GetFinalRenderedCamCoord(), GetFinalRenderedCamRot(2), GetFinalRenderedCamFov()
    sess.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', at.x, at.y, at.z, rot.x, rot.y, rot.z, fov, false, 2)
    SetCamActive(sess.cam, true) -- RenderScriptCams shows only an active camera
    letterbox(true)
    camOn(sess)

    restoreTubPrompts(sess)

    ped = PlayerPedId()
    startRegularNetwork(ped)
    if sess.rag and DoesEntityExist(sess.rag) then
        MoveNet.startAt(sess.rag, A.networks.regular, A.clipsets.regularRag, A.clipsetVariable, A.startState,
            sess.house.rag, sess.house.ragHeading)
        if type(ForceEntityAiAndAnimationUpdate) == 'function' then
            pcall(ForceEntityAiAndAnimationUpdate, sess.rag, true)
        end
    end
    Citizen.InvokeNative(N_AFTER_NETWORK, ped)
    return true
end

local function runBath(sess)
    local ok, result = pcall(runIntro, sess)
    if not ok then print(('^1[pup-misc/bathing]^7 intro failed: %s'):format(tostring(result))) end
    if not alive(sess) then return end
    if not ok or not result then
        TriggerServerEvent(EV_REFUND, 'regular') -- sent before emergencyExit frees the bathhouse
        return emergencyExit(sess)
    end
    TriggerServerEvent(EV_STARTED, 'regular')

    local ok2, err = pcall(tubLoop, sess)
    if not ok2 then
        print(('^1[pup-misc/bathing]^7 bath failed: %s'):format(tostring(err)))
        emergencyExit(sess)
    end
end

RegisterNetEvent(EV_BEGIN, function(key)
    pendingSince = nil
    local house = CFG.Houses[key]
    if bath or not house then
        TriggerServerEvent(EV_FINISHED)
        return
    end
    local sess = { key = key, house = house, scenes = {}, part = 1, progress = 0.0 }
    bath = sess
    hideAll()
    CreateThread(function() runBath(sess) end)
end)

RegisterNetEvent(EV_REFUSED, function()
    pendingSince = nil
end)

-- the server freed the bathhouse (the player left it)
RegisterNetEvent(EV_RELEASED, function(key)
    local sess = bath
    if sess and sess.key == key then endBath(sess, { dress = true, clearTasks = true }) end
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    local sess = bath
    if sess then endBath(sess, { clearTasks = true, noDress = true }) end
end)

-- ------------------------------------------------------------------ ordering a bath

local function nearHouse()
    local here = GetEntityCoords(PlayerPedId())
    for key, house in pairs(CFG.Houses) do
        if #(here - house.consumer) <= CFG.Distances.prompt then return key end
    end
    return nil
end

CreateThread(function()
    while not next(prompts) do Wait(100) end
    while true do
        local wait = T.orderLoopMs
        if pendingSince and GetGameTimer() - pendingSince > T.replyTimeoutMs then pendingSince = nil end
        if bath or pendingSince then
            setPrompt('start', false)
        else
            local key = nearHouse()
            if key then
                setPrompt('start', true)
                if promptDone('start') then
                    hideAll()
                    pendingSince = GetGameTimer()
                    TriggerServerEvent(EV_REQUEST, key)
                    Wait(T.afterRequestMs)
                end
            else
                setPrompt('start', false)
                wait = wait + T.farExtraMs
            end
        end
        Wait(wait)
    end
end)

-- ------------------------------------------------------------------ ways out

RegisterCommand(CFG.Commands.exit, function()
    local sess = bath
    if sess then CreateThread(function() emergencyExit(sess) end) end
end, false)

local function drawHint(text)
    SetTextScale(0.3, 0.3)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.15, 0.13)
end

-- exit spots: only while sitting in the tub (not during a cutscene), only at
-- the bathhouse in use
CreateThread(function()
    while true do
        local wait = 1000
        local sess = bath
        local spot = sess and sess.house.exitSpot
        if spot and sess.cam and not sess.busy and not sess.ending then
            wait = 250
            if #(GetEntityCoords(PlayerPedId()) - spot.at) <= spot.radius then
                wait = 0
                drawHint(L.exitHint)
                if IsControlJustReleased(0, CFG.ExitKey) then emergencyExit(sess) end
            end
        end
        Wait(wait)
    end
end)

-- ------------------------------------------------------------------ map and doors

local blips = {}

CreateThread(function()
    registerPrompts()
    for _, house in pairs(CFG.Houses) do
        local c = house.consumer
        local blip = Citizen.InvokeNative(N_BLIP_FOR_COORDS, CFG.Blip.style, c.x, c.y, c.z)
        SetBlipSprite(blip, GetHashKey(CFG.Blip.sprite), true)
        Citizen.InvokeNative(N_BLIP_NAME, blip, L.blipName)
        blips[#blips + 1] = blip

        if not truthy(IsDoorRegisteredWithSystem(house.door)) then
            Citizen.InvokeNative(N_ADD_DOOR, house.door, 1, 1, 0, 0, 0, 0)
            DoorSystemSetDoorState(house.door, 1)
        end
        Wait(CFG.Blip.spacingMs)
    end
end)

-- ------------------------------------------------------------------ resource stop

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    local sess = bath
    if sess then
        bath = nil
        sess.over = true
        for scene in pairs(sess.scenes) do
            if sceneExists(scene) then Citizen.InvokeNative(N_SCENE_DELETE, scene) end
        end
        deleteEntity(sess.rag)
        deleteEntity(sess.maid)
        if sess.cam and DoesCamExist(sess.cam) then
            camOff()
            DestroyCam(sess.cam, false)
        end
        letterbox(false)
        setLegIk(PlayerPedId(), 2)
    end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    for _, p in pairs(prompts) do PromptDelete(p.handle) end
end)
