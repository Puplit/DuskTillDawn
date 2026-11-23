-- pup-misc storagebox: portable storage boxes and job packs.
-- The module also creates the table and syncs the item rows on start; importing this first
-- lets vorp_inventory load the items on its own first start.

CREATE TABLE IF NOT EXISTS `storage_boxes` (
    `box_id`    varchar(20) NOT NULL,              -- 'pupbox_' + 8 lowercase letters; also the vorp custom inventory id
    `capacity`  int NOT NULL DEFAULT 500,          -- slot limit of the custom inventory
    `placed`    tinyint(1) NOT NULL DEFAULT 0,     -- 1 while the box stands in the world
    `pos_x`     float NULL DEFAULT NULL,
    `pos_y`     float NULL DEFAULT NULL,
    `pos_z`     float NULL DEFAULT NULL,
    `pos_h`     float NULL DEFAULT NULL,           -- facing angle in degrees while placed
    `item_name` varchar(50) NULL DEFAULT NULL,     -- box or pack item name
    PRIMARY KEY (`box_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `weight`) VALUES
    ('storage_box_1000', 'Storage Box',   10, 1, 'item_standard', 1, 1, 1, '{}', 'A portable storage box. Holds up to 1000 item slots.', 0, NULL, 1),
    ('miner_pack',       'Miner''s Pack',  1, 1, 'item_standard', 1, 1, 4, '{}', 'A heavy canvas pack for ore. Holds 400 units of mining materials.', 0, NULL, 1),
    ('lumber_pack',      'Lumber Pack',    1, 1, 'item_standard', 1, 1, 4, '{}', 'A strapped timber pack. Holds 400 units of lumber materials.', 0, NULL, 1),
    ('farmer_pack',      'Farmer''s Pack', 1, 1, 'item_standard', 1, 1, 4, '{}', 'A canvas produce pack. Holds 400 units of seeds and crops.', 0, NULL, 1)
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`), `limit` = VALUES(`limit`), `can_remove` = VALUES(`can_remove`), `type` = VALUES(`type`),
    `usable` = VALUES(`usable`), `rarityId` = VALUES(`rarityId`), `desc` = VALUES(`desc`), `weight` = VALUES(`weight`);
