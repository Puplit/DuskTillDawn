-- pup-misc / props: attaches/removes the wearable props the server announces

local activeProps = {}
-- other players' props are held back for PropsConfig.General.startupDelaySeconds after character select
local propSpawnReady = true

local function RemoveProp(obj)
    if not obj or not DoesEntityExist(obj) then return end
    DetachEntity(obj, false, false)
    -- delete BEFORE releasing it: giving the engine ownership first can leave the object standing in the world
    DeleteObject(obj)
    if DoesEntityExist(obj) then SetEntityAsNoLongerNeeded(obj) end
end

-- a set (def.extra) is one item wearing several objects, so they go together
local function RemoveEntry(entry)
    if type(entry) ~= "table" then return end
    RemoveProp(entry.obj)
    if type(entry.extra) == "table" then
        for _, o in ipairs(entry.extra) do RemoveProp(o) end
    end
end

-- six real numbers, or it does not go near AttachEntityToEntity
local function validOff(o)
    if type(o) ~= "table" then return false end
    for i = 1, 6 do
        local v = o[i]
        if type(v) ~= "number" or v ~= v then return false end
    end
    return true
end

local function ResolveAttach(ped, def)
    -- a saved offset that did not survive the round trip is ignored (it would attach the prop at garbage);
    -- the built-in offset is used instead, which can be fixed with /pa
    if def.custom then
        if validOff(def.custom) then return def.custom end
        print(("^3[pup-misc/props]^7 saved offset for this prop is unusable, using the default"))
    end
    if def.attach_male and def.attach_female then
        return IsPedMale(ped) and def.attach_male or def.attach_female
    end
    return def.attach
end

local function ResolveModel(ped, def)
    if def.model_male and def.model_female then
        return IsPedMale(ped) and def.model_male or def.model_female
    end
    return def.model
end

local function Attach(obj, ped, boneName, o)
    local boneIdx
    -- ENTITY_ROOT is not a bone. It is the body root, which is where a prop that
    -- stands in front of the player goes so it does not sway with the animation.
    if boneName == "ENTITY_ROOT" then
        boneIdx = 0
    else
        boneIdx = GetEntityBoneIndexByName(ped, boneName)
        -- an unknown bone returns -1, which pins the prop to the ped's root instead
        if not boneIdx or boneIdx == -1 then
            print(("^3[pup-misc/props]^7 bone '%s' not found on this ped"):format(tostring(boneName)))
            boneIdx = 0
        end
    end
    AttachEntityToEntity(obj, ped, boneIdx, o[1], o[2], o[3], o[4], o[5], o[6], false, true, false, true, 2, true)
end

local function SpawnAndAttach(ped, model, boneName, offsets)
    local coords = GetEntityCoords(ped)
    local hash   = GetHashKey(model)

    RequestModel(hash)
    local attempts = 0
    while not HasModelLoaded(hash) do
        Wait(50)
        attempts = attempts + 1
        if attempts > 60 then
            print("[pup-misc/props] Timed out loading model: " .. model)
            return nil
        end
    end

    -- LOCAL, not networked
    local obj = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, false, false)
    if not DoesEntityExist(obj) then
        print("[pup-misc/props] object was not created: " .. model)
        return nil
    end
    Citizen.InvokeNative(0xE0580EC84813875A, obj, false, true)
    SetEntityCollision(obj, false, false)

    local tries = 0
    repeat
        Attach(obj, ped, boneName, offsets)
        tries = tries + 1
        if IsEntityAttachedToEntity(obj, ped) then break end
        Wait(0)
    until tries >= 10

    SetModelAsNoLongerNeeded(hash)
    return obj
end

-- OPTIONAL IDLE ANIMATION
-- def.anim = { dict, clip } plays a looping idle (a banjo held in a fist reads wrong without one).
-- Only on your own ped: forcing a task onto a ped you do not own desyncs.
local animatedBy = {} -- itemName -> true, so the loop is only cleared once

local scenarioBy = {} -- itemName -> true when a scenario, not an anim, is running

local function PlayPropAnim(ped, def, itemName)
    -- def.scenario puts the ped INTO a pose, e.g. sitting down to read
    if type(def.scenario) == "string" and def.scenario ~= "" then
        local seatZ <const> = tonumber(def.scenarioSeatZ)
        if seatZ then
            -- below the ped, so a seat scenario sits rather than stands
            local x, y, z = table.unpack(GetEntityCoords(ped))
            TaskStartScenarioAtPosition(ped, GetHashKey(def.scenario), x, y, z + seatZ, GetEntityHeading(ped), -1, false, true)
        else
            TaskStartScenarioInPlace(ped, GetHashKey(def.scenario), -1, true, false, false, false)
        end
        animatedBy[itemName] = { scenario = true }
        scenarioBy[itemName] = true
        -- a def may carry both: the scenario poses the body, def.anim layers the hands
        if type(def.anim) ~= "table" then return end
    end

    if type(def.anim) ~= "table" or not def.anim[1] or not def.anim[2] then return end
    local dict, clip = def.anim[1], def.anim[2]
    -- anim = { dict, clip, duration, flag, rate }. Flag 31 carries AF_NOT_INTERRUPTABLE,
    -- which is what stops running from cancelling the idle.
    local duration = tonumber(def.anim[3]) or 9999999999
    local flag     = tonumber(def.anim[4]) or def.animFlag or 31
    local rate     = tonumber(def.anim[5]) or 1.0

    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 100 do
        Wait(10)
        tries = tries + 1
    end
    if not HasAnimDictLoaded(dict) then
        print(("^3[pup-misc/props]^7 anim dict failed to load: %s"):format(dict))
        return
    end

    -- 13-argument form, and the dict is deliberately NOT removed afterwards
    TaskPlayAnim(ped, dict, clip, 1.0, 1.0, duration, flag, rate, false, false, false, 0, true)
    -- the clip is kept so it can be stopped by name: see StopPropAnim
    animatedBy[itemName] = { dict = dict, clip = clip, flag = flag }
end

local function StopPropAnim(ped, itemName)
    local a <const> = animatedBy[itemName]
    if not a then return end
    local wasScenario <const> = scenarioBy[itemName]
    animatedBy[itemName] = nil
    scenarioBy[itemName] = nil
    if not DoesEntityExist(ped) then return end

    -- a scenario is a full task; clearing only the secondary one leaves them sat down
    if wasScenario then return ClearPedTasksImmediately(ped) end

    -- the idle may be a primary task, which ClearPedSecondaryTask never ends: stop the clip by name
    if type(a) == "table" and a.dict then StopAnimTask(ped, a.dict, a.clip, 4.0) end
    ClearPedSecondaryTask(ped)
end

RegisterNetEvent("pup_props:toggle")
AddEventHandler("pup_props:toggle", function(playerId, itemName, def, equipped)
    if not activeProps[playerId] then activeProps[playerId] = {} end

    local existing = activeProps[playerId][itemName]
    local isSelf   = (playerId == GetPlayerServerId(PlayerId()))

    if not equipped then
        -- `existing` is { obj, extra, def }; the object is the field, not the table
        if existing then RemoveEntry(existing) end
        activeProps[playerId][itemName] = nil
        if isSelf then
            StopPropAnim(PlayerPedId(), itemName)
            TriggerEvent("vorp:TipRight", PropsLocale.prop_removed, 2500)
        end
        return
    end

    -- record first, spawn second: the wearer may have no ped here yet, and the watchdog attaches later
    if existing then RemoveEntry(existing) end
    activeProps[playerId][itemName] = { obj = nil, extra = nil, def = def }

    -- not yet: the post-delay resync fetches everything worn, so nothing is lost
    if not isSelf and not propSpawnReady then return end

    local playerHandle = GetPlayerFromServerId(playerId)
    if playerHandle == -1 then return end
    local ped = GetPlayerPed(playerHandle)
    if not DoesEntityExist(ped) then return end

    -- animOnly: the pose already carries its own prop (a scenario book, a shovel),
    -- so attaching ours too would put two of the same thing in their hands
    if def.animOnly then
        if isSelf then
            PlayPropAnim(ped, def, itemName)
            if not existing then TriggerEvent("vorp:TipRight", PropsLocale.prop_equipped, 2500) end
        end
        return
    end

    local obj = SpawnAndAttach(ped, ResolveModel(ped, def), def.bone, ResolveAttach(ped, def))
    if obj then
        -- def.extra: the rest of a set, each with its own model, bone and offset.
        -- A piece that fails to load is skipped rather than failing the whole set.
        local extra
        if type(def.extra) == "table" then
            extra = {}
            for _, part in ipairs(def.extra) do
                local o = SpawnAndAttach(ped, ResolveModel(ped, part), part.bone or def.bone, ResolveAttach(ped, part))
                if o then extra[#extra + 1] = o end
            end
        end
        activeProps[playerId][itemName] = { obj = obj, extra = extra, def = def }
        if isSelf then PlayPropAnim(ped, def, itemName) end
        if isSelf and not existing then TriggerEvent("vorp:TipRight", PropsLocale.prop_equipped, 2500) end
    elseif isSelf then
        TriggerEvent("vorp:TipRight", PropsLocale.prop_load_failed, 2500)
    end
end)

-- own props follow the ped through rebuilds (/rc, revive) and instance changes
local function resync()
    for playerId, props in pairs(activeProps) do
        for _, p in pairs(props) do RemoveEntry(p) end
        activeProps[playerId] = nil
    end
    TriggerServerEvent("pup_props:requestSync")
end
AddEventHandler("playerSpawned", function() Wait(2000) resync() end)
AddEventHandler("vorp_character:client:reloadedComponents", function() Wait(1500) resync() end)
RegisterNetEvent("vorp_core:instanceChanged", function() Wait(1000) resync() end)

-- character select: hold other players' props for the configured delay, then pull them all
RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function()
    local delay = math.max(0, math.floor(tonumber(PropsConfig and PropsConfig.General.startupDelaySeconds) or 0))
    if delay <= 0 then propSpawnReady = true return end
    propSpawnReady = false
    Citizen.SetTimeout(delay * 1000, function()
        propSpawnReady = true
        resync()
    end)
end)

-- players who leave scope: drop their objects so nothing stays orphaned, but KEEP the record so the prop comes back
-- when they walk into view again (a disconnect clears the record through the server's toggle-off)
CreateThread(function()
    while true do
        Wait(3000)
        local mySid = GetPlayerServerId(PlayerId())
        for playerId, props in pairs(activeProps) do
            local handle = GetPlayerFromServerId(playerId)
            local ped = (handle ~= -1) and GetPlayerPed(handle) or 0
            if ped == 0 or not DoesEntityExist(ped) then
                for _, p in pairs(props) do
                    if p.obj or p.extra then RemoveEntry(p) p.obj, p.extra = nil, nil end
                end
            elseif playerId ~= mySid and propSpawnReady then
                for _, p in pairs(props) do
                    -- animOnly carries no object of its own, so it is never "missing"
                    if p.def and not p.def.animOnly
                        and (not p.obj or not DoesEntityExist(p.obj) or not IsEntityAttachedToEntity(p.obj, ped)) then
                        -- a set re-attaches whole: its pieces are placed against each other
                        RemoveEntry(p)
                        p.extra = nil
                        p.obj = SpawnAndAttach(ped, ResolveModel(ped, p.def), p.def.bone, ResolveAttach(ped, p.def))
                        if p.obj and type(p.def.extra) == "table" then
                            p.extra = {}
                            for _, part in ipairs(p.def.extra) do
                                local o = SpawnAndAttach(ped, ResolveModel(ped, part), part.bone or p.def.bone, ResolveAttach(ped, part))
                                if o then p.extra[#p.extra + 1] = o end
                            end
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if GetCurrentResourceName() ~= resource then return end
    for _, props in pairs(activeProps) do
        for _, p in pairs(props) do RemoveEntry(p) end
    end
    activeProps = {}
end)

-- /pa: move a worn prop and save the position for this character
local K = PropsConfig.Keys
local editing = nil   -- { item, def, obj, off = {6}, orig = {6} }
local stepT, stepR = 0.01, 1.0
local PA_OWNER = "pup-misc:props"
local paRows = {}
local paMenu = false

local function paReattach()
    local ped = PlayerPedId()
    if not editing or not DoesEntityExist(editing.obj) then return end
    DetachEntity(editing.obj, false, false)
    Attach(editing.obj, ped, editing.def.bone, editing.off)
end

local function drawTxt(text, x, y)
    SetTextScale(0.3, 0.3)
    SetTextColor(255, 255, 255, 255)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end

local function paExit(save)
    if not editing then return end
    local e = editing
    editing = nil
    if save then
        TriggerServerEvent("pup_props:saveOffset", e.item, e.off)
        TriggerEvent("vorp:TipRight", PropsLocale.position_saved, 2500)
    else
        e.off = e.orig
        editing = e
        paReattach()
        editing = nil
    end
end

local function paConfirm()
    paRows = {
        { label = PropsLocale.option_save, value = "save" },
        { label = PropsLocale.option_resume, value = "resume" },
        { label = PropsLocale.option_reset, value = "reset" },
        { label = PropsLocale.option_cancel, value = "cancel" },
    }
    paMenu = "confirm"
    local options = {}
    for i, r in ipairs(paRows) do options[i] = { label = r.label } end
    exports['pup-ui']:OpenListMenu({ owner = PA_OWNER, title = PropsLocale.confirm_title, options = options })
end

local function paStart(item, def)
    local mine = activeProps[GetPlayerServerId(PlayerId())]
    local p = mine and mine[item]
    if not p or not p.obj or not DoesEntityExist(p.obj) then
        return TriggerEvent("vorp:TipRight", PropsLocale.prop_not_on_you, 3000)
    end
    local cur = ResolveAttach(PlayerPedId(), def)
    editing = { item = item, def = def, obj = p.obj,
        off = { cur[1], cur[2], cur[3], cur[4], cur[5], cur[6] },
        orig = { cur[1], cur[2], cur[3], cur[4], cur[5], cur[6] } }
    -- key-repeat state for this edit session (see PropsConfig.Editor)
    local holdStart, lastStep = nil, 0
    local paRepeat <const> = tonumber(PropsConfig.Editor.moveRepeatMs) or 70
    local paDelay  <const> = tonumber(PropsConfig.Editor.moveDelayMs) or 250

    CreateThread(function()
        while editing and editing.item == item do
            Wait(0)
            local e = editing
            drawTxt(PropsLocale.editing:format(item), 0.02, 0.35)
            drawTxt(("x=%.3f y=%.3f z=%.3f"):format(e.off[1], e.off[2], e.off[3]), 0.02, 0.38)
            drawTxt(("rx=%.1f ry=%.1f rz=%.1f  step %.3f / %.1f"):format(e.off[4], e.off[5], e.off[6], stepT, stepR), 0.02, 0.41)
            drawTxt(PropsLocale.help_move, 0.02, 0.45)
            drawTxt(PropsLocale.help_keys, 0.02, 0.48)

            if IsControlPressed(0, K.cancel) then paExit(false) break end
            if IsControlJustPressed(0, K.save) then Wait(300) paConfirm() break end
            if IsControlJustPressed(0, K.stepSize) then
                if stepT < 0.011 then stepT, stepR = 0.05, 2.0
                elseif stepT < 0.051 then stepT, stepR = 0.001, 0.5
                else stepT, stepR = 0.01, 1.0 end
            end
            if IsControlJustPressed(0, K.reset) then
                for i = 1, 6 do e.off[i] = e.orig[i] end
                paReattach()
            end
            -- one step per tap, then repeat on a clock while held, so the speed does not follow the framerate
            local held = IsControlPressed(0, K.up) or IsControlPressed(0, K.down)
                or IsControlPressed(0, K.left) or IsControlPressed(0, K.right)
                or IsControlPressed(0, K.raise) or IsControlPressed(0, K.lower)
            local nowMs = GetGameTimer()
            local step = false
            if not held then
                holdStart = nil
            elseif not holdStart then
                holdStart, lastStep, step = nowMs, nowMs, true
            elseif (nowMs - holdStart) >= paDelay and (nowMs - lastStep) >= paRepeat then
                lastStep, step = nowMs, true
            end

            local shift = IsControlPressed(0, K.rotate)
            local moved = false
            if step then
                if IsControlPressed(0, K.up)    then if shift then e.off[5] = e.off[5] + stepR else e.off[2] = e.off[2] + stepT end moved = true end
                if IsControlPressed(0, K.down)  then if shift then e.off[5] = e.off[5] - stepR else e.off[2] = e.off[2] - stepT end moved = true end
                if IsControlPressed(0, K.left)  then if shift then e.off[4] = e.off[4] - stepR else e.off[1] = e.off[1] - stepT end moved = true end
                if IsControlPressed(0, K.right) then if shift then e.off[4] = e.off[4] + stepR else e.off[1] = e.off[1] + stepT end moved = true end
                if IsControlPressed(0, K.raise)  then if shift then e.off[6] = e.off[6] - stepR else e.off[3] = e.off[3] + stepT end moved = true end
                if IsControlPressed(0, K.lower) then if shift then e.off[6] = e.off[6] + stepR else e.off[3] = e.off[3] - stepT end moved = true end
            end
            if moved then paReattach() end
        end
    end)
end

RegisterNetEvent("pup_props:worn")
AddEventHandler("pup_props:worn", function(list)
    if #list == 0 then
        return TriggerEvent("vorp:TipRight", PropsLocale.no_props_worn, 3000)
    end
    paRows = {}
    local options = {}
    for i, w in ipairs(list) do
        local label = w.item
        for _, it in ipairs(PropsConfig.Props or {}) do if it.item == w.item then label = it.label break end end
        paRows[i] = { value = "pick", item = w.item, def = w.def, label = label }
        options[i] = { label = label }
    end
    paMenu = "pick"
    exports['pup-ui']:OpenListMenu({ owner = PA_OWNER, title = PropsLocale.picker_title, options = options })
end)

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= PA_OWNER or not paMenu then return end
    local row = paRows[index]
    local mode = paMenu
    paMenu = false
    if not row then return end
    if mode == "pick" then
        paStart(row.item, row.def)
    elseif mode == "confirm" and editing then
        if row.value == "save" then paExit(true)
        elseif row.value == "resume" then paStart(editing.item, editing.def)
        elseif row.value == "reset" then
            local e = editing
            editing = nil
            TriggerServerEvent("pup_props:resetOffset", e.item)
            TriggerEvent("vorp:TipRight", PropsLocale.position_reset, 2500)
        else paExit(false) end
    end
end)

local function paMenuGone(owner)
    if owner ~= PA_OWNER or not paMenu then return end
    paMenu = false
    if editing then paExit(false) end
end
AddEventHandler('pup-ui:client:listBack', paMenuGone)
AddEventHandler('pup-ui:client:listClosed', paMenuGone)

RegisterCommand(PropsConfig.General.command or "pa", function()
    if editing then return end
    TriggerServerEvent("pup_props:requestWorn")
end, false)
