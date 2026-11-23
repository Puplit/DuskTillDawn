-- What is playing, and who is being sent it.
-- Music goes only to players in hearing range ("listeners"). A light thread runs
-- while anything plays, adding players who walk into range (with the right start
-- offset) and dropping those who walk well out of it.

PH = PH or {}

-- [id] = { serial, url, volume, pos, loop, radius, startedAt, loopResetAt, starter,
--          listeners = { [src] = true }, endedBy = { [src] = true } }
PH.Playing = {}

local serialSeq = 0
local syncRunning = false

local function joinRange(play)
    return play.radius + Config.Ranges.hearMargin
end

local function leaveRange(play)
    return play.radius + Config.Ranges.hearMargin + Config.Ranges.leaveMargin
end

local function sendPlay(src, id, play, offset)
    TriggerClientEvent('pup-phonograph:client:play', src, {
        id = id,
        serial = play.serial,
        url = play.url,
        volume = play.volume,
        pos = { x = play.pos.x, y = play.pos.y, z = play.pos.z },
        loop = play.loop,
        radius = play.radius,
        offset = offset,
    })
end

local function connected()
    local list = {}
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        if src then list[#list + 1] = src end
    end
    return list
end

-- add or drop listeners of one play, for the given players
local function syncPlay(id, play, players, now)
    local join, leave = joinRange(play), leaveRange(play)
    for _, src in ipairs(players) do
        local d = PH.DistTo(src, play.pos)
        if play.listeners[src] then
            if d > leave then
                play.listeners[src] = nil
                play.endedBy[src] = nil
                TriggerClientEvent('pup-phonograph:client:stop', src, id)
            end
        elseif d <= join then
            play.listeners[src] = true
            sendPlay(src, id, play, math.max(0, now - play.startedAt))
        end
    end
end

local function syncAll()
    local players = connected()
    local now = os.time()
    for id, play in pairs(PH.Playing) do
        syncPlay(id, play, players, now)
    end
end

local function ensureSync()
    if syncRunning then return end
    syncRunning = true
    CreateThread(function()
        while next(PH.Playing) ~= nil do
            Wait(Config.Timing.listenerSyncMs)
            syncAll()
        end
        syncRunning = false
    end)
end

function PH.SendToListeners(id, event, ...)
    local play = PH.Playing[id]
    if not play then return end
    for src in pairs(play.listeners) do
        TriggerClientEvent(event, src, ...)
    end
end

-- stop one phonograph's music; true if something was playing
function PH.StopPlay(id)
    local play = PH.Playing[id]
    if not play then return false end
    PH.Playing[id] = nil
    for src in pairs(play.listeners) do
        TriggerClientEvent('pup-phonograph:client:stop', src, id)
    end
    return true
end

function PH.StopAllPlays()
    local ids = {}
    for id in pairs(PH.Playing) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do PH.StopPlay(id) end
end

-- start music; the position always comes from the server's copy of the phonograph
function PH.StartPlay(id, url, volume, loop, radius, starter)
    local p = PH.Phonos[id]
    if not p then return false end
    PH.StopPlay(id)

    serialSeq = serialSeq + 1
    local now = os.time()
    local play = {
        serial = serialSeq,
        url = url,
        volume = volume,
        pos = { x = p.x, y = p.y, z = p.z },
        loop = loop == true,
        radius = radius,
        startedAt = now,
        loopResetAt = now,
        starter = starter,
        listeners = {},
        endedBy = {},
    }
    PH.Playing[id] = play
    p.volume = volume
    p.radius = radius

    syncPlay(id, play, connected(), now)
    ensureSync()
    return true
end

-- a player's client reports this play ended. The record is forgotten only when
-- it is older than the echo guard and at least half its listeners agree, so one
-- client cannot wipe it for late joiners.
function PH.ReportEnded(src, id, serial)
    local play = PH.Playing[id]
    if not play or play.serial ~= serial or play.loop then return end
    if not play.listeners[src] then return end
    play.endedBy[src] = true
    if os.time() - play.startedAt < Config.Timing.echoGuardSec then return end

    local listeners, ended = 0, 0
    for s in pairs(play.listeners) do
        listeners = listeners + 1
        if play.endedBy[s] then ended = ended + 1 end
    end
    if ended * 2 >= listeners then
        PH.Playing[id] = nil
    end
end

-- a player's client restarted a looping track; reset the start time (rate-limited)
function PH.ReportLooped(src, id, serial)
    local play = PH.Playing[id]
    if not play or play.serial ~= serial or not play.loop then return end
    if not play.listeners[src] then return end
    local now = os.time()
    if now - play.loopResetAt < Config.Timing.loopReportGuardSec then return end
    play.startedAt = now
    play.loopResetAt = now
end

-- a client lost its sounds (character select) and must be sent them again
function PH.ResyncPlayer(src)
    local now = os.time()
    for id, play in pairs(PH.Playing) do
        play.listeners[src] = nil
        play.endedBy[src] = nil
        syncPlay(id, play, { src }, now)
    end
end

function PH.DropListener(src)
    for _, play in pairs(PH.Playing) do
        play.listeners[src] = nil
        play.endedBy[src] = nil
    end
end

-- music this player started (used when StopWhenStarterLeaves is on)
function PH.StopStartedBy(src)
    local ids = {}
    for id, play in pairs(PH.Playing) do
        if play.starter == src then ids[#ids + 1] = id end
    end
    for _, id in ipairs(ids) do PH.StopPlay(id) end
end
