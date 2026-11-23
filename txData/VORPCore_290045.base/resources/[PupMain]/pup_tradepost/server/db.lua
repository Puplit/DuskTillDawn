-- Tables this resource owns, and the one-time import of the legacy market tables.

DB = {}

local SCHEMA = {
    [[CREATE TABLE IF NOT EXISTS `tradepost_licences` (
        `charid` INT NOT NULL,
        `market` VARCHAR(32) NOT NULL,
        `inv_id` INT NOT NULL,
        `slots` INT NOT NULL DEFAULT 100,
        `created_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`charid`, `market`),
        UNIQUE KEY `inv_id` (`inv_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `tradepost_orders` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `charid` INT NOT NULL,
        `market` VARCHAR(32) NOT NULL,
        `side` ENUM('buy','sell') NOT NULL,
        `item` VARCHAR(96) NOT NULL,
        `label` VARCHAR(128) NOT NULL DEFAULT '',
        `total` INT NOT NULL,
        `remaining` INT NOT NULL,
        `price_each` DECIMAL(12,2) NOT NULL,
        `created_at` INT NOT NULL,
        `expires_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `board` (`side`, `item`),
        KEY `owner` (`charid`),
        KEY `expiry` (`expires_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `tradepost_trades` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `item` VARCHAR(96) NOT NULL,
        `label` VARCHAR(128) NOT NULL DEFAULT '',
        `qty` INT NOT NULL,
        `price_each` DECIMAL(12,2) NOT NULL,
        `buyer` INT NOT NULL DEFAULT 0,
        `seller` INT NOT NULL DEFAULT 0,
        `market` VARCHAR(32) NOT NULL DEFAULT '',
        `traded_at` INT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `item_time` (`item`, `traded_at`),
        KEY `buyer` (`buyer`),
        KEY `seller` (`seller`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `tradepost_accounts` (
        `charid` INT NOT NULL,
        `balance` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `lifetime` DECIMAL(12,2) NOT NULL DEFAULT 0,
        `pay_with` VARCHAR(8) NOT NULL DEFAULT 'cash',
        `bank` VARCHAR(64) NULL DEFAULT NULL,
        PRIMARY KEY (`charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function DB.EnsureSchema()
    for _, sql in ipairs(SCHEMA) do
        MySQL.query.await(sql)
    end
end

-- affected-row count from an oxmysql update/insert result
function DB.Affected(result)
    if type(result) == 'number' then return result end
    if type(result) == 'table' then
        return tonumber(result.affectedRows) or 0
    end
    return 0
end

local function tableExists(name)
    local rows = MySQL.query.await(
        'SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?',
        { name })
    return rows and rows[1] and tonumber(rows[1].n) and tonumber(rows[1].n) > 0
end

---------------------------------------------------------------------------
-- legacy import. Guarded by the KVP below; the old tables are only read.
---------------------------------------------------------------------------
local MIGRATED_KEY <const> = 'pup_tradepost:migrated'

local function migrateMarket(now, counts)
    local rows = MySQL.query.await('SELECT `charidentifier`, `location`, `invid`, `invslots`, `listing` FROM `market`') or {}
    local lifetime = Config.Orders.buy.lifetimeDays * 86400
    for _, row in ipairs(rows) do
        local charid = tonumber(row.charidentifier)
        local market = row.location
        local invid = tonumber(row.invid)
        if charid and TP.MarketByKey[market] and invid and TP.IsWhole(invid) then
            local slots = math.max(1, math.floor(tonumber(row.invslots) or Config.Licence.startSlots))
            local res = MySQL.update.await(
                'INSERT IGNORE INTO tradepost_licences (charid, market, inv_id, slots, created_at) VALUES (?, ?, ?, ?, ?)',
                { charid, market, invid, slots, now })
            counts.licences = counts.licences + DB.Affected(res)

            local okJson, listing = pcall(json.decode, row.listing or '[]')
            if okJson and type(listing) == 'table' then
                for _, entry in ipairs(listing) do
                    local item = type(entry) == 'table' and type(entry.item) == 'table' and entry.item or nil
                    local name = item and item.item
                    local amount = tonumber(entry.amount)
                    local price = tonumber(entry.price)
                    if type(name) == 'string' and name ~= '' and amount and amount > 0 and price and price > 0 then
                        amount = math.floor(amount)
                        if amount > 0 then
                            local eachCents = TP.ToCents(price / amount)
                            local label = type(item.label) == 'string' and item.label or name
                            MySQL.insert.await(
                                'INSERT INTO tradepost_orders (charid, market, side, item, label, total, remaining, price_each, created_at, expires_at) VALUES (?, ?, \'buy\', ?, ?, ?, ?, ?, ?, ?)',
                                { charid, market, name, label:sub(1, 128), amount, amount, TP.FromCents(eachCents), now, now + lifetime })
                            counts.orders = counts.orders + 1
                        end
                    end
                end
            end
        end
    end
end

local function migrateLedger(counts)
    local rows = MySQL.query.await('SELECT `charidentifier`, `balance`, `lifetime`, `bank` FROM `market_ledger`') or {}
    for _, row in ipairs(rows) do
        local charid = tonumber(row.charidentifier)
        if charid then
            local bank = (type(row.bank) == 'string' and row.bank ~= '') and row.bank or nil
            local res = MySQL.update.await(
                'INSERT IGNORE INTO tradepost_accounts (charid, balance, lifetime, pay_with, bank) VALUES (?, ?, ?, ?, ?)',
                { charid, TP.FromCents(TP.ToCents(row.balance) or 0), TP.FromCents(TP.ToCents(row.lifetime) or 0),
                  bank and 'bank' or 'cash', bank })
            counts.accounts = counts.accounts + DB.Affected(res)
        end
    end
end

local function migrateTrades(counts)
    local rows = MySQL.query.await(
        'SELECT `item`, `amount`, `per_item`, UNIX_TIMESTAMP(`traded_at`) AS ts FROM `market_trades`') or {}
    local batch, params = {}, {}
    local function flush()
        if #batch == 0 then return end
        MySQL.insert.await(
            'INSERT INTO tradepost_trades (item, label, qty, price_each, buyer, seller, market, traded_at) VALUES '
            .. table.concat(batch, ','), params)
        counts.trades = counts.trades + #batch
        batch, params = {}, {}
    end
    for _, row in ipairs(rows) do
        local item = row.item
        local qty = math.floor(tonumber(row.amount) or 0)
        local each = TP.ToCents(row.per_item)
        local ts = math.floor(tonumber(row.ts) or 0)
        if type(item) == 'string' and item ~= '' and qty > 0 and each then
            batch[#batch + 1] = '(?, ?, ?, ?, 0, 0, \'\', ?)'
            local p = params
            p[#p + 1] = item; p[#p + 1] = item:sub(1, 128); p[#p + 1] = qty
            p[#p + 1] = TP.FromCents(each); p[#p + 1] = ts
            if #batch >= 200 then flush() end
        end
    end
    flush()
end

function DB.MigrateOnce()
    if GetResourceKvpInt(MIGRATED_KEY) == 1 then return end

    local counts = { licences = 0, orders = 0, accounts = 0, trades = 0 }
    local now = os.time()
    local hasMarket = tableExists('market')
    local hasLedger = tableExists('market_ledger')
    local hasTrades = tableExists('market_trades')

    -- once anything is written the flag must be set, or a second run would duplicate it
    local ok, err = pcall(function()
        if hasMarket then migrateMarket(now, counts) end
        if hasLedger then migrateLedger(counts) end
        if hasTrades then migrateTrades(counts) end
    end)
    SetResourceKvpInt(MIGRATED_KEY, 1)

    if not ok then
        print('[pup_tradepost] ^1migration stopped part way^7: ' .. tostring(err))
    end
    print(('[pup_tradepost] 1.x import: %d licences, %d buy orders, %d ledger accounts, %d trades')
        :format(counts.licences, counts.orders, counts.accounts, counts.trades))
end
