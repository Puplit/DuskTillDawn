-- pup-magic | database install. Safe to run more than once; it only adds the item if it is missing.
-- pup-magic has no tables of its own. It reads `characters` and `clothing_extras` and writes nothing during play.
-- After running this, do a FULL server restart: vorp_inventory reads the items table once at start-up.

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('blood_vial', 'Vial of Blood', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A stoppered vial of human blood.', 0, NULL, NULL, 1.00);
