-- pup-misc / instance - routing buckets (zones, missions, other resources)
--   instanceplayer:setNamed   (from players: into a zone they are at, or back out of one)
--   instanceplayer:setNamed2  (server-side only, any source)
-- * CHARACTER CREATOR ISOLATION

local VorpCore = nil
CreateThread(function()
    while VorpCore == nil do
        TriggerEvent("getCore", function(core) VorpCore = core end)
        if VorpCore == nil then
            local ok, core = pcall(function() return exports.vorp_core:GetCore() end)
            if ok and core then VorpCore = core end
        end
        Wait(100)
    end
end)

Namedinstances = {}

-- bucket requests only count once a character is active; the creator and selection screens keep their private buckets
local function hasActiveCharacter(src)
    local user = VorpCore and VorpCore.getUser and VorpCore.getUser(src)
    return user and user.getUsedCharacter ~= nil
end

local function setNamedFor(src, setName)
    if not hasActiveCharacter(src) then return end
    TriggerClientEvent('DoTheBigRefreshYmaps', src)
    local instanceSource = nil
    if setName == 0 then
        for k, v in pairs(Namedinstances) do
            for k2, v2 in pairs(v.people) do
                if v2 == src then table.remove(v.people, k2) end
            end
            if #v.people == 0 then Namedinstances[k] = nil end
        end
        instanceSource = 0
    else
        for k, v in pairs(Namedinstances) do
            if v.name == setName then instanceSource = k end
        end
        if instanceSource == nil then instanceSource = setName end
    end
    if instanceSource ~= 0 then
        if not Namedinstances[instanceSource] then
            Namedinstances[instanceSource] = { name = setName, people = {} }
        end
        table.insert(Namedinstances[instanceSource].people, src)
    end
    SetPlayerRoutingBucket(src, instanceSource)
end

-- A player only ever asks to walk into a zone or back out of one.
local ZONE_MARGIN <const> = 25.0
local zoneByBucket = {}
for _, zone in ipairs(InstanceConfig.Zones or {}) do
    if zone.channelId then zoneByBucket[zone.channelId] = zone end
end
local homeBucket = {} -- [src] = the bucket they walked into a zone from

local function atZone(src, zone)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return true end
    local c = GetEntityCoords(ped)
    if not c or (c.x == 0 and c.y == 0 and c.z == 0) then return true end
    local points = zone.points or {}
    if #points == 0 then return true end
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, p in ipairs(points) do
        minX, maxX = math.min(minX, p.x), math.max(maxX, p.x)
        minY, maxY = math.min(minY, p.y), math.max(maxY, p.y)
    end
    return c.x >= minX - ZONE_MARGIN and c.x <= maxX + ZONE_MARGIN and c.y >= minY - ZONE_MARGIN and c.y <= maxY + ZONE_MARGIN
end

RegisterServerEvent("pup-misc:instance:setNamed")
AddEventHandler("pup-misc:instance:setNamed", function(setName)
    local src = source
    local wanted = tonumber(setName)
    if not wanted then return end
    local current = GetPlayerRoutingBucket(src)

    local zone = zoneByBucket[wanted]
    if zone then
        if not atZone(src, zone) then return end
        if not zoneByBucket[current] then homeBucket[src] = current end
        return setNamedFor(src, wanted)
    end

    -- leaving: the server knows where they came from, so whatever number was sent they can't be left stuck
    if zoneByBucket[current] then
        local home = homeBucket[src] or 0
        homeBucket[src] = nil
        setNamedFor(src, 0)
        if home ~= 0 then SetPlayerRoutingBucket(src, home) end
    end
end)

-- Other resources only: not a network event, so no client can move anyone with it.
AddEventHandler("pup-misc:instance:setNamed2", function(src, setName)
    setNamedFor(src, setName)
end)

-- CHARACTER CREATOR ISOLATION
local CREATOR_BASE <const> = InstanceConfig.Buckets.creatorBase -- + server id = a bucket nobody else uses
local creatorInstanced = {}

RegisterServerEvent('pup-misc:instance:creatorStart')
AddEventHandler('pup-misc:instance:creatorStart', function()
    local src = source
    -- only honored while NO character is active - a logged-in player cannot use this to vanish out of the world
    local user = VorpCore and VorpCore.getUser and VorpCore.getUser(src)
    local Character = user and user.getUsedCharacter
    if Character then
        print(('[pup-misc] creator instance refused: player %s has an active character'):format(src))
        return
    end
    creatorInstanced[src] = true
    SetPlayerRoutingBucket(src, CREATOR_BASE + src)
end)

-- authoritative restore: the moment a character is picked, back to the world
AddEventHandler('vorp:SelectedCharacter', function(source, character)
    local src = source
    if creatorInstanced[src] then
        creatorInstanced[src] = nil
        SetPlayerRoutingBucket(src, 0)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    creatorInstanced[src] = nil
    homeBucket[src] = nil
    for k, v in pairs(Namedinstances) do
        for i = #v.people, 1, -1 do
            if v.people[i] == src then table.remove(v.people, i) end
        end
        if #v.people == 0 then Namedinstances[k] = nil end
    end
end)

-- exports for other resources (vorp_admin's panel has its own gated event)
exports('SetInstance', function(src, bucket)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return false end
    SetPlayerRoutingBucket(src, math.max(0, math.floor(tonumber(bucket) or 0)))
    return true
end)

exports('GetInstance', function(src)
    src = tonumber(src)
    if not src or not GetPlayerName(src) then return nil end
    return GetPlayerRoutingBucket(src)
end)
