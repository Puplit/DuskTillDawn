-- pup-medical | purge overrides of the respawn rules (server side)

local function eventsResource()
    return Config.Integrations and Config.Integrations.events and Config.Integrations.events.resource
end

local function eventKey()
    return Config.Purge and Config.Purge.eventKey
end

local function check()
    local res, key = eventsResource(), eventKey()
    if not key then return end
    local live = false
    if Started(res) then
        local ok, v = pcall(function() return exports[res]:IsLive(key) end)
        live = ok and v == true
    end
    SetPurgeApplied(live)
end

CreateThread(function()
    Wait(8000)
    while true do
        check()
        Wait(10000)
    end
end)

AddEventHandler('pup-events:server:state', function(key, on)
    if key ~= eventKey() then return end
    SetPurgeApplied(on == true)
end)

exports('PurgeDeathStatus', function()
    return PurgeStatus()
end)
