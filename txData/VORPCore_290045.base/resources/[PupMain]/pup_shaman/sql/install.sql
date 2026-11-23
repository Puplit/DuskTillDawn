-- pup_shaman install
-- The resource also checks this schema on every start (additive only).

-- characters.curse holds the curse key (lycan, vamp, bear, witch, weak); NULL or '' = none.
-- Run this ALTER only if the column does not exist yet (the resource adds it itself on start).
-- ALTER TABLE `characters` ADD COLUMN `curse` VARCHAR(255) DEFAULT NULL;

CREATE TABLE IF NOT EXISTS `shaman_afflictions` (
    `charid` INT(11) NOT NULL,
    `curse` VARCHAR(32) NOT NULL,
    `started_at` INT(11) NOT NULL,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items`
    (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
    ('curse_cure', 'Curse Cure', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00);
