-- pup-props | install.sql
--
-- Creates:  world_props (every permanent prop placed from the admin prop placer)
-- Items:    none
-- Requires: nothing from other resources.
--
-- server/main.lua also creates this table on start.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `world_props` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `model` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  `frozen` tinyint(4) NOT NULL DEFAULT 1,
  `collision` tinyint(4) NOT NULL DEFAULT 1,
  `label` varchar(100) DEFAULT NULL,
  `placed_by` int(11) DEFAULT NULL,
  `placed_by_name` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `bypos` (`x`,`y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
