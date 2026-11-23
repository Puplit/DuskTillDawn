-- pup-misc / ecoboost | install.sql
--
-- Creates:  ecoboost (one row per character: when the boost was last activated, whether it
--           is used up, how much it has earned and when it was completed)
-- Items:    none
-- Requires: nothing (charid refers to characters.charidentifier, no foreign key)
--
-- server/ecoboost/main.lua also creates this table on start.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `ecoboost` (
  `charid` int(11) NOT NULL,
  `last_activated` int(11) NOT NULL DEFAULT 0,
  `exhausted` tinyint(1) NOT NULL DEFAULT 0,
  `earned` double NOT NULL DEFAULT 0,
  `completed_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
