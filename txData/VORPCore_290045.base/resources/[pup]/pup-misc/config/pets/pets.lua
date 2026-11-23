-- pup-misc/pets | the pet list (see README)

PetsConfig.Pets = {
    -- DOGS
    ['pet_foxhound']   = { label = 'American Foxhound', model = 'A_C_DogAmericanFoxhound_01', scale = 1.0 },
    ['pet_shepherd']   = { label = 'Australian Shepherd', model = 'A_C_DogAustralianSheperd_01', scale = 1.0 }, -- no variant = random coat
    -- Fixed coats
    ['pet_shepherd_merle'] = { label = 'Merle Australian Shepherd', model = 'A_C_DogAustralianSheperd_01', variant = 0, scale = 1.0 },
    ['pet_shepherd_red']   = { label = 'Red Australian Shepherd',   model = 'A_C_DogAustralianSheperd_01', variant = 1, scale = 0.5 },
    ['pet_shepherd_black'] = { label = 'Black Australian Shepherd', model = 'A_C_DogAustralianSheperd_01', variant = 2, scale = 1.0 },
    ['pet_coonhound']  = { label = 'Bluetick Coonhound', model = 'A_C_DogBluetickCoonhound_01', scale = 1.0 },
    ['pet_cur']        = { label = 'Catahoula Cur',     model = 'A_C_DogCatahoulaCur_01', scale = 1.0 },
    ['pet_retriever']  = { label = 'Bay Retriever',     model = 'A_C_DogChesBayRetriever_01', scale = 1.0 },
    ['pet_collie']     = { label = 'Collie',            model = 'A_C_DogCollie_01', scale = 1.0 },
    ['pet_hobo']       = { label = 'Hobo Dog',          model = 'A_C_DogHobo_01', scale = 1.0 },
    ['pet_hound']      = { label = 'Hound',             model = 'A_C_DogHound_01', scale = 1.0 },
    -- rename once you have seen it; the coat behind a number is not in the data
    ['pet_hound_10']   = { label = 'Hound (Variant 10)', model = 'A_C_DogHound_01', variant = 10, scale = 1.0 },
    ['pet_husky']      = { label = 'Husky',             model = 'A_C_DogHusky_01', scale = 1.0 },
    ['pet_lab']        = { label = 'Labrador',          model = 'A_C_DogLab_01', scale = 1.0 },
    ['pet_liondog']    = { label = 'Lion Dog',          model = 'A_C_DogLion_01', scale = 1.0 },
    ['pet_poodle']     = { label = 'Poodle',            model = 'A_C_DogPoodle_01', scale = 1.0 },
    ['pet_rufus']      = { label = 'Rufus',             model = 'A_C_DogRufus_01', scale = 1.0 },
    ['pet_street']     = { label = 'Street Dog',        model = 'A_C_DogStreet_01', scale = 1.0 },

    -- CATS AND SMALL CRITTERS
    ['pet_cat']        = { label = 'Cat',        model = 'A_C_Cat_01', scale = 1.0 },
    ['pet_rabbit']     = { label = 'Rabbit',     model = 'A_C_Rabbit_01', scale = 1.0 },
    ['pet_squirrel']   = { label = 'Squirrel',   model = 'A_C_Squirrel_01', scale = 1.0 },
    ['pet_chipmunk']   = { label = 'Chipmunk',   model = 'A_C_Chipmunk_01', scale = 1.0 },
    ['pet_raccoon']    = { label = 'Raccoon',    model = 'A_C_Raccoon_01', scale = 1.0 },
    ['pet_possum']     = { label = 'Possum',     model = 'A_C_Possum_01', scale = 1.0 },
    ['pet_skunk']      = { label = 'Skunk',      model = 'A_C_Skunk_01', scale = 1.0 },
    ['pet_badger']     = { label = 'Badger',     model = 'A_C_Badger_01', scale = 1.0 },
    ['pet_beaver']     = { label = 'Beaver',     model = 'A_C_Beaver_01', scale = 1.0 },
    ['pet_muskrat']    = { label = 'Muskrat',    model = 'A_C_Muskrat_01', scale = 1.0 },
    ['pet_armadillo']  = { label = 'Armadillo',  model = 'a_c_armadillo_01', scale = 1.0 },
    ['pet_rat']        = { label = 'Rat',        model = 'A_C_Rat_01', scale = 1.5 },
    ['pet_toad']       = { label = 'Toad',       model = 'A_C_Toad_01', scale = 1.0 },
    ['pet_frog']       = { label = 'Bullfrog',   model = 'A_C_FrogBull_01', scale = 3.0 },
    ['pet_turtle']     = { label = 'Turtle',     model = 'A_C_TurtleSnapping_01', scale = 1.0 },
    -- lizards: the two marked verified are the safe ones
    ['pet_gila']       = { label = 'Gila Monster',  model = 'A_C_GilaMonster_01', scale = 1.5 },  -- verified
    ['pet_iguana_d']   = { label = 'Desert Iguana', model = 'A_C_IguanaDesert_01', scale = 1.5 }, -- verified
    ['pet_iguana']     = { label = 'Iguana',        model = 'A_C_Iguana_01', scale = 1.5 },

    -- BIRDS
    ['pet_parrot']     = { label = 'Parrot',     model = 'A_C_Parrot_01', scale = 1.0 },
    ['pet_owl']        = { label = 'Owl',        model = 'A_C_Owl_01', scale = 1.0 },
    ['pet_raven']      = { label = 'Raven',      model = 'A_C_Raven_01', scale = 1.0 },
    ['pet_crow']       = { label = 'Crow',       model = 'A_C_Crow_01', scale = 1.0 },
    ['pet_bluejay']    = { label = 'Blue Jay',   model = 'A_C_BlueJay_01', scale = 1.0 },
    ['pet_cardinal']   = { label = 'Cardinal',   model = 'A_C_Cardinal_01', scale = 1.0 },
    ['pet_robin']      = { label = 'Robin',      model = 'A_C_Robin_01', scale = 1.0 },
    ['pet_sparrow']    = { label = 'Sparrow',    model = 'A_C_Sparrow_01', scale = 1.0 },
    ['pet_songbird']   = { label = 'Songbird',   model = 'A_C_SongBird_01', scale = 1.0 },
    ['pet_pigeon']     = { label = 'Pigeon',     model = 'A_C_Pigeon', scale = 1.0 }, -- no _01 on this one
    ['pet_chicken']    = { label = 'Chicken',    model = 'A_C_Chicken_01', scale = 1.0 },
    ['pet_rooster']    = { label = 'Rooster',    model = 'A_C_Rooster_01', scale = 1.0 },
    ['pet_turkey']     = { label = 'Turkey',     model = 'A_C_Turkey_01', scale = 1.0 },
    ['pet_goose']      = { label = 'Goose',      model = 'A_C_GooseCanada_01', scale = 1.0 },

    -- FARM
    ['pet_pig']        = { label = 'Pig',        model = 'A_C_Pig_01', scale = 1.0 },
    ['pet_goat']       = { label = 'Goat',       model = 'A_C_Goat_01', scale = 1.0 },
    ['pet_sheep']      = { label = 'Sheep',      model = 'A_C_Sheep_01', scale = 1.0 },
    -- the Guthrie Farm sheep: the bow is outfit variant 7
    ['pet_sheep_bow']  = { label = 'Pink Bow Sheep', model = 'A_C_Sheep_01', variant = 7, scale = 0.5 },
    ['pet_cow']        = { label = 'Cow',        model = 'A_C_Cow', scale = 1.0 },   -- no _01 on this one
    ['pet_donkey']     = { label = 'Donkey',     model = 'A_C_Donkey_01', scale = 1.0 },

    -- WILD
    ['pet_fox']        = { label = 'Fox',        model = 'A_C_Fox_01', scale = 1.0 },
    ['pet_boar']       = { label = 'Boar',       model = 'A_C_Boar_01', scale = 1.0 },
    ['pet_deer']       = { label = 'Deer',       model = 'A_C_Deer_01', scale = 1.0 },
    ['pet_buck']       = { label = 'Buck',       model = 'A_C_Buck_01', scale = 1.0 },
    ['pet_pronghorn']  = { label = 'Pronghorn',  model = 'A_C_Pronghorn_01', scale = 1.0 },
    ['pet_ram']        = { label = 'Bighorn Ram', model = 'A_C_BigHornRam_01', scale = 1.0 },
    ['pet_snake']      = { label = 'Snake',      model = 'A_C_Snake_01', scale = 1.0 },
    ['pet_lion']       = { label = 'Mangy Lion', model = 'A_C_LionMangy_01', scale = 1.0 },

    -- LEGENDARY
    ['pet_leg_sunalligator']        = { label = 'Legendary Sun Alligator',         model = 'mp_a_c_alligator_01',    variant = 1, scale = 1.0 },
    ['pet_leg_bullgator']           = { label = 'Legendary Bullgator',             model = 'a_c_alligator_02',       variant = 0, scale = 1.0 },
    ['pet_leg_greybeaver']          = { label = 'Legendary Grey Beaver',           model = 'mp_a_c_beaver_01',       variant = 0, scale = 1.0 },
    ['pet_leg_blackbeaver']         = { label = 'Legendary Black Beaver',          model = 'mp_a_c_beaver_01',       variant = 2, scale = 1.0 },
    ['pet_leg_cogiboar']            = { label = 'Legendary Cogi Boar',             model = 'mp_a_c_boar_01',         variant = 0, scale = 1.0 },
    ['pet_leg_wakpaboar']           = { label = 'Legendary Wakpa Boar',            model = 'mp_a_c_boar_01',         variant = 1, scale = 1.0 },
    ['pet_leg_wildhog']             = { label = 'Legendary Wildhog',               model = 'mp_a_c_boar_01',         variant = 5, scale = 1.0 },
    ['pet_leg_igugacougar']         = { label = 'Legendary Iguga Cougar',          model = 'mp_a_c_cougar_01',       variant = 0, scale = 1.0 },
    ['pet_leg_sapacougar']          = { label = 'Legendary Sapa Cougar',           model = 'mp_a_c_cougar_01',       variant = 2, scale = 1.0 },
    ['pet_leg_blackcougar']         = { label = 'Legendary Black Cougar',          model = 'mp_a_c_cougar_01',       variant = 3, scale = 1.0 },
    ['pet_leg_redstreakcoyote']     = { label = 'Legendary Red Streak Coyote',     model = 'mp_a_c_coyote_01',       variant = 0, scale = 1.0 },
    ['pet_leg_midnightpawcoyote']   = { label = 'Legendary Midnight Paw Coyote',   model = 'mp_a_c_coyote_01',       variant = 1, scale = 1.0 },
    ['pet_leg_milkcoyote']          = { label = 'Legendary Milk Coyote',           model = 'mp_a_c_coyote_01',       variant = 2, scale = 1.0 },
    ['pet_leg_nightwalkerpanther']  = { label = 'Legendary Nightwalker Panther',   model = 'mp_a_c_panther_01',      variant = 0, scale = 1.0 },
    ['pet_leg_ghostpanther']        = { label = 'Legendary Ghost Panther',         model = 'mp_a_c_panther_01',      variant = 1, scale = 1.0 },
    ['pet_leg_emeraldwolf']         = { label = 'Legendary Emerald Wolf',          model = 'mp_a_c_wolf_01',         variant = 0, scale = 1.0 },
    ['pet_leg_onyxwolf']            = { label = 'Legendary Onyx Wolf',             model = 'mp_a_c_wolf_01',         variant = 1, scale = 1.0 },
    ['vanagandr']                   = { label = 'Legendary Moonstone Wolf',        model = 'mp_a_c_wolf_01',         variant = 2, scale = 1.0 },
    ['pet_leg_deadlybear']          = { label = 'Legendary Deadly Bear',           model = 'mp_a_c_bear_01',         variant = 0, scale = 1.0 },
    ['pet_leg_owizabear']           = { label = 'Legendary Owiza Bear',            model = 'mp_a_c_bear_01',         variant = 1, scale = 1.0 },
    ['pet_leg_ridgebackspiritbear'] = { label = 'Legendary Ridgeback Spirit Bear', model = 'mp_a_c_bear_01',         variant = 2, scale = 1.0 },
    ['pet_leg_chalkhornram']        = { label = 'Legendary Chalk Horn Ram',        model = 'mp_a_c_bighornram_01',   variant = 1, scale = 1.0 },
    ['pet_leg_rutilehornram']       = { label = 'Legendary Rutile Horn Ram',       model = 'mp_a_c_bighornram_01',   variant = 2, scale = 1.0 },
    ['pet_leg_greathornram']        = { label = 'Legendary GreatHorn Ram',         model = 'mp_a_c_bighornram_01',   variant = 3, scale = 1.0 },
    ['pet_leg_mudrunnerbuck']       = { label = 'Legendary Mudrunner Buck',        model = 'mp_a_c_buck_01',         variant = 2, scale = 1.0 },
    ['pet_leg_shadowbuck']          = { label = 'Legendary Shadow Buck',           model = 'mp_a_c_buck_01',         variant = 4, scale = 1.0 },
    ['pet_leg_tatankabison']        = { label = 'Legendary Tatanka Bison',         model = 'mp_a_c_buffalo_01',      variant = 0, scale = 1.0 },
    ['pet_leg_payatabison']         = { label = 'Legendary Payata Bison',          model = 'mp_a_c_buffalo_01',      variant = 2, scale = 1.0 },
    ['pet_leg_katataelk']           = { label = 'Legendary Katata Elk',            model = 'mp_a_c_elk_01',          variant = 0, scale = 1.0 },
    ['pet_leg_otafox']              = { label = 'Legendary Ota Fox',               model = 'mp_a_c_fox_01',          variant = 0, scale = 1.0 },
    ['pet_leg_crossfox']            = { label = 'Legendary Cross Fox',             model = 'mp_a_c_fox_01',          variant = 2, scale = 1.0 },
    ['pet_leg_knightmoose']         = { label = 'Legendary Knight Moose',          model = 'mp_a_c_moose_01',        variant = 2, scale = 1.0 },
    ['pet_leg_ruddymoose']          = { label = 'Legendary Ruddy Moose',           model = 'mp_a_c_moose_01',        variant = 3, scale = 1.0 },
    ['pet_leg_greatboar']           = { label = 'Legendary Great Boar',            model = 'a_c_boarlegendary_01',   variant = 0, scale = 1.0 },
    ['pet_leg_boa']                 = { label = 'Legendary Boa',                   model = 'a_c_snakeredboa10ft_01', variant = 0, scale = 1.0 },
    -- disabled in legendaryhunt (its hunt spots are off), but the model and coat are valid, so it works fine as a pet
    ['pet_leg_rattlesnake']         = { label = 'Legendary Rattlesnake',           model = 'a_c_snake_01',           variant = 3, scale = 1.0 },
    ['pet_leg_bison']               = { label = 'Legendary Bison',                 model = 'a_c_buffalo_01',         variant = 4, scale = 1.0 },
    ['pet_leg_fox']                 = { label = 'Legendary Fox',                   model = 'a_c_fox_01',             variant = 3, scale = 1.0 },
    ['pet_leg_bighornram']          = { label = 'Legendary Bighorn Ram',           model = 'a_c_bighornram_01',      variant = 12, scale = 1.0 },
    ['pet_leg_beaver']              = { label = 'Legendary Beaver',                model = 'a_c_beaver_01',          variant = 1, scale = 1.0 },
    ['pet_leg_buck']                = { label = 'Legendary Buck',                  model = 'a_c_buck_01',            variant = 3, scale = 1.0 },
    ['pet_leg_coyote']              = { label = 'Legendary Coyote',                model = 'a_c_coyote_01',          variant = 1, scale = 1.0 },
    ['pet_leg_pronghorn']           = { label = 'Legendary Pronghorn',             model = 'a_c_pronghorn_01',       variant = 1, scale = 1.0 },
    ['pet_leg_wolf']                = { label = 'Legendary Wolf',                  model = 'A_C_Wolf',               variant = 3, scale = 1.0 },
    ['pet_leg_moose']               = { label = 'Legendary Moose',                 model = 'a_c_moose_01',           variant = 6, scale = 1.0 },
    ['pet_leg_tatankabison2']       = { label = 'Legendary Tatanka Bison',         model = 'a_c_buffalo_tatanka_01', variant = 0, scale = 1.0 },
    ['pet_leg_elk']                 = { label = 'Legendary Elk',                   model = 'a_c_elk_01',             variant = 1, scale = 1.0 },

}
