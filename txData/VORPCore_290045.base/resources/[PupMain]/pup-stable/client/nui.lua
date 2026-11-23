-- pup-stable | bridge to the menu page. The page can only name menus and items we sent it, and only
-- the action names below ever run.

Ui = { open = false, menus = {}, owner = nil, ready = false }

local ALLOWED = {
    open = true, buy = true, buyGold = true, color = true, favourite = true, retrieve = true, transfer = true, release = true,
    delete = true, revive = true, reviveGold = true, equip = true, unequip = true, manage = true, destroy = true, rename = true,
    save = true, select = true, focus = true, bag = true, outfit = true, storage = true, transferHere = true, sendAway = true,
    shoes = true, retire = true, done = true, price = true, close = true,
}

function Ui.send(kind, data)
    data = data or {}
    data.type = kind
    SendNUIMessage(data)
end

local function sendSetup()
    local tbl = {}
    for k, v in pairs(Locale) do if type(v) == 'string' then tbl[k] = v end end
    Ui.send('lang', { table = tbl })
    if Running('pup-ui') then
        local ok, theme = pcall(function() return exports['pup-ui']:GetTheme() end)
        if ok and type(theme) == 'table' then
            local fonts = {}
            -- the stable keeps its own pair over the theme's default; any other font from pup-ui's folder is used
            for slot, file in pairs(theme.fonts or {}) do
                if file ~= 'oswald.ttf' and file ~= 'imfell.ttf' then fonts[slot] = file end
            end
            fonts.title = fonts.title or 'imfell.ttf'
            fonts.body = fonts.body or 'robotoslab.ttf'
            Ui.send('theme', { colors = theme.colors, fonts = fonts })
        end
    end
end

function Ui.menu(m)
    Ui.menus[m.id] = m
    Ui.send('menu', { menu = m })
end

function Ui.root(id) Ui.send('root', { id = id }) end
function Ui.go(id, reset, select) Ui.send('go', { id = id, reset = reset == true, select = select }) end
function Ui.back() Ui.send('back') end
function Ui.header(title, raw) Ui.send('header', { title = title, raw = raw }) end

function Ui.item(menuId, itemId, fields)
    local m = Ui.menus[menuId]
    if m then
        for _, it in ipairs(m.items) do
            if it.id == itemId then for k, v in pairs(fields) do if k ~= 'sliders' then it[k] = v end end end
        end
    end
    Ui.send('item', { menu = menuId, item = itemId, fields = fields })
end

function Ui.cash()
    local st = LocalPlayer.state.Character
    local money = type(st) == 'table' and st.Money or 0
    local gold = type(st) == 'table' and st.Gold or nil
    Ui.send('cash', { money = money, gold = Config.General.useGold and gold or nil })
end

-- owner = { onAction(menuId, item, act, sliders), onPreview(menuId, item, sliders), onClose(), onRotate(dir), onBack(menuId) }
-- the player's menu side (set in fred_hud's /hud editor, kept by pup-ui); read each time a menu opens
local function sendSide()
    local side = 'left'
    if Running('pup-ui') then
        local ok, s = pcall(function() return exports['pup-ui']:GetMenuSide() end)
        if ok and s == 'right' then side = 'right' end
    end
    Ui.send('menuSide', { side = side })
end

function Ui.show(owner)
    Ui.owner = owner
    Ui.open = true
    if not Ui.ready then sendSetup() end
    sendSide()
    Ui.cash()
    Ui.send('show', { on = true })
    SetNuiFocus(true, Config.General.useMouse)
    HideHud()
end

function Ui.hide(instant)
    if not Ui.open then return end
    Ui.open = false
    Ui.send('show', { on = false, instant = instant == true })
    SetNuiFocus(false, false)
    ShowHud()
    local owner = Ui.owner
    Ui.owner = nil
    Ui.menus = {}
    if owner and owner.onClose then owner.onClose() end
end

-- detach the page without firing onClose (an action that hands over to pup-ui input, for example)
function Ui.suspend()
    Ui.send('show', { on = false, instant = true })
    SetNuiFocus(false, false)
end

function Ui.resume()
    if not Ui.open then return end
    sendSide()
    Ui.cash()
    Ui.send('show', { on = true })
    SetNuiFocus(true, Config.General.useMouse)
end

local function findItem(menuId, itemId)
    local m = Ui.menus[menuId]
    if not m then return nil end
    for _, it in ipairs(m.items) do if it.id == itemId then return it, m end end
    return nil
end

RegisterNUICallback('ready', function(_, cb)
    cb('ok')
    Ui.ready = true
    sendSetup()
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
    Ui.hide(false)
end)

RegisterNUICallback('back', function(data, cb)
    cb('ok')
    local o = Ui.owner
    if o and o.onBack and type(data) == 'table' then o.onBack(data.menu) end
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' or not ALLOWED[data.act] then return end
    local it, m = findItem(data.menu, data.item)
    local o = Ui.owner
    if not it or not o or not o.onAction or it.disabled then return end
    -- only an action the row (or its page) actually offers, or opening its submenu
    local offered = false
    for _, a in ipairs(it.actions or m.actions or {}) do if a.act == data.act then offered = true end end
    if data.act == 'open' and it.child then offered = true end
    if not offered then return end
    local sl = type(data.sliders) == 'table' and data.sliders or {}
    CreateThread(function() o.onAction(m.id, it, data.act, sl) end)
end)

RegisterNUICallback('preview', function(data, cb)
    cb('ok')
    if type(data) ~= 'table' then return end
    local it, m = findItem(data.menu, data.item)
    local o = Ui.owner
    if it and o and o.onPreview then
        local sl = type(data.sliders) == 'table' and data.sliders or {}
        if it.sliders then for i, s in ipairs(it.sliders) do if sl[i] ~= nil then s.index = U.int(sl[i], s.index) end end end
        CreateThread(function() o.onPreview(m.id, it, sl) end)
    end
end)

RegisterNUICallback('rotate', function(data, cb)
    cb('ok')
    local o = Ui.owner
    if o and o.onRotate and type(data) == 'table' then o.onRotate(U.int(data.dir, 0)) end
end)

AddEventHandler('pup-stable:closeAll', function() Ui.hide(true) end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES then return end
    if Ui.open then SetNuiFocus(false, false) end
end)
