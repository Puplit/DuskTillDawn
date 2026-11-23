-- pup-pinboard | migrate_2026-11-21.sql
--
-- For a database made before 2026-11-21. New installs only need install.sql.
-- Safe to run more than once: every step checks first and does nothing when already done.
-- MariaDB 10.2+ / MySQL 5.7+. Run it on the database in server.cfg, with the server stopped.
-- The table is `pinboard_posters` (the name after the 2026-11-19 table rename).
--
-- 1. Columns: creator_vorp_char_id -> author_charid, creator_name -> author_name (data kept).
-- 2. Notice content (JSON in `content`), so existing notices keep showing:
--      text notices:    "sections" -> "lines", line "type":"headline" -> "style":"heading", "type":"text" -> "style":"body"
--      picture notices: "image_url" -> "picture"
--      both:            the leftover "everywhere" and "response_event_type" keys are removed
--    The `type` column keeps 'text' / 'image'.

SET @db  = DATABASE();
SET @tbl = 'pinboard_posters';

SET @has_table = (SELECT COUNT(*) FROM information_schema.TABLES
                  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl);

-- 1a. creator_vorp_char_id -> author_charid
SET @old = (SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND COLUMN_NAME = 'creator_vorp_char_id');
SET @new = (SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND COLUMN_NAME = 'author_charid');
SET @sql = IF(@has_table = 1 AND @old = 1 AND @new = 0,
    CONCAT('ALTER TABLE `', @tbl, '` CHANGE COLUMN `creator_vorp_char_id` `author_charid` INT(11) NOT NULL'),
    'SELECT ''author_charid: nothing to do'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 1b. creator_name -> author_name
SET @old = (SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND COLUMN_NAME = 'creator_name');
SET @new = (SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = @db AND TABLE_NAME = @tbl AND COLUMN_NAME = 'author_name');
SET @sql = IF(@has_table = 1 AND @old = 1 AND @new = 0,
    CONCAT('ALTER TABLE `', @tbl, '` CHANGE COLUMN `creator_name` `author_name` VARCHAR(128) DEFAULT NULL'),
    'SELECT ''author_name: nothing to do'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2a. text notices. The server writes compact JSON, and quotes inside players' text are escaped (\"),
--     so these patterns only ever match keys, never something a player typed.
SET @sql = IF(@has_table = 1,
    CONCAT('UPDATE `', @tbl, '` SET `content` = ',
           'REPLACE(REPLACE(REPLACE(`content`, ''"sections":'', ''"lines":''), ',
           '''"type":"headline"'', ''"style":"heading"''), ''"type":"text"'', ''"style":"body"'') ',
           'WHERE `content` LIKE ''%"sections":%'' OR `content` LIKE ''%"type":"headline"%'' OR `content` LIKE ''%"type":"text"%'''),
    'SELECT ''no table'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2b. picture notices
SET @sql = IF(@has_table = 1,
    CONCAT('UPDATE `', @tbl, '` SET `content` = REPLACE(`content`, ''"image_url":'', ''"picture":'') ',
           'WHERE `content` LIKE ''%"image_url":%'''),
    'SELECT ''no table'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- 2c. keys that were stored by accident (runs after the REPLACEs: JSON_REMOVE may re-space the JSON)
SET @sql = IF(@has_table = 1,
    CONCAT('UPDATE `', @tbl, '` SET `content` = JSON_REMOVE(`content`, ''$.everywhere'') ',
           'WHERE JSON_VALID(`content`) AND JSON_CONTAINS_PATH(`content`, ''one'', ''$.everywhere'')'),
    'SELECT ''no table'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = IF(@has_table = 1,
    CONCAT('UPDATE `', @tbl, '` SET `content` = JSON_REMOVE(`content`, ''$.response_event_type'') ',
           'WHERE JSON_VALID(`content`) AND JSON_CONTAINS_PATH(`content`, ''one'', ''$.response_event_type'')'),
    'SELECT ''no table'' AS pinboard_migration');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- check: both should be 0 rows / 'author_charid' and 'author_name' should be listed
-- SELECT COUNT(*) FROM `pinboard_posters` WHERE `content` LIKE '%"sections":%' OR `content` LIKE '%"image_url":%';
-- SHOW COLUMNS FROM `pinboard_posters`;
