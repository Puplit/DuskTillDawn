-- pup-stable | birth ranks of a new horse: { speed, acceleration, handling } by model.
-- The game keeps these on the horse ped, where the server cannot read them, so they are listed here
-- and a new horse (shop, tamed or bred) always gets these, whatever a player's game reports.
-- A model missing here uses the most common ranks of its breed, then Config.Starter.
-- To change one, edit the numbers; ranks are capped by Config.Training.ceilings.

Config.HorseBirthStats = {
    -- American Paint
    ['a_c_horse_americanpaint_greyovero'] = { 3, 3, 2 },
    ['a_c_horse_americanpaint_overo'] = { 3, 3, 2 }, -- breed value
    ['a_c_horse_americanpaint_splashedwhite'] = { 2, 2, 2 },
    ['a_c_horse_americanpaint_tobiano'] = { 3, 3, 2 }, -- breed value
    -- American Standardbred
    ['a_c_horse_americanstandardbred_black'] = { 3, 2, 3 },
    ['a_c_horse_americanstandardbred_buckskin'] = { 3, 2, 3 }, -- breed value
    ['a_c_horse_americanstandardbred_palominodapple'] = { 3, 2, 3 }, -- breed value
    ['a_c_horse_americanstandardbred_silvertailbuckskin'] = { 3, 2, 3 }, -- breed value
    ['a_c_horse_americanstandardbred_lightbuckskin'] = { 3, 2, 3 }, -- breed value
    -- Andalusian
    ['a_c_horse_andalusian_darkbay'] = { 2, 2, 2 }, -- breed value
    ['a_c_horse_andalusian_perlino'] = { 2, 2, 2 },
    ['a_c_horse_andalusian_rosegray'] = { 2, 2, 2 }, -- breed value
    -- Appaloosa
    ['a_c_horse_appaloosa_blacksnowflake'] = { 3, 3, 2 },
    ['a_c_horse_appaloosa_blanket'] = { 3, 3, 2 }, -- breed value
    ['a_c_horse_appaloosa_brownleopard'] = { 3, 3, 2 }, -- breed value
    ['a_c_horse_appaloosa_fewspotted_pc'] = { 2, 2, 2 },
    ['a_c_horse_appaloosa_leopard'] = { 3, 2, 2 },
    ['a_c_horse_appaloosa_leopardblanket'] = { 2, 2, 2 },
    -- Arabian
    ['a_c_horse_arabian_black'] = { 5, 5, 3 },
    ['a_c_horse_arabian_grey'] = { 5, 5, 3 }, -- breed value
    ['a_c_horse_arabian_redchestnut'] = { 5, 5, 3 }, -- breed value
    ['a_c_horse_arabian_rosegreybay'] = { 5, 5, 3 }, -- breed value
    ['a_c_horse_arabian_warpedbrindle_pc'] = { 5, 5, 3 }, -- breed value
    ['a_c_horse_arabian_white'] = { 5, 5, 3 }, -- breed value
    -- Ardennes
    -- A_C_Horse_Ardennes_BayRoan: no data yet
    -- A_C_Horse_Ardennes_IronGreyRoan: no data yet
    -- A_C_Horse_Ardennes_StrawberryRoan: no data yet
    -- Belgian Draft
    ['a_c_horse_belgian_blondchestnut'] = { 2, 2, 1 }, -- breed value
    ['a_c_horse_belgian_mealychestnut'] = { 2, 2, 1 },
    -- Dutch Warmblood
    ['a_c_horse_dutchwarmblood_chocolateroan'] = { 3, 2, 2 },
    ['a_c_horse_dutchwarmblood_sealbrown'] = { 2, 2, 2 }, -- breed value
    ['a_c_horse_dutchwarmblood_sootybuckskin'] = { 2, 2, 2 },
    -- Hungarian Halfbred
    ['a_c_horse_hungarianhalfbred_darkdapplegrey'] = { 2, 2, 2 },
    ['a_c_horse_hungarianhalfbred_flaxenchestnut'] = { 3, 3, 2 }, -- breed value
    ['a_c_horse_hungarianhalfbred_liverchestnut'] = { 3, 3, 2 },
    ['a_c_horse_hungarianhalfbred_piebaldtobiano'] = { 3, 3, 2 }, -- breed value
    -- Kentucky Saddler
    ['a_c_horse_kentuckysaddle_black'] = { 2, 1, 2 },
    ['a_c_horse_kentuckysaddle_buttermilkbuckskin_pc'] = { 3, 1, 2 },
    ['a_c_horse_kentuckysaddle_chestnutpinto'] = { 2, 1, 2 },
    ['a_c_horse_kentuckysaddle_grey'] = { 2, 1, 2 },
    ['a_c_horse_kentuckysaddle_silverbay'] = { 2, 1, 2 },
    -- Kladruber
    -- A_C_Horse_Kladruber_Black: no data yet
    -- A_C_Horse_Kladruber_Silver: no data yet
    -- A_C_Horse_Kladruber_Cremello: no data yet
    -- A_C_Horse_Kladruber_Grey: no data yet
    -- A_C_Horse_Kladruber_DappleRoseGrey: no data yet
    -- A_C_Horse_Kladruber_White: no data yet
    -- Missouri Fox Trotter
    ['a_c_horse_missourifoxtrotter_amberchampagne'] = { 6, 4, 2 }, -- breed value
    ['a_c_horse_missourifoxtrotter_sablechampagne'] = { 6, 4, 2 }, -- breed value
    ['a_c_horse_missourifoxtrotter_silverdapplepinto'] = { 6, 4, 2 },
    ['a_c_horse_missourifoxtrotter_blueroan'] = { 6, 4, 2 },
    ['a_c_horse_missourifoxtrotter_buckskinbrindle'] = { 6, 4, 2 }, -- breed value
    ['a_c_horse_missourifoxtrotter_dapplegrey'] = { 6, 4, 2 }, -- breed value
    ['a_c_horse_missourifoxtrotter_blacktovero'] = { 6, 4, 2 },
    -- Morgan
    ['a_c_horse_morgan_bay'] = { 2, 2, 2 },
    ['a_c_horse_morgan_bayroan'] = { 2, 1, 2 },
    ['a_c_horse_morgan_flaxenchestnut'] = { 2, 1, 2 },
    ['a_c_horse_morgan_liverchestnut_pc'] = { 3, 1, 2 },
    ['a_c_horse_morgan_palomino'] = { 2, 1, 2 },
    -- Mangy Horse
    ['a_c_horse_mp_mangy_backup'] = { 1, 1, 2 },
    ['a_c_horse_murfreebrood_mange_01'] = { 1, 1, 2 },
    ['a_c_horse_murfreebrood_mange_02'] = { 3, 2, 3 },
    ['a_c_horse_murfreebrood_mange_03'] = { 2, 2, 2 },
    -- Mustang
    ['a_c_horse_mustang_goldendun'] = { 5, 3, 1 },
    ['a_c_horse_mustang_grullodun'] = { 2, 1, 1 },
    ['a_c_horse_mustang_tigerstripedbay'] = { 5, 3, 2 }, -- breed value
    ['a_c_horse_mustang_wildbay'] = { 2, 1, 1 },
    ['a_c_horse_mustang_buckskin'] = { 5, 3, 2 },
    ['a_c_horse_mustang_chestnuttovero'] = { 5, 3, 2 },
    ['a_c_horse_mustang_reddunovero'] = { 5, 3, 2 },
    ['a_c_horse_mustang_blackovero'] = { 5, 3, 2 },
    -- Nokota
    ['a_c_horse_nokota_blueroan'] = { 6, 4, 3 }, -- breed value
    ['a_c_horse_nokota_reversedappleroan'] = { 6, 4, 3 },
    ['a_c_horse_nokota_whiteroan'] = { 3, 2, 1 },
    -- Shire
    ['a_c_horse_shire_darkbay'] = { 2, 1, 1 },
    ['a_c_horse_shire_lightgrey'] = { 2, 1, 1 },
    ['a_c_horse_shire_ravenblack'] = { 2, 1, 1 },
    -- Suffolk Punch
    -- A_C_Horse_SuffolkPunch_RedChestnut: no data yet
    -- A_C_Horse_SuffolkPunch_Sorrel: no data yet
    -- Tennessee Walker
    ['a_c_horse_tennesseewalker_blackrabicano'] = { 1, 1, 2 },
    ['a_c_horse_tennesseewalker_chestnut'] = { 1, 1, 2 },
    ['a_c_horse_tennesseewalker_dapplebay'] = { 1, 1, 2 },
    ['a_c_horse_tennesseewalker_flaxenroan'] = { 2, 2, 2 },
    ['a_c_horse_tennesseewalker_mahoganybay'] = { 1, 1, 2 },
    ['a_c_horse_tennesseewalker_redroan'] = { 1, 1, 2 },
    ['a_c_horse_tennesseewalker_goldpalomino_pc'] = { 2, 1, 2 },
    -- Thoroughbred
    ['a_c_horse_thoroughbred_blackchestnut'] = { 6, 4, 3 },
    ['a_c_horse_thoroughbred_bloodbay'] = { 6, 4, 3 }, -- breed value
    ['a_c_horse_thoroughbred_brindle'] = { 6, 4, 3 },
    ['a_c_horse_thoroughbred_dapplegrey'] = { 6, 4, 3 }, -- breed value
    ['a_c_horse_thoroughbred_reversedappleblack'] = { 6, 4, 3 }, -- breed value
    -- Turkoman
    ['a_c_horse_turkoman_darkbay'] = { 5, 4, 2 }, -- breed value
    ['a_c_horse_turkoman_silver'] = { 5, 4, 2 }, -- breed value
    ['a_c_horse_turkoman_chestnut'] = { 5, 4, 2 },
    ['a_c_horse_turkoman_grey'] = { 5, 4, 2 }, -- breed value
    ['a_c_horse_turkoman_perlino'] = { 5, 4, 2 }, -- breed value
    ['a_c_horse_gang_sadie'] = { 5, 4, 2 }, -- breed value
    ['a_c_horse_turkoman_black'] = { 5, 4, 2 },
    ['a_c_horse_turkoman_chestnutovero'] = { 5, 4, 2 }, -- breed value
    -- Criollo
    ['a_c_horse_criollo_dun'] = { 6, 4, 1 }, -- breed value
    ['a_c_horse_criollo_marblesabino'] = { 6, 4, 1 },
    ['a_c_horse_criollo_bayframeovero'] = { 6, 4, 1 },
    ['a_c_horse_criollo_baybrindle'] = { 5, 3, 1 },
    ['a_c_horse_criollo_sorrelovero'] = { 5, 3, 1 },
    ['a_c_horse_criollo_blueroanovero'] = { 4, 2, 1 },
    -- Breton
    ['a_c_horse_breton_steelgrey'] = { 5, 3, 2 },
    ['a_c_horse_breton_mealydapplebay'] = { 5, 3, 2 },
    ['a_c_horse_breton_sealbrown'] = { 5, 3, 2 }, -- breed value
    ['a_c_horse_breton_grullodun'] = { 4, 2, 2 },
    ['a_c_horse_breton_sorrel'] = { 5, 3, 2 }, -- breed value
    ['a_c_horse_breton_redroan'] = { 5, 3, 2 }, -- breed value
    -- Norfolk Roadster
    ['a_c_horse_norfolkroadster_black'] = { 6, 5, 2 }, -- breed value
    ['a_c_horse_norfolkroadster_speckledgrey'] = { 6, 5, 2 }, -- breed value
    ['a_c_horse_norfolkroadster_piebaldroan'] = { 6, 5, 2 }, -- breed value
    ['a_c_horse_norfolkroadster_rosegrey'] = { 6, 5, 2 }, -- breed value
    ['a_c_horse_norfolkroadster_dappledbuckskin'] = { 6, 5, 2 }, -- breed value
    ['a_c_horse_norfolkroadster_spottedtricolor'] = { 6, 5, 2 },
    -- Horse Mule
    -- A_C_HorseMulePainted_01: no data yet
    -- Mule
    ['a_c_horsemule_01'] = { 1, 1, 1 },
    -- Donkey
    ['a_c_donkey_01'] = { 1, 1, 1 },
    -- Gypsy Cob
    ['a_c_horse_gypsycob_piebald'] = { 1, 1, 2 }, -- breed value
    ['a_c_horse_gypsycob_skewbald'] = { 1, 1, 2 }, -- breed value
    ['a_c_horse_gypsycob_splashedbay'] = { 1, 1, 2 }, -- breed value
    ['a_c_horse_gypsycob_splashedpiebald'] = { 1, 1, 2 }, -- breed value
    ['a_c_horse_gypsycob_whiteblagdon'] = { 1, 1, 2 },
    ['a_c_horse_gypsycob_palominoblagdon'] = { 1, 1, 2 }, -- breed value
}
