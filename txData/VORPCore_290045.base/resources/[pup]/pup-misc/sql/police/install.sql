-- pup-misc / police | install.sql
--
-- Creates:  police_badge_offsets (where each character has moved their worn badge, offset is JSON)
-- Items:    none
-- Requires: nothing (charid refers to characters.charidentifier, no foreign key)
--
-- server/police/main.lua also creates this table on start.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `police_badge_offsets` (
  `charid` int(11) NOT NULL,
  `offset` text NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
