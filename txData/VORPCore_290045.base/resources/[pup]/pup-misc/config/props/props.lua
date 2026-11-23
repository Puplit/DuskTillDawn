-- pup-misc/props | wearable props (see README)

PropsConfig.Props = {
    -- Custom props (streams resource)
    {
        item = "pup_cane_wood", label = "Wooden Cane", limit = 1,
        model  = "cane_wood",
        bone   = "skel_l_hand",
        attach = { 0.0539, 0.1546, -0.1073, -139.7477, 0.0, 0.0 },
    },
    {
        item = "pup_cane_diamond", label = "Diamond Cane", limit = 1,
        model  = "cane_diamond",
        bone   = "skel_l_hand",
        attach = { 0.0908, 0.1419, -0.0879, -139.7477, 0.0, 0.0 },
    },
    {
        item = "pup_cane_claw", label = "Claw Cane", limit = 1,
        model  = "cane_claw",
        bone   = "skel_l_hand",
        attach = { 0.0908, 0.1419, -0.0879, -139.7477, 0.0, 0.0 },
    },
    {
        item = "pup_cane_skull", label = "Skull Cane", limit = 1,
        model  = "cane_skull",
        bone   = "skel_l_hand",
        attach = { 0.0900, 0.1708, -0.1265, -139.7477, 0.0, 0.0 },
    },

    -- Mouth accessories (native props; remove any you do not want sold or held)
    {
        item = "pup_cigar", label = "Lit Cigar", limit = 1,
        model         = "p_cigarlit01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.017, -0.099, -0.045, -1.0, -0.5, 60.7 },
        attach_female = { -0.015, -0.101, -0.008, 0.0, 0.0, 76.1 },
    },
    {
        item = "pup_cigarette", label = "Cigarette", limit = 1,
        model         = "p_cigarette01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.021, -0.103, -0.044, 0.0, 0.0, 69.1 },
        attach_female = { -0.0084, -0.0852, -0.0198, 0.0000, 0.0000, 67.5620 },
    },
    {
        item = "pup_cigarette_holder", label = "Cigarette Holder", limit = 1,
        model         = "p_cigaretteholder01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.068, -0.193, -0.055, 2.7, -14.5, 65.3 },
        attach_female = { -0.036, -0.149, -0.010, 0.0, 0.0, 69.9 },
    },
    {
        item = "pup_opium_pipe", label = "Opium Pipe", limit = 1,
        model         = "p_opiumpipe01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.052, -0.188, -0.093, 25.0, 1.0, -16.7 },
        attach_female = { -0.040, -0.208, -0.022, 6.9, 4.2, -12.5 },
    },
    {
        item = "pup_pipe_clay", label = "Clay Pipe", limit = 1,
        model         = "p_pipe02x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.044, -0.227, -0.104, 0.0, 0.0, -10.5 },
        attach_female = { -0.021, -0.216, -0.062, 0.0, 0.0, -4.5 },
    },
    {
        item = "pup_pipe_corn", label = "Corn Cob Pipe", limit = 1,
        model         = "p_pipe01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.070, -0.182, -0.102, 0.6, -18.0, 56.8 },
        attach_female = { -0.073, -0.185, -0.044, 0.0, 0.0, 56.1 },
    },
    {
        item = "pup_pipe_briar", label = "Briar Pipe", limit = 1,
        model         = "p_pipe03x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.061, -0.182, -0.089, 13.3, -0.3, -26.0 },
        attach_female = { -0.049, -0.173, -0.034, 0.0, 0.0, -20.3 },
    },
    {
        item = "pup_hay", label = "Hay Piece", limit = 1,
        model         = "p_cs_haypiece01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.016, -0.097, -0.047, 98.8, 8.5, -15.8 },
        attach_female = { 0.000, -0.030, -0.001, 97.3, 12.9, -11.4 },
    },
    {
        item = "pup_toothpick", label = "Toothpick", limit = 1,
        model         = "p_toothpick01x",
        bone          = "HairScale_F_Ramp",
        attach_male   = { -0.0093, -0.0974, -0.0452, -6.8139, -1.8025, -76.1836 },
        attach_female = { -0.0012, -0.1075, -0.0191, -0.3327, 0.1169, -71.3506 },
    },

    -- Necklaces
    {
        item = "pup_cross_necklace", label = "Silver Cross Necklace", limit = 1,
        model_male    = "cross_neck_m",
        model_female  = "cross_neck_f",
        bone          = "CP_NeckBack",
        attach_male   = { -0.01, 0.00, -0.08, -54.0, 0.00, -85.0 },
        attach_female = { 0.01, 0.00, -0.08, -60.0, -1.0, -90.0 },
    },

    -- Everyday held items
    {
        item = "cane", label = "Cane", limit = 1,
        model  = "p_cane01x",
        bone   = "SKEL_L_Hand",
        attach = { 0.1000, -0.8000, 0.0300, -90.0, 1.0, 0.0 },
    },
    {
        item = "lumberaxe", label = "Lumber Axe", limit = 1,
        model         = "p_axe02x",
        bone          = "SKEL_R_Hand",
        attach_male   = { 0.0600, -0.2000, -0.0300, -90.0, -6.0, 0.0 },
        attach_female = { 0.0600, -0.2200, -0.0300, -90.0, -10.0, 0.0 },
    },
    {
        item = "parasol", label = "Parasol", limit = 1,
        model         = "p_parasol02x",
        bone          = "SKEL_R_Hand",
        attach_male   = { 0.0700, -0.0100, -0.0300, -90.0, 0.0, 0.0 },
        attach_female = { 0.0700, -0.0300, -0.0300, -90.0, 0.0, 0.0 },
        anim          = { "amb_rest_sit@prop_human_seat_bench@parasol@female_a@wip_base", "wip_base" },
    },
    {
        item = "fan", label = "Fan", limit = 1,
        model  = "P_CS_FAN01X",
        bone   = "SKEL_R_Finger13",
        attach = { 0.0000, 0.0000, -0.0200, 0.0, 120.0, 55.0 },
    },
    {
        item = "book", label = "Book", limit = 1,
        model  = "p_book01x",
        bone   = "SKEL_L_Hand",
        attach = { 0.1700, 0.0700, 0.0800, 80.0, 160.0, 180.0 },
    },
    -- notebook: a clipboard in the left hand plus a pen in the right (extra)
    {
        item = "notebook", label = "Notebook", limit = 1,
        model         = "P_AMB_CLIPBOARD_01",
        bone          = "SKEL_L_Hand",
        attach_male   = { 0.1700, 0.0700, 0.0800, 80.0, 160.0, 180.0 },
        attach_female = { 0.1700, 0.0700, 0.0800, 70.0, 155.0, 185.0 },
        extra         = {
            { model = "P_PEN01X", bone = "SKEL_R_Hand", attach = { 0.1050, 0.0550, -0.1300, -5.0000, 0.0000, 0.0000 } },
        },
    },

    -- ---------------------------------------------------------------
    -- Vanilla RDR2 held props (no streamed assets needed)
    -- ---------------------------------------------------------------
    -- Instruments
    {
        item = "pup_contrabass", label = "Double Bass", limit = 1,
        model  = "p_cs_contrabass01x",
        bone   = "CP_Chest",
        attach = { -1.3700, 0.0300, 0.0500, -88.0000, 8.0000, 260.0000 },
        anim   = { "ai_gestures@instruments@double_bass@standing@female@normal", "dbass_base" },
    },
    {
        item = "pup_banjo_snakeskin", label = "Snakeskin Banjo", limit = 1,
        model  = "s_banjosnakeskin01x",
        bone   = "CP_Back",
        attach = { -0.4400, 0.2200, -0.0100, -87.0000, -0.3000, 232.0000 },
    },
    {
        item = "pup_banjo", label = "Banjo", limit = 1,
        model  = "p_banjo01x",
        bone   = "CP_Back",
        attach = { -0.4400, 0.2200, -0.0100, -87.0000, -0.3000, 232.0000 },
    },
    {
        item = "pup_mandolin", label = "Mandolin", limit = 1,
        model  = "p_mandolin01x",
        bone   = "CP_Back",
        attach = { -0.4400, 0.2200, -0.0100, -90.0000, -0.3000, 232.0000 },
    },
    {
        item = "pup_viola", label = "Viola", limit = 1,
        model  = "p_viola01x",
        bone   = "CP_Back",
        attach = { -0.4400, 0.2200, -0.0100, -85.0000, -0.3000, 232.0000 },
    },
    {
        item = "pup_trumpet", label = "Trumpet", limit = 1,
        model  = "p_trumpet01x",
        bone   = "CP_Chest",
        attach = { -0.1800, -0.0300, 0.1200, 22.0000, 196.0000, -7.0000 },
    },

    -- Light
    {
        item = "pup_candelabra", label = "Candelabra", limit = 1,
        model  = "p_candelabra02x",
        bone   = "SKEL_R_Finger12",
        attach = { 0.0000, 0.0450, 0.2230, -189.0000, -3.0000, 96.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },
    {
        item = "pup_lantern_hanging", label = "Hanging Lantern", limit = 1,
        model  = "p_hanginglanternnbx01x",
        bone   = "skel_l_hand",
        attach = { 0.0400, 0.0000, 0.0400, -5.0000, 107.0000, -12.0000 },
        anim   = { "amb_wander@code_human_lantern_wander@male_a@base", "base" },
    },
    {
        item = "pup_lantern_brass", label = "Brass Lantern", limit = 1,
        model  = "p_lanternbrass01x",
        bone   = "skel_r_hand",
        attach = { 0.0500, -0.0800, -0.0400, -74.0000, 123.0000, 5.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },
    {
        item = "pup_lantern_brass2", label = "Brass Lantern II", limit = 1,
        model  = "p_lanternbrass02x",
        bone   = "skel_r_hand",
        attach = { 0.1200, -0.0500, -0.1200, 91.0000, -23.0000, 164.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },
    {
        item = "pup_candle", label = "Candle", limit = 1,
        model  = "p_candle04x",
        bone   = "Skel_r_hand",
        attach = { 0.0700, -0.0400, -0.0500, -67.0000, 80.0000, 2.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },
    {
        item = "pup_candle_lamp", label = "Candle Lamp", limit = 1,
        model  = "p_candlelamp01x",
        bone   = "Skel_r_hand",
        attach = { 0.0500, -0.0700, -0.0400, 14.0000, 92.0000, 82.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },

    -- Drink and smoke
    {
        item = "pup_cigar_unlit", label = "Unlit Cigar", limit = 1,
        model         = "p_cigar02x",
        bone          = "HairScale_B_Ramp",
        attach        = { -0.0580, -0.1660, -0.0650, -11.2000, 11.4000, 152.4000 },
        attach_female = { -0.0150, -0.1010, -0.0080, 0.0000, 0.0000, 76.1000 },
    },
    {
        item = "pup_whiskey_glass", label = "Whiskey Glass", limit = 1,
        model  = "p_cs_whiskeygls01x",
        bone   = "skel_r_hand",
        attach = { 0.0900, 0.0000, -0.0800, -80.0000, 0.0000, -14.0000 },
        anim   = { "mech_inventory@drinking@coffee", "base" },
    },
    {
        item = "pup_coffee_mug", label = "Coffee Mug", limit = 1,
        model  = "p_mugcoffee01x",
        bone   = "XH_R_Hand00",
        attach = { 0.0700, -0.0200, -0.0700, -92.2000, -21.0000, -27.8000 },
        anim   = { "amb_rest_drunk@world_human_coffee_drink@female_c@base", "base" },
    },

    -- Reading. A scenario brings its own book, so these use the carry-book idle instead.
    {
        item = "pup_book_worn", label = "Worn Book", limit = 1,
        model  = "p_cs_book01x",
        bone   = "skel_l_hand",
        attach = { 0.1000, -0.0200, 0.0600, -11.0000, 197.0000, -5.0000 },
        anim   = { "mech_loco_m@character@beau_gray@carry@book@idle", "idle", 9999999999, 31, 0.0 },
    },
    {
        item = "pup_book_leather", label = "Leather Book", limit = 1,
        model  = "p_cs_book04x",
        bone   = "SKEL_L_FINGER12",
        attach = { -0.0100, -0.0500, -0.0500, -137.0000, -31.0000, 311.0000 },
        anim   = { "mech_loco_m@character@beau_gray@carry@book@idle", "idle", 9999999999, 31, 0.0 },
    },
    {
        item = "pup_book_lillian", label = "Old Ledger", limit = 1,
        model  = "p_cs_lillianbook01x",
        bone   = "skel_l_hand",
        attach = { 0.0900, -0.0300, 0.0800, 5.0000, -177.0000, -15.0000 },
        anim   = { "mech_loco_m@character@beau_gray@carry@book@idle", "idle", 9999999999, 31, 0.0 },
    },
    {
        item = "pup_bible", label = "Bible", limit = 1,
        model  = "p_bookbible01x",
        bone   = "skel_r_hand",
        attach = { 0.1900, 0.0300, -0.0900, -17.0000, 217.0000, 8.0000 },
        anim   = { "script_common@shared_scenarios@stand@random@town_burial@preacher@c@base", "base", 9999999999, 31, 0.0 },
    },
    {
        item = "pup_magnifier", label = "Magnifying Glass", limit = 1,
        model  = "p_magnifyingglass01x",
        bone   = "skel_r_hand",
        attach = { 0.0800, -0.0200, -0.0400, -102.0000, -70.0000, -0.0400 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },

    -- Law
    {
        item = "pup_badge_deputy", label = "Deputy Badge", limit = 1,
        model  = "s_badgedeputy01x",
        bone   = "SKEL_L_CLAVICLE",
        attach = { 0.0700, 0.1500, 0.0900, 176.0000, 0.0000, -20.0000 },
    },
    {
        item = "pup_badge_sheriff", label = "Sheriff Badge", limit = 1,
        model  = "s_badgesherif01x",
        bone   = "SKEL_L_CLAVICLE",
        attach = { 0.0700, 0.1500, 0.0900, 176.0000, 0.0000, -20.0000 },
    },
    {
        item = "pup_badge_marshal", label = "US Marshal Badge", limit = 1,
        model  = "s_badgeusmarshal01x",
        bone   = "SKEL_L_CLAVICLE",
        attach = { 0.0700, 0.1500, 0.0900, 176.0000, 0.0000, -20.0000 },
    },
    {
        item = "pup_badge_pinkerton", label = "Pinkerton Badge", limit = 1,
        model  = "s_badgepinkerton01x",
        bone   = "SKEL_L_CLAVICLE",
        attach = { 0.0700, 0.1500, 0.0900, 176.0000, 0.0000, -20.0000 },
    },
    {
        item = "pup_badge_police", label = "Police Badge", limit = 1,
        model  = "s_badgepolice01x",
        bone   = "SKEL_L_CLAVICLE",
        attach = { 0.0700, 0.1500, 0.0900, 176.0000, 0.0000, -20.0000 },
    },
    {
        item = "pup_billyclub", label = "Billy Club", limit = 1,
        model  = "p_billyclub01x",
        bone   = "XH_R_Hand00",
        attach = { 0.0880, -0.0120, -0.0330, -153.0000, 0.0000, -94.0000 },
    },

    -- Trinkets
    {
        item = "pup_ring1", label = "Gold Band", limit = 1,
        model  = "s_inv_ring01x",
        bone   = "Skel_L_Finger31",
        attach = { 0.0300, -0.0020, -0.0100, 4.4000, -87.6000, 19.2000 },
    },
    {
        item = "pup_ring2", label = "Silver Band", limit = 1,
        model  = "s_inv_ring02x",
        bone   = "Skel_L_Finger43",
        attach = { -0.0170, -0.0240, 0.0000, 86.0000, 60.0000, 162.0000 },
    },
    {
        item = "pup_ring3", label = "Signet Ring", limit = 1,
        model  = "s_inv_ring03x",
        bone   = "Skel_R_Finger42",
        attach = { -0.0100, -0.0070, 0.0090, -2.0000, 96.0000, 9.0000 },
    },
    {
        item = "pup_ring4", label = "Jewelled Ring", limit = 1,
        model  = "s_inv_ring04x",
        bone   = "Skel_R_Finger22",
        attach = { 0.0000, -0.0040, 0.0080, 0.0000, 84.0000, 0.0000 },
    },
    {
        item = "pup_ring5", label = "Bone Ring", limit = 1,
        model  = "s_inv_ring05x",
        bone   = "Skel_L_Finger32",
        attach = { -0.0070, -0.0060, 0.0040, 0.0000, 0.0000, -47.1000 },
    },
    {
        item = "pup_necklace", label = "Necklace", limit = 1,
        model  = "s_inv_necklace02x",
        bone   = "HairScale_F_Ramp",
        attach = { 0.0000, -0.1000, 0.0900, -33.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_trinket_turtle", label = "Turtle Shell Trinket", limit = 1,
        model  = "s_turtleshelltrinket01x",
        bone   = "PH_L_Hip",
        attach = { -0.0200, 0.0300, 0.1200, 87.0000, -48.0000, -6.0000 },
    },
    {
        item = "pup_rabbit_foot", label = "Rabbit Foot", limit = 1,
        model  = "p_shoprabbitfoot01x",
        bone   = "PH_L_Hip",
        attach = { 0.0500, 0.0100, 0.1000, -75.0000, -37.0000, -41.0000 },
    },
    {
        item = "pup_feather_eagle", label = "Eagle Feather", limit = 1,
        model  = "p_cs_eaglefeather04x",
        bone   = "HairScale_B",
        attach = { -0.0100, -0.0300, 0.0500, 37.1000, 0.0000, 0.0000 },
    },
    {
        item = "pup_feather_spoonbill", label = "Spoonbill Feather", limit = 1,
        model  = "s_spoonbillfeather01x",
        bone   = "HairScale_B",
        attach = { 0.0400, 0.0850, -0.0460, 74.0000, 43.6000, -11.2000 },
    },
    {
        item = "pup_trinket_crane", label = "Crane Feather Trinket", limit = 1,
        model  = "s_cranefeathertrinket01x",
        bone   = "HairScale_B",
        attach = { -0.0120, 0.1130, -0.1330, -166.8000, 8.8000, -28.8000 },
    },
    {
        item = "pup_trinket_gold", label = "Ornate Gold Trinket", limit = 1,
        model  = "s_ornategoldtrinket01x",
        bone   = "HairScale_B",
        attach = { 0.0820, 0.0190, -0.0140, 0.0000, 4.0000, -271.0000 },
    },

    -- Occult
    {
        item = "pup_skull", label = "Human Skull", limit = 1,
        model  = "p_humanskull02x",
        bone   = "HairScale_B_Ramp",
        attach = { -0.0170, -0.0070, -0.0740, -3.1000, -1.2000, 10.5000 },
    },
    {
        item = "pup_rabbit_head", label = "Rabbit Head", limit = 1,
        model  = "p_cs_rabbithead01x",
        bone   = "HairScale_B_Ramp",
        attach = { 0.0000, 0.0000, 0.0900, 0.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_voodoo_doll", label = "Voodoo Doll", limit = 1,
        model  = "p_voodoodoll01x",
        bone   = "Skel_r_hand",
        attach = { 0.0700, 0.1300, 0.0100, -35.0000, -17.0000, -136.0000 },
    },
    {
        item = "pup_voodoo_doll2", label = "Voodoo Doll II", limit = 1,
        model  = "s_inv_voodoodoll01x",
        bone   = "Skel_r_hand",
        attach = { 0.0800, 0.1400, 0.0500, -42.0000, 6.0000, -151.0000 },
    },
    {
        item = "pup_voodoo_bag", label = "Voodoo Bag", limit = 1,
        model  = "p_bag_voodoo01x",
        bone   = "PH_L_Hip",
        attach = { 0.1600, -0.0300, 0.0000, -50.0000, 7.0000, 88.0000 },
    },
    {
        item = "pup_totem", label = "Carved Totem", limit = 1,
        model  = "p_spookynative07x",
        bone   = "skel_r_hand",
        attach = { 0.1300, 0.8200, -0.2200, -103.0000, -23.0000, -6.0000 },
    },
    {
        item = "pup_shrunken_head", label = "Shrunken Head", limit = 1,
        model  = "s_shrunkenhead01x",
        bone   = "PH_Satchel",
        attach = { 0.1100, -0.0600, 0.0800, -67.0000, -29.0000, -104.0000 },
    },
    {
        item = "pup_dreamcatcher", label = "Dreamcatcher", limit = 1,
        model  = "p_indiandream03x",
        bone   = "HairScale_B",
        attach = { -0.0360, -0.0120, -0.0930, 117.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_rattle", label = "Ritual Rattle", limit = 1,
        model  = "p_indianrattle01x",
        bone   = "HairScale_B",
        attach = { -0.0450, -0.0540, 0.0340, 168.9000, 3.9000, -72.1000 },
    },
    {
        item = "pup_mask_native", label = "Carved Mask", limit = 1,
        model  = "s_masknative01x",
        bone   = "HairScale_B",
        attach = { -0.0020, -0.0990, -0.1930, -8.5000, 0.5000, -2.0000 },
    },

    -- Odds and ends
    {
        item = "pup_scissors", label = "Barber Scissors", limit = 1,
        model  = "s_barberscissors01x",
        bone   = "Skel_R_Finger00",
        attach = { 0.1100, 0.0560, 0.0300, 18.9000, 83.7000, 8.7000 },
    },
    {
        item = "pup_stethoscope", label = "Stethoscope", limit = 1,
        model  = "p_stethascope01x",
        bone   = "CP_NeckBack",
        attach = { -0.1200, -0.0200, -0.3500, 27.0000, 0.0000, 100.0000 },
    },
    {
        item = "pup_flowers", label = "Flower Pot", limit = 1,
        model         = "p_pot_flowerarng02x",
        bone          = "SKEL_L_Hand",
        attach        = { 0.0800, -0.1000, 0.1000, 75.0000, 155.0000, 180.0000 },
        attach_female = { 0.0500, -0.1000, 0.1000, 65.0000, 150.0000, 185.0000 },
    },
    {
        item = "pup_doll", label = "Porcelain Doll", limit = 1,
        model  = "p_doll01x",
        bone   = "Skel_r_hand",
        attach = { 0.1100, -0.1500, -0.1300, -74.0000, 15.0000, 1.0000 },
    },
    {
        item = "pup_doll2", label = "Rag Doll", limit = 1,
        model  = "p_doll02x",
        bone   = "Skel_r_hand",
        attach = { 0.1600, -0.0800, -0.1400, -1.0000, 51.0000, 25.0000 },
    },
    {
        item = "pup_megaphone", label = "Megaphone", limit = 1,
        model  = "p_cs_megaphone01x",
        bone   = "SKEL_R_Finger12",
        attach = { 0.0200, -0.0200, 0.0800, 83.0000, 3.0000, -84.0000 },
        anim   = { "script_mp@moonshiner@story_missions@moon1@ig4_megaphone", "idle_hixon" },
    },
    {
        item = "pup_shoe", label = "Shoe", limit = 1,
        model  = "p_shoe01x",
        bone   = "skel_r_hand",
        attach = { 0.1000, 0.1300, -0.0400, 25.0000, 28.0000, 20.0000 },
    },
    {
        item = "pup_basket", label = "Basket", limit = 1,
        model  = "p_basket06bx",
        bone   = "skel_r_hand",
        attach = { 0.2100, -0.0800, -0.2300, -45.0000, -2.0000, 58.0000 },
        anim   = { "amb_wander@code_human_basket_wander@female_a@base", "base" },
    },
    {
        item = "pup_fan_folding", label = "Folding Fan", limit = 1,
        model  = "p_cs_fan01x",
        bone   = "SKEL_R_Finger13",
        attach = { 0.0000, 0.0000, -0.0200, 0.0000, 120.0000, 55.0000 },
        anim   = { "amb_wander@code_human_fan_wander@female_a@trans", "nonfan_trans_fan" },
    },
    {
        item = "pup_arrows", label = "Arrow Bundle", limit = 1,
        model  = "p_arrowbundle01x",
        bone   = "CP_Back",
        attach = { -0.1600, 0.0400, 0.0000, -12.0000, -16.0000, 65.0000 },
    },
    {
        item = "pup_veil", label = "Mourning Veil", limit = 1,
        model  = "p_cs_leonsnieceveil_01x",
        bone   = "HairScale_B_Ramp",
        attach = { -0.0100, 0.0100, 0.0000, -18.0000, 4.0000, 0.0000 },
    },
    {
        item = "pup_medical_box", label = "Medical Box", limit = 1,
        model  = "p_boxmedmedical01x",
        bone   = "skel_l_hand",
        attach = { 0.3000, 0.0000, 0.0900, 104.0000, -5.0000, 265.0000 },
    },
    {
        item = "pup_umbrella", label = "Umbrella", limit = 1,
        model  = "p_umbrella01x",
        bone   = "SKEL_L_Hand",
        attach = { 0.3500, -0.4500, 0.4100, -126.0000, 6.0000, 25.0000 },
    },
    {
        item = "pup_hatband1", label = "Hat Band", limit = 1,
        model  = "p_hat_band_001",
        bone   = "HairScale_B",
        attach = { 0.0020, -0.1000, 0.0110, 80.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_hatband12", label = "Hat Band IV", limit = 1,
        model  = "p_hat_band_012",
        bone   = "HairScale_B",
        attach = { 0.0010, 0.1080, -0.0410, -100.4000, 0.0000, 0.0000 },
    },
    {
        item = "pup_hatband2", label = "Hat Band II", limit = 1,
        model  = "p_hat_band_002",
        bone   = "HairScale_B",
        attach = { 0.0000, -0.1000, 0.0000, 78.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_fan_feather2", label = "Feather Fan II", limit = 1,
        model  = "p_indianfan02x",
        bone   = "HairScale_B",
        attach = { -0.0500, -0.0390, -0.0450, -27.3000, -17.4000, 0.0000 },
    },
    {
        item = "pup_fan_feather", label = "Feather Fan", limit = 1,
        model  = "p_indianfan01x",
        bone   = "HairScale_B",
        attach = { 0.0540, 0.0220, -0.0570, -36.8000, 24.0000, 4.0000 },
    },
    {
        item = "pup_hatband4", label = "Hat Band III", limit = 1,
        model  = "p_hat_band_004",
        bone   = "HairScale_B",
        attach = { -0.0030, 0.0940, -0.0690, -105.6000, 0.8000, 0.8000 },
    },
    {
        item = "pup_moneystack", label = "Stack of Bills", limit = 1,
        model  = "p_cs_billstack01x",
        bone   = "skel_l_hand",
        attach = { 0.1400, 0.0200, 0.0400, -101.0000, -83.0000, 75.0000 },
        anim   = { "script_story@mud3@ig@ig_greettheinnkeeper", "count_base_valhotelowner" },
    },
    {
        item = "pup_pen", label = "Pen", limit = 1,
        model  = "P_PEN01X",
        bone   = "SKEL_R_Hand",
        attach = { 0.1050, 0.0550, -0.1300, -5.0000, 0.0000, 0.0000 },
    },
    {
        item = "pup_candlestand", label = "Candle Stand", limit = 1,
        model  = "p_candlestand",
        bone   = "SKEL_R_Finger12",
        attach = { 0.0300, 0.0900, 0.0500, 175.0000, -7.0000, 86.0000 },
        anim   = { "mech_respawn@photo", "stand_loop_player" },
    },
    {
        item = "pup_wineglass", label = "Glass of Wine", limit = 1,
        model  = "s_wineglass01x_red",
        bone   = "skel_r_hand",
        attach = { 0.0800, -0.0400, -0.0500, -109.0000, -55.0000, -15.0000 },
        anim   = { "amb_rest_drunk@world_human_coffee_drink@female_c@base", "base" },
    },
    -- SETS. One item, several objects, placed against each other on the head.
    {
        item = "pup_headdress_owl", label = "Owl Feather Headdress", limit = 1,
        model  = "p_cs_owlfeathertrinket",
        bone   = "HairScale_B",
        attach = { 0.0000, -0.0900, 0.0500, 11.2000, 179.2000, -4.0000 },
        extra  = {
            { model = "s_cateyetrinket01x_1", bone = "HairScale_B", attach = { 0.0900, -0.0100, -0.0200, 91.6000, 4.8000, 88.0000 } },
            { model = "s_cateyetrinket01x_1", bone = "HairScale_B", attach = { -0.0900, 0.0100, -0.0200, 90.8000, -6.4000, -84.0000 } },
        },
    },
    {
        item = "pup_headdress_native", label = "Feathered Mask Headdress", limit = 1,
        model  = "s_masknative01x",
        bone   = "HairScale_B",
        attach = { -0.0020, -0.0990, -0.1930, -8.5000, 0.5000, -2.0000 },
        extra  = {
            { model = "p_cs_owlfeathertrinket", bone = "HairScale_B", attach = { 0.0000, -0.0900, 0.0500, 11.2000, 179.2000, -4.0000 } },
            { model = "s_cateyetrinket01x_1", bone = "HairScale_B", attach = { 0.0900, -0.0100, -0.0200, 91.6000, 4.8000, 88.0000 } },
            { model = "s_cateyetrinket01x_1", bone = "HairScale_B", attach = { -0.0900, 0.0100, -0.0200, 90.8000, -6.4000, -84.0000 } },
        },
    },
    -- Piano and stool ride the body root, not a bone, so they stand still while the
    -- scenario seats and plays. Piano 0.8m ahead, both 0.5m down. Tune with /pa.
    -- The bench scenario starts 0.5m below the ped, so the stool is sat on.
    {
        item = "pup_piano", label = "Upright Piano", limit = 1,
        model         = "p_nbxpiano01x",
        bone          = "ENTITY_ROOT",
        attach        = { 0.0000, 0.8000, -0.5000, 0.0000, 0.0000, 0.0000 },
        scenario      = "GENERIC_SEAT_BENCH_SCENARIO",
        scenarioSeatZ = -0.5,
        anim          = { "amb_misc@prop_human_piano@male_a@idle_b", "idle_d", 9999999999, 31, 0.0 },
        extra         = {
            { model = "p_pianochair01x", bone = "ENTITY_ROOT", attach = { 0.0000, 0.0000, -0.5000, 0.0000, 0.0000, 0.0000 } },
        },
    },
}
