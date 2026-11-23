-- pup_ranchero | staff tools on the client: the create-ranch menu and the ranch dashboard

------------------------------------------------------------------------------
-- /createranch
------------------------------------------------------------------------------
RegisterNetEvent('pup_ranchero:openCreate', function()
    local draft = { name = '', price = 0, tax = 0 }
    Menu.begin(nil)
    local function show()
        Menu.show({
            title = L('createTitle'),
            rows = {
                { label = L('ranchName', draft.name ~= '' and draft.name or '-'), run = function()
                    local v = Ask(L('name'), { { label = L('name'), type = 'text', required = true, maxlength = Config.General.maxNameLength } })
                    if v and v[1] then draft.name = U.cut(U.trim(v[1]), Config.General.maxNameLength) end
                    show()
                end },
                -- 0 is allowed here, matching the server (a free or untaxed ranch)
                { label = L('ranchPrice', U.money(draft.price)), run = function()
                    local n = AskNumber(L('price'), L('price'))
                    if n and n >= 0 then draft.price = n elseif n then TipBottom(L('invalidInput')) end
                    show()
                end },
                { label = L('ranchTax', U.money(draft.tax)), run = function()
                    local n = AskNumber(L('tax'), L('tax'))
                    if n and n >= 0 then draft.tax = math.floor(n) elseif n then TipBottom(L('invalidInput')) end
                    show()
                end },
                { label = L('confirm'), run = function()
                    Confirm(L('createTitle'), L('yes'), function()
                        Menu.closeAll()
                        Call('createRanch', draft.name, draft.price, draft.tax, MyPos())
                    end, show)
                end },
            },
        })
    end
    show()
end)

------------------------------------------------------------------------------
-- dashboard (pup-ui app panel); opened by vorp_admin with a LOCAL event
------------------------------------------------------------------------------
local APP = OWNER .. ':admin'
local cache = nil -- { overview, ranches, detail = { id, activity } }
local activeTab = 'overview'

local TABS = {
    { id = 'overview', label = 'Overview', icon = 'chart' },
    { id = 'ranches', label = 'Ranches', icon = 'doc' },
}

local function money(n) return '$' .. U.money(n or 0) end

local function ago(ts, now)
    local s = math.max(0, (now or ts) - ts)
    if s < 60 then return 'just now' end
    if s < 3600 then return math.floor(s / 60) .. 'm ago' end
    if s < 86400 then return math.floor(s / 3600) .. 'h ago' end
    return math.floor(s / 86400) .. 'd ago'
end

local TONE = { DEPOSIT = 'badge-green', WITHDRAW = 'badge-red' }

local function activityTable(title, rows, now, perPage)
    local out = {}
    for _, a in ipairs(rows or {}) do
        out[#out + 1] = { cells = {
            when = { text = ago(a.ts, now) },
            kind = { text = a.type, tone = TONE[a.type] or 'badge-neutral' },
            detail = { text = a.detail },
            by = { text = a.actor },
            ranch = { text = a.ranch },
        } }
    end
    return {
        type = 'table', title = title, perPage = perPage,
        columns = {
            { key = 'when', label = 'When' }, { key = 'kind', label = 'Type' }, { key = 'detail', label = 'Detail' },
            { key = 'by', label = 'By' }, { key = 'ranch', label = 'Ranch' },
        },
        rows = out,
    }
end

local function envText(env, max)
    if (env or 0) <= 0 then return '0 (dead)' end
    return ('%d / %d (%d%%)'):format(env, max, U.round(env / max * 100))
end

local function overviewContent()
    local o = cache and cache.overview
    if not o then return { { type = 'heading', text = 'Overview', sub = 'Loading...' } } end
    return {
        { type = 'heading', text = 'Overview', sub = 'Every ranch on the server: who owns what, what the ledgers hold, and what has happened lately.' },
        { type = 'stats', items = {
            { value = tostring(o.total), label = 'Total ranches' },
            { value = tostring(o.owned), label = 'Owned' },
            { value = tostring(o.forSale), label = 'For sale' },
            { value = money(o.ledger), label = 'Combined ledger' },
        } },
        activityTable('Recent Activity', o.activity, o.now, 8),
    }
end

local function findRanch(id)
    for _, r in ipairs(cache and cache.ranches and cache.ranches.list or {}) do
        if r.id == id then return r end
    end
end

local function ranchesContent()
    local data = cache and cache.ranches
    if not data then return { { type = 'heading', text = 'Ranches', sub = 'Loading...' } } end
    local items = {}
    for _, r in ipairs(data.list) do
        local owner = r.owner or (r.repoed == 1 and 'For Sale (repoed)' or 'For Sale')
        items[#items + 1] = {
            title = ('%s (#%d)'):format(r.name, r.id),
            sub = ('Owner: %s | Ledger %s | Members %d | Cattle %d | Env %s'):format(owner, money(r.ledger), #r.members, r.cattle, envText(r.env, data.envMax)),
            actions = { { id = 'view:' .. r.id, label = 'View' } },
        }
    end
    return {
        { type = 'heading', text = 'Ranches', sub = 'Sorted by ID. Open one for its members and recent activity.' },
        { type = 'list', items = items },
    }
end

local function detailContent(id)
    local r = findRanch(id)
    if not r then return ranchesContent() end
    local envMax = cache.ranches.envMax
    local members = {}
    for _, m in ipairs(r.members) do members[#members + 1] = { title = m.name, sub = m.role } end
    if #members == 0 then members[1] = { title = 'Nobody', sub = 'No owner or hands' } end
    local d = cache.detail
    local content = {
        { type = 'heading', text = ('%s (#%d)'):format(r.name, r.id),
          sub = ('Owner: %s | Tax: %s | Cow pen: %s | Chicken coop: %s'):format(r.owner or 'none', money(r.tax), r.hasPen and 'yes' or 'no', r.hasCoop and 'yes' or 'no') },
        { type = 'stats', items = {
            { value = money(r.ledger), label = 'Ledger' },
            { value = tostring(#r.members), label = 'Members' },
            { value = tostring(r.cattle), label = 'Cattle' },
            { value = ('%d / %d'):format(r.milk, r.eggs), label = 'Milk / eggs' },
            { value = envText(r.env, envMax), label = 'Environment' },
        } },
        { type = 'list', items = members },
    }
    if d and d.id == id then
        content[#content + 1] = activityTable('Latest Activity', d.activity, d.now, nil)
    else
        content[#content + 1] = { type = 'heading', text = 'Latest Activity', sub = 'Loading...' }
    end
    content[#content + 1] = { type = 'actions', buttons = {
        { id = 'back', label = 'Back to list' },
        { id = 'tp:' .. r.id, label = 'Teleport to Ranch', tone = 'red' },
    } }
    return content
end

local function render()
    if not cache then return end
    local content
    if activeTab == 'overview' then content = overviewContent()
    elseif cache.viewing then content = detailContent(cache.viewing)
    else content = ranchesContent() end
    exports['pup-ui']:UpdateApp({ active = activeTab, content = content })
end

local function refresh(tab)
    CreateThread(function()
        local data = Call('adminData', tab)
        if not cache or type(data) ~= 'table' then return end
        cache[tab] = data
        if activeTab == tab then render() end
    end)
end

AddEventHandler('pup_ranchero:openAdminTool', function()
    CreateThread(function()
        local data = Call('adminData', 'overview')
        if type(data) ~= 'table' then return end
        cache = { overview = data }
        activeTab = 'overview'
        exports['pup-ui']:OpenApp({
            owner = APP, title = 'RANCHES', subtitle = 'ADMINISTRATION', badge = 'RANCH ADMIN',
            tabs = TABS, active = 'overview', content = overviewContent(),
        })
    end)
end)

AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= APP or not cache then return end
    if tab ~= 'overview' and tab ~= 'ranches' then return end
    activeTab = tab
    cache.viewing = nil
    render()       -- cached first
    refresh(tab)   -- then fresh data in the background
end)

AddEventHandler('pup-ui:client:appAction', function(owner, action)
    if owner ~= APP or not cache or type(action) ~= 'string' then return end
    if action == 'back' then
        cache.viewing = nil
        render()
        return
    end
    local view = tonumber(action:match('^view:(%d+)$'))
    if view then
        cache.viewing = view
        render()
        CreateThread(function()
            local data = Call('adminData', 'activity', view)
            if not cache or type(data) ~= 'table' then return end
            cache.detail = { id = view, activity = data.activity, now = data.now }
            if cache.viewing == view then render() end
        end)
        return
    end
    local tp = tonumber(action:match('^tp:(%d+)$'))
    if tp then
        local r = findRanch(tp)
        exports['pup-ui']:CloseApp()
        cache = nil
        if r and r.coords then
            SetEntityCoords(PlayerPedId(), r.coords.x + 0.0, r.coords.y + 0.0, r.coords.z + 1.0, false, false, false, false)
            TipBottom(L('teleported', r.name))
        else
            TipBottom(L('noCoords'))
        end
    end
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner == APP then cache = nil end
end)
