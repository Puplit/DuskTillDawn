-- pup_mercantile | opening a shop with a licence, and the paid shop move

local L = Util.L
local CREATE_OWNER <const> = 'pup_mercantile:create'
local WRITE_MS <const> = 10000

local function tip(text, ms) TriggerEvent('vorp:TipBottom', text, ms or 4000) end

local function myPos()
    return GetEntityCoords(PlayerPedId())
end

------------------------------------------------------------------------------
-- creation: name, ten seconds of paperwork, then the server decides
------------------------------------------------------------------------------
local creation = nil -- { kind, job }

RegisterNetEvent('pup_mercantile:create:begin', function(kind, job)
    if kind ~= 'player' and kind ~= 'society' then return end
    if St.inStore or St.moveMode or St.creating or creation then
        return TriggerServerEvent('pup_mercantile:create:cancel')
    end
    -- early warning only; the server re-checks spacing against shops of both kinds
    if NearOtherShop(myPos()) then
        tip(L('tooClose'))
        return TriggerServerEvent('pup_mercantile:create:cancel')
    end
    creation = { kind = kind, job = job }
    local ok = exports['pup-ui']:OpenInput({
        owner = CREATE_OWNER,
        title = L('inConfirm'),
        submit = L('inConfirm'),
        fields = { { label = L('inShopName'), type = 'text', required = true, maxlength = 50 } },
    })
    if ok == false then
        creation = nil
        TriggerServerEvent('pup_mercantile:create:cancel')
    end
end)

local function writeOut(c, name)
    St.creating = true
    local ped = PlayerPedId()
    -- TASK_START_SCENARIO_IN_PLACE_HASH
    Citizen.InvokeNative(0x524B54361229154F, ped, joaat('WORLD_HUMAN_WRITE_NOTEBOOK'), WRITE_MS, true, false, false, false)
    local untilAt = GetGameTimer() + WRITE_MS
    local aborted = false
    while GetGameTimer() < untilAt do
        Wait(250)
        ped = PlayerPedId()
        if IsEntityDead(ped) or IsPedOnMount(ped) then aborted = true break end
    end
    ClearPedTasks(ped)
    St.creating = false
    if aborted then return TriggerServerEvent('pup_mercantile:create:cancel') end
    local p = GetEntityCoords(ped)
    TriggerServerEvent('pup_mercantile:create:finish', c.kind, name, { x = p.x, y = p.y, z = p.z }, c.job)
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= CREATE_OWNER then return end
    local c = creation
    creation = nil
    if not c then return end
    if type(values) ~= 'table' then return TriggerServerEvent('pup_mercantile:create:cancel') end
    local name = Util.cleanName(values[1])
    if not name then
        tip(L('clientBadName'))
        return TriggerServerEvent('pup_mercantile:create:cancel')
    end
    CreateThread(function() writeOut(c, name) end)
end)

------------------------------------------------------------------------------
-- paid move: walk to the new spot and confirm with the move command
------------------------------------------------------------------------------
local moveCmd = Config.Commands.move

function StopMoveMode()
    St.moveMode = false
    St.moving = nil
    pcall(function() exports['pup-ui']:PromptHide() end)
end

RegisterNetEvent('pup_mercantile:move:approved', function(kind, id)
    local v = St.venue
    if not v or v.kind ~= kind or v.id ~= id then return end
    -- the player walks: unfreeze, but keep the visit (the server holds it in move mode)
    FreezeEntityPosition(PlayerPedId(), false)
    ClearPedTasks(PlayerPedId())
    TriggerEvent('inv:dropstatus', true)
    St.inStore = false
    St.moveMode = true
    St.moving = { kind = kind, id = id }
    local hint = L('moveHint', moveCmd, moveCmd)
    tip(hint, 10000)
    CreateThread(function()
        while St.moveMode do
            pcall(function() exports['pup-ui']:Prompt({ key = '/' .. moveCmd, label = hint, ttl = 2000 }) end)
            Wait(1000)
        end
    end)
end)

-- the server refused the spot but kept the move open
RegisterNetEvent('pup_mercantile:move:retry', function()
    if St.moveMode then tip(L('moveTooClose', moveCmd), 6000) end
end)

RegisterCommand(moveCmd, function(_, args)
    if not St.moveMode or not St.moving then return end
    if args[1] and tostring(args[1]):lower() == 'cancel' then
        TriggerServerEvent('pup_mercantile:move:cancel')
        StopMoveMode()
        St.venue = nil
        return
    end
    local pos = myPos()
    if NearOtherShop(pos, St.moving.kind, St.moving.id) then
        return tip(L('moveTooClose', moveCmd), 6000)
    end
    TriggerServerEvent('pup_mercantile:move:confirm', { x = pos.x, y = pos.y, z = pos.z })
end, false)

-- leaving through any other path ends the move too
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and St.moveMode then StopMoveMode() end
end)

-- a character switch drops a half-finished licence
RegisterNetEvent('vorp:SelectedCharacter', function()
    if creation then
        creation = nil
        TriggerServerEvent('pup_mercantile:create:cancel')
    end
end)
