-- weathersync : pup-ui admin panel A drop-in replacement for the bundled ui/ NUI

if not Config.usePupUi then return end

local PANEL_OWNER = 'weathersync:admin'

local open       = false
local currentTab = 'weather'
local state      = nil  -- { weather, day, hour, min, sec, timescale, windDirection, windSpeed, syncDelay }
local lastSig    = nil  -- change detector, so we don't repaint an idle panel

local TABS = {
    { id = 'weather', label = 'Weather', icon = 'star' },
    { id = 'time',    label = 'Time',    icon = 'clock' },
    { id = 'wind',    label = 'Wind',    icon = 'chart' },
}

-- helpers

-- pup-ui's OpenInput is non-blocking and takes `fields`
local function askInput(title, fields)
    local p = promise.new()
    local owner = 'weathersync:input:' .. title
    local ev
    ev = AddEventHandler('pup-ui:client:inputDone', function(o, values)
        if o ~= owner then return end
        RemoveEventHandler(ev)
        p:resolve(values)
    end)
    exports['pup-ui']:OpenInput({ owner = owner, title = title, fields = fields })
    return Citizen.Await(p)
end

local function clock()
    if not state then return '--:--' end
    return ('%02d:%02d:%02d'):format(
        tonumber(state.hour) or 0, tonumber(state.min) or 0, tonumber(state.sec) or 0)
end

-- "sunny" -> "Sunny", "snowlight" -> "Snowlight"
local function pretty(w)
    w = tostring(w or '')
    if w == '' then return 'unknown' end
    return w:sub(1, 1):upper() .. w:sub(2)
end

-- content builders
local function tabWeather()
    local items = {}
    for _, w in ipairs(Config.weatherTypes or {}) do
        local isNow = state and state.weather == w
        items[#items + 1] = {
            title = pretty(w),
            sub = isNow and 'Currently in effect' or nil,
            actions = {
                { id = 'setw:' .. w, label = isNow and 'Re-apply' or 'Set',
                  tone = isNow and 'ghost' or nil },
            },
        }
    end

    return {
        { type = 'heading', text = 'Weather',
          sub = 'Applies to every player. Transition time is asked for on the next screen.' },
        { type = 'stats', items = {
            { value = pretty(state and state.weather), label = 'Now' },
            { value = clock(),                          label = 'Server Time' },
        } },
        { type = 'list', items = items },
    }
end

local function tabTime()
    return {
        { type = 'heading', text = 'Time',
          sub = 'Server clock and how fast it runs. Timescale 0 follows real time.' },
        { type = 'stats', items = {
            { value = clock(),                                    label = 'Time' },
            { value = tostring(state and state.day or 0),          label = 'Day' },
            { value = tostring(state and state.timescale or 0),    label = 'Timescale' },
        } },
        { type = 'list', items = {
            { title = 'Set time', sub = 'Day, hour, minute - applied to everyone',
              actions = { { id = 'settime', label = 'Set' } } },
            { title = 'Freeze time here', sub = 'Stops the clock at the current moment',
              actions = { { id = 'freezetime', label = 'Freeze' } } },
            { title = 'Set timescale', sub = 'Game seconds per real second (0 = real time)',
              actions = { { id = 'setscale', label = 'Set' } } },
        } },
        { type = 'actions', buttons = {
            { id = 'time:dawn',  label = 'Dawn 06:00' },
            { id = 'time:noon',  label = 'Noon 12:00' },
            { id = 'time:dusk',  label = 'Dusk 18:00' },
            { id = 'time:night', label = 'Night 00:00' },
        } },
    }
end

local function tabWind()
    return {
        { type = 'heading', text = 'Wind & Sync',
          sub = 'Wind drives weather drift; sync delay is how often clients are corrected.' },
        { type = 'stats', items = {
            { value = ('%.0f'):format(tonumber(state and state.windDirection) or 0), label = 'Direction' },
            { value = ('%.1f'):format(tonumber(state and state.windSpeed) or 0),     label = 'Speed' },
            { value = tostring(state and state.syncDelay or 0),                      label = 'Sync Delay' },
        } },
        { type = 'list', items = {
            { title = 'Set wind', sub = 'Direction in degrees, speed',
              actions = { { id = 'setwind', label = 'Set' } } },
            { title = 'Set sync delay', sub = 'Seconds between client corrections',
              actions = { { id = 'setdelay', label = 'Set' } } },
        } },
    }
end

local function buildTab(tab)
    if tab == 'time' then return tabTime() end
    if tab == 'wind' then return tabWind() end
    return tabWeather()
end

local function render()
    exports['pup-ui']:OpenApp({
        owner = PANEL_OWNER,
        title = 'WEATHER',
        subtitle = 'TIME & WEATHER CONTROL',
        badge = 'ADMIN',
        tabs = TABS,
        active = currentTab,
        content = buildTab(currentTab),
    })
end

local function repaint()
    if not open then return end
    exports['pup-ui']:UpdateApp({ active = currentTab, content = buildTab(currentTab) })
end

-- wiring

-- the bundled UI polls the server every second while open; keep that, it is what feeds the live clock
AddEventHandler('weathersync:updateAdminUi', function(weather, time, timescale, windDirection, windSpeed, syncDelay)
    if not open then return end
    local d, h, m, s = TimeToDHMS(time)
    state = {
        weather = weather, day = d, hour = h, min = m, sec = s,
        timescale = timescale, windDirection = windDirection,
        windSpeed = windSpeed, syncDelay = syncDelay,
    }
    -- only repaint on a real change: at timescale 30 the seconds field moves every tick
    local sig = ('%s|%s|%s|%s|%s|%s|%s|%s'):format(
        tostring(weather), tostring(d), tostring(h), tostring(m), tostring(s),
        tostring(timescale), tostring(windDirection) .. '/' .. tostring(windSpeed), tostring(syncDelay))
    if sig == lastSig then return end
    lastSig = sig
    repaint()
end)

AddEventHandler('pup-ui:client:appNav', function(owner, tab)
    if owner ~= PANEL_OWNER then return end
    currentTab = tab
    repaint()
end)

AddEventHandler('pup-ui:client:appClosed', function(owner)
    if owner ~= nil and owner ~= PANEL_OWNER then return end
    open = false
    currentTab = 'weather'
    lastSig = nil
end)

AddEventHandler('pup-ui:client:appAction', function(owner, action)
    if owner ~= PANEL_OWNER or type(action) ~= 'string' then return end

    -- weather: ask for the transition, then fire the SAME event the bundled UI did
    local w = action:match('^setw:(.+)$')
    if w then
        Citizen.CreateThread(function()
            local vals = askInput('Change Weather', {
                { label = 'Transition seconds (0 = instant)', type = 'number', default = 15, min = 0, max = 600 },
                { label = 'Freeze weather here', type = 'select', default = 'no',
                  options = { { label = 'No', value = 'no' }, { label = 'Yes', value = 'yes' } } },
            })
            if vals then
                TriggerServerEvent('weathersync:setWeather', w,
                    (tonumber(vals[1]) or 0) * 1.0, vals[2] == 'yes', Config.permanentSnow)
            end
            render()
        end)
        return
    end

    -- quick time presets
    local preset = action:match('^time:(%a+)$')
    if preset then
        local hours = { dawn = 6, noon = 12, dusk = 18, night = 0 }
        local h = hours[preset]
        if h then
            TriggerServerEvent('weathersync:setTime', state and state.day or 0, h, 0, 0, 0, false)
        end
        return
    end

    if action == 'settime' then
        Citizen.CreateThread(function()
            local vals = askInput('Set Time', {
                { label = 'Day',    type = 'number', default = state and state.day or 0,  min = 0 },
                { label = 'Hour',   type = 'number', default = state and state.hour or 12, min = 0, max = 23 },
                { label = 'Minute', type = 'number', default = state and state.min or 0,  min = 0, max = 59 },
            })
            if vals then
                TriggerServerEvent('weathersync:setTime',
                    tonumber(vals[1]) or 0, tonumber(vals[2]) or 0, tonumber(vals[3]) or 0, 0, 0, false)
            end
            render()
        end)
        return
    end

    if action == 'freezetime' then
        TriggerServerEvent('weathersync:setTime',
            state and state.day or 0, state and state.hour or 0,
            state and state.min or 0, state and state.sec or 0, 0, true)
        return
    end

    if action == 'setscale' then
        Citizen.CreateThread(function()
            local vals = askInput('Set Timescale', {
                { label = 'Game seconds per real second (0 = real time)', type = 'number',
                  default = state and state.timescale or 30, min = 0, max = 1000 },
            })
            if vals and vals[1] ~= nil then
                TriggerServerEvent('weathersync:setTimescale', (tonumber(vals[1]) or 0) * 1.0)
            end
            render()
        end)
        return
    end

    if action == 'setwind' then
        Citizen.CreateThread(function()
            local vals = askInput('Set Wind', {
                { label = 'Direction (degrees)', type = 'number',
                  default = math.floor(tonumber(state and state.windDirection) or 0), min = 0, max = 360 },
                { label = 'Speed', type = 'number',
                  default = tonumber(state and state.windSpeed) or 0, min = 0, max = 12 },
                { label = 'Freeze wind', type = 'select', default = 'no',
                  options = { { label = 'No', value = 'no' }, { label = 'Yes', value = 'yes' } } },
            })
            if vals then
                TriggerServerEvent('weathersync:setWind',
                    (tonumber(vals[1]) or 0) * 1.0, (tonumber(vals[2]) or 0) * 1.0, vals[3] == 'yes')
            end
            render()
        end)
        return
    end

    if action == 'setdelay' then
        Citizen.CreateThread(function()
            local vals = askInput('Set Sync Delay', {
                { label = 'Seconds between client corrections', type = 'number',
                  default = state and state.syncDelay or 0, min = 0, max = 600 },
            })
            if vals and vals[1] ~= nil then
                TriggerServerEvent('weathersync:setSyncDelay', tonumber(vals[1]) or 0)
            end
            render()
        end)
        return
    end
end)

-- Global on purpose: client.lua's openAdminUi handler calls this instead of SendNUIMessage when Config.usePupUi is on
function WeatherSyncOpenPupUi()
    open = true
    currentTab = 'weather'
    lastSig = nil
    render()
    -- same 1s server poll the bundled UI ran; it is what keeps the clock live
    Citizen.CreateThread(function()
        while open do
            TriggerServerEvent('weathersync:requestUpdatedAdminUi')
            Citizen.Wait(1000)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and open then
        pcall(function() exports['pup-ui']:CloseApp() end)
    end
end)
