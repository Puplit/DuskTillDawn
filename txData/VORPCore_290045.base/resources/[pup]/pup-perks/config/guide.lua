-- pup-perks | config/guide.lua
-- The Guide panel players read inside the perks menu. Placeholders and section types are in README.md.

Config.Guide = {
    title = 'Guide',
    sections = {
        {
            title = 'Getting Started',
            glyph = 'home',
            steps = {
                'Pick a side with the tabs at the top.',
                'Open a specialisation, read its perks, then commit to it.',
                'Do the work to earn experience and level up.',
                'Spend your points on perks. They work as soon as you buy them.',
            },
        },
        {
            title = 'The Two Sides',
            glyph = 'users',
            text = {
                'Honest Work and Outlaw never mix. Each side has its own level, its own points and its own specialisation.',
                'A dot lights up on a tab when that side has points to spend.',
            },
        },
        {
            title = 'Earning Experience',
            glyph = 'chart',
            text = {
                'Experience only counts once you have chosen a specialisation on that side. Work done before that will not level you.',
                'After that, all work on that side counts toward your specialisation, whatever the job.',
            },
            list = {
                { label = 'Honest Work', text = 'Skinning, taming horses, crafting, gunsmithing, ranching, farming, digging, mining, panning, lumber and fishing.' },
                { label = 'Outlaw', text = 'Robberies, moonshine stills, drug sales, fencing stolen goods, grave robbing and wagon robberies.' },
                { label = 'Split', text = 'Undertaker work, bounties and camp wagon runs pay half to each side.' },
            },
        },
        {
            title = 'Levels and Points',
            glyph = 'medal',
            text = {
                'Each level gives {pointsPerLevel} point on that side, with extra points at levels {bonusLevels}. The highest level is {maxLevel}.',
                'Points can only be spent on the side that earned them.',
            },
        },
        {
            title = 'Perks',
            glyph = 'spade',
            text = {
                'A perk has up to {maxRank} ranks. Each rank costs points and needs a certain level, and the perk shows you both.',
                'Some perks need another perk first. There is nothing to equip: a perk you own is always working.',
                'Special perks are open to everyone, whatever you specialised in. Each one is paid for by one side, and the perk says which.',
            },
        },
        {
            title = 'Changing Your Mind',
            glyph = 'clock',
            resets = {
                free = {
                    name = 'Free Reset',
                    cost = 'Free, every {resetDays} days',
                    does = 'Gives back every point you spent on both sides, so you can spend them again.',
                    keeps = 'You keep both specialisations, your levels and your experience.',
                },
                switch = {
                    name = 'Switch Specialisation',
                    cost = 'Free. With points spent on that side it uses your free reset',
                    does = "Moves one side to a different specialisation and clears that side's perks. Your level and points then follow the experience the new specialisation has.",
                    keeps = 'Your other side is not touched.',
                    how = 'Find it under Switch Specialisation in the left-hand list. You can read the whole specialisation before you confirm.',
                },
                full = {
                    name = 'Full Reset',
                    cost = '${resetPrice} cash',
                    does = 'Clears every perk and both specialisations, so you can choose again.',
                    keeps = 'Experience stays with each specialisation, so going back to one picks up where it left off.',
                },
            },
        },
    },
}
