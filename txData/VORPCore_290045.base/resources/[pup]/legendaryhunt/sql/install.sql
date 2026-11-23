-- legendaryhunt | sql/install.sql
-- Adds the item rows this resource uses. INSERT IGNORE: an item that already exists is left as it is,
-- so running this twice is safe and it never overwrites another resource's row. No tables are created.
-- vorp_inventory reads the items table once at start-up: restart the whole server afterwards.
--
-- The item ids are shared with skinanimals (which hands out the trophies) and with other resources,
-- so keep them exactly as written, including the capital W in Wild_Carrot.

INSERT IGNORE INTO `items`
    (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `useExpired`, `groupId`, `rarityId`, `metadata`, `desc`, `degradation`, `durability`, `instructions`, `weight`)
VALUES
    -- the trap
    ('beartrap', 'Hunting Trap', 3, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A heavy sprung trap. Set it on open ground, put a lure in it and wait for something big.', 0, NULL, NULL, 4.00),
    ('trapoil', 'Trap Oil', 20, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A tin of thin oil for keeping trap springs from rusting.', 0, NULL, NULL, 0.20),

    -- lures (rows other resources may already have added)
    ('biggame', 'Big Game Meat', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A raw, bloody cut from a large animal. Wolves and big cats follow the smell for miles.', 0, NULL, NULL, 0.80),
    ('stringy', 'Stringy Meat', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Gristly scraps that need long cooking. Scavengers are not so fussy.', 0, NULL, NULL, 0.50),
    ('game', 'Game Meat', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Fresh meat from a wild animal, good on a spit or in a stew.', 0, NULL, NULL, 0.60),
    ('fishmeat', 'Bigfish Meat', 20, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Thick fillets and guts from a large fish. Anything that hunts the water comes for it.', 0, NULL, NULL, 0.60),
    ('honey', 'Honey', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Wild honey still in the comb.', 0, NULL, NULL, 0.30),
    ('corn', 'Corn', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'Dried kernels, sweet enough to eat and easy to scatter for hogs.', 0, NULL, NULL, 0.20),
    ('Wild_Carrot', 'Wild Carrot', 50, 1, 'item_standard', 1, 0, 1, 1, '{}', 'A thin, pale root pulled from a meadow. Deer and moose dig for them.', 0, NULL, NULL, 0.10),
    ('salt', 'Salt', 50, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Coarse rock salt. Grazers will walk a long way to lick it.', 0, NULL, NULL, 0.20),

    -- legendary antlers and horns
    ('legendbuckantler', 'Legendary Buck Antlers', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A wide, many-pointed rack from a legendary buck.', 0, NULL, NULL, 1.50),
    ('legelkantler', 'Legendary Elk Antlers', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Sweeping antlers from a legendary elk, still in velvet at the tips.', 0, NULL, NULL, 2.50),
    ('legmooseantler', 'Legendary Moose Antlers', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Broad, flat palms of antler from a legendary moose. Heavy enough to need two hands.', 0, NULL, NULL, 3.50),
    ('legramhorn', 'Legendary Ram Horns', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A full curl of ridged horn from a legendary ram.', 0, NULL, NULL, 2.00),
    ('legbisonhorn', 'Legendary Bison Horns', 10, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Short, thick horns worn smooth by a legendary bison.', 0, NULL, NULL, 2.00),

    -- bears
    ('leggbears', 'Legendary Bear Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A vast, scarred hide off a legendary grizzly. It takes a wagon to carry more than one.', 0, NULL, NULL, 5.00),
    ('legbears1', 'Deadly Bear Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Coarse dark fur from the Deadly Bear, torn along one flank from old fights.', 0, NULL, NULL, 5.00),
    ('legbears2', 'Owiza Bear Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A thick, warm hide from the Owiza Bear, prized for bedrolls.', 0, NULL, NULL, 5.00),
    ('legbears3', 'Ridgeback Spirit Bear Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Pale fur with a raised ridge down the spine, from the Ridgeback Spirit Bear.', 0, NULL, NULL, 5.00),
    ('legbears4', 'Golden Spirit Bear Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A hide that shines gold in the sun, from the Golden Spirit Bear.', 0, NULL, NULL, 5.00),

    -- wolves, coyotes, foxes
    ('legwolfpelt', 'Legendary Wolf Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A long, grizzled pelt from a legendary wolf.', 0, NULL, NULL, 2.50),
    ('legwolfs1', 'Emerald Wolf Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dense pelt from the Emerald Wolf, with a green sheen in some light.', 0, NULL, NULL, 2.50),
    ('legwolfs2', 'Onyx Wolf Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Jet-black fur from the Onyx Wolf.', 0, NULL, NULL, 2.50),
    ('legwolfs3', 'Moonstone Wolf Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Silver-grey fur from the Moonstone Wolf, soft as smoke.', 0, NULL, NULL, 2.50),
    ('legcoyotes', 'Legendary Coyote Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A thin but handsome pelt from a legendary coyote.', 0, NULL, NULL, 1.50),
    ('legcoyotes1', 'Red Streak Coyote Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Tawny fur with a rust-red stripe, from the Red Streak Coyote.', 0, NULL, NULL, 1.50),
    ('legcoyotes2', 'Midnight Paw Coyote Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A light pelt with dark legs, from the Midnight Paw Coyote.', 0, NULL, NULL, 1.50),
    ('legcoyotes3', 'Milk Coyote Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A pale, almost white pelt from the Milk Coyote.', 0, NULL, NULL, 1.50),
    ('legfoxskin', 'Legendary Fox Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A bright, full-tailed pelt from a legendary fox.', 0, NULL, NULL, 1.00),
    ('legfoxs1', 'Ota Fox Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A fine pelt from the Ota Fox, soft enough for a lady''s collar.', 0, NULL, NULL, 1.00),
    ('legfoxs2', 'Marble Fox Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Grey and white fur swirled like stone, from the Marble Fox.', 0, NULL, NULL, 1.00),
    ('legfoxs3', 'Cross Fox Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Red fur crossed with a dark band over the shoulders, from the Cross Fox.', 0, NULL, NULL, 1.00),

    -- big cats
    ('legcougars', 'Legendary Cougar Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A long, supple pelt from a legendary cougar.', 0, NULL, NULL, 2.50),
    ('legcougars1', 'Iguga Cougar Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A sandy pelt from the Iguga Cougar.', 0, NULL, NULL, 2.50),
    ('legcougars2', 'Maza Cougar Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A heavy, dark-tipped pelt from the Maza Cougar.', 0, NULL, NULL, 2.50),
    ('legcougars3', 'Sapa Cougar Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A smoky pelt from the Sapa Cougar.', 0, NULL, NULL, 2.50),
    ('legcougars4', 'Black Cougar Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A rare, near-black pelt from the Black Cougar.', 0, NULL, NULL, 2.50),
    ('legpanthers1', 'Nightwalker Panther Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A glossy black pelt from the Nightwalker Panther.', 0, NULL, NULL, 2.50),
    ('legpanthers2', 'Ghost Panther Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A pale, faintly spotted pelt from the Ghost Panther.', 0, NULL, NULL, 2.50),
    ('legpanthers3', 'Iwakta Panther Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A sleek pelt from the Iwakta Panther, the largest of the three.', 0, NULL, NULL, 2.50),

    -- swamp and water
    ('legaligators', 'Legendary Alligator Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Armoured, knobbled hide from a legendary alligator.', 0, NULL, NULL, 4.00),
    ('legaligators1', 'Teca Alligator Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Dark, ridged hide from the Teca Alligator.', 0, NULL, NULL, 4.00),
    ('legaligators2', 'Sun Alligator Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A yellow-banded hide from the Sun Alligator.', 0, NULL, NULL, 4.00),
    ('legaligators3', 'Banded Alligator Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A hide striped light and dark, from the Banded Alligator.', 0, NULL, NULL, 4.00),
    ('legendsnakes', 'Legendary Boa Skin', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Ten feet of patterned skin from a legendary boa.', 0, NULL, NULL, 1.50),
    ('legbeawers', 'Legendary Beaver Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A thick, water-shedding pelt from a legendary beaver.', 0, NULL, NULL, 1.50),
    ('legbeavers1', 'Grey Beaver Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dense grey pelt from the Grey Beaver.', 0, NULL, NULL, 1.50),
    ('legbeavers2', 'White Beaver Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'An unusual pale pelt from the White Beaver.', 0, NULL, NULL, 1.50),
    ('legbeavers3', 'Black Beaver Pelt', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A deep black pelt from the Black Beaver, the hatters'' favourite.', 0, NULL, NULL, 1.50),

    -- boars
    ('legboars', 'Legendary Boar Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'Bristled, tough hide from a legendary boar.', 0, NULL, NULL, 3.00),
    ('legboars1', 'Cogi Boar Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A reddish, bristled hide from the Cogi Boar.', 0, NULL, NULL, 3.00),
    ('legboars2', 'Wakpa Boar Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dark, mud-caked hide from the Wakpa Boar.', 0, NULL, NULL, 3.00),
    ('legboars3', 'Icahi Boar Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A mottled hide from the Icahi Boar.', 0, NULL, NULL, 3.00),
    ('legboars4', 'Wildhog Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A scarred, wiry hide from the Legendary Wildhog.', 0, NULL, NULL, 3.00),

    -- deer, elk and moose
    ('legbucks', 'Legendary Whitetail Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A clean, pale-bellied hide from a legendary whitetail buck.', 0, NULL, NULL, 2.00),
    ('legbucks1', 'Legendary Buck Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A fine, even hide from a legendary buck.', 0, NULL, NULL, 2.00),
    ('legbucks2', 'Mudrunner Buck Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A brown hide splashed darker at the legs, from the Mudrunner Buck.', 0, NULL, NULL, 2.00),
    ('legbucks3', 'Snow Buck Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A white winter hide from the Snow Buck.', 0, NULL, NULL, 2.00),
    ('legbucks4', 'Shadow Buck Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dusky, almost black hide from the Shadow Buck.', 0, NULL, NULL, 2.00),
    ('legelks', 'Legendary Elk Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A big, heavy-maned hide from a legendary elk.', 0, NULL, NULL, 3.50),
    ('legelks1', 'Katata Elk Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A tawny hide from the Katata Elk.', 0, NULL, NULL, 3.50),
    ('legelks2', 'Ozula Elk Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dark-necked hide from the Ozula Elk.', 0, NULL, NULL, 3.50),
    ('legelks3', 'Inahme Elk Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A pale, frosted hide from the Inahme Elk.', 0, NULL, NULL, 3.50),
    ('legmooses', 'Legendary Moose Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A huge, coarse hide from a legendary moose.', 0, NULL, NULL, 4.50),
    ('legmooses1', 'Snowflake Moose Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A hide flecked with white, from the Snowflake Moose.', 0, NULL, NULL, 4.50),
    ('legmooses2', 'Knight Moose Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dark, stately hide from the Knight Moose.', 0, NULL, NULL, 4.50),
    ('legmooses3', 'Ruddy Moose Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A red-brown hide from the Ruddy Moose.', 0, NULL, NULL, 4.50),

    -- rams, bison and pronghorn
    ('legrams', 'Legendary Ram Fleece', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A thick, curled fleece from a legendary bighorn.', 0, NULL, NULL, 2.50),
    ('legrams1', 'Gabbro Horn Ram Fleece', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dark grey fleece from the Gabbro Horn Ram.', 0, NULL, NULL, 2.50),
    ('legrams2', 'Chalk Horn Ram Fleece', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A chalk-pale fleece from the Chalk Horn Ram.', 0, NULL, NULL, 2.50),
    ('legrams3', 'Rutile Horn Ram Fleece', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A fleece with a coppery cast, from the Rutile Horn Ram.', 0, NULL, NULL, 2.50),
    ('legrams4', 'Great Horn Ram Fleece', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'The heaviest fleece of any ram, from the Great Horn Ram.', 0, NULL, NULL, 2.50),
    ('legbisons', 'Legendary Bison Robe', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A shaggy robe from a legendary bison. Warm enough for a Grizzlies winter.', 0, NULL, NULL, 5.00),
    ('legbisons1', 'Tatanka Bison Robe', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A dark, heavy robe from the Tatanka Bison.', 0, NULL, NULL, 5.00),
    ('legbisons2', 'Winyan Bison Robe', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A lighter, red-brown robe from the Winyan Bison.', 0, NULL, NULL, 5.00),
    ('legbisons3', 'Payata Bison Robe', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A pale-shouldered robe from the Payata Bison.', 0, NULL, NULL, 5.00),
    ('legbisonstak', 'Great Tatanka Bison Robe', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'The largest robe the plains have to give, from the great Tatanka bull.', 0, NULL, NULL, 6.00),
    ('legprongs', 'Legendary Pronghorn Hide', 5, 1, 'item_standard', 0, 0, 1, 1, '{}', 'A light, banded hide from a legendary pronghorn.', 0, NULL, NULL, 1.50);
