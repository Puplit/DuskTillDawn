-- legendaryhunt | client: the hunter's one trap
-- States: idle -> holding -> busy (putting down) -> placed -> busy (picking up) -> idle.
-- Every wait that can be interrupted captures Trap.gen; a reset bumps it so stale work stops.

Trap = {
    state = 'idle',
    gen = 0,
    confirmed = false,       -- the server took a trap item for this hold
    returnOnConfirm = false, -- put away before the server answered: hand it back when it does
}

local T, H = Config.Trap, Config.Hunt
local holdGroup, placedGroup
local pPlace, pPutAway, pTake, pLure, pActivate
local alertBlips = {}
local replies, reqSeq = {}, 0

local DISABLED_WHILE_HOLDING <const> = {
    `INPUT_OPEN_WHEEL_MENU`, `INPUT_OPEN_SATCHEL_MENU`, `INPUT_OPEN_SATCHEL_HORSE_MENU`,
    `INPUT_QUICK_SELECT_INSPECT`, `INPUT_AIM`, `INPUT_ATTACK`, `INPUT_MELEE_ATTACK`,
    `INPUT_MELEE_GRAPPLE`, `INPUT_NEXT_WEAPON`, `INPUT_PREV_WEAPON`, `INPUT_SELECT_NEXT_WEAPON`,
    `INPUT_SELECT_PREV_WEAPON`, `INPUT_TWIRL_PISTOL`, `INPUT_RELOAD`, `INPUT_INTERACT_LOCKON`,
    `INPUT_QUICK_USE_ITEM`, `INPUT_OPEN_JOURNAL`,
}

CreateThread(function()
    holdGroup, placedGroup = Cli.newGroup(), Cli.newGroup()
    pPlace    = Cli.prompt(Config.Keys.place, Rules.text('promptPlace'), holdGroup)
    pPutAway  = Cli.prompt(Config.Keys.putAway, Rules.text('promptPutAway'), holdGroup)
    pTake     = Cli.prompt(Config.Keys.take, Rules.text('promptTake'), placedGroup)
    pLure     = Cli.prompt(Config.Keys.lure, Rules.text('promptBait'), placedGroup)
    pActivate = Cli.prompt(Config.Keys.activate, Rules.text('promptActivate'), placedGroup)
end)

local function pose(clip)
    if not Trap.obj or not DoesEntityExist(Trap.obj) then return end
    if Cli.loadDict(T.poseDict) then
        Cli.native('PlayEntityAnim', Trap.obj, clip, T.poseDict, 1000.0, false, true, false, 0.0, 0)
    end
end

-- forget the trap. deleteLegendary only on resource stop: a spawned legendary normally stays out.
function Trap.reset(deleteLegendary)
    Trap.gen = Trap.gen + 1
    Cli.deleteEntity(Trap.held)
    Cli.deleteEntity(Trap.ghost)
    Cli.deleteEntity(Trap.obj)
    if Menu.isOpen() then Menu.hide() end
    Trap.held, Trap.ghost, Trap.obj, Trap.pos = nil, nil, nil, nil
    Trap.zoneName, Trap.groundIdx, Trap.animalId = nil, nil, nil
    Trap.lure, Trap.lureLabel, Trap.luringAt = nil, nil, nil
    Trap.open, Trap.callTimer, Trap.actTimer = false, 0, 0
    Trap.pending, Trap.spawning, Trap.spent = false, false, false
    Trap.confirmed, Trap.returnOnConfirm = false, false
    Trap.state = 'idle'
    if deleteLegendary then
        Cli.deleteEntity(Trap.legendary)
        Trap.legendary = nil
        for b in pairs(alertBlips) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
        alertBlips = {}
    end
end

-- hunting ground at a point: the game's area (12), district (11) and region (10) there are
-- checked in that order against config/grounds.lua; the smallest zone that is a ground wins
local function groundAt(pos)
    for _, zoneType in ipairs({ 12, 11, 10 }) do
        local raw = Citizen.InvokeNative(0x43AD8FC02B429D33, pos.x, pos.y, pos.z, zoneType, Citizen.ResultAsInteger())
        if raw and raw ~= 0 then
            local index = Rules.groundByZone[Rules.signed32(raw)]
            local g = index and Rules.ground(index)
            if g then return tostring(g.label or g.zone), index end
        end
    end
    return Config.Text.none, nil
end

-- compared as signed 32-bit: a hash can come back signed or unsigned depending on the call
local UNARMED <const> = Cli.signed32(`WEAPON_UNARMED`)
local function weaponOut()
    local _, weapon = GetCurrentPedWeapon(PlayerPedId(), true, 0, true)
    if weapon == nil or weapon == 0 then return false end
    return Cli.signed32(weapon) ~= UNARMED
end

-- 1. take the trap out
local function startHold()
    local hash = Cli.loadModel(T.model)
    if not hash then return false end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local held = CreateObject(hash, c.x, c.y, c.z, true, true, false)
    SetEntityCollision(held, false, false)
    local bone = IsPedMale(ped) and T.boneMale or T.boneFemale
    AttachEntityToEntity(held, ped, bone, T.handOffset.x, T.handOffset.y, T.handOffset.z,
        T.handRotation.x, T.handRotation.y, T.handRotation.z, false, false, false, false, 2, true, false, false)
    local ghost = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    SetEntityCollision(ghost, false, false)
    SetEntityAlpha(ghost, T.ghostAlpha, false)
    SetModelAsNoLongerNeeded(hash)
    Trap.held, Trap.ghost = held, ghost
    Trap.confirmed, Trap.returnOnConfirm = false, false
    Trap.state = 'holding'
    return true
end

-- put away before the server answered; the wait gives up after 20 s so a lost answer cannot block the trap item
local function awaitingReturn()
    if Trap.returnOnConfirm and GetGameTimer() - (Trap.returnSince or 0) < 20000 then return true end
    Trap.returnOnConfirm = false
    return false
end

local function markReturnOnConfirm()
    Trap.returnOnConfirm, Trap.returnSince = true, GetGameTimer()
end

RegisterNetEvent('legendaryhunt:useTrap', function()
    pcall(function() exports.vorp_inventory:closeInventory() end)
    if awaitingReturn() then return Cli.tip(Config.Text.busy) end
    if Trap.state == 'holding' then return Cli.tip(Rules.text('trapInHand')) end
    if Trap.state ~= 'idle' then return Cli.tip(Rules.text('trapAlreadyPlaced')) end
    if weaponOut() then return Cli.tip(Rules.text('noWeapon')) end
    if startHold() then TriggerServerEvent('legendaryhunt:takeTrap') end
end)

RegisterNetEvent('legendaryhunt:takeResult', function(ok)
    if Trap.state == 'idle' then
        -- put away before the answer came: the server now holds a trap that should come back.
        -- Idle means this client holds no trap, so any "taken" answer is handed straight back.
        if ok then TriggerServerEvent('legendaryhunt:returnTrap') end
        Trap.returnOnConfirm = false
        return
    end
    if ok then
        Trap.confirmed = true
    else
        Trap.reset(false) -- no item was taken, so no trap (the server already said why)
    end
end)

local function putAway()
    local confirmed = Trap.confirmed
    Trap.reset(false)
    if confirmed then
        TriggerServerEvent('legendaryhunt:returnTrap')
    else
        markReturnOnConfirm()
    end
end

-- 2. put it down
local function place()
    if IsEntityInWater(Trap.ghost) then return Cli.tip(Rules.text('cantPlace')) end
    local gen = Trap.gen
    local ped = PlayerPedId()
    local pos, heading = GetEntityCoords(Trap.ghost), GetEntityHeading(Trap.ghost)
    Trap.state = 'busy'
    Cli.deleteEntity(Trap.held)
    Cli.deleteEntity(Trap.ghost)
    Trap.held, Trap.ghost = nil, nil

    CreateThread(function()
        TaskTurnPedToFaceCoord(ped, pos.x, pos.y, pos.z, 1000)
        Wait(500)
        local animOk = Cli.loadDict(T.placeAnim.dict)
        if animOk then
            TaskPlayAnim(ped, T.placeAnim.dict, T.placeAnim.clip, 8.0, -8.0, T.placeAnim.ms, 0, 0.0, false, false, false)
        end
        local hash = Cli.loadModel(T.model)
        local obj
        if hash and Trap.gen == gen then
            obj = CreateObject(hash, pos.x, pos.y, pos.z, true, true, false)
            SetEntityHeading(obj, heading)
            PlaceObjectOnGroundProperly(obj, true)
            SetEntityAsMissionEntity(obj, true, true)
            SetModelAsNoLongerNeeded(hash)
        end
        if Trap.gen == gen then
            Trap.obj = obj
            pose(T.shutClip)
        end
        Wait(T.placeAnim.ms)
        ClearPedTasks(ped)
        if animOk then RemoveAnimDict(T.placeAnim.dict) end
        if Trap.gen ~= gen then
            if obj ~= Trap.obj then Cli.deleteEntity(obj) end
            return
        end
        if not obj then
            -- the model never loaded: give the trap back rather than leave it nowhere
            putAway()
            return
        end
        Trap.pos = GetEntityCoords(obj)
        Trap.zoneName, Trap.groundIdx = groundAt(Trap.pos)
        Trap.animalId = nil
        Trap.open, Trap.callTimer, Trap.actTimer = false, 0, 0
        Trap.state = 'placed'
    end)
end

-- 3. the placed trap's prompts
local function take()
    local gen = Trap.gen
    Trap.state = 'busy'
    Trap.pending = false
    CreateThread(function()
        Cli.playTimed(T.pickupAnim)
        if Trap.gen ~= gen then return end
        local confirmed = Trap.confirmed
        Trap.reset(false)
        if confirmed then
            TriggerServerEvent('legendaryhunt:returnTrap')
        else
            markReturnOnConfirm()
        end
    end)
end

-- a lure sent to the server and not yet answered (or its crouch still playing); 5 s at most
local function luring()
    return Trap.luringAt ~= nil and GetGameTimer() - Trap.luringAt < 5000
end

local function openLureMenu()
    if Trap.lure then return Cli.tip(Rules.text('hasBait')) end
    -- a second lure picked during the first one's round trip would take a second item for nothing
    if luring() then return Cli.tip(Config.Text.busy) end
    local ped = PlayerPedId()
    local options = {}
    for _, l in ipairs(Config.Lures) do
        options[#options + 1] = { label = l.label, desc = Rules.text('baitOptionDesc') }
    end
    TaskStandStill(ped, -1)
    local opened = Menu.open({
        title = Rules.text('baitMenuTitle'),
        subtitle = Rules.text('baitMenuSubtitle'),
        options = options,
    }, {
        select = function(index)
            ClearPedTasks(ped)
            local l = Config.Lures[index]
            if l and Trap.state == 'placed' and not Trap.lure and not luring() then
                Trap.luringAt = GetGameTimer()
                TriggerServerEvent('legendaryhunt:addLure', l.item)
            end
        end,
        back = function() ClearPedTasks(ped) end,
        closed = function() ClearPedTasks(ped) end,
    })
    if not opened then ClearPedTasks(ped) end
end

RegisterNetEvent('legendaryhunt:lureResult', function(ok, item, label)
    if not ok or Trap.state ~= 'placed' or type(item) ~= 'string' then
        Trap.luringAt = nil
        return
    end
    local gen = Trap.gen
    Trap.luringAt = GetGameTimer() -- covers the crouch
    CreateThread(function()
        Cli.playTimed(T.baitAnim)
        if Trap.gen ~= gen then return end
        Trap.lure, Trap.lureLabel = item, tostring(label or item)
        Trap.luringAt = nil
        -- advisory: tell the hunter now if what this lure calls here is resting
        local id = Rules.beastForLure(Rules.ground(Trap.groundIdx), item)
        if id then TriggerServerEvent('legendaryhunt:peek', id) end
    end)
end)

local function explainSilence()
    local ground = Rules.ground(Trap.groundIdx)
    if not ground then return Cli.tip(Config.Text.whyNoBeast) end
    if not Rules.beastForLure(ground, Trap.lure) then return Cli.tip(Config.Text.whyWrongLure) end
    if not Rules.beastNow(ground, Trap.lure, GetClockHours()) then return Cli.tip(Config.Text.whyWrongHour) end
end

local function activate()
    if Trap.open then
        pose(T.shutClip)
        Trap.open = false
    elseif not Trap.lure then
        Cli.tip(Rules.text('noBaitInTrap'))
    else
        pose(T.openClip)
        Trap.callTimer = 0
        Trap.open = true
        if Config.Options.tellWhyNothingComes then explainSilence() end
    end
end

-- called every frame by client/main.lua while holding
function Trap.holdFrame()
    local ped = PlayerPedId()
    for _, c in ipairs(DISABLED_WHILE_HOLDING) do DisableControlAction(0, c, true) end
    if Trap.ghost and DoesEntityExist(Trap.ghost) then
        local p = GetOffsetFromEntityInWorldCoords(ped, 0.0, T.ghostForward, -T.ghostDown)
        SetEntityCoordsNoOffset(Trap.ghost, p.x, p.y, p.z, false, false, false)
        SetEntityHeading(Trap.ghost, GetEntityHeading(ped))
    end
    PromptSetActiveGroupThisFrame(holdGroup, Cli.varString(Rules.text('promptGroupTrap')))
    PromptSetEnabled(pPlace, Trap.confirmed)
    if Cli.pressed(pPlace) and Trap.confirmed then
        place()
    elseif Cli.pressed(pPutAway) then
        putAway()
    end
end

-- called every frame by client/main.lua while the owner stands by the placed trap
function Trap.placedFrame()
    local above = Trap.pos + vector3(0.0, 0.0, 0.45)
    Cli.drawLabel(above,
        Config.Text.baitLine:format(Trap.lureLabel or Config.Text.none),
        Config.Text.areaLine:format(Trap.zoneName or 'None'))
    PromptSetActiveGroupThisFrame(placedGroup, Cli.varString(Rules.text('promptGroupTrap')))
    -- while the server is deciding on the spawn the trap stays put (taking it would void the approval)
    if Trap.spawning then return end
    if Cli.pressed(pTake) then
        take()
    elseif Cli.pressed(pLure) then
        openLureMenu()
    elseif Cli.pressed(pActivate) then
        activate()
    end
end

function Trap.distance()
    if Trap.state ~= 'placed' or not Trap.pos then return nil end
    return #(GetEntityCoords(PlayerPedId()) - Trap.pos)
end

-- 4. the call and the spawn
RegisterNetEvent('legendaryhunt:checkResult', function(reqId, onCooldown)
    reqId = tonumber(reqId)
    if reqId and replies[reqId] == false then replies[reqId] = { onCooldown = onCooldown == true } end
end)

local function alertBlip(pos, name)
    local b = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, pos.x, pos.y, pos.z)
    if not b or b == 0 then return end
    SetBlipSprite(b, H.alertSprite, true)
    SetBlipScale(b, 1.0)
    Citizen.InvokeNative(0x9CB1A1623062F402, b, tostring(name))
    Citizen.InvokeNative(0x662D364ABF16DE2F, b, H.alertModifier)
    alertBlips[b] = true
    -- each blip removes itself, so a second spawn cannot strand the first
    SetTimeout(H.alertSeconds * 1000, function()
        if alertBlips[b] then
            alertBlips[b] = nil
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
    end)
end

local function alive(ped)
    return ped and ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped)
end

local function createLegendary(animal, base)
    local hash = Cli.loadModel(animal.model, 10000)
    if not hash then
        Cli.warnOnce('model_' .. tostring(animal.model), ('legendary model for "%s" did not load'):format(tostring(animal.name)))
        return nil
    end
    local span = H.spawnMax - H.spawnMin
    local x = base.x + H.spawnMin + math.random() * span
    local y = base.y + H.spawnMin + math.random() * span

    local ped
    for _ = 1, 30 do
        ped = CreatePed(hash, x, y, base.z, 0.0, true, true, false, false)
        if ped and ped ~= 0 and DoesEntityExist(ped) then break end
        ped = nil
        Wait(100)
    end
    SetModelAsNoLongerNeeded(hash)
    if not ped then return nil end

    FreezeEntityPosition(ped, true)
    local outfit = tonumber(animal.outfit) or 0
    Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit, false)
    local deadline = GetGameTimer() + 4000
    while not Citizen.InvokeNative(0xA0BC8FAED8CFEB3C, ped) and GetGameTimer() < deadline do
        Citizen.InvokeNative(0x77FF8D35EEC6BBC4, ped, outfit, false)
        Wait(50)
    end

    local z, found, gz = 100.0, false, 0.0
    for _ = 1, 120 do
        found, gz = GetGroundZFor_3dCoord(x, y, z, false)
        if found then break end
        z = z + 10.0
    end
    if found then SetEntityCoordsNoOffset(ped, x, y, gz, false, false, false) end
    FreezeEntityPosition(ped, false)

    SetEntityMaxHealth(ped, math.floor(H.legendaryHealth))
    SetEntityHealth(ped, math.floor(H.legendaryHealth), 0)
    -- no lasso, so no hogtie
    Cli.native('SetPedLassoHogtieFlag', ped, 0, false)
    Cli.native('SetPedLassoHogtieFlag', ped, 1, false)
    if Rules.fighter[Cli.signed32(hash)] then
        SetPedCombatAttributes(ped, 5, true)
        SetPedCombatAttributes(ped, 58, true)
    end
    return ped
end

-- wander a little, walk to the trap, then roam around it
local function behave(ped, trapPos)
    CreateThread(function()
        Cli.native('TaskWanderStandard', ped, 10.0, 10)
        Wait(H.wanderFirstMs)
        if not alive(ped) then return end
        TaskGoToCoordAnyMeans(ped, trapPos.x, trapPos.y, trapPos.z, 1.0, 0, false, 0, 0.0)
        local deadline = GetGameTimer() + 300000
        while alive(ped) and GetGameTimer() < deadline do
            if #(GetEntityCoords(ped) - trapPos) <= H.reachTrapMetres then
                Cli.native('TaskWanderInArea', ped, trapPos.x, trapPos.y, trapPos.z, H.roamRadius, 0, 0, 0)
                return
            end
            Wait(1000)
        end
    end)
end

local function attemptSpawn()
    local gen = Trap.gen
    local id = Trap.animalId
    local animal = Rules.animal(id)
    Trap.spawning = true
    CreateThread(function()
        reqSeq = reqSeq + 1
        local req = reqSeq
        replies[req] = false
        TriggerServerEvent('legendaryhunt:check', id, req)
        local deadline = GetGameTimer() + H.replyTimeoutMs
        while replies[req] == false and GetGameTimer() < deadline do Wait(100) end
        local answer = replies[req]
        replies[req] = nil
        if Trap.gen ~= gen then return end
        Trap.spawning = false

        if type(answer) ~= 'table' then
            Trap.pending, Trap.spent = false, true
            return Cli.tip(Config.Text.replyTimeout)
        end
        if answer.onCooldown or not animal then
            Trap.pending, Trap.spent = false, true
            return Cli.tip(Rules.text('onCooldown'))
        end

        TriggerServerEvent('legendaryhunt:log', Trap.zoneName)
        local base = Trap.pos
        local ped = createLegendary(animal, base)
        Trap.pending = false
        Trap.open = false
        if Trap.gen ~= gen then
            -- character switch or stop while the legendary was being made: the approval is gone, so is it
            Cli.deleteEntity(ped)
            return
        end
        if not ped then
            Trap.spent = true
            return
        end
        TriggerServerEvent('legendaryhunt:spawned', id)
        Trap.lure, Trap.lureLabel = nil, nil -- the call used the lure up
        Trap.legendary = ped
        alertBlip(GetEntityCoords(ped), animal.name)
        behave(ped, base)
    end)
end

-- once a second: count the call, then the activation
function Trap.tick()
    if Trap.legendary and not alive(Trap.legendary) then
        if DoesEntityExist(Trap.legendary) then SetEntityAsNoLongerNeeded(Trap.legendary) end
        Trap.legendary = nil
    end
    if Trap.state ~= 'placed' or Trap.spawning or Trap.spent then return end

    if Trap.pending then
        Trap.actTimer = Trap.actTimer + 1
        if Trap.actTimer >= Cli.scaledSeconds(H.activateSeconds) then attemptSpawn() end
        return
    end
    if not Trap.open or Trap.legendary then return end
    local id = Rules.beastNow(Rules.ground(Trap.groundIdx), Trap.lure, GetClockHours())
    if not id then return end
    Trap.callTimer = Trap.callTimer + 1
    if Trap.callTimer >= Cli.scaledSeconds(H.callSeconds) then
        -- the beast is fixed once the call goes out, even if the hour turns while it comes
        Trap.animalId = id
        Trap.pending = true
        Trap.actTimer = 0
    end
end

-- vorp_admin world cleanup: staff deleted the placed trap, so it goes back in the satchel
-- (the same as taking it). A trap in the hand is attached to the player and is kept.
RegisterNetEvent('vorp_admin:worldCleanupDone', function()
    if Trap.state ~= 'placed' or not Trap.obj or DoesEntityExist(Trap.obj) then return end
    local confirmed = Trap.confirmed
    Trap.reset(false)
    if confirmed then
        TriggerServerEvent('legendaryhunt:returnTrap')
    else
        markReturnOnConfirm()
    end
end)
