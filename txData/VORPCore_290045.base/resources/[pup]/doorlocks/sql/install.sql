-- doorlocks | fresh install
-- Creates: doorlock_doors (every registered door; one row per door, settings as JSON in `data`)
--          and the `lockpick` item used to pick lockpickable doors.
-- Requires: VORP core `items` table (vorp_inventory).
-- server/db.lua also runs CREATE TABLE IF NOT EXISTS for doorlock_doors at startup; this file
-- matches it. No doors are seeded: they are created in game with /createdoor, from
-- config/doors.lua, or through the GetAPI export.
-- Per-door key items (a door's "item access" field) are chosen in game and are not created here.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `doorlock_doors` (
  `doorid` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL DEFAULT 'door',
  `data` longtext NOT NULL DEFAULT '[]',
  `lastupdate` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`doorid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('lockpick', 'Lockpick', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A handy tool used for picking locks', 0, NULL, NULL, 1.00);
