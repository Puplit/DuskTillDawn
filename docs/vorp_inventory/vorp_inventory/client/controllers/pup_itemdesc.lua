-- Player-written item descriptions: the satchel's edit card talks to the server
-- through here. Every rule is re-checked server side; this half is only the UI.

local myCharId = nil

local function pushWho()
    SendNUIMessage({ action = 'pup_descWho', charid = myCharId })
end

RegisterNetEvent('vorp:SelectedCharacter', function(charid)
    myCharId = tonumber(charid)
    pushWho()
end)

-- the server answers too, for a resource restart after vorp:SelectedCharacter has fired
RegisterNetEvent('pup_inventory:whoAmI', function(charid)
    myCharId = tonumber(charid)
    pushWho()
end)

local function askServer()
    if myCharId == nil then TriggerServerEvent('pup_inventory:whoAmI') end
end

CreateThread(function()
    Wait(2000)
    askServer()
end)

-- the page can load after the character did, so it asks as well
RegisterNUICallback('PupDescWho', function(_, cb)
    askServer()
    cb({ charid = myCharId })
end)

-- the saved list lives in pup_workbench's KVP, so the bench and this card share one
local function savedList()
    if GetResourceState('pup_workbench') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports['pup_workbench']:GetSavedDescriptions() end)
    return (ok and type(list) == 'table') and list or {}
end

RegisterNUICallback('PupDescSavedGet', function(_, cb)
    cb({ list = savedList() })
end)

RegisterNUICallback('PupDescSavedSet', function(data, cb)
    local list <const> = (type(data) == 'table' and type(data.list) == 'table') and data.list or {}
    -- client event, so pup_workbench picks it up and writes it back to KVP
    TriggerEvent('pup_inventory:savedDescriptions', list)
    cb({ list = list })
end)

RegisterNUICallback('PupDescSave', function(data, cb)
    cb({})
    if type(data) ~= 'table' then return end
    local id <const> = tonumber(data.id)
    if not id then return end
    TriggerServerEvent('pup_inventory:setItemDescription', id, tostring(data.text or ''))
end)
