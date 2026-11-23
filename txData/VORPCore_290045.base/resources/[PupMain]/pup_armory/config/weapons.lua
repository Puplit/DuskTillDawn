-- pup_armory | the weapon list: base-game RDR2 props (see README for the entry format)
-- Every weapon uses a carry style and a hold style from config/main.lua. Fine-tune each one in game
-- with /wp; staff can save a position as the server default for everyone.

Config.Weapons = Config.Weapons or {}
local function add(list) for _, w in ipairs(list) do Config.Weapons[#Config.Weapons + 1] = w end end

-------------------------------------------------------------------------------
-- TOOLS AND WORK GEAR
-------------------------------------------------------------------------------
add({
    { item = 'axe_wep',       label = "Woodcutter's Axe", model = 'p_axe02x',            kind = 'blade', carry = 'back',  hold = 'club' },
    { item = 'hatchet_wep',   label = 'Camp Hatchet',     model = 'w_melee_hatchet01',   kind = 'blade', carry = 'hip',   hold = 'club' },
    { item = 'pickaxe_wep',   label = 'Pickaxe',          model = 'p_pickaxe01x',        kind = 'blunt', carry = 'back',  hold = 'club' },
    { item = 'spade_wep',     label = 'Grave Spade',      model = 'p_shovel02x',         kind = 'blunt', carry = 'back',  hold = 'long' },
    { item = 'rake_wep',      label = 'Garden Rake',      model = 'p_rake02x',           kind = 'blunt', carry = 'back',  hold = 'long' },
    { item = 'cane_wep',      label = 'Walking Cane',     model = 'p_cane01x',           kind = 'blunt', carry = 'hip',   hold = 'club' },
    { item = 'stick_wep',     label = 'Walking Stick',    model = 'p_stick04x',          kind = 'blunt', carry = 'back',  hold = 'club' },
    { item = 'plank_wep',     label = 'Wooden Plank',     model = 'p_woodplank01x',      kind = 'blunt', carry = 'back',  hold = 'club' },
    { item = 'yardbroom_wep', label = 'Yard Broom',       model = 'p_broom04x',          kind = 'blunt', carry = 'back',  hold = 'long' },
    { item = 'skinner_wep',   label = "Skinner's Knife",  model = 'w_melee_knife06',     kind = 'knife', carry = 'belt',  hold = 'knife' },
    { item = 'shovel_weapon', label = 'Shovel',           model = 'mp005_p_collectorshovel01', kind = 'blunt', carry = 'back', hold = 'long' },
    { item = 'hammer02',      label = 'Sledge Hammer',    model = 'p_sledgehammer02x',   kind = 'blunt', carry = 'back',  hold = 'long' },
    { item = 'hammer_wep',    label = 'Hammer',           model = 'p_hammer02x',         kind = 'blunt', carry = 'hip',   hold = 'club' },
    { item = 'mallet_wep',    label = 'Mallet',           model = 'p_mallet01x',         kind = 'blunt', carry = 'hip',   hold = 'club' },
    { item = 'crowbar01',     label = 'Crowbar',          model = 'p_prybar01x',         kind = 'blunt', carry = 'back',  hold = 'club' },
    { item = 'clamp01',       label = 'Clamp',            model = 'p_clamphand01x',      kind = 'blunt', carry = 'belt',  hold = 'club' },
    { item = 'broom',         label = 'Broom',            model = 'p_broom03x',          kind = 'blunt', carry = 'back',  hold = 'long' },
    { item = 'scythe',        label = 'Scythe',           model = 'p_scythe01x',         kind = 'blade', carry = 'back',  hold = 'long' },
})

-------------------------------------------------------------------------------
-- SWORDS AND BLADES
-------------------------------------------------------------------------------
add({
    { item = 'sword03',      label = "Warrior's Sword",  model = 'p_sword01x',            kind = 'blade', carry = 'spine', hold = 'blade' },
    { item = 'sword04',      label = "Pirate's Cutlass", model = 'w_melee_brokensword01', kind = 'blade', carry = 'spine', hold = 'blade' },
    { item = 'saber03',      label = "Dancer's Sabre",   model = 's_re_dancersword01x',   kind = 'blade', carry = 'spine', hold = 'blade' },
    { item = 'cleaver01',    label = 'Butcher Cleaver',  model = 'p_cleaver01x',          kind = 'blade', carry = 'belt',  hold = 'blade' },
    { item = 'knife01',      label = 'Large Knife',      model = 'p_butcherknife01x',     kind = 'knife', carry = 'belt',  hold = 'knife' },
    { item = 'hook_knife',   label = 'Hoof Knife',       model = 'p_hoofknife01x',        kind = 'knife', carry = 'hip',   hold = 'knife' },
    { item = 'stake01',      label = 'Wooden Stake',     model = 'p_woodstake01x',        kind = 'knife', carry = 'belt',  hold = 'knife' },
    { item = 'stake02',      label = 'Metal Stake',      model = 'p_spike01x',            kind = 'knife', carry = 'belt',  hold = 'knife' },
    { item = 'stake_wooden', label = 'Sharpened Stake',  model = 'p_ambstake01x',         kind = 'knife', carry = 'belt',  hold = 'knife' },
})

-------------------------------------------------------------------------------
-- CLUBS AND ODDITIES
-------------------------------------------------------------------------------
add({
    { item = 'club01',             label = 'Club',             model = 'p_club01x',                 kind = 'blunt', carry = 'hip',  hold = 'club', jobs = { 'police', 'marshal' } },
    { item = 'club02',             label = 'Police Club',      model = 'p_billyclub01x',            kind = 'blunt', carry = 'hip',  hold = 'club', jobs = { 'police', 'marshal' } },
    { item = 'club03',             label = 'Wooden Club',      model = 'p_club02x',                 kind = 'blunt', carry = 'hip',  hold = 'club' },
    { item = 'club06',             label = 'Bone Club',        model = 'p_humanskeleton02x_thighr', kind = 'blunt', carry = 'back', hold = 'club' },
    { item = 'pan01',              label = 'Pan',              model = 'p_pan01x',                  kind = 'blunt', carry = 'back', hold = 'club' },
    { item = 'pan02',              label = 'Big Pan',          model = 'p_panlg01x',                kind = 'blunt', carry = 'back', hold = 'club' },
    { item = 'wizardstaff',        label = 'Staff',            model = 'p_wedgestick02x',           kind = 'blunt', carry = 'back', hold = 'long' },
    { item = 'proleg',             label = 'Prosthetic Leg',   model = 'p_cs_prostheticleg_01x',    kind = 'blunt', carry = 'back', hold = 'club' },
    { item = 'newspaper',          label = 'Rolled Newspaper', model = 'p_newspaperroll01x',        kind = 'blunt', carry = 'hip',  hold = 'club' },
    { item = 'tbweapon',           label = 'Field Detector',   model = 'w_electricfielddetector01', kind = 'blunt', carry = 'hip',  hold = 'club' },
    { item = 'vodkabottle',        label = 'Broken Bottle',    model = 'p_bottle004x',              kind = 'blunt', carry = 'belt', hold = 'club' },
    { item = 'horse_whip_weapons', label = 'Horse Whip',       model = 'horse_whip',                kind = 'blunt', carry = 'hip',  hold = 'club' },
})
