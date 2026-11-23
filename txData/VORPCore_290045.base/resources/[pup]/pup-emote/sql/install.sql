-- pup-emote | install.sql
-- Creates: emotewheel (one row per character; `emotes` holds the saved sets as JSON).
-- Requires: nothing from other resources (charid is the VORP character id).
-- Items: none. Seed rows: none.
-- server/main.lua also runs this file on start, so no manual step is needed. Keep it a
-- single statement for that reason.
-- Safe to run more than once.
CREATE TABLE IF NOT EXISTS `emotewheel` (
  `charid` int(11) NOT NULL,
  `emotes` longtext NOT NULL,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
