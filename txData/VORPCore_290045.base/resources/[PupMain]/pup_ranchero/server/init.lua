-- pup_ranchero | start-up (tables, flags, loading) and player lifecycle

local STARTUP_TABLES = {
    [[CREATE TABLE IF NOT EXISTS `ranch_stats` (
        `charid` int NOT NULL,
        `ranchid` int NOT NULL,
        `name` varchar(100) NOT NULL DEFAULT '',
        `milk` int NOT NULL DEFAULT 0,
        `eggs` int NOT NULL DEFAULT 0,
        `chores` int NOT NULL DEFAULT 0,
        `chore_score` int NOT NULL DEFAULT 0,
        `herds` int NOT NULL DEFAULT 0,
        `herd_animals` int NOT NULL DEFAULT 0,
        `herd_quality` double NOT NULL DEFAULT 0,
        `cattle_money` double NOT NULL DEFAULT 0,
        `discord` varchar(32) NOT NULL DEFAULT '',
        `p_milk` int NOT NULL DEFAULT 0,
        `p_eggs` int NOT NULL DEFAULT 0,
        `p_chores` int NOT NULL DEFAULT 0,
        `p_herds` int NOT NULL DEFAULT 0,
        `p_herd_animals` int NOT NULL DEFAULT 0,
        `p_herd_quality` double NOT NULL DEFAULT 0,
        `p_cattle_money` double NOT NULL DEFAULT 0,
        `first_ts` int NOT NULL DEFAULT 0,
        `last_ts` int NOT NULL DEFAULT 0,
        `herd_lost` int NOT NULL DEFAULT 0,
        `p_herd_lost` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`charid`, `ranchid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `ranch_stats_meta` (
        `k` varchar(50) NOT NULL,
        `v` varchar(100) NOT NULL DEFAULT '',
        PRIMARY KEY (`k`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `ranch_paycfg` (
        `ranchid` int NOT NULL,
        `milk_price` double NOT NULL DEFAULT 1.25,
        `egg_price` double NOT NULL DEFAULT 1.25,
        `reset_period` varchar(16) NOT NULL DEFAULT 'never',
        `last_reset` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`ranchid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `ranch_herds` (
        `id` int NOT NULL AUTO_INCREMENT,
        `ranchid` int NOT NULL,
        `charid` int NOT NULL,
        `name` varchar(100) NOT NULL DEFAULT '',
        `animal` varchar(50) NOT NULL DEFAULT '',
        `started` int NOT NULL DEFAULT 0,
        `survived` int NOT NULL DEFAULT 0,
        `quality` double NOT NULL DEFAULT 0,
        `ts` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `ranch_ts` (`ranchid`, `ts`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS `cron_state` (
        `name` varchar(64) NOT NULL,
        `lastrun` varchar(16) NOT NULL DEFAULT '',
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    -- herds bought since their last herding trip (not sellable yet)
    [[CREATE TABLE IF NOT EXISTS `ranch_fresh` (
        `ranchid` int NOT NULL,
        `animal` varchar(50) NOT NULL,
        PRIMARY KEY (`ranchid`, `animal`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

-- later-added stats columns, added when missing
local LATE_COLUMNS = {
    { 'herd_lost', 'int NOT NULL DEFAULT 0' },
    { 'p_herd_lost', 'int NOT NULL DEFAULT 0' },
    { 'cattle_money', 'double NOT NULL DEFAULT 0' },
    { 'discord', "varchar(32) NOT NULL DEFAULT ''" },
    { 'p_milk', 'int NOT NULL DEFAULT 0' },
    { 'p_eggs', 'int NOT NULL DEFAULT 0' },
    { 'p_chores', 'int NOT NULL DEFAULT 0' },
    { 'p_herds', 'int NOT NULL DEFAULT 0' },
    { 'p_herd_animals', 'int NOT NULL DEFAULT 0' },
    { 'p_herd_quality', 'double NOT NULL DEFAULT 0' },
    { 'p_cattle_money', 'double NOT NULL DEFAULT 0' },
}

local function prepareTables()
    for _, sql in ipairs(STARTUP_TABLES) do
        local ok, err = pcall(MySQL.query.await, sql)
        if not ok then print('^1[pup_ranchero]^7 table setup failed: ' .. tostring(err)) end
    end
    local ok, rows = pcall(MySQL.query.await,
        "SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'ranch_stats'")
    if ok and type(rows) == 'table' then
        local have = {}
        for _, row in ipairs(rows) do have[tostring(row.COLUMN_NAME or row.column_name)] = true end
        for _, c in ipairs(LATE_COLUMNS) do
            if not have[c[1]] then
                pcall(MySQL.query.await, ('ALTER TABLE `ranch_stats` ADD COLUMN `%s` %s'):format(c[1], c[2]))
            end
        end
    end
end

CreateThread(function()
    prepareTables()
    -- nobody stays locked out after a restart
    pcall(MySQL.update.await, 'UPDATE player_ranch SET herding = 0, selling = 0, milking = 0, checking = 0')

    local ok, rows = pcall(MySQL.query.await, 'SELECT * FROM player_ranch')
    if not ok or type(rows) ~= 'table' then
        print('^1[pup_ranchero]^7 could not load player_ranch - is sql/install.sql applied?')
        rows = {}
    end
    for _, row in ipairs(rows) do
        local r = RanchFromRow(row)
        if r.id > 0 then Ranches[r.id] = r end
    end

    local okF, fresh = pcall(MySQL.query.await, 'SELECT ranchid, animal FROM ranch_fresh')
    if okF and type(fresh) == 'table' then
        for _, row in ipairs(fresh) do
            local rid = tonumber(row.ranchid)
            if rid and Ranches[rid] then
                FreshHerds[rid] = FreshHerds[rid] or {}
                FreshHerds[rid][tostring(row.animal)] = true
            end
        end
    end

    RanchesReady = true
    local n = 0
    for _ in pairs(Ranches) do n = n + 1 end
    print(('[pup_ranchero] %d ranches loaded'):format(n))
    BroadcastList()
    for _, sid in ipairs(GetPlayers()) do SendInfo(tonumber(sid)) end
end)

------------------------------------------------------------------------------
-- player lifecycle
------------------------------------------------------------------------------
local function dropPlayerState(src, why)
    ReleaseLocksOf(src)
    EndDriveAbruptly(src, why)
    Vouchers[src] = nil
    DropProduceState(src)
end

AddEventHandler('playerDropped', function()
    local src = source
    dropPlayerState(src, 'drop')
    DropStamps(src)
end)

-- vorp_core fires this on the server when a character is chosen; a drive from the previous
-- character ends here instead of lingering
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    dropPlayerState(src, 'switch')
    SetTimeout(1500, function() if GetPlayerName(src) then SendInfo(src) end end)
end)
