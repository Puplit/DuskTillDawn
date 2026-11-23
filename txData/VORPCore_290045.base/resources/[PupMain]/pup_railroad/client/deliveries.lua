-- pup_railroad | client: delivery routes

local L <const> = Rail.L

local stopBlip = nil
local waitingAnswer = false

--------------------------------------------------------------------------------
-- markers
--------------------------------------------------------------------------------
local function clearMarkers()
    Cl.removeBlip(stopBlip)
    stopBlip = nil
    Cl.native('ClearGpsMultiRoute', 0x6B4F6E8D4D4A5D0C)
end

local function placeMarkers()
    clearMarkers()
    local r = Cl.route
    if not r then return end
    local stop = r.route.stops[r.stop]
    if not stop then return end
    Cl.native('StartGpsMultiRoute', 0x3D3D15AF7BCAAF83, GetHashKey(Config.Blips.gpsColour), true, true)
    Cl.native('AddPointToGpsMultiRoute', 0x64C59DD6834FA942, stop.coords.x, stop.coords.y, stop.coords.z)
    Cl.native('SetGpsMultiRouteRender', 0x4426D65E029A4DC0, true)
    stopBlip = Cl.coordBlip(Config.Blips.stopSprite, stop.coords, Config.Blips.stopScale, stop.name)
    Citizen.InvokeNative(0x662D364ABF16DE2F, stopBlip, Config.Blips.stopModifier) -- blip colour modifier
end

--- end the running route on this client (markers cleared); message optional
function Cl.endRoute(message)
    if not Cl.route then return end
    Cl.route = nil
    waitingAnswer = false
    clearMarkers()
    if message then Cl.notify(message) end
end

local function beginRoute(route, trainId)
    Cl.route = { route = route, stop = 1, trainId = trainId }
    placeMarkers()
    Cl.notify(L('started', route.stops[1].name))
end

--------------------------------------------------------------------------------
-- route picker
--------------------------------------------------------------------------------
function Cl.openRoutePicker(st, trainId)
    if Cl.route then return Cl.notify(L('finish_first')) end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)

    local available = {}
    for _, routes in pairs(Config.Circuits) do
        for i = 1, #routes do
            local route = routes[i]
            -- same distance rule as the server
            if #(pos - route.stops[1].coords) >= Config.MinRouteDistance then
                available[#available + 1] = route
            end
        end
    end
    table.sort(available, function(a, b) return a.name < b.name end)

    local rows = {}
    for i = 1, #available do
        local route = available[i]
        local stopTexts = {}
        for s = 1, #route.stops do
            local stop = route.stops[s]
            local cargo = {}
            for c = 1, #stop.cargo do
                cargo[c] = ('%d %s'):format(stop.cargo[c].count, stop.cargo[c].label)
            end
            stopTexts[s] = ('%s (%s)'):format(stop.name, table.concat(cargo, ', '))
        end
        rows[#rows + 1] = {
            label = L('route_row', route.name, route.total),
            description = route.description .. ' ' .. L('stops_desc', #route.stops, table.concat(stopTexts, ' > ')),
            action = function()
                local r = Cl.call('startRoute', 6000, route.name, trainId)
                if not r then return Cl.officeSilent() end
                if not r.ok then return end
                Cl.closeMenu()
                beginRoute(route, trainId)
            end,
        }
    end
    if #rows == 0 then rows[1] = { label = L('no_routes') } end

    FreezeEntityPosition(ped, true)
    Cl.openMenu({
        title = L('deliver_title'),
        subtitle = st.name,
        rows = rows,
        onClose = function() FreezeEntityPosition(PlayerPedId(), false) end,
    })
end

--------------------------------------------------------------------------------
-- view / cancel (called from the driving prompts)
--------------------------------------------------------------------------------
function Cl.viewMission()
    local r = Cl.route
    if not r then return end
    local rows = {}
    for s = r.stop, #r.route.stops do
        local stop = r.route.stops[s]
        rows[#rows + 1] = {
            label = L('mission_row', stop.name, stop.pay),
            description = Rail.cargoText(stop.cargo),
        }
    end
    Cl.openMenu({ title = r.route.name, subtitle = L('deliver_title'), rows = rows })
end

function Cl.cancelMission()
    -- the server refuses a cancel while a stop is being paid; wait for that answer first
    if not Cl.route or waitingAnswer then return end
    Cl.tell('cancelRoute')
    Cl.endRoute(L('cancelled'))
end

--------------------------------------------------------------------------------
-- the train leaving the list ends the route; the server can end it too
--------------------------------------------------------------------------------
Cl.onListChanged(function()
    if Cl.route and not Cl.byId[Cl.route.trainId] then
        Cl.endRoute(L('train_gone'))
    end
end)

RegisterNetEvent('pup_railroad:routeEnded', function(reasonKey)
    if type(reasonKey) ~= 'string' or not Locale[reasonKey] then return end
    Cl.endRoute(L(reasonKey))
end)

-- a new character does not keep the old one's route
RegisterNetEvent('vorp:SelectedCharacter', function()
    Cl.endRoute(nil)
end)

--------------------------------------------------------------------------------
-- at a stop
--------------------------------------------------------------------------------
local function drawHint(text)
    Cl.native('SetTextScale', 0x4170B650590B3B00, 0.0, 0.42)
    Cl.native('SetTextColor', 0x50A41AD966910F03, 240, 232, 214, 235)
    Cl.native('SetTextCentre', 0xBE5261939FBECB8C, true)
    Cl.native('SetTextDropshadow', 0x1BE39DBAA7263CA5, 1, 0, 0, 0, 255)
    Cl.native('DisplayText', 0xD79334A4BB99BAD1, Cl.literal(text), 0.5, 0.86)
end

local function deliver(stopNo)
    waitingAnswer = true
    local r = Cl.call('deliver', Config.Timings.deliverAnswer, stopNo)
    waitingAnswer = false
    local route = Cl.route
    if not route then return end
    if not r then return Cl.officeSilent() end
    if not r.ok then return end
    if r.last then
        -- report what was actually paid over the route
        Cl.endRoute(L('complete', r.paid or r.pay or 0))
        return
    end
    route.stop = (Rail.int(r.stop) or route.stop) + 1
    local nextStop = route.route.stops[route.stop]
    placeMarkers()
    Cl.notify(L('paid_next', r.pay or 0, nextStop and nextStop.name or ''))
end

function Cl.deliverStop(n)
    if waitingAnswer or not Cl.route or Cl.route.stop ~= n then return end
    waitingAnswer = true
    CreateThread(function() deliver(n) end)
end

CreateThread(function()
    local group = Cl.newGroup()
    local prompt = Cl.newPrompt(Config.Keys.deliver, L('deliver'), group)
    Cl.onCleanup(function()
        Cl.deletePrompt(prompt)
        clearMarkers()
    end)

    while true do
        local sleep = 1000
        local r = Cl.route
        Cl.deliverReady = nil
        if r then
            sleep = 500
            local stop = r.route.stops[r.stop]
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local dx = stop and pos.x - stop.coords.x or 1e9
            local dy = stop and pos.y - stop.coords.y or 1e9
            if stop and dx * dx + dy * dy <= Config.Timings.stopPrompt ^ 2 and not Cl.incapacitated(ped) then
                sleep = 0
                local veh = Cl.vehicleForEntry(Cl.byId[r.trainId])
                if veh and GetEntitySpeed(veh) > Config.Timings.movingAtStop then
                    drawHint(L('bring_stop', stop.name))
                elseif not waitingAnswer and Cl.idle() and Cl.drivingNow then
                    -- in the driver seat the Deliver prompt joins the locomotive's prompt group
                    Cl.deliverReady = r.stop
                elseif not waitingAnswer and Cl.idle() then
                    Cl.showGroup(group, stop.name)
                    if Cl.promptPressed(prompt) then Cl.deliverStop(r.stop) end
                end
            end
        end
        Wait(sleep)
    end
end)
