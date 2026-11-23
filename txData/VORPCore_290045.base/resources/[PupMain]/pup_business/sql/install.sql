-- pup_business | install
-- The resource also creates these tables, and adds missing columns, when it starts.
-- This file adds no items (the resource uses none).

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `society_ranks` (
    `job` varchar(50) NOT NULL,
    `grade` int NOT NULL,
    `salary` int NOT NULL DEFAULT 0,
    `perms` longtext NOT NULL DEFAULT '{}',
    `tax` int NOT NULL DEFAULT 0,
    `taxperiod` varchar(10) NOT NULL DEFAULT 'weekly',
    `taxsince` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`job`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `society_tax` (
    `charidentifier` int NOT NULL,
    `job` varchar(50) NOT NULL,
    `grade` int NOT NULL DEFAULT 0,
    `anchor` int NOT NULL DEFAULT 0,
    `paidperiods` int NOT NULL DEFAULT 0,
    `lastpaid` int NULL DEFAULT NULL,
    PRIMARY KEY (`charidentifier`, `job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- the unique key job_unique is added by the resource at start, only when no job has two rows
CREATE TABLE IF NOT EXISTS `society_ledger` (
    `job` longtext NULL DEFAULT NULL,
    `ledger` int NOT NULL DEFAULT 0,
    `webhook` longtext NULL DEFAULT NULL,
    `invaccess` int NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `society_activity` (
    `id` int NOT NULL AUTO_INCREMENT,
    `job` varchar(50) NOT NULL,
    `ts` int NOT NULL,
    `type` varchar(20) NOT NULL,
    `detail` varchar(255) NOT NULL DEFAULT '',
    `actor` varchar(100) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `job_ts` (`job`, `ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `bills` (
    `id` int NOT NULL AUTO_INCREMENT,
    `job` longtext NULL DEFAULT NULL,
    `playername` longtext NULL DEFAULT NULL,
    `identifier` varchar(50) NULL DEFAULT NULL,
    `charidentifier` int NULL DEFAULT NULL,
    `issuer` longtext NULL DEFAULT NULL,
    `amount` int NULL DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- legacy salary table, still read by paydays and pup_mercantile
CREATE TABLE IF NOT EXISTS `society` (
    `job` longtext NULL DEFAULT NULL,
    `jobgrade` int NULL DEFAULT NULL,
    `salary` int NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- shared with vorp_inventory stashes and pup_railroad; invslots belongs to this resource
CREATE TABLE IF NOT EXISTS `container` (
    `id` int NOT NULL AUTO_INCREMENT,
    `name` longtext NULL DEFAULT NULL,
    `items` longtext NULL DEFAULT '{}',
    `invslots` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
