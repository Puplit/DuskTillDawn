-- THE PURGE | weather. main.lua raises the blood moon; this is the sky under it.
-- weathersync walks a weighted table, so naming only storms keeps it stormy

local PURGE_PATTERN <const> = {
    thunderstorm = { thunderstorm = 45, thunder = 20, sandstorm = 35 },
    thunder      = { thunderstorm = 45, thunder = 15, sandstorm = 40 },
    sandstorm    = { sandstorm = 40, thunderstorm = 40, thunder = 20 },
}

local applied = false

local function weather(fn, ...)
    if GetResourceState('weathersync') ~= 'started' then return false end
    -- '...' cannot be read inside the pcall closure, so pack it out here
    local args <const> = table.pack(...)
    local ok, err = pcall(function()
        local api <const> = exports['weathersync'] -- inside the pcall: a missing export throws
        return api[fn](api, table.unpack(args, 1, args.n))
    end)
    if not ok then print('^3[pup-events]^7 weathersync:' .. fn .. ' failed: ' .. tostring(err)) end
    return ok
end

local function apply(on)
    if on == applied then return end
    applied = on

    if on then
        weather('setWeatherPattern', PURGE_PATTERN)
        -- start it in the storm rather than waiting out the current interval
        weather('setWeather', 'thunderstorm', 60, false)
        print('^3[pup-events]^7 purge weather on - thunderstorm / dust')
    else
        weather('resetWeatherPattern')
        weather('resetWeather')
        print('^3[pup-events]^7 purge weather off - normal pattern restored')
    end
end

AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= 'purge' then return end
    apply(on == true)
end)

PurgeWeatherApplied = function() return applied end

-- a restart with the purge already live must not leave the sky normal
CreateThread(function()
    Wait(10000)
    local ok, live = pcall(function() return exports['pup-events']:IsLive('purge') end)
    if ok and live then apply(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if applied then
        weather('resetWeatherPattern')
        weather('resetWeather')
    end
end)
