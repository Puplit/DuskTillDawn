-- pup_hideouts | instances: who may go in, occupants, last world position

local popOff = {} -- buckets already set up

local function prepBucket(b)
    if popOff[b] then return end
    popOff[b] = true
    SetRoutingBucketPopulationEnabled(b, false)
end

-- everything that has to follow a player changing instance (also called by the 1 s sweep
-- when another resource moved them)
function HX.onBucketChange(src, newBucket)
    local was = HX.buckets[src]
    HX.buckets[src] = newBucket
    if was == newBucket then return end
    local nowIn = HX.hideoutByBucket(newBucket)
    for id, occ in pairs(HX.occupants) do
        if occ[src] and (not nowIn or nowIn.id ~= id) then occ[src] = nil end
    end
    for id, holder in pairs(HX.menuLock) do
        if holder == src and (not nowIn or nowIn.id ~= id) then HX.menuLock[id] = nil end
    end
    for id, holder in pairs(HX.stashLock) do
        if holder == src and (not nowIn or nowIn.id ~= id) then HX.stashLock[id] = nil end
    end
    if nowIn then HX.invites[src] = nil end
    if HX.Bookie then HX.Bookie.onLeft(src, nowIn and nowIn.id or nil) end
    if HX.Raids then HX.Raids.onBucket(src, nowIn and nowIn.id or nil) end
end

-- may this player be moved into this hideout's instance?
function HX.mayEnter(src, h)
    if not h then return false end
    if not Player(src).state.IsInSession then return false end
    local cid = HX.charId(src)
    if not cid then return false end
    if HX.isMember(h, cid) then return true end
    if HX.isCrew(h, cid) then return true end
    if HX.isAdmin(src) then return true end
    local inv = HX.invites[src]
    if inv and inv.id == h.id and inv.expires > os.time() then return true end
    return false
end

-- returns the bucket the player ends up in
HX.rpc('setBucket', function(src, wanted)
    wanted = U.int(wanted)
    if not wanted then return HX.bucket(src) end
    if wanted == 0 then
        -- the world is always allowed once a character session is live
        if not Player(src).state.IsInSession then return HX.bucket(src) end
        SetPlayerRoutingBucket(src, 0)
        HX.onBucketChange(src, HX.bucket(src))
        TriggerClientEvent('pup-instance:bucket', src, HX.bucket(src))
        return HX.bucket(src)
    end
    local h = HX.hideoutByBucket(wanted)
    -- every way in starts at the door (the enter prompt, an answered knock, a picked lock), so
    -- anyone but an admin must be standing there: no walking in from across the map
    local atDoor = h and HX.bucket(src) == 0 and U.dist(HX.pos(src), h.coords) <= Config.Hideouts.doorReach
    if h and (atDoor or HX.isAdmin(src)) and HX.mayEnter(src, h) then
        prepBucket(wanted)
        SetPlayerRoutingBucket(src, wanted)
        HX.onBucketChange(src, wanted)
    end
    TriggerClientEvent('pup-instance:bucket', src, HX.bucket(src))
    return HX.bucket(src)
end, 500)

-- the client finished walking in
HX.on('entered', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h or not HX.isInside(src, h) then return end
    HX.occupants[h.id] = HX.occupants[h.id] or {}
    HX.occupants[h.id][src] = true
    if HX.Bookie then HX.Bookie.sendState(h.id, src) end
end, 500)

HX.on('left', function(src, id)
    id = tonumber(id)
    if id and HX.occupants[id] then HX.occupants[id][src] = nil end
end, 200)

function HX.occupantList(id)
    local out = {}
    for s in pairs(HX.occupants[id] or {}) do
        if GetPlayerName(s) and HX.bucket(s) == id + Config.InstanceOffset then out[#out + 1] = s end
    end
    return out
end

-- everyone inside, by bucket (not just the ones who reported in)
function HX.insideSources(h)
    local out = {}
    local b = HX.bucketOf(h)
    for _, sid in ipairs(GetPlayers()) do
        local s = tonumber(sid)
        if s and GetPlayerRoutingBucket(s) == b then out[#out + 1] = s end
    end
    return out
end

-- put everyone inside back outside
function HX.forceOut(h)
    for _, s in ipairs(HX.insideSources(h)) do
        TriggerClientEvent('pup_hideouts:forceLeave', s, h.id, h.coords)
    end
end

-- the client's row refresh before entering
HX.rpc('row', function(src, id)
    local h = HX.hideouts[tonumber(id)]
    if not h then return nil end
    return HX.viewFor(h, src)
end, 300)

HX.rpc('rows', function(src)
    HX.pushAllTo(src)
    return true
end, 1000)

-- what the client may show (prompts, blips, the create command). Read fresh from VORP every
-- time, so a job change is picked up; the server re-checks every action anyway.
function HX.flags(src)
    return {
        admin = HX.isAdmin(src) == true,
        staff = HX.isStaff(src) == true,
        police = HX.isPoliceJob(src) == true,
        job = HX.jobOf(src),
    }
end

HX.rpc('me', function(src) return HX.flags(src) end, 500)

----------------------------------------------------------------------------------------------------
-- last world position (shared with pup_realestate). Always the sender's own character.
----------------------------------------------------------------------------------------------------
RegisterNetEvent('pup_hideouts:sendlastcoords', function(_, coords)
    local src = tonumber(source)
    if not src or not GetPlayerName(src) or not HX.ready then return end
    if not HX.rateOk(src, 'lastcoords', 1000) then return end
    local cid = HX.charId(src)
    local c = U.plain(coords)
    local pos = HX.pos(src)
    if not cid or not c or not pos or U.isOrigin(c) then return end
    if U.dist(c, pos) > Config.Hideouts.lastPosReach then return end
    MySQL.update('UPDATE `characters` SET `moonshineenty` = ? WHERE `charidentifier` = ?', { json.encode(c), cid })
end)

RegisterNetEvent('pup_hideouts:getlastshinecoords', function()
    local src = tonumber(source)
    if not src or not GetPlayerName(src) or not HX.ready then return end
    if not HX.rateOk(src, 'getlast', 1000) then return end
    local cid = HX.charId(src)
    local out
    if cid then
        local row = MySQL.single.await('SELECT `moonshineenty` FROM `characters` WHERE `charidentifier` = ?', { cid })
        out = U.plain(U.decode(row and row.moonshineenty, nil))
        if out and U.isOrigin(out) then out = nil end
    end
    if not out then
        local f = Config.FallbackSpots[1]
        out = f and U.plain(f.coords) or { x = 0.0, y = 0.0, z = 0.0 }
    end
    TriggerClientEvent('pup_hideouts:reclastshinecoords', src, out)
    TriggerClientEvent('pup_realestate:reclastshinecoords', src, out)
end)

-- catch instance changes made by anything else
CreateThread(function()
    while true do
        Wait(1000)
        for src in pairs(HX.online) do
            if GetPlayerName(src) then
                local b = GetPlayerRoutingBucket(src)
                if HX.buckets[src] ~= b then HX.onBucketChange(src, b) end
            end
        end
    end
end)
