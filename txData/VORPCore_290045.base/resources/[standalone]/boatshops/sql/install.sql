-- boatshops: owned boats. The resource creates this table on start if it is missing;
-- this file is the same definition for a manual install.

CREATE TABLE IF NOT EXISTS `boats` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(100) NOT NULL DEFAULT '',
    `charidentifier` int(11) NOT NULL,
    `name` varchar(64) NOT NULL DEFAULT 'Boat',
    `boat` varchar(64) NOT NULL DEFAULT '',
    `components` longtext NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `charidentifier` (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
