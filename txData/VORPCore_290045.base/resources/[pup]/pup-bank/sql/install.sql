-- pup-bank | install.sql
-- Creates: bank_users (one row per character, one balance column per branch),
--          bank_activity (transaction ledger, trimmed to ~90 days by the server),
--          bank_statement_clears ("clear my statement" markers; hides rows, never deletes),
--          bank_treasury (the bank's own money, a single row id = 1).
-- Requires: VORP core `characters` (the teller account lookup reads firstname/lastname).
-- Items: none.
-- Seed rows: none here. The server creates bank_treasury and inserts its id = 1 row
-- itself on start (server/teller.lua).
-- Branch columns: every branch in config/banks.lua needs a `<name>_money` column in bank_users
-- (name lowercased, " bank" and spaces removed).
-- Safe to run more than once.

-- one row per character: who it is, then what each branch holds, then the running total
CREATE TABLE IF NOT EXISTS `bank_users` (
  `id`               INT(11)       NOT NULL AUTO_INCREMENT,
  `charidentifier`   INT(11)       NOT NULL,
  `identifier`       VARCHAR(50)   NOT NULL,
  `steamname`        VARCHAR(255)  NULL     DEFAULT NULL,

  `annesburg_money`  DECIMAL(10,2) NULL     DEFAULT 0.00,
  `armadillo_money`  DECIMAL(10,2) NULL     DEFAULT 0.00,
  `blackwater_money` DECIMAL(10,2) NULL     DEFAULT 0.00,
  `rhodes_money`     DECIMAL(10,2) NULL     DEFAULT 0.00,
  `saintdenis_money` DECIMAL(10,2) NULL     DEFAULT 0.00,
  `strawberry_money` DECIMAL(10,2) NULL     DEFAULT 0.00,
  `valentine_money`  DECIMAL(10,2) NULL     DEFAULT 0.00,

  `total_money`      DECIMAL(10,2) NULL     DEFAULT 0.00,

  PRIMARY KEY (`id`),
  UNIQUE KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `bank_activity` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `bank` varchar(50) NOT NULL DEFAULT '',
  `ts` int(11) NOT NULL,
  `type` varchar(20) NOT NULL,
  `amount` double NOT NULL,
  `balance_after` double NOT NULL DEFAULT 0,
  `actor` varchar(100) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  KEY `char_bank` (`charidentifier`,`bank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `bank_statement_clears` (
  `charidentifier` int(11) NOT NULL,
  `bank` varchar(50) NOT NULL,
  `cleared_at` int(11) NOT NULL,
  PRIMARY KEY (`charidentifier`,`bank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `bank_treasury` (
  `id` int(11) NOT NULL DEFAULT 1,
  `balance` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_tax_in` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_fees_in` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_loaned` decimal(14,2) NOT NULL DEFAULT 0.00,
  `total_repaid` decimal(14,2) NOT NULL DEFAULT 0.00,
  `updated_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
