-- pup_library | a small stack of pup-ui ink menus.
-- A level is { title, subtitle, build = function(level) return rows end, index, state }.
-- A row is { label, description, values, valueIndex, onSelect = fn(valueIndex), onChange = fn(valueIndex) }.
-- Rows without onSelect are information rows.

Menu = {
    stack = {},
    open = false,    -- an ink menu of ours is on screen
    active = false,  -- a library session is running (the player is frozen)
    waiting = nil,   -- { kind, token, onReply }
    onClosed = nil,  -- called once when the whole stack closes
}

local MENU_OWNER <const> = 'pup_library:menu'
local inputSeq, requestSeq = 0, 0
local pendingInput = nil -- { owner, cb }

-- values shown in a slider row go through innerHTML in pup-ui, so keep them plain
local function plain(s)
    return (tostring(s or ''):gsub('[<>&]', ''))
end

local function top()
    return Menu.stack[#Menu.stack]
end

function Menu.Draw()
    local level = top()
    if not level then return end
    local rows = level.build(level) or {}
    if #rows == 0 then rows = { { label = T('nothing_here') } } end
    level.rows = rows
    if not level.index or level.index > #rows then level.index = math.min(level.index or 1, #rows) end
    if level.index < 1 then level.index = 1 end

    local options = {}
    for i, r in ipairs(rows) do
        local values
        if r.values then
            values = {}
            for j, v in ipairs(r.values) do values[j] = plain(v) end
        end
        options[i] = {
            label = r.label or '',
            description = r.description,
            values = values,
            valueIndex = r.valueIndex or 1,
        }
    end
    Menu.open = true
    exports['pup-ui']:OpenInkMenu({
        owner = MENU_OWNER,
        title = level.title or T('menu_title'),
        subtitle = level.subtitle,
        startIndex = level.index,
        options = options,
    })
end

function Menu.Push(level)
    level.index = level.index or 1
    level.state = level.state or {}
    Menu.stack[#Menu.stack + 1] = level
    Menu.active = true
    Menu.waiting = nil
    Menu.Draw()
end

function Menu.Close()
    local wasOpen = Menu.active
    Menu.active = false
    if Menu.open then exports['pup-ui']:HideInkMenu() end
    Menu.open = false
    Menu.stack = {}
    Menu.waiting = nil
    pendingInput = nil
    if wasOpen and Menu.onClosed then
        local cb = Menu.onClosed
        Menu.onClosed = nil
        cb()
    end
end

-- Asks the server for a list. The reply opens only while this exact request is still awaited.
function Menu.Request(kind, send, onReply)
    requestSeq = requestSeq + 1
    local token = requestSeq
    Menu.waiting = { kind = kind, token = token, onReply = onReply }
    send(token)
end

RegisterNetEvent('pup_library:list', function(token, kind, rows)
    local w = Menu.waiting
    if not Menu.open or not w or w.token ~= token or w.kind ~= kind then return end
    Menu.waiting = nil
    if type(rows) ~= 'table' then rows = {} end
    w.onReply(rows)
end)

-- A pup-ui input box over the menu. cb(values) runs only on submit; a cancel changes nothing.
function Menu.Input(spec, cb)
    inputSeq = inputSeq + 1
    local owner = ('pup_library:input:%d'):format(inputSeq)
    pendingInput = { owner = owner, cb = cb }
    spec.owner = owner
    exports['pup-ui']:OpenInput(spec)
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    local p = pendingInput
    if not p or owner ~= p.owner then return end
    pendingInput = nil
    if values == nil or not Menu.open then return end
    p.cb(values)
end)

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner ~= MENU_OWNER then return end
    local level = top()
    if level then level.index = tonumber(index) or level.index end
end)

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if owner ~= MENU_OWNER then return end
    local level = top()
    if not level or not level.rows then return end
    index = tonumber(index)
    local row = index and level.rows[index]
    if not row or not row.values then return end
    level.index = index
    row.valueIndex = tonumber(valueIndex) or 1
    if row.onChange then row.onChange(row.valueIndex) end
    if Menu.open and top() == level then Menu.Draw() end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, valueIndex, owner)
    if owner ~= MENU_OWNER then return end
    local level = top()
    if not level or not level.rows then return end
    index = tonumber(index)
    local row = index and level.rows[index]
    if not row then return end
    level.index = index
    if row.onSelect then row.onSelect(tonumber(valueIndex)) end
end)

-- Esc: back one level, or close at the top
AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= MENU_OWNER then return end
    Menu.open = false
    Menu.waiting = nil
    pendingInput = nil
    Menu.stack[#Menu.stack] = nil
    if #Menu.stack == 0 then
        Menu.Close()
    else
        Menu.Draw()
    end
end)
