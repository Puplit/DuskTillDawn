-- legendaryhunt | the legendaries a baited trap can call
-- Key = beast id; config/grounds.lua says where each one roams. Keys need not be continuous.
-- model  = ped model; outfit = outfit preset index for that model
-- lure   = item from Config.Lures that calls it
-- hours  = { from, to } in-game hours, from <= hour < to; from > to runs past midnight ({ 21, 5 } = 21:00 to 05:00)

Config.Animals = {
    -- bears
    [1]  = { name = "Legendary Deadly Bear",           model = `mp_a_c_bear_01`,         outfit = 0,  lure = 'honey',       hours = { 6, 20 } },
    [2]  = { name = "Legendary Owiza Bear",            model = `mp_a_c_bear_01`,         outfit = 1,  lure = 'fishmeat',    hours = { 0, 24 } },
    [3]  = { name = "Legendary Ridgeback Spirit Bear", model = `mp_a_c_bear_01`,         outfit = 2,  lure = 'honey',       hours = { 5, 19 } },
    [4]  = { name = "Legendary Golden Spirit Bear",    model = `mp_a_c_bear_01`,         outfit = 3,  lure = 'honey',       hours = { 8, 18 } },
    [5]  = { name = "Legendary Bear",                  model = `a_c_bear_01`,            outfit = 10, lure = 'biggame',     hours = { 19, 7 } },

    -- wolves
    [6]  = { name = "Legendary Emerald Wolf",          model = `mp_a_c_wolf_01`,         outfit = 0,  lure = 'biggame',     hours = { 20, 5 } },
    [7]  = { name = "Legendary Onyx Wolf",             model = `mp_a_c_wolf_01`,         outfit = 1,  lure = 'biggame',     hours = { 18, 4 } },
    [8]  = { name = "Legendary Moonstone Wolf",        model = `mp_a_c_wolf_01`,         outfit = 2,  lure = 'biggame',     hours = { 21, 6 } },
    [9]  = { name = "Legendary Wolf",                  model = `A_C_Wolf`,               outfit = 3,  lure = 'biggame',     hours = { 21, 5 } },

    -- big cats
    [10] = { name = "Legendary Iguga Cougar",          model = `mp_a_c_cougar_01`,       outfit = 0,  lure = 'biggame',     hours = { 18, 6 } },
    [11] = { name = "Legendary Maza Cougar",           model = `mp_a_c_cougar_01`,       outfit = 1,  lure = 'biggame',     hours = { 0, 24 } },
    [12] = { name = "Legendary Sapa Cougar",           model = `mp_a_c_cougar_01`,       outfit = 2,  lure = 'biggame',     hours = { 17, 5 } },
    [13] = { name = "Legendary Black Cougar",          model = `mp_a_c_cougar_01`,       outfit = 3,  lure = 'biggame',     hours = { 5, 12 } },
    [14] = { name = "Legendary Giaguaro Cougar",       model = `a_c_cougar_01`,          outfit = 5,  lure = 'biggame',     hours = { 12, 21 } },
    [15] = { name = "Legendary Tiger Cougar",          model = `a_c_cougar_01`,          outfit = 2,  lure = 'biggame',     hours = { 0, 24 } },
    [17] = { name = "Legendary Nightwalker Panther",   model = `mp_a_c_panther_01`,      outfit = 0,  lure = 'biggame',     hours = { 20, 5 } },
    [18] = { name = "Legendary Ghost Panther",         model = `mp_a_c_panther_01`,      outfit = 1,  lure = 'biggame',     hours = { 21, 4 } },
    [19] = { name = "Legendary Iwakta Panther",        model = `mp_a_c_panther_01`,      outfit = 2,  lure = 'biggame',     hours = { 0, 24 } },

    -- coyotes and foxes
    [20] = { name = "Legendary Red Streak Coyote",     model = `mp_a_c_coyote_01`,       outfit = 0,  lure = 'stringy',     hours = { 0, 24 } },
    [21] = { name = "Legendary Midnight Paw Coyote",   model = `mp_a_c_coyote_01`,       outfit = 1,  lure = 'stringy',     hours = { 19, 6 } },
    [22] = { name = "Legendary Milk Coyote",           model = `mp_a_c_coyote_01`,       outfit = 2,  lure = 'stringy',     hours = { 0, 24 } },
    [23] = { name = "Legendary Coyote",                model = `a_c_coyote_01`,          outfit = 1,  lure = 'stringy',     hours = { 0, 24 } },
    [24] = { name = "Legendary Ota Fox",               model = `mp_a_c_fox_01`,          outfit = 0,  lure = 'game',        hours = { 4, 11 } },
    [25] = { name = "Legendary Marble Fox",            model = `mp_a_c_fox_01`,          outfit = 1,  lure = 'game',        hours = { 0, 24 } },
    [26] = { name = "Legendary Cross Fox",             model = `mp_a_c_fox_01`,          outfit = 2,  lure = 'game',        hours = { 16, 23 } },
    [27] = { name = "Legendary Fox",                   model = `a_c_fox_01`,             outfit = 3,  lure = 'game',        hours = { 0, 24 } },

    -- swamp and water
    [28] = { name = "Legendary Teca Alligator",        model = `mp_a_c_alligator_01`,    outfit = 0,  lure = 'fishmeat',    hours = { 0, 24 } },
    [29] = { name = "Legendary Sun Alligator",         model = `mp_a_c_alligator_01`,    outfit = 1,  lure = 'fishmeat',    hours = { 8, 20 } },
    [30] = { name = "Legendary Banded Alligator",      model = `mp_a_c_alligator_01`,    outfit = 2,  lure = 'fishmeat',    hours = { 0, 24 } },
    [31] = { name = "Legendary Bullgator",             model = `a_c_alligator_02`,       outfit = 0,  lure = 'fishmeat',    hours = { 20, 6 } },
    [32] = { name = "Legendary Boa",                   model = `a_c_snakeredboa10ft_01`, outfit = 0,  lure = 'stringy',     hours = { 0, 24 } },
    [33] = { name = "Legendary Grey Beaver",           model = `mp_a_c_beaver_01`,       outfit = 0,  lure = 'Wild_Carrot', hours = { 17, 23 } },
    [34] = { name = "Legendary White Beaver",          model = `mp_a_c_beaver_01`,       outfit = 1,  lure = 'Wild_Carrot', hours = { 16, 22 } },
    [35] = { name = "Legendary Black Beaver",          model = `mp_a_c_beaver_01`,       outfit = 2,  lure = 'Wild_Carrot', hours = { 17, 23 } },
    [36] = { name = "Legendary Beaver",                model = `a_c_beaver_01`,          outfit = 1,  lure = 'Wild_Carrot', hours = { 0, 24 } },

    -- boars
    [37] = { name = "Legendary Cogi Boar",             model = `mp_a_c_boar_01`,         outfit = 0,  lure = 'corn',        hours = { 6, 16 } },
    [38] = { name = "Legendary Wakpa Boar",            model = `mp_a_c_boar_01`,         outfit = 1,  lure = 'corn',        hours = { 5, 13 } },
    [39] = { name = "Legendary Icahi Boar",            model = `mp_a_c_boar_01`,         outfit = 2,  lure = 'corn',        hours = { 13, 21 } },
    [40] = { name = "Legendary Wildhog",               model = `mp_a_c_boar_01`,         outfit = 5,  lure = 'corn',        hours = { 0, 24 } },
    [41] = { name = "Legendary Great Boar",            model = `a_c_boarlegendary_01`,   outfit = 0,  lure = 'corn',        hours = { 0, 24 } },
    [42] = { name = "Legendary Boar",                  model = `a_c_boar_01`,            outfit = 2,  lure = 'corn',        hours = { 21, 5 } },

    -- deer, elk and moose
    [43] = { name = "Legendary Buck",                  model = `mp_a_c_buck_01`,         outfit = 0,  lure = 'Wild_Carrot', hours = { 5, 10 } },
    [44] = { name = "Legendary Mudrunner Buck",        model = `mp_a_c_buck_01`,         outfit = 2,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [45] = { name = "Legendary Snow Buck",             model = `mp_a_c_buck_01`,         outfit = 3,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [46] = { name = "Legendary Shadow Buck",           model = `mp_a_c_buck_01`,         outfit = 4,  lure = 'Wild_Carrot', hours = { 17, 23 } },
    [47] = { name = "Legendary Buck",                  model = `a_c_buck_01`,            outfit = 3,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [48] = { name = "Legendary Katata Elk",            model = `mp_a_c_elk_01`,          outfit = 0,  lure = 'Wild_Carrot', hours = { 5, 11 } },
    [49] = { name = "Legendary Ozula Elk",             model = `mp_a_c_elk_01`,          outfit = 1,  lure = 'Wild_Carrot', hours = { 6, 12 } },
    [50] = { name = "Legendary Inahme Elk",            model = `mp_a_c_elk_01`,          outfit = 2,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [51] = { name = "Legendary Elk",                   model = `a_c_elk_01`,             outfit = 1,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [52] = { name = "Legendary Snowflake Moose",       model = `mp_a_c_moose_01`,        outfit = 1,  lure = 'Wild_Carrot', hours = { 4, 12 } },
    [53] = { name = "Legendary Knight Moose",          model = `mp_a_c_moose_01`,        outfit = 2,  lure = 'Wild_Carrot', hours = { 5, 11 } },
    [54] = { name = "Legendary Ruddy Moose",           model = `mp_a_c_moose_01`,        outfit = 3,  lure = 'Wild_Carrot', hours = { 0, 24 } },
    [55] = { name = "Legendary Moose",                 model = `a_c_moose_01`,           outfit = 6,  lure = 'Wild_Carrot', hours = { 0, 24 } },

    -- salt-lick grazers
    [56] = { name = "Legendary Pronghorn",             model = `a_c_pronghorn_01`,       outfit = 1,  lure = 'salt',        hours = { 6, 13 } },
    [57] = { name = "Legendary Gabbro Horn Ram",       model = `mp_a_c_bighornram_01`,   outfit = 0,  lure = 'salt',        hours = { 0, 24 } },
    [58] = { name = "Legendary Chalk Horn Ram",        model = `mp_a_c_bighornram_01`,   outfit = 1,  lure = 'salt',        hours = { 0, 24 } },
    [59] = { name = "Legendary Rutile Horn Ram",       model = `mp_a_c_bighornram_01`,   outfit = 2,  lure = 'salt',        hours = { 6, 12 } },
    [60] = { name = "Legendary Great Horn Ram",        model = `mp_a_c_bighornram_01`,   outfit = 3,  lure = 'salt',        hours = { 0, 24 } },
    [61] = { name = "Legendary Bighorn Ram",           model = `a_c_bighornram_01`,      outfit = 12, lure = 'salt',        hours = { 0, 24 } },
    [62] = { name = "Legendary Tatanka Bison",         model = `mp_a_c_buffalo_01`,      outfit = 0,  lure = 'salt',        hours = { 6, 14 } },
    [63] = { name = "Legendary Winyan Bison",          model = `mp_a_c_buffalo_01`,      outfit = 1,  lure = 'salt',        hours = { 13, 20 } },
    [64] = { name = "Legendary Payata Bison",          model = `mp_a_c_buffalo_01`,      outfit = 2,  lure = 'salt',        hours = { 0, 24 } },
    [65] = { name = "Legendary Bison",                 model = `a_c_buffalo_01`,         outfit = 4,  lure = 'salt',        hours = { 14, 22 } },
    [66] = { name = "Legendary Tatanka Bison",         model = `a_c_buffalo_tatanka_01`, outfit = 0,  lure = 'salt',        hours = { 20, 6 } },
}
