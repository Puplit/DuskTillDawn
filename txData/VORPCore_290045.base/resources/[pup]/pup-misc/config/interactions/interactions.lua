-- pup-misc/interactions | what can be done where (see README)
-- Menu text for every scenario and anim lives in config/interactions/locale.lua (InteractionsLocale.actions).

-------------------------------------------------------------------------------
-- SCENARIOS
-- `ped` = who the scenario suits: 'any', 'male' or 'female' (or any gate tag from the README).
-------------------------------------------------------------------------------
InteractionsConfig.Scenarios = {}
local S = InteractionsConfig.Scenarios

S.seated = {
    { scenario = 'GENERIC_SEAT_BENCH_SCENARIO',                    ped = 'any' },
    { scenario = 'GENERIC_SEAT_CHAIR_SCENARIO',                    ped = 'male' },
    { scenario = 'GENERIC_SEAT_CHAIR_TABLE_SCENARIO',              ped = 'any' },
    { scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_DRINKING',  ped = 'any' },
    { scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_BENCH_PORCH_SMOKING',   ped = 'any' },
    { scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR',                 ped = 'any' },
    { scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS',    ped = 'any' },
    { scenario = 'MP_LOBBY_PROP_HUMAN_SEAT_CHAIR_WHITTLE',         ped = 'any' },
    { scenario = 'PROP_CAMP_FIRE_SEAT_CHAIR',                      ped = 'any' },
    { scenario = 'PROP_HUMAN_CAMP_FIRE_SEAT_BOX',                  ped = 'any' },
    { scenario = 'PROP_HUMAN_SEAT_BENCH_CONCERTINA',               ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_BENCH_FIDDLE',                   ped = 'female' },
    { scenario = 'PROP_HUMAN_SEAT_BENCH_JAW_HARP',                 ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_BENCH_MANDOLIN',                 ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR',                          ped = 'any' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_BANJO',                    ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_CIGAR',                    ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_CLEAN_RIFLE',              ped = 'any' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_CLEAN_SADDLE',             ped = 'any' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_CRAB_TRAP',                ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_GROOMING_GROSS',           ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_GROOMING_POSH',            ped = 'female' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_GUITAR',                   ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_KNIFE_BADASS',             ped = 'male' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_KNITTING',                 ped = 'female' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_PORCH',                    ped = 'any' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_READING',                  ped = 'female' },
    { scenario = 'PROP_HUMAN_SEAT_CHAIR_TABLE_DRINKING',           ped = 'any' },
}

S.lying = {
    { scenario = 'PROP_HUMAN_SLEEP_BED_PILLOW',      ped = 'any' },
    { scenario = 'PROP_HUMAN_SLEEP_BED_PILLOW_HIGH', ped = 'male' },
    { scenario = 'WORLD_HUMAN_SIT_FALL_ASLEEP',      ped = 'any' },
    { scenario = 'WORLD_HUMAN_SLEEP_GROUND_ARM',     ped = 'any' },
    { scenario = 'WORLD_HUMAN_SLEEP_GROUND_PILLOW',  ped = 'any' },
    { scenario = 'WORLD_PLAYER_SLEEP_BEDROLL',       ped = 'any' },
    { scenario = 'WORLD_PLAYER_SLEEP_GROUND',        ped = 'any' },
}

S.piano = {
    { scenario = 'PROP_HUMAN_ABIGAIL_PIANO', ped = 'female' },
    { scenario = 'PROP_HUMAN_PIANO',         ped = 'male' },
}

S.seatedDrink     = { { scenario = 'PROP_HUMAN_SEAT_CHAIR_DRINKING',  ped = 'any' } }
S.seatedFan       = { { scenario = 'PROP_HUMAN_SEAT_CHAIR_FAN',       ped = 'female' } }
S.seatedHarmonica = { { scenario = 'PROP_HUMAN_SEAT_BENCH_HARMONICA', ped = 'male' } }

-------------------------------------------------------------------------------
-- ANIMATIONS
-- `id` names the menu text in InteractionsLocale.actions. A single anim plays looped.
-- `parts` stacks several anims: each starts `delay` ms after the one before, with its own `flag`.
-------------------------------------------------------------------------------
InteractionsConfig.Animations = {}
local A = InteractionsConfig.Animations

local BATH <const> = 'mini_games@bathing@regular@arthur'
A.bath = {
    { id = 'bath_soak',      dict = BATH, clip = 'bathing_idle_02' },
    { id = 'bath_left_arm',  dict = BATH, clip = 'left_arm_scrub_medium' },
    { id = 'bath_left_leg',  dict = BATH, clip = 'left_leg_scrub_medium' },
    { id = 'bath_right_arm', dict = BATH, clip = 'right_arm_scrub_medium' },
    { id = 'bath_right_leg', dict = BATH, clip = 'right_leg_scrub_medium' },
}

A.dance = {
    { id = 'dance_sway',       dict = 'amb_misc@world_human_dancing@female_a@base',   clip = 'base' },
    { id = 'dance_twirl',      dict = 'amb_misc@world_human_dancing@female_a@idle_a', clip = 'idle_c' },
    { id = 'dance_acrobat',    dict = 'script_shows@acrobatics@act3_p1',              clip = 'acrobat_acrobatics' },
    { id = 'dance_cancan_1',   dict = 'script_shows@cancandance@p1',                  clip = 'cancandance_fem0' },
    { id = 'dance_cancan_2',   dict = 'script_shows@cancandance@p2',                  clip = 'cancandance_p2_fem1' },
    { id = 'dance_flourish',   dict = 'script_shows@firebreather@act2_p1',            clip = 'dancer_breath_win' },
    { id = 'dance_showgirl',   dict = 'script_shows@firebreather@act2_p1',            clip = 'dancer_dance' },
    { id = 'dance_fire',       dict = 'script_shows@firedancer@act3_p1',              clip = 'dance' },
    { id = 'dance_performer',  dict = 'script_shows@fireperformer@act1_p1',           clip = 'action_performer' },
    { id = 'dance_snake_slow', dict = 'script_shows@snakedancer@act1_p1',             clip = 'dance_dancer' },
    { id = 'dance_snake_fast', dict = 'script_shows@snakedancer@act2_p1',             clip = 'dance_dancer' },
    { id = 'dance_sword',      dict = 'script_shows@sworddance@act3_p1',              clip = 'dancer_sworddance' },

    { id = 'dance_tipsy_cancan', parts = {
        { dict = 'ai_gestures@instruments@double_bass@standing@female@drunk', clip = 'dbass_low_pull_+1_0_-1_02', flag = 1,  delay = 0 },
        { dict = 'script_shows@cancandance@p1',                               clip = 'cancandance_fem2',          flag = 25, delay = 350 },
    } },
    { id = 'dance_limp_sway', parts = {
        { dict = 'amb_misc@world_human_dancing@female_a@idle_a',          clip = 'idle_c',            flag = 1,  delay = 0 },
        { dict = 'script_mp@endflow@endcelebration@team_grouping@8v8@v1', clip = 'coffins_a_dead_02', flag = 25, delay = 350 },
    } },
    { id = 'dance_prayer', parts = {
        { dict = 'amb_misc@world_human_waiting_impatient@female_a@idle_c', clip = 'idle_h',                   flag = 1,  delay = 0 },
        { dict = 'script_story@mud3@ig@ig_2_prayingkelonian',              clip = 'idle_deepprayer_kelonian', flag = 25, delay = 350 },
    } },
    { id = 'dance_weepy', parts = {
        { dict = 'cnv_camp@rcbch@cnv@bcanj4',     clip = 'abigail_base', flag = 31, delay = 0 },
        { dict = 'script_common@other@unapproved', clip = 'cry_loop',    flag = 1,  delay = 50 },
    } },
    { id = 'dance_stagger', parts = {
        { dict = 'mech_loco_m@generic@injured@unarmed@critical_back@idle',             clip = 'idle', flag = 1,  delay = 0 },
        { dict = 'mech_loco_m@character@arthur@injured@left_shoulder@unarmed@idle', clip = 'idle', flag = 31, delay = 50 },
        { dict = 'mech_loco_m@generic@injured@unarmed@head@idle',                   clip = 'idle', flag = 31, delay = 50 },
    } },
    { id = 'dance_jig', parts = {
        { dict = 'script_mp@emotes@prospector_jig@male@unarmed@upper', clip = 'loop',   flag = 1,  delay = 0 },
        { dict = 'script_mp@emotes@posse_up@male@unarmed@upper',       clip = 'action', flag = 25, delay = 350 },
    } },
}

-------------------------------------------------------------------------------
-- INTERACTIONS
-- On a prop:  objects = model list, radius = metres from the prop, x/y/z = offset in the prop's own
--             frame (x right, y forward, z up), heading = added to the prop's heading.
-- World spot: no objects; x/y/z/heading are world values; radius = metres from that point.
-- Anywhere:   anywhere = true; played where the player stands.
-- Also: scenarios or animations (one of the lists above), category ('sit', 'rest', 'piano', 'bathe',
-- 'dance'), side ('left' / 'right' on two-person props), effect (InteractionsConfig.Effects id),
-- ped (gate tag, see README). The offsets were measured in game.
-------------------------------------------------------------------------------
local M = InteractionsConfig.Models

InteractionsConfig.Interactions = {
    -- bedrolls and mattresses on the floor
    { objects = { 'p_amb_mattress04x', 'p_bedrollopen01x', 'p_bedrollopen03x', 'p_mattress04x', 'p_mattress07x',
                  'p_mattresscombined01x', 'p_re_bedrollopen01x', 's_bedrollfurlined01x', 's_bedrollopen01x' },
      radius = 1.5, x = 0.0, y = 0.0, z = 0.0, heading = 180.0, scenarios = S.lying, category = 'rest' },

    -- beds
    { objects = { 'p_ambbed01x', 'p_bed03x', 'p_bed09x', 'p_bedindian01x' },
      radius = 2.0, x = 0.0, y = 0.0, z = 0.5, heading = 270.0, scenarios = S.lying, category = 'rest' },

    { objects = { 'p_barstool01x' },
      radius = 1.5, x = 0.0, y = 0.0, z = 0.8, heading = 0.0, scenarios = S.seated, category = 'sit', ped = 'human' },

    -- bathtubs that are props
    { objects = { 'p_bath02x' },
      radius = 1.5, x = 0.0, y = 0.5, z = 1.0, heading = 180.0, animations = A.bath, category = 'bathe', effect = 'clean' },
    { objects = { 'p_bath03x' },
      radius = 2.0, x = -0.5, y = 0.0, z = 0.65, heading = 270.0, animations = A.bath, category = 'bathe', effect = 'clean' },

    { objects = { 'p_bed05x' },
      radius = 2.0, x = 0.0, y = -0.5, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed10x' }, side = 'left',
      radius = 2.0, x = 0.3, y = -0.2, z = 0.7, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed10x' }, side = 'right',
      radius = 2.0, x = -0.3, y = -0.2, z = 0.7, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed12x', 'p_bed13x', 'p_bed22x' },
      radius = 2.0, x = 0.0, y = -0.3, z = 0.8, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed14x', 'p_bed17x', 'p_bed21x', 'p_bedbunk03x', 'p_bedindian02x', 'p_cot01x' },
      radius = 2.0, x = 0.0, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed20madex', 'p_cs_bed20madex', 'p_cs_pro_bed_unmade' }, side = 'left',
      radius = 2.0, x = 0.3, y = -0.2, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed20madex', 'p_cs_bed20madex', 'p_cs_pro_bed_unmade' }, side = 'right',
      radius = 2.0, x = -0.3, y = -0.2, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed20x' }, side = 'left',
      radius = 2.0, x = 0.3, y = -0.2, z = 0.8, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bed20x' }, side = 'right',
      radius = 2.0, x = -0.3, y = -0.2, z = 0.8, heading = 180.0, scenarios = S.lying, category = 'rest' },
    -- measured with left on -x here, the other way round from most beds: check in game
    { objects = { 'p_bedking02x' }, side = 'left',
      radius = 2.0, x = -0.5, y = 0.5, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_bedking02x' }, side = 'right',
      radius = 2.0, x = 0.5, y = 0.5, z = 0.5, heading = 180.0, scenarios = S.lying, category = 'rest' },

    -- both ends of these benches carry the same gate
    { objects = { 'p_bench17x', 'p_benchbear01x' }, side = 'left',
      radius = 1.5, x = 0.3, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'human' },
    { objects = { 'p_bench17x', 'p_benchbear01x' }, side = 'right',
      radius = 1.5, x = -0.3, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'human' },

    { objects = { 'p_chairrusticsav01x' },
      radius = 1.5, x = 0.0, y = -0.1, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'adult' },
    { objects = { 'p_chairtall01x' },
      radius = 1.5, x = 0.0, y = 0.0, z = 0.8, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'adult' },

    { objects = { 'p_cs_ann_wrkr_bed01x', 'p_cs_roc_hse_bed', 'p_medbed01x' },
      radius = 2.0, x = 0.1, y = 0.0, z = 0.85, heading = 270.0, scenarios = S.lying, category = 'rest' },
    -- the two sides of this bed differ in y, not x: check in game
    { objects = { 'p_cs_bedsleptinbed08x' }, side = 'left',
      radius = 2.0, x = 0.3, y = -0.3, z = 0.5, heading = 270.0, scenarios = S.lying, category = 'rest' },
    { objects = { 'p_cs_bedsleptinbed08x' }, side = 'right',
      radius = 2.0, x = 0.3, y = 0.3, z = 0.5, heading = 270.0, scenarios = S.lying, category = 'rest' },

    -- pianos
    { objects = { 'p_nbmpiano01x' },
      radius = 2.0, x = 0.0, y = -0.77, z = 0.5, heading = 0.0, scenarios = S.piano, category = 'piano', ped = 'human' },
    { objects = { 'p_nbxpiano01x' },
      radius = 2.0, x = -0.1, y = -0.75, z = 0.5, heading = 0.0, scenarios = S.piano, category = 'piano', ped = 'human' },
    { objects = { 'p_piano02x', 'p_piano03x' },
      radius = 2.0, x = 0.0, y = -0.7, z = 0.5, heading = 0.0, scenarios = S.piano, category = 'piano', ped = 'human' },
    { objects = { 'sha_man_piano01' },
      radius = 2.0, x = 0.0, y = -0.75, z = 0.5, heading = 0.0, scenarios = S.piano, category = 'piano', ped = 'human' },

    -- one-person seats (children sit a little lower)
    { objects = M.seatSingle,
      radius = 1.5, x = 0.0, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'adult' },
    { objects = M.seatSingle,
      radius = 1.5, x = 0.0, y = 0.0, z = 0.4, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'child' },
    { objects = M.seatSingle,
      radius = 1.5, x = 0.0, y = 0.05, z = -0.1, heading = 180.0, scenarios = S.seatedDrink, category = 'sit', ped = 'adult' },
    { objects = M.seatSingle,
      radius = 1.5, x = 0.0, y = 0.0, z = 0.5, heading = 240.0, scenarios = S.seatedFan, category = 'sit', ped = 'adult_female' },
    { objects = M.seatSingle,
      radius = 1.5, x = 0.0, y = -0.3, z = 0.5, heading = 180.0, scenarios = S.seatedHarmonica, category = 'sit', ped = 'male' },

    -- two-person seats, one spot per end
    { objects = M.seatWide, side = 'left',
      radius = 2.0, x = 0.5, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'human' },
    { objects = M.seatWide, side = 'right',
      radius = 2.0, x = -0.5, y = 0.0, z = 0.5, heading = 180.0, scenarios = S.seated, category = 'sit', ped = 'human' },
    { objects = M.seatWide, side = 'left',
      radius = 1.5, x = 0.4, y = -0.05, z = -0.1, heading = 180.0, scenarios = S.seatedDrink, category = 'sit', ped = 'adult' },
    { objects = M.seatWide, side = 'right',
      radius = 1.5, x = -0.4, y = -0.05, z = -0.1, heading = 180.0, scenarios = S.seatedDrink, category = 'sit', ped = 'adult' },

    -- bathtubs built into the map, found by position
    { x = -5513.196,   y = -2972.139,   z = -0.75,     heading = 108.131, radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Tumbleweed
    { x = -1812.46838, y = -373.23529,  z = 166.64999, heading = 92.105,  radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Strawberry
    { x = -823.362,    y = -1318.832,   z = 43.679,    heading = 92.793,  radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Blackwater
    { x = -317.01651,  y = 761.86,      z = 117.45099, heading = 100.278, radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Valentine
    { x = 1336.35,     y = -1377.972,   z = 84.345,    heading = -96.693, radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Rhodes
    { x = 2365.649,    y = -1211.78,    z = 51.888,    heading = 3.0,     radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Bronte Mansion
    { x = 2629.4099,   y = -1223.7757,  z = 59.6699,   heading = 2.896,   radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Saint Denis
    { x = 2952.804199, y = 1335.031494, z = 44.496986, heading = 154.996, radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Annesburg
    { x = 2987.698,    y = 573.76,      z = 47.92,     heading = 171.942, radius = 2.0, animations = A.bath, category = 'bathe', effect = 'clean' }, -- Van Horn

    -- dancing where you stand (turned off by Dance.anywhere = false)
    { anywhere = true, animations = A.dance, category = 'dance', ped = 'adult' },
}
