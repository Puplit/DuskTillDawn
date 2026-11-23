-- "Last played" on the character select cards.
-- server/pup_charcards.lua loads and runs this on start; no manual step needed.
ALTER TABLE `characters` ADD COLUMN IF NOT EXISTS `lastplayed` TIMESTAMP NULL DEFAULT NULL;
