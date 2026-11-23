-- pup-events | Dead of Night: the two UFO sites.

local function say(text, ms)
    TriggerEvent('vorp:TipRight', text, ms or 5500)
end

-- ===========================================================================
-- UFO
-- ===========================================================================
local ufoProp, ufoSite, ufoStarted = nil, nil, 0

local function ufoHourOk()
    -- no hours set = the whole event, so an admin forcing it on at any hour still gets the UFO
    local U <const> = Config.DeadOfNight.ufo
    if not U.hourFrom or not U.hourTo then return true end
    -- GetClockHours on the client: weathersync's getTime is a server export
    local h <const> = GetClockHours()
    if not h then return false end
    local from, to = U.hourFrom, U.hourTo
    if from <= to then return h >= from and h < to end
    return h >= from or h < to
end

local function endUfo()
    if ufoProp then EVC.deleteEntity(ufoProp) ufoProp = nil end
    ufoSite, ufoStarted = nil, 0
end

local function startUfo(site)
    ufoSite, ufoStarted = site, GetGameTimer()
    if site.line then say(site.line, 8000) end
    if Config.DeadOfNight.ufo.model then
        local hash = EVC.loadModel(Config.DeadOfNight.ufo.model, 5000)
        if hash then
            ufoProp = CreateObject(hash, site.coords.x, site.coords.y, site.coords.z, false, false, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            if ufoProp and ufoProp ~= 0 then
                FreezeEntityPosition(ufoProp, true)
                SetEntityCollision(ufoProp, false, false)
            end
        end
    end
end

CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state.IsInSession
    while true do
        local wait = 2000
        local U <const> = Config.DeadOfNight.ufo

        if U and U.enabled and EVC.isLive('deadofnight') then
            local me <const> = GetEntityCoords(PlayerPedId())

            if ufoSite then
                wait = 0
                local elapsed <const> = (GetGameTimer() - ufoStarted) / 1000.0
                local rise <const> = math.min(1.0, elapsed / (U.riseSeconds or 25.0))
                local z <const> = ufoSite.coords.z + (U.height or 65.0) * rise
                local L <const> = U.light or {}

                DrawLightWithRange(ufoSite.coords.x, ufoSite.coords.y, z,
                    L.r or 90, L.g or 255, L.b or 140, L.range or 45.0, L.intensity or 4.0)
                if ufoProp and DoesEntityExist(ufoProp) then
                    SetEntityCoords(ufoProp, ufoSite.coords.x, ufoSite.coords.y, z, false, false, false, false)
                    SetEntityHeading(ufoProp, (GetGameTimer() / 40.0) % 360.0)
                end

                local gone <const> = elapsed > ((U.riseSeconds or 25.0) + (U.holdSeconds or 90.0))
                if gone or #(me - ufoSite.coords) > (U.radius or 120.0) * 1.5 or not ufoHourOk() then
                    endUfo()
                end
            elseif ufoHourOk() then
                for _, site in ipairs(U.sites) do
                    if #(me - site.coords) <= (U.radius or 120.0) then
                        startUfo(site)
                        break
                    end
                end
            end
        elseif ufoSite then
            endUfo()
        end

        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    endUfo()
end)

-- ===========================================================================
-- /eventhere - print the spot you are standing on, ready to paste
-- ===========================================================================
RegisterCommand('eventhere', function(_, args)
    local c <const> = GetEntityCoords(PlayerPedId())
    local h <const> = GetEntityHeading(PlayerPedId())
    local note <const> = table.concat(args or {}, ' ')

    local door <const> = ('vector4(%.2f, %.2f, %.2f, %.1f),'):format(c.x, c.y, c.z, h)
    local zone <const> = ('centre = vector3(%.2f, %.2f, %.2f), radius = 120.0,'):format(c.x, c.y, c.z)
    print(door)
    print(zone)

    -- the client cannot write files, so the server appends it to coords.txt
    TriggerServerEvent('pup-events:here', door, zone, note)
    say('Coords printed to F8 and written to coords.txt.', 5000)
end, false)
