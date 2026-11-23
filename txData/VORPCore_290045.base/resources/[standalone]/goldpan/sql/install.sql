-- goldpan | sql/install.sql
--
-- Creates: no tables of its own. goldpan never queries the database.
-- Items:   the gold pan and everything panning can give.
-- Requires: VORP core `items` (with its item_group and item_rarity rows).
-- Existing rows are never changed (INSERT IGNORE). Safe to run more than once.
-- After adding items do a FULL server restart: vorp_inventory reads the items table at start.

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('goldpan', 'Gold pan', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A shallow pan used for gold panning.', 0, NULL, NULL, 1.00),
  ('goldnugget', 'Gold Nugget', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A small lump of placer gold.', 0, NULL, NULL, 1.00),
  ('diamond', 'Diamond', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A rough diamond, a rare find in river gravel.', 0, NULL, NULL, 0.10),
  ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A green stone washed down from the hills.', 0, NULL, NULL, 0.10),
  ('salt', 'Salt', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Common salt', 0, NULL, NULL, 1.00);
