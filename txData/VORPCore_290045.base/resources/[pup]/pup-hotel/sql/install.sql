-- pup-hotel | fresh install
-- Creates: hotel_rentals (live room stays) and hotel_settings (office price overrides,
--          key 'price:<tier>'; an empty table means the config prices are used).
-- Requires: VORP core `characters` (guest lookup), and pup_business for the society cut
--           (paid through its AddToLedger export; its tables are created by pup_business).
-- No items, no seed rows. The server also creates both tables on start if they are missing.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `hotel_rentals` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `hotel` varchar(50) NOT NULL,
  `room` varchar(50) NOT NULL,
  `charid` int(11) NOT NULL,
  `identifier` varchar(50) NOT NULL DEFAULT '',
  `guest` varchar(100) NOT NULL DEFAULT '',
  `tier` varchar(30) NOT NULL DEFAULT '',
  `rentedat` int(11) NOT NULL DEFAULT 0,
  `expiresat` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `hotelroom` (`hotel`,`room`),
  KEY `charid` (`charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `hotel_settings` (
  `k` varchar(64) NOT NULL,
  `v` varchar(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`k`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
