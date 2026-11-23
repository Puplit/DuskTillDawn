-- pup_mercantile | monthly (or "weekly") tax on player shops, and repossession

local warnedDay = nil
local collectedDay = nil

-- the due time today, or nil when today is not a collection day
local function dueToday(now)
    local t = os.date('*t', now)
    local sched
    if Config.Tax.monthly.enabled then
        if t.day == Config.Tax.monthly.day then sched = Config.Tax.monthly end
    elseif Config.Tax.weekly.enabled then
        for _, d in ipairs(Config.Tax.weekly.days) do
            if t.day == d then sched = Config.Tax.weekly break end
        end
    end
    if not sched then return nil end
    return os.time({ year = t.year, month = t.month, day = t.day, hour = sched.hour, min = sched.minute, sec = 0 })
end

local function dayKey(now)
    return os.date('%Y-%j', now)
end

local function warnOwners(now)
    local tax = Config.Tax.amount
    local warned = 0
    for _, s in pairs(Shops.player) do
        if not s.repo and s.charid ~= 0 and s.taxledger < tax then
            local short = Util.round2(tax - s.taxledger)
            SendMail(s.charid, Util.L('mailTaxSubject', s.name, s.id),
                Util.L('mailTaxBody', Util.fmt(tax), Util.fmt(s.taxledger), Util.fmt(short)))
            local online = OnlineByCharId(s.charid)
            if online then Notify(online, Util.L('taxWarnTip', s.name, Util.fmt(short)), 10000) end
            warned = warned + 1
        end
    end
    print(('[pup_mercantile] tax warning sent to %d shop owner(s)'):format(warned))
    warnedDay = dayKey(now)
end

local function collect(now)
    local key = dayKey(now)
    if collectedDay == key then return end
    local okr, last = pcall(MySQL.scalar.await, "SELECT lastrun FROM cron_state WHERE name = 'stores'")
    if not okr then return end
    if last == key then collectedDay = key return end
    -- written before the run, so a restart in the middle cannot collect twice
    local okw = pcall(MySQL.query.await,
        "INSERT INTO cron_state (name, lastrun) VALUES ('stores', ?) ON DUPLICATE KEY UPDATE lastrun = VALUES(lastrun)", { key })
    if not okw then return end
    collectedDay = key

    local tax = Config.Tax.amount
    for _, s in pairs(Shops.player) do
        if not s.repo and s.charid ~= 0 then
            local online = OnlineByCharId(s.charid)
            if s.taxledger >= tax then
                s.taxledger = Util.round2(s.taxledger - tax)
                SaveShop(s)
                if online then Notify(online, Util.L('taxPaid'), 6000) end
            else
                s.repo = true
                SaveShop(s)
                CloseShopForEveryone(s)
                BroadcastShop(s)
                if online then Notify(online, Util.L('taxFailed'), 10000) end
                Log({ title = Util.L('logRepo'), colour = Colours.repo, shop = s, fields = {
                    { 'Name', s.name }, { 'Shop', '#' .. s.id }, { 'Tax ledger', '$' .. Util.fmt(s.taxledger) },
                    { 'Required', '$' .. Util.fmt(tax) } } })
                SendMail(s.charid, Util.L('mailRepoSubject', s.name),
                    Util.L('mailRepoBody', Util.fmt(tax), Util.fmt(s.taxledger)))
            end
        end
    end
    print('[pup_mercantile] store tax collected')
end

CreateThread(function()
    while true do
        Wait((Config.Tax.checkEvery or 30) * 1000)
        if ShopsReady then
            local now = os.time()
            local due = dueToday(now)
            if due then
                if now >= due then
                    local ok, err = pcall(collect, now)
                    if not ok then print('^1[pup_mercantile]^7 tax collection failed: ' .. tostring(err)) end
                elseif now >= due - Config.Tax.warnMinutes * 60 and warnedDay ~= dayKey(now) then
                    local ok, err = pcall(warnOwners, now)
                    if not ok then print('^1[pup_mercantile]^7 tax warning failed: ' .. tostring(err)) end
                end
            end
        end
    end
end)
