-- Schema: every statement is idempotent, so start-up can always run it.
DB = {}

local TABLES <const> = {
    [[CREATE TABLE IF NOT EXISTS `crafting_recipes` (
        `id` int(11) NOT NULL,
        `name` varchar(128) NULL DEFAULT NULL,
        `category` varchar(64) NULL DEFAULT NULL,
        `enabled` tinyint(4) NOT NULL DEFAULT 1,
        `data` longtext NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `crafting_locations` (
        `name` varchar(64) NOT NULL,
        `x` double NOT NULL,
        `y` double NOT NULL,
        `z` double NOT NULL,
        `enabled` tinyint(4) NOT NULL DEFAULT 1,
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `crafting_queue` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `charidentifier` int(11) NOT NULL,
        `label` varchar(96) NOT NULL DEFAULT '',
        `catagory` varchar(64) NOT NULL DEFAULT '',
        `count` int(11) NOT NULL DEFAULT 1,
        `rewards` longtext NOT NULL,
        `exp` int(11) NOT NULL DEFAULT 0,
        `metadata` longtext NULL DEFAULT NULL,
        `queued_at` int(11) NOT NULL DEFAULT 0,
        `ready_at` int(11) NOT NULL DEFAULT 0,
        `claimed` tinyint(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`charidentifier`, `claimed`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `crafting_lock_owner` (
        `identifier` varchar(50) NOT NULL,
        `charidentifier` int(11) NOT NULL,
        `steamname` varchar(50) NOT NULL DEFAULT '',
        `charname` varchar(100) NOT NULL DEFAULT '',
        `lastseen` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`identifier`, `charidentifier`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `workbench_favourites` (
        `charid` int(11) NOT NULL,
        `ids` longtext NOT NULL,
        PRIMARY KEY (`charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

local XP_DEFAULT <const> = '{"medical":0,"blacksmith":0,"basic":0,"survival":0,"brewing":0,"food":0}'

local function columnExists(tbl, col)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?',
        { tbl, col })
    return (tonumber(n) or 0) > 0
end

local function indexExists(tbl, idx)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?',
        { tbl, idx })
    return (tonumber(n) or 0) > 0
end

function DB.tableExists(tbl)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = ?', { tbl })
    return (tonumber(n) or 0) > 0
end

--- Create our tables and the characters.crafting column. Returns false on failure.
function DB.ensureSchema()
    local ok, err = pcall(function()
        for _, sql in ipairs(TABLES) do MySQL.query.await(sql) end
        if DB.tableExists('characters') then
            if not columnExists('characters', 'crafting') then
                MySQL.query.await(("ALTER TABLE `characters` ADD COLUMN `crafting` longtext DEFAULT '%s'"):format(XP_DEFAULT))
            end
            if not indexExists('characters', 'crafting') then
                MySQL.query.await('ALTER TABLE `characters` ADD INDEX `crafting` (`crafting`(768))')
            end
        end
    end)
    if not ok then
        Warn('schema check failed: %s', tostring(err))
        return false
    end
    return true
end
