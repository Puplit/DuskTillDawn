-- pup-stable | horses for sale. Breed ids and coat order are saved on horses: see README before changing.

Config.HorseDefaults = {
    saddlebag = { slots = 150, weight = 100, weapons = true },
    age       = 2,
    neverDies = true,
}

Config.Breeds = {
    {
        id = 1, name = 'American Paint', neverDies = false,
        coats = {
            { model = 'A_C_Horse_AmericanPaint_Greyovero',     name = 'Grey Overo',     price = 200 },
            { model = 'A_C_Horse_AmericanPaint_Overo',         name = 'Overo',          price = 200 },
            { model = 'A_C_Horse_AmericanPaint_SplashedWhite', name = 'Splashed White', price = 200 },
            { model = 'A_C_Horse_AmericanPaint_Tobiano',       name = 'Tobiano',        price = 200 },
        },
    },
    {
        id = 2, name = 'American Standardbred', age = 1, neverDies = false,
        coats = {
            { model = 'A_C_Horse_AmericanStandardbred_Black',              name = 'Black',                price = 400 },
            { model = 'A_C_Horse_AmericanStandardbred_Buckskin',           name = 'Buckskin',             price = 400 },
            { model = 'A_C_Horse_AmericanStandardbred_PalominoDapple',     name = 'Palomino Dapple',      price = 400 },
            { model = 'A_C_Horse_AmericanStandardbred_SilverTailBuckskin', name = 'Silver Tail Buckskin', price = 400 },
            { model = 'A_C_Horse_AmericanStandardbred_Lightbuckskin',      name = 'Light Buckskin',       price = 400 },
        },
    },
    {
        id = 3, name = 'Andalusian', age = 3, neverDies = false,
        coats = {
            { model = 'A_C_Horse_Andalusian_DarkBay',  name = 'Dark Bay',  price = 600 },
            { model = 'A_C_Horse_Andalusian_Perlino',  name = 'Perlino',   price = 600 },
            { model = 'A_C_Horse_Andalusian_RoseGray', name = 'Rose Gray', price = 600 },
        },
    },
    {
        id = 4, name = 'Appaloosa', age = false, neverDies = false,
        coats = {
            { model = 'A_C_Horse_Appaloosa_BlackSnowflake', name = 'Black Snowflake', price = 300 },
            { model = 'A_C_Horse_Appaloosa_Blanket',        name = 'Blanket',         price = 300 },
            { model = 'A_C_Horse_Appaloosa_BrownLeopard',   name = 'Brown Leopard',   price = 300 },
            { model = 'A_C_Horse_Appaloosa_FewSpotted_PC',  name = 'Few Spotted',     price = 300 },
            { model = 'A_C_Horse_Appaloosa_Leopard',        name = 'Leopard',         price = 300 },
            { model = 'A_C_Horse_Appaloosa_LeopardBlanket', name = 'Leopard Blanket', price = 300 },
        },
    },
    {
        id = 5, name = 'Arabian',
        coats = {
            { model = 'A_C_Horse_Arabian_Black',            name = 'Black',                     price = 10000 },
            { model = 'A_C_Horse_Arabian_Grey',             name = 'Grey',                      price = 10000 },
            { model = 'A_C_Horse_Arabian_RedChestnut',      name = 'White Stripe Red Chestnut', price = 10000 },
            { model = 'A_C_Horse_Arabian_RoseGreyBay',      name = 'Rose Grey Bay',             price = 10000 },
            { model = 'A_C_Horse_Arabian_WarpedBrindle_PC', name = 'Warped Brindle',            price = 10000 },
            { model = 'A_C_Horse_Arabian_White',            name = 'White',                     price = 10000 },
        },
    },
    {
        id = 6, name = 'Ardennes',
        coats = {
            { model = 'A_C_Horse_Ardennes_BayRoan',        name = 'Bay Roan',        price = 400 },
            { model = 'A_C_Horse_Ardennes_IronGreyRoan',   name = 'Iron Grey Roan',  price = 400 },
            { model = 'A_C_Horse_Ardennes_StrawberryRoan', name = 'Strawberry Roan', price = 400 },
        },
    },
    {
        id = 7, name = 'Belgian Draft',
        coats = {
            { model = 'A_C_Horse_Belgian_BlondChestnut', name = 'Blond Chestnut', price = 300 },
            { model = 'A_C_Horse_Belgian_MealyChestnut', name = 'Mealy Chestnut', price = 300 },
        },
    },
    {
        id = 8, name = 'Dutch Warmblood',
        coats = {
            { model = 'A_C_Horse_DutchWarmblood_ChocolateRoan', name = 'Chocolate Roan', price = 800 },
            { model = 'A_C_Horse_DutchWarmblood_SealBrown',     name = 'Seal Brown',     price = 800 },
            { model = 'A_C_Horse_DutchWarmblood_SootyBuckskin', name = 'Sooty Buckskin', price = 800 },
        },
    },
    {
        id = 9, name = 'Hungarian Halfbred',
        coats = {
            { model = 'A_C_Horse_HungarianHalfbred_DarkDappleGrey', name = 'Dark Dapple Grey', price = 1000 },
            { model = 'A_C_Horse_HungarianHalfbred_FlaxenChestnut', name = 'Flaxen Chestnut',  price = 1000 },
            { model = 'A_C_Horse_HungarianHalfbred_LiverChestnut',  name = 'Liver Chestnut',   price = 1000 },
            { model = 'A_C_Horse_HungarianHalfbred_PiebaldTobiano', name = 'Piebald Tobiano',  price = 1000 },
        },
    },
    {
        id = 10, name = 'Kentucky Saddler',
        coats = {
            { model = 'A_C_Horse_KentuckySaddle_Black',                 name = 'Black',                price = 100 },
            { model = 'A_C_Horse_KentuckySaddle_ButterMilkBuckskin_PC', name = 'Butter Milk Buckskin', price = 100 },
            { model = 'A_C_Horse_KentuckySaddle_ChestnutPinto',         name = 'Chestnut Pinto',       price = 100 },
            { model = 'A_C_Horse_KentuckySaddle_Grey',                  name = 'Grey',                 price = 100 },
            { model = 'A_C_Horse_KentuckySaddle_SilverBay',             name = 'Silver Bay',           price = 100 },
        },
    },
    {
        id = 11, name = 'Kladruber',
        coats = {
            { model = 'A_C_Horse_Kladruber_Black',          name = 'Black',            price = 2000 },
            { model = 'A_C_Horse_Kladruber_Silver',         name = 'Silver',           price = 2000 },
            { model = 'A_C_Horse_Kladruber_Cremello',       name = 'Cremello',         price = 2000 },
            { model = 'A_C_Horse_Kladruber_Grey',           name = 'Grey',             price = 2000 },
            { model = 'A_C_Horse_Kladruber_DappleRoseGrey', name = 'Dapple Rose Grey', price = 2000 },
            { model = 'A_C_Horse_Kladruber_White',          name = 'White',            price = 2000 },
        },
    },
    {
        id = 12, name = 'Missouri Fox Trotter',
        coats = {
            { model = 'A_C_Horse_MissouriFoxTrotter_AmberChampagne',    name = 'Amber Champagne',     price = 3000 },
            { model = 'A_C_Horse_MissouriFoxTrotter_SableChampagne',    name = 'Sable Champagne',     price = 3000 },
            { model = 'A_C_Horse_MissouriFoxTrotter_SilverDapplePinto', name = 'Silver Dapple Pinto', price = 3000 },
            { model = 'a_c_horse_missourifoxtrotter_blueroan',          name = 'Blue Roan',           price = 3000 },
            { model = 'a_c_horse_missourifoxtrotter_buckskinbrindle',   name = 'Buckskin Brindle',    price = 3000 },
            { model = 'a_c_horse_missourifoxtrotter_dapplegrey',        name = 'Dapple Grey',         price = 3000 },
            { model = 'A_C_Horse_MissouriFoxTrotter_Blacktovero',       name = 'Black Tovero',        price = 3000 },
        },
    },
    {
        id = 13, name = 'Morgan', saddlebag = { slots = 100, weight = 100, weapons = true },
        coats = {
            { model = 'A_C_Horse_Morgan_Bay',              name = 'Bay',             price = 50 },
            { model = 'A_C_Horse_Morgan_BayRoan',          name = 'Bay Roan',        price = 50 },
            { model = 'A_C_Horse_Morgan_FlaxenChestnut',   name = 'Flaxen Chestnut', price = 50 },
            { model = 'A_C_Horse_Morgan_LiverChestnut_PC', name = 'Liver Chestnut',  price = 50 },
            { model = 'A_C_Horse_Morgan_Palomino',         name = 'Palomino',        price = 50 },
        },
    },
    {
        id = 14, name = 'Mangy Horse',
        coats = {
            { model = 'A_C_Horse_MP_Mangy_Backup',       name = 'Flaxen Chestnut',        price = 20 },
            { model = 'A_C_Horse_MurfreeBrood_Mange_01', name = 'Scarred Blanket',        price = 20 },
            { model = 'A_C_Horse_MurfreeBrood_Mange_02', name = 'Scarred Blue Roan',      price = 20 },
            { model = 'A_C_Horse_MurfreeBrood_Mange_03', name = 'Scarred Black Rabicano', price = 20 },
        },
    },
    {
        id = 15, name = 'Mustang',
        coats = {
            { model = 'A_C_Horse_Mustang_GoldenDun',       name = 'Golden Dun',        price = 800 },
            { model = 'A_C_Horse_Mustang_GrulloDun',       name = 'Grullo Dun',        price = 800 },
            { model = 'A_C_Horse_Mustang_TigerStripedBay', name = 'Tiger Striped Bay', price = 800 },
            { model = 'A_C_Horse_Mustang_WildBay',         name = 'Wild Bay',          price = 800 },
            { model = 'a_c_horse_mustang_buckskin',        name = 'Buckskin',          price = 800 },
            { model = 'a_c_horse_mustang_chestnuttovero',  name = 'Chestnut Tovero',   price = 800 },
            { model = 'a_c_horse_mustang_reddunovero',     name = 'Red Dun Overo',     price = 800 },
            { model = 'A_C_HORSE_MUSTANG_BLACKOVERO',      name = 'Black Overo',       price = 800 },
        },
    },
    {
        id = 16, name = 'Nokota',
        coats = {
            { model = 'A_C_Horse_Nokota_BlueRoan',          name = 'Blue Roan',           price = 300 },
            { model = 'A_C_Horse_Nokota_ReverseDappleRoan', name = 'Reverse Dapple Roan', price = 300 },
            { model = 'A_C_Horse_Nokota_WhiteRoan',         name = 'White Roan',          price = 300 },
        },
    },
    {
        id = 17, name = 'Shire',
        coats = {
            { model = 'A_C_Horse_Shire_DarkBay',    name = 'Dark Bay',    price = 200 },
            { model = 'A_C_Horse_Shire_LightGrey',  name = 'Light Grey',  price = 200 },
            { model = 'A_C_Horse_Shire_RavenBlack', name = 'Raven Black', price = 200 },
        },
    },
    {
        id = 18, name = 'Suffolk Punch',
        coats = {
            { model = 'A_C_Horse_SuffolkPunch_RedChestnut', name = 'Red Chestnut', price = 200 },
            { model = 'A_C_Horse_SuffolkPunch_Sorrel',      name = 'Sorrel',       price = 200 },
        },
    },
    {
        id = 19, name = 'Tennessee Walker',
        coats = {
            { model = 'A_C_Horse_TennesseeWalker_BlackRabicano',   name = 'Black Rabicano', price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_Chestnut',        name = 'Chestnut',       price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_DappleBay',       name = 'Dapple Bay',     price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_FlaxenRoan',      name = 'Flaxen Roan',    price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_MahoganyBay',     name = 'Mahogany Bay',   price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_RedRoan',         name = 'Red Roan',       price = 100 },
            { model = 'A_C_Horse_TennesseeWalker_GoldPalomino_PC', name = 'Gold Palomino',  price = 100 },
        },
    },
    {
        id = 20, name = 'Thoroughbred',
        coats = {
            { model = 'A_C_Horse_Thoroughbred_BlackChestnut',      name = 'Black Chestnut',       price = 3000 },
            { model = 'A_C_Horse_Thoroughbred_BloodBay',           name = 'Blood Bay',            price = 3000 },
            { model = 'A_C_Horse_Thoroughbred_Brindle',            name = 'Brindle',              price = 3000 },
            { model = 'A_C_Horse_Thoroughbred_DappleGrey',         name = 'Dapple Grey',          price = 3000 },
            { model = 'A_C_Horse_Thoroughbred_ReverseDappleBlack', name = 'Reverse Dapple Black', price = 3000 },
        },
    },
    {
        id = 21, name = 'Turkoman',
        coats = {
            { model = 'A_C_Horse_Turkoman_DarkBay',       name = 'Dark Bay',       price = 5000 },
            { model = 'A_C_Horse_Turkoman_Silver',        name = 'Silver',         price = 5000 },
            { model = 'a_c_horse_turkoman_chestnut',      name = 'Chestnut',       price = 5000 },
            { model = 'a_c_horse_turkoman_grey',          name = 'Grey',           price = 5000 },
            { model = 'a_c_horse_turkoman_perlino',       name = 'Perlino',        price = 5000 },
            { model = 'a_c_horse_gang_sadie',             name = 'Gold Dapple',    price = 5000 },
            { model = 'A_C_HORSE_TURKOMAN_BLACK',         name = 'Black',          price = 5000 },
            { model = 'A_C_HORSE_TURKOMAN_CHESTNUTOVERO', name = 'Chestnut Overo', price = 5000 },
        },
    },
    {
        id = 22, name = 'Criollo',
        coats = {
            { model = 'A_C_Horse_Criollo_Dun',           name = 'Dun',             price = 1000 },
            { model = 'A_C_Horse_Criollo_MarbleSabino',  name = 'Marble Sabino',   price = 1000 },
            { model = 'A_C_Horse_Criollo_BayFrameOvero', name = 'Bay Frame Overo', price = 1000 },
            { model = 'A_C_Horse_Criollo_BayBrindle',    name = 'Bay Brindle',     price = 1000 },
            { model = 'A_C_Horse_Criollo_SorrelOvero',   name = 'Sorrel Overo',    price = 1000 },
            { model = 'A_C_Horse_Criollo_BlueRoanOvero', name = 'Blue Roan Overo', price = 1000 },
        },
    },
    {
        id = 23, name = 'Breton',
        coats = {
            { model = 'A_C_Horse_Breton_SteelGrey',      name = 'Steel Grey',       price = 600 },
            { model = 'A_C_Horse_Breton_MealyDappleBay', name = 'Mealy Dapple Bay', price = 600 },
            { model = 'A_C_Horse_Breton_SealBrown',      name = 'Seal Brown',       price = 600 },
            { model = 'A_C_Horse_Breton_GrulloDun',      name = 'Grullo Dun',       price = 600 },
            { model = 'A_C_Horse_Breton_Sorrel',         name = 'Sorrel',           price = 600 },
            { model = 'A_C_Horse_Breton_RedRoan',        name = 'Red Roan',         price = 600 },
        },
    },
    {
        id = 24, name = 'Norfolk Roadster',
        coats = {
            { model = 'A_C_HORSE_NORFOLKROADSTER_BLACK',           name = 'Black',            price = 1000 },
            { model = 'A_C_HORSE_NORFOLKROADSTER_SPECKLEDGREY',    name = 'Speckled Grey',    price = 1000 },
            { model = 'A_C_HORSE_NORFOLKROADSTER_PIEBALDROAN',     name = 'Piebald Roan',     price = 1000 },
            { model = 'A_C_HORSE_NORFOLKROADSTER_ROSEGREY',        name = 'Rose Grey',        price = 1000 },
            { model = 'A_C_HORSE_NORFOLKROADSTER_DAPPLEDBUCKSKIN', name = 'Dappled Buckskin', price = 1000 },
            { model = 'A_C_HORSE_NORFOLKROADSTER_SPOTTEDTRICOLOR', name = 'Spotted Tricolor', price = 1000 },
        },
    },
    {
        id = 25, name = 'Horse Mule',
        coats = {
            { model = 'A_C_HorseMulePainted_01', name = 'Painted Mule', price = 15000 },
        },
    },
    {
        id = 26, name = 'Mule',
        coats = {
            { model = 'A_C_HorseMule_01', name = 'Mule', price = 20 },
        },
    },
    {
        id = 27, name = 'Donkey', saddlebag = { slots = 50, weight = 100, weapons = true },
        coats = {
            { model = 'A_C_Donkey_01', name = 'Donkey', price = 50 },
        },
    },
    {
        id = 28, name = 'Gypsy Cob',
        coats = {
            { model = 'a_c_horse_gypsycob_piebald',         name = 'Piebald',          price = 5000 },
            { model = 'a_c_horse_gypsycob_skewbald',        name = 'Skewbald',         price = 5000 },
            { model = 'a_c_horse_gypsycob_splashedbay',     name = 'Splashed Bay',     price = 5000 },
            { model = 'a_c_horse_gypsycob_splashedpiebald', name = 'Splashed Piebald', price = 5000 },
            { model = 'a_c_horse_gypsycob_whiteblagdon',    name = 'White Blagdon',    price = 5000 },
            { model = 'A_C_Horse_GypsyCob_PalominoBlagdon', name = 'Palomino Blagdon', price = 5000 },
        },
    },
}

-- the donkey has no mane/tail/mustache menu
Config.NoHairModels = { [('A_C_Donkey_01'):lower()] = true }

-------------------------------------------------------------------------------
-- Nothing to edit below: turns the list above into the lookups the stable uses.
-------------------------------------------------------------------------------
Config.BreedById = {}
Config.BreedByModel = {}   -- lower-case model -> breed id, coat index
do
    local D = Config.HorseDefaults
    for _, b in ipairs(Config.Breeds) do
        b.label = b.name
        b.bag = b.saddlebag or D.saddlebag
        if b.age == nil then b.age = D.age elseif b.age == false then b.age = nil end
        if b.neverDies == nil then b.neverDies = D.neverDies end
        local cheapest = nil
        for i, c in ipairs(b.coats) do
            local price = c.price or b.price
            if price == nil then
                error(('pup-stable config/horses.lua: %s / %s has no price'):format(b.name, tostring(c.name)))
            end
            if not cheapest or price < cheapest then cheapest = price end
            b.coats[i] = { model = c.model, label = c.name, price = price, bag = c.saddlebag, job = c.job, color = c.color, gold = c.gold }
            Config.BreedByModel[c.model:lower()] = { breed = b.id, coat = i }
        end
        b.price = cheapest   -- shown on the breed list as its starting price
        Config.BreedById[b.id] = b
    end
end
