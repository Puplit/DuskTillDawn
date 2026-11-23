-- pup-misc / traffic - ambient ped, animal and vehicle density (settings: config/traffic/main.lua)

-- towns where animals are switched off, by hash
local noAnimalTowns = {}
for _, name in ipairs(TrafficConfig.Density.noAnimalTowns or {}) do
    noAnimalTowns[GetHashKey(name)] = true
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        local pedCoords = GetEntityCoords(PlayerPedId())
        local town_hash = Citizen.InvokeNative(0x43AD8FC02B429D33, pedCoords, 1)
        local animalfreq = TrafficConfig.Density.animals
        if noAnimalTowns[town_hash] then 
            animalfreq = 0.0
        end

        -- Peds
        Citizen.InvokeNative(0xAB0D553FE20A6E25,TrafficConfig.Density.peds) -- SetAmbientPedDensityMultiplierThisFrame
        Citizen.InvokeNative(0x7A556143A1C03898,TrafficConfig.Density.peds) -- SetScenarioPedDensityMultiplierThisFrame

        -- Humans
        Citizen.InvokeNative(0xBA0980B5C0A11924,TrafficConfig.Density.peds) -- SetAmbientHumanDensityMultiplierThisFrame
        Citizen.InvokeNative(0x28CB6391ACEDD9DB,TrafficConfig.Density.peds) -- SetScenarioHumanDensityMultiplierThisFrame

        -- Animals
        Citizen.InvokeNative(0xC0258742B034DFAF,animalfreq) -- SetAmbientAnimalDensityMultiplierThisFrame
        Citizen.InvokeNative(0xDB48E99F8E064E56,animalfreq) -- SetScenarioAnimalDensityMultiplierThisFrame

        -- Vehicles
        Citizen.InvokeNative(0xFEDFA97638D61D4A,TrafficConfig.Density.vehicles) -- SetParkedVehicleDensityMultiplierThisFrame
        Citizen.InvokeNative(0x1F91D44490E1EA0C,TrafficConfig.Density.vehicles) -- SetRandomVehicleDensityMultiplierThisFrame
        Citizen.InvokeNative(0x606374EBFC27B133,TrafficConfig.Density.vehicles) -- SetVehicleDensityMultiplierThisFrame

    end 
end)