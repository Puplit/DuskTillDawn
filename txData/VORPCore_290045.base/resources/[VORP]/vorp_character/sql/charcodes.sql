-- Character codes: a short code that carries a LOOK, never a name.
-- The payload is stored here rather than in the code itself, so the thing people
-- paste to each other stays short enough to type.
CREATE TABLE IF NOT EXISTS `character_codes` (
    `code`       VARCHAR(12) NOT NULL,
    `sex`        VARCHAR(16) NOT NULL,
    `skin`       LONGTEXT    NOT NULL,
    `comps`      LONGTEXT    NOT NULL,
    `tints`      LONGTEXT        NULL,
    `created_by` INT             NULL,
    `created_at` TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `uses`       INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (`code`),
    KEY `created_by` (`created_by`)
);
