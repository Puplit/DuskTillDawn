-- Posting, filling, buying, cancelling and expiring orders.

Orders = {}

local locks = {} -- [orderId] = true while one request settles it (memory only)

function Orders.IsLocked(id) return locks[id] == true end

local ORDER_COLS <const> = 'id, charid, market, side, item, label, total, remaining, price_each, created_at, expires_at'

local function shape(row)
    return {
        id = math.floor(tonumber(row.id)),
        charid = math.floor(tonumber(row.charid)),
        market = row.market,
        side = row.side,
        item = row.item,
        label = (row.label ~= nil and row.label ~= '') and row.label or row.item,
        rawLabel = row.label or '',
        total = math.floor(tonumber(row.total) or 0),
        remaining = math.floor(tonumber(row.remaining) or 0),
        price = TP.ToCents(row.price_each) or 0,
        createdAt = math.floor(tonumber(row.created_at) or 0),
        expiresAt = math.floor(tonumber(row.expires_at) or 0),
    }
end

function Orders.Fetch(id)
    if not TP.IsWhole(id) or id < 1 then return nil end
    local rows = MySQL.query.await('SELECT ' .. ORDER_COLS .. ' FROM tradepost_orders WHERE id = ?', { id })
    if not rows or not rows[1] then return nil end
    return shape(rows[1])
end

function Orders.Shape(row) return shape(row) end
Orders.Columns = ORDER_COLS

-- open orders a character has on one side (expired rows no longer count)
local function openCount(charid, side, market)
    local sql = 'SELECT COUNT(*) AS n FROM tradepost_orders WHERE charid = ? AND side = ? AND expires_at > ?'
    local params = { charid, side, os.time() }
    if not Config.Orders.limitAcrossMarkets then
        sql = sql .. ' AND market = ?'
        params[#params + 1] = market
    end
    local rows = MySQL.query.await(sql, params)
    return rows and rows[1] and tonumber(rows[1].n) or 0
end

local function feeRate(tradeMarket, orderMarket)
    local rate = Config.Fees.sale
    if tradeMarket ~= orderMarket then rate = rate + Config.Fees.crossMarket end
    return math.max(Config.Fees.min, math.min(Config.Fees.max, rate))
end

local function recordTrade(order, qty, buyer, seller, market)
    MySQL.insert.await(
        'INSERT INTO tradepost_trades (item, label, qty, price_each, buyer, seller, market, traded_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { order.item, order.rawLabel ~= '' and order.rawLabel or order.item, qty, TP.FromCents(order.price), buyer, seller, market, os.time() })
end

-- reserve qty on an order in one conditional update
local function claim(order, qty)
    local res = MySQL.update.await(
        'UPDATE tradepost_orders SET remaining = remaining - ? WHERE id = ? AND remaining >= ? AND expires_at > ?',
        { qty, order.id, qty, os.time() })
    return DB.Affected(res) > 0
end

local function release(order, qty)
    MySQL.update.await('UPDATE tradepost_orders SET remaining = remaining + ? WHERE id = ?', { qty, order.id })
end

local function finish(order)
    MySQL.update.await('DELETE FROM tradepost_orders WHERE id = ? AND remaining <= 0', { order.id })
end

local function withLock(id, fn)
    if locks[id] then return false, Lang.notOpen end
    locks[id] = true
    local ok, a, b = pcall(fn)
    locks[id] = nil
    if not ok then error(a, 0) end
    return a, b
end

---------------------------------------------------------------------------
-- posting
---------------------------------------------------------------------------
function Orders.Post(src, charid, market, side, itemName, qty, price)
    if side ~= 'buy' and side ~= 'sell' then return false, Lang.notTradeable end
    local rules = Config.Orders[side]
    if side == 'sell' and not rules.enabled then return false, Lang.listingsOff end
    if not Storage.Licence(charid, market) then return false, Lang.needLicenceHere end
    if openCount(charid, side, market) >= rules.maxOpen then return false, Lang.tooMany end

    local entry = Items.Get(itemName)
    if not entry then return false, Lang.notTradeable end
    if not TP.IsWhole(qty) or qty < 1 or qty > rules.maxQty then return false, Lang.badAmount end

    local cents = TP.ToCents(price)
    local minC, maxC = TP.ToCents(rules.minPrice), TP.ToCents(rules.maxPrice)
    if not cents or cents < minC or cents > maxC then
        return false, Lang.badPrice:format(TP.Money(rules.minPrice), TP.Money(rules.maxPrice))
    end

    if not TP.SameChar(src, charid) then return false, Lang.notOpen end

    if side == 'buy' then
        local paid, why = Money.Charge(src, charid, qty * cents, 'trading post buy order')
        if not paid then return false, why end
    else
        if Items.PlainCount(src, entry.name) < qty then return false, Lang.notEnough end
        if not Items.TakePlain(src, entry.name, qty) then return false, Lang.notEnough end
    end

    local now = os.time()
    local okIns, id = pcall(function()
        return MySQL.insert.await(
            'INSERT INTO tradepost_orders (charid, market, side, item, label, total, remaining, price_each, created_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { charid, market, side, entry.name, entry.label:sub(1, 128), qty, qty, TP.FromCents(cents), now, now + rules.lifetimeDays * 86400 })
    end)
    if not okIns or not id then
        -- give back what was taken; a buy refund goes to the ledger
        if side == 'buy' then
            Money.Refund(charid, qty * cents)
        elseif not Items.Give(src, entry.name, qty) then
            print(('[pup_tradepost] ^1could not return %dx %s to character %d after a failed listing^7'):format(qty, entry.name, charid))
        end
        if not okIns then print('[pup_tradepost] order insert failed: ' .. tostring(id)) end
        return false, Lang.failed
    end
    return true, Lang.posted:format(qty, entry.label)
end

---------------------------------------------------------------------------
-- trading on an order
---------------------------------------------------------------------------
local function fillBuyOrder(src, charid, market, order, qty)
    if Items.PlainCount(src, order.item) < qty then return false, Lang.notEnough end
    if not Storage.Licence(order.charid, order.market) then return false, Lang.notOpen end
    if not claim(order, qty) then return false, Lang.notOpen end

    if not TP.SameChar(src, charid) then release(order, qty); return false, Lang.notOpen end
    if not Items.TakePlain(src, order.item, qty) then release(order, qty); return false, Lang.notEnough end

    -- an error here must still hand the goods back and release the claim
    local okDeliver, delivered = pcall(Storage.Deliver, order.charid, order.market, order.item, qty)
    if not okDeliver then print('[pup_tradepost] delivery error: ' .. tostring(delivered)) end
    if not (okDeliver and delivered) then
        if not Items.Give(src, order.item, qty) then
            print(('[pup_tradepost] ^1could not hand back %dx %s to character %d^7'):format(qty, order.item, charid))
        end
        release(order, qty)
        return false, Lang.theirFull
    end

    local gross = qty * order.price
    local fee = math.floor(gross * feeRate(market, order.market) + 0.5)
    local net = gross - fee
    Money.Payout(charid, net)
    recordTrade(order, qty, order.charid, charid, market)
    finish(order)

    local where = TP.MarketName(order.market)
    TP.ToastChar(order.charid, Lang.toastDelivered:format(qty, order.label, where))
    TP.Mail(order.charid, Lang.mailGotSubject, Lang.mailGotBody:format(qty, order.label, where))
    return true, Lang.sold:format(qty, order.label, TP.Money(TP.FromCents(net)))
end

local function buyFromListing(src, charid, market, order, qty)
    if not Items.CanCarry(src, order.item, qty) then return false, Lang.cantCarry end
    if not claim(order, qty) then return false, Lang.notOpen end

    local gross = qty * order.price
    local okCharge, paid, why = pcall(Money.Charge, src, charid, gross, 'trading post purchase')
    if not okCharge then paid, why = false, Lang.failed end
    if not paid then release(order, qty); return false, why end

    if not TP.SameChar(src, charid) or not Items.Give(src, order.item, qty) then
        Money.Refund(charid, gross)
        release(order, qty)
        return false, Lang.cantCarry
    end

    local fee = math.floor(gross * feeRate(market, order.market) + 0.5)
    local net = gross - fee
    Money.Payout(order.charid, net)
    recordTrade(order, qty, charid, order.charid, market)
    finish(order)

    local netTxt, feeTxt = TP.Money(TP.FromCents(net)), TP.Money(TP.FromCents(fee))
    TP.ToastChar(order.charid, Lang.toastSold:format(qty, order.label, netTxt))
    TP.Mail(order.charid, Lang.mailSoldSubject, Lang.mailSoldBody:format(qty, order.label, netTxt, feeTxt))
    return true, Lang.bought:format(qty, order.label, TP.Money(TP.FromCents(gross)))
end

-- The lock is taken before the row is read, so the row seen here is never a
-- snapshot from before another settlement on the same order finished.
function Orders.Trade(src, charid, market, id, qty)
    if not TP.IsWhole(id) or id < 1 then return false, Lang.notOpen end
    return withLock(id, function()
        local order = Orders.Fetch(id)
        if not order or order.remaining <= 0 or order.expiresAt <= os.time() then return false, Lang.notOpen end
        if order.charid == charid then return false, Lang.ownOrder end
        if not TP.IsWhole(qty) or qty < 1 or qty > order.remaining then return false, Lang.badAmount end
        if order.side == 'buy' then
            return fillBuyOrder(src, charid, market, order, qty)
        end
        return buyFromListing(src, charid, market, order, qty)
    end)
end

---------------------------------------------------------------------------
-- closing (cancel, expiry, staff)
---------------------------------------------------------------------------
local function reinsert(order)
    local ok, err = pcall(function()
        MySQL.insert.await(
            'INSERT INTO tradepost_orders (' .. ORDER_COLS .. ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            { order.id, order.charid, order.market, order.side, order.item, order.rawLabel, order.total,
              order.remaining, TP.FromCents(order.price), order.createdAt, order.expiresAt })
    end)
    if not ok then
        print(('[pup_tradepost] ^1listing #%d (%dx %s, character %d) could not be put back: %s^7')
            :format(order.id, order.remaining, order.item, order.charid, tostring(err)))
    end
end

-- Returns true, or false plus 'gone' | 'stuck'. The caller holds the lock.
-- A listing is deleted before its goods move and put back if they cannot be
-- delivered, so goods can never be both returned and still listed.
local function close(order)
    if order.side == 'buy' then
        local res = MySQL.update.await('DELETE FROM tradepost_orders WHERE id = ?', { order.id })
        if DB.Affected(res) < 1 then return false, 'gone' end
        Money.Refund(order.charid, order.remaining * order.price)
        return true
    end

    if not Storage.Licence(order.charid, order.market) then return false, 'stuck' end
    local res = MySQL.update.await('DELETE FROM tradepost_orders WHERE id = ?', { order.id })
    if DB.Affected(res) < 1 then return false, 'gone' end
    if order.remaining <= 0 then return true end
    local okDeliver, delivered = pcall(Storage.Deliver, order.charid, order.market, order.item, order.remaining)
    if not okDeliver then print('[pup_tradepost] delivery error: ' .. tostring(delivered)) end
    if okDeliver and delivered then return true end
    reinsert(order)
    return false, 'stuck'
end

local function closedLine(order)
    if order.side == 'buy' then
        return Lang.mailClosedMoney:format(TP.Money(TP.FromCents(order.remaining * order.price)))
    end
    return Lang.mailClosedGoods:format(order.remaining, TP.MarketName(order.market))
end

local function ageText(order)
    local age = math.max(0, os.time() - order.createdAt)
    if age < 86400 then return Lang.hoursMany:format(math.max(1, math.floor(age / 3600 + 0.5))) end
    local days = math.floor(age / 86400 + 0.5)
    if days <= 1 then return Lang.daysOne end
    return Lang.daysMany:format(days)
end

local function closeRefusal(reason, isOwner, order)
    if reason == 'stuck' then
        if isOwner then return Lang.yourFull:format(TP.MarketName(order.market)) end
        return Lang.theirFull
    end
    return Lang.notOpen
end

-- the panel's Cancel (owner, or staff)
function Orders.Cancel(src, charid, id, staff)
    if not TP.IsWhole(id) or id < 1 then return false, Lang.notOpen end
    return withLock(id, function()
        local order = Orders.Fetch(id)
        if not order then return false, Lang.notOpen end
        local isOwner = order.charid == charid
        if not isOwner and not staff then return false, Lang.notOpen end
        local ok, reason = close(order)
        if not ok then return false, closeRefusal(reason, isOwner, order) end
        if not isOwner then
            TP.ToastChar(order.charid, Lang.toastStaff:format(order.label))
            TP.Mail(order.charid, Lang.mailStaffSubject, Lang.mailStaffBody:format(order.label, closedLine(order)))
        end
        return true, Lang.cancelled
    end)
end

---------------------------------------------------------------------------
-- expiry sweep
---------------------------------------------------------------------------
local stuckUntil = {}   -- [orderId] = os.time() of the next retry
local stuckTold = {}    -- [orderId] = true once the owner heard about it

local function sweepOne(order)
    local ok, reason = close(order)
    if ok then
        stuckUntil[order.id], stuckTold[order.id] = nil, nil
        TP.ToastChar(order.charid, Lang.toastClosed)
        TP.Mail(order.charid, Lang.mailClosedSubject,
            Lang.mailClosedBody:format(order.label, ageText(order), closedLine(order)))
    elseif reason == 'stuck' then
        stuckUntil[order.id] = os.time() + Config.Sweep.stuckRetryMinutes * 60
        if not stuckTold[order.id] then
            stuckTold[order.id] = true
            local where = TP.MarketName(order.market)
            TP.ToastChar(order.charid, Lang.toastStuck:format(where))
            TP.Mail(order.charid, Lang.mailStuckSubject, Lang.mailStuckBody:format(order.remaining, order.label, where))
        end
    end
end

-- Walks every expired row by id, so listings that cannot be returned never
-- hide the ones behind them. At most Config.Sweep.batch close attempts per pass.
function Orders.Sweep()
    local now = os.time()
    local cursor, attempts, pages = 0, 0, 0
    while attempts < Config.Sweep.batch and pages < 50 do
        pages = pages + 1
        local rows = MySQL.query.await(
            'SELECT ' .. ORDER_COLS .. ' FROM tradepost_orders WHERE expires_at <= ? AND id > ? ORDER BY id ASC LIMIT 100',
            { now, cursor }) or {}
        for _, row in ipairs(rows) do
            local order = shape(row)
            cursor = order.id
            local waitUntil = stuckUntil[order.id]
            if not locks[order.id] and not (waitUntil and waitUntil > now) then
                attempts = attempts + 1
                locks[order.id] = true
                -- re-read under the lock: the page above may predate a trade that
                -- settled while earlier rows were being closed
                local ok, err = pcall(function()
                    local fresh = Orders.Fetch(order.id)
                    if fresh and fresh.expiresAt <= os.time() then sweepOne(fresh) end
                end)
                locks[order.id] = nil
                if not ok then print(('[pup_tradepost] sweep of order #%d failed: %s'):format(order.id, tostring(err))) end
                if attempts >= Config.Sweep.batch then break end
            end
        end
        if #rows < 100 then break end
    end
end

---------------------------------------------------------------------------
-- staff exports
---------------------------------------------------------------------------
function Orders.AdminCancel(adminSrc, id)
    adminSrc = tonumber(adminSrc)
    local _, _, charid = TP.Player(adminSrc)
    if not charid or not TP.IsStaff(adminSrc) then return false, Lang.notStaff end
    id = tonumber(id)
    if not TP.IsWhole(id) or id < 1 then return false, Lang.notOpen end
    local order
    local ok, msg = withLock(id, function()
        order = Orders.Fetch(id)
        if not order then return false, Lang.notOpen end
        local done, reason = close(order)
        if not done then return false, closeRefusal(reason, order.charid == charid, order) end
        return true, Lang.cancelled
    end)
    if ok then
        if order.charid ~= charid then
            TP.ToastChar(order.charid, Lang.toastStaff:format(order.label))
            TP.Mail(order.charid, Lang.mailStaffSubject, Lang.mailStaffBody:format(order.label, closedLine(order)))
        end
        TP.Log(adminSrc, Lang.logCancelled, Config.Discord.colours.cancelled,
            msg .. '\n' .. Lang.logStaffNote:format(order.id, order.charid))
    end
    return ok, msg
end
