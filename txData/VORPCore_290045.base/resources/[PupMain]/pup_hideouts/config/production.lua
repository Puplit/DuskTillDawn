-- pup_hideouts | stills, recipes, storage tiers, themes and decorations

Config = Config or {}

Config.DistilleryJobs = { sdsmallsaloon = true, vtsmallsaloon = true, abdistillery = true, amdistillery = true }
Config.DoubleYieldItem = 'alcohol' -- only this mash doubles for distillery jobs

-- parts are taken from the hideout stash
Config.Stills = {
    [1] = { model = 'mp006_mshine_Still_01', parts = {
        { name = 'condenser', label = 'Condenser', amount = 3 },
        { name = 'pipecopper', label = 'Copper Pipe', amount = 5 },
    } },
    [2] = { model = 'mp006_mshine_Still_02', parts = {
        { name = 'condenser', label = 'Condenser', amount = 3 },
        { name = 'pot', label = 'Distillery Pot', amount = 5 },
        { name = 'rubbertube', label = 'Rubber Tube', amount = 10 },
    } },
    [3] = { model = 'mp006_mshine_Still_03', parts = {
        { name = 'stillkit', label = 'Still Kit', amount = 5 },
        { name = 'barrel', label = 'Barrel', amount = 10 },
        { name = 'condenser', label = 'Condenser', amount = 3 },
        { name = 'pipecopper', label = 'Copper Pipe', amount = 5 },
        { name = 'pot', label = 'Distillery Pot', amount = 5 },
        { name = 'rubbertube', label = 'Rubber Tube', amount = 5 },
    } },
}

Config.Mash = {
    { label = 'Alcohol', resultitem = 'alcohol', limit = 50, qt = 25, minutes = 15, stilllevel = 1, items = {
        { name = 'water',         label = 'Water',         amount = 1 },
        { name = 'hop',           label = 'Hop',           amount = 4 },
        { name = 'glassbottle',   label = 'Glass Bottle',  amount = 1 },
    } },
    { label = 'Raspberry Mash', resultitem = 'mashraspberry', limit = 20, qt = 5, minutes = 15, stilllevel = 1, items = {
        { name = 'water',         label = 'Water',         amount = 1 },
        { name = 'alcohol',       label = 'Alcohol',       amount = 1 },
        { name = 'Red_Raspberry', label = 'Red Raspberry', amount = 2 },
        { name = 'glassbottle',   label = 'Glass Bottle',  amount = 5 },
    } },
    { label = 'Apple Mash', resultitem = 'mashapple', limit = 20, qt = 5, minutes = 15, stilllevel = 2, items = {
        { name = 'water',         label = 'Water',         amount = 1 },
        { name = 'alcohol',       label = 'Alcohol',       amount = 2 },
        { name = 'apple',         label = 'Apple',         amount = 2 },
        { name = 'glassbottle',   label = 'Glass Bottle',  amount = 5 },
    } },
    { label = 'Strong Mash Batch', resultitem = 'mashstrong', limit = 20, qt = 5, minutes = 20, stilllevel = 3, items = {
        { name = 'water',         label = 'Water',         amount = 1 },
        { name = 'alcohol',       label = 'Alcohol',       amount = 5 },
        { name = 'hop',           label = 'Hop',           amount = 1 },
        { name = 'glassbottle',   label = 'Glass Bottle',  amount = 5 },
    } },
}

-- entries without distill = true are not brewed, only bought by locals (in this order)
Config.Distill = {
    { label = 'Raspberry Moonshine', resultitem = 'moonshineraspberry', limit = 15, qt = 30, minutes = 20, stilllevel = 1, distill = true, items = {
        { name = 'water',         label = 'Water',             amount = 1 },
        { name = 'mashraspberry', label = 'Raspberry Mash',    amount = 1 },
        { name = 'glassbottle',   label = 'Glass Bottle',      amount = 15 },
        { name = 'sugar',         label = 'Sugar',             amount = 1 },
    } },
    { label = 'Apple Moonshine', resultitem = 'moonshineapple', limit = 15, qt = 30, minutes = 20, stilllevel = 2, distill = true, items = {
        { name = 'water',         label = 'Water',             amount = 1 },
        { name = 'mashapple',     label = 'Apple Mash',        amount = 1 },
        { name = 'glassbottle',   label = 'Glass Bottle',      amount = 15 },
        { name = 'sugar',         label = 'Sugar',             amount = 1 },
    } },
    { label = 'Moonshine', resultitem = 'moonshine', limit = 15, qt = 15, minutes = 20, stilllevel = 3, distill = true, sellprice = 80, items = {
        { name = 'water',         label = 'Water',             amount = 1 },
        { name = 'mashstrong',    label = 'Strong Mash Batch', amount = 2 },
        { name = 'glassbottle',   label = 'Glass Bottle',      amount = 10 },
        { name = 'sugar',         label = 'Sugar',             amount = 1 },
    } },
    { label = 'Heroin',   resultitem = 'heroin' },
    { label = 'Pure',     resultitem = 'pure' },
    { label = 'Morphine', resultitem = 'morphine' },
    { label = 'Hemp',     resultitem = 'hemp' },
}

----------------------------------------------------------------------------------------------------
-- Storage tiers (level = the storage level required; buying sets it to level + 1)
----------------------------------------------------------------------------------------------------
Config.StorageTiers = {
    { name = 'upgrade', level = 0, slots = 500, price = 100, items = {
        { name = 'hwood',         label = 'Hard Wood',       amount = 5 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
    } },
    { name = 'upgrade +1', level = 1, slots = 100, price = 100, items = {
        { name = 'hwood',         label = 'Hard Wood',       amount = 5 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
        { name = 'clay',          label = 'Clay',            amount = 5 },
    } },
    { name = 'upgrade +2', level = 2, slots = 150, price = 150, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 1 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 1 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
        { name = 'barrel',        label = 'Barrel',          amount = 1 },
    } },
    { name = 'upgrade +3', level = 3, slots = 250, price = 250, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 5 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 5 },
        { name = 'nails',         label = 'Nails',           amount = 15 },
        { name = 'barrel',        label = 'Barrel',          amount = 2 },
        { name = 'ironbar',       label = 'Iron Bar',        amount = 5 },
    } },
    { name = 'upgrade +4', level = 4, slots = 350, price = 350, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 8 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 8 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
        { name = 'ironbar',       label = 'Iron Bar',        amount = 10 },
        { name = 'handsaw',       label = 'Handsaw',         amount = 1 },
    } },
    { name = 'upgrade +5', level = 5, slots = 500, price = 500, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 10 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 10 },
        { name = 'ironbar',       label = 'Iron Bar',        amount = 15 },
        { name = 'handsaw',       label = 'Handsaw',         amount = 1 },
        { name = 'ironhammer',    label = 'Iron Hammer',     amount = 1 },
    } },
    { name = 'upgrade +6', level = 6, slots = 1000, price = 1000, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 10 },
        { name = 'nails',         label = 'Nails',           amount = 10 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 10 },
        { name = 'ironbar',       label = 'Iron Bar',        amount = 20 },
        { name = 'sap',           label = 'Sap',             amount = 5 },
        { name = 'ironhammer',    label = 'Iron Hammer',     amount = 1 },
        { name = 'handsaw',       label = 'Handsaw',         amount = 1 },
        { name = 'barrel',        label = 'Barrel',          amount = 4 },
    } },
    { name = 'upgrade +7', level = 7, slots = 1500, price = 1500, items = {
        { name = 'hwoodboard',    label = 'Hard Wood Board', amount = 20 },
        { name = 'nails',         label = 'Nails',           amount = 20 },
        { name = 'wooden_boards', label = 'Wooden Boards',   amount = 20 },
        { name = 'ironbar',       label = 'Iron Bar',        amount = 30 },
        { name = 'sap',           label = 'Sap',             amount = 10 },
        { name = 'ironhammer',    label = 'Iron Hammer',     amount = 2 },
        { name = 'handsaw',       label = 'Handsaw',         amount = 2 },
        { name = 'barrel',        label = 'Barrel',          amount = 5 },
    } },
}

----------------------------------------------------------------------------------------------------
-- Look of the shack
----------------------------------------------------------------------------------------------------
Config.Themes = {
    { label = 'Floral',  set = 'mp006_mshine_theme_floral',  price = 100 },
    { label = 'Goth',    set = 'mp006_mshine_theme_goth',    price = 200 },
    { label = 'Hunter',  set = 'mp006_mshine_theme_hunter',  price = 50 },
    { label = 'Refined', set = 'mp006_mshine_theme_refined', price = 300 },
}

Config.DecorCategories = { 'christmas', 'shelf', 'frame', 'struct', 'bench', 'band' }
Config.DecorCategoryLabels = {
    christmas = 'Christmas', shelf = 'Shelves', frame = 'Picture Frames',
    struct = 'Structures', bench = 'Bench', band = 'Band Corner',
}

Config.Decorations = {
    { label = 'Christmas', category = 'christmas', set = 'mp006_mshine_theme_christmas', price = 100 },
    { label = 'Shelf 1', category = 'shelf', set = 'mp006_mshine_shelfwall1', price = 20 },
    { label = 'Shelf 2', category = 'shelf', set = 'mp006_mshine_shelfwall2', price = 20 },
    { label = 'Bench', category = 'bench', set = 'mp006_mshine_bar_benchAndFrame', price = 20 },
    { label = 'Boarded',  category = 'band', set = 'mp006_mshine_band1',  price = 100 },
    { label = 'Boarded2', category = 'band', set = 'mp006_mshine_band1b', price = 100 },
    { label = 'Shelves',  category = 'band', set = 'mp006_mshine_band1c', price = 100 },
    { label = 'Piano',    category = 'band', set = 'mp006_mshine_band2',  price = 500 },
}
for i = 1, 10 do
    Config.Decorations[#Config.Decorations + 1] = { label = ('Picture Frame %d'):format(i), category = 'frame', set = ('mp006_mshine_pic_%02d'):format(i), price = 50 }
end
for i = 1, 5 do
    Config.Decorations[#Config.Decorations + 1] = { label = ('Structure %d'):format(i), category = 'struct', set = ('mp006_mshine_location%d'):format(i), price = 30 }
end
