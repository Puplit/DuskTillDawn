-- pup-ui | price picker: bottom-centred value chooser driven by left/right

local active = nil -- { owner, steps, notch }

local CONTROLS = {
    left   = `INPUT_FRONTEND_LEFT`,
    right  = `INPUT_FRONTEND_RIGHT`,
    accept = `INPUT_FRONTEND_ACCEPT`,
    cancel = 0x156F7119, -- BACKSPACE: ESC belongs to the pause menu
}

local REPEAT_FIRST = 350 -- ms
local REPEAT_EVERY = 90 -- ms

local held = {}

local function justPressed(c)
    return IsControlJustPressed(0, c) or IsDisabledControlJustPressed(0, c)
end
local function isPressed(c)
    return IsControlPressed(0, c) or IsDisabledControlPressed(0, c)
end

-- tap moves one notch; holding repeats
local function pressed(c)
    if justPressed(c) then
        held[c] = GetGameTimer() + REPEAT_FIRST
        return true
    end
    if isPressed(c) then
        local at = held[c]
        if at and GetGameTimer() >= at then
            held[c] = GetGameTimer() + REPEAT_EVERY
            return true
        end
    else
        held[c] = nil
    end
    return false
end

local function move(dir)
    local n = active.notch + dir
    if n < 0 then n = 0 elseif n > active.steps then n = active.steps end
    if n == active.notch then return end
    active.notch = n
    SendNUIMessage({ action = 'pricePickerState', data = { notch = n } })
    TriggerEvent('pup-ui:client:priceChange', n, active.owner)
end

local function close()
    active = nil
    held = {}
    SendNUIMessage({ action = 'pricePickerHide' })
end

local function inputLoop(session)
    CreateThread(function()
        -- skip the opening frame so the keypress that opened this picker is not read again as a confirm
        Wait(0)
        while active == session do
            Wait(0)
            if PanelActive() then
                held = {}
                Wait(100)
                goto continue
            end
            if pressed(CONTROLS.left) then move(-1) end
            if pressed(CONTROLS.right) then move(1) end
            if justPressed(CONTROLS.accept) then
                local owner, notch = active.owner, active.notch
                close()
                TriggerEvent('pup-ui:client:priceConfirm', notch, owner)
                break
            end
            if justPressed(CONTROLS.cancel) then
                local owner = active.owner
                close()
                TriggerEvent('pup-ui:client:priceCancel', owner)
                break
            end
            ::continue::
        end
    end)
end

local function openPricePicker(data)
    if type(data) ~= 'table' then return end
    local steps = math.max(1, math.floor(tonumber(data.steps) or 12))
    local notch = math.floor(tonumber(data.notch) or math.floor(steps / 2))
    if notch < 0 then notch = 0 elseif notch > steps then notch = steps end

    UiLog(('OpenPricePicker owner=%s min=%s max=%s steps=%d'):format(
        tostring(data.owner), tostring(data.min), tostring(data.max), steps))

    local session = { owner = data.owner, steps = steps, notch = notch }
    active = session
    SendNUIMessage({ action = 'pricePicker', data = {
        caption = data.caption, title = data.title,
        min = tonumber(data.min) or 0, max = tonumber(data.max) or 0,
        steps = steps, notch = notch,
        prefix = data.prefix, foot = data.foot,
    } })
    inputLoop(session)
end

local function hidePricePicker()
    if active then close() end
end

exports('OpenPricePicker', openPricePicker)
exports('HidePricePicker', hidePricePicker)

-- /hideui must not leave the picker's input loop alive with nothing on screen
AddEventHandler('pup-ui:HideAllUI', function()
    if not active then return end
    local owner = active.owner
    close()
    TriggerEvent('pup-ui:client:priceCancel', owner)
end)
