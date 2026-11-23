-- boatshops | boats in the water: created by the server, one per character,
-- forgotten on park, sale, disconnect, or when the boat no longer exists

BoatFleet = {}
local F = BoatFleet
local S = BoatServer
local CFG <const> = BoatConfig
local T <const> = CFG.Timings
local L <const> = BoatLocale

local out = {}          -- [rowId] = { id, key, hash, name, charId, src, ent, netId, grace }
local leftBehind = {}   -- [charId] = { ent, src }  parked boats kept when deleteOnPark is off

function F.isOut(id)
    return out[tonumber(id) or -1] ~= nil
end

function F.get(id)
    return out[tonumber(id) or -1]
end

function F.ofChar(charId)
    for _, e in pairs(out) do
        if e.charId == charId then return e end
    end
    return nil
end

local function deleteEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function clearLeftBehind(charId)
    local lb = leftBehind[charId]
    if not lb then return end
    leftBehind[charId] = nil
    deleteEntity(lb.ent)
end

function F.remove(id, delete)
    local e = out[id]
    if not e then return nil end
    out[id] = nil
    if delete then deleteEntity(e.ent) end
    return e
end

-- what the owner's client needs about its boat in the water
local function stateOf(e)
    if not e then return false end
    return { id = e.id, netId = e.netId, key = e.key, hash = e.hash, name = e.name, components = e.components }
end

function F.sendState(src, charId)
    TriggerClientEvent('boatshops:active', src, stateOf(charId and F.ofChar(charId) or nil))
end

-- ------------------------------------------------------------------ spawning

-- The server's CreateVehicle is an RPC: the game creates the boat on the client
-- nearest the launch point, and vorp_admin's guard judges it by that client.
-- So the buyer and anyone standing at least as close to the launch point get a
-- short grant for this one model.
local function grantGuard(src, hash, at)
    if GetResourceState('vorp_admin') ~= 'started' then return end
    local function allow(who)
        local ok, err = pcall(function() return exports.vorp_admin:SpawnGuardAllow(who, hash, CFG.Spawn.guardGrantMs) end)
        if not ok then Boat.debug('SpawnGuardAllow failed: ' .. tostring(err)) end
    end
    allow(src)
    local mine = S.pos(src)
    if not mine or not at or type(GetPlayers) ~= 'function' then return end
    local reach = S.dist(mine, at.x, at.y, at.z) + (tonumber(CFG.Spawn.grantMarginMeters) or 0.0)
    for _, p in ipairs(GetPlayers()) do
        local other = tonumber(p)
        if other and other ~= src then
            local pos = S.pos(other)
            if pos and S.dist(pos, at.x, at.y, at.z) <= reach then allow(other) end
        end
    end
end

local function create(hash, at)
    local x, y, z, h = at.x + 0.0, at.y + 0.0, at.z + 0.0, (at.h or 0.0) + 0.0
    local ent = nil
    if CFG.Spawn.method == 'setter' and type(CreateVehicleServerSetter) == 'function' then
        local ok, e = pcall(CreateVehicleServerSetter, hash, 'boat', x, y, z, h)
        if ok and e and e ~= 0 then ent = e end
    end
    if not ent and type(CreateVehicle) == 'function' then
        local ok, e = pcall(CreateVehicle, hash, x, y, z, h, true, true)
        if ok and e and e ~= 0 then ent = e end
    end
    if not ent then return nil end
    local deadline = GetGameTimer() + T.serverSpawnWaitMs
    while not DoesEntityExist(ent) and GetGameTimer() < deadline do Wait(50) end
    if not DoesEntityExist(ent) then return nil end
    return ent
end

local function spawn(src, ch, shopId, rowId)
    local charId = ch.charIdentifier
    local row = S.loadOwned(rowId, charId)
    if not row then return end
    local shop, entry = S.shopFor(src, ch, shopId, row.boat)
    if not shop then return end
    if not entry then return S.tip(src, L.notHere) end
    if type(entry.jobs) == 'table' and #entry.jobs > 0 and not Boat.inList(entry.jobs, ch.job) then
        return S.tip(src, L.notPermitted)
    end
    if out[row.id] then
        S.tip(src, L.alreadyOut)
        return F.sendState(src, charId)
    end
    if F.ofChar(charId) then
        S.tip(src, L.otherOut)
        return F.sendState(src, charId)
    end

    clearLeftBehind(charId)
    local hash = tonumber(entry.hash) or GetHashKey(row.boat)
    grantGuard(src, hash, shop.launch)
    local ent = create(hash, shop.launch)
    if not ent then
        S.tip(src, L.launchFailed)
        return F.sendState(src, charId)
    end
    -- the player may have left, or switched character, while we waited
    local now = S.online(src) and S.char(src) or nil
    if not now or now.charIdentifier ~= charId then return deleteEntity(ent) end

    local e = {
        id = row.id, key = row.boat, hash = hash, name = row.name, components = row.components,
        charId = charId, src = src, ent = ent,
        netId = NetworkGetNetworkIdFromEntity(ent),
        grace = GetGameTimer() + T.lostGraceMs,
    }
    out[row.id] = e
    pcall(function() Entity(ent).state:set('boatshops_boat', row.id, true) end)

    TriggerClientEvent('boatshops:spawned', src, stateOf(e))
    S.sendBoats(src)
    Boat.debug(('%s launched boat %s (%s)'):format(src, row.id, row.boat))
end

RegisterNetEvent('boatshops:spawn', function(shopId, rowId)
    local src = source
    if S.limited(src, 'spawn') then return end
    local ch = S.char(src)
    if not ch then return end
    S.locked(ch.charIdentifier, spawn, src, ch, shopId, tonumber(rowId))
end)

-- the client never found the boat it was handed
RegisterNetEvent('boatshops:spawnFailed', function(rowId)
    local src = source
    local ch = S.char(src)
    local e = F.get(rowId)
    if not ch or not e or e.charId ~= ch.charIdentifier then return end
    F.remove(e.id, true)
    S.tip(src, L.launchFailed)
    F.sendState(src, ch.charIdentifier)
    S.sendBoats(src)
end)

-- ------------------------------------------------------------------ parking

RegisterNetEvent('boatshops:park', function(rowId)
    local src = source
    local ch = S.char(src)
    local e = F.get(rowId)
    -- only the owner can bring their own boat back
    if not ch or not e or e.charId ~= ch.charIdentifier then return end
    local delete = CFG.Park.deleteOnPark ~= false
    F.remove(e.id, delete)
    if not delete and DoesEntityExist(e.ent) then
        clearLeftBehind(ch.charIdentifier)
        leftBehind[ch.charIdentifier] = { ent = e.ent, src = src }
    end
    F.sendState(src, ch.charIdentifier)
    S.sendBoats(src)
end)

RegisterNetEvent('boatshops:getState', function()
    local src = source
    if S.limited(src, 'state') then return end
    local ch = S.char(src)
    if not ch then return end
    F.sendState(src, ch.charIdentifier)
end)

-- ------------------------------------------------------------------ lost boats

-- a boat deleted by anything but parking goes back to the owner's list
CreateThread(function()
    while true do
        Wait(T.lostCheckMs)
        local now = GetGameTimer()
        for id, e in pairs(out) do
            if now > e.grace and not DoesEntityExist(e.ent) then
                out[id] = nil
                if S.online(e.src) then
                    local ch = S.char(e.src)
                    if ch and ch.charIdentifier == e.charId then
                        S.tip(e.src, L.boatLost:format(e.name), T.tipMs)
                        F.sendState(e.src, e.charId)
                        S.sendBoats(e.src)
                    end
                end
            end
        end
    end
end)

-- vorp_admin world cleanup: a swept boat goes back to its owner's list at once
-- (the check above would get there on its own, just later)
AddEventHandler('vorp_admin:worldCleanupDone', function()
    for id, e in pairs(out) do
        if not DoesEntityExist(e.ent) then
            out[id] = nil
            if S.online(e.src) then
                local ch = S.char(e.src)
                if ch and ch.charIdentifier == e.charId then
                    F.sendState(e.src, e.charId)
                    S.sendBoats(e.src)
                end
            end
        end
    end
    for charId, lb in pairs(leftBehind) do
        if not DoesEntityExist(lb.ent) then leftBehind[charId] = nil end
    end
end)

-- ------------------------------------------------------------------ clean-up

local function dropSource(src)
    for id, e in pairs(out) do
        if e.src == src then F.remove(id, true) end
    end
    for charId, lb in pairs(leftBehind) do
        if lb.src == src then clearLeftBehind(charId) end
    end
end

AddEventHandler('playerDropped', function()
    dropSource(source)
end)

-- a character switch takes the previous character's boat out of the water
AddEventHandler('vorp:SelectedCharacter', function(src)
    src = tonumber(src)
    if src then dropSource(src) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(out) do F.remove(id, true) end
    for charId in pairs(leftBehind) do clearLeftBehind(charId) end
end)
