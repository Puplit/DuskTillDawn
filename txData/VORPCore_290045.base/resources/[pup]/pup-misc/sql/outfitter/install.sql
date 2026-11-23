-- pup-misc / outfitter | install.sql
--
-- Creates:  outfitter (camps and gear each character owns: placed = 1 means it stands at
--           x/y/z/h, 0 means it is packed in the wagon). `sku` keys into config/outfitter/items.lua,
--           so the model, label and price live in the config. Changing a sku orphans what people own.
-- Items:    none (pieces are rows here, not inventory items)
-- Requires: VORP core characters (charidentifier). pup-stable must run for the shop and wagons.
--
-- server/outfitter/main.lua also creates this table on start.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `outfitter` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `charidentifier` int(11) NOT NULL,
  `sku` varchar(64) NOT NULL,
  `placed` tinyint(1) NOT NULL DEFAULT 0,
  `x` float DEFAULT NULL,
  `y` float DEFAULT NULL,
  `z` float DEFAULT NULL,
  `h` float DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `owner` (`charidentifier`),
  KEY `standing` (`placed`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
