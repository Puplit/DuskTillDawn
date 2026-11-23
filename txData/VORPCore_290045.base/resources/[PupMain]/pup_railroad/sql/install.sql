-- pup_railroad | install
-- Safe to run more than once.

-- Lockbox rows. Shared with vorp_inventory stashes and pup_business; created only if absent.
CREATE TABLE IF NOT EXISTS `container` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` longtext DEFAULT NULL,
  `items` longtext NOT NULL DEFAULT '{}',
  `invslots` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ID` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Company trains.
CREATE TABLE IF NOT EXISTS `player_trains` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT '0',
  `contid` int(11) DEFAULT NULL,
  `maint` float DEFAULT 100,
  `coal` int(11) DEFAULT 0,
  `coalcap` int(11) DEFAULT NULL,
  `speed` float DEFAULT NULL,
  `hash` varchar(50) DEFAULT NULL,
  `company` varchar(50) DEFAULT NULL,
  `coalcon` int(11) DEFAULT NULL,
  `img` varchar(50) DEFAULT NULL,
  `coalup` int(11) DEFAULT 0,
  `speedup` int(11) DEFAULT 0,
  `items` longtext DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Items used by keys, coal, repairs, upgrades and deliveries.
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('alcohol', 'Alcohol', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An intoxicating beverage consumed for recreational purposes.', 0, NULL, NULL, 1.00),
  ('bolts', 'Bolts', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Metal bolts often used in construction.', 0, NULL, NULL, 1.00),
  ('clay', 'Clay', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A block of clay for crafting.', 0, NULL, NULL, 1.00),
  ('coal', 'Coal', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A chunk of coal for fuel.', 0, NULL, NULL, 1.00),
  ('copper', 'Copper', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A piece of copper.', 0, NULL, NULL, 1.00),
  ('copper_bar', 'Copper Bar', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('fertilizer', 'Fertilizer', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A substance used to enrich soil and promote plant growth.', 0, NULL, NULL, 1.00),
  ('fibers', 'Fibers', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Fine threads or filaments extracted from plants or animals, often used for crafting or weaving.', 0, NULL, NULL, 1.00),
  ('ironbar', 'Iron Bar', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A solid bar made of iron, known for its strength and durability.', 0, NULL, NULL, 1.00),
  ('ironhammer', 'Iron Hammer', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A hammer with a head made of iron, used for various construction and crafting purposes.', 0, NULL, NULL, 1.00),
  ('legbisons', 'Legendary Bison pelt', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A rare and valuable pelt from a legendary bison', 0, NULL, NULL, 1.00),
  ('legprongs', 'Legendary Pronghorn pelt', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A sleek and coveted skin from a legendary pronghorn', 0, NULL, NULL, 1.00),
  ('medical_box_bag', 'Medical Box', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('rock', 'Rock', 30, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A solid mineral material that forms the Earths crust, commonly found in various shapes and sizes.', 0, NULL, NULL, 1.00),
  ('shellcasing', 'Shell Casing', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Empty shell casing', 0, NULL, NULL, 1.00),
  ('stim2', 'Weak Horse Stimulant', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('string', 'String', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A bundle of string with many uses.', 0, NULL, NULL, 1.00),
  ('trainkey', 'Train Key', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A key to unlock a train.', 0, NULL, NULL, 1.00),
  ('wooden_boards', 'Wooden Boards', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Boards made from wood material.', 0, NULL, NULL, 1.00),
  ('wool', 'Wool', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Fiber obtained from the fleece of sheep.', 0, NULL, NULL, 1.00);
