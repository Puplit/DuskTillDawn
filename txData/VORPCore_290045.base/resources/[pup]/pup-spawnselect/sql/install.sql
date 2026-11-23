-- pup-spawnselect | install.sql
--
-- Creates:  spawnselect (per character: last spawn pick, last disconnect, pick count,
--           drives the cooldown and relog-grace guards)
-- Items:    none
-- Requires (not created here, both optional):
--   pup_realestate: table playerhousing (house spawn cards, only while it runs)
--   pup-mdt:        table mdt_prison_records (jailed characters get no picker)
--
-- server/main.lua also creates this table on start.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `spawnselect` (
  `charidentifier` int(11) NOT NULL,
  `last_pick` int(11) NOT NULL DEFAULT 0,
  `last_drop` int(11) NOT NULL DEFAULT 0,
  `picks` int(11) NOT NULL DEFAULT 0,
  `last_label` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
