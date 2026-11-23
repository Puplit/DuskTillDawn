-- local MenuData compatibility layer backed by pup-ui
--   TriggerEvent('menuapi:getData', cb) -> cb(MenuData-compatible table)
--   MenuData.Open('default', res, ns, data, submit [, cancel]) -> menu
--     data    = { title, subtext, align, elements, lastmenu }
--     element = { label, value, desc } or { type='slider', min, max, hop }
-- submit(data, menu): data.current = the element (value updated for sliders)

local session = nil -- { owner, data, elements, submit, cancel, index, menu }
local seq = 0

-- strip HTML -> plain text for display (labels/desc were built as HTML)
local function plain(s)
    if type(s) ~= 'string' then
        if s == nil then return nil end
        return tostring(s)
    end
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
            vals[#vals + 1] = math.floor((mn + i * hop) * 1000 + 0.5) / 1000
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
        if d < bestd then bestd, best = d, i end
    end
    return best
end

local function buildRows(s)
    local rows = {}
    for i, el in ipairs(s.elements) do
        -- prefer descText, the short plain line, over the HTML side-panel text
        local d = plain(el.descText or el.desc)
        if d == '' then d = nil end
        local row = { label = plain(el.label) or '', description = d }
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

-- `silent` = programmatic close used as a TRANSITION between menus
local function closeSession(silent)
    if session == nil then return end
    session = nil
    exports['pup-ui']:HideInkMenu()
    if not silent then TriggerEvent('menuapi:closemenu') end
end

local function makeMenu(s)
    local m = { data = { elements = s.elements } }
    function m.close() closeSession(false) end
    function m.refresh() if session == s then rerender(s) end end
    function m.setElement(index, key, value)
        local el = s.elements[index]
        if el then el[key] = value end
    end
    function m.removeElementByIndex(index) table.remove(s.elements, index) end
    function m.addNewElement(el) s.elements[#s.elements + 1] = el end
    return m
end

local MenuCompat = {}

function MenuCompat.Open(_type, _res, _ns, data, submit, cancel)
    data = data or {}
    seq = seq + 1
    local elements = {}
    for i, el in ipairs(data.elements or {}) do elements[i] = el end
    local s = {
        owner = ('pup-doorlocks:menucompat:%d'):format(seq),
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

function MenuCompat.CloseAll() closeSession(true) end
function MenuCompat.GetOpened() return session and session.menu or nil end
function MenuCompat.call() end -- defensive stub for stray callers

-- this copy is for doorlocks only (MenuData is set from it below): it does not answer menuapi:getData /
-- vorp_menu:getData, so other scripts always get pup-ui's full vorp_menu-compatible MenuData

-- export, vorp_core:GetCore() style

-- InkMenu event bridge (owner-token filtered)
AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if not session or owner ~= session.owner then return end
    session.index = index
end)

-- submit/cancel receive the original data table with .current set on it
local function submitPayload(s, current)
    s.data.current = current
    s.data.elements = s.elements
    return s.data
end

AddEventHandler('pup-ui:client:inkChange', function(index, valueIndex, owner)
    if not session or owner ~= session.owner then return end
    local s = session
    s.index = index
    local el = s.elements[index]
    if not el then return end
    if el.type == 'slider' then
        local vals = sliderValues(el)
        if vals[valueIndex] ~= nil then el.value = vals[valueIndex] end
    end
    if s.submit then s.submit(submitPayload(s, el), s.menu) end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, valueIndex, owner)
    if not session or owner ~= session.owner then return end
    local s = session
    s.index = index
    local el = s.elements[index]
    if not el then return end
    if el.type == 'slider' and valueIndex then
        local vals = sliderValues(el)
        if vals[valueIndex] ~= nil then el.value = vals[valueIndex] end
    end
    if s.submit then s.submit(submitPayload(s, el), s.menu) end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if not session or owner ~= session.owner then return end
    local s = session
    if s.cancel then
        s.data.trigger = s.data.lastmenu
        s.cancel(submitPayload(s, 'backup'), s.menu)
        return
    end
    if s.data.lastmenu and s.submit then
        s.data.trigger = s.data.lastmenu
        s.submit(submitPayload(s, 'backup'), s.menu)
        return
    end
    closeSession()
end)

-- pup-ui's own menucompat already answers this event, and client events reach EVERY resource

-- local MenuData for this resource, a copy of pup-ui/client/menucompat.lua
MenuData = MenuCompat
