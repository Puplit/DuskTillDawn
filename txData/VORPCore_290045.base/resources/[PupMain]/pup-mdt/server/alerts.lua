-- pup-mdt | law alerts (server memory only), alert commands, radius alerts

Alerts = { list = {}, responders = {}, nextId = 0, cmdCooldown = {}, clientCooldown = {}, radiusId = 0, radiusCooldown = {} }

local A = Config.Alerts
local R = Config.RadiusAlerts

local function xyz(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return nil end
    local x, y, z = tonumber(c.x or c[1]), tonumber(c.y or c[2]), tonumber(c.z or c[3])
    if not x or not y then return nil end
    return { x = x, y = y, z = z or 0.0 }
end

local function commandMessage(text)
    for _, c in ipairs(A.commands) do if c.message == text then return true end end
    return false
end

local function regionMatch(src, region)
    if region == nil or region == '' then return true end
    local r = Duty.region(src)
    if type(region) == 'table' then
        for _, x in ipairs(region) do if x == r then return true end end
        return false
    end
    return r == region
end

local function recipients(region)
    local out = {}
    for _, src in ipairs(Duty.lawmen()) do
        if regionMatch(src, region) then out[#out + 1] = src end
    end
    return out
end

-- every player holding a law job (on duty or not) plus an optional extra id
local function lawJobPlayers()
    local out = {}
    for _, s in ipairs(GetPlayers()) do
        local a = MDT.player(s)
        if a and a.isLaw then out[#out + 1] = a.src end
    end
    return out
end

local function publicAlert(al)
    return {
        id = al.id, text = al.text, title = al.text, message = al.text, location = al.location,
        sender = al.sender, senderId = al.senderId, timestamp = al.created, coords = al.coords,
        persistent = al.persistent, isCommand = al.isCommand, locked = al.locked, lockedBy = al.lockedBy, priority = 'high',
    }
end

-- create an alert; forcedSource false = anonymous, nil = the triggering player
function Alerts.create(coords, text, persistent, forcedSource, location, region, triggering)
    if not A.enabled then return false end
    text = MDT.str(text, A.maxTextLength)
    if text == '' then return false end
    local senderSrc
    if forcedSource == false then senderSrc = nil
    elseif forcedSource == nil then senderSrc = tonumber(triggering)
    else senderSrc = tonumber(forcedSource) end
    if senderSrc and not MDT.online(senderSrc) then senderSrc = nil end
    local sender = 'System'
    local senderRank
    if senderSrc then
        local a = MDT.player(senderSrc)
        if a then sender = a.name; senderRank = a.isLaw and Perms.rankName(a.job, a.grade) or nil end
    end
    local c = xyz(coords)
    if not c and senderSrc then
        local p = MDT.coords(senderSrc)
        if p then c = { x = p.x, y = p.y, z = p.z } end
    end
    c = c or { x = 0.0, y = 0.0, z = 0.0 }
    location = MDT.str(location, 100)
    if location == '' then location = PupMdtZones.nameFromCoords(c) end
    Alerts.nextId = Alerts.nextId + 1
    local al = {
        id = tostring(Alerts.nextId), text = text, created = os.time(), sender = sender, senderId = senderSrc,
        senderRank = senderRank, persistent = persistent == true, location = location, coords = c,
        isCommand = commandMessage(text), locked = false, lockedBy = nil, region = region,
    }
    Alerts.list[al.id] = al
    Alerts.responders[al.id] = {}
    Cache.clear('dashboard')
    MDT.log('alerts', 'ALERT CREATED', ('%s at %s (by %s)'):format(text, location, sender), 'orange')
    MDT.logAlert(al)
    local msg = publicAlert(al)
    for _, src in ipairs(recipients(region)) do TriggerClientEvent('pup-mdt:client:alert', src, msg) end
    if al.isCommand and senderSrc then TriggerClientEvent('pup-mdt:client:alertSender', senderSrc, al.id, 'sent') end
    return true, al.id
end

local function removeAlert(id, reason)
    local al = Alerts.list[id]
    if not al then return false end
    Alerts.list[id] = nil
    Alerts.responders[id] = nil
    Cache.clear('dashboard')
    local seen = {}
    for _, src in ipairs(lawJobPlayers()) do
        seen[src] = true
        TriggerClientEvent('pup-mdt:client:alertRemove', src, id, reason)
    end
    if al.senderId and MDT.online(al.senderId) then
        if not seen[al.senderId] then TriggerClientEvent('pup-mdt:client:alertRemove', al.senderId, id, reason) end
        TriggerClientEvent('pup-mdt:client:alertSender', al.senderId, id, 'cleared')
    end
    return true, al
end

-- alerts a viewer may see: those created since they clocked in
function Alerts.forViewer(src)
    local s = Duty.state[src]
    local since = s and s.since or os.time()
    local out = {}
    for _, al in pairs(Alerts.list) do
        if al.created >= since and regionMatch(src, al.region) then out[#out + 1] = publicAlert(al) end
    end
    table.sort(out, function(x, y) return x.timestamp > y.timestamp end)
    return out
end

local function responderList(id)
    local out = {}
    for _, r in pairs(Alerts.responders[id] or {}) do out[#out + 1] = r end
    table.sort(out, function(x, y) return x.timestamp < y.timestamp end)
    return out
end

local function broadcastResponders(id)
    local list = responderList(id)
    for _, src in ipairs(Duty.lawmen()) do TriggerClientEvent('pup-mdt:client:alertResponses', src, id, list) end
end

CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, al in pairs(Alerts.list) do
            if not al.persistent and now - al.created >= A.timer then
                removeAlert(id, 'expired')
                MDT.log('alerts', 'ALERT EXPIRED', al.text, 'grey')
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, list in pairs(Alerts.responders) do
        if list[src] then list[src] = nil; broadcastResponders(id) end
    end
end)

---------------------------------------------------------------------------
-- Screen requests
---------------------------------------------------------------------------
MDT.rpc('respondToExistingAlert', { law = true, duty = true }, function(actor, p)
    local id = MDT.str(p.alertId, 20)
    local al = Alerts.list[id]
    if not al then return { success = false, message = L('alert_not_found') } end
    if al.locked and al.lockedBy ~= actor.name then return { success = false, message = L('alert_locked_by', al.lockedBy or '?') } end
    local list = Alerts.responders[id]
    if list[actor.src] then return { success = true, message = L('alert_already_responding') } end
    list[actor.src] = { serverId = actor.src, playerName = actor.name, rank = Perms.rankName(actor.job, actor.grade), department = actor.jobLabel, timestamp = os.time() }
    if al.isCommand and al.senderId and MDT.online(al.senderId) and al.senderId ~= actor.src then
        TriggerClientEvent('pup-mdt:client:alertSender', al.senderId, id, 'help')
        MDT.notify(al.senderId, L('alert_help_coming'), 6000)
    end
    broadcastResponders(id)
    TriggerClientEvent('pup-mdt:client:alertRoute', actor.src, id, al.coords)
    return { success = true, message = L('alert_responding') }
end)

MDT.rpc('leaveAlert', { law = true }, function(actor, p)
    local id = MDT.str(p.alertId, 20)
    local list = Alerts.responders[id]
    if not list or not list[actor.src] then return { success = false, message = L('alert_not_responding') } end
    list[actor.src] = nil
    broadcastResponders(id)
    return { success = true, message = L('alert_left') }
end)

MDT.rpc('getAlertResponseCounts', { law = true, duty = true, deny = { success = false, responseCounts = {} } }, function(_, p)
    local out = {}
    for _, id in ipairs(MDT.list(p.alertIds, 50, 20)) do
        if Alerts.list[id] then
            local list = responderList(id)
            out[id] = { count = #list, responses = list }
        end
    end
    return { success = true, responseCounts = out }
end)

MDT.rpc('toggleAlertLock', { law = true, duty = true }, function(actor, p)
    local id = MDT.str(p.alertId, 20)
    local al = Alerts.list[id]
    if not al then return { success = false, message = L('alert_not_found') } end
    if al.locked then
        if al.lockedBy ~= actor.name and not MDT.can(actor, 'createlawmen') then
            return { success = false, message = L('alert_locked_by', al.lockedBy or '?') }
        end
        al.locked, al.lockedBy = false, nil
    else
        al.locked, al.lockedBy = true, actor.name
    end
    MDT.log('alerts', al.locked and 'Alert locked' or 'Alert unlocked', ('%s: %s'):format(actor.name, al.text), 'grey')
    for _, src in ipairs(Duty.lawmen()) do TriggerClientEvent('pup-mdt:client:alertLock', src, id, al.locked, al.lockedBy) end
    return { success = true }
end)

MDT.rpc('removePoliceAlert', { law = true, duty = true }, function(actor, p)
    local id = MDT.str(p.alertId, 20)
    local al = Alerts.list[id]
    if not al then return { success = false, message = L('alert_not_found') } end
    if al.locked and al.lockedBy ~= actor.name and not MDT.can(actor, 'createlawmen') then
        return { success = false, message = L('alert_locked_by', al.lockedBy or '?') }
    end
    removeAlert(id, 'deleted')
    MDT.log('alerts', 'ALERT DELETED', ('%s deleted: %s'):format(actor.name, al.text), 'red')
    if al.senderId and al.senderId ~= actor.src and MDT.online(al.senderId) then
        MDT.notify(al.senderId, L('alert_cancelled_by_law'), 5000)
    end
    return { success = true, message = L('alert_removed') }
end)

---------------------------------------------------------------------------
-- Alert commands (text, persistence and coordinates come from the server)
---------------------------------------------------------------------------
for _, c in ipairs(A.commands) do
    RegisterCommand(c.command, function(src)
        if src <= 0 then return end
        local a = MDT.player(src)
        if not a then return end
        if c.lawOnly and not (a.isLaw and Duty.isOn(src)) then return MDT.notify(src, L('must_be_onduty_lawman'), 4000) end
        local key = src .. ':' .. c.message
        local last = Alerts.cmdCooldown[key]
        if c.cooldown > 0 and last and os.time() - last < c.cooldown - 2 then
            return MDT.notify(src, L('cl_alert_spam', c.cooldown - (os.time() - last)), 4000)
        end
        Alerts.cmdCooldown[key] = os.time()
        if #Duty.lawmen() == 0 then return MDT.notify(src, L('alert_no_lawmen'), 5000) end
        local p = MDT.coords(src)
        Alerts.create(p and { x = p.x, y = p.y, z = p.z } or nil, c.message, c.persistent, src, nil, nil, src)
        MDT.notify(src, L('alert_sent'), 4000)
    end, false)
end

RegisterCommand(A.cancelCommand, function(src)
    if src <= 0 then return end
    for id, al in pairs(Alerts.list) do
        if al.isCommand and al.senderId == src then
            removeAlert(id, 'cancelled')
            return MDT.notify(src, L('alert_cancelled'), 4000)
        end
    end
    MDT.notify(src, L('alert_none_to_cancel'), 4000)
end, false)

AddEventHandler('playerDropped', function()
    local src = source
    for key in pairs(Alerts.cmdCooldown) do
        if key:match('^(%d+):') == tostring(src) then Alerts.cmdCooldown[key] = nil end
    end
end)

-- client exports SendPoliceAlert / SendPoliceAlertFromClient
RegisterNetEvent('pup-mdt:server:clientAlert', function(coords, text, persistent)
    local src = source
    if not Duty.isLawOnDuty(src) then return end
    local last = Alerts.clientCooldown[src]
    if last and os.time() - last < A.clientExportCooldown then return end
    Alerts.clientCooldown[src] = os.time()
    local c = xyz(coords)
    local p = MDT.coords(src)
    if not c or not p or MDT.dist(c, p) > A.clientExportMaxDistance then c = p and { x = p.x, y = p.y, z = p.z } or nil end
    Alerts.create(c, text, persistent == true and not commandMessage(MDT.str(text, A.maxTextLength)), src, nil, nil, src)
end)

---------------------------------------------------------------------------
-- Radius alerts
---------------------------------------------------------------------------
function Alerts.radius(coords, opts)
    if not A.enabled or not R.enabled then return false end
    opts = type(opts) == 'table' and opts or {}
    local chance = tonumber(opts.chance) or R.exportChance
    if math.random(1, 100) > chance then return false end
    local c = xyz(coords)
    if not c then return false end
    Alerts.radiusId = Alerts.radiusId + 1
    local zone = PupMdtZones.nameFromCoords(c)
    local data = {
        id = Alerts.radiusId, coords = c, radius = tonumber(opts.radius) or R.radius,
        label = MDT.str(opts.label, 60) ~= '' and MDT.str(opts.label, 60) or R.label,
        duration = tonumber(opts.duration) or R.duration, colour = R.colour, sprite = R.sprite,
        notifyText = R.notify and (R.notifyText .. ' in ' .. zone) or nil, notifyMs = R.notifyMs,
    }
    for _, src in ipairs(Duty.lawmen()) do TriggerClientEvent('pup-mdt:client:radiusAlert', src, data) end
    return true
end

if R.enabled and R.testEnabled then
    RegisterCommand(R.testCommand, function(src)
        if src <= 0 then return end
        if not IsPlayerAceAllowed(src, 'command.' .. R.testCommand) then return end
        if not Duty.isLawOnDuty(src) then return MDT.notify(src, L('must_be_onduty_lawman'), 4000) end
        local last = Alerts.radiusCooldown[src]
        if last and os.time() - last < R.testCooldown then return MDT.notify(src, L('cl_alert_spam', R.testCooldown - (os.time() - last)), 4000) end
        Alerts.radiusCooldown[src] = os.time()
        local p = MDT.coords(src)
        if p then Alerts.radius(p, { chance = 100 }) end
    end, false)
end

if R.enabled then
    RegisterCommand(R.clearCommand, function(src)
        if src <= 0 then return end
        if not Duty.isLawOnDuty(src) then return MDT.notify(src, L('must_be_onduty_lawman'), 4000) end
        for _, s in ipairs(Duty.lawmen()) do TriggerClientEvent('pup-mdt:client:radiusClear', s) end
        MDT.notify(src, L('drug_alerts_cleared'), 4000)
    end, false)
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
-- an export call carries no reliable "triggering player", so nil means no sender
exports('SendPoliceAlert', function(coords, text, persistent, forcedSource, location, region)
    local ok = Alerts.create(coords, text, persistent, forcedSource, location, region, nil)
    return ok == true
end)

exports('SendDetailedAlert', function(data)
    data = type(data) == 'table' and data or {}
    Alerts.create(data.coords, data.text, data.persistent, data.source, data.location, data.region, nil)
    return true
end)

exports('SendEmergencyAlert', function(coords, text, forcedSource, location)
    Alerts.create(coords, 'EMERGENCY: ' .. tostring(text or ''), true, forcedSource, location, nil, nil)
    return true
end)

exports('SendBackupAlert', function(coords, text, forcedSource, location)
    Alerts.create(coords, 'BACKUP NEEDED: ' .. tostring(text or ''), true, forcedSource, location, nil, nil)
    return true
end)

exports('SendPoliceAlertFromClient', function(src, coords, text, persistent, location)
    local ok = Alerts.create(coords, text, persistent, src, location, nil, src)
    return ok == true
end)

exports('SendRadiusAlert', function(coords, opts) return Alerts.radius(coords, opts) end)
exports('IsAlertSystemEnabled', function() return A.enabled == true end)
exports('GetAlertConfig', function() return A end)
exports('GetAlertResponses', function(id) return responderList(tostring(id)) end)
exports('ZoneNameFromCoords', function(coords) return PupMdtZones.nameFromCoords(coords) end)
