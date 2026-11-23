-- pup_business | data for the job menu and the management dashboard

Handle('whoami', 250, function(_, ch)
    return { job = ch.job, grade = CharGrade(ch), charid = CharId(ch) }
end)

Handle('businesses', 250, function(src)
    WaitLoaded(15000)
    PushBusinesses(src)
    return true
end)

local function canManageAny(p)
    return p.hire or p.fire or p.setranks or p.managepay or p.billing or p.store
end

-- everything the dashboard draws, stripped to what the viewer may see
function DashboardData(src, ch)
    local job, grade = ch.job, CharGrade(ch)
    local b = Biz[job]
    if not b then return nil end
    local admin = IsSocietyAdmin(src)
    local boss = IsBossGrade(job, grade)
    local perms = EffectivePerms(job, grade, admin)
    local canManage = boss or admin or canManageAny(perms)
    local seeLedger = boss or admin or perms.managepay
    local seeBills = boss or admin or perms.billing

    local roster = MergedRoster()
    local online = OnlineMembers(job)
    local onlineByChar, onDuty = {}, 0
    for _, m in ipairs(online) do
        onlineByChar[m.charid] = m.id
        local e = roster[m.id]
        if e and e.job == job then onDuty = onDuty + 1 end
    end

    local d = {
        job = job,
        name = DisplayName(job),
        grade = grade,
        bossrank = b.bossrank,
        recruit = b.recruitmentrank,
        isBoss = boss,
        admin = admin,
        canManage = canManage,
        perms = perms,
        invaccess = StashAccessGrade(job),
        base = Config.BaseSlots,
        bought = BoughtSlots(job),
        stashName = b.containername,
        salaryOn = b.salary,
        taxOn = b.tax,
        maxSalary = Config.MaxSalary,
        slotPrice = Config.SlotPrice,
        hasWebhook = (LedgerInfo[job] and LedgerInfo[job].webhook or '') ~= '',
        counts = { online = #online, onduty = onDuty, employees = 0 },
    }

    local members = MySQL.query.await(
        'SELECT charidentifier, firstname, lastname, jobgrade FROM characters WHERE job = ? ORDER BY jobgrade DESC, firstname ASC LIMIT 200',
        { job }) or {}
    d.counts.employees = #members

    if seeLedger then
        d.ledger = LedgerGet(job) or 0
        local payroll = 0
        for _, m in ipairs(members) do
            local r = RankOf(job, tonumber(m.jobgrade) or 0)
            payroll = payroll + (r and r.salary or 0)
        end
        d.payroll = payroll
    end

    if seeBills then
        local rows = MySQL.query.await('SELECT id, playername, issuer, amount FROM bills WHERE job = ? ORDER BY id DESC', { job }) or {}
        local list, total = {}, 0
        for _, r in ipairs(rows) do
            local amt = tonumber(r.amount) or 0
            total = total + amt
            list[#list + 1] = { id = tonumber(r.id), debtor = tostring(r.playername or '?'), issuer = tostring(r.issuer or '?'), amount = amt }
        end
        d.bills = { list = list, total = total }
    end

    if canManage then
        local list = {}
        for _, m in ipairs(members) do
            local cid = tonumber(m.charidentifier)
            local sid = onlineByChar[cid]
            local e = sid and roster[sid]
            list[#list + 1] = {
                charid = cid,
                name = (('%s %s'):format(m.firstname or '', m.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                grade = tonumber(m.jobgrade) or 0,
                online = sid ~= nil,
                id = sid,
                onduty = e ~= nil and e.job == job,
                self = cid == CharId(ch),
            }
        end
        d.members = list

        local ranks = {}
        for g = b.bossrank, 0, -1 do
            local r = RankOf(job, g) or { salary = 0, tax = 0, taxperiod = 'weekly' }
            ranks[#ranks + 1] = {
                grade = g, salary = r.salary or 0, perms = RankPerms(job, g),
                tax = r.tax or 0, taxperiod = r.taxperiod or 'weekly',
            }
        end
        d.ranks = ranks
    end
    return d
end

Handle('dash', 400, function(src, ch)
    return DashboardData(src, ch) or false
end)

-- one round trip for the job menu: dashboard, tax line
Handle('jobMenu', 600, function(src, ch)
    local d = DashboardData(src, ch)
    if not d then return false end
    d.tax = TaxStatus(CharId(ch), ch.job, CharGrade(ch)) or false
    return d
end)

---------------------------------------------------------------------------
-- dashboard rank card save
---------------------------------------------------------------------------

Handle('rankSave', 750, function(src, ch, data)
    if type(data) ~= 'table' then return false end
    local job, myGrade = ch.job, CharGrade(ch)
    local b = Biz[job]
    if not b then Notify(src, L('not_in_business')) return false end
    local grade = PB.int(data.id)
    if not grade or grade < 0 or grade > b.bossrank then Notify(src, L('invalid_grade')) return false end

    local admin = IsSocietyAdmin(src)
    local boss = IsBossGrade(job, myGrade)
    local mine = EffectivePerms(job, myGrade, false)
    if not (admin or boss or (mine.setranks and mine.managepay and grade < myGrade)) then
        Notify(src, L('no_permission')) return false
    end

    local salary = PB.int(data.salary) or 0
    salary = math.max(0, math.min(salary, Config.MaxSalary))
    local perms = {}
    if grade >= b.bossrank then
        perms = AllPerms()
    elseif type(data.perms) == 'table' then
        for _, k in ipairs(PB.PERM_KEYS) do perms[k] = data.perms[k] == true end
    end

    local cur = RankOf(job, grade) or { salary = 0, tax = 0, taxperiod = 'weekly', taxsince = 0 }
    local tax, period, since = cur.tax or 0, cur.taxperiod or 'weekly', cur.taxsince or 0
    local restarted = false
    if b.tax and data.tax ~= nil then
        local newTax = math.max(0, math.min(PB.int(data.tax) or 0, 1000000))
        local newPeriod = PB.period(data.taxperiod)
        if newTax ~= tax or newPeriod ~= period or since <= 0 then
            since = Now()
            restarted = true
        end
        tax, period = newTax, newPeriod
    end

    MySQL.update.await([[
        INSERT INTO society_ranks (job, grade, salary, perms, tax, taxperiod, taxsince) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE salary = VALUES(salary), perms = VALUES(perms), tax = VALUES(tax),
            taxperiod = VALUES(taxperiod), taxsince = VALUES(taxsince)
    ]], { job, grade, salary, EncodePerms(perms), tax, period, since })
    WriteSalary(job, grade, salary)
    Ranks[job] = Ranks[job] or {}
    Ranks[job][grade] = { salary = salary, perms = DecodePerms(EncodePerms(perms)), tax = tax, taxperiod = period, taxsince = since }

    if restarted then
        RestartTaxCycle(job, grade, since)
        if tax > 0 then Notify(src, L('tax_set', PB.money(tax), period)) end
    end

    local who = FullName(ch)
    Notify(src, L('rank_saved', grade))
    Activity(job, 'RANKSAVE', ('Grade %d saved: salary %s'):format(grade, PB.money(salary)), who)
    SendLog(job, 'Rank Updated', COLOUR.yellow, table.pack(F('Who', WhoText(src))),
        ('%s set grade %d salary to %s and updated its permissions'):format(who, grade, PB.money(salary)))
    return true
end)
