-- skinanimals | config/animals.lua
-- Three tables:
--   Config.Yields      what a kind of animal gives: up to three item ids, paid in this order
--   Config.Animals     ped model -> yield (any outfit)
--   Config.Legendaries ped model + meta outfit hash -> its own three items (counts as Legendary)
-- A legendary row is checked before the plain row of the same model, so a legendary outfit pays
-- its trophy and every other outfit of that model pays the plain yield.
-- Item labels shown to the player are in Config.Labels at the bottom.

Config.Yields = {
    -- big game
    grizzly    = { 'biggame', 'gbears', 'beart' },
    blackbear  = { 'biggame', 'bbears', 'bearc' },
    wolf       = { 'stringy', 'wolfpelt', 'wolftooth' },
    cougar     = { 'game', 'cougars', 'cougarf' },
    panther    = { 'game', 'panthers', 'panthere' },
    coyote     = { 'stringy', 'coyotes', 'coyotef' },
    fox        = { 'game', 'foxskin', 'foxt' },
    alligator  = { 'herptile', 'aligators', 'aligatorto' },

    -- antlers and horns
    doe        = { 'venison', 'deerskin', 'deerheart' },
    buck       = { 'venison', 'bucks', 'buckantler' },
    elk        = { 'venison', 'elks', 'elkantler' },
    moose      = { 'biggame', 'mooses', 'mooseantler' },
    pronghorn  = { 'venison', 'prongs', 'pronghornh' },
    bison      = { 'biggame', 'bisons', 'bisonhorn' },
    ram        = { 'mutton', 'rams', 'ramhorn' },
    goat       = { 'mutton', 'goats' },

    -- farm stock
    sheep      = { 'mutton', 'wool', 'sheephead' },
    cow        = { 'beef', 'cows', 'cowh' },
    bull       = { 'beef', 'bulls', 'bullhorn' },
    ox         = { 'beef', 'oxs', 'oxhorn' },
    pig        = { 'pork', 'pigs', 'porkfat' },

    -- wild hogs
    boar       = { 'pork', 'porkfat', 'boarmusk' },
    javelina   = { 'pork', 'pecaris', 'boarmusk' },

    -- small fur
    beaver     = { 'game', 'beawers', 'beavertail' },
    muskrat    = { 'game', 'muskrats', 'scentg' },
    badger     = { 'game', 'badgers', 'scentg' },
    skunk      = { 'stringy', 'scentg' },
    raccoon    = { 'game', 'raccoons', 'raccoont' },
    possum     = { 'stringy', 'opossums', 'opossumc' },
    rabbit     = { 'game', 'rabbits', 'rabbitpaw' },
    armadillo  = { 'herptile', 'armadillos', 'armadilloc' },

    -- reptiles
    rattler    = { 'herptile', 'fsnakes', 'Snake_Poison' },
    ferdelance = { 'herptile', 'asnakes', 'Snake_Poison' },
    boa        = { 'herptile', 'boaskin' },
    watersnake = { 'herptile', 'wsnakeskin' },
    iguana     = { 'herptile', 'gleguans' },
    desertiguana = { 'herptile', 'dleguans' },
    gila       = { 'herptile', 'lizards', 'lizardl' },
    turtle     = { 'herptile', 'turtleshell', 'turtlet' },

    -- birds of prey and carrion birds
    eagle      = { 'bird', 'eaglef', 'eaglet' },
    hawk       = { 'bird', 'hawkf', 'hawkt' },
    owl        = { 'bird', 'owlf', 'owlt' },
    condor     = { 'bird', 'kcondorf', 'kcondorb' },
    vulture    = { 'bird', 'condorf', 'condorb' },
    raven      = { 'bird', 'ravenf', 'ravenc' },

    -- water and shore birds
    heron      = { 'bird', 'kbirdf', 'kbirdb' },
    egret      = { 'bird', 'egretf', 'egretb' },
    spoonbill  = { 'bird', 'rspoonf', 'rspoonb' },
    crane      = { 'bird', 'daruf', 'darub' },
    pelican    = { 'bird', 'pelicanf', 'pelicanb' },
    cormorant  = { 'bird', 'bbirdf', 'bbirdb' },
    loon       = { 'bird', 'loonf', 'loonb' },
    gull       = { 'bird', 'seagullf', 'seagullb' },
    booby      = { 'bird', 'boobyf', 'boobyb' },
    duck       = { 'bird', 'duckfat', 'Feather' },
    goose      = { 'bird', 'goosef', 'gooseb' },

    -- game birds and poultry
    turkey     = { 'bird', 'turkeyf', 'turkeyb' },
    pheasant   = { 'bird', 'peasantf', 'peasantb' },
    quail      = { 'bird', 'quailf', 'quailb' },
    prairiehen = { 'bird', 'prairif', 'prairib' },
    hen        = { 'bird', 'chickenf', 'chickenheart' },
    rooster    = { 'bird', 'cockf', 'cockc' },
    parrot     = { 'bparrotf', 'bparrotb' },

    -- whole small carcasses: one item, the carcass itself
    crow       = { 'crow_c' },
    pigeon     = { 'pigeon_c' },
    robin      = { 'robin_c' },
    sparrow    = { 'sparrow1_c' },
    songbird   = { 'songbird_c' },
    cardinal   = { 'cardinal_c' },
    bluejay    = { 'bluejay_c' },
    waxwing    = { 'cedarwaxwing_c' },
    oriole     = { 'oriole_c' },
    woodpecker = { 'woodpeck01_c' },
    woodpecker2 = { 'woodpeck02_c' },
    chipmunk   = { 'chipmunk_c' },
    squirrel   = { 'squirrel_grey_c' },
    rat        = { 'rat_c' },
    bat        = { 'bat_c' },
    toad       = { 'toad_c' },
    bullfrog   = { 'frogbull_c' },
    crab       = { 'crab_c' },
    crawfish   = { 'crawfish_c' },

    -- fish: sea fish give a fillet; river and lake fish give the fish itself (item id = model name)
    seafish    = { 'fishmeat' },
}

-- { name, model, yield }. Name is only used in the Discord skinning log.
Config.Animals = {
    -- big game
    { 'Grizzly Bear',          `a_c_bear_01`,                 'grizzly' },
    { 'Grizzly Bear',          `mp_a_c_bear_01`,              'grizzly' },
    { 'Black Bear',            `a_c_bearblack_01`,            'blackbear' },
    { 'Grey Wolf',             `a_c_wolf`,                    'wolf' },
    { 'Grey Wolf',             `a_c_wolf_medium`,             'wolf' },
    { 'Grey Wolf',             `a_c_wolf_small`,              'wolf' },
    { 'Grey Wolf',             `mp_a_c_wolf_01`,              'wolf' },
    { 'Cougar',                `a_c_cougar_01`,               'cougar' },
    { 'Cougar',                `mp_a_c_cougar_01`,            'cougar' },
    { 'Mangy Lion',            `a_c_lionmangy_01`,            'cougar' },
    { 'Panther',               `a_c_panther_01`,              'panther' },
    { 'Panther',               `mp_a_c_panther_01`,           'panther' },
    { 'Coyote',                `a_c_coyote_01`,               'coyote' },
    { 'Coyote',                `mp_a_c_coyote_01`,            'coyote' },
    { 'Fox',                   `a_c_fox_01`,                  'fox' },
    { 'Fox',                   `mp_a_c_fox_01`,               'fox' },
    { 'Alligator',             `a_c_alligator_01`,            'alligator' },
    { 'Small Alligator',       `a_c_alligator_03`,            'alligator' },
    { 'Alligator',             `mp_a_c_alligator_01`,         'alligator' },

    -- antlers and horns
    { 'Whitetail Deer',        `a_c_deer_01`,                 'doe' },
    { 'Whitetail Deer',        `mp_a_c_deer_01`,              'doe' },
    { 'Whitetail Buck',        `a_c_buck_01`,                 'buck' },
    { 'Whitetail Buck',        `mp_a_c_buck_01`,              'buck' },
    { 'Elk',                   `a_c_elk_01`,                  'elk' },
    { 'Elk',                   `mp_a_c_elk_01`,               'elk' },
    { 'Moose',                 `a_c_moose_01`,                'moose' },
    { 'Moose',                 `mp_a_c_moose_01`,             'moose' },
    { 'Pronghorn',             `a_c_pronghorn_01`,            'pronghorn' },
    { 'Pronghorn',             `mp_a_c_pronghorn_01`,         'pronghorn' },
    { 'American Bison',        `a_c_buffalo_01`,              'bison' },
    { 'American Bison',        `mp_a_c_buffalo_01`,           'bison' },
    { 'Bighorn Sheep',         `a_c_bighornram_01`,           'ram' },
    { 'Bighorn Sheep',         `mp_a_c_bighornram_01`,        'ram' },
    { 'Goat',                  `a_c_goat_01`,                 'goat' },

    -- farm stock
    { 'Sheep',                 `a_c_sheep_01`,                'sheep' },
    { 'Sheep',                 `mp_a_c_sheep_01`,             'sheep' },
    { 'Cow',                   `a_c_cow`,                     'cow' },
    { 'Bull',                  `a_c_bull_01`,                 'bull' },
    { 'Ox',                    `a_c_ox_01`,                   'ox' },
    { 'Pig',                   `a_c_pig_01`,                  'pig' },

    -- wild hogs
    { 'Wild Boar',             `a_c_boar_01`,                 'boar' },
    { 'Wild Boar',             `mp_a_c_boar_01`,              'boar' },
    { 'Javelina',              `a_c_javelina_01`,             'javelina' },

    -- small fur
    { 'Beaver',                `a_c_beaver_01`,               'beaver' },
    { 'Beaver',                `mp_a_c_beaver_01`,            'beaver' },
    { 'Muskrat',               `a_c_muskrat_01`,              'muskrat' },
    { 'Badger',                `a_c_badger_01`,               'badger' },
    { 'Skunk',                 `a_c_skunk_01`,                'skunk' },
    { 'Raccoon',               `a_c_raccoon_01`,              'raccoon' },
    { 'Opossum',               `a_c_possum_01`,               'possum' },
    { 'Opossum',               `mp_a_c_possum_01`,            'possum' },
    { 'Rabbit',                `a_c_rabbit_01`,               'rabbit' },
    { 'Rabbit',                `mp_a_c_rabbit_01`,            'rabbit' },
    { 'Armadillo',             `a_c_armadillo_01`,            'armadillo' },

    -- reptiles
    { 'Rattlesnake',           `a_c_snake_01`,                'rattler' },
    { 'Black-tailed Rattlesnake', `a_c_snakeblacktailrattle_01`, 'rattler' },
    { 'Fer-de-Lance',          `a_c_snakeferdelance_01`,      'ferdelance' },
    { 'Red Boa',               `a_c_snakeredboa_01`,          'boa' },
    { 'Water Snake',           `a_c_snakewater_01`,           'watersnake' },
    { 'Green Iguana',          `a_c_iguana_01`,               'iguana' },
    { 'Desert Iguana',         `a_c_iguanadesert_01`,         'desertiguana' },
    { 'Gila Monster',          `a_c_gilamonster_01`,          'gila' },
    { 'Snapping Turtle',       `a_c_turtlesnapping_01`,       'turtle' },
    { 'Sea Turtle',            `a_c_turtlesea_01`,            'turtle' },

    -- birds of prey and carrion birds
    { 'Bald Eagle',            `a_c_eagle_01`,                'eagle' },
    { 'Hawk',                  `a_c_hawk_01`,                 'hawk' },
    { 'Owl',                   `a_c_owl_01`,                  'owl' },
    { 'Owl',                   `mp_a_c_owl_01`,               'owl' },
    { 'California Condor',     `a_c_californiacondor_01`,     'condor' },
    { 'Vulture',               `a_c_vulture_01`,              'vulture' },
    { 'Raven',                 `a_c_raven_01`,                'raven' },

    -- water and shore birds
    { 'Great Blue Heron',      `a_c_heron_01`,                'heron' },
    { 'Egret',                 `a_c_egret_01`,                'egret' },
    { 'Roseate Spoonbill',     `a_c_roseatespoonbill_01`,     'spoonbill' },
    { 'Whooping Crane',        `a_c_cranewhooping_01`,        'crane' },
    { 'Pelican',               `a_c_pelican_01`,              'pelican' },
    { 'Cormorant',             `a_c_cormorant_01`,            'cormorant' },
    { 'Loon',                  `a_c_loon_01`,                 'loon' },
    { 'Seagull',               `a_c_seagull_01`,              'gull' },
    { 'Red-footed Booby',      `a_c_redfootedbooby_01`,       'booby' },
    { 'Duck',                  `a_c_duck_01`,                 'duck' },
    { 'Canada Goose',          `a_c_goosecanada_01`,          'goose' },

    -- game birds and poultry
    { 'Turkey',                `a_c_turkey_01`,               'turkey' },
    { 'Turkey',                `a_c_turkey_02`,               'turkey' },
    { 'Wild Turkey',           `a_c_turkeywild_01`,           'turkey' },
    { 'Pheasant',              `a_c_pheasant_01`,             'pheasant' },
    { 'Quail',                 `a_c_quail_01`,                'quail' },
    { 'Prairie Chicken',       `a_c_prairiechicken_01`,       'prairiehen' },
    { 'Chicken',               `a_c_chicken_01`,              'hen' },
    { 'Chicken',               `mp_a_c_chicken_01`,           'hen' },
    { 'Rooster',               `a_c_rooster_01`,              'rooster' },
    { 'Parrot',                `a_c_parrot_01`,               'parrot' },
    { 'Carolina Parakeet',     `a_c_carolinaparakeet_01`,     'parrot' },

    -- whole small carcasses
    { 'Crow',                  `a_c_crow_01`,                 'crow' },
    { 'Pigeon',                `a_c_pigeon`,                  'pigeon' },
    { 'Robin',                 `a_c_robin_01`,                'robin' },
    { 'Sparrow',               `a_c_sparrow_01`,              'sparrow' },
    { 'Songbird',              `a_c_songbird_01`,             'songbird' },
    { 'Cardinal',              `a_c_cardinal_01`,             'cardinal' },
    { 'Blue Jay',              `a_c_bluejay_01`,              'bluejay' },
    { 'Cedar Waxwing',         `a_c_cedarwaxwing_01`,         'waxwing' },
    { 'Oriole',                `a_c_oriole_01`,               'oriole' },
    { 'Woodpecker',            `a_c_woodpecker_01`,           'woodpecker' },
    { 'Woodpecker',            `a_c_woodpecker_02`,           'woodpecker2' },
    { 'Chipmunk',              `a_c_chipmunk_01`,             'chipmunk' },
    { 'Squirrel',              `a_c_squirrel_01`,             'squirrel' },
    { 'Rat',                   `a_c_rat_01`,                  'rat' },
    { 'Bat',                   `a_c_bat_01`,                  'bat' },
    { 'Toad',                  `a_c_toad_01`,                 'toad' },
    { 'Bullfrog',              `a_c_frogbull_01`,             'bullfrog' },
    { 'Crab',                  `a_c_crab_01`,                 'crab' },
    { 'Crawfish',              `a_c_crawfish_01`,             'crawfish' },

    -- sea fish
    { 'Hammerhead Shark',      `a_c_sharkhammerhead_01`,      'seafish' },
    { 'Tiger Shark',           `a_c_sharktiger`,              'seafish' },
}

-- River and lake fish: the carcass gives the fish item of the same name (the fishing convention).
-- Listed by model name only; the yield is built from the name.
Config.Fish = {
    'a_c_fishbluegil_01_sm', 'a_c_fishbluegil_01_ms',
    'a_c_fishbullheadcat_01_sm', 'a_c_fishbullheadcat_01_ms',
    'a_c_fishchainpickerel_01_sm', 'a_c_fishchainpickerel_01_ms',
    'a_c_fishperch_01_sm', 'a_c_fishperch_01_ms',
    'a_c_fishredfinpickerel_01_sm', 'a_c_fishredfinpickerel_01_ms',
    'a_c_fishrockbass_01_sm', 'a_c_fishrockbass_01_ms',
    'a_c_fishlargemouthbass_01_ms', 'a_c_fishlargemouthbass_01_lg',
    'a_c_fishsmallmouthbass_01_ms', 'a_c_fishsmallmouthbass_01_lg',
    'a_c_fishrainbowtrout_01_ms', 'a_c_fishrainbowtrout_01_lg',
    'a_c_fishsalmonsockeye_01_ms', 'a_c_fishsalmonsockeye_01_ml', 'a_c_fishsalmonsockeye_01_lg',
    'a_c_fishchannelcatfish_01_lg', 'a_c_fishchannelcatfish_01_xl',
    'a_c_fishlakesturgeon_01_lg', 'a_c_fishlongnosegar_01_lg',
    'a_c_fishmuskie_01_lg', 'a_c_fishnorthernpike_01_lg',
}

-- { name, model, meta outfit hash or false (any outfit), { meat, trophy, part } }
-- Names, models and outfit hashes are the game's legendary animals.
Config.Legendaries = {
    -- bears
    { 'Legendary Deadly Bear',           `mp_a_c_bear_01`,         892552081,   { 'biggame', 'legbears1', 'beart' } },
    { 'Legendary Owiza Bear',            `mp_a_c_bear_01`,         -1508185179, { 'biggame', 'legbears2', 'beart' } },
    { 'Legendary Ridgeback Spirit Bear', `mp_a_c_bear_01`,         -1210544352, { 'biggame', 'legbears3', 'beart' } },
    { 'Legendary Golden Spirit Bear',    `mp_a_c_bear_01`,         -147271932,  { 'biggame', 'legbears4', 'beart' } },
    { 'Legendary Bear',                  `a_c_bear_01`,            -1508185179, { 'biggame', 'leggbears', 'beart' } },

    -- wolves
    { 'Legendary Emerald Wolf',          `mp_a_c_wolf_01`,         263659570,   { 'stringy', 'legwolfs1', 'wolftooth' } },
    { 'Legendary Onyx Wolf',             `mp_a_c_wolf_01`,         -1657259210, { 'stringy', 'legwolfs2', 'wolftooth' } },
    { 'Legendary Moonstone Wolf',        `mp_a_c_wolf_01`,         -1428269438, { 'stringy', 'legwolfs3', 'wolftooth' } },
    { 'Legendary Wolf',                  `a_c_wolf`,               922027494,   { 'stringy', 'legwolfpelt', 'wolftooth' } },

    -- big cats
    { 'Legendary Iguga Cougar',          `mp_a_c_cougar_01`,       2096045552,  { 'game', 'legcougars1', 'cougarf' } },
    { 'Legendary Maza Cougar',           `mp_a_c_cougar_01`,       -835665806,  { 'game', 'legcougars2', 'cougarf' } },
    { 'Legendary Sapa Cougar',           `mp_a_c_cougar_01`,       693761739,   { 'game', 'legcougars3', 'cougarf' } },
    { 'Legendary Black Cougar',          `mp_a_c_cougar_01`,       -435549190,  { 'game', 'legcougars4', 'cougarf' } },
    { 'Legendary Giaguaro Cougar',       `a_c_cougar_01`,          -841151793,  { 'game', 'legcougars', 'cougarf' } },
    { 'Legendary Tiger Cougar',          `a_c_cougar_01`,          1095382564,  { 'game', 'legcougars', 'cougarf' } },
    { 'Legendary Nightwalker Panther',   `mp_a_c_panther_01`,      968333004,   { 'game', 'legpanthers1', 'panthere' } },
    { 'Legendary Ghost Panther',         `mp_a_c_panther_01`,      -606676212,  { 'game', 'legpanthers2', 'panthere' } },
    { 'Legendary Iwakta Panther',        `mp_a_c_panther_01`,      -360941481,  { 'game', 'legpanthers3', 'panthere' } },

    -- coyotes and foxes
    { 'Legendary Red Streak Coyote',     `mp_a_c_coyote_01`,       807110531,   { 'stringy', 'legcoyotes1', 'coyotef' } },
    { 'Legendary Midnight Paw Coyote',   `mp_a_c_coyote_01`,       1662119255,  { 'stringy', 'legcoyotes2', 'coyotef' } },
    { 'Legendary Milk Coyote',           `mp_a_c_coyote_01`,       1155641591,  { 'stringy', 'legcoyotes3', 'coyotef' } },
    { 'Legendary Coyote',                `a_c_coyote_01`,          375593826,   { 'stringy', 'legcoyotes', 'coyotef' } },
    { 'Legendary Ota Fox',               `mp_a_c_fox_01`,          -1558958207, { 'game', 'legfoxs1', 'foxt' } },
    { 'Legendary Marble Fox',            `mp_a_c_fox_01`,          -1936391549, { 'game', 'legfoxs2', 'foxt' } },
    { 'Legendary Cross Fox',             `mp_a_c_fox_01`,          131922197,   { 'game', 'legfoxs3', 'foxt' } },
    { 'Legendary Fox',                   `a_c_fox_01`,             725155934,   { 'game', 'legfoxskin', 'foxt' } },

    -- swamp and water
    { 'Legendary Teca Alligator',        `mp_a_c_alligator_01`,    1659735712,  { 'herptile', 'legaligators1', 'aligatorto' } },
    { 'Legendary Sun Alligator',         `mp_a_c_alligator_01`,    -972401444,  { 'herptile', 'legaligators2', 'aligatorto' } },
    { 'Legendary Banded Alligator',      `mp_a_c_alligator_01`,    -1203226280, { 'herptile', 'legaligators3', 'aligatorto' } },
    { 'Legendary Bullgator',             `a_c_alligator_02`,       false,       { 'herptile', 'legaligators', 'aligatorto' } },
    { 'Legendary Boa',                   `a_c_snakeredboa10ft_01`, false,       { 'herptile', 'legendsnakes', 'Snake_Poison' } },
    { 'Legendary Grey Beaver',           `mp_a_c_beaver_01`,       1321671943,  { 'game', 'legbeavers1', 'beavertail' } },
    { 'Legendary White Beaver',          `mp_a_c_beaver_01`,       334014283,   { 'game', 'legbeavers2', 'beavertail' } },
    { 'Legendary Black Beaver',          `mp_a_c_beaver_01`,       766106317,   { 'game', 'legbeavers3', 'beavertail' } },
    { 'Legendary Beaver',                `a_c_beaver_01`,          -1212478257, { 'game', 'legbeawers', 'beavertail' } },

    -- boars (the game reports the Wildhog with the Cogi Boar's hash, so it pays as the Cogi Boar)
    { 'Legendary Cogi Boar',             `mp_a_c_boar_01`,         -661738271,  { 'pork', 'legboars1', 'boarmusk' } },
    { 'Legendary Wakpa Boar',            `mp_a_c_boar_01`,         -978876653,  { 'pork', 'legboars2', 'boarmusk' } },
    { 'Legendary Icahi Boar',            `mp_a_c_boar_01`,         -188652218,  { 'pork', 'legboars3', 'boarmusk' } },
    { 'Legendary Great Boar',            `a_c_boarlegendary_01`,   false,       { 'pork', 'legboars', 'boarmusk' } },
    { 'Legendary Boar',                  `a_c_boar_01`,            659982441,   { 'pork', 'legboars', 'boarmusk' } },

    -- deer, elk and moose
    { 'Legendary Buck',                  `mp_a_c_buck_01`,         -1483933996, { 'venison', 'legbucks1', 'legendbuckantler' } },
    { 'Legendary Mudrunner Buck',        `mp_a_c_buck_01`,         -1617752974, { 'venison', 'legbucks2', 'legendbuckantler' } },
    { 'Legendary Snow Buck',             `mp_a_c_buck_01`,         -1381586791, { 'venison', 'legbucks3', 'legendbuckantler' } },
    { 'Legendary Shadow Buck',           `mp_a_c_buck_01`,         -1141848787, { 'venison', 'legbucks4', 'legendbuckantler' } },
    { 'Legendary Buck',                  `a_c_buck_01`,            -2137753947, { 'venison', 'legbucks', 'legendbuckantler' } },
    { 'Legendary Katata Elk',            `mp_a_c_elk_01`,          610434548,   { 'venison', 'legelks1', 'legelkantler' } },
    { 'Legendary Ozula Elk',             `mp_a_c_elk_01`,          -44203702,   { 'venison', 'legelks2', 'legelkantler' } },
    { 'Legendary Inahme Elk',            `mp_a_c_elk_01`,          319532198,   { 'venison', 'legelks3', 'legelkantler' } },
    { 'Legendary Elk',                   `a_c_elk_01`,             -566788959,  { 'venison', 'legelks', 'legelkantler' } },
    { 'Legendary Snowflake Moose',       `mp_a_c_moose_01`,        538065295,   { 'biggame', 'legmooses1', 'legmooseantler' } },
    { 'Legendary Knight Moose',          `mp_a_c_moose_01`,        206311939,   { 'biggame', 'legmooses2', 'legmooseantler' } },
    { 'Legendary Ruddy Moose',           `mp_a_c_moose_01`,        878961202,   { 'biggame', 'legmooses3', 'legmooseantler' } },
    { 'Legendary Moose',                 `a_c_moose_01`,           1415163930,  { 'biggame', 'legmooses', 'legmooseantler' } },

    -- rams, bison and pronghorn
    { 'Legendary Gabbro Horn Ram',       `mp_a_c_bighornram_01`,   797910655,   { 'mutton', 'legrams1', 'legramhorn' } },
    { 'Legendary Chalk Horn Ram',        `mp_a_c_bighornram_01`,   -1369857002, { 'mutton', 'legrams2', 'legramhorn' } },
    { 'Legendary Rutile Horn Ram',       `mp_a_c_bighornram_01`,   -1667956595, { 'mutton', 'legrams3', 'legramhorn' } },
    { 'Legendary Great Horn Ram',        `mp_a_c_bighornram_01`,   -1513285038, { 'mutton', 'legrams4', 'legramhorn' } },
    { 'Legendary Tatanka Bison',         `mp_a_c_buffalo_01`,      -139301483,  { 'biggame', 'legbisons1', 'legbisonhorn' } },
    { 'Legendary Winyan Bison',          `mp_a_c_buffalo_01`,      -378711797,  { 'biggame', 'legbisons2', 'legbisonhorn' } },
    { 'Legendary Payata Bison',          `mp_a_c_buffalo_01`,      -605047280,  { 'biggame', 'legbisons3', 'legbisonhorn' } },
    { 'Legendary Bison',                 `a_c_buffalo_01`,         279472558,   { 'biggame', 'legbisons', 'legbisonhorn' } },
    { 'Legendary Tatanka Bison',         `a_c_buffalo_tatanka_01`, false,       { 'biggame', 'legbisonstak', 'legbisonhorn' } },
    { 'Legendary Pronghorn',             `a_c_pronghorn_01`,       -386220147,  { 'venison', 'legprongs', 'pronghornh' } },
}

-- labels shown in the "you got" message
Config.Labels = {
    -- fish
    a_c_fishbluegil_01_sm = 'Bluegill', a_c_fishbluegil_01_ms = 'Bluegill (medium)',
    a_c_fishbullheadcat_01_sm = 'Bullhead Catfish', a_c_fishbullheadcat_01_ms = 'Bullhead Catfish (medium)',
    a_c_fishchainpickerel_01_sm = 'Chain Pickerel', a_c_fishchainpickerel_01_ms = 'Chain Pickerel (medium)',
    a_c_fishperch_01_sm = 'Perch', a_c_fishperch_01_ms = 'Perch (medium)',
    a_c_fishredfinpickerel_01_sm = 'Redfin Pickerel', a_c_fishredfinpickerel_01_ms = 'Redfin Pickerel (medium)',
    a_c_fishrockbass_01_sm = 'Rock Bass', a_c_fishrockbass_01_ms = 'Rock Bass (medium)',
    a_c_fishlargemouthbass_01_ms = 'Largemouth Bass', a_c_fishlargemouthbass_01_lg = 'Largemouth Bass (large)',
    a_c_fishsmallmouthbass_01_ms = 'Smallmouth Bass', a_c_fishsmallmouthbass_01_lg = 'Smallmouth Bass (large)',
    a_c_fishrainbowtrout_01_ms = 'Rainbow Trout', a_c_fishrainbowtrout_01_lg = 'Rainbow Trout (large)',
    a_c_fishsalmonsockeye_01_ms = 'Sockeye Salmon', a_c_fishsalmonsockeye_01_ml = 'Sockeye Salmon (big)',
    a_c_fishsalmonsockeye_01_lg = 'Sockeye Salmon (large)',
    a_c_fishchannelcatfish_01_lg = 'Channel Catfish (large)', a_c_fishchannelcatfish_01_xl = 'Channel Catfish (huge)',
    a_c_fishlakesturgeon_01_lg = 'Lake Sturgeon', a_c_fishlongnosegar_01_lg = 'Longnose Gar',
    a_c_fishmuskie_01_lg = 'Muskie', a_c_fishnorthernpike_01_lg = 'Northern Pike',

    -- meat
    biggame = 'Big Game Meat', game = 'Game Meat', stringy = 'Stringy Meat', herptile = 'Reptile Meat',
    bird = 'Bird Meat', venison = 'Venison', beef = 'Beef', pork = 'Pork', mutton = 'Mutton', fishmeat = 'Fish Fillet',

    -- hides and pelts
    gbears = 'Grizzly Hide', bbears = 'Black Bear Hide', wolfpelt = 'Wolf Pelt', cougars = 'Cougar Pelt',
    panthers = 'Panther Pelt', coyotes = 'Coyote Pelt', foxskin = 'Fox Pelt', aligators = 'Alligator Hide',
    deerskin = 'Deer Hide', bucks = 'Buck Hide', elks = 'Elk Hide', mooses = 'Moose Hide',
    prongs = 'Pronghorn Hide', bisons = 'Bison Hide', rams = 'Bighorn Fleece', goats = 'Goat Hide',
    wool = 'Wool', cows = 'Cowhide', bulls = 'Bull Hide', oxs = 'Ox Hide', pigs = 'Pig Hide',
    pecaris = 'Javelina Hide', beawers = 'Beaver Pelt', muskrats = 'Muskrat Pelt', badgers = 'Badger Pelt',
    raccoons = 'Raccoon Pelt', opossums = 'Opossum Pelt', rabbits = 'Rabbit Pelt', armadillos = 'Armadillo Shell',
    fsnakes = 'Rattlesnake Skin', asnakes = 'Fer-de-Lance Skin', boaskin = 'Boa Skin', wsnakeskin = 'Water Snake Skin',
    gleguans = 'Green Iguana Skin', dleguans = 'Desert Iguana Skin', lizards = 'Gila Monster Skin',
    turtleshell = 'Turtle Shell',

    -- parts
    beart = 'Bear Tooth', bearc = 'Bear Claw', wolftooth = 'Wolf Fang', cougarf = 'Cougar Fang',
    panthere = 'Panther Eye', coyotef = 'Coyote Fang', foxt = 'Fox Tooth', aligatorto = 'Alligator Tooth',
    deerheart = 'Deer Heart', buckantler = 'Buck Antlers', elkantler = 'Elk Antlers', mooseantler = 'Moose Antlers',
    pronghornh = 'Pronghorn Horn', bisonhorn = 'Bison Horn', ramhorn = 'Ram Horn', sheephead = 'Sheep Skull',
    cowh = 'Cow Horn', bullhorn = 'Bull Horn', oxhorn = 'Ox Horn', porkfat = 'Lard', boarmusk = 'Boar Tusk',
    beavertail = 'Beaver Tail', scentg = 'Scent Gland', raccoont = 'Raccoon Tooth', opossumc = 'Opossum Claw',
    rabbitpaw = "Rabbit's Foot", armadilloc = 'Armadillo Claw', Snake_Poison = 'Snake Venom',
    lizardl = 'Gila Foot', turtlet = 'Turtle Beak',

    -- feathers, beaks and claws
    eaglef = 'Eagle Feather', eaglet = 'Eagle Talon', hawkf = 'Hawk Feather', hawkt = 'Hawk Talon',
    owlf = 'Owl Feather', owlt = 'Owl Talon', kcondorf = 'Condor Feather', kcondorb = 'Condor Beak',
    condorf = 'Vulture Feather', condorb = 'Vulture Beak', ravenf = 'Raven Feather', ravenc = 'Raven Talon',
    kbirdf = 'Heron Plume', kbirdb = 'Heron Beak', egretf = 'Egret Plume', egretb = 'Egret Beak',
    rspoonf = 'Spoonbill Plume', rspoonb = 'Spoonbill Beak', daruf = 'Crane Feather', darub = 'Crane Beak',
    pelicanf = 'Pelican Feather', pelicanb = 'Pelican Beak', bbirdf = 'Cormorant Feather', bbirdb = 'Cormorant Beak',
    loonf = 'Loon Feather', loonb = 'Loon Beak', seagullf = 'Gull Feather', seagullb = 'Gull Beak',
    boobyf = 'Booby Feather', boobyb = 'Booby Beak', duckfat = 'Duck Fat', Feather = 'Feather',
    goosef = 'Goose Feather', gooseb = 'Goose Beak', turkeyf = 'Turkey Feather', turkeyb = 'Turkey Beak',
    peasantf = 'Pheasant Feather', peasantb = 'Pheasant Beak', quailf = 'Quail Feather', quailb = 'Quail Beak',
    prairif = 'Prairie Chicken Feather', prairib = 'Prairie Chicken Beak', chickenf = 'Chicken Feather',
    chickenheart = 'Chicken Heart', cockf = 'Rooster Feather', cockc = 'Rooster Spur',
    bparrotf = 'Parrot Feather', bparrotb = 'Parrot Beak',

    -- whole carcasses
    crow_c = 'Crow', pigeon_c = 'Pigeon', robin_c = 'Robin', sparrow1_c = 'Sparrow', songbird_c = 'Songbird',
    cardinal_c = 'Cardinal', bluejay_c = 'Blue Jay', cedarwaxwing_c = 'Cedar Waxwing', oriole_c = 'Oriole',
    woodpeck01_c = 'Woodpecker', woodpeck02_c = 'Pileated Woodpecker', chipmunk_c = 'Chipmunk',
    squirrel_grey_c = 'Squirrel', rat_c = 'Rat', bat_c = 'Bat', toad_c = 'Toad', frogbull_c = 'Bullfrog',
    crab_c = 'Crab', crawfish_c = 'Crawfish',

    -- legendary trophies
    legbears1 = 'Deadly Bear Hide', legbears2 = 'Owiza Bear Hide', legbears3 = 'Ridgeback Spirit Bear Hide',
    legbears4 = 'Golden Spirit Bear Hide', leggbears = 'Legendary Bear Hide',
    legwolfs1 = 'Emerald Wolf Pelt', legwolfs2 = 'Onyx Wolf Pelt', legwolfs3 = 'Moonstone Wolf Pelt',
    legwolfpelt = 'Legendary Wolf Pelt',
    legcougars1 = 'Iguga Cougar Pelt', legcougars2 = 'Maza Cougar Pelt', legcougars3 = 'Sapa Cougar Pelt',
    legcougars4 = 'Black Cougar Pelt', legcougars = 'Legendary Cougar Pelt',
    legpanthers1 = 'Nightwalker Panther Pelt', legpanthers2 = 'Ghost Panther Pelt', legpanthers3 = 'Iwakta Panther Pelt',
    legcoyotes1 = 'Red Streak Coyote Pelt', legcoyotes2 = 'Midnight Paw Coyote Pelt', legcoyotes3 = 'Milk Coyote Pelt',
    legcoyotes = 'Legendary Coyote Pelt',
    legfoxs1 = 'Ota Fox Pelt', legfoxs2 = 'Marble Fox Pelt', legfoxs3 = 'Cross Fox Pelt', legfoxskin = 'Legendary Fox Pelt',
    legaligators1 = 'Teca Alligator Hide', legaligators2 = 'Sun Alligator Hide', legaligators3 = 'Banded Alligator Hide',
    legaligators = 'Legendary Alligator Hide', legendsnakes = 'Legendary Boa Skin',
    legbeavers1 = 'Grey Beaver Pelt', legbeavers2 = 'White Beaver Pelt', legbeavers3 = 'Black Beaver Pelt',
    legbeawers = 'Legendary Beaver Pelt',
    legboars1 = 'Cogi Boar Hide', legboars2 = 'Wakpa Boar Hide', legboars3 = 'Icahi Boar Hide',
    legboars4 = 'Wildhog Hide', legboars = 'Legendary Boar Hide',
    legbucks1 = 'Legendary Buck Hide', legbucks2 = 'Mudrunner Buck Hide', legbucks3 = 'Snow Buck Hide',
    legbucks4 = 'Shadow Buck Hide', legbucks = 'Legendary Whitetail Hide',
    legelks1 = 'Katata Elk Hide', legelks2 = 'Ozula Elk Hide', legelks3 = 'Inahme Elk Hide', legelks = 'Legendary Elk Hide',
    legmooses1 = 'Snowflake Moose Hide', legmooses2 = 'Knight Moose Hide', legmooses3 = 'Ruddy Moose Hide',
    legmooses = 'Legendary Moose Hide',
    legrams1 = 'Gabbro Horn Ram Fleece', legrams2 = 'Chalk Horn Ram Fleece', legrams3 = 'Rutile Horn Ram Fleece',
    legrams4 = 'Great Horn Ram Fleece',
    legbisons1 = 'Tatanka Bison Robe', legbisons2 = 'Winyan Bison Robe', legbisons3 = 'Payata Bison Robe',
    legbisons = 'Legendary Bison Robe', legbisonstak = 'Great Tatanka Bison Robe', legprongs = 'Legendary Pronghorn Hide',
    legendbuckantler = 'Legendary Buck Antlers', legelkantler = 'Legendary Elk Antlers',
    legmooseantler = 'Legendary Moose Antlers', legramhorn = 'Legendary Ram Horns', legbisonhorn = 'Legendary Bison Horns',
}
