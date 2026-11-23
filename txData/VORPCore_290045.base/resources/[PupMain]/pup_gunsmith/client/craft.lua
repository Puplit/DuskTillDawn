-- pup_gunsmith | crafting station: the pup-ui app screen, the craft itself and the skill bar

CraftCl = {}

local WEAPON_ORDER <const> = { 'Melee', 'Bows', 'Rifles', 'Repeaters', 'Pistols', 'Revolvers', 'Throwable', 'Shotguns', 'Misc.' }
local WEAPON_ICONS <const> = {
    Melee = 'skull', Bows = 'flag', Rifles = 'fire', Repeaters = 'box', Pistols = 'star',
    Revolvers = 'medal', Throwable = 'warning', Shotguns = 'shield', ['Misc.'] = 'doc',
}
local AMMO_ORDER <const> = { 'Repeater', 'Revolver', 'Rifle', 'Shotgun', 'Pistol', 'Arrow', 'Varmint Ammo', 'Throwing' }
local AMMO_ICONS <const> = {
    Repeater = 'box', Revolver = 'medal', Rifle = 'fire', Shotgun = 'shield', Pistol = 'star',
    Arrow = 'flag', ['Varmint Ammo'] = 'info', Throwing = 'warning',
}

local app = nil       -- the open station screen
local customDefaults = {} -- text the player typed last time (this game session only)

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function orderedCats(cats, fixed)
    local out, seen, rest = {}, {}, {}
    for _, c in ipairs(fixed) do
        if cats[c] then out[#out + 1] = c; seen[c] = true end
    end
    for c in pairs(cats) do
        if not seen[c] then rest[#rest + 1] = c end
    end
    table.sort(rest)
    for _, c in ipairs(rest) do out[#out + 1] = c end
    return out
end

local function ammoLabel(cat)
    if cat:find('Ammo', 1, true) then return cat end
    return cat .. L('ammo_suffix')
end

local function canMake(rec)
    for _, m in ipairs(rec.mats or {}) do
        local have = app.counts[m.name]
        if have ~= nil and (tonumber(have) or 0) < (tonumber(m.amount) or 1) then return false end
    end
    return true
end

local function xpText()
    return L('xp_level', math.floor(tonumber(app.xp) or 0))
end

local function badge()
    local prefix = ''
    if app.jobOnly and type(app.jobs) == 'table' and #app.jobs > 0 then
        local up = {}
        for i, j in ipairs(app.jobs) do up[i] = tostring(j):upper() end
        prefix = table.concat(up, '/') .. '  |  '
    end
    return prefix .. xpText()
end

local function buildTabs()
    local tabs = {}
    app.tabOrder = {}
    local wcats = orderedCats(app.weapons, WEAPON_ORDER)
    if #wcats > 0 then
        tabs[#tabs + 1] = { section = L('section_weapons') }
        for _, c in ipairs(wcats) do
            local id = 'w:' .. c
            tabs[#tabs + 1] = { id = id, label = c, icon = WEAPON_ICONS[c] or 'box' }
            app.tabOrder[#app.tabOrder + 1] = id
        end
    end
    local acats = orderedCats(app.ammo, AMMO_ORDER)
    if #acats > 0 then
        tabs[#tabs + 1] = { section = L('section_ammo') }
        for _, c in ipairs(acats) do
            local id = 'a:' .. c
            tabs[#tabs + 1] = { id = id, label = ammoLabel(c), icon = AMMO_ICONS[c] or 'box' }
            app.tabOrder[#app.tabOrder + 1] = id
        end
    end
    if app.box then
        tabs[#tabs + 1] = { section = L('section_storage') }
        tabs[#tabs + 1] = { id = 'box', label = L('box_name'), icon = 'box' }
        app.tabOrder[#app.tabOrder + 1] = 'box'
    end
    if app.term then
        tabs[#tabs + 1] = { section = L('section_search') }
        tabs[#tabs + 1] = { id = 'results', label = L('tab_results'), icon = 'info' }
    end
    return tabs
end

-- the recipe rows for a set of (kind, category, recipe) entries
local function recipeList(entries)
    local rows = {}
    for _, e in ipairs(entries) do
        local ok = canMake(e.rec)
        if ok or not app.filter then rows[#rows + 1] = { e = e, ok = ok } end
    end
    table.sort(rows, function(a, b)
        if a.ok ~= b.ok then return a.ok end
        return tostring(a.e.rec.label):lower() < tostring(b.e.rec.label):lower()
    end)
    local items = {}
    for _, r in ipairs(rows) do
        local rec = r.e.rec
        app.rows[#app.rows + 1] = r.e
        local mats = {}
        for _, m in ipairs(rec.mats or {}) do
            mats[#mats + 1] = { img = GS.itemImage(m.name), amount = m.amount, label = m.label }
        end
        table.sort(mats, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
        local art = r.e.kind == 'weapon' and tostring(rec.weapon or ''):lower() or tostring(rec.item or '')
        items[#items + 1] = {
            title = rec.label,
            img = GS.itemImage(art),
            mats = mats,
            actions = { { id = 'craft:' .. #app.rows, label = L('craft_button'), tone = r.ok and 'green' or 'ghost' } },
        }
    end
    return items
end

local function controls()
    return {
        { type = 'search', id = 'search', value = app.rawTerm or '', placeholder = L('search_placeholder') },
        { type = 'actions', buttons = { {
            id = 'filter',
            label = app.filter and L('filter_on') or L('filter_off'),
            tone = app.filter and 'red' or 'ghost',
        } } },
    }
end

local function entriesOf(kind, cat)
    local out = {}
    local src = kind == 'weapon' and app.weapons or app.ammo
    for _, rec in ipairs(src[cat] or {}) do out[#out + 1] = { kind = kind, category = cat, rec = rec } end
    return out
end

local function content(tab)
    app.rows = {}
    local blocks = {}
    if tab == 'box' then
        blocks[#blocks + 1] = { type = 'heading', text = L('box_heading'), sub = L('box_sub') }
        blocks[#blocks + 1] = { type = 'list', items = { {
            title = L('box_row'),
            actions = { { id = 'openBox', label = L('box_open'), tone = 'red' } },
        } } }
        return blocks
    end
    if tab == 'results' then
        local matches = {}
        for _, kind in ipairs({ 'weapon', 'ammo' }) do
            local cats = kind == 'weapon' and app.weapons or app.ammo
            for cat in pairs(cats) do
                for _, e in ipairs(entriesOf(kind, cat)) do
                    local hay = { tostring(e.rec.label) }
                    for _, m in ipairs(e.rec.mats or {}) do hay[#hay + 1] = tostring(m.label) end
                    if table.concat(hay, '\n'):lower():find(app.term, 1, true) then matches[#matches + 1] = e end
                end
            end
        end
        blocks[#blocks + 1] = { type = 'heading', text = L('search_heading', app.rawTerm or app.term), sub = L('search_sub') }
        blocks[#blocks + 1] = { type = 'stats', items = { { value = #matches, label = L('search_matches') } } }
        for _, b in ipairs(controls()) do blocks[#blocks + 1] = b end
        local items = recipeList(matches)
        if #items == 0 then
            blocks[#blocks + 1] = { type = 'note', text = L('search_none') }
        else
            blocks[#blocks + 1] = { type = 'list', items = items }
        end
        return blocks
    end

    local kind = tab:sub(1, 2) == 'w:' and 'weapon' or 'ammo'
    local cat = tab:sub(3)
    local label = kind == 'weapon' and cat or ammoLabel(cat)
    blocks[#blocks + 1] = { type = 'heading', text = label, sub = xpText() }
    for _, b in ipairs(controls()) do blocks[#blocks + 1] = b end
    blocks[#blocks + 1] = { type = 'list', items = recipeList(entriesOf(kind, cat)) }
    return blocks
end

local function openApp()
    local tabs = buildTabs()
    if not app.tab or (app.tab == 'results' and not app.term) then app.tab = app.tabOrder[1] end
    exports['pup-ui']:OpenApp({
        owner = OWNER.app,
        title = L('app_title'),
        subtitle = L('app_subtitle'),
        badge = badge(),
        tabs = tabs,
        active = app.tab,
        content = app.tab and content(app.tab) or {},
    })
end

local function refresh()
    exports['pup-ui']:UpdateApp({ active = app.tab, content = content(app.tab) })
end

local function closeStation()
    app = nil
    Cl.freeze(false)
    if Cl.busy == 'station' then Cl.busy = nil end
end

---------------------------------------------------------------------------
-- open
---------------------------------------------------------------------------
function CraftCl.open(station)
    local res = Cl.rpc('stationOpen', station.name)
    if not res or not res.ok then
        Cl.busy = nil
        Cl.tip(res and res.msg)
        return
    end
    app = {
        station = station,
        xp = tonumber(res.xp) or 0,
        weapons = type(res.weapons) == 'table' and res.weapons or {},
        ammo = type(res.ammo) == 'table' and res.ammo or {},
        counts = type(res.counts) == 'table' and res.counts or {},
        jobs = res.jobs,
        jobOnly = res.jobOnly == true,
        box = res.box == true,
        filter = false,
        rows = {},
    }
    Cl.busy = 'station'
    Cl.freeze(true)
    Cl.blockJournal()
    openApp()
end

---------------------------------------------------------------------------
-- the craft
---------------------------------------------------------------------------
local function skillBar(diff, kind)
    local sb = Config.SkillBar
    local v = tonumber(diff) or 3000
    local level = v > 20 and (v - 2000) / 1000 or v
    if level < 0 then level = 0 end
    local p = promise.new()
    local settled = false
    local function settle(result)
        if settled then return end
        settled = true
        p:resolve(result)
    end
    local started = pcall(function()
        exports['pup-minigames']:skill_bar({
            style = 'default',
            icon = kind == 'weapon' and sb.iconWeapon or sb.iconAmmo,
            orientation = 1,
            area_size = GS.clamp(sb.baseZone - sb.zoneLossPerLvl * level, sb.minZone, sb.baseZone),
            perfect_area_size = sb.perfectZone,
            speed = GS.clamp(sb.baseSpeed + sb.speedPerLvl * level, sb.baseSpeed, sb.maxSpeed),
            moving_icon = false,
        }, function(result) settle(result) end)
    end)
    if not started then return false end
    -- a game that never reports back counts as lost
    SetTimeout(120000, function() settle('failed') end)
    local result = Citizen.Await(p)
    return result == 'success' or result == 'perfect'
end

local noSerial = {}
for _, w in ipairs(Config.Craft.noSerial) do noSerial[w:upper()] = true end

local function askCustom(rec)
    local opts = Config.Craft.custom
    local fields, keys = {}, {}
    local max = Config.Craft.customMax
    if opts.serial and not noSerial[tostring(rec.weapon or ''):upper()] then
        fields[#fields + 1] = { label = L('custom_serial'), type = 'text', maxlength = max.serial, default = customDefaults.serial }
        keys[#keys + 1] = 'serial'
    end
    if opts.label then
        fields[#fields + 1] = { label = L('custom_label'), type = 'text', maxlength = max.label, default = customDefaults.label }
        keys[#keys + 1] = 'label'
    end
    if opts.description then
        fields[#fields + 1] = { label = L('custom_desc'), type = 'textarea', maxlength = max.description, default = customDefaults.description }
        keys[#keys + 1] = 'description'
    end
    if #fields == 0 then return {} end
    local values = Cl.askInput({ owner = OWNER.custom, title = L('craft_form_title'), fields = fields })
    if not values then return nil end
    local out = {}
    for i, k in ipairs(keys) do
        local v = values[i]
        if type(v) == 'string' and GS.trim(v) ~= '' then
            out[k] = v
            customDefaults[k] = v
        end
    end
    return out
end

local function craft(entry)
    exports['pup-ui']:CloseApp()
    closeStation()
    Cl.busy = 'crafting'

    local rec = entry.rec
    local amount, custom = 1, nil
    if entry.kind == 'ammo' then
        amount = Cl.askAmount()
        if not amount then Cl.busy = nil return end
    else
        custom = askCustom(rec)
        if custom == nil then Cl.busy = nil return end
    end

    local start = Cl.rpc('craftStart', entry.kind, entry.category, rec.label, amount, custom)
    if not start or not start.ok then
        Cl.tip(start and start.msg)
        Cl.busy = nil
        return
    end

    local ped = PlayerPedId()
    TaskStartScenarioInPlaceHash(ped, joaat(Config.Craft.scenario), Config.Craft.scenarioMs, true, false, false, false)
    TriggerEvent('vorp_inventory:CloseInv')
    local won = skillBar(start.diff, entry.kind)

    local fin = Cl.rpc('craftFinish', start.ticket, won)
    ClearPedTasks(PlayerPedId())
    if fin then
        Cl.tip(fin.msg)
        if fin.note then Cl.tip(fin.note) end
        if fin.ok and (tonumber(fin.gained) or 0) > 0 then
            Cl.tip(L('xp_after', math.floor(tonumber(fin.total) or 0), math.floor(tonumber(fin.gained) or 0)))
        end
    end
    if Cl.busy == 'crafting' then Cl.busy = nil end
end

---------------------------------------------------------------------------
-- pup-ui app events
---------------------------------------------------------------------------
AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= OWNER.app or not app or type(tab) ~= 'string' then return end
    app.tab = tab
    refresh()
end)

local function setSearch(value)
    local raw = GS.trim(type(value) == 'string' and value or '')
    local term = raw:lower()
    local had = app.term ~= nil
    if term == '' then
        app.term, app.rawTerm = nil, nil
        if had then
            app.tab = app.tabOrder[1]
            openApp() -- the Results tab goes away
        end
        return
    end
    app.term, app.rawTerm = term, raw
    app.tab = 'results'
    if had then refresh() else openApp() end -- the Results tab appears
end

AddEventHandler('pup-ui:client:appAction', function(owner, action, data)
    if owner ~= OWNER.app or not app or type(action) ~= 'string' then return end
    if action == 'search' then
        setSearch(type(data) == 'table' and data.value or '')
    elseif action == 'filter' then
        app.filter = not app.filter
        refresh()
    elseif action == 'openBox' then
        exports['pup-ui']:CloseApp()
        closeStation()
        CreateThread(function()
            local res = Cl.rpc('openBox')
            if not res or not res.ok then Cl.tip((res and res.msg) or L('stand_station')) end
        end)
    else
        local n = tonumber(action:match('^craft:(%d+)$'))
        local entry = n and app.rows[n]
        if entry then CreateThread(function() craft(entry) end) end
    end
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner == OWNER.app and app then closeStation() end
end)

function CraftCl.stop()
    if app then
        pcall(function() exports['pup-ui']:CloseApp() end)
        app = nil
    end
end
