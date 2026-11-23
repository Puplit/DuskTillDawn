-- pup_hideouts | the client loop, getting unstuck, /getout and the debug theme probe

local H <const> = Config.Hideouts

----------------------------------------------------------------------------------------------------
-- one loop for every prompt this resource shows. Idle (nothing near) it sleeps half a second;
-- it only runs every frame while a door, the inside of a hideout or a knock needs drawing.
----------------------------------------------------------------------------------------------------
CreateThread(function()
    while true do
        local sleep = 500
        if HX.insideId then
            sleep = 0
            HX.insideMaintain()
            if not HX.busy and not HX.knockPrompt() and not HX.menuOpen then HX.insidePrompts() end
        elseif HX.hasKnockAsk() and not HX.menuOpen then
            sleep = 0
            HX.knockPrompt()
        elseif not HX.busy and not HX.menuOpen then
            local pos = HX.pos()
            local r = HX.nearestDoor(pos, H.promptRange)
            if r then
                sleep = 0
                HX.doorPrompts(r)
            elseif HX.nearestDoor(pos, 25.0) then
                sleep = 100 -- close enough to start caring: check more often
            end
        end
        Wait(sleep)
    end
end)

----------------------------------------------------------------------------------------------------
-- getting unstuck after a join or a restart with the player still at an interior
----------------------------------------------------------------------------------------------------
local function nearInterior(pos)
    for _, z in pairs(Config.Zones) do
        if U.dist(pos, z.inside) <= H.nearInterior then return true end
    end
    return false
end

local lastPosWait = nil
RegisterNetEvent('pup_hideouts:reclastshinecoords', function(c)
    if lastPosWait then
        local p = lastPosWait
        lastPosWait = nil
        p:resolve(c)
    end
end)

local function askLastPos()
    local p = promise.new()
    lastPosWait = p
    TriggerServerEvent('pup_hideouts:getlastshinecoords', HX.charId)
    SetTimeout(8000, function() if lastPosWait == p then lastPosWait = nil; p:resolve(nil) end end)
    return Citizen.Await(p)
end

local function fallbackNear(c)
    local spots = Config.FallbackSpots
    if not spots[1] then return nil end
    local best, bd = spots[1].coords, math.huge
    local v = U.vec(c)
    if not v or U.isOrigin(v) then return best end
    for _, s in ipairs(spots) do
        local d = U.dist(v, s.coords)
        if d < bd then best, bd = s.coords, d end
    end
    return best
end

local recovering = false
local function recoverIfStuck()
    if recovering or HX.insideId then return end
    local ped = PlayerPedId()
    if not nearInterior(GetEntityCoords(ped)) then return end
    recovering = true
    FreezeEntityPosition(ped, true)
    HX.fade(true)
    local last = askLastPos()
    local spot = fallbackNear(last)
    HX.call('setBucket', 4000, 0)
    if spot then HX.teleport(spot) end
    FreezeEntityPosition(PlayerPedId(), false)
    HX.fade(false)
    recovering = false
end

local function afterJoin()
    CreateThread(function()
        local t = GetGameTimer() + 60000
        while not LocalPlayer.state.IsInSession and GetGameTimer() < t do Wait(1000) end
        if not LocalPlayer.state.IsInSession then return end
        Wait(3000)
        HX.refreshFlags()
        HX.blipsSoon()
        recoverIfStuck()
    end)
end

RegisterNetEvent('vorp:SelectedCharacter', function()
    -- a new character starts outside every hideout; whatever the old one had open goes
    HX.menuClose()
    if HX.insideId then
        HX.clearLook()
        HX.insideId = nil
        TriggerEvent('pup-scene:stopscene', true) -- give /scene back (it was blocked on entering)
    end
    afterJoin() -- raid / wagon crews follow the server id across a switch
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.IsInSession then afterJoin() end
end)

-- the server (re)learned who we are: refresh what we may see
RegisterNetEvent('pup_hideouts:hello', function()
    CreateThread(function()
        HX.refreshFlags()
        HX.blipsSoon()
    end)
end)

----------------------------------------------------------------------------------------------------
-- /getout
----------------------------------------------------------------------------------------------------
RegisterCommand(H.getoutCommand, function()
    if HX.insideId then return HX.leave() end
    if not nearInterior(HX.pos()) then return end
    CreateThread(function()
        HX.call('setBucket', 4000, 0)
        TriggerEvent('pup-scene:stopscene', true)
        HX.fade(true)
        HX.teleport(H.getoutPoint)
        HX.fade(false)
    end)
end, false)

----------------------------------------------------------------------------------------------------
-- /themecheck (debug): which theme sets exist in this interior
----------------------------------------------------------------------------------------------------
RegisterCommand('themecheck', function()
    if not Config.Debug then return HX.tip(L('debug_disabled')) end
    local r = HX.insideId and HX.rows[HX.insideId]
    local zone = U.zone(r and r.zone)
    for _, t in ipairs(Config.Themes) do
        local v = Citizen.InvokeNative(0xD56FF170710D3E5A, zone.interior, t.set) -- _IS_INTERIOR_ENTITY_SET_VALID
        print(('[pup_hideouts] theme %s (%s): %s'):format(t.label, t.set, (v == true or v == 1) and 'exists' or 'missing'))
    end
end, false)
