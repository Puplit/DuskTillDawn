-- river | move an existing install from the old bottle item names to the new ones.
-- Run once, with the server stopped. Players keep their bottles: the item rows, every
-- inventory stack and every crafted item record are renamed in place.
--   butelka_brudna_woda -> bottle_river_water   (dirty)
--   butelka_czysta_woda -> bottle_boiled_water  (clean)
-- Rerunning it does nothing. Skip it on a fresh install.

UPDATE `items` SET `item` = 'bottle_river_water',
       `desc` = 'River water. Boil it at a fire before drinking, or risk poisoning.'
 WHERE `item` = 'butelka_brudna_woda';
UPDATE `items` SET `item` = 'bottle_boiled_water',
       `desc` = 'Boiled water, safe to drink.'
 WHERE `item` = 'butelka_czysta_woda';

UPDATE `character_inventories` SET `item_name` = 'bottle_river_water'  WHERE `item_name` = 'butelka_brudna_woda';
UPDATE `character_inventories` SET `item_name` = 'bottle_boiled_water' WHERE `item_name` = 'butelka_czysta_woda';

UPDATE `items_crafted` SET `item_name` = 'bottle_river_water'  WHERE `item_name` = 'butelka_brudna_woda';
UPDATE `items_crafted` SET `item_name` = 'bottle_boiled_water' WHERE `item_name` = 'butelka_czysta_woda';
