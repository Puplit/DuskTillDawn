-- pup-mdt client | law alerts: blips, expiry, routes, sender lines, radius alerts, counsel requests

MdtC = MdtC or {}

local alerts = {}      -- id -> { data, blip, expiresAt }
local order = {}       -- ids, oldest first
local unseen = false   -- an alert arrived while the MDT was closed
local senderLines = nil -- { hint, main, untilAt }
local routeAlert = nil -- alert id being responded to

local ALERT_MODIFIER = 0x6F85C3CE

local function key(id) return tostring(id) end

local function list()
    local out = {}
    for i = #order, 1, -1 do
        local a = alerts[order[i]]
        if a then out[#out + 1] = a.data end
    end
    return out
end

function MdtC.pushAlerts()
    if MdtC.mdtOpen then MdtC.send({ action = 'updatePoliceAlerts', alerts = list() }) end
end

local function dropFromOrder(k)
    for i = #order, 1, -1 do
        if order[i] == k then table.remove(order, i) end
    end
end

-- remove one alert locally; tellPage pushes the removal to an open page
function MdtC.removeAlertLocal(id, tellPage)
    local k = key(id)
    local a = alerts[k]
    if not a then return end
    MdtC.removeBlip(a.blip)
    alerts[k] = nil
    dropFromOrder(k)
    if routeAlert == k then
        routeAlert = nil
        MdtC.clearRoute('alert')
    end
    if tellPage ~= false and MdtC.mdtOpen then MdtC.send({ action = 'removeAlert', alertId = id }) end
end

function MdtC.clearAllAlerts()
    for k, a in pairs(alerts) do MdtC.removeBlip(a.blip) alerts[k] = nil end
    order = {}
    unseen = false
    if routeAlert then MdtC.clearRoute('alert') routeAlert = nil end
    if MdtC.clearRadius then MdtC.clearRadius() end
    if MdtC.mdtOpen then MdtC.send({ action = 'clearAllAlerts' }) end
end

local function makeBlip(d)
    local x, y, z = MdtC.xyzh(d.coords)
    if not x then return nil end
    local cfg = Config.Alerts.blip or {}
    local b = MdtC.blip(x, y, z, cfg.sprite or 2119977580, cfg.scale or 0.2, d.text or d.title)
    if not b or b == 0 then b = MdtC.blip(x, y, z, 'blip_ambient_law', cfg.scale or 0.2, d.text or d.title) end
    MdtC.blipModifier(b, ALERT_MODIFIER)
    return b
end

RegisterNetEvent('pup-mdt:client:alert', function(d)
    if type(d) ~= 'table' or d.id == nil then return end
    if Config.Alerts.enabled == false then return end
    if not MdtC.onDuty or MdtC.isLawyer then return end
    local k = key(d.id)
    if alerts[k] then MdtC.removeAlertLocal(d.id, false) end
    -- keep at most maxClient alerts; tell the page about the one dropped
    local max = math.max(1, tonumber(Config.Alerts.maxClient) or 10)
    while #order >= max do
        local oldest = order[1]
        local a = alerts[oldest]
        MdtC.removeAlertLocal(a and a.data.id or oldest, true)
        if order[1] == oldest then table.remove(order, 1) end
    end
    local timer = tonumber(Config.Alerts.timer) or 900
    alerts[k] = { data = d, blip = makeBlip(d), expiresAt = (not d.persistent) and (GetGameTimer() + timer * 1000) or nil }
    order[#order + 1] = k
    MdtC.notify(('%s: %s'):format(tostring(d.text or d.title or ''), L('alert_check_alerts')), tonumber(Config.Alerts.popupMs) or 7000)
    if not MdtC.mdtOpen then unseen = true end
    MdtC.pushAlerts()
end)

RegisterNetEvent('pup-mdt:client:alertRemove', function(id)
    MdtC.removeAlertLocal(id, true)
end)

RegisterNetEvent('pup-mdt:client:clearAlerts', function()
    MdtC.clearAllAlerts()
end)

RegisterNetEvent('pup-mdt:client:alertResponses', function(id, responders)
    local out = {}
    for _, r in ipairs(responders or {}) do
        out[#out + 1] = { name = r.playerName or r.name, rank = r.rank, department = r.department, time = r.timestamp }
    end
    local a = alerts[key(id)]
    if a then a.data.responders = out end
    if MdtC.mdtOpen then MdtC.send({ action = 'updateAlertResponses', alertId = id, count = #out, responders = out }) end
end)

RegisterNetEvent('pup-mdt:client:alertLock', function(id, locked, lockedBy)
    local a = alerts[key(id)]
    if a then a.data.locked = locked == true; a.data.lockedBy = lockedBy end
    if MdtC.mdtOpen then MdtC.send({ action = 'updateAlertLock', alertId = id, locked = locked == true, lockedBy = lockedBy }) end
end)

-- the server accepted our response: red route and arrival check
RegisterNetEvent('pup-mdt:client:alertRoute', function(id, coords)
    local x, y, z = MdtC.xyzh(coords)
    if not x then return end
    local k = key(id)
    if alerts[k] and not (alerts[k].blip and DoesBlipExist(alerts[k].blip)) then alerts[k].blip = makeBlip(alerts[k].data) end
    MdtC.setRoute('alert', x, y, z, 'COLOR_RED')
    routeAlert = k
    MdtC.notify(L('alert_responding'), 2000)
    CreateThread(function()
        while routeAlert == k do
            Wait(1000)
            if not alerts[k] then
                if routeAlert == k then routeAlert = nil MdtC.clearRoute('alert') end
                return
            end
            local c = GetEntityCoords(PlayerPedId())
            if #(c - vector3(x, y, z)) <= 5.0 then
                MdtC.notify(L('alert_arrived'), 3000)
                if routeAlert == k then routeAlert = nil MdtC.clearRoute('alert') end
                return
            end
        end
    end)
end)

-- leave keeps the alert and its blip; only our route goes
function MdtC.leaveAlertLocal(id)
    if routeAlert == key(id) then
        routeAlert = nil
        MdtC.clearRoute('alert')
    end
    MdtC.notify(L('alert_left'), 2000)
end

-- temporary "show on map" blip
function MdtC.locateAlert(id, coords)
    local a = alerts[key(id)]
    local x, y, z = MdtC.xyzh(coords or (a and a.data.coords))
    if not x then return false end
    local b = MdtC.blip(x, y, z, 'blip_ambient_law', 0.3, a and (a.data.text or a.data.title) or nil)
    SetTimeout(30000, function() MdtC.removeBlip(b) end)
    return true
end

-- expiry of non-persistent alerts
CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for k, a in pairs(alerts) do
            if a.expiresAt and now >= a.expiresAt then MdtC.removeAlertLocal(a.data.id or k, true) end
        end
    end
end)

function MdtC.ackReminders()
    unseen = false
    MdtC.counselUnseen = false
end

---------------------------------------------------------------------------
-- sender's own lines (/alertlaw etc.)
---------------------------------------------------------------------------
RegisterNetEvent('pup-mdt:client:alertSender', function(_, state)
    if state == 'sent' then
        senderLines = { hint = L('alert_cancel_hint'), main = L('alert_was_sent'), untilAt = GetGameTimer() + 120000 }
    elseif state == 'help' then
        MdtC.notify(L('alert_help_coming'), 4000)
        senderLines = { main = L('alert_help_coming'), untilAt = GetGameTimer() + 10000 }
    else
        senderLines = nil
    end
end)

-- on-screen lines, top-left in the western font: the sender's red hint over a larger line,
-- then the lawman's unread reminders in red
local TX <const>, TY <const> = 0.15, 0.13
CreateThread(function()
    while true do
        local busy = false
        local y = TY
        if senderLines then
            busy = true
            if GetGameTimer() > senderLines.untilAt then senderLines = nil
            else
                if senderLines.hint then MdtC.drawText('~e~' .. senderLines.hint, TX, y, 0.3) end
                MdtC.drawText(senderLines.main, TX, y + 0.03, 0.5, 0.3)
                y = y + 0.075
            end
        end
        if not MdtC.mdtOpen then
            if unseen and next(alerts) then
                busy = true
                MdtC.drawText('~e~' .. L('alert_unread_line1'), TX, y, 0.3)
                MdtC.drawText('~e~' .. L('alert_unread_line2'), TX, y + 0.03, 0.3)
                y = y + 0.065
            end
            if MdtC.counselUnseen then
                busy = true
                MdtC.drawText('~e~' .. L('counsel_reminder'), TX, y, 0.3)
            end
        end
        Wait(busy and 0 or 500)
    end
end)

---------------------------------------------------------------------------
-- radius ("drug") alerts
---------------------------------------------------------------------------
local radius = {}

function MdtC.clearRadius()
    for _, r in pairs(radius) do MdtC.removeBlip(r.area) MdtC.removeBlip(r.centre) end
    radius = {}
end

RegisterNetEvent('pup-mdt:client:radiusAlert', function(d)
    if type(d) ~= 'table' then return end
    local x, y, z = MdtC.xyzh(d.coords)
    if not x then return end
    local id = d.id or GetGameTimer()
    local area = MdtC.radiusBlip(x, y, z, tonumber(d.radius) or 80.0)
    MdtC.blipModifier(area, d.colour or 'BLIP_MODIFIER_MP_COLOR_2')
    local centre = MdtC.blip(x, y, z, d.sprite or 'blip_attention', 0.2, d.label)
    radius[id] = { area = area, centre = centre }
    if d.notifyText then
        MdtC.notify(('%s - %s'):format(d.notifyText, MdtC.zoneName({ x = x, y = y, z = z })), tonumber(d.notifyMs) or 8000)
    end
    SetTimeout((tonumber(d.duration) or 120) * 1000, function()
        local r = radius[id]
        if r then MdtC.removeBlip(r.area) MdtC.removeBlip(r.centre) radius[id] = nil end
    end)
end)

RegisterNetEvent('pup-mdt:client:radiusClear', function() MdtC.clearRadius() end)

---------------------------------------------------------------------------
-- counsel requests (attorneys)
---------------------------------------------------------------------------
local counsel = {} -- id -> blip
local counselRouteId = nil

function MdtC.clearCounsel()
    for id, b in pairs(counsel) do MdtC.removeBlip(b) counsel[id] = nil end
    MdtC.counselUnseen = false
    if counselRouteId then counselRouteId = nil MdtC.clearRoute('counsel') end
end

RegisterNetEvent('pup-mdt:client:counselAlert', function(req)
    if type(req) ~= 'table' or req.id == nil then return end
    local x, y, z = MdtC.xyzh(req.coords)
    if not x then return end
    if counsel[req.id] then MdtC.removeBlip(counsel[req.id]) end
    local legal = Config.Legal and Config.Legal.counsel or {}
    local b = nil
    if legal.blip ~= false then
        local name = L('ui_counsel_requests')
        if name == 'ui_counsel_requests' then name = 'Counsel Requests' end
        b = MdtC.blip(x, y, z, (Config.Alerts.blip and Config.Alerts.blip.sprite) or 2119977580, (Config.Alerts.blip and Config.Alerts.blip.scale) or 0.2, name)
        MdtC.blipModifier(b, legal.blipColour or 'BLIP_MODIFIER_MP_COLOR_1')
    end
    counsel[req.id] = b
    MdtC.counselUnseen = not MdtC.mdtOpen
    MdtC.notify(L('counsel_reminder'), 6000)
    local id = req.id
    SetTimeout((tonumber(req.expires) or tonumber(legal.blipSeconds) or 300) * 1000, function()
        if counsel[id] == b then MdtC.removeBlip(b) counsel[id] = nil end
    end)
end)

RegisterNetEvent('pup-mdt:client:counselCancel', function(id)
    if counsel[id] then MdtC.removeBlip(counsel[id]) counsel[id] = nil end
    if counselRouteId == id then counselRouteId = nil MdtC.clearRoute('counsel') end
end)

RegisterNetEvent('pup-mdt:client:counselRoute', function(id, coords)
    local x, y, z = MdtC.xyzh(coords)
    if not x then return end
    local legal = Config.Legal and Config.Legal.counsel or {}
    MdtC.setRoute('counsel', x, y, z, legal.routeColour or 'COLOR_BLUE')
    counselRouteId = id
    local arrive = tonumber(legal.arriveMetres) or 15.0
    CreateThread(function()
        while counselRouteId == id do
            Wait(2000)
            local c = GetEntityCoords(PlayerPedId())
            if #(c - vector3(x, y, z)) <= arrive then
                if counsel[id] then MdtC.removeBlip(counsel[id]) counsel[id] = nil end
                counselRouteId = nil
                MdtC.clearRoute('counsel')
                MdtC.notify(L('cl_counsel_arrived'), 4000)
                return
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- client exports: alerts raised by other client scripts
---------------------------------------------------------------------------
local function clientAlert(coords, text, persistent)
    local x, y, z = MdtC.xyzh(coords)
    local c = x and { x = x, y = y, z = z } or MdtC.myCoords()
    TriggerServerEvent('pup-mdt:server:clientAlert', c, tostring(text or ''):sub(1, 200), persistent == true)
    return true
end
exports('SendPoliceAlertFromClient', clientAlert)
exports('SendPoliceAlert', clientAlert)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, a in pairs(alerts) do MdtC.removeBlip(a.blip) end
    for _, b in pairs(counsel) do MdtC.removeBlip(b) end
    MdtC.clearRadius()
    if MdtC.routeOwner() then ClearGpsMultiRoute() end
end)
