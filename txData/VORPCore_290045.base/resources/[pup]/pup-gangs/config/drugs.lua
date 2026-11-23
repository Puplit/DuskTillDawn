-- pup-gangs | the gang drug

-------------------------------------------------------------------------------
-- GANG DRUG
-------------------------------------------------------------------------------
Config.GangDrug = {
    enabled    = true,
    perk       = 'drug_production', -- perk flag; must be in Config.Perks.labels and a level's unlocks
    managePerm = 'bank',            -- rank permission to create, rename, re-skin and spend points (leader always passes)
    buyPerm    = 'bank',            -- rank permission to order seed from the ledger (nil = any member)
    seedItem   = 'gang_seed',       -- shared seed item (sql/install.sql)
    drugItem   = 'gang_drug',       -- shared product item (sql/install.sql)
    nameMin    = 3,                 -- product name length, characters
    nameMax    = 24,
    renameCost = 25,                -- blood money out of the gang ledger per rename (0 = free)

    -- icons a gang may pick from. image = PNG basename under vorp_inventory/html/img/items/
    -- (it must exist there or the slot renders blank). entry: key, label, image
    icons = {
        { key = 'moonshine', label = 'Moonshine Bottle', image = 'moonshine' },
        { key = 'cigar',     label = 'Cigar',            image = 'cigar' },
        { key = 'syringe',   label = 'Syringe',          image = 'syringe' },
        { key = 'powder',    label = 'Powder Bag',       image = 'coca_powder' },
        { key = 'pills',     label = 'Pills',            image = 'morphine' },
        { key = 'herbs',     label = 'Herbs',            image = 'oleander_sage' },
        { key = 'bottle',    label = 'Bottle',           image = 'alcoholbottle' },
        { key = 'opium',     label = 'Opium Pipe',       image = 'pup_opium_pipe' },
        { key = 'tar',       label = 'Black Tar',        image = 'heroin' },
    },

    -- seed: ordered (and paid) at the gang table, collected in person from the pup_robbery fence
    seed = {
        price          = 25,    -- blood money per batch, out of the gang ledger
        perBuy         = 5,     -- seeds per batch
        maxHeld        = 50,    -- refuse a collection that would take a member over this
        collectAtFence = true,  -- false = straight to the satchel when ordered
        fenceDistance  = 4.0,   -- metres from the fence to collect
        maxPending     = 100,   -- an order this big cannot be added to
    },

    -- selling through pup_hideouts' NPC prompt
    sale = {
        price            = 55,     -- base price per unit, before haggling
        foreignOnly      = false,  -- true = the locals refuse it outside rival ground
        ownTurfSells     = true,   -- sells on your own ground, but earns no points
        neutralSells     = true,   -- same for unclaimed ground
        bonusMult        = 1.25,   -- money multiplier on a qualifying sale
        pointsPerUnit    = 10,     -- drug progression per unit sold on rival ground
        pointsPerSaleCap = 40,     -- hard ceiling on one sale, whatever the stack
    },

    -- consumption: the base effect before any tree node, applied through fred_metabolism
    effect = {
        health      = 5,       -- inner health core points (0-100)
        stamina     = 10,      -- inner stamina core points
        deadeye     = 0,       -- inner dead eye core points
        healthGold  = 0.0,     -- fortified health, 0.0-1.0
        staminaGold = 0.0,
        deadeyeGold = 0.0,
        durationMs  = 30000,   -- how long the fortified cores are held
        hunger      = 0,
        thirst      = 0,
        metabolism  = 0,
        animation   = 'drink', -- an animations key ('' = none)
        prop        = '',
        screen      = '',      -- screen effect name ('' = none)
    },

    -- the tree (entry fields and effect keys are listed in README.md)
    tree = {
        {
            id = 'mastery', name = 'Drug Mastery', tier = 1,
            description = 'The crew learns the trade. Every batch comes out cleaner.',
            icon = 'skull', requiredPoints = 60, prerequisites = {},
            effect = 'yield', effectValue = 1,
        },
        {
            id = 'health1', name = 'Health I', tier = 2,
            description = 'A steadier hand. The product mends as much as it burns.',
            icon = 'heart', requiredPoints = 80, prerequisites = { 'mastery' },
            effect = 'health', effectValue = 8,
        },
        {
            id = 'health2', name = 'Health II', tier = 3,
            description = 'Whatever they are cutting it with, it works.',
            icon = 'heart', requiredPoints = 160, prerequisites = { 'health1' },
            effect = 'health', effectValue = 12,
        },
        {
            id = 'stamina1', name = 'Stamina I', tier = 2,
            description = 'Keeps a rider upright long past where he should have dropped.',
            icon = 'bolt', requiredPoints = 80, prerequisites = { 'mastery' },
            effect = 'stamina', effectValue = 15,
        },
        {
            id = 'stamina2', name = 'Stamina II', tier = 3,
            description = 'A full day of work out of a half day of sleep.',
            icon = 'bolt', requiredPoints = 160, prerequisites = { 'stamina1' },
            effect = 'stamina', effectValue = 25,
        },
        {
            id = 'duration1', name = 'Slow Burn', tier = 2,
            description = 'The effect holds for twice as long.',
            icon = 'clock', requiredPoints = 100, prerequisites = { 'mastery' },
            effect = 'duration', effectValue = 30000,
        },
        {
            id = 'yield1', name = 'Heavy Harvest', tier = 2,
            description = 'One more unit off every plant the crew pulls.',
            icon = 'leaf', requiredPoints = 120, prerequisites = { 'mastery' },
            effect = 'yield', effectValue = 1,
        },
        {
            id = 'trade1', name = 'Street Value', tier = 2,
            description = 'The name carries. Locals pay more for it than for anything else.',
            icon = 'coin', requiredPoints = 120, prerequisites = { 'mastery' },
            effect = 'saleValue', effectValue = 0.15,
        },
        {
            id = 'street1', name = 'Word Travels', tier = 2,
            description = 'Every run onto rival ground buys the crew more than money.',
            icon = 'feather', requiredPoints = 140, prerequisites = { 'mastery' },
            effect = 'progression', effectValue = 0.25,
        },
        {
            id = 'mastery2', name = 'Mastery', tier = 4,
            description = 'Both halves of the recipe perfected at once.',
            icon = 'skull', requiredPoints = 300,
            prerequisites = { 'health2', 'stamina2' },
            effect = 'duration', effectValue = 30000,
        },
        {
            id = 'advanced', name = 'Advanced Effects', tier = 5,
            description = 'It fortifies now. A man on this does not go down easy.',
            icon = 'star', requiredPoints = 500, prerequisites = { 'mastery2' },
            effect = 'healthGold', effectValue = 1.0,
        },
        {
            id = 'advanced2', name = 'Deadened Nerves', tier = 5,
            description = 'Fortified stamina and a sharper eye with it.',
            icon = 'star', requiredPoints = 500, prerequisites = { 'mastery2' },
            effect = 'staminaGold', effectValue = 1.0,
        },
    },

    -- drug level, read off lifetime points earned (never the spendable balance). entry: level, points, label
    levels = {
        { level = 1, points = 0,    label = 'Backroom Batch' },
        { level = 2, points = 250,  label = 'Local Trade' },
        { level = 3, points = 750,  label = 'Known Product' },
        { level = 4, points = 2000, label = 'Frontier Supply' },
        { level = 5, points = 5000, label = 'The Only Name' },
    },
}
