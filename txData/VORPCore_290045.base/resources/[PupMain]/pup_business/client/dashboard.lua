-- pup_business | the management dashboard (a pup-ui app)
-- The server sends only what the viewer may see; tabs follow the same rules.

local OWNER <const> = 'pup_business:dash'

local D = nil          -- latest dashboard data
local tab = 'overview'
local tabsKey = ''
local armedBill = nil  -- bill id waiting for "Confirm Delete?"
local mail = { state = nil }

local TAB_DEFS <const> = {
    { id = 'overview',  label = 'Overview',  icon = 'chart' },
    { id = 'employees', label = 'Employees', icon = 'users' },
    { id = 'ranks',     label = 'Ranks',     icon = 'medal' },
    { id = 'ledger',    label = 'Ledger',    icon = 'coins' },
    { id = 'bills',     label = 'Bills',     icon = 'doc' },
    { id = 'storage',   label = 'Storage',   icon = 'box' },
    { id = 'mail',      label = 'Mail',      icon = 'mail' },
}

local PERM_LABELS <const> = {
    hire = 'Hire', fire = 'Fire', setranks = 'Set Ranks', managepay = 'Manage Pay',
    stash = 'Open Storage', store = 'Manage Storage', billing = 'Billing', mail = 'Mail',
}

local function full(d) return d.isBoss or d.admin end

local function tabVisible(d, id)
    local p = d.perms or {}
    if full(d) then return true end
    if id == 'overview' then return true end
    if id == 'employees' then return p.hire or p.fire or p.setranks end
    if id == 'ranks' then return p.setranks and p.managepay end
    if id == 'ledger' then return p.managepay end
    if id == 'bills' then return p.billing end
    if id == 'storage' then return p.stash or p.store or d.grade >= (d.invaccess or 0) end
    if id == 'mail' then return p.mail end
    return false
end

local function visibleTabs(d)
    local out, keys = {}, {}
    for _, t in ipairs(TAB_DEFS) do
        if tabVisible(d, t.id) then
            out[#out + 1] = { id = t.id, label = t.label, icon = t.icon }
            keys[#keys + 1] = t.id
        end
    end
    return out, table.concat(keys, ',')
end

---------------------------------------------------------------------------
-- tab contents
---------------------------------------------------------------------------

local function overview(d)
    local stats = {
        { value = tostring(d.counts.employees), label = 'Employees' },
        { value = ('%d / %d'):format(d.counts.onduty, d.counts.online), label = 'On Duty / Online' },
    }
    if d.ledger then stats[#stats + 1] = { value = PB.money(d.ledger), label = 'Ledger Balance' } end
    if d.bills then stats[#stats + 1] = { value = tostring(#d.bills.list), label = 'Open Bills' } end
    local blocks = {
        { type = 'heading', text = 'Overview', sub = ('%s at a glance'):format(d.name) },
        { type = 'stats', items = stats },
    }
    if d.ledger then
        local cols = { { value = PB.money(d.ledger), label = 'Balance' } }
        if d.bills then cols[#cols + 1] = { value = PB.money(d.bills.total), label = 'Bills Outstanding' } end
        blocks[#blocks + 1] = { type = 'glance', title = 'Ledger', cols = cols, link = { text = 'View Ledger', id = 'gotoLedger' } }
    end
    return blocks
end

local function canTouch(d, m)
    if m.self then return false end
    if full(d) then return true end
    return m.grade < d.grade
end

local function employees(d)
    local p = d.perms or {}
    local members = d.members or {}
    local blocks = {
        { type = 'heading', text = ('Employees (%d)'):format(#members),
          sub = 'Offline members are listed too, and firing works while they are offline.' },
    }
    if p.hire then
        blocks[#blocks + 1] = { type = 'actions', buttons = { { id = 'hire', label = 'Hire Nearby Player', tone = 'green' } } }
    end
    local items = {}
    for _, m in ipairs(members) do
        local sub = { ('Grade %d'):format(m.grade) }
        if m.onduty then sub[#sub + 1] = 'ON DUTY' elseif m.online then sub[#sub + 1] = 'ONLINE' end
        if m.online and m.id then sub[#sub + 1] = ('ID %d'):format(m.id) end
        local actions = {}
        if canTouch(d, m) then
            if p.setranks and m.grade + 1 < d.grade then
                actions[#actions + 1] = { id = 'emp:promote:' .. m.charid, label = 'Promote', tone = 'green' }
            end
            if p.setranks and m.grade > 0 then
                actions[#actions + 1] = { id = 'emp:demote:' .. m.charid, label = 'Demote', tone = 'ghost' }
            end
            if p.fire then
                actions[#actions + 1] = { id = 'emp:fire:' .. m.charid, label = 'Fire', tone = 'red' }
            end
        end
        items[#items + 1] = {
            title = m.self and (m.name .. ' (you)') or m.name,
            sub = table.concat(sub, '  -  '),
            actions = actions,
        }
    end
    if #items == 0 then items[1] = { title = 'No members yet.' } end
    blocks[#blocks + 1] = { type = 'list', items = items }
    return blocks
end

local function ranks(d)
    local sub = ('Salaries go up to %s per tick.'):format(PB.money(d.maxSalary))
    if d.taxOn then
        sub = sub .. ' A tax of 0 means none. Changing a tax amount or period restarts that grade\'s cycle from today.'
    end
    local permKeys = {}
    for _, k in ipairs(PB.PERM_KEYS) do permKeys[#permKeys + 1] = { key = k, label = PERM_LABELS[k] } end
    local p = d.perms or {}
    local cards = {}
    for _, r in ipairs(d.ranks or {}) do
        local title, note
        if r.grade >= d.bossrank then
            title = ('Grade %d - Boss'):format(r.grade)
            note = 'Full authority - every permission is always on.'
        else
            title = r.grade == d.recruit and ('Grade %d - Recruiter'):format(r.grade) or ('Grade %d'):format(r.grade)
            note = ('Pays %s per salary tick.'):format(PB.money(r.salary))
            if d.taxOn then
                note = note .. (r.tax > 0 and (' Owes %s %s.'):format(PB.money(r.tax), r.taxperiod) or ' No tax.')
            end
        end
        cards[#cards + 1] = {
            id = r.grade, title = title, note = note, salary = r.salary,
            tax = r.tax, taxperiod = r.taxperiod,
            editable = d.isBoss or d.admin or (p.setranks and p.managepay and r.grade < d.grade) or false,
            perms = r.perms,
        }
    end
    return {
        { type = 'heading', text = 'Ranks & Permissions', sub = sub },
        { type = 'ranks', permKeys = permKeys, tax = d.taxOn == true, ranks = cards },
    }
end

local function ledger(d)
    local p = d.perms or {}
    local buttons = { { id = 'deposit', label = 'Deposit', tone = 'green' } }
    if d.isBoss or p.managepay then buttons[#buttons + 1] = { id = 'withdraw', label = 'Withdraw', tone = 'red' } end
    if d.isBoss then
        buttons[#buttons + 1] = { id = 'webhook', label = 'Set Webhook', tone = 'ghost' }
        if d.hasWebhook then buttons[#buttons + 1] = { id = 'webhookClear', label = 'Clear Webhook', tone = 'ghost' } end
    end
    return {
        { type = 'heading', text = 'Ledger', sub = 'The business account. Salaries are paid from here.' },
        { type = 'stats', items = {
            { value = PB.money(d.ledger or 0), label = 'Balance' },
            { value = PB.money(d.payroll or 0), label = 'Payroll Per Tick' },
            { value = tostring(d.counts.employees), label = 'Employees' },
        } },
        { type = 'actions', buttons = buttons },
    }
end

local function bills(d)
    local list = d.bills and d.bills.list or {}
    local p = d.perms or {}
    local items = {}
    for _, b in ipairs(list) do
        local actions = {}
        if d.isBoss or p.billing then
            if armedBill == b.id then
                actions = {
                    { id = 'bill:confirm:' .. b.id, label = 'Confirm Delete?', tone = 'red' },
                    { id = 'bill:cancel', label = 'Cancel', tone = 'ghost' },
                }
            else
                actions = { { id = 'bill:del:' .. b.id, label = 'Delete', tone = 'ghost' } }
            end
        end
        items[#items + 1] = {
            title = ('%s - %s'):format(b.debtor, PB.money(b.amount)),
            sub = ('Bill #%d - issued by %s'):format(b.id, b.issuer),
            actions = actions,
        }
    end
    if #items == 0 then items[1] = { title = 'No outstanding bills.' } end
    return {
        { type = 'heading', text = ('Bills (%d)'):format(#list),
          sub = ('%s outstanding'):format(PB.money(d.bills and d.bills.total or 0)) },
        { type = 'list', items = items },
    }
end

local function storage(d)
    local p = d.perms or {}
    local buttons = {}
    if d.isBoss or p.stash or d.grade >= (d.invaccess or 0) then
        buttons[#buttons + 1] = { id = 'stash', label = 'Open Stash', tone = 'green' }
    end
    if d.isBoss or p.store then
        buttons[#buttons + 1] = { id = 'access', label = 'Set Access Rank', tone = 'ghost' }
        local price = PB.money(d.slotPrice):gsub('%.00$', '')
        buttons[#buttons + 1] = { id = 'buySlots', label = ('Buy Slots (%s each)'):format(price), tone = 'ghost' }
    end
    local blocks = {
        { type = 'heading', text = 'Storage', sub = d.stashName },
        { type = 'stats', items = {
            { value = tostring(d.base + d.bought), label = 'Total Slots' },
            { value = tostring(d.bought), label = 'Purchased Slots' },
            { value = ('Grade %d+'):format(d.invaccess or 0), label = 'Stash Access' },
        } },
    }
    if #buttons > 0 then blocks[#blocks + 1] = { type = 'actions', buttons = buttons } end
    return blocks
end

local function mailTab(d)
    local head = { type = 'heading', text = 'Mail', sub = 'Your business PO box: letters sent to it reach the business, and members with the Mail permission can sign for it.' }
    if GetResourceState('pup_postoffice') ~= 'started' then
        return { head, { type = 'list', items = { { title = 'The mail resource is not running.' } } } }
    end
    local st = mail.state
    if st == nil then
        return { head, { type = 'list', items = { { title = 'Reading...' } } } }
    end
    if type(st) == 'table' and st.token then
        local blocks = {
            head,
            { type = 'stats', items = {
                { value = tostring(st.handle or '-'), label = 'PO Address' },
                { value = tostring(st.name or d.name), label = 'Signed As' },
            } },
        }
        if d.isBoss then
            local label = 'Change PO Address'
            local cost = tonumber(st.changeCost)
            if cost and cost > 0 then label = ('%s (%s from the ledger)'):format(label, PB.money(cost)) end
            blocks[#blocks + 1] = { type = 'actions', buttons = { { id = 'mailChange', label = label, tone = 'ghost' } } }
        end
        return blocks
    end
    if d.isBoss then
        return { head, { type = 'actions', buttons = { { id = 'mailRegister', label = 'Register PO Box', tone = 'green' } } } }
    end
    return { head, { type = 'list', items = { { title = 'The owner has not registered a PO box yet.' } } } }
end

local RENDER <const> = {
    overview = overview, employees = employees, ranks = ranks, ledger = ledger,
    bills = bills, storage = storage, mail = mailTab,
}

---------------------------------------------------------------------------
-- opening and refreshing
---------------------------------------------------------------------------

local handlers

local function badge(d)
    return ('%s - GRADE %d'):format(d.isBoss and 'BOSS' or 'MEMBER', d.grade)
end

local function openApp()
    local tabs, key = visibleTabs(D)
    tabsKey = key
    UI.OpenApp(OWNER, {
        title = tostring(D.name):upper(),
        subtitle = 'MANAGEMENT',
        badge = badge(D),
        tabs = tabs,
        active = tab,
        content = RENDER[tab](D),
    }, handlers)
end

local function redraw()
    if not D or not UI.AppOpen(OWNER) then return end
    UI.UpdateApp(OWNER, { active = tab, content = RENDER[tab](D) })
end

local function apply(d)
    D = d
    if not tabVisible(D, tab) then tab = 'overview' end
    local _, key = visibleTabs(D)
    if key ~= tabsKey then
        openApp()
    else
        redraw()
    end
end

local function refresh()
    CreateThread(function()
        local d = Call('dash')
        if not UI.AppOpen(OWNER) then return end
        -- nil = throttled or timed out: keep what is on screen
        if d == nil then return end
        if d == false or type(d) ~= 'table' then
            -- no longer in a business: nothing here applies any more
            D = nil
            UI.CloseApp(true)
            return
        end
        apply(d)
    end)
end

local function askMail()
    if GetResourceState('pup_postoffice') ~= 'started' then return end
    mail.state = nil
    TriggerServerEvent('mail:business:request')
end

-- shows an input in place of the app, then brings the app back
local function withInput(def)
    local after = def.after
    def.after = function()
        if after then after() end
        if D then
            openApp()
            SetTimeout(600, refresh)
        end
    end
    UI.Input(def)
end

local function memberById(charid)
    for _, m in ipairs(D and D.members or {}) do
        if m.charid == charid then return m end
    end
    return nil
end

local function call(name, ...)
    local args = table.pack(...)
    CreateThread(function()
        Call(name, table.unpack(args, 1, args.n))
        refresh()
    end)
end

local function numberInput(title, label, default, fn)
    withInput({
        title = title,
        fields = { { label = label, type = 'number', default = default, required = true } },
        onDone = function(v)
            local n = tonumber(v and v[1])
            if not n then return Tip(L('invalid_amount')) end
            fn(math.floor(n))
        end,
    })
end

local function onAction(id, data)
    if not D then return end
    if id == 'gotoLedger' then
        if tabVisible(D, 'ledger') then handlers.nav('ledger') end
        return
    end

    local kind, verb, arg = id:match('^(%a+):(%a+):?(%d*)$')
    if kind == 'emp' then
        local m = memberById(tonumber(arg))
        if not m then return end
        if verb == 'promote' then call('setRank', m.charid, m.grade + 1)
        elseif verb == 'demote' then call('setRank', m.charid, m.grade - 1)
        elseif verb == 'fire' then call('fire', m.charid) end
        return
    elseif kind == 'bill' then
        if verb == 'del' then armedBill = tonumber(arg); redraw()
        elseif verb == 'cancel' then armedBill = nil; redraw()
        elseif verb == 'confirm' and tonumber(arg) == armedBill then
            armedBill = nil
            call('deleteBill', tonumber(arg))
        end
        return
    end

    if id == 'rankSave' then
        call('rankSave', {
            id = tonumber(data.id), salary = tonumber(data.salary), perms = data.perms,
            tax = data.tax ~= nil and tonumber(data.tax) or nil, taxperiod = data.taxperiod,
        })
    elseif id == 'hire' then
        local near = ClosestPlayer(Config.HirePrefillDistance)
        numberInput('Hire', 'Server ID', near, function(n) call('hire', n) end)
    elseif id == 'deposit' then
        numberInput('Deposit', 'Amount ($)', nil, function(n) call('deposit', n) end)
    elseif id == 'withdraw' then
        numberInput('Withdraw', 'Amount ($)', nil, function(n) call('withdraw', n) end)
    elseif id == 'webhook' then
        withInput({
            title = 'Set Webhook', subtitle = 'A Discord webhook link. Use Clear Webhook to switch logs off.',
            fields = { { label = 'Webhook Link', type = 'text', maxlength = 200 } },
            onDone = function(v)
                local url = v and v[1]
                if type(url) == 'string' and url ~= '' then call('setWebhook', url) end
            end,
        })
    elseif id == 'webhookClear' then
        call('setWebhook', '')
    elseif id == 'stash' then
        D = nil
        UI.CloseApp(true)
        Send('openStash')
    elseif id == 'access' then
        numberInput('Set Access Rank', ('Grade (0 - %d)'):format(D.bossrank), D.invaccess or 0, function(n)
            if n < 0 or n > D.bossrank then return Tip(L('invalid_grade')) end
            call('setAccess', n)
        end)
    elseif id == 'buySlots' then
        numberInput('Buy Slots', L('slots_amount', D.slotPrice), nil, function(n) call('buySlots', n) end)
    elseif id == 'mailRegister' or id == 'mailChange' then
        local register = id == 'mailRegister'
        withInput({
            title = register and 'Register PO Box' or 'Change PO Address',
            subtitle = 'Three letters then three numbers, for example val556.',
            fields = { { label = 'PO Address', type = 'text', maxlength = 6, required = true } },
            onDone = function(v)
                local text = type(v and v[1]) == 'string' and v[1]:lower():gsub('%s', '') or ''
                if text == '' then return end
                TriggerServerEvent(register and 'mail:business:register' or 'mail:business:setHandle', text)
                SetTimeout(1200, askMail)
            end,
        })
    end
end

handlers = {
    nav = function(t)
        if not D or not tabVisible(D, t) then return end
        tab = t
        armedBill = nil
        if t == 'mail' then askMail() end
        redraw()
        refresh()
    end,
    action = onAction,
    closed = function()
        D = nil
        armedBill = nil
    end,
}

function OpenDashboard(data)
    if type(data) ~= 'table' then return end
    D = data
    tab = 'overview'
    armedBill = nil
    mail.state = nil
    openApp()
end

RegisterNetEvent('mail:business:state', function(state)
    mail.state = type(state) == 'table' and state or false
    if tab == 'mail' then redraw() end
end)

AddEventHandler('pup_business:client:refreshDashboard', function()
    if UI.AppOpen(OWNER) then refresh() end
end)
