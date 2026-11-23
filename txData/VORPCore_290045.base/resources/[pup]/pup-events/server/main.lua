-- pup-events | server. Owns the clock: decides when an event is live and tells everyone.

local VorpCore = {}
TriggerEvent('getCore', function(core) VorpCore = core end)

EVT = {}
EVT.live  = {}   -- [key] = true while running
EVT.force = {}   -- [key] = true | false, set by an admin, overrides the schedule

local function dbg(...)
    if Config.General.debug then print('^5[pup-events]^7', ...) end
end

local function isAdmin(src)
    if src == 0 then return true end
    local ok, user = pcall(function() return VorpCore.getUser(src) end)
    local group = ok and user and user.getGroup
    if group and Config.General.adminGroups[group] then return true end
    local gotPanel, allowed = pcall(function()
        return exports.vorp_admin:allowedToExecuteAction(src, Config.General.adminPermission)
    end)
    return gotPanel and allowed == true
end

EVT.isAdmin = isAdmin

-- the in-game hour, from weathersync. nil means it could not be read.
function EVT.hour()
    local ok, t = pcall(function() return exports['weathersync']:getTime() end)
    if not ok or type(t) ~= 'table' then return nil end
    return tonumber(t.hour)
end

-- windows: dates live in the database so staff can move an event; config hours are only defaults
EVT.windows = {}   -- [key] = { from, to, hourFrom, hourTo }

local DATE_PATTERN <const> = '^%d%d%d%d%-%d%d%-%d%d$'

local function validDate(s)
    return type(s) == 'string' and s ~= '' and s:match(DATE_PATTERN) ~= nil
end

-- effective window: what is saved, falling back to the config for the hours
function EVT.window(key, e)
    local w <const> = EVT.windows[key] or {}
    return {
        from     = validDate(w.from) and w.from or nil,
        to       = validDate(w.to) and w.to or nil,
        hourFrom = tonumber(w.hourFrom) or e.hourFrom or 0,
        hourTo   = tonumber(w.hourTo) or e.hourTo or 24,
    }
end

local function loadWindows()
    local ok, rows = pcall(function()
        return MySQL.query.await('SELECT * FROM event_windows', {})
    end)
    if not ok then return end
    for _, r in ipairs(rows or {}) do
        EVT.windows[r.event] = {
            from = r.date_from, to = r.date_to,
            hourFrom = tonumber(r.hour_from), hourTo = tonumber(r.hour_to),
        }
    end
end

local function inDateWindow(key, e)
    local w <const> = EVT.window(key, e)
    -- no dates saved = never starts itself, or it would come back every night
    if not w.from and not w.to then return false end
    local today <const> = os.date('%Y-%m-%d')
    if w.from and today < w.from then return false end
    if w.to and today > w.to then return false end
    return true
end

local function inHourWindow(key, e)
    local h <const> = EVT.hour()
    if not h then return false end
    local w <const> = EVT.window(key, e)
    local from, to = w.hourFrom, w.hourTo
    if from <= to then return h >= from and h < to end
    return h >= from or h < to
end

local function shouldRun(key, e)
    if EVT.force[key] ~= nil then return EVT.force[key] end
    if not e.enabled then return false end
    return inDateWindow(key, e) and inHourWindow(key, e)
end

local function bloodMoon(up)
    local fn <const> = up and 'Raise' or 'Lower'
    local ok, err = pcall(function() return exports['pup-bloodmoon'][fn](exports['pup-bloodmoon'], 'dead of night') end)
    if not ok then dbg('pup-bloodmoon:' .. fn .. ' unavailable:', err) end
end

local function moonIsUp()
    local ok, active = pcall(function() return exports['pup-bloodmoon']:IsBloodMoon() end)
    return ok and active == true
end

local lastSaid = {}   -- [key] = os.time() of the last open/close line

-- `announce` is false on the first pass, so starting the resource never toasts anyone
local function setLive(key, e, on, announce)
    local was <const> = EVT.live[key] == true
    if was == on then return end
    EVT.live[key] = on or nil
    TriggerClientEvent('pup-events:state', -1, key, on)
    -- other resources hook this rather than polling IsLive
    TriggerEvent('pup-events:server:state', key, on)
    if e.bloodMoon then bloodMoon(on) end

    -- the in-game clock runs much faster than real time, so announcements are rate limited
    if announce then
        -- open and close are rate limited separately, or a quick open/close would never announce its end
        local slot <const> = key .. (on and ':open' or ':close')
        local gap <const> = (tonumber(Config.General.announceCooldownMinutes) or 120) * 60
        if (os.time() - (lastSaid[slot] or 0)) >= gap then
            local line = on and e.openLine or e.closeLine
            if line then
                -- title over subtitle, both drawn as text
                TriggerClientEvent('vorp:ShowTopNotification', -1, e.label or '', line, 7000)
                lastSaid[slot] = os.time()
            end
        end
    end

    print(('^3[pup-events]^7 %s %s'):format(e.label or key, on and 'is live' or 'has ended'))
end

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `event_windows` (
            `event` VARCHAR(64) NOT NULL,
            `date_from` VARCHAR(10) DEFAULT NULL,
            `date_to` VARCHAR(10) DEFAULT NULL,
            `hour_from` INT DEFAULT NULL,
            `hour_to` INT DEFAULT NULL,
            PRIMARY KEY (`event`)
        )
    ]])
    Wait(1000)
    loadWindows()
end)

CreateThread(function()
    Wait(8000) -- let weathersync come up, and the windows to load
    local first = true
    while true do
        for key, e in pairs(Config.Events) do
            local want <const> = shouldRun(key, e) and true or false
            setLive(key, e, want, not first)

            -- put pup-bloodmoon back while the event still runs (it drops at its own dawn or by hand); Raise refuses in daylight
            if want and e.bloodMoon and not moonIsUp() then bloodMoon(true) end
        end
        first = false
        Wait(math.max(5, Config.General.tickSeconds) * 1000)
    end
end)

-- stopping with a moon up would leave weathersync suspended on every client
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for key, e in pairs(Config.Events) do
        if EVT.live[key] and e.bloodMoon then bloodMoon(false) end
        EVT.live[key] = nil
    end
end)

-- a joining client needs the current picture
RegisterNetEvent('pup-events:sync', function()
    local src <const> = source
    for key in pairs(Config.Events) do
        TriggerClientEvent('pup-events:state', src, key, EVT.live[key] == true)
    end
end)

exports('IsLive', function(key) return EVT.live[key] == true end)

-- ===========================================================================
-- ADMIN PANEL
-- ===========================================================================

local function bloodMoonState()
    local ok, active = pcall(function() return exports['pup-bloodmoon']:IsBloodMoon() end)
    if not ok then return nil end
    return active == true
end

-- everything the Events page draws, in one call
exports('PanelSnapshot', function()
    local out = {
        hour = EVT.hour(),
        today = os.date('%Y-%m-%d'),
        bloodMoon = bloodMoonState(),
        events = {},
    }

    for key, e in pairs(Config.Events) do
        local w <const> = EVT.window(key, e)
        out.events[#out.events + 1] = {
            key      = key,
            label    = e.label or key,
            enabled  = e.enabled and true or false,
            live     = EVT.live[key] == true,
            forced   = EVT.force[key],            -- true / false / nil
            from     = w.from, to = w.to,
            hourFrom = w.hourFrom, hourTo = w.hourTo,
            dated    = (w.from ~= nil or w.to ~= nil),
            bloodMoon = e.bloodMoon and true or false,
            inDate   = inDateWindow(key, e),
            inHour   = inHourWindow(key, e),
        }
    end
    table.sort(out.events, function(a, b) return a.key < b.key end)

    -- Dead of Night detail, so the page can show whether it is actually doing anything
    if Config.DeadOfNight then
        out.don = {
            ufoOn       = (Config.DeadOfNight.ufo or {}).enabled and true or false,
            ufoSites    = #((Config.DeadOfNight.ufo or {}).sites or {}),
            lighthouseOn = (Config.DeadOfNight.lighthouse or {}).enabled and true or false,
            batsOn      = (Config.DeadOfNight.bats or {}).enabled and true or false,
            batTowns    = #((Config.DeadOfNight.bats or {}).towns or {}),
        }
        if Config.TrickOrTreat then
            local live = (EVT.tnt or {}).doors or {}
            local tricks = 0
            for _, d in ipairs(live) do if d.trick then tricks = tricks + 1 end end
            out.don.tntOn    = Config.TrickOrTreat.enabled and true or false
            out.don.tntDoors = #live
            out.don.tntPool  = #(Config.TrickOrTreat.doors or {})
            out.don.tntTrick = tricks
        end
    end

    -- Spring Hunt detail
    if Config.Easter then
        local live = (EVT.easter or {}).patches or {}
        local eggs = 0
        for _, p in pairs(live) do
            for _ in pairs(p.eggs or {}) do eggs = eggs + 1 end
        end
        out.easter = {
            generation = (EVT.easter or {}).generation or 0,
            patches    = #live,
            eggsLeft   = eggs,
            regions    = #(Config.Easter.regions or {}),
            resetMins  = (Config.Easter.patches or {}).resetMinutes or 0,
            blipsOn    = (Config.Easter.blips or {}).enabled and true or false,
            rabbitsOn  = (Config.Easter.rabbits or {}).enabled and true or false,
            webhooks   = (function()
                local W = (Secrets or {}).Webhooks or {}
                local n = 0
                for _, k in ipairs({ 'easterGoldPickup', 'easterGoldOpen' }) do
                    if type(W[k]) == 'string' and W[k] ~= '' then n = n + 1 end
                end
                return n
            end)(),
        }
    end

    -- Purge detail. Its rules live in other resources, so each one reports its own
    -- state rather than this file guessing.
    if Config.Events.purge then
        local function ask(resource, fn)
            if GetResourceState(resource) ~= 'started' then return nil end
            local ok, res = pcall(function() return exports[resource][fn](exports[resource]) end)
            return ok and res or nil
        end

        local search = ask('pup-misc', 'PurgeSearchStatus')
        local death  = ask('pup-medical', 'PurgeDeathStatus')

        out.purge = {
            live        = EVT.live.purge == true,
            weatherOn   = (PurgeWeatherApplied and PurgeWeatherApplied()) and true or false,
            searchOk    = search ~= nil,
            searchOn    = search and search.applied or false,
            lootDead    = search and search.isDead or false,
            maxItems    = search and search.maxItems or 0,
            shieldMins  = search and search.shieldMins or 0,
            protectedJobs = search and search.protectedJobs or 0,
            blacklisted = search and search.blacklisted or 0,
            deathOk     = death ~= nil,
            deathOn     = death and death.applied or false,
            respawn     = death and death.respawnDelay or 0,
        }
    end

    return out
end)

-- save an event's window; empty dates clear it (admin-only again). Returns false with a reason
exports('PanelSetWindow', function(key, from, to, hourFrom, hourTo)
    local e = Config.Events[key]
    if not e then return false, 'no such event' end

    from = (type(from) == 'string' and from ~= '') and from or nil
    to   = (type(to) == 'string' and to ~= '') and to or nil
    if from and not validDate(from) then return false, 'from must be YYYY-MM-DD' end
    if to and not validDate(to) then return false, 'to must be YYYY-MM-DD' end
    if from and to and to < from then return false, 'the end date is before the start' end

    local hf = tonumber(hourFrom) or e.hourFrom or 0
    local ht = tonumber(hourTo) or e.hourTo or 24
    hf = math.max(0, math.min(24, math.floor(hf)))
    ht = math.max(0, math.min(24, math.floor(ht)))

    EVT.windows[key] = { from = from, to = to, hourFrom = hf, hourTo = ht }

    MySQL.query([[
        INSERT INTO event_windows (event, date_from, date_to, hour_from, hour_to)
        VALUES (?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE date_from = VALUES(date_from), date_to = VALUES(date_to),
                                hour_from = VALUES(hour_from), hour_to = VALUES(hour_to)
    ]], { key, from, to, hf, ht })

    -- a saved window is a decision: drop any manual override so the schedule owns it
    EVT.force[key] = nil
    setLive(key, e, shouldRun(key, e) and true or false, true)
    return true
end)

-- mode: 'on' | 'off' | 'auto'
exports('PanelForce', function(key, mode)
    local e = Config.Events[key]
    if not e then return false end
    if mode == 'auto' then
        EVT.force[key] = nil
        setLive(key, e, shouldRun(key, e) and true or false, true)
    elseif mode == 'on' or mode == 'off' then
        EVT.force[key] = (mode == 'on')
        setLive(key, e, mode == 'on', true)
    else
        return false
    end
    return true
end)

-- move the whole server's in-game clock so an hour window can be reached without waiting
exports('PanelSetHour', function(hour)
    hour = tonumber(hour)
    if not hour or hour < 0 or hour > 23 then return false end
    -- weathersync's SERVER setTime is (day, hour, minute, second, transition, freeze);
    -- keep the day it is already on
    local okGet, t = pcall(function() return exports['weathersync']:getTime() end)
    local day <const> = (okGet and type(t) == 'table' and tonumber(t.day)) or 0
    local ok = pcall(function()
        exports['weathersync']:setTime(day, math.floor(hour), 0, 0, 2000, false)
    end)
    return ok
end)

-- ===========================================================================
-- ADMIN
-- ===========================================================================
RegisterCommand(Config.General.command, function(src, args)
    if not isAdmin(src) then return end
    local function say(msg)
        if src > 0 then TriggerClientEvent('vorp:TipRight', src, msg, 6000) else print('  ' .. msg) end
    end

    local sub <const> = tostring(args[1] or ''):lower()
    local key <const> = tostring(args[2] or '')

    if sub == 'on' or sub == 'off' then
        local e = Config.Events[key]
        if not e then return say('No event called ' .. key) end
        EVT.force[key] = (sub == 'on')
        setLive(key, e, sub == 'on', true)
        return say((e.label or key) .. ' forced ' .. sub)
    end

    if sub == 'auto' then
        local e = Config.Events[key]
        if not e then return say('No event called ' .. key) end
        EVT.force[key] = nil
        return say((e.label or key) .. ' back on its schedule')
    end

    local h <const> = EVT.hour()
    say('In-game hour: ' .. tostring(h or 'unknown'))
    for k, e in pairs(Config.Events) do
        say(('%s [%s] - %s%s'):format(k, e.label or '?',
            EVT.live[k] and 'LIVE' or 'off',
            EVT.force[k] ~= nil and ' (forced)' or ''))
    end
    say('/' .. Config.General.command .. ' on|off|auto <key>')
end, false)

-- /eventhere appends here, because a client cannot write files
RegisterNetEvent('pup-events:here', function(door, zone, note)
    local src <const> = source
    -- a staff tool that rewrites a file on the server
    if not isAdmin(src) then return end
    if type(door) ~= 'string' or type(zone) ~= 'string' then return end
    if #door > 200 or #zone > 200 then return end

    local who = tostring(src)
    local ok, user = pcall(function() return VorpCore and VorpCore.getUser(src) end)
    local ch = ok and user and user.getUsedCharacter
    if ch then who = ('%s %s'):format(ch.firstname or '', ch.lastname or '') end

    local head = ('-- %s  by %s'):format(os.date('%Y-%m-%d %H:%M'), who)
    if type(note) == 'string' and note ~= '' then
        head = head .. '  ' .. note:sub(1, 60):gsub('[\r\n]', ' ')
    end

    local res <const> = GetCurrentResourceName()
    local path <const> = 'coords.txt'
    local existing <const> = LoadResourceFile(res, path) or ''
    local block <const> = ('%s\n%s\n%s\n\n'):format(head, door, zone)

    if not SaveResourceFile(res, path, existing .. block, -1) then
        print('^1[pup-events]^7 could not write ' .. path .. ' - is the resource folder read-only?')
        return TriggerClientEvent('vorp:TipRight', src, 'Could not write coords.txt.', 6000)
    end
    print(('^2[pup-events]^7 coords.txt <- %s'):format(door))
end)
