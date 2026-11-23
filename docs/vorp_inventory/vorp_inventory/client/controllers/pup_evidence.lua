-- Evidence locker bridge. The station check lives in pup-mdt; this carries it
-- to the inventory page and relays the click.

local lastStation = false

local function refreshStation()
    local ok, station = pcall(function()
        return exports.vorp_core:GetCore().Callback.TriggerAwait('pup-mdt:evidence:canSeize')
    end)
    local value = (ok and station) or false
    if value ~= lastStation then
        lastStation = value
        SendNUIMessage({ action = 'pupEvidenceState', station = value })
    end
end

local watching = false

local function watchWhileOpen()
    if watching then return end
    watching = true
    CreateThread(function()
        refreshStation()
        -- time boxed rather than trusting IS_INV_OPEN to be set yet
        for _ = 1, 200 do
            Wait(3000)
            if not IS_INV_OPEN then break end
            refreshStation()
        end
        watching = false
        lastStation = false
        SendNUIMessage({ action = 'pupEvidenceState', station = false })
    end)
end

RegisterNetEvent('vorp_inventory:OpenstealInventory', watchWhileOpen)
-- fires on every search refresh, so it covers a view opened another way
RegisterNetEvent('vorp_inventory:ReloadstealInventory', watchWhileOpen)

RegisterNUICallback('PupEvidenceSeize', function(data, cb)
    if cb then cb('ok') end
    if type(data) ~= 'table' or type(data.item) ~= 'table' then return end
    -- the target comes from the server's own search session, not from the page
    TriggerServerEvent('pup-mdt:evidence:seize', data.item)
end)
