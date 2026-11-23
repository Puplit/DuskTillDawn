-- pup-ui | placement mode: shared crosshair-follow prop placer

local active = nil -- { owner, prop, model, heading, grounded, zOffset, distance, bounds, title }

-- Arrow keys, not the mouse wheel: the wheel controls are unreliable without NUI focus
local CONTROLS = {
    up     = 0x6319DB71, --[[Arrow Up]]
    down   = 0x05CA7C52, --[[Arrow Down]]
    left   = 0xA65EBAB4, --[[Arrow Left]]
    right  = 0xDEB34313, --[[Arrow Right]]
    shift  = 0x8FFC75D6,
    ground = 0x760A9C6F, --[[G]]
    accept = `INPUT_FRONTEND_ACCEPT`,    -- Enter
    cancel = 0x156F7119, --[[Backspace]]
}

local MIN_DISTANCE, MAX_DISTANCE = 1.0, 12.0 -- metres
local MIN_ZOFF, MAX_ZOFF         = -3.0, 5.0 -- metres

-- CreateObject does not stream models in; it returns 0 for an unloaded model
local function ensureModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 300 do -- ~3s ceiling
        tries = tries + 1
        Wait(10)
    end
    return HasModelLoaded(model)
end

local function drawTxt(text, x, y, scale)
    SetTextScale(scale, scale)
    SetTextColor(255, 255, 255, 255)
    SetTextCentre(true)
    DisplayText(CreateVarString(10, "LITERAL_STRING", text), x, y)
end

-- world point under the crosshair, or a point out in front when nothing is hit
local function aimPoint(distance, ignoreEntity)
    local cam <const>  = GetGameplayCamCoord()
    local rot <const>  = GetGameplayCamRot(2)
    local rx <const>   = rot.x * math.pi / 180.0
    local rz <const>   = rot.z * math.pi / 180.0
    local cosRx <const> = math.abs(math.cos(rx))
    local dir <const>  = vector3(-math.sin(rz) * cosRx, math.cos(rz) * cosRx, math.sin(rx))
    local dest <const> = cam + dir * distance

    local ray <const> = StartShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, -1, ignoreEntity, 0)
    local _, hit, endCoords = GetShapeTestResult(ray)
    if hit == 1 or hit == true then
        return endCoords, true
    end
    return dest, false
end

local function inBounds(pos)
    local b = active and active.bounds
    if not b or not b.radius then return true end
    return #(pos - vector3(b.x + 0.0, b.y + 0.0, b.z + 0.0)) <= (b.radius + 0.0)
end

local function destroyProp()
    if active and active.prop and active.prop ~= 0 and DoesEntityExist(active.prop) then
        DeleteObject(active.prop)
    end
    if active then active.prop = nil end
end

local function finish()
    destroyProp()
    if active and active.model then SetModelAsNoLongerNeeded(active.model) end
    active = nil
end

local function placementThread()
    CreateThread(function()
        while active do
            local a = active
            if not a or not a.prop then break end

            -- 1. follow the crosshair
            local pos, didHit = aimPoint(a.distance, a.prop)
            local z = pos.z + a.zOffset
            if a.grounded and didHit then
                z = pos.z + a.baseOffset
            end
            SetEntityCoordsNoOffset(a.prop, pos.x, pos.y, z, false, false, false)
            SetEntityHeading(a.prop, a.heading % 360.0)

            local ok <const> = inBounds(GetEntityCoords(a.prop))
            SetEntityAlpha(a.prop, ok and 200 or 90, false)

            -- 2. input: held keys, so holding spins/raises smoothly
            local fast <const> = IsControlPressed(0, CONTROLS.shift)

            if IsControlPressed(0, CONTROLS.left) then
                a.heading = a.heading - (fast and 3.0 or 1.0)
            elseif IsControlPressed(0, CONTROLS.right) then
                a.heading = a.heading + (fast and 3.0 or 1.0)
            end

            -- up/down raises/lowers (and breaks ground snap); with SHIFT it changes distance
            if IsControlPressed(0, CONTROLS.up) then
                if fast then
                    a.distance = math.min(MAX_DISTANCE, a.distance + 0.05)
                else
                    a.grounded = false
                    a.zOffset = math.min(MAX_ZOFF, a.zOffset + 0.01)
                end
            elseif IsControlPressed(0, CONTROLS.down) then
                if fast then
                    a.distance = math.max(MIN_DISTANCE, a.distance - 0.05)
                else
                    a.grounded = false
                    a.zOffset = math.max(MIN_ZOFF, a.zOffset - 0.01)
                end
            end

            if IsControlJustPressed(0, CONTROLS.ground) then
                a.grounded = not a.grounded
                if a.grounded then a.zOffset = 0.0 end
            end

            -- 3. hints
            drawTxt(a.title or 'PLACE OBJECT', 0.5, 0.86, 0.5)
            drawTxt('Look to move  ~e~|~q~  LEFT/RIGHT rotate  ~e~|~q~  UP/DOWN height  ~e~|~q~  SHIFT+UP/DOWN distance', 0.5, 0.895, 0.35)
            drawTxt(('G ground snap: %s  ~e~|~q~  ENTER place  ~e~|~q~  BACKSPACE cancel')
                :format(a.grounded and '~t6~ON~q~' or '~e~OFF~q~'), 0.5, 0.925, 0.35)
            if not ok then
                drawTxt('~e~Too far from the plot', 0.5, 0.955, 0.4)
            end

            -- 4. confirm / cancel
            if IsControlJustPressed(0, CONTROLS.cancel) then
                local owner <const> = a.owner
                finish()
                TriggerEvent('pup-ui:client:placeCancel', owner)
                return
            end

            if ok and IsControlJustPressed(0, CONTROLS.accept) then
                local final <const> = GetEntityCoords(a.prop)
                local place <const> = {
                    x = final.x, y = final.y, z = final.z,
                    heading = GetEntityHeading(a.prop),
                    grounded = a.grounded,
                }
                local owner <const> = a.owner
                finish()
                TriggerEvent('pup-ui:client:placeConfirm', owner, place)
                return
            end

            Wait(0)
        end
    end)
end

local function startPlacement(data)
    if type(data) ~= 'table' then return false end
    if active then finish() end -- only one at a time

    local model = data.model
    if type(model) == 'string' then model = joaat(model) end
    if not model then return false end

    if not ensureModel(model) then
        print(('^1[pup-ui]^7 placement: model %s would not stream in'):format(tostring(data.model)))
        return false
    end

    local ped <const> = PlayerPedId()
    local c <const>   = GetEntityCoords(ped)
    local prop = CreateObject(model, c.x, c.y, c.z, false, false, false)
    if prop == 0 or not DoesEntityExist(prop) then
        print(('^1[pup-ui]^7 placement: CreateObject failed for %s'):format(tostring(data.model)))
        return false
    end

    SetEntityCollision(prop, false, false)
    SetEntityAsMissionEntity(prop, true, true)
    FreezeEntityPosition(prop, true)
    SetEntityAlpha(prop, 200, false)

    -- how far the model's lowest point sits below its origin
    local minDim, _ = GetModelDimensions(model)
    local baseOffset = 0.0
    if minDim then baseOffset = -(minDim.z or 0.0) end

    active = {
        owner      = data.owner,
        model      = model,
        prop       = prop,
        heading    = tonumber(data.heading) or 0.0,
        grounded   = data.grounded ~= false,
        zOffset    = 0.0,
        distance   = 3.0,
        baseOffset = baseOffset,
        bounds     = data.bounds,
        title      = data.title,
    }

    UiLog(('StartPlacement owner=%s model=%s'):format(tostring(data.owner), tostring(data.model)))
    placementThread()
    return true
end

-- programmatic close: fires no event
local function cancelPlacement()
    if not active then return end
    finish()
end

local function isPlacing()
    return active ~= nil
end

exports('StartPlacement', startPlacement)
exports('CancelPlacement', cancelPlacement)
exports('IsPlacing', isPlacing)

-- never leave a ghost prop behind on a resource restart
AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then finish() end
end)
