-- pup_business | thin layer over pup-ui: list menus, input boxes and apps
-- Every panel carries an owner token so other resources' events are ignored.

UI = {}

local PUI = exports['pup-ui']
local LIST_OWNER <const> = 'pup_business:list'
local INPUT_OWNER <const> = 'pup_business:input'

local cur = { list = nil, input = nil }
local app = { owner = nil, handlers = nil }
local held = false
local settleToken = 0

---------------------------------------------------------------------------
-- standing still while the job menu is up
---------------------------------------------------------------------------

function UI.Hold()
    if held then return end
    held = true
    local ped = PlayerPedId()
    TaskStandStill(ped, -1)
    FreezeEntityPosition(ped, true)
end

function UI.Release()
    if not held then return end
    held = false
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

function UI.AnyOpen()
    return cur.list ~= nil or cur.input ~= nil or app.owner ~= nil
end

-- released a moment after the last panel closed, so a menu that opens the next
-- one after a server answer does not unfreeze the player in between
local function settle()
    settleToken = settleToken + 1
    local token = settleToken
    SetTimeout(400, function()
        if token == settleToken and not UI.AnyOpen() then UI.Release() end
    end)
end
UI.Settle = settle

---------------------------------------------------------------------------
-- list menus: def = { title, subtitle, hold, options = { { label, desc, disabled, onSelect } }, onBack, onClose }
---------------------------------------------------------------------------

function UI.List(def)
    if app.owner then UI.CloseApp(true) end
    cur.list = def
    if def.hold then UI.Hold() end
    local opts = {}
    for i, o in ipairs(def.options or {}) do
        opts[i] = { label = tostring(o.label or ''), desc = o.desc and tostring(o.desc) or nil, disabled = o.disabled == true }
    end
    PUI:OpenListMenu({
        owner = LIST_OWNER,
        title = tostring(def.title or ''),
        subtitle = def.subtitle and tostring(def.subtitle) or nil,
        options = opts,
        keyboard = true,
    })
end

function UI.HideList()
    if not cur.list then return end
    cur.list = nil
    PUI:HideListMenu()
    settle()
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= LIST_OWNER then return end
    local def = cur.list
    cur.list = nil
    local opt = def and def.options and def.options[tonumber(index) or 0]
    if opt and not opt.disabled and opt.onSelect then opt.onSelect() end
    settle()
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= LIST_OWNER then return end
    local def = cur.list
    cur.list = nil
    if def and def.onBack then def.onBack() elseif def and def.onClose then def.onClose() end
    settle()
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= LIST_OWNER then return end
    local def = cur.list
    cur.list = nil
    if def and def.onClose then def.onClose() end
    settle()
end)

---------------------------------------------------------------------------
-- input boxes: def = { title, subtitle, submit, fields, onDone(values), onCancel, after }
---------------------------------------------------------------------------

function UI.Input(def)
    if cur.list then cur.list = nil; PUI:HideListMenu() end
    if app.owner then UI.CloseApp(true) end
    cur.input = def
    PUI:OpenInput({
        owner = INPUT_OWNER,
        title = tostring(def.title or ''),
        subtitle = def.subtitle,
        submit = def.submit,
        fields = def.fields or {},
    })
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= INPUT_OWNER then return end
    local def = cur.input
    cur.input = nil
    if not def then return settle() end
    if values == nil then
        if def.onCancel then def.onCancel() end
    elseif def.onDone then
        def.onDone(values)
    end
    if def.after then def.after() end
    settle()
end)

---------------------------------------------------------------------------
-- apps: handlers = { nav(tab), action(id, data), closed() }
---------------------------------------------------------------------------

function UI.OpenApp(owner, data, handlers)
    if cur.list then cur.list = nil; PUI:HideListMenu() end
    app.owner, app.handlers = owner, handlers
    data.owner = owner
    PUI:OpenApp(data)
end

function UI.UpdateApp(owner, data)
    if app.owner ~= owner then return end
    PUI:UpdateApp(data)
end

function UI.AppOpen(owner)
    return app.owner ~= nil and app.owner == owner
end

-- silent = our own close (an input box is taking its place): no closed() call
function UI.CloseApp(silent)
    if not app.owner then return end
    local h = app.handlers
    app.owner, app.handlers = nil, nil
    PUI:CloseApp()
    if not silent and h and h.closed then h.closed() end
    settle()
end

AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner == nil or owner ~= app.owner then return end
    if app.handlers and app.handlers.nav then app.handlers.nav(tab) end
end)

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner == nil or owner ~= app.owner then return end
    if app.handlers and app.handlers.action then app.handlers.action(tostring(action or ''), type(data) == 'table' and data or {}) end
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner == nil or owner ~= app.owner then return end
    local h = app.handlers
    app.owner, app.handlers = nil, nil
    if h and h.closed then h.closed() end
    settle()
end)

---------------------------------------------------------------------------
-- clean up
---------------------------------------------------------------------------

function UI.CloseAll()
    if cur.list then cur.list = nil; pcall(function() PUI:HideListMenu() end) end
    cur.input = nil
    if app.owner then
        app.owner, app.handlers = nil, nil
        pcall(function() PUI:CloseApp() end)
    end
    UI.Release()
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    UI.CloseAll()
end)
