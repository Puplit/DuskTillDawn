-- pup-ui | ink menu: keyboard-driven list menu with slider rows; takes no NUI focus

local active = nil -- { options, index }

local CONTROLS = {
    up     = `INPUT_FRONTEND_UP`,
    down   = `INPUT_FRONTEND_DOWN`,
    left   = `INPUT_FRONTEND_LEFT`,
    right  = `INPUT_FRONTEND_RIGHT`,
    accept = `INPUT_FRONTEND_ACCEPT`,
    cancel = `INPUT_FRONTEND_CANCEL`,
}

local REPEAT_FIRST = 350 -- ms before a held key starts repeating
local REPEAT_EVERY = 110 -- ms between repeats while held

local function nuiOpen(data)
    SendNUIMessage({ action = 'inkMenu', data = data })
end

local function nuiState(state)
    SendNUIMessage({ action = 'inkMenuState', data = state })
end

local function nuiHide()
    SendNUIMessage({ action = 'inkMenuHide' })
end

local function currentOption()
    return active and active.options[active.index]
end

local function moveCursor(dir)
    local count = #active.options
    if count == 0 then return end
    local index = active.index + dir
    if index < 1 then index = count elseif index > count then index = 1 end
    active.index = index
    nuiState({ index = index })
    TriggerEvent('pup-ui:client:inkMove', index, active.owner)
end

local function scrollValue(dir)
    local opt = currentOption()
    if not opt or not opt.values or #opt.values == 0 then return end
    local vIdx = (opt.valueIndex or 1) + dir
    -- clamp = stop at the ends (vorp_menu sliders) instead of wrapping round
    if opt.clamp and (vIdx < 1 or vIdx > #opt.values) then return end
    if vIdx < 1 then vIdx = #opt.values elseif vIdx > #opt.values then vIdx = 1 end
    opt.valueIndex = vIdx
    nuiState({ index = active.index, valueIndex = vIdx })
    TriggerEvent('pup-ui:client:inkChange', active.index, vIdx, active.owner)
end

local heldSince = {} -- control -> next-fire time

-- read enabled and disabled state, so a caller disabling controls cannot kill navigation
local function justPressed(control)
    return IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control)
end
local function isPressed(control)
    return IsControlPressed(0, control) or IsDisabledControlPressed(0, control)
end

local function pressed(control)
    if justPressed(control) then
        heldSince[control] = GetGameTimer() + REPEAT_FIRST
        return true
    end
    if isPressed(control) then
        local at = heldSince[control]
        if at and GetGameTimer() >= at then
            heldSince[control] = GetGameTimer() + REPEAT_EVERY
            return true
        end
    else
        heldSince[control] = nil
    end
    return false
end

local function inputLoop(session)
    CreateThread(function()
        -- skip the opening frame so a menu rebuilt inside a select/close handler does not see the same keypress
        Wait(0)
        while active == session do
            Wait(0)
            -- a focus-holding panel is up: those keys belong to it
            if PanelActive() then
                heldSince = {}
                Wait(100)
                goto continue
            end
            if pressed(CONTROLS.up) then moveCursor(-1) end
            if pressed(CONTROLS.down) then moveCursor(1) end
            if pressed(CONTROLS.left) then scrollValue(-1) end
            if pressed(CONTROLS.right) then scrollValue(1) end
            if justPressed(CONTROLS.accept) then
                local opt = currentOption()
                if opt then
                    TriggerEvent('pup-ui:client:inkSelect', active.index, opt.values and opt.valueIndex or nil, active.owner)
                end
            end
            if justPressed(CONTROLS.cancel) then
                local owner = active.owner
                UiLog(('inkClose (ESC) owner=%s'):format(tostring(owner)))
                active = nil
                nuiHide()
                -- before the handler, so a reopen from inside it takes the hold back
                HudRelease('ink')
                TriggerEvent('pup-ui:client:inkClose', owner)
                break
            end
            ::continue::
        end
    end)
end

local function openInkMenu(data)
    if type(data) ~= 'table' or type(data.options) ~= 'table' then return end
    UiLog(('OpenInkMenu owner=%s title=%s options=%d'):format(tostring(data.owner), tostring(data.title), #data.options))
    local session = {
        options = data.options,
        owner = data.owner, -- consumers filter the ink events by this token
        index = math.min(math.max(tonumber(data.startIndex) or 1, 1), math.max(#data.options, 1)),
    }
    active = session
    -- heldSince survives across opens on purpose

    local rows = {}
    for i = 1, #session.options do
        local opt = session.options[i]
        rows[i] = {
            label = opt.label or '',
            description = opt.description,
            values = opt.values,
            valueIndex = opt.valueIndex or 1,
            slider = opt.slider,
            noneFirst = opt.noneFirst, -- values[1] is a "None" slot, left out of the counter
            image = opt.image,
        }
    end
    nuiOpen({
        title = data.title or '',
        subtitle = data.subtitle,
        index = session.index,
        options = rows,
        theme = data.theme,
        side = data.side, -- 'right' anchors this menu only, not the player's menu side
        hints = data.hints,
    })
    inputLoop(session)
    HudHold('ink')
end

local function hideInkMenu()
    if active then
        active = nil
        nuiHide()
    end
    HudRelease('ink')
end

exports('OpenInkMenu', openInkMenu)
exports('HideInkMenu', hideInkMenu)

-- /hideui must not leave the input loop alive with the menu invisible
AddEventHandler('pup-ui:HideAllUI', function()
    if not active then return end
    local owner = active.owner
    active = nil
    nuiHide()
    HudDropLatch() -- or the ink holder lingers and blocks a later restore
    TriggerEvent('pup-ui:client:inkClose', owner)
end)
