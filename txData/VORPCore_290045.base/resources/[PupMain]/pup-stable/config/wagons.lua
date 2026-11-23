-- pup-stable | wagons for sale. Keep categories and wagons in order: see README.

Config.WagonCategories = {
    { id = 1, name = 'Utility & Work', wagons = {
        { model = 'cart01',          name = 'Small Cart',           price = 500, storage = 100, seats = 2, horses = 1 },
        { model = 'cart02',          name = 'Wood Cart',            price = 500, storage = 100, seats = 2, horses = 1 },
        { model = 'cart03',          name = 'Delivery Cart',        price = 500, storage = 300, seats = 2, horses = 1 },
        { model = 'cart04',          name = 'Heavy Cart',           price = 500, storage = 100, seats = 2, horses = 1 },
        { model = 'cart05',          name = 'Tiny Cart',            price = 150, storage = 25, seats = 1, horses = 1 },
        { model = 'cart06',          name = 'Large Delivery Cart',  price = 1000, storage = 500, seats = 2, horses = 2 },
        { model = 'cart07',          name = 'Flatbed Cart',         price = 500, storage = 100, seats = 2, horses = 1 },
        { model = 'cart08',          name = 'Industrial Cart',      price = 500, storage = 100, seats = 2, horses = 1 },
        { model = 'chuckwagon000x',  name = 'Chuckwagon',           price = 500, storage = 100, seats = 2, horses = 2 },
        { model = 'chuckwagon002x',  name = 'Large Chuckwagon',     price = 20000, storage = 10000, seats = 2, horses = 2 },
        { model = 'coal_wagon',      name = 'Coal Wagon',           price = 750, storage = 150, seats = 2, horses = 2 },
        { model = 'huntercart01',    name = 'Hunter Cart',          price = 500, storage = 150, seats = 2, horses = 1 },
        { model = 'supplywagon',     name = 'Large Supply Wagon',   price = 10000, storage = 5000, seats = 2, horses = 4 },
        { model = 'utilliwag',       name = 'Utility Wagon',        price = 1000, storage = 500, seats = 2, horses = 2 },
        { model = 'wagon02x',        name = 'Heavy Wagon',          price = 5000, storage = 2500, seats = 2, horses = 2 },
        { model = 'wagon03x',        name = 'Standard Wagon',       price = 1500, storage = 750, seats = 2, horses = 2 },
        { model = 'wagon04x',        name = 'reinforced Wagon',     price = 5000, storage = 2500, seats = 2, horses = 2 },
        { model = 'wagon05x',        name = 'Cargo Wagon',          price = 1500, storage = 750, seats = 2, horses = 2 },
        { model = 'wagon06x',        name = 'Light Wagon',          price = 500, storage = 250, seats = 2, horses = 1 },
        { model = 'wagonwork01x',    name = 'Work Wagon',           price = 500, storage = 250, seats = 2, horses = 2 },
    } },
    { id = 2, name = 'Coaches & Buggies', wagons = {
        { model = 'buggy01',  name = 'Small Buggy',       price = 500, storage = 50, seats = 2, horses = 1 },
        { model = 'buggy02',  name = 'Reinforced Buggy',  price = 500, storage = 50, seats = 2, horses = 1 },
        { model = 'buggy03',  name = 'Buggy',             price = 500, storage = 50, seats = 2, horses = 1 },
        { model = 'coach2',   name = 'Elegant Coach',     price = 3000, storage = 100, seats = 6, horses = 2 },
        { model = 'coach3',   name = 'Luxury Coach',      price = 3000, storage = 100, seats = 6, horses = 4 },
        { model = 'coach4',   name = 'Standard Coach',    price = 2500, storage = 100, seats = 6, horses = 2 },
        { model = 'coach5',   name = 'Heavy Coach',       price = 2500, storage = 100, seats = 6, horses = 2 },
        { model = 'coach6',   name = 'Traveler Coach',    price = 2500, storage = 100, seats = 6, horses = 2 },
    } },
    { id = 3, name = 'Stagecoaches', wagons = {
        { model = 'stagecoach001x',    name = 'Standard Stagecoach',    price = 3000, storage = 100, seats = 6, horses = 4 },
        { model = 'stagecoach002x',    name = 'Reinforced Stagecoach',  price = 3000, storage = 100, seats = 6, horses = 4 },
        { model = 'stagecoach003x',    name = 'Light Stagecoach',       price = 1500, storage = 100, seats = 4, horses = 2 },
        { model = 'stagecoach004_2x',  name = 'Heavy Stagecoach 2',     price = 3500, storage = 100, seats = 6, horses = 4 },
        { model = 'stagecoach004x',    name = 'Heavy Stagecoach',       price = 3500, storage = 100, seats = 6, horses = 4 },
        { model = 'stagecoach005x',    name = 'Traveler Stagecoach',    price = 2750, storage = 100, seats = 6, horses = 4 },
        { model = 'stagecoach006x',    name = 'Small Stagecoach',       price = 1500, storage = 100, seats = 4, horses = 2 },
    } },
    { id = 4, name = 'Specialized & Government', wagons = {
        { model = 'armysupplywagon',        name = 'Blue Army Wagon',       forSale = false, storage = 50, seats = 2, horses = 4 },
        { model = 'bountywagon01x',         name = 'Bounty Wagon',          forSale = false, storage = 50, seats = 2, horses = 2 },
        { model = 'oilwagon01x',            name = 'Oil Wagon',             price = 1500, storage = 10, seats = 2, horses = 2 },
        { model = 'oilwagon02x',            name = 'Large Oil Wagon',       price = 1500, storage = 10, seats = 2, horses = 2 },
        { model = 'policewagon01x',         name = 'Police Wagon',          forSale = false, storage = 250, seats = 2, horses = 2 },
        { model = 'policewagongatling01x',  name = 'Police Gatling Wagon',  forSale = false, storage = 250, seats = 2, horses = 2 },
        { model = 'wagonarmoured01x',       name = 'Armoured Wagon',        forSale = false, storage = 250, seats = 2, horses = 4 },
        { model = 'wagoncircus01x',         name = 'Circus Wagon',          price = 750, storage = 250, seats = 2, horses = 2 },
        { model = 'wagoncircus02x',         name = 'Large Circus Wagon',    price = 750, storage = 250, seats = 2, horses = 2 },
        { model = 'wagondairy01x',          name = 'Dairy Wagon',           price = 750, storage = 250, seats = 2, horses = 2 },
        { model = 'wagondoc01x',            name = 'Doctor Wagon',          price = 750, storage = 250, seats = 2, horses = 2 },
        { model = 'wagonprison01x',         name = 'Prison Wagon',          forSale = false, storage = 250, seats = 2, horses = 2 },
        { model = 'wagontraveller01x',      name = 'Traveler Wagon',        price = 750, storage = 250, seats = 2, horses = 2 },
        { model = 'warwagon2',              name = 'War Wagon',             forSale = false, storage = 400000, seats = 2, horses = 4, job = 'police' },
        { model = 'gatchuck_2',             name = 'Gatling Chuckwagon 2',  forSale = false, storage = 1000, seats = 2, horses = 2 },
        { model = 'gatchuck',               name = 'Gatling Chuckwagon',    forSale = false, storage = 30, seats = 2, horses = 2 },
    } },
}

-- names for owned wagons whose model is not sold above
Config.WagonExtraNames = {
    supplywagon2 = 'Supply Wagon 2',
}

-------------------------------------------------------------------------------
-- Nothing to edit below: turns the list above into the lookups the stable uses.
-------------------------------------------------------------------------------
Config.NotForSale = 5e7   -- internal: a price at or above this means "not for sale"
Config.WagonByModel = {}
Config.WagonCategoryById = {}
Config.WagonDefaultNames = {}
for model, name in pairs(Config.WagonExtraNames) do Config.WagonDefaultNames[model:lower()] = name end
for _, c in ipairs(Config.WagonCategories) do
    c.label = c.name
    for i, wg in ipairs(c.wagons) do
        wg.label = wg.name
        if wg.forSale == false then wg.price = Config.NotForSale end
        if wg.storage then wg.locker = { slots = wg.storage, weight = Config.Locker.default.weight, weapons = true } end
        wg.seatsHint, wg.horsesHint = wg.seats, wg.horses
        Config.WagonByModel[wg.model:lower()] = { cat = c.id, index = i }
        Config.WagonDefaultNames[wg.model:lower()] = wg.name
    end
    Config.WagonCategoryById[c.id] = c
end
