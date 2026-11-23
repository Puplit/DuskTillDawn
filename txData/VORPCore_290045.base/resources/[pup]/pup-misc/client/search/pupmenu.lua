-- PupMenu | a level stack over pup-ui's list menu, shared by this resource's
-- modules (search, outfitter). Must load before every client file that uses it.
--
--   PupMenu.Open(spec)     fresh stack, spec as the root level
--   PupMenu.Push(spec)     add a level
--   PupMenu.Pop()          back one level; at the root, hide and call OnClose
--   PupMenu.Close()        if open: clear, hide, call OnClose
--   PupMenu.Refresh(spec)  redraw the current level (optionally with a new spec)
--   PupMenu.IsOpen()
--   PupMenu.OnClose        replaced by whoever opens a menu; starts as a no-op
--
-- spec   = { title, subtitle, options = { option, ... } }
-- option = { label, desc, value, price, disabled,
--            action = fn(option) | submenu = spec | fn() -> spec,
--            close = true (close after the action), reopen = false (no redraw) }

PupMenu = {}
PupMenu.OnClose = function() end

local resName = GetCurrentResourceName()
local levels = {}
local generation = 0

local function token()
    return ('%s:pupmenu:%d'):format(resName, generation)
end

local function top()
    return levels[#levels]
end

local function draw()
    local level = top()
    if not level then return end
    local rows = {}
    for i, opt in ipairs(level.options or {}) do
        rows[i] = {
            label = opt.label,
            desc = opt.desc,
            value = opt.value,
            price = opt.price,
            disabled = opt.disabled,
        }
    end
    exports['pup-ui']:OpenListMenu({
        owner = token(),
        title = level.title,
        subtitle = level.subtitle,
        options = rows,
    })
end

local function finish()
    levels = {}
    local cb = PupMenu.OnClose
    if type(cb) == 'function' then
        local ok, err = pcall(cb)
        if not ok then print(('^1[%s/pupmenu]^7 OnClose: %s'):format(resName, tostring(err))) end
    end
end

function PupMenu.Open(spec)
    generation = generation + 1
    levels = { spec }
    draw()
end

function PupMenu.Push(spec)
    if #levels == 0 then return PupMenu.Open(spec) end
    levels[#levels + 1] = spec
    draw()
end

function PupMenu.Pop()
    if #levels == 0 then return end
    levels[#levels] = nil
    if #levels > 0 then
        draw()
    else
        exports['pup-ui']:HideListMenu()
        finish()
    end
end

function PupMenu.Close()
    if #levels == 0 then return end
    exports['pup-ui']:HideListMenu()
    finish()
end

function PupMenu.Refresh(spec)
    if #levels == 0 then return end
    if spec then levels[#levels] = spec end
    draw()
end

function PupMenu.IsOpen()
    return #levels > 0
end

AddEventHandler('pup-ui:client:listSelect', function(index, owner)
    if owner ~= token() then return end
    local level = top()
    if not level then return end
    local opt = (level.options or {})[tonumber(index) or -1]
    if not opt or opt.disabled then
        draw()
        return
    end
    if opt.submenu then
        local sub = opt.submenu
        if type(sub) == 'function' then sub = sub() end
        if sub then PupMenu.Push(sub) else draw() end
        return
    end
    local before = generation
    if type(opt.action) == 'function' then opt.action(opt) end
    if opt.close then
        PupMenu.Close()
    elseif opt.reopen ~= false and #levels > 0 and generation == before then
        draw()
    end
end)

AddEventHandler('pup-ui:client:listBack', function(owner)
    if owner ~= token() then return end
    PupMenu.Pop()
end)

AddEventHandler('pup-ui:client:listClosed', function(owner)
    if owner ~= nil and owner ~= token() then return end
    if #levels > 0 then finish() end
end)
