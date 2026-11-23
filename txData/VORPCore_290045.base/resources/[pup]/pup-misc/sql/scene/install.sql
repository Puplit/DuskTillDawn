-- pup-misc / scene | install.sql
--
-- Creates:  playerscenes (one row per /scene text placed in the world, style = its look as JSON,
--           NULL = the defaults)
-- Items:    none
-- Requires: nothing (charid refers to characters.charidentifier, no foreign key)
--
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `playerscenes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,
  `coords` longtext DEFAULT '{}',
  `text` longtext DEFAULT '',
  `style` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
