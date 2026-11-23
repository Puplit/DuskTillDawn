-- pup_business | the money ledger, cash movements, salaries and AddToLedger

---------------------------------------------------------------------------
-- ledger rows (whole dollars). Every write names one row (LIMIT 1) so a job
-- with duplicate rows can never be credited twice.
---------------------------------------------------------------------------

-- a query error becomes "did not happen" so it never unwinds past a cash refund or a held lock
local function safe(fn, query, params)
    local ok, res = pcall(fn, query, params)
    if not ok then
        print(('^1[%s]^7 ledger query failed: %s'):format(RES, tostring(res)))
        return nil, true
    end
    return res, false
end

function LedgerGet(job)
    local v = safe(MySQL.scalar.await, 'SELECT ledger FROM society_ledger WHERE job = ? LIMIT 1', { job })
    if v == nil then return nil end
    return tonumber(v) or 0
end

-- creates the row when it is missing; true when a row exists afterwards
function LedgerEnsure(job)
    if LedgerGet(job) ~= nil then return true end
    safe(MySQL.insert.await,
        "INSERT INTO society_ledger (job, ledger, webhook, invaccess) SELECT ?, 0, '', 0 FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM society_ledger WHERE job = ?)",
        { job, job })
    return LedgerGet(job) ~= nil
end

function LedgerAdd(job, amount)
    local n = safe(MySQL.update.await, 'UPDATE society_ledger SET ledger = ledger + ? WHERE job = ? LIMIT 1', { amount, job })
    return (tonumber(n) or 0) > 0
end

-- succeeds only while the balance still covers it
function LedgerTake(job, amount)
    local n = safe(MySQL.update.await, 'UPDATE society_ledger SET ledger = ledger - ? WHERE job = ? AND ledger >= ? LIMIT 1', { amount, job, amount })
    return (tonumber(n) or 0) > 0
end

---------------------------------------------------------------------------
-- cash <-> ledger. Cash is never taken unless the ledger row exists, and is
-- handed back if the credit does not land.
---------------------------------------------------------------------------

-- returns ok, reason ('noledger' | 'gone' | 'cash' | 'credit'), cashBefore
function CashToLedger(src, charid, job, amount, allowDebt)
    if not LedgerEnsure(job) then return false, 'noledger' end
    local ch = GetCharIf(src, charid)
    if not ch then return false, 'gone' end
    local cash = tonumber(ch.money) or 0
    if not allowDebt and cash < amount then return false, 'cash', cash end
    ch.removeCurrency(0, amount)
    if not LedgerAdd(job, amount) then
        local back = GetCharIf(src, charid)
        if back then
            back.addCurrency(0, amount)
        else
            print(('^1[%s]^7 ledger credit failed and char %s left before the refund of %s'):format(RES, tostring(charid), PB.money(amount)))
        end
        return false, 'credit', cash
    end
    return true, nil, cash
end

-- ledger -> player cash; the ledger is refunded when the player is gone
function LedgerToCash(src, charid, job, amount)
    if not LedgerTake(job, amount) then return false, 'ledger' end
    local ch = GetCharIf(src, charid)
    if not ch then
        LedgerAdd(job, amount)
        return false, 'gone'
    end
    ch.addCurrency(0, amount)
    return true
end

local function ledgerFailText(reason)
    if reason == 'cash' then return L('not_enough_money') end
    if reason == 'noledger' then return L('ledger_missing') end
    if reason == 'credit' then return L('ledger_credit_failed') end
    return L('action_failed')
end
LedgerFailText = ledgerFailText

local function memberBiz(ch)
    local b = Biz[ch.job]
    return b, ch.job, CharGrade(ch)
end

---------------------------------------------------------------------------
-- deposit / withdraw
---------------------------------------------------------------------------

Handle('deposit', 1000, function(src, ch, amount, wantJob)
    amount = PB.int(amount)
    if not amount or amount < 1 then Notify(src, L('invalid_amount')) return false end
    local b, job = memberBiz(ch)
    -- members deposit into their own business; the VORP admin group may name any business
    if type(wantJob) == 'string' and wantJob ~= job and Biz[wantJob] and IsGroupAdmin(src) then
        b, job = Biz[wantJob], wantJob
    end
    if not b then Notify(src, L('not_in_business')) return false end
    local charid = CharId(ch)
    if (tonumber(ch.money) or 0) < amount then Notify(src, L('not_enough_money')) return false end

    local lockKey = 'cash:' .. charid
    if not Lock(lockKey) then return false end
    local before = LedgerGet(job)
    local ok, reason = CashToLedger(src, charid, job, amount, false)
    Unlock(lockKey)
    if not ok then Notify(src, ledgerFailText(reason)) return false end

    Notify(src, L('deposited', amount))
    Activity(job, 'DEPOSIT', ('Deposited %s into the ledger'):format(PB.money(amount)), FullName(ch))
    CreateThread(function()
        local after = LedgerGet(job) or 0
        SendLog(job, 'Deposit', COLOUR.green, table.pack(
            F('Who', WhoText(src)), F('Amount', PB.money(amount), true),
            F('Ledger', LedgerText(before or (after - amount), amount, after)), F('Business', job, true)))
    end)
    return true
end)

Handle('withdraw', 1000, function(src, ch, amount)
    amount = PB.int(amount)
    if not amount or amount < 1 then Notify(src, L('invalid_amount')) return false end
    local b, job, grade = memberBiz(ch)
    if not b then Notify(src, L('not_in_business')) return false end
    if not (IsBossGrade(job, grade) or IsSocietyAdmin(src) or HasRankPerm(job, grade, 'managepay')) then
        Notify(src, L('no_permission')) return false
    end
    local charid = CharId(ch)
    local lockKey = 'cash:' .. charid
    if not Lock(lockKey) then return false end
    local before = LedgerGet(job)
    if not before or before < amount then
        Unlock(lockKey)
        Notify(src, L('ledger_short')) return false
    end
    local ok, reason = LedgerToCash(src, charid, job, amount)
    Unlock(lockKey)
    if not ok then
        Notify(src, reason == 'ledger' and L('ledger_short') or L('action_failed'))
        return false
    end

    Notify(src, L('withdrew', amount))
    Activity(job, 'WITHDRAW', ('Withdrew %s from the ledger'):format(PB.money(amount)), FullName(ch))
    CreateThread(function()
        local after = LedgerGet(job) or 0
        local share = before > 0 and math.floor(amount / before * 100 + 0.5) or 100
        local shareText = share >= 100 and '100% (emptied it)' or (share .. '%')
        SendLog(job, 'Withdrawal', COLOUR.orange, table.pack(
            F('Who', WhoText(src)), F('Amount', PB.money(amount), true),
            F('Ledger', LedgerText(before, -amount, after)), F('Share of balance', shareText, true),
            F('Business', job, true)))
    end)
    return true
end)

---------------------------------------------------------------------------
-- salary of a grade (fallback menu; the dashboard saves ranks in dashboard.lua)
---------------------------------------------------------------------------

-- writes the per-rank table and keeps the legacy table in step
function WriteSalary(job, grade, salary)
    MySQL.update.await('UPDATE society_ranks SET salary = ? WHERE job = ? AND grade = ?', { salary, job, grade })
    local n = MySQL.update.await('UPDATE society SET salary = ? WHERE job = ? AND jobgrade = ?', { salary, job, grade })
    if (tonumber(n) or 0) == 0 then
        MySQL.insert.await('INSERT INTO society (job, jobgrade, salary) VALUES (?, ?, ?)', { job, grade, salary })
    end
    if Ranks[job] and Ranks[job][grade] then Ranks[job][grade].salary = salary end
end

Handle('setSalary', 750, function(src, ch, grade, salary)
    grade, salary = PB.int(grade), PB.int(salary)
    local b, job, myGrade = memberBiz(ch)
    if not b or not grade or not salary then Notify(src, L('invalid_amount')) return false end
    local admin = IsSocietyAdmin(src)
    local boss = IsBossGrade(job, myGrade)
    if not (admin or boss or HasRankPerm(job, myGrade, 'managepay')) then Notify(src, L('no_permission')) return false end
    if grade < 0 or grade > b.bossrank then Notify(src, L('invalid_grade')) return false end
    if not admin and not boss and grade >= myGrade then Notify(src, L('pay_below_only')) return false end
    if salary < 0 or salary > Config.MaxSalary then Notify(src, L('max_salary', Config.MaxSalary)) return false end

    local old = (RankOf(job, grade) or {}).salary or 0
    WriteSalary(job, grade, salary)
    Notify(src, L('salary_updated', grade, salary))
    Activity(job, 'SALARY', ('Grade %d salary set to %s'):format(grade, PB.money(salary)), FullName(ch))
    CreateThread(function()
        local bal = LedgerGet(job) or 0
        SendLog(job, 'Salary changed', COLOUR.yellow, table.pack(
            F('Who', WhoText(src)), F('Grade', grade, true),
            F('Per tick', ('%s -> %s'):format(PB.money(old), PB.money(salary)), true),
            F('Ledger', PB.money(bal), true), F('Business', job, true)))
    end)
    return true
end)

---------------------------------------------------------------------------
-- payday (the client asks every interval; the server decides)
---------------------------------------------------------------------------

local lastPay = {} -- [charid] = os.time(); survives reconnects, not restarts

Handle('payday', 5000, function(src, ch)
    local charid = CharId(ch)
    local now = Now()
    local gap = Config.PaydayMinutes * 60 - Config.PaydayGraceSeconds
    if lastPay[charid] and now - lastPay[charid] < gap then return false end

    local job, grade = ch.job, CharGrade(ch)
    local b = Biz[job]
    if not b or not b.salary then return false end
    if Config.DutyJobsPaidOnDutyOnly and Config.DutyJobs[job] and not IsOnDutyMerged(src) then return false end

    lastPay[charid] = now
    local salary = PB.int(MySQL.scalar.await('SELECT salary FROM society WHERE job = ? AND jobgrade = ? LIMIT 1', { job, grade })) or 0
    if salary <= 0 then return false end

    -- still the same job and grade after the read?
    local again = GetCharIf(src, charid)
    if not again or again.job ~= job or CharGrade(again) ~= grade then return false end

    local ok = LedgerToCash(src, charid, job, salary)
    if not ok then
        Notify(src, L('salary_ledger_short'))
        return false
    end
    Notify(src, L('salary_paid', salary))
    return true
end)

---------------------------------------------------------------------------
-- business webhook (boss or the VORP admin group)
---------------------------------------------------------------------------

function SaveWebhook(job, url)
    local on = url ~= ''
    LedgerEnsure(job)
    MySQL.update.await('UPDATE society_ledger SET webhook = ? WHERE job = ? LIMIT 1', { url, job })
    MySQL.update.await('UPDATE society_business SET webhook = ? WHERE job = ?', { on and 1 or 0, job })
    LedgerInfo[job] = LedgerInfo[job] or { webhook = '', invaccess = 0 }
    LedgerInfo[job].webhook = url
    if Biz[job] then Biz[job].webhook = on end
end

Handle('setWebhook', 1500, function(src, ch, url)
    local b, job, grade = memberBiz(ch)
    if not b then Notify(src, L('not_in_business')) return false end
    if not (IsGroupAdmin(src) or IsBossGrade(job, grade)) then Notify(src, L('no_permission')) return false end
    url = type(url) == 'string' and url:gsub('^%s+', ''):gsub('%s+$', '') or ''
    if url ~= '' and not ValidWebhook(url) then Notify(src, L('webhook_invalid')) return false end
    SaveWebhook(job, url)
    Notify(src, url == '' and L('webhook_cleared') or L('webhook_set'))
    return true
end)

---------------------------------------------------------------------------
-- AddToLedger: money another resource already took from a player
---------------------------------------------------------------------------

function AddToLedger(job, amount, reason, who)
    if type(job) ~= 'string' or not Biz[job] then return false, 'unknown business' end
    amount = tonumber(amount)
    if not amount or amount ~= amount or amount <= 0 then return false, 'amount must be positive' end
    -- the ledger holds whole dollars; cents are dropped here, not by the database
    amount = math.floor(amount)
    if amount < 1 then return false, 'amount must be at least $1' end
    reason = (type(reason) == 'string' and reason ~= '') and reason:sub(1, 80) or 'Earnings'
    who = (type(who) == 'string' and who ~= '') and who:sub(1, 100) or 'Trade'

    CreateThread(function()
        local before = LedgerGet(job)
        if before == nil then
            print(('^3[%s]^7 AddToLedger: %s had no ledger row - creating it'):format(RES, job))
            if not LedgerEnsure(job) then
                print(('^1[%s]^7 AddToLedger: could not create a ledger row for %s; %s not credited'):format(RES, job, PB.money(amount)))
                return
            end
            before = 0
        end
        if not LedgerAdd(job, amount) then
            print(('^1[%s]^7 AddToLedger: credit of %s to %s did not land'):format(RES, PB.money(amount), job))
            return
        end
        local after = LedgerGet(job) or (before + amount)
        Activity(job, 'EARNINGS', ('%s paid %s into the ledger'):format(reason, PB.money(amount)), who)
        SendLog(job, reason, COLOUR.green, table.pack(
            F('Source', who, true), F('Amount', PB.money(amount), true),
            F('Ledger', LedgerText(before, amount, after)), F('Business', job, true)))
    end)
    return true
end
