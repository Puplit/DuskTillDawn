-- pup_armory | install.sql
-- Builds everything this script needs on an empty database. Safe to run more than once.
--
-- Creates: armory_offsets, armory_defaults
-- Items: 39 rows
-- Requires: VORP core items.

CREATE TABLE IF NOT EXISTS `armory_offsets` (
  `charid` int(11) NOT NULL,
  `item` varchar(50) NOT NULL,
  `slot` varchar(10) NOT NULL,
  `x` double NOT NULL DEFAULT 0,
  `y` double NOT NULL DEFAULT 0,
  `z` double NOT NULL DEFAULT 0,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  PRIMARY KEY (`charid`,`item`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `armory_defaults` (
  `item` varchar(50) NOT NULL,
  `slot` varchar(10) NOT NULL,
  `x` double NOT NULL DEFAULT 0,
  `y` double NOT NULL DEFAULT 0,
  `z` double NOT NULL DEFAULT 0,
  `rx` double NOT NULL DEFAULT 0,
  `ry` double NOT NULL DEFAULT 0,
  `rz` double NOT NULL DEFAULT 0,
  PRIMARY KEY (`item`,`slot`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('axe_wep', 'Woodcutter\'s Axe', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('broom', 'Broom', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('cane_wep', 'Walking Cane', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('clamp01', 'Clamp', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('cleaver01', 'Butcher Cleaver', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club01', 'Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club02', 'Police Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club03', 'Wooden Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club06', 'Bone Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('crowbar01', 'Crowbar', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('hammer02', 'Sledge Hammer', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('hammer_wep', 'Hammer', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('hatchet_wep', 'Camp Hatchet', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('hook_knife', 'Hoof Knife', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('horse_whip_weapons', 'Horse Whip', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('knife01', 'Large Knife', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('mallet_wep', 'Mallet', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('newspaper', 'Rolled Newspaper', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A printed publication containing news and articles', 0, NULL, NULL, 1.00),
  ('pan01', 'Pan', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('pan02', 'Big Pan', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('pickaxe_wep', 'Pickaxe', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('plank_wep', 'Wooden Plank', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('proleg', 'Prosthetic Leg', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('rake_wep', 'Garden Rake', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('saber03', 'Dancer\'s Sabre', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('scythe', 'Scythe', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('shovel_weapon', 'Shovel', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, 100, NULL, 1.00),
  ('skinner_wep', 'Skinner\'s Knife', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('spade_wep', 'Grave Spade', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('stake01', 'Wooden Stake', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('stake02', 'Metal Stake', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('stake_wooden', 'Sharpened Stake', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('stick_wep', 'Walking Stick', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('sword03', 'Warrior\'s Sword', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('sword04', 'Pirate\'s Cutlass', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('tbweapon', 'Field Detector', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('vodkabottle', 'Broken Bottle', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('wizardstaff', 'Staff', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('yardbroom_wep', 'Yard Broom', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00);

-- An existing database keeps its old rows (INSERT IGNORE skips them). To bring it up to date, run once:
--   UPDATE `items` SET `label` = 'Warrior\'s Sword'  WHERE `item` = 'sword03';
--   UPDATE `items` SET `label` = 'Pirate\'s Cutlass' WHERE `item` = 'sword04';
--   UPDATE `items` SET `label` = 'Dancer\'s Sabre'   WHERE `item` = 'saber03';
--   UPDATE `items` SET `label` = 'Sharpened Stake'   WHERE `item` = 'stake_wooden';
--   UPDATE `items` SET `limit` = 1 WHERE `item` IN ('broom','clamp01','cleaver01','club01','club02','hammer02','hammer_wep','hook_knife','horse_whip_weapons','knife01','mallet_wep','newspaper','pan01','pan02','proleg','saber03','scythe','stake01','stake02','stake_wooden','sword03','sword04','tbweapon','vodkabottle','wizardstaff');
--   UPDATE `items` SET `desc` = 'A blade carried on the body. Use it to take it out or put it away.' WHERE `item` IN ('cleaver01','saber03','scythe','sword03','sword04') AND `desc` = 'nice item';
--   UPDATE `items` SET `desc` = 'A short blade carried on the body. Use it to take it out or put it away.' WHERE `item` IN ('hook_knife','knife01','stake01','stake02','stake_wooden') AND `desc` = 'nice item';
--   UPDATE `items` SET `desc` = 'Carried on the body and swung as a club. Use it to take it out or put it away.' WHERE `item` IN ('broom','clamp01','club01','club02','club03','club06','crowbar01','hammer02','hammer_wep','horse_whip_weapons','mallet_wep','pan01','pan02','proleg','shovel_weapon','tbweapon','vodkabottle','wizardstaff') AND `desc` = 'nice item';
