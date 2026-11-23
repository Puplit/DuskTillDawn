-- pup_business | the in-world admin app, opened from vorp_admin's panel
-- The server answers panel admins only and re-checks every action.

local OWNER <const> = 'pup_business:admin'

local A = nil              -- { list, now, management }
local tab = 'overview'
local view = 'list'        -- businesses tab: list | detail | audit | employees | shops
local sel = nil            -- selected job
local shops = { job = nil, data = nil }

local TABS <const> = {
    { id = 'overview',   label = 'Overview',   icon = 'chart' },
    { id = 'businesses', label = 'Businesses', icon = 'box' },
    { id = 'activity',   label = 'Activity',   icon = 'doc' },
}

local function onOff(v) return v and 'on' or 'off' end

local function here()
    local p = GetEntityCoords(PlayerPedId())
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0 }
end

local function selected()
    if not A or not sel then return nil end
    for _, b in ipairs(A.list) do
        if b.job == sel then return b end
    end
    return nil
end

local function display(b) return (b.name ~= nil and b.name ~= '') and b.name or b.job end

local function nowTs() return (A and A.now) or 0 end

---------------------------------------------------------------------------
-- activity tables
---------------------------------------------------------------------------

local TYPE_TONE <const> = { DEPOSIT = 'badge-green', WITHDRAW = 'badge-red' }

local function allActivity()
    local rows = {}
    for _, b in ipairs(A and A.list or {}) do
        for _, a in ipairs(b.activity or {}) do
            rows[#rows + 1] = { ts = a.ts, type = a.type, detail = a.detail, actor = a.actor, job = b.job }
        end
    end
    table.sort(rows, function(x, y) return (x.ts or 0) > (y.ts or 0) end)
    return rows
end

local function activityTable(title, rows, limit, withBusiness, perPage)
    local cols = {
        { key = 'when', label = 'When' }, { key = 'type', label = 'Type' },
        { key = 'detail', label = 'Detail' }, { key = 'by', label = 'By' },
    }
    if withBusiness then cols[#cols + 1] = { key = 'biz', label = 'Business' } end
    local out = {}
    for i, r in ipairs(rows) do
        if limit and i > limit then break end
        out[#out + 1] = { cells = {
            when = { text = PB.ago(r.ts, nowTs()), tone = 'muted' },
            type = { text = tostring(r.type or ''), tone = TYPE_TONE[r.type] or 'badge-neutral' },
            detail = { text = tostring(r.detail or '') },
            by = { text = tostring(r.actor or '') },
            biz = { text = tostring(r.job or '') },
        } }
    end
    return { type = 'table', title = title, columns = cols, rows = out, perPage = perPage }
end

---------------------------------------------------------------------------
-- pages
---------------------------------------------------------------------------

local function overviewPage()
    local staff, blipsShown, ledger = 0, 0, 0
    for _, b in ipairs(A.list) do
        staff = staff + (b.staffcount or 0)
        if b.showblip then blipsShown = blipsShown + #(b.positions or {}) end
        ledger = ledger + (b.ledger or 0)
    end
    return {
        { type = 'heading', text = 'Overview', sub = 'Every business on the server.' },
        { type = 'stats', items = {
            { value = tostring(#A.list), label = 'Businesses' },
            { value = tostring(staff), label = 'Total Staff' },
            { value = tostring(blipsShown), label = 'Blips Shown' },
            { value = PB.money(ledger), label = 'Combined Ledger' },
        } },
        activityTable('Latest Activity', allActivity(), 8, true),
    }
end

local function activityPage()
    return {
        { type = 'heading', text = 'Server Activity', sub = 'The newest entries across all businesses.' },
        activityTable('Server Activity', allActivity(), 40, true, 10),
    }
end

local function listPage()
    local items = {}
    for _, b in ipairs(A.list) do
        items[#items + 1] = {
            title = ('%s (%s)'):format(display(b), b.job),
            sub = ('Ledger %s  |  Staff %d  |  Container #%s  |  Last active %s'):format(
                PB.money(b.ledger or 0), b.staffcount or 0, tostring(b.containerid or '-'), PB.ago(b.lastactive, nowTs())),
            actions = { { id = 'manage:' .. b.job, label = 'Manage', tone = 'ghost' } },
        }
    end
    items[#items + 1] = {
        title = 'Create Business',
        sub = 'Places the first blip and job-menu point where you stand.',
        actions = { { id = 'create', label = 'Create', tone = 'green' } },
    }
    return {
        { type = 'heading', text = 'Businesses', sub = ('%d registered'):format(#A.list) },
        { type = 'list', items = items },
    }
end

local function detailPage(b)
    local items = {
        { title = 'Storage', sub = ('%s  -  container #%s  -  access grade %d+'):format(b.containername, tostring(b.containerid or '-'), b.invaccess or 0) },
        { title = 'Blip', sub = ('%s  -  sprite %s  -  %d blip point(s), %d menu point(s)'):format(
            b.showblip and 'shown' or 'hidden', tostring(b.blipsprite), #(b.positions or {}), #(b.jobmenu or {})) },
        { title = 'Flags', sub = ('billing %s  -  salary %s  -  webhook %s  -  recruiter grade %d'):format(
            onOff(b.billing), onOff(b.salary), onOff(b.webhook), b.recruitmentrank or 0) },
    }
    local fields = {
        { key = 'name', label = 'Display name', value = b.name },
        { key = 'containername', label = 'Storage name', value = b.containername },
        { key = 'blipsprite', label = 'Blip sprite', value = tostring(b.blipsprite) },
        { key = 'bossrank', label = 'Boss rank', value = tostring(b.bossrank) },
        { key = 'recruitmentrank', label = 'Recruiter rank', value = tostring(b.recruitmentrank) },
    }
    local editItems = {}
    for _, f in ipairs(fields) do
        editItems[#editItems + 1] = { title = f.label, sub = tostring(f.value or ''), actions = { { id = 'edit:' .. f.key, label = 'Edit', tone = 'ghost' } } }
    end
    for _, t in ipairs({ { 'showblip', 'Show blip' }, { 'billing', 'Billing' }, { 'salary', 'Salary' }, { 'webhook', 'Webhook logs' }, { 'tax', 'Tax' } }) do
        local on = b[t[1]] == true
        editItems[#editItems + 1] = { title = t[2], sub = on and 'On' or 'Off',
            actions = { { id = 'toggle:' .. t[1], label = on and 'Turn Off' or 'Turn On', tone = on and 'red' or 'green' } } }
    end
    return {
        { type = 'heading', text = ('%s (%s)'):format(display(b), b.job), sub = b.owner and ('Owner: %s'):format(b.owner) or 'No owner at the boss grade' },
        { type = 'stats', items = {
            { value = PB.money(b.ledger or 0), label = 'Ledger' },
            { value = tostring(b.staffcount or 0), label = 'Employees' },
            { value = tostring(b.bossrank), label = 'Boss Rank' },
            { value = PB.ago(b.lastactive, nowTs()), label = 'Last Active' },
        } },
        { type = 'list', items = items },
        { type = 'actions', buttons = {
            { id = 'addBlip', label = 'Add Blip Here', tone = 'ghost' },
            { id = 'addMenu', label = 'Add Job-Menu Point Here', tone = 'ghost' },
            { id = 'clearLoc', label = 'Clear All Locations', tone = 'red' },
        } },
        { type = 'list', items = editItems },
        { type = 'actions', buttons = {
            { id = 'page:employees', label = 'Employees', tone = 'ghost' },
            { id = 'page:audit', label = 'Audit Trail', tone = 'ghost' },
            { id = 'page:shops', label = 'Society Shops', tone = 'ghost' },
            { id = 'back', label = 'Back' },
        } },
        { type = 'list', items = { {
            title = 'Delete Business',
            sub = 'Releases every member to unemployed, then removes the storage and its contents, the ledger, bills, ranks, tax records, history and society shops. Asks you to type DELETE.',
            actions = { { id = 'delete', label = 'Delete', tone = 'red' } },
        } } },
    }
end

local function auditPage(b)
    local actors, users = {}, 0
    for _, a in ipairs(b.activity or {}) do
        local key = a.actor or ''
        if key ~= '' then
            if not actors[key] then actors[key] = { n = 0, last = 0 }; users = users + 1 end
            actors[key].n = actors[key].n + 1
            if (a.ts or 0) > actors[key].last then actors[key].last = a.ts end
        end
    end
    local who = {}
    for name, v in pairs(actors) do who[#who + 1] = { name = name, n = v.n, last = v.last } end
    table.sort(who, function(x, y) return x.last > y.last end)
    local whoRows = {}
    for _, w in ipairs(who) do
        whoRows[#whoRows + 1] = { cells = {
            name = { text = w.name }, events = { text = tostring(w.n) }, seen = { text = PB.ago(w.last, nowTs()), tone = 'muted' },
        } }
    end
    local roster = {}
    for _, s in ipairs(b.staff or {}) do
        roster[#roster + 1] = { cells = {
            name = { text = s.name },
            grade = { text = tostring(s.grade) },
            boss = s.grade >= b.bossrank and { text = 'BOSS', tone = 'badge-red' } or { text = '' },
            charid = { text = tostring(s.charid or '-'), copy = true },
            discord = { text = s.discord or 'not linked', copy = s.discord ~= nil },
        } }
    end
    local points = #(b.positions or {}) + #(b.jobmenu or {})
    return {
        { type = 'heading', text = ('Audit Trail - %s'):format(b.job),
          sub = ('Container #%s  -  owner grade %d  -  access grade %d+'):format(tostring(b.containerid or '-'), b.bossrank, b.invaccess or 0) },
        { type = 'stats', items = {
            { value = b.owner or '-', label = 'Owner' },
            { value = tostring((b.baseSlots or 0) + (b.boughtslots or 0)), label = 'Slots' },
            { value = PB.ago(b.lastactive, nowTs()), label = 'Last Active' },
            { value = PB.money(b.ledger or 0), label = 'Ledger Now' },
        } },
        { type = 'stats', items = {
            { value = tostring(#(b.activity or {})), label = 'Logged Events' },
            { value = tostring(users), label = 'Active Users' },
            { value = tostring(b.staffcount or 0), label = 'Employees' },
            { value = tostring(points), label = 'Map Points' },
        } },
        { type = 'table', title = 'Who Has Been Active', columns = {
            { key = 'name', label = 'Name' }, { key = 'events', label = 'Events' }, { key = 'seen', label = 'Last Seen' },
        }, rows = whoRows },
        { type = 'table', title = 'Current Roster', columns = {
            { key = 'name', label = 'Name' }, { key = 'grade', label = 'Grade' }, { key = 'boss', label = '' },
            { key = 'charid', label = 'Char ID' }, { key = 'discord', label = 'Discord' },
        }, rows = roster, perPage = 10 },
        activityTable('Full History', b.activity or {}, nil, false, 10),
        { type = 'actions', buttons = { { id = 'back', label = 'Back' } } },
    }
end

local function employeesPage(b)
    local items = {}
    for _, s in ipairs(b.staff or {}) do
        items[#items + 1] = {
            title = s.name,
            sub = ('Grade %d%s  -  Char #%s  -  Discord %s'):format(s.grade, s.grade >= b.bossrank and ' (Boss)' or '',
                tostring(s.charid or '-'), s.discord or 'not linked'),
            actions = {
                { id = 'emp:rank:' .. tostring(s.charid), label = 'Set Rank', tone = 'ghost' },
                { id = 'emp:fire:' .. tostring(s.charid), label = 'Fire', tone = 'red' },
            },
        }
    end
    if #items == 0 then items[1] = { title = 'No staff.' } end
    items[#items + 1] = { title = 'Hire by server ID', actions = { { id = 'hireById', label = 'Hire', tone = 'green' } } }
    items[#items + 1] = { title = 'Set MY rank', sub = ('Put yourself in %s at any grade 0 - %d.'):format(b.job, b.bossrank),
        actions = { { id = 'myRank', label = 'Set', tone = 'ghost' } } }
    return {
        { type = 'heading', text = ('Employees - %s'):format(display(b)), sub = ('%d on the books'):format(b.staffcount or 0) },
        { type = 'list', items = items },
        { type = 'actions', buttons = { { id = 'back', label = 'Back' } } },
    }
end

local function coordsText(c)
    if type(c) == 'string' then
        local ok, v = pcall(json.decode, c)
        c = ok and v or nil
    end
    if type(c) ~= 'table' then return '-' end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not x then return '-' end
    return ('%.1f, %.1f, %.1f'):format(x, y, z or 0)
end

local function shopsPage(b)
    local head = { type = 'heading', text = ('Society Shops - %s'):format(display(b)), sub = 'pup_mercantile shop fronts of this business.' }
    local back = { type = 'actions', buttons = { { id = 'shopsRefresh', label = 'Refresh', tone = 'ghost' }, { id = 'back', label = 'Back' } } }
    local data = shops.job == b.job and shops.data or nil
    if not data then return { head, { type = 'list', items = { { title = 'Loading shops...' } } }, back } end
    if not data.ready then return { head, { type = 'list', items = { { title = 'Shops unavailable', sub = 'pup_mercantile is not running.' } } }, back } end
    local list = data.shops or {}
    if #list == 0 then return { head, { type = 'list', items = { { title = 'No shops' } } }, back } end
    local items, active = {}, 0
    for _, s in ipairs(list) do
        local on = PB.bool(s.enabled)
        if on then active = active + 1 end
        local id = tostring(s.id)
        items[#items + 1] = {
            title = ('#%s %s'):format(id, tostring(s.name or '')),
            sub = ('%s  -  min grade %s  -  blip %s  -  %s slots  -  %s items, %s weapons  -  %s'):format(
                on and 'Active' or 'DISABLED', tostring(s.rank or 0), onOff(PB.bool(s.blip)), tostring(s.slots or 0),
                tostring(s.items or 0), tostring(s.weapons or 0), coordsText(s.coords)),
            actions = {
                { id = (on and 'shop:disable:' or 'shop:enable:') .. id, label = on and 'Disable' or 'Enable', tone = on and 'red' or 'green' },
                { id = 'shop:rename:' .. id, label = 'Rename', tone = 'ghost' },
                { id = 'shop:rank:' .. id, label = 'Rank', tone = 'ghost' },
                { id = 'shop:blip:' .. id, label = PB.bool(s.blip) and 'Blip Off' or 'Blip On', tone = 'ghost' },
                { id = 'shop:move:' .. id, label = 'Move Here', tone = 'ghost' },
                { id = 'shop:delete:' .. id, label = 'Delete', tone = 'red' },
            },
        }
    end
    return {
        head,
        { type = 'stats', items = { { value = tostring(#list), label = 'Shops' }, { value = tostring(active), label = 'Active' } } },
        { type = 'list', items = items },
        back,
    }
end

local function content()
    if not A then return { { type = 'heading', text = 'Loading...' } } end
    if tab == 'overview' then return overviewPage() end
    if tab == 'activity' then return activityPage() end
    local b = selected()
    if view == 'list' or not b then view = 'list'; return listPage() end
    if view == 'audit' then return auditPage(b) end
    if view == 'employees' then return employeesPage(b) end
    if view == 'shops' then return shopsPage(b) end
    return detailPage(b)
end

---------------------------------------------------------------------------
-- app plumbing
---------------------------------------------------------------------------

local handlers

local function openApp()
    UI.OpenApp(OWNER, {
        title = 'SOCIETIES', subtitle = 'ADMINISTRATION', badge = 'SOCIETY ADMIN',
        tabs = TABS, active = tab, content = content(),
    }, handlers)
end

local function redraw()
    if not UI.AppOpen(OWNER) then return end
    UI.UpdateApp(OWNER, { active = tab, content = content() })
end

local function withInput(def)
    local after = def.after
    def.after = function()
        if after then after() end
        if A then openApp() end
    end
    UI.Input(def)
end

local function textInput(title, label, default, max, fn)
    withInput({
        title = title,
        fields = { { label = label, type = 'text', default = default, maxlength = max or 100, required = true } },
        onDone = function(v)
            local s = v and v[1]
            if type(s) == 'string' and s ~= '' then fn(s) end
        end,
    })
end

local function numberInput(title, label, default, fn)
    withInput({
        title = title,
        fields = { { label = label, type = 'number', default = default, required = true } },
        onDone = function(v)
            local n = tonumber(v and v[1])
            if n then fn(math.floor(n)) end
        end,
    })
end

local function update(job, changes) TriggerServerEvent('pup_business:admin:update', job, changes) end

local function askShops(job)
    shops.job, shops.data = job, nil
    TriggerServerEvent('pup_business:admin:shops', job)
end

local function shopAction(b, verb, id)
    local shopId = tonumber(id)
    if not shopId then return end
    local job = b.job
    if verb == 'enable' or verb == 'disable' then
        TriggerServerEvent('pup_business:admin:shopAction', job, shopId, verb, nil)
    elseif verb == 'rename' then
        textInput('Rename Shop', 'Name', nil, 50, function(s)
            TriggerServerEvent('pup_business:admin:shopAction', job, shopId, 'rename', s)
        end)
    elseif verb == 'rank' then
        numberInput('Shop Rank', 'Minimum grade (0 - 100)', 0, function(n)
            TriggerServerEvent('pup_business:admin:shopAction', job, shopId, 'rank', math.max(0, math.min(n, 100)))
        end)
    elseif verb == 'blip' then
        local on = false
        for _, s in ipairs(shops.data and shops.data.shops or {}) do
            if tonumber(s.id) == shopId then on = PB.bool(s.blip) end
        end
        TriggerServerEvent('pup_business:admin:shopAction', job, shopId, 'blip', not on)
    elseif verb == 'move' then
        TriggerServerEvent('pup_business:admin:shopAction', job, shopId, 'move', here())
    elseif verb == 'delete' then
        textInput('Delete Shop', 'Type DELETE to confirm', nil, 10, function(s)
            if s == 'DELETE' then TriggerServerEvent('pup_business:admin:shopAction', job, shopId, 'delete', nil) end
        end)
    end
end

local function onAction(id, _)
    if not A then return end
    local parts = {}
    for p in id:gmatch('[^:]+') do parts[#parts + 1] = p end
    local head = parts[1]

    if head == 'manage' then
        sel, view = parts[2], 'detail'
        return redraw()
    elseif head == 'create' then
        withInput({
            title = 'Create Business',
            subtitle = 'The first blip and job-menu point go where you stand.',
            fields = {
                { label = 'Job code (a-z, 0-9, _)', type = 'text', maxlength = 50, required = true },
                { label = 'Display name', type = 'text', maxlength = 100 },
                { label = 'Boss rank', type = 'number', default = 3, min = 1, max = 100, required = true },
            },
            onDone = function(v)
                local job = PB.jobCode(v and v[1] or '')
                if job == '' then return Tip(L('admin_bad_job')) end
                local name = type(v[2]) == 'string' and v[2] ~= '' and v[2] or job
                local p = here()
                TriggerServerEvent('pup_business:admin:create', {
                    job = job, name = name, bossrank = math.max(1, math.floor(tonumber(v[3]) or 1)),
                    positions = { p }, jobmenu = { p },
                })
            end,
        })
        return
    elseif head == 'back' then
        if view == 'detail' then view, sel = 'list', nil else view = 'detail' end
        return redraw()
    elseif head == 'shopsRefresh' then
        if sel then askShops(sel) end
        return redraw()
    end

    local b = selected()
    if not b then return end

    if head == 'page' then
        view = parts[2]
        if view == 'shops' then askShops(b.job) end
        redraw()
    elseif head == 'addBlip' then
        local list = { table.unpack(b.positions or {}) }
        list[#list + 1] = here()
        update(b.job, { positions = list })
    elseif head == 'addMenu' then
        local list = { table.unpack(b.jobmenu or {}) }
        list[#list + 1] = here()
        update(b.job, { jobmenu = list })
    elseif head == 'clearLoc' then
        update(b.job, { positions = {}, jobmenu = {} })
    elseif head == 'edit' then
        local key = parts[2]
        if key == 'name' or key == 'containername' then
            textInput(key == 'name' and 'Display name' or 'Storage name', 'Name', b[key], 100, function(s)
                update(b.job, { [key] = s })
            end)
        elseif key == 'blipsprite' or key == 'bossrank' or key == 'recruitmentrank' then
            numberInput(key == 'blipsprite' and 'Blip sprite' or key == 'bossrank' and 'Boss rank' or 'Recruiter rank',
                'Value', b[key], function(n) update(b.job, { [key] = n }) end)
        end
    elseif head == 'toggle' then
        local key = parts[2]
        update(b.job, { [key] = not (b[key] == true) })
    elseif head == 'delete' then
        textInput('Delete Business', ('Type DELETE to remove %s'):format(b.job), nil, 10, function(s)
            if s == 'DELETE' then
                TriggerServerEvent('pup_business:admin:delete', b.job)
                view, sel = 'list', nil
            end
        end)
    elseif head == 'emp' then
        local charid = tonumber(parts[3])
        if not charid then return end
        if parts[2] == 'rank' then
            numberInput('Set Rank', ('Grade (0 - %d)'):format(b.bossrank), 0, function(n)
                TriggerServerEvent('pup_business:admin:setSelfRank', b.job, n, charid)
            end)
        elseif parts[2] == 'fire' then
            TriggerServerEvent('pup_business:fire', charid, b.job)
            SetTimeout(800, function() CreateThread(function() local r = Call('adminOverview') if r then A = r; redraw() end end) end)
        end
    elseif head == 'hireById' then
        numberInput('Hire', 'Server ID', nil, function(n)
            TriggerServerEvent('pup_business:hire', n, b.job)
            SetTimeout(800, function() CreateThread(function() local r = Call('adminOverview') if r then A = r; redraw() end end) end)
        end)
    elseif head == 'myRank' then
        numberInput('Set MY rank', ('Grade (0 - %d)'):format(b.bossrank), b.bossrank, function(n)
            TriggerServerEvent('pup_business:admin:setSelfRank', b.job, n, nil)
        end)
    elseif head == 'shop' then
        shopAction(b, parts[2], parts[3])
    end
end

handlers = {
    nav = function(t)
        for _, x in ipairs(TABS) do
            if x.id == t then
                tab = t
                if t == 'businesses' and view ~= 'list' and not selected() then view = 'list' end
                redraw()
                CreateThread(function()
                    local r = Call('adminOverview')
                    if r and UI.AppOpen(OWNER) then A = r; redraw() end
                end)
                return
            end
        end
    end,
    action = onAction,
    closed = function()
        A = nil
    end,
}

AddEventHandler('pup_business:openAdminTool', function()
    CreateThread(function()
        local r = Call('adminOverview')
        if type(r) ~= 'table' then return end
        A = r
        tab, view, sel = 'overview', 'list', nil
        openApp()
    end)
end)

RegisterNetEvent('pup_business:adminData', function(r)
    if type(r) ~= 'table' or not UI.AppOpen(OWNER) then
        if type(r) == 'table' and A then A = r end
        return
    end
    A = r
    if view ~= 'list' and not selected() then view, sel = 'list', nil end
    redraw()
end)

RegisterNetEvent('pup_business:adminShops', function(job, data)
    if type(data) ~= 'table' then return end
    shops.job, shops.data = job, data
    if UI.AppOpen(OWNER) and tab == 'businesses' and view == 'shops' then redraw() end
end)
