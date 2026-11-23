-- pup_realestate | menu stack on pup-ui ink menus, and input boxes
-- A menu node is a function returning { title, subtitle, options = { { label, description, select, sub } } }.
-- Esc goes back one level and closes at the top.

Menu = { stack = {}, current = nil, onClose = nil }
local OWNER = 'pup_realestate:menu'

local function render()
    local builder = Menu.stack[#Menu.stack]
    if not builder then return Menu.finish() end
    local ok, spec = pcall(builder)
    if not ok or type(spec) ~= 'table' then
        if not ok then print('^1[pup_realestate]^7 menu: ' .. tostring(spec)) end
        table.remove(Menu.stack)
        return render()
    end
    if #spec.options == 0 then
        spec.options = { { label = Locale.nothing_here } }
    end
    Menu.current = spec
    local rows = {}
    for i, o in ipairs(spec.options) do rows[i] = { label = o.label, description = o.description } end
    UI:OpenInkMenu({ owner = OWNER, title = spec.title or '', subtitle = spec.subtitle, options = rows, startIndex = spec.startIndex })
end

function Menu.isOpen() return #Menu.stack > 0 end

-- open a root menu; onClose runs once when the whole stack is gone
function Menu.open(builder, onClose)
    if Menu.isOpen() then Menu.close() end
    Menu.stack = { builder }
    Menu.onClose = onClose
    C.menuOpen = true
    render()
end

function Menu.push(builder)
    if not Menu.isOpen() then return Menu.open(builder) end
    Menu.stack[#Menu.stack + 1] = builder
    render()
end

function Menu.refresh()
    if Menu.isOpen() then render() end
end

function Menu.back()
    table.remove(Menu.stack)
    if #Menu.stack > 0 then render() else Menu.finish() end
end

function Menu.finish()
    Menu.stack = {}
    Menu.current = nil
    C.menuOpen = false
    local cb = Menu.onClose
    Menu.onClose = nil
    if cb then
        local ok, err = pcall(cb)
        if not ok then print('^1[pup_realestate]^7 menu close: ' .. tostring(err)) end
    end
end

-- close everything (no pup-ui event fires for a programmatic close)
function Menu.close()
    if not Menu.isOpen() then return end
    UI:HideInkMenu()
    Menu.finish()
end

-- Yes / No
function Menu.confirm(title, subtitle, onYes)
    Menu.push(function()
        return {
            title = title, subtitle = subtitle or Locale.are_you_sure,
            options = {
                { label = Locale.yes, select = onYes },
                { label = Locale.no, select = function() Menu.back() end },
            },
        }
    end)
end

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not Menu.current then return end
    local opt = Menu.current.options[index]
    if not opt then return end
    if opt.sub then
        Menu.push(opt.sub)
    elseif opt.select then
        local ok, err = pcall(opt.select)
        if not ok then print('^1[pup_realestate]^7 menu select: ' .. tostring(err)) end
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER or not Menu.isOpen() then return end
    Menu.back()
end)

-- input boxes: returns the values array, or nil when cancelled or after two minutes
local inputSeq, waiting = 0, {}

function Ask(title, fields, subtitle)
    inputSeq = inputSeq + 1
    local owner = 'pup_realestate:input:' .. inputSeq
    local p = promise.new()
    waiting[owner] = p
    UI:OpenInput({ owner = owner, title = title, subtitle = subtitle, submit = Locale.confirm, fields = fields })
    SetTimeout(Config.Timers.inputGiveUp, function()
        if waiting[owner] then
            waiting[owner] = nil
            p:resolve(false)
        end
    end)
    local values = Citizen.Await(p)
    return values or nil
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    local p = waiting[owner]
    if not p then return end
    waiting[owner] = nil
    p:resolve(type(values) == 'table' and values or false)
end)

-- resource stop: never leave a menu, a frozen player or a prompt pill behind
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Menu.isOpen() then
        UI:HideInkMenu()
        ClearPedTasks(PlayerPedId())
    end
    UI:PromptHide()
end)

-- one whole number of at least 1
function AskAmount(title, label)
    local v = Ask(title, { { label = label or Locale.amount, type = 'number', min = 1, required = true } })
    local n = v and U.int(v[1])
    if not n or n < 1 then return nil end
    return n
end
