-- pup-misc/emotes | the chat-command emotes (see README)

-------------------------------------------------------------------------------
-- WALK STYLES  (command = walk style)
-------------------------------------------------------------------------------
EmotesConfig.WalkStyles = {
    walkcasual     = 'MP_Style_Casual',
    walkcrazy      = 'MP_Style_Crazy',
    walkdrunk      = 'MP_Style_drunk',
    walkeasy       = 'MP_Style_EasyRider',
    walkflamboyant = 'MP_Style_Flamboyant',
    walkgreenhorn  = 'MP_Style_Greenhorn',
    walkgunslinger = 'MP_Style_Gunslinger',
    walkcurious    = 'MP_Style_inquisitive',
    walkrefined    = 'MP_Style_Refined',
    walksilent     = 'MP_Style_SilentType',
    walkveteran    = 'MP_Style_Veteran',
    walkreset      = 'noanim',
}

-------------------------------------------------------------------------------
-- EMOTES  (command = KIT_EMOTE_* name)
-------------------------------------------------------------------------------
EmotesConfig.Emotes = {
    -- greetings
    wave         = 'KIT_EMOTE_GREET_GENTLEWAVE_1',
    wavenear     = 'KIT_EMOTE_GREET_WAVENEAR_1',
    wavesubtle   = 'KIT_EMOTE_GREET_SUBTLE_WAVE_1',
    bow          = 'KIT_EMOTE_GREET_RESPECTFUL_BOW_1',
    fancybow     = 'KIT_EMOTE_GREET_FANCY_BOW_1',
    hatflick     = 'KIT_EMOTE_GREET_HAT_FLICK_1',
    tiphat       = 'KIT_EMOTE_GREET_HAT_TIP_1',
    greettough   = 'KIT_EMOTE_GREET_TOUGH_1',
    thumbsup     = 'KIT_EMOTE_GREET_THUMBSUP_1',

    -- reactions
    thumbsdown   = 'KIT_EMOTE_REACTION_THUMBSDOWN_1',
    pointlaugh   = 'KIT_EMOTE_REACTION_POINTLAUGH_1',
    laugh        = 'KIT_EMOTE_REACTION_JOVIAL_LAUGH_1',
    hush         = 'KIT_EMOTE_REACTION_HUSH_YOUR_MOUTH_1',
    yeehaw       = 'KIT_EMOTE_REACTION_YEEHAW_1',
    shuffle      = 'KIT_EMOTE_REACTION_SHUFFLE_1',

    -- actions
    flex         = 'KIT_EMOTE_ACTION_FLEX_1',
    blowkiss     = 'KIT_EMOTE_ACTION_BLOW_KISS_1',
    followme     = 'KIT_EMOTE_ACTION_FOLLOW_ME_1',
    hissyfit     = 'KIT_EMOTE_ACTION_HISSYFIT_1',
    scheme       = 'KIT_EMOTE_ACTION_SCHEME_1',
    checkwatch   = 'KIT_EMOTE_ACTION_CHECK_POCKET_WATCH_1',
    jig          = 'KIT_EMOTE_ACTION_PROSPECTOR_JIG_1',

    -- taunts
    youstink     = 'KIT_EMOTE_TAUNT_YOUSTINK_1',
    throatslit   = 'KIT_EMOTE_TAUNT_THROAT_SLIT_1',
    versus       = 'KIT_EMOTE_TAUNT_VERSUS_1',
    flipoff      = 'KIT_EMOTE_TAUNT_FLIP_OFF_1',
    provoke      = 'KIT_EMOTE_TAUNT_PROVOKE_1',
    watchingyou  = 'KIT_EMOTE_TAUNT_IM_WATCHING_YOU_1',
    chicken      = 'KIT_EMOTE_TAUNT_CHICKEN_1',
    gorilla      = 'KIT_EMOTE_TAUNT_GORILLA_CHEST_1',

    -- dances
    danceawkward = 'KIT_EMOTE_DANCE_AWKWARD_A_1',
    dancecarefree= 'KIT_EMOTE_DANCE_CAREFREE_B_1',
    danceconfident='KIT_EMOTE_DANCE_CONFIDENT_A_1',
    dancecocky   = 'KIT_EMOTE_DANCE_CONFIDENT_B_1',
    dancedrunk   = 'KIT_EMOTE_DANCE_DRUNK_A_1',
    dancesimple  = 'KIT_EMOTE_DANCE_DRUNK_B_1',
    danceformal  = 'KIT_EMOTE_DANCE_FORMAL_A_1',
    dancegraceful= 'KIT_EMOTE_DANCE_GRACEFUL_A_1',
    danceold     = 'KIT_EMOTE_DANCE_OLD_A_1',
    dancewild    = 'KIT_EMOTE_DANCE_WILD_A_1',
    dancewilder  = 'KIT_EMOTE_DANCE_WILD_B_1',
}

-------------------------------------------------------------------------------
-- SCENARIOS  (command = scenario name)
-------------------------------------------------------------------------------
EmotesConfig.Scenarios = {
    mirror   = 'WORLD_HUMAN_POCKET_MIRROR',
    badass   = 'WORLD_HUMAN_BADASS',
    notebook = 'WORLD_HUMAN_WRITE_NOTEBOOK',
}

-------------------------------------------------------------------------------
-- ANIMATIONS  (TaskPlayAnim)
-------------------------------------------------------------------------------
EmotesConfig.Anims = {
    -- dancing
    dance1 = { dict = 'amb_misc@world_human_drunk_dancing@male@male_b@idle_a', name = 'idle_b' },
    dance2 = { dict = 'script_mp@emotes@dance@drunk@b@male@unarmed@full',     name = 'fullbody' },
    dance3 = { dict = 'script_mp@emotes@dance@confident@b@male@unarmed@full', name = 'fullbody' },
    dance4 = { dict = 'script_mp@emotes@dance@wild@b@male@unarmed@full',      name = 'fullbody' },
    dance5 = { dict = 'script_mp@emotes@dance@drunk@a@male@unarmed@full',     name = 'fullbody' },
    dance6 = { dict = 'script_mp@emotes@dance@old@a@male@unarmed@full',       name = 'fullbody' },
    dance7 = { dict = 'script_mp@emotes@dance@carefree@a@male@unarmed@full',  name = 'fullbody' },
    dance8 = { dict = 'script_mp@emotes@dance@awkward@a@male@unarmed@full',   name = 'fullbody' },

    -- greeting flavour
    gentletip   = { dict = 'mech_loco_m@character@dutch@fancy@unarmed@idle@_variations', name = 'idle_b' },
    bigwave     = { dict = 'mech_loco_m@character@nicholas_timmins@normal@unarmed@idle@variations@big_wave', name = 'idle' },
    subtletip   = { dict = 'mech_loco_m@character@arthur@fidgets@hat@normal@unarmed@normal@left_hand', name = 'hat_lhand_b' },
    sarcastic   = { dict = 'ai_gestures@gen_female@standing@silent', name = 'silent_neutral_wave_r_001' },
    flirtywave  = { dict = 'ai_gestures@gen_female@standing@silent', name = 'silent_flirty_greet_r_001' },
    smooth      = { dict = 'ai_gestures@arthur@standing@speaker@rt_hand', name = 'greet_cocky_l_003' },
    nod         = { dict = 'ai_gestures@gen_female@standing@silent', name = 'silent_neutral_greet_f_002' },
    clap        = { dict = 'ai_gestures@gen_male@standing@silent@script', name = 'silent_clap_f_001',
                    fdict = 'ai_gestures@gen_female@standing@silent@script', fname = 'silent_clap_f_001' },

    -- surrender / duress
    handsup     = { dict = 'mech_loco_m@generic@reaction@handsup@unarmed@tough', name = 'loop',
                    fdict = 'mech_loco_f@generic@reaction@handsup@unarmed@normal', fname = 'loop' },
    surrender   = { dict = 'mech_busted@unapproved', name = 'idle_2_hands_up' },
    hostage     = { dict = 'mini_hostage', name = 'gped_host_knl_pre' },
    prisoner    = { dict = 'script_proc@robberies@unapproved', name = 'stand_prisoner_cell_idle_a' },
    cover       = { dict = 'script_common@other@unapproved', name = 'windowwasher_shot_reaction' },

    -- injuries
    hurtarm     = { dict = 'mech_loco_m@generic@injured@unarmed@right_arm@idle', name = 'idle' },
    hurtshoulder= { dict = 'mech_loco_m@character@arthur@injured@left_shoulder@unarmed@idle', name = 'idle' },
    hurtleg     = { dict = 'mech_loco_m@generic@injured@unarmed@left_leg@idle', name = 'idle' },
    hurtchest   = { dict = 'mech_loco_m@generic@injured@unarmed@chest@idle', name = 'idle' },
    hurthead    = { dict = 'mech_loco_m@generic@injured@unarmed@head@idle', name = 'idle' },
    hurtneck    = { dict = 'mech_loco_m@generic@injured@unarmed@critical_neck_right@idle', name = 'idle' },
    hurtback    = { dict = 'mech_loco_m@generic@injured@unarmed@critical_back@idle', name = 'idle' },
    bleeding1   = { dict = 'mech_loco_m@generic@injured@unarmed@critical_ground@idle@_variations@d', name = 'idle' },
    bleeding2   = { dict = 'mech_loco_m@generic@injured@unarmed@critical_ground@idle@_variations@e', name = 'idle' },
    dying       = { dict = 'amb_misc@world_human_indian_sick_dying@male@male_b@enter', name = 'enter' },
    collapse    = { dict = 'script_story@gua2@ig@ig_walkcollapse', name = 'gua2_collapse_rf' },

    -- sickness
    sick        = { dict = 'amb_wander@upperbody_idles@sick@both_arms@male_a@idle_a', name = 'idle_c' },
    unwell      = { dict = 'script_story@fin2@ig@ig2_chase_cleet', name = 'civilian_injured_loop_a_civilian' },
    itch        = { dict = 'mech_loco_m@generic@special@unarmed@itchy@idle', name = 'idle_intro' },
    vomit       = { dict = 'amb_misc@world_human_vomit@male_a@idle_b', name = 'idle_f' },
    cough       = { dict = 'amb_misc@world_human_coughing@male_c@wip_base', name = 'wip_base' },

    -- moods and idles
    angry       = { dict = 'ai_react@react_look_layers@base_emotions@angry', name = 'direct' },
    brave       = { dict = 'ai_react@react_look_layers@base_emotions@brave', name = 'direct' },
    sad         = { dict = 'mech_loco_m@generic@emotion@unarmed@sad@idle', name = 'idle' },
    cry         = { dict = 'script_common@other@unapproved', name = 'cry_loop' },
    mourn       = { dict = 'script_common@other@unapproved', name = 'hostage_fallstoknees' },
    calm        = { dict = 'mech_loco_m@character@arthur@calming@unarmed@idle', name = 'idle' },
    nervous     = { dict = 'script_rc@rmyr4@unapproved@scared', name = 'idle' },
    impatient   = { dict = 'amb_misc@world_human_waiting_impatient@male_d@idle_b', name = 'idle_d' },
    drunkidle   = { dict = 'mech_loco_m@generic@drunk@unarmed@idle_moderate_drunk', name = 'idle' },
    drunkdance  = { dict = 'amb_misc@world_human_drunk_dancing@male@male_a@idle_b', name = 'idle_e' },
    crossarms   = { dict = 'mech_skin@buck@butcher', name = 'trans_to_stoic_butcher' },
    handswaist  = { dict = 'script_amb@stores@store_waist_stern_guy', name = 'base' },
    handsbelt   = { dict = 'mech_loco_m@character@arthur@casual@unarmed@normal_to_casual', name = 'idle_transition' },
    wait1       = { dict = 'amb_misc@world_human_stand_waiting@female_a@idle_a', name = 'idle_a' },
    wait2       = { dict = 'amb_misc@world_human_stand_waiting@female_a@idle_a', name = 'idle_b' },
    guard       = { dict = 'script_common@other@unapproved', name = 'stand_guard@idle_a' },
    cold        = { dict = 'script_re@lost_man', name = 'idle' },
    hot         = { dict = 'mech_loco_m@generic@fidgets@hot', name = 'both_hands_fanning_02' },
    thanks      = { dict = 'script_common@thank@female@unapproved', name = 'thank_c' },
    knock       = { dict = 'amb_misc@world_human_door_knock@male_a@idle_c', name = 'idle_g',
                    fdict = 'amb_misc@world_human_door_knock@male_a@idle_c', fname = 'idle_h' },
    bell        = { dict = 'script_common@service_bell@unapproved', name = 'enter' },
    writing     = { dict = 'amb_work@world_human_write_notebook@female_a@idle_c', name = 'idle_g' },
    leanrail    = { dict = 'amb_rest_lean@world_human_lean_fence_fwd_check_out_livestock@male_e@idle_c', name = 'idle_g' },
    sitground   = { dict = 'amb_camp@world_camp_fire_sit_ground@male_c@idle_a', name = 'idle_a' },
    sleep       = { dict = 'amb_rest@world_human_sleep_ground@arm@male_b@idle_b', name = 'idle_f' },
}
