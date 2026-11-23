-- pup-stable | install. The resource also creates and upgrades these on start (server/schema.lua);
-- run this by hand only if the database user may not create tables or triggers.

CREATE TABLE IF NOT EXISTS `stable_horses` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stable_horse_stats` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stable_bought` (
    `id` int NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) NOT NULL,
    `charid` int NOT NULL,
    `category` varchar(50) NOT NULL,
    `hash` bigint NOT NULL,
    `equiped_on` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner` (`identifier`, `charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stable_color` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stable_wagons` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE IF NOT EXISTS `stable_bred` (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `stable_starter` (
    `charid` int NOT NULL,
    `identifier` varchar(50) NOT NULL,
    `horseid` int NOT NULL DEFAULT 0,
    `grantedat` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TRIGGER IF EXISTS `add_stable_horse_stats`;
CREATE TRIGGER `add_stable_horse_stats` AFTER INSERT ON `stable_horses` FOR EACH ROW
    INSERT IGNORE INTO `stable_horse_stats` (`horseid`) VALUES (NEW.`id`);

DROP TRIGGER IF EXISTS `delete_stable_horse_stats`;
CREATE TRIGGER `delete_stable_horse_stats` AFTER DELETE ON `stable_horses` FOR EACH ROW
    DELETE FROM `stable_horse_stats` WHERE `horseid` = OLD.`id`;

DROP TRIGGER IF EXISTS `update_stable_equiped_component`;
CREATE TRIGGER `update_stable_equiped_component` BEFORE DELETE ON `stable_horses` FOR EACH ROW
    UPDATE `stable_bought` SET `equiped_on` = 0 WHERE `equiped_on` = OLD.`id`;

-- care items (vorp items table)
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `weight`, `desc`) VALUES
    ('sugarcube', 'Sugar Cube', 10, 1, 'item_standard', 1, 1.0, 'A treat for your horse.'),
    ('Wild_Carrot', 'Wild Carrot', 50, 1, 'item_standard', 1, 1.0, 'Feed for your horse.'),
    ('consumable_haycube', 'Haycube', 10, 1, 'item_standard', 1, 1.0, 'Feed for your horse.'),
    ('carrots', 'Carrot', 10, 1, 'item_standard', 1, 1.0, 'Feed for your horse.'),
    ('holgo', 'Horse Oats', 20, 1, 'item_standard', 1, 1.0, 'Feed for your horse.'),
    ('aplic', 'Fresh Apple', 20, 1, 'item_standard', 1, 1.0, 'Feed for your horse.'),
    ('horsebrush', 'Horse Brush', 5, 1, 'item_standard', 1, 1.0, 'Keeps a horse clean.'),
    ('stim', 'Horse Meds', 50, 1, 'item_standard', 1, 1.0, 'Restores and fortifies a horse.'),
    ('unique_horsesupp', 'Horse Supplement', 10, 1, 'item_standard', 1, 1.0, 'Restores and fortifies a horse.'),
    ('stim2', 'Weak Horse Stimulant', 50, 1, 'item_standard', 1, 1.0, 'Restores a horse a little.'),
    ('horse_coat_changer', 'Horse Coat Tonic', 10, 1, 'item_standard', 1, 1.0, 'Changes your horse''s coat colour at a stable.');
