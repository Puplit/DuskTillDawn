-- pup_business | duty stations (used only when Config.DutyStationsEnabled = true in config/main.lua)
-- jobs = who may clock on here | blip = true shows it on the map, false hides it

Config.DutyStations = {
    { region = 'armadillo',  coords = vector3(-3620.92, -2606.35, -13.33), jobs = { 'police', 'marshal' }, label = 'Armadillo Duty Station',  blip = true },
    { region = 'blackwater', coords = vector3(-761.7, -1268.1, 44.0),      jobs = { 'police', 'marshal' }, label = 'Blackwater Duty Station', blip = true },
    { region = 'strawberry', coords = vector3(-1814.0, -354.8, 164.6),     jobs = { 'police', 'marshal' }, label = 'Strawberry Duty Station', blip = true },
    { region = 'valentine',  coords = vector3(-278.4, 805.3, 119.3),       jobs = { 'police', 'marshal' }, label = 'Valentine Duty Station',  blip = true },
    { region = 'annes',      coords = vector3(2908.3, 1308.9, 44.9),       jobs = { 'police', 'marshal' }, label = 'Annesburg Duty Station',  blip = true },
    { region = 'rhodes',     coords = vector3(1361.95, -1298.9, 77.76),    jobs = { 'police', 'marshal' }, label = 'Rhodes Duty Station',     blip = true },
    { region = 'sd',         coords = vector3(2511.99, -1309.1, 48.95),    jobs = { 'police', 'marshal' }, label = 'Saint Denis Duty Station', blip = true },
}
