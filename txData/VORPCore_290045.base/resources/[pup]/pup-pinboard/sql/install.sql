-- pup-pinboard | install.sql
--
-- Creates:  pinboard_posters (notices pinned to the town boards, content is JSON)
-- Items:    none
-- Requires: nothing from other resources (character data is read through VORP core at runtime).
--
-- server/main.lua also creates this table on start.
-- Safe to run more than once. A database made before 2026-11-21 needs sql/migrate_2026-11-21.sql instead.

CREATE TABLE IF NOT EXISTS `pinboard_posters` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `type` varchar(16) NOT NULL,
  `content` longtext NOT NULL,
  `author_charid` int(11) NOT NULL,
  `author_name` varchar(128) DEFAULT NULL,
  `location` varchar(64) NOT NULL,
  `created_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `location` (`location`),
  KEY `created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
