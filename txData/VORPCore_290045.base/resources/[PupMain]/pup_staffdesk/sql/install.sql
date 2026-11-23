-- pup_staffdesk | install.sql
-- Builds everything this script needs on an empty database. Safe to run more than once.
--
-- Creates: staffdesk_parcels, staffdesk_bounty, staffdesk_ledger, staffdesk_renames, staffdesk_milestones, staffdesk_audit
-- Items: 9 rows
-- The resource also creates these tables on start; running this by hand is optional.
-- Requires: VORP core characters, items, loadout. The Discord reports also read tables from pup_business, pup_camps, pup_mercantile, pup_ranchero, pup_realestate and [pup] scripts; those are optional.
-- recomps, bug_points and recomp_namecd are read once if an older server still has them; not created here.

CREATE TABLE IF NOT EXISTS `staffdesk_parcels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,  -- for one character ...
  `discordid` varchar(32) DEFAULT NULL,  -- ... or for any character on a Discord account
  `kind` varchar(8) NOT NULL,  -- cash | item | weapon
  `name` varchar(64) NOT NULL DEFAULT '',  -- item code or weapon hash
  `label` varchar(100) NOT NULL DEFAULT '',
  `amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `note` varchar(200) NOT NULL DEFAULT '',
  `sent_by` varchar(100) NOT NULL DEFAULT '',
  `origin` varchar(16) NOT NULL DEFAULT 'staff',  -- staff | legacy | milestone | <resource name>
  `created_at` int(11) NOT NULL,
  `claimed_at` int(11) DEFAULT NULL,
  `claimed_by` int(11) DEFAULT NULL,
  `cancelled_at` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char` (`charid`,`claimed_at`),
  KEY `idx_discord` (`discordid`,`claimed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `staffdesk_bounty` (
  `charid` int(11) NOT NULL,
  `points` int(11) NOT NULL DEFAULT 0,
  `earned` int(11) NOT NULL DEFAULT 0,
  `spent` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `staffdesk_ledger` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) NOT NULL,
  `delta` int(11) NOT NULL,
  `reason` varchar(160) NOT NULL DEFAULT '',
  `by_name` varchar(100) NOT NULL DEFAULT '',
  `at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_char` (`charid`,`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `staffdesk_renames` (
  `kind` varchar(16) NOT NULL,  -- name | weapon
  `ref` varchar(64) NOT NULL,  -- charid or weapon id
  `named_at` int(11) NOT NULL,
  PRIMARY KEY (`kind`,`ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `staffdesk_milestones` (
  `charid` int(11) NOT NULL,
  `hours` int(11) NOT NULL,
  `paid_at` int(11) NOT NULL,
  PRIMARY KEY (`charid`,`hours`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `staffdesk_audit` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `at` int(11) NOT NULL,
  `via` varchar(10) NOT NULL,  -- game | discord
  `actor` varchar(100) NOT NULL,
  `command` varchar(32) NOT NULL,
  `args` varchar(255) NOT NULL DEFAULT '',
  `ok` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_at` (`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('cane', 'Cane', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A walking stick for support and stability.', 0, NULL, NULL, 1.00),
  ('clamp01', 'Clamp', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('club03', 'Wooden Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('club06', 'Bone Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('crowbar01', 'Crowbar', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_cane_wood', 'Wooden Cane', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_cigar', 'Lit Cigar', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('shovel_weapon', 'Shovel', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, 100, NULL, 1.00),
  ('bread', 'Bread', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00);
