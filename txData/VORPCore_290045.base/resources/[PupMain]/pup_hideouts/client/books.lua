-- pup_hideouts | the books (management menu), the still and production menus, member questions,
-- relocation, the owner's webhook, founding with plans and the staff create command

local H <const> = Config.Hideouts

local function row(id) return HX.rows[id] end

-- refresh one row from the server (at most 2 s)
local function refreshRow(id)
    local ok, fresh = HX.call('row', 2000, id)
    if ok and type(fresh) == 'table' and fresh.id then HX.rows[fresh.id] = fresh end
    return HX.rows[id]
end

-- run a server action from a menu; refresh the page afterwards
local function act(name, ...)
    local ok, res = HX.call(name, 6000, ...)
    if not ok then HX.tip(L('no_answer')) return false end
    HX.menuRefreshSoon()
    return res
end

local function askNumber(title, subtitle)
    local v = HX.input(title, subtitle, { { label = L('amount'), type = 'number', min = 1, required = true } })
    if not v then return nil end
    local n = U.posInt(v[1])
    if not n then HX.tip(L('bad_amount')) end
    return n
end

local function askText(title, subtitle, label, max)
    local v = HX.input(title, subtitle, { { label = label, type = 'text', required = true, maxlength = max or 50 } })
    if not v or type(v[1]) ~= 'string' then return nil end
    local s = U.trim(v[1])
    if s == '' then return nil end
    return s
end

local function askServerId()
    local v = HX.input(L('coowners_menu'), nil, { { label = L('server_id'), type = 'number', min = 1, required = true } })
    if not v then return nil end
    local n = U.posInt(v[1])
    if not n then HX.tip(L('invalid_id')) end
    return n
end

-- one person in the books / production at a time
local function takeLock(id)
    local ok, res = HX.call('menuLock', 5000, id)
    if not ok then HX.tip(L('no_answer')) return false end
    if res == 'busy' then HX.tip(L('menu_in_use')) return false end
    return res == 'ok'
end

----------------------------------------------------------------------------------------------------
-- pages of the books
----------------------------------------------------------------------------------------------------
local P = {}

function P.themes(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {}
        for _, t in ipairs(Config.Themes) do
            if t.set ~= r.theme then
                opts[#opts + 1] = { label = t.label, description = L('price_prefix', U.money(t.price)),
                    onSelect = function() act('buyTheme', id, t.set) end }
            end
        end
        return { title = L('theme'), subtitle = L('theme_desc'), options = opts }
    end
end

function P.decorCategory(id, cat)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local current = (r.upgrades or {})[cat]
        local opts = {}
        if current then
            opts[#opts + 1] = { label = L('remove_upgrade'), description = L('remove_upgrade_desc'),
                onSelect = function() act('removeDecor', id, cat) end }
        end
        for _, d in ipairs(Config.Decorations) do
            if d.category == cat and d.set ~= current then
                opts[#opts + 1] = { label = L('decor_price', d.label, U.money(d.price)),
                    onSelect = function() act('buyDecor', id, d.set) end }
            end
        end
        return { title = Config.DecorCategoryLabels[cat] or cat, subtitle = L('upgrades_menu'), options = opts }
    end
end

function P.upgrades(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {}
        for _, cat in ipairs(Config.DecorCategories) do
            opts[#opts + 1] = { label = Config.DecorCategoryLabels[cat] or cat,
                onSelect = function(cur) HX.page(P.decorCategory(id, cat), cur) end }
        end
        return { title = L('upgrades'), subtitle = L('upgrades_desc'), options = opts }
    end
end

function P.ledger(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        return {
            title = L('ledger_menu'), subtitle = L('ledger_amount', U.money(r.ledger or 0)),
            options = {
                { label = L('withdraw'), description = L('withdraw_desc'), onSelect = function()
                    local n = askNumber(L('withdraw'), L('withdraw_desc'))
                    if n then act('ledgerWithdraw', id, n) end
                end },
                { label = L('deposit'), description = L('deposit_desc'), onSelect = function()
                    local n = askNumber(L('deposit'), L('deposit_desc'))
                    if n then act('ledgerDeposit', id, n) end
                end },
            },
        }
    end
end

function P.tier(id, tierName)
    return function()
        local r = row(id)
        local t = U.tierByName(tierName)
        if not r or not r.member or not t or t.level ~= (r.invlevel or 0) then return nil end
        local opts = { { label = L('cash_price', U.money(t.price)) } }
        for _, it in ipairs(t.items) do
            opts[#opts + 1] = { label = L('item_requirement', it.label, it.amount) }
        end
        opts[#opts + 1] = { label = L('confirm_purchase'), onSelect = function() act('buyTier', id, t.name) end }
        return { title = t.name, subtitle = L('add_slots', t.slots), options = opts }
    end
end

function P.tiers(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {}
        for _, t in ipairs(U.tiersAt(r.invlevel or 0)) do
            opts[#opts + 1] = { label = t.name, onSelect = function(cur) HX.page(P.tier(id, t.name), cur) end }
        end
        if #opts == 0 then return nil end
        return { title = L('upgrade_inventory'), subtitle = L('current_slots', r.invslots or 0), options = opts }
    end
end

local function openStorage(id, cur)
    local r = row(id)
    local tiers = U.tiersAt(r and r.invlevel or 0)
    if #tiers == 0 then return HX.bottom(L('stash_maxed')) end
    if #tiers == 1 then return HX.page(P.tier(id, tiers[1].name), cur) end
    HX.page(P.tiers(id), cur)
end

function P.removeCoowner(id)
    return function()
        local r = row(id)
        if not r or r.role ~= 'owner' then return nil end
        local opts = {}
        for _, co in ipairs(r.coowners or {}) do
            local charid, name = co.charid, tostring(co.name or '?')
            opts[#opts + 1] = { label = name, onSelect = function(cur)
                HX.confirm(L('remove_coowner'), L('are_you_sure'), cur, function()
                    act('removeCoowner', id, charid)
                    HX.menuBack(cur)
                end)
            end }
        end
        if #opts == 0 then return nil end
        return { title = L('remove_coowner'), subtitle = L('coowners_desc'), options = opts }
    end
end

function P.coowners(id)
    return function()
        local r = row(id)
        if not r or r.role ~= 'owner' then return nil end
        local opts = {
            { label = L('add_coowner'), onSelect = function()
                local sid = askServerId()
                if sid then act('addCoowner', id, sid) end
            end },
            { label = L('transfer'), description = L('transfer_desc'), onSelect = function(cur)
                local sid = askServerId()
                if not sid then return end
                HX.confirm(L('transfer'), L('transfer_confirm'), cur, function()
                    act('transfer', id, sid)
                    HX.menuBack(cur)
                end)
            end },
        }
        if #(r.coowners or {}) > 0 then
            opts[#opts + 1] = { label = L('remove_coowner'), onSelect = function(cur) HX.page(P.removeCoowner(id), cur) end }
        end
        return { title = L('coowners_menu'), subtitle = L('coowners_desc'), options = opts }
    end
end

local function setWebhook(id)
    local url = askText(L('add_webhook'), L('add_webhook_desc'), L('discord_webhook'), 255)
    if not url then return end
    if not U.validWebhook(url) then return HX.tip(L('webhook_invalid')) end
    act('setWebhook', id, url)
end

function P.logistics(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {
            { label = L('change_name'), description = L('change_name_desc', H.renamePrice), onSelect = function()
                local name = askText(L('change_name'), L('change_name_desc', H.renamePrice), L('name'), H.nameMax)
                if name then act('rename', id, name) end
            end },
            { label = L('ledger'), description = L('ledger_desc'), onSelect = function(cur) HX.page(P.ledger(id), cur) end },
        }
        if (r.invlevel or 0) == 0 then
            opts[#opts + 1] = { label = L('buy_inventory'), description = L('buy_inventory_desc'),
                onSelect = function(cur) openStorage(id, cur) end }
        else
            opts[#opts + 1] = { label = L('upgrade_inventory'), description = L('current_slots', r.invslots or 0),
                onSelect = function(cur) openStorage(id, cur) end }
        end
        if not r.bookie then
            opts[#opts + 1] = { label = L('buy_bookie'), description = L('buy_bookie_desc', Config.Bookie.price),
                onSelect = function() act('buyBookie', id) end }
        end
        if r.role == 'owner' then
            opts[#opts + 1] = { label = L('move_shack'), description = L('move_shack_desc', H.relocatePrice), onSelect = function(cur)
                HX.confirm(L('move_shack'), L('are_you_sure'), cur, function()
                    local ok, started = HX.call('relocateStart', 6000, id)
                    if not ok then return HX.tip(L('no_answer')) end
                    if started then HX.menuClose() else HX.menuBack(cur) end
                end)
            end }
            opts[#opts + 1] = { label = L('coowners_menu'), description = L('coowners_desc'),
                onSelect = function(cur) HX.page(P.coowners(id), cur) end }
            if Config.Logs.ownerWebhooks then
                opts[#opts + 1] = { label = L('add_webhook') .. (r.haswebhook and L('webhook_set_tag') or ''),
                    description = L('add_webhook_desc'), onSelect = function() setWebhook(id) end }
            end
        end
        return { title = L('logistics_menu'), subtitle = L('logistics_desc'), options = opts }
    end
end

----------------------------------------------------------------------------------------------------
-- the still (from the books): parts missions and crafting the next level
----------------------------------------------------------------------------------------------------
function P.craft(id, level)
    return function()
        local r = row(id)
        local def = Config.Stills[level]
        if not r or not r.member or not def then return nil end
        local opts = {}
        for _, p in ipairs(def.parts) do opts[#opts + 1] = { label = L('part_line', p.amount, p.label) } end
        opts[#opts + 1] = { label = L('craft_still_btn'), onSelect = function()
            act('craftStill', id, level)
            HX.menuClose()
        end }
        return { title = L('craft_still', level), subtitle = L('craft_still_desc', level), options = opts }
    end
end

function P.still(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local level = r.still and r.still.stilllevel or 0
        local opts = {}
        if not r.jobCooldown then
            for _, jl in ipairs(U.jobsFor(level)) do
                local lvl = Config.WagonLevels[jl]
                if lvl and #lvl.locations > 0 then
                    opts[#opts + 1] = { label = L('mission_' .. jl), description = L('mission_desc'), onSelect = function()
                        HX.tip(L('exit_to_start'))
                        HX.call('jobStart', 6000, id, jl)
                        HX.menuClose()
                    end }
                end
            end
        end
        if level < 3 and Config.Stills[level + 1] then
            opts[#opts + 1] = { label = L('craft_still', level + 1), description = L('craft_still_desc', level + 1),
                onSelect = function(cur) HX.page(P.craft(id, level + 1), cur) end }
        end
        return { title = L('still_mgmt_title'), subtitle = L('still_level', level), options = opts }
    end
end

function P.root(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {
            { label = L('theme'), description = L('theme_desc'), onSelect = function(cur) HX.page(P.themes(id), cur) end },
            { label = L('upgrades'), description = L('upgrades_desc'), onSelect = function(cur) HX.page(P.upgrades(id), cur) end },
            { label = L('logistics'), description = L('logistics_desc'), onSelect = function(cur) HX.page(P.logistics(id), cur) end },
            { label = L('still_menu'), description = L('still_menu_desc'), onSelect = function(cur) HX.page(P.still(id), cur) end },
        }
        if r.role == 'coowner' then
            opts[#opts + 1] = { label = L('leave_hideout'), description = L('leave_hideout_desc'), onSelect = function(cur)
                HX.confirm(L('leave_hideout'), L('are_you_sure'), cur, function()
                    HX.call('leave', 6000, id)
                    HX.menuClose()
                end)
            end }
        end
        return { title = L('mgmt_title'), subtitle = L('mgmt_sub'), options = opts }
    end
end

----------------------------------------------------------------------------------------------------
-- sitting in the books
----------------------------------------------------------------------------------------------------
local function standUp(id, back)
    HX.send('menuUnlock', id)
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if back and HX.insideId == id and not HX.leaving and not HX.dead() then
        SetEntityCoords(ped, back.x, back.y, back.z, false, false, false, false)
        SetEntityHeading(ped, back.w)
    end
end

function HX.openBooks(id)
    if HX.menuOpen or HX.busy then return end
    HX.busy = true
    local r = refreshRow(id)
    if not r or not r.member or not takeLock(id) then HX.busy = false return end
    HX.busy = false
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local back = vector4(p.x, p.y, p.z, GetEntityHeading(ped))
    local seat = U.zone(r.zone).seat
    TaskStartScenarioAtPosition(ped, joaat(seat.scenario), seat.coords.x, seat.coords.y, seat.coords.z,
        seat.heading % 360.0, -1, true, true, 0, false, 0)
    HX.menuClose()
    local root = P.root(id)
    local function onClose() standUp(id, back) end
    -- onClose lives inside the build, so every rebuild of the root page keeps it
    local function build()
        local s = root()
        if s then s.onClose = onClose end
        return s
    end
    local spec = build()
    if not spec then return standUp(id, back) end
    spec.build = build
    HX.menu(spec, nil)
end

----------------------------------------------------------------------------------------------------
-- production (at the still)
----------------------------------------------------------------------------------------------------
local function workAnim(zone, kind)
    local spot = kind == 'mash' and zone.mashSpot or zone.stillSpot
    local a = zone.workAnim
    local ped = PlayerPedId()
    SetEntityCoords(ped, spot.coords.x, spot.coords.y, spot.coords.z - 1.0, false, false, false, false)
    SetEntityHeading(ped, spot.heading)
    FreezeEntityPosition(ped, true)
    if HX.loadDict(a.dict) then TaskPlayAnim(ped, a.dict, a.name, 8.0, -8.0, a.seconds * 1000, 1, 0, false, false, false) end
    Wait(a.seconds * 1000)
    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

function P.recipe(id, kind, recipe)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local opts = {}
        for _, it in ipairs(recipe.items) do opts[#opts + 1] = { label = L('part_line', it.amount, it.label) } end
        opts[#opts + 1] = { label = L('confirm'), onSelect = function()
            local ok, started = HX.call('prodStart', 6000, id, kind, recipe.resultitem)
            if not ok then return HX.tip(L('no_answer')) end
            if not started then return HX.menuRefreshSoon() end
            HX.menuClose()
            HX.tip(L('started_batch'))
            workAnim(U.zone(r.zone), kind)
        end }
        return { title = recipe.label, subtitle = kind == 'mash' and L('mash_recipe') or L('distill_recipe'), options = opts }
    end
end

function P.recipes(id, kind)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local level = r.still and r.still.stilllevel or 0
        local opts = {}
        for _, rc in ipairs(kind == 'mash' and Config.Mash or Config.Distill) do
            if (kind == 'mash' or rc.distill) and rc.items and (rc.stilllevel or 1) <= level then
                opts[#opts + 1] = { label = rc.label, onSelect = function(cur) HX.page(P.recipe(id, kind, rc), cur) end }
            end
        end
        return { title = kind == 'mash' and L('mash_menu') or L('distill_menu'), subtitle = L('still_level', level), options = opts }
    end
end

function P.production(id)
    return function()
        local r = row(id)
        if not r or not r.member then return nil end
        local level = r.still and r.still.stilllevel or 0
        local opts = {}
        local mashLeft = r.mashinfo and HX.secsLeft(r, 'mash') or 0
        if mashLeft > 0 then
            opts[#opts + 1] = { label = L('mash_ready_in', U.mmss(mashLeft)) }
        else
            opts[#opts + 1] = { label = L('mash'), description = L('mash_desc'),
                onSelect = function(cur) HX.page(P.recipes(id, 'mash'), cur) end }
        end
        local stillLeft = r.stillinfo and HX.secsLeft(r, 'distill') or 0
        if stillLeft > 0 then
            opts[#opts + 1] = { label = L('shine_ready_in', U.mmss(stillLeft)) }
        else
            opts[#opts + 1] = { label = L('still'), description = L('still_desc'),
                onSelect = function(cur) HX.page(P.recipes(id, 'distill'), cur) end }
        end
        return { title = L('prod_title'), subtitle = L('still_level', level), options = opts }
    end
end

function HX.openProduction(id)
    if HX.menuOpen or HX.busy then return end
    HX.busy = true
    local r = refreshRow(id)
    if not r or not r.member or not takeLock(id) then HX.busy = false return end
    HX.busy = false
    HX.menuClose()
    local page = P.production(id)
    local function onClose() HX.send('menuUnlock', id) end
    local function build()
        local s = page()
        if s then s.onClose = onClose end
        return s
    end
    local spec = build()
    if not spec then return onClose() end
    spec.build = build
    HX.menu(spec, nil)
end

-- a change to the hideout on screen refreshes the open page
AddEventHandler('pup_hideouts:rowChanged', function(id)
    if HX.menuOpen and HX.insideId == id then HX.menuRefreshSoon() end
end)

----------------------------------------------------------------------------------------------------
-- being asked to join or take over a hideout
----------------------------------------------------------------------------------------------------
local consent = nil -- { token, answered }

RegisterNetEvent('pup_hideouts:consentAsk', function(token, title, sub)
    local c = { token = token, answered = false }
    HX.menuClose()
    consent = c
    local function answer(yes)
        if c.answered then return end
        c.answered = true
        HX.send('consentAnswer', c.token, yes)
    end
    HX.menu({
        title = tostring(title or ''), subtitle = tostring(sub or ''),
        options = {
            { label = L('accept'), onSelect = function() answer(true); HX.menuClose() end },
            { label = L('decline'), onSelect = function() answer(false); HX.menuClose() end },
        },
        onClose = function() answer(false); if consent == c then consent = nil end end, -- Esc counts as no
    }, nil)
end)

RegisterNetEvent('pup_hideouts:consentClose', function(token)
    if consent and consent.token == token then
        consent.answered = true
        consent = nil
        HX.menuClose()
    end
end)

----------------------------------------------------------------------------------------------------
-- relocation
----------------------------------------------------------------------------------------------------
local relocating = nil

local function drawLine(text, y)
    SetTextScale(0.0, 0.42)
    SetTextColor(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    DisplayText(CreateVarString(10, 'LITERAL_STRING', text), 0.5, y)
end

RegisterNetEvent('pup_hideouts:relocateBegin', function(id)
    if relocating then relocating = id return end
    relocating = id
    CreateThread(function()
        while relocating do
            Wait(0)
            drawLine(L('relocate_go', H.relocateCommand), 0.86)
            drawLine(L('relocate_cancel_hint', H.relocateCommand), 0.895)
        end
    end)
end)

RegisterNetEvent('pup_hideouts:relocateEnd', function() relocating = nil end)

RegisterCommand(H.relocateCommand, function(_, args)
    if args[1] and tostring(args[1]):lower() == 'cancel' then
        CreateThread(function() HX.call('relocateCancel', 5000) end)
        return
    end
    if not relocating then return HX.tip(L('no_relocation')) end
    if HX.insideId then return HX.tip(L('relocate_inside')) end
    local pos = HX.pos()
    if HX.inBlockedTown(pos) then return HX.tip(L('town_relocate')) end
    CreateThread(function()
        local ok = HX.call('relocateHere', 6000, { x = pos.x, y = pos.y, z = pos.z })
        if not ok then HX.tip(L('no_answer')) end
    end)
end, false)

----------------------------------------------------------------------------------------------------
-- founding a hideout with plans
----------------------------------------------------------------------------------------------------
-- nil when the spot is fine, else the locale text to show
local function spotProblem(list)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if IsEntityInWater(ped) then return L('no_water') end
    if HX.inBlockedTown(pos) then return L('town_plans') end
    for _, e in ipairs(type(list) == 'table' and list or {}) do
        if not U.isOrigin(e.c) then
            local need = e.owned and H.spacingOwned or H.spacingUnowned
            local d = U.dist(pos, e.c)
            if d < need then return L('too_close_other', math.floor(d), math.floor(need)) end
        end
    end
    return nil
end

local planning = false
RegisterNetEvent('pup_hideouts:plansBegin', function(list)
    if planning then return end
    planning = true
    CreateThread(function()
        local why = spotProblem(list)
        if why then HX.tip(why) planning = false return end
        local v = HX.input(L('plans_name_title'), L('plans_name_sub'),
            { { label = L('name'), type = 'text', required = true, maxlength = H.nameMax } })
        if not v then planning = false return end
        why = spotProblem(list) -- they may have walked while typing
        if why then HX.tip(why) planning = false return end
        local pos = HX.pos()
        local ok = HX.call('plansFound', 8000, { x = pos.x, y = pos.y, z = pos.z }, tostring(v[1] or ''))
        if not ok then HX.tip(L('no_answer')) end
        planning = false
    end)
end)

----------------------------------------------------------------------------------------------------
-- staff: a new hideout for sale at your feet
----------------------------------------------------------------------------------------------------
RegisterCommand('createhideout', function()
    CreateThread(function()
        local f = HX.refreshFlags()
        if not f.staff then return HX.tip(L('no_permission')) end
        local v = HX.input(L('create_title'), L('zone_lemoyne'), {
            { label = L('create_price'), type = 'number', min = 0, placeholder = L('create_price_ph'), required = true },
            { label = L('create_name'), type = 'text', placeholder = L('create_name_ph'), required = true, maxlength = H.nameMax },
        })
        if not v then return end
        local price = tonumber(v[1])
        local name = type(v[2]) == 'string' and U.trim(v[2]) or ''
        if not price or price < 0 or name == '' then return HX.tip(L('create_bad')) end
        local ok = HX.call('create', 6000, price, name)
        if not ok then HX.tip(L('no_answer')) end
    end)
end, false)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    relocating = nil
end)
