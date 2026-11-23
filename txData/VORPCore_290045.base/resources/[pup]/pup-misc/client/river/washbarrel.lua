-- wash barrel | client: a face-wash prompt at water troughs and barrels. Clears dirt,
-- blood and wetness, stops the drunk / drug screen effects listed in the config, turns
-- drunkenness off and fires pup_camps:washedface. Needs WaterClient from main.lua.

local CFG <const> = WaterConfig
local B <const> = CFG.Barrel
local L <const> = WaterLocale
local W <const> = WaterClient

-- unique model hashes
local models = {}
do
    local seen = {}
    for _, m in ipairs(B.models or {}) do
        local h = type(m) == 'number' and m or GetHashKey(m)
        if not seen[h] then
            seen[h] = true
            models[#models + 1] = h
        end
    end
end

local function nearestBarrel(ped)
    local c = GetEntityCoords(ped)
    local best, bestDist = nil, nil
    for _, h in ipairs(models) do
        local obj = GetClosestObjectOfType(c.x, c.y, c.z, B.radius, h, false, false, false)
        if obj ~= 0 then
            local d = #(GetEntityCoords(obj) - c)
            if not bestDist or d < bestDist then best, bestDist = obj, d end
        end
    end
    return best
end

local function stopEffects()
    for _, fx in ipairs(B.effects or {}) do
        if AnimpostfxIsRunning(fx) then AnimpostfxStop(fx) end
    end
end

local function washFace(obj)
    local ped = PlayerPedId()
    if obj and DoesEntityExist(obj) then
        TaskTurnPedToFaceEntity(ped, obj, B.turnMs)
        Wait(B.turnMs + B.afterTurnMs)
    end
    Citizen.InvokeNative(0xFCCC886EDE3C63EC, ped, false, true)

    local a = IsPedMale(ped) and CFG.Anims.barrelMale or CFG.Anims.barrelFemale
    if W.loadDict(a.dict) then
        TaskPlayAnim(ped, a.dict, a.clip, 1.0, 1.0, -1, 0, 0, false, false, false, '', false)
        RemoveAnimDict(a.dict)
    end
    Wait(B.cleanDelayMs)

    ped = PlayerPedId()
    W.cleanPed(ped)
    stopEffects()
    Citizen.InvokeNative(0x406CCF555B04FAD3, ped, false, 0.0)
    W.washed()
end

local GROUP <const> = GetRandomIntInRange(0, 0xffffff)
local washPrompt

CreateThread(function()
    washPrompt = PromptRegisterBegin()
    PromptSetControlAction(washPrompt, CFG.Keys.barrelWash)
    PromptSetText(washPrompt, CreateVarString(10, 'LITERAL_STRING', L.washFace))
    PromptSetEnabled(washPrompt, 1)
    PromptSetVisible(washPrompt, 1)
    PromptSetHoldMode(washPrompt, CFG.Prompts.holdMs or 800)
    PromptSetGroup(washPrompt, GROUP)
    PromptRegisterEnd(washPrompt)
    local label = CreateVarString(10, 'LITERAL_STRING', L.groupBarrel)

    while true do
        local ped = PlayerPedId()
        local obj = nil
        if not W.busy and W.onFoot(ped) and not W.dead(ped) then
            obj = nearestBarrel(ped)
        end
        W.nearBarrel = obj ~= nil

        if not obj then
            Wait(B.scanMs)
        else
            -- draw the prompt every frame until the next scan
            local until_ = GetGameTimer() + B.scanMs
            while GetGameTimer() < until_ and not W.busy do
                if W.modifierOk() then PromptSetActiveGroupThisFrame(GROUP, label) end
                if W.modifierOk() and PromptHasHoldModeCompleted(washPrompt) then
                    W.busy = true
                    washFace(obj)
                    W.busy = false
                    break
                end
                Wait(0)
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if washPrompt then PromptDelete(washPrompt) end
end)
