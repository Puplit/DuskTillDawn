-- river | the water bottles and the antidote. Safe to run more than once: existing rows are left alone.
-- An install that still has the older bottle item names: run rename-bottles.sql instead of adding new rows.
-- water_bottle_empty is only used while WaterConfig.Items.emptyBottle is set; with it set to false the row is unused.

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('bottle_river_water', 'Dirty Water Bottle', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'River water. Boil it at a fire before drinking, or risk poisoning.', 0, NULL, NULL, 1.00),
  ('bottle_boiled_water', 'Clean Water Bottle', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Boiled water, safe to drink.', 0, NULL, NULL, 1.00),
  ('water_bottle_empty', 'Empty Water Bottle', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Fill it in a river or lake.', 0, NULL, NULL, 0.50),
  ('antipoison', 'Antipoison', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A medicine that counteracts poison.', 0, NULL, NULL, 1.00);
