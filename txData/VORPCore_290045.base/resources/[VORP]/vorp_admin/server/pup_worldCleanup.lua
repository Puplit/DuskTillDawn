-- WORLD CLEANUP. The "Clear spawned entities" button on the Anti-Cheat tab.
-- Warns everyone in chat, counts down, then deletes every SCRIPT-CREATED vehicle, ped
-- and prop on the server (OneSync). Player peds, whatever a player is sitting in or on,
-- and the game's own ambient population are left alone.
--
-- Other resources keep their state right by listening for:
--   server  AddEventHandler('vorp_admin:worldCleanup', fn(info))      just before deleting
--           AddEventHandler('vorp_admin:worldCleanupDone', fn(info))  after deleting
--   client  RegisterNetEvent('vorp_admin:worldCleanup' / 'vorp_admin:worldCleanupDone')
-- info = { id, by, at } and, on Done, info.counts = { vehicle, ped, object, kept, asked, failed }

local W = Config.WorldCleanup or {}
local TXT = W.text or {}

local TYPE_PED <const>, TYPE_VEHICLE <const>, TYPE_OBJECT <const> = 1, 2, 3
-- GET_ENTITY_POPULATION_TYPE (server, CFX): 7 = POPTYPE_MISSION, 0 = POPTYPE_UNKNOWN
local POP_MISSION <const>, POP_UNKNOWN <const> = 7, 0

local state = {
    running = false,
    cancelled = false,
    id = 0,
    by = nil,
    bySrc = 0,
    endsAt = 0,
    collectId = nil, -- the id clients may answer while it is set
    reported = {},   -- src -> true, one report per player per cleanup
    protect = {},    -- entity -> true, what players said they are in or on
    finishedAt = 0,
    last = nil,
}

local function allowed(src)
    if src == 0 then return true end -- server console
    if not HasPermission then return false end
    return HasPermission(src, W.permission or 'anticheat_cleanup') == true
end

local function tell(src, msg)
    if src and src > 0 then
        TriggerClientEvent('vorp:TipRight', src, msg, 6000)
    else
        print('^3[worldcleanup]^7 ' .. msg)
    end
end

-- poodlechat (and the stock chat) take chat:addMessage
local function chat(msg)
    TriggerClientEvent('chat:addMessage', -1, {
        color = { 255, 140, 0 },
        multiline = true,
        args = { TXT.chatTitle or 'STAFF', msg },
    })
end

-- the two spellings differ between builds; take whichever this server has
local function netIdOf(entity)
    if type(NetworkGetNetworkIdFromEntity) == 'function' then return NetworkGetNetworkIdFromEntity(entity) end
    if type(GetNetworkIdFromEntity) == 'function' then return GetNetworkIdFromEntity(entity) end
    return nil
end

local keepModelSet
local function keepModels()
    if keepModelSet then return keepModelSet end
    keepModelSet = {}
    for _, m in ipairs(W.keepModels or {}) do
        local h = type(m) == 'number' and m or GetHashKey(tostring(m))
        keepModelSet[h] = true
    end
    return keepModelSet
end

local function hasKeepKey(entity)
    local keys = W.keepStateKeys
    if type(keys) ~= 'table' or #keys == 0 then return false end
    local ok, st = pcall(function() return Entity(entity).state end)
    if not ok or not st then return false end
    for _, key in ipairs(keys) do
        if st[key] ~= nil and st[key] ~= false then return true end
    end
    return false
end

local function allOf(fn, want)
    if not want or type(fn) ~= 'function' then return {} end
    return fn() or {}
end

-- Decide for one entity, ignoring attachments. true = it is a script entity we delete.
local function baseDecision(e, etype, playerPeds, playerVehicles)
    if playerPeds[e] or state.protect[e] or playerVehicles[e] then return false end
    if keepModels()[GetEntityModel(e)] then return false end
    if hasKeepKey(e) then return false end

    local pop = GetEntityPopulationType(e)
    if etype == TYPE_PED then
        if pop ~= POP_MISSION then return false end
        -- the driver or passenger of something a player is in
        local veh = GetVehiclePedIsIn(e, false)
        if veh and veh ~= 0 and (playerVehicles[veh] or state.protect[veh]) then return false end
        return true
    elseif etype == TYPE_VEHICLE then
        return pop == POP_MISSION
    elseif etype == TYPE_OBJECT then
        if pop == POP_MISSION then return true end
        return pop == POP_UNKNOWN and W.objectsUnknownPopType ~= false
    end
    return false
end

-- top of an attachment chain (a prop in a hand, a carcass on a saddle, a lantern on a wagon)
local function attachRoot(e)
    local cur, depth = e, 0
    while depth < 6 do
        local parent = GetEntityAttachedTo(cur)
        if not parent or parent == 0 or parent == cur or not DoesEntityExist(parent) then break end
        cur, depth = parent, depth + 1
    end
    return cur
end

local function classify()
    local playerPeds, playerVehicles = {}, {}
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            playerPeds[ped] = true
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 then playerVehicles[veh] = true end
        end
    end

    local candidates = {}
    local function add(list, etype)
        for _, e in pairs(list) do
            if DoesEntityExist(e) then candidates[#candidates + 1] = { e = e, t = etype } end
        end
    end
    add(allOf(GetAllVehicles, W.vehicles ~= false), TYPE_VEHICLE)
    add(allOf(GetAllPeds, W.peds ~= false), TYPE_PED)
    add(allOf(GetAllObjects, W.objects ~= false), TYPE_OBJECT)

    local base = {}
    for i, c in ipairs(candidates) do
        base[c.e] = baseDecision(c.e, c.t, playerPeds, playerVehicles)
        if i % 200 == 0 then Wait(0) end
    end

    -- an attached entity goes or stays with whatever it hangs from. Anything on a player,
    -- on a kept horse, or in an ambient townsperson's hand is kept.
    local delete, kept = {}, 0
    for _, c in ipairs(candidates) do
        local go = base[c.e]
        if go then
            local root = attachRoot(c.e)
            if root ~= c.e then
                if playerPeds[root] then
                    go = false
                elseif base[root] == nil then
                    -- a root we never looked at (a kind that is switched off): keep
                    go = false
                else
                    go = base[root] == true
                end
            end
        end
        if go then
            delete[#delete + 1] = c
        elseif base[c.e] then
            kept = kept + 1 -- was a script entity, but protected
        end
    end
    return delete, kept, playerVehicles
end

-- DeleteEntity first. When the server cannot remove one, the client that owns it is
-- asked to take control and delete it (client/pup_cleanup.lua).
local function removeEntity(entity, etype)
    if not DoesEntityExist(entity) then return 'gone' end
    local netId = netIdOf(entity)
    local owner = NetworkGetEntityOwner(entity)

    DeleteEntity(entity)
    if not DoesEntityExist(entity) then return 'deleted' end

    if owner and owner > 0 and netId and netId > 0 then
        TriggerClientEvent('vorp_admin:cleanup:deleteNetId', owner, netId, etype == TYPE_VEHICLE)
        return 'asked'
    end
    return 'failed'
end

local KIND <const> = { [TYPE_VEHICLE] = 'vehicle', [TYPE_PED] = 'ped', [TYPE_OBJECT] = 'object' }

local function sweep()
    local delete, kept = classify()

    -- a player may have climbed in since the list was built
    local seated = {}
    for _, pid in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(pid)
        if ped and ped ~= 0 then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and veh ~= 0 then seated[veh] = true end
        end
    end

    local counts = { vehicle = 0, ped = 0, object = 0, kept = kept, asked = 0, failed = 0 }
    for i, c in ipairs(delete) do
        if seated[c.e] then
            counts.kept = counts.kept + 1
        else
            local r = removeEntity(c.e, c.t)
            if r == 'deleted' or r == 'gone' then
                counts[KIND[c.t]] = counts[KIND[c.t]] + 1
            elseif r == 'asked' then
                counts.asked = counts.asked + 1
            else
                counts.failed = counts.failed + 1
            end
        end
        if i % 100 == 0 then Wait(0) end
    end
    return counts
end

local function reset()
    state.running = false
    state.cancelled = false
    state.collectId = nil
    state.reported = {}
    state.protect = {}
    state.endsAt = 0
end

local function run(src)
    state.running = true
    state.cancelled = false
    state.id = state.id + 1
    state.bySrc = src
    state.by = src > 0 and (GetPlayerName(src) or ('id ' .. src)) or 'console'
    state.reported, state.protect = {}, {}

    local id = state.id
    local seconds = math.max(1, math.floor(tonumber(W.seconds) or 10))
    state.endsAt = os.time() + seconds

    local marks = {}
    for _, s in ipairs(W.announceAt or { 10, 5, 3, 2, 1 }) do marks[tonumber(s) or -1] = true end

    local warning = (TXT.warning or 'All spawned wagons, horses, objects and peds will be deleted in %d seconds.'):format(seconds)
    chat(warning)
    TriggerClientEvent('vorp:ShowTopNotification', -1, TXT.chatTitle or 'STAFF', warning, 8000)
    tell(src, TXT.started or 'World cleanup started.')
    print(('^3[worldcleanup]^7 started by %s, %ds countdown'):format(state.by, seconds))

    local collectAt = math.min(2, seconds)
    for left = seconds, 1, -1 do
        if state.cancelled then
            chat(TXT.cancelled or 'The world cleanup was cancelled by staff.')
            print(('^3[worldcleanup]^7 cancelled (%s)'):format(state.by))
            reset()
            return
        end
        if left ~= seconds and marks[left] then
            chat((TXT.countdown or 'Deleting spawned entities in %d...'):format(left))
        end
        -- ask everyone what they are riding or driving, so it is left alone
        if left == collectAt then
            state.collectId = id
            TriggerClientEvent('vorp_admin:worldCleanup:collect', -1, id)
        end
        Wait(1000)
    end
    state.collectId = nil

    local info = { id = id, by = state.by, at = os.time() }
    -- resources clear their own records and delete their own client-only props now
    TriggerEvent('vorp_admin:worldCleanup', info)
    TriggerClientEvent('vorp_admin:worldCleanup', -1, info)
    Wait(250)

    local counts = sweep()

    -- owners handed a delete need a moment before "gone" is true everywhere
    Wait(1500)
    info.counts = counts
    TriggerEvent('vorp_admin:worldCleanupDone', info)
    TriggerClientEvent('vorp_admin:worldCleanupDone', -1, info)
    chat(TXT.done or 'Spawned entities have been cleared.')

    local report = ('%d wagons/vehicles, %d peds (horses included), %d objects deleted; %d kept (ridden, carried or protected), %d handed to the owner, %d could not be removed')
        :format(counts.vehicle, counts.ped, counts.object, counts.kept, counts.asked, counts.failed)
    print(('^3[worldcleanup]^7 %s: %s'):format(state.by, report))
    TriggerEvent('vorp_admin:logs', state.bySrc, Secrets.Webhooks.spawnGuard, 'World cleanup',
        ('Cleared spawned entities after a %ds warning\n%s'):format(seconds, report))

    state.last = {
        at = info.at, by = state.by,
        vehicle = counts.vehicle, ped = counts.ped, object = counts.object,
        kept = counts.kept, asked = counts.asked, failed = counts.failed,
    }
    state.finishedAt = os.time()
    reset()
end

local function start(src)
    if W.enabled == false then return tell(src, TXT.disabled or 'World cleanup is turned off.') end
    if state.running then return tell(src, TXT.running or 'A world cleanup is already counting down.') end
    local wait = (tonumber(W.cooldown) or 0) - (os.time() - state.finishedAt)
    if state.finishedAt > 0 and wait > 0 then
        return tell(src, (TXT.cooldown or 'Wait %d seconds.'):format(wait))
    end
    -- set before the thread starts, so a double click cannot slip in two
    state.running = true
    CreateThread(function()
        local ok, err = pcall(run, src)
        if not ok then
            print('^1[worldcleanup]^7 failed: ' .. tostring(err))
            reset()
        end
    end)
end

RegisterNetEvent('vorp_admin:worldCleanup:start', function()
    local src = source
    if not allowed(src) then return end
    start(src)
end)

-- what each player is sitting in or on, answered from client/pup_worldCleanup.lua.
-- Only entities near that player count, so nobody can shield something across the map.
RegisterNetEvent('vorp_admin:worldCleanup:report', function(id, netIds)
    local src = source
    if not state.running or state.collectId == nil or id ~= state.collectId then return end
    if type(netIds) ~= 'table' or state.reported[src] then return end
    state.reported[src] = true

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local here = GetEntityCoords(ped)
    local radius = tonumber(W.reportRadius) or 30.0

    for i = 1, math.min(#netIds, 10) do
        local nid = tonumber(netIds[i])
        if nid and nid > 0 then
            local e = NetworkGetEntityFromNetworkId(nid)
            if e and e ~= 0 and DoesEntityExist(e) and #(GetEntityCoords(e) - here) <= radius then
                state.protect[e] = true
            end
        end
    end
end)

-- console or staff: /worldcleanup to start, /worldcleanup cancel during the countdown
RegisterCommand('worldcleanup', function(src, args)
    src = tonumber(src) or 0
    if not allowed(src) then return end
    if tostring(args[1] or ''):lower() == 'cancel' then
        if not state.running then return tell(src, 'No world cleanup is running.') end
        state.cancelled = true
        return tell(src, 'Cancelling the world cleanup.')
    end
    start(src)
end, false)

-- for the Anti-Cheat tab
function WorldCleanupStatus()
    return {
        running = state.running,
        secondsLeft = state.running and math.max(0, state.endsAt - os.time()) or 0,
        by = state.running and state.by or nil,
        last = state.last,
    }
end

exports('worldCleanupStatus', function() return WorldCleanupStatus() end)
exports('isWorldCleanupRunning', function() return state.running end)
