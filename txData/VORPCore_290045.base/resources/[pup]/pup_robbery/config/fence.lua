-- pup_robbery | the fence: a travelling buyer who hands out bank jobs and runs a small tool stall

local function v(x, y, z) return vector3(x, y, z) end

Config.Fence = {
    npc = {
        enabled = true,
        model = 'u_m_m_nbxshadydealer_01',
        fallbackModel = 's_m_m_unibutchers_01',
        promptGroup = 'Fence',
        promptText = 'Talk to the fence',
        promptRange = 2.0,
        pressThrottleMs = 1500,
        sinkMetres = 1.0, -- he is placed this far under the stop's height so his feet meet the ground
    },
    stayMinutes = 75,
    reach = 20.0,           -- server: metres from the fence (or his prompt point) for every fence action
    askThrottleMs = 2000,
    whereRetries = 20,
    whereRetryMs = 1500,

    stops = {
        { label = 'Saint Denis', region = 'Lemoyne', pos = v(2859.4268, -1202.3197, 49.3409), heading = 10.6248, prompt = v(2859.3704, -1200.6846, 49.3402) },
        { label = 'the oil field', region = 'the Heartlands', pos = v(595.447, 647.658, 115.061), heading = 305.34 },
        { label = 'Mount Hagen', region = 'the Grizzlies', pos = v(-1499.548, 1253.252, 313.564), heading = 214.87 },
        { label = 'Benedict Point', region = 'Rio Bravo', pos = v(-5201.643, -3490.691, -22.153), heading = 287.24 },
        { label = 'Twin Rocks', region = 'Gaptooth Ridge', pos = v(-3963.318, -2117.738, -5.117), heading = 55.29 },
        { label = "Monto's Rest", region = 'Big Valley', pos = v(-1407.651, -253.369, 99.325), heading = 64.97 },
    },

    -- pay rate: a fraction rolled per stop between min and max, or a fixed number
    payRate = { min = 0.55, max = 0.85 },

    jobs = {
        categories = { bank = true }, -- place categories the fence hands out
        posseRequired = true,
        needsPerk = false,           -- the introduction gate (perk Config.Perks.access); off
        letterSubject = 'Work',
        blipMinutes = 15,
    },

    buyer = {
        enabled = true,
        payoutMinutes = 25,
        crateSlots = 30,
        crateName = 'The Fence',
        cratePrefix = 'fence_sell_', -- keep: existing crates are stored under this id
        sweepSeconds = 30,
        tipDelayMs = 6500,
        prices = {
            goldbar = 80, moneybag_large = 1500, moneybag_medium = 750, moneybag_small = 350,
            diamond = 100, ruby = 90, emerald = 80, sapphire = 70,
            coin_gold_eagle = 85, coin_half_eagle = 70, coin_five_dollar = 65, coin_gold_quarter = 65,
            coin_gold_dollar = 50, coin_new_yorke = 40, coin_quarter_1792_2 = 30, coin_quarter_1792 = 26,
            coin_half_dime = 20, coin_nickel_1792 = 16, coin_penny_1789 = 12, coin_penny_1787 = 10,
            coin_half_penny = 8, robbery_ledger = 95, art_golden_chalice = 85, antique_jewelry_box = 75,
            necklace_amethyst_richelieu = 70, necklace_amethyst_braxton = 58, necklace_ancient = 55,
            necklace_mini_blakely = 55, platinum_ring = 48, necklace_gold_cross = 45, necklace_gold_ring = 38,
            necklace_pearl_rou = 35, necklace_pearl_pelle = 35, pocket_watch = 30, wedding_ring = 28,
            tooth_gold = 22, silver_ring = 18, cigar = 5,
        },
    },

    stall = {
        enabled = true,
        storeName = 'The Fence',
        pushDelayMs = 2000,
        stock = {
            { name = 'lockpick', label = 'Lockpick', price = '100', type = 'item_standard' },
            { name = 'crowbar', label = 'Crowbar', price = '75', type = 'item_standard' },
            { name = 'banktools', label = 'Safe Tools', price = '150', type = 'item_standard' },
            { name = 'dynamite', label = 'Pipe Charge Dynamite', price = '75', type = 'item_standard' },
            { name = 'hideout_plans', label = 'Hideout Plans', price = '10000', type = 'item_standard' },
        },
    },

    rumours = {
        enabled = true,
        chance = 65,
        cooldownMinutes = 10,
        landmarkRank = 3,
        showMs = 9000,
        moveNotice = true,
        moveMail = true,
        mailFrom = 'A Friend',
        mailSubject = 'He has moved on',
        regionLines = {
            'Fella came through asking about valuables. Said he was moving on to {region} next.',
            'Word is that buyer is done here soon. {region} is where he goes after.',
            'The man who pays cash for stolen goods is shifting camp. {region}, so they say.',
            'Heard the fence is pulling out. Try {region} once he settles.',
            'If you have goods to move, be in {region} when he gets there.',
        },
        landmarkLines = {
            'That buyer? He is setting up at {label} next. Do not say I told you.',
            'The fence moves on to {label}. Be there before the rush.',
        },
        saleRegion = '"I am pulling out soon. Headed for {where} after this."',
        saleLandmark = '"I am pulling out soon. Look for me at {where}. Do not say I told you."',
        saleChase = 'Your money is %d minutes out. You will be collecting it from him there.',
        letterRegion = 'The man you did business with has packed up and gone.\n\nWord is he is working out of {region} now. Ask around when you get there.\n\nBurn this.',
        letterLandmark = 'The man you did business with has packed up and gone.\n\nLook for him at {label}, out in {region}. Do not say where you heard it.\n\nBurn this.',
        screenRegion = 'Word reaches you: the fence is working out of {region} now.',
        screenLandmark = 'Word reaches you: the fence has set up at {label}, in {region}.',
        fallbackRegion = 'the county',
        fallbackLandmark = 'somewhere quiet',
        fallbackWhere = 'elsewhere',
    },

    sins = {
        enabled = true,
        lines = {
            { sin = 'Pride', text = 'Pride. Every man who walks in here reckons he is the one who does not get caught.' },
            { sin = 'Greed', text = 'Greed. You will notice nobody ever brings me the last thing they steal.' },
            { sin = 'Envy', text = 'Envy. Half of what crosses this table was taken because somebody else had it first.' },
            { sin = 'Wrath', text = 'Wrath. Cheapest of the seven. Costs a man everything and buys him nothing.' },
            { sin = 'Sloth', text = 'Sloth. Plenty of honest work out there. Here you are.' },
            { sin = 'Gluttony', text = 'Gluttony. A man with enough has never once known it.' },
            { sin = 'Lust', text = 'Lust. More of my trade starts in a bedroom than a bank, and that is the truth.' },
            { sin = 'Pride', text = 'Pride again. You did not haggle. You should have haggled.' },
            { sin = 'Greed', text = 'Greed. I take my cut and you call me a thief. Look at what you carried in.' },
            { sin = 'Wrath', text = 'Wrath. Blood on the goods costs you. I have to scrub it off before I sell them.' },
            { sin = 'Envy', text = 'Envy. Whoever you are trying to outdo is not thinking about you at all.' },
            { sin = 'Sloth', text = 'Sloth. You could have stolen twice this by now.' },
            { sin = 'Gluttony', text = 'Gluttony. You will be back tomorrow. They always are.' },
            { sin = 'Lust', text = 'Lust. Whatever she asked you for, it was not worth the rope.' },
        },
    },

    brushOffs = {
        "Never seen you before. Buy something or move along.",
        "I sell tinned peaches, friend. That's the whole business.",
        "You've got an honest face. I don't much care for it.",
        "Whatever you heard about me, you heard wrong. Loudly, I'd wager.",
        "Come back when somebody I trust knows your name.",
    },
    brushOffFallback = 'He looks straight through you.',

    reputation = {
        enabled = true,
        perDollar = 0.01,
        minPerSale = 1,
        levels = {
            { from = 0, name = 'Stranger', keeps = 1.00 },
            { from = 250, name = 'Known Face', keeps = 0.85 },
            { from = 750, name = 'Regular', keeps = 0.70 },
            { from = 1750, name = 'Trusted', keeps = 0.50 },
            { from = 3500, name = 'Partner', keeps = 0.25 },
            { from = 6000, name = 'Family', keeps = 0.00 },
        },
    },

    letters = {
        from = 'A Friend',
        payoutSubject = 'Your money',
    },
}
