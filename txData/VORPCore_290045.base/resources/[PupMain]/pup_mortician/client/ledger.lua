-- pup_mortician | the Undertaker's Ledger, drawn by pup-ui's App panel.
-- Every string goes to pup-ui as data; pup-ui writes it with textContent.

Ledger = { open = false, key = nil, tab = 'table', seq = 0, inputPending = nil, boss = false }

local OWNER <const> = RES

-- a small coffin, drawn here as SVG (no shipped art)
local COFFIN_SVG <const> = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'>"
    .. "<path d='M24 3h16l9 15-7 43H22L15 18z' fill='#6b4a2b' stroke='#2b1d10' stroke-width='2'/>"
    .. "<path d='M32 17v20M25 24h14' stroke='#d8c39a' stroke-width='3' stroke-linecap='round'/></svg>"
local COFFIN_IMG <const> = 'data:image/svg+xml;charset=utf-8,'
    .. COFFIN_SVG:gsub('[^%w%-_%.~]', function(c) return ('%%%02X'):format(c:byte()) end)

local function tabsFor(data)
    local tabs = { { id = 'table', label = L('tabTable'), icon = 'box' } }
    if data.contracts then tabs[#tabs + 1] = { id = 'board', label = L('tabBoard'), icon = 'flag' } end
    tabs[#tabs + 1] = { id = 'register', label = L('tabRegister'), icon = 'doc' }
    if data.business and data.business.boss then tabs[#tabs + 1] = { id = 'business', label = L('tabBusiness'), icon = 'coins' } end
    return tabs
end

local function allowed(tab, data)
    if tab == 'table' or tab == 'register' then return true end
    if tab == 'board' then return data.contracts == true end
    if tab == 'business' then return data.business and data.business.boss == true end
    return false
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------
local function tableTab(data)
    local sub
    if data.left <= 0 and data.reopen then
        sub = L('noBuriesUntil', data.reopen)
    else
        sub = L('buriesLeft', data.left, data.limit)
    end
    local out = { { type = 'heading', text = data.town, sub = sub } }
    local st = data.table or { state = 'empty' }

    if st.state == 'empty' then
        local carrying = CarriedCorpse() ~= nil
        out[#out + 1] = { type = 'note', text = carrying and L('emptyCarrying') or L('emptyHint') }
        if carrying then
            out[#out + 1] = { type = 'actions', buttons = { { id = 'lay', label = L('btnLayDown'), tone = 'red' } } }
        end
        return out
    end

    local open = st.state == 'open'
    out[#out + 1] = {
        type = 'hero', img = COFFIN_IMG,
        title = st.deceased or L('unknownSoul'),
        sub = open and L('subOpen') or L('subClosed'),
        tags = { data.mine and L('tagMine') or L('tagOther') },
    }

    if open then
        local items, missing = {}, false
        for _, g in ipairs(data.goods or {}) do
            local have = g.laid and g.amount or math.min(g.held or 0, g.amount)
            if not g.laid then missing = true end
            items[#items + 1] = {
                img = Config.ItemImages .. tostring(g.item) .. '.png',
                label = g.label,
                have = have, need = g.amount,
                note = ('%d / %d  -  %s'):format(have, g.amount, g.laid and L('laidIn') or L('bonus', g.bonus or 0)),
            }
        end
        out[#out + 1] = { type = 'bill', items = items }
        if data.mine then
            local buttons = {}
            if missing then buttons[#buttons + 1] = { id = 'layin', label = L('btnLayIn'), tone = 'green' } end
            buttons[#buttons + 1] = { id = 'close', label = L('btnClose'), tone = missing and 'ghost' or 'red' }
            out[#out + 1] = { type = 'actions', buttons = buttons }
            if missing then out[#out + 1] = { type = 'note', text = L('warnEarly') } end
        end
    elseif data.mine then
        out[#out + 1] = { type = 'actions', buttons = { { id = 'carry', label = L('btnCarry'), tone = 'red' } } }
    end
    return out
end

local function boardTab(data)
    local out = { { type = 'heading', text = L('boardHeading'), sub = L('boardSub') } }
    local board = data.board or {}
    if #board == 0 then
        out[#out + 1] = { type = 'note', text = L('boardEmpty') }
        return out
    end
    local holdsHere = false
    for _, p in ipairs(board) do if p.mine then holdsHere = true end end
    local items = {}
    for _, p in ipairs(board) do
        local parts = { p.cause }
        if (p.bodies or 1) > 1 then parts[#parts + 1] = L('bodies', p.bodies) end
        if data.travel and p.town then parts[#parts + 1] = p.town end
        if p.mine and p.left then
            parts[#parts + 1] = L('timeLeft', math.floor(p.left / 60), p.left % 60)
        elseif p.taken then
            parts[#parts + 1] = L('taken')
        end
        local actions = {}
        if p.mine then
            actions[1] = { id = 'giveup', label = L('btnGiveUp'), tone = 'ghost' }
        elseif not p.taken and not holdsHere then
            actions[1] = { id = 'take:' .. tostring(p.id), label = L('btnTake'), tone = 'red' }
        end
        items[#items + 1] = {
            title = (p.mine and '\u{2605} ' or '') .. tostring(p.name),
            sub = table.concat(parts, '  \u{00B7}  '),
            actions = actions,
        }
    end
    out[#out + 1] = { type = 'list', items = items }
    return out
end

local function registerTab(data)
    local out = { { type = 'heading', text = L('registerHeading'), sub = L('registerSub') } }
    local rows = data.register or {}
    if #rows == 0 then
        out[#out + 1] = { type = 'note', text = L('registerEmpty') }
        return out
    end
    local tableRows = {}
    for _, r in ipairs(rows) do
        tableRows[#tableRows + 1] = { cells = {
            when = { text = r.when, tone = 'muted' },
            deceased = { text = r.deceased },
            cause = { text = (r.cause and r.cause ~= '') and r.cause or '-', tone = 'muted' },
            undertaker = { text = r.undertaker },
            paid = { text = ('$%d'):format(r.paid or 0) },
            place = { text = r.place, tone = 'muted' },
        } }
    end
    out[#out + 1] = {
        type = 'table', perPage = 10,
        columns = {
            { key = 'when', label = L('colWhen') }, { key = 'deceased', label = L('colDeceased') },
            { key = 'cause', label = L('colCause') }, { key = 'undertaker', label = L('colUndertaker') },
            { key = 'paid', label = L('colPaid') }, { key = 'place', label = L('colWhere') },
        },
        rows = tableRows,
    }
    return out
end

local function businessTab(data)
    local b = data.business or {}
    local out = {
        { type = 'heading', text = L('businessHeading'), sub = L('businessSub') },
        { type = 'stats', items = {
            { value = ('%d%%'):format(b.cut or 0), label = L('statCut') },
            { value = b.webhook and L('on') or L('off'), label = L('statReports') },
        } },
        { type = 'actions', buttons = {
            { id = 'setcut', label = L('btnSetCut'), tone = 'ghost' },
            { id = 'hook', label = L('btnWebhook'), tone = 'ghost' },
        } },
    }
    local sum = b.summary or {}
    if #sum > 0 then
        local rows = {}
        for _, s in ipairs(sum) do
            rows[#rows + 1] = { cells = {
                undertaker = { text = s.undertaker },
                burials = { text = tostring(s.burials) },
                paid = { text = ('$%d'):format(s.paid or 0) },
                house = { text = ('$%d'):format(s.house or 0) },
            } }
        end
        out[#out + 1] = {
            type = 'table', title = L('last7'), perPage = 8,
            columns = {
                { key = 'undertaker', label = L('colUndertaker') }, { key = 'burials', label = L('colBurials') },
                { key = 'paid', label = L('colPaid') }, { key = 'house', label = L('colHouse') },
            },
            rows = rows,
        }
    end
    return out
end

local BUILDERS <const> = { table = tableTab, board = boardTab, register = registerTab, business = businessTab }

---------------------------------------------------------------------------
-- Open / refresh / close
---------------------------------------------------------------------------
local function fetch(tab)
    Ledger.seq = Ledger.seq + 1
    local seq = Ledger.seq
    local res = Act('ledger', { key = Ledger.key, tab = tab })
    if seq ~= Ledger.seq then return nil, true end -- a newer request superseded this one
    if not res.ok and res.quiet then
        -- probably the rate limit after a quick tab switch: one more try
        Wait(Config.RateLimit.ledger + 50)
        if seq ~= Ledger.seq then return nil, true end
        res = Act('ledger', { key = Ledger.key, tab = tab })
        if seq ~= Ledger.seq then return nil, true end
    end
    return res, false
end

function Ledger.Close()
    if not Ledger.open then return end
    Ledger.open = false
    Ledger.seq = Ledger.seq + 1
    pcall(function() exports['pup-ui']:CloseApp() end)
end

-- a real refusal closes the panel with its reason; a quiet one (rate limit,
-- timeout) leaves whatever is on screen alone
local function refused(res)
    if res.quiet then return end
    Say(res)
    Ledger.Close()
    Ledger.key = nil
end

-- opens (or reopens) the panel for a table on a tab
function Ledger.Open(key, tab)
    Ledger.key = key
    tab = tab or 'table'
    local res, stale = fetch(tab)
    if stale then return end
    if not res.ok or type(res.data) ~= 'table' then return refused(res) end
    local data = res.data
    Ledger.data = data
    if not allowed(tab, data) then tab = 'table' end
    Ledger.tab = tab
    Ledger.boss = data.business and data.business.boss == true
    Ledger.open = true
    exports['pup-ui']:OpenApp({
        owner = OWNER,
        title = L('ledgerTitle'),
        subtitle = data.town,
        tabs = tabsFor(data),
        active = tab,
        content = BUILDERS[tab](data),
    })
end

function Ledger.Refresh(tab)
    if not Ledger.open or not Ledger.key then return end
    tab = tab or Ledger.tab
    local res, stale = fetch(tab)
    if stale or not Ledger.open then return end
    if not res.ok or type(res.data) ~= 'table' then return refused(res) end
    local data = res.data
    Ledger.data = data
    if not allowed(tab, data) then
        tab = 'table'
        if Ledger.tab ~= 'table' then
            -- the allowed tabs changed underneath us: rebuild the whole panel
            return Ledger.Open(Ledger.key, 'table')
        end
    end
    Ledger.tab = tab
    exports['pup-ui']:UpdateApp({ active = tab, content = BUILDERS[tab](data) })
end

function Ledger.IsOpen()
    return Ledger.open or Ledger.inputPending ~= nil
end

---------------------------------------------------------------------------
-- pup-ui events
---------------------------------------------------------------------------
AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER or not Ledger.open then return end
    if type(tab) ~= 'string' or not BUILDERS[tab] then tab = 'table' end
    CreateThread(function() Ledger.Refresh(tab) end)
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= OWNER then return end
    if Ledger.inputPending then
        -- the input dialog replaced the panel; it comes back when the input closes
        Ledger.open = false
        return
    end
    Ledger.open = false
    Ledger.key = nil
    Ledger.seq = Ledger.seq + 1
end)

local function openInput(kind)
    local key = Ledger.key
    if not key then return end
    Ledger.inputPending = { kind = kind, key = key }
    if kind == 'cut' then
        -- the last data the server sent; the server checks again on save
        local b = (Ledger.data and Ledger.data.business) or {}
        if not b.boss then
            Ledger.inputPending = nil
            Tip(L('onlyOwner'))
            return
        end
        exports['pup-ui']:OpenInput({
            owner = OWNER, title = L('cutTitle'), subtitle = L('cutSub', b.max or 0), submit = L('save'),
            fields = { { label = L('cutField'), type = 'number', required = true, default = b.cut or 0, min = 0, max = b.max or 0 } },
        })
    else
        exports['pup-ui']:OpenInput({
            owner = OWNER, title = L('hookTitle'), subtitle = L('hookSub'), submit = L('save'),
            fields = { { label = L('hookField'), type = 'text', placeholder = L('hookPlaceholder'), maxlength = 250 } },
        })
    end
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER or not Ledger.inputPending then return end
    local pending = Ledger.inputPending
    CreateThread(function()
        if type(values) == 'table' then
            local v = values[1]
            local res
            if pending.kind == 'cut' then
                res = Act('setCut', { key = pending.key, value = tonumber(v) })
            else
                res = Act('setWebhook', { key = pending.key, url = type(v) == 'string' and v or '' })
            end
            Say(res)
        end
        Ledger.inputPending = nil
        Ledger.Open(pending.key, 'business')
    end)
end)

local function runAction(action)
    local key = Ledger.key
    if not key then return end
    if action == 'lay' then
        Work.LayBody(key)
    elseif action == 'layin' then
        local wanted = {}
        local st = TableStates[key]
        if st and st.wanted then
            local laid = {}
            for _, i in ipairs(st.laid or {}) do laid[i] = true end
            for _, i in ipairs(st.wanted) do if not laid[i] then wanted[#wanted + 1] = i end end
        end
        local res = Act('layin', { key = key, goods = wanted })
        Say(res)
        if res.ok then
            Ledger.Close()
            Busy = true
            Work.Prepare(res.count or 1)
            Busy = false
            Ledger.Open(key, 'table')
            return
        end
    elseif action == 'close' then
        Say(Act('close', { key = key }))
    elseif action == 'carry' then
        Ledger.Close()
        Carry.Start(key)
        return
    elseif action == 'giveup' then
        Say(Act('giveup', {}))
        RefreshStatus()
    elseif action:sub(1, 5) == 'take:' then
        local id = tonumber(action:sub(6))
        if id then
            Say(Act('take', { key = key, id = id }))
            RefreshStatus()
        end
    elseif action == 'setcut' then
        return openInput('cut')
    elseif action == 'hook' then
        return openInput('hook')
    else
        return
    end
    Ledger.Refresh()
end

local acting = false
AddEventHandler('pup-ui:client:appAction', function(owner, action)
    if owner ~= OWNER or not Ledger.open or type(action) ~= 'string' or acting then return end
    acting = true
    CreateThread(function()
        local ok, err = pcall(runAction, action)
        if not ok then print(('[%s] ledger action failed: %s'):format(RES, tostring(err))) end
        acting = false
    end)
end)
