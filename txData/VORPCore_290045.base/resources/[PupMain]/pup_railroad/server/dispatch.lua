-- pup_railroad | server: sign-in, track junctions, station announcements

local L <const> = Rail.L

local Switches = {} -- [junction index] = value last set
local Cooldown = {} -- [src] = os.time() of the last announcement

--------------------------------------------------------------------------------
-- sign-in: job, trains out, junction states
--------------------------------------------------------------------------------
Srv.on('hello', { gap = 1000 }, function(_, char)
    local switches = {}
    for i, v in pairs(Switches) do switches[#switches + 1] = { i, v } end
    return { ok = true, job = char.job, list = Srv.publicList(), switches = switches }
end)

--------------------------------------------------------------------------------
-- junctions
--------------------------------------------------------------------------------
Srv.on('switch', { gap = Config.Timings.switchGap }, function(src, _, index, side)
    index = Rail.int(index)
    local j = index and Config.Junctions[index]
    if not j or (side ~= 'left' and side ~= 'right') then return end
    if not Srv.hasKey(src) then return end
    if not Srv.within(Srv.playerPos(src), j.pos, Config.Reach.junction) then return end
    local value = side == 'left' and j.left or j.right
    Switches[index] = value
    TriggerClientEvent('pup_railroad:junction', -1, index, value)
end)

--------------------------------------------------------------------------------
-- announcements
--------------------------------------------------------------------------------
local function playersNear(points, radius)
    local hits = {}
    for _, id in ipairs(GetPlayers()) do
        local s = tonumber(id)
        local pos = s and Srv.playerPos(s)
        if pos then -- players the server cannot place are not counted
            for i = 1, #points do
                if #(pos - points[i]) <= radius then
                    hits[#hits + 1] = s
                    break
                end
            end
        end
    end
    return hits
end

Srv.on('announce', { gap = 500 }, function(src, char, kind, originKey, target)
    local cfg = Config.Announcements
    if not cfg.enabled or not cfg.boardEnabled or char.job ~= cfg.job then return Srv.fail(src, 'invalid') end
    local origin = Rail.stationByKey(originKey)
    if not origin then return Srv.fail(src, 'invalid') end

    local now = os.time()
    if Cooldown[src] and now - Cooldown[src] < cfg.cooldown then return Srv.fail(src, 'announce_cooldown') end

    if kind == 'route' then
        local dest = Rail.stationByKey(target)
        if not dest or dest.key == origin.key then return Srv.fail(src, 'invalid') end
        Cooldown[src] = now
        local text = L('route_call', origin.name, dest.name)
        local hits = playersNear({ dest.coords }, dest.hearing or cfg.hearingDistance)
        for i = 1, #hits do TriggerClientEvent('vorp:TipBottom', hits[i], text, Config.Timings.announceNotice) end
        Srv.notify(src, L('called_ahead', dest.name, #hits))
        return { ok = true }
    elseif kind == 'status' then
        local status
        for i = 1, #cfg.statuses do
            if cfg.statuses[i].key == target then status = cfg.statuses[i] end
        end
        if not status then return Srv.fail(src, 'invalid') end
        Cooldown[src] = now
        local points = {}
        if cfg.statusEverywhere then
            for i = 1, #Config.Stations do points[i] = Config.Stations[i].coords end
        else
            points[1] = origin.coords
        end
        local text = L(status.text, origin.name)
        local hits = playersNear(points, cfg.platformRadius)
        for i = 1, #hits do TriggerClientEvent('vorp:TipBottom', hits[i], text, Config.Timings.announceNotice) end
        Srv.notify(src, L('called_down', #hits))
        return { ok = true }
    end
    return Srv.fail(src, 'invalid')
end)

AddEventHandler('playerDropped', function()
    Cooldown[source] = nil
end)
