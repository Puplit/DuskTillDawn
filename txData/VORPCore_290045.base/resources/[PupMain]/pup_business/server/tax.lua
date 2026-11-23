-- pup_business | per-rank business tax

local function taxRule(job, grade)
    local b = Biz[job]
    if not b or not b.tax then return nil end
    local r = RankOf(job, grade)
    if not r or r.tax <= 0 or r.taxsince <= 0 then return nil end
    return r
end

-- the record measured against the current cycle; a missing or stale record
-- starts square (everything already elapsed counts as paid)
local function taxRecord(charid, job, grade, rule, now)
    local len = PB.PERIODS[rule.taxperiod]
    local elapsed = math.max(0, (now - rule.taxsince) // len)
    local rec = MySQL.single.await('SELECT grade, anchor, paidperiods, lastpaid FROM society_tax WHERE charidentifier = ? AND job = ?', { charid, job })
    if not rec or tonumber(rec.grade) ~= grade or tonumber(rec.anchor) ~= rule.taxsince then
        MySQL.update.await([[
            INSERT INTO society_tax (charidentifier, job, grade, anchor, paidperiods, lastpaid) VALUES (?, ?, ?, ?, ?, NULL)
            ON DUPLICATE KEY UPDATE grade = VALUES(grade), anchor = VALUES(anchor), paidperiods = VALUES(paidperiods), lastpaid = NULL
        ]], { charid, job, grade, rule.taxsince, elapsed })
        return { grade = grade, anchor = rule.taxsince, paid = elapsed, lastpaid = nil }, elapsed, len
    end
    return { grade = grade, anchor = rule.taxsince, paid = tonumber(rec.paidperiods) or 0, lastpaid = tonumber(rec.lastpaid) }, elapsed, len
end

-- nil when no tax applies; otherwise a status table for menus
function TaxStatus(charid, job, grade)
    local rule = taxRule(job, grade)
    if not rule then return nil end
    local now = Now()
    local rec, elapsed, len = taxRecord(charid, job, grade, rule, now)
    local owed = math.max(0, elapsed - rec.paid)
    return {
        owed = owed,
        due = owed * rule.tax,
        rate = rule.tax,
        period = rule.taxperiod,
        nextDue = FormatDate(rule.taxsince + (rec.paid + 1) * len),
        lastPaid = FormatDate(rec.lastpaid),
        elapsed = elapsed,
        paid = rec.paid,
        anchor = rule.taxsince,
    }
end

Handle('taxStatus', 400, function(_, ch)
    return TaxStatus(CharId(ch), ch.job, CharGrade(ch)) or false
end)

Handle('payTax', 2000, function(src, ch)
    local charid, job, grade = CharId(ch), ch.job, CharGrade(ch)
    local st = TaxStatus(charid, job, grade)
    if not st then Notify(src, L('tax_none')) return false end
    if st.owed <= 0 then Notify(src, L('tax_nothing_due', st.nextDue)) return false end
    local cash = tonumber((GetCharIf(src, charid) or {}).money) or 0
    if cash < st.due then Notify(src, L('tax_need_cash', PB.money(st.due))) return false end
    if not LedgerEnsure(job) then Notify(src, L('ledger_missing')) return false end

    -- claim the owed periods: only one request can move paidperiods from this value
    local now = Now()
    local claimed = MySQL.update.await([[
        UPDATE society_tax SET paidperiods = ?, lastpaid = ?
        WHERE charidentifier = ? AND job = ? AND grade = ? AND anchor = ? AND paidperiods = ?
    ]], { st.elapsed, now, charid, job, grade, st.anchor, st.paid })
    if (tonumber(claimed) or 0) ~= 1 then return false end

    local function unclaim()
        MySQL.update.await([[
            UPDATE society_tax SET paidperiods = ?, lastpaid = NULL
            WHERE charidentifier = ? AND job = ? AND anchor = ? AND paidperiods = ?
        ]], { st.paid, charid, job, st.anchor, st.elapsed })
    end

    -- the rank or job may have changed while the claim was in flight
    local again = GetCharIf(src, charid)
    if not again or again.job ~= job or CharGrade(again) ~= grade then unclaim() return false end

    local lockKey = 'cash:' .. charid
    if not Lock(lockKey) then unclaim() return false end
    local ok, reason = CashToLedger(src, charid, job, st.due, false)
    Unlock(lockKey)
    if not ok then
        unclaim()
        Notify(src, reason == 'cash' and L('tax_need_cash', PB.money(st.due)) or LedgerFailText(reason))
        return false
    end

    local len = PB.PERIODS[st.period]
    local nextDue = FormatDate(st.anchor + (st.elapsed + 1) * len)
    Notify(src, L('tax_paid', PB.money(st.due), nextDue))
    Notify(src, L('tax_paid_tip', nextDue))
    Activity(job, 'TAX', ('Paid %s tax (%d %s periods)'):format(PB.money(st.due), st.owed, st.period), FullName(ch))
    return true
end)

-- restarts a grade's cycle now: every member of that grade, online or not, starts at zero
function RestartTaxCycle(job, grade, now)
    local rows = MySQL.query.await('SELECT charidentifier FROM characters WHERE job = ? AND jobgrade = ?', { job, grade }) or {}
    for _, r in ipairs(rows) do
        local cid = tonumber(r.charidentifier)
        if cid then
            MySQL.update.await([[
                INSERT INTO society_tax (charidentifier, job, grade, anchor, paidperiods, lastpaid) VALUES (?, ?, ?, ?, 0, NULL)
                ON DUPLICATE KEY UPDATE grade = VALUES(grade), anchor = VALUES(anchor), paidperiods = 0, lastpaid = NULL
            ]], { cid, job, grade, now })
        end
    end
end
