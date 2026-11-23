-- pup_camps | menu layer over pup-ui ink menus and input boxes
-- A page = { title, subtitle, rows = { { label, description, disabled, values, valueIndex,
--            onSelect = fn(row, valueIndex), onChange = fn(row, valueIndex), onFocus = fn(row) } },
--            onBack = fn() (optional: replaces the default "go up one page") }
-- ESC goes up one page; on the root page it closes the whole session.

Menu = {}

local OWNER <const> = 'pup_camps:menu'
local INPUT_OWNER <const> = 'pup_camps:input'

local session = nil   -- { stack = { page, ... }, onClose = fn, campId, lock }
local inputWait = nil -- promise while an input box is open

local function render(page, index)
    local options = {}
    for i, r in ipairs(page.rows) do
        local label = r.label or ''
        if r.disabled then label = '- ' .. label end
        options[i] = {
            label = label, description = r.description,
            values = r.values, valueIndex = r.valueIndex, slider = r.values ~= nil,
        }
    end
    if #options == 0 then options[1] = { label = '-' } end
    page.index = index or page.index or 1
    exports['pup-ui']:OpenInkMenu({
        owner = OWNER, title = page.title or L('menu_title'), subtitle = page.subtitle,
        startIndex = page.index, options = options,
    })
end

local function top()
    return session and session.stack[#session.stack] or nil
end

function Menu.isOpen()
    return session ~= nil
end

-- start a menu session (one at a time). opts.onClose runs once however the session ends.
function Menu.begin(opts)
    if session then return false end
    if not UiRunning() then return false end
    session = { stack = {}, onClose = opts and opts.onClose, campId = opts and opts.campId }
    State.busy = true
    local ped = PlayerPedId()
    if not (opts and opts.noFreeze) then FreezeEntityPosition(ped, true) end
    session.frozen = not (opts and opts.noFreeze)
    -- while a menu is open: no inventory key, and death closes everything
    local my = session
    CreateThread(function()
        while session == my do
            DisableControlAction(0, Config.Keys.inventory, true)
            if IsDeadOrDying() then Menu.closeAll() break end
            Wait(0)
        end
    end)
    return true
end

function Menu.push(page)
    if not session then return end
    session.stack[#session.stack + 1] = page
    render(page, 1)
end

-- replace the page on top (refresh after a change), keeping the cursor
function Menu.replace(page)
    if not session then return end
    local cur = top()
    local idx = cur and cur.index or 1
    if #session.stack == 0 then session.stack[1] = page else session.stack[#session.stack] = page end
    if idx > #page.rows then idx = math.max(1, #page.rows) end
    render(page, idx)
end

function Menu.back()
    if not session then return end
    if #session.stack <= 1 then return Menu.closeAll() end
    session.stack[#session.stack] = nil
    local page = top()
    if page.refresh then
        local fresh = page.refresh()
        if fresh then
            fresh.refresh = page.refresh
            fresh.index = page.index
            session.stack[#session.stack] = fresh
            page = fresh
        end
    end
    render(page, page.index)
end

function Menu.closeAll()
    local s = session
    if not s then return end
    session = nil
    pcall(function() exports['pup-ui']:HideInkMenu() end)
    if s.frozen then FreezeEntityPosition(PlayerPedId(), false) end
    State.busy = false
    if s.onClose then
        local ok, err = pcall(s.onClose)
        if not ok then print('^1[pup_camps]^7 menu close failed: ' .. tostring(err)) end
    end
end

-- hide the ink menu without ending the session (placement, minigames, input)
function Menu.hide()
    pcall(function() exports['pup-ui']:HideInkMenu() end)
end

function Menu.show()
    local page = top()
    if page then render(page, page.index) end
end

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner ~= OWNER then return end
    local page = top()
    if not page then return end
    page.index = index
    local row = page.rows[index]
    if row and row.onFocus then row.onFocus(row) end
end)

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if owner ~= OWNER then return end
    local page = top()
    local row = page and page.rows[index]
    if not row then return end
    row.valueIndex = valueIndex
    if row.onChange then row.onChange(row, valueIndex) end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, valueIndex, owner)
    if owner ~= OWNER then return end
    local page = top()
    local row = page and page.rows[index]
    if not row or row.disabled or not row.onSelect then return end
    page.index = index
    CreateThread(function() row.onSelect(row, valueIndex) end)
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER or not session then return end
    local page = top()
    if page and page.onBack then
        CreateThread(function() page.onBack() end)
        return
    end
    -- pup-ui has already hidden the menu; going up re-renders the parent
    Menu.back()
end)

------------------------------------------------------------------------------ input boxes

-- returns the list of values (in field order) or nil when cancelled
function Menu.input(title, fields, subtitle)
    if inputWait then return nil end
    local p = promise.new()
    inputWait = p
    local ok = exports['pup-ui']:OpenInput({ owner = INPUT_OWNER, title = title, subtitle = subtitle, submit = L('confirm'), fields = fields })
    if not ok then
        inputWait = nil
        return nil
    end
    local values = Citizen.Await(p)
    return values
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= INPUT_OWNER or not inputWait then return end
    local p = inputWait
    inputWait = nil
    p:resolve(type(values) == 'table' and values or nil)
end)

-- one whole number >= 1, or nil (shows "invalid" when typed wrong)
function Menu.amount(title, subtitle)
    local v = Menu.input(title, { { label = L('amount'), type = 'number', min = 1, required = true } }, subtitle)
    if not v then return nil end
    local n = tonumber(v[1])
    if not n or n < 1 or n ~= math.floor(n) then
        Notify(L('invalid_amount'))
        return nil
    end
    return math.floor(n)
end

function Menu.text(title, label, default, maxlength)
    local v = Menu.input(title, { { label = label, type = 'text', default = default, maxlength = maxlength or 60 } })
    if not v then return nil end
    return U.trim(tostring(v[1] or ''))
end

-- yes/no page; fn runs on yes
function Menu.confirm(title, text, fn)
    Menu.push({
        title = title or L('confirm_title'), subtitle = text,
        rows = {
            { label = L('yes'), onSelect = function() fn() end },
            { label = L('no'), onSelect = function() Menu.back() end },
        },
    })
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if session then
        pcall(function() exports['pup-ui']:HideInkMenu() end)
        if session.frozen then FreezeEntityPosition(PlayerPedId(), false) end
    end
end)
