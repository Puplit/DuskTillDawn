-- pup-stable | side saddle, auto ride follow, waypoint sharing with a passenger, chat suggestions

------------------------------------------------------------------------------
-- side saddle
------------------------------------------------------------------------------
local side = false
local SS = Config.SideSaddle
local SS_DICT = SS.dict

if Config.Commands.sidesaddle then
    RegisterCommand(Config.Commands.sidesaddle, function()
        local me = PlayerPedId()
        if side then
            side = false
            ClearPedSecondaryTask(me)
            return
        end
        if not IsPedOnMount(me) then return Tip(L('notYourOwn')) end
        if not LoadDict(SS_DICT) then return end
        side = true
        CreateThread(function()
            local last = nil
            while side do
                local mount = GetMount(me)
                if mount == 0 then break end
                local pitch = GetEntityPitch(mount)
                local tilt = pitch > 10.0 and 'up' or (pitch < -10.0 and 'down' or 'flat')
                local clip = SS[tilt]
                if tilt ~= last or not IsEntityPlayingAnim(me, SS_DICT, clip, 3) then
                    last = tilt
                    TaskPlayAnim(me, SS_DICT, clip, 4.0, -4.0, -1, 1 + 16 + 32, 0.0, false, false, false)
                end
                Wait(500)
            end
            side = false
            ClearPedSecondaryTask(me)
        end)
    end, false)
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.sidesaddle, L('sideSaddleHelp'))
end

------------------------------------------------------------------------------
-- auto ride follow (ped config flag); "0" turns it back on
------------------------------------------------------------------------------
if Config.Commands.disableAutoRideFollow then
    RegisterCommand(Config.Commands.disableAutoRideFollow, function(_, args)
        local on = args[1] == '0'
        SetPedConfigFlag(PlayerPedId(), 560, not on)
        Tip(on and L('autoRideOn') or L('autoRideOff'))
    end, false)
end

if Config.Commands.reloadHorse then
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.reloadHorse, L('fixHorseHelp'))
end

if Config.Commands.fixHorse then
    RegisterCommand(Config.Commands.fixHorse, function()
        CreateThread(function() RefreshHorses() Horse.refind() end)
    end, false)
end

------------------------------------------------------------------------------
-- waypoint sharing with someone on the same horse
------------------------------------------------------------------------------
if Config.Horse.shareWaypoint then
    local sharedBlip = nil
    local sharedAt = nil
    local lastSent = nil

    local function clearShared()
        if sharedBlip then N.blipRemove(sharedBlip) sharedBlip = nil end
        if sharedAt then ClearGpsMultiRoute() sharedAt = nil end
    end

    CreateThread(function()
        while true do
            Wait(1000)
            local me = PlayerPedId()
            local mount = GetMount(me)
            if mount ~= 0 and IsWaypointActive() then
                local wp = GetWaypointCoords()
                local key = ('%.1f:%.1f'):format(wp.x, wp.y)
                if key ~= lastSent then
                    lastSent = key
                    local others = {}
                    for _, pl in ipairs(GetActivePlayers()) do
                        local ped = GetPlayerPed(pl)
                        if ped ~= me and GetMount(ped) == mount then others[#others + 1] = GetPlayerServerId(pl) end
                    end
                    if #others > 0 then TriggerServerEvent('pup-stable:waypoint', others, wp.x, wp.y) clearShared() end
                end
            elseif not IsWaypointActive() then
                lastSent = nil
            end
            if sharedAt and #(vector2(GetEntityCoords(me).x, GetEntityCoords(me).y) - sharedAt) <= 10.0 then clearShared() end
        end
    end)

    RegisterNetEvent('pup-stable:waypoint', function(x, y)
        x, y = tonumber(x), tonumber(y)
        if not x or not y then return end
        clearShared()
        sharedAt = vector2(x, y)
        sharedBlip = N.blipCoords(1664425300, x, y, 0.0)
        if sharedBlip and sharedBlip ~= 0 then N.blipName(sharedBlip, L('blipWaypoint')) end
        StartGpsMultiRoute(joaat('COLOR_YELLOW'), true, true)
        AddPointToGpsMultiRoute(x, y, 0.0)
        SetGpsMultiRouteRender(true)
    end)

    AddEventHandler('onResourceStop', function(res) if res == RES then clearShared() end end)
end
