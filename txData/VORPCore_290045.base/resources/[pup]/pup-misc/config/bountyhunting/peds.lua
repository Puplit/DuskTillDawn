-- pup-misc/bountyhunting | ped model pools (see README)
-- A contract names a pool as its gang (outlaws, wanted men, ambushers) or its client.
-- Every ped takes a random model from the list; a model listed twice comes up twice as often.

BountyConfig.PedPools = {
    ------------------------------------------------------------------ outlaws
    -- road agents, horse thieves and small-time robbers
    roadagents = {
        'a_m_m_griroughtravellers_01', 'a_m_m_htlroughtravellers_01', 'a_m_m_nearoughtravellers_01',
        'a_m_m_sclroughtravellers_01', 'a_m_m_rkrroughtravellers_01', 'a_m_m_bivroughtravellers_01',
        'a_m_m_bynroughtravellers_01', 'a_m_m_valcriminals_01',
    },
    -- an organised gang in matching rags
    dusters = {
        'g_m_m_uniduster_01', 'g_m_m_uniduster_02', 'g_m_m_uniduster_03',
        'g_m_m_uniduster_04', 'g_m_m_uniduster_05', 'g_f_m_uniduster_01',
    },
    -- old soldiers who never went home
    greycoats = {
        'g_m_y_uniexconfeds_01', 'g_m_y_uniexconfeds_02', 'g_m_o_uniexconfeds_01',
    },
    -- New Austin raiders
    bandidos = {
        'g_m_m_unibanditos_01', 'g_m_m_unibanditos_01', 'a_m_m_unigunslinger_01',
    },
    -- backwoods families and hill people
    hillfolk = {
        'g_m_m_unimountainmen_01', 'g_m_m_uniinbred_01', 'a_m_m_btchillbilly_01', 'a_m_o_btchillbilly_01',
    },
    -- swamp and river folk, moonshiners
    bayoufolk = {
        'g_m_m_uniswamp_01', 'g_m_m_uniswamp_01', 'a_m_m_moonshiners_01', 'a_m_m_btchillbilly_01',
    },
    -- paid guns in good coats
    hiredguns = {
        'g_m_m_unicriminals_01', 'g_m_m_unicriminals_02', 'g_m_m_unigrays_01',
        'g_m_m_unigrays_02', 'g_m_m_unibraithwaites_01', 'g_m_m_unicornwallgoons_01',
    },
    -- city toughs and dock bruisers
    cityroughs = {
        'a_m_m_nbxslums_01', 'a_m_m_sdslums_02', 'a_m_m_lowersdtownfolk_02',
        'a_m_m_nbxdockworkers_01', 'a_m_m_vhtthug_01', 'a_m_m_smhthug_01',
    },
    -- miners and claim jumpers
    claimjumpers = {
        'a_m_m_asbminer_01', 'a_m_m_asbminer_02', 'a_m_m_asbminer_03',
        'a_m_m_asbminer_04', 'a_m_y_asbminer_02', 'a_m_m_strlaborer_01',
    },

    ------------------------------------------------------------------ escort clients
    gentry = {
        'a_m_m_blwupperclass_01', 'a_f_m_blwupperclass_01', 'a_m_m_rhdupperclass_01',
        'a_f_m_rhdupperclass_01', 'a_m_m_nbxupperclass_01', 'a_f_m_nbxupperclass_01', 'a_m_o_sdupperclass_01',
    },
    travellers = {
        'a_m_m_grifancytravellers_01', 'a_f_m_grifancytravellers_01', 'a_m_m_htlfancytravellers_01',
        'a_f_m_htlfancytravellers_01', 'a_m_m_sclfancytravellers_01', 'a_f_m_sclfancytravellers_01',
    },
    workfolk = {
        'a_m_m_valfarmer_01', 'a_m_m_rancher_01', 'a_m_m_emrfarmhand_01',
        'a_m_m_strlaborer_01', 'a_m_m_blwlaborer_01', 'a_f_m_valtownfolk_01',
    },
    townsfolk = {
        'a_m_m_valtownfolk_01', 'a_f_m_rhdtownfolk_01', 'a_m_m_armtownfolk_01', 'a_f_m_strtownfolk_01',
        'a_m_m_asbtownfolk_01', 'a_f_m_tumtownfolk_01', 'a_m_m_middlesdtownfolk_01', 'a_f_m_middlesdtownfolk_01',
    },
}
