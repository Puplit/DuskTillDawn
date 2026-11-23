-- =====================================================================
-- pup-gangs | sql/install.sql
--
-- Creates:
--   gangs             the gangs: faction, points, ledger, gang drug record
--   gang_members      one row per character in a gang
--   gang_territories  claimable ground (seeded with the three forts)
--   gang_factions     faction season standings (seeded with the three factions)
--   gang_wars         wars between gangs
--   gang_activity     the gang activity feed / point ledger
--   gang_tables       the placed gang tables
--   gang_plants       delivery-run plants
--   gang_dens         player and fixed dens (the server seeds the fixed
--                         dens from Config.Dens.locations itself, so no rows here)
--   gang_den_found    which gang has found which fixed den
--   gang_blood_log    blood money ledger history
--   gang_drug_log     gang drug audit trail
--   gang_meta         one-off flags written by the server
--   items                 gang items, plus the reward / recipe items it uses
--
-- Requires (VORP core): items (with its item_group and item_rarity rows),
-- character_inventories.
-- Uses at runtime (no tables): pup_realestate, pup_homestead, pup_hideouts,
-- pup_robbery, fred_metabolism, pup-ui.
--
-- After adding items do a FULL server restart: vorp_inventory caches the
-- items table at startup.
-- Safe to run more than once.
-- =====================================================================

CREATE TABLE IF NOT EXISTS `gangs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `faction` varchar(32) NOT NULL DEFAULT 'outlaws',
  `leader` int(11) NOT NULL COMMENT 'charidentifier of the founder/current boss',
  `points` int(11) NOT NULL DEFAULT 0,
  `money` int(11) NOT NULL DEFAULT 0 COMMENT 'gang treasury',
  `motd` varchar(255) NOT NULL DEFAULT '',
  `created_at` int(11) NOT NULL DEFAULT 0 COMMENT 'unix epoch',
  `last_activity` int(11) NOT NULL DEFAULT 0 COMMENT 'unix epoch, drives point decay',
  `last_mission` int(11) NOT NULL DEFAULT 0,
  `shortname` varchar(8) NOT NULL DEFAULT '',
  `stats` longtext DEFAULT NULL,
  `ranks` longtext DEFAULT NULL,
  `blipcolor` varchar(16) NOT NULL DEFAULT '',
  `bloodmoney` int(11) NOT NULL DEFAULT 0,
  `slots_bought` int(11) NOT NULL DEFAULT 0,
  `perks_bought` text DEFAULT NULL,
  `drug_name` varchar(48) DEFAULT NULL,
  `drug_icon` varchar(32) DEFAULT NULL,
  `drug_points` int(11) NOT NULL DEFAULT 0,
  `drug_earned` int(11) NOT NULL DEFAULT 0,
  `drug_nodes` text DEFAULT NULL,
  `drug_created` int(11) NOT NULL DEFAULT 0,
  `drug_seed_pending` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gangs_name` (`name`),
  KEY `idx_pup_gangs_faction` (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) NOT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `rank` int(11) NOT NULL DEFAULT 1,
  `points` int(11) NOT NULL DEFAULT 0 COMMENT 'personal contribution, for the members table',
  `joined_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_members_char` (`charid`),
  KEY `idx_pup_gang_members_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_territories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) NOT NULL,
  `gangid` int(11) DEFAULT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `claimed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_territories_name` (`name`),
  KEY `idx_pup_gang_territories_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_factions` (
  `faction` varchar(32) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0 COMMENT 'accumulated, never decays',
  `updated_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`faction`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_wars` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gang_a` int(11) NOT NULL,
  `gang_b` int(11) NOT NULL,
  `score_a` int(11) NOT NULL DEFAULT 0,
  `score_b` int(11) NOT NULL DEFAULT 0,
  `startts` int(11) NOT NULL DEFAULT 0,
  `endts` int(11) NOT NULL DEFAULT 0,
  `status` varchar(16) NOT NULL DEFAULT 'active',
  `winner` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_wars_a` (`gang_a`),
  KEY `idx_pup_gang_wars_b` (`gang_b`),
  KEY `idx_pup_gang_wars_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `ts` int(11) NOT NULL DEFAULT 0,
  `type` varchar(32) NOT NULL DEFAULT '',
  `detail` varchar(255) NOT NULL DEFAULT '',
  `actor` varchar(64) NOT NULL DEFAULT '',
  `pts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_activity_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_tables` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) DEFAULT NULL,
  `houseid` int(11) NOT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `h` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `placed_by` int(11) NOT NULL DEFAULT 0,
  `placed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_tables_gang` (`gangid`),
  KEY `idx_pup_gang_tables_house` (`houseid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_plants` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `attacker` int(11) NOT NULL COMMENT 'gang that planted',
  `defender` int(11) NOT NULL COMMENT 'gang whose territory it is in',
  `territoryid` int(11) NOT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `startts` int(11) NOT NULL DEFAULT 0,
  `endts` int(11) NOT NULL DEFAULT 0,
  `status` varchar(16) NOT NULL DEFAULT 'active',
  PRIMARY KEY (`id`),
  KEY `idx_pup_gang_plants_status` (`status`),
  KEY `idx_pup_gang_plants_def` (`defender`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_dens` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) DEFAULT NULL,
  `houseid` int(11) DEFAULT NULL,
  `x` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `y` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `z` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `h` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `stored` int(11) NOT NULL DEFAULT 0,
  `last_brew` int(11) NOT NULL DEFAULT 0,
  `last_raided` int(11) NOT NULL DEFAULT 0,
  `created_at` int(11) NOT NULL DEFAULT 0,
  `admin` tinyint(4) NOT NULL DEFAULT 0,
  `label` varchar(64) NOT NULL DEFAULT '',
  `cook_until` int(11) NOT NULL DEFAULT 0,
  `last_cook` int(11) NOT NULL DEFAULT 0,
  `last_seized` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_pup_gang_dens_house` (`houseid`),
  KEY `idx_pup_gang_dens_gang` (`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_den_found` (
  `denid` int(11) NOT NULL,
  `gangid` int(11) NOT NULL,
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`denid`,`gangid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_blood_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `amount` int(11) NOT NULL DEFAULT 0 COMMENT 'positive = deposit, negative = spend',
  `reason` varchar(96) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_blood_gang` (`gangid`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_drug_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gangid` int(11) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `name` varchar(64) NOT NULL DEFAULT '',
  `kind` varchar(24) NOT NULL DEFAULT '',
  `amount` int(11) NOT NULL DEFAULT 0,
  `detail` varchar(160) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_drug_gang` (`gangid`,`ts`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `gang_meta` (
  `k` varchar(50) NOT NULL,
  `v` varchar(50) NOT NULL,
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------
-- Seed rows
-- ---------------------------------------------------------------------
-- The three factions (keys of Config.Factions.list), so the standings
-- board is populated before anyone scores.
INSERT IGNORE INTO `gang_factions` (`faction`, `points`, `updated_at`) VALUES
  ('outlaws', 0, 0),
  ('syndicate', 0, 0),
  ('reapers', 0, 0);

-- Claimable ground: forts only, never towns. The code never creates
-- territories, so without these rows there is nothing to claim.
INSERT IGNORE INTO `gang_territories` (`name`, `gangid`, `x`, `y`, `z`) VALUES
  ('Fort Mercer', NULL, -4203.0100, -3446.0500, 40.0200),
  ('Fort Wallace', NULL, 357.7900, 1466.8200, 179.2000),
  ('Lemoyne Fort', NULL, 2454.5000, 292.5000, 70.3500);

-- ---------------------------------------------------------------------
-- Items
-- ---------------------------------------------------------------------
-- Owned by pup-gangs: gang_table, drug_package, blood_money, den_key,
-- gang_seed, gang_drug (the gang crop / product), gunpowder and paper
-- (powder bench materials).
-- Also used (rewards, fort loot, bench recipes) and normally provided by
-- other resources; listed so a fresh install has every row it hands out.
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('gang_table', 'Gang Table', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Place inside a house you own to found a gang.', 0, NULL, NULL, 1.00),
  ('drug_package', 'Drug Package', 1, 1, 'item_standard', 0, 0, 1, 5, '{}', 'Contraband. Plant it in rival territory.', 0, NULL, NULL, 1.00),
  ('blood_money', 'Blood Money', 500, 1, 'item_standard', 0, 0, 4, 4, '{}', 'A band of notes gone brown at one corner. Nobody asks whose it was. Worth something to a crew that keeps a ledger.', 0, NULL, NULL, 1.00),
  ('den_key', 'Den Key', 1, 1, 'item_standard', 0, 0, 4, 5, '{}', 'A heavy iron key on a frayed leather cord, the brass tag worn smooth. Opens a door somebody would rather have kept shut.', 0, NULL, NULL, 1.00),
  ('gang_seed', 'Gang Seed', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Seed stock for a gang\'s own crop.', 0, NULL, NULL, 1.00),
  ('gang_drug', 'Gang Product', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A gang\'s own product.', 0, NULL, NULL, 1.00),
  ('gunpowder', 'Gunpowder', 50, 1, 'item_standard', 0, 0, 4, 1, '{}', 'Coarse black powder in a waxed paper twist. Keep it dry, keep it away from the fire, and do not drop it.', 0, NULL, NULL, 1.00),
  ('paper', 'Paper', 50, 1, 'item_standard', 0, 0, 4, 1, '{}', 'Sheets of paper for writing or drawing.', 0, NULL, NULL, 1.00),
  ('acid', 'Acid', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A corrosive substance used for various purposes.', 0, NULL, NULL, 1.00),
  ('ammodynamite', 'Dynamite Ammo', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An explosive device with a short fuse, capable of causing significant damage.', 0, NULL, NULL, 1.00),
  ('ammovoldynamite', 'Volatile Dynamite Ammo', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Ammo used for crafting Volatile Dynamite', 0, NULL, NULL, 1.00),
  ('dynamite', 'Pipe Charge Dynamite', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An explosive device consisting of a tube filled with explosive material, used for various purposes including mining and demolition.', 0, NULL, NULL, 1.00),
  ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious green gemstone with a sparkling appearance.', 0, NULL, NULL, 1.00),
  ('goldbar', 'Gold Bar', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A bar made of solid gold.', 0, NULL, NULL, 1.00),
  ('heroin', 'Heroin', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A highly addictive and illegal drug.', 0, NULL, NULL, 1.00),
  ('moneybag_medium', 'Medium Bag of Cash', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('moonshine', 'Moonshine', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An illegally distilled and potent alcoholic beverage', 0, NULL, NULL, 1.00),
  ('stolenmerch', 'Stolen Items', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Various stolen items of questionable origin.', 0, NULL, NULL, 1.00);
