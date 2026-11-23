-- skinanimals | client/main.lua
-- Watches the game's loot-complete event, works out which row of the animal table the
-- carcass is, and asks the server for the payout. The server decides what is paid.

local LOOT_COMPLETE <const> = SkinUtil.u32(`EVENT_LOOT_COMPLETE`)
local NATIVE_EVENT_DATA <const> = 0x57EC5FA4D4D6AFCA
local NATIVE_META_OUTFIT <const> = 0x30569F348D126A5A
local NATIVE_CARRIED <const> = 0xD806CD2A4F2C2996
local NATIVE_MERCY_KILL <const> = 0x39363DFD04E91496
local PED_TYPE_ANIMAL <const> = 28

local recent = {}          -- [entity] = GetGameTimer() of our last claim for it
local pending = {}         -- [netId or 'e'..entity] = { ent = ..., at = ... } carcasses to delete

------------------------------------------------------------------------------- event data
-- The loot-complete event carries three 32-bit fields, each in an 8-byte slot.
-- The buffer is longer than 40 bytes so Lua never shares (interns) it.
local function readLootEvent(index)
    local buf = string.rep('\0', 64)
    Citizen.InvokeNative(NATIVE_EVENT_DATA, 0, index, buf, 3)
    local looter = string.unpack('<i4', buf, 1)
    local looted = string.unpack('<i4', buf, 9)
    local success = string.unpack('<i4', buf, 17)
    return looter, looted, success
end

------------------------------------------------------------------------------- clean-up
local function deleteIfOwned(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if NetworkGetEntityIsNetworked(ent) and not NetworkHasControlOfEntity(ent) then
        NetworkRequestControlOfEntity(ent)
        local untilAt = GetGameTimer() + 1000
        while not NetworkHasControlOfEntity(ent) and GetGameTimer() < untilAt do
            Wait(50)
        end
        if not DoesEntityExist(ent) or not NetworkHasControlOfEntity(ent) then return end
    end
    SetEntityAsMissionEntity(ent, true, true)
    DeleteEntity(ent)
end

local function deleteCarriedPelt()
    local ped = PlayerPedId()
    local carried = Citizen.InvokeNative(NATIVE_CARRIED, ped, Citizen.ResultAsInteger())
    if not carried or carried == 0 or not DoesEntityExist(carried) then return end
    -- only an object (the pelt); never a carried ped or anything else
    if GetEntityType(carried) ~= 3 then return end
    deleteIfOwned(carried)
end

local function pendingKey(netId, ent)
    return netId ~= 0 and netId or ('e' .. ent)
end

------------------------------------------------------------------------------- claim
local function onLooted(ent)
    if not DoesEntityExist(ent) or GetPedType(ent) ~= PED_TYPE_ANIMAL then return end

    local now = GetGameTimer()
    if recent[ent] and now - recent[ent] < 5000 then return end

    local model = GetEntityModel(ent)
    local outfit = Citizen.InvokeNative(NATIVE_META_OUTFIT, ent, Citizen.ResultAsInteger())
    local rowIndex = SkinUtil.findRow(model, outfit)
    if not rowIndex then return end

    recent[ent] = now
    local netId = 0
    if NetworkGetEntityIsNetworked(ent) then netId = NetworkGetNetworkIdFromEntity(ent) or 0 end

    TriggerServerEvent('skinanimals:claim', rowIndex, netId)

    if Config.Skinning.deleteCarcass then
        local key = pendingKey(netId, ent)
        pending[key] = { ent = ent, at = now }
        -- fallback when the server never answers
        SetTimeout(3000, function()
            local p = pending[key]
            if p and p.ent == ent then
                pending[key] = nil
                deleteIfOwned(ent)
            end
        end)
    end

    if Config.Skinning.deletePelt then
        SetTimeout(Config.Skinning.peltDelayMs or 1000, deleteCarriedPelt)
    end
end

-- The server answered a claim: the carcass may go now (only if deletion is on).
RegisterNetEvent('skinanimals:claimDone', function(netId)
    netId = tonumber(netId)
    if not netId or not Config.Skinning.deleteCarcass then return end
    local p
    if netId ~= 0 then
        p = pending[netId]
        pending[netId] = nil
    else
        -- an unnetworked carcass: take the oldest one waiting
        local bestKey, best
        for k, v in pairs(pending) do
            if type(k) == 'string' and (not best or v.at < best.at) then bestKey, best = k, v end
        end
        if bestKey then pending[bestKey] = nil end
        p = best
    end
    if p then CreateThread(function() deleteIfOwned(p.ent) end) end
end)

------------------------------------------------------------------------------- event watch
-- The AI event queue only holds this frame's events, so it has to be read every frame.
-- While no character is in the session the loop sleeps.
CreateThread(function()
    while true do
        if not LocalPlayer.state.IsInSession then
            Wait(1000)
        else
            Wait(0)
            local count = GetNumberOfEvents(0)
            if count > 0 then
                local me = PlayerPedId()
                for i = 0, count - 1 do
                    if SkinUtil.u32(GetEventAtIndex(0, i)) == LOOT_COMPLETE then
                        local looter, looted, success = readLootEvent(i)
                        if looter == me and success == 1 and looted and looted ~= 0 then
                            onLooted(looted)
                        end
                    end
                end
            end
        end
    end
end)

-- forget old per-entity claim times
CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        for ent, at in pairs(recent) do
            if now - at > 10000 then recent[ent] = nil end
        end
    end
end)

------------------------------------------------------------------------------- messages
RegisterNetEvent('skinanimals:notify', function(text, duration, title, kind)
    if type(text) ~= 'string' or text == '' then return end
    duration = tonumber(duration) or 5000
    if Config.Messages.style == 'left' then
        local colour = kind == 'error' and 'COLOR_RED' or 'COLOR_WHITE'
        TriggerEvent('vorp:NotifyLeft', tostring(title or Locale.title), text, 'generic_textures', 'tick', duration, colour)
    else
        TriggerEvent('vorp:TipRight', text, duration)
    end
end)

------------------------------------------------------------------------------- mercy kill
local function applyMercyKill()
    if not Config.MercyKill.enabled then return end
    Citizen.InvokeNative(NATIVE_MERCY_KILL, PlayerId(), true)
end

CreateThread(function()
    Wait(Config.MercyKill.startDelayMs or 1000)
    applyMercyKill()
end)

RegisterNetEvent('vorp:SelectedCharacter', function()
    SetTimeout(Config.MercyKill.selectDelayMs or 2000, applyMercyKill)
end)

------------------------------------------------------------------------------- stop
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    recent, pending = {}, {}
end)
