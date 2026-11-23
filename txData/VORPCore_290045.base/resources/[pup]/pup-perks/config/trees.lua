-- pup-perks | config/trees.lua
-- The perk trees (the panel's left sidebar) and what the two sides are called.

-------------------------------------------------------------------------------
-- TREES
-------------------------------------------------------------------------------
-- Fields and rules are explained in README.md.
Config.Trees = {
    sideLabels = {
        civ   = 'Honest Work',
        crime = 'Outlaw',
    },

    list = {
        { key = 'hunting', label = 'Hunting', glyph = 'paw', side = 'civ',
          desc = 'The pelt is worth more than the shot. Skinners and trappers who bring back twice what anyone else does.' },
        { key = 'farming', label = 'Farming', glyph = 'leaf', side = 'civ',
          desc = 'Land worked properly pays forever. Bigger plots, faster hands and a harvest that keeps coming up heavy.' },
        { key = 'gathering', label = 'Gathering', glyph = 'pickaxe', side = 'civ',
          desc = 'Everything worth having is buried or hidden. Shovel work, panning and a homestead that never runs dry.' },
        { key = 'crafting', label = 'Crafting', glyph = 'anvil', side = 'civ',
          desc = 'Raw goods into finished ones, and nothing wasted along the way. The bench answers to you.' },
        { key = 'stamina', label = 'Stamina', glyph = 'lungs', side = 'civ',
          desc = 'Wind, legs and the will to keep going after everyone else has stopped.' },
        { key = 'combat', label = 'Combat', glyph = 'pistol', side = 'crime',
          desc = 'Doors, boxes and safes. When you take a place apart you leave nothing in the corners.' },
        { key = 'economy', label = 'Economy', glyph = 'coins', side = 'crime',
          desc = 'Contraband moves, money follows. You know what a thing is worth and never take the first offer.' },
        { key = 'utility', label = 'Utility', glyph = 'clock', side = 'crime',
          desc = 'Speed is the whole trade. Stills, carts and cellars worked faster than the law can arrive.' },
        { key = 'special', label = 'Special', glyph = 'spade', side = 'both',
          desc = 'Open to everyone regardless of what you specialised in.' },
    },
}
