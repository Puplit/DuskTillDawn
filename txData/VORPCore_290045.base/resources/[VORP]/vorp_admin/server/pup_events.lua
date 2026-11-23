-- Modified by Puppet (Dusk Till Dawn), 2026
-- Events tab, server side. Everything goes through pup-events' exports, never its tables.

local PERM <const> = 'manage_events'

local CoreRef
local function core()
    if not CoreRef then
        local ok, c = pcall(function() return exports.vorp_core:GetCore() end)
        if ok then CoreRef = c end
    end
    return CoreRef
end

local function tell(src, msg, ms)
    local c = core()
    if c and c.NotifyRightTip then c.NotifyRightTip(src, msg, ms or 5000) end
end

local function eventsUp()
    return GetResourceState('pup-events') == 'started'
end

local function allowed(src)
    if not HasPermission then return false end
    return HasPermission(src, PERM) == true
end

local function logStaff(src, msg)
    print(('^3[vorp_admin]^7 events: %s (by %s)'):format(msg, GetPlayerName(src) or src))
    TriggerEvent('vorp_admin:logs', src, Secrets.Webhooks.panelEvents,
        'Admin Panel - Events', msg)
end

CreateThread(function()
    local Core = exports.vorp_core:GetCore()

    Core.Callback.Register('vorp_admin:Callback:eventsSnapshot', function(source, cb)
        if not allowed(source) then return cb(false) end
        if not eventsUp() then return cb({ down = true }) end
        local ok, snap = pcall(function() return exports['pup-events']:PanelSnapshot() end)
        if not ok or type(snap) ~= 'table' then return cb({ down = true }) end
        cb(snap)
    end)
end)

-- on | off | auto
RegisterNetEvent('vorp_admin:events:force', function(key, mode)
    local src = source
    if not allowed(src) or not eventsUp() then return end
    key, mode = tostring(key or ''), tostring(mode or '')
    if mode ~= 'on' and mode ~= 'off' and mode ~= 'auto' then return end

    local ok, done = pcall(function() return exports['pup-events']:PanelForce(key, mode) end)
    if ok and done then
        logStaff(src, ('%s forced %s'):format(key, mode))
    else
        tell(src, 'No event called ' .. key, 5000)
    end
end)

RegisterNetEvent('vorp_admin:events:setWindow', function(key, from, to, hourFrom, hourTo)
    local src = source
    if not allowed(src) or not eventsUp() then return end
    key = tostring(key or '')

    local ok, done, why = pcall(function()
        return exports['pup-events']:PanelSetWindow(key,
            tostring(from or ''), tostring(to or ''), tonumber(hourFrom), tonumber(hourTo))
    end)
    if ok and done then
        logStaff(src, ('%s window set to %s..%s, hours %s-%s'):format(
            key, tostring(from), tostring(to), tostring(hourFrom), tostring(hourTo)))
        tell(src, 'Saved.', 4000)
    else
        tell(src, 'Not saved: ' .. tostring(why or 'check the dates'), 6000)
    end
end)

-- Moves the in-game clock for EVERYONE. The only quick way to reach a night
-- window without sitting through the day.
RegisterNetEvent('vorp_admin:events:setHour', function(hour)
    local src = source
    if not allowed(src) or not eventsUp() then return end
    hour = tonumber(hour)
    if not hour or hour < 0 or hour > 23 then return end

    local ok, done = pcall(function() return exports['pup-events']:PanelSetHour(hour) end)
    if ok and done then
        logStaff(src, ('in-game clock set to %02d:00'):format(hour))
        tell(src, ('Clock set to %02d:00 for the whole server.'):format(hour), 5000)
    else
        tell(src, 'weathersync refused the time change.', 5000)
    end
end)
