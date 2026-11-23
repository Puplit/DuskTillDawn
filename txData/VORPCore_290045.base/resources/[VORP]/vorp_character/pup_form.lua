-- Modified by Puppet (Dusk Till Dawn), 2026
-- pup-ui shim for the legacy focused-menu global: Form.Open / Form.CloseAll plus a
-- `menu` object. Stock labels are HTML, so plain() strips tags for display only.

local RES = GetCurrentResourceName()

Form = {}

local session = nil -- { owner, data, elements, submit, cancel, index, menu }
local seq = 0

-- strip HTML -> plain text for InkMenu display (labels/desc are built as HTML)
local function plain(s)
    if type(s) ~= 'string' then
        if s == nil then return nil end
        return tostring(s)
    end
    -- turn structural HTML into line breaks BEFORE stripping the rest
    s = s:gsub('<%s*[bB][rR]%s*/?%s*>', '\n')      -- <br>  -> newline
    s = s:gsub('</%s*[tT][hH]%s*>', ' ')           -- </th> -> gap between label and value
    s = s:gsub('</%s*[tT][rR]%s*>', '\n')          -- </tr> -> newline (one row per line)
    s = s:gsub('</%s*[pP]%s*>', '\n')              -- </p>  -> newline
    s = s:gsub('</%s*[dD][iI][vV]%s*>', '\n')      -- </div>-> newline
    s = s:gsub('</%s*[lL][iI]%s*>', '\n')          -- </li> -> newline
    s = s:gsub('<[^>]*>', '')                       -- strip all remaining tags
    s = s:gsub('&nbsp;', ' ')
    s = s:gsub('&amp;', '&')
    s = s:gsub('\r', '')
    s = s:gsub('[ \t]+', ' ')                       -- collapse runs of spaces
    s = s:gsub(' *\n *', '\n')                      -- trim spaces around newlines
    s = s:gsub('\n\n\n+', '\n\n')                   -- at most one blank line
    s = s:gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s
end

-- discrete value list for a slider element from min/max/hop
local function sliderValues(el)
    local mn = tonumber(el.min) or 0
    local mx = tonumber(el.max) or 0
    local hop = tonumber(el.hop) or 1
    if hop == 0 then hop = 1 end
    local vals = {}
    if mx < mn then
        vals[1] = mn
    else
        local n = math.floor((mx - mn) / hop + 0.5)
        for i = 0, n do
            local v = mn + i * hop
            v = math.floor(v * 1000 + 0.5) / 1000 -- kill float drift
            vals[#vals + 1] = v
        end
    end
    return vals
end

local function indexForValue(el, vals)
    local target = tonumber(el.value)
    if target == nil then return 1 end
    local best, bestd = 1, math.huge
    for i, v in ipairs(vals) do
        local d = math.abs(v - target)
        if d < bestd then
            bestd = d
            best = i
        end
    end
    return best
end

-- the creator attaches a reference picture to nearly every row
local function imageOf(desc)
    if type(desc) ~= 'string' then return nil end
    local src = desc:match("<%s*[iI][mM][gG][^>]-src%s*=%s*'([^']+)'")
        or desc:match('<%s*[iI][mM][gG][^>]-src%s*=%s*"([^"]+)"')
    return src
end

-- off by default: most rows carry the same generic sketch, which covers the character preview
local function imagesWanted()
    return Config and Config.FormRowImages == true
end

local function buildRows(s)
    local rows = {}
    local wantImage = imagesWanted()
    for i, el in ipairs(s.elements) do
        local d = plain(el.desc)
        if d == '' then d = nil end
        local row = { label = plain(el.label) or '', description = d,
            image = wantImage and imageOf(el.desc) or nil }
        if el.type == 'slider' then
            local vals = sliderValues(el)
            row.values = vals
            row.valueIndex = indexForValue(el, vals)
        end
        rows[i] = row
    end
    return rows
end

local function rerender(s)
    if session ~= s then return end
    exports['pup-ui']:OpenInkMenu({
        owner = s.owner,
        title = plain(s.data.title) or '',
        subtitle = plain(s.data.subtext),
        startIndex = s.index or 1,
        options = buildRows(s),
    })
end

local function closeSession()
    if session == nil then return end
    session = nil
    exports['pup-ui']:HideInkMenu()
    -- same events stock vorp_menu fires on close, so existing listeners still run
    TriggerEvent('menuapi:closemenu')
    TriggerEvent('vorp_menu:closemenu')
end

local function makeMenu(s)
    local m = { data = { elements = s.elements } }

    function m.close()
        closeSession()
    end

    function m.refresh()
        if session == s then rerender(s) end
    end

    function m.setElement(index, key, value)
        local el = s.elements[index]
        if el then el[key] = value end
    end

    function m.removeElementByIndex(index)
        table.remove(s.elements, index)
    end

    function m.addNewElement(el)
        s.elements[#s.elements + 1] = el
    end

    -- yes/no confirmation dialog -> pup-ui focused select input
    function m.displayInput(cfg, cb)
        cfg = cfg or {}
        local owner = RES .. ':dispinput:' .. tostring(GetGameTimer())
        local ev
        ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
            if o ~= owner then return end
            RemoveEventHandler(ev)
            local yes = values ~= nil and tostring(values[1]) == 'yes'
            if cb then cb(yes) end
        end)
        local confirmLabel = (cfg.buttons and cfg.buttons.confirm) or 'Yes'
        local cancelLabel = (cfg.buttons and cfg.buttons.cancel) or 'No'
        exports['pup-ui']:OpenInput({
            owner = owner,
            title = plain(cfg.header) or 'Confirm',
            subtitle = plain(cfg.description),
            submit = confirmLabel,
            fields = {
                {
                    label = plain(cfg.description) or plain(cfg.header) or 'Confirm',
                    type = 'select',
                    required = true,
                    options = {
                        { label = confirmLabel, value = 'yes' },
                        { label = cancelLabel,  value = 'no' },
                    },
                },
            },
        })
    end

    return m
end

-- Open a menu
function Form.Open(_type, _res, namespace, data, submit, cancel)
    data = data or {}
    seq = seq + 1

    local elements = {}
    for i, el in ipairs(data.elements or {}) do
        elements[i] = el
    end
    if data.confirmButton then
        elements[#elements + 1] = { label = data.confirmButton.label, value = data.confirmButton.value }
    end
    if data.cancelButton then
        elements[#elements + 1] = { label = data.cancelButton.label, value = data.cancelButton.value }
    end

    local s = {
        owner = RES .. ':form:' .. seq,
        namespace = namespace,
        data = data,
        elements = elements,
        submit = submit,
        cancel = cancel,
        index = 1,
    }
    s.menu = makeMenu(s)
    session = s
    rerender(s)
    return s.menu
end

function Form.CloseAll()
    closeSession()
end

function Form.IsOpen()
    return session ~= nil
end

-- InkMenu event bridge (all filtered by the per-menu owner token)
AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if not session or owner ~= session.owner then return end
    session.index = index
end)

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if not session or owner ~= session.owner then return end
    local s = session
    s.index = index
    local el = s.elements[index]
    if not el then return end
    el.index = index
    if el.type == 'slider' then
        local vals = sliderValues(el)
        local v = vals[valueIndex]
        if v ~= nil then el.value = v end
    end
    if s.submit then s.submit({ current = el }, s.menu) end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, valueIndex, owner)
    if not session or owner ~= session.owner then return end
    local s = session
    s.index = index
    local el = s.elements[index]
    if not el then return end
    el.index = index
    if el.type == 'slider' and valueIndex then
        local vals = sliderValues(el)
        local v = vals[valueIndex]
        if v ~= nil then el.value = v end
    end
    if s.submit then s.submit({ current = el }, s.menu) end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if not session or owner ~= session.owner then return end
    local s = session
    -- an explicit cancel callback (6th arg of Form.Open) wins
    if s.cancel then
        s.cancel({ current = 'backup', trigger = s.data.lastmenu }, s.menu)
        return
    end
    -- otherwise reproduce back-nav when the menu declared a parent
    if s.data.lastmenu and s.submit then
        s.submit({ current = 'backup', trigger = s.data.lastmenu }, s.menu)
        return
    end
    -- noClose menus (character selection) swallow ESC and redraw, or the player is stranded
    if s.data.noClose then
        rerender(s)
        return
    end
    -- root menu with no parent: ESC closes it
    closeSession()
end)
