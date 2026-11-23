-- vorp_admin | sql/install.sql
-- Complete install for the current code. Safe to run more than once.
-- server/bans.lua and server/pup_flagStore.lua also create these tables on start.
--
-- Creates: admin_bans (one row per ban; ban_id is the XXXX-XXXX appeal code, lifting sets active = 0 so history is kept),
--          admin_ban_identities (last known identity per steam id, so an offline ban can match a licence),
--          vorp_admin_flags (Anti-Cheat panel flag history, pruned to 30 days by the resource).
-- No items and no seed rows: the resource needs none.
-- Requires: vorp_core (users, characters), vorp_inventory/sql/install.sql (character_inventories, items).
-- Read or written by optional panel pages when those resources are installed: bank_users, bills, clan,
-- player_ranch, playerhousing, playershops, stables, wagons, underground, society_ledger, society_ranks,
-- society_shops and the tables of pup-bank, pup_ranchero, pup_realestate, pup_business, pup-stable,
-- pup_workbench and doorlocks.

CREATE TABLE IF NOT EXISTS `admin_bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `ban_id` varchar(16) NOT NULL,
  `charid` int(11) DEFAULT NULL,
  `charname` varchar(100) NOT NULL DEFAULT '',
  `playername` varchar(100) NOT NULL DEFAULT '',
  `license` varchar(80) NOT NULL DEFAULT '',
  `license2` varchar(80) NOT NULL DEFAULT '',
  `steam` varchar(50) NOT NULL DEFAULT '',
  `discord` varchar(40) NOT NULL DEFAULT '',
  `xbl` varchar(40) NOT NULL DEFAULT '',
  `liveid` varchar(40) NOT NULL DEFAULT '',
  `ip` varchar(64) NOT NULL DEFAULT '',
  `tokens` longtext DEFAULT NULL,
  `reason` varchar(512) NOT NULL DEFAULT '',
  `staff` varchar(100) NOT NULL DEFAULT '',
  `created` timestamp NOT NULL DEFAULT current_timestamp(),
  `expires` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `unbanned_by` varchar(100) DEFAULT NULL,
  `unbanned_at` timestamp NULL DEFAULT NULL,
  `ban_count` int(11) NOT NULL DEFAULT 1,
  `first_banned` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ban_id_idx` (`ban_id`),
  KEY `license_idx` (`license`),
  KEY `steam_idx` (`steam`),
  KEY `discord_idx` (`discord`),
  KEY `active_idx` (`active`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `admin_ban_identities` (
  `steam` varchar(50) NOT NULL,
  `license` varchar(80) NOT NULL DEFAULT '',
  `license2` varchar(80) NOT NULL DEFAULT '',
  `discord` varchar(40) NOT NULL DEFAULT '',
  `ip` varchar(64) NOT NULL DEFAULT '',
  `tokens` longtext DEFAULT NULL,
  `playername` varchar(100) NOT NULL DEFAULT '',
  `last_seen` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`steam`),
  KEY `license_idx` (`license`),
  KEY `last_seen_idx` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `vorp_admin_flags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charid` int(11) DEFAULT NULL,
  `identifier` varchar(100) NOT NULL DEFAULT '',
  `name` varchar(100) NOT NULL DEFAULT '',
  `kind` varchar(32) NOT NULL,
  `detail` varchar(255) NOT NULL DEFAULT '',
  `at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `charid` (`charid`),
  KEY `at` (`at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;