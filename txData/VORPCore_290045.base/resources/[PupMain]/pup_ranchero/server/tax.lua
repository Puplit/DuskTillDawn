-- pup_ranchero | environment decay and tax / repossession

------------------------------------------------------------------------------
-- environment decay on fixed wall-clock slots: with 30 minutes the ticks are always :00 and :30,
-- no matter when the resource started
------------------------------------------------------------------------------
CreateThread(function()
    local step = math.max(1, Config.Environment.decayMinutes) * 60
    local function slot()
        local t = os.date('*t')
        return math.floor((t.hour * 3600 + t.min * 60 + t.sec) / step) + t.yday * 100000 + t.year * 100000000
    end
    local last = slot()
    while true do
        Wait(30000)
        local now = slot()
        if now ~= last then
            last = now
            local changed = {}
            for _, r in pairs(Ranches) do
                if r.owned == 1 and r.env > 0 then
                    r.env = math.max(0, r.env - Config.Environment.decay)
                    Save(r, 'q_ranch')
                    changed[#changed + 1] = r
                end
            end
            -- open menus show the new environment
            for _, r in ipairs(changed) do
                if Ranches[r.id] then RefreshRanch(r) end
            end
        end
    end
end)

------------------------------------------------------------------------------
-- tax
------------------------------------------------------------------------------
local function schedule()
    return Config.Tax.mode == 'weekly' and Config.Tax.weekly or Config.Tax.monthly
end

local function isDueDay(t)
    for _, d in ipairs(schedule().days) do
        if d == t.day then return true end
    end
    return false
end

local function dayKey(t)
    return ('%04d-%03d'):format(t.year, t.yday)
end

local function mail(charid, subject, body)
    if not charid or GetResourceState('pup_postoffice') ~= 'started' then return end
    pcall(function() exports['pup_postoffice']:SendSystemMail(charid, subject, body, Config.Tax.mailFrom) end)
end

local function tellOwner(charid, msg)
    local s = charid and SrcOfChar(charid)
    if s then Notify(s, msg, 10000) end
end

local warnedKey = nil

local function sendWarnings(key)
    if warnedKey == key then return end
    warnedKey = key
    for _, r in pairs(Ranches) do
        if r.owned == 1 and r.tax > 0 and r.ledger < r.tax then
            local title = RanchTitle(r)
            local short = r.tax - r.ledger
            mail(r.charid, ('Tax Due: %s'):format(title), table.concat({
                ('Tax of $%s falls due on %s within the hour.'):format(U.money(r.tax), title),
                ('The ranch ledger holds $%s, which leaves it $%s short.'):format(U.money(r.ledger), U.money(short)),
                Config.Tax.deleteRepo
                    and 'Unless the shortfall is deposited before collection, the ranch will be repossessed and dissolved.'
                    or 'Unless the shortfall is deposited before collection, the ranch will be repossessed and put back on sale.',
            }, '\n\n'))
            tellOwner(r.charid, L('taxWarn', title, U.money(short)))
        end
    end
end

local function repossess(r)
    local title, ownerCid, held = RanchTitle(r), r.charid, r.ledger
    local formerHands = {}
    for _, h in ipairs(r.hired) do formerHands[#formerHands + 1] = h.charidentifier end
    -- everyone loses their place: running drives end for free, so a later buyer never pays for them
    EndDrivesOfRanch(r.id)
    SetTimeout(500, function()
        RefreshChar(ownerCid)
        for _, cid in ipairs(formerHands) do RefreshChar(cid) end
    end)
    if Config.Tax.deleteRepo then
        Ranches[r.id] = nil
        MySQL.update('DELETE FROM player_ranch WHERE id = ?', { r.id })
        MySQL.update('DELETE FROM ranch_fresh WHERE ranchid = ?', { r.id })
        FreshHerds[r.id] = nil
        Activity(r.id, 'REPO', ('tax $%s unpaid (ledger $%s) - ranch dissolved'):format(U.money(r.tax), U.money(held)), 'System')
        LogPlain('ledger', r, 'Ranch Repossessed', {
            ('Ranch ID: %d'):format(r.id), ('Name: %s'):format(r.name), ('Tax: $%s'):format(U.money(r.tax)), 'Outcome: deleted',
        })
    else
        r.identifier, r.charid, r.owned, r.repoed, r.hired = nil, nil, 0, 1, {}
        LogPlain('ledger', r, 'Ranch Repossessed', {
            ('Ranch ID: %d'):format(r.id), ('Name: %s'):format(r.name), ('Tax: $%s'):format(U.money(r.tax)), 'Outcome: back on sale',
        })
        r.webhook = nil
        Save(r, 'identifier', 'charidentifier', 'owned', 'repoed', 'hired', 'webhook')
        Activity(r.id, 'REPO', ('tax $%s unpaid (ledger $%s) - back on sale'):format(U.money(r.tax), U.money(held)), 'System')
    end
    mail(ownerCid, ('Ranch Repossessed: %s'):format(title), table.concat({
        ('Tax of $%s was due on %s, but the ranch ledger held only $%s.'):format(U.money(r.tax), title, U.money(held)),
        Config.Tax.deleteRepo
            and 'The ranch has been repossessed and dissolved.'
            or 'The ranch has been repossessed and put back on the market, and its hands have been dismissed.',
        'Keep the ledger topped up ahead of each collection to avoid this in future.',
    }, '\n\n'))
    tellOwner(ownerCid, L('taxRepo', title))
end

local function collect()
    local list = {}
    for _, r in pairs(Ranches) do
        if r.owned == 1 and r.tax > 0 then list[#list + 1] = r end -- tax-0 ranches are skipped
    end
    for _, r in ipairs(list) do
        if r.ledger + 1e-6 >= r.tax then
            r.ledger = U.cents(r.ledger - r.tax)
            Save(r, 'ledger')
            Activity(r.id, 'TAX', ('Paid $%s tax'):format(U.money(r.tax)), 'System')
            LogPlain('ledger', r, 'Ranch Tax Collected', {
                ('Ranch ID: %d'):format(r.id), ('Name: %s'):format(r.name), ('Tax: $%s'):format(U.money(r.tax)), ('Ledger now: $%s'):format(U.money(r.ledger)),
            })
        else
            repossess(r)
        end
        RefreshRanch(r)
    end
    BroadcastList()
end

-- marks the day BEFORE running, so a restart later the same day never collects twice
local function claimDay(key)
    local ok, rows = pcall(MySQL.query.await, "SELECT lastrun FROM cron_state WHERE name = 'ranch'")
    if not ok then return false end
    if rows and rows[1] and rows[1].lastrun == key then return false end
    local ok2 = pcall(MySQL.query.await,
        "INSERT INTO cron_state (name, lastrun) VALUES ('ranch', ?) ON DUPLICATE KEY UPDATE lastrun = VALUES(lastrun)", { key })
    return ok2
end

CreateThread(function()
    while not RanchesReady do Wait(1000) end
    while true do
        if Config.Tax.enabled then
            local t = os.date('*t')
            if isDueDay(t) then
                local s = schedule()
                local nowMin = t.hour * 60 + t.min
                local dueMin = s.hour * 60 + s.minute
                local key = dayKey(t)
                if nowMin >= dueMin then
                    if claimDay(key) then collect() end
                elseif nowMin >= dueMin - Config.Tax.warnMinutes then
                    sendWarnings(key)
                end
            end
        end
        Wait(60000)
    end
end)
