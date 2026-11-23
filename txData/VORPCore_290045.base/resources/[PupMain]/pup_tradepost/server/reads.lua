-- Read-only answers for the panel and the staff export.

Reads = {}

---------------------------------------------------------------------------
-- going rates (quantity-weighted average over the window, cached)
---------------------------------------------------------------------------
local rateCache, rateAt = {}, -1

function Reads.GoingRates()
    if not Config.GoingRate.enabled then return {} end
    local now = os.time()
    if rateAt >= 0 and now - rateAt < Config.GoingRate.cacheSeconds then return rateCache end
    local since = now - Config.GoingRate.windowDays * 86400
    local rows = MySQL.query.await(
        'SELECT item, SUM(qty) AS q, SUM(qty * price_each) AS v FROM tradepost_trades WHERE traded_at >= ?'
        .. (Config.GoingRate.includeImported and '' or ' AND (buyer <> 0 OR seller <> 0)')
        .. ' GROUP BY item HAVING COUNT(*) >= ?',
        { since, Config.GoingRate.minTrades }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local q, v = tonumber(r.q) or 0, tonumber(r.v) or 0
        if q > 0 then out[r.item] = TP.FromCents(TP.ToCents(v / q)) end
    end
    rateCache, rateAt = out, now
    return out
end

---------------------------------------------------------------------------
-- board
---------------------------------------------------------------------------

-- LIKE pattern for a literal substring ('!' is the escape character)
local function likeLiteral(text)
    return '%' .. text:gsub('[!%%_]', function(c) return '!' .. c end) .. '%'
end

local function cleanSearch(text)
    if type(text) ~= 'string' then return '' end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    return text:sub(1, 64):lower()
end

-- the open-orders query shared by the board and AdminListOrders
local function openOrders(search, side, sort)
    local sql = { 'SELECT ' .. Orders.Columns .. ' FROM tradepost_orders WHERE expires_at > ? AND remaining > 0' }
    local params = { os.time() }
    if side == 'buy' or side == 'sell' then
        sql[#sql + 1] = 'AND side = ?'
        params[#params + 1] = side
    end
    search = cleanSearch(search)
    if search ~= '' then
        local pat = likeLiteral(search)
        sql[#sql + 1] = "AND (LOWER(label) LIKE ? ESCAPE '!' OR LOWER(item) LIKE ? ESCAPE '!')"
        params[#params + 1] = pat
        params[#params + 1] = pat
    end
    if sort == 'low' then
        sql[#sql + 1] = 'ORDER BY price_each ASC, id DESC'
    elseif sort == 'high' then
        sql[#sql + 1] = 'ORDER BY price_each DESC, id DESC'
    else
        sql[#sql + 1] = 'ORDER BY created_at DESC, id DESC'
    end
    sql[#sql + 1] = 'LIMIT ' .. math.floor(Config.Limits.boardRows)
    return MySQL.query.await(table.concat(sql, ' '), params) or {}
end

function Reads.Board(src, charid, args)
    local side = (args.filter == 'buy' or args.filter == 'sell') and args.filter or nil
    local sort = (args.sort == 'low' or args.sort == 'high') and args.sort or 'new'
    local rows = openOrders(args.search, side, sort)
    local rates = Reads.GoingRates()
    local carried = Items.PlainCounts(src)
    local now = os.time()
    local out = {}
    for _, row in ipairs(rows) do
        local o = Orders.Shape(row)
        out[#out + 1] = {
            id = o.id, side = o.side, item = o.item, label = o.label,
            remaining = o.remaining, price = TP.FromCents(o.price),
            market = o.market, marketName = TP.MarketName(o.market),
            secondsLeft = math.max(0, o.expiresAt - now),
            rate = rates[o.item], mine = o.charid == charid,
            have = o.side == 'buy' and (carried[o.item] or 0) or nil,
        }
    end
    return { rows = out }
end

function Reads.AdminList(query, side)
    local rows = openOrders(query, side, 'new')
    local out = {}
    for _, row in ipairs(rows) do
        local o = Orders.Shape(row)
        out[#out + 1] = {
            id = o.id, charid = o.charid, market = o.market, side = o.side, item = o.item,
            label = o.rawLabel, remaining = o.remaining, price_each = TP.FromCents(o.price),
            expires_at = o.expiresAt,
        }
    end
    return out
end

---------------------------------------------------------------------------
-- my orders and recent trades
---------------------------------------------------------------------------
function Reads.Mine(charid)
    local rows = MySQL.query.await(
        'SELECT ' .. Orders.Columns .. ' FROM tradepost_orders WHERE charid = ? ORDER BY created_at DESC, id DESC', { charid }) or {}
    local now = os.time()
    local orders = {}
    for _, row in ipairs(rows) do
        local o = Orders.Shape(row)
        orders[#orders + 1] = {
            id = o.id, side = o.side, item = o.item, label = o.label, remaining = o.remaining,
            price = TP.FromCents(o.price), market = o.market, marketName = TP.MarketName(o.market),
            secondsLeft = math.max(0, o.expiresAt - now), expired = o.expiresAt <= now,
        }
    end

    local trades = MySQL.query.await(
        'SELECT item, label, qty, price_each, buyer, seller, market, traded_at FROM tradepost_trades WHERE buyer = ? OR seller = ? ORDER BY traded_at DESC, id DESC LIMIT ?',
        { charid, charid, Config.Limits.recentTrades }) or {}
    local recent = {}
    for _, t in ipairs(trades) do
        local ts = math.floor(tonumber(t.traded_at) or 0)
        recent[#recent + 1] = {
            when = ts,
            whenText = os.date('%d %b', ts),
            label = (t.label ~= nil and t.label ~= '') and t.label or t.item,
            bought = tonumber(t.buyer) == charid,
            qty = math.floor(tonumber(t.qty) or 0),
            price = TP.FromCents(TP.ToCents(t.price_each) or 0),
            marketName = TP.MarketName(t.market),
        }
    end
    return { orders = orders, trades = recent }
end

---------------------------------------------------------------------------
-- catalogue, carried goods, price check
---------------------------------------------------------------------------
function Reads.Catalogue(search)
    local rates = Reads.GoingRates()
    local out = {}
    for _, e in ipairs(Items.Search(cleanSearch(search))) do
        out[#out + 1] = { item = e.name, label = e.label, rate = rates[e.name] }
    end
    return { items = out }
end

function Reads.Carried(src)
    local rates = Reads.GoingRates()
    local out = {}
    for name, count in pairs(Items.PlainCounts(src)) do
        local e = Items.Get(name)
        if e and count > 0 then
            out[#out + 1] = { item = name, label = e.label, count = count, rate = rates[name], lower = e.lower }
        end
    end
    table.sort(out, function(a, b)
        if a.lower == b.lower then return a.item < b.item end
        return a.lower < b.lower
    end)
    for _, r in ipairs(out) do r.lower = nil end
    return { items = out }
end

function Reads.Price(itemName)
    local e = Items.Get(itemName)
    if not e then return nil end
    local now = os.time()
    local since = now - Config.GoingRate.windowDays * 86400
    local stats = MySQL.query.await(
        'SELECT MIN(price_each) AS lo, MAX(price_each) AS hi, SUM(qty) AS vol FROM tradepost_trades WHERE item = ? AND traded_at >= ?',
        { e.name, since }) or {}
    local best = MySQL.query.await(
        "SELECT MAX(CASE WHEN side = 'buy' THEN price_each END) AS bestbuy, MIN(CASE WHEN side = 'sell' THEN price_each END) AS cheapest FROM tradepost_orders WHERE item = ? AND expires_at > ? AND remaining > 0",
        { e.name, now }) or {}
    local s, b = stats[1] or {}, best[1] or {}
    local function money(v)
        local c = TP.ToCents(v)
        if not c or c <= 0 then return nil end
        return TP.FromCents(c)
    end
    return {
        item = e.name, label = e.label,
        rate = Reads.GoingRates()[e.name],
        low = money(s.lo), high = money(s.hi),
        volume = math.floor(tonumber(s.vol) or 0),
        bestBuy = money(b.bestbuy), cheapest = money(b.cheapest),
    }
end

---------------------------------------------------------------------------
-- account overview
---------------------------------------------------------------------------
function Reads.Overview(src, charid, market)
    local acct = Money.Account(charid)
    local held = MySQL.query.await(
        "SELECT COALESCE(SUM(remaining * price_each), 0) AS held FROM tradepost_orders WHERE charid = ? AND side = 'buy'",
        { charid }) or {}
    local lic = TP.MarketByKey[market] and Storage.Licence(charid, market) or nil
    local m = TP.MarketByKey[market]
    return {
        balance = TP.FromCents(acct.balance),
        lifetime = TP.FromCents(acct.lifetime),
        payWith = (acct.payWith == 'bank' and acct.bank) and 'bank' or 'cash',
        bank = acct.bank,
        held = TP.FromCents(TP.ToCents(held[1] and held[1].held) or 0),
        licence = lic and { invId = lic.invId, slots = lic.slots } or nil,
        banks = Money.BankNames(),
        marketBank = m and m.bank or nil,
        staff = TP.IsStaff(src),
        sellEnabled = Config.Orders.sell.enabled,
        prices = {
            licence = Config.Licence.price, slot = Config.Licence.slotPrice,
            startSlots = Config.Licence.startSlots, maxSlotsPerBuy = Config.Licence.maxSlotsPerBuy,
            buyMax = Config.Orders.buy.maxQty, sellMax = Config.Orders.sell.maxQty,
            buyMin = Config.Orders.buy.minPrice, buyTop = Config.Orders.buy.maxPrice,
            sellMin = Config.Orders.sell.minPrice, sellTop = Config.Orders.sell.maxPrice,
        },
    }
end
