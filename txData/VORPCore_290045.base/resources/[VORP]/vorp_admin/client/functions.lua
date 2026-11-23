-- Modified by Puppet (Dusk Till Dawn), 2026
-- FUNCTIONS -------------------------------------------------

local T = Translation.Langs[Config.General.language]

function Closem()
    PupMenu.Close()
    if Inmenu then
        Inmenu = false
    end
end

function GetPlayers()
    TriggerServerEvent("vorp_admin:GetPlayers")
    local playersData = {}
    RegisterNetEvent("vorp_admin:SendPlayers", function(result)
        playersData = result
    end)
    while next(playersData) == nil do
        Wait(10)
    end
    return playersData
end

function GetPlayersClient(player)
    local players = GetActivePlayers()
    for i = 1, #players, 1 do
        local server = GetPlayerServerId(players[i])
        if tonumber(server) == tonumber(player) then
            local ped = 0
            while ped == 0 do
                ped = GetPlayerPed(players[i])
                Wait(10)
            end
            return ped
        end
    end
end

-- Convert leftover HTML in localized menu descriptions to pup-ui plain text. <br> becomes a newline
function PlainDesc(s)
    if type(s) ~= "string" then return s end
    s = s:gsub("<br%s*/?>", "\n")
    s = s:gsub("<[^>]->", "")
    return s
end

-- pup-ui input helper: opens an OpenInput dialog and awaits the result
function AskInput(title, fields, subtitle)
    local p = promise.new()
    local owner = GetCurrentResourceName() .. ':' .. title
    local ev
    ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
        if o ~= owner then return end
        RemoveEventHandler(ev)
        p:resolve(values)
    end)
    exports['pup-ui']:OpenInput({
        owner = owner,
        title = title,
        subtitle = subtitle,
        submit = T.Menus.DefaultsInputs.confirm,
        fields = fields
    })
    return Citizen.Await(p)
end

-- MAIN MENU -----------------------------------------------------------------
function OpenMenu()
    PupMenu.Open({
        title = T.Menus.DefaultsMenusTitle.menuTitle,
        subtitle = T.Menus.DefaultsMenusTitle.menuSubTitle,
        options = {
            {
                label = T.Menus.MainMenuOptions.administration,
                desc = T.Menus.MainMenuOptions.administration_desc,
                submenu = function() if IsAdminAllowed("admin_menu") then return BuildAdmin() end end
            },
            {
                label = T.Menus.MainMenuOptions.booster,
                desc = T.Menus.MainMenuOptions.booster_desc,
                submenu = function() if IsAdminAllowed("boosters_menu") then return BuildBoost() end end
            },
            {
                label = T.Menus.MainMenuOptions.database,
                desc = T.Menus.MainMenuOptions.database_desc,
                submenu = function() if IsAdminAllowed("database_menu") then return BuildDataBase() end end
            },
            {
                label = T.Menus.MainMenuOptions.teleport,
                desc = T.Menus.MainMenuOptions.teleport_desc,
                submenu = function() if IsAdminAllowed("teleport_menu") then return BuildTeleport() end end
            },
            {
                label = T.Menus.MainMenuOptions.devTools,
                desc = T.Menus.MainMenuOptions.devTools_desc,
                submenu = function() if IsAdminAllowed("devtools_menu") then return BuildDevTools() end end
            },
        }
    })
end

-- FUNCTIONS
local function Round(input, decimalPlaces)
    return tonumber(string.format("%." .. (decimalPlaces or 0) .. "f", input))
end

function CopyToClipboard(dataType)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local x, y, z = Round(coords.x, 2), Round(coords.y, 2), Round(coords.z, 2)

    if dataType == 'v2' then
        local copiedText = string.format('{x = %s, y = %s, z = %s}', x, y, z)
        SendNUIMessage({ string = copiedText })
        TriggerEvent('vorp:TipRight', T.Notify.copied, 3000)
    elseif dataType == 'v3' then
        local copiedText = string.format('vector3(%s, %s, %s)', x, y, z)
        SendNUIMessage({ string = copiedText })
        TriggerEvent('vorp:TipRight', T.Notify.copied, 3000)
    elseif dataType == 'v4' then
        local heading = GetEntityHeading(ped)
        local h = Round(heading, 2)
        local copiedText = string.format('vector4(%s, %s, %s, %s)', x, y, z, h)
        SendNUIMessage({ string = copiedText })
        TriggerEvent('vorp:TipRight', T.Notify.copied, 3000)
    elseif dataType == 'heading' then
        local heading = Round(GetEntityHeading(ped), 2)
        SendNUIMessage({ string = heading })
        TriggerEvent('vorp:TipRight', T.Notify.copied, 3000)
    end
end

-- GET CLOSESTOBJECT
function GetClosestObject(coords)
    local ped = PlayerPedId()
    local objects = GetGamePool('CObject')
    local closestDistance = -1
    local closestObject = -1
    if not coords then
        coords = GetEntityCoords(ped)
    end

    for i = 1, #objects, 1 do
        local objectCoords = GetEntityCoords(objects[i])
        local distance = #(objectCoords - coords)
        if closestDistance == -1 or closestDistance > distance then
            closestObject = objects[i]
            closestDistance = distance
        end
    end
    return closestObject, closestDistance
end
