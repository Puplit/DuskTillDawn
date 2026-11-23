-- pup-mdt | department and firm ledgers, payroll

Ledger = {}

local function ensure(job)
    DB.q('INSERT IGNORE INTO mdt_ledger (job, balance) VALUES (?, ?)', { job, Config.Ledger.startBalance or 0 })
end
Ledger.ensure = ensure

function Ledger.balance(job)
    ensure(job)
    return tonumber(DB.val('SELECT balance FROM mdt_ledger WHERE job = ?', { job })) or 0
end

local function logRow(job, kind, amount, actorName, note)
    local after = Ledger.balance(job)
    DB.ins('INSERT INTO mdt_ledger_log (job, type, amount, balance_after, actor_name, note) VALUES (?, ?, ?, ?, ?, ?)',
        { job, kind, amount, after, actorName or 'System', MDT.str(note, 255) })
    return after
end

function Ledger.credit(job, amount, kind, actorName, note)
    amount = MDT.int(amount, 0, nil, 0)
    if amount <= 0 or not job then return false end
    ensure(job)
    DB.upd('UPDATE mdt_ledger SET balance = balance + ? WHERE job = ?', { amount, job })
    logRow(job, kind or 'credit', amount, actorName, note)
    return true
end

-- atomic: only when the balance covers it (unless negatives are allowed)
function Ledger.debit(job, amount, kind, actorName, note)
    amount = MDT.int(amount, 0, nil, 0)
    if amount <= 0 or not job then return false end
    ensure(job)
    local n
    if Config.Ledger.allowNegative then
        n = DB.upd('UPDATE mdt_ledger SET balance = balance - ? WHERE job = ?', { amount, job })
    else
        n = DB.upd('UPDATE mdt_ledger SET balance = balance - ? WHERE job = ? AND balance >= ?', { amount, job, amount })
    end
    if n == 0 then return false end
    logRow(job, kind or 'debit', -amount, actorName, note)
    return true
end

local function ledgerOn(actor)
    if not Config.Ledger.enabled then return false end
    if actor.isLawyer and not Config.Legal.firmLedger.enabled then return false end
    return true
end

local function atStation(actor)
    local list, only, radius
    if actor.isLawyer then
        list, only, radius = Config.Legal.firmLedger.stations, Config.Legal.firmLedger.stationOnly, Config.Ledger.stationRadius
    else
        list, only, radius = Config.Ledger.stations, Config.Ledger.stationOnly, Config.Ledger.stationRadius
    end
    if not only or not list or #list == 0 then return true end
    local c = MDT.coords(actor.src)
    if not c then return false end
    for _, s in ipairs(list) do
        if MDT.dist(c, s.coords) <= (s.radius or radius) then return true end
    end
    return false
end

local function wageFor(job, grade)
    local w = Config.Payroll.wages[job]
    if not w then return 0 end
    return tonumber(w[tonumber(grade) or 0]) or tonumber(w.default) or 0
end

MDT.rpc('getLedger', { perm = 'ledger', staff = true, deny = { enabled = false } }, function(actor)
    if not ledgerOn(actor) then return { enabled = false } end
    return {
        enabled = true,
        balance = Ledger.balance(actor.job),
        job = actor.job,
        currency = Config.Ledger.currency,
        canDeposit = MDT.can(actor, 'ledgerdeposit'),
        canWithdraw = MDT.can(actor, 'ledgerwithdraw'),
        atStation = atStation(actor),
        salary = Config.Payroll.enabled and { amount = wageFor(actor.job, actor.grade), interval = Config.Payroll.intervalMinutes } or nil,
    }
end)

MDT.rpc('ledgerDeposit', { perm = 'ledger', staff = true, duty = true }, function(actor, p)
    if not ledgerOn(actor) then return { success = false, message = L('ledger_disabled') } end
    if not MDT.can(actor, 'ledgerdeposit') then return { success = false, message = L('no_permission') } end
    if not atStation(actor) then return { success = false, message = L('ledger_not_at_station') } end
    local amount = MDT.int(p.amount, 1, 100000000, nil)
    if not amount or tonumber(p.amount) ~= amount then return { success = false, message = L('ledger_bad_amount') } end
    local ch = MDT.char(actor.src)
    if not ch or (tonumber(ch.money) or 0) < amount then return { success = false, message = L('ledger_not_enough_cash') } end
    ch.removeCurrency(0, amount)
    Ledger.credit(actor.job, amount, 'deposit', actor.name, 'Deposit')
    MDT.audit(actor, actor.isLawyer and 'lawyer_ledger_deposit' or 'ledger_deposit', nil, nil, ('$%d deposited'):format(amount))
    return { success = true, message = L('ledger_deposited', amount), balance = Ledger.balance(actor.job) }
end)

MDT.rpc('ledgerWithdraw', { perm = 'ledgerwithdraw', staff = true, duty = true }, function(actor, p)
    if not ledgerOn(actor) then return { success = false, message = L('ledger_disabled') } end
    if not MDT.can(actor, 'ledger') then return { success = false, message = L('no_permission') } end
    if not atStation(actor) then return { success = false, message = L('ledger_not_at_station') } end
    local amount = MDT.int(p.amount, 1, 100000000, nil)
    if not amount or tonumber(p.amount) ~= amount then return { success = false, message = L('ledger_bad_amount') } end
    if not Ledger.debit(actor.job, amount, 'withdraw', actor.name, 'Withdrawal') then
        return { success = false, message = L('ledger_insufficient'), balance = Ledger.balance(actor.job) }
    end
    local ch = MDT.char(actor.src)
    local ok = ch ~= nil and tostring(ch.charIdentifier) == actor.cid and pcall(ch.addCurrency, 0, amount)
    if not ok then
        Ledger.credit(actor.job, amount, 'withdraw_refund', actor.name, 'Withdrawal could not be paid out')
        return { success = false, message = L('ledger_payout_failed'), balance = Ledger.balance(actor.job) }
    end
    MDT.audit(actor, actor.isLawyer and 'lawyer_ledger_withdraw' or 'ledger_withdraw', nil, nil, ('$%d withdrawn'):format(amount))
    return { success = true, message = L('ledger_withdrawn', amount), balance = Ledger.balance(actor.job) }
end)

---------------------------------------------------------------------------
-- Payroll: wages in proportion to the minutes on duty since the last payday
---------------------------------------------------------------------------
-- the server watches on-duty positions itself too, so a payday never relies only on the
-- client's AFK report: standing within Config.Duty.serverAfkMetres for afkMinutes is idle
local function serverAfkOn()
    return (tonumber(Config.Duty.afkMinutes) or 0) > 0 and (tonumber(Config.Duty.serverAfkMetres) or 0) > 0
end

local function samplePosition(src, s)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local pos = GetEntityCoords(ped)
    if pos.x == 0.0 and pos.y == 0.0 and pos.z == 0.0 then return end
    local now = os.time()
    if not s.afkPos or #(pos - s.afkPos) > Config.Duty.serverAfkMetres then
        s.afkPos = pos
        s.movedAt = now
    end
end

local function idleTooLong(s)
    if not serverAfkOn() or not s.movedAt then return false end
    return os.time() - s.movedAt >= Config.Duty.afkMinutes * 60
end

CreateThread(function()
    while true do
        Wait(math.max(10, tonumber(Config.Duty.afkPollSeconds) or 10) * 1000)
        if serverAfkOn() then
            for _, src in ipairs(MDT.keys(Duty.state)) do
                local s = Duty.state[src]
                if s and s.on and MDT.online(src) then pcall(samplePosition, src, s) end
            end
        end
    end
end)

local function payOne(src, s)
    local a = MDT.player(src)
    if not a or (not a.isLaw and not a.isLawyer) then return end
    if a.isLawyer and Config.Payroll.fromLedger and not Config.Legal.firmLedger.enabled then return end
    local interval = math.max(1, Config.Payroll.intervalMinutes) * 60
    local now = os.time()
    if idleTooLong(s) then
        s.lastPay = now
        Duty.clockOff(src, 'afk')
        return
    end
    local since = math.max(s.lastPay or s.since or now, s.since or now)
    local share = Config.Payroll.proRata and math.min(1, (now - since) / interval) or 1
    s.lastPay = now
    local wage = math.floor(wageFor(a.job, a.grade) * share)
    if wage <= 0 then return end
    if Config.Payroll.fromLedger and Config.Ledger.enabled then
        if not Ledger.debit(a.job, wage, 'salary', a.name, 'Payday') then
            return MDT.notify(src, L('ledger_payday_skipped'), 6000)
        end
        -- the debit waited on the database: pay the character that is loaded now, if it is still theirs
        local ch = MDT.char(src)
        local ok = ch ~= nil and tostring(ch.charIdentifier) == a.cid and pcall(ch.addCurrency, 0, wage)
        if not ok then
            Ledger.credit(a.job, wage, 'salary_refund', a.name, 'Payday could not be paid out')
            return
        end
    else
        a.char.addCurrency(0, wage)
    end
    MDT.notify(src, L('ledger_payday', wage), 6000)
end

CreateThread(function()
    while true do
        Wait(math.max(1, Config.Payroll.intervalMinutes) * 60000)
        if Config.Payroll.enabled and Config.Ledger.enabled then
            for _, src in ipairs(MDT.keys(Duty.state)) do
                local s = Duty.state[src]
                if s and s.on and MDT.online(src) then
                    local ok, err = pcall(payOne, src, s)
                    if not ok then print('^1[pup-mdt]^7 payroll: ' .. tostring(err)) end
                end
            end
        end
    end
end)
