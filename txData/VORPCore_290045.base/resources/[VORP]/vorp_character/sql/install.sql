-- vorp_character | sql/install.sql
-- Complete install for the current code. Safe to run more than once.
--
-- Creates: outfits (saved outfits; pup_realestate also reads them),
--          character_codes (/charcode: a short code that carries a look, never a name),
--          characters.lastplayed ("last played" on the character select cards).
-- Seeds:   secondchance (usable Second Chance token); the name must match Config.Shops.secondChance.item.
-- Requires: vorp_core (users, characters), vorp_inventory/sql/install.sql (items).
-- Optional (read only when present): mdt_prison_records, society_shops.
-- sql/charcards.sql and sql/charcodes.sql stay beside this file: the resource loads and runs them by name on start.

CREATE TABLE IF NOT EXISTS `outfits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `identifier` varchar(45) NOT NULL,
  `charidentifier` int(11) DEFAULT NULL,
  `title` varchar(255) DEFAULT NULL,
  `comps` longtext DEFAULT NULL,
  `compTints` longtext DEFAULT NULL,
  PRIMARY KEY (`id`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE IF NOT EXISTS `character_codes` (
  `code` varchar(12) NOT NULL,
  `sex` varchar(16) NOT NULL,
  `skin` longtext NOT NULL,
  `comps` longtext NOT NULL,
  `tints` longtext DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `uses` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`code`),
  KEY `created_by` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;

ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `lastplayed` TIMESTAMP NULL DEFAULT NULL;

-- usable must be 1 or vorp_inventory never fires the usable-item callback.
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('secondchance', 'Second Chance', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A fresh start. Use it to remake your face, body and hair wherever you stand - height stays as it is.', 0, NULL, NULL, 1.00);
