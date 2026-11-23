-- pup_railroad | delivery routes, grouped by circuit (shownTotal is display only; each stop's pay is what is paid)

local circuits = {
    newhanover = {
        {
            name = 'New Hanover Line Run', description = 'Work the line. Every station takes its share.', shownTotal = 1300,
            stops = {
                { stop = 'Valentine',     position = vector3(-176.2, 628.27, 114.09),     pay = 250, cargo = {
                    { item = 'wool',            label = 'Wool',            count = 15 },
                } },
                { stop = 'Emerald Ranch', position = vector3(1523.527, 442.676, 90.728),  pay = 300, cargo = {
                    { item = 'fertilizer',      label = 'Fertilizer',      count = 10 },
                    { item = 'wooden_boards',   label = 'Wooden Boards',   count = 10 },
                } },
                { stop = 'Rhodes',        position = vector3(1229.50, -1298.20, 76.95),   pay = 300, cargo = {
                    { item = 'alcohol',         label = 'Alcohol',         count = 10 },
                } },
                { stop = 'Saint Denis',   position = vector3(2735.09, -1434.52, 45.9),    pay = 450, cargo = {
                    { item = 'medical_box_bag', label = 'Medical Box',     count = 2 },
                    { item = 'stim2',           label = 'Horse Stimulant', count = 5 },
                } },
            },
        },
        {
            name = 'New Hanover Mission 1', description = 'Stone and clay up to the overlook.', shownTotal = 300,
            stops = {
                { stop = 'Valentine',          position = vector3(-176.2, 628.27, 114.09), pay = 150, cargo = {
                    { item = 'rock', label = 'Rock', count = 60 },
                } },
                { stop = 'Horseshoe Overlook', position = vector3(484.6, 662.9, 117.4),    pay = 150, cargo = {
                    { item = 'clay', label = 'Clay', count = 75 },
                } },
            },
        },
        {
            name = 'New Hanover Mission 2', description = 'Hardware and cloth, east along the river.', shownTotal = 550,
            stops = {
                { stop = 'Emerald Ranch', position = vector3(1523.527, 442.676, 90.728), pay = 150, cargo = {
                    { item = 'wool',       label = 'Wool',        count = 10 },
                } },
                { stop = 'Annesburg',     position = vector3(2939.39, 1288.43, 44.4),    pay = 200, cargo = {
                    { item = 'bolts',      label = 'Bolts',       count = 5 },
                    { item = 'ironhammer', label = 'Iron Hammer', count = 5 },
                } },
                { stop = 'Van Horn',      position = vector3(2892.96, 626.84, 57.75),    pay = 200, cargo = {
                    { item = 'fibers',     label = 'Fibers',      count = 10 },
                } },
            },
        },
        {
            name = 'New Hanover Mission 3', description = 'Timber and iron, west into Big Valley.', shownTotal = 715,
            stops = {
                { stop = 'Riggs Station', position = vector3(-1095.6, -576.6, 82.45),    pay = 215, cargo = {
                    { item = 'wooden_boards', label = 'Wooden Boards',   count = 20 },
                } },
                { stop = 'Blackwater',    position = vector3(-880.65, -1244.34, 43.92),  pay = 250, cargo = {
                    { item = 'stim2',         label = 'Horse Stimulant', count = 5 },
                } },
                { stop = 'Big Valley',    position = vector3(-1346.13, -199.81, 101.92), pay = 250, cargo = {
                    { item = 'ironbar',       label = 'Iron Bar',        count = 20 },
                    { item = 'string',        label = 'String',          count = 20 },
                } },
            },
        },
        {
            name = 'New Hanover Mission 4', description = 'The long haul. Ends with a legendary hide.', shownTotal = 2000,
            stops = {
                { stop = 'Rhodes',           position = vector3(1229.50, -1298.20, 76.95), pay = 600, cargo = {
                    { item = 'fertilizer',      label = 'Fertilizer',           count = 10 },
                    { item = 'copper_bar',      label = 'Copper Bar',           count = 20 },
                } },
                { stop = 'Annesburg',        position = vector3(2939.39, 1288.43, 44.4),   pay = 650, cargo = {
                    { item = 'alcohol',         label = 'Alcohol',              count = 10 },
                    { item = 'medical_box_bag', label = 'Medical Box',          count = 2 },
                } },
                { stop = 'Saint Denis Yard', position = vector3(2430.38, -1506.87, 45.97), pay = 750, cargo = {
                    { item = 'shellcasing',     label = 'Shell Casings',        count = 175 },
                    { item = 'legbisons',       label = 'Legendary Bison Pelt', count = 1 },
                } },
            },
        },
    },
    newaustin = {
        {
            name = 'New Austin Line Run', description = 'Three stops across the dry country.', shownTotal = 1100,
            stops = {
                { stop = 'Armadillo',       position = vector3(-3729.02, -2601.26, -12.93), pay = 300, cargo = {
                    { item = 'ironbar',       label = 'Iron Bar',        count = 10 },
                } },
                { stop = 'Armadillo Yard',  position = vector3(-2494.85, -2437.45, 60.7),   pay = 350, cargo = {
                    { item = 'ironhammer',    label = 'Iron Hammer',     count = 3 },
                    { item = 'wooden_boards', label = 'Wooden Boards',   count = 10 },
                } },
                { stop = 'Armadillo Depot', position = vector3(-5230.2, -3468.1, -20.35),   pay = 450, cargo = {
                    { item = 'alcohol',       label = 'Alcohol',         count = 10 },
                    { item = 'stim2',         label = 'Horse Stimulant', count = 5 },
                } },
            },
        },
        {
            name = 'New Austin Mission 1', description = 'Stone and clay out to the far depot.', shownTotal = 300,
            stops = {
                { stop = 'Armadillo Depot', position = vector3(-5230.2, -3468.1, -20.35),   pay = 150, cargo = {
                    { item = 'rock', label = 'Rock', count = 60 },
                } },
                { stop = 'Cholla Springs',  position = vector3(-5378.94, -3670.92, -22.48), pay = 150, cargo = {
                    { item = 'clay', label = 'Clay', count = 75 },
                } },
            },
        },
        {
            name = 'New Austin Mission 2', description = 'Hardware and cloth, running west.', shownTotal = 550,
            stops = {
                { stop = 'Armadillo',       position = vector3(-3729.02, -2601.26, -12.93), pay = 150, cargo = {
                    { item = 'wool',       label = 'Wool',        count = 10 },
                } },
                { stop = 'Rio Bravo',       position = vector3(-4360.5, -3079.21, -10.02),  pay = 200, cargo = {
                    { item = 'bolts',      label = 'Bolts',       count = 5 },
                    { item = 'ironhammer', label = 'Iron Hammer', count = 5 },
                } },
                { stop = 'Armadillo Depot', position = vector3(-5230.2, -3468.1, -20.35),   pay = 200, cargo = {
                    { item = 'fibers',     label = 'Fibers',      count = 10 },
                } },
            },
        },
        {
            name = 'New Austin Mission 3', description = 'Timber and iron through the hills.', shownTotal = 715,
            stops = {
                { stop = 'Armadillo Yard', position = vector3(-2494.85, -2437.45, 60.7),   pay = 215, cargo = {
                    { item = 'wooden_boards', label = 'Wooden Boards',   count = 20 },
                } },
                { stop = 'Armadillo',      position = vector3(-3729.02, -2601.26, -12.93), pay = 250, cargo = {
                    { item = 'stim2',         label = 'Horse Stimulant', count = 5 },
                } },
                { stop = 'Gaptooth Ridge', position = vector3(-5017.78, -2752.49, -12.09), pay = 250, cargo = {
                    { item = 'ironbar',       label = 'Iron Bar',        count = 20 },
                    { item = 'string',        label = 'String',          count = 20 },
                } },
            },
        },
        {
            name = 'New Austin Mission 4', description = 'The long haul. Ends with a legendary hide.', shownTotal = 2000,
            stops = {
                { stop = 'Armadillo Yard',   position = vector3(-2494.85, -2437.45, 60.7), pay = 600, cargo = {
                    { item = 'fertilizer',      label = 'Fertilizer',               count = 10 },
                    { item = 'copper_bar',      label = 'Copper Bar',               count = 20 },
                } },
                { stop = 'Armadillo Depot',  position = vector3(-5230.2, -3468.1, -20.35), pay = 650, cargo = {
                    { item = 'alcohol',         label = 'Alcohol',                  count = 10 },
                    { item = 'medical_box_bag', label = 'Medical Box',              count = 2 },
                } },
                { stop = "Hennigan's Stead", position = vector3(-3743.59, -2639.15, -14.0), pay = 750, cargo = {
                    { item = 'shellcasing',     label = 'Shell Casings',            count = 175 },
                    { item = 'legprongs',       label = 'Legendary Pronghorn Pelt', count = 1 },
                } },
            },
        },
    },
    ambarino = {
        {
            name = 'Ambarino Line Run', description = 'The mountain stations. Cold work, decent pay.', shownTotal = 1200,
            stops = {
                { stop = 'Bacchus Station', position = vector3(582.49, 1681.31, 187.78),    pay = 350, cargo = {
                    { item = 'wooden_boards',   label = 'Wooden Boards', count = 15 },
                } },
                { stop = 'Manzanita Post',  position = vector3(-1944.43, -1608.14, 116.69), pay = 400, cargo = {
                    { item = 'wool',            label = 'Wool',          count = 10 },
                    { item = 'alcohol',         label = 'Alcohol',       count = 5 },
                } },
                { stop = 'Wallace Station', position = vector3(-1299.4, 402.1, 95.39),      pay = 450, cargo = {
                    { item = 'medical_box_bag', label = 'Medical Box',   count = 2 },
                    { item = 'ironbar',         label = 'Iron Bar',      count = 10 },
                } },
            },
        },
    },
}

--------------------------------------------------------------------------------
-- Nothing to edit below: this turns the routes above into the shape the code reads.
--------------------------------------------------------------------------------
Config.Circuits = {}
for circuit, routes in pairs(circuits) do
    local out = {}
    for r, route in ipairs(routes) do
        local stops = {}
        for s, st in ipairs(route.stops) do
            local cargo = {}
            for c, item in ipairs(st.cargo) do
                cargo[c] = { item = item.item, label = item.label, count = item.count }
            end
            stops[s] = { name = st.stop, coords = st.position, pay = st.pay, cargo = cargo }
        end
        out[r] = { name = route.name, description = route.description, total = route.shownTotal, stops = stops }
    end
    Config.Circuits[circuit] = out
end
