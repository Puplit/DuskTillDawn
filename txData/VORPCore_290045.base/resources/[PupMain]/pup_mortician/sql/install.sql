-- pup_mortician install script
-- The resource also creates its three tables on start if they are missing.

CREATE TABLE IF NOT EXISTS `mortician_business` (
    `job` varchar(50) NOT NULL,
    `cut` int(11) NOT NULL DEFAULT 0,
    `webhook` text DEFAULT NULL,
    PRIMARY KEY (`job`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mortician_register` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `job` varchar(50) NOT NULL,
    `charid` int(11) NOT NULL,
    `undertaker` varchar(100) NOT NULL,
    `deceased` varchar(100) NOT NULL,
    `cause` varchar(100) NOT NULL DEFAULT '',
    `place` varchar(50) NOT NULL DEFAULT '',
    `kind` varchar(10) NOT NULL DEFAULT 'casket',
    `goods` varchar(255) NOT NULL DEFAULT '',
    `paid` int(11) NOT NULL DEFAULT 0,
    `house` int(11) NOT NULL DEFAULT 0,
    `at` int(11) NOT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_job` (`job`, `at`),
    KEY `idx_char` (`charid`, `at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `mortician_shift` (
    `charid` int(11) NOT NULL,
    `started` int(11) NOT NULL,
    `burials` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- vorp_inventory items (never overwrites an existing row)
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
    ('acid', 'Acid', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A corrosive substance used for various purposes.', 0, NULL, NULL, 1.00),
    ('burialoil', 'Burial Perfume Oil', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('burialwraps', 'Burial Wraps', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('coal', 'Coal', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A chunk of coal for fuel.', 0, NULL, NULL, 1.00),
    ('copper', 'Copper', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A piece of copper.', 0, NULL, NULL, 1.00),
    ('diamond', 'Diamond', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious gemstone known for its brilliance and value.', 0, NULL, NULL, 1.00),
    ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious green gemstone with a sparkling appearance.', 0, NULL, NULL, 1.00),
    ('flowerarrangement', 'Flower Arrangement', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('goldbar', 'Gold Bar', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A bar made of solid gold.', 0, NULL, NULL, 1.00),
    ('goldnugget', 'Gold Nugget', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('goodbyliquor', 'Good-bye Liquor', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('holywater', 'Holy Water', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('honey', 'Honey', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A sweet and sticky substance produced by bees.', 0, NULL, NULL, 1.00),
    ('joint', 'Joint', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('luckycoin', 'Lucky Coin', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('potato', 'Potato', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An edible starchy tuber that is commonly used in cooking.', 0, NULL, NULL, 1.00),
    ('sap', 'Sap', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Sticky sap', 0, NULL, NULL, 1.00),
    ('shovel', 'Shovel', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, 100, NULL, 1.00),
    ('Wild_Carrot', 'Wild Carrot', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A type of carrot that grows in the wild.', 0, NULL, NULL, 1.00),
    ('wine', 'Wine', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An alcoholic beverage made from fermented grapes.', 0, NULL, NULL, 1.00),
    ('wool', 'Wool', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Fiber obtained from the fleece of sheep.', 0, NULL, NULL, 1.00);
