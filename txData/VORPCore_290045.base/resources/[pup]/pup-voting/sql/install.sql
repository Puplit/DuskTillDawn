-- pup-voting | install.sql
--
-- Creates:  the mayoral election tables election_settings, election,
--           election_candidates and election_votes
-- Items:    none. No seed rows (the server writes the `enabled` row the first time staff flip it).
-- Requires: VORP core characters (read only, for candidate lookup).
--
-- server/main.lua also runs the statements in this file on start, so a manual run is optional.
-- Do not put semicolons in comments here: the server splits the file on them.
-- Safe to run more than once.

-- one row per setting. `enabled` is the master switch staff flip in the office,
-- kept here so a restart does not quietly reopen the polls
CREATE TABLE IF NOT EXISTS `election_settings` (
  `k` varchar(32) NOT NULL,
  `v` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- open = 0 and started_at NULL is a draft still being set up
CREATE TABLE IF NOT EXISTS `election` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `region` varchar(32) NOT NULL DEFAULT '',
  `ends_at` timestamp NULL DEFAULT NULL,
  `open` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` varchar(100) NOT NULL DEFAULT '',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `hours` int(11) NOT NULL DEFAULT 48,
  `started_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `region` (`region`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- a candidate is a real character, looked up when they are added.
-- They stand in exactly one region per election.
CREATE TABLE IF NOT EXISTS `election_candidates` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `election_id` int(11) NOT NULL,
  `charid` int(11) NOT NULL,
  `name` varchar(64) NOT NULL,
  `region` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_run_each` (`election_id`,`charid`),
  KEY `election_id` (`election_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- one vote per ACCOUNT per REGION: the unique key is the rule
CREATE TABLE IF NOT EXISTS `election_votes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `election_id` int(11) NOT NULL,
  `candidate_id` int(11) NOT NULL,
  `identifier` varchar(100) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `voter_name` varchar(100) NOT NULL DEFAULT '',
  `voted_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `region` varchar(32) NOT NULL DEFAULT '',
  PRIMARY KEY (`id`),
  UNIQUE KEY `one_per_region` (`election_id`,`region`,`identifier`),
  KEY `candidate_id` (`candidate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
