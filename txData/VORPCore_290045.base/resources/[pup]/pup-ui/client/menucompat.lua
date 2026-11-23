-- pup-ui | vorp_menu / menuapi drop-in, drawn with the ink menu
--
-- The same MenuData API and the same callback order as VORPCORE/vorp_menu (which is also what menuapi became).
-- A script that used vorp_menu or menuapi only changes how it fetches MenuData:
--   exports.vorp_menu:GetMenuData()                    ->  exports['pup-ui']:GetMenuData()
--   TriggerEvent('vorp_menu:getData' / 'menuapi:getData', cb)   ->  unchanged
-- and vorp_inputs callers:
--   exports.vorp_inputs:advancedInput(cfg)             ->  exports['pup-ui']:advancedInput(cfg)
--   TriggerEvent('vorpinputs:getInput' / 'vorpinputs:advancedInput' ...)  ->  unchanged
-- When the real vorp_menu or vorp_inputs is running, pup-ui does not answer for it.

local MD = {
    Opened = {},
    RegisteredTypes = { default = true },
    LastSelectedIndex = {},
}

local shown = nil   -- the menu on screen
local seq = 0

local function realMenuRunning() return GetResourceState('vorp_menu') == 'started' end
local function realInputsRunning() return GetResourceState('vorp_inputs') == 'started' end

--------------------------------------------------------------------------------
-- text and values

-- labels and descriptions were written as HTML for vorp_menu's page: the ink menu shows plain text
local function plain(s)
    if s == nil then return nil end
    if type(s) ~= 'string' then return tostring(s) end
    s = s:gsub('<%s*[bB][rR]%s*/?%s*>', '\n')
    s = s:gsub('</%s*[tT][hH]%s*>', ' ')
    s = s:gsub('</%s*[tT][rR]%s*>', '\n')
    s = s:gsub('</%s*[pP]%s*>', '\n')
    s = s:gsub('</%s*[dD][iI][vV]%s*>', '\n')
    s = s:gsub('</%s*[lL][iI]%s*>', '\n')
    s = s:gsub('<[^>]*>', '')
    s = s:gsub('&nbsp;', ' ')
    s = s:gsub('&amp;', '&')
    s = s:gsub('\r', '')
    s = s:gsub('[ \t]+', ' ')
    s = s:gsub(' *\n *', '\n')
    s = s:gsub('\n\n\n+', '\n\n')
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s
end

local function isSlider(el)
    local t = el.type
    return t == 'slider' or t == 'label-slider' or (t == 'desc-slider' and type(el.sliders) ~= 'table')
end

local function isTextSlider(el)
    return el.type == 'text-slider' and type(el.textList) == 'table' and #el.textList > 0
end

-- every value a slider can take, min to max in steps of hop (vorp_menu default hop is 1)
local function sliderValues(el)
    local mn = tonumber(el.min) or 0
    local mx = tonumber(el.max)
    if mx == nil then mx = 10 end
    local hop = tonumber(el.hop) or 1
    if hop <= 0 then hop = 1 end
    local vals = {}
    if mx < mn then
        vals[1] = mn
    else
        local n = math.floor((mx - mn) / hop + 0.5)
        if n > 2000 then n = 2000 end
        for i = 0, n do
            local v = mn + i * hop
            -- a whole hop keeps whole numbers; a fractional hop keeps one decimal, as vorp_menu does
            if math.type(hop) == 'integer' or hop % 1 == 0 then v = math.floor(v + 0.5) else v = math.floor(v * 10 + 0.5) / 10 end
            vals[#vals + 1] = v
        end
    end
    return vals
end

local function nearestIndex(vals, target)
    target = tonumber(target)
    if target == nil then return 1 end
    local best, bestd = 1, math.huge
    for i, v in ipairs(vals) do
        local d = math.abs(v - target)
        if d < bestd then bestd, best = d, i end
    end
    return best
end

local function buildRows(menu)
    local rows = {}
    for i, el in ipairs(menu.data.elements or {}) do
        local d = plain(el.descText or el.desc)
        if el.descPrice and el.descPrice.amount ~= nil then
            local price = ('Price: %s'):format(tostring(el.descPrice.amount))
            d = (d and d ~= '') and (d .. '\n' .. price) or price
        end
        if d == '' then d = nil end
        local label = plain(el.label) or ''
        if el.tickBox then label = label .. (el.value == 'ticked' and '  [x]' or '  [ ]') end
        local row = { label = label, description = d, image = el.image }
        if isSlider(el) then
            local vals = sliderValues(el)
            row.values = vals
            row.valueIndex = nearestIndex(vals, el.value)
            row.clamp = true
            row.noneFirst = el.noneFirst
        elseif isTextSlider(el) then
            local vals = {}
            for k, t in ipairs(el.textList) do vals[k] = plain(t.label) or tostring(t.value or k) end
            row.values = vals
            row.valueIndex = math.min(math.max(tonumber(el.textIndex) or 1, 1), #vals)
            row.clamp = true
        end
        rows[i] = row
    end
    return rows
end

--------------------------------------------------------------------------------
-- showing and forgetting menus

local function key(menu) return menu.type .. '_' .. menu.namespace .. '_' .. menu.name end

local function show(menu)
    shown = menu
    local n = #(menu.data.elements or {})
    local idx = menu._index or ((tonumber(menu.data.selected) or 0) + 1)
    if idx > n then idx = math.max(n, 1) end
    if idx < 1 then idx = 1 end
    menu._index = idx
    exports['pup-ui']:OpenInkMenu({
        owner = menu._owner,
        title = plain(menu.data.title) or '',
        subtitle = plain(menu.data.subtext),
        startIndex = idx,
        options = buildRows(menu),
    })
end

local function forget(menu)
    for i = #MD.Opened, 1, -1 do
        if MD.Opened[i] == menu then table.remove(MD.Opened, i) end
    end
end

-- after the menu on screen goes away, the one opened before it comes back (vorp_menu's focus order)
local function showTopOrHide()
    shown = nil
    local top = MD.Opened[#MD.Opened]
    if top then show(top) else exports['pup-ui']:HideInkMenu() end
end

local function findOpened(menuType, namespace, name)
    for _, m in ipairs(MD.Opened) do
        if m.type == menuType and m.namespace == namespace and m.name == name then return m end
    end
    return nil
end

--- What vorp_menu's page sends with submit and change: { _namespace, _name, current, elements, trigger? }
local function payload(menu, current, withTrigger)
    local p = { _namespace = menu.namespace, _name = menu.name, current = current, elements = menu.data.elements }
    if withTrigger then p.trigger = menu.data.lastmenu end
    return p
end

local function call(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then print(('^1[pup-ui]^7 menu callback failed: %s'):format(tostring(err))) end
end

--------------------------------------------------------------------------------
-- inputs (menu.displayInput and vorp_inputs)

local inputSeq = 0

--- Open pup-ui's input form. done(value) gets the value, or nil on cancel.
local function askInput(title, submitLabel, field, done)
    inputSeq = inputSeq + 1
    local owner = ('pup-ui:inputcompat:%d'):format(inputSeq)
    local ev
    ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
        if o ~= owner then return end
        RemoveEventHandler(ev)
        local v = values and values[1]
        local ok, err = pcall(done, v)
        if not ok then print(('^1[pup-ui]^7 input callback failed: %s'):format(tostring(err))) end
    end)
    exports['pup-ui']:OpenInput({
        owner = owner,
        title = plain(title) or 'Input',
        submit = plain(submitLabel) or 'Confirm',
        fields = { field },
    })
end

--------------------------------------------------------------------------------
-- MenuData

function MD.Open(menuType, namespace, name, data, submit, cancel, change, close)
    menuType = menuType or 'default'
    namespace = tostring(namespace or 'unknown')
    name = tostring(name or 'menu')
    data = type(data) == 'table' and data or {}
    data.elements = type(data.elements) == 'table' and data.elements or {}

    -- the same menu opened again replaces itself
    local old = findOpened(menuType, namespace, name)
    if old then forget(old) end

    seq = seq + 1
    local menu = {
        type = menuType, namespace = namespace, name = name, data = data,
        submit = submit, cancel = cancel, change = change,
        _closeCb = close, _owner = ('pup-ui:menucompat:%d'):format(seq),
    }
    menu.data.selected = MD.LastSelectedIndex[key(menu)] or 0

    function menu.close(showRadar, closeSound, triggerCloseEvent)
        local wasShown = shown == menu
        forget(menu)
        if wasShown then showTopOrHide() end
        if showRadar then DisplayRadar(true) end
        if closeSound then PlaySoundFrontend('MENU_CLOSE', 'HUD_PLAYER_MENU', true, 0) end
        if triggerCloseEvent or triggerCloseEvent == nil then TriggerEvent('vorp_menu:closemenu') end
        call(close)
    end

    function menu.update(query, newData)
        for _, el in ipairs(menu.data.elements) do
            local match = true
            for k, v in pairs(query or {}) do if el[k] ~= v then match = false end end
            if match then for k, v in pairs(newData or {}) do el[k] = v end end
        end
    end

    function menu.addNewElement(element) menu.data.elements[#menu.data.elements + 1] = element end

    function menu.removeElementByValue(value, stop)
        for i = #menu.data.elements, 1, -1 do
            if menu.data.elements[i] and menu.data.elements[i].value == value then
                table.remove(menu.data.elements, i)
                if stop then break end
            end
        end
    end

    function menu.removeElementByIndex(index, stop)
        if menu.data.elements[index] then table.remove(menu.data.elements, index) end
    end

    function menu.removeElement(query)
        for i = #menu.data.elements, 1, -1 do
            local el = menu.data.elements[i]
            for k, v in pairs(query or {}) do
                if el and el[k] == v then table.remove(menu.data.elements, i); break end
            end
        end
    end

    function menu.refresh()
        -- vorp_menu redraws the menu and brings it to the front
        forget(menu)
        MD.Opened[#MD.Opened + 1] = menu
        show(menu)
    end

    function menu.setElement(i, k, v) if menu.data.elements[i] then menu.data.elements[i][k] = v end end
    function menu.setElements(newElements) menu.data.elements = type(newElements) == 'table' and newElements or {} end
    function menu.setTitle(v) menu.data.title = v end
    function menu.setSubtext(v) menu.data.subtext = v end

    function menu.displayInput(inputConfig, onSubmit, onCancel)
        Wait(500)
        if MD.InputCallbacks then return end
        local cfg = type(inputConfig) == 'table' and inputConfig or {}
        MD.InputCallbacks = { onSubmit = onSubmit, onCancel = onCancel }
        local t = cfg.inputType == 'number' and 'number' or (cfg.inputType == 'textarea' and 'textarea' or 'text')
        askInput(cfg.header or 'Input', 'Confirm', { label = plain(cfg.description) or '', placeholder = cfg.placeholder, type = t }, function(v)
            local cbs = MD.InputCallbacks
            MD.InputCallbacks = nil
            if not cbs then return end
            if v == nil then call(cbs.onCancel) else call(cbs.onSubmit, v) end
        end)
    end

    function menu.isInputActive() return MD.InputCallbacks ~= nil end

    if data.hideRadar then DisplayRadar(false) end

    MD.Opened[#MD.Opened + 1] = menu
    show(menu)

    if data.soundOpen then
        PlaySoundFrontend('MENU_ENTER', 'HUD_PLAYER_MENU', true, 0)
    else
        PlaySoundFrontend('SELECT', 'RDRO_Character_Creator_Sounds', true, 0)
    end
    if not data.skipOpenEvent then TriggerEvent('vorp_menu:openmenu') end
    return menu
end

function MD.Close(menuType, namespace, name, showRadar, closeSound, triggerCloseEvent)
    local m = findOpened(menuType, namespace, name)
    if m then m.close(showRadar, closeSound, triggerCloseEvent) end
end

function MD.CloseAll(showRadar, closeSound, triggerCloseEvent)
    for i = #MD.Opened, 1, -1 do
        local m = MD.Opened[i]
        if m then m.close(showRadar, closeSound, triggerCloseEvent) end
    end
end

function MD.GetOpened(menuType, namespace, name)
    -- with no arguments: the menu on screen (older pup-ui callers asked like this)
    if menuType == nil and namespace == nil and name == nil then return shown end
    return findOpened(menuType, namespace, name)
end

function MD.GetOpenedMenus() return MD.Opened end
function MD.IsOpen(menuType, namespace, name) return findOpened(menuType, namespace, name) ~= nil end

function MD.ReOpen(oldMenu)
    if type(oldMenu) ~= 'table' then return end
    return MD.Open(oldMenu.type, oldMenu.namespace, oldMenu.name, oldMenu.data, oldMenu.submit, oldMenu.cancel, oldMenu.change, oldMenu._closeCb)
end

function MD.IsInputActive() return MD.InputCallbacks ~= nil end

-- vorp_menu catches raw keys through its page; the ink menu takes no keyboard focus, so this is not offered
local warnedControls = false
function MD.RegisterControls()
    if not warnedControls then
        warnedControls = true
        print('^3[pup-ui]^7 MenuData.RegisterControls is not supported by pup-ui; read the keys with IsControlJustPressed instead')
    end
end
function MD.UnregisterControls() end

function MD.call() end -- stub kept for older callers

--------------------------------------------------------------------------------
-- answering the menu providers

AddEventHandler('menuapi:getData', function(cb)
    if realMenuRunning() then return end
    if cb then cb(MD) end
end)
AddEventHandler('vorp_menu:getData', function(cb)
    if realMenuRunning() then return end
    if cb then cb(MD) end
end)
-- menu_base (Rexshack) is the same API
AddEventHandler('menu_base:getData', function(cb)
    if GetResourceState('menu_base') == 'started' then return end
    if cb then cb(MD) end
end)

exports('GetMenuData', function() return MD end)

--------------------------------------------------------------------------------
-- the ink menu's keys, as vorp_menu's page handled them

local function element(menu, index)
    local el = menu.data.elements[index]
    if el then el.index = index end
    return el
end

-- up / down: vorp_menu marks the new row selected and calls change
AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    local menu = shown
    if not menu or owner ~= menu._owner then return end
    menu._index = index
    for i, e in ipairs(menu.data.elements) do e.selected = (i == index) end
    MD.LastSelectedIndex[key(menu)] = index - 1
    PlaySoundFrontend('NAV_LEFT', 'PAUSE_MENU_SOUNDSET', true, 0)
    local el = element(menu, index)
    if el then call(menu.change, payload(menu, el), menu) end
end)

-- left / right on a slider: vorp_menu calls change, then submit (text sliders: submit only)
AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    local menu = shown
    if not menu or owner ~= menu._owner then return end
    menu._index = index
    local el = element(menu, index)
    if not el or el.isDisabled then return end
    if isSlider(el) then
        local v = sliderValues(el)[valueIndex]
        if v == nil or v == tonumber(el.value) then return end
        el.value = v
        PlaySoundFrontend('NAV_LEFT', 'PAUSE_MENU_SOUNDSET', true, 0)
        call(menu.change, payload(menu, el), menu)
        if shown == menu then call(menu.submit, payload(menu, el), menu) end
    elseif isTextSlider(el) then
        local t = el.textList[valueIndex]
        if not t then return end
        el.value = t.value
        el.currentTextLabel = t.label
        el.textIndex = valueIndex
        PlaySoundFrontend('NAV_LEFT', 'PAUSE_MENU_SOUNDSET', true, 0)
        call(menu.submit, payload(menu, el), menu)
    end
end)

-- enter: submit the row (a tick box flips first); disabled rows do nothing
AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    local menu = shown
    if not menu or owner ~= menu._owner then return end
    menu._index = index
    local el = element(menu, index)
    if not el or el.isDisabled then return end
    PlaySoundFrontend('SELECT', 'RDRO_Character_Creator_Sounds', true, 0)
    if el.tickBox then
        el.value = el.value == 'ticked' and 'unticked' or 'ticked'
        call(menu.submit, payload(menu, el), menu)
        if shown == menu then show(menu) end
        return
    end
    call(menu.submit, payload(menu, el), menu)
end)

-- back: with a lastmenu, vorp_menu submits "backup" (trigger = lastmenu); otherwise it calls cancel
-- and fires the close events. The ink menu hides itself on this key first.
AddEventHandler('pup-ui:client:inkClose', function(owner)
    local menu = shown
    if not menu or owner ~= menu._owner then return end
    shown = nil
    local last = menu.data.lastmenu
    if last ~= nil and last ~= '' and last ~= 'undefined' then
        call(menu.submit, payload(menu, 'backup', true), menu)
        -- the script opened nothing new: keep this menu up, as vorp_menu does
        if shown == nil and findOpened(menu.type, menu.namespace, menu.name) == menu then show(menu) end
        return
    end
    call(menu.cancel, { _namespace = menu.namespace, _name = menu.name }, menu)
    TriggerEvent('menuapi:closemenu')
    TriggerEvent('vorp_menu:closemenu')
    -- nothing else on screen and the script left this menu open: let it go rather than leave it invisible
    if shown == nil then
        if findOpened(menu.type, menu.namespace, menu.name) == menu then forget(menu) end
        showTopOrHide()
    end
end)

-- the pause menu hides open menus and brings them back afterwards (vorp_menu closes and reopens them)
CreateThread(function()
    local pausedMenu = nil
    while true do
        if #MD.Opened == 0 and not pausedMenu then
            Wait(500)
        else
            Wait(150)
            if IsPauseMenuActive() then
                if shown and not pausedMenu then
                    pausedMenu = shown
                    shown = nil
                    exports['pup-ui']:HideInkMenu()
                end
            elseif pausedMenu then
                Wait(1000)
                local m = pausedMenu
                pausedMenu = nil
                if not shown and findOpened(m.type, m.namespace, m.name) == m then show(m) end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- vorp_inputs events, served by pup-ui's input form ("" on cancel, as vorp_inputs did)

local function inputType(t, attrType)
    if t == 'textarea' then return 'textarea' end
    if t == 'number' or attrType == 'number' then return 'number' end
    return 'text'
end

local function simpleInput(button, placeholder, kind, cb)
    if realInputsRunning() or not cb then return end
    askInput(placeholder ~= nil and placeholder ~= '' and placeholder or button, button, {
        label = '', placeholder = plain(placeholder), type = inputType(kind),
    }, function(v) cb(v ~= nil and tostring(v) or '') end)
end

AddEventHandler('vorpinputs:getInput', function(button, placeholder, cb)
    simpleInput(button, placeholder, 'input', cb)
end)

AddEventHandler('vorpinputs:getInputsWithInputType', function(button, placeholder, kind, cb)
    simpleInput(button, placeholder, kind, cb)
end)

local function advanced(config, cb)
    local cfg = config
    if type(cfg) == 'string' then
        local ok, decoded = pcall(json.decode, cfg)
        cfg = ok and decoded or {}
    end
    if type(cfg) ~= 'table' then cfg = {} end
    local attrs = type(cfg.attributes) == 'table' and cfg.attributes or {}
    askInput(attrs.inputHeader or cfg.button or 'Input', cfg.button or 'Confirm', {
        label = plain(attrs.title) or '', placeholder = plain(cfg.placeholder), type = inputType(cfg.inputType, attrs.type),
    }, function(v) if cb then cb(v ~= nil and tostring(v) or '') end end)
end

AddEventHandler('vorpinputs:advancedInput', function(config, cb)
    if realInputsRunning() then return end
    advanced(config, cb)
end)

exports('advancedInput', function(config)
    local p = promise.new()
    advanced(config, function(result) p:resolve(result) end)
    return Citizen.Await(p)
end)

-- pup_inputs:sendinputs: the older pup name for a one-line input
AddEventHandler('pup_inputs:sendinputs', function(confirmLabel, title, cb)
    if not cb then return end
    askInput(title, confirmLabel, { label = plain(title) or 'Value', type = 'text', required = false }, function(v)
        cb(v ~= nil and tostring(v) or '')
    end)
end)

-- if this never prints in F8, this file failed to load
print('^2[pup-ui]^7 menucompat loaded - vorp_menu / menuapi / vorp_inputs answered by pup-ui')
