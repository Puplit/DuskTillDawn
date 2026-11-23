-- pup-medical | install. Safe to run more than once: nothing is dropped or overwritten.

CREATE TABLE IF NOT EXISTS `death_losses` (
    `id`             INT NOT NULL AUTO_INCREMENT,
    `charidentifier` INT NOT NULL,
    `identifier`     VARCHAR(50)  NOT NULL DEFAULT '',
    `charname`       VARCHAR(100) NOT NULL DEFAULT '',
    `steamname`      VARCHAR(50)  NOT NULL DEFAULT '',
    `weapons`        LONGTEXT NULL,
    `items`          LONGTEXT NULL,
    `cash`           DOUBLE NOT NULL DEFAULT 0,
    `gold`           DOUBLE NOT NULL DEFAULT 0,
    `restored`       TINYINT(1) NOT NULL DEFAULT 0,
    `restoredby`     VARCHAR(100) NULL,
    `created`        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `charid_idx` (`charidentifier`),
    KEY `created_idx` (`created`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items`
    (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
    ('bandage',        'Bandage',        20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Clean linen for binding a wound.',                       0, NULL, NULL, 1.00),
    ('illegalsyringe', 'Illegal Syringe', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A back-street stimulant. It may bring someone round. It may not.', 0, NULL, NULL, 1.00),
    ('syringe',        'Syringe',        20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A doctor''s syringe for bringing the unconscious round.', 0, NULL, NULL, 1.00);
