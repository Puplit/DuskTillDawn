-- pup_tradepost tables. The resource also creates these on start if they are missing.
-- This resource owns no items, so there are no item rows to insert.

CREATE TABLE IF NOT EXISTS `tradepost_licences` (
    `charid` INT NOT NULL,
    `market` VARCHAR(32) NOT NULL,
    `inv_id` INT NOT NULL,
    `slots` INT NOT NULL DEFAULT 100,
    `created_at` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`charid`, `market`),
    UNIQUE KEY `inv_id` (`inv_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `tradepost_orders` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `charid` INT NOT NULL,
    `market` VARCHAR(32) NOT NULL,
    `side` ENUM('buy','sell') NOT NULL,
    `item` VARCHAR(96) NOT NULL,
    `label` VARCHAR(128) NOT NULL DEFAULT '',
    `total` INT NOT NULL,
    `remaining` INT NOT NULL,
    `price_each` DECIMAL(12,2) NOT NULL,
    `created_at` INT NOT NULL,
    `expires_at` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `board` (`side`, `item`),
    KEY `owner` (`charid`),
    KEY `expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `tradepost_trades` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `item` VARCHAR(96) NOT NULL,
    `label` VARCHAR(128) NOT NULL DEFAULT '',
    `qty` INT NOT NULL,
    `price_each` DECIMAL(12,2) NOT NULL,
    `buyer` INT NOT NULL DEFAULT 0,
    `seller` INT NOT NULL DEFAULT 0,
    `market` VARCHAR(32) NOT NULL DEFAULT '',
    `traded_at` INT NOT NULL,
    PRIMARY KEY (`id`),
    KEY `item_time` (`item`, `traded_at`),
    KEY `buyer` (`buyer`),
    KEY `seller` (`seller`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `tradepost_accounts` (
    `charid` INT NOT NULL,
    `balance` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `lifetime` DECIMAL(12,2) NOT NULL DEFAULT 0,
    `pay_with` VARCHAR(8) NOT NULL DEFAULT 'cash',
    `bank` VARCHAR(64) NULL DEFAULT NULL,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
