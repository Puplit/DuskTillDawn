-- pup-phonograph install. Safe to run more than once; changes no existing rows.

CREATE TABLE IF NOT EXISTS `phonographs` (
    `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
    `owner_identifier` varchar(255) NULL DEFAULT NULL,
    `owner_charid` int(11) NULL DEFAULT NULL,
    `x` double NULL DEFAULT NULL,
    `y` double NULL DEFAULT NULL,
    `z` double NULL DEFAULT NULL,
    `rot_x` double NULL DEFAULT NULL,
    `rot_y` double NULL DEFAULT NULL,
    `rot_z` double NULL DEFAULT NULL,
    `job` varchar(50) NULL DEFAULT '',
    `rank` int(11) NULL DEFAULT 0,
    `current_record` varchar(50) NULL DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items`
    (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
    ('phonograph', 'Phonograph', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Set it down and play a tune.', 0, NULL, NULL, 2.00);
