-- pup-misc search | no tables of its own. Adds the character creation time that
-- the new-character shield reads (also read by vorp_admin, pup-mdt and
-- pup_staffdesk). Safe to run more than once (MariaDB).

ALTER TABLE `characters`
    ADD COLUMN IF NOT EXISTS `character_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Optional, ONLY on a first install: without it every existing character counts
-- as new for the shield's 24 hours. Uncomment to give them an old date instead.
-- UPDATE `characters` SET `character_created` = '2000-01-01 00:00:00';
