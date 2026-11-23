local VorpCore = {}
TriggerEvent("getCore", function(core) VorpCore = core end)

local active   = false
local endsAt   = 0
local lastHowl = 0
local lookIdx  = Config.Moon.defaultLook or 1

local function isAdmin(src)
    local ok, user = pcall(function() return VorpCore.getUser(src) end)
    local group = ok and user and user.getGroup
    if group and Config.General.adminGroups[group] then return true end
    local gotPanel, panelOk = pcall(function()
        return exports.vorp_admin:allowedToExecuteAction(src, "open_menu")
    end)
    return gotPanel and panelOk == true
end

local function isNight()
    if not Config.Night.enabled then return true end
    local ok, t = pcall(function() return exports['weathersync']:getTime() end)
    local hour = (ok and type(t) == 'table') and tonumber(t.hour) or nil
    if not hour then return true end
    local from, to = Config.Night.fromHour, Config.Night.toHour
    if from <= to then return hour >= from and hour < to end
    return hour >= from or hour < to
end

local function raise(why)
    active = true
    endsAt = (Config.Moon.durationMinutes > 0) and (os.time() + Config.Moon.durationMinutes * 60) or 0
    TriggerClientEvent('pup-bloodmoon:set', -1, Config.Moon.transitionInSeconds, lookIdx)
    print(('^1[bloodmoon]^7 up (look %d) - %s'):format(lookIdx, why or '?'))
end

local function lower(why)
    if not active then return end
    active, endsAt = false, 0
    TriggerClientEvent('pup-bloodmoon:clear', -1, Config.Moon.transitionOutSeconds)
    print(('^2[bloodmoon]^7 down - %s'):format(why or '?'))

    -- weathersync only broadcasts on change, so re-push its weather or clients stay stuck
    SetTimeout(1000, function()
        local ok, w = pcall(function() return exports['weathersync']:getWeather() end)
        if not ok or type(w) ~= 'string' or w == '' then
            return print('^1[bloodmoon]^7 could not read weathersync weather to restore it')
        end
        TriggerClientEvent('weathersync:changeWeather', -1, w, Config.Moon.transitionOutSeconds, false)
    end)
end

CreateThread(function()
    while true do
        Wait(30000)
        if active then
            if endsAt > 0 and os.time() >= endsAt then
                lower('ran its course')
            elseif not isNight() then
                lower('dawn')
            end
        end
    end
end)

AddEventHandler('playerJoining', function()
    if active then TriggerClientEvent('pup-bloodmoon:set', source, 0.0, lookIdx) end
end)
RegisterNetEvent('pup-bloodmoon:sync', function()
    if active then TriggerClientEvent('pup-bloodmoon:set', source, 0.0, lookIdx) end
end)

-- refusals are silent to the player, so the console says why
local function howlDbg(src, why, ...)
    print(('^3[bloodmoon]^7 howl from %s refused: ' .. why):format(GetPlayerName(src) or src, ...))
end

local lastHowlTry = {}
AddEventHandler('playerDropped', function() lastHowlTry[source] = nil end)

-- hashes come back signed or unsigned depending on the native
local function unsignedHash(h)
    h = tonumber(h) or 0
    return h < 0 and h + 4294967296 or h
end

RegisterNetEvent('pup-bloodmoon:howl', function()
    local src = source
    -- a refused howl prints to the console, so one try every few seconds is plenty
    local now = GetGameTimer()
    if lastHowlTry[src] and now - lastHowlTry[src] < 3000 then return end
    lastHowlTry[src] = now
    local H = Config.Howl
    local S = Config.Integrations.shaman
    if not (H and H.enabled) then return end
    if active then return howlDbg(src, 'a moon is already up') end

    if not isNight() then
        howlDbg(src, 'not night')
        return TriggerClientEvent('vorp:TipRight', src, Locale.notNight, 4000)
    end

    if os.time() - lastHowl < (H.cooldownMinutes * 60) then
        local mins = math.ceil(((H.cooldownMinutes * 60) - (os.time() - lastHowl)) / 60)
        howlDbg(src, 'cooldown, %d min left', mins)
        return TriggerClientEvent('vorp:TipRight', src,
            Locale.cooldown:format(mins), 5000)
    end

    -- position and model come off the server's ped, never the client's word for it
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return howlDbg(src, 'no ped on the server') end
    local here = GetEntityCoords(ped)

    local site, nearest = nil, math.huge
    for _, s in ipairs(H.sites or {}) do
        local d = #(s.coords - here)
        if d < nearest then nearest = d end
        if d <= (tonumber(s.radius) or 40.0) then site = s break end
    end
    if not site then return howlDbg(src, '%.0fm from the nearest site', nearest) end

    local model <const> = GetEntityModel(ped)
    local isWolf = false
    for _, name in ipairs(S.wolfModels or {}) do
        if unsignedHash(model) == unsignedHash(GetHashKey(name)) then isWolf = true break end
    end
    if not isWolf then
        howlDbg(src, 'not a wolf ped (model hash %s)', tostring(model))
        return TriggerClientEvent('vorp:TipRight', src, Locale.unanswered, 4000)
    end

    -- pup_shaman's live table, not characters.curse, which can be stale
    if S.requireCurse then
        local ok, curse = pcall(function() return exports['pup_shaman']:GetCurse(src) end)
        if not ok then
            howlDbg(src, 'pup_shaman:GetCurse unavailable')
            return TriggerClientEvent('vorp:TipRight', src, Locale.unanswered, 4000)
        end
        if tostring(curse) ~= S.requireCurse then
            howlDbg(src, 'curse is "%s", needs "%s"', tostring(curse), S.requireCurse)
            return TriggerClientEvent('vorp:TipRight', src, Locale.unanswered, 4000)
        end
    end

    lastHowl = os.time()
    raise(('howled at %s by %s'):format(site.label or '?', GetPlayerName(src) or src))
    if Locale.howlBroadcast and Locale.howlBroadcast ~= '' then
        TriggerClientEvent('vorp:TipRight', -1, Locale.howlBroadcast, 8000)
    end
end)

RegisterCommand(Config.General.command, function(src, args)
    if src > 0 and not isAdmin(src) then return end

    local sub = string.lower(args[1] or '')
    local function say(msg)
        if src > 0 then TriggerClientEvent('vorp:TipRight', src, msg, 5000) else print('  ' .. msg) end
    end

    if sub == 'on' then
        raise('admin')
        return say(Locale.moonUp)

    elseif sub == 'off' then
        lower('admin')
        return say(Locale.moonDown)

    elseif sub == 'look' then
        local n = tonumber(args[2])
        local list = Config.Looks or {}
        if not n or not list[n] then
            say(Locale.pickLook:format(#list))
            for i, l in ipairs(list) do
                local line = ('%d) %s'):format(i, l.label or l.weather)
                if src > 0 then TriggerClientEvent('vorp:TipRight', src, line, 7000) else print('  ' .. line) end
            end
            return
        end
        lookIdx = n
        if active then
            TriggerClientEvent('pup-bloodmoon:set', -1, Config.Moon.transitionInSeconds, lookIdx)
        else
            raise('admin, look ' .. n)
        end
        return say(Locale.lookSet:format(n, list[n].label or list[n].weather))

    elseif sub == 'status' then
        local l = (Config.Looks or {})[lookIdx]
        if not active then return say(Locale.statusNone:format(lookIdx, l and (l.label or l.weather) or '?')) end
        local left = (endsAt > 0) and math.ceil((endsAt - os.time()) / 60) or -1
        return say(Locale.statusUp:format(lookIdx,
            l and (l.label or l.weather) or '?',
            left >= 0 and Locale.statusMinutesLeft:format(left) or ''))
    end

    say(Locale.usage:format(Config.General.command))
end, false)

exports('IsBloodMoon', function() return active end)

-- refuses in daylight: raising then would also suspend weathersync until the maintenance thread undid it
exports('Raise', function(why)
    if active then return false end
    if not isNight() then return false end
    raise(why or 'another resource')
    return true
end)

exports('Lower', function(why)
    if not active then return false end
    lower(why or 'another resource')
    return true
end)
