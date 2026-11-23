-- pup-stable | tables, columns and triggers: created when missing, upgraded in place

local function q(sql, p) return MySQL.query.await(sql, p or {}) end

local function columns(name)
    local out = {}
    local r = q('SELECT column_name AS c, data_type AS t FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ?', { name })
    for _, row in ipairs(r or {}) do out[row.c] = row.t end
    return out
end

local function addColumn(tbl, col, def, after)
    local cols = columns(tbl)
    if cols[col] then return false end
    q(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(tbl, col, def))
    if after then after() end
    return true
end

local CREATE = {
    stable_horses = [[CREATE TABLE IF NOT EXISTS `stable_horses` (
        `id` int NOT NULL AUTO_INCREMENT,
        `identifier` varchar(50) NOT NULL,
        `charid` int NOT NULL,
        `stable` varchar(50) NOT NULL,
        `model` varchar(100) NOT NULL,
        `isFemale` tinyint(1) NOT NULL DEFAULT 0,
        `name` varchar(50) NOT NULL,
        `speed` tinyint NOT NULL,
        `acceleration` tinyint NOT NULL,
        `handling` tinyint NOT NULL,
        `favourite` tinyint(1) NOT NULL DEFAULT 0,
        `isDead` tinyint(1) NOT NULL DEFAULT 0,
        `isOut` tinyint(1) NOT NULL DEFAULT 0,
        `baseSpeed` tinyint NULL DEFAULT NULL,
        `baseAcceleration` tinyint NULL DEFAULT NULL,
        `baseHandling` tinyint NULL DEFAULT NULL,
        `scale` float NOT NULL DEFAULT 1,
        `bred` tinyint(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`identifier`, `charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
    stable_horse_stats = [[CREATE TABLE IF NOT EXISTS `stable_horse_stats` (
        `horseid` int NOT NULL,
        `distance` int NOT NULL DEFAULT 0,
        `lastNewShoes` int NOT NULL DEFAULT 0,
        `bonding` int NOT NULL DEFAULT 0,
        `stamina` int NOT NULL DEFAULT 0,
        `health` int NOT NULL DEFAULT 0,
        `xp` int NOT NULL DEFAULT 0,
        `speedXP` int NOT NULL DEFAULT 0,
        `accelerationXP` int NOT NULL DEFAULT 0,
        `handlingXP` int NOT NULL DEFAULT 0,
        `focus` varchar(20) NULL DEFAULT NULL,
        `healthCore` int NOT NULL DEFAULT 100,
        `staminaCore` int NOT NULL DEFAULT 100,
        `pedStamina` int NOT NULL DEFAULT 0,
        `restedAt` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`horseid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
    stable_bought = [[CREATE TABLE IF NOT EXISTS `stable_bought` (
        `id` int NOT NULL AUTO_INCREMENT,
        `identifier` varchar(50) NOT NULL,
        `charid` int NOT NULL,
        `category` varchar(50) NOT NULL,
        `hash` bigint NOT NULL,
        `equiped_on` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`identifier`, `charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
    stable_color = [[CREATE TABLE IF NOT EXISTS `stable_color` (
        `id` int NOT NULL,
        `drawable` int NULL DEFAULT NULL,
        `albedo` int NULL DEFAULT NULL,
        `normal` int NULL DEFAULT NULL,
        `material` int NULL DEFAULT NULL,
        `palette` varchar(100) NULL DEFAULT NULL,
        `tint0` tinyint unsigned NULL DEFAULT NULL,
        `tint1` tinyint unsigned NULL DEFAULT NULL,
        `tint2` tinyint unsigned NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        CONSTRAINT `pup_stable_color_fk` FOREIGN KEY (`id`) REFERENCES `stable_bought` (`id`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
    stable_wagons = [[CREATE TABLE IF NOT EXISTS `stable_wagons` (
        `id` int NOT NULL AUTO_INCREMENT,
        `identifier` varchar(50) NOT NULL,
        `charid` int NOT NULL,
        `stable` varchar(50) NOT NULL,
        `model` varchar(100) NOT NULL,
        `name` varchar(100) DEFAULT '',
        `vehicle_tints` int NOT NULL DEFAULT -2,
        `vehicle_propsets` varchar(50) NOT NULL DEFAULT '-1',
        `vehicle_liveries` int NOT NULL DEFAULT -1,
        `vehicle_lantern_propsets` varchar(50) NOT NULL DEFAULT '-1',
        `vehicle_extras` int NOT NULL DEFAULT -1,
        `isOut` tinyint(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
    stable_bred = [[CREATE TABLE IF NOT EXISTS `stable_bred` (
        `id` int NOT NULL AUTO_INCREMENT,
        `stableid` varchar(50) NOT NULL,
        `job` varchar(50) NOT NULL DEFAULT '',
        `horseid` int NOT NULL,
        `variation` int NOT NULL DEFAULT 1,
        `model` varchar(100) NOT NULL,
        `name` varchar(100) NOT NULL,
        `price` int NOT NULL,
        `palette` varchar(64) NULL DEFAULT NULL,
        `tint0` smallint NOT NULL DEFAULT 0,
        `tint1` smallint NOT NULL DEFAULT 0,
        `tint2` smallint NOT NULL DEFAULT 0,
        `scale` float NOT NULL DEFAULT 1,
        `stock` int NOT NULL DEFAULT 0,
        `sold` int NOT NULL DEFAULT 0,
        `bredby` varchar(50) NULL DEFAULT NULL,
        `bredat` int NOT NULL DEFAULT 0,
        `active` tinyint(1) NOT NULL DEFAULT 1,
        `hairpalette` varchar(64) NULL DEFAULT NULL,
        `htint0` smallint NOT NULL DEFAULT 0,
        `htint1` smallint NOT NULL DEFAULT 0,
        `htint2` smallint NOT NULL DEFAULT 0,
        `sirebreed` varchar(100) NULL DEFAULT NULL,
        `dambreed` varchar(100) NULL DEFAULT NULL,
        `speed` smallint NULL DEFAULT NULL,
        `acceleration` smallint NULL DEFAULT NULL,
        `handling` smallint NULL DEFAULT NULL,
        `health` smallint NULL DEFAULT NULL,
        `stamina` smallint NULL DEFAULT NULL,
        `readyat` int NOT NULL DEFAULT 0,
        `siremodel` varchar(100) NULL DEFAULT NULL,
        `dammodel` varchar(100) NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `stableid` (`stableid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    stable_starter = [[CREATE TABLE IF NOT EXISTS `stable_starter` (
        `charid` int NOT NULL,
        `identifier` varchar(50) NOT NULL,
        `horseid` int NOT NULL DEFAULT 0,
        `grantedat` int NOT NULL DEFAULT 0,
        PRIMARY KEY (`charid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8]],
}

local function triggers()
    -- stats row follows the horse row; deleting a horse sends its tack back to storage
    -- the triggers from before the table rename (2026-11-19) still name the old tables, so they go first
    for _, old in ipairs({ 'add_' .. 'pup_horses_stats', 'delete_' .. 'pup_horses_stats', 'update_' .. 'pup_stable_equiped_component' }) do
        q(('DROP TRIGGER IF EXISTS `%s`'):format(old))
    end
    q('DROP TRIGGER IF EXISTS `add_stable_horse_stats`')
    q([[CREATE TRIGGER `add_stable_horse_stats` AFTER INSERT ON `stable_horses` FOR EACH ROW
        INSERT IGNORE INTO `stable_horse_stats` (`horseid`) VALUES (NEW.`id`)]])
    q('DROP TRIGGER IF EXISTS `delete_stable_horse_stats`')
    q([[CREATE TRIGGER `delete_stable_horse_stats` AFTER DELETE ON `stable_horses` FOR EACH ROW
        DELETE FROM `stable_horse_stats` WHERE `horseid` = OLD.`id`]])
    q('DROP TRIGGER IF EXISTS `update_stable_equiped_component`')
    q([[CREATE TRIGGER `update_stable_equiped_component` BEFORE DELETE ON `stable_horses` FOR EACH ROW
        UPDATE `stable_bought` SET `equiped_on` = 0 WHERE `equiped_on` = OLD.`id`]])
end

function CreateSchema()
    -- order matters: the colour table refers to the bought table
    for _, name in ipairs({ 'stable_horses', 'stable_horse_stats', 'stable_bought', 'stable_color', 'stable_wagons', 'stable_bred', 'stable_starter' }) do
        q(CREATE[name])
    end

    -- upgrades
    addColumn('stable_wagons', 'name', "varchar(100) DEFAULT ''")
    local bought = columns('stable_bought')
    if bought.hash and bought.hash ~= 'bigint' then q('ALTER TABLE `stable_bought` MODIFY `hash` bigint NOT NULL') end
    local color = columns('stable_color')
    if color.tint1 and color.tint3 and not color.tint0 then
        q('ALTER TABLE `stable_color` CHANGE `tint1` `tint0` tinyint unsigned NULL DEFAULT NULL')
        q('ALTER TABLE `stable_color` CHANGE `tint2` `tint1` tinyint unsigned NULL DEFAULT NULL')
        q('ALTER TABLE `stable_color` CHANGE `tint3` `tint2` tinyint unsigned NULL DEFAULT NULL')
    end

    addColumn('stable_horse_stats', 'health', 'int NOT NULL DEFAULT 0', function() q('UPDATE `stable_horse_stats` SET `health` = `bonding`') end)
    addColumn('stable_horse_stats', 'stamina', 'int NOT NULL DEFAULT 0', function() q('UPDATE `stable_horse_stats` SET `stamina` = `bonding`') end)
    addColumn('stable_horses', 'baseSpeed', 'tinyint NULL DEFAULT NULL', function() q('UPDATE `stable_horses` SET `baseSpeed` = `speed`') end)
    addColumn('stable_horses', 'baseAcceleration', 'tinyint NULL DEFAULT NULL', function() q('UPDATE `stable_horses` SET `baseAcceleration` = `acceleration`') end)
    addColumn('stable_horses', 'baseHandling', 'tinyint NULL DEFAULT NULL', function() q('UPDATE `stable_horses` SET `baseHandling` = `handling`') end)

    local st = columns('stable_horse_stats')
    if not st.xp then
        for _, c in ipairs({ 'xp', 'speedXP', 'accelerationXP', 'handlingXP' }) do addColumn('stable_horse_stats', c, 'int NOT NULL DEFAULT 0') end
        addColumn('stable_horse_stats', 'focus', 'varchar(20) NULL DEFAULT NULL')
        -- old per-stat training-session counters, if this install had them
        if st.speedTraining and st.accelerationTraining and st.handlingTraining then
            q([[UPDATE `stable_horse_stats` SET `speedXP` = `speedTraining` * 170, `accelerationXP` = `accelerationTraining` * 170,
                `handlingXP` = `handlingTraining` * 200,
                `xp` = (`speedTraining` + `accelerationTraining`) * 170 + `handlingTraining` * 200 + `bonding`]])
        else
            q('UPDATE `stable_horse_stats` SET `xp` = `bonding`')
        end
    end
    addColumn('stable_horse_stats', 'focus', 'varchar(20) NULL DEFAULT NULL')
    addColumn('stable_horse_stats', 'healthCore', 'int NOT NULL DEFAULT 100')
    addColumn('stable_horse_stats', 'staminaCore', 'int NOT NULL DEFAULT 100')
    addColumn('stable_horse_stats', 'pedStamina', 'int NOT NULL DEFAULT 0')
    addColumn('stable_horse_stats', 'restedAt', 'int NOT NULL DEFAULT 0')
    addColumn('stable_horses', 'scale', 'float NOT NULL DEFAULT 1')
    addColumn('stable_horses', 'bred', 'tinyint(1) NOT NULL DEFAULT 0')
    for col, def in pairs({
        job = "varchar(50) NOT NULL DEFAULT ''", hairpalette = 'varchar(64) NULL DEFAULT NULL', htint0 = 'smallint NOT NULL DEFAULT 0',
        htint1 = 'smallint NOT NULL DEFAULT 0', htint2 = 'smallint NOT NULL DEFAULT 0', sirebreed = 'varchar(100) NULL DEFAULT NULL',
        dambreed = 'varchar(100) NULL DEFAULT NULL', speed = 'smallint NULL DEFAULT NULL', acceleration = 'smallint NULL DEFAULT NULL',
        handling = 'smallint NULL DEFAULT NULL', health = 'smallint NULL DEFAULT NULL', stamina = 'smallint NULL DEFAULT NULL',
        readyat = 'int NOT NULL DEFAULT 0', siremodel = 'varchar(100) NULL DEFAULT NULL', dammodel = 'varchar(100) NULL DEFAULT NULL',
    }) do
        addColumn('stable_bred', col, def)
    end

    triggers()
    -- stats rows for horses created before the trigger existed
    q('INSERT IGNORE INTO `stable_horse_stats` (`horseid`) SELECT `id` FROM `stable_horses`')
end
