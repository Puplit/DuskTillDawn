-- pup_ranchero | menus (pup-ui ink menu) and input boxes

Menu = { cur = nil, session = nil }

-- session = { onEnd = fn } : what to undo when the whole menu stack closes
function Menu.isOpen() return Menu.cur ~= nil or Menu.session ~= nil end

local function firstSelectable(rows)
    for i, r in ipairs(rows) do if r.run then return i end end
    return 1
end

-- m = { title, subtitle, rows = { { label, desc, run = fn|nil } }, back = fn|nil, index, key }
function Menu.show(m)
    local opts = {}
    for i, r in ipairs(m.rows) do opts[i] = { label = r.label, description = r.desc } end
    if #opts == 0 then opts[1] = { label = '-' } end
    m.index = math.min(m.index or firstSelectable(m.rows), math.max(#opts, 1))
    Menu.cur = m
    exports['pup-ui']:OpenInkMenu({ owner = OWNER, title = m.title or '', subtitle = m.subtitle, startIndex = m.index, options = opts })
end

function Menu.closeAll()
    local s = Menu.session
    Menu.cur, Menu.session = nil, nil
    pcall(function() exports['pup-ui']:HideInkMenu() end)
    if s and s.onEnd then s.onEnd() end
end

function Menu.begin(onEnd)
    if Menu.session then Menu.closeAll() end
    Menu.session = { onEnd = onEnd }
end

AddEventHandler('pup-ui:client:inkMove', function(index, owner)
    if owner == OWNER and Menu.cur then Menu.cur.index = index end
end)

AddEventHandler('pup-ui:client:inkSelect', function(index, _, owner)
    if owner ~= OWNER or not Menu.cur then return end
    local m = Menu.cur
    local row = m.rows[index]
    if row and row.run then
        m.index = index
        CreateThread(function() row.run(row) end)
    end
end)

AddEventHandler('pup-ui:client:inkClose', function(owner)
    if owner ~= OWNER then return end
    local m = Menu.cur
    Menu.cur = nil
    if m and m.back then
        CreateThread(m.back)
    else
        Menu.closeAll()
    end
end)

Cleanups[#Cleanups + 1] = function()
    if Menu.isOpen() then Menu.closeAll() end
end

------------------------------------------------------------------------------
-- input boxes
------------------------------------------------------------------------------
local inputSeq, inputWait = 0, {}

-- blocking; returns the values array or nil when cancelled
function Ask(title, fields, submit)
    inputSeq = inputSeq + 1
    local owner = OWNER .. ':input:' .. inputSeq
    local p = promise.new()
    inputWait[owner] = p
    exports['pup-ui']:OpenInput({ owner = owner, title = title, submit = submit or L('submit'), fields = fields })
    local values = Citizen.Await(p)
    return values or nil
end

AddEventHandler('pup-ui:client:inputDone', function(owner, values)
    local p = owner and inputWait[owner]
    if p then
        inputWait[owner] = nil
        p:resolve(type(values) == 'table' and values or false)
    end
end)

function AskNumber(title, label)
    local v = Ask(title, { { label = label, type = 'number', required = true, min = 0 } })
    if not v then return nil end
    return tonumber(v[1])
end

function AskWhole(title, label)
    local n = AskNumber(title, label)
    if not n or n < 1 or n ~= math.floor(n) then
        if n ~= nil then TipBottom(L('invalidInput')) end
        return nil
    end
    return n
end

function Confirm(title, yesLabel, onYes, back)
    Menu.show({
        title = title, subtitle = L('sure'),
        rows = {
            { label = yesLabel or L('yes'), run = onYes },
            { label = L('no'), run = function() if back then back() else Menu.closeAll() end end },
        },
        back = back,
    })
end

------------------------------------------------------------------------------
-- buying a ranch
------------------------------------------------------------------------------
function OpenBuyMenu(r)
    Menu.begin(function() SetFrozen(false) end)
    SetFrozen(true)
    local function main()
        Menu.show({
            title = L('forSale'),
            rows = {
                { label = L('ranchName', r.name) },
                { label = L('ranchId', r.id) },
                { label = L('ranchPrice', U.money(r.price)) },
                { label = L('ranchTax', U.money(r.tax)) },
                { label = L('confirm'), run = function()
                    Confirm(L('forSale'), L('yes'), function()
                        Call('buyRanch', r.id)
                        Menu.closeAll()
                    end, main)
                end },
            },
        })
    end
    main()
end

------------------------------------------------------------------------------
-- the ranch menu
------------------------------------------------------------------------------
local function cdText(deadline)
    local l = LeftOf(deadline)
    if l == -1 then return L('busy') end
    return U.shortTime(l)
end

local function cdRunning(deadline)
    local l = LeftOf(deadline)
    return l == -1 or l > 0
end

-- herding / selling timer text, naming whoever is out on the drive or ran the last one
local function driveLine(kind)
    local deadline = kind == 'herd' and Deadlines.herd or Deadlines.sell
    local w = Ranch.me and Ranch.me[kind == 'herd' and 'herdBy' or 'sellBy']
    if type(w) == 'table' and w.by then
        if w.running then
            if w.live and w.endsAt then
                local secs = math.max(0, (w.endsAt - GetGameTimer()) / 1000)
                return L(kind == 'herd' and 'herdOutBy' or 'sellOutBy', w.by, U.shortTime(secs))
            end
            return L(kind == 'herd' and 'herdPrepBy' or 'sellPrepBy', w.by)
        end
        return L('lastBy', cdText(deadline), w.by)
    end
    return cdText(deadline)
end

local function waitingLine()
    local parts = {}
    if cdRunning(Deadlines.herd) then parts[#parts + 1] = L('herdShort') .. ': ' .. driveLine('herd') end
    if cdRunning(Deadlines.sell) then parts[#parts + 1] = L('sellShort') .. ': ' .. driveLine('sell') end
    if cdRunning(Deadlines.milk) then parts[#parts + 1] = L('milkShort') .. ' ' .. cdText(Deadlines.milk) end
    if cdRunning(Deadlines.eggs) then parts[#parts + 1] = L('eggShort') .. ' ' .. cdText(Deadlines.eggs) end
    if #parts == 0 then return L('allReady') end
    return L('waitingOn', table.concat(parts, ' - '))
end

local function cattleRows(cap, run)
    local me, rows = Ranch.me, {}
    for _, t in ipairs(U.sortedKeys(me.cattle)) do
        local n = me.cattle[t]
        if cap then n = math.min(n, Config.Livestock.maxPerType) end
        rows[#rows + 1] = {
            label = L('cattleRow', t, n, tonumber(me.cattleQuality and me.cattleQuality[t]) or 0),
            run = run and function() run(t) end or nil,
        }
    end
    return rows
end

local showMain

local function sub(title, rows, subtitle)
    Menu.show({ title = title, subtitle = subtitle, rows = rows, back = showMain })
end

local function herdCount()
    local total, kinds = 0, 0
    for _, n in pairs(Ranch.me.cattle or {}) do total = total + n; kinds = kinds + 1 end
    return total, kinds
end

local function buildMain()
    local me = Ranch.me
    local role = me.role
    local boss = role == 'owner' or role == 'manager'
    local rows = {}

    local roleLine = role == 'owner' and L('roleOwner') or (role == 'manager' and L('roleManager') or L('roleHand'))
    local idLine = '#' .. me.id
    if boss then idLine = idLine .. ' - ' .. L('ranchTax', U.money(me.ranchTax)) end
    rows[#rows + 1] = { label = me.ranchName, desc = idLine .. ' - ' .. roleLine }

    if (tonumber(Config.Environment.max) or 0) ~= 0 then
        local scale = U.envMax()
        local e = tonumber(me.ranchQuality) or 0
        local n = U.yieldFor(Config.Chores.maxScore, e)
        rows[#rows + 1] = {
            label = L('environment', e, scale, U.round(e / scale * 100)),
            desc = n > 0 and L('producePer', n) or L('produceTooLow'),
        }
    end

    local total, kinds = herdCount()
    local herdLabel = L('herdHeader', total) .. (kinds > 1 and L('herdBreeds', kinds) or '')
    local herdDesc = me.trail and L('trailSet') or L('noTrail')
    if me.dog and me.dog ~= '0' and me.dog ~= '' then herdDesc = herdDesc .. ' - ' .. L('dogOnBooks') end
    rows[#rows + 1] = { label = herdLabel, desc = herdDesc }

    if boss and (me.uncollectedMilk or 0) > 0 then
        rows[#rows + 1] = { label = L('uncollectedMilk', me.uncollectedMilk), desc = L('uncollectedHint') }
    end

    if Drive and Drive.active then
        rows[#rows + 1] = { label = L('herdCooldown', cdText(Deadlines.herd)), desc = L('driveRunning') }
        rows[#rows + 1] = { label = L('sellCooldown', cdText(Deadlines.sell)), desc = L('driveRunning') }
        return rows
    end

    -- herd
    if not me.trail then
        rows[#rows + 1] = { label = L('noTrailRow') }
    elseif cdRunning(Deadlines.herd) then
        rows[#rows + 1] = { label = L('herdBusyRow', driveLine('herd')) }
    else
        rows[#rows + 1] = { label = L('herdCattle'), run = function()
            local list = cattleRows(false, function(t) StartDriveRequest('herd', t) end)
            if #list == 0 then list = { { label = L('noCattle') } } end
            sub(L('selectCattle'), list)
        end }
    end
    -- sell
    if cdRunning(Deadlines.sell) then
        rows[#rows + 1] = { label = L('sellBusyRow', driveLine('sell')) }
    else
        rows[#rows + 1] = { label = L('sellCattle'), run = function()
            local list = cattleRows(true, function(t) StartDriveRequest('sell', t) end)
            if #list == 0 then list = { { label = L('noCattle') } } end
            sub(L('selectCattle'), list)
        end }
    end
    rows[#rows + 1] = { label = L('viewCattle'), run = function()
        local list = cattleRows(false, nil)
        if #list == 0 then list = { { label = L('noCattle') } } end
        sub(L('viewCattle'), list)
    end }
    rows[#rows + 1] = { label = L('choresMenu'), run = function() OpenChoresMenu() end }
    rows[#rows + 1] = { label = L('buyCattle'), desc = L('fundsHint'), run = function() OpenBuyCattle() end }
    if boss then
        rows[#rows + 1] = { label = L('produceStore'), desc = L('produceDesc', me.milk or 0, me.eggs or 0), run = function()
            Menu.closeAll()
            Call('openStore')
        end }
    end
    if me.cows then rows[#rows + 1] = { label = L('cowPen'), run = function() OpenEnclosureMenu('milk') end } end
    if me.chickens then rows[#rows + 1] = { label = L('chickenCoop'), run = function() OpenEnclosureMenu('eggs') end } end
    if boss then rows[#rows + 1] = { label = L('bossActions'), run = function() OpenBossMenu() end } end
    if role ~= 'owner' then
        rows[#rows + 1] = { label = L('quit'), run = function()
            Confirm(L('quit'), L('quitYes'), function()
                Menu.closeAll()
                Call('quit')
            end, showMain)
        end }
    end
    return rows
end

local mainSig = nil

local function signature(rows, subtitle)
    local parts = { subtitle }
    for _, r in ipairs(rows) do parts[#parts + 1] = (r.label or '') .. '|' .. (r.desc or '') .. '|' .. (r.run and '1' or '0') end
    return table.concat(parts, '\n')
end

showMain = function(keepIndex)
    if not HasRanch() then Menu.closeAll() return end
    local rows = buildMain()
    local subtitle = waitingLine()
    local index = keepIndex and Menu.cur and Menu.cur.isMain and Menu.cur.index or nil
    mainSig = signature(rows, subtitle)
    Menu.show({ title = L('menuTitle'), subtitle = subtitle, rows = rows, isMain = true, index = index })
end

function ShowRanchMain() showMain() end

-- redraw once a second, only when something shown changed
CreateThread(function()
    while true do
        Wait(1000)
        if Menu.cur and Menu.cur.isMain and HasRanch() then
            local rows = buildMain()
            local subtitle = waitingLine()
            if signature(rows, subtitle) ~= mainSig then showMain(true) end
        end
    end
end)

InfoListeners[#InfoListeners + 1] = function(info)
    if (info.id or 0) == 0 and Menu.session and Menu.session.ranch then Menu.closeAll() end
end

function OpenRanchMenu()
    if Menu.isOpen() or not HasRanch() then return end
    local ok = Call('openMenu')
    if not ok then return end
    Menu.begin(function()
        SetFrozen(false)
        Send('closeMenu')
    end)
    Menu.session.ranch = true
    SetFrozen(true)
    showMain()
end

------------------------------------------------------------------------------
-- buying cattle
------------------------------------------------------------------------------
function OpenBuyCattle()
    local me, rows = Ranch.me, {}
    for _, t in ipairs(U.sortedKeys(Config.Animals)) do
        local a = Config.Animals[t]
        local have = (me.cattle and me.cattle[t]) or 0
        local jobOk = a.job == 'none' or a.job == me.job
        if a.price and a.model and a.job and jobOk and have < Config.Livestock.maxPerType then
            rows[#rows + 1] = {
                label = L('buyRow', t) .. (have > 0 and L('ownedPart', have) or '') .. L('pricePart', U.money(a.price)),
                run = function()
                    local n = AskWhole(L('buyRow', t), L('amount'))
                    if not n then return end
                    if have + n > Config.Livestock.maxPerType then TipBottom(L('tooManyAnimals')) return end
                    Call('buyCattle', t, n)
                end,
            }
        end
    end
    if #rows == 0 then rows[1] = { label = L('nothingToBuy') } end -- say why, not "on cooldown"
    sub(L('buyCattle'), rows, L('fundsHint'))
end

------------------------------------------------------------------------------
-- chores
------------------------------------------------------------------------------
function OpenChoresMenu()
    local me, rows = Ranch.me, {}
    for _, name in ipairs(Config.Chores.order) do
        if me.chores and me.chores[name] then
            if cdRunning(Deadlines.chores[name]) then
                rows[#rows + 1] = { label = L('choreCooldown', U.choreLabel(name)), desc = cdText(Deadlines.chores[name]) }
            else
                rows[#rows + 1] = { label = U.choreLabel(name), run = function()
                    Menu.closeAll()
                    StartChoreActivity(name)
                end }
            end
        end
    end
    if #rows == 0 then rows[1] = { label = L('noChores') } end
    sub(L('choresMenu'), rows)
end

------------------------------------------------------------------------------
-- cow pen / chicken coop
------------------------------------------------------------------------------
function OpenEnclosureMenu(kind)
    local me = Ranch.me
    local boss = IsBoss()
    local rows = {}
    local isMilk = kind == 'milk'
    if isMilk and boss and (me.uncollectedMilk or 0) > 0 then
        rows[#rows + 1] = { label = L('takeMilk', me.uncollectedMilk), run = function()
            local n = AskWhole(L('takeMilk', me.uncollectedMilk), L('amount'))
            if not n then return end
            if n > (Ranch.me.uncollectedMilk or 0) then TipBottom(L('invalidInput')) return end
            Call('takeMilk', n)
            OpenEnclosureMenu(kind)
        end }
    end
    local deadline = isMilk and Deadlines.milk or Deadlines.eggs
    if cdRunning(deadline) then
        rows[#rows + 1] = { label = (isMilk and L('milkCooldownRow', cdText(deadline)) or L('eggCooldownRow', cdText(deadline))) }
    else
        rows[#rows + 1] = { label = isMilk and L('milkCows') or L('checkChickens'), run = function()
            Menu.closeAll()
            StartProduceActivity(kind)
        end }
    end
    if PenAnimalsOut(kind) then
        rows[#rows + 1] = { label = isMilk and L('returnCow') or L('returnChickens'), run = function()
            RemovePenAnimals(kind)
            OpenEnclosureMenu(kind)
        end }
    end
    if boss then
        rows[#rows + 1] = { label = L('changeLocation'), run = function()
            Menu.closeAll()
            StartSpotRegistration(isMilk and L('cowPen') or L('chickenCoop'), nil, function(pos)
                Call('moveEnclosure', isMilk and 'cows' or 'chickens', pos)
            end)
        end }
    end
    sub(isMilk and L('cowPen') or L('chickenCoop'), rows)
end

------------------------------------------------------------------------------
-- boss actions
------------------------------------------------------------------------------
local function staffMenu(title, run, back)
    local list = Call('staffList')
    if type(list) ~= 'table' then return end
    local rows = {}
    for _, h in ipairs(list) do
        rows[#rows + 1] = {
            label = h.manager and L('managerRow', h.name) or L('handRow', h.name),
            run = function() run(h) end,
        }
    end
    if #rows == 0 then rows[1] = { label = L('hiredStaffNone') } end
    Menu.show({ title = title, rows = rows, back = back })
end

local function ledgerMenu()
    local me = Ranch.me
    Menu.show({
        title = L('ledger'),
        rows = {
            { label = L('ledgerBalance', U.money(me.ledger or 0)) },
            { label = L('withdraw'), run = function()
                local n = AskNumber(L('withdraw'), L('amount'))
                if not n or n <= 0 then if n then TipBottom(L('invalidInput')) end return end
                Call('withdraw', n)
                ledgerMenu()
            end },
            { label = L('deposit'), run = function()
                local n = AskNumber(L('deposit'), L('amount'))
                if not n or n <= 0 then if n then TipBottom(L('invalidInput')) end return end
                Call('deposit', n)
                ledgerMenu()
            end },
        },
        back = OpenBossMenu,
    })
end

local function upgradesMenu()
    local me = Ranch.me
    local rows = {}
    if not me.cows then
        rows[#rows + 1] = { label = L('cowPenBuy', U.money(Config.Upgrades.cowPen)), run = function()
            Menu.closeAll()
            StartSpotRegistration(L('cowPen'), L('spotCost', U.money(Config.Upgrades.cowPen)), function(pos) Call('buyPen', pos) end)
        end }
    end
    if not me.chickens then
        rows[#rows + 1] = { label = L('coopBuy', U.money(Config.Upgrades.chickenCoop)), run = function()
            Menu.closeAll()
            StartSpotRegistration(L('chickenCoop'), L('spotCost', U.money(Config.Upgrades.chickenCoop)), function(pos) Call('buyCoop', pos) end)
        end }
    end
    rows[#rows + 1] = { label = L('herdingDog'), run = function()
        local breeds = {}
        for _, b in ipairs(Config.Dog.breeds) do breeds[#breeds + 1] = b end
        table.sort(breeds, function(a, b) return a.label:lower() < b.label:lower() end)
        local list = {}
        for _, b in ipairs(breeds) do
            list[#list + 1] = { label = L('dogRow', b.label, U.money(b.price)), run = function()
                Call('buyDog', b.model)
                upgradesMenu()
            end }
        end
        Menu.show({ title = L('herdingDog'), subtitle = L('upgradesHint'), rows = list, back = upgradesMenu })
    end }
    Menu.show({ title = L('upgrades'), subtitle = L('upgradesHint'), rows = rows, back = OpenBossMenu })
end

------------------------------------------------------------------------------
-- managers: who is working right now
------------------------------------------------------------------------------
local ACTIVE = { herding = true, selling = true, chore = true, milking = true, eggs = true }

local function agoText(sec)
    sec = math.max(0, tonumber(sec) or 0)
    if sec < 3600 then return U.shortTime(sec) end
    if sec < 86400 then return math.floor(sec / 3600) .. 'h' end
    return math.floor(sec / 86400) .. 'd'
end

local function whoView(res)
    local rows, busy = {}, 0
    for _, m in ipairs(res.list or {}) do
        if ACTIVE[m.status] then busy = busy + 1 end
        local roleTxt = m.role == 'owner' and L('tagOwner') or (m.role == 'manager' and L('tagManager') or L('tagHand'))
        local seen = (tonumber(m.last) or 0) > 0 and L('lastWorked', agoText((res.now or 0) - m.last)) or L('neverWorked')
        rows[#rows + 1] = {
            label = L('whoRow', m.name, L('st_' .. tostring(m.status), m.detail or '')),
            desc = roleTxt .. ' - ' .. seen,
        }
    end
    if #rows == 0 then rows[1] = { label = L('hiredStaffNone') } end
    return rows, L('whoSubtitle', busy, #(res.list or {}))
end

local whoSig = nil

function OpenWhoMenu(keepIndex)
    local res = Call('boardWho')
    if type(res) ~= 'table' or not Menu.isOpen() then return end
    local rows, subtitle = whoView(res)
    local index = keepIndex and Menu.cur and Menu.cur.isWho and Menu.cur.index or nil
    whoSig = signature(rows, subtitle)
    Menu.show({ title = L('workingNow'), subtitle = subtitle, rows = rows, back = OpenBossMenu, isWho = true, index = index })
end

-- an open list keeps itself current
CreateThread(function()
    while true do
        Wait(tonumber(Config.Board.refreshMs) or 4000)
        if Menu.cur and Menu.cur.isWho then
            local res = Call('boardWho')
            if type(res) == 'table' and Menu.cur and Menu.cur.isWho then
                local rows, subtitle = whoView(res)
                if signature(rows, subtitle) ~= whoSig then
                    whoSig = signature(rows, subtitle)
                    Menu.show({ title = L('workingNow'), subtitle = subtitle, rows = rows, back = OpenBossMenu, isWho = true, index = Menu.cur.index })
                end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- managers: the ranch leaderboard
------------------------------------------------------------------------------
local SORTS = { 'chores', 'milk', 'eggs', 'herds' }

function OpenLeaderboard(sortKey)
    sortKey = sortKey or 'chores'
    local res = Call('boardStats')
    if type(res) ~= 'table' or not Menu.isOpen() then return end
    local list = res.rows or {}
    table.sort(list, function(a, b)
        if a[sortKey] ~= b[sortKey] then return a[sortKey] > b[sortKey] end
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)

    local top, tc, tm, te = nil, 0, 0, 0
    for _, p in ipairs(list) do
        tc, tm, te = tc + p.chores, tm + p.milk, te + p.eggs
        if p.chores > 0 and (not top or p.chores > top.chores) then top = p end
    end

    local nextKey = SORTS[1]
    for i, k in ipairs(SORTS) do if k == sortKey then nextKey = SORTS[i % #SORTS + 1] end end

    local rows = {
        { label = L('boardSort', L('sort_' .. sortKey)), desc = L('boardSortHint'), run = function() OpenLeaderboard(nextKey) end },
    }
    for i, p in ipairs(list) do
        local name = p.member and p.name or L('formerMember', p.name)
        rows[#rows + 1] = {
            label = L('boardRow', i, name, p[sortKey], L('unit_' .. sortKey)),
            desc = L('boardDesc', p.chores, p.milk, p.eggs, p.herds),
        }
    end
    if #list == 0 then
        rows[#rows + 1] = { label = L('boardEmpty') }
    else
        rows[#rows + 1] = { label = L('boardTotal', tc, tm, te) }
    end
    local subtitle = top and L('boardTop', top.name, top.chores) or L('boardNoTop')
    Menu.show({ title = L('leaderboard'), subtitle = subtitle, rows = rows, back = OpenBossMenu, index = 1 })
end

function OpenBossMenu()
    local role = Role()
    local rows = {
        { label = L('workingNow'), desc = L('workingNowHint'), run = function() OpenWhoMenu() end },
        { label = L('leaderboard'), desc = L('leaderboardHint'), run = function() OpenLeaderboard('chores') end },
        { label = L('hire'), run = function()
            local id = AskWhole(L('hire'), L('playerId'))
            if id then Call('hire', id) end
        end },
        { label = L('fire'), run = function()
            staffMenu(L('fire'), function(h)
                Call('fire', h.charid) -- at once, no confirmation
                OpenBossMenu()
            end, OpenBossMenu)
        end },
        { label = L('ledger'), run = ledgerMenu },
        { label = L('setChores'), run = function()
            local list = {}
            for _, name in ipairs(Config.Chores.order) do
                list[#list + 1] = { label = L('choreSpotRow', U.choreLabel(name)), run = function()
                    Menu.closeAll()
                    StartSpotRegistration(U.choreLabel(name), nil, function(pos) Call('setChoreSpot', name, pos) end)
                end }
            end
            Menu.show({ title = L('setChores'), rows = list, back = OpenBossMenu })
        end },
        { label = L('setTrail'), desc = L('setTrailHint'), run = function()
            Menu.closeAll()
            StartTrailRecording()
        end },
        { label = L('upgrades'), desc = L('upgradesHint'), run = upgradesMenu },
    }
    if role == 'owner' then
        rows[#rows + 1] = { label = L('updateManagers'), run = function()
            local function again()
                staffMenu(L('updateManagers'), function(h)
                    Call('setManager', h.charid, not h.manager)
                    again()
                end, OpenBossMenu)
            end
            again()
        end }
        rows[#rows + 1] = { label = L('setWebhook'), run = function()
            local v = Ask(L('setWebhook'), { { label = L('enterWebhook'), type = 'text', required = true, maxlength = 256 } })
            if v and v[1] then Call('setWebhook', tostring(v[1])) end
        end }
        if Config.General.allowTransfer then
            rows[#rows + 1] = { label = L('transfer'), run = function()
                local id = AskWhole(L('transfer'), L('playerId'))
                if not id then return end
                Confirm(L('transfer'), L('yes'), function()
                    Menu.closeAll()
                    Call('transfer', id)
                end, OpenBossMenu)
            end }
        end
    end
    sub(L('bossActions'), rows)
end
