-- pup-medical | job alerts: sending, the call list, accept/deny, arrival,
-- cancel, the first-call clock and the exports other resources may use

Alerts = {}

local pool        = {}   -- [typeKey] = { [id] = { id, player, coords, zone, time, netid, created } }
local callerOf    = {}   -- [src] = { [typeKey] = id }  pooled alerts a player sent
local links       = {}   -- [id] = { responder, caller, typeKey, busy }
local busy        = {}   -- [src] = number of open calls that keep them busy
local lastSend    = {}   -- [src] = { [typeKey] = os.time() }
local acceptCount = {}   -- [src] = accepts this session
local incomingOn  = {}   -- [src] = true while their client shows "someone is asking"
local firstDown   = {}   -- [src] = os.time() of the first send while down
local safeRespawn = {}   -- [src] = true when nobody could answer a downed caller

local nextId = 1000000

for _, key in ipairs(AlertTypeKeys()) do pool[key] = {} end

local function cfgA() return Config.Alerts or {} end

local function newId()
    repeat nextId = nextId + 1 until not links[nextId]
    return nextId
end

---------------------------------------------------------------------------
-- Respawn helpers
---------------------------------------------------------------------------
local function freeWindow()
    local fr = cfgA().freeRespawn
    if type(fr) ~= 'table' or not fr.enabled then return nil end
    return (tonumber(fr.waitMinutes) or 10) * 60 - 30
end

function Alerts.SafeToRespawn(src)
    if safeRespawn[src] then return true end
    local window = freeWindow()
    if not window then return false end
    local now = os.time()
    if firstDown[src] and now - firstDown[src] >= window then return true end
    for key, id in pairs(callerOf[src] or {}) do
        local a = pool[key] and pool[key][id]
        if a and now - a.created >= window then return true end
    end
    return false
end

function Alerts.ClearRespawnState(src)
    safeRespawn[src] = nil
    firstDown[src] = nil
end

local function noteSendClock(src, dead)
    if dead then
        if not firstDown[src] then firstDown[src] = os.time() end
    else
        firstDown[src] = nil
    end
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function isDeadNow(src)
    local ctx = GetCtx(src)
    return ctx ~= nil and ctx.dead
end

-- may this player answer calls of this type right now?
local function canRespond(ctx, def)
    if not ctx or not InList(def.jobs, ctx.job) then return false end
    if cfgA().requireOnDuty and not IsOnDuty(ctx.src, ctx.job) then return false end
    return true
end

local function setCallerState(src, state, typeKey, extra)
    TriggerClientEvent('pup-medical:client:callerState', src, state, typeKey, extra)
end

local function freeBusy(src, link)
    if not (link and link.busy) then return end
    local n = (busy[src] or 0) - 1
    busy[src] = n > 0 and n or nil
end

local function vec(c)
    return { x = c.x, y = c.y, z = c.z }
end

-- removes a pooled alert; returns it
local function unpool(typeKey, id)
    local t = pool[typeKey]
    local a = t and t[id]
    if not a then return nil end
    t[id] = nil
    local mine = callerOf[a.player]
    if mine and mine[typeKey] == id then
        mine[typeKey] = nil
        if next(mine) == nil then callerOf[a.player] = nil end
    end
    return a
end

-- types whose jobs include this job
local function typesForJob(job)
    local out = {}
    for _, key in ipairs(AlertTypeKeys()) do
        local def = AlertType(key)
        if def and InList(def.jobs, job) then out[#out + 1] = key end
    end
    return out
end

local function hasPooledFor(job)
    for _, key in ipairs(typesForJob(job)) do
        if next(pool[key] or {}) ~= nil then return true end
    end
    return false
end

-- clears "someone is asking for help" for everyone with nothing left to answer
local function refreshIncoming()
    for src in pairs(incomingOn) do
        local ctx = GetCtx(src)
        if not ctx or not hasPooledFor(ctx.job) then
            incomingOn[src] = nil
            if Online(src) then TriggerClientEvent('pup-medical:client:incoming', src, false) end
        end
    end
end

-- "help is on the way from %"
local function formatNotify(text, zone)
    text = tostring(text or '')
    local known = type(zone) == 'string' and zone ~= '' and zone ~= UNKNOWN_ZONE and zone ~= 'Unknown'
    if text:find('%', 1, true) then
        if known then
            return (text:gsub('%%', (zone:gsub('%%', '%%%%'))))
        end
        text = text:gsub('%s*[Ff][Rr][Oo][Mm]%s*%%', ''):gsub('%%', '')
        return (text:gsub('%s+$', ''))
    end
    if known then return text .. L('fromZone', zone) end
    return text
end

-- notices to every job holder who could answer
local function notifyResponders(def, callerSrc)
    for _, p in ipairs(OnlinePlayers()) do
        if p ~= callerSrc and not busy[p] then
            local pc = GetCtx(p)
            if canRespond(pc, def) then
                TipRight(p, def.notifyJob or '', 8000)
                incomingOn[p] = true
                TriggerClientEvent('pup-medical:client:incoming', p, true)
            end
        end
    end
end

-- builds and pools an alert for a player at their server-side position
local function poolAlert(src, typeKey, zone)
    local pos = Pos(src)
    if not pos then return nil end
    local old = callerOf[src] and callerOf[src][typeKey]
    if old then unpool(typeKey, old) end

    local ped = GetPlayerPed(src)
    local netid = 0
    if ped and ped ~= 0 and DoesEntityExist(ped) then netid = NetworkGetNetworkIdFromEntity(ped) or 0 end

    local id = newId()
    local alert = {
        id      = id,
        player  = src,
        coords  = pos,
        zone    = zone,
        time    = os.date('%H:%M:%S'),
        netid   = netid,
        created = os.time(),
    }
    pool[typeKey] = pool[typeKey] or {}
    pool[typeKey][id] = alert
    callerOf[src] = callerOf[src] or {}
    callerOf[src][typeKey] = id
    return alert
end

---------------------------------------------------------------------------
-- Discord
---------------------------------------------------------------------------
local function alertHooks(typeKey, job, allJobs)
    local out, seen = {}, {}
    local function add(url) if url and not seen[url] then seen[url] = true; out[#out + 1] = url end end
    local base = Hook('alerts', typeKey, 'default') or Hook('alertDefault')
    if allJobs then
        add(base)
        local jobs = Hooks.alerts and Hooks.alerts[typeKey] and Hooks.alerts[typeKey].jobs
        if type(jobs) == 'table' then
            for j in pairs(jobs) do add(Hook('alerts', typeKey, 'jobs', j)) end
        end
    else
        add(Hook('alerts', typeKey, 'jobs', job) or base)
    end
    return out
end

local function logAccept(def, typeKey, responderCtx, callerSrc, zone)
    if not def.log then return end
    local ok, err = pcall(function()
        local embed = {
            title  = 'Call accepted',
            color  = Colors.green,
            fields = {
                PersonField('Responder', responderCtx),
                PersonField('Caller', GetCtx(callerSrc)),
                Field('Zone', zone),
                Field('Type', typeKey),
                Field('Accepts this session', acceptCount[responderCtx.src] or 0),
            },
        }
        for _, url in ipairs(alertHooks(typeKey, responderCtx.job, false)) do
            PostWebhook(url, embed, 'Job Alerts')
        end
    end)
    if not ok then Warn('accept log failed: ' .. tostring(err)) end
end

local function logCancel(def, typeKey, cancellerCtx, alert)
    if not def.log then return end
    local ok, err = pcall(function()
        local embed = {
            title  = 'Call cancelled',
            color  = Colors.orange,
            fields = {
                PersonField('Cancelled by', cancellerCtx),
                PersonField('Caller', GetCtx(alert.player)),
                Field('Zone', alert.zone),
                Field('Type', typeKey),
                Field('Reason', 'the player cancelled their own call'),
            },
        }
        for _, url in ipairs(alertHooks(typeKey, nil, true)) do
            PostWebhook(url, embed, 'Job Alerts')
        end
    end)
    if not ok then Warn('cancel log failed: ' .. tostring(err)) end
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:sendAlert', function(typeKey, zone)
    local src = source
    local def = AlertType(typeKey)
    if not def then return end
    if not RateOk(src, 'sendAlert', 1500) then return end

    local now = os.time()
    local mine = lastSend[src]
    if mine and mine[typeKey] and now - mine[typeKey] < ALERT_COOLDOWN - 1 then
        return TipRight(src, L('cooldown', ALERT_COOLDOWN), 8000)
    end

    zone = CleanZone(zone)
    local ctx = GetCtx(src)
    if not ctx or not ctx.job then return end
    if type(def.senderJobs) == 'table' and #def.senderJobs > 0 and not InList(def.senderJobs, ctx.job) then
        return TipRight(src, L('cantUseAlert'), 8000)
    end
    if def.deadCanUse == false and ctx.dead then
        return TipRight(src, L('deadCantUse'), 8000)
    end

    if cfgA().requireOnDuty then
        local found = false
        local seen = {}
        for _, p in ipairs(OnlinePlayers()) do
            if p ~= src or cfgA().countSelfAsResponder then
                local pc = GetCtx(p)
                if pc and InList(def.jobs, pc.job) then
                    local on = IsOnDuty(p, pc.job)
                    seen[#seen + 1] = ('%d:%s=%s'):format(p, pc.job, tostring(on))
                    if on then found = true break end
                end
            end
        end
        if not found then
            Debug('alerts', ('no responder for %s from %d; job holders: %s'):format(
                typeKey, src, #seen > 0 and table.concat(seen, ', ') or 'none'))
            noteSendClock(src, ctx.dead)
            if ctx.dead and cfgA().noDoctorsNoLoss then
                safeRespawn[src] = true
                setCallerState(src, 'nobody', typeKey, { free = true })
                return TipRight(src, L('noMedicsFree'), 8000)
            end
            setCallerState(src, 'nobody', typeKey, { free = false })
            return TipRight(src, L('nobodyOnDuty'), 8000)
        end
    end

    if type(def.stations) == 'table' and #def.stations > 0 then
        local pos = Pos(src)
        local reach = tonumber(def.stationDistance) or tonumber(def.promptDistance) or 6.0
        local near = false
        if pos then
            for _, st in ipairs(def.stations) do
                if st.coords and #(pos - st.coords) <= reach then near = true break end
            end
        end
        if not near then return TipRight(src, L('nearStation'), 8000) end
    end

    local alert = poolAlert(src, typeKey, zone)
    if not alert then return end
    lastSend[src] = lastSend[src] or {}
    lastSend[src][typeKey] = now
    noteSendClock(src, ctx.dead)
    safeRespawn[src] = nil

    setCallerState(src, 'waiting', typeKey, { dead = ctx.dead })
    TipRight(src, def.alertSent or '', 8000)
    notifyResponders(def, src)
    Debug('alerts', ('%s alert %d from %d in %s'):format(typeKey, alert.id, src, zone))
end)

---------------------------------------------------------------------------
-- Movement: "I moved"; the position is read from the server's ped
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:moved', function()
    local src = source
    if not RateOk(src, 'moved', 1000) then return end
    local pos = Pos(src)
    if not pos then return end
    for key, id in pairs(callerOf[src] or {}) do
        local a = pool[key] and pool[key][id]
        if a then a.coords = pos end
    end
    for id, link in pairs(links) do
        if link.caller == src and Online(link.responder) then
            TriggerClientEvent('pup-medical:client:targetMoved', link.responder, id, vec(pos))
        end
    end
end)

---------------------------------------------------------------------------
-- The call list
---------------------------------------------------------------------------
local function resolveType(arg, job)
    if type(arg) == 'string' and arg ~= '' then
        if AlertType(arg) then return arg end
        for _, key in ipairs(AlertTypeKeys()) do
            if InList(AlertType(key).jobs, arg) then return key end
        end
        return nil
    end
    for _, key in ipairs(AlertTypeKeys()) do
        if InList(AlertType(key).jobs, job) then return key end
    end
    return nil
end

RegisterNetEvent('pup-medical:server:openList', function(arg, afterBack)
    local src = source
    if not RateOk(src, 'openList', 800) then return end
    local ctx = GetCtx(src)
    if not ctx then return end
    if arg ~= nil and type(arg) ~= 'string' then return end

    local typeKey = resolveType(arg, ctx.job)
    local def = AlertType(typeKey)
    if not def then return TipRight(src, L('noAccess'), 8000) end
    if not InList(def.jobs, ctx.job) then return TipRight(src, L('noAccess'), 8000) end
    if cfgA().requireOnDuty and not IsOnDuty(src, ctx.job) then return TipRight(src, L('notOnDuty'), 8000) end

    local now = os.time()
    local list = {}
    for _, key in ipairs(typesForJob(ctx.job)) do
        for id, a in pairs(pool[key] or {}) do
            if Online(a.player) then
                list[#list + 1] = {
                    id = id, player = a.player, coords = vec(a.coords), time = a.time,
                    netid = a.netid, typeKey = key, dead = isDeadNow(a.player),
                    waited = now - a.created,
                }
            end
        end
    end
    if #list == 0 then
        incomingOn[src] = nil
        TriggerClientEvent('pup-medical:client:incoming', src, false)
        return TipRight(src, L(afterBack and 'noMoreCalls' or 'noCalls'), 8000)
    end
    TriggerClientEvent('pup-medical:client:alertList', src, list, typeKey)
end)

---------------------------------------------------------------------------
-- Accept / deny
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:accept', function(id, typeKey, zone)
    local src = source
    if not RateOk(src, 'decide', 1000) then return end
    id = tonumber(id)
    local def = AlertType(typeKey)
    if not id or not def then return end
    local alert = pool[typeKey] and pool[typeKey][id]
    if not alert then return TipRight(src, L('callGone'), 8000) end

    local ctx = GetCtx(src)
    if not canRespond(ctx, def) then return TipRight(src, L('notOnDuty'), 8000) end
    if Config.Switches.busyBlocksAccept and busy[src] then return TipRight(src, L('busyFinishFirst'), 8000) end

    local caller = alert.player
    if not Online(caller) then
        unpool(typeKey, id)
        refreshIncoming()
        return TipRight(src, L('callGone'), 8000)
    end
    zone = CleanZone(zone)

    setCallerState(caller, 'helpComing', typeKey)
    TipRight(caller, formatNotify(def.notifyPlayer, zone), 8000)

    local coords = Pos(caller) or alert.coords
    TriggerClientEvent('pup-medical:client:responding', src, {
        id = id, typeKey = typeKey, coords = vec(coords),
    })
    TipRight(src, L('accepted'), 8000)

    local link = { responder = src, caller = caller, typeKey = typeKey, busy = def.busyOnAccept == true }
    links[id] = link
    if link.busy then busy[src] = (busy[src] or 0) + 1 end
    if incomingOn[src] and link.busy then
        incomingOn[src] = nil
        TriggerClientEvent('pup-medical:client:incoming', src, false)
    end

    unpool(typeKey, id)
    CallPay.Start(id, alert, caller, ctx, typeKey, alert.zone)
    acceptCount[src] = (acceptCount[src] or 0) + 1
    logAccept(def, typeKey, ctx, caller, alert.zone)
    refreshIncoming()
end)

RegisterNetEvent('pup-medical:server:deny', function(id, typeKey)
    local src = source
    if not RateOk(src, 'decide', 1000) then return end
    id = tonumber(id)
    local def = AlertType(typeKey)
    if not id or not def then return end
    local ctx = GetCtx(src)
    if not ctx or not InList(def.jobs, ctx.job) then return end
    local alert = unpool(typeKey, id)
    if not alert then return end
    if Online(alert.player) then
        TipRight(alert.player, L('callRemoved'), 8000)
        setCallerState(alert.player, 'clear', typeKey)
    end
    refreshIncoming()
end)

---------------------------------------------------------------------------
-- Arrival: frees the responder; pay waits for the treatment
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:arrived', function(id, typeKey)
    local src = source
    if not RateOk(src, 'arrived', 1000) then return end
    id = tonumber(id)
    local def = AlertType(typeKey)
    if not id or not def then return end
    local ctx = GetCtx(src)
    if pool[typeKey] and pool[typeKey][id] and ctx and InList(def.jobs, ctx.job) then
        unpool(typeKey, id)
        refreshIncoming()
    end
    local link = links[id]
    if link and link.responder == src then
        links[id] = nil
        freeBusy(src, link)
        if Online(link.caller) then setCallerState(link.caller, 'clear', link.typeKey) end
    end
end)

---------------------------------------------------------------------------
-- A list row the client could not show
---------------------------------------------------------------------------
RegisterNetEvent('pup-medical:server:dropStale', function(id, typeKey)
    local src = source
    if not RateOk(src, 'dropStale', 500) then return end
    id = tonumber(id)
    local def = AlertType(typeKey)
    if not id or not def then return end
    local ctx = GetCtx(src)
    if pool[typeKey] and pool[typeKey][id] and ctx and InList(def.jobs, ctx.job) then
        local a = unpool(typeKey, id)
        if a and Online(a.player) then setCallerState(a.player, 'clear', typeKey) end
        refreshIncoming()
        return
    end
    local link = links[id]
    if link and link.responder == src then
        links[id] = nil
        CallPay.Void(id, 'dropped as stale')
        freeBusy(src, link)
        TriggerClientEvent('pup-medical:client:clearResponding', src, id)
        if Online(link.caller) then setCallerState(link.caller, 'clear', link.typeKey) end
    end
end)

---------------------------------------------------------------------------
-- Cancel (/calert, and automatically after a revive)
---------------------------------------------------------------------------
local function cancelFor(src, quiet)
    CallPay.VoidFor(src, 'cancelled')
    local ctx = GetCtx(src)
    local removedAny = false

    for key, id in pairs(callerOf[src] or {}) do
        local a = unpool(key, id)
        if a then
            removedAny = true
            local def = AlertType(key)
            if def then logCancel(def, key, ctx, a) end
        end
    end
    callerOf[src] = nil

    if not (ctx and ctx.dead) then Alerts.ClearRespawnState(src) end

    local unlinked = false
    for id, link in pairs(links) do
        if link.caller == src then
            links[id] = nil
            unlinked = true
            freeBusy(link.responder, link)
            if Online(link.responder) then
                TriggerClientEvent('pup-medical:client:clearResponding', link.responder, id)
                TipRight(link.responder, L('callRemoved'), 8000)
            end
        elseif link.responder == src then
            links[id] = nil
            unlinked = true
            freeBusy(src, link)
            if Online(link.caller) then
                setCallerState(link.caller, 'clear', link.typeKey)
                TipRight(link.caller, L('callRemoved'), 8000)
            end
        end
    end

    if removedAny then refreshIncoming() end
    setCallerState(src, 'clear', nil)
    if not quiet and (removedAny or unlinked) then TipRight(src, L('callRemoved'), 8000) end
end

RegisterNetEvent('pup-medical:server:cancel', function(quiet)
    local src = source
    if not RateOk(src, 'cancel', 1000) then return end
    cancelFor(src, quiet == true)
end)

---------------------------------------------------------------------------
-- Disconnect / character switch
---------------------------------------------------------------------------
OnPlayerLeft(function(src)
    local changed = false
    for key, id in pairs(callerOf[src] or {}) do
        if unpool(key, id) then changed = true end
    end
    callerOf[src] = nil
    for id, link in pairs(links) do
        if link.caller == src then
            links[id] = nil
            freeBusy(link.responder, link)
            if Online(link.responder) then
                TriggerClientEvent('pup-medical:client:clearResponding', link.responder, id)
                TipRight(link.responder, L('callRemoved'), 8000)
            end
        elseif link.responder == src then
            links[id] = nil
            if Online(link.caller) then
                setCallerState(link.caller, 'clear', link.typeKey)
                TipRight(link.caller, L('callRemoved'), 8000)
            end
        end
    end
    busy[src] = nil
    lastSend[src] = nil
    acceptCount[src] = nil
    incomingOn[src] = nil
    Alerts.ClearRespawnState(src)
    if changed then refreshIncoming() end
    if Online(src) then
        -- character switch: the new character starts clean
        setCallerState(src, 'clear', nil)
        TriggerClientEvent('pup-medical:client:clearResponding', src, nil)
        TriggerClientEvent('pup-medical:client:incoming', src, false)
    end
end)

-- after a revive (any kind): clears the downed state
function Alerts.OnRevived(src)
    Alerts.ClearRespawnState(src)
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
local function copyAlert(a)
    return { id = a.id, player = a.player, coords = a.coords, zone = a.zone, time = a.time, netid = a.netid, created = a.created }
end

local function copyPool(key)
    local out = {}
    for id, a in pairs(pool[key] or {}) do out[id] = copyAlert(a) end
    return out
end

exports('GetAlertNumbersForJob', function(job)
    local n = 0
    for _, key in ipairs(typesForJob(job)) do
        for _ in pairs(pool[key] or {}) do n = n + 1 end
    end
    return n
end)

exports('GetCloseRegion', function(job, coords, distance)
    local out = {}
    distance = tonumber(distance) or 0
    if type(coords) ~= 'vector3' then
        if type(coords) == 'table' and coords.x then
            coords = vector3(tonumber(coords.x) or 0, tonumber(coords.y) or 0, tonumber(coords.z) or 0)
        else
            return out
        end
    end
    for _, key in ipairs(typesForJob(job)) do
        for id, a in pairs(pool[key] or {}) do
            local d = #(a.coords - coords)
            if d <= distance then
                out[#out + 1] = { id = id, jobType = key, coords = a.coords, distance = d }
            end
        end
    end
    return out
end)

exports('GetCurrentAlertedJobs', function()
    local out, seen = {}, {}
    for _, key in ipairs(AlertTypeKeys()) do
        for _, job in ipairs(AlertType(key).jobs or {}) do
            if not seen[job] then seen[job] = true; out[#out + 1] = job end
        end
    end
    return out
end)

exports('GetCurrentAlertedJobsByIndex', function(typeKey)
    local def = AlertType(typeKey)
    if not def or type(def.jobs) ~= 'table' then return false end
    local out = {}
    for i, j in ipairs(def.jobs) do out[i] = j end
    return out
end)

exports('GetAllCurrentAlerts', function()
    local out = {}
    for _, key in ipairs(AlertTypeKeys()) do out[key] = copyPool(key) end
    return out
end)

exports('GetCurrentAlertByIndex', function(typeKey)
    if not AlertType(typeKey) then return false end
    return { [typeKey] = copyPool(typeKey) }
end)

local function finish(typeKey, src)
    src = tonumber(src)
    if not src or not AlertType(typeKey) then return false end
    local id = callerOf[src] and callerOf[src][typeKey]
    if not id or not unpool(typeKey, id) then return false end
    refreshIncoming()
    return true
end

exports('FinishAlert', function(typeKey, src) return finish(typeKey, src) end)
exports('RemoveAlert', function(src, typeKey) return finish(typeKey, src) end)

exports('InsertAlert', function(src, command)
    src = tonumber(src)
    if not src or type(command) ~= 'string' then return false end
    local ctx = GetCtx(src)
    if not ctx or not ctx.job then return false end

    local typeKey = nil
    for _, key in ipairs(AlertTypeKeys()) do
        if AlertType(key).command == command then typeKey = key break end
    end
    if not typeKey then
        local bare = command:gsub('[Aa][Ll][Ee][Rr][Tt]', ''):lower()
        for _, key in ipairs(AlertTypeKeys()) do
            if key:lower() == bare then typeKey = key break end
        end
    end
    if not typeKey then return false end

    local alert = poolAlert(src, typeKey, UNKNOWN_ZONE)
    if not alert then return false end
    -- responders are told about it too
    notifyResponders(AlertType(typeKey), src)
    return true
end)
