-- pup-events | sql/install.sql
--
-- Creates: event_windows (saved date/hour windows per event, edited from the vorp_admin Events page),
--          easter_limits (Spring Hunt per-character pickup counts per patch; cleared every reset).
--          The server also creates both on start.
-- Items:   the Spring Hunt eggs and Trick or Treat sweets this resource owns, plus every other item
--          its loot tables give or consume.
-- Seed:    fred_consumables rows for the five Trick or Treat sweets (what they do when eaten).
-- Requires: VORP core `items` (with its item_group and item_rarity rows); fred_metabolism's
--           `fred_consumables` for the last section only.
-- Not inserted (no row exists live, add them yourself if you use them):
--   bm_cross_necklace, puffofbadmanners, sipofbadmanners, pinchofbadmanners, dragofbadmanners
--   (Spring Hunt loot in config/easter.lua).
-- After adding items do a FULL server restart: vorp_inventory caches the items table at startup.
-- Safe to run more than once.

CREATE TABLE IF NOT EXISTS `event_windows` (
  `event` varchar(64) NOT NULL,
  `date_from` varchar(10) DEFAULT NULL,
  `date_to` varchar(10) DEFAULT NULL,
  `hour_from` int(11) DEFAULT NULL,
  `hour_to` int(11) DEFAULT NULL,
  PRIMARY KEY (`event`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `easter_limits` (
  `charidentifier` int(11) NOT NULL,
  `patch` int(11) NOT NULL,
  `generation` int(11) NOT NULL,
  `count` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`charidentifier`,`patch`,`generation`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- ---------------------------------------------------------------------------
-- Items owned by pup-events (Spring Hunt eggs, Trick or Treat sweets)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('easter_egg', 'Painted Egg', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('easter_egg_gold', 'Golden Egg', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('berry_goodness', 'Berry Goodness', 25, 1, 'item_standard', 1, 0, 3, 4, '{}', 'Too red to be berries alone.', 0, NULL, NULL, 1.00),
  ('dirty_grave', 'Dirty Grave', 25, 1, 'item_standard', 1, 0, 3, 4, '{}', 'Chocolate soil, and something buried in it.', 0, NULL, NULL, 1.00),
  ('ginger_dracula', 'Ginger Dracula', 25, 1, 'item_standard', 1, 0, 3, 4, '{}', 'Gingerbread with a bite taken out of you.', 0, NULL, NULL, 1.00),
  ('sour_souls', 'Sour Souls', 25, 1, 'item_standard', 1, 0, 3, 4, '{}', 'They scream on the way down.', 0, NULL, NULL, 1.00),
  ('witches_brew', 'Witches Brew', 25, 1, 'item_standard', 1, 0, 3, 4, '{}', 'Still warm, and nobody is tending the pot.', 0, NULL, NULL, 1.00);

-- ---------------------------------------------------------------------------
-- Items from other resources that the loot tables give or the caches consume
-- (purge caches, egg loot, sacks, lockpick)
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`) VALUES
  ('acid', 'Acid', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A corrosive substance used for various purposes.', 0, NULL, NULL, 1.00),
  ('ammodynamite', 'Dynamite Ammo', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An explosive device with a short fuse, capable of causing significant damage.', 0, NULL, NULL, 1.00),
  ('ammopistolnormal', 'Pistol Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with pistols for self-defense and combat.', 0, NULL, NULL, 1.00),
  ('ammorevolvernormal', 'Revolver Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with revolvers for self-defense and combat.', 0, NULL, NULL, 1.00),
  ('ammoriflenormal', 'Rifle Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with rifles for self-defense and combat.', 0, NULL, NULL, 1.00),
  ('ammoshotgunnormal', 'Shotgun Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with shotguns for self-defense and combat.', 0, NULL, NULL, 1.00),
  ('ammoshotgunslug', 'Shotgun Ammo Slug', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Ammunition with a single solid projectile, offering increased accuracy and range for shotguns.', 0, NULL, NULL, 1.00),
  ('cakecarrot', 'Carrot Cake', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('cleaver01', 'Butcher Cleaver', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club01', 'Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club02', 'Police Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('club03', 'Wooden Club', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('crowbar01', 'Crowbar', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('dynamite', 'Pipe Charge Dynamite', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An explosive device consisting of a tube filled with explosive material, used for various purposes including mining and demolition.', 0, NULL, NULL, 1.00),
  ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious green gemstone with a sparkling appearance.', 0, NULL, NULL, 1.00),
  ('goldbar', 'Gold Bar', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A bar made of solid gold.', 0, NULL, NULL, 1.00),
  ('heroin', 'Heroin', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A highly addictive and illegal drug.', 0, NULL, NULL, 1.00),
  ('horse_coat_changer', 'Horse Coat Tonic', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('knife01', 'Large Knife', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A short blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('lemonad', 'Lemonade', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('lockpick', 'Lockpick', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A handy tool used for picking locks', 0, NULL, NULL, 1.00),
  ('moneybag_medium', 'Medium Bag of Cash', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('moneybag_small', 'Small Bag of Cash', 25, 1, 'item_standard', 0, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pan01', 'Pan', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'Carried on the body and swung as a club. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('pup_candle', 'Candle', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_candle_lamp', 'Candle Lamp', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_cane_skull', 'Skull Cane', 1, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_cane_wood', 'Wooden Cane', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_cross_necklace', 'Silver Cross Necklace', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_ring5', 'Bone Ring', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('pup_skull', 'Human Skull', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('saber03', 'Dancer\'s Sabre', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('scythe', 'Scythe', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'A blade carried on the body. Use it to take it out or put it away.', 0, NULL, NULL, 1.00),
  ('shovel_weapon', 'Shovel', 1, 1, 'item_standard', 1, 0, 1, 5, '{}', 'nice item', 0, 100, NULL, 1.00),
  ('stim', 'Horse Meds', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A Horse Meds to boost a horses performance.', 0, NULL, NULL, 1.00),
  ('stim2', 'Weak Horse Stimulant', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
  ('stolenmerch', 'Stolen Items', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Various stolen items of questionable origin.', 0, NULL, NULL, 1.00);

-- ---------------------------------------------------------------------------
-- fred_metabolism: what each Trick or Treat sweet does when eaten.
-- Needs fred_consumables (fred_metabolism). Kept last, so a server without it
-- still gets everything above. INSERT IGNORE keeps values tuned in the panel.
-- ---------------------------------------------------------------------------
INSERT IGNORE INTO `fred_consumables` (`name`, `displayname`, `hunger`, `thirst`, `metabolism`, `animation`, `propname`, `effect`, `effectduration`, `innercorestamina`, `innercorestaminagold`, `outercorestaminagold`, `innercorehealth`, `innercorehealthgold`, `outercorehealthgold`, `innercoredeadeye`, `innercoredeadeyegold`, `outercoredeadeyegold`) VALUES ('berry_goodness','Berry Goodness',40,20,0,'eat','p_pie01x_slice','',0,12,0,0,14,0,0,0,0,0);
INSERT IGNORE INTO `fred_consumables` (`name`, `displayname`, `hunger`, `thirst`, `metabolism`, `animation`, `propname`, `effect`, `effectduration`, `innercorestamina`, `innercorestaminagold`, `outercorestaminagold`, `innercorehealth`, `innercorehealthgold`, `outercorehealthgold`, `innercoredeadeye`, `innercoredeadeyegold`, `outercoredeadeyegold`) VALUES ('dirty_grave','Dirty Grave',45,0,0,'eat','p_pie01x_slice','',0,14,0,0,12,0,0,0,0,0);
INSERT IGNORE INTO `fred_consumables` (`name`, `displayname`, `hunger`, `thirst`, `metabolism`, `animation`, `propname`, `effect`, `effectduration`, `innercorestamina`, `innercorestaminagold`, `outercorestaminagold`, `innercorehealth`, `innercorehealthgold`, `outercorehealthgold`, `innercoredeadeye`, `innercoredeadeyegold`, `outercoredeadeyegold`) VALUES ('ginger_dracula','Ginger Dracula',44,1,0,'eat','p_bread05x','',0,15,0,0,15,0,0,0,0,0);
INSERT IGNORE INTO `fred_consumables` (`name`, `displayname`, `hunger`, `thirst`, `metabolism`, `animation`, `propname`, `effect`, `effectduration`, `innercorestamina`, `innercorestaminagold`, `outercorestaminagold`, `innercorehealth`, `innercorehealthgold`, `outercorehealthgold`, `innercoredeadeye`, `innercoredeadeyegold`, `outercoredeadeyegold`) VALUES ('sour_souls','Sour Souls',25,10,0,'eat','s_chocolatebar02x','',0,20,0,0,8,0,0,0,0,0);
INSERT IGNORE INTO `fred_consumables` (`name`, `displayname`, `hunger`, `thirst`, `metabolism`, `animation`, `propname`, `effect`, `effectduration`, `innercorestamina`, `innercorestaminagold`, `outercorestaminagold`, `innercorehealth`, `innercorehealthgold`, `outercorehealthgold`, `innercoredeadeye`, `innercoredeadeyegold`, `outercoredeadeyegold`) VALUES ('witches_brew','Witches Brew',5,60,0,'drink_cup','p_cuptin01x','',0,25,0,0,20,0,0,0,0,0);
