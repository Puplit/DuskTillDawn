-- Start-up, the single panel callback, and the staff exports.

local ready = false

CreateThread(function()
    DB.EnsureSchema()
    DB.MigrateOnce()
    Items.Load()

    while GetResourceState('vorp_inventory') ~= 'started' do Wait(500) end
    Storage.RegisterAll()
    ready = true

    -- expiry sweep: first pass one interval after start
    local interval = math.max(1, Config.Sweep.intervalMinutes) * 60 * 1000
    while true do
        Wait(interval)
        local ok, err = pcall(Orders.Sweep)
        if not ok then print('[pup_tradepost] sweep failed: ' .. tostring(err)) end
    end
end)

---------------------------------------------------------------------------
-- request handling
---------------------------------------------------------------------------
local READS = { overview = true, board = true, mine = true, catalogue = true, carried = true, price = true }
local WRITES = {
    post = true, trade = true, cancel = true, licence = true, slots = true,
    storage = true, withdraw = true, tobank = true, paywith = true,
}

local function num(v)
    local n = tonumber(v)
    if not n or n ~= n then return nil end
    return n
end

local function doRead(src, charid, req)
    local op = req.op
    if op == 'overview' then return Reads.Overview(src, charid, req.market) end
    if op == 'board' then return Reads.Board(src, charid, req) end
    if op == 'mine' then return Reads.Mine(charid) end
    if op == 'catalogue' then return Reads.Catalogue(req.search) end
    if op == 'carried' then return Reads.Carried(src) end
    if op == 'price' then return { detail = Reads.Price(req.item) } end
    return nil
end

local function withdraw(src, charid)
    local acct = Money.Account(charid)
    if acct.balance <= 0 then return false, Lang.nothingToTake end
    if acct.balance < TP.ToCents(Config.Payout.minWithdraw) then return false, Lang.badAmount end
    local cents = acct.balance
    if not TP.SameChar(src, charid) then return false, Lang.notOpen end
    if not Money.TakeLedger(charid, cents) then return false, Lang.nothingToTake end
    if not Money.GiveCash(src, charid, cents) then
        Money.CreditLedger(charid, cents, false)
        return false, Lang.failed
    end
    return true, Lang.withdrew:format(TP.Money(TP.FromCents(cents)))
end

local function toBank(charid)
    local acct = Money.Account(charid)
    if not acct.bank then return false, Lang.pickBank end
    if acct.balance <= 0 then return false, Lang.nothingToTake end
    if acct.balance < (TP.ToCents(Config.Payout.minToBank) or 0) then return false, Lang.badAmount end
    local ok, why = Money.SendToBank(charid, acct.balance, acct.bank)
    if not ok then return false, why end
    return true, Lang.sentToBank:format(TP.Money(TP.FromCents(acct.balance)), acct.bank)
end

local function payWith(charid, value)
    if value == 'cash' then
        Money.SetPayWith(charid, 'cash')
        return true, Lang.payCash
    end
    local branch = Money.ValidBank(value)
    if not branch then return false, Lang.unknownBank end
    Money.SetPayWith(charid, 'bank', branch)
    return true, Lang.payBank:format(branch)
end

-- returns ok, message, logTitle, logColour, extra
local function doWrite(src, charid, req)
    local op, market = req.op, req.market
    local c = Config.Discord.colours
    if op == 'post' then
        local ok, msg = Orders.Post(src, charid, market, req.side, req.item, num(req.qty), num(req.price))
        return ok, msg, ok and Lang.logPosted, c.posted, ok and { switchTab = 'mine' } or nil
    elseif op == 'trade' then
        local ok, msg = Orders.Trade(src, charid, market, num(req.id), num(req.qty))
        return ok, msg, ok and Lang.logTrade, c.trade
    elseif op == 'cancel' then
        local ok, msg = Orders.Cancel(src, charid, num(req.id), TP.IsStaff(src))
        return ok, msg, ok and Lang.logCancelled, c.cancelled
    elseif op == 'licence' then
        local ok, msg = Storage.BuyLicence(src, charid, market)
        return ok, msg, ok and Lang.logLicence, c.licence
    elseif op == 'slots' then
        local ok, msg = Storage.BuySlots(src, charid, market, num(req.count))
        return ok, msg
    elseif op == 'storage' then
        local ok, msg = Storage.Open(src, charid, market)
        return ok, msg, nil, nil, ok and { close = true } or nil
    elseif op == 'withdraw' then
        local ok, msg = withdraw(src, charid)
        return ok, msg, ok and Lang.logLedger, c.ledger
    elseif op == 'tobank' then
        local ok, msg = toBank(charid)
        return ok, msg, ok and Lang.logLedger, c.ledger
    elseif op == 'paywith' then
        return payWith(charid, req.value)
    end
    return false, Lang.failed
end

Core.Callback.Register('pup_tradepost:request', function(source, cb, req)
    local src = source
    if type(req) ~= 'table' or type(req.op) ~= 'string' or not (READS[req.op] or WRITES[req.op]) then
        return cb(nil)
    end
    local _, _, charid = TP.Player(src)
    if not charid then return cb(nil) end
    if not ready then return cb(READS[req.op] and { busy = true } or { ok = false, msg = Lang.busy }) end
    if not TP.AllowRequest(src) then
        return cb(READS[req.op] and { busy = true } or { ok = false, msg = Lang.busy })
    end
    if type(req.market) ~= 'string' then req.market = nil end
    TP.Debug('request', src, charid, req.op, req.market)

    if READS[req.op] then
        local ok, data = pcall(doRead, src, charid, req)
        if not ok then
            print(('[pup_tradepost] %s failed for %d: %s'):format(req.op, src, tostring(data)))
            return cb({ busy = true })
        end
        return cb(data or {})
    end

    -- money and goods: the counter for the named market must be in reach
    if not req.market or not TP.MarketByKey[req.market] or not TP.NearMarket(src, req.market) then
        return cb({ ok = false, msg = Lang.stepUp })
    end
    if not TP.BeginWrite(src, charid) then return cb({ ok = false, msg = Lang.busy }) end

    local ok, success, msg, title, colour, extra = pcall(doWrite, src, charid, req)
    TP.EndWrite(charid)
    if not ok then
        print(('[pup_tradepost] %s failed for %d: %s'):format(req.op, src, tostring(success)))
        return cb({ ok = false, msg = Lang.failed })
    end
    if success and title and msg then TP.Log(src, title, colour, msg) end
    local reply = { ok = success == true, msg = msg }
    if type(extra) == 'table' then
        for k, v in pairs(extra) do reply[k] = v end
    end
    return cb(reply)
end)

---------------------------------------------------------------------------
-- staff exports (argument order and return shapes are fixed)
---------------------------------------------------------------------------
exports('AdminListOrders', function(query, side)
    if type(query) ~= 'string' then query = nil end
    if side ~= 'buy' and side ~= 'sell' then side = nil end
    local ok, rows = pcall(Reads.AdminList, query, side)
    if not ok then
        print('[pup_tradepost] AdminListOrders failed: ' .. tostring(rows))
        return {}
    end
    return rows
end)

exports('AdminCancelOrder', function(adminSrc, orderId)
    local ok, done, msg = pcall(Orders.AdminCancel, adminSrc, orderId)
    if not ok then
        print('[pup_tradepost] AdminCancelOrder failed: ' .. tostring(done))
        return false, Lang.failed
    end
    return done == true, msg
end)
