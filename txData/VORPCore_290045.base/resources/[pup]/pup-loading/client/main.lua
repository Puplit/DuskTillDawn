-- pup-loading | the manifest sets loadscreen_manual_shutdown, so the dismissal is ours

local WATCHDOG_MS = (Config.WatchdogSeconds or 12) * 1000 -- backstop; the events below normally fire first
local done = false

local function finish(reason)
    if done then return end
    done = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    SetNuiFocus(false, false) -- the frame goes, the input focus does not
    print(('[pup-loading] loading screen dismissed (%s)'):format(reason))
end

-- character flow (vorp_character)
RegisterNetEvent('vorpcharacter:startCharacterCreator', function() finish('character creator') end)
RegisterNetEvent('vorpcharacter:selectCharacter',       function() finish('character select') end)
RegisterNetEvent('vorpcharacter:spawnUniqueCharacter',  function() finish('unique character') end)

-- world/spawn flow (vorp_core + spawnmanager)
RegisterNetEvent('vorp:initCharacter',   function() finish('vorp:initCharacter') end)
RegisterNetEvent('vorp:SelectedCharacter', function() finish('vorp:SelectedCharacter') end)
AddEventHandler('playerSpawned',         function() finish('playerSpawned') end)

-- backstop, in case none of the above fires
CreateThread(function()
    Wait(WATCHDOG_MS)
    finish('watchdog timeout')
end)
