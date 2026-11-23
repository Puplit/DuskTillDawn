-- pup_business | bills: writing, auto-collect, paying and deleting

local function issuerBiz(ch)
    local b = Biz[ch.job]
    if not b or not b.billing then return nil end
    return b
end

-- last bill time per business + target character (GetGameTimer ms)
local lastBilled = {}

Handle('bill', 1500, function(src, ch, target, amount)
    local b = issuerBiz(ch)
    if not b then Notify(src, L('cant_bill')) return false end
    local job = ch.job
    if Config.BillingNeedsPerm and not HasRankPerm(job, CharGrade(ch), 'billing') then
        Notify(src, L('rank_cant_bill')) return false
    end

    amount = tonumber(amount)
    if not amount or amount ~= amount or amount <= 0 then Notify(src, L('invalid_amount')) return false end
    if amount > Config.MaxBill then Notify(src, L('bill_too_big', Config.MaxBill)) return false end
    -- bills and the ledger are whole dollars
    amount = math.floor(amount)
    if amount < 1 then Notify(src, L('bill_min')) return false end

    target = PB.int(target)
    if not target then Notify(src, L('no_person_nearby')) return false end
    if target == src then Notify(src, L('cant_bill_self')) return false end
    local tch = GetChar(target)
    if not tch then Notify(src, L('no_person_nearby')) return false end
    if not WithinOrUnknown(src, target, Config.BillReachServer) then Notify(src, L('too_far_to_bill')) return false end

    local issuer = FullName(ch)
    local debtor = FullName(tch)
    local tCharid = CharId(tch)

    -- one bill per business and target within Config.BillCooldownSeconds
    local coolKey = job .. ':' .. tostring(tCharid)
    local coolMs = (tonumber(Config.BillCooldownSeconds) or 0) * 1000
    local nowMs = GetGameTimer()
    local last = lastBilled[coolKey]
    if last and nowMs - last < coolMs then
        Notify(src, L('bill_cooldown', math.ceil((coolMs - (nowMs - last)) / 1000))) return false
    end

    -- auto-collect: straight from the target's cash into the ledger
    if Config.AutoCollect and Config.AutoCollectJobs[job] then
        local cashNow = tonumber(tch.money) or 0
        local canPay = cashNow >= amount
        if canPay or Config.AllowDebt then
            local lockKey = 'cash:' .. tCharid
            if not Lock(lockKey) then return false end
            local before = LedgerGet(job)
            local ok, reason, cashBefore = CashToLedger(target, tCharid, job, amount, Config.AllowDebt)
            Unlock(lockKey)
            if not ok then Notify(src, LedgerFailText(reason)) return false end
            lastBilled[coolKey] = GetGameTimer()
            local debt = (cashBefore or cashNow) < amount
            Notify(src, L('bill_sent', amount))
            Notify(target, L('bill_received', amount))
            if debt then
                Notify(target, L('bill_debt', PB.money(amount - math.max(0, cashBefore or 0))))
            end
            Activity(job, 'BILLPAID', ('%s paid %s on the spot'):format(debtor, PB.money(amount)), issuer)
            CreateThread(function()
                local after = LedgerGet(job) or 0
                SendLog(job, 'Bill collected', debt and COLOUR.red or COLOUR.orange, table.pack(
                    F('Collected by', WhoText(src)), F('From', WhoText(target)), F('Amount', PB.money(amount), true),
                    F('Ledger', LedgerText(before or (after - amount), amount, after)),
                    F('Method', debt and 'Auto-collect - put them in debt' or 'Auto-collect', true),
                    F('Business', job, true)))
            end)
            return true
        end
        -- not enough cash and no debt: nothing is taken, the bill waits on /paybills
        Notify(src, L('bill_cant_cover'))
    end

    -- everyone else: a bill waiting on /paybills
    local id = MySQL.insert.await(
        'INSERT INTO bills (job, playername, identifier, charidentifier, issuer, amount) VALUES (?, ?, ?, ?, ?, ?)',
        { job, debtor, tch.identifier, tCharid, issuer, amount })
    if not id then Notify(src, L('action_failed')) return false end
    lastBilled[coolKey] = GetGameTimer()
    Notify(src, L('bill_sent', amount))
    Notify(target, L('bill_received', amount))
    SendLog(job, 'Bill issued', COLOUR.orange, table.pack(
        F('Issued by', WhoText(src)), F('Billed to', WhoText(target)), F('Amount', PB.money(amount), true),
        F('Status', 'Unpaid - waiting on /paybills', true), F('Business', job, true)))
    return true
end)

-- the caller's own unpaid bills
Handle('myBills', 1000, function(_, ch)
    local rows = MySQL.query.await('SELECT id, job, amount FROM bills WHERE charidentifier = ? ORDER BY id ASC', { CharId(ch) }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        out[#out + 1] = { id = tonumber(r.id), job = tostring(r.job or ''), amount = tonumber(r.amount) or 0 }
    end
    return out
end)

-- pays one bill. The bill row is claimed (deleted) first; only the request that
-- removed it moves any money. If the money cannot move, the row is put back.
Handle('payBill', 1500, function(src, ch, billId)
    billId = PB.int(billId)
    if not billId then return false end
    local charid = CharId(ch)
    local row = MySQL.single.await('SELECT * FROM bills WHERE id = ? AND charidentifier = ? LIMIT 1', { billId, charid })
    if not row then Notify(src, L('bill_not_found')) return false end
    local amount = tonumber(row.amount) or 0
    local job = tostring(row.job or '')

    if amount <= 0 then
        MySQL.update.await('DELETE FROM bills WHERE id = ? AND charidentifier = ?', { billId, charid })
        return true
    end

    local now = GetCharIf(src, charid)
    if not now or (tonumber(now.money) or 0) < amount then Notify(src, L('not_enough_money')) return false end
    if not LedgerEnsure(job) then Notify(src, L('ledger_missing')) return false end

    local claimed = MySQL.update.await('DELETE FROM bills WHERE id = ? AND charidentifier = ?', { billId, charid })
    if (tonumber(claimed) or 0) ~= 1 then return false end

    local function restore()
        MySQL.insert.await(
            'INSERT INTO bills (id, job, playername, identifier, charidentifier, issuer, amount) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { billId, row.job, row.playername, row.identifier, row.charidentifier, row.issuer, row.amount })
    end

    local lockKey = 'cash:' .. charid
    if not Lock(lockKey) then restore() return false end
    local before = LedgerGet(job)
    local ok, reason, cashBefore = CashToLedger(src, charid, job, amount, false)
    Unlock(lockKey)
    if not ok then
        restore()
        Notify(src, LedgerFailText(reason))
        return false
    end

    Notify(src, L('bill_paid', PB.money(amount)))
    local payer = FullName(ch)
    Activity(job, 'BILLPAID', ('%s paid bill #%d for %s'):format(payer, billId, PB.money(amount)), payer)
    CreateThread(function()
        local after = LedgerGet(job) or 0
        local cashAfter = (GetCharIf(src, charid) or {}).money
        SendLog(job, 'Bill paid', COLOUR.green, table.pack(
            F('Paid by', WhoText(src)), F('Amount', PB.money(amount), true),
            F('Ledger', LedgerText(before or (after - amount), amount, after)),
            F('Payer cash', ('%s -> %s'):format(PB.money(cashBefore or 0), PB.money(cashAfter or 0)), true),
            F('Original issuer', row.issuer, true),
            F('Bill', ('#%d - %s'):format(billId, tostring(row.playername or '?')), true),
            F('Business', job, true)))
    end)
    return true
end)

-- dashboard delete: boss, billing permission, or the VORP admin group
Handle('deleteBill', 750, function(src, ch, billId)
    billId = PB.int(billId)
    if not billId then return false end
    local job, grade = ch.job, CharGrade(ch)
    local groupAdmin = IsGroupAdmin(src)
    if not groupAdmin and not (Biz[job] and HasRankPerm(job, grade, 'billing')) then
        Notify(src, L('bill_delete_denied')) return false
    end
    local row = MySQL.single.await('SELECT * FROM bills WHERE id = ? LIMIT 1', { billId })
    if not row then Notify(src, L('bill_not_found')) return false end
    if row.job ~= job and not groupAdmin then Notify(src, L('bill_not_yours')) return false end

    local n = MySQL.update.await('DELETE FROM bills WHERE id = ?', { billId })
    if (tonumber(n) or 0) == 0 then Notify(src, L('bill_delete_error')) return false end
    Notify(src, L('bill_deleted'))
    local billJob = tostring(row.job or '')
    Activity(billJob, 'BILLDEL', ('Deleted bill #%d for %s owed by %s'):format(billId, PB.money(row.amount or 0), tostring(row.playername or '?')), FullName(ch))
    SendLog(billJob, 'Bill deleted', COLOUR.red, table.pack(
        F('Deleted by', WhoText(src)), F('Amount wiped', PB.money(row.amount or 0), true),
        F('Bill', ('#%d - %s'):format(billId, tostring(row.playername or '?')), true),
        F('Original issuer', row.issuer, true), F('Debtor char ID', row.charidentifier, true),
        F('Business', billJob, true)))
    return true
end)
