-- Crafting categories, in tab order.
-- icon:    a pup-ui icon name (key, cross, fire, box, shield, money, heart, home, star, anvil, leaf, goblet ...)
-- picture: kept for reference only, nothing displays it
-- jobs:    nil for no lock, or a list of job names allowed to see this category
Config.Categories = {
    { key = 'custom',     label = 'Custom',     desc = 'Craft Custom Item',      icon = 'key',    picture = 'rpblacksoulgem' },
    { key = 'medical',    label = 'Medical',    desc = 'Craft Medical Supplies', icon = 'cross',  picture = 'medical' },
    { key = 'blacksmith', label = 'Blacksmith', desc = 'Craft Blacksmith items', icon = 'fire',   picture = 'weapon_melee_hammer' },
    { key = 'basic',      label = 'Basic',      desc = 'Craft Basic Supplies',   icon = 'box',    picture = 'basic' },
    { key = 'survival',   label = 'Survival',   desc = 'Craft Survival Supplies', icon = 'shield', picture = 'survival' },
    { key = 'brewing',    label = 'Brewing',    desc = 'Brew Beavarage',         icon = 'money',  picture = 'brewing' },
    { key = 'food',       label = 'Food',       desc = 'Cook Food',              icon = 'heart',  picture = 'food' },
    { key = 'furni',      label = 'Furniture',  desc = 'Build Furniture',        icon = 'home',   picture = 'wood_chair' },
}

Config.DefaultCategoryIcon = 'box'
