-- huntingbirds | sql/install.sql
--
-- Creates: the `birds` table (one row per bird a character owns).
-- Items:   the bird call and every item a scavenging bird can bring back.
-- Safe to run more than once: CREATE TABLE IF NOT EXISTS and INSERT IGNORE never change existing rows.
-- vorp_inventory caches the items table, so restart the whole server after running this.

CREATE TABLE IF NOT EXISTS `birds` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(60) NOT NULL,
    `charid` INT(11) NOT NULL,
    `model` INT(11) NOT NULL,
    `name` VARCHAR(50) NOT NULL,
    `preset` INT(11) NOT NULL DEFAULT 0,
    `xp` INT(11) NOT NULL DEFAULT 0,
    `price` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner` (`identifier`, `charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `items`
    (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
    ('ammoarrmownormal', 'Normal Arrow Ammo', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('ammorepeaternormal', 'Repeater Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with repeater rifles for self-defense and combat.', 0, NULL, NULL, 1.00),
    ('ammorevolvernormal', 'Revolver Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with revolvers for self-defense and combat.', 0, NULL, NULL, 1.00),
    ('ammoriflenormal', 'Rifle Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with rifles for self-defense and combat.', 0, NULL, NULL, 1.00),
    ('ammoshotgunnormal', 'Shotgun Ammo Normal', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Standard ammunition used with shotguns for self-defense and combat.', 0, NULL, NULL, 1.00),
    ('birdcall', 'Bird Call', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('Black_Berry_Seed', 'Black Berry Seed', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A seed that can be planted to grow blackberries.', 0, NULL, NULL, 1.00),
    ('cigar', 'Cigar', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A fine cigar for relaxing.', 0, NULL, NULL, 1.00),
    ('cigarette', 'Cigarette', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A cigarette for a quick smoke.', 0, NULL, NULL, 1.00),
    ('cocoa', 'Cocoa', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Cocoa beans for making chocolate.', 0, NULL, NULL, 1.00),
    ('copper', 'Copper', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A piece of copper.', 0, NULL, NULL, 1.00),
    ('diamond', 'Diamond', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious gemstone known for its brilliance and value.', 0, NULL, NULL, 1.00),
    ('dynamite', 'Pipe Charge Dynamite', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'An explosive device consisting of a tube filled with explosive material, used for various purposes including mining and demolition.', 0, NULL, NULL, 1.00),
    ('egg', 'Egg', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A small oval object laid by a female bird, reptile, or fish, containing a fertilized embryo and nutrients for development.', 0, NULL, NULL, 1.00),
    ('emerald', 'Emerald', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A precious green gemstone with a sparkling appearance.', 0, NULL, NULL, 1.00),
    ('goldnugget', 'Gold Nugget', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('hop_seed', 'Hop Seed', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A seed that can be planted to grow hop plants.', 0, NULL, NULL, 1.00),
    ('iron', 'Iron', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A strong and durable metal.', 0, NULL, NULL, 1.00),
    ('ironbar', 'Iron Bar', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A solid bar made of iron, known for its strength and durability.', 0, NULL, NULL, 1.00),
    ('opium', 'Opium', 25, 1, 'item_standard', 1, 0, 1, 1, '{}', 'nice item', 0, NULL, NULL, 1.00),
    ('pipe', 'Pipe', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A tubular device used for smoking tobacco or other substances.', 0, NULL, NULL, 1.00),
    ('pocket_watch', 'Pocket Watch', 5, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A small timepiece designed to be carried in a pocket.', 0, NULL, NULL, 1.00),
    ('pulp', 'Pulp', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A soft and moist mass of plant fibers, typically obtained from crushing or processing plant materials.', 0, NULL, NULL, 1.00),
    ('Red_Sage_Seed', 'Red Sage Seed', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A seed that can be planted to grow red sage plants.', 0, NULL, NULL, 1.00),
    ('sap', 'Sap', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Sticky sap', 0, NULL, NULL, 1.00),
    ('tylenol', 'Tylenol', 10, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A medication called Tylenol.', 0, NULL, NULL, 1.00),
    ('Wild_Carrot', 'Wild Carrot', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A type of carrot that grows in the wild.', 0, NULL, NULL, 1.00);
