-- vorp_crawfish | sql/install.sql
-- Item definitions (Config.CrawfishItemName, Config.CrawfishGivenItemName). Safe to run more than once.
-- Requires vorp_inventory/sql/install.sql (items).

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('animal_crawfish', 'Crawfish', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A small freshwater crustacean.', 0, NULL, NULL, 1.00),
  ('provision_meat_crustacean', 'Raw Crustacean Meat', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', '', 0, NULL, NULL, 0.05);
