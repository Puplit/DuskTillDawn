-- pup-misc/traffic | settings (see README)

TrafficConfig = {}

-------------------------------------------------------------------------------
-- GENERAL
-------------------------------------------------------------------------------
TrafficConfig.General = {}

TrafficConfig.Keys = {}

-------------------------------------------------------------------------------
-- INTEGRATIONS
-------------------------------------------------------------------------------
TrafficConfig.Integrations = {}

-------------------------------------------------------------------------------
-- DENSITY  (1.0 = the game's normal amount, 0.0 = none)
-------------------------------------------------------------------------------
TrafficConfig.Density = {
    peds     = 0.2,   -- ambient + scenario peds and humans
    animals  = 0.3,   -- ambient + scenario animals
    vehicles = 0.0,   -- parked, random and moving vehicles (wagons, coaches)

    -- towns where the animal density is forced to 0.0
    noAnimalTowns = { 'Armadillo', 'Vanhorn' },
}
