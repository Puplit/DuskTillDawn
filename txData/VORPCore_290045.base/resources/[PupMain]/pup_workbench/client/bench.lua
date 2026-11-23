-- The bench: a pup-ui App panel with category, favourites, pending, box and search tabs.
Bench = {
    open = false,
    ctx = nil,          -- { mode, name | model + pos | item, label }
    data = nil,         -- what the server sent on open
    visible = {},       -- recipes shown at this bench
    counts = {},        -- item name -> how many the player holds
    tab = nil,
    selected = {},      -- tab id -> recipe id
    search = '',
    canMake = false,
    descDialog = nil,   -- the recipe being crafted with a description, while its dialog is up
    pending = nil,      -- nil while fetching
    serverNow = 0, fetchedAt = 0,
    tickId = 0,
}

local UI = exports['pup-ui']

-- RECIPE MATHS
local function have(name) return tonumber(Bench.counts[name]) or 0 end

local function toolsOk(r)
    for _, t in ipairs(r.tools or {}) do
        if have(t.name) < t.count then return false end
    end
    return true
end

--- The maximum honours tools as well as materials (0 when anything is short).
local function maxUnits(r)
    if not toolsOk(r) then return 0 end
    local m = Config.MaxUnitsPerCraft
    for _, mat in ipairs(r.materials or {}) do
        m = math.min(m, math.floor(have(mat.name) / mat.count))
    end
    return math.max(0, m)
end

local function affordable(r)
    return not r.locked and maxUnits(r) >= 1
end

local function rank(r)
    if r.locked then return 2 end
    return affordable(r) and 0 or 1
end

local function sorted(list)
    table.sort(list, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then return ra < rb end
        return a.id < b.id
    end)
    return list
end

local function filtered(list)
    if not Bench.canMake then return list end
    local out = {}
    for _, r in ipairs(list) do
        if affordable(r) then out[#out + 1] = r end
    end
    return out
end

local function byId(id)
    for _, r in ipairs(Bench.visible) do
        if r.id == id then return r end
    end
    return nil
end

local function isFav(id)
    for _, f in ipairs(Bench.data.favourites or {}) do
        if f == id then return true end
    end
    return false
end

-- WHICH RECIPES SHOW HERE
local function shownAt(r, ctx)
    local hasStations = type(r.stations) == 'table' and #r.stations > 0
    local hasProps = type(r.props) == 'table' and #r.props > 0
    if ctx.mode == 'station' then
        if hasStations then return WB.listHas(r.stations, ctx.name) end
        return Config.Rules.genericRecipesAtStations and not hasProps
    end
    if hasStations then return false end
    if ctx.mode == 'prop' then
        return not hasProps or WB.listHas(r.props, ctx.model)
    end
    return not hasProps
end

-- PAGE PIECES
local function firstReward(r)
    return (r.rewards and r.rewards[1]) or { name = '', count = 1 }
end

local function serverTime()
    return Bench.serverNow + (GetGameTimer() - Bench.fetchedAt) / 1000
end

local function timedOn()
    return Bench.data and Bench.data.timed == true
end

local function stepperStart(maxU)
    local top = math.max(1, maxU)
    if Prefs.data.automax then return top end
    if Prefs.data.reopen then return math.max(1, math.min(top, Prefs.data.amount)) end
    return 1
end

local function detailBlocks(r)
    if not r then return { { type = 'note', text = L('pick_recipe') } } end
    local fr = firstReward(r)
    local tags = { L('tag_xp', r.expadd or 0) }
    if timedOn() then tags[#tags + 1] = L('tag_each', WB.fmtTime(r.time or Config.Timed.defaultSecondsPerUnit)) end
    if r.locked then tags[#tags + 1] = L('locked') end

    local blocks = {
        { type = 'hero', img = WB.itemImage(fr.name), title = ('%d x %s'):format(fr.count, r.title), sub = r.desc, tags = tags },
    }
    if r.locked and r.reason then blocks[#blocks + 1] = { type = 'note', text = r.reason } end

    local bill = {}
    for _, m in ipairs(r.materials or {}) do
        bill[#bill + 1] = { img = WB.itemImage(m.name), label = m.label, have = have(m.name), need = m.count }
    end
    for _, t in ipairs(r.tools or {}) do
        bill[#bill + 1] = {
            img = WB.itemImage(t.name), label = t.label, have = have(t.name), need = t.count, tool = true,
            note = ('%s - %d / %d'):format(L('tool_kept'), have(t.name), t.count),
        }
    end
    blocks[#blocks + 1] = { type = 'heading', text = L('needs_heading') }
    blocks[#blocks + 1] = { type = 'bill', items = bill }

    local maxU = maxUnits(r)
    local craftable = not r.locked and maxU >= 1
    blocks[#blocks + 1] = {
        type = 'stepper', id = 'amt',
        label = L('amount_can', maxU),
        value = stepperStart(maxU), min = 1, max = math.max(1, maxU), step = 1,
        buttons = { { id = 'craft:' .. r.id, label = L('craft'), tone = craftable and 'red' or 'ghost' } },
    }
    local buttons = { { id = 'fav:' .. r.id, label = isFav(r.id) and L('unfavourite') or L('favourite') } }
    if Config.Descriptions.enabled then
        buttons[#buttons + 1] = { id = 'craftdesc:' .. r.id, label = L('craft_desc'), tone = 'ghost' }
    end
    blocks[#blocks + 1] = { type = 'actions', buttons = buttons }
    return blocks
end

--- Grid on the left, detail on the right. `emptyText` when there is nothing to list.
local function splitView(list, emptyText)
    local selId = Bench.selected[Bench.tab]
    local sel = nil
    for _, r in ipairs(list) do
        if r.id == selId then sel = r end
    end
    if not sel and list[1] then
        sel = list[1]
        Bench.selected[Bench.tab] = sel.id
    end

    local left
    if #list == 0 then
        left = { { type = 'note', text = emptyText } }
    else
        local items = {}
        for _, r in ipairs(list) do
            local fr = firstReward(r)
            items[#items + 1] = {
                img = WB.itemImage(fr.name), label = r.title, count = fr.count,
                sub = r.locked and L('locked') or nil,
                dim = r.locked or not affordable(r),
                sel = sel ~= nil and r.id == sel.id,
                id = 'pick:' .. r.id,
            }
        end
        left = { { type = 'grid', items = items } }
    end
    return { type = 'split', side = 'wide', left = left, right = detailBlocks(sel) }
end

local function searchBlock()
    return { type = 'search', id = 'search', value = Bench.search, placeholder = L('search_placeholder') }
end

local function chipsBlock()
    return { type = 'chips', items = {
        { id = 'chip:canmake', label = L('chip_canmake'), active = Bench.canMake },
        { id = 'chip:automax', label = L('chip_automax'), active = Prefs.data.automax },
        { id = 'chip:remember', label = L('chip_remember'), active = Prefs.data.reopen },
    } }
end

local function levelOf(cat, xp)
    local list = (Bench.data.thresholds or {})[cat] or {}
    local m = math.max(1, #list)
    local n = 0
    for _, v in ipairs(list) do
        if xp >= v then n = n + 1 end
    end
    return math.max(1, math.min(n, m)), m
end

local function categoryPage(cat)
    local list, locked = {}, 0
    for _, r in ipairs(Bench.visible) do
        if r.category == cat.key then
            list[#list + 1] = r
            if r.locked then locked = locked + 1 end
        end
    end
    local xp = tonumber((Bench.data.xp or {})[cat.key]) or 0
    local n, m = levelOf(cat.key, xp)
    return {
        { type = 'heading', text = cat.label, sub = cat.desc },
        { type = 'stats', items = {
            { value = tostring(math.floor(xp)), label = L('stat_xp') },
            { value = L('level_fmt', n, m), label = L('stat_level') },
            { value = ('%d / %d'):format(#list - locked, #list), label = L('stat_recipes') },
            { value = tostring(#(Bench.data.favourites or {})), label = L('stat_favs') },
        } },
        searchBlock(),
        chipsBlock(),
        splitView(filtered(sorted(list)), L('empty_category')),
    }
end

local function favouritesPage()
    local list = {}
    for _, id in ipairs(Bench.data.favourites or {}) do
        local r = byId(id)
        if r then list[#list + 1] = r end
    end
    return {
        { type = 'heading', text = L('favs_heading'), sub = L('favs_sub') },
        searchBlock(),
        chipsBlock(),
        splitView(filtered(sorted(list)), L('empty_favs')),
    }
end

local function searchPage()
    local term = Bench.search:lower()
    local list = {}
    for _, r in ipairs(Bench.visible) do
        local fr = firstReward(r)
        if (r.title or ''):lower():find(term, 1, true)
            or (fr.name or ''):lower():find(term, 1, true)
            or (r.desc or ''):lower():find(term, 1, true) then
            list[#list + 1] = r
        end
    end
    return {
        { type = 'heading', text = L('search_heading', Bench.search), sub = L('search_sub') },
        searchBlock(),
        { type = 'actions', buttons = { { id = 'clearsearch', label = L('search_clear'), tone = 'ghost' } } },
        chipsBlock(),
        splitView(filtered(sorted(list)), L('search_none')),
    }
end

local function categoryLabel(key)
    local c = WB.categoryByKey(key)
    return c and c.label or tostring(key or '')
end

local function pendingPage()
    local blocks = { { type = 'heading', text = L('pending_heading'), sub = L('pending_sub') } }
    if Bench.pending == nil then
        blocks[#blocks + 1] = { type = 'note', text = L('fetching') }
        return blocks
    end
    if #Bench.pending == 0 then
        blocks[#blocks + 1] = { type = 'note', text = L('pending_none') }
        return blocks
    end
    local now = serverTime()
    local items, anyReady = {}, false
    for _, p in ipairs(Bench.pending) do
        local total = math.max(1, (p.ready or 0) - (p.queued or 0))
        local left = (p.ready or 0) - now
        local ready = left <= 0
        if ready then anyReady = true end
        items[#items + 1] = {
            id = 'q' .. p.id,
            img = p.img and WB.itemImage(p.img) or nil,
            label = ('%s x%d'):format(p.label or '', p.count or 1),
            sub = categoryLabel(p.category),
            value = ready and 1 or math.max(0, math.min(1, (total - left) / total)),
            right = ready and L('ready') or L('time_left', WB.fmtTime(math.ceil(left))),
            done = ready,
            actions = ready and { { id = 'collect:' .. p.id, label = L('collect'), tone = 'red' } } or nil,
        }
    end
    if anyReady then
        blocks[#blocks + 1] = { type = 'actions', buttons = { { id = 'collectall', label = L('collect_all'), tone = 'red' } } }
    end
    blocks[#blocks + 1] = { type = 'progress', items = items }
    return blocks
end

local function boxPage()
    return {
        { type = 'heading', text = L('box_heading'), sub = L('box_sub') },
        { type = 'actions', buttons = { { id = 'openbox', label = L('box_open'), tone = 'red' } } },
    }
end

-- TABS
local function showPendingTab()
    return timedOn() or (Bench.data and #(Bench.data.pending or {}) > 0)
end

local function buildTabs()
    local tabs = {}
    for _, c in ipairs(Config.Categories) do
        for _, r in ipairs(Bench.visible) do
            if r.category == c.key then
                tabs[#tabs + 1] = { id = 'cat:' .. c.key, label = c.label, icon = c.icon or Config.DefaultCategoryIcon }
                break
            end
        end
    end
    tabs[#tabs + 1] = { id = 'favs', label = L('tab_favourites'), icon = 'star' }
    if showPendingTab() then tabs[#tabs + 1] = { id = 'pending', label = L('tab_pending'), icon = 'clock' } end
    if Bench.data.box then tabs[#tabs + 1] = { id = 'box', label = L('tab_box'), icon = 'box' } end
    if Bench.search ~= '' then tabs[#tabs + 1] = { id = 'search', label = L('tab_search'), icon = 'eye' } end
    return tabs
end

local function tabExists(tabs, id)
    for _, t in ipairs(tabs) do
        if t.id == id then return true end
    end
    return false
end

local function content()
    local tab = Bench.tab or ''
    if tab:sub(1, 4) == 'cat:' then
        local c = WB.categoryByKey(tab:sub(5))
        if c then return categoryPage(c) end
    elseif tab == 'favs' then return favouritesPage()
    elseif tab == 'pending' then return pendingPage()
    elseif tab == 'box' then return boxPage()
    elseif tab == 'search' then return searchPage()
    end
    return favouritesPage()
end

--- Full draw (tabs may have changed).
local function drawAll()
    local tabs = buildTabs()
    if not Bench.tab or not tabExists(tabs, Bench.tab) then Bench.tab = tabs[1] and tabs[1].id or 'favs' end
    UI:OpenApp({
        owner = OWNER,
        title = L('panel_title'),
        subtitle = Bench.ctx.label,
        tabs = tabs,
        active = Bench.tab,
        content = content(),
    })
end

--- Content only.
local function redraw()
    if not Bench.open or Bench.descDialog then return end
    UI:UpdateApp({ active = Bench.tab, content = content() })
end
Bench.redraw = redraw

-- DATA
local function fetchCounts()
    local names, seen = {}, {}
    for _, r in ipairs(Bench.visible) do
        for _, group in ipairs({ r.materials or {}, r.tools or {} }) do
            for _, l in ipairs(group) do
                if not seen[l.name] and #names < 400 then
                    seen[l.name] = true
                    names[#names + 1] = l.name
                end
            end
        end
    end
    local res = Req('counts', names)
    if type(res) == 'table' and res.ok and type(res.counts) == 'table' then Bench.counts = res.counts end
end

local function applyOpenData(res)
    Bench.data = res
    Bench.serverNow = tonumber(res.now) or 0
    Bench.fetchedAt = GetGameTimer()
    Bench.pending = res.pending
    local vis = {}
    for _, r in ipairs(res.recipes or {}) do
        if shownAt(r, Bench.ctx) then vis[#vis + 1] = r end
    end
    Bench.visible = vis
end

local function refreshPending()
    local res = Req('pending')
    if type(res) == 'table' and type(res.list) == 'table' then
        Bench.pending = res.list
        Bench.serverNow = tonumber(res.now) or Bench.serverNow
        Bench.fetchedAt = GetGameTimer()
        if Bench.data then Bench.data.pending = res.list end
    end
end

local function startTicker()
    Bench.tickId = Bench.tickId + 1
    local id = Bench.tickId
    CreateThread(function()
        while Bench.open and Bench.tab == 'pending' and Bench.tickId == id do
            Wait(1000)
            if Bench.open and Bench.tab == 'pending' and Bench.tickId == id and not Bench.descDialog then
                redraw()
            end
        end
    end)
end

local function freeze(on)
    local ped = PlayerPedId()
    if on then ClearPedTasks(ped) end
    FreezeEntityPosition(ped, on)
end

-- OPEN / CLOSE
function Bench.openAt(ctx)
    if Bench.open or Craft.busy then return end
    local res = Req('open')
    if type(res) ~= 'table' or type(res.recipes) ~= 'table' then
        Notify(L('not_ready'))
        return
    end
    Bench.ctx = ctx
    Bench.open = true
    Bench.tab, Bench.selected, Bench.search, Bench.canMake = nil, {}, '', false
    Bench.counts = {}
    applyOpenData(res)
    freeze(true)
    drawAll()
    fetchCounts()
    redraw()
end

local function onClosed()
    Bench.open = false
    Bench.descDialog = nil
    Bench.tickId = Bench.tickId + 1
    freeze(false)
end

function Bench.close()
    if not Bench.open then return end
    UI:CloseApp()
    onClosed()
end

-- the server changed recipes: refetch if the bench is up
RegisterNetEvent('pup_workbench:recipesChanged', function()
    if not Bench.open or Bench.descDialog then return end
    local res = Req('open')
    if not Bench.open or type(res) ~= 'table' or type(res.recipes) ~= 'table' then return end
    applyOpenData(res)
    fetchCounts()
    if Bench.open and not Bench.descDialog then drawAll() end
end)

-- DESCRIPTION DIALOG
local function cut(s)
    if #s > 40 then return WB.cut(s, 40) .. '...' end
    return s
end

local function openDescDialog(r)
    local maxU = maxUnits(r)
    local amount
    if Prefs.data.automax then amount = math.max(1, maxU)
    elseif Prefs.data.reopen then amount = Prefs.data.amount
    else amount = 1 end
    local fields = {
        { label = L('amount'), type = 'number', default = amount, min = 1, max = Config.MaxUnitsPerCraft, required = true },
        { label = L('desc_field'), type = 'text', placeholder = L('desc_hint'),
          default = Prefs.data.reopen and Prefs.data.desc or nil, maxlength = Config.Descriptions.maxLength },
    }
    if #Prefs.saved > 0 then
        local opts = { { label = L('desc_pick'), value = '0' } }
        for i, s in ipairs(Prefs.saved) do opts[#opts + 1] = { label = cut(s), value = tostring(i) } end
        fields[#fields + 1] = { label = L('desc_recent'), type = 'select', default = '0', options = opts }
    end
    Bench.descDialog = r
    UI:OpenInput({ owner = OWNER, title = L('craft'), subtitle = r.title, submit = L('craft_confirm'), fields = fields })
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    if owner ~= OWNER or not Bench.descDialog then return end
    local r = Bench.descDialog
    Bench.descDialog = nil
    if not Bench.open then return end
    if type(values) ~= 'table' then
        -- cancelled: back to the bench, unless the dialog was swept away by death
        if IsEntityDead(PlayerPedId()) then return onClosed() end
        drawAll()
        return
    end
    local amount = WB.int(values[1])
    local desc = type(values[2]) == 'string' and WB.trim(values[2]) or ''
    if desc == '' and values[3] ~= nil then
        local i = WB.int(values[3])
        if i and i > 0 and Prefs.saved[i] then desc = Prefs.saved[i] end
    end
    if desc ~= '' and WB.hasBannedWord(desc) then
        Notify(L('banned_words'))
        drawAll()
        return
    end
    Craft.begin(r, amount, desc ~= '' and desc or nil)
end)

-- PANEL EVENTS
AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER or not Bench.open then return end
    Bench.tab = tostring(tab)
    if Bench.tab == 'pending' then
        Bench.pending = nil
        redraw()
        refreshPending()
        if not Bench.open or Bench.tab ~= 'pending' then return end
        startTicker()
    end
    redraw()
end)

local function clearSearch()
    Bench.search = ''
    Bench.tab = nil
    drawAll()
end

local function showResult(res)
    if type(res) == 'table' and res.msg then Notify(res.msg) end
end

local function toggleFavourite(id)
    local list, found = {}, false
    for _, f in ipairs(Bench.data.favourites or {}) do
        if f == id then found = true else list[#list + 1] = f end
    end
    if not found then list[#list + 1] = id end
    local res = Req('favs', list)
    -- a refusal (rate limit, busy) must never replace the list, or the next star wipes it
    if type(res) == 'table' and res.ok and type(res.list) == 'table' then
        Bench.data.favourites = res.list
    else
        showResult(res)
    end
end

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner ~= OWNER or not Bench.open or type(action) ~= 'string' then return end
    data = type(data) == 'table' and data or {}

    if action == 'search' then
        local term = WB.cut(WB.trim(tostring(data.value or '')), 60)
        if term == '' then return clearSearch() end
        local hadTab = Bench.search ~= ''
        Bench.search = term
        Bench.tab = 'search'
        if hadTab then redraw() else drawAll() end
        return
    end
    if action == 'clearsearch' then return clearSearch() end

    if action == 'chip:canmake' then
        Bench.canMake = not Bench.canMake
        return redraw()
    elseif action == 'chip:automax' then
        Prefs.data.automax = not Prefs.data.automax
        Prefs.save()
        return redraw()
    elseif action == 'chip:remember' then
        Prefs.data.reopen = not Prefs.data.reopen
        Prefs.save()
        return redraw()
    end

    local verb, arg = action:match('^(%w+):(%d+)$')
    local id = tonumber(arg)
    if verb == 'pick' then
        Bench.selected[Bench.tab] = id
        return redraw()
    elseif verb == 'craft' then
        local r = byId(id)
        if r then Craft.begin(r, WB.int(data.value), nil) end
        return
    elseif verb == 'fav' then
        toggleFavourite(id)
        return redraw()
    elseif verb == 'craftdesc' then
        local r = byId(id)
        if r then
            if r.locked then return Notify(r.reason or L('locked')) end
            openDescDialog(r)
        end
        return
    elseif verb == 'collect' then
        showResult(Req('collect', id))
        refreshPending()
        fetchCounts()
        return redraw()
    end

    if action == 'collectall' then
        showResult(Req('collectAll'))
        refreshPending()
        fetchCounts()
        return redraw()
    elseif action == 'openbox' then
        local res = Req('openBox')
        if type(res) == 'table' and res.ok then
            Bench.close()
        else
            showResult(res)
        end
    end
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= OWNER then return end
    if Bench.descDialog then return end -- the description dialog replaced the panel; not a close
    if Bench.open then onClosed() end
end)

-- portable kits (none configured by default)
RegisterNetEvent('pup_workbench:kit:open', function(item)
    if type(item) ~= 'string' or not Config.Kits[item] then return end
    Bench.openAt({ mode = 'kit', item = item, label = L('bench_kit') })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Bench.open then
        pcall(function() UI:CloseApp() end)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)
