-- pup_business | database schema: tables created and columns added when missing
-- Table and column names below are constants of this file, never player input.

local TABLES <const> = {
    { name = 'society_business', create = [[
        CREATE TABLE IF NOT EXISTS `society_business` (
            `job` varchar(50) NOT NULL,
            `name` varchar(100) NOT NULL DEFAULT '',
            `blipsprite` bigint NOT NULL DEFAULT 778811758,
            `showblip` tinyint(1) NOT NULL DEFAULT 1,
            `recruitmentrank` int NOT NULL DEFAULT 0,
            `bossrank` int NOT NULL DEFAULT 1,
            `containerid` int NOT NULL,
            `containername` varchar(100) NOT NULL DEFAULT 'Storage',
            `billing` tinyint(1) NOT NULL DEFAULT 1,
            `webhook` tinyint(1) NOT NULL DEFAULT 0,
            `salary` tinyint(1) NOT NULL DEFAULT 1,
            `positions` longtext NOT NULL,
            `jobmenu` longtext NOT NULL,
            `created_by` varchar(50) NULL DEFAULT NULL,
            `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
            `tax` tinyint(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`job`),
            UNIQUE KEY `containerid` (`containerid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'name', "`name` varchar(100) NOT NULL DEFAULT ''" },
        { 'blipsprite', '`blipsprite` bigint NOT NULL DEFAULT 778811758' },
        { 'showblip', '`showblip` tinyint(1) NOT NULL DEFAULT 1' },
        { 'recruitmentrank', '`recruitmentrank` int NOT NULL DEFAULT 0' },
        { 'bossrank', '`bossrank` int NOT NULL DEFAULT 1' },
        { 'containername', "`containername` varchar(100) NOT NULL DEFAULT 'Storage'" },
        { 'billing', '`billing` tinyint(1) NOT NULL DEFAULT 1' },
        { 'webhook', '`webhook` tinyint(1) NOT NULL DEFAULT 0' },
        { 'salary', '`salary` tinyint(1) NOT NULL DEFAULT 1' },
        { 'positions', '`positions` longtext NOT NULL' },
        { 'jobmenu', '`jobmenu` longtext NOT NULL' },
        { 'created_by', '`created_by` varchar(50) NULL DEFAULT NULL' },
        { 'created_at', '`created_at` timestamp NOT NULL DEFAULT current_timestamp()' },
        { 'tax', '`tax` tinyint(1) NOT NULL DEFAULT 0' },
      } },

    { name = 'society_ranks', create = [[
        CREATE TABLE IF NOT EXISTS `society_ranks` (
            `job` varchar(50) NOT NULL,
            `grade` int NOT NULL,
            `salary` int NOT NULL DEFAULT 0,
            `perms` longtext NOT NULL DEFAULT '{}',
            `tax` int NOT NULL DEFAULT 0,
            `taxperiod` varchar(10) NOT NULL DEFAULT 'weekly',
            `taxsince` int NOT NULL DEFAULT 0,
            PRIMARY KEY (`job`, `grade`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'salary', '`salary` int NOT NULL DEFAULT 0' },
        { 'perms', "`perms` longtext NOT NULL DEFAULT '{}'" },
        { 'tax', '`tax` int NOT NULL DEFAULT 0' },
        { 'taxperiod', "`taxperiod` varchar(10) NOT NULL DEFAULT 'weekly'" },
        { 'taxsince', '`taxsince` int NOT NULL DEFAULT 0' },
      } },

    { name = 'society_tax', create = [[
        CREATE TABLE IF NOT EXISTS `society_tax` (
            `charidentifier` int NOT NULL,
            `job` varchar(50) NOT NULL,
            `grade` int NOT NULL DEFAULT 0,
            `anchor` int NOT NULL DEFAULT 0,
            `paidperiods` int NOT NULL DEFAULT 0,
            `lastpaid` int NULL DEFAULT NULL,
            PRIMARY KEY (`charidentifier`, `job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'grade', '`grade` int NOT NULL DEFAULT 0' },
        { 'anchor', '`anchor` int NOT NULL DEFAULT 0' },
        { 'paidperiods', '`paidperiods` int NOT NULL DEFAULT 0' },
        { 'lastpaid', '`lastpaid` int NULL DEFAULT NULL' },
      } },

    { name = 'society_ledger', create = [[
        CREATE TABLE IF NOT EXISTS `society_ledger` (
            `job` longtext NULL DEFAULT NULL,
            `ledger` int NOT NULL DEFAULT 0,
            `webhook` longtext NULL DEFAULT NULL,
            `invaccess` int NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'ledger', '`ledger` int NOT NULL DEFAULT 0' },
        { 'webhook', '`webhook` longtext NULL DEFAULT NULL' },
        { 'invaccess', '`invaccess` int NOT NULL DEFAULT 0' },
      } },

    { name = 'society_activity', create = [[
        CREATE TABLE IF NOT EXISTS `society_activity` (
            `id` int NOT NULL AUTO_INCREMENT,
            `job` varchar(50) NOT NULL,
            `ts` int NOT NULL,
            `type` varchar(20) NOT NULL,
            `detail` varchar(255) NOT NULL DEFAULT '',
            `actor` varchar(100) NOT NULL DEFAULT '',
            PRIMARY KEY (`id`),
            KEY `job_ts` (`job`, `ts`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'detail', "`detail` varchar(255) NOT NULL DEFAULT ''" },
        { 'actor', "`actor` varchar(100) NOT NULL DEFAULT ''" },
      } },

    { name = 'bills', create = [[
        CREATE TABLE IF NOT EXISTS `bills` (
            `id` int NOT NULL AUTO_INCREMENT,
            `job` longtext NULL DEFAULT NULL,
            `playername` longtext NULL DEFAULT NULL,
            `identifier` varchar(50) NULL DEFAULT NULL,
            `charidentifier` int NULL DEFAULT NULL,
            `issuer` longtext NULL DEFAULT NULL,
            `amount` int NULL DEFAULT NULL,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {} },

    { name = 'society', create = [[
        CREATE TABLE IF NOT EXISTS `society` (
            `job` longtext NULL DEFAULT NULL,
            `jobgrade` int NULL DEFAULT NULL,
            `salary` int NOT NULL DEFAULT 0
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {} },

    -- shared with vorp_inventory stashes and pup_railroad; only invslots is ours
    { name = 'container', create = [[
        CREATE TABLE IF NOT EXISTS `container` (
            `id` int NOT NULL AUTO_INCREMENT,
            `name` longtext NULL DEFAULT NULL,
            `items` longtext NULL DEFAULT '{}',
            `invslots` int NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
      columns = {
        { 'invslots', '`invslots` int NOT NULL DEFAULT 0' },
      } },
}

local function existingColumns(tbl)
    local rows = MySQL.query.await(
        'SELECT COLUMN_NAME AS c FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?',
        { tbl }) or {}
    local have = {}
    for _, r in ipairs(rows) do have[tostring(r.c):lower()] = true end
    return have
end

local function indexExists(tbl, index)
    local n = MySQL.scalar.await(
        'SELECT COUNT(*) FROM information_schema.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?',
        { tbl, index })
    return (tonumber(n) or 0) > 0
end

-- the ledger unique key goes on only when no job has two rows
local function ensureLedgerKey()
    if indexExists('society_ledger', 'job_unique') then return end
    local dupes = MySQL.query.await(
        'SELECT job, COUNT(*) AS n FROM society_ledger GROUP BY job HAVING COUNT(*) > 1') or {}
    if #dupes > 0 then
        local names = {}
        for _, r in ipairs(dupes) do names[#names + 1] = ('%s (%d rows)'):format(tostring(r.job), tonumber(r.n) or 0) end
        print(('^3[%s]^7 society_ledger has duplicate rows for: %s - the job_unique key was not added. Merge them by hand.')
            :format(RES, table.concat(names, ', ')))
        return
    end
    local ok, err = pcall(MySQL.query.await, 'ALTER TABLE `society_ledger` ADD UNIQUE KEY `job_unique` (`job`(100))')
    if not ok then print(('^3[%s]^7 could not add society_ledger.job_unique: %s'):format(RES, tostring(err))) end
end

function EnsureSchema()
    for _, t in ipairs(TABLES) do
        local ok, err = pcall(MySQL.query.await, t.create)
        if not ok then print(('^1[%s]^7 creating %s failed: %s'):format(RES, t.name, tostring(err))) end
        if #t.columns > 0 then
            local have = existingColumns(t.name)
            for _, col in ipairs(t.columns) do
                if not have[col[1]] then
                    local ok2, err2 = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD COLUMN %s'):format(t.name, col[2]))
                    if ok2 then
                        print(('^2[%s]^7 added %s.%s'):format(RES, t.name, col[1]))
                    else
                        print(('^1[%s]^7 adding %s.%s failed: %s'):format(RES, t.name, col[1], tostring(err2)))
                    end
                end
            end
        end
    end
    if not indexExists('society_activity', 'job_ts') then
        pcall(MySQL.query.await, 'ALTER TABLE `society_activity` ADD INDEX `job_ts` (`job`, `ts`)')
    end
    ensureLedgerKey()
end
