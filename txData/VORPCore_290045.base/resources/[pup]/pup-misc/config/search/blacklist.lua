-- search | what a robber can never take (see README)

SearchConfig.Blacklist = {}

-- any item whose name STARTS with one of these
SearchConfig.Blacklist.prefixes = {
    'pristine_', -- every pristine clothing item
    'pet_',      -- pet whistles: a stolen one spawns nothing for the thief
    'pup_',      -- worn props (canes, pipes, jewellery, instruments)
}

-- exact weapon names (compared upper-case)
SearchConfig.Blacklist.weapons = {
    'WEAPON_MELEE_HAMMER',
    'WEAPON_MELEE_MACHETE_HORROR',
    'WEAPON_MELEE_TORCH',
}

-- exact item names
SearchConfig.Blacklist.items = {
    -- misc and keys
    'gutra', 'vampkey', 'trainkey', 'scythe', 'cri', 'vi', 'pocketoutfit', 'roses',
    'necklacekey', 'envelope', 'lifeticket', 'pet_rat', 'pet_shepherd_red',

    -- melee items (pup_armory weapons)
    'sword03', 'sword04',
    'saber03', 'cleaver01', 'hammer02', 'clamp01',
    'club01', 'club02', 'club03', 'club06',
    'crowbar01', 'pan01', 'pan02', 'stake01', 'stake02', 'knife01',
    'shovel_weapon',

    -- worn props from pup-misc
    'pup_cane_wood', 'pup_cane_diamond', 'pup_cane_claw', 'pup_cane_skull', 'pup_cigar',
    'pup_cigarette', 'pup_cigarette_holder', 'pup_opium_pipe', 'pup_pipe_clay',
    'pup_pipe_corn', 'pup_pipe_briar', 'pup_hay', 'pup_toothpick', 'pup_cross_necklace',
    'cane', 'lumberaxe', 'parasol', 'fan', 'book', 'notebook',

    -- pristine clothing (also covered by the prefix; listed so the count is honest)
    'pristine_accessories', 'pristine_armor', 'pristine_belts', 'pristine_belt_buckles',
    'pristine_boots', 'pristine_boot_accessories', 'pristine_chaps', 'pristine_cloaks',
    'pristine_clothingset', 'pristine_clothingset2', 'pristine_coats', 'pristine_coats_closed',
    'pristine_eyewear', 'pristine_gauntlets', 'pristine_gloves', 'pristine_gunbelts',
    'pristine_gunbelt_accs', 'pristine_hair_accessories', 'pristine_hats',
    'pristine_holsters_left', 'pristine_jewelry_bracelets', 'pristine_jewelry_rings_left',
    'pristine_jewelry_rings_right', 'pristine_loadouts', 'pristine_masks', 'pristine_neckties',
    'pristine_neckwear', 'pristine_pants', 'pristine_ponchos', 'pristine_satchels',
    'pristine_shirts_full', 'pristine_skirts', 'pristine_spats', 'pristine_suspenders',
    'pristine_vests',
}
