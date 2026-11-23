-- The trading panel, drawn with pup-ui's App and input dialog.
-- Every redraw asks the server; nothing here decides prices, counts or rights.

local OWNER <const> = TP.Res
local Core = exports.vorp_core:GetCore()
local UI = exports['pup-ui']

local panel = nil   -- client-only state while the panel (or one of its dialogs) is up
local drawSeq = 0

local TABS <const> = {
    { id = 'board',   label = Lang.tabs.board,   icon = 'chart' },
    { id = 'post',    label = Lang.tabs.post,    icon = 'box' },
    { id = 'mine',    label = Lang.tabs.mine,    icon = 'user' },
    { id = 'price',   label = Lang.tabs.price,   icon = 'eye' },
    { id = 'account', label = Lang.tabs.account, icon = 'coin' },
}

function TP.PanelOpen() return panel ~= nil end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function money(v) return TP.Money(v) end

local function timeLeft(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    if secs >= 86400 then
        return ('%dd %dh'):format(secs // 86400, (secs % 86400) // 3600)
    elseif secs >= 3600 then
        return ('%dh'):format(secs // 3600)
    end
    return ('%dm'):format(math.max(1, secs // 60))
end

local function cleanText(v)
    if type(v) ~= 'string' then return '' end
    return v:sub(1, 64)
end

-- one round trip to the server; nil when it could not answer
local function ask(op, args)
    if not panel then return nil end
    args = args or {}
    args.op = op
    args.market = panel.market
    local ok, res = pcall(Core.Callback.TriggerAwait, 'pup_tradepost:request', args)
    if not ok or type(res) ~= 'table' or res.busy then return nil end
    return res
end

local function marketName() return panel and TP.MarketName(panel.market) or '' end

local function unavailable(head)
    return {
        { type = 'heading', text = head },
        { type = 'note', text = Lang.noData },
    }
end

---------------------------------------------------------------------------
-- tab builders (each returns a block list)
---------------------------------------------------------------------------
local function rowTitle(r)
    local fmt = r.side == 'buy' and Lang.rowWanted or Lang.rowForSale
    return fmt:format(r.remaining, r.label)
end

local function buildBoard()
    local b = panel.board
    local data = ask('board', { filter = b.filter, sort = b.sort, search = b.search })
    if not data or type(data.rows) ~= 'table' then return unavailable(Lang.boardHead) end

    panel.rows = {}
    local content = {
        { type = 'heading', text = Lang.boardHead, sub = Lang.boardSub },
        { type = 'search', id = 'b_search', value = b.search, placeholder = Lang.searchItems },
        { type = 'chips', items = {
            { id = 'b_f_all',  label = Lang.filterAll, active = b.filter == 'all' },
            { id = 'b_f_buy',  label = Lang.filterBuy, active = b.filter == 'buy' },
            { id = 'b_f_sell', label = Lang.filterSell, active = b.filter == 'sell' },
            { id = 'b_s_new',  label = Lang.sortNew, active = b.sort == 'new' },
            { id = 'b_s_low',  label = Lang.sortLow, active = b.sort == 'low' },
            { id = 'b_s_high', label = Lang.sortHigh, active = b.sort == 'high' },
        } },
    }

    local rows = data.rows
    if #rows == 0 then
        content[#content + 1] = { type = 'note', text = Lang.boardEmpty }
        return content
    end

    local size = Config.Panel.boardPageSize
    local pages = math.max(1, math.ceil(#rows / size))
    b.page = math.max(1, math.min(b.page, pages))
    local first = (b.page - 1) * size + 1
    local last = math.min(#rows, first + size - 1)

    local items = {}
    for i = first, last do
        local r = rows[i]
        panel.rows[r.id] = r
        local sub = Lang.rowSub:format(money(r.price), r.remaining, r.marketName, timeLeft(r.secondsLeft))
        if r.rate then sub = sub .. Lang.rowGoing:format(money(r.rate)) end
        local actions = nil
        if not r.mine then
            if r.side == 'buy' then
                actions = { { id = 'fill:' .. r.id, label = Lang.btnSellTo, tone = 'green' } }
            else
                actions = { { id = 'buy:' .. r.id, label = Lang.btnBuy, tone = 'red' } }
            end
        end
        items[#items + 1] = { img = TP.ItemImage(r.item), title = rowTitle(r), sub = sub, actions = actions }
    end
    content[#content + 1] = { type = 'list', items = items }

    if pages > 1 then
        local buttons = {}
        if b.page > 1 then buttons[#buttons + 1] = { id = 'b_prev', label = '<' } end
        buttons[#buttons + 1] = { id = 'b_page', label = Lang.pageLabel:format(b.page, pages), tone = 'ghost' }
        if b.page < pages then buttons[#buttons + 1] = { id = 'b_next', label = '>' } end
        content[#content + 1] = { type = 'actions', buttons = buttons }
        content[#content + 1] = { type = 'note', text = Lang.boardShowing:format(last - first + 1, #rows) }
    end
    return content
end

local function rateSub(rate)
    if rate then return '$' .. money(rate) end
    return nil
end

local function buildPost()
    local o = ask('overview')
    if not o then return unavailable(Lang.postHead) end
    panel.overview = o

    local content = { { type = 'heading', text = Lang.postHead, sub = Lang.postSub:format(marketName()) } }
    if not o.licence then
        content[#content + 1] = { type = 'note', text = Lang.needLicence }
        content[#content + 1] = { type = 'actions', buttons = { { id = 'goto_account', label = Lang.gotoAccount, tone = 'red' } } }
        return content
    end

    local p = panel.post
    if p.mode == 'sell' and not o.sellEnabled then p.mode = 'buy' end
    local chips = { { id = 'p_mode_buy', label = Lang.modeBuy, active = p.mode == 'buy' } }
    if o.sellEnabled then
        chips[#chips + 1] = { id = 'p_mode_sell', label = Lang.modeSell, active = p.mode == 'sell' }
    end
    content[#content + 1] = { type = 'chips', items = chips }

    panel.tiles = {}
    if p.mode == 'buy' then
        content[#content + 1] = { type = 'note', text = Lang.modeBuyNote }
        content[#content + 1] = { type = 'search', id = 'p_search', value = p.search, placeholder = Lang.searchItems }
        local data = ask('catalogue', { search = p.search })
        local grid = {}
        for _, it in ipairs(data and data.items or {}) do
            panel.tiles[it.item] = it
            grid[#grid + 1] = { id = 'pb:' .. it.item, img = TP.ItemImage(it.item), label = it.label, sub = rateSub(it.rate) }
        end
        content[#content + 1] = { type = 'grid', items = grid }
    else
        content[#content + 1] = { type = 'note', text = Lang.modeSellNote }
        local data = ask('carried')
        local list = data and data.items or {}
        if #list == 0 then
            content[#content + 1] = { type = 'note', text = Lang.nothingToList }
        else
            local grid = {}
            for _, it in ipairs(list) do
                panel.tiles[it.item] = it
                grid[#grid + 1] = { id = 'ps:' .. it.item, img = TP.ItemImage(it.item), label = it.label, count = it.count, sub = rateSub(it.rate) }
            end
            content[#content + 1] = { type = 'grid', items = grid }
        end
    end
    return content
end

local function buildMine()
    local data = ask('mine')
    if not data or type(data.orders) ~= 'table' then return unavailable(Lang.mineHead) end
    local content = { { type = 'heading', text = Lang.mineHead, sub = Lang.mineSub } }

    if #data.orders == 0 then
        content[#content + 1] = { type = 'note', text = Lang.mineEmpty }
    else
        local items = {}
        for _, r in ipairs(data.orders) do
            local sub
            if r.expired then
                sub = Lang.rowSubExpired:format(money(r.price), r.remaining, r.marketName)
            else
                sub = Lang.rowSub:format(money(r.price), r.remaining, r.marketName, timeLeft(r.secondsLeft))
            end
            items[#items + 1] = {
                img = TP.ItemImage(r.item), title = rowTitle(r), sub = sub,
                actions = { { id = 'cancel:' .. r.id, label = Lang.btnCancel, tone = 'ghost' } },
            }
        end
        content[#content + 1] = { type = 'list', items = items }
    end

    if type(data.trades) == 'table' and #data.trades > 0 then
        local rows = {}
        for _, t in ipairs(data.trades) do
            rows[#rows + 1] = { cells = {
                when = { text = t.whenText or '', tone = 'muted' },
                item = { text = t.label },
                side = t.bought and { text = Lang.sideBought, tone = 'badge-neutral' } or { text = Lang.sideSold, tone = 'badge-green' },
                qty = { text = tostring(t.qty) },
                each = { text = '$' .. money(t.price) },
                market = { text = t.marketName, tone = 'muted' },
            } }
        end
        content[#content + 1] = {
            type = 'table', title = Lang.recentTitle, perPage = Config.Panel.recentPerPage,
            columns = {
                { key = 'when', label = Lang.colWhen }, { key = 'item', label = Lang.colItem },
                { key = 'side', label = Lang.colSide }, { key = 'qty', label = Lang.colQty },
                { key = 'each', label = Lang.colEach }, { key = 'market', label = Lang.colMarket },
            },
            rows = rows,
        }
    end
    return content
end

local function moneyOrDash(v)
    if v and v > 0 then return '$' .. money(v) end
    return Lang.none
end

local function buildPrice()
    local p = panel.price
    local content = {
        { type = 'heading', text = Lang.priceHead, sub = Lang.priceSub },
        { type = 'search', id = 'pc_search', value = p.search, placeholder = Lang.searchItems },
    }
    if p.search ~= '' then
        local data = ask('catalogue', { search = p.search })
        local grid = {}
        for _, it in ipairs(data and data.items or {}) do
            grid[#grid + 1] = { id = 'pc:' .. it.item, img = TP.ItemImage(it.item), label = it.label, sel = it.item == p.item }
        end
        content[#content + 1] = { type = 'grid', items = grid }
    end
    if p.item then
        local data = ask('price', { item = p.item })
        local d = data and data.detail
        if d then
            content[#content + 1] = { type = 'hero', img = TP.ItemImage(d.item), title = d.label }
            content[#content + 1] = { type = 'stats', items = {
                { value = moneyOrDash(d.rate), label = Lang.statGoing },
                { value = moneyOrDash(d.low), label = Lang.statLow },
                { value = moneyOrDash(d.high), label = Lang.statHigh },
                { value = tostring(d.volume or 0), label = Lang.statVolume },
            } }
            content[#content + 1] = { type = 'stats', items = {
                { value = moneyOrDash(d.bestBuy), label = Lang.statBestBuy },
                { value = moneyOrDash(d.cheapest), label = Lang.statCheapest },
            } }
        end
    end
    return content
end

local function buildAccount()
    local o = ask('overview')
    if not o then return unavailable(Lang.accountHead) end
    panel.overview = o
    local where = marketName()

    local content = {
        { type = 'heading', text = Lang.accountHead, sub = Lang.accountSub:format(where) },
        { type = 'stats', items = {
            { value = '$' .. money(o.balance), label = Lang.statWaiting },
            { value = '$' .. money(o.lifetime), label = Lang.statEarned },
            { value = '$' .. money(o.held), label = Lang.statHeld },
            { value = o.licence and tostring(o.licence.slots) or Lang.none, label = Lang.statSlots },
        } },
    }
    local buttons = { { id = 'a_withdraw', label = Lang.btnWithdraw, tone = 'green' } }
    if o.bank then buttons[#buttons + 1] = { id = 'a_tobank', label = Lang.btnToBank, tone = 'ghost' } end
    content[#content + 1] = { type = 'actions', buttons = buttons }

    -- this town's own branch first, then the rest in pup-bank's order
    content[#content + 1] = { type = 'heading', text = Lang.payWithHead }
    local chips = { { id = 'pay:cash', label = Lang.payCash, active = o.payWith == 'cash' } }
    panel.bankChoices = {}
    local ordered = {}
    for _, name in ipairs(o.banks or {}) do
        if name == o.marketBank then table.insert(ordered, 1, name) else ordered[#ordered + 1] = name end
    end
    for i, name in ipairs(ordered) do
        panel.bankChoices[i] = name
        chips[#chips + 1] = {
            id = 'pay:' .. i,
            label = (name == o.marketBank and Lang.payBankHere or Lang.payBank):format(name),
            active = o.payWith == 'bank' and o.bank == name,
        }
    end
    content[#content + 1] = { type = 'chips', items = chips }

    content[#content + 1] = { type = 'heading', text = Lang.licenceHead:format(where) }
    if o.licence then
        content[#content + 1] = { type = 'actions', buttons = {
            { id = 'a_storage', label = Lang.btnStorage, tone = 'red' },
            { id = 'a_slots', label = Lang.btnSlots:format(money(o.prices.slot)), tone = 'ghost' },
        } }
    else
        content[#content + 1] = { type = 'note', text = Lang.noLicence:format(money(o.prices.licence), o.prices.startSlots) }
        content[#content + 1] = { type = 'actions', buttons = {
            { id = 'a_licence', label = Lang.btnLicence:format(money(o.prices.licence)), tone = 'red' },
        } }
    end
    return content
end

local BUILDERS <const> = {
    board = buildBoard, post = buildPost, mine = buildMine, price = buildPrice, account = buildAccount,
}

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------
local function showApp(content)
    UI:OpenApp({
        owner = OWNER,
        title = Lang.panelTitle,
        subtitle = marketName(),
        tabs = TABS,
        active = panel.tab,
        content = content or { { type = 'note', text = Lang.loading } },
    })
end

-- fetches the current tab and draws it; only the newest request wins
local function redraw()
    if not panel or panel.dialog then return end
    drawSeq = drawSeq + 1
    local seq = drawSeq
    CreateThread(function()
        if not panel then return end
        local tab = panel.tab
        local ok, content = pcall(BUILDERS[tab])
        if not ok then
            TP.Debug('redraw failed', content)
            content = unavailable(Lang.panelTitle)
        end
        if not panel or panel.dialog or seq ~= drawSeq or panel.tab ~= tab then return end
        UI:UpdateApp({ active = tab, content = content })
    end)
end

function TP.OpenPanel(marketKey)
    if panel or not TP.MarketByKey[marketKey] then return end
    panel = {
        market = marketKey,
        tab = 'board',
        board = { filter = 'all', sort = 'new', search = '', page = 1 },
        post = { mode = 'buy', search = '' },
        price = { search = '', item = nil },
        rows = {}, tiles = {}, bankChoices = {},
        overview = nil, dialog = nil, busy = false,
    }
    showApp()
    redraw()
end

function TP.ClosePanel()
    if not panel then return end
    local hadDialog = panel.dialog ~= nil
    panel = nil
    drawSeq = drawSeq + 1
    if not hadDialog then UI:CloseApp() end
end

---------------------------------------------------------------------------
-- money/goods actions
---------------------------------------------------------------------------
local function write(op, args)
    if not panel or panel.busy then return end
    panel.busy = true
    CreateThread(function()
        local res = ask(op, args)
        if not panel then return end
        panel.busy = false
        local msg = res and res.msg or Lang.noData
        TriggerEvent('vorp:TipRight', msg, 4000)
        if res and res.close then
            TP.ClosePanel()
            return
        end
        if res and res.ok and res.switchTab and BUILDERS[res.switchTab] then
            panel.tab = res.switchTab
        end
        redraw()
    end)
end

-- the App closes while a dialog is up (pup-ui shows one panel at a time)
local function openDialog(spec)
    if not panel or panel.busy then return end
    panel.dialog = spec
    drawSeq = drawSeq + 1
    UI:CloseApp()
    UI:OpenInput({
        owner = OWNER,
        title = spec.title,
        subtitle = spec.subtitle,
        submit = spec.submit,
        fields = spec.fields,
    })
end

local function wholeNumber(v)
    local n = tonumber(v)
    if not n then return nil end
    return math.floor(n)
end

local function tradeDialog(id)
    local r = panel.rows[id]
    if not r then return end
    local spec
    if r.side == 'buy' then
        local have = math.floor(tonumber(r.have) or 0)
        spec = {
            title = r.label,
            subtitle = Lang.fillSub:format(money(r.price), have),
            submit = Lang.fillSubmit,
            fields = { { label = Lang.fieldHowMany, type = 'number', required = true,
                default = math.max(1, math.min(r.remaining, have > 0 and have or r.remaining)), min = 1, max = r.remaining } },
        }
    else
        spec = {
            title = r.label,
            subtitle = Lang.buySub:format(money(r.price), r.remaining),
            submit = Lang.buySubmit,
            fields = { { label = Lang.fieldHowMany, type = 'number', required = true, default = r.remaining, min = 1, max = r.remaining } },
        }
    end
    spec.onSubmit = function(values)
        local qty = wholeNumber(values[1])
        if qty then write('trade', { id = id, qty = qty }) else redraw() end
    end
    openDialog(spec)
end

local function postDialog(side, item)
    local t = panel.tiles[item]
    local o = panel.overview
    if not t or not o then return end
    local pr = o.prices
    local maxQty, minPrice, maxPrice, defQty
    if side == 'buy' then
        maxQty, minPrice, maxPrice, defQty = pr.buyMax, pr.buyMin, pr.buyTop, 1
    else
        local count = math.floor(tonumber(t.count) or 0)
        maxQty, minPrice, maxPrice = math.min(count, pr.sellMax), pr.sellMin, pr.sellTop
        defQty = maxQty
        if maxQty < 1 then return end
    end
    openDialog({
        title = (side == 'buy' and Lang.dlgBuyOrder or Lang.dlgSellListing):format(t.label),
        subtitle = t.rate and Lang.dlgGoing:format(money(t.rate)) or Lang.dlgNoGoing,
        submit = side == 'buy' and Lang.modeBuy or Lang.modeSell,
        fields = {
            { label = Lang.fieldHowMany, type = 'number', required = true, default = defQty, min = 1, max = maxQty },
            { label = Lang.fieldPrice, type = 'number', required = true, default = t.rate or minPrice, min = minPrice, max = maxPrice },
        },
        onSubmit = function(values)
            local qty, price = wholeNumber(values[1]), tonumber(values[2])
            if qty and price then
                write('post', { side = side, item = item, qty = qty, price = price })
            else
                redraw()
            end
        end,
    })
end

local function slotsDialog()
    local o = panel.overview
    if not o then return end
    openDialog({
        title = Lang.btnSlots:format(money(o.prices.slot)),
        submit = Lang.btnSlots:format(money(o.prices.slot)),
        fields = { { label = Lang.fieldSlots, type = 'number', required = true, default = 10, min = 1, max = o.prices.maxSlotsPerBuy } },
        onSubmit = function(values)
            local count = wholeNumber(values[1])
            if count then write('slots', { count = count }) else redraw() end
        end,
    })
end

---------------------------------------------------------------------------
-- pup-ui events
---------------------------------------------------------------------------
local SIMPLE <const> = {
    b_f_all  = function() panel.board.filter = 'all';  panel.board.page = 1 end,
    b_f_buy  = function() panel.board.filter = 'buy';  panel.board.page = 1 end,
    b_f_sell = function() panel.board.filter = 'sell'; panel.board.page = 1 end,
    b_s_new  = function() panel.board.sort = 'new';    panel.board.page = 1 end,
    b_s_low  = function() panel.board.sort = 'low';    panel.board.page = 1 end,
    b_s_high = function() panel.board.sort = 'high';   panel.board.page = 1 end,
    b_prev   = function() panel.board.page = math.max(1, panel.board.page - 1) end,
    b_next   = function() panel.board.page = panel.board.page + 1 end,
    goto_account = function() panel.tab = 'account' end,
    p_mode_buy   = function() panel.post.mode = 'buy' end,
    p_mode_sell  = function() panel.post.mode = 'sell' end,
}

local SEARCHES <const> = {
    b_search  = function(v) panel.board.search = v; panel.board.page = 1 end,
    p_search  = function(v) panel.post.search = v end,
    pc_search = function(v) panel.price.search = v end,
}

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner ~= OWNER or not panel or panel.dialog or type(action) ~= 'string' then return end

    if action == 'b_page' then return end
    if SIMPLE[action] then
        SIMPLE[action]()
        if action == 'goto_account' then UI:UpdateApp({ active = 'account' }) end
        return redraw()
    end
    if SEARCHES[action] then
        SEARCHES[action](cleanText(type(data) == 'table' and data.value or ''))
        return redraw()
    end

    if action == 'a_withdraw' then return write('withdraw') end
    if action == 'a_tobank' then return write('tobank') end
    if action == 'a_storage' then
        -- close first: closing the App after the container opens would take its focus away
        local market = panel.market
        if panel.busy then return end
        TP.ClosePanel()
        CreateThread(function()
            local ok, res = pcall(Core.Callback.TriggerAwait, 'pup_tradepost:request', { op = 'storage', market = market })
            if ok and type(res) == 'table' and not res.ok and res.msg then
                TriggerEvent('vorp:TipRight', res.msg, 4000)
            end
        end)
        return
    end
    if action == 'a_licence' then return write('licence') end
    if action == 'a_slots' then return slotsDialog() end

    local kind, rest = action:match('^(%a+):(.+)$')
    if not kind then return end
    if kind == 'fill' or kind == 'buy' then
        local id = tonumber(rest)
        if id then tradeDialog(id) end
    elseif kind == 'cancel' then
        local id = tonumber(rest)
        if id then write('cancel', { id = id }) end
    elseif kind == 'pb' then
        postDialog('buy', rest)
    elseif kind == 'ps' then
        postDialog('sell', rest)
    elseif kind == 'pc' then
        panel.price.item = rest
        redraw()
    elseif kind == 'pay' then
        if rest == 'cash' then
            write('paywith', { value = 'cash' })
        else
            local name = panel.bankChoices[tonumber(rest) or 0]
            if name then write('paywith', { value = name }) end
        end
    end
end)

AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER or not panel or panel.dialog or not BUILDERS[tab] then return end
    panel.tab = tab
    redraw()
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= OWNER and owner ~= nil then return end
    if not panel then return end
    if panel.dialog then
        -- only a close-everything (death, /hideui) reaches us while a dialog is up
        if owner == nil then panel.forced = true end
        return
    end
    panel = nil
    drawSeq = drawSeq + 1
end)

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER or not panel or not panel.dialog then return end
    local spec = panel.dialog

    if values == nil then
        -- Decide one tick later: a close-everything (/hideui, death) may fire
        -- inputClosed before appClosed(nil), so panel.forced is only known then.
        local mine = panel
        CreateThread(function()
            Wait(0)
            if panel ~= mine or not panel.dialog then return end
            panel.dialog = nil
            -- a cancel caused by another panel taking the screen: leave it to that panel
            if panel.forced or UI:IsPanelOpen() or IsEntityDead(PlayerPedId()) then
                panel = nil
                return
            end
            showApp()
            redraw()
        end)
        return
    end

    panel.dialog = nil
    showApp()
    if type(values) == 'table' and spec.onSubmit then
        spec.onSubmit(values)
    else
        redraw()
    end
end)

-- a character switch ends the session at the counter
RegisterNetEvent('vorp:SelectedCharacter', function()
    TP.ClosePanel()
end)
