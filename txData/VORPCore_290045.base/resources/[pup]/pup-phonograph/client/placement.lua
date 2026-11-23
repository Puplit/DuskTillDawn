-- Placement mode: a see-through local preview the player nudges into place.
-- Movement follows the camera: "up" moves away from the camera, "right" to its right.

PC = PC or {}
PC.Placing = nil -- { mode, abort, busy }

local K = Config.Keys
local DISABLED <const> = {
    K.forward, K.back, K.left, K.right, K.turnLeft, K.turnRight,
    K.step, K.raise, K.lower, K.cancel, K.confirm, K.openMenu,
}

local function panel(step)
    PC.Call('pup-ui', 'DrawHudPanel', {
        title = Lang.panelTitle,
        rows = {
            Lang.panelMove,
            Lang.panelRotate,
            Lang.panelHeight,
            Lang.panelStepKey,
            '',
            Lang.panelStep:format(step),
            Lang.panelConfirm,
        },
        footer = Lang.panelCancel,
    })
end

-- held keys act once, then repeat after a short delay
local function repeater()
    local nextAt = {}
    return function(key)
        if not IsDisabledControlPressed(0, key) then
            nextAt[key] = nil
            return false
        end
        local now = GetGameTimer()
        if nextAt[key] == nil then
            nextAt[key] = now + Config.Placement.repeatFirstMs
            return true
        end
        if now >= nextAt[key] then
            nextAt[key] = now + Config.Placement.repeatMs
            return true
        end
        return false
    end
end

local function deletePreview(obj)
    if obj and DoesEntityExist(obj) then
        SetEntityAsMissionEntity(obj, true, true)
        DeleteObject(obj)
    end
end

local function run(session)
    if not PC.LoadModel() or session.abort then
        if PC.Placing == session then PC.Placing = nil end
        return
    end
    local ped = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(ped, 0.0, Config.Placement.previewDistance, 0.0)
    -- local only: other players never see the preview, and nothing is left behind on a drop
    local obj = CreateObject(PC.ModelHash, start.x, start.y, start.z, false, false, false)
    session.obj = obj
    PlaceObjectOnGroundProperly(obj)
    SetEntityAlpha(obj, Config.Placement.previewAlpha, false)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)

    local pos = GetEntityCoords(obj)
    local heading = GetEntityHeading(ped)
    SetEntityHeading(obj, heading)
    local step = Config.Placement.startStep
    local held = repeater()
    local result = nil

    while not session.abort do
        Wait(0)
        for _, key in ipairs(DISABLED) do DisableControlAction(0, key, true) end
        panel(step)

        if IsEntityDead(PlayerPedId()) then
            result = 'cancel'
            break
        end

        if not session.busy then
            local camH = math.rad(GetGameplayCamRot(2).z)
            local fx, fy = -math.sin(camH), math.cos(camH)
            local rx, ry = math.cos(camH), math.sin(camH)
            local moved = false

            if held(K.forward) then pos = pos + vector3(fx * step, fy * step, 0.0); moved = true end
            if held(K.back) then pos = pos - vector3(fx * step, fy * step, 0.0); moved = true end
            if held(K.right) then pos = pos + vector3(rx * step, ry * step, 0.0); moved = true end
            if held(K.left) then pos = pos - vector3(rx * step, ry * step, 0.0); moved = true end
            if held(K.raise) then pos = pos + vector3(0.0, 0.0, step); moved = true end
            if held(K.lower) then pos = pos - vector3(0.0, 0.0, step); moved = true end
            if held(K.turnLeft) then heading = (heading + Config.Placement.turnDegrees) % 360.0; moved = true end
            if held(K.turnRight) then heading = (heading - Config.Placement.turnDegrees) % 360.0; moved = true end

            if moved then
                SetEntityCoordsNoOffset(obj, pos.x, pos.y, pos.z, false, false, false)
                SetEntityHeading(obj, heading)
            end

            if IsDisabledControlJustPressed(0, K.step) then
                session.busy = true
                CreateThread(function()
                    local v = PC.AskValue({
                        title = Lang.stepTitle,
                        subtitle = Lang.stepHint,
                        label = Lang.stepLabel,
                        type = 'number',
                        placeholder = Lang.stepPlaceholder,
                    })
                    local n = tonumber(v)
                    if n and n > 0 then
                        step = PC.Clamp(n, Config.Placement.minStep, Config.Placement.maxStep)
                    end
                    session.busy = false
                end)
            elseif IsDisabledControlJustPressed(0, K.confirm) then
                result = 'confirm'
                break
            elseif IsDisabledControlJustPressed(0, K.cancel) then
                result = 'cancel'
                break
            end
        end
    end

    local final = GetEntityCoords(obj)
    local finalHeading = GetEntityHeading(obj)
    deletePreview(obj)
    session.obj = nil
    SetModelAsNoLongerNeeded(PC.ModelHash)

    local function release()
        if PC.Placing == session then PC.Placing = nil end
    end

    if session.abort or result ~= 'confirm' then
        release()
        if result == 'cancel' then PC.Tip(Lang.placementCancelled, 2000) end
        return
    end

    Wait(Config.Placement.confirmDelayMs)
    release()
    if session.abort then return end
    local posT = { x = final.x, y = final.y, z = final.z }
    local rotT = { x = 0.0, y = 0.0, z = finalHeading }
    if session.mode == 'staff' then
        PC.OpenStaffSetup(posT, rotT)
    else
        TriggerServerEvent('pup-phonograph:server:savePlayer', posT, rotT)
    end
end

function PC.StartPlacement(mode)
    if PC.Placing then return end
    local session = { mode = mode, abort = false, busy = false }
    PC.Placing = session
    PC.CloseMenus()
    CreateThread(function() run(session) end)
end

function PC.AbortPlacement()
    local s = PC.Placing
    if not s then return end
    s.abort = true
    deletePreview(s.obj)
    PC.Placing = nil
end

RegisterNetEvent('pup-phonograph:client:startPlacement', function(mode)
    if mode ~= 'player' and mode ~= 'staff' then return end
    PC.StartPlacement(mode)
end)
