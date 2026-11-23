-- pup-perks | install.sql
--
-- Creates:  perks (one row per character, created on first login: both XP ladders, admin point
--           grants, the committed trees, perk ranks and equipped cards)
-- Items:    none. The perk deck lives in config/perks.lua.
-- Requires: VORP core characters (read for names on the vorp_admin Perks page).
-- Other readers: pup_staffdesk's Discord lookup selects civxp, crimexp and bonuspoints.
--
--   civxp / crimexp       lifetime XP on each side
--   bonusciv / bonuscrime perk points an admin granted (or took) on that side, may be negative
--   civtree / crimetree   committed tree key (config/trees.lua), NULL or '' until chosen
--   bonuspoints           single-pool column: pup-perks no longer uses it, pup_staffdesk still reads it
--   ranks                 JSON object {"skinner":3}  perk id -> rank
--   equipped              JSON array  ["skinner"]    loadout order
--   civbase / crimebase   xp banked when a specialist was chosen
--   lastreset             unix time of the last free weekly reset, 0 = never
--   treexp                JSON object {"hunting":1200}  xp banked per tree
--
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `perks` (
  `charidentifier` int(11) NOT NULL,
  `civxp` int(11) NOT NULL DEFAULT 0,
  `crimexp` int(11) NOT NULL DEFAULT 0,
  `bonusciv` int(11) NOT NULL DEFAULT 0,
  `bonuscrime` int(11) NOT NULL DEFAULT 0,
  `civtree` varchar(32) DEFAULT NULL,
  `crimetree` varchar(32) DEFAULT NULL,
  `bonuspoints` int(11) NOT NULL DEFAULT 0,
  `ranks` longtext DEFAULT NULL,
  `equipped` longtext DEFAULT NULL,
  `civbase` int(11) NOT NULL DEFAULT 0,
  `crimebase` int(11) NOT NULL DEFAULT 0,
  `lastreset` int(11) NOT NULL DEFAULT 0,
  `treexp` text DEFAULT NULL,
  PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
