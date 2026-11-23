-- pup_gunsmith | the parts the bench can fit
-- Part names are the game's component names. A part is { component, label }; a range
-- { range = 'NAME_%d', first = 1, last = 8, label = 'Shade %d' } stands for one part per number.
-- Add cash = / gold = to a part or range to price it apart from GunParts.price.
-- The bench lists a slot's parts in the order written; a model's first GRIP is its stock grip.

GunParts = {
    -- price of one part unless it sets its own; Config.Bench.partCash / partGold override all
    price = { cash = 10, gold = 0 },

    -- parts every gun of a family can take (shared/catalogue.lua says which guns are in a family)
    families = {
        LONGARM = {
            BARREL_ENGRAVING = {
                { range = 'COMPONENT_LONGARM_BARREL_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            BARREL_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_BARREL_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            BARREL_MATERIAL = {
                { range = 'COMPONENT_LONGARM_BARREL_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            BARREL_RIFLING = { { 'COMPONENT_LONGARM_BARREL_RIFLING_1', 'Rifled' } },
            CYLINDER_ENGRAVING = {
                { range = 'COMPONENT_LONGARM_CYLINDER_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            CYLINDER_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_CYLINDER_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            CYLINDER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_CYLINDER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            ENGRAVING = {
                { range = 'COMPONENT_LONGARM_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            FRAME_ENGRAVING = {
                { range = 'COMPONENT_LONGARM_FRAME_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            FRAME_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_FRAME_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            FRAME_MATERIAL = {
                { range = 'COMPONENT_LONGARM_FRAME_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            GRIPSTOCK_ENGRAVING = {
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_ENGRAVING_%d', first = 1, last = 6, label = 'Pattern %d' },
            },
            GRIPSTOCK_TINT = {
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_GUTTAPERCHA', 'Guttapercha' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_PEARL', 'Pearl' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_GRAY_BIRCH', 'Gray Birch' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_BURLED', 'Burled' },
            },
            GRIP_MATERIAL = { { 'COMPONENT_LONGARM_GRIP_MATERIAL_BURLED', 'Burled' } },
            HAMMER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_HAMMER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            SCOPE = {
                { 'COMPONENT_RIFLE_SCOPE02', 'Scope 2' },
                { 'COMPONENT_RIFLE_SCOPE03', 'Scope 3' },
                { 'COMPONENT_RIFLE_SCOPE04', 'Scope 4' },
            },
            SIGHT_MATERIAL = {
                { range = 'COMPONENT_LONGARM_SIGHT_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            STRAP = {
                { 'COMPONENT_REPEATER_STRAP01', 'Repeater Strap' },
                { 'COMPONENT_RIFLE_CS_STRAP01', 'Rifle Strap' },
                { 'COMPONENT_REPEATER_CLOTH_STRAP01', 'Cloth Strap' },
                { 'COMPONENT_LEFTSHOULDER_STRAP01', 'Left Shoulder Strap' },
            },
            STRAP_TINT = {
                { range = 'COMPONENT_LONGARM_STRAP_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
            },
            TRIGGER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_TRIGGER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            WRAP_MATERIAL = {
                { 'COMPONENT_LONGARM_WRAP_MATERIAL_LEATHER', 'Leather' },
                { 'COMPONENT_LONGARM_WRAP_MATERIAL_CLOTH', 'Cloth' },
            },
            WRAP_TINT = {
                { 'COMPONENT_LONGARM_WRAP_TINT_WHITE', 'White' },
                { 'COMPONENT_LONGARM_WRAP_TINT_BLACK', 'Black' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_C_%d', first = 1, last = 9, label = 'Shade C%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_D_%d', first = 1, last = 8, label = 'Shade D%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_E_%d', first = 1, last = 10, label = 'Shade E%d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_POLKADOT_DEFAULT', 'Polkadot Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_POLKADOT_%d', first = 1, last = 5, label = 'Polkadot %d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_NATIVE_DEFAULT', 'Native Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_NATIVE_%d', first = 1, last = 5, label = 'Native %d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_TARTAN_DEFAULT', 'Tartan Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_TARTAN_%d', first = 1, last = 5, label = 'Tartan %d' },
            },
        },
        MELEE_BLADE = {
            ENGRAVING = {
                { range = 'COMPONENT_MELEE_ENGRAVING_%d', first = 1, last = 3, label = 'Pattern %d' },
            },
            ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_MELEE_ENGRAVING_MATERIAL_%d', first = 1, last = 9, label = 'Finish %d' },
                { range = 'COMPONENT_MELEE_ENGRAVING_MATERIAL_%d', first = 11, last = 14, label = 'Finish %d' },
            },
            GRIP_TINT = {
                { range = 'COMPONENT_MELEE_GRIP_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_MELEE_GRIP_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { 'COMPONENT_MELEE_GRIP_TINT_GRAY_BIRCH', 'Gray Birch' },
            },
            MELEE_BLADE_ENGRAVING = {
                { range = 'COMPONENT_MELEE_BLADE_ENGRAVING_%d', first = 1, last = 3, label = 'Pattern %d' },
            },
            MELEE_BLADE_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_MELEE_BLADE_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            MELEE_BLADE_MATERIAL = {
                { range = 'COMPONENT_MELEE_BLADE_MATERIAL_%d', first = 1, last = 9, label = 'Finish %d' },
            },
        },
        SHORTARM = {
            BARREL_ENGRAVING = {
                { range = 'COMPONENT_SHORTARM_BARREL_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            BARREL_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_BARREL_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            BARREL_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_BARREL_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            BARREL_RIFLING = { { 'COMPONENT_SHORTARM_BARREL_RIFLING_1', 'Rifled' } },
            CYLINDER_ENGRAVING = {
                { range = 'COMPONENT_SHORTARM_CYLINDER_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            CYLINDER_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_CYLINDER_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            CYLINDER_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_CYLINDER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            ENGRAVING = {
                { range = 'COMPONENT_SHORTARM_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            FRAME_ENGRAVING = {
                { range = 'COMPONENT_SHORTARM_FRAME_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            FRAME_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_FRAME_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            FRAME_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_FRAME_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            GRIPSTOCK_ENGRAVING = {
                { range = 'COMPONENT_SHORTARM_GRIPSTOCK_ENGRAVING_%d', first = 1, last = 6, label = 'Pattern %d' },
            },
            GRIPSTOCK_TINT = {
                { range = 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_GUTTAPERCHA', 'Guttapercha' },
                { 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_PEARL', 'Pearl' },
                { 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_GRAY_BIRCH', 'Gray Birch' },
                { 'COMPONENT_SHORTARM_GRIPSTOCK_TINT_BURLED', 'Burled' },
            },
            GRIP_MATERIAL = {
                { 'COMPONENT_SHORTARM_GRIP_MATERIAL_PEARL', 'Pearl' },
                { 'COMPONENT_SHORTARM_GRIP_MATERIAL_BURLED', 'Burled' },
            },
            HAMMER_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_HAMMER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            SIGHT_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_SIGHT_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            TRIGGER_MATERIAL = {
                { range = 'COMPONENT_SHORTARM_TRIGGER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
        },
        SHOTGUN = {
            BARREL_ENGRAVING = {
                { range = 'COMPONENT_SHOTGUN_BARREL_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            BARREL_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_BARREL_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            BARREL_MATERIAL = {
                { range = 'COMPONENT_LONGARM_BARREL_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            BARREL_RIFLING = { { 'COMPONENT_LONGARM_BARREL_RIFLING_1', 'Rifled' } },
            CYLINDER_ENGRAVING = {
                { range = 'COMPONENT_SHOTGUN_CYLINDER_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            CYLINDER_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_CYLINDER_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            CYLINDER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_CYLINDER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            ENGRAVING = {
                { range = 'COMPONENT_SHOTGUN_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            FRAME_ENGRAVING = {
                { range = 'COMPONENT_SHOTGUN_FRAME_ENGRAVING_%d', first = 1, last = 4, label = 'Pattern %d' },
            },
            FRAME_ENGRAVING_MATERIAL = {
                { range = 'COMPONENT_LONGARM_FRAME_ENGRAVING_MATERIAL_%d', first = 1, last = 14, label = 'Finish %d' },
            },
            FRAME_MATERIAL = {
                { range = 'COMPONENT_LONGARM_FRAME_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            GRIPSTOCK_ENGRAVING = {
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_ENGRAVING_%d', first = 1, last = 6, label = 'Pattern %d' },
            },
            GRIPSTOCK_TINT = {
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_LONGARM_GRIPSTOCK_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_GUTTAPERCHA', 'Guttapercha' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_PEARL', 'Pearl' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_GRAY_BIRCH', 'Gray Birch' },
                { 'COMPONENT_LONGARM_GRIPSTOCK_TINT_BURLED', 'Burled' },
            },
            GRIP_MATERIAL = { { 'COMPONENT_LONGARM_GRIP_MATERIAL_BURLED', 'Burled' } },
            HAMMER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_HAMMER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            SIGHT_MATERIAL = {
                { range = 'COMPONENT_LONGARM_SIGHT_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            STRAP = {
                { 'COMPONENT_REPEATER_STRAP01', 'Repeater Strap' },
                { 'COMPONENT_RIFLE_CS_STRAP01', 'Rifle Strap' },
                { 'COMPONENT_REPEATER_CLOTH_STRAP01', 'Cloth Strap' },
                { 'COMPONENT_LEFTSHOULDER_STRAP01', 'Left Shoulder Strap' },
            },
            STRAP_TINT = {
                { range = 'COMPONENT_LONGARM_STRAP_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
            },
            TRIGGER_MATERIAL = {
                { range = 'COMPONENT_LONGARM_TRIGGER_MATERIAL_%d', first = 1, last = 10, label = 'Finish %d' },
            },
            WRAP_MATERIAL = {
                { 'COMPONENT_LONGARM_WRAP_MATERIAL_LEATHER', 'Leather' },
                { 'COMPONENT_LONGARM_WRAP_MATERIAL_CLOTH', 'Cloth' },
            },
            WRAP_TINT = {
                { 'COMPONENT_LONGARM_WRAP_TINT_WHITE', 'White' },
                { 'COMPONENT_LONGARM_WRAP_TINT_BLACK', 'Black' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_B_%d', first = 1, last = 8, label = 'Shade B%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_C_%d', first = 1, last = 9, label = 'Shade C%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_D_%d', first = 1, last = 8, label = 'Shade D%d' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_E_%d', first = 1, last = 10, label = 'Shade E%d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_POLKADOT_DEFAULT', 'Polkadot Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_POLKADOT_%d', first = 1, last = 5, label = 'Polkadot %d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_NATIVE_DEFAULT', 'Native Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_NATIVE_%d', first = 1, last = 5, label = 'Native %d' },
                { 'COMPONENT_LONGARM_WRAP_TINT_TARTAN_DEFAULT', 'Tartan Plain' },
                { range = 'COMPONENT_LONGARM_WRAP_TINT_TARTAN_%d', first = 1, last = 5, label = 'Tartan %d' },
            },
        },
    },

    -- parts of one weapon model
    models = {
        WEAPON_BOW_IMPROVED = {
            CYLINDER_TINT = {
                { range = 'COMPONENT_BOW_FRAME_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
            },
            FRAME_VERTDATA = {
                { 'COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_ALLIGATOR', 'Alligator' },
                { 'COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_HORNED', 'Horned' },
                { 'COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_JAGUAR', 'Jaguar' },
                { 'COMPONENT_BOW_ROLE_ENGRAVING_IMPROVED_WOODEN_INLAY', 'Wooden Inlay' },
            },
            GRIP = {
                { 'COMPONENT_BOW_IMPROVED_GRIP', 'Standard' },
                { 'COMPONENT_BOW_IMPROVED_GRIP_ALLIGATOR', 'Alligator' },
                { 'COMPONENT_BOW_IMPROVED_GRIP_HORNED', 'Horned' },
                { 'COMPONENT_BOW_IMPROVED_GRIP_JAGUAR', 'Jaguar' },
                { 'COMPONENT_BOW_IMPROVED_GRIP_WOODEN_INLAY', 'Wooden Inlay' },
            },
            GRIPSTOCK_TINT = {
                { range = 'COMPONENT_BOW_GRIPSTOCK_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
            },
            TRIGGER_TINT = {
                { range = 'COMPONENT_BOW_TRIGGER_TINT_A_%d', first = 1, last = 8, label = 'Shade A%d' },
            },
        },
        WEAPON_KIT_BINOCULARS = {
            TORCH_MATCHSTICK = { { 'COMPONENT_BINOCULARS_SCOPE01', 'Standard Lens' } },
        },
        WEAPON_MELEE_KNIFE = {
            GRIP = {
                { 'COMPONENT_MELEE_KNIFE02_GRIP', 'Handle 02' },
                { 'COMPONENT_MELEE_KNIFE13_GRIP', 'Handle 13' },
            },
        },
        WEAPON_PISTOL_M1899 = {
            BARREL = {
                { 'COMPONENT_PISTOL_M1899_BARREL_SHORT', 'Short' },
                { 'COMPONENT_PISTOL_M1899_BARREL_LONG', 'Long' },
            },
            CLIP = { { 'COMPONENT_PISTOL_M1899_CLIP', 'Standard' } },
            GRIP = {
                { 'COMPONENT_PISTOL_M1899_GRIP', 'Standard' },
                { 'COMPONENT_PISTOL_M1899_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_PISTOL_M1899_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_PISTOL_M1899_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_PISTOL_M1899_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_PISTOL_M1899_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_PISTOL_M1899_SIGHT_WIDE', 'Wide' },
            },
        },
        WEAPON_PISTOL_MAUSER = {
            BARREL = {
                { 'COMPONENT_PISTOL_MAUSER_BARREL_SHORT', 'Short' },
                { 'COMPONENT_PISTOL_MAUSER_BARREL_LONG', 'Long' },
                { 'COMPONENT_PISTOL_MAUSER_BARREL_AZTEC', 'Aztec' },
            },
            CLIP = {
                { 'COMPONENT_PISTOL_MAUSER_CLIP', 'Standard' },
                { 'COMPONENT_PISTOL_MAUSER_CLIP_EMPTY', 'Empty' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_SHORTARM_ROLE_ENGRAVING_MAUSER_AZTEC', 'Aztec' } },
            GRIP = {
                { 'COMPONENT_PISTOL_MAUSER_GRIP', 'Standard' },
                { 'COMPONENT_PISTOL_MAUSER_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_PISTOL_MAUSER_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_PISTOL_MAUSER_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_PISTOL_MAUSER_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_PISTOL_MAUSER_GRIP_AZTEC', 'Aztec' },
            },
            SIGHT = {
                { 'COMPONENT_PISTOL_MAUSER_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_PISTOL_MAUSER_SIGHT_WIDE', 'Wide' },
            },
        },
        WEAPON_PISTOL_SEMIAUTO = {
            BARREL = {
                { 'COMPONENT_PISTOL_SEMIAUTO_BARREL_SHORT', 'Short' },
                { 'COMPONENT_PISTOL_SEMIAUTO_BARREL_LONG', 'Long' },
            },
            CLIP = { { 'COMPONENT_PISTOL_SEMIAUTO_CLIP', 'Standard' } },
            GRIP = {
                { 'COMPONENT_PISTOL_SEMIAUTO_GRIP', 'Standard' },
                { 'COMPONENT_PISTOL_SEMIAUTO_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_PISTOL_SEMIAUTO_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_PISTOL_SEMIAUTO_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_PISTOL_SEMIAUTO_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_PISTOL_SEMIAUTO_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_PISTOL_SEMIAUTO_SIGHT_WIDE', 'Wide' },
            },
        },
        WEAPON_PISTOL_VOLCANIC = {
            BARREL = {
                { 'COMPONENT_PISTOL_VOLCANIC_BARREL_SHORT', 'Short' },
                { 'COMPONENT_PISTOL_VOLCANIC_BARREL_LONG', 'Long' },
                { 'COMPONENT_PISTOL_VOLCANIC_BARREL_COLLECTOR', 'Collector' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_SHORTARM_FRAME_ENGRAVING_VOLCANIC_COLLECTOR', 'Collector' } },
            GRIP = {
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP', 'Standard' },
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP_COLLECTOR', 'Collector' },
                { 'COMPONENT_PISTOL_VOLCANIC_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_PISTOL_VOLCANIC_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_PISTOL_VOLCANIC_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_PISTOL_VOLCANIC_SIGHT_COLLECTOR', 'Collector' },
            },
        },
        WEAPON_REPEATER_CARBINE = {
            CLIP = { { 'COMPONENT_REPEATER_CARBINE_CLIP', 'Standard' } },
            GRIP = {
                { 'COMPONENT_REPEATER_CARBINE_GRIP', 'Standard' },
                { 'COMPONENT_REPEATER_CARBINE_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REPEATER_CARBINE_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_REPEATER_CARBINE_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REPEATER_CARBINE_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REPEATER_CARBINE_SIGHT_WIDE', 'Wide' },
            },
            TUBE = { { 'COMPONENT_REPEATER_CARBINE_TUBE', 'Standard' } },
            WRAP = {
                { range = 'COMPONENT_REPEATER_CARBINE_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_REPEATER_EVANS = {
            FRAME_ENGRAVING = { { 'COMPONENT_LONGARM_ROLE_ENGRAVING_EVANS_WINTER', 'Winter' } },
            GRIP = {
                { 'COMPONENT_REPEATER_EVANS_GRIP', 'Standard' },
                { 'COMPONENT_REPEATER_EVANS_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REPEATER_EVANS_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_REPEATER_EVANS_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_REPEATER_EVANS_GRIP_WINTER', 'Winter' },
            },
            SIGHT = {
                { 'COMPONENT_REPEATER_EVANS_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REPEATER_EVANS_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { 'COMPONENT_REPEATER_EVANS_WRAP', 'Standard' },
                { range = 'COMPONENT_REPEATER_EVANS_WRAP%d', first = 2, last = 6, label = 'Wrap %d' },
                { 'COMPONENT_REPEATER_EVANS_WRAP_WINTER', 'Winter' },
            },
        },
        WEAPON_REPEATER_HENRY = {
            GRIP = {
                { 'COMPONENT_REPEATER_HENRY_GRIP', 'Standard' },
                { 'COMPONENT_REPEATER_HENRY_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REPEATER_HENRY_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_REPEATER_HENRY_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REPEATER_HENRY_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REPEATER_HENRY_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_REPEATER_HENRY_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_REPEATER_WINCHESTER = {
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_FRAME_ENGRAVING_WINCHESTER_COLLECTOR', 'Collector' } },
            GRIP = {
                { 'COMPONENT_REPEATER_WINCHESTER_GRIP', 'Standard' },
                { 'COMPONENT_REPEATER_WINCHESTER_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REPEATER_WINCHESTER_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_REPEATER_WINCHESTER_GRIP_COLLECTOR', 'Collector' },
                { 'COMPONENT_REPEATER_WINCHESTER_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REPEATER_WINCHESTER_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REPEATER_WINCHESTER_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_REPEATER_WINCHESTER_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
                { 'COMPONENT_REPEATER_WINCHESTER_WRAP_COLLECTOR', 'Collector' },
            },
        },
        WEAPON_REVOLVER_CATTLEMAN = {
            BARREL = {
                { 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_SHORT', 'Short' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LONG', 'Long' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_BARREL_LEGENDARY', 'Legendary' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_SHORTARM_ROLE_ENGRAVING_CATTLEMAN_LEGENDARY', 'Legendary' } },
            GRIP = {
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP', 'Standard' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_GOOD_HONOR', 'Good Honor' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_GRIP_LEGENDARY', 'Legendary' },
            },
            SIGHT = {
                { 'COMPONENT_REVOLVER_CATTLEMAN_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REVOLVER_CATTLEMAN_SIGHT_WIDE', 'Wide' },
            },
        },
        WEAPON_REVOLVER_DOUBLEACTION = {
            BARREL = {
                { 'COMPONENT_REVOLVER_DOUBLEACTION_BARREL_SHORT', 'Short' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_BARREL_LONG', 'Long' },
            },
            GRIP = {
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP', 'Standard' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BAD_HONOR', 'Bad Honor' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_REVOLVER_DOUBLEACTION_SIGHT_NARROW', 'Narrow' },
            },
        },
        WEAPON_REVOLVER_DOUBLEACTION_EXOTIC = {
            GRIP = { { 'COMPONENT_REVOLVER_DOUBLEACTION_GRIP_EXOTIC', 'Exotic' } },
        },
        WEAPON_REVOLVER_LEMAT = {
            BARREL = {
                { 'COMPONENT_REVOLVER_LEMAT_BARREL_SHORT', 'Short' },
                { 'COMPONENT_REVOLVER_LEMAT_BARREL_LONG', 'Long' },
                { 'COMPONENT_REVOLVER_LEMAT_BARREL_BOUNTY', 'Bounty' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_SHORTARM_ROLE_ENGRAVING_LEMAT_BOUNTY', 'Bounty' } },
            GRIP = {
                { 'COMPONENT_REVOLVER_LEMAT_GRIP', 'Standard' },
                { 'COMPONENT_REVOLVER_LEMAT_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_REVOLVER_LEMAT_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_REVOLVER_LEMAT_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REVOLVER_LEMAT_GRIP_BOUNTY', 'Bounty' },
                { 'COMPONENT_REVOLVER_LEMAT_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REVOLVER_LEMAT_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REVOLVER_LEMAT_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_REVOLVER_LEMAT_SIGHT_BOUNTY', 'Bounty' },
            },
        },
        WEAPON_REVOLVER_NAVY = {
            BARREL = {
                { 'COMPONENT_REVOLVER_NAVY_BARREL_SHORT', 'Short' },
                { 'COMPONENT_REVOLVER_NAVY_BARREL_LONG', 'Long' },
                { 'COMPONENT_REVOLVER_NAVY_BARREL_CROSSOVER', 'Crossover' },
            },
            GRIP = {
                { 'COMPONENT_REVOLVER_NAVY_GRIP', 'Standard' },
                { 'COMPONENT_REVOLVER_NAVY_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REVOLVER_NAVY_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_REVOLVER_NAVY_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_REVOLVER_NAVY_GRIP_CROSSOVER', 'Crossover' },
                { 'COMPONENT_REVOLVER_NAVY_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REVOLVER_NAVY_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REVOLVER_NAVY_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_REVOLVER_NAVY_SIGHT_CROSSOVER', 'Crossover' },
            },
        },
        WEAPON_REVOLVER_SCHOFIELD = {
            BARREL = {
                { 'COMPONENT_REVOLVER_SCHOFIELD_BARREL_SHORT', 'Short' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_BARREL_LONG', 'Long' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_BARREL_BOUNTY', 'Bounty' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_SHORTARM_FRAME_ENGRAVING_SCHOFIELD_BOUNTY', 'Bounty' } },
            GRIP = {
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP', 'Standard' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP_PEARL', 'Pearl' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP_BOUNTY', 'Bounty' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REVOLVER_SCHOFIELD_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_REVOLVER_SCHOFIELD_SIGHT_BOUNTY', 'Bounty' },
            },
        },
        WEAPON_RIFLE_BOLTACTION = {
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_FRAME_ENGRAVING_BOLTACTION_BOUNTY', 'Bounty' } },
            GRIP = {
                { 'COMPONENT_RIFLE_BOLTACTION_GRIP', 'Standard' },
                { 'COMPONENT_RIFLE_BOLTACTION_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_BOLTACTION_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_BOLTACTION_GRIP_BOUNTY', 'Bounty' },
                { 'COMPONENT_RIFLE_BOLTACTION_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_RIFLE_BOLTACTION_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_RIFLE_BOLTACTION_SIGHT_NARROW', 'Narrow' },
            },
            WRAP = {
                { 'COMPONENT_RIFLE_BOLTACTION_WRAP', 'Standard' },
                { range = 'COMPONENT_RIFLE_BOLTACTION_WRAP%d', first = 2, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_RIFLE_ELEPHANT = {
            BARREL = {
                { 'COMPONENT_RIFLE_ELEPHANT_BARREL_SHORT', 'Short' },
                { 'COMPONENT_RIFLE_ELEPHANT_BARREL_LONG', 'Long' },
            },
            GRIP = {
                { 'COMPONENT_RIFLE_ELEPHANT_GRIP', 'Standard' },
                { 'COMPONENT_RIFLE_ELEPHANT_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_ELEPHANT_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_ELEPHANT_GRIP_BURLED', 'Burled' },
            },
            MAG = {
                { 'COMPONENT_RIFLE_ELEPHANT_MAG', 'Standard' },
                { 'COMPONENT_RIFLE_ELEPHANT_MAG_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_ELEPHANT_MAG_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_ELEPHANT_MAG_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_RIFLE_ELEPHANT_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_RIFLE_ELEPHANT_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { 'COMPONENT_RIFLE_ELEPHANT_WRAP1', 'Wrap 1' },
                { 'COMPONENT_RIFLE_ELEPHANT_WRAP2', 'Wrap 2' },
            },
        },
        WEAPON_RIFLE_SPRINGFIELD = {
            GRIP = {
                { 'COMPONENT_RIFLE_SPRINGFIELD_GRIP', 'Standard' },
                { 'COMPONENT_RIFLE_SPRINGFIELD_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_SPRINGFIELD_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_SPRINGFIELD_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_RIFLE_SPRINGFIELD_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_RIFLE_SPRINGFIELD_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_RIFLE_SPRINGFIELD_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_RIFLE_VARMINT = {
            CLIP = {
                { 'COMPONENT_RIFLE_VARMINT_CLIP', 'Standard' },
                { 'COMPONENT_RIFLE_VARMINT_CLIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_VARMINT_CLIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_VARMINT_CLIP_NATURALIST', 'Naturalist' },
                { 'COMPONENT_RIFLE_VARMINT_CLIP_BURLED', 'Burled' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_ROLE_ENGRAVING_VARMINT_NATURALIST', 'Naturalist' } },
            GRIP = {
                { 'COMPONENT_RIFLE_VARMINT_GRIP', 'Standard' },
                { 'COMPONENT_RIFLE_VARMINT_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_VARMINT_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_VARMINT_GRIP_NATURALIST', 'Naturalist' },
                { 'COMPONENT_RIFLE_VARMINT_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_REPEATER_PUMPACTION_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_REPEATER_PUMPACTION_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_RIFLE_VARMINT_SIGHT_NATURALIST', 'Naturalist' },
            },
            WRAP = {
                { range = 'COMPONENT_RIFLE_VARMINT_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SHOTGUN_DOUBLEBARREL = {
            BARREL = {
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_SHORT', 'Short' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_LONG', 'Long' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_BARREL_KRAMPUS', 'Krampus' },
            },
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_ROLE_ENGRAVING_DOUBLEBARREL_KRAMPUS', 'Krampus' } },
            GRIP = {
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_EXOTIC', 'Exotic' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_KRAMPUS', 'Krampus' },
            },
            MAG = {
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG', 'Standard' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_BURLED', 'Burled' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_EXOTIC', 'Exotic' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_MAG_KRAMPUS', 'Krampus' },
            },
            SIGHT = {
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_SHOTGUN_DOUBLEBARREL_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SHOTGUN_PUMP = {
            BARREL = {
                { 'COMPONENT_SHOTGUN_PUMP_BARREL_SHORT', 'Short' },
                { 'COMPONENT_SHOTGUN_PUMP_BARREL_LONG', 'Long' },
                { 'COMPONENT_SHOTGUN_PUMP_BARREL_HALLOWEEN', 'Halloween' },
            },
            CLIP = {
                { 'COMPONENT_SHOTGUN_PUMP_CLIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_PUMP_CLIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_PUMP_CLIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_PUMP_CLIP_BURLED', 'Burled' },
                { 'COMPONENT_SHOTGUN_PUMP_CLIP_TRADER', 'Trader' },
                { 'COMPONENT_SHOTGUN_PUMP_CLIP_HALLOWEEN', 'Halloween' },
            },
            FRAME_VERTDATA = {
                { 'COMPONENT_SHOTGUN_FRAME_ENGRAVING_PUMP_TRADER', 'Trader' },
                { 'COMPONENT_LONGARM_ROLE_ENGRAVING_PUMP_HALLOWEEN', 'Halloween' },
            },
            GRIP = {
                { 'COMPONENT_SHOTGUN_PUMP_GRIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_PUMP_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_PUMP_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_PUMP_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_SHOTGUN_PUMP_GRIP_TRADER', 'Trader' },
                { 'COMPONENT_SHOTGUN_PUMP_GRIP_HALLOWEEN', 'Halloween' },
            },
            SIGHT = {
                { 'COMPONENT_SHOTGUN_PUMP_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_SHOTGUN_PUMP_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_SHOTGUN_PUMP_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SHOTGUN_REPEATING = {
            BARREL = {
                { 'COMPONENT_SHOTGUN_REPEATING_BARREL_SHORT', 'Short' },
                { 'COMPONENT_SHOTGUN_REPEATING_BARREL_LONG', 'Long' },
            },
            GRIP = {
                { 'COMPONENT_SHOTGUN_REPEATING01_GRIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_REPEATING01_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_REPEATING01_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_REPEATING_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_SHOTGUN_REPEATING_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_SHOTGUN_REPEATING_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { 'COMPONENT_SHOTGUN_REPEATING01_WRAP1', 'Wrap 1' },
                { 'COMPONENT_SHOTGUN_REPEATING01_WRAP2', 'Wrap 2' },
                { range = 'COMPONENT_SHOTGUN_REPEATING_WRAP%d', first = 3, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SHOTGUN_SAWEDOFF = {
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_ROLE_ENGRAVING_SAWEDOFF_MOONSHINER', 'Moonshiner' } },
            GRIP = {
                { 'COMPONENT_SHOTGUN_SAWEDOFF_GRIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_GRIP_EBONY', 'Ebony' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_GRIP_MOONSHINER', 'Moonshiner' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_SHOTGUN_DOUBLEBARREL_GRIP_KRAMPUS', 'Krampus' },
            },
            SIGHT = {
                { 'COMPONENT_SHOTGUN_SAWED_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_SHOTGUN_SAWED_SIGHT_WIDE', 'Wide' },
                { 'COMPONENT_SHOTGUN_SAWED_SIGHT_MOONSHINER', 'Moonshiner' },
            },
            STOCK = {
                { 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK', 'Standard' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK_EBONY', 'Ebony' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK_MOONSHINER', 'Moonshiner' },
                { 'COMPONENT_SHOTGUN_SAWEDOFF_STOCK_BURLED', 'Burled' },
            },
            WRAP = {
                { range = 'COMPONENT_SHOTGUN_SAWEDOFF_WRAP%d', first = 1, last = 5, label = 'Wrap %d' },
            },
        },
        WEAPON_SHOTGUN_SEMIAUTO = {
            BARREL = {
                { 'COMPONENT_SHOTGUN_SEMIAUTO_BARREL_SHORT', 'Short' },
                { 'COMPONENT_SHOTGUN_SEMIAUTO_BARREL_LONG', 'Long' },
            },
            GRIP = {
                { 'COMPONENT_SHOTGUN_SEMIAUTO_GRIP', 'Standard' },
                { 'COMPONENT_SHOTGUN_SEMIAUTO_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SHOTGUN_SEMIAUTO_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SHOTGUN_SEMIAUTO_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_SHOTGUN_SEMIAUTO_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_SHOTGUN_SEMIAUTO_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SNIPERRIFLE_CARCANO = {
            CLIP = {
                { 'COMPONENT_RIFLE_CARCANO_CLIP', 'Standard' },
                { 'COMPONENT_RIFLE_CARCANO_CLIP_EMPTY', 'Empty' },
            },
            GRIP = {
                { 'COMPONENT_RIFLE_CARCANO_GRIP', 'Standard' },
                { 'COMPONENT_RIFLE_CARCANO_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_RIFLE_CARCANO_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_RIFLE_CARCANO_GRIP_BURLED', 'Burled' },
            },
            SIGHT = {
                { 'COMPONENT_RIFLE_CARCANO_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_RIFLE_CARCANO_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_RIFLE_CARCANO_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
        WEAPON_SNIPERRIFLE_ROLLINGBLOCK = {
            FRAME_VERTDATA = { { 'COMPONENT_LONGARM_ROLE_ENGRAVING_ROLLINGBLOCK_REAPER', 'Reaper' } },
            GRIP = {
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP', 'Standard' },
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_IRONWOOD', 'Ironwood' },
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_EXOTIC', 'Exotic' },
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_ENGRAVED', 'Engraved' },
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_BURLED', 'Burled' },
                { 'COMPONENT_SNIPERRIFLE_ROLLINGBLOCK_GRIP_REAPER', 'Reaper' },
            },
            SIGHT = {
                { 'COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_NARROW', 'Narrow' },
                { 'COMPONENT_RIFLE_ROLLINGBLOCK_SIGHT_WIDE', 'Wide' },
            },
            WRAP = {
                { range = 'COMPONENT_RIFLE_ROLLINGBLOCK_WRAP%d', first = 1, last = 6, label = 'Wrap %d' },
            },
        },
    },
}
