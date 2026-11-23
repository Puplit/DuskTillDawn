-- pup_ranchero install script. Safe to run more than once.
-- The stats, herd-history, cron and fresh-herd tables are also created by the resource at start-up.

CREATE TABLE IF NOT EXISTS `player_ranch` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) DEFAULT NULL,
    `charidentifier` int(11) DEFAULT NULL,
    `name` longtext DEFAULT NULL,
    `price` float DEFAULT NULL,
    `coords` longtext DEFAULT '[]',
    `owned` int(11) DEFAULT 0,
    `herdtrail` longtext DEFAULT '[]',
    `cattle` longtext DEFAULT '[]',
    `q_cattle` longtext DEFAULT '[]',
    `dist` int(11) DEFAULT NULL,
    `chores` longtext DEFAULT '[]',
    `cows` longtext DEFAULT '[]',
    `chickens` longtext DEFAULT '[]',
    `milk` int(11) DEFAULT 0,
    `eggs` int(11) DEFAULT 0,
    `ledger` float DEFAULT 0,
    `dog` varchar(50) DEFAULT '0',
    `q_ranch` int(11) DEFAULT 0,
    `repoed` int(11) DEFAULT 0,
    `herding` int(11) DEFAULT 0,
    `selling` int(11) DEFAULT 0,
    `milking` int(11) DEFAULT 0,
    `checking` int(11) DEFAULT 0,
    `tax` int(11) DEFAULT 0,
    `hired` longtext DEFAULT '[]',
    `webhook` longtext DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ranch_activity` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `ranchid` int(11) NOT NULL,
    `ts` int(11) NOT NULL,
    `type` varchar(20) NOT NULL,
    `detail` varchar(191) NOT NULL DEFAULT '',
    `actor` varchar(100) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ranch_stats` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ranch_stats_meta` (
    `k` varchar(50) NOT NULL,
    `v` varchar(100) NOT NULL DEFAULT '',
    PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ranch_paycfg` (
    `ranchid` int NOT NULL,
    `milk_price` double NOT NULL DEFAULT 1.25,
    `egg_price` double NOT NULL DEFAULT 1.25,
    `reset_period` varchar(16) NOT NULL DEFAULT 'never',
    `last_reset` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`ranchid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `ranch_herds` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- shared with pup_camps, pup_mercantile and pup_realestate (identical definition)
CREATE TABLE IF NOT EXISTS `cron_state` (
    `name` varchar(64) NOT NULL,
    `lastrun` varchar(16) NOT NULL DEFAULT '',
    PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- herd types bought since their last herding trip (cannot be sold yet)
CREATE TABLE IF NOT EXISTS `ranch_fresh` (
    `ranchid` int NOT NULL,
    `animal` varchar(50) NOT NULL,
    PRIMARY KEY (`ranchid`, `animal`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- items
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `weight`, `degradation`, `metadata`, `desc`) VALUES
    ('beef',     'Beef',            20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A cut of beef from a ranch herd.'),
    ('bisons',   'Bison pelt',      20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A heavy, shaggy bison hide.'),
    ('chickenf', 'Chicken feather', 20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A soft feather from a hen.'),
    ('cows',     'Cow pelt',        20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A tanned-ready cow hide.'),
    ('deerskin', 'Deer pelt',       20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A supple deer hide.'),
    ('egg',      'Egg',             50, 1, 'item_standard', 1, 1.0, 0, '{}', 'A fresh brown egg.'),
    ('fibers',   'Fibers',          50, 1, 'item_standard', 0, 1.0, 0, '{}', 'Coarse goat-hair fibre.'),
    ('milk',     'Milk',            50, 1, 'item_standard', 1, 1.0, 0, '{}', 'A bottle of fresh milk.'),
    ('porkfat',  'Pig fat',         20, 1, 'item_standard', 1, 1.0, 0, '{}', 'Rendered pig fat.'),
    ('prongs',   'Pronghorn Skin',  20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A light pronghorn skin.'),
    ('rams',     'Ram Pelt',        20, 1, 'item_standard', 1, 1.0, 0, '{}', 'A thick bighorn ram pelt.'),
    ('venison',  'Venison',         20, 1, 'item_standard', 1, 1.0, 0, '{}', 'Lean game meat.'),
    ('wool',     'Wool',            50, 1, 'item_standard', 1, 1.0, 0, '{}', 'A bundle of sheep wool.');
