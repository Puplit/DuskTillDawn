-- pup-magic | the vampire's side of feeding: the Feed prompt, lining up, and the feed itself
-- The client only feeds while the server has told it the curse is 'vamp'.

local F <const> = Config.Feeding
local A <const> = Config.Integrations.animations

local POSE_DICT <const> = 'script_special_ped@pdsdv_vampire@ig@ig1_confront'
local POSE_CLIP <const> = 'stay_back_l_corpse'
local SCARE_EVENT <const> = 0x2107E573

local curse = nil      -- what the server last sent
local feeding = false
local lastFeedAt = nil -- GetGameTimer() when the last feed started

local prompt, promptGroup = nil, nil

local function removePrompt()
    if prompt then UiPromptDelete(prompt) end
    prompt, promptGroup = nil, nil
end

local function buildPrompt(group)
    removePrompt()
    local p = UiPromptRegisterBegin()
    UiPromptSetControlAction(p, Config.Keys.feed)
    UiPromptSetText(p, CreateVarString(10, 'LITERAL_STRING', Locale.feedPrompt))
    UiPromptSetEnabled(p, true)
    UiPromptSetVisible(p, true)
    UiPromptSetHoldMode(p, F.holdMs)
    UiPromptSetGroup(p, group, 0)
    UiPromptRegisterEnd(p)
    prompt, promptGroup = p, group
end

RegisterNetEvent('pup-magic:curse', function(key)
    curse = (type(key) == 'string') and key or ''
    if curse ~= 'vamp' then removePrompt() end
    Dbg('curse is "%s"', curse)
end)

-- ask until the server answers: every 2 s, at most 10 times
CreateThread(function()
    for _ = 1, 10 do
        if curse ~= nil then return end
        TriggerServerEvent('pup-magic:askCurse')
        Wait(2000)
    end
end)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

-- move `me` next to `target`: a little behind, to its left, a little lower. Returns the heading for the target.
local function lineUp(me, target)
    local tp = GetEntityCoords(target)
    local fwd = GetEntityForwardVector(target)
    local right = vector3(fwd.y, -fwd.x, 0.0)
    local spot = vector3(tp.x - fwd.x * 0.10 - right.x * 0.30, tp.y - fwd.y * 0.10 - right.y * 0.30, tp.z - 0.30)
    SetEntityCoordsNoOffset(me, spot.x, spot.y, spot.z, false, false, false)
    SetEntityHeading(me, HeadingTo(spot, tp))
    return HeadingTo(tp, spot)
end

local function holster(ped)
    pcall(function() SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true) end)
end

local function scare(victim)
    local me = PlayerPedId()
    local pos = GetEntityCoords(me)
    pcall(function() AddShockingEventAtPosition(SCARE_EVENT, pos.x, pos.y, pos.z, 0.5) end)
    local radius = tonumber(F.scareRadius) or 0
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= victim and ped ~= me and not IsPedAPlayer(ped) and IsPedHuman(ped) and not IsEntityDead(ped)
            and #(GetEntityCoords(ped) - pos) <= radius then
            NetworkRequestControlOfEntity(ped)
            ClearPedTasksImmediately(ped)
            TaskSmartFleeCoord(ped, pos.x, pos.y, pos.z, 150.0, F.scareDurationMs, 0, 3.0)
            SetPedKeepTask(ped, true)
        end
    end
end

---------------------------------------------------------------------------
-- feeding on an NPC
---------------------------------------------------------------------------
local function feedNpc(npc)
    feeding = true
    CreateThread(function()
        local me = PlayerPedId()
        for _ = 1, 50 do
            if NetworkHasControlOfEntity(npc) then break end
            NetworkRequestControlOfEntity(npc)
            Wait(10)
        end
        if not NetworkGetEntityIsNetworked(npc) then pcall(NetworkRegisterEntityAsNetworked, npc) end
        local netId = NetworkGetEntityIsNetworked(npc) and NetworkGetNetworkIdFromEntity(npc) or 0

        scare(npc)
        FreezeEntityPosition(me, true)
        FreezeEntityPosition(npc, true)
        SetEntityHeading(npc, lineUp(me, npc))
        ClearPedTasksImmediately(me)
        ClearPedTasksImmediately(npc)
        holster(me)

        if not LoadAnimDict(POSE_DICT, 6000) then
            FreezeEntityPosition(me, false)
            if DoesEntityExist(npc) then FreezeEntityPosition(npc, false) end
            feeding = false
            return
        end

        TriggerServerEvent('pup-magic:feedNpc', netId)
        TaskPlayAnim(npc, POSE_DICT, POSE_CLIP, 1.0, 1.0, -1, 17, 1.0, false, false, false, '', false)
        Wait(200)
        StartVorpAnim(A.feed)
        Wait(math.max(0, F.feedMs - 200))

        EndVorpAnim(A.feed)
        ClearPedTasks(me)
        FreezeEntityPosition(me, false)
        TriggerServerEvent('pup-magic:feedDone', 'npc')
        feeding = false

        Wait(F.victimExtraMs)
        if not DoesEntityExist(npc) then return end
        ClearPedTasks(npc)
        FreezeEntityPosition(npc, false)
        SetDrunk(npc, true, 0.95)
        TaskWanderStandard(npc, 10.0, 10)
        Wait(F.drunkMs)
        if DoesEntityExist(npc) then
            SetDrunk(npc, false, 0.0)
            ClearPedTasks(npc)
        end
    end)
end

---------------------------------------------------------------------------
-- feeding on a player
---------------------------------------------------------------------------
local function feedPlayer(victimPed)
    local sid = ServerIdOfPed(victimPed)
    if not sid then return end
    feeding = true
    CreateThread(function()
        local me = PlayerPedId()
        scare(victimPed)
        FreezeEntityPosition(me, true)
        local victimHeading = lineUp(me, victimPed)
        ClearPedTasksImmediately(me)
        holster(me)
        StartVorpAnim(A.feed)
        TriggerServerEvent('pup-magic:putDown', sid, F.feedMs + F.victimExtraMs, victimHeading)

        Wait(F.feedMs)
        EndVorpAnim(A.feed)
        ClearPedTasks(me)
        FreezeEntityPosition(me, false)
        TriggerServerEvent('pup-magic:feedDone', 'player', sid)
        feeding = false
    end)
end

local function tryFeed(target)
    if feeding then return end
    local now = GetGameTimer()
    if lastFeedAt and now - lastFeedAt < F.cooldownMs then
        TipBottom(Locale.tooFull:format(math.ceil((F.cooldownMs - (now - lastFeedAt)) / 1000)), 3000)
        -- a completed hold stays completed while the key is down: rebuild the prompt so the tip shows once per hold
        removePrompt()
        return
    end
    lastFeedAt = now
    removePrompt()
    if IsPedAPlayer(target) then feedPlayer(target) else feedNpc(target) end
end

---------------------------------------------------------------------------
-- the prompt loop
---------------------------------------------------------------------------
local function focusedHuman(me)
    local ok, focusing = pcall(function() return Citizen.InvokeNative(0x4605C66E0F935F83, PlayerId()) end)
    if not ok or not (focusing == true or focusing == 1) then return nil end
    local found, ent = GetPlayerTargetEntity(PlayerId())
    if not found or not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if not IsEntityAPed(ent) or not IsPedHuman(ent) or IsEntityDead(ent) then return nil end
    if #(GetEntityCoords(ent) - GetEntityCoords(me)) > F.radius then return nil end
    return ent
end

CreateThread(function()
    while true do
        if curse ~= 'vamp' then
            removePrompt()
            Wait(1000)
        else
            local me = PlayerPedId()
            local target = (not feeding) and focusedHuman(me) or nil
            if target then
                local group = Citizen.InvokeNative(0xB796970BD125FCE8, target, Citizen.ResultAsInteger())
                if group and group ~= 0 then
                    if group ~= promptGroup then buildPrompt(group) end
                    if UiPromptHasHoldModeCompleted(prompt) then tryFeed(target) end
                else
                    removePrompt()
                end
                Wait(0)
            else
                removePrompt()
                Wait(100)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removePrompt()
    if feeding then
        FreezeEntityPosition(PlayerPedId(), false)
        EndVorpAnim(A.feed)
    end
end)
