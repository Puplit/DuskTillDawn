-- pup_robbery | database install. Safe to run more than once.
-- The resource also creates its own four tables at start-up if they are missing.
-- After adding items, do a FULL server restart: vorp_inventory reads the items table once at start-up.

CREATE TABLE IF NOT EXISTS `robbery_cooldowns` (
    `scope` varchar(16) NOT NULL,
    `ckey` varchar(64) NOT NULL,
    `expires` int(11) NOT NULL,
    PRIMARY KEY (`scope`, `ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `robbery_history` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `bank` varchar(64) NOT NULL,
    `outcome` varchar(16) NOT NULL,
    `crew` text DEFAULT NULL,
    `lootTaken` int(11) NOT NULL DEFAULT 0,
    `lootTotal` int(11) NOT NULL DEFAULT 0,
    `alarmPeak` int(11) NOT NULL DEFAULT 0,
    `duration` int(11) NOT NULL DEFAULT 0,
    `at` int(11) NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `robbery_fence_rep` (
    `charidentifier` int(11) NOT NULL,
    `rep` int(11) NOT NULL DEFAULT 0,
    `sales` int(11) NOT NULL DEFAULT 0,
    `value` int(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `robbery_fence_payouts` (
    `charidentifier` int(11) NOT NULL,
    `amount` int(11) NOT NULL DEFAULT 0,
    `readyAt` int(11) NOT NULL,
    `mailed` tinyint(4) NOT NULL DEFAULT 0,
    PRIMARY KEY (`charidentifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `weight`) VALUES
  ('lockpick', 'Lockpick', 5, 1, 'item_standard', 1, 1, 1, '{}', 'A handy tool used for picking locks', 0, 1.00),
  ('banktools', 'Safe Tools', 10, 1, 'item_standard', 1, 1, 1, '{}', 'nice item', 0, 1.00),
  ('crowbar', 'Crowbar', 10, 1, 'item_standard', 1, 1, 1, '{}', 'nice item', 0, 1.00),
  ('dynamite', 'Pipe Charge Dynamite', 10, 1, 'item_standard', 1, 1, 1, '{}', 'An explosive device consisting of a tube filled with explosive material, used for various purposes including mining and demolition.', 0, 1.00),
  ('ironhammer', 'Iron Hammer', 5, 1, 'item_standard', 1, 1, 1, '{}', 'A hammer with a head made of iron, used for various construction and crafting purposes.', 0, 1.00),
  ('hideout_plans', 'Hideout Plans', 1, 1, 'item_standard', 1, 1, 5, '{}', 'nice item', 0, 1.00),
  ('moneybag_small', 'Small Bag of Cash', 25, 1, 'item_standard', 0, 1, 1, '{}', 'nice item', 0, 1.00),
  ('moneybag_medium', 'Medium Bag of Cash', 25, 1, 'item_standard', 0, 1, 1, '{}', 'nice item', 0, 1.00),
  ('moneybag_large', 'Large Bag of Cash', 25, 1, 'item_standard', 0, 1, 1, '{}', 'nice item', 0, 1.00),
  ('goldbar', 'Gold Bar', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A bar made of solid gold.', 0, 1.00),
  ('diamond', 'Diamond', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A precious gemstone known for its brilliance and value.', 0, 1.00),
  ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A precious green gemstone with a sparkling appearance.', 0, 1.00),
  ('stolenmerch', 'Stolen Items', 20, 1, 'item_standard', 0, 1, 1, '{}', 'Various stolen items of questionable origin.', 0, 1.00),
  ('acid', 'Acid', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A corrosive substance used for various purposes.', 0, 1.00),
  ('heroin', 'Heroin', 20, 1, 'item_standard', 1, 1, 1, '{}', 'A highly addictive and illegal drug.', 0, 1.00),
  ('alcohol', 'Alcohol', 50, 1, 'item_standard', 1, 1, 1, '{}', 'An intoxicating beverage consumed for recreational purposes.', 0, 1.00),
  ('coal', 'Coal', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A chunk of coal for fuel.', 0, 1.00),
  ('iron', 'Iron', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A strong and durable metal.', 0, 1.00),
  ('clay', 'Clay', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A block of clay for crafting.', 0, 1.00),
  ('salt', 'Salt', 50, 1, 'item_standard', 0, 1, 1, '{}', 'Common salt', 0, 1.00),
  ('ruby', 'Ruby', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A blood red ruby.', 0, 1.00),
  ('sapphire', 'Sapphire', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A deep blue sapphire.', 0, 1.00),
  ('coin_gold_eagle', 'Gold Eagle', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A ten dollar eagle gold coin.', 0, 1.00),
  ('coin_half_eagle', 'Half Eagle', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A five dollar half eagle gold coin.', 0, 1.00),
  ('coin_five_dollar', 'Five Dollar Coin', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A five dollar gold coin.', 0, 1.00),
  ('coin_gold_quarter', 'Gold Quarter', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A gold quarter eagle coin.', 0, 1.00),
  ('coin_gold_dollar', 'Gold Dollar', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A golden dollar coin.', 0, 1.00),
  ('coin_new_yorke', 'New Yorke Token', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A rare New Yorke trade token.', 0, 1.00),
  ('coin_quarter_1792_2', '1792 Quarter (Variant)', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A rare variant quarter from 1792.', 0, 1.00),
  ('coin_quarter_1792', '1792 Quarter', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A quarter dollar from 1792.', 0, 1.00),
  ('coin_half_dime', 'Half Dime', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A small silver half dime coin.', 0, 1.00),
  ('coin_nickel_1792', '1792 Nickel', 50, 1, 'item_standard', 0, 1, 1, '{}', 'An old nickel coin from 1792.', 0, 1.00),
  ('coin_penny_1789', '1789 Penny', 50, 1, 'item_standard', 0, 1, 1, '{}', 'An old copper penny from 1789.', 0, 1.00),
  ('coin_penny_1787', '1787 Penny', 50, 1, 'item_standard', 0, 1, 1, '{}', 'An old copper penny from 1787.', 0, 1.00),
  ('coin_half_penny', '1796 Half Penny', 50, 1, 'item_standard', 0, 1, 1, '{}', 'An old copper half penny coin.', 0, 1.00),
  ('robbery_ledger', 'Robbery Ledger', 5, 1, 'item_standard', 0, 1, 1, '{}', 'A book containing records of houses and valuable targets.', 0, 1.00),
  ('art_golden_chalice', 'Golden Chalice', 5, 1, 'item_standard', 0, 1, 1, '{}', 'A ceremonial golden cup.', 0, 1.00),
  ('antique_jewelry_box', 'Antique Jewelry Box', 5, 1, 'item_standard', 0, 1, 1, '{}', 'An ornate antique jewelry box.', 0, 1.00),
  ('necklace_amethyst_richelieu', 'Amethyst Necklace (Richelieu)', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A highly valuable amethyst necklace.', 0, 1.00),
  ('necklace_amethyst_braxton', 'Amethyst Necklace (Braxton)', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A rare amethyst necklace.', 0, 1.00),
  ('necklace_ancient', 'Ancient Necklace', 20, 1, 'item_standard', 0, 1, 1, '{}', 'An ancient necklace of unknown origin.', 0, 1.00),
  ('necklace_mini_blakely', 'Blakely Miniature Necklace', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A delicate miniature necklace.', 0, 1.00),
  ('platinum_ring', 'Platinum Ring', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A valuable platinum ring.', 0, 1.00),
  ('necklace_gold_cross', 'Gold Cross Necklace', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A gold cross on a chain.', 0, 1.00),
  ('necklace_gold_ring', 'Gold Ring Necklace', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A gold chain with a ring.', 0, 1.00),
  ('necklace_pearl_rou', 'Pearl Necklace', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A beautiful pearl necklace.', 0, 1.00),
  ('necklace_pearl_pelle', 'Pearl Pendant', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A pearl pendant necklace.', 0, 1.00),
  ('pocket_watch', 'Pocket Watch', 5, 1, 'item_standard', 1, 1, 1, '{}', 'A small timepiece designed to be carried in a pocket.', 0, 1.00),
  ('wedding_ring', 'Wedding Ring', 10, 1, 'item_standard', 1, 1, 1, '{}', 'A beautiful wedding ring.', 0, 1.00),
  ('tooth_gold', 'Gold Tooth', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A golden tooth pulled from... somewhere.', 0, 1.00),
  ('silver_ring', 'Silver Ring', 50, 1, 'item_standard', 0, 1, 1, '{}', 'A simple silver ring.', 0, 1.00),
  ('cigar', 'Cigar', 20, 1, 'item_standard', 1, 1, 1, '{}', 'A fine cigar for relaxing.', 0, 1.00),
  -- limit, weight and description are suggested values
  ('sealedpackage', 'Sealed Package', 20, 1, 'item_standard', 0, 1, 1, '{}', 'A tightly bound parcel. Nobody is saying what is inside.', 0, 1.00);
