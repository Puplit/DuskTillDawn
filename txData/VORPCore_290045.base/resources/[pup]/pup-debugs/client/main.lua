-- reports this client's load stage so a drop can be attributed; public natives only

local worstHitch, hitchCount = 0, 0
local frames, frameMs = 0, 0

-- a freeze is one huge frame: compare the gap we got with the one we asked for
CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(100)
        local now = GetGameTimer()
        local took = now - last
        local over = took - 100
        frames = frames + 1
        frameMs = frameMs + took
        if over > Config.Drops.hitchMs then
            hitchCount = hitchCount + 1
            if over > worstHitch then worstHitch = over end
        end
        last = now
    end
end)

local function inSession()
    return LocalPlayer.state.IsInSession and true or false
end

-- stage from position and the session flag only, never another resource's globals
local function stage(ped)
    if inSession() then return "ingame" end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return "no-ped" end
    if #(GetEntityCoords(ped) - Config.Drops.creatorCoords) < Config.Drops.creatorRadius then
        return "creator/select"
    end
    return "loading"
end

-- the signals the creator waits on; a timeout with these false means streaming never arrived
local function streaming(ped)
    local interior = 0
    pcall(function()
        local i = GetInteriorAtCoords(Config.Drops.creatorCoords.x, Config.Drops.creatorCoords.y, Config.Drops.creatorCoords.z)
        if i ~= 0 and IsValidInterior(i) == 1 and IsInteriorReady(i) == 1 then interior = 1 end
    end)
    return {
        coll  = (ped ~= 0 and HasCollisionLoadedAroundEntity(ped)) and 1 or 0,
        scene = IsLoadSceneLoaded() and 1 or 0,
        int   = interior,
        net   = NetworkIsPlayerActive(PlayerId()) and 1 or 0,
        faded = IsScreenFadedOut() and 1 or 0,
    }
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local co = (ped ~= 0 and DoesEntityExist(ped)) and GetEntityCoords(ped) or vector3(0, 0, 0)
        local s = streaming(ped)
        local avg = frames > 0 and math.floor(frameMs / frames) or 0

        TriggerServerEvent("pup-debugs:beacon", {
            stage = stage(ped),
            x = math.floor(co.x + 0.5), y = math.floor(co.y + 0.5), z = math.floor(co.z + 0.5),
            coll = s.coll, scene = s.scene, int = s.int, net = s.net, faded = s.faded,
            hitch = worstHitch, hitches = hitchCount,
            tick = avg,  -- average ms per 100ms wake: >100 means the client is behind
        })

        worstHitch, hitchCount, frames, frameMs = 0, 0, 0, 0
        Wait(inSession() and Config.Drops.beaconInSessionMs or Config.Drops.beaconPreSessionMs)
    end
end)

-- staff asked the server for this client's numbers
RegisterNetEvent("pup-debugs:ping", function()
    TriggerServerEvent("pup-debugs:pong", {
        hitch = worstHitch, hitches = hitchCount,
        fps = frames > 0 and math.floor(1000 / math.max(1, frameMs / frames)) or 0,
    })
end)
