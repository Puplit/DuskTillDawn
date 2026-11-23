-- pup-perks | config/perks.lua
-- The perk deck: every card, its ranks, costs and the effect other resources read.

-------------------------------------------------------------------------------
-- PERKS  (panel order = list order)
-------------------------------------------------------------------------------
-- Card fields, effect keys and an example are in README.md.
Config.Perks = {
    -- HUNTING ---------------------------------------------------------------
    {
        id = 'skinner', cat = 'hunting', glyph = 'paw', req = 1,
        name = 'Practiced Hand',
        desc = 'Years at the skinning table. Sometimes a carcass gives up twice what it should.',
        effect = { key = 'skin_double' },
        ranks = {
            { cost = 1, text = '5% chance of double items when skinning', chance = 5 },
            { cost = 2, req = 6, text = '10% chance of double items when skinning', chance = 10 },
            { cost = 3, req = 12, text = '15% chance of double items when skinning', chance = 15 },
        },
    },
    {
        id = 'legendaryhunter', cat = 'hunting', slot = 'special', glyph = 'eye', req = 6,
        name = 'Legendary Hunter',
        desc = 'You know the signs, the wind and the hour. What takes other hunters an afternoon takes you half of one.',
        effect = { key = 'legendary_call_speed' },
        ranks = {
            { cost = 2, text = 'Legendary animals answer the trap in 8 minutes instead of 10', mult = 0.80 },
            { cost = 3, req = 11, text = 'Legendary animals answer the trap in 6 minutes instead of 8', mult = 0.60 },
            { cost = 4, req = 17, text = 'Legendary animals answer the trap in 5 minutes instead of 6', mult = 0.50 },
        },
    },
    {
        id = 'falconer', cat = 'hunting', glyph = 'feather', req = 4,
        name = 'Falconer',
        desc = 'The bird works for you because it wants to. It learns in a week what takes other handlers a season.',
        effect = { key = 'bird_xp' },
        ranks = {
            { cost = 2, text = 'Your hunting birds gain 15% more experience', mult = 1.15 },
            { cost = 3, req = 10, text = 'Your hunting birds gain 30% more experience', mult = 1.30 },
            { cost = 4, req = 16, text = 'Your hunting birds gain double experience', mult = 2.00 },
        },
    },
    {
        id = 'trapper', cat = 'hunting', glyph = 'medal', req = 12,
        name = "Trapper's Eye",
        desc = 'You know where the good hide is on a legend, and how to take it clean.',
        effect = { key = 'skin_legendary_double' },
        ranks = {
            { cost = 2, text = '5% chance a legendary carcass gives two pelts', chance = 5 },
            { cost = 3, req = 16, text = '10% chance a legendary carcass gives two pelts', chance = 10 },
            { cost = 4, req = 20, text = '15% chance a legendary carcass gives two pelts', chance = 15 },
        },
    },

    -- FARMING ---------------------------------------------------------------
    {
        id = 'greenthumb', cat = 'farming', glyph = 'leaf', req = 2,
        name = 'Green Thumb',
        desc = 'You read the soil the way other people read a newspaper. Every crop comes up fuller.',
        effect = { key = 'farm_bonus' },
        ranks = {
            { cost = 1, text = '+1 of every crop you harvest', add = 1 },
            { cost = 2, req = 7, text = '+2 of every crop you harvest', add = 2 },
            { cost = 3, req = 13, text = '+3 of every crop you harvest', add = 3 },
        },
    },
    {
        id = 'fieldhand', cat = 'farming', glyph = 'hand', req = 2,
        name = 'Field Hand',
        desc = 'Rake, seed, water, clear. You have done it so often your hands do it without you.',
        effect = { key = 'farm_speed' },
        ranks = {
            { cost = 1, text = 'Planting, watering and clearing 20% faster', mult = 0.80 },
            { cost = 2, req = 6, text = 'Planting, watering and clearing 40% faster', mult = 0.60 },
            { cost = 3, req = 12, text = 'Planting, watering and clearing 60% faster', mult = 0.40 },
        },
    },
    {
        id = 'rainmaker', cat = 'farming', glyph = 'drop', req = 4,
        name = 'Rainmaker',
        desc = 'One pass with the can and the whole row drinks. You stopped counting trips years ago.',
        effect = { key = 'farm_water_radius' },
        ranks = {
            { cost = 1, text = 'Watering also waters plants within 2.5m, and a can lasts the whole pass', add = 2.5 },
            { cost = 2, req = 9, text = 'Watering also waters plants within 4m, and a can lasts the whole pass', add = 4.0 },
            { cost = 3, req = 15, text = 'Watering also waters plants within 6m, and a can lasts the whole pass', add = 6.0 },
        },
    },
    {
        id = 'smallholder', cat = 'farming', glyph = 'home', req = 5,
        name = 'Smallholder',
        desc = 'More ground than one person should be able to work, and you work it anyway.',
        effect = { key = 'farm_limit' },
        ranks = {
            { cost = 1, text = '+10 to your plant limit, and +5 of any one crop', add = 5 },
            { cost = 2, req = 10, text = '+20 to your plant limit, and +10 of any one crop', add = 10 },
            { cost = 3, req = 16, text = '+30 to your plant limit, and +15 of any one crop', add = 15 },
        },
    },

    -- GATHERING -------------------------------------------------------------
    {
        id = 'prospector', cat = 'gathering', glyph = 'pickaxe', req = 3,
        name = 'Prospector',
        desc = 'A practised back and a good shovel. Ground gives way faster.',
        effect = { key = 'dig_speed' },
        ranks = {
            { cost = 1, text = 'Digging and grave work 10% faster', mult = 0.90 },
            { cost = 2, req = 9, text = 'Digging and grave work 15% faster', mult = 0.85 },
            { cost = 3, req = 14, text = 'Digging and grave work 25% faster', mult = 0.75 },
        },
    },
    {
        id = 'panhandler', cat = 'gathering', glyph = 'drop', req = 2,
        name = 'Panhandler',
        desc = 'You read the creek bed before the pan ever touches the water. Fewer empty swirls, more colour.',
        effect = { key = 'pan_luck' },
        ranks = {
            { cost = 1, text = 'Better odds of finding gold when panning', add = 8 },
            { cost = 2, req = 8, text = 'Much better odds of finding gold when panning', add = 16 },
            { cost = 3, req = 14, text = 'The creek rarely gives you nothing', add = 25 },
        },
    },
    {
        id = 'richseam', cat = 'gathering', slot = 'special', glyph = 'pickaxe', req = 3,
        name = 'Rich Seam',
        desc = 'You swing where the rock is already breaking, and you fell a tree where it wants to fall.',
        effect = { key = 'gather_yield' },
        ranks = {
            { cost = 1, text = '+1 from every ore vein and tree', add = 1 },
            { cost = 2, req = 9, text = '+2 from every ore vein and tree', add = 2 },
            { cost = 3, req = 15, text = '+3 from every ore vein and tree', add = 3 },
        },
    },
    {
        id = 'homesteader', cat = 'gathering', glyph = 'box', req = 2,
        name = 'Homesteader',
        desc = 'The animals settle for you. Every run off the ranch comes back heavier.',
        effect = { key = 'ranch_bonus' },
        ranks = {
            { cost = 1, text = '+1 on every milking and egg run', add = 1 },
            { cost = 2, req = 8, text = '+2 on every milking and egg run', add = 2 },
            { cost = 3, req = 14, text = '+3 on every milking and egg run', add = 3 },
        },
    },

    -- CRAFTING --------------------------------------------------------------
    {
        id = 'craftsman', cat = 'crafting', glyph = 'anvil', req = 2,
        name = 'Craftsman',
        desc = 'Nothing wasted. Now and then the bench gives you a second one free.',
        effect = { key = 'craft_double' },
        ranks = {
            { cost = 1, text = '5% chance a craft yields double', chance = 5 },
            { cost = 2, req = 9, text = '10% chance a craft yields double', chance = 10 },
            { cost = 3, req = 15, text = '15% chance a craft yields double', chance = 15 },
        },
    },
    {
        id = 'bootlegger', cat = 'crafting', glyph = 'box', req = 5,
        name = 'Bootlegger',
        desc = 'You built the thing. You know exactly which pieces come off clean.',
        effect = { key = 'underground_bonus' },
        ranks = {
            { cost = 1, text = '+1 of every part when tearing down a still', add = 1 },
            { cost = 2, req = 11, text = '+2 of every part when tearing down a still', add = 2 },
        },
    },

    -- COMBAT ----------------------------------------------------------------
    {
        id = 'lockbreaker', cat = 'combat', glyph = 'key', req = 1,
        name = 'Lockbreaker',
        desc = 'You empty a box properly. Nothing gets left in the corners.',
        effect = { key = 'robbery_double' },
        ranks = {
            { cost = 1, text = '5% chance of double robbery loot', chance = 5 },
            { cost = 2, req = 10, text = '10% chance of double robbery loot', chance = 10 },
            { cost = 3, req = 17, text = '15% chance of double robbery loot', chance = 15 },
        },
    },
    {
        id = 'coolhead', cat = 'combat', glyph = 'clock', req = 3,
        name = 'Cool Head',
        desc = 'No shaking, no second-guessing. You are steady again before anyone else has stopped sweating.',
        effect = { key = 'robbery_cooldown' },
        ranks = {
            { cost = 1, text = 'Your own robbery cooldown is 10% shorter', mult = 0.90 },
            { cost = 2, req = 8, text = 'Your own robbery cooldown is 20% shorter', mult = 0.80 },
            { cost = 3, req = 14, text = 'Your own robbery cooldown is 30% shorter', mult = 0.70 },
        },
    },
    {
        id = 'lonerider', cat = 'combat', slot = 'special', glyph = 'skull', req = 15,
        name = 'Lone Rider',
        desc = 'You stopped needing a crew a long time ago. Doors, guards and the getaway - all of it alone, and nobody left behind to talk.',
        effect = { key = 'solo_robbery' },
        ranks = {
            { cost = 8, text = 'Rob anywhere without a posse. No crew, no minimum riders.' },
        },
    },

    -- UTILITY ---------------------------------------------------------------
    {
        id = 'distiller', cat = 'utility', slot = 'special', glyph = 'box', req = 3,
        name = 'Master Distiller',
        desc = 'Same mash, same still, more bottles. You worked out where the rest of it was going years ago.',
        effect = { key = 'still_yield' },
        ranks = {
            { cost = 1, text = '+1 bottle from every mash and still batch', add = 1 },
            { cost = 2, req = 8, text = '+2 bottles from every mash and still batch', add = 2 },
            { cost = 3, req = 14, text = '+4 bottles from every mash and still batch', add = 4 },
        },
    },
    {
        id = 'slowburn', cat = 'utility', glyph = 'fire', req = 6,
        name = 'Slow Burn',
        desc = 'You know the exact moment it is ready, so nothing sits on the heat longer than it has to.',
        effect = { key = 'cook_speed' },
        ranks = {
            { cost = 1, text = 'Mash and still batches finish 8% sooner', mult = 0.92 },
            { cost = 2, req = 11, text = 'Mash and still batches finish 15% sooner', mult = 0.85 },
            { cost = 3, req = 16, text = 'Mash and still batches finish 22% sooner', mult = 0.78 },
        },
    },
    {
        id = 'cellarrat', cat = 'utility', glyph = 'clock', req = 4,
        name = 'Cellar Rat',
        desc = 'You have done this in the dark a hundred times. Your hands are quicker than your nerve.',
        effect = { key = 'underground_speed' },
        ranks = {
            { cost = 1, text = 'Moonshine and cart work 8% faster', mult = 0.92 },
            { cost = 2, req = 8, text = 'Moonshine and cart work 15% faster', mult = 0.85 },
            { cost = 3, req = 13, text = 'Moonshine and cart work 20% faster', mult = 0.80 },
        },
    },

    -- ECONOMY ---------------------------------------------------------------
    {
        id = 'hardbargain', cat = 'economy', glyph = 'coins', req = 2,
        name = 'Hard Bargain',
        desc = 'You count it twice and you always find more. Every till, safe and lockbox gives up extra.',
        effect = { key = 'robbery_cash' },
        ranks = {
            { cost = 1, text = 'Robbery cash payouts are 5% larger', mult = 1.05 },
            { cost = 2, req = 7, text = 'Robbery cash payouts are 10% larger', mult = 1.10 },
            { cost = 3, req = 13, text = 'Robbery cash payouts are 20% larger', mult = 1.20 },
        },
    },
    {
        id = 'fencecut', cat = 'economy', glyph = 'coins', req = 5,
        name = 'Old Friends',
        desc = 'He still takes his cut. He just takes rather less of it from you than he does from everyone else.',
        effect = { key = 'fence_cut' },
        ranks = {
            { cost = 1, text = 'The fence pays 10% more for what you bring him', mult = 1.10 },
            { cost = 2, req = 10, text = 'The fence pays 20% more for what you bring him', mult = 1.20 },
            { cost = 3, req = 16, text = 'The fence pays 30% more for what you bring him', mult = 1.30 },
        },
    },
    {
        id = 'streetword', cat = 'economy', glyph = 'eye', req = 4,
        name = 'Word on the Street',
        desc = 'You buy a drink, you ask nothing, and somehow you always leave knowing where the man with the money is standing.',
        effect = { key = 'fence_word' },
        ranks = {
            { cost = 1, text = 'Contraband sales turn up word on the fence more often', add = 15 },
            { cost = 2, req = 9, text = 'Word on the fence reaches you far more often', add = 30 },
            { cost = 3, req = 15, text = 'The word names the exact place he is working, not just the region', add = 30 },
        },
    },
    {
        id = 'looselips', cat = 'economy', glyph = 'feather', req = 6,
        name = 'Loose Lips',
        desc = 'He talks more than he should once the goods are counted. Not to everyone. To you.',
        effect = { key = 'fence_next' },
        ranks = {
            { cost = 1, text = 'The fence sometimes mentions where he is headed next', chance = 20 },
            { cost = 2, req = 11, text = 'The fence often mentions where he is headed next', chance = 35 },
            { cost = 3, req = 17, text = 'The fence usually mentions where he is headed next', chance = 50 },
        },
    },
    {
        id = 'quiettrade', cat = 'economy', glyph = 'lock', req = 4,
        name = 'Quiet Trade',
        desc = 'Nothing changes hands in daylight and nobody remembers your face. Word travels slower when it is about you.',
        effect = { key = 'sale_quiet' },
        ranks = {
            { cost = 1, text = 'Contraband sales are noticed a little less often', add = 5 },
            { cost = 2, req = 9, text = 'Contraband sales are noticed less often', add = 10 },
            { cost = 3, req = 15, text = 'Contraband sales are noticed much less often', add = 15 },
        },
    },
    {
        id = 'smuggler', cat = 'economy', slot = 'special', glyph = 'money', req = 6,
        name = 'Smuggler',
        desc = 'You know what it is worth, and you never take the first offer.',
        effect = { key = 'drug_payout' },
        ranks = {
            { cost = 1, text = 'Locals never lowball you as hard', mult = 1.05 },
            { cost = 2, text = 'Locals open a little closer to what it is worth', mult = 1.10 },
            { cost = 3, req = 14, text = 'Locals rarely open at the bottom', mult = 1.15 },
        },
    },
    {
        id = 'hustler', cat = 'economy', glyph = 'spade', req = 3,
        name = 'Hustler',
        desc = 'You know which doors to knock on. Fewer locals turn your goods away.',
        effect = { key = 'sale_scam' },
        ranks = {
            { cost = 1, text = 'Locals haggle a little more willingly', add = 1 },
            { cost = 2, req = 8, text = 'Locals take a high price more often', add = 2 },
            { cost = 3, req = 13, text = 'Locals rarely walk away from a steep price', add = 4 },
        },
    },

    -- SPECIAL ---------------------------------------------------------------
    {
        id = 'hardworker', cat = 'special', side = 'civ', glyph = 'chart', req = 7,
        name = 'Hard Worker',
        desc = 'Honest labour teaches faster than anything else can.',
        effect = { key = 'civ_xp' },
        ranks = {
            { cost = 2, text = '+15% experience from honest work', mult = 1.15 },
            { cost = 3, req = 13, text = '+25% experience from honest work', mult = 1.25 },
        },
    },
    {
        id = 'nightowl', cat = 'special', side = 'crime', glyph = 'fire', req = 7,
        name = 'Night Owl',
        desc = 'The lessons that stick are the ones you could hang for.',
        effect = { key = 'crime_xp' },
        ranks = {
            { cost = 2, text = '+15% experience from outlaw work', mult = 1.15 },
            { cost = 3, req = 13, text = '+25% experience from outlaw work', mult = 1.25 },
        },
    },
    {
        id = 'wagonboss', cat = 'special', side = 'civ', glyph = 'box', req = 5,
        name = 'Wagon Boss',
        desc = 'You pack a wagon the way other men pack a suitcase. Supply runs come back heavier.',
        effect = { key = 'clan_supply_bonus' },
        ranks = {
            { cost = 1, text = 'Camp supply wagons deliver 10% more supplies', mult = 1.10 },
            { cost = 2, req = 9, text = 'Camp supply wagons deliver 20% more supplies', mult = 1.20 },
            { cost = 3, req = 14, text = 'Camp supply wagons deliver 30% more supplies', mult = 1.30 },
        },
    },
    {
        id = 'campfence', cat = 'special', side = 'crime', glyph = 'coins', req = 5,
        name = 'Camp Fence',
        desc = 'Buyers pay what you tell them the stock is worth.',
        effect = { key = 'clan_sale_bonus' },
        ranks = {
            { cost = 1, text = 'Selling camp stock pays 10% more', mult = 1.10 },
            { cost = 2, req = 9, text = 'Selling camp stock pays 20% more', mult = 1.20 },
            { cost = 3, req = 14, text = 'Selling camp stock pays 30% more', mult = 1.30 },
        },
    },
}
