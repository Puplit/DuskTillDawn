-- pup_workbench install. Safe to run more than once.
-- The resource also creates its own tables at start-up.

CREATE TABLE IF NOT EXISTS `crafting_recipes` (
  `id` int(11) NOT NULL,
  `name` varchar(128) NULL DEFAULT NULL,
  `category` varchar(64) NULL DEFAULT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  `data` longtext NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crafting_locations` (
  `name` varchar(64) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `enabled` tinyint(4) NOT NULL DEFAULT 1,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crafting_queue` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `crafting_lock_owner` (
  `identifier` varchar(50) NOT NULL,
  `charidentifier` int(11) NOT NULL,
  `steamname` varchar(50) NOT NULL DEFAULT '',
  `charname` varchar(100) NOT NULL DEFAULT '',
  `lastseen` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`identifier`, `charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `workbench_favourites` (
  `charid` int(11) NOT NULL,
  `ids` longtext NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- the experience column this resource owns on VORP's characters table (MariaDB)
ALTER TABLE `characters`
  ADD COLUMN IF NOT EXISTS `crafting` longtext DEFAULT '{"medical":0,"blacksmith":0,"basic":0,"survival":0,"brewing":0,"food":0}';
CREATE INDEX IF NOT EXISTS `crafting` ON `characters` (`crafting`(768));

-- items the bench uses out of the box (inserted only when missing)
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `weight`) VALUES
  ('campfire', 'Campfire', 5, 1, 'item_standard', 1, 1, 1, '{}', 'A fire pit used for cooking and warmth during camping.', 0, 1.00),
  ('handsaw', 'Handsaw', 10, 1, 'item_standard', 1, 1, 1, '{}', 'A hand saw used to cut wood', 0, 1.00),
  ('skinning_knife', 'Skinning Knife', 25, 1, 'item_standard', 0, 1, 1, '{}', 'nice item', 0, 1.00),
  ('unique_straightrazor', 'Straight Razor', 25, 1, 'item_standard', 0, 1, 1, '{}', 'nice item', 0, 1.00),
  ('wood_plane', 'Wood Plane', 10, 1, 'item_standard', 1, 1, 1, '{}', 'A wood plane used for shaping wood.', 0, 1.00),
  ('wrench', 'Wrench', 10, 1, 'item_standard', 1, 1, 1, '{}', 'A wrech used to tighten bolts and other things.', 0, 1.00);
