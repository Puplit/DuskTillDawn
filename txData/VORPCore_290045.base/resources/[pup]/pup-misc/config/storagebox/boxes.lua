-- storagebox | the box and pack item types (see README)
local C = StorageBoxConfig

C.Boxes = {
    -- rows reference this name: never rename it
    storage_box_1000 = {
        label = 'Storage Box',
        desc = 'A portable storage box. Holds up to 1000 item slots.',
        capacity = 1000,
        moveRate = 0.7,
        model = nil,
    },
}

local farmerSeeds = {
    'Alaskan_Ginseng_Seed', 'American_Ginseng_Seed', 'Apple_Seed', 'Black_Berry_Seed', 'Black_Currant_Seed',
    'Blood_Flower_Seed', 'Choc_Daisy_Seed', 'coca_seeds', 'cocoaseeds', 'coffeeseeds', 'cornseed',
    'Creeking_Thyme_Seed', 'Creekplum_Seed', 'Crows_Garlic_Seed', 'English_Mace_Seed', 'hemp_seed', 'hop_seed',
    'Indian_Tobbaco_Seed', 'Milk_Weed_Seed', 'Oleander_Sage_Seed', 'Oregano_Seed', 'Parasol_Mushroom_Seed',
    'peachseeds', 'potatoseed', 'Prairie_Poppy_Seed', 'pumpkinseeds', 'Red_Raspberry_Seed', 'Red_Sage_Seed',
    'sugarcaneseed', 'teaseeds', 'Wild_Carrot_Seed', 'Wild_Mint_Seed', 'Wintergreen_Berry_Seed', 'Yarrow_Seed',
}
local farmerCrops = {
    'Alaskan_Ginseng', 'American_Ginseng', 'apple', 'Black_Berry', 'Black_Currant', 'Blood_Flower', 'Choc_Daisy',
    'cocoa', 'coffeebeans', 'consumable_peach', 'corn', 'Creeking_Thyme', 'Creekplum', 'Crows_Garlic',
    'English_Mace', 'hemp', 'hop', 'Indian_Tobbaco', 'Milk_Weed', 'Oleander_Sage', 'Oregano', 'Parasol_Mushroom',
    'potato', 'Prairie_Poppy', 'pumpkin', 'Red_Raspberry', 'Red_Sage', 'sugar', 'tealeaf', 'wet_coca_leaf',
    'Wild_Carrot', 'Wild_Mint', 'Wintergreen_Berry', 'Yarrow',
}
local farmerFruit = { 'banana', 'blueberry', 'lemon', 'mango', 'orange', 'pear', 'strawberry', 'tomato1' }

local function join(...)
    local out = {}
    for _, list in ipairs({ ... }) do
        for _, v in ipairs(list) do out[#out + 1] = v end
    end
    return out
end

C.Packs = {
    miner_pack = {
        label = "Miner's Pack",
        desc = 'A heavy canvas pack for ore. Holds 400 units of mining materials.',
        gather = 'mining',
        capacity = 400, limit = 1, rarity = 4, jobs = {},
        materials = { 'clay', 'coal', 'copper', 'iron', 'nitrite', 'rock', 'salt', 'goldnugget' },
    },
    lumber_pack = {
        label = 'Lumber Pack',
        desc = 'A strapped timber pack. Holds 400 units of lumber materials.',
        gather = 'lumber',
        capacity = 400, limit = 1, rarity = 4, jobs = {},
        materials = { 'sap', 'honey', 'wood', 'hwood', 'rubber', 'fibers', 'pulp' },
    },
    farmer_pack = {
        label = "Farmer's Pack",
        desc = 'A canvas produce pack. Holds 400 units of seeds and crops.',
        gather = 'farming',
        capacity = 400, limit = 1, rarity = 4, jobs = {},
        materials = join(farmerSeeds, farmerCrops, farmerFruit),
    },
}
