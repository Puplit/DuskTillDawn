-- pup-misc/erp | the paired poses, in menu order (see README)

ErpConfig.Emotes = {
    {
        key = 'slap', label = 'Slap', ms = 2600, level = true,
        player = { dict = 'script_re@peep_tom@spanking_cowboy', anim = 'spanking_idle_female', flag = 1 },
        target = { dict = 'script_re@peep_tom@spanking_cowboy', anim = 'spanking_idle_cowboy', flag = 1,
                   posX = -0.43, posY = 0.60, posZ = 0.09, rotZ = 90.0 },
    },
    {
        key = 'hug', label = 'Hug', ms = 20000, level = true, anywhere = true,
        player = { dict = 'cnv_camp@rchso@cnv@ccsnk_par_cnv2', anim = 'sean_base_outro', flag = 1 },
        target = { dict = 'cnv_camp@rchso@cnv@ccsnk_par_cnv2', anim = 'sean_base_outro', flag = 1,
                   posX = 0.0, posY = 0.39, posZ = 0.0, rotZ = 180.0 },
    },
    {
        key = 'hug2', label = 'Hug 2', ms = 20000, level = true, anywhere = true,
        player = { dict = 'mech_carry_box', anim = 'idle', flag = 2 },
        target = { dict = 'mech_carry_box', anim = 'idle', flag = 2,
                   posX = 0.05, posY = 0.40, posZ = 0.0, rotZ = 180.0 },
    },
    {
        key = 'hug3', label = 'Hug 3', ms = 20000, level = true, anywhere = true,
        player = { dict = 'mech_loco_m@generic@carry@box@front@idle', anim = 'idle', flag = 1 },
        target = { dict = 'mech_loco_m@generic@carry@box@front@idle', anim = 'idle', flag = 1,
                   posX = 0.05, posY = 0.20, posZ = 0.0, rotZ = 180.0 },
    },
    {
        key = 'kiss', label = 'Kiss', ms = 15000, level = true, anywhere = true,
        player = { dict = 'cnv_camp@rchso@cnv@ccsnk_par_cnv2', anim = 'sean_base_outro', flag = 1 },
        target = { dict = 'cnv_camp@rchso@cnv@ccsnk_par_cnv2', anim = 'karen_base_outro', flag = 1,
                   posX = 0.05, posY = 0.40, posZ = 0.0, rotZ = 140.0 },
    },
    {
        key = 'lietogether', label = 'Lie Together', ms = 60000, level = true,
        player = { dict = 'amb_rest_sit@world_human_sit_ground@fall_asleep@female_a@sleeping@base', anim = 'base', flag = 1 },
        target = { dict = 'amb_rest@world_human_sleep_ground@pillow@female_a@idle_a', anim = 'idle_a', flag = 1,
                   posX = 0.55, posY = 0.40, posZ = 0.03, rotZ = -90.0 },
    },
    {
        key = 'lietogether2', label = 'Lie Together 2', ms = 60000, level = true,
        player = { dict = 'amb_rest_sit@world_human_sit_ground@fall_asleep@female_a@sleeping@base', anim = 'base', flag = 1 },
        target = { dict = 'amb_camp@world_camp_jack_es_sleep@male_a@base', anim = 'base', flag = 1,
                   posX = 0.70, posY = 0.40, posZ = -0.12, rotZ = -90.0 },
    },
    {
        key = 'spank', label = 'Spank', ms = 12000, level = true,
        player = { dict = 'script_re@peep_tom@spanking_cowboy', anim = 'spanking_idle_female', flag = 1 },
        target = { dict = 'script_re@peep_tom@spanking_cowboy', anim = 'spanking_idle_cowboy', flag = 1,
                   posX = -0.43, posY = 0.60, posZ = 0.09, rotZ = 90.0 },
    },
    {
        key = 'standing', label = 'Standing', ms = 30000, level = true,
        player = { dict = 'script_story@mud3@ig@ig_1_throw_whore', anim = 'base_att', flag = 1 },
        target = { dict = 'script_story@mud3@ig@ig_1_throw_whore', anim = 'base_vtm', flag = 1,
                   posX = 0.0, posY = 0.22, posZ = 0.10, rotZ = 0.0 },
    },
}
