-- pup_business | the job menu, the fallback list menus, tax, bills and duty lists

local opening = false

-- closest other player within `reach` metres: serverId, distance
function ClosestPlayer(reach)
    local me = PlayerId()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= me then
            local ped = GetPlayerPed(pid)
            if ped ~= 0 and DoesEntityExist(ped) then
                local d = #(pos - GetEntityCoords(ped))
                if d <= reach and (not bestD or d < bestD) then best, bestD = GetPlayerServerId(pid), d end
            end
        end
    end
    return best, bestD
end

local function someoneClose()
    if not Config.LegacyTooClose then return false end
    return ClosestPlayer(Config.LegacyTooCloseDistance) ~= nil
end

local function askNumber(title, label, default, onDone, after)
    UI.Input({
        title = title,
        fields = { { label = label, type = 'number', default = default, required = true } },
        onDone = function(values)
            local n = tonumber(values and values[1])
            if not n then return Tip(L('invalid_amount')) end
            onDone(n)
        end,
        after = after,
    })
end

---------------------------------------------------------------------------
-- tax
---------------------------------------------------------------------------

local function taxLine(t)
    if not t then return nil end
    if t.owed > 0 then
        return L('tax_desc_overdue', t.owed, t.period, PB.money(t.due))
    end
    return L('tax_desc_paid', PB.money(t.rate), t.nextDue)
end

function OpenTaxMenu(back)
    CreateThread(function()
        local t = Call('taxStatus')
        if not t then
            Tip(L('tax_none'))
            if back then back() end
            return
        end
        local b = MyBusiness()
        local opts = {}
        if t.owed > 0 then
            opts[1] = {
                label = L('tax_pay', PB.money(t.due)),
                desc = L('tax_pay_desc', t.owed, t.period, PB.money(t.rate)),
                onSelect = function()
                    CreateThread(function()
                        Call('payTax')
                        if back then back() end
                    end)
                end,
            }
        else
            opts[1] = { label = L('tax_nothing'), desc = L('tax_paid_up', t.nextDue), disabled = true }
        end
        opts[2] = { label = L('tax_rate', PB.money(t.rate), t.period), disabled = true }
        UI.List({ title = L('tax_title'), subtitle = b and b.name or nil, hold = true, options = opts, onBack = back })
    end)
end

---------------------------------------------------------------------------
-- fallback list menus (used only when the dashboard data did not arrive)
---------------------------------------------------------------------------

local OpenManageEmployees, OpenLedgerMenu

local function memberSubmenu(title, fmt, onPick, back)
    CreateThread(function()
        local list = Call('members') or {}
        local opts = {}
        for _, m in ipairs(list) do
            opts[#opts + 1] = {
                label = fmt(m),
                onSelect = function() onPick(m) end,
            }
        end
        if #opts == 0 then opts[1] = { label = L('none_available'), disabled = true } end
        UI.List({ title = title, hold = true, options = opts, onBack = back })
    end)
end

local function gradeSubmenu(title, onPick, back)
    local b = MyBusiness()
    local opts = {}
    for g = 0, (b and b.bossrank or 0) do
        opts[#opts + 1] = { label = L('rank_n', g), onSelect = function() onPick(g) end }
    end
    UI.List({ title = title, hold = true, options = opts, onBack = back })
end

OpenManageEmployees = function()
    local b = MyBusiness()
    if not b then return end
    local back = OpenManageEmployees
    local opts = {
        { label = L('menu_hire'), onSelect = function()
            askNumber(L('menu_hire'), L('server_id'), nil, function(id)
                Send('hire', math.floor(id))
            end, back)
        end },
        { label = L('menu_fire'), onSelect = function()
            memberSubmenu(L('menu_fire'), function(m) return L('member_line', m.id, m.name) end, function(m)
                CreateThread(function() Call('fire', m.charid); back() end)
            end, back)
        end },
        { label = L('menu_set_rank'), onSelect = function()
            memberSubmenu(L('menu_set_rank'), function(m) return L('member_rank_line', m.id, m.name, m.grade) end, function(m)
                askNumber(L('menu_set_rank'), L('rank'), m.grade, function(g)
                    Send('setRank', m.charid, math.floor(g))
                end, back)
            end, back)
        end },
    }
    if b.salary then
        opts[#opts + 1] = { label = L('menu_set_salary'), onSelect = function()
            gradeSubmenu(L('menu_set_salary'), function(g)
                askNumber(L('menu_set_salary'), L('salary'), nil, function(s)
                    Send('setSalary', g, math.floor(s))
                end, back)
            end, back)
        end }
    end
    if IsBossHere() then
        opts[#opts + 1] = { label = L('menu_set_access'), onSelect = function()
            gradeSubmenu(L('menu_set_access'), function(g)
                CreateThread(function()
                    Call('setAccess', g)
                    TipBottom(L('access_tip', g))
                    back()
                end)
            end, back)
        end }
    end
    UI.List({ title = L('menu_manage'), subtitle = b.name, hold = true, options = opts, onBack = OpenJobMenu })
end

OpenLedgerMenu = function(balance)
    local b = MyBusiness()
    if not b then return end
    if balance == nil then
        -- the first line shows the balance; ask for it (gives up after the RPC timeout)
        CreateThread(function()
            local d = Call('dash')
            OpenLedgerMenu(type(d) == 'table' and d.ledger or false)
        end)
        return
    end
    local back = function() OpenLedgerMenu() end
    local function money(kind)
        if someoneClose() then return Tip(L('too_close')) end
        askNumber(kind == 'deposit' and L('menu_deposit') or L('menu_withdraw'), L('amount'), nil, function(n)
            Send(kind, math.floor(n))
        end, back)
    end
    UI.List({
        title = L('menu_ledger'), subtitle = b.name, hold = true, onBack = OpenJobMenu,
        options = {
            { label = L('ledger_cash', balance ~= false and tostring(balance) or '?'), disabled = true },
            { label = L('menu_deposit'), onSelect = function() money('deposit') end },
            { label = L('menu_withdraw'), onSelect = function() money('withdraw') end },
            { label = L('menu_set_webhook'), onSelect = function()
                UI.Input({
                    title = L('menu_set_webhook'),
                    fields = { { label = L('webhook_link'), type = 'text', maxlength = 200 } },
                    onDone = function(v)
                        local url = v and v[1]
                        if type(url) == 'string' and url ~= '' then Send('setWebhook', url) end
                    end,
                    after = back,
                })
            end },
            { label = L('menu_clear_webhook'), onSelect = function()
                CreateThread(function() Call('setWebhook', ''); back() end)
            end },
            { label = L('menu_set_slots'), desc = L('slots_price_desc', Config.SlotPrice), onSelect = function()
                askNumber(L('menu_set_slots'), L('slots_amount', Config.SlotPrice), nil, function(n)
                    Send('buySlots', math.floor(n))
                end, back)
            end },
        },
    })
end

---------------------------------------------------------------------------
-- the job menu
---------------------------------------------------------------------------

function OpenJobMenu()
    if opening then return end
    opening = true
    CreateThread(function()
        UI.Hold()
        RefreshJob()
        local b = MyBusiness()
        if not b then opening = false; UI.Settle() return end
        local d = Call('jobMenu')
        opening = false

        local opts = {}
        local grade = Me.grade or 0
        local perms = d and d.perms or {}
        local canStash = (d and (d.isBoss or perms.stash)) or grade >= (d and d.invaccess or b.invaccess or 0)
        if canStash then
            opts[#opts + 1] = { label = L('menu_inventory'), onSelect = function() Send('openStash') end }
        end
        if d and d.tax then
            opts[#opts + 1] = { label = L('menu_tax'), desc = taxLine(d.tax), onSelect = function() OpenTaxMenu(OpenJobMenu) end }
        end
        if d then
            if d.canManage then
                opts[#opts + 1] = { label = L('menu_management'), desc = L('menu_management_desc'), onSelect = function()
                    OpenDashboard(d)
                end }
            end
        else
            local boss = grade >= b.bossrank
            if boss or grade >= (b.recruitmentrank or 0) then
                opts[#opts + 1] = { label = L('menu_manage'), onSelect = OpenManageEmployees }
            end
            if boss then
                opts[#opts + 1] = { label = L('menu_ledger'), onSelect = function() OpenLedgerMenu(nil) end }
            end
        end
        if #opts == 0 then opts[1] = { label = L('none_available'), disabled = true } end
        UI.List({ title = L('menu_job'), subtitle = b.name, hold = true, options = opts })
    end)
end

---------------------------------------------------------------------------
-- bills
---------------------------------------------------------------------------

RegisterCommand('bill', function(_, args)
    local b = MyBusiness()
    if not b or not b.billing then return Tip(L('cant_bill')) end
    local amount = tonumber(args[1])
    if not amount or amount <= 0 then return Tip(L('invalid_amount')) end
    local target = tonumber(args[2])
    if not target then
        target = ClosestPlayer(Config.BillReachClient)
        if not target then return Tip(L('no_person_nearby')) end
    end
    Send('bill', math.floor(target), amount)
end, false)

local function openPayBills()
    CreateThread(function()
        local list = Call('myBills') or {}
        local opts = {}
        for _, bill in ipairs(list) do
            opts[#opts + 1] = {
                label = L('bill_line', bill.job, PB.money(bill.amount)),
                onSelect = function()
                    CreateThread(function()
                        Call('payBill', bill.id)
                        openPayBills()
                    end)
                end,
            }
        end
        if #opts == 0 then opts[1] = { label = L('none_available'), disabled = true } end
        UI.List({ title = L('your_bills'), options = opts })
    end)
end

RegisterCommand('paybills', openPayBills, false)

---------------------------------------------------------------------------
-- /viewduty answer from the server
---------------------------------------------------------------------------

RegisterNetEvent('pup_business:showDuty', function(job, rows)
    local opts = {}
    for _, r in ipairs(type(rows) == 'table' and rows or {}) do
        opts[#opts + 1] = { label = tostring(r.name or ('ID ' .. tostring(r.id))), desc = L('server_id_line', r.id), disabled = true }
    end
    if #opts == 0 then opts[1] = { label = L('none_available'), disabled = true } end
    UI.List({ title = L('duty_list_title', tostring(job)), options = opts })
end)
