-- Start-up, player lifecycle and shutdown.

PH = PH or {}

local function registerItem()
    local ok, err = pcall(function()
        exports.vorp_inventory:registerUsableItem(Config.Item, function(data)
            -- own thread: the use may wait for the database load, and the
            -- callback runs inside vorp_inventory's call, which must not yield
            CreateThread(function() PH.OnItemUsed(data) end)
        end, PH.Res)
    end)
    if not ok then
        print(('^1[%s]^7 could not register the %s item: %s'):format(PH.Res, Config.Item, tostring(err)))
    end
end

-- the item is registered at once; a use waits for the database load (see PH.OnItemUsed)
registerItem()

CreateThread(function()
    local ok, err = pcall(PH.LoadAll)
    if not ok then
        print(('^1[%s]^7 loading phonographs failed: %s'):format(PH.Res, tostring(err)))
        return
    end
    TriggerClientEvent('pup-phonograph:client:list', -1, PH.PublicList())
end)

local function forget(src)
    PH.ForgetPlacement(src)
    PH.ForgetPlayer(src)
end

AddEventHandler('playerDropped', function()
    local src = source
    forget(src)
    PH.DropListener(src)
    if Config.StopWhenStarterLeaves then PH.StopStartedBy(src) end
end)

-- character select / switch: drop half-done placements and re-send staff status.
-- The client asks for its music again itself (pup-phonograph:server:resync).
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if not src then return end
    forget(src)
    TriggerClientEvent('pup-phonograph:client:staff', src, PH.IsStaff(src))
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= PH.Res then return end
    TriggerClientEvent('pup-phonograph:client:stopAll', -1)
    pcall(function() exports.vorp_inventory:unRegisterUsableItem(Config.Item) end)
end)
