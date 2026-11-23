-- pup_mercantile | tables, start-up loading and the item catalogue

local TABLES <const> = {
    playershops = {
        create = [[CREATE TABLE IF NOT EXISTS `playershops` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `identifier` varchar(50) NOT NULL DEFAULT '0',
            `charidentifier` int(11) NOT NULL DEFAULT 0,
            `items` longtext NOT NULL DEFAULT '[]',
            `weapons` longtext NOT NULL DEFAULT '[]',
            `price` float NOT NULL DEFAULT 0,
            `name` varchar(50) NOT NULL DEFAULT '',
            `slots` int(11) NOT NULL DEFAULT 0,
            `coords` longtext NOT NULL DEFAULT '[]',
            `owned` int(11) DEFAULT 0,
            `blip` int(11) DEFAULT 1,
            `ledger` double DEFAULT 0,
            `level` int(255) DEFAULT 0,
            `taxledger` double DEFAULT 0,
            `repo` int(11) DEFAULT 0,
            `buyitems` longtext DEFAULT '{}',
            `webhook` longtext DEFAULT '',
            `manager` int(11) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
        columns = {
            { 'identifier', "varchar(50) NOT NULL DEFAULT '0'" },
            { 'charidentifier', 'int(11) NOT NULL DEFAULT 0' },
            { 'items', "longtext NOT NULL DEFAULT '[]'" },
            { 'weapons', "longtext NOT NULL DEFAULT '[]'" },
            { 'price', 'float NOT NULL DEFAULT 0' },
            { 'name', "varchar(50) NOT NULL DEFAULT ''" },
            { 'slots', 'int(11) NOT NULL DEFAULT 0' },
            { 'coords', "longtext NOT NULL DEFAULT '[]'" },
            { 'owned', 'int(11) DEFAULT 0' },
            { 'blip', 'int(11) DEFAULT 1' },
            { 'ledger', 'double DEFAULT 0' },
            { 'level', 'int(255) DEFAULT 0' },
            { 'taxledger', 'double DEFAULT 0' },
            { 'repo', 'int(11) DEFAULT 0' },
            { 'buyitems', "longtext DEFAULT '{}'" },
            { 'webhook', "longtext DEFAULT ''" },
            { 'manager', 'int(11) NOT NULL DEFAULT 0' },
        },
    },
    society_shops = {
        create = [[CREATE TABLE IF NOT EXISTS `society_shops` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `society` varchar(50) NOT NULL DEFAULT '0',
            `items` longtext NOT NULL DEFAULT '[]',
            `weapons` longtext NOT NULL DEFAULT '[]',
            `slots` int(11) NOT NULL DEFAULT 50,
            `level` int(11) NOT NULL DEFAULT 0,
            `name` varchar(50) DEFAULT '',
            `coords` longtext DEFAULT '{}',
            `rank` int(11) DEFAULT 0,
            `blip` int(11) DEFAULT 0,
            `buyitems` longtext DEFAULT '{}',
            `webhook` longtext DEFAULT '{}',
            `enabled` tinyint(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
        columns = {
            { 'society', "varchar(50) NOT NULL DEFAULT '0'" },
            { 'items', "longtext NOT NULL DEFAULT '[]'" },
            { 'weapons', "longtext NOT NULL DEFAULT '[]'" },
            { 'slots', 'int(11) NOT NULL DEFAULT 50' },
            { 'level', 'int(11) NOT NULL DEFAULT 0' },
            { 'name', "varchar(50) DEFAULT ''" },
            { 'coords', "longtext DEFAULT '{}'" },
            { 'rank', 'int(11) DEFAULT 0' },
            { 'blip', 'int(11) DEFAULT 0' },
            { 'buyitems', "longtext DEFAULT '{}'" },
            { 'webhook', "longtext DEFAULT '{}'" },
            { 'enabled', 'tinyint(1) NOT NULL DEFAULT 1' },
        },
    },
    cron_state = {
        create = [[CREATE TABLE IF NOT EXISTS `cron_state` (
            `name` varchar(64) NOT NULL,
            `lastrun` varchar(16) NOT NULL DEFAULT '',
            PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
        columns = {
            { 'lastrun', "varchar(16) NOT NULL DEFAULT ''" },
        },
    },
}

local function existingColumns(tbl)
    local set = {}
    local rows = MySQL.query.await(
        'SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { tbl }) or {}
    for _, r in ipairs(rows) do set[r.c] = true end
    return set
end

local function ensureSchema()
    for name, def in pairs(TABLES) do
        MySQL.query.await(def.create)
        local have = existingColumns(name)
        for _, col in ipairs(def.columns) do
            if not have[col[1]] then
                -- names and types come from the table above, never from input
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(name, col[1], col[2]))
                print(('^3[pup_mercantile]^7 added column %s.%s'):format(name, col[1]))
            end
        end
    end
    local chars = existingColumns('characters')
    if next(chars) and not chars.discordid then
        MySQL.query.await("ALTER TABLE `characters` ADD COLUMN `discordid` varchar(255) DEFAULT '0'")
        print('^3[pup_mercantile]^7 added column characters.discordid')
    end
end

local function ensureTokens()
    local rows = {
        { Config.PlayerShops.token, 'Shop Creation License', 'Lets you open a shop of your own.' },
        { Config.SocietyShops.token, 'Society Shop Creation License', 'Lets the head of a business open a business shop.' },
    }
    for _, r in ipairs(rows) do
        local ok = pcall(MySQL.insert.await,
            'INSERT IGNORE INTO items (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`) VALUES (?, ?, 5, 1, ?, 1, ?)',
            { r[1], r[2], 'item_standard', r[3] })
        if not ok then
            pcall(MySQL.insert.await,
                'INSERT IGNORE INTO items (`item`, `label`, `limit`, `can_remove`, `type`, `usable`) VALUES (?, ?, 5, 1, ?, 1)',
                { r[1], r[2], 'item_standard' })
        end
    end
end

local function migrateV1()
    for _, v in ipairs(Config.V1SocietyShops or {}) do
        local pos = Util.validCoords(v.pos)
        local name = Util.cleanName(v.name)
        if type(v.job) == 'string' and pos and name then
            local exists = MySQL.scalar.await('SELECT id FROM society_shops WHERE society = ? AND name = ? LIMIT 1', { v.job, name })
            if not exists then
                MySQL.insert.await(
                    'INSERT INTO society_shops (society, items, weapons, slots, level, name, coords, `rank`, blip, buyitems, webhook, enabled) VALUES (?, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, 1)',
                    { v.job, '[]', '[]', Config.SocietyShops.startSlots, name, json.encode(pos),
                      math.floor(tonumber(v.rank) or 0), (tonumber(v.blip) or 1) == 1 and 1 or 0, '[]', '' })
                print(('^3[pup_mercantile]^7 migrated V1 society shop %s / %s'):format(v.job, name))
            end
        end
    end
end

local function loadShops()
    Shops.player, Shops.society = {}, {}
    for _, r in ipairs(MySQL.query.await('SELECT * FROM playershops') or {}) do
        local s = ShopFromRow('player', r)
        Shops.player[s.id] = s
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM society_shops') or {}) do
        local s = ShopFromRow('society', r)
        Shops.society[s.id] = s
    end
    LinkSharedStock()
end

function LoadCatalogue()
    local rows = MySQL.query.await('SELECT item, label, type FROM items') or {}
    local list, by = {}, {}
    for _, r in ipairs(rows) do
        if type(r.item) == 'string' then
            local e = { name = r.item, label = tostring(r.label or r.item), type = r.type }
            list[#list + 1] = e
            by[r.item] = e
        end
    end
    table.sort(list, function(a, b) return Util.naturalLess(a.label, b.label) end)
    Catalogue, CatalogueByName = list, by
end

-- what the Add Items tab shows: no weapons, no blacklisted items
function ClientCatalogue()
    local out = {}
    for _, e in ipairs(Catalogue) do
        if e.type ~= 'item_weapon' and not Util.blacklisted(e.name) then
            out[#out + 1] = { n = e.name, l = e.label }
        end
    end
    return out
end

CreateThread(function()
    Wait(1000)
    local ok, err = pcall(function()
        ensureSchema()
        ensureTokens()
        RefreshBossRanks()
        migrateV1()
        loadShops()
    end)
    if not ok then
        print('^1[pup_mercantile]^7 start-up failed: ' .. tostring(err))
        return
    end
    local okc, errc = pcall(LoadCatalogue)
    if not okc then print('^1[pup_mercantile]^7 item catalogue failed: ' .. tostring(errc)) end
    ShopsReady = true
    BroadcastAll()
    local np, ns = 0, 0
    for _ in pairs(Shops.player) do np = np + 1 end
    for _ in pairs(Shops.society) do ns = ns + 1 end
    print(('^2[pup_mercantile]^7 %d player shops and %d society shops loaded'):format(np, ns))
end)
