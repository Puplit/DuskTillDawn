-- pup_library | database install. Safe to run more than once.

CREATE TABLE IF NOT EXISTS `books` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `title` varchar(50) NOT NULL,
  `author` longtext NOT NULL,
  `data` longtext NOT NULL,
  `edit` longtext NOT NULL,
  `charid` int NOT NULL DEFAULT 0,
  `item` varchar(50) DEFAULT 'book',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `books_publishing` (
  `id` int(11) NOT NULL,
  `publish` int(11) DEFAULT 0,
  `charid` int(11) NULL DEFAULT NULL,
  `copies` int(11) DEFAULT 0,
  `price` float DEFAULT 0,
  `title` varchar(50) NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `book_royalties` (
  `charid` int(11) NOT NULL,
  `cash` float DEFAULT 0,
  PRIMARY KEY (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `items`
  (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
  ('book',       'Book',      1,  1, 'item_standard', 1, 0, 1, 1, '{}', 'A written or printed work consisting of pages.', 0, NULL, NULL, 1.00),
  ('newspaper1', 'Newspaper', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('magazine',   'Magazine',  20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('letter',     'Letter',    20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('contract',   'Contract',  20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00);
