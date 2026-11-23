-- pup_clothing | tables. Safe to run more than once; the resource also creates them on start.

CREATE TABLE IF NOT EXISTS `clothing_starter` (
    `charidentifier` int(11) NOT NULL,
    PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `clothing_extras` (
    `charidentifier` int(11) NOT NULL,
    `extras` longtext NULL,
    PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `clothing_outfits` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `charidentifier` int(11) NOT NULL,
    `identifier` varchar(100) NULL DEFAULT NULL,
    `title` varchar(255) NOT NULL DEFAULT 'Outfit',
    `comps` longtext NULL,
    `extras` longtext NULL,
    PRIMARY KEY (`id`),
    KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
