-- legendaryhunt | the fur buyer's counter
-- buy  = what he sells. sell = what he pays for, in groups; every group shows in the menu, in this order.
-- Each row: { item, label, price } (dollars). The server reads its own copy of this file.
-- Meat lures are not on his shelf: hunters bring their own from skinning.

Config.Shop = {
    title    = 'Fur Buyer',
    subtitle = 'Traps, lures and trophies',

    buy = {
        title    = 'Trapping Supplies',
        subtitle = 'What he keeps on the shelf',
        desc     = 'Pay and take one',
        rows = {
            { 'beartrap',    'Hunting Trap',  40 },
            { 'salt',        'Salt Lick',      3 },
            { 'corn',        'Cracked Corn',   3 },
            { 'Wild_Carrot', 'Wild Carrots',   3 },
            { 'honey',       'Honeycomb',      4 },
        },
    },

    sell = {
        title    = 'Sell Trophies',
        subtitle = 'He pays for proof of a great beast',
        desc     = 'Hand one over',
        groups = {
            {
                label = 'Bears',
                rows = {
                    { 'leggbears', 'Legendary Bear Hide',          185 },
                    { 'legbears1', 'Deadly Bear Hide',             170 },
                    { 'legbears2', 'Owiza Bear Hide',              170 },
                    { 'legbears3', 'Ridgeback Spirit Bear Hide',   175 },
                    { 'legbears4', 'Golden Spirit Bear Hide',      180 },
                },
            },
            {
                label = 'Wolves, Coyotes and Foxes',
                rows = {
                    { 'legwolfpelt', 'Legendary Wolf Pelt',        135 },
                    { 'legwolfs1',   'Emerald Wolf Pelt',          130 },
                    { 'legwolfs2',   'Onyx Wolf Pelt',             130 },
                    { 'legwolfs3',   'Moonstone Wolf Pelt',        130 },
                    { 'legcoyotes',  'Legendary Coyote Pelt',       80 },
                    { 'legcoyotes1', 'Red Streak Coyote Pelt',      75 },
                    { 'legcoyotes2', 'Midnight Paw Coyote Pelt',    75 },
                    { 'legcoyotes3', 'Milk Coyote Pelt',            75 },
                    { 'legfoxskin',  'Legendary Fox Pelt',          90 },
                    { 'legfoxs1',    'Ota Fox Pelt',                85 },
                    { 'legfoxs2',    'Marble Fox Pelt',             85 },
                    { 'legfoxs3',    'Cross Fox Pelt',              85 },
                },
            },
            {
                label = 'Big Cats',
                rows = {
                    { 'legcougars',   'Legendary Cougar Pelt',      140 },
                    { 'legcougars1',  'Iguga Cougar Pelt',          135 },
                    { 'legcougars2',  'Maza Cougar Pelt',           135 },
                    { 'legcougars3',  'Sapa Cougar Pelt',           135 },
                    { 'legcougars4',  'Black Cougar Pelt',          145 },
                    { 'legpanthers1', 'Nightwalker Panther Pelt',   150 },
                    { 'legpanthers2', 'Ghost Panther Pelt',         150 },
                    { 'legpanthers3', 'Iwakta Panther Pelt',        155 },
                },
            },
            {
                label = 'Swamp and Water',
                rows = {
                    { 'legaligators',  'Legendary Alligator Hide',  145 },
                    { 'legaligators1', 'Teca Alligator Hide',       140 },
                    { 'legaligators2', 'Sun Alligator Hide',        140 },
                    { 'legaligators3', 'Banded Alligator Hide',     140 },
                    { 'legendsnakes',  'Legendary Boa Skin',         95 },
                    { 'legbeawers',    'Legendary Beaver Pelt',      90 },
                    { 'legbeavers1',   'Grey Beaver Pelt',           85 },
                    { 'legbeavers2',   'White Beaver Pelt',          85 },
                    { 'legbeavers3',   'Black Beaver Pelt',          85 },
                },
            },
            {
                label = 'Boars',
                rows = {
                    { 'legboars',  'Legendary Boar Hide',   115 },
                    { 'legboars1', 'Cogi Boar Hide',        105 },
                    { 'legboars2', 'Wakpa Boar Hide',       105 },
                    { 'legboars3', 'Icahi Boar Hide',       105 },
                    { 'legboars4', 'Wildhog Hide',          110 },
                },
            },
            {
                label = 'Deer, Elk and Moose',
                rows = {
                    { 'legbucks',   'Legendary Whitetail Hide', 110 },
                    { 'legbucks1',  'Legendary Buck Hide',      110 },
                    { 'legbucks2',  'Mudrunner Buck Hide',      110 },
                    { 'legbucks3',  'Snow Buck Hide',           115 },
                    { 'legbucks4',  'Shadow Buck Hide',         115 },
                    { 'legelks',    'Legendary Elk Hide',       125 },
                    { 'legelks1',   'Katata Elk Hide',          120 },
                    { 'legelks2',   'Ozula Elk Hide',           120 },
                    { 'legelks3',   'Inahme Elk Hide',          120 },
                    { 'legmooses',  'Legendary Moose Hide',     135 },
                    { 'legmooses1', 'Snowflake Moose Hide',     130 },
                    { 'legmooses2', 'Knight Moose Hide',        130 },
                    { 'legmooses3', 'Ruddy Moose Hide',         130 },
                },
            },
            {
                label = 'Rams, Bison and Pronghorn',
                rows = {
                    { 'legrams',      'Legendary Ram Fleece',     115 },
                    { 'legrams1',     'Gabbro Horn Ram Fleece',   110 },
                    { 'legrams2',     'Chalk Horn Ram Fleece',    110 },
                    { 'legrams3',     'Rutile Horn Ram Fleece',   110 },
                    { 'legrams4',     'Great Horn Ram Fleece',    120 },
                    { 'legbisons',    'Legendary Bison Robe',     150 },
                    { 'legbisons1',   'Tatanka Bison Robe',       145 },
                    { 'legbisons2',   'Winyan Bison Robe',        145 },
                    { 'legbisons3',   'Payata Bison Robe',        145 },
                    { 'legbisonstak', 'Great Tatanka Bison Robe', 160 },
                    { 'legprongs',    'Legendary Pronghorn Hide',  95 },
                },
            },
            {
                label = 'Antlers and Horns',
                rows = {
                    { 'legendbuckantler', 'Legendary Buck Antlers',  40 },
                    { 'legelkantler',     'Legendary Elk Antlers',   45 },
                    { 'legmooseantler',   'Legendary Moose Antlers', 50 },
                    { 'legramhorn',       'Legendary Ram Horns',     45 },
                    { 'legbisonhorn',     'Legendary Bison Horns',   50 },
                },
            },
        },
    },
}
