-- pup_mercantile | the management dashboard (pup-ui "app" panel)
-- Every figure shown here comes from the server; every action is re-checked there.

local OWNER <const> = 'pup_mercantile'
local PAGE <const> = 25
local IMG <const> = 'nui://vorp_inventory/html/img/items/%s.png'

local L = Util.L
local UI = exports['pup-ui']

Dash = {
    open = false,   -- the app is on screen
    kind = nil, id = nil,
    tab = 'overview',
    data = nil,     -- last shop data from the server
    search = '',
    page = 1,
    input = nil,    -- { kind, ctx } while a pup-ui input replaces the app
    asked = 0,      -- GetGameTimer() of the last data request
}

local function money(n) return '$' .. Util.fmt(n) end

------------------------------------------------------------------------------
-- tab contents
------------------------------------------------------------------------------
local function overview(d)
    local blocks = {}
    if d.kind == 'player' then
        blocks[#blocks + 1] = { type = 'heading', text = L('ovHeading', d.name, d.id), sub = L('ovSub') }
        blocks[#blocks + 1] = { type = 'stats', items = {
            { value = money(d.ledger), label = L('ovLedger') },
            { value = ('%s / %s'):format(money(d.taxledger), money(d.taxCap)), label = L('ovTax') },
            { value = tostring(d.slots), label = L('ovSlots') },
            { value = tostring(#d.buyitems), label = L('ovListings') },
        } }
        blocks[#blocks + 1] = { type = 'actions', buttons = {
            { id = 'deposit', label = L('btnDeposit'), tone = 'green' },
            { id = 'withdraw', label = L('btnWithdraw'), tone = 'red' },
            { id = 'tax', label = L('btnDepositTax') },
        } }
        blocks[#blocks + 1] = { type = 'note', text = L('ovTaxNote', Util.fmt(d.taxCap)) }
    else
        blocks[#blocks + 1] = { type = 'heading', text = L('ovHeading', d.name, d.id), sub = L('ovSub') }
        blocks[#blocks + 1] = { type = 'stats', items = {
            { value = tostring(d.society), label = L('ovSociety') },
            { value = tostring(d.rank), label = L('ovRank') },
            { value = tostring(d.slots), label = L('ovSlots') },
            { value = tostring(#d.buyitems), label = L('ovListings') },
        } }
    end
    return blocks
end

local function sortedBuyList(d)
    local list = {}
    for _, b in ipairs(d.buyitems or {}) do list[#list + 1] = b end
    table.sort(list, function(a, b) return Util.naturalLess(a.label, b.label) end)
    return list
end

local function stockTab(d)
    local blocks = {
        { type = 'heading', text = L('stHeading'), sub = L('stSub') },
        { type = 'actions', buttons = { { id = 'grid', label = L('btnOpenGrid'), tone = 'green' } } },
    }
    local list = sortedBuyList(d)
    if #list == 0 then
        blocks[#blocks + 1] = { type = 'note', text = L('stEmpty') }
        return blocks
    end
    local items = {}
    for _, b in ipairs(list) do
        items[#items + 1] = {
            title = L('stListing', b.label, Util.fmt(b.price)),
            sub = L('stWanted', b.amount),
            img = IMG:format(b.name),
            actions = {
                { id = 'edit:' .. b.name, label = L('btnManageListing') },
                { id = 'rm:' .. b.name, label = L('btnRemoveListing'), tone = 'red' },
            },
        }
    end
    blocks[#blocks + 1] = { type = 'list', items = items }
    return blocks
end

local function filteredCatalogue()
    local out = {}
    local needle = Dash.search:lower()
    for _, e in ipairs(St.catalogue or {}) do
        if needle == '' or tostring(e.l):lower():find(needle, 1, true) then out[#out + 1] = e end
    end
    return out
end

local function addTab()
    local list = filteredCatalogue()
    local total = #list
    local pages = math.max(1, math.ceil(total / PAGE))
    if Dash.page > pages then Dash.page = pages end
    if Dash.page < 1 then Dash.page = 1 end
    local first = (Dash.page - 1) * PAGE + 1
    local last = math.min(total, first + PAGE - 1)
    local blocks = {
        { type = 'heading', text = L('addHeading'), sub = total > 0 and L('addRange', first, last, total) or L('addRange', 0, 0, 0) },
        { type = 'search', id = 'search', value = Dash.search, placeholder = L('addSearch') },
        { type = 'actions', buttons = {
            { id = 'clear', label = L('btnClear'), tone = 'ghost' },
            { id = 'prev', label = L('btnPrev'), tone = 'ghost' },
            { id = 'next', label = L('btnNext'), tone = 'ghost' },
        } },
    }
    if total == 0 then
        blocks[#blocks + 1] = { type = 'note', text = L('addNone') }
        return blocks
    end
    local items = {}
    for i = first, last do
        local e = list[i]
        items[#items + 1] = {
            title = e.l, sub = e.n, img = IMG:format(e.n),
            actions = { { id = 'add:' .. e.n, label = L('btnAddItem'), tone = 'green' } },
        }
    end
    blocks[#blocks + 1] = { type = 'list', items = items }
    return blocks
end

local function settingsTab(d)
    local tiles = {
        { value = money(d.slotPrice), label = L('setSlotCost') },
        { value = '$' .. Util.fmtThousands(d.movePrice), label = L('setMoveCost') },
        { value = tostring(d.blip), label = L('setBlip') },
    }
    if d.kind == 'player' then
        tiles[#tiles + 1] = { value = d.managerName or L('setNone'), label = L('setManager') }
    end
    local buttons = {
        { id = 'rename', label = L('btnName') },
        { id = 'blip', label = L('btnBlip') },
        { id = 'slots', label = L('btnSlots') },
        { id = 'move', label = L('btnMove') },
    }
    if d.webhooks then buttons[#buttons + 1] = { id = 'webhook', label = L('btnWebhook') } end
    if d.kind == 'society' and d.isBoss then buttons[#buttons + 1] = { id = 'rank', label = L('btnRank') } end
    if d.kind == 'player' and d.isOwner then
        buttons[#buttons + 1] = { id = 'setmgr', label = L('btnSetManager') }
        if (tonumber(d.manager) or 0) ~= 0 then
            buttons[#buttons + 1] = { id = 'rmmgr', label = L('btnRemoveManager'), tone = 'red' }
        end
    end
    return {
        { type = 'heading', text = L('setHeading'), sub = L('setSub') },
        { type = 'stats', items = tiles },
        { type = 'actions', buttons = buttons },
    }
end

local function content()
    local d = Dash.data
    if not d then return {} end
    if Dash.tab == 'stock' then return stockTab(d) end
    if Dash.tab == 'add' then return addTab() end
    if Dash.tab == 'settings' then return settingsTab(d) end
    return overview(d)
end

local function render()
    local d = Dash.data
    if not d or Dash.input then return end
    if Dash.open then
        UI:UpdateApp({ active = Dash.tab, content = content() })
        return
    end
    UI:OpenApp({
        owner = OWNER,
        title = tostring(d.name):upper(),
        subtitle = L('dashSubtitle'),
        badge = d.kind == 'society' and L('dashSociety') or L('dashOwner'),
        tabs = {
            { id = 'overview', label = L('tabOverview'), icon = 'home' },
            { id = 'stock', label = L('tabStock'), icon = 'box' },
            { id = 'add', label = L('tabAdd'), icon = 'doc' },
            { id = 'settings', label = L('tabSettings'), icon = 'key' },
        },
        active = Dash.tab,
        content = content(),
    })
    Dash.open = true
end

local function request()
    Dash.asked = GetGameTimer()
    TriggerServerEvent('pup_mercantile:dash:get')
end

------------------------------------------------------------------------------
-- open / close
------------------------------------------------------------------------------
function OpenDashboard(kind, id, tab)
    Dash.kind, Dash.id = kind, id
    Dash.tab = tab or 'overview'
    Dash.data = nil
    Dash.input = nil
    request()
    local asked = Dash.asked
    SetTimeout(6000, function()
        -- no answer: do not leave the player frozen
        if Dash.asked == asked and not Dash.data and not Dash.open and St.inStore then LeaveEverything(false) end
    end)
end

function CloseDashboard()
    Dash.input = nil
    if Dash.open then
        Dash.open = false
        UI:CloseApp()
    end
    Dash.data = nil
end

RegisterNetEvent('pup_mercantile:dash:data', function(d)
    if type(d) ~= 'table' then
        if Dash.open or (St.inStore and Dash.kind) then
            CloseDashboard()
            LeaveEverything(true)
        end
        return
    end
    local v = St.venue
    if not v or v.kind ~= d.kind or v.id ~= d.id or St.gridOpen or St.moveMode then return end
    if type(d.buyitems) ~= 'table' then d.buyitems = {} end
    Dash.data = d
    render()
end)

------------------------------------------------------------------------------
-- inputs (they replace the app; it comes back on the same tab afterwards)
------------------------------------------------------------------------------
local function ask(kind, ctx, title, fields)
    Dash.input = { kind = kind, ctx = ctx }
    local ok = UI:OpenInput({ owner = OWNER, title = title, submit = L('inConfirm'), fields = fields })
    if ok == false then Dash.input = nil end
end

local function amountField(default)
    return { label = L('inAmount'), type = 'number', default = default, min = 0, required = true }
end

local function priceField(default)
    return { label = L('inPrice'), type = 'number', default = default, min = 0, required = true }
end

local function bad(key) TriggerEvent('vorp:TipBottom', L(key), 4000) end

local handlers = {}

function handlers.deposit(_, vals)
    local n = Util.money(vals[1])
    if not n then return bad('clientBadAmount') end
    TriggerServerEvent('pup_mercantile:dash:deposit', n)
end

function handlers.withdraw(_, vals)
    local n = Util.money(vals[1])
    if not n then return bad('clientBadAmount') end
    TriggerServerEvent('pup_mercantile:dash:withdraw', n)
end

function handlers.tax(_, vals)
    local n = Util.money(vals[1])
    if not n then return bad('clientBadAmount') end
    local d = Dash.data
    if d and Util.round2((tonumber(d.taxledger) or 0) + n) > (tonumber(d.taxCap) or 0) then
        return TriggerEvent('vorp:TipBottom', L('taxCap', Util.fmt(d.taxCap)), 4000)
    end
    TriggerServerEvent('pup_mercantile:dash:tax', n)
end

local function listing(ctx, vals, event)
    local n = Util.whole(tonumber(vals[1]), 1, 999999999)
    local p = Util.money(vals[2])
    if not n or not p then return bad('clientBadAmount') end
    TriggerServerEvent(event, ctx.name, n, p)
end

function handlers.buyAdd(ctx, vals) listing(ctx, vals, 'pup_mercantile:dash:buyAdd') end
function handlers.buyEdit(ctx, vals) listing(ctx, vals, 'pup_mercantile:dash:buyEdit') end

function handlers.rename(_, vals)
    local n = Util.cleanName(vals[1])
    if not n then return bad('clientBadName') end
    if Dash.data then Dash.data.name = n end
    LocalShopUpdate(Dash.kind, Dash.id, { name = n })
    TriggerServerEvent('pup_mercantile:visit:pending', n, nil)
    TriggerEvent('vorp:TipBottom', L('nameChanged'), 4000)
end

function handlers.slots(_, vals)
    local n = Util.whole(tonumber(vals[1]), 1, 100000)
    if not n then return bad('clientBadAmount') end
    TriggerServerEvent('pup_mercantile:dash:slots', n)
end

function handlers.webhook(_, vals)
    local url = Util.trim(vals[1])
    if not url or not Util.validWebhook(url) then return bad('clientBadUrl') end
    TriggerServerEvent('pup_mercantile:dash:webhook', url)
end

function handlers.rank(_, vals)
    -- 0 means every employee may manage
    local n = Util.whole(tonumber(vals[1]), 0, 100)
    if not n then return bad('clientBadAmount') end
    TriggerServerEvent('pup_mercantile:dash:rank', n)
end

function handlers.manager(_, vals)
    local raw = Util.trim(tostring(vals[1] or '')) or ''
    if raw == '' or tonumber(raw) == 0 then
        return TriggerServerEvent('pup_mercantile:dash:manager', 0)
    end
    local n = Util.whole(tonumber(raw), 1, 2147483647)
    if not n then return bad('clientBadAmount') end
    TriggerServerEvent('pup_mercantile:dash:manager', n)
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER then return end
    local inp = Dash.input
    Dash.input = nil
    if not inp then return end
    if type(values) == 'table' and handlers[inp.kind] then handlers[inp.kind](inp.ctx or {}, values) end
    -- the visit may have ended while the input was up
    if not St.venue or St.venue.kind == 'npc' or St.moveMode or St.gridOpen then return end
    if Dash.data then render() else request() end
    SetTimeout(600, function()
        if Dash.open and not Dash.input then request() end
    end)
end)

------------------------------------------------------------------------------
-- app events
------------------------------------------------------------------------------
local function findListing(name)
    for _, b in ipairs((Dash.data and Dash.data.buyitems) or {}) do
        if b.name == name then return b end
    end
    return nil
end

local function catalogueLabel(name)
    for _, e in ipairs(St.catalogue or {}) do
        if e.n == name then return e.l end
    end
    return name
end

local actions = {}

actions.deposit = function() ask('deposit', nil, L('btnDeposit'), { amountField() }) end
actions.withdraw = function() ask('withdraw', nil, L('btnWithdraw'), { amountField() }) end
actions.tax = function() ask('tax', nil, L('btnDepositTax'), { amountField() }) end

actions.grid = function()
    CloseDashboard()
    OpenOwnerGrid()
end

actions.clear = function() Dash.search, Dash.page = '', 1 render() end
actions.prev = function() Dash.page = Dash.page - 1 render() end
actions.next = function() Dash.page = Dash.page + 1 render() end

actions.rename = function()
    ask('rename', nil, L('btnName'), {
        { label = L('inShopName'), type = 'text', default = Dash.data and Dash.data.name or '', required = true, maxlength = 50 },
    })
end

actions.blip = function()
    local d = Dash.data
    if not d then return end
    d.blip = d.blip == 1 and 0 or 1
    LocalShopUpdate(Dash.kind, Dash.id, { blip = d.blip == 1 })
    TriggerServerEvent('pup_mercantile:visit:pending', nil, d.blip)
    render()
end

actions.slots = function() ask('slots', nil, L('btnSlots'), { { label = L('inSlots'), type = 'number', min = 1, max = 100000, required = true } }) end

actions.move = function()
    CloseDashboard()
    TriggerServerEvent('pup_mercantile:move:request')
end

actions.webhook = function()
    ask('webhook', nil, L('btnWebhook'), { { label = L('inWebhook'), type = 'text', required = true, maxlength = 200 } })
end

actions.rank = function()
    ask('rank', nil, L('btnRank'), {
        { label = L('inRank'), type = 'number', default = Dash.data and Dash.data.rank or 0, min = 0, max = 100, required = true },
    })
end

actions.setmgr = function()
    ask('manager', nil, L('btnSetManager'), { { label = L('inCharId'), type = 'number', min = 0, required = false } })
end

actions.rmmgr = function() TriggerServerEvent('pup_mercantile:dash:manager', 0) end

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner ~= OWNER or not Dash.open or type(action) ~= 'string' then return end
    if action == 'search' then
        Dash.search = tostring(type(data) == 'table' and data.value or ''):sub(1, 60)
        Dash.page = 1
        return render()
    end
    local verb, name = action:match('^(%a+):(.+)$')
    if verb == 'edit' then
        local b = findListing(name)
        if not b then return end
        return ask('buyEdit', { name = name }, b.label, { amountField(b.amount), priceField(b.price) })
    elseif verb == 'rm' then
        return TriggerServerEvent('pup_mercantile:dash:buyRemove', name)
    elseif verb == 'add' then
        local b = findListing(name)
        return ask('buyAdd', { name = name }, catalogueLabel(name), { amountField(b and b.amount), priceField(b and b.price) })
    end
    local fn = actions[action]
    if fn then fn() end
end)

AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER or not Dash.open then return end
    if tab ~= 'overview' and tab ~= 'stock' and tab ~= 'add' and tab ~= 'settings' then return end
    Dash.tab = tab
    request()
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= OWNER then return end
    if Dash.input then
        -- an input of ours replaced the app; it is reopened when the input finishes
        Dash.open = false
        return
    end
    if not Dash.open then return end
    Dash.open = false
    Dash.data = nil
    LeaveEverything(false)
end)
