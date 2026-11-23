-- pup_realestate | house storage tiers
-- Tiers are bought one after another; the materials are taken from the house stash.
-- Each tier is { slots = extra slots, { item, amount }, { item, amount }, ... }.
-- A tier may also set name = 'menu text'; otherwise the menu shows "Storage tier N".

-- menu names for the material items (vorp_inventory item name = label)
Config.UpgradeMaterials = {
    nails = 'Nails',
    wood = 'Softwood',
    hwood = 'Hardwood',
    clay = 'Clay',
    rock = 'Stone',
    sap = 'Tree Sap',
    fibers = 'Plant Fibre',
    wooden_boards = 'Softwood Planks',
    hwoodboard = 'Hardwood Planks',
    timber = 'Timber Beam',
    barrel = 'Empty Barrel',
    ironbar = 'Iron Bar',
    copper_bar = 'Copper Bar',
    bolts = 'Bolts',
    wax = 'Beeswax',
    string = 'Twine',
    varnish = 'Varnish',
    leather = 'Leather',
    cloth = 'Cloth',
    wicker = 'Wicker',
    ironhammer = 'Iron Hammer',
    wood_plane = 'Hand Plane',
    handsaw = 'Hand Saw',
    laddera = 'Ladder',
    legbeawers = 'Legendary Beaver Pelt',
    legcougars = 'Legendary Cougar Pelt',
    leggbears = 'Legendary Bear Pelt',
}

Config.StorageTiers = {
    -- 1-2: rough timber
    { slots = 25, { 'nails', 5 }, { 'wood', 10 }, { 'clay', 5 } },
    { slots = 25, { 'nails', 10 }, { 'wood', 20 }, { 'clay', 5 } },
    -- 3-4: hardwood
    { slots = 50, { 'nails', 15 }, { 'hwood', 25 }, { 'clay', 5 } },
    { slots = 50, { 'nails', 15 }, { 'wooden_boards', 15 }, { 'rock', 20 }, { 'hwood', 20 } },
    -- 5-6: sealed
    { slots = 100, { 'nails', 25 }, { 'wooden_boards', 25 }, { 'rock', 25 }, { 'hwood', 20 }, { 'sap', 5 }, { 'fibers', 10 } },
    { slots = 100, { 'nails', 25 }, { 'wooden_boards', 25 }, { 'rock', 25 }, { 'hwood', 20 }, { 'sap', 10 }, { 'fibers', 20 } },
    -- 7-10: iron fittings
    { slots = 200, { 'nails', 35 }, { 'wooden_boards', 25 }, { 'hwoodboard', 25 }, { 'ironhammer', 1 }, { 'ironbar', 10 }, { 'fibers', 20 }, { 'sap', 10 } },
    { slots = 200, { 'nails', 35 }, { 'wooden_boards', 25 }, { 'hwoodboard', 25 }, { 'ironhammer', 1 }, { 'ironbar', 10 }, { 'fibers', 25 }, { 'sap', 15 } },
    { slots = 200, { 'nails', 35 }, { 'wooden_boards', 25 }, { 'hwoodboard', 25 }, { 'ironhammer', 1 }, { 'ironbar', 10 }, { 'fibers', 30 }, { 'sap', 20 }, { 'barrel', 5 } },
    { slots = 200, { 'nails', 35 }, { 'wooden_boards', 25 }, { 'hwoodboard', 25 }, { 'ironhammer', 1 }, { 'ironbar', 20 }, { 'fibers', 40 }, { 'sap', 30 }, { 'barrel', 10 } },
    -- 11-13: copper and wax
    { slots = 250, { 'nails', 50 }, { 'barrel', 10 }, { 'hwoodboard', 40 }, { 'ironhammer', 1 }, { 'timber', 5 }, { 'wax', 5 }, { 'copper_bar', 5 }, { 'string', 8 } },
    { slots = 250, { 'nails', 50 }, { 'barrel', 10 }, { 'hwoodboard', 40 }, { 'ironhammer', 1 }, { 'timber', 10 }, { 'wax', 10 }, { 'copper_bar', 10 }, { 'string', 12 } },
    { slots = 250, { 'nails', 50 }, { 'barrel', 20 }, { 'hwoodboard', 40 }, { 'ironhammer', 1 }, { 'timber', 5 }, { 'wax', 10 }, { 'copper_bar', 10 }, { 'string', 15 } },
    -- 14-17: joinery
    { slots = 300, { 'nails', 60 }, { 'barrel', 10 }, { 'timber', 15 }, { 'ironhammer', 2 }, { 'wood_plane', 1 }, { 'bolts', 10 }, { 'varnish', 10 }, { 'wax', 10 }, { 'copper_bar', 10 } },
    { slots = 300, { 'nails', 60 }, { 'barrel', 10 }, { 'timber', 15 }, { 'ironhammer', 2 }, { 'wood_plane', 1 }, { 'bolts', 10 }, { 'varnish', 10 }, { 'wax', 10 }, { 'copper_bar', 10 } },
    { slots = 300, { 'nails', 60 }, { 'barrel', 10 }, { 'timber', 20 }, { 'ironhammer', 2 }, { 'wood_plane', 1 }, { 'bolts', 20 }, { 'varnish', 10 }, { 'wax', 10 }, { 'copper_bar', 20 } },
    { slots = 300, { 'nails', 60 }, { 'barrel', 10 }, { 'timber', 20 }, { 'ironhammer', 2 }, { 'wood_plane', 1 }, { 'bolts', 25 }, { 'varnish', 10 }, { 'wax', 10 }, { 'copper_bar', 25 } },
    -- 18-19: lined
    { slots = 300, { 'nails', 60 }, { 'barrel', 20 }, { 'timber', 30 }, { 'ironhammer', 2 }, { 'wood_plane', 2 }, { 'handsaw', 2 }, { 'leather', 8 }, { 'cloth', 10 }, { 'bolts', 30 }, { 'varnish', 20 }, { 'wax', 20 }, { 'wicker', 15 } },
    { slots = 300, { 'nails', 60 }, { 'barrel', 20 }, { 'timber', 30 }, { 'ironhammer', 2 }, { 'wood_plane', 2 }, { 'handsaw', 2 }, { 'leather', 10 }, { 'cloth', 15 }, { 'bolts', 30 }, { 'varnish', 20 }, { 'wax', 20 }, { 'wicker', 20 } },
    -- 20-22: each needs one legendary pelt
    { slots = 400, { 'nails', 100 }, { 'barrel', 20 }, { 'hwoodboard', 50 }, { 'wooden_boards', 50 }, { 'timber', 20 }, { 'leather', 10 }, { 'laddera', 2 }, { 'handsaw', 2 }, { 'ironhammer', 2 }, { 'wood_plane', 2 }, { 'bolts', 30 }, { 'copper_bar', 20 }, { 'wicker', 20 }, { 'string', 10 }, { 'legbeawers', 1 } },
    { slots = 400, { 'nails', 100 }, { 'barrel', 20 }, { 'hwoodboard', 50 }, { 'wooden_boards', 50 }, { 'timber', 20 }, { 'leather', 10 }, { 'handsaw', 2 }, { 'ironhammer', 2 }, { 'wood_plane', 2 }, { 'bolts', 30 }, { 'copper_bar', 20 }, { 'wicker', 20 }, { 'string', 10 }, { 'legcougars', 1 } },
    { slots = 400, { 'nails', 100 }, { 'barrel', 20 }, { 'hwoodboard', 50 }, { 'wooden_boards', 50 }, { 'timber', 20 }, { 'leather', 10 }, { 'handsaw', 2 }, { 'ironhammer', 2 }, { 'wood_plane', 2 }, { 'bolts', 30 }, { 'copper_bar', 20 }, { 'wicker', 20 }, { 'string', 10 }, { 'leggbears', 1 } },
}
