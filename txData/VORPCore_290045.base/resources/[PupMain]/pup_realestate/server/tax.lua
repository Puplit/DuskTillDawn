-- pup_realestate | tax collection, warnings and repossession

local warned = {}         -- due timestamp -> true (memory only; a restart inside the hour may warn again)
local collectedKey = nil  -- year-dayofyear of the last run seen this session

local function balanceOf(h)
    if Config.Ledger.taxLedger then return h.taxledger end
    return h.ledger
end

-- the due time on the calendar day of ts, or nil when that day collects nothing
local function dueOn(ts)
    local t = os.date('*t', ts)
    local hour, minute
    local m, w = Config.Tax.monthly, Config.Tax.weekly
    if m.enabled then
        if t.day ~= m.day then return nil end
        hour, minute = m.hour, m.minute
    elseif w.enabled then
        if not U.inList(w.days, t.day) then return nil end
        hour, minute = w.hour, w.minute
    else
        return nil
    end
    return os.time({ year = t.year, month = t.month, day = t.day, hour = hour, min = minute, sec = 0 })
end

local function dayKey(ts)
    return ('%s-%03d'):format(os.date('%Y', ts), tonumber(os.date('%j', ts)))
end

local function owedHouses()
    local list = {}
    for _, h in pairs(S.houses) do
        if h.owned and (h.tax or 0) > 0 and (h.buyerChar or 0) > 0 then list[#list + 1] = h end
    end
    return list
end

local function sendWarnings()
    local n = 0
    for _, h in ipairs(owedHouses()) do
        local bal = balanceOf(h)
        if bal < h.tax then
            n = n + 1
            local short = h.tax - bal
            local title = U.title(h)
            S.sendLetter(h.buyerChar, 'Tax Due: ' .. title, table.concat({
                ('Property tax on %s is collected in one hour.'):format(title),
                '',
                ('Due: $%s'):format(U.money(h.tax)),
                ('Held in the %s: $%s'):format(Config.Ledger.taxLedger and 'tax ledger' or 'ledger', U.money(bal)),
                ('Short by: $%s'):format(U.money(short)),
                '',
                'Unless the ledger is topped up before collection, the property will be repossessed and put back on the market.',
                '',
                '- Housing Team',
            }, '\n'))
            local src = S.sourceOf(h.buyerChar)
            if src then Tip(src, ('%s is $%s short for tax - collection is in one hour'):format(title, U.money(short)), 10000) end
        end
    end
    if n > 0 then AdminLog(('Tax warnings sent to %s house owner(s).'):format(n)) end
end

local function repossess(h)
    local bal = balanceOf(h)
    local formerOwner = h.buyerChar
    local title = U.title(h)
    h.taxledger = 0
    if not Config.Rules.repoKeepsLedger then h.ledger = 0 end
    S.save(h, 'taxledger', 'ledger')
    S.clearOwner(h, { repo = true })
    Activity(h.id, 'REPO', ('Tax $%s not covered (held $%s)'):format(h.tax, bal), nil)
    S.sendLetter(formerOwner, 'House Repossessed: ' .. title, table.concat({
        ('%s has been repossessed for unpaid property tax.'):format(title),
        '',
        ('Tax due: $%s'):format(U.money(h.tax)),
        ('Held in the %s: $%s'):format(Config.Ledger.taxLedger and 'tax ledger' or 'ledger', U.money(bal)),
        '',
        'The property is back on the market and every key to it is void.',
        'Anything stored there and the furniture stay with the house and pass to its next owner.',
        Config.Rules.repoKeepsLedger and 'The money in the house ledger also stays with the property.' or 'The house ledger was emptied.',
        '',
        ('Keep at least $%s in the %s to avoid this in future.'):format(U.money(h.tax), Config.Ledger.taxLedger and 'tax ledger' or 'ledger'),
        '',
        '- Housing Team',
    }, '\n'))
    local src = S.sourceOf(formerOwner)
    if src then Tip(src, ('%s has been repossessed for unpaid tax'):format(title), 10000) end
end

local function collect(key)
    -- the day key is written before running so a crash cannot collect twice
    local ok, last = pcall(MySQL.scalar.await, 'SELECT lastrun FROM cron_state WHERE name = ?', { 'housing' })
    if not ok then return end
    collectedKey = key
    if last == key then return end
    local okW = pcall(MySQL.update.await,
        'INSERT INTO cron_state (name, lastrun) VALUES (?, ?) ON DUPLICATE KEY UPDATE lastrun = VALUES(lastrun)', { 'housing', key })
    if not okW then
        collectedKey = nil
        return
    end
    local repod = 0
    for _, h in ipairs(owedHouses()) do
        if balanceOf(h) < h.tax then
            repossess(h)
            repod = repod + 1
        elseif Config.Ledger.taxLedger then
            h.taxledger = h.taxledger - h.tax
            S.save(h, 'taxledger')
        else
            h.ledger = h.ledger - h.tax
            S.save(h, 'ledger')
        end
    end
    S.sendFull()
    AdminLog(('House tax collection executed. Repossessed %s houses.'):format(repod))
end

local function tick()
    local now = Now()
    -- warnings: today's or tomorrow's due time (an early collection time warns the evening before)
    for _, day in ipairs({ now, now + 86400 }) do
        local due = dueOn(day)
        if due and now >= due - 3600 and now < due and not warned[due] then
            warned[due] = true
            sendWarnings()
        end
    end
    local due = dueOn(now)
    if due and now >= due then
        local key = dayKey(now)
        if collectedKey ~= key then collect(key) end
    end
end

CreateThread(function()
    while not S.ready do Wait(1000) end
    while true do
        local ok, err = pcall(tick)
        if not ok then Warn('tax clock: %s', tostring(err)) end
        Wait(60000)
    end
end)
