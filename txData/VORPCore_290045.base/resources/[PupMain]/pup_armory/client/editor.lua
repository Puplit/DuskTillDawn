-- pup_armory | position editor (/wp)

local K <const> = Config.Keys
local OWNER <const> = 'pup_armory:edit'
local STEPS <const> = {
    { name = Locale.stepFine,   move = 0.002, turn = 0.5 },
    { name = Locale.stepNormal, move = 0.01,  turn = 2.0 },
    { name = Locale.stepCoarse, move = 0.05,  turn = 10.0 },
}
local picking = nil      -- the ink menu currently open: { kind, choices, onClose }
local editing = false
local awaitingChoice = false   -- staff picking where a fitted position goes
local openPicker, askSaveTarget

local function tip(msg) TriggerEvent('vorp:TipRight', msg, 4000) end
local function copy(t) return { t[1], t[2], t[3], t[4], t[5], t[6] } end

local function myState() return LocalPlayer.state.pup_armory end

local function current(state, def, slot)
    local saved = state.pos and state.pos[def.item] and state.pos[def.item][slot]
    return copy(saved or Armory.default(def, slot))
end

local function slotLabel(def, slot)
    if slot == 'hand' then return Locale.spotHand end
    return def.kind == 'shield' and Locale.spotWornShield or Locale.spotWorn
end

local function text(str, x, y, scale, r, g, b)
    SetTextScale(scale, scale)
    SetTextColor(r or 240, g or 230, b or 210, 255)
    SetTextCentre(true)
    SetTextDropshadow(2, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', str), x, y)
end

-- the live editing loop: keys nudge ArmoryPreview.off, which main.lua re-hangs each tick
local function edit(def, slot)
    local state = myState()
    if not state then return end
    local start = current(state, def, slot)
    ArmoryPreview = { item = def.item, slot = slot, off = copy(start) }
    editing = true
    local step, nextRepeat = 2, 0

    CreateThread(function()
        while editing do
            Wait(0)
            for _, c in pairs(K) do DisableControlAction(0, c, true) end
            local o = ArmoryPreview.off
            local s = STEPS[step]
            local turning = IsDisabledControlPressed(0, K.rotate)
            local now = GetGameTimer()

            -- held keys repeat, so a long press keeps moving
            local function held(c) return IsDisabledControlJustPressed(0, c) or (IsDisabledControlPressed(0, c) and now >= nextRepeat) end
            local moved = false
            local function nudge(i, d) o[i] = o[i] + d moved = true end
            if held(K.up)    then if turning then nudge(4,  s.turn) else nudge(2,  s.move) end end
            if held(K.down)  then if turning then nudge(4, -s.turn) else nudge(2, -s.move) end end
            if held(K.right) then if turning then nudge(5,  s.turn) else nudge(1,  s.move) end end
            if held(K.left)  then if turning then nudge(5, -s.turn) else nudge(1, -s.move) end end
            if held(K.raise) then if turning then nudge(6,  s.turn) else nudge(3,  s.move) end end
            if held(K.lower) then if turning then nudge(6, -s.turn) else nudge(3, -s.move) end end
            if moved then nextRepeat = now + 90 end

            if IsDisabledControlJustPressed(0, K.step) then step = step % #STEPS + 1 end
            if IsDisabledControlJustPressed(0, K.reset) then ArmoryPreview.off = copy(Armory.default(def, slot)) end

            if IsDisabledControlJustPressed(0, K.save) then
                editing = false
                if not Armory.validOffset(o) then
                    tip(Locale.tooFar)
                elseif LocalPlayer.state.pup_armory_staff then
                    -- staff choose: just their character, or everyone's default
                    awaitingChoice = true
                    local off = copy(o)
                    SetTimeout(0, function() askSaveTarget(def, slot, off) end)
                else
                    TriggerServerEvent('pup_armory:saveSpot', def.item, slot, o)
                end
            elseif IsDisabledControlJustPressed(0, K.cancel) then
                tip(Locale.cancelled)
                editing = false
            end

            text(Locale.panelTitle:format(def.label, slotLabel(def, slot)), 0.5, 0.80, 0.42)
            text(('x %.3f  y %.3f  z %.3f   |   %.1f  %.1f  %.1f'):format(o[1], o[2], o[3], o[4], o[5], o[6]), 0.5, 0.835, 0.33, 210, 180, 110)
            text(Locale.panelMove, 0.5, 0.865, 0.3)
            text(Locale.panelStep:format(s.name) .. '     ' .. Locale.panelKeys, 0.5, 0.89, 0.3)
        end
        -- the saved position arrives through the state bag; until then keep showing it
        if awaitingChoice then return end
        Wait(500)
        ArmoryPreview = nil
    end)
end

function askSaveTarget(def, slot, off)
    local function done(event)
        awaitingChoice = false
        if event then TriggerServerEvent(event, def.item, slot, off) else tip(Locale.cancelled) end
        SetTimeout(500, function() ArmoryPreview = nil end)
    end
    openPicker('save', Locale.editTitle, Locale.saveWhere, {
        { label = Locale.saveForMe,     desc = Locale.saveForMeDesc,     run = function() done('pup_armory:saveSpot') end },
        { label = Locale.saveForServer, desc = Locale.saveForServerDesc, run = function() done('pup_armory:saveDefault') end },
    }, function() done(nil) end)
end

-- pickers ---------------------------------------------------------------------
function openPicker(kind, title, subtitle, choices, onClose)
    picking = { kind = kind, choices = choices, onClose = onClose }
    local rows = {}
    for i, c in ipairs(choices) do rows[i] = { label = c.label, description = c.desc } end
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = title, subtitle = subtitle, options = rows })
end

local function pickSpot(def)
    local choices = {}
    local staff = LocalPlayer.state.pup_armory_staff
    for _, slot in ipairs(def.slots) do
        if staff or not Armory.handLocked(slot) then
            choices[#choices + 1] = { label = slotLabel(def, slot), run = function() edit(def, slot) end }
        end
    end
    choices[#choices + 1] = { label = Locale.resetAll, desc = Locale.resetAllDesc,
        run = function() TriggerServerEvent('pup_armory:resetItem', def.item) end }
    if LocalPlayer.state.pup_armory_staff then
        choices[#choices + 1] = { label = Locale.resetServer, desc = Locale.resetServerDesc,
            run = function() TriggerServerEvent('pup_armory:resetDefault', def.item) end }
    end
    openPicker('spot', Locale.editTitle, def.label .. ' - ' .. Locale.editPickSpot, choices)
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not picking then return end
    local c = picking.choices[index]
    picking = nil
    exports['pup-ui']:HideInkMenu()
    if c then c.run() end
end)
AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER or not picking then return end
    local onClose = picking.onClose
    picking = nil
    if onClose then onClose() end
end)

RegisterCommand(Config.General.editCommand, function()
    if editing then return end
    local state = myState()
    local carried = {}
    for _, item in ipairs({ state and state.hand, state and state.shield }) do
        local def = item and Armory.get(item)
        if def then carried[#carried + 1] = def end
    end
    if #carried == 0 then return tip(Locale.editNothing) end
    if #carried == 1 then return pickSpot(carried[1]) end

    local choices = {}
    for _, def in ipairs(carried) do choices[#choices + 1] = { label = def.label, run = function() pickSpot(def) end } end
    openPicker('item', Locale.editTitle, Locale.editPickItem, choices)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    editing = false
    ArmoryPreview = nil
    if picking then exports['pup-ui']:HideInkMenu() end
end)
